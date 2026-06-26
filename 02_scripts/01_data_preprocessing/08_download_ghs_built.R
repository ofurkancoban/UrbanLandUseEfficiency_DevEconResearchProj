# ==============================================================================
# File:          08_download_ghs_built.R
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
# Description:   Downloads the GHS-BUILT-S (built-up surface) global raster, 
#                R2023A, 1 km, epoch 2020, from JRC GHSL open-data server.
# ==============================================================================
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
