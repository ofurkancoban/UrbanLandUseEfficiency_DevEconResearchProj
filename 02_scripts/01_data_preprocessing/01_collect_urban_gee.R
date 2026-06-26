# ==============================================================================
# File:          01_collect_urban_gee.R
# Project:       Measuring Sustainable Urbanization in Turkey: An Empirical 
#                Evaluation of the Land Consumption to Population Growth Ratio
# Author:        Ömer Furkan Çoban
# Date:          13.06.2026
# 
# University:    Carl von Ossietzky University of Oldenburg
# Department:    Applied Economics and Data Science
# Course:        Development Economics
# Semester:      SoSe 26
# Lecturers:     Prof. Dr. Jürgen Bitzer
#
# Category:      Data Preprocessing
# Description:   URBAN-scale GHSL collection (Built-up and Population) for 
#                SDG 11.3.1 via Google Earth Engine.
# ==============================================================================
project_root <- if (requireNamespace("here", quietly = TRUE)) here::here() else getwd()
source(file.path(project_root, "02_scripts/00_setup/01_encryption_utils.R"))
my_password <- "OmerFurkanCoban"
load_secure_secrets(my_password, file.path(project_root, "03_datasets/config/secrets.enc"))
load_ee_credentials(my_password, file.path(project_root, "03_datasets/config/ee_credentials.enc"))
library(tidyverse); library(cli)
ee <- reticulate::import("ee"); if (nzchar(Sys.getenv("GEE_PROJECT"))) ee$Initialize(project = Sys.getenv("GEE_PROJECT")) else ee$Initialize()

# ── settings ──────────────────────────────────────────────────────────────────
output_dir    <- file.path(project_root, "03_datasets/raw/Zonal_Stats_Urban_GAUL2024/")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
drive_main    <- "GEE_Export_SDG_Urban_GAUL2024"   # per-country tasks
drive_parts   <- "GEE_Export_SDG_Urban_PARTS"      # per-ADM1 fallback tasks
target_years  <- seq(1975, 2030, by = 5)
URBAN_MIN     <- 21L
simplify_m    <- 1        # primary geometry simplify tolerance (m)
simplify_fb_m <- 200      # fallback per-ADM1 simplify tolerance (m)
maxpx         <- 3e9
admin_asset   <- ee$FeatureCollection("projects/sat-io/open-datasets/FAO/GAUL/GAUL_2024_L1")

# ── country scope: 193 UN states (stable ISO3 reference), indexed by UN name ──
panel_iso <- suppressMessages(read_csv(file.path(project_root,"03_datasets/config/un_member_iso3.csv"), show_col_types=FALSE))
panel_iso <- unique(na.omit(panel_iso$iso3))
countries <- countrycode::codelist |> filter(!is.na(iso3c),!is.na(un.name.en), iso3c %in% panel_iso) |>
  arrange(un.name.en) |> pull(iso3c) |> unique()
stub_of <- function(iso) {
  i <- which(countries == iso); nm <- countrycode::countrycode(iso,"iso3c","country.name"); if (is.na(nm)) nm <- iso
  sprintf("%03d_%s", i, iconv(nm,to="ASCII//TRANSLIT") |> str_replace_all("[^[:alnum:]]","_"))
}
cli::cli_alert_info("Country scope: {length(countries)} UN states")

# ── URBAN-masked combined image (Built_GHSL + Pop_GHSL per year) ─────────────
native_proj <- ee$ImageCollection("JRC/GHSL/P2023A/GHS_BUILT_S")$first()$projection()
pick <- function(coll, band, yr) {
  c <- ee$ImageCollection(coll)$filterDate(paste0(yr,"-01-01"), paste0(yr,"-12-31"))
  ee$Image(ee$Algorithms$If(c$size()$gt(0), c$first()$select(band), ee$Image$constant(0)))
}
yearly_imgs <- lapply(target_years, function(yr) {
  u <- pick("JRC/GHSL/P2023A/GHS_SMOD","smod_code",yr)$gte(URBAN_MIN)         # DEGURBA urban mask
  b <- pick("JRC/GHSL/P2023A/GHS_BUILT_S","built_surface",yr)
  p <- pick("JRC/GHSL/P2023A/GHS_POP","population_count",yr)
  b$updateMask(b$gte(0))$updateMask(u)$rename(paste0("Built_GHSL_",yr))$
    addBands(p$updateMask(p$gte(0))$updateMask(u)$rename(paste0("Pop_GHSL_",yr)))
})
combined_img <- ee$ImageCollection(yearly_imgs)$toBands()
cli::cli_alert_success("Urban-masked image: {length(target_years)*2} bands")

