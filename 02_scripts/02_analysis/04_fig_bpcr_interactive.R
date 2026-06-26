# ==============================================================================
# File:          04_fig_bpcr_interactive.R
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
# Description:   Generates interactive HTML maps and plots for the BpCR 
#                (Built-up per Capita Change Ratio).
# ==============================================================================

library(tidyverse)
library(sf)
library(rnaturalearth)
library(rnaturalearthdata)
library(leaflet)
library(plotly)
library(htmltools)
library(htmlwidgets)
library(here)

# ── Data ──────────────────────────────────────────────────────────────────────
# metadata-correct URBAN panel (DEGURBA / GHS-POP)
panel <- read_csv(here("03_datasets/processed/reg_panel_urban.csv"), show_col_types = FALSE)

country_bpcr <- panel |>
  filter(year <= 2020) |>                         # observed epochs (drop 2025/2030 projections)
  group_by(iso3) |>
  summarise(
    country_name = dplyr::first(na.omit(country_name)),
    region       = dplyr::first(na.omit(region)),
    income_group = dplyr::first(na.omit(income_group)),
    bpcr_mean    = mean(bpcr, na.rm = TRUE),
    .groups = "drop"
  ) |>
  filter(!is.na(bpcr_mean))

# Absolute thresholds: BpCR = 0 (theory), medians of each side (−0.006 / +0.010)
lvls <- c("Strong densification", "Mild densification",
          "Mild sprawl",          "Strong sprawl")

cat_colors <- c(
  "Strong densification" = "#4CAF96",
  "Mild densification"   = "#A8D8A8",
  "Mild sprawl"          = "#FA897B",
  "Strong sprawl"        = "#CC6B6B"
)

mech_lvls   <- c("Active densification", "Passive densification",
                 "Passive sprawl",        "Active sprawl")
# Distinct teal<->orange palette so this layer is not confused with the
# green/red BpCR Category layer (densification = cool, sprawl = warm).
mech_colors <- c(
  "Active densification"  = "#00695C",
  "Passive densification" = "#80CBC4",
  "Passive sprawl"        = "#FFB74D",
  "Active sprawl"         = "#E65100"
)

trend_lvls   <- c("Improving", "Stable", "Worsening")
trend_colors <- c(
  "Improving" = "#1976D2",
  "Stable"    = "#BDBDBD",
  "Worsening" = "#E53935"
)

# ── Active/Passive decomposition per country (regression sample: panel_fixed) ─
# Replicate panel_fixed filters from presentation.qmd
panel_fixed <- panel |>
  filter(!is.na(bpcr), !is.na(lcrpgr_log)) |>
  mutate(period_f = factor(year)) |>
  arrange(iso3, year) |>
  group_by(iso3) |>
  mutate(bpcr_L = lag(bpcr), lcrpgr_L = lag(lcrpgr_log)) |>
  ungroup() |>
  filter(!is.na(bpcr_L), !is.na(lcrpgr_L)) |>
  filter(!is.na(ln_gdp_pc), !is.na(net_migr_pct))

