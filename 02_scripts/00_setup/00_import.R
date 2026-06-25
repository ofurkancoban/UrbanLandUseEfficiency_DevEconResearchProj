# ==============================================================================
# File:          00_import.R
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
# Category:      Environment Setup
# Description:   Manages all R and Python dependencies. Automatically detects
#                missing Python environments and configures GEE API.
# ==============================================================================

if (!requireNamespace("here", quietly = TRUE)) {
  install.packages("here", repos = "https://cloud.r-project.org")
}

# 1. LOAD PROJECT CONFIG FIRST
if (file.exists(here::here(".env"))) {
  readRenviron(here::here(".env"))
}

# 2. R PACKAGES
pkgs <- c(
  "reticulate", "sf", "dplyr", "tidyr", "readr",
  "geodata", "terra", "purrr", "geojsonsf", "cyphr",
  "sodium", "ggplot2", "viridis", "gridExtra", "zoo",
  # modelling + reporting (country GMM and the German Kreis supplementary)
  "fixest", "plm", "kableExtra", "knitr"
)

missing_pkgs <- pkgs[!(pkgs %in% installed.packages()[, "Package"])]
if (length(missing_pkgs) > 0) {
  message("→ Installing missing R dependencies: ", paste(missing_pkgs, collapse = ", "))
  install.packages(missing_pkgs, repos = "https://cloud.r-project.org")
}

# inkaR (German INKAR regional indicators, used by the Kreis supplementary) is not
# on CRAN; it is published on the author's R-universe.
if (!("inkaR" %in% installed.packages()[, "Package"])) {
  message("→ Installing inkaR from R-universe ...")
  install.packages("inkaR",
    repos = c("https://ofurkancoban.r-universe.dev", "https://cloud.r-project.org"))
}

# 3. PYTHON & GEE API SETUP
library(reticulate)

# Strategy 1: Use Python path from .env if provided
py_path <- Sys.getenv("PYTHON_PATH")

if (py_path != "" && file.exists(py_path)) {
  cat("→ Using Python from .env path...\n")
  reticulate::use_python(py_path, required = TRUE)
} else {
  # Strategy 2: Use a dedicated environment (Conda or Virtualenv)
  env_name <- "gee_research_env"
  
  has_conda <- !is.null(tryCatch(reticulate::conda_binary(), error = function(e) NULL))
  
  if (has_conda) {
    if (!env_name %in% reticulate::conda_list()$name) {
      cat("→ Creating Conda environment...\n")
      reticulate::conda_create(env_name, packages = "python=3.10")
      reticulate::conda_install(env_name, "earthengine-api")
    }
    reticulate::use_condaenv(env_name, required = TRUE)
  } else {
    # Fallback to virtualenv if no conda
    if (!reticulate::virtualenv_exists(env_name)) {
      cat("→ Conda not found. Creating Virtualenv instead...\n")
      reticulate::virtualenv_create(env_name)
      reticulate::virtualenv_install(env_name, "earthengine-api")
    }
    reticulate::use_virtualenv(env_name, required = TRUE)
  }
}

# Final check for Earth Engine module
if (!reticulate::py_module_available("ee")) {
  cat("→ Earth Engine API missing. Attempting installation...\n")
  reticulate::py_install("earthengine-api")
}

message("✔ Environment Ready: ", here::here())
