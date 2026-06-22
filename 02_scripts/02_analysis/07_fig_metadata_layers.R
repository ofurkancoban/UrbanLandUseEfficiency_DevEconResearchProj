# ============================================================================
# 07_fig_metadata_layers.R
# Step-by-step GIS visualisation of the SDG 11.3.1 / BpCR inputs (Istanbul /
# Bosphorus): (a) satellite basemap, (b) GHS-BUILT-S, (c) GHS-SMOD DEGURBA,
# (d) urban-masked built-up. The MAP of each panel has rounded corners and a
# frame; the title sits above and the legend beside it. Latin Modern fonts.
# Output: 04_outputs/figures/metadata_layers.png
# ============================================================================
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

utm <- "EPSG:32635"
bb_ll <- st_bbox(c(xmin=28.30, xmax=29.80, ymin=40.65, ymax=41.40), crs=st_crs(4326))
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
cty<-gaul[gaul$iso3_code=="TUR",]|>st_union()|>st_transform(utm)|>st_crop(st_bbox(win_m))
smod_lev<-c("10","11","12","13","21","22","23","30")
smod_col<-c("#9ecae1","#e5f5b8","#c7e29a","#7bb661","#ffe34d","#f0a23c","#c5562b","#d7191c")
co<-coord_sf(crs=utm,expand=FALSE,xlim=c(ext_m$xmin,ext_m$xmax),ylim=c(ext_m$ymin,ext_m$ymax))
bnd<-geom_sf(data=cty,fill=NA,color="#FFD700",linewidth=0.6,inherit.aes=FALSE)
bg <-geom_spatraster_rgb(data=bm)
maptheme<-theme_void()+theme(legend.position="none",plot.margin=margin(0,0,0,0))
legtheme<-theme_void(base_family=ff)+theme(
  legend.title=element_text(family=ff,size=11,face="bold"),
  legend.text=element_text(family=ff,size=10),
  legend.key.height=unit(0.55,"cm"),legend.key.width=unit(0.4,"cm"),
  legend.justification="left", legend.box.just="left",
  legend.margin=margin(0,0,0,2), legend.box.margin=margin(0,0,0,0))

map_a<-ggplot()+bg+bnd+co+maptheme
map_b<-ggplot()+bg+geom_spatraster(data=built_p,alpha=0.85)+bnd+co+
  scale_fill_viridis_c(option="inferno",limits=blim,na.value="transparent",name="Built-up\n(% of cell)")+maptheme
map_c<-ggplot()+bg+geom_spatraster(data=as.factor(smod),alpha=1)+bnd+co+
  scale_fill_manual(values=setNames(smod_col,smod_lev),breaks=smod_lev,limits=smod_lev,drop=FALSE,
                    na.value="transparent",name="SMOD",na.translate=FALSE)+maptheme
map_d<-ggplot()+bg+geom_spatraster(data=urb_p,alpha=0.92)+bnd+co+
  scale_fill_viridis_c(option="inferno",limits=blim,na.value="transparent",name="Built-up\n(% of cell)")+maptheme

# round + frame the MAP only, via a grid roundrect mask in magick
MW<-1200; MH<-round(MW/aspect); rad<-40
round_map<-function(p){
  pf<-tempfile(fileext=".png"); ggsave(pf,p,width=MW/150,height=MH/150,dpi=150,bg="white")
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
        size=15, x=0.01, hjust=0, y=0.15, vjust=0)
  cowplot::plot_grid(ttl, row, ncol=1, rel_heights=c(0.06,1))
}
P <- list(
  panel(map_a,"(a) Satellite Basemap (Reference)", withleg=FALSE),
  panel(map_b,"(b) GHS-BUILT-S: Built-up Surface"),
  panel(map_c,"(c) GHS-SMOD: Degree of Urbanisation"),
  panel(map_d,"(d) Urban-Masked Built-up (Analysis Input)"))
fig<-cowplot::plot_grid(plotlist=P, nrow=2, ncol=2)
out<-here("04_outputs/figures/metadata_layers.png")
cowplot::save_plot(out, fig, base_width=9.6, base_height=2*9.6/2/aspect+1.4, bg="white")
cat("wrote", out, "\n")
