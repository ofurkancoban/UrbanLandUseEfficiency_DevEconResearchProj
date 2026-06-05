library(sf)
library(dplyr)
library(leaflet)
library(htmltools)
library(htmlwidgets)
library(rnaturalearth)
library(rnaturalearthdata)
library(here)
library(readr)
library(terra)

sf_use_s2(FALSE)

un_gdp <- read_csv(here("03_datasets/raw/un_gdp_per_capita.csv"), show_col_types = FALSE) |>
  filter(year == 2020) |>
  transmute(iso3, gdp_pc = gdp_pc_un)

# Country polygons for the GDP choropleth = REAL GAUL 2025 L1 dissolved to country
# level, so its borders match the GAUL WMS layers (no NaturalEarth mismatch).
# Downloaded by 01_data_preprocessing/04_download_gaul2025.R (cols are lowercase).
# Simplified for size.
adm0 <- sf::st_read("03_datasets/raw/GAUL_2025_L1/gaul_2025_l1.shp", quiet = TRUE) |>
  st_transform(4326) |>
  st_make_valid() |>
  st_simplify(dTolerance = 0.02, preserveTopology = TRUE) |>
  group_by(iso_join = iso3_code, name = gaul0_name) |>
  summarise(.groups = "drop") |>
  st_make_valid() |>
  st_collection_extract("POLYGON") |>   # dissolve can yield GEOMETRYCOLLECTIONs
  st_cast("MULTIPOLYGON") |>
  left_join(un_gdp, by = c("iso_join" = "iso3"))

# Boundaries ONLINE from FAO GeoServer WMS (real, full detail, global, embedded-free):
#  - Country lines: UN Clear Map "bndl" (style unmap_boundary_lines = clean lines)
#  - Sub-national : GAUL 2025 L1 / L2 (style gaul_2024_style = grey fill + outline)
fao_bnd_wms  <- "https://data.apps.fao.org/map/gsrv/gsrv1/boundaries/wms"
fao_gaul_wms <- "https://data.apps.fao.org/map/gsrv/gsrv1/gaul/wms"

# Custom border colours while staying ONLINE: send an inline SLD (SLD_BODY) to the
# GeoServer WMS -> recolours the stroke and drops the grey fill (outline only).
sld_doc <- function(layer, symb) sprintf(
  '<?xml version="1.0" encoding="UTF-8"?><StyledLayerDescriptor version="1.0.0" xmlns="http://www.opengis.net/sld"><NamedLayer><Name>%s</Name><UserStyle><FeatureTypeStyle><Rule>%s</Rule></FeatureTypeStyle></UserStyle></NamedLayer></StyledLayerDescriptor>',
  layer, symb)
stroke  <- function(color, w) sprintf('<Stroke><CssParameter name="stroke">%s</CssParameter><CssParameter name="stroke-width">%s</CssParameter></Stroke>', color, w)
sld_l0   <- sld_doc("gaul_2024_l0", sprintf('<PolygonSymbolizer>%s</PolygonSymbolizer>', stroke("#FFFFFF", 1.6))) # countries: white (GAUL L0)
sld_l1   <- sld_doc("gaul_2025_l1", sprintf('<PolygonSymbolizer>%s</PolygonSymbolizer>', stroke("#00E5FF", 1.6))) # regions: cyan
sld_l2   <- sld_doc("gaul_2025_l2", sprintf('<PolygonSymbolizer>%s</PolygonSymbolizer>', stroke("#00E5FF", 0.7))) # districts: cyan

# map window (Oldenburg / NW Germany), lon/lat
crop_ll <- terra::vect(terra::ext(7.5, 9.0, 52.8, 53.6), crs = "EPSG:4326")

