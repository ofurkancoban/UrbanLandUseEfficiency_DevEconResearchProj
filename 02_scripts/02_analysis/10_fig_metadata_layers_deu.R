# ==============================================================================
# File:          10_fig_metadata_layers_deu.R
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
# Category:      Data Analysis
# Description:   Germany (Berlin/Brandenburg) version of the step-by-step GIS
#                visualization of SDG 11.3.1 inputs (satellite, built-up,
#                DEGURBA, urban-masked built-up) for the supplementary material.
# ==============================================================================
suppressMessages({library(here); library(terra); library(sf); library(ggplot2)
  library(tidyterra); library(maptiles); library(showtext); library(sysfonts)
  library(grid); library(magick); library(cowplot)}); setwd(here::here())
sf::sf_use_s2(FALSE)

lm_dir <- "~/Library/TinyTeX/texmf-dist/fonts/opentype/public/lm"
font_add("lmroman",
  regular=path.expand(file.path(lm_dir,"lmroman10-regular.otf")),
  bold   =path.expand(file.path(lm_dir,"lmroman10-bold.otf")),
  italic =path.expand(file.path(lm_dir,"lmroman10-italic.otf")))
showtext_auto(); showtext_opts(dpi=300); ff <- "lmroman"

# Berlin (dense urban city-state) embedded in rural Brandenburg: the same urban
# core / rural matrix contrast as the national figure, at a German Kreis scale.
utm <- "EPSG:32633"
bb_ll <- st_bbox(c(xmin=12.70, xmax=14.10, ymin=52.25, ymax=52.85), crs=st_crs(4326))
win_m <- st_transform(st_as_sfc(bb_ll), utm); ext_m <- ext(st_bbox(win_m)[c("xmin","xmax","ymin","ymax")])
win_buf <- st_buffer(win_m, 20000)   # 20 km buffer so layers overfill the frame
aspect <- as.numeric((ext_m$xmax-ext_m$xmin)/(ext_m$ymax-ext_m$ymin))
moll <- "ESRI:54009"
prep <- function(f, method="bilinear"){ r<-rast(f); if(is.na(crs(r))||crs(r)=="") crs(r)<-moll
  project(crop(r, ext(project(vect(win_buf),moll))), utm, method=method) }
built<-prep(built_tif<-here("03_datasets/raw/GHS_BUILT_S_E2020_GLOBE_R2023A_54009_1000_V1_0/GHS_BUILT_S_E2020_GLOBE_R2023A_54009_1000_V1_0.tif")); names(built)<-"built"; built[built<=0]<-NA
# project SMOD onto the SAME grid as built-up (fine template) so it aligns exactly
smod_tif <- here("03_datasets/raw/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0.tif")
smod_src <- rast(smod_tif); if(is.na(crs(smod_src))||crs(smod_src)=="") crs(smod_src)<-moll
smod_src <- crop(smod_src, ext(project(vect(win_buf),moll)))
tmpl <- disagg(built, fact=4)                      # 250 m UTM template from built-up
smod <- project(smod_src, tmpl, method="near"); names(smod)<-"smod"
smod_r<-resample(smod,built,method="near"); urb<-built; urb[smod_r<21]<-NA
to_pct<-function(r) r/1e6*100; built_p<-to_pct(built); urb_p<-to_pct(urb)
blim<-c(0, as.numeric(global(built_p,"max",na.rm=TRUE)))
bm<-get_tiles(win_m, provider="Esri.WorldImagery", crop=TRUE, zoom=11, cachedir=tempdir())
gaul<-st_read(here("03_datasets/raw/GAUL_2025_L1/gaul_2025_l1.shp"),quiet=TRUE)|>st_make_valid()
# keep individual German states (no union) so Berlin's outline and the surrounding
# Brandenburg boundary both show inside the interior window
cty<-gaul[gaul$iso3_code=="DEU",]|>st_transform(utm)|>st_crop(st_bbox(win_m))
smod_lev<-c("10","11","12","13","21","22","23","30")
smod_col<-c("#9ecae1","#e5f5b8","#c7e29a","#7bb661","#ffe34d","#f0a23c","#c5562b","#d7191c")
co<-coord_sf(crs=utm,expand=FALSE,xlim=c(ext_m$xmin,ext_m$xmax),ylim=c(ext_m$ymin,ext_m$ymax))
bnd<-geom_sf(data=cty[cty$gaul1_name == "Berlin", ],fill=NA,color="#00FFFF",linewidth=1.8,inherit.aes=FALSE)
bg <-geom_spatraster_rgb(data=bm)