# ── Drive helpers ────────────────────────────────────────────────────────────
library(googledrive)
load_drive_token(my_password, file.path(project_root,"03_datasets/config/drive_token.enc"))
get_folder <- function(nm) { f <- tryCatch(googledrive::drive_get(nm), error=function(e) NULL)
  if (is.null(f) || nrow(f)==0) f <- tryCatch(googledrive::drive_find(pattern=paste0("^",nm,"$"), type="folder", n_max=100), error=function(e) tibble()); f }
dl_csvs <- function(folder_nm, dest, prefix=NULL) {
  f <- get_folder(folder_nm); if (is.null(f) || nrow(f)==0) return(invisible())
  fl <- googledrive::drive_ls(googledrive::as_id(f$id[1]), n_max=Inf)
  fl <- fl[grepl("\\.csv$", fl$name, ignore.case=TRUE), , drop=FALSE]
  if (!is.null(prefix)) fl <- fl[grepl(prefix, fl$name), , drop=FALSE]
  for (j in seq_len(nrow(fl))) { lp <- file.path(dest, fl$name[j]); if (file.exists(lp)) next
    tryCatch({ googledrive::drive_download(googledrive::as_id(fl$id[j]), path=lp, overwrite=TRUE); cli::cli_alert_success("dl {fl$name[j]}") },
             error=function(e) cli::cli_alert_danger("dl {fl$name[j]}: {e$message}")) } }

# ── PRE-DOWNLOAD: pull exports already on Drive, so finished countries are NOT
#    re-processed in GEE — only genuinely missing ones get a new export task.
#    If every country file is already local, skip Drive entirely (no API calls). ─
local_nums0 <- na.omit(as.integer(str_extract(list.files(output_dir, pattern="\\.csv$"), "^[0-9]+")))
if (length(local_nums0) >= length(countries)) {
  cli::cli_alert_success("All {length(countries)} country files already local — skipping Drive pre-download.")
} else {
  cli::cli_h2("Pre-download: fetching exports on Drive that are not already local")
  dl_csvs(drive_main, output_dir)   # dl_csvs already skips files present locally
}

# ── PRIMARY: per-country reduceRegions export ────────────────────────────────
existing_nums <- as.integer(str_extract(list.files(output_dir, pattern="\\.csv$"), "^[0-9]+"))
cli::cli_h1("PRIMARY: per-country export")
task_list <- list(); name2iso <- list(); skipped <- 0
for (iso in countries) {
  idx <- which(countries == iso); export_name <- stub_of(iso)
  if (idx %in% existing_nums) { skipped <- skipped + 1; next }
  tol <- simplify_m   # coarsened on "Encoded string is too large" (huge geometries)
  for (attempt in 1:4) {
    ok <- tryCatch({
      cities <- admin_asset$filter(ee$Filter$eq("iso3_code", iso))$map(function(f) f$simplify(tol, native_proj))
      if (cities$size()$getInfo() == 0) { cli::cli_alert_danger("{export_name}: 0 features"); TRUE }
      else {
        fc <- combined_img$reduceRegions(collection=cities, reducer=ee$Reducer$sum(), scale=100, crs=native_proj, tileScale=16)
        tk <- ee$batch$Export$table$toDrive(collection=fc, description=export_name, folder=drive_main, fileNamePrefix=export_name, fileFormat="CSV")
        tk$start(); task_list[[export_name]] <- tk; name2iso[[export_name]] <- iso
        cli::cli_alert_success("[{sprintf('%03d',idx)}] {iso}"); TRUE
      }
    }, error=function(e) {
      if (grepl("Too Many Requests|rate|concurrency", e$message, ignore.case=TRUE)) { Sys.sleep(attempt*10); FALSE }
      else if (grepl("too large|Encoded string", e$message, ignore.case=TRUE)) {
        tol <<- tol * 50; cli::cli_alert_warning("{export_name}: geometry too large — retry at simplify {tol} m"); FALSE
      } else { cli::cli_alert_danger("{export_name}: {e$message}"); TRUE } })
    if (isTRUE(ok)) { Sys.sleep(2); break }
  }
}
cli::cli_alert_info("Submitted {length(task_list)} | skipped {skipped}")

