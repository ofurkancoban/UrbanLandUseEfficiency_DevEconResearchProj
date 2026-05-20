# ==============================================================================
# 02_collect_global_gee.R
# GEE BATCH EXPORT (GAUL 2024) - ALL 193 COUNTRIES (Built_GHSL + Pop_GHSL),
# FULL TERRITORY (whole-country, not urban-only). Provides the national TOTAL
# population used by 02_analysis/03_add_urban_share_density.R to form
# urban_pop_share = urban pop / total pop.
#
#   Admin source : projects/sat-io/open-datasets/FAO/GAUL/GAUL_2024_L1
#                  (FAO Global Administrative Unit Layers 2024, CC BY 4.0)
#   Country key  : iso3_code
#   Unit fields  : gaul1_code / gaul1_name
#
# GAUL 2024 covers every UN member at level 1, so no microstate fallback needed.
# Output: 03_datasets/raw/Zonal_Stats_Global_GAUL2024/  (one CSV per country,
#   columns Built_GHSL_<year> / Pop_GHSL_<year>, summed over the whole territory).
#
# Submits all countries as GEE server-side export tasks.
# Skips countries that already have a CSV file.
# Includes rate-limit protection and retry logic.
# Results go to Google Drive → then downloaded locally.
# ==============================================================================

# 1. SETUP & AUTHENTICATION
project_root <- if (requireNamespace("here", quietly = TRUE)) {
  here::here()
} else {
  getwd()
}

source(file.path(project_root, "02_scripts/00_setup/01_encryption_utils.R"))
my_password <- "OmerFurkanCoban"

load_secure_secrets(
  my_password,
  file.path(project_root, "03_datasets/config/secrets.enc")
)
load_ee_credentials(
  my_password,
  file.path(project_root, "03_datasets/config/ee_credentials.enc")
)

library(tidyverse)
library(sf)
library(cli)

ee <- reticulate::import("ee")
ee$Initialize(project = Sys.getenv("GEE_PROJECT"))

# 2. SETTINGS
output_dir <- file.path(project_root, "03_datasets/raw/Zonal_Stats_Global_GAUL2024/")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

target_years <- c(1975, 1980, 1985, 1990, 1995, 2000, 2005, 2010, 2015, 2020)
drive_folder <- "GEE_Export_SDG_GAUL2024"

# GAUL 2024 first sub-national level (level 1). Country key is `iso3_code`.
admin_asset  <- ee$FeatureCollection(
  "projects/sat-io/open-datasets/FAO/GAUL/GAUL_2024_L1"
)

# Build full country list (193 UN members)
countries <- countrycode::codelist |>
  filter(!is.na(iso3c), !is.na(un.name.en)) |>
  arrange(un.name.en) |>
  pull(iso3c) |>
  unique()

# 3. BUILD COMBINED IMAGE (server-side, only Built_GHSL + Pop_GHSL)
cli::cli_alert_info("Building combined image for {length(target_years)} years...")

ghsl_sample <- ee$ImageCollection("JRC/GHSL/P2023A/GHS_BUILT_S")$first()
native_proj  <- ghsl_sample$projection()

yearly_imgs <- lapply(target_years, function(yr) {
  b_coll    <- ee$ImageCollection("JRC/GHSL/P2023A/GHS_BUILT_S")$filterDate(
    paste0(yr, "-01-01"), paste0(yr, "-12-31")
  )
  built_raw <- ee$Image(ee$Algorithms$If(
    b_coll$size()$gt(0),
    b_coll$first()$select("built_surface"),
    ee$Image$constant(0)
  ))
  built     <- built_raw$updateMask(built_raw$gte(0))$rename(
    paste0("Built_GHSL_", yr)
  )

  p_coll  <- ee$ImageCollection("JRC/GHSL/P2023A/GHS_POP")$filterDate(
    paste0(yr, "-01-01"), paste0(yr, "-12-31")
  )
  pop_raw <- ee$Image(ee$Algorithms$If(
    p_coll$size()$gt(0),
    p_coll$first()$select("population_count"),
    ee$Image$constant(0)
  ))
  pop     <- pop_raw$updateMask(pop_raw$gte(0))$rename(
    paste0("Pop_GHSL_", yr)
  )

  ee$Image(c(built, pop))
})
combined_img <- ee$ImageCollection(yearly_imgs)$toBands()
cli::cli_alert_success(
  "Combined image ready: {length(target_years) * 2} bands"
)

