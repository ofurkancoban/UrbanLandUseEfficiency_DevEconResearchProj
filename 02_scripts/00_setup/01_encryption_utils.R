# ==============================================================================
# File:          01_encryption_utils.R
# Project:       Measuring Sustainable Urbanization in Turkey: An Empirical 
#                Evaluation of the Land Consumption to Population Growth Ratio
# Author:        Ömer Furkan Çoban
# 
# University:    Carl von Ossietzky University of Oldenburg
# Department:    Applied Economics and Data Science
# Course:        Development Economics
# Semester:      SoSe 26
# Lecturers:     Prof. Dr. Jürgen Bitzer
#
# Category:      Security & Utilities
# Description:   Provides helper functions for password-based symmetric 
#                encryption and safe secret loading into memory.
# ==============================================================================

library(cyphr)
library(sodium)

# Function to load and decrypt secrets into environment
load_secure_secrets <- function(password, encrypted_vault_path) {
  # Fall back to the user's own environment when the vault is absent (e.g. a
  # public clone): set any needed variables (such as GEE_PROJECT) yourself.
  if (!file.exists(encrypted_vault_path)) {
    message("ℹ No encrypted secrets vault (", basename(encrypted_vault_path),
            "); skipping. Set GEE_PROJECT (and any other env vars) yourself.")
    return(invisible(FALSE))
  }
  pw_raw <- sodium::sha256(charToRaw(password))
  key <- cyphr::key_sodium(pw_raw)
  
  # Read raw bytes
  file_size <- file.info(encrypted_vault_path)$size
  raw_vault <- readBin(encrypted_vault_path, "raw", n = file_size)
  
  # Direct decryption
  decrypted_data <- key$decrypt(raw_vault)
  
  # Parse and set env variables
  env_lines <- readLines(textConnection(rawToChar(decrypted_data)))
  for (line in env_lines) {
    # Skip empty lines and comments
    if (trimws(line) == "" || grepl("^#", trimws(line))) next
    
    if (grepl("=", line)) {
      parts <- strsplit(line, "=")[[1]]
      var_name <- trimws(parts[1])
      var_val <- trimws(paste(parts[-1], collapse = "="))
      
      # Use do.call to pass named arguments to Sys.setenv correctly
      if (var_name != "") {
        arg_list <- list(var_val)
        names(arg_list) <- var_name
        do.call(Sys.setenv, arg_list)
      }
    }
  }
  message("✔ Secrets successfully decrypted and loaded into memory.")
}

# Function to encrypt Google Drive OAuth token after first browser auth
save_encrypted_drive_token <- function(password, output_path) {
  token <- googledrive::drive_token()
  if (is.null(token)) stop("No active Drive token. Run drive_auth() first.")

  tmp <- tempfile(fileext = ".rds")
  saveRDS(token, tmp)
  on.exit(unlink(tmp))

  pw_raw    <- sodium::sha256(charToRaw(password))
  key       <- cyphr::key_sodium(pw_raw)
  file_size <- file.info(tmp)$size
  raw_token <- readBin(tmp, "raw", n = file_size)
  encrypted <- key$encrypt(raw_token)

  writeBin(encrypted, output_path)
  message("✔ Drive token encrypted and saved: ", output_path)
}

# Function to load encrypted Drive token (no browser needed)
load_drive_token <- function(password, encrypted_token_path) {
  # Fall back to interactive Google Drive login (the reproducer's OWN account)
  # when no encrypted token is shipped.
  if (!file.exists(encrypted_token_path)) {
    message("ℹ No encrypted Drive token (", basename(encrypted_token_path),
            "); using interactive Google Drive login (your own account).")
    googledrive::drive_auth()
    return(invisible(FALSE))
  }

  pw_raw    <- sodium::sha256(charToRaw(password))
  key       <- cyphr::key_sodium(pw_raw)
  file_size <- file.info(encrypted_token_path)$size
  raw_enc   <- readBin(encrypted_token_path, "raw", n = file_size)
  decrypted <- key$decrypt(raw_enc)

  tmp <- tempfile(fileext = ".rds")
  writeBin(decrypted, tmp)
  on.exit(unlink(tmp))

  token <- readRDS(tmp)
  # Non-interactive (server / PM2) robustness: the stored OAuth access token may
  # have expired. Refresh it with the embedded refresh token, and disable any
  # interactive fallback so a stale token fails loudly instead of opening a browser.
  options(gargle_oauth_email = TRUE, rlang_interactive = FALSE)
  try(token$refresh(), silent = TRUE)
  googledrive::drive_deauth()
  googledrive::drive_auth(token = token)
  message("✔ Drive token loaded from encrypted vault.")
}

# Function to encrypt EE personal OAuth credentials (run once interactively)
save_encrypted_ee_credentials <- function(password, output_path) {
  ee_creds_path <- path.expand("~/.config/earthengine/credentials")
  if (!file.exists(ee_creds_path)) {
    stop("EE credentials not found. Run ee$Authenticate() or 'earthengine authenticate' first.")
  }
  pw_raw    <- sodium::sha256(charToRaw(password))
  key       <- cyphr::key_sodium(pw_raw)
  file_size <- file.info(ee_creds_path)$size
  raw_creds <- readBin(ee_creds_path, "raw", n = file_size)
  encrypted <- key$encrypt(raw_creds)
  writeBin(encrypted, output_path)
  message("✔ EE credentials encrypted and saved: ", output_path)
}

# Function to restore EE credentials headlessly (no browser needed)
load_ee_credentials <- function(password, encrypted_creds_path) {
  # Fall back to the reproducer's OWN Earth Engine login when none is shipped.
  if (!file.exists(encrypted_creds_path)) {
    message("ℹ No encrypted EE credentials (", basename(encrypted_creds_path),
            "); using your own Earth Engine login. Run `earthengine authenticate` ",
            "(or ee$Authenticate() in Python) once if you have not already.")
    return(invisible(FALSE))
  }
  pw_raw    <- sodium::sha256(charToRaw(password))
  key       <- cyphr::key_sodium(pw_raw)
  file_size <- file.info(encrypted_creds_path)$size
  raw_enc   <- readBin(encrypted_creds_path, "raw", n = file_size)
  decrypted <- key$decrypt(raw_enc)
  ee_dir    <- path.expand("~/.config/earthengine/")
  if (!dir.exists(ee_dir)) dir.create(ee_dir, recursive = TRUE)
  writeBin(decrypted, file.path(ee_dir, "credentials"))
  message("✔ EE credentials restored from vault.")
}

# Function to decrypt GEE Key to a temporary file
get_decrypted_gee_key <- function(password, encrypted_key_path) {
  if (!file.exists(encrypted_key_path)) {
    message("ℹ No encrypted GEE service-account key; using your own EE auth instead.")
    return(NULL)
  }
  pw_raw <- sodium::sha256(charToRaw(password))
  key <- cyphr::key_sodium(pw_raw)
  
  # Read raw bytes
  file_size <- file.info(encrypted_key_path)$size
  raw_key <- readBin(encrypted_key_path, "raw", n = file_size)
  
  # Direct decryption
  decrypted_bytes <- key$decrypt(raw_key)
  
  # Create a secure temporary file
  temp_key <- tempfile(fileext = ".json")
  writeBin(decrypted_bytes, temp_key)
  
  return(temp_key)
}
