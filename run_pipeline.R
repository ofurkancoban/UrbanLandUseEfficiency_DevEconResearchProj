# ==============================================================================
# run_pipeline.R  —  Master pipeline for the SDG 11.3.1 / BpCR project
#
# Reproduces the full chain:  download data -> build panel -> figures -> render
# the presentation, paper, and supplementary. Each step is SKIPPED if its output already
# exists, so a fresh checkout (which ships the committed processed/ data) jumps
# straight to figures + render without re-downloading the raw GEE rasters.
#
# Usage:
#   Rscript run_pipeline.R              # run all steps, skipping done ones
#   Rscript run_pipeline.R --force      # re-run every step (ignore existing output)
#   Rscript run_pipeline.R --gee        # also run the Google Earth Engine steps
#                                        #   (needs credentials; see 00_setup)
#   Rscript run_pipeline.R --no-render  # stop before rendering presentation/paper
#
# NOTE: raw-rebuild steps (marked raw = TRUE) re-create the raw inputs — either
# GEE collections (need decrypted Earth Engine credentials, can take HOURS) or
# web downloads (GAUL 2025 boundaries, GHS-SMOD raster, UN GDP/migration). They
# are SKIPPED by default because the repo ships the processed panels + figures.
# Pass --gee to rebuild ALL raw inputs from their sources.
#
# ONE-TIME SETUP (not part of this orchestrator; run manually if needed):
#   02_scripts/00_setup/02_configure_secrets.R   -> writes encrypted *.enc creds
#   02_scripts/00_setup/03_upload_gadm_to_gee.R  -> uploads GADM as a GEE asset
#                                                    (prerequisite for --gee)
# Helper (auto-sourced by the GEE scripts, not a standalone step):
#   02_scripts/00_setup/01_encryption_utils.R    -> decrypts creds at runtime
# ==============================================================================

if (!requireNamespace("here", quietly = TRUE))
  install.packages("here", repos = "https://cloud.r-project.org")
library(here)
setwd(here::here())

args      <- commandArgs(trailingOnly = TRUE)
FORCE     <- "--force"     %in% args
RUN_GEE   <- "--gee"       %in% args
NO_RENDER <- "--no-render" %in% args

hr <- function(ch = "=") cat(strrep(ch, 78), "\n", sep = "")
hr(); cat("SDG 11.3.1 / BpCR  —  pipeline\n"); hr(); cat("\n")

# Ensure standard output directories exist (clean checkout, or folders deleted to
# test a from-scratch rebuild) so every step can write without failing.
for (d in c("03_datasets/processed", "03_datasets/raw",
            "04_outputs/figures", "04_outputs/tables"))
  dir.create(here::here(d), recursive = TRUE, showWarnings = FALSE)

# Pre-flight: committed mode needs the committed panel. If it is missing and the
# user did not ask to rebuild from sources, tell them how rather than crash later.
if (!RUN_GEE && !file.exists(here::here("03_datasets/processed/reg_panel_urban.csv"))) {
  cat("! Committed data (03_datasets/processed/) is missing and --gee was not set.\n",
      "  The default mode renders from committed data; it cannot rebuild it.\n",
      "  Run:  Rscript run_pipeline.R --gee     # rebuild raw -> processed -> render\n",
      "        (the 3 GEE steps need Earth Engine credentials; downloads do not)\n", sep = "")
  quit(status = 1)
}

# ------------------------------------------------------------------------------
# Pipeline definition.  Each task:
#   name   : human label
#   script : path relative to project root
#   verify : function() -> TRUE if output already exists (then skip); NULL = no gate
#   raw    : TRUE if it (re)builds a raw input (GEE collection or web download);
#            skipped unless --gee, because the repo ships processed/ + figures.
# Order encodes the dependency DAG.
# ------------------------------------------------------------------------------
ex  <- function(p) file.exists(here::here(p))   # output-exists helper
ncsv <- function(d) length(list.files(here::here(d), pattern = "\\.csv$"))
hascol <- function(p, col) ex(p) &&
  col %in% names(readr::read_csv(here::here(p), n_max = 0, show_col_types = FALSE))