# 4. PRE-DOWNLOAD: pull exports already on Drive so finished countries are NOT
#    re-processed in GEE — only genuinely missing ones get a new export task.
#    If every country file is already local, skip Drive entirely (no API calls).
local_nums0 <- as.integer(str_extract(list.files(output_dir, pattern = "\\.csv$"), "^[0-9]+"))
local_nums0 <- na.omit(local_nums0)
if (length(local_nums0) >= length(countries)) {
  cli::cli_alert_success("All {length(countries)} country files already local — skipping Drive.")
} else {
  if (!requireNamespace("googledrive", quietly = TRUE)) install.packages("googledrive")
  library(googledrive)
  load_drive_token(my_password, file.path(project_root, "03_datasets/config/drive_token.enc"))
  predl_folder <- tryCatch(googledrive::drive_get(drive_folder), error = function(e) NULL)
  if (is.null(predl_folder) || nrow(predl_folder) == 0)
    predl_folder <- tryCatch(googledrive::drive_find(pattern = paste0("^", drive_folder, "$"),
                             type = "folder", n_max = 100), error = function(e) tibble())
  if (nrow(predl_folder) > 0) {
    cli::cli_h2("Pre-download: fetching exports on Drive that are not already local")
    predl <- tryCatch(googledrive::drive_ls(googledrive::as_id(predl_folder$id[1]), n_max = Inf),
                      error = function(e) tibble())
    predl <- predl[grepl("\\.csv$", predl$name, ignore.case = TRUE), , drop = FALSE]
    for (j in seq_len(nrow(predl))) {
      nm  <- predl$name[j]
      num <- as.integer(str_extract(nm, "^[0-9]+"))
      lp  <- file.path(output_dir, nm)
      if (file.exists(lp) || (!is.na(num) && num %in% local_nums0)) next  # already local
      tryCatch({ googledrive::drive_download(googledrive::as_id(predl$id[j]), path = lp, overwrite = TRUE)
                 cli::cli_alert_success("pre-dl {nm}") },
               error = function(e) cli::cli_alert_danger("pre-dl {nm}: {e$message}"))
    }
  }
}

# 4b. DETERMINE WHICH COUNTRIES TO PROCESS (after the pre-download)
existing_files <- list.files(output_dir, pattern = "\\.csv$")
existing_nums  <- as.integer(str_extract(existing_files, "^[0-9]+"))
all_nums       <- seq_along(countries)

cli::cli_h1("Submitting GEE Export Tasks ({length(countries)} countries)")

task_list    <- list()
name2iso     <- list()    # export_name -> iso, to map task failures back to a country
failed_list  <- list()
notfound_list <- list()   # countries with 0 features for the iso3_code filter
skipped      <- 0

for (i in all_nums) {
  iso       <- countries[i]
  full_name <- countrycode::countrycode(iso, "iso3c", "country.name")
  if (is.na(full_name)) full_name <- iso

  file_index  <- sprintf("%03d", i)
  safe_name   <- iconv(full_name, to = "ASCII//TRANSLIT") |>
    str_replace_all("[^[:alnum:]]", "_")
  export_name <- paste0(file_index, "_", safe_name)

  # Skip if CSV already exists locally
  if (i %in% existing_nums) {
    skipped <- skipped + 1
    next
  }

  # --- SUBMIT WITH RETRY + RATE LIMIT PROTECTION ---
  max_retries  <- 5
  submitted    <- FALSE
  simplify_tol <- 1   # coarsened on "Encoded string is too large" (huge geometries
                      # like Chile/Australia: many vertices exceed the request limit)

  for (attempt in 1:max_retries) {
    tryCatch({
      # A. Filter GAUL 2024 by ISO3 code (`iso3_code`).
      # simplify() cleans degenerate edges before Mollweide reprojection; the
      # tolerance grows on "too large" errors so detailed coastlines still fit.
      cities_ee <- admin_asset$filter(
        ee$Filter$eq("iso3_code", iso)
      )$map(function(f) f$simplify(simplify_tol, native_proj))

      n_units <- cities_ee$size()$getInfo()

      if (n_units == 0) {
        cli::cli_alert_danger(
          "Skipping {full_name} ({iso}): 0 features for iso3_code == '{iso}' in GAUL 2024"
        )
        notfound_list[[export_name]] <<- iso
        submitted <- TRUE
        break
      }

      # B. Server-side reduceRegions (no getInfo = no timeout)
      result_fc <- combined_img$reduceRegions(
        collection = cities_ee,
        reducer    = ee$Reducer$sum(),
        scale      = 100,
        crs        = native_proj,
        tileScale  = 16
      )

      # C. Submit export task to Google Drive
      task <- ee$batch$Export$table$toDrive(
        collection     = result_fc,
        description    = export_name,
        folder         = drive_folder,
        fileNamePrefix = export_name,
        fileFormat     = "CSV"
      )
      task$start()

      task_list[[export_name]] <- task
      name2iso[[export_name]] <- iso
      cli::cli_alert_success(
        "[{file_index}] {full_name} ({n_units} ADM1 units)"
      )
      submitted <- TRUE

      Sys.sleep(2)
      break

    }, error = function(e) {
      if (grepl("Too Many Requests|rate|concurrency", e$message,
                ignore.case = TRUE)) {
        wait_time <- attempt * 10
        cli::cli_alert_warning(
          "[{file_index}] Rate limited on {full_name}. ",
          "Waiting {wait_time}s (attempt {attempt}/{max_retries})..."
        )
        Sys.sleep(wait_time)
      } else if (grepl("too large|Encoded string", e$message, ignore.case = TRUE)) {
        simplify_tol <<- simplify_tol * 50   # coarsen geometry, then retry
        cli::cli_alert_warning(
          "[{file_index}] {full_name}: geometry too large — ",
          "retry at simplify {simplify_tol} m (attempt {attempt}/{max_retries})"
        )
      } else {
        cli::cli_alert_danger(
          "[{file_index}] Error on {full_name}: {e$message}"
        )
        if (attempt == max_retries) {
          failed_list[[export_name]] <<- e$message
        }
      }
    })
  }

  if (!submitted) {
    failed_list[[export_name]] <- "Exhausted all retries"
  }
}

