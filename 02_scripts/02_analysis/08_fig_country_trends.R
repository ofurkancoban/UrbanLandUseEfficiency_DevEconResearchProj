# ============================================================================
# 08_fig_country_trends.R
# Static two-panel country-trend figure for the paper: official log-LCRPGR (left)
# vs BpCR (right) for seven regional representatives, 1985-2020. Shows LCRPGR's
# erratic swings against BpCR's smooth, interpretable series.
# Output: 04_outputs/figures/country_trends.png
# ============================================================================
suppressMessages({library(here); library(readr); library(dplyr); library(tidyr)
  library(ggplot2); library(showtext); library(sysfonts)}); setwd(here::here())
lm_dir <- "~/Library/TinyTeX/texmf-dist/fonts/opentype/public/lm"
font_add("lmroman", regular=path.expand(file.path(lm_dir,"lmroman10-regular.otf")),
         bold=path.expand(file.path(lm_dir,"lmroman10-bold.otf")),
         italic=path.expand(file.path(lm_dir,"lmroman10-italic.otf")))
showtext_auto(); showtext_opts(dpi=300); ff<-"lmroman"

reps <- c(CHN="China", USA="United States", DEU="Germany", BRA="Brazil",
          NGA="Nigeria", IND="India", JPN="Japan")
cols <- c(China="#e8000b", `United States`="#1f77b4", Germany="#2ca02c",
          Brazil="#ff7f0e", Nigeria="#7b3294", India="#8c564b", Japan="#e377c2")
d <- read_csv("03_datasets/processed/reg_panel_urban.csv", show_col_types=FALSE) |>
  filter(year>=1985, year<=2020, iso3 %in% names(reps)) |>
  mutate(country=factor(reps[iso3], levels=names(cols)))

base_t <- theme_minimal(base_size=12, base_family=ff) +
  theme(plot.title=element_text(family=ff,face="bold",size=12.5),
        axis.title=element_text(family=ff,size=11),
        legend.title=element_blank(), legend.text=element_text(family=ff,size=10),
        legend.position="bottom", panel.grid.minor=element_blank(),
        plot.margin=margin(6,10,4,6))
pa <- ggplot(d, aes(year, lcrpgr_log, color=country)) +
  geom_hline(yintercept=c(0,1), linetype=c("solid","dashed"), color="grey60", linewidth=0.3) +
  geom_line(linewidth=0.7) + geom_point(size=1.1) +
  scale_color_manual(values=cols) +
  labs(title="(a) Official LCRPGR (log)", x=NULL, y="LCRPGR (log)") + base_t
pb <- ggplot(d, aes(year, bpcr, color=country)) +
  geom_hline(yintercept=0, color="grey60", linewidth=0.3) +
  geom_line(linewidth=0.7) + geom_point(size=1.1) +
  scale_color_manual(values=cols) +
  labs(title="(b) BpCR", x=NULL, y="BpCR") + base_t

library(patchwork)
fig <- pa + pb + plot_layout(guides="collect") &
  theme(legend.position="bottom") &
  guides(color=guide_legend(nrow=1, override.aes=list(linewidth=1.1)))
out <- here("04_outputs/figures/country_trends.png")
ggsave(out, fig, width=9.2, height=3.3, dpi=300, bg="white")
cat("wrote", out, "| rows:", nrow(d), "| countries:", n_distinct(d$country), "\n")
