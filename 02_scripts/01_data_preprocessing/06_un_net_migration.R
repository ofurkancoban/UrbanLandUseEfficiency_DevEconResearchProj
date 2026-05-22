# ============================================================================
# 23_un_net_migration.R
# Net migration from UN DESA World Population Prospects 2024 (Crude rate of net
# migration, CNMR, per 1,000) -> net_migr_pct = CNMR/10 (% of population).
# Replaces the WDI net-migration control. Source: WPP2024 Demographic Indicators.
# Output: 03_datasets/raw/un_net_migration.csv  (iso3, year, net_migr_pct)
# ============================================================================
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
