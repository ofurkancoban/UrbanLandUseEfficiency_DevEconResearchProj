# ============================================================================
# 07_fig_metadata_layers.R
# Step-by-step GIS visualisation of how the SDG 11.3.1 / BpCR inputs are built,
# following the metadata stages, for the same example window used in the deck
# data-sources map (Oldenburg / NW Germany).
# Three panels: (1) GHS-BUILT-S built-up surface, (2) GHS-SMOD Degree of
# Urbanisation, (3) urban-masked built-up (the analysis input), with the GAUL
# country boundary overlaid. Output: 04_outputs/figures/metadata_layers.png
# ============================================================================
suppressMessages({library(here); library(terra); library(sf); library(ggplot2)
  library(tidyterra); library(patchwork)}); setwd(here::here())

win <- ext(7.5, 9.0, 52.8, 53.6)                   # Oldenburg / NW Germany (deck window)
moll <- "ESRI:54009"
built_tif <- here("03_datasets/raw/GHS_BUILT_S_E2020_GLOBE_R2023A_54009_1000_V1_0/GHS_BUILT_S_E2020_GLOBE_R2023A_54009_1000_V1_0.tif")
smod_tif  <- here("03_datasets/raw/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0.tif")

# window polygon in Mollweide for cropping
win_ll <- vect(win, crs = "EPSG:4326")
win_m  <- project(win_ll, moll)

cropm <- function(f) { r <- rast(f); if (is.na(crs(r))||crs(r)=="") crs(r) <- moll
  project(crop(r, ext(win_m)), "EPSG:4326") }
built <- cropm(built_tif); names(built) <- "built"
smod  <- cropm(smod_tif);  names(smod)  <- "smod"
built[built <= 0] <- NA

# urban-masked built-up: keep built-up only where SMOD >= 21 (DEGURBA urban)
smod_r <- resample(smod, built, method = "near")
urb <- built; urb[smod_r < 21] <- NA

# GAUL country boundary (Turkey) clipped to window
gaul <- st_read(here("03_datasets/raw/GAUL_2025_L1/gaul_2025_l1.shp"), quiet = TRUE) |>
  st_make_valid()
cty  <- gaul[gaul$iso3_code == "DEU", ] |> st_union() |>
  st_crop(st_bbox(c(xmin=7.5,xmax=9.0,ymin=52.8,ymax=53.6), crs=st_crs(4326)))

bound <- geom_sf(data = cty, fill = NA, color = "grey20", linewidth = 0.3)
base_t <- theme_void(base_size = 11) +
  theme(plot.title = element_text(face = "bold", size = 11, hjust = 0),
        legend.key.height = unit(0.35,"cm"), legend.key.width = unit(0.3,"cm"),
        legend.title = element_text(size = 8), legend.text = element_text(size = 7))

p1 <- ggplot() + geom_spatraster(data = built) + bound +
  scale_fill_viridis_c(option = "inferno", na.value = "transparent", name = "m²") +
  labs(title = "(a) GHS-BUILT-S: built-up surface") + base_t

smod_f <- as.factor(smod)
p2 <- ggplot() + geom_spatraster(data = smod_f) + bound +
  scale_fill_manual(values = c("10"="#c6dbef","11"="#cdf57a","12"="#abcd66","13"="#375623",
                               "21"="#ffff00","22"="#a87000","23"="#732600","30"="#ff0000"),
                    na.value = "transparent", name = "SMOD") +
  labs(title = "(b) GHS-SMOD: Degree of Urbanisation") + base_t

p3 <- ggplot() + geom_spatraster(data = urb) + bound +
  scale_fill_viridis_c(option = "inferno", na.value = "transparent", name = "m²") +
  labs(title = "(c) Urban-masked built-up (analysis input)") + base_t

fig <- p1 + p2 + p3 + plot_layout(nrow = 1)
out <- here("04_outputs/figures/metadata_layers.png")
ggsave(out, fig, width = 11, height = 3.4, dpi = 150, bg = "white")
cat("wrote", out, "\n")
