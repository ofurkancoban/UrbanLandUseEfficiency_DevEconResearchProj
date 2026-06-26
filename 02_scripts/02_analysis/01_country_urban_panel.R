# ==============================================================================
# File:          01_country_urban_panel.R
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
# Description:   Assembles country-level SDG 11.3.1 panel data using GHSL components 
#                and UN controls (GDP, migration, region/development groups).
# ==============================================================================
suppressMessages({library(tidyverse)})
setwd(here::here())
indir <- "03_datasets/raw/Zonal_Stats_Urban_GAUL2024"

# ---- 1. read each file -> NATIONAL urban totals per (iso3, year) by COLUMN sums
#     (sum built and pop columns across ADM1 rows separately; no ADM1-level join,
#      which previously cross-multiplied units and inflated the level totals)
read_one <- function(f) {
  d <- suppressWarnings(suppressMessages(readr::read_csv(f, show_col_types = FALSE)))
  bcols <- grep("_Built_GHSL_", names(d), value = TRUE)
  pcols <- grep("_Pop_GHSL_",   names(d), value = TRUE)
  if (!length(bcols) || !length(pcols) || !"iso3_code" %in% names(d)) return(NULL)
  bl <- d |> summarise(across(all_of(bcols), ~sum(.x, na.rm=TRUE))) |>
    pivot_longer(everything(), names_to="k", values_to="U") |>
    transmute(year = as.integer(str_extract(k,"^[0-9]{4}")), U)
  pl <- d |> summarise(across(all_of(pcols), ~sum(.x, na.rm=TRUE))) |>
    pivot_longer(everything(), names_to="k", values_to="P") |>
    transmute(year = as.integer(str_extract(k,"^[0-9]{4}")), P)
  left_join(bl, pl, by="year") |> mutate(iso3 = d$iso3_code[1], n_adm1 = nrow(d))
}
files <- list.files(indir, pattern="\\.csv$", full.names=TRUE)
nat <- map_dfr(files, read_one) |> filter(!is.na(U), !is.na(P), U >= 0, P >= 0)
cat("national urban rows:", nrow(nat), "| countries:", n_distinct(nat$iso3), "\n")

# ---- 2. aggregate-then-compute: period indicators per country -----------------
ind <- nat |>
  arrange(iso3, year) |>
  group_by(iso3) |>
  mutate(z = year - lag(year), U_lag = lag(U), P_lag = lag(P),
         year_start = lag(year), period = paste0(lag(year), "-", year)) |>
  ungroup() |>
  filter(!is.na(z), U_lag > 0, P_lag > 0, P > 0) |>
  mutate(
    lcr_log      = log(U / U_lag) / z,
    pgr_log      = log(P / P_lag) / z,
    lcrpgr_log   = if_else(pgr_log != 0, lcr_log / pgr_log, NA_real_),
    lcr          = (U - U_lag) / U_lag / z,                 # metadata arithmetic LCR
    lcrpgr       = if_else(pgr_log != 0, lcr / pgr_log, NA_real_),   # official LCRPGR
    total_change = (U - U_lag) / U_lag,
    bup          = U / P,
    bup_lag      = U_lag / P_lag,
    bpcr         = log(bup / bup_lag) / z,
    lue_status   = case_when(is.na(lcrpgr_log) ~ NA_integer_,
                             lcrpgr_log > 0 & lcrpgr_log <= 1 ~ 1L, TRUE ~ 0L)
  ) |>
  rename(built_urban_m2 = U, pop_urban = P) |>
  select(iso3, period, year, year_start, z, built_urban_m2, pop_urban, n_adm1,
         lcr, lcr_log, pgr_log, lcrpgr, lcrpgr_log, total_change, bup, bpcr, lue_status)

# ---- 3. country name (derived from ISO3; no external control panel needed) ----
suppressMessages(library(countrycode))
panel <- ind |>
  mutate(country_name = countrycode(iso3, "iso3c", "country.name")) |>
  relocate(country_name, .after = iso3)

# ---- 3b. GDP per capita: UN SNAAMA (constant 2020 US$), all 193 states --------
# See 01_data_preprocessing/un_gdp_per_capita.R for the source pull.
un_gdp <- suppressMessages(read_csv("03_datasets/raw/un_gdp_per_capita.csv", show_col_types = FALSE)) |>
  transmute(iso3, year, ln_gdp_pc = log(gdp_pc_un))
panel <- panel |> left_join(un_gdp, by = c("iso3","year"))

# ---- 3c. Net migration: UN DESA WPP 2024 (CNMR/10) ----------------------------
# See 01_data_preprocessing/un_net_migration.R for the source pull.
un_mig <- suppressMessages(read_csv("03_datasets/raw/un_net_migration.csv", show_col_types = FALSE)) |>
  transmute(iso3, year, net_migr_pct)
panel <- panel |> left_join(un_mig, by = c("iso3","year"))

# ---- 3d. UN classifications: region (M49) + development group ----------------
# region  = UN M49 region (continent). development = UN "more developed regions"
# (Europe + USA/CAN/JPN/AUS/NZL) vs Least Developed Countries (UN CDP list) vs
# Developing (the rest). Replaces the World Bank region & income-group columns.
suppressMessages(library(countrycode))
ldc <- c("AFG","AGO","BGD","BEN","BFA","BDI","KHM","CAF","TCD","COM","COD","DJI",
         "ERI","ETH","GMB","GIN","GNB","HTI","KIR","LAO","LSO","LBR","MDG","MWI",
         "MLI","MRT","MOZ","MMR","NPL","NER","RWA","SEN","SLE","SLB","SOM","SSD",
         "SDN","TLS","TGO","TUV","UGA","TZA","YEM","ZMB")
panel <- panel |>
  mutate(
    region = countrycode(iso3, "iso3c", "un.region.name"),
    income_group = case_when(
      iso3 %in% ldc ~ "LDC",
      region == "Europe" | iso3 %in% c("USA","CAN","JPN","AUS","NZL") ~ "Developed",
      TRUE ~ "Developing")
  )

out <- "03_datasets/processed/reg_panel_urban.csv"
write_csv(panel, out)
cat(sprintf("\nWrote %s\n  rows: %d | countries: %d | periods: %s\n",
            out, nrow(panel), n_distinct(panel$iso3), paste(sort(unique(panel$period)), collapse=", ")))

# ---- 4. quick sanity: urban vs whole-territory bpcr (estimation range) --------
cat("\nBpCR (urban) summary, 1990-2020:\n")
print(summary(panel$bpcr[panel$year >= 1995 & panel$year <= 2020]))
cat("\nLCRPGR(log) urban range (instability):",
    paste(round(range(panel$lcrpgr_log, na.rm=TRUE),1), collapse=" .. "), "\n")
cat("rows with non-NA ln_gdp_pc:", sum(!is.na(panel$ln_gdp_pc)), "\n")
