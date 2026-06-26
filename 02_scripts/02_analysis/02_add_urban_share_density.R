# ==============================================================================
# File:          02_add_urban_share_density.R
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
# Category:      Data Analysis
# Description:   Adds urban population share and urban density controls to the 
#                country-level panel data.
# ==============================================================================
suppressMessages({library(tidyverse)})
setwd(here::here())

# total population (whole territory GHS-POP) per (iso3, year) from full files
read_pop <- function(f){ d <- suppressWarnings(suppressMessages(readr::read_csv(f, show_col_types=FALSE)))
  pc <- grep("_Pop_GHSL_", names(d), value=TRUE); if(!length(pc)||!"iso3_code"%in%names(d)) return(NULL)
  d |> select(iso3=iso3_code, all_of(pc)) |> pivot_longer(-iso3, names_to="k", values_to="pop") |>
    mutate(year=as.integer(str_extract(k,"^[0-9]{4}"))) |> select(-k) }
fullf <- list.files("03_datasets/raw/Zonal_Stats_Global_GAUL2024", pattern="\\.csv$", full.names=TRUE)
totpop <- map_dfr(fullf, read_pop) |> filter(!is.na(pop)) |>
  group_by(iso3, year) |> summarise(total_pop = sum(pop, na.rm=TRUE), .groups="drop")
cat("total-pop rows:", nrow(totpop), "| countries:", n_distinct(totpop$iso3), "\n")

panel <- suppressMessages(read_csv("03_datasets/processed/reg_panel_urban.csv", show_col_types=FALSE))
panel <- panel |> select(-any_of(c("total_pop","urban_pop_share","urban_area_km2","urban_density","ln_urban_density")))
panel <- panel |> left_join(totpop, by=c("iso3","year")) |>
  mutate(urban_pop_share = if_else(total_pop > 0, pop_urban/total_pop, NA_real_))

ua_path <- "03_datasets/raw/smod_urban_area_national.csv"
if (file.exists(ua_path)) {
  # GAUL_2024_L0 has multiple features for some iso3 (multi-part countries) -> the
  # GEE export returns several rows per (iso3, year); SUM them to the country total.
  ua <- suppressMessages(read_csv(ua_path, show_col_types=FALSE)) |>
    group_by(iso3, year) |> summarise(urban_area_km2 = sum(urban_area_km2, na.rm=TRUE), .groups="drop")
  panel <- panel |> left_join(ua, by=c("iso3","year")) |>
    mutate(urban_density = if_else(urban_area_km2 > 0, pop_urban/urban_area_km2, NA_real_),
           ln_urban_density = log(urban_density))
  cat("urban_area merged:", sum(!is.na(panel$urban_density)), "rows with density\n")
} else cat("NOTE: urban_area file not found yet -> density skipped (urban_pop_share added)\n")

write_csv(panel, "03_datasets/processed/reg_panel_urban.csv")
cat("\nUpdated reg_panel_urban.csv | cols:", ncol(panel), "\n")
cat("urban_pop_share summary (1990-2020):\n"); print(summary(panel$urban_pop_share[panel$year>=1990 & panel$year<=2020]))
if ("urban_density" %in% names(panel)) { cat("urban_density (people/km² urban) summary:\n")
  print(summary(panel$urban_density[panel$year>=1990 & panel$year<=2020])) }