monitor <- function(tasks, label) {
  if (!length(tasks)) return(setNames(character(0), character(0)))
  cli::cli_h2("Monitoring {length(tasks)} {label} task(s)...")
  repeat {
    Sys.sleep(45)
    st <- sapply(tasks, function(t) tryCatch(t$status()$state, error=function(e) "UNKNOWN"))
    cli::cli_alert_info("[{label} {format(Sys.time(),'%H:%M:%S')}] done {sum(st=='COMPLETED')} | run {sum(st %in% c('RUNNING','READY'))} | fail {sum(st=='FAILED')} / {length(tasks)}")
    if (sum(st %in% c("RUNNING","READY")) == 0) return(st)
  }
}
prim_st <- monitor(task_list, "primary")

# ── FALLBACK: failed countries -> per-ADM1 reduceRegion tasks ────────────────
failed_isos <- unique(unlist(name2iso[names(prim_st)[prim_st %in% c("FAILED","UNKNOWN")]]))
fb_tasks <- list()
if (length(failed_isos)) {
  cli::cli_h1("FALLBACK (per-ADM1): {paste(failed_isos, collapse=', ')}")
  for (iso in failed_isos) {
    stub <- stub_of(iso); pdir <- file.path(output_dir, paste0(tolower(sub("^[0-9]+_","",stub)), "_parts"))
    if (!dir.exists(pdir)) dir.create(pdir, recursive = TRUE)
    fc <- admin_asset$filter(ee$Filter$eq("iso3_code", iso)); n <- fc$size()$getInfo(); lst <- fc$toList(n)
    cli::cli_alert_info("{iso}: {n} ADM1 units")
    for (i in 0:(n-1)) {
      fi <- ee$Feature(lst$get(i)); nm <- tryCatch(fi$get("gaul1_name")$getInfo(), error=function(e) paste0("adm",i))
      ename <- sprintf("%s_p%02d_%s", stub, i, iconv(nm,to="ASCII//TRANSLIT") |> str_replace_all("[^[:alnum:]]","_"))
      tryCatch({
        one <- ee$FeatureCollection(list(fi$simplify(simplify_fb_m, native_proj)))
        res <- one$map(function(ff) ff$set(combined_img$reduceRegion(reducer=ee$Reducer$sum(), geometry=ff$geometry(),
                 scale=100, crs=native_proj, maxPixels=maxpx, tileScale=16, bestEffort=TRUE)))
        tk <- ee$batch$Export$table$toDrive(collection=res, description=ename, folder=drive_parts, fileNamePrefix=ename, fileFormat="CSV")
        tk$start(); fb_tasks[[ename]] <- tk; cli::cli_alert_success("  [{iso} p{sprintf('%02d',i)}] {nm}"); Sys.sleep(1)
      }, error=function(e) cli::cli_alert_danger("  [{iso} p{sprintf('%02d',i)}] {nm}: {e$message}"))
    }
  }
  monitor(fb_tasks, "fallback")
}

# ── DOWNLOAD (main folder): fetch any newly-exported results ──────────────────
cli::cli_h2("Downloading per-country results")
dl_csvs(drive_main, output_dir)

# ── DOWNLOAD + MERGE parts for fallback countries ────────────────────────────
if (length(failed_isos)) {
  cli::cli_h2("Downloading + merging per-ADM1 parts")
  for (iso in failed_isos) {
    stub <- stub_of(iso); pdir <- file.path(output_dir, paste0(tolower(sub("^[0-9]+_","",stub)), "_parts"))
    dl_csvs(drive_parts, pdir, prefix=paste0("^", stub, "_p"))
    parts <- list.files(pdir, pattern=paste0("^", stub, "_p.*\\.csv$"), full.names=TRUE)
    if (length(parts)) {
      merged <- parts |> map(~ suppressMessages(read_csv(.x, show_col_types=FALSE))) |> bind_rows()
      write_csv(merged, file.path(output_dir, paste0(stub, ".csv")))
      cli::cli_alert_success("merged {length(parts)} parts -> {stub}.csv ({nrow(merged)} rows)")
    } else cli::cli_alert_danger("no parts for {stub}")
  }
}

# ── reconcile ────────────────────────────────────────────────────────────────
have <- sort(unique(as.integer(str_extract(list.files(output_dir, pattern="\\.csv$"), "^[0-9]+"))))
missing <- setdiff(seq_along(countries), have)
if (length(missing)==0) {
  cli::cli_alert_success("All {length(countries)} countries present.")
} else {
  cli::cli_alert_danger("Missing {length(missing)}: {paste(sprintf('%03d',missing), collapse=', ')}")
}
cli::cli_h1("DONE")