# 5. SUMMARY
cli::cli_h1("Submission Complete")
cli::cli_alert_info("Submitted: {length(task_list)}")
cli::cli_alert_info("Skipped (already exist): {skipped}")
if (length(failed_list) > 0) {
  cli::cli_alert_danger("Failed: {length(failed_list)}")
  for (fn in names(failed_list)) {
    cli::cli_alert_danger("  {fn}: {failed_list[[fn]]}")
  }
}

if (length(notfound_list) > 0) {
  cli::cli_alert_warning("Not found in GAUL 2024 (iso3_code mismatch): {length(notfound_list)}")
  for (fn in names(notfound_list)) {
    cli::cli_alert_warning("  {fn}: iso3_code '{notfound_list[[fn]]}' returned 0 features")
  }
}

# 6. MONITOR TASK STATUS — only if anything was submitted this run.
# (Download still runs afterwards, so a re-run can fetch already-finished exports.)
if (length(task_list) > 0) {
cli::cli_h2(
  "Monitoring task progress (Ctrl+C to stop - tasks continue on GEE)..."
)

repeat {
  Sys.sleep(60)

  statuses <- sapply(task_list, function(t) {
    tryCatch(t$status()$state, error = function(e) "UNKNOWN")
  })

  n_completed <- sum(statuses == "COMPLETED")
  n_failed    <- sum(statuses == "FAILED")
  n_running   <- sum(statuses %in% c("RUNNING", "READY"))

  cli::cli_alert_info(
    "[{format(Sys.time(), '%H:%M:%S')}] ",
    "✅ {n_completed} | 🔄 {n_running} | ❌ {n_failed} | ",
    "Total: {length(task_list)}"
  )

  if (n_running == 0) {
    cli::cli_h2("All tasks finished!")

    failed_names <- names(statuses[statuses == "FAILED"])
    if (length(failed_names) > 0) {
      cli::cli_alert_danger("{length(failed_names)} tasks FAILED:")
      for (ft in failed_names) {
        err_msg <- tryCatch(
          task_list[[ft]]$status()$error_message,
          error = function(e) "Unknown error"
        )
        cli::cli_alert_danger("  {ft}: {err_msg}")
      }
    }
    break
  }
}

# 6b. FALLBACK: tasks that FAILED at runtime (e.g. "Encoded string is too large"
#     for Chile/Australia — huge multi-island coastlines). Re-export with very
#     aggressive geometry simplification; the national TOTAL-population sum is
#     insensitive to boundary precision, so a coarse outline is fine.
fb_failed <- names(statuses[statuses %in% c("FAILED", "UNKNOWN")])
if (length(fb_failed) > 0) {
  cli::cli_h1("Fallback: re-exporting {length(fb_failed)} failed country(ies) with coarse geometry")
  for (ft in fb_failed) {
    iso <- name2iso[[ft]]; if (is.null(iso)) next
    done_fb <- FALSE
    for (tol in c(2000, 8000, 30000)) {       # coarsen until it fits
      ok <- tryCatch({
        cities_ee <- admin_asset$filter(ee$Filter$eq("iso3_code", iso))$map(function(f) f$simplify(tol, native_proj))
        result_fc <- combined_img$reduceRegions(collection = cities_ee, reducer = ee$Reducer$sum(),
                       scale = 100, crs = native_proj, tileScale = 16)
        tk <- ee$batch$Export$table$toDrive(collection = result_fc, description = ft,
                folder = drive_folder, fileNamePrefix = ft, fileFormat = "CSV")
        tk$start()
        repeat { Sys.sleep(45); s <- tryCatch(tk$status()$state, error = function(e) "UNKNOWN")
          if (s %in% c("COMPLETED","FAILED","CANCELLED","UNKNOWN")) break }
        if (s == "COMPLETED") { cli::cli_alert_success("fallback {ft}: OK at simplify {tol} m"); TRUE }
        else { cli::cli_alert_warning("fallback {ft}: {s} at simplify {tol} m"); FALSE }
      }, error = function(e) { cli::cli_alert_warning("fallback {ft} @ {tol} m: {e$message}"); FALSE })
      if (isTRUE(ok)) { done_fb <- TRUE; break }
    }
    if (!done_fb) cli::cli_alert_danger("fallback {ft}: still failing after all simplify levels")
  }
}
}  # end: if (length(task_list) > 0)

