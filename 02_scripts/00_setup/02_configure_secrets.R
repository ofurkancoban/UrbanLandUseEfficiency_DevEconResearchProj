# ==============================================================================
# File:          02_configure_secrets.R
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
# Category:      Security Setup
# Description:   One-time setup script to encrypt the GEE Service Account JSON
#                and .env file into the project's secure vault.
# ==============================================================================

source(here::here("02_scripts/00_setup/00_import.R"))
library(cyphr)
library(sodium)

# 1. DEFINE PASSWORD (User Input required once)
my_password <- "OmerFurkanCoban"
key <- cyphr::key_sodium(sodium::sha256(charToRaw(my_password)))

# 2. ENCRYPT .env FILE
if (file.exists(here::here(".env"))) {
  env_raw <- readBin(here::here(".env"), "raw", file.info(here::here(".env"))$size)
  writeBin(key$encrypt(env_raw), here::here("03_datasets/config/secrets.enc"))
  message("✔ .env file encrypted to 03_datasets/config/secrets.enc")
}

# 3. ENCRYPT GEE JSON KEY
gee_json_path <- here::here("ee-turkey-research-43d9ea16a1ec.json")
if (file.exists(gee_json_path)) {
  gee_raw <- readBin(gee_json_path, "raw", file.info(gee_json_path)$size)
  writeBin(key$encrypt(gee_raw), here::here("03_datasets/config/gee_key.enc"))
  message("✔ GEE JSON Key encrypted to 03_datasets/config/gee_key.enc")
}

# 4. ENCRYPT GOOGLE DRIVE OAUTH TOKEN
# Opens browser once for consent — token is then cached and encrypted.
library(googledrive)
source(here::here("02_scripts/00_setup/01_encryption_utils.R"))

drive_token_path <- here::here("03_datasets/config/drive_token.enc")
if (!file.exists(drive_token_path)) {
  message("→ Opening browser for Google Drive authentication (one-time only)...")
  googledrive::drive_auth(email = "f.coban93@gmail.com")
  save_encrypted_drive_token(my_password, drive_token_path)
} else {
  message("✔ Drive token already encrypted — skipping.")
}

cat("\nSECURITY NOTICE: You can now safely delete the original .env and .json files.\n")
