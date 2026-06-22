# ============================================================================
# 07_fig_metadata_layers.R
# Step-by-step GIS visualisation of how the SDG 11.3.1 / BpCR inputs are built,
# following the metadata stages. 2x2 panels over a real satellite basemap
# (Istanbul / Bosphorus): (a) basemap, (b) GHS-BUILT-S built-up surface,
# (c) GHS-SMOD Degree of Urbanisation, (d) urban-masked built-up (analysis input).
# Fonts use Latin Modern Roman to match the paper body text. UTM 35N (metric).
# Output: 04_outputs/figures/metadata_layers.png
# ============================================================================
suppressMessages({library(here); library(terra); library(sf); library(ggplot2)
  library(tidyterra); library(patchwork); library(maptiles)
  library(showtext); library(sysfonts)}); setwd(here::here())
sf::sf_use_s2(FALSE)

# Latin Modern Roman (same family as the Elsevier/LaTeX body text)
lm_dir <- "~/Library/TinyTeX/texmf-dist/fonts/opentype/public/lm"
font_add("lmroman",
  regular    = path.expand(file.path(lm_dir, "lmroman10-regular.otf")),
  bold       = path.expand(file.path(lm_dir, "lmroman10-bold.otf")),
  italic     = path.expand(file.path(lm_dir, "lmroman10-italic.otf")))
showtext_auto(); showtext_opts(dpi = 300)
ff <- "lmroman"

utm <- "EPSG:32635"
bb_ll <- st_bbox(c(xmin=28.30, xmax=29.80, ymin=40.65, ymax=41.40), crs = st_crs(4326))
win_m <- st_transform(st_as_sfc(bb_ll), utm)
ext_m <- ext(st_bbox(win_m)[c("xmin","xmax","ymin","ymax")])

built_tif <- here("03_datasets/raw/GHS_BUILT_S_E2020_GLOBE_R2023A_54009_1000_V1_0/GHS_BUILT_S_E2020_GLOBE_R2023A_54009_1000_V1_0.tif")
smod_tif  <- here("03_datasets/raw/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0.tif")
moll <- "ESRI:54009"
prep <- function(f){ r <- rast(f); if (is.na(crs(r))||crs(r)=="") crs(r) <- moll
  project(crop(r, ext(project(vect(win_m), moll))), utm) }
built <- prep(built_tif); names(built) <- "built"; built[built <= 0] <- NA
smod  <- prep(smod_tif);  names(smod)  <- "smod"
smod_r <- resample(smod, built, method = "near")
urb <- built; urb[smod_r < 21] <- NA
to_pct <- function(r) r / 1e6 * 100
built_p <- to_pct(built); urb_p <- to_pct(urb)
blim <- c(0, as.numeric(global(built_p, "max", na.rm=TRUE)))

bm <- get_tiles(win_m, provider = "Esri.WorldImagery", crop = TRUE, zoom = 11, cachedir = tempdir())
gaul <- st_read(here("03_datasets/raw/GAUL_2025_L1/gaul_2025_l1.shp"), quiet = TRUE) |> st_make_valid()
cty  <- gaul[gaul$iso3_code == "TUR", ] |> st_union() |> st_transform(utm) |> st_crop(st_bbox(win_m))

smod_lev <- c("10","11","12","13","21","22","23","30")
smod_col <- c("#9ecae1","#e5f5b8","#c7e29a","#7bb661","#ffe34d","#f0a23c","#c5562b","#d7191c")

theme_layer <- function() theme_void(base_size = 13, base_family = ff) +
  theme(plot.title = element_text(family=ff, face="bold", size=12.5, hjust=0,
                                  margin=margin(b=4)),
        panel.border = element_rect(color="grey25", fill=NA, linewidth=0.5),
        plot.margin = margin(6,8,6,8),
        legend.key.height=unit(0.5,"cm"), legend.key.width=unit(0.34,"cm"),
        legend.title=element_text(family=ff, size=10, face="bold"),
        legend.text=element_text(family=ff, size=9))
co  <- coord_sf(crs = utm, expand = FALSE, xlim=c(ext_m$xmin,ext_m$xmax), ylim=c(ext_m$ymin,ext_m$ymax))
bnd <- geom_sf(data = cty, fill=NA, color="#FFD700", linewidth=0.6, inherit.aes=FALSE)
bg  <- geom_spatraster_rgb(data = bm)

pa <- ggplot() + bg + bnd + co + labs(title="(a) Satellite Basemap (Reference)") + theme_layer()
pb <- ggplot() + bg + geom_spatraster(data=built_p, alpha=0.85) + bnd + co +
  scale_fill_viridis_c(option="inferno", limits=blim, na.value="transparent",
                       name="Built-up\n(% of cell)") +
  labs(title="(b) GHS-BUILT-S: Built-up Surface") + theme_layer()
pc <- ggplot() + bg + geom_spatraster(data=as.factor(smod), alpha=0.78) + bnd + co +
  scale_fill_manual(values=setNames(smod_col,smod_lev), breaks=smod_lev,
                    limits=smod_lev, drop=FALSE, na.value="transparent",
                    name="SMOD", na.translate=FALSE) +
  labs(title="(c) GHS-SMOD: Degree of Urbanisation") + theme_layer()
pd <- ggplot() + bg + geom_spatraster(data=urb_p, alpha=0.92) + bnd + co +
  scale_fill_viridis_c(option="inferno", limits=blim, na.value="transparent",
                       name="Built-up\n(% of cell)") +
  labs(title="(d) Urban-Masked Built-up (Analysis Input)") + theme_layer()

fig <- (pa | pb) / (pc | pd) +
  plot_layout(guides="collect") &
  theme(plot.background = element_rect(fill="white", color=NA), legend.position="right")
out <- here("04_outputs/figures/metadata_layers.png")
ggsave(out, fig, width = 9.4, height = 7.7, dpi = 300, bg = "white")
cat("wrote", out, "\n")