# Map built-up data (urb_p) to RGB using scales::col_numeric and convert to grayscale outside Berlin
berlin <- cty[cty$gaul1_name == "Berlin", ]
berlin_vect <- vect(berlin)

val_urb <- values(urb_p)[, 1]
valid_idx <- which(!is.na(val_urb))
cols <- rep(NA, length(val_urb))
cols[valid_idx] <- scales::col_numeric("inferno", domain=blim)(val_urb[valid_idx])
rgb_mat <- matrix(NA, nrow=length(val_urb), ncol=3)
rgb_mat[valid_idx, ] <- t(col2rgb(cols[valid_idx]))

urb_rgb <- c(urb_p, urb_p, urb_p)
values(urb_rgb[[1]]) <- rgb_mat[, 1]
values(urb_rgb[[2]]) <- rgb_mat[, 2]
values(urb_rgb[[3]]) <- rgb_mat[, 3]
RGB(urb_rgb) <- 1:3

gray_urb <- 0.299 * urb_rgb[[1]] + 0.587 * urb_rgb[[2]] + 0.114 * urb_rgb[[3]]
urb_gray <- urb_rgb
urb_gray[[1]] <- gray_urb
urb_gray[[2]] <- gray_urb
urb_gray[[3]] <- gray_urb

urb_color_masked <- mask(urb_rgb, berlin_vect)
urb_gray_masked <- mask(urb_gray, berlin_vect, inverse=TRUE)
urb_d_rgb <- cover(urb_color_masked, urb_gray_masked)
RGB(urb_d_rgb) <- 1:3

# Map Degree of Urbanisation (smod >= 21) to RGB and convert to grayscale outside Berlin
smod_urb <- smod
smod_urb[smod_urb < 21] <- NA
val_smod <- as.character(values(smod_urb)[, 1])
smod_rgb_cols <- rep(NA, length(val_smod))
for (i in seq_along(smod_lev)) {
  idx <- which(val_smod == smod_lev[i])
  if (length(idx) > 0) {
    smod_rgb_cols[idx] <- smod_col[i]
  }
}
rgb_smod_mat <- matrix(NA, nrow=length(val_smod), ncol=3)
valid_smod_idx <- which(!is.na(smod_rgb_cols))
rgb_smod_mat[valid_smod_idx, ] <- t(col2rgb(smod_rgb_cols[valid_smod_idx]))

smod_rgb <- c(smod_urb, smod_urb, smod_urb)
values(smod_rgb[[1]]) <- rgb_smod_mat[, 1]
values(smod_rgb[[2]]) <- rgb_smod_mat[, 2]
values(smod_rgb[[3]]) <- rgb_smod_mat[, 3]
RGB(smod_rgb) <- 1:3

gray_smod <- 0.299 * smod_rgb[[1]] + 0.587 * smod_rgb[[2]] + 0.114 * smod_rgb[[3]]
smod_gray <- smod_rgb
smod_gray[[1]] <- gray_smod
smod_gray[[2]] <- gray_smod
smod_gray[[3]] <- gray_smod

smod_color_masked <- mask(smod_rgb, berlin_vect)
smod_gray_masked <- mask(smod_gray, berlin_vect, inverse=TRUE)
smod_d_rgb <- cover(smod_color_masked, smod_gray_masked)
RGB(smod_d_rgb) <- 1:3

