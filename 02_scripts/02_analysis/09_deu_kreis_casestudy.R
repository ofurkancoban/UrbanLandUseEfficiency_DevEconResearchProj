# ==============================================================================
# File:          09_deu_kreis_casestudy.R
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
# Description:   Processes sub-national case study data for German districts 
#                (Kreis level) using GHSL and INKAR.
# ==============================================================================
suppressMessages({library(inkaR); library(dplyr); library(tidyr)})
pr <- here::here(); setwd(pr)
cachef <- "03_datasets/processed/_deu_ghsl_raw.rds"

# --- GHSL urban V/P/A per GAUL L2 district, cached (delete the .rds to refetch from GEE) ---
if (file.exists(cachef)) {
  ghsl <- readRDS(cachef)
} else {
  suppressMessages(library(reticulate))
  source(file.path(pr,"02_scripts/00_setup/01_encryption_utils.R")); my_password <- "OmerFurkanCoban"
  load_secure_secrets(my_password, file.path(pr,"03_datasets/config/secrets.enc"))
  load_ee_credentials(my_password, file.path(pr,"03_datasets/config/ee_credentials.enc"))
  ee <- reticulate::import("ee"); ee$Initialize(project = Sys.getenv("GEE_PROJECT"))
  years <- seq(1985, 2020, by = 5); URBAN <- 21L
  smodC <- ee$ImageCollection("JRC/GHSL/P2023A/GHS_SMOD")
  builtC<- ee$ImageCollection("JRC/GHSL/P2023A/GHS_BUILT_S")
  popC  <- ee$ImageCollection("JRC/GHSL/P2023A/GHS_POP")
  # district geographic area (km2) is carried through to disambiguate same-named city/rural twins
  l2 <- ee$FeatureCollection("projects/sat-io/open-datasets/FAO/GAUL/GAUL_2024_L2")$
    filter(ee$Filter$eq("iso3_code","DEU"))$
    map(function(f) f$set("garea", f$area(10)$divide(1e6)))
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
  ghsl <- bind_rows(out); saveRDS(ghsl, cachef)
}

# Match GAUL districts to INKAR Kreise on a cleaned base name, stripping the
# city/rural markers each source uses (GAUL "... Urban"; INKAR "..., Stadt" /
# "Landkreis ...") so that ~all 400 districts match, not only the unambiguous names.
base <- function(x){x<-tolower(x); x<-gsub("[- ]*urban$","",x); x<-gsub(",.*$","",x); x<-gsub("\\s*\\(.*\\)","",x)
  x<-gsub("ä","ae",x);x<-gsub("ö","oe",x);x<-gsub("ü","ue",x);x<-gsub("ß","ss",x)
  x<-gsub("landkreis|kreisfreie|landeshauptstadt|hansestadt|kreis|stadt","",x)
  trimws(gsub("[^a-z]","",x))}

# Collapse any same-named duplicate GAUL polygons (e.g. Regionalverband Saarbrücken
# is stored as two features) into one district per year before computing rates
g <- ghsl |> filter(gaul2_name!="Waterbody") |>
  group_by(gaul2_name, year) |>
  summarise(V=sum(V), P=sum(P), A=sum(A), garea=sum(garea), .groups="drop") |>
  arrange(gaul2_name,year) |> group_by(gaul2_name) |>
  mutate(bpcr=log((V/P)/dplyr::lag(V/P))/5, pgr_log=log(P/dplyr::lag(P))/5, lcr_log=log(V/dplyr::lag(V))/5,
         lcrpgr_log=ifelse(pgr_log!=0,lcr_log/pgr_log,NA), ln_density=log(P/(A/1e6)),
         bpcr_L=dplyr::lag(bpcr)) |> ungroup()   # lag on the full GHSL series, so the 1995 lag = BpCR(1990)
# GAUL key: base name; for same-named city/rural twins the smaller-area unit is the city (S).
# One row per district name (max area) so the key table never duplicates a district.
gkey <- g |> group_by(gaul2_name) |> summarise(garea=max(garea), .groups="drop") |>
  mutate(b=base(gaul2_name)) |> add_count(b, name="nb") |>
  group_by(b) |> mutate(gtype=if(n()==1) "" else ifelse(garea==min(garea),"S","L")) |> ungroup() |>
  transmute(gaul2_name, key=ifelse(nb==1,b,paste0(b,"|",gtype)))
g <- g |> left_join(gkey, by="gaul2_name")

F <- function(id) as.data.frame(get_inkar_data(id, level="KRE")) |>
  transmute(Kennziffer, Raumeinheit, Zeit=as.integer(Zeit), val=Wert)
mig <- F("166"); gdp <- F("546"); tot <- F("xbev")
# INKAR key: base name; within twins the member with an unambiguous Stadt/Landkreis
# marker fixes the type and the other takes the complement
ik <- mig |> distinct(Kennziffer,Raumeinheit) |>
  mutate(b=base(Raumeinheit), low=tolower(Raumeinheit),
         stadt=grepl("stadt|kreisfrei|hansestadt|landeshauptstadt",low), lk=grepl("landkreis",low)) |>
  add_count(b, name="nb") |> group_by(b) |>
  mutate(itype=if(n()==1) "" else if(any(stadt)&!all(stadt)) ifelse(stadt,"S","L")
               else if(any(lk)&!all(lk)) ifelse(lk,"L","S") else ifelse(row_number()==1,"S","L")) |>
  ungroup() |> mutate(key=ifelse(nb==1,b,paste0(b,"|",itype)))
ok <- intersect(unique(g$key), unique(ik$key))
ep <- c(1995,2000,2005,2010,2015,2020)
migE <- bind_rows(lapply(ep, function(e) mig |> inner_join(ik,by=c("Kennziffer","Raumeinheit")) |>
  filter(key%in%ok, Zeit>e-5, Zeit<=e) |> group_by(key) |> summarise(int_migr=mean(val,na.rm=TRUE),.groups="drop") |> mutate(year=e)))
gdpE <- gdp |> inner_join(ik,by=c("Kennziffer","Raumeinheit")) |> filter(key%in%ok, Zeit%in%ep) |>
  transmute(key, year=Zeit, ln_gdp=log(val))
totE <- tot |> inner_join(ik,by=c("Kennziffer","Raumeinheit")) |> filter(key%in%ok, Zeit%in%ep) |>
  transmute(key, year=Zeit, total_pop=val)

# Keep the 1990 epoch as a base row (controls NA) so the 1995 estimation row has a
# lagged DV and the dynamic GMM has the deeper-lag history; estimation rows are 1995-2020.
d <- g |> filter(key%in%ok, year>=1990, !is.na(bpcr), is.finite(lcrpgr_log)) |>
  left_join(migE,by=c("key","year")) |> left_join(gdpE,by=c("key","year")) |> left_join(totE,by=c("key","year")) |>
  mutate(urban_pop_share = P/total_pop) |>
  transmute(kreis=gaul2_name, key, year, V, P, A, total_pop, bpcr, bpcr_L, pgr_log, lcr_log, lcrpgr_log,
            ln_density, urban_pop_share, ln_gdp, int_migr) |>
  arrange(key, year)
write.csv(d, "03_datasets/processed/deu_kreis_casestudy.csv", row.names=FALSE)
nest <- sum(d$year >= 1995)
cat("wrote deu_kreis_casestudy.csv:", nest, "estimation district-periods (1995-2020) +",
    nrow(d)-nest, "base rows (1990) |", dplyr::n_distinct(d$key), "districts\n")