decomp_country <- panel_fixed |>
  filter(!is.na(lcr_log)) |>
  mutate(
    # dln_B = log growth of urban built-up itself (= lcr_log = bpcr + pgr_log).
    # Active vs passive depends on whether built-up grew alongside per-capita BpCR.
    dln_B     = lcr_log,
    land_type = case_when(
      bpcr > 0 & dln_B > 0  ~ "Active sprawl",
      bpcr > 0 & dln_B <= 0 ~ "Passive sprawl",
      bpcr < 0 & dln_B <= 0 ~ "Active densification",
      bpcr < 0 & dln_B > 0  ~ "Passive densification",
      TRUE                   ~ NA_character_
    )
  ) |>
  filter(!is.na(land_type)) |>
  group_by(iso3) |>
  add_count(name = "n_total") |>
  count(iso3, land_type, n_total) |>
  mutate(share = n / n_total * 100) |>
  slice_max(share, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(iso3, dominant_type = land_type, dominant_share = share, n_periods = n_total)

# ── BpCR trend: slope over last 3 periods (2010–2020) ─────────────────────────
# Classification: p < 0.10 + sign of slope (n=5 obs 2000–2020, df=3, t_crit≈2.35)
# p >= 0.10 → Stable (no statistically detectable trend)
trend_country <- panel |>
  filter(!is.na(bpcr), year >= 2000) |>
  group_by(iso3) |>
  filter(n() >= 2) |>
  summarise(
    bpcr_slope = coef(lm(bpcr ~ year))[2],
    bpcr_pval  = coef(summary(lm(bpcr ~ year)))[2, 4],
    .groups    = "drop"
  ) |>
  mutate(trend_dir = factor(case_when(
    bpcr_pval >= 0.10 ~ "Stable",
    bpcr_slope < 0    ~ "Improving",
    TRUE              ~ "Worsening"
  ), levels = trend_lvls))

# Join decomp + trend → country_bpcr
country_bpcr <- country_bpcr |>
  left_join(decomp_country,  by = "iso3") |>
  left_join(trend_country |> select(iso3, bpcr_slope, bpcr_pval, trend_dir), by = "iso3")

# Add Greenland using Denmark's values
dnk_row <- country_bpcr |> filter(iso3 == "DNK")
country_bpcr <- bind_rows(country_bpcr,
  tibble(
    iso3           = "GRL",
    country_name   = "Greenland (DNK territory)",
    region         = "Europe",
    income_group   = dnk_row$income_group,
    bpcr_mean      = dnk_row$bpcr_mean,
    dominant_type  = dnk_row$dominant_type,
    dominant_share = dnk_row$dominant_share,
    n_periods      = dnk_row$n_periods,
    bpcr_slope     = dnk_row$bpcr_slope,
    bpcr_pval      = dnk_row$bpcr_pval,
    trend_dir      = dnk_row$trend_dir
  )
)

# data-driven class breaks: theory split at 0, plus the median of each side
neg_med <- median(country_bpcr$bpcr_mean[country_bpcr$bpcr_mean <  0], na.rm = TRUE)
pos_med <- median(country_bpcr$bpcr_mean[country_bpcr$bpcr_mean >= 0], na.rm = TRUE)

country_bpcr <- country_bpcr |>
  mutate(
    category = factor(case_when(
      bpcr_mean <  neg_med ~ "Strong densification",
      bpcr_mean <   0      ~ "Mild densification",
      bpcr_mean <  pos_med ~ "Mild sprawl",
      TRUE                 ~ "Strong sprawl"
    ), levels = lvls),
    dominant_type = factor(dominant_type, levels = mech_lvls),
    trend_dir     = factor(trend_dir,     levels = trend_lvls),
    label_html = paste0(
      "<b>", country_name, "</b> (", iso3, ")<br>",
      "Region: ", region, "<br>",
      "Development group: <b>", ifelse(is.na(income_group), "N/A", as.character(income_group)), "</b><br>",
      "Mean BpCR: <b>", sprintf("%.5f", bpcr_mean), "</b><br>",
      "Classification: <b>", category, "</b><br>",
      "Trend (2000–2020): <b>",
      ifelse(!is.na(trend_dir),
        paste0(trend_dir, "  (slope: ", sprintf("%+.5f", bpcr_slope),
               "/yr, p=", sprintf("%.3f", bpcr_pval), ")"),
        "N/A"),
      "</b><br>",
      "Dominant mechanism: <b>",
      ifelse(!is.na(dominant_type),
        paste0(dominant_type, " (", round(dominant_share, 0), "% of periods)"),
        "N/A"),
      "</b>"
    )
  )

# ── Shapefile ─────────────────────────────────────────────────────────────────
world <- ne_countries(scale = "medium", returnclass = "sf") |>
  mutate(iso_join = ifelse(iso_a3 == "-99", iso_a3_eh, iso_a3)) |>
  select(iso_join, geometry)

map_data <- world |>
  left_join(country_bpcr, by = c("iso_join" = "iso3")) |>
  st_transform(crs = 4326)

# Country centroids for ISO labels
centroids <- map_data |>
  filter(!is.na(country_name)) |>
  st_centroid() |>
  mutate(
    lng        = st_coordinates(geometry)[, 1],
    lat        = st_coordinates(geometry)[, 2],
    short_name = iso_join
  ) |>
  st_drop_geometry()

# ── Palettes ──────────────────────────────────────────────────────────────────
pal <- colorFactor(
  palette  = unname(cat_colors),
  levels   = lvls,
  na.color = "#DDDDDD"
)

pal_mech <- colorFactor(
  palette  = unname(mech_colors[mech_lvls]),
  levels   = mech_lvls,
  na.color = "#DDDDDD"
)

pal_trend <- colorFactor(
  palette  = unname(trend_colors[trend_lvls]),
  levels   = trend_lvls,
  na.color = "#DDDDDD"
)

# ── Shared polygon options ────────────────────────────────────────────────────
poly_opts <- list(
  fillOpacity  = 0.85,
  color        = "white",
  weight       = 0.5,
  smoothFactor = 0.5,
  highlight    = highlightOptions(
    weight = 2, color = "#444", fillOpacity = 0.95, bringToFront = TRUE
  ),
  labelOptions = labelOptions(
    style     = list("font-size" = "12px", "padding" = "6px 10px"),
    direction = "auto"
  )
)

# ── Leaflet map ───────────────────────────────────────────────────────────────
lmap <- leaflet(map_data,
  height  = 480,
  options = leafletOptions(minZoom = 1, maxZoom = 8, worldCopyJump = FALSE)
) |>
  addProviderTiles(providers$CartoDB.PositronNoLabels,
    options = tileOptions(opacity = 0.5)) |>

  # Layer 1: BpCR Category (quintile choropleth)
  addPolygons(
    fillColor    = ~pal(category),
    fillOpacity  = poly_opts$fillOpacity,
    color        = poly_opts$color,
    weight       = poly_opts$weight,
    smoothFactor = poly_opts$smoothFactor,
    group        = "BpCR Category",
    highlight    = poly_opts$highlight,
    label        = ~lapply(label_html, HTML),
    labelOptions = poly_opts$labelOptions
  ) |>

  # Layer 2: Active vs Passive Mechanism
  addPolygons(
    fillColor    = ~pal_mech(dominant_type),
    fillOpacity  = poly_opts$fillOpacity,
    color        = poly_opts$color,
    weight       = poly_opts$weight,
    smoothFactor = poly_opts$smoothFactor,
    group        = "Active vs Passive",
    highlight    = poly_opts$highlight,
    label        = ~lapply(label_html, HTML),
    labelOptions = poly_opts$labelOptions
  ) |>

  # ISO labels
  addLabelOnlyMarkers(
    data         = centroids,
    lng          = ~lng,
    lat          = ~lat,
    label        = ~short_name,
    labelOptions = labelOptions(
      permanent  = TRUE, noHide = TRUE,
      direction  = "center", textOnly = TRUE,
      style      = list(
        "font-family" = "Plus Jakarta Sans, sans-serif",
        "font-size"   = "9px",
        "font-weight" = "600",
        "color"       = "#333",
        "text-shadow" = "0 0 3px #fff, 0 0 3px #fff"
      )
    )
  ) |>

  # Legend 1: BpCR quintile
  addLegend(
    position  = "bottomleft",
    pal       = pal,
    values    = ~category,
    title     = "BpCR Classification (1980–2020)",
    opacity   = 0.9,
    na.label  = "No data",
    className = "info legend legend-bpcr"
  ) |>

  # Layer 3: BpCR Trend Direction
  addPolygons(
    fillColor    = ~pal_trend(trend_dir),
    fillOpacity  = poly_opts$fillOpacity,
    color        = poly_opts$color,
    weight       = poly_opts$weight,
    smoothFactor = poly_opts$smoothFactor,
    group        = "BpCR Trend",
    highlight    = poly_opts$highlight,
    label        = ~lapply(label_html, HTML),
    labelOptions = poly_opts$labelOptions
  ) |>

  # Legend 2: Dominant mechanism
  addLegend(
    position  = "bottomleft",
    colors    = unname(mech_colors[mech_lvls]),
    labels    = mech_lvls,
    title     = "Dominant Mechanism",
    opacity   = 0.9,
    className = "info legend legend-mech"
  ) |>

  # Legend 3: BpCR trend
  addLegend(
    position  = "bottomleft",
    colors    = unname(trend_colors[trend_lvls]),
    labels    = trend_lvls,
    title     = "BpCR Trend (2000–2020)",
    opacity   = 0.9,
    className = "info legend legend-trend"
  ) |>

  # Toggle control
  addLayersControl(
    baseGroups = c("BpCR Category", "Active vs Passive", "BpCR Trend"),
    options    = layersControlOptions(collapsed = FALSE)
  ) |>

  setView(lng = 35, lat = 38, zoom = 4)

# ── Regional pie charts (plotly) ───────────────────────────────────────────────
grp_order <- c("LDC", "Developing", "Developed")
grp_short <- c("LDC" = "LDC", "Developing" = "Developing", "Developed" = "Developed")

n_reg   <- length(grp_order)
pie_gap <- 0.02
pie_w   <- (1 - pie_gap * (n_reg - 1)) / n_reg

pie_ann <- lapply(seq_along(grp_order), function(i) {
  x0 <- (i - 1) * (pie_w + pie_gap)
  x1 <- x0 + pie_w
  list(x = (x0+x1)/2, y = -0.12, xref = "paper", yref = "paper",
       text = grp_short[grp_order[i]], showarrow = FALSE,
       font = list(size = 15, color = "#222", family = "Plus Jakarta Sans, sans-serif"),
       align = "center", xanchor = "center")
})

# Build one set of pies (by development group) for a given classification column,
# so the pies switch in sync with the selected map layer.
build_pies <- function(class_col, lv, colors_x) {
  pd <- country_bpcr |>
    filter(!is.na(.data[[class_col]]), !is.na(income_group)) |>
    count(grp = income_group, cls = .data[[class_col]]) |>
    mutate(grp = factor(grp, levels = grp_order),
           cls = factor(as.character(cls), levels = lv)) |>
    complete(grp = factor(grp_order, levels = grp_order),
             cls = factor(lv, levels = lv), fill = list(n = 0)) |>
    group_by(grp) |> mutate(pct = ifelse(sum(n) > 0, n / sum(n) * 100, 0)) |> ungroup()
  fig <- plot_ly()
  for (i in seq_along(grp_order)) {
    g  <- grp_order[i]
    d  <- pd |> filter(grp == g)
    x0 <- (i - 1) * (pie_w + pie_gap); x1 <- x0 + pie_w
    fig <- fig |> add_trace(
      type   = "pie", labels = d$cls, values = d$n, name = g, sort = FALSE,
      domain = list(x = c(x0, x1), y = c(0, 1)),
      marker = list(colors = unname(colors_x[as.character(d$cls)]),
                    line = list(color = "white", width = 1)),
      textinfo = "percent", textposition = "inside", insidetextfont = list(size = 13),
      hovertemplate = paste0(
        "<b style='font-size:13px'>", g, "</b><br>",
        "<span style='color:%{color}'>&#9632;</span> <b>%{label}</b><br>",
        "Countries: <b>%{value}</b><br>Share: <b>%{percent}</b><extra></extra>"),
      showlegend = FALSE)
  }
  fig |> layout(annotations = pie_ann, margin = list(t = 10, b = 60, l = 5, r = 5),
                paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
                autosize = TRUE, height = 320) |>
    config(displayModeBar = FALSE, responsive = TRUE)
}

fig_pies_cat   <- build_pies("category",      lvls,       cat_colors)
fig_pies_mech  <- build_pies("dominant_type", mech_lvls,  mech_colors)
fig_pies_trend <- build_pies("trend_dir",     trend_lvls, trend_colors)

# ── Combine: leaflet + title + pies ───────────────────────────────────────────
title_div <- tags$div(
  style = "text-align:center; padding:10px 0 6px;",
  tags$b(style = "font-size:20px; color:#222; font-family:'Outfit',sans-serif; font-weight:700;",
    "Urban Land Consumption Efficiency: Global Distribution"),
  tags$br(),
  tags$span(style = "font-size:14px; color:#777; font-family:'Plus Jakarta Sans',sans-serif;",
    "Category: 1980–2020 | Trend: 2000–2020")
)

pies_title <- tags$div(
  style = "text-align:center; padding:6px 0 2px;",
  tags$b(style = "font-size:16px; color:#444; font-family:'Plus Jakarta Sans',sans-serif; font-weight:600;",
    "Distribution by Development Group (%)")
)

# ── Layer-specific classification boxes (toggle with the selected layer) ───────
chip <- function(color, label, rule) {
  paste0("<span style='display:inline-block; margin:4px 12px; font-size:15px; ",
         "font-family:\"Plus Jakarta Sans\",sans-serif; color:#333;'>",
         "<span style='display:inline-block;width:12px;height:12px;border-radius:3px;background:",
         unname(color), ";margin-right:6px;vertical-align:middle;'></span>",
         "<b>", label, ":</b> ", rule, "</span>")
}
expl_box <- function(cls, chips_html, note) {
  tags$div(class = cls,
    style = paste0("text-align:center; padding:10px 16px 8px; margin-top:8px; ",
                   "background:rgba(0,0,0,0.025); border:1px solid #e6e6e6; border-radius:12px;"),
    HTML(chips_html),
    tags$div(style = "font-size:15px; color:#777; margin-top:5px; font-family:'Plus Jakarta Sans',sans-serif;",
             HTML(note)))
}

expl_bpcr <- expl_box("expl-bpcr", paste0(
    chip(cat_colors["Strong densification"], "Strong densification", sprintf("BpCR &lt; %.3f", neg_med)),
    chip(cat_colors["Mild densification"],   "Mild densification",   sprintf("%.3f &le; BpCR &lt; 0", neg_med)),
    chip(cat_colors["Mild sprawl"],          "Mild sprawl",          sprintf("0 &le; BpCR &lt; %.3f", pos_med)),
    chip(cat_colors["Strong sprawl"],        "Strong sprawl",        sprintf("BpCR &ge; %.3f", pos_med))),
  "Country mean BpCR, 1980&ndash;2020. Thresholds: 0 (theory) and the median of each side.")

expl_mech <- expl_box("expl-mech", paste0(
    chip(mech_colors["Active sprawl"],         "Active sprawl",         "BpCR &gt; 0 &and; &Delta;B &gt; 0"),
    chip(mech_colors["Passive sprawl"],        "Passive sprawl",        "BpCR &gt; 0 &and; &Delta;B &le; 0"),
    chip(mech_colors["Active densification"],  "Active densification",  "BpCR &lt; 0 &and; &Delta;B &le; 0"),
    chip(mech_colors["Passive densification"], "Passive densification", "BpCR &lt; 0 &and; &Delta;B &gt; 0")),
  "&Delta;B = &Delta;ln(built-up) = BpCR + population growth. Active = total built-up also expanding.")

expl_trend <- expl_box("expl-trend", paste0(
    chip(trend_colors["Improving"], "Improving", "slope &lt; 0, p &lt; 0.10"),
    chip(trend_colors["Stable"],    "Stable",    "p &ge; 0.10"),
    chip(trend_colors["Worsening"], "Worsening", "slope &gt; 0, p &lt; 0.10")),
  "OLS slope of BpCR on year, 2000&ndash;2020. Improving = BpCR falling toward densification.")

combined <- browsable(tags$div(
  style = "background:transparent; width:100%;",
  title_div,
  tags$div(style = "height:480px; width:100%; border-radius:12px; overflow:hidden;", lmap),
  pies_title,
  # All three render visible (full width) at load; the wrapper clips to one row
  # so only the active set shows. Switching toggles display only (no resize).
  tags$div(style = "height:310px; overflow:hidden;",
    tags$div(class = "pies-bpcr",  style = "height:340px;", as_widget(fig_pies_cat)),
    tags$div(class = "pies-mech",  style = "height:340px;", as_widget(fig_pies_mech)),
    tags$div(class = "pies-trend", style = "height:340px;", as_widget(fig_pies_trend))
  ),
  expl_bpcr, expl_mech, expl_trend
))

# ── Save ───────────────────────────────────────────────────────────────────────
out <- here("04_presentation/figures/bpcr_interactive.html")
save_html(combined, out)

# Post-process: transparent bg + fonts + leaflet height fix
html_txt <- readLines(out, warn = FALSE)
legend_sync_js <- '
<script>
(function() {
  var LEG  = [".legend-bpcr", ".legend-mech", ".legend-trend"];
  var PIE  = [".pies-bpcr", ".pies-mech", ".pies-trend"];
  var EXPL = [".expl-bpcr", ".expl-mech", ".expl-trend"];
  function sync(activeIdx) {
    [LEG, PIE, EXPL].forEach(function(group) {
      group.forEach(function(cls, i) {
        var el = document.querySelector(cls);
        // pies/expl were rendered visible at load (correct width); switching is a
        // pure show/hide of the already-sized content (no resize needed).
        if (el) el.style.display = (i === activeIdx) ? "block" : "none";
      });
    });
  }
  var attempts = 0;
  var iv = setInterval(function() {
    attempts++;
    var base = document.querySelector(".leaflet-control-layers-base");
    if (base) {
      clearInterval(iv);
      base.addEventListener("change", function(e) {
        if (e.target.type !== "radio") return;
        var radios = base.querySelectorAll("input[type=radio]");
        var idx = Array.prototype.indexOf.call(radios, e.target);
        sync(idx);
      });
    }
    if (attempts > 150) clearInterval(iv);
  }, 100);
})();
</script>
'

html_txt <- sub("</head>", paste0(
  '<link rel="preconnect" href="https://fonts.googleapis.com">\n',
  '<link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@300;400;500;600;700&family=Outfit:wght@600;700;800&family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">\n',
  '<style>\n',
  '  html,body{background:transparent!important;margin:0;padding:0;}\n',
  '  .legend-mech{display:none;}\n',
  '  .legend-trend{display:none;}\n',
  '  .expl-mech{display:none;}\n',
  '  .expl-trend{display:none;}\n',
  '</style>\n',
  '</head>'
), html_txt, fixed = TRUE)

# Inject legend sync just before </body>
html_txt <- sub("</body>", paste0(legend_sync_js, '</body>'), html_txt, fixed = TRUE)
html_txt <- gsub('width:100%;height:400px;', 'width:100%;height:480px;', html_txt, fixed = TRUE)
writeLines(html_txt, out)

cat("Saved:", out, "\n")
