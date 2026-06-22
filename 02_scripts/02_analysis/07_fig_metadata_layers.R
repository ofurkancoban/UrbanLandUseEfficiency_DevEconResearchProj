# ============================================================================
# 07_fig_metadata_layers.R
# Step-by-step GIS visualisation of how the SDG 11.3.1 / BpCR inputs are built,
# following the metadata stages, for the same window used in the deck data-sources
# map (Oldenburg / NW Germany). 2x2 panels over a real satellite basemap:
#   (a) basemap, (b) GHS-BUILT-S, (c) GHS-SMOD (DEGURBA), (d) urban-masked built-up.
# Layers are drawn semi-transparent over the basemap. Everything is reprojected to
# UTM 32N so cells are square and the aspect ratio is geographically correct.
# Output: 04_outputs/figures/metadata_layers.png
# ============================================================================
suppressMessages({library(here); library(terra); library(sf); library(ggplot2)
  library(tidyterra); library(patchwork); library(maptiles)}); setwd(here::here())

utm <- "EPSG:25832"                                   # UTM 32N (metric, NW Germany)
bb_ll <- st_bbox(c(xmin=8.00, xmax=8.50, ymin=53.02, ymax=53.28), crs = st_crs(4326))  # zoom on Oldenburg
win_m <- st_transform(st_as_sfc(bb_ll), utm)
ext_m <- ext(st_bbox(win_m)[c("xmin","xmax","ymin","ymax")])

built_tif <- here("03_datasets/raw/GHS_BUILT_S_E2020_GLOBE_R2023A_54009_1000_V1_0/GHS_BUILT_S_E2020_GLOBE_R2023A_54009_1000_V1_0.tif")
smod_tif  <- here("03_datasets/raw/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0.tif")
moll <- "ESRI:54009"
prep <- function(f){ r <- rast(f); if (is.na(crs(r))||crs(r)=="") crs(r) <- moll
  win_moll <- project(vect(win_m), moll)
  project(crop(r, ext(win_moll)), utm) }
built <- prep(built_tif); names(built) <- "built"; built[built <= 0] <- NA
smod  <- prep(smod_tif);  names(smod)  <- "smod"
smod_r <- resample(smod, built, method = "near")
urb <- built; urb[smod_r < 21] <- NA

# real satellite basemap for the window
bm <- get_tiles(win_m, provider = "Esri.WorldImagery", crop = TRUE, zoom = 12, cachedir = tempdir())

gaul <- st_read(here("03_datasets/raw/GAUL_2025_L1/gaul_2025_l1.shp"), quiet = TRUE) |> st_make_valid()
cty  <- gaul[gaul$iso3_code == "DEU", ] |> st_union() |> st_transform(utm) |>
  st_crop(st_bbox(win_m))

base_t <- theme_void(base_size = 11) +
  theme(plot.title = element_text(face="bold", size=11, hjust=0),
        legend.key.height=unit(0.35,"cm"), legend.key.width=unit(0.3,"cm"),
        legend.title=element_text(size=8), legend.text=element_text(size=7))
co  <- coord_sf(crs = utm, expand = FALSE, xlim=c(ext_m$xmin,ext_m$xmax), ylim=c(ext_m$ymin,ext_m$ymax))
bnd <- geom_sf(data = cty, fill=NA, color="white", linewidth=0.3, inherit.aes=FALSE)
bg  <- geom_spatraster_rgb(data = bm)

pa <- ggplot() + bg + bnd + co + labs(title="(a) Satellite basemap (Esri)") + base_t
pb <- ggplot() + bg + geom_spatraster(data=built, alpha=0.8) + bnd + co +
  scale_fill_viridis_c(option="inferno", na.value="transparent", name="m^2") +
  labs(title="(b) GHS-BUILT-S: built-up") + base_t
pc <- ggplot() + bg + geom_spatraster(data=as.factor(smod), alpha=0.7) + bnd + co +
  scale_fill_manual(values=c("10"="#9ecae1","11"="#cdf57a","12"="#abcd66","13"="#375623",
                             "21"="#ffff00","22"="#a87000","23"="#732600","30"="#ff0000"),
                    na.value="transparent", name="SMOD") +
  labs(title="(c) GHS-SMOD: Degree of Urbanisation") + base_t
pd <- ggplot() + bg + geom_spatraster(data=urb, alpha=0.9) + bnd + co +
  scale_fill_viridis_c(option="inferno", na.value="transparent", name="m^2") +
  labs(title="(d) Urban-masked built-up (analysis input)") + base_t

fig <- (pa | pb) / (pc | pd)
out <- here("04_outputs/figures/metadata_layers.png")
ggsave(out, fig, width = 9, height = 7.6, dpi = 150, bg = "white")
cat("wrote", out, "\n")