# ── GHSL built-up local raster (100 m, 2020) — OPTIONAL (kept if the tif exists) ──
ghsl_tif  <- here("03_datasets/raw/GHS_BUILT_S_E2020_GLOBE_R2023A_54009_100_V1_0/GHS_BUILT_S_E2020_GLOBE_R2023A_54009_100_V1_0.tif")
have_ghsl <- file.exists(ghsl_tif)
if (have_ghsl) {
  ghsl_full <- terra::rast(ghsl_tif)
  if (is.na(terra::crs(ghsl_full)) || terra::crs(ghsl_full) == "") terra::crs(ghsl_full) <- "ESRI:54009"
  ghsl_crop <- terra::crop(ghsl_full, terra::ext(terra::project(crop_ll, terra::crs(ghsl_full))))
  ghsl_crop[ghsl_crop <= 0] <- NA
  built_max <- as.numeric(terra::global(ghsl_crop, "max", na.rm = TRUE))
  if (!is.finite(built_max) || built_max <= 0) built_max <- 10000
  built_pal <- colorNumeric(c("#000004","#420a68","#932667","#dd513a","#fca50a","#fcffa4"),
                            domain = c(0, built_max), na.color = "transparent")
}

# ── GHS-SMOD (DEGURBA) layer, cropped to the window (1 km, ESRI:54009) ──
smod_tif  <- here("03_datasets/raw/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0.tif")
smod_full <- terra::rast(smod_tif)
if (is.na(terra::crs(smod_full)) || terra::crs(smod_full) == "") terra::crs(smod_full) <- "ESRI:54009"
smod_crop <- terra::crop(smod_full, terra::ext(terra::project(crop_ll, terra::crs(smod_full))))
smod_crop[smod_crop == 10] <- NA
smod_lvls <- c(11,12,13,21,22,23,30)
smod_cols <- c("#cdf57a","#abcd66","#375623","#ffff00","#a87000","#732600","#ff0000")
smod_labs <- c("Very low rural","Low rural","Rural cluster","Suburban / peri-urban",
               "Semi-dense cluster","Dense cluster","Urban centre")
smod_pal  <- colorFactor(smod_cols, domain = smod_lvls, na.color = "transparent")

# previous release WMS (online) for comparison
ghsl_wms <- "https://jeodpp.jrc.ec.europa.eu/jeodpp/services/ows/wms/landcover/ghsl"
built_pal_2018 <- colorNumeric(hcl.colors(64, "Plasma"), domain = c(0, 100), na.color = "transparent")

bins <- c(0, 1000, 3000, 10000, 30000, 60000, Inf)
pal <- colorBin("YlGnBu", domain = adm0$gdp_pc, bins = bins, na.color = "#ECEFF1")

g_smod <- "GHS-SMOD (DEGURBA) · 2020 · 1 km"
g_b18  <- "GHSL Built-up · 2018 · 10 m · R2022A"
g_b20  <- "GHSL Built-up · 2020 · 100 m · R2023A"
g_gaul <- "GAUL Level 0 (Countries) · FAO WMS"
g_adm1 <- "GAUL Level 1 (Regions) · FAO WMS"
g_adm2 <- "GAUL Level 2 (Districts) · FAO WMS"
g_wdi  <- "UN GDP per Capita (2020)"

lmap <- leaflet(options = leafletOptions(minZoom = 1, maxZoom = 18, worldCopyJump = FALSE, preferCanvas = TRUE)) |>
  addProviderTiles(providers$Esri.WorldImagery, options = tileOptions(opacity = 1), group = "World Imagery (XYZ)") |>
  addWMSTiles(baseUrl = ghsl_wms, layers = "LC.GHS_BUILT_S_E2018_GLOBE_R2022A_54009_10_V1_0",
    options = WMSTileOptions(format="image/png", transparent=TRUE, opacity=0.8, version="1.3.0", maxZoom=18),
    group = g_b18, attribution = "© EC JRC — GHS-BUILT-S R2022A, Sentinel-2, 2018")

if (have_ghsl) lmap <- lmap |> addRasterImage(ghsl_crop, colors = built_pal, opacity = 0.85,
    project = TRUE, method = "ngb", maxBytes = 12*1024*1024, group = g_b20,
    attribution = "© European Union — GHS-BUILT-S R2023A, 100 m, 2020 (CC BY 4.0)")