tasks <- list(

  # ---- Phase 0: environment & credentials --------------------------------
  list(name = "Setup: packages & Python/Earth Engine",
       script = "02_scripts/00_setup/00_import.R",
       verify = NULL, raw = FALSE),   # always run; no output gate

  # ---- Phase 1: raw inputs — GEE collections + web downloads (--gee) -----
  list(name = "[GEE] Urban (DEGURBA/SMOD) zonal stats",
       script = "02_scripts/01_data_preprocessing/01_collect_urban_gee.R",
       verify = function() ncsv("03_datasets/raw/Zonal_Stats_Urban_GAUL2024") >= 190, raw = TRUE),
  list(name = "[GEE] Full-territory zonal stats (built-up + total population)",
       script = "02_scripts/01_data_preprocessing/02_collect_global_gee.R",
       # require ALL 193 so the runtime-failure fallback (e.g. Chile) actually runs;
       # re-runs are cheap because finished countries pre-download from Drive.
       verify = function() ncsv("03_datasets/raw/Zonal_Stats_Global_GAUL2024") >= 193, raw = TRUE),
  list(name = "[GEE] SMOD urban area (km2) per country",
       script = "02_scripts/01_data_preprocessing/03_smod_urban_area_gee.R",
       verify = function() ex("03_datasets/raw/smod_urban_area_national.csv"), raw = TRUE),
  list(name = "[download] GAUL 2025 L1 boundaries (FAO WFS)",
       script = "02_scripts/01_data_preprocessing/04_download_gaul2025.R",
       verify = function() ex("03_datasets/raw/GAUL_2025_L1/gaul_2025_l1.shp"), raw = TRUE),
  list(name = "[download] UN GDP per capita (constant 2020 US$)",
       script = "02_scripts/01_data_preprocessing/05_un_gdp_per_capita.R",
       verify = function() ex("03_datasets/raw/un_gdp_per_capita.csv"), raw = TRUE),
  list(name = "[download] UN net migration",
       script = "02_scripts/01_data_preprocessing/06_un_net_migration.R",
       verify = function() ex("03_datasets/raw/un_net_migration.csv"), raw = TRUE),
  list(name = "[download] GHS-SMOD raster (JRC, DEGURBA overlay)",
       script = "02_scripts/01_data_preprocessing/07_download_ghs_smod.R",
       verify = function() ex(file.path("03_datasets/raw",
                 "GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0",
                 "GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0.tif")), raw = TRUE),

  # ---- Phase 2: panel construction (the deck's data) ---------------------
  list(name = "Country urban panel (reg_panel_urban.csv)",
       script = "02_scripts/02_analysis/01_country_urban_panel.R",
       verify = function() ex("03_datasets/processed/reg_panel_urban.csv"), raw = FALSE),
  list(name = "Add urban share & density controls",
       script = "02_scripts/02_analysis/02_add_urban_share_density.R",
       verify = function() hascol("03_datasets/processed/reg_panel_urban.csv", "urban_pop_share"),
       raw = FALSE),   # mutates reg_panel_urban in place; gate = has the added column
  list(name = "Dynamic-panel GMM (Arellano-Bond + Blundell-Bond)",
       script = "02_scripts/02_analysis/03_dynamic_gmm.R",
       verify = function() ex("03_datasets/processed/dynamic_gmm.rds"), raw = FALSE),

  # ---- Supplementary: sub-national case study (Germany, Kreis level) -----
  # Pulls GHSL via GEE (cached in _deu_ghsl_raw.rds) + INKAR controls -> panel CSV.
  # raw = TRUE: skipped by default (repo ships the committed CSV); --gee rebuilds.
  list(name = "[GEE] Supplementary: German Kreis case-study panel",
       script = "02_scripts/02_analysis/09_deu_kreis_casestudy.R",
       verify = function() ex("03_datasets/processed/deu_kreis_casestudy.csv"), raw = TRUE),

  # ---- Phase 3: presentation figures (interactive HTML) ------------------
  list(name = "Figure: BpCR interactive map",
       script = "02_scripts/02_analysis/04_fig_bpcr_interactive.R",
       verify = function() ex("04_outputs/figures/bpcr_interactive.html"), raw = FALSE),
  list(name = "Figure: regional trend contrast",
       script = "02_scripts/02_analysis/05_fig_desc_trend_regional.R",
       verify = function() ex("04_outputs/figures/desc_trend_regional.html"), raw = FALSE),
  list(name = "Figure: data sources map",
       script = "02_scripts/02_analysis/06_fig_data_sources_map.R",
       verify = function() ex("04_outputs/figures/data_sources_map.html"), raw = FALSE)
)

