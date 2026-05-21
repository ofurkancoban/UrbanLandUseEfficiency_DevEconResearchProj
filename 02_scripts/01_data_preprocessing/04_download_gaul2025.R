# ============================================================================
# 04_download_gaul2025.R
# Download FAO GAUL 2025 Level-1 (sub-national) admin boundaries as a shapefile,
# straight from the FAO GeoServer WFS — the SAME server that serves the map's
# WMS border layers, so the country choropleth fill (L1 dissolved to L0) matches
# the on-map GAUL borders exactly. Fully reproducible; no manual download.
# Output: 03_datasets/raw/GAUL_2025_L1/gaul_2025_l1.shp  (+ .dbf/.shx/.prj)
# ============================================================================
suppressMessages({library(here); library(sf)})
setwd(here::here())

out_dir <- here("03_datasets/raw/GAUL_2025_L1")
shp     <- file.path(out_dir, "gaul_2025_l1.shp")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

if (file.exists(shp)) {
  message("GAUL 2025 L1 already present: ", shp)
} else {
  # FAO GeoServer's SHAPE-ZIP output is server-side broken, so pull GeoJSON. The
  # full layer in one request (~600 MB) gets truncated mid-stream ("Unterminated
  # object"), so page it: download in chunks of `page` features, validate each
  # page parses, retry per page, then combine and write the shapefile.
  base <- paste0("https://data.apps.fao.org/map/gsrv/gsrv1/gaul/ows",
                 "?service=WFS&version=2.0.0&request=GetFeature",
                 "&typeNames=gaul:gaul_2025_l1&outputFormat=application/json")
  old <- options(timeout = 600); on.exit(options(old), add = TRUE)

  page  <- 500L; start <- 0L; parts <- list()
  message("Downloading GAUL 2025 L1 from FAO WFS in pages of ", page, " ...")
  repeat {
    # sortBy is REQUIRED by this GeoServer whenever startIndex is used (stable paging)
    url <- sprintf("%s&sortBy=gaul1_code&count=%d&startIndex=%d", base, page, start)
    x <- NULL
    for (attempt in 1:4) {
      gj <- tempfile(fileext = ".geojson")
      ok <- tryCatch({ utils::download.file(url, gj, mode = "wb", method = "libcurl", quiet = TRUE)
                       x <- sf::st_read(gj, quiet = TRUE); TRUE },
                     error = function(e) { message("  page @", start, " attempt ", attempt, " failed: ",
                                                   conditionMessage(e)); FALSE })
      unlink(gj)
      if (isTRUE(ok)) break
      Sys.sleep(attempt * 3)
    }
    if (is.null(x)) stop("GAUL 2025 page @", start, " failed after retries")
    if (nrow(x) == 0) break
    parts[[length(parts) + 1]] <- x
    message(sprintf("  got %d features (total %d)", nrow(x),
                    sum(vapply(parts, nrow, integer(1)))))
    if (nrow(x) < page) break          # last page
    start <- start + page
  }
  x <- do.call(rbind, parts)
  if (!nrow(x)) stop("WFS download returned no features")
  sf::st_write(x, shp, delete_dsn = TRUE, quiet = TRUE)
  message(sprintf("Saved: %s  (%d features, cols: %s)",
                  shp, nrow(x), paste(setdiff(names(x), attr(x, "sf_column")), collapse = ", ")))
}