lmap <- lmap |> addRasterImage(smod_crop, colors = smod_pal, opacity = 0.8, project = TRUE,
    method = "ngb", maxBytes = 8*1024*1024, group = g_smod,
    attribution = "© European Union — GHS-SMOD R2023A, 1 km, 2020 (CC BY 4.0)") |>
  addWMSTiles(baseUrl = fao_gaul_wms, layers = "gaul_2024_l0",
    options = WMSTileOptions(format="image/png", transparent=TRUE, opacity=0.95, version="1.3.0",
                             styles="", sld_body = sld_l0),
    group = g_gaul, attribution = "© FAO — GAUL 2024 L0 (CC BY 4.0)") |>
  addWMSTiles(baseUrl = fao_gaul_wms, layers = "gaul_2025_l1",
    options = WMSTileOptions(format="image/png", transparent=TRUE, opacity=0.95, version="1.3.0",
                             styles="", sld_body = sld_l1),
    group = g_adm1, attribution = "© FAO — GAUL 2025 L1 (CC BY 4.0)") |>
  addPolygons(data = adm0[!is.na(adm0$gdp_pc), ], fillColor = ~pal(gdp_pc), fillOpacity = 0.7, color = "#4A4A4A",
    weight = 0.8, opacity = 0.8, group = g_wdi,
    label = ~paste0(name, ": ", ifelse(is.na(gdp_pc), "No Data", paste0("$", formatC(round(gdp_pc), big.mark = ",", format = "d")))),
    labelOptions = labelOptions(style=list("font-size"="11px"), direction="auto")) |>
  addLegend(pal = built_pal_2018, values = c(0,100), opacity = 0.8,
    title = "GHSL built-up 2018 (m² / 10 m cell)", position = "bottomleft", group = g_b18)

if (have_ghsl) lmap <- lmap |> addLegend(pal = built_pal, values = c(0, built_max), opacity = 0.85,
    title = "GHSL built-up (m² / 100 m cell)", position = "bottomleft", group = g_b20)

lmap <- lmap |>
  addLegend(colors = smod_cols, labels = smod_labs, opacity = 0.8,
    title = "GHS-SMOD (urban = SMOD &ge; 21)", position = "bottomright", group = g_smod) |>
  addLegend(pal = pal, values = na.omit(adm0$gdp_pc), opacity = 0.7,
    title = "GDP per capita (constant 2020 US$)", position = "bottomright", group = g_wdi)

grps <- c(g_b18, if (have_ghsl) g_b20, g_smod, g_gaul, g_adm1, g_wdi)
lmap <- lmap |>
  addLayersControl(overlayGroups = grps, options = layersControlOptions(collapsed = FALSE)) |>
  hideGroup(grps) |>
  setView(lng = 8.182224, lat = 53.147084, zoom = 17)