# ------------------------------------------------------------------------------
# Execution loop
#   * STRICTLY SEQUENTIAL: source() is blocking, so step N+1 never starts until
#     step N has fully finished.
#   * AUTO-SKIP: any step whose output already exists is skipped (unless --force).
#   * STOP-ON-FAILURE: if a step errors, or finishes without producing its
#     declared output, the pipeline halts immediately (no downstream step runs
#     on incomplete inputs).
# ------------------------------------------------------------------------------
# done(v): TRUE if the step's output exists. verify = NULL means "no output gate"
# (always run, never auto-skip, no post-run check) -> treated as NOT done.
done <- function(v) !is.null(v) && isTRUE(try(v(), silent = TRUE))

for (i in seq_along(tasks)) {
  t <- tasks[[i]]
  cat(sprintf("\n--- [%d/%d] %s ---\n", i, length(tasks), t$name))

  if (isTRUE(t$raw) && !RUN_GEE) {
    cat("  - skipped (raw-rebuild step; pass --gee to run). Uses committed data instead.\n")
    next
  }
  if (!FORCE && done(t$verify)) {
    cat("  - skipped (output already exists).\n")
    next
  }

  sp <- here::here(t$script)
  if (!file.exists(sp)) stop(sprintf("script not found: %s", t$script), call. = FALSE)

  cat(sprintf("  -> running %s\n", t$script))
  t0 <- Sys.time()
  setwd(here::here())            # each script may setwd; reset before sourcing
  ok <- tryCatch({ source(sp, local = new.env()); TRUE },
                 error = function(e) { cat(sprintf("  ! ERROR: %s\n", conditionMessage(e))); FALSE })
  setwd(here::here())            # restore wd after a script that setwd'd elsewhere
  if (!ok)
    stop(sprintf("Pipeline stopped: step %d (%s) failed. Fix it and re-run; completed steps will be skipped.",
                 i, t$script), call. = FALSE)

  # Confirm the step actually produced its output before moving on
  # (skip this gate for tasks declared with verify = NULL).
  if (!is.null(t$verify) && !done(t$verify))
    stop(sprintf("Pipeline stopped: step %d (%s) finished but produced no expected output.",
                 i, t$script), call. = FALSE)

  cat(sprintf("  - done (%.1fs).\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}

# ------------------------------------------------------------------------------
# Phase 6: render deliverables
# ------------------------------------------------------------------------------
if (!NO_RENDER) {
  setwd(here::here())
  hr(); cat("Rendering deliverables\n"); hr()
  if (nzchar(Sys.which("quarto"))) {
    cat("\n-> presentation\n")
    system2("quarto", c("render", shQuote(here::here("04_presentation/presentation.qmd"))))
    if (file.exists(here::here("05_paper/paper.qmd"))) {
      cat("\n-> paper\n")
      system2("quarto", c("render", shQuote(here::here("05_paper/paper.qmd"))))
    }
    if (file.exists(here::here("05_paper/supplementary.qmd"))) {
      cat("\n-> supplementary\n")
      system2("quarto", c("render", shQuote(here::here("05_paper/supplementary.qmd"))))
    }
  } else {
    cat("  ! quarto not found on PATH; skipping render.\n")
  }
}

hr(); cat("Pipeline complete.\n"); hr()