maptheme<-theme_void()+theme(legend.position="none",plot.margin=margin(0,0,0,0))
legtheme<-theme_void(base_family=ff)+theme(
  legend.title=element_text(family=ff,size=15,face="bold"),
  legend.text=element_text(family=ff,size=13),
  legend.key.height=unit(0.55,"cm"),legend.key.width=unit(0.4,"cm"),
  legend.justification="left", legend.box.just="left",
  legend.margin=margin(0,0,0,2), legend.box.margin=margin(0,0,0,0))

map_a<-ggplot()+bg+bnd+co+maptheme
map_b<-ggplot()+bg+geom_spatraster(data=built_p,alpha=0.85)+bnd+co+
  scale_fill_viridis_c(option="inferno",limits=blim,na.value="transparent",name="Built-up\n(% of cell)")+maptheme
map_c<-ggplot()+bg+geom_spatraster(data=as.factor(smod),alpha=1)+bnd+co+
  scale_fill_manual(values=setNames(smod_col,smod_lev),breaks=smod_lev,limits=smod_lev,drop=FALSE,
                    na.value="transparent",name="SMOD",na.translate=FALSE)+maptheme
map_d<-ggplot()+
  geom_spatraster_rgb(data=smod_d_rgb,alpha=0.5)+
  geom_spatraster_rgb(data=urb_d_rgb,alpha=0.92)+
  geom_spatraster(data=urb_p,alpha=0)+
  bnd+co+
  scale_fill_viridis_c(option="inferno",limits=blim,na.value="transparent",name="Built-up\n(% of cell)")+maptheme

# round + frame the MAP only, via a grid roundrect mask in magick
MW<-2400; MH<-round(MW/aspect); rad<-80
round_map<-function(p){
  pf<-tempfile(fileext=".png"); ggsave(pf,p,width=MW/300,height=MH/300,dpi=300,bg="white")
  mk<-tempfile(fileext=".png"); png(mk,width=MW,height=MH,bg="transparent")
  grid.draw(roundrectGrob(r=unit(rad,"pt"),gp=gpar(fill="white",col=NA))); dev.off()
  fr<-tempfile(fileext=".png"); png(fr,width=MW,height=MH,bg="transparent")
  grid.draw(roundrectGrob(r=unit(rad,"pt"),gp=gpar(fill=NA,col="grey30",lwd=4))); dev.off()
  img<-image_composite(image_scale(image_read(pf),paste0(MW,"x",MH,"!")),image_read(mk),operator="CopyOpacity")
  image_composite(img,image_read(fr))
}
leg_of<-function(p) cowplot::get_legend(p+legtheme+theme(legend.position="right"))

panel<-function(map,title,withleg=TRUE){
  rm<-round_map(map)
  body<-cowplot::ggdraw()+cowplot::draw_image(rm, y=1, vjust=1, valign=1)
  # thin spacer column between map and legend so the legend is not stuck to it
  if(withleg){
    row<-cowplot::plot_grid(body, NULL, leg_of(map), nrow=1, rel_widths=c(1,0.05,0.22))
  } else row<-cowplot::plot_grid(body, NULL, nrow=1, rel_widths=c(1,0.27))
  # title close to the map (small row, label near its bottom edge)
  ttl<-cowplot::ggdraw()+cowplot::draw_label(title, fontfamily=ff, fontface="bold",
        size=22, x=0.01, hjust=0, y=0.5, vjust=0.5)
  cowplot::plot_grid(ttl, row, ncol=1, rel_heights=c(0.1,1))
}
P <- list(
  panel(map_a,"(a) Satellite Basemap (Reference)", withleg=FALSE),
  panel(map_b,"(b) GHS-BUILT-S: Built-up Surface"),
  panel(map_c,"(c) GHS-SMOD: Degree of Urbanisation"),
  panel(map_d,"(d) Urban-Masked Built-up (Analysis Input)"))
fig<-cowplot::plot_grid(plotlist=P, nrow=2, ncol=2)
out<-here("04_outputs/figures/metadata_layers_deu.png")
cowplot::save_plot(out, fig, base_width=9.6, base_height=2*(9.6/2*(1/1.27)/aspect)+0.9, dpi=600, bg="white")
cat("wrote", out, "\n")