# Hover names via WMS GetFeatureInfo (online, no embedding). GAUL L1/L2 are
# queryable; show country / region / district for whichever GAUL layer is visible.
lmap <- lmap |> htmlwidgets::onRender(r"---(
function(el, x) {
  var map = this;
  var GAUL = 'https://data.apps.fao.org/map/gsrv/gsrv1/gaul/wms';
  var tip = document.createElement('div');
  tip.style.cssText = 'position:absolute;z-index:1000;pointer-events:none;background:rgba(20,20,20,0.82);color:#fff;padding:3px 8px;border-radius:4px;font:12px/1.3 sans-serif;display:none;white-space:nowrap;box-shadow:0 1px 4px rgba(0,0,0,0.4);';
  el.appendChild(tip);
  function pick() {
    var l2=false, l1=false, b=false;
    map.eachLayer(function(l){ if (l.wmsParams && l.wmsParams.layers){ var L=l.wmsParams.layers;
      if (L.indexOf('gaul_2025_l2')>-1) l2=true; else if (L.indexOf('gaul_2025_l1')>-1) l1=true; else if (L.indexOf('gaul_2024_l0')>-1) b=true; } });
    if (l2) return 2; if (l1) return 1; if (b) return 0; return -1;
  }
  var busy = false;
  map.on('mousemove', function(e){
    var lvl = pick();
    if (lvl < 0) { tip.style.display='none'; return; }
    if (busy) return; busy = true; setTimeout(function(){ busy=false; }, 110);
    var ql = (lvl===2) ? 'gaul_2025_l2' : 'gaul_2025_l1';
    var sz = map.getSize(), bnd = map.getBounds();
    var sw = map.options.crs.project(bnd.getSouthWest()), ne = map.options.crs.project(bnd.getNorthEast());
    var p = e.containerPoint;
    var url = GAUL + '?service=WMS&version=1.1.1&request=GetFeatureInfo&info_format=application/json&feature_count=1'
      + '&layers=' + ql + '&query_layers=' + ql + '&srs=EPSG:3857'
      + '&bbox=' + [sw.x,sw.y,ne.x,ne.y].join(',')
      + '&width=' + sz.x + '&height=' + sz.y + '&x=' + Math.round(p.x) + '&y=' + Math.round(p.y);
    fetch(url).then(function(r){ return r.json(); }).then(function(d){
      if (!d.features || !d.features.length) { tip.style.display='none'; return; }
      var pr = d.features[0].properties, parts = [];
      if (lvl>=2 && pr.gaul2_name) parts.push(pr.gaul2_name);
      if (lvl>=1 && pr.gaul1_name) parts.push(pr.gaul1_name);
      if (pr.gaul0_name) parts.push(pr.gaul0_name);
      if (!parts.length) { tip.style.display='none'; return; }
      tip.innerHTML = parts.join(', ');
      tip.style.left = (p.x + 14) + 'px'; tip.style.top = (p.y + 14) + 'px'; tip.style.display = 'block';
    }).catch(function(){ tip.style.display='none'; });
  });
  map.on('mouseout', function(){ tip.style.display='none'; });

  // --- sync overlay layers across windows (speaker view <-> main) via BroadcastChannel ---
  try {
    var bc = new BroadcastChannel('dsmap-sync');
    var suppress = false;
    map.on('overlayadd overlayremove', function(e){
      if (suppress) return;
      bc.postMessage({ a: (e.type === 'overlayadd' ? 'add' : 'rm'), n: e.name });
    });
    map.on('moveend', function(){
      if (suppress) return;
      var c = map.getCenter();
      bc.postMessage({ a: 'view', lat: c.lat, lng: c.lng, z: map.getZoom() });
    });
    bc.onmessage = function(ev){
      var d = ev.data;
      if (d.a === 'view') {
        suppress = true;
        map.setView([d.lat, d.lng], d.z, { animate: false });
        setTimeout(function(){ suppress = false; }, 150);
        return;
      }
      suppress = true;
      var labels = el.querySelectorAll('.leaflet-control-layers-overlays label');
      for (var i = 0; i < labels.length; i++) {
        var lb = labels[i];
        if (lb.textContent.trim() === d.n) {
          var cb = lb.querySelector('input[type=checkbox]');
          if (cb && cb.checked !== (d.a === 'add')) cb.click();
        }
      }
      setTimeout(function(){ suppress = false; }, 80);
    };
  } catch (err) {}
}
)---")

out <- here("04_presentation/figures/data_sources_map.html")
saveWidget(lmap, file = out, selfcontained = FALSE,
           libdir = here("04_presentation/figures/data_sources_map_files"), title = "Data Sources Map")
html_txt <- readLines(out, warn = FALSE)
html_txt <- sub("</head>", '<style>html,body{background:transparent!important;margin:0;padding:0;}</style>\n</head>', html_txt, fixed = TRUE)
writeLines(html_txt, out)
cat("Saved:", out, "| GHSL local layer:", have_ghsl, "\n")
