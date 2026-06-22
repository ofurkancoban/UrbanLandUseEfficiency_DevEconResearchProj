# ============================================================================
# 07_fig_metadata_layers.R
# Step-by-step GIS visualisation of the SDG 11.3.1 / BpCR inputs (Istanbul /
# Bosphorus): (a) satellite basemap, (b) GHS-BUILT-S, (c) GHS-SMOD DEGURBA,
# (d) urban-masked built-up. Each panel is rendered as a rounded, framed card
# with its own legend. Fonts use Latin Modern Roman to match the paper.
# Output: 04_outputs/figures/metadata_layers.png
# ============================================================================
suppressMessages({library(here); library(terra); library(sf); library(ggplot2)
  library(tidyterra); library(maptiles); library(showtext); library(sysfonts)
  library(grid); library(magick)}); setwd(here::here())
sf::sf_use_s2(FALSE)

lm_dir <- "~/Library/TinyTeX/texmf-dist/fonts/opentype/public/lm"
font_add("lmroman",
  regular = path.expand(file.path(lm_dir,"lmroman10-regular.otf")),
  bold    = path.expand(file.path(lm_dir,"lmroman10-bold.otf")),
  italic  = path.expand(file.path(lm_dir,"lmroman10-italic.otf")))
showtext_auto(); showtext_opts(dpi = 300); ff <- "lmroman"

utm <- "EPSG:32635"
bb_ll <- st_bbox(c(xmin=28.30, xmax=29.80, ymin=40.65, ymax=41.40), crs = st_crs(4326))
win_m <- st_transform(st_as_sfc(bb_ll), utm); ext_m <- ext(st_bbox(win_m)[c("xmin","xmax","ymin","ymax")])
built_tif <- here("03_datasets/raw/GHS_BUILT_S_E2020_GLOBE_R2023A_54009_1000_V1_0/GHS_BUILT_S_E2020_GLOBE_R2023A_54009_1000_V1_0.tif")
smod_tif  <- here("03_datasets/raw/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0.tif")
moll <- "ESRI:54009"
prep <- function(f){ r <- rast(f); if (is.na(crs(r))||crs(r)=="") crs(r) <- moll
  project(crop(r, ext(project(vect(win_m), moll))), utm) }
built <- prep(built_tif); names(built)<-"built"; built[built<=0]<-NA
smod  <- prep(smod_tif);  names(smod)<-"smod"
smod_r <- resample(smod, built, method="near"); urb <- built; urb[smod_r<21]<-NA
to_pct <- function(r) r/1e6*100; built_p<-to_pct(built); urb_p<-to_pct(urb)
blim <- c(0, as.numeric(global(built_p,"max",na.rm=TRUE)))
bm <- get_tiles(win_m, provider="Esri.WorldImagery", crop=TRUE, zoom=11, cachedir=tempdir())
gaul <- st_read(here("03_datasets/raw/GAUL_2025_L1/gaul_2025_l1.shp"), quiet=TRUE) |> st_make_valid()
cty  <- gaul[gaul$iso3_code=="TUR",] |> st_union() |> st_transform(utm) |> st_crop(st_bbox(win_m))
smod_lev <- c("10","11","12","13","21","22","23","30")
smod_col <- c("#9ecae1","#e5f5b8","#c7e29a","#7bb661","#ffe34d","#f0a23c","#c5562b","#d7191c")

th <- function() theme_void(base_size=13, base_family=ff) +
  theme(plot.title=element_text(family=ff,face="bold",size=13,hjust=0,margin=margin(b=5)),
        plot.margin=margin(10,12,10,12),
        legend.key.height=unit(0.5,"cm"), legend.key.width=unit(0.34,"cm"),
        legend.title=element_text(family=ff,size=10,face="bold"),
        legend.text=element_text(family=ff,size=9))
co  <- coord_sf(crs=utm, expand=FALSE, xlim=c(ext_m$xmin,ext_m$xmax), ylim=c(ext_m$ymin,ext_m$ymax))
bnd <- geom_sf(data=cty, fill=NA, color="#FFD700", linewidth=0.6, inherit.aes=FALSE)
bg  <- geom_spatraster_rgb(data=bm)
pa <- ggplot()+bg+bnd+co+labs(title="(a) Satellite Basemap (Reference)")+th()
pb <- ggplot()+bg+geom_spatraster(data=built_p,alpha=0.85)+bnd+co+
  scale_fill_viridis_c(option="inferno",limits=blim,na.value="transparent",name="Built-up\n(% of cell)")+
  labs(title="(b) GHS-BUILT-S: Built-up Surface")+th()
pc <- ggplot()+bg+geom_spatraster(data=as.factor(smod),alpha=0.78)+bnd+co+
  scale_fill_manual(values=setNames(smod_col,smod_lev),breaks=smod_lev,limits=smod_lev,
                    drop=FALSE,na.value="transparent",name="SMOD",na.translate=FALSE)+
  labs(title="(c) GHS-SMOD: Degree of Urbanisation")+th()
pd <- ggplot()+bg+geom_spatraster(data=urb_p,alpha=0.92)+bnd+co+
  scale_fill_viridis_c(option="inferno",limits=blim,na.value="transparent",name="Built-up\n(% of cell)")+
  labs(title="(d) Urban-Masked Built-up (Analysis Input)")+th()

# render each panel, then round corners + frame with a grid mask via magick
W <- 1500; H <- 1080; rad <- 46
card <- function(plot){
  pf <- tempfile(fileext=".png"); ggsave(pf, plot, width=W/150, height=H/150, dpi=150, bg="white")
  img <- image_read(pf)
  mk <- tempfile(fileext=".png"); png(mk, width=W, height=H, bg="transparent")
  grid.draw(roundrectGrob(r=unit(rad,"pt"), gp=gpar(fill="white", col=NA))); dev.off()
  fr <- tempfile(fileext=".png"); png(fr, width=W, height=H, bg="transparent")
  grid.draw(roundrectGrob(r=unit(rad,"pt"), gp=gpar(fill=NA, col="grey30", lwd=4))); dev.off()
  img <- image_composite(image_scale(img, paste0(W,"x",H,"!")), image_read(mk), operator="CopyOpacity")
  image_composite(img, image_read(fr))
}
cards <- lapply(list(pa,pb,pc,pd), card)
gap <- image_blank(40, H, color="white")
vgap <- image_blank(2*W+40, 40, color="white")
row1 <- image_append(c(cards[[1]], gap, cards[[2]]))
row2 <- image_append(c(cards[[3]], gap, cards[[4]]))
fig  <- image_append(c(row1, vgap, row2), stack=TRUE)
fig  <- image_background(image_border(fig, "white", "24x24"), "white")
out <- here("04_outputs/figures/metadata_layers.png")
image_write(fig, out, format="png")
cat("wrote", out, "\n")
