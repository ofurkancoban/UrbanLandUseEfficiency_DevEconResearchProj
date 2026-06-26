# ==============================================================================
# File:          06_un_net_migration.R
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
# Description:   Downloads and processes net migration rates from UN DESA World 
#                Population Prospects 2024.
# ==============================================================================
suppressMessages({library(tidyverse)})
setwd(here::here())

gz <- "03_datasets/raw/WPP2024_Demographic_Indicators_Medium.csv.gz"
if (!file.exists(gz)) {
  download.file(
    "https://population.un.org/wpp/assets/Excel%20Files/1_Indicator%20(Standard)/CSV_FILES/WPP2024_Demographic_Indicators_Medium.csv.gz",
    gz, mode = "wb", quiet = TRUE)
}

wpp <- read_csv(gzfile(gz), show_col_types = FALSE) |>
  filter(LocTypeName == "Country/Area", Time >= 1980, Time <= 2020, !is.na(CNMR)) |>
  transmute(iso3 = ISO3_code, year = as.integer(Time), net_migr_pct = CNMR / 10) |>
  filter(!is.na(iso3))

write_csv(wpp, "03_datasets/raw/un_net_migration.csv")
cat("wrote un_net_migration.csv | countries:", n_distinct(wpp$iso3),
    "| years:", paste(range(wpp$year), collapse = "-"), "| rows:", nrow(wpp), "\n")
