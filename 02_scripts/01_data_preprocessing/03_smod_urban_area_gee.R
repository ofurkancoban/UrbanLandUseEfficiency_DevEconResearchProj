# ============================================================================
# 14_smod_urban_area_gee.R
# National URBAN AREA (km²) from GHS-SMOD (DEGURBA urban = SMOD >= 21), per
# country per year, for urban density (= urban population / urban area).
# Single server-side Export.table.toDrive task (no getInfo timeout), then
# download + parse. Years 1975-2020.
# Output: 03_datasets/raw/smod_urban_area_national.csv  (iso3, year, urban_area_km2)
# ============================================================================
suppressMessages({library(tidyverse); library(cli)})
pr <- here::here(); setwd(pr)
source(file.path(pr,"02_scripts/00_setup/01_encryption_utils.R")); my_password <- "OmerFurkanCoban"
load_secure_secrets(my_password, file.path(pr,"03_datasets/config/secrets.enc"))
load_ee_credentials(my_password, file.path(pr,"03_datasets/config/ee_credentials.enc"))
ee <- reticulate::import("ee"); ee$Initialize(project = Sys.getenv("GEE_PROJECT"))

years <- seq(1975, 2020, by = 5); URBAN_MIN <- 21L
smod  <- ee$ImageCollection("JRC/GHSL/P2023A/GHS_SMOD")
panel_iso <- suppressMessages(read_csv("03_datasets/config/un_member_iso3.csv", show_col_types=FALSE))
iso3_193  <- sort(unique(na.omit(panel_iso$iso3)))
adm0 <- ee$FeatureCollection("projects/sat-io/open-datasets/FAO/GAUL/GAUL_2024_L0")$
  filter(ee$Filter$inList("iso3_code", iso3_193))

imgs <- lapply(years, function(yr){
  s <- ee$Image(smod$filterDate(paste0(yr,"-01-01"), paste0(yr,"-12-31"))$first())$select("smod_code")
  ee$Image$pixelArea()$updateMask(s$gte(URBAN_MIN))$rename(paste0("ua_", yr)) })
img <- imgs[[1]]; for (k in 2:length(imgs)) img <- img$addBands(imgs[[k]])

fc <- img$reduceRegions(collection = adm0, reducer = ee$Reducer$sum(), scale = 1000, tileScale = 8)$
  map(function(f) f$setGeometry(NULL))                       # drop geometry -> small payload
drive_folder <- "GEE_Urban_Area"
library(googledrive); load_drive_token(my_password, file.path(pr,"03_datasets/config/drive_token.enc"))

# Skip the GEE export if the result is already on Drive — download it directly.
hit <- tryCatch(googledrive::drive_find(pattern = "urban_area_national", type = "csv", n_max = 50),
                error = function(e) tibble())
if (nrow(hit) == 0) {
  task <- ee$batch$Export$table$toDrive(collection = fc, description = "urban_area_national",
            folder = drive_folder, fileNamePrefix = "urban_area_national", fileFormat = "CSV")
  task$start(); cli::cli_alert_success("export task started")
  repeat { Sys.sleep(30); s <- tryCatch(task$status()$state, error=function(e) "UNKNOWN")
    cli::cli_alert_info("task: {s}"); if (s %in% c("COMPLETED","FAILED","CANCELLED")) break }
  hit <- googledrive::drive_find(pattern = "urban_area_national", type = "csv", n_max = 50)
  if (nrow(hit) == 0) stop("export not found on Drive yet; re-run download later")
} else {
  cli::cli_alert_info("Found existing export on Drive — skipping GEE, downloading directly")
}
lp <- file.path(pr, "03_datasets/raw/urban_area_national_raw.csv")
googledrive::drive_download(googledrive::as_id(hit$id[1]), path = lp, overwrite = TRUE)

raw <- suppressMessages(read_csv(lp, show_col_types = FALSE))
ua  <- raw |> select(iso3 = iso3_code, matches("^ua_[0-9]{4}$")) |>
  pivot_longer(-iso3, names_to = "k", values_to = "urban_area_m2") |>
  mutate(year = as.integer(str_remove(k, "ua_")), urban_area_km2 = urban_area_m2/1e6) |>
  select(iso3, year, urban_area_km2) |> filter(!is.na(urban_area_km2))
write_csv(ua, "03_datasets/raw/smod_urban_area_national.csv")
cli::cli_alert_success("smod_urban_area_national.csv: {nrow(ua)} rows | {n_distinct(ua$iso3)} countries")
