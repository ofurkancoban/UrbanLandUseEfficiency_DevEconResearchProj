# ==============================================================================
# GADM 4.1 → GEE Asset Upload
# ==============================================================================
# Downloads GADM 4.1 level-1 administrative boundaries, extracts the ADM_1
# layer, and uploads it to Google Earth Engine as a project asset.
#
# Run this script ONCE before using 01_data_collection_batch.R with GADM.
#
# Prerequisites:
#   - earthengine CLI authenticated: earthengine authenticate
#   - R packages: sf, here
# ==============================================================================

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

library(sf)
library(cli)

ee <- reticulate::import("ee")
ee$Initialize(project = Sys.getenv("GEE_PROJECT"))

gee_project  <- Sys.getenv("GEE_PROJECT")
asset_id     <- paste0("projects/", gee_project, "/assets/GADM_level1")
work_dir     <- file.path(project_root, "03_datasets/raw/GADM")
gpkg_zip     <- file.path(work_dir, "gadm_410-levels.zip")
gpkg_file    <- file.path(work_dir, "gadm_410-levels.gpkg")
out_gpkg     <- file.path(work_dir, "GADM_level1.gpkg")

if (!dir.exists(work_dir)) dir.create(work_dir, recursive = TRUE)

# 1. DOWNLOAD -------------------------------------------------------------------
cli::cli_h1("Step 1: Downloading GADM 4.1 layered GeoPackage")

gadm_url <- "https://geodata.ucdavis.edu/gadm/gadm4.1/gadm_410-levels.zip"

if (!file.exists(gpkg_zip)) {
  cli::cli_alert_info("Downloading (~2.5 GB) with resume support...")

  # Use curl for resume capability (-C -) and no timeout limit
  exit_code <- system2(
    "curl",
    args = c(
      "-L",           # follow redirects
      "-C", "-",      # resume if interrupted
      "--retry", "5",
      "--retry-delay", "10",
      "-o", shQuote(gpkg_zip),
      gadm_url
    )
  )

  if (exit_code != 0) stop("Download failed (exit code ", exit_code, ")")
  cli::cli_alert_success("Download complete.")
} else {
  cli::cli_alert_info("Archive already exists, skipping download.")
}

# 2. EXTRACT --------------------------------------------------------------------
cli::cli_h1("Step 2: Extracting GeoPackage")

if (!file.exists(gpkg_file)) {
  cli::cli_alert_info("Unzipping...")
  unzip(gpkg_zip, exdir = work_dir)
  cli::cli_alert_success("Extracted.")
} else {
  cli::cli_alert_info("GeoPackage already extracted, skipping.")
}

# 3. READ ADM_1 LAYER -----------------------------------------------------------
cli::cli_h1("Step 3: Reading ADM_1 layer from GeoPackage")

if (file.exists(out_gpkg)) {
  cli::cli_alert_info("Output GeoPackage already exists, skipping read.")
  adm1 <- NULL
} else {
  cli::cli_alert_info("Available layers:")
  layers <- st_layers(gpkg_file)
  print(layers$name)

  cli::cli_alert_info("Reading ADM_1 (this may take a few minutes)...")
  adm1 <- st_read(gpkg_file, layer = "ADM_1", quiet = TRUE)
  cli::cli_alert_success(
    "Loaded {nrow(adm1)} ADM1 features, {ncol(adm1)} fields."
  )
  cli::cli_alert_info(
    "Key fields: {paste(intersect(names(adm1),
      c('GID_0','NAME_0','GID_1','NAME_1')), collapse=', ')}"
  )
}

# 4. WRITE GEOPACKAGE ----------------------------------------------------------
cli::cli_h1("Step 4: Writing GeoPackage (simplified, UTF-8 safe)")

