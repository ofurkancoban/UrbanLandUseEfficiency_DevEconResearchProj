# ============================================================================
# 08_download_ghs_built.R
# Download the GHS-BUILT-S (built-up surface) global raster, R2023A, 1 km, epoch
# 2020, from the JRC GHSL open-data FTP. Used with GHS-SMOD to draw the metadata
# layer-stack figure in the paper (Section 4). Fully reproducible.
# Output: 03_datasets/raw/GHS_BUILT_S_E2020_GLOBE_R2023A_54009_1000_V1_0/<...>.tif
# ============================================================================
suppressMessages(library(here)); setwd(here::here())
base <- "GHS_BUILT_S_E2020_GLOBE_R2023A_54009_1000_V1_0"
out_dir <- here("03_datasets/raw", base); tif <- file.path(out_dir, paste0(base, ".tif"))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
if (file.exists(tif)) { message("GHS-BUILT-S already present: ", tif) } else {
  url <- paste0("https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/",
                "GHS_BUILT_S_GLOBE_R2023A/GHS_BUILT_S_E2020_GLOBE_R2023A_54009_1000/V1-0/", base, ".zip")
  zip <- tempfile(fileext = ".zip"); old <- options(timeout = 900); on.exit(options(old), add = TRUE)
  message("Downloading GHS-BUILT-S R2023A 1km (~145 MB) ...")
  utils::download.file(url, zip, mode = "wb", method = "libcurl", quiet = TRUE)
  utils::unzip(zip, exdir = out_dir); unlink(zip)
  if (!file.exists(tif)) { got <- list.files(out_dir, pattern="\\.tif$", full.names=TRUE)
    if (!length(got)) stop("no .tif"); if (basename(got[1])!=basename(tif)) file.rename(got[1], tif) }
  message("Saved: ", tif)
}