# 7. DOWNLOAD FROM GOOGLE DRIVE
cli::cli_h2("Downloading results from Google Drive...")

if (!requireNamespace("googledrive", quietly = TRUE)) {
  install.packages("googledrive")
}
library(googledrive)

load_drive_token(
  my_password,
  file.path(project_root, "03_datasets/config/drive_token.enc")
)

# Resolve the Drive folder by id (robust; not by bare string path)
folder <- tryCatch(googledrive::drive_get(drive_folder), error = function(e) NULL)
if (is.null(folder) || nrow(folder) == 0) {
  folder <- tryCatch(googledrive::drive_find(
    pattern = paste0("^", drive_folder, "$"), type = "folder", n_max = 100
  ), error = function(e) tibble())
}

if (nrow(folder) == 0) {
  cli::cli_alert_danger("Drive folder '{drive_folder}' not found — download skipped.")
  cli::cli_alert_info("Re-run 01_data_collection_gaul2024_download.R once exports appear in Drive.")
} else {
  folder_id   <- folder$id[1]
  drive_files <- tryCatch(
    googledrive::drive_ls(googledrive::as_id(folder_id), n_max = Inf),
    error = function(e) { cli::cli_alert_danger("drive_ls failed: {e$message}"); tibble() }
  )
  drive_files <- drive_files[grepl("\\.csv$", drive_files$name, ignore.case = TRUE), , drop = FALSE]
  cli::cli_alert_info("Found {nrow(drive_files)} CSV(s) on Drive")

  downloaded <- 0L
  for (j in seq_len(nrow(drive_files))) {
    fname      <- drive_files$name[j]
    local_path <- file.path(output_dir, fname)
    if (file.exists(local_path)) next
    ok <- FALSE
    for (attempt in 1:3) {
      ok <- tryCatch({
        googledrive::drive_download(googledrive::as_id(drive_files$id[j]),
                                    path = local_path, overwrite = TRUE)
        TRUE
      }, error = function(e) {
        cli::cli_alert_warning("retry {attempt}/3 — {fname}: {e$message}")
        Sys.sleep(attempt * 3); FALSE
      })
      if (isTRUE(ok)) break
    }
    if (isTRUE(ok)) { downloaded <- downloaded + 1L; cli::cli_alert_success("⬇ {fname}") }
  }
  cli::cli_alert_success("Downloaded {downloaded} new file(s)")

  # Reconcile: which of the 193 countries are still missing locally?
  local_csvs  <- list.files(output_dir, pattern = "\\.csv$")
  have_idx    <- sort(unique(as.integer(str_extract(local_csvs, "^[0-9]+"))))
  missing_idx <- setdiff(seq_along(countries), have_idx)
  if (length(missing_idx) > 0) {
    cli::cli_alert_danger("Still missing {length(missing_idx)} / {length(countries)} countries:")
    for (i in missing_idx) {
      iso <- countries[i]; nm <- countrycode::countrycode(iso, "iso3c", "country.name")
      cli::cli_alert_danger("  {sprintf('%03d', i)} {ifelse(is.na(nm), iso, nm)} ({iso})")
    }
  } else {
    cli::cli_alert_success("All {length(countries)} countries present locally.")
  }
}

cli::cli_h1("ALL DONE")
