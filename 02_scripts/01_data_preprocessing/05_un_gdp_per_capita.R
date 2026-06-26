# ==============================================================================
# File:          05_un_gdp_per_capita.R
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
# Description:   Downloads and processes UN SNAAMA Per Capita GDP at constant 2020 
#                prices in US Dollars for all countries.
# ==============================================================================
suppressMessages({library(tidyverse); library(readxl); library(countrycode)})
setwd(here::here())

xlsx <- "03_datasets/raw/UN_GDPpc_constant2020_USD.xlsx"
if (!file.exists(xlsx)) {
  download.file("https://unstats.un.org/unsd/amaapi/api/file/12", xlsx, mode = "wb", quiet = TRUE)
}

raw  <- read_excel(xlsx, sheet = 1, col_names = FALSE)
hrow <- which(raw[[1]] == "CountryID")[1]
hdr  <- as.character(unlist(raw[hrow, ])); hdr[is.na(hdr)] <- paste0("x", which(is.na(hdr)))
names(raw) <- make.unique(hdr)
un <- raw[(hrow + 1):nrow(raw), ]
ycols <- names(un)[suppressWarnings(!is.na(as.numeric(names(un))))]

un_gdp <- un |>
  select(CountryID, all_of(ycols)) |>
  pivot_longer(-CountryID, names_to = "year", values_to = "gdp_pc_un") |>
  mutate(year = as.integer(as.numeric(year)),
         gdp_pc_un = as.numeric(gdp_pc_un),
         CountryID = as.integer(CountryID),
         iso3 = suppressWarnings(countrycode(CountryID, "iso3n", "iso3c")))
un_gdp$iso3[un_gdp$CountryID == 835] <- "TZA"   # "U.R. of Tanzania: Mainland" -> TZA
un_gdp <- un_gdp |> filter(!is.na(iso3), is.finite(gdp_pc_un), gdp_pc_un > 0) |>
  select(iso3, year, gdp_pc_un)

write_csv(un_gdp, "03_datasets/raw/un_gdp_per_capita.csv")
cat("wrote un_gdp_per_capita.csv | countries:", n_distinct(un_gdp$iso3),
    "| years:", paste(range(un_gdp$year), collapse = "-"),
    "| DPRK:", any(un_gdp$iso3 == "PRK"), "| TZA:", any(un_gdp$iso3 == "TZA"), "\n")
