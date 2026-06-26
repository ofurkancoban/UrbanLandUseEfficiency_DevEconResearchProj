# ==============================================================================
# File:          05_fig_desc_trend_regional.R
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
# Description:   Generates regional representative trend plots (BpCR and LCRPGR) 
#                for 7 countries.
# ==============================================================================
suppressMessages({library(tidyverse); library(plotly); library(htmlwidgets)})
setwd(here::here())

reps <- c(CHN="China", USA="United States", DEU="Germany", BRA="Brazil",
          NGA="Nigeria", IND="India", JPN="Japan")
cols <- c(China="#e8000b", `United States`="#1f77b4", Germany="#2ca02c",
          Brazil="#ff7f0e", Nigeria="#7b3294", India="#8c564b", Japan="#e377c2")

d <- read_csv("03_datasets/processed/reg_panel_urban.csv", show_col_types = FALSE) |>
  filter(year >= 1980, year <= 2020, iso3 %in% names(reps)) |>
  mutate(country = factor(reps[iso3], levels = names(cols))) |>
  arrange(country, year)

mk <- function(yvar, showleg) {
  p <- plot_ly()
  for (cn in names(cols)) {
    s <- d |> filter(country == cn)
    p <- add_trace(p, data = s, x = ~year, y = s[[yvar]], type = "scatter",
      mode = "lines+markers", name = cn, legendgroup = cn, showlegend = showleg,
      line = list(color = cols[[cn]], width = 2.5),
      marker = list(color = cols[[cn]], size = 7),
      hovertemplate = paste0("<b>", cn, "</b><br>%{x}: %{y:.4f}<extra></extra>"))
  }
  p |> layout(xaxis = list(title = "", gridcolor = "rgba(0,0,0,0.07)", dtick = 5,
                           zeroline = FALSE, tickfont = list(size = 13)),
              yaxis = list(gridcolor = "rgba(0,0,0,0.07)", zerolinecolor = "rgba(0,0,0,0.25)",
                           tickfont = list(size = 13)),
              shapes = list(list(type = "line", x0 = 1990, x1 = 2020, y0 = 0, y1 = 0,
                                 line = list(color = "rgba(0,0,0,0.3)", dash = "dash", width = 1))))
}

p1 <- mk("bpcr", TRUE)
p2 <- mk("lcrpgr", FALSE)        # metadata-official LCRPGR = arithmetic LCR / log PGR

fig <- subplot(p2, p1, nrows = 1, margin = 0.055, titleX = TRUE) |>
  layout(
    title = list(text = "<b>Urban Land Efficiency Trends: Regional Representatives</b><br><sup style='color:#888'>5-year periods, 1980-2020</sup>",
                 x = 0.5, xanchor = "center", font = list(size = 23)),
    annotations = list(
      list(text = "<b>LCRPGR (official: LCR / PGR)</b>", x = 0.21, y = 1.0, xref = "paper", yref = "paper",
           showarrow = FALSE, font = list(size = 15)),
      list(text = "<b>BpCR (log difference)</b>", x = 0.80, y = 1.0, xref = "paper", yref = "paper",
           showarrow = FALSE, font = list(size = 15))),
    legend = list(orientation = "h", x = 0.5, xanchor = "center", y = -0.26, yanchor = "top",
                  font = list(size = 14), bgcolor = "rgba(0,0,0,0)",
                  entrywidth = 150, entrywidthmode = "pixels", itemsizing = "constant"),
    margin = list(t = 70, b = 120, l = 50, r = 20),
    paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
    font = list(family = "DM Sans, sans-serif", color = "#222")
  ) |> config(displayModeBar = FALSE, responsive = TRUE)

# Save with libdir RELATIVE to the html's own directory (bare name) so the
# baked-in asset paths resolve correctly under 04_outputs/figures/.
out_dir <- here::here("04_outputs/figures")
out     <- file.path(out_dir, "desc_trend_regional.html")
withr::with_dir(out_dir,
  saveWidget(fig, "desc_trend_regional.html", selfcontained = FALSE,
             libdir = "desc_trend_regional_files", title = "Regional Trends"))
# transparent page background
h <- readLines(out, warn = FALSE)
h <- sub("</head>", "<style>html,body{background:transparent!important;margin:0;padding:0;}</style>\n</head>", h, fixed = TRUE)
writeLines(h, out)
cat("wrote", out, "| countries:", n_distinct(d$country), "| rows:", nrow(d), "\n")
