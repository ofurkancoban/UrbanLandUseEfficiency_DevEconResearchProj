# ============================================================================
# 09_deu_kreis_casestudy.R
# Supplementary sub-national case study (Germany, Kreis level).
# GHSL urban built-up V, urban population P, urban area A aggregated to GAUL L2
# German districts (5-yr epochs), matched to INKAR controls (GDP per capita 546,
# internal net migration 166) by district name + type. Builds the analysis panel
# read by 05_paper/supplementary.qmd.
# Output: 03_datasets/processed/deu_kreis_casestudy.csv
# Zonal sums use native 100 m scale (urban population/built-up levels are correct,
# so the urban-population share is meaningful); this makes the GEE step slow.
# Needs: GEE credentials (or your own login) + the inkaR package.
# ============================================================================
suppressMessages({library(reticulate); library(inkaR); library(dplyr); library(tidyr)})
pr <- here::here(); setwd(pr)
source(file.path(pr,"02_scripts/00_setup/01_encryption_utils.R")); my_password <- "OmerFurkanCoban"
load_secure_secrets(my_password, file.path(pr,"03_datasets/config/secrets.enc"))
load_ee_credentials(my_password, file.path(pr,"03_datasets/config/ee_credentials.enc"))
ee <- reticulate::import("ee"); ee$Initialize(project = Sys.getenv("GEE_PROJECT"))

years <- seq(1985, 2020, by = 5); URBAN <- 21L
smodC <- ee$ImageCollection("JRC/GHSL/P2023A/GHS_SMOD")
builtC<- ee$ImageCollection("JRC/GHSL/P2023A/GHS_BUILT_S")
popC  <- ee$ImageCollection("JRC/GHSL/P2023A/GHS_POP")
l2 <- ee$FeatureCollection("projects/sat-io/open-datasets/FAO/GAUL/GAUL_2024_L2")$
  filter(ee$Filter$eq("iso3_code","DEU"))
yi <- function(c,b,y) ee$Image(c$filterDate(paste0(y,"-01-01"),paste0(y,"-12-31"))$first())$select(b)
out <- list()
for (yr in years) {
  urb <- yi(smodC,"smod_code",yr)$gte(URBAN)
  img <- yi(builtC,"built_surface",yr)$updateMask(urb)$rename("V")$
         addBands(yi(popC,"population_count",yr)$updateMask(urb)$rename("P"))$
         addBands(ee$Image$pixelArea()$updateMask(urb)$rename("A"))
  fc <- img$reduceRegions(collection=l2, reducer=ee$Reducer$sum(), scale=100, tileScale=16)$
        map(function(f) f$setGeometry(NULL))
  d <- bind_rows(lapply(fc$getInfo()$features, function(f) as.data.frame(f$properties, stringsAsFactors=FALSE)))
  d$year <- yr; out[[as.character(yr)]] <- d
}
ghsl <- bind_rows(out)

clean <- function(x){x<-tolower(x); x<-gsub("[- ]*urban$","",x); x<-gsub(",.*$","",x); x<-gsub("\\s*\\(.*\\)","",x)
  x<-gsub("ä","ae",x);x<-gsub("ö","oe",x);x<-gsub("ü","ue",x);x<-gsub("ß","ss",x); trimws(gsub("[^a-z]","",x))}
tg <- function(x) ifelse(grepl("urban",x,ignore.case=TRUE),"S","L")
ti <- function(x) ifelse(grepl("stadt|kreisfrei",x,ignore.case=TRUE),"S","L")

g <- ghsl |> filter(gaul2_name!="Waterbody") |>
  mutate(key=paste0(clean(gaul2_name),"|",tg(gaul2_name))) |> arrange(gaul2_name,year) |> group_by(gaul2_name) |>
  mutate(bpcr=log((V/P)/dplyr::lag(V/P))/5, pgr_log=log(P/dplyr::lag(P))/5, lcr_log=log(V/dplyr::lag(V))/5,
         lcrpgr_log=ifelse(pgr_log!=0,lcr_log/pgr_log,NA), ln_density=log(P/(A/1e6))) |> ungroup()
gu <- g |> count(key,year) |> filter(n==1) |> distinct(key)

F <- function(id) as.data.frame(get_inkar_data(id, level="KRE")) |>
  transmute(Kennziffer, Raumeinheit, Zeit=as.integer(Zeit), val=Wert)
mig <- F("166"); gdp <- F("546"); tot <- F("xbev")
ik <- mig |> distinct(Kennziffer,Raumeinheit) |> mutate(key=paste0(clean(Raumeinheit),"|",ti(Raumeinheit)))
iu <- ik |> count(key) |> filter(n==1) |> distinct(key); ok <- intersect(gu$key, iu$key)
ep <- c(1995,2000,2005,2010,2015,2020)
migE <- bind_rows(lapply(ep, function(e) mig |> inner_join(ik,by=c("Kennziffer","Raumeinheit")) |>
  filter(key%in%ok, Zeit>e-5, Zeit<=e) |> group_by(key) |> summarise(int_migr=mean(val,na.rm=TRUE),.groups="drop") |> mutate(year=e)))
gdpE <- gdp |> inner_join(ik,by=c("Kennziffer","Raumeinheit")) |> filter(key%in%ok, Zeit%in%ep) |>
  transmute(key, year=Zeit, ln_gdp=log(val))
totE <- tot |> inner_join(ik,by=c("Kennziffer","Raumeinheit")) |> filter(key%in%ok, Zeit%in%ep) |>
  transmute(key, year=Zeit, total_pop=val)

d <- g |> filter(key%in%ok, year%in%ep, !is.na(bpcr), is.finite(lcrpgr_log)) |>
  inner_join(migE,by=c("key","year")) |> inner_join(gdpE,by=c("key","year")) |> inner_join(totE,by=c("key","year")) |>
  mutate(urban_pop_share = P/total_pop) |>
  transmute(kreis=gaul2_name, key, year, V, P, A, total_pop, bpcr, pgr_log, lcr_log, lcrpgr_log,
            ln_density, urban_pop_share, ln_gdp, int_migr)
write.csv(d, "03_datasets/processed/deu_kreis_casestudy.csv", row.names=FALSE)
cat("wrote deu_kreis_casestudy.csv:", nrow(d), "district-periods |", dplyr::n_distinct(d$key), "districts\n")