gpkg_just_written <- FALSE
if (file.exists(out_gpkg)) {
  cli::cli_alert_info("GeoPackage already exists, skipping write.")
} else {
  # Simplify to stay under GEE's 1M-vertex-per-feature limit.
  # S2 must be disabled: st_simplify can produce Cartesian-valid but
  # spherically-invalid geometries that S2 rejects.
  # Very small countries (MCO, MDV, KIR) disappear even at 0.001 deg;
  # keep their original geometries and simplify only the rest.
  tiny_iso <- c("MCO", "MDV", "KIR")
  adm1_tiny  <- adm1[adm1$GID_0 %in% tiny_iso, ]
  adm1_large <- adm1[!adm1$GID_0 %in% tiny_iso, ]

  cli::cli_alert_info(
    "Simplifying {nrow(adm1_large)} features (dTolerance = 0.01)..."
  )
  sf::sf_use_s2(FALSE)
  adm1_large <- sf::st_simplify(
    adm1_large, preserveTopology = TRUE, dTolerance = 0.01
  )
  sf::sf_use_s2(TRUE)

  adm1 <- rbind(adm1_large, adm1_tiny)
  cli::cli_alert_success(
    "Simplified. Kept {nrow(adm1_tiny)} tiny countries unsimplified."
  )
  st_write(adm1, out_gpkg, layer = "ADM_1", quiet = TRUE)
  cli::cli_alert_success("GeoPackage written: {out_gpkg}")
  gpkg_just_written <- TRUE
}

# 5. UPLOAD TO GEE -------------------------------------------------------------
cli::cli_h1("Step 5: Uploading to GEE")

asset_check <- system2(
  "earthengine",
  args   = c("asset", "info", asset_id),
  stdout = TRUE,
  stderr = TRUE
)

if (any(grepl("Found asset", asset_check))) {
  cli::cli_alert_warning("Asset already exists: {asset_id}")
  cli::cli_alert_info(
    "Delete with: earthengine rm {asset_id}"
  )
} else {
  # Upload to Google Drive, then ingest into GEE from Drive
  library(googledrive)
  load_drive_token(
    my_password,
    file.path(project_root, "03_datasets/config/drive_token.enc")
  )

  cli::cli_alert_info(
    "Step 5a: Checking Google Drive for GADM_level1.gpkg..."
  )
  existing_drive <- drive_find(pattern = "GADM_level1\\.gpkg")

  if (nrow(existing_drive) > 0 && !gpkg_just_written) {
    drive_id <- existing_drive$id[1]
    cli::cli_alert_success(
      "Found existing Drive file (id: {drive_id}), skipping upload."
    )
  } else {
    if (gpkg_just_written && nrow(existing_drive) > 0) {
      cli::cli_alert_info(
        "GPKG was re-generated — deleting old Drive file first..."
      )
      drive_rm(as_id(existing_drive$id[1]))
    }
    cli::cli_alert_info("Uploading simplified GPKG to Google Drive...")
    drive_file <- drive_upload(
      media = out_gpkg,
      name  = "GADM_level1.gpkg",
      overwrite = FALSE
    )
    drive_id <- drive_file$id
    cli::cli_alert_success("Uploaded to Drive (id: {drive_id})")
  }

  # GEE ingestion requires a gs:// URI — Drive URLs are not accepted.
  # Manual upload instructions:
  cli::cli_alert_warning(
    "Step 5b: GEE startTableIngestion only accepts gs:// URIs."
  )
  cli::cli_alert_info("Manual upload option A — GEE Code Editor UI:")
  cli::cli_alert_info(
    "  1. Open https://code.earthengine.google.com"
  )
  cli::cli_alert_info("  2. Assets → New → Table upload")
  cli::cli_alert_info(
    "  3. Select file: {out_gpkg}"
  )
  cli::cli_alert_info(
    "  4. Asset ID: {asset_id}"
  )
  cli::cli_alert_info("")
  cli::cli_alert_info(
    "Manual upload option B — gcloud CLI (if installed):"
  )
  cli::cli_alert_info(
    "  gsutil cp {out_gpkg} gs://YOUR_BUCKET/GADM_level1.gpkg"
  )
  cli::cli_alert_info(
    paste0(
      "  earthengine upload table ",
      "--asset_id=", asset_id,
      " gs://YOUR_BUCKET/GADM_level1.gpkg"
    )
  )
}

# 6. DONE ----------------------------------------------------------------------
cli::cli_h1("Done!")
cli::cli_alert_success(
  "Use this asset ID in 01_data_collection_batch.R:"
)
cli::cli_alert_info(
  '  admin_asset <- ee$FeatureCollection("{asset_id}")'
)
cli::cli_alert_info(
  '  Filter by: ee$Filter$eq("GID_0", iso)  # ISO3 code'
)
