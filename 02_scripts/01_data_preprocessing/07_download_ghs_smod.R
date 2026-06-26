# ==============================================================================
# File:          07_download_ghs_smod.R
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
# Description:   Downloads the GHS-SMOD (Degree of Urbanisation) global raster, 
#                R2023A, 1 km, epoch 2020, from the JRC GHSL open-data server.
# ==============================================================================
suppressMessages(library(here))
setwd(here::here())

base <- "GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0"
out_dir <- here("03_datasets/raw", base)
tif     <- file.path(out_dir, paste0(base, ".tif"))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

if (file.exists(tif)) {
  message("GHS-SMOD raster already present: ", tif)
} else {
  url <- paste0("https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/",
                "GHS_SMOD_GLOBE_R2023A/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000/",
                "V2-0/", base, ".zip")
  zip <- tempfile(fileext = ".zip")
  message("Downloading GHS-SMOD R2023A 1km (~34 MB) from JRC GHSL ...")
  old <- options(timeout = 600); on.exit(options(old), add = TRUE)
  utils::download.file(url, zip, mode = "wb", method = "libcurl", quiet = FALSE)
  utils::unzip(zip, exdir = out_dir); unlink(zip)
  if (!file.exists(tif)) {
    got <- list.files(out_dir, pattern = "\\.tif$", full.names = TRUE)
    if (!length(got)) stop("GHS-SMOD zip produced no .tif in ", out_dir)
    if (basename(got[1]) != basename(tif)) file.rename(got[1], tif)
  }
  message("Saved: ", tif)
}
