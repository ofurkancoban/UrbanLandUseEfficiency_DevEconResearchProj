# ============================================================================
# 24_dynamic_gmm.R
# Dynamic-panel GMM (Arellano-Bond diff + Blundell-Bond system) for the BpCR
# inertia coefficient, addressing the downward Nickell bias of the lagged-DV FE
# estimator. Computed here (plm attached) and saved so the presentation does NOT
# load plm (which would mask dplyr::lag used throughout the panel build).
# Output: 03_datasets/processed/dynamic_gmm.rds  (list: main, robust tibbles)
# ============================================================================
suppressMessages({library(plm); library(fixest); library(dplyr); library(readr); library(tidyr); library(here)})
setwd(here::here())  # project root (portable; works for any clone location)

stars <- function(p) ifelse(is.na(p), "", ifelse(p < .01, "***", ifelse(p < .05, "**", ifelse(p < .1, "*", ""))))
fc    <- function(est, se, p) {
  ifelse(is.na(est), "", sprintf("%+.4f%s<br>(%.4f)", est, stars(p), se))
}

ctl  <- "ln_urban_density + net_migr_pct + ln_gdp_pc + urban_pop_share"
terms_keep <- c("lag(bpcr, 1)", "ln_urban_density", "net_migr_pct", "ln_gdp_pc", "urban_pop_share")
term_lab   <- c("BpCR[t−1]", "ln(Urban Density)", "Net Migration (% Pop)",
                "ln(GDP per capita)", "Urban Pop. Share")
fe_terms   <- c("bpcr_L", "ln_urban_density", "net_migr_pct", "ln_gdp_pc", "urban_pop_share")

fmt_w <- function(x) ifelse(is.na(x), "–", sprintf("%.3f", x))
fmt_p <- function(x) ifelse(is.na(x), "–", sprintf("%.2f", x))

run_ols <- function(d) {   # pure pooled OLS (no FE): upper bound for rho (Bond 2002)
  d <- filter(d, !is.na(bpcr_L))
  m <- feols(bpcr ~ bpcr_L + ln_urban_density + net_migr_pct + ln_gdp_pc + urban_pop_share, d, vcov = ~iso3)
  ct <- coeftable(m)
  list(coef = setNames(fc(ct[fe_terms, 1], ct[fe_terms, 2], ct[fe_terms, 4]), fe_terms),
       nobs = nobs(m), nc = n_distinct(d$iso3), wr2 = unname(r2(m)["ar2"]),  # adjusted R^2 (no FE)
       cfe = "No", pfe = "No", sargan = NA, ar2 = NA)
}
run_fe <- function(d) {
  d <- filter(d, !is.na(bpcr_L))   # bpcr_L is lagged on the full series (deck-consistent)
  m <- feols(bpcr ~ bpcr_L + ln_urban_density + net_migr_pct + ln_gdp_pc + urban_pop_share |
             iso3 + factor(year), d, vcov = ~iso3)
  ct <- coeftable(m)
  list(coef = setNames(fc(ct[fe_terms, 1], ct[fe_terms, 2], ct[fe_terms, 4]), fe_terms),
       nobs = nobs(m), nc = n_distinct(d$iso3), wr2 = unname(r2(m)["wr2"]),
       cfe = "Yes", pfe = "Yes", sargan = NA, ar2 = NA)
}
run_gmm <- function(d, instr, eff, mod, tr) {
  d  <- d |> arrange(iso3, year) |> mutate(t = as.integer(factor(year)))
  pd <- pdata.frame(as.data.frame(d), index = c("iso3", "t"))
  f  <- as.formula(paste("bpcr ~ lag(bpcr,1) +", ctl, "|", instr))
  m  <- pgmm(f, data = pd, effect = eff, model = mod, transformation = tr, collapse = TRUE)
  s  <- summary(m, robust = TRUE)
  cf <- s$coefficients
  list(coef = setNames(fc(cf[terms_keep, 1], cf[terms_keep, 2], cf[terms_keep, 4]), terms_keep),
       nobs = sum(lengths(m$residuals)), nc = length(m$residuals), wr2 = NA,
       cfe = "Yes", pfe = "Yes", sargan = s$sargan$p.value, ar2 = s$m2$p.value)
}

build_tab <- function(d, instr, full = FALSE) {
  fe <- run_fe(d)
  ab <- run_gmm(d, instr, "twoways", "twosteps", "d")
  bb <- run_gmm(d, instr, "twoways", "twosteps", "ld")
  cv <- function(m, keys) unname(m$coef[keys])
  if (!full) {
    body <- tibble(Term = term_lab,
      `FE (within)` = cv(fe, fe_terms), `Arellano-Bond` = cv(ab, terms_keep), `Blundell-Bond` = cv(bb, terms_keep))
    diag <- tibble(Term = c("Observations", "Countries", "Sargan (p)", "AR(2) (p)"),
      `FE (within)`   = c(format(fe$nobs, big.mark = ","), as.character(fe$nc), "–", "–"),
      `Arellano-Bond` = c(format(ab$nobs, big.mark = ","), as.character(ab$nc), fmt_p(ab$sargan), fmt_p(ab$ar2)),
      `Blundell-Bond` = c(format(bb$nobs, big.mark = ","), as.character(bb$nc), fmt_p(bb$sargan), fmt_p(bb$ar2)))
    return(bind_rows(body, diag))
  }
  ols <- run_ols(d)
  body <- tibble(Term = term_lab,
    `Pooled OLS` = cv(ols, fe_terms), `FE (within)` = cv(fe, fe_terms),
    `Arellano-Bond` = cv(ab, terms_keep), `Blundell-Bond` = cv(bb, terms_keep))
  dd <- function(g) c(format(g$nobs, big.mark = ","), fmt_w(g$wr2), g$cfe, g$pfe, fmt_p(g$sargan), fmt_p(g$ar2))
  diag <- tibble(Term = c("Observations", "R²", "Country FE", "Period FE", "Sargan (p)", "AR(2) (p)"),
    `Pooled OLS` = dd(ols), `FE (within)` = dd(fe), `Arellano-Bond` = dd(ab), `Blundell-Bond` = dd(bb))
  bind_rows(body, diag)
}

# Combined table: dynamic FE stepwise (Base -> full) + Arellano-Bond + Blundell-Bond.
fc_s   <- function(est, p) ifelse(is.na(est) | is.na(p), "", sprintf("%+.4f%s", est, stars(p)))  # coef + stars only
fe_col <- function(m) {
  ct <- coeftable(m)
  vapply(fe_terms, function(v) if (v %in% rownames(ct)) fc(ct[v, 1], ct[v, 2], ct[v, 4]) else "", character(1))
}
gmm_col <- function(d, instr, tr) {
  d2 <- d |> arrange(iso3, year) |> mutate(t = as.integer(factor(year)))
  pd <- pdata.frame(as.data.frame(d2), index = c("iso3", "t"))
  m  <- pgmm(as.formula(paste("bpcr ~ lag(bpcr,1) +", ctl, "|", instr)),
             data = pd, effect = "twoways", model = "twosteps", transformation = tr, collapse = TRUE)
  s  <- summary(m, robust = TRUE); cf <- s$coefficients
  list(coef = vapply(terms_keep, function(v) fc(cf[v, 1], cf[v, 2], cf[v, 4]), character(1)),
       nobs = sum(lengths(m$residuals)), ninst = ncol(m$W[[1]]),
       # two-step estimation: the over-id statistic is the Hansen J (robust);
       # report AR(1) (expected significant) alongside AR(2) (should not be)
       hansen = s$sargan$p.value, ar1 = s$m1$p.value, ar2 = s$m2$p.value)
}
build_combo <- function(d, instr) {
  d2 <- filter(d, !is.na(bpcr_L))
  ff <- function(rhs) feols(as.formula(paste("bpcr ~", rhs, "| iso3 + factor(year)")), d2, vcov = ~iso3)
  b1 <- ff("bpcr_L")
  b2 <- ff("bpcr_L + ln_urban_density")
  b3 <- ff("bpcr_L + ln_urban_density + net_migr_pct")
  b4 <- ff("bpcr_L + ln_urban_density + net_migr_pct + ln_gdp_pc")
  b5 <- ff("bpcr_L + ln_urban_density + net_migr_pct + ln_gdp_pc + urban_pop_share")
  ab <- gmm_col(d, instr, "d"); bb <- gmm_col(d, instr, "ld")
  body <- tibble(Term = term_lab,
    `Base` = fe_col(b1), `+ Density` = fe_col(b2), `+ Net Migr.` = fe_col(b3),
    `+ GDP` = fe_col(b4), `+ Urban %` = fe_col(b5),
    `Arellano-Bond` = ab$coef, `Blundell-Bond` = bb$coef)
  # per-equation observation counts: AB = differenced obs; BB = level-equation obs
  ab_obs <- ab$nobs                 # difference equation (loses first period per country)
  bb_obs <- bb$nobs - ab$nobs       # level equation of the system estimator (recovers it)
  fed <- function(m) c(format(nobs(m), big.mark = ","), fmt_w(unname(r2(m)["wr2"])), "Yes", "Yes", "–", "–", "–", "–")
  diag <- tibble(Term = c("Observations", "Within R²", "Country FE", "Period FE", "Instruments", "Hansen (p)", "AR(1) (p)", "AR(2) (p)"),
    `Base` = fed(b1), `+ Density` = fed(b2), `+ Net Migr.` = fed(b3), `+ GDP` = fed(b4), `+ Urban %` = fed(b5),
    `Arellano-Bond` = c(format(ab_obs, big.mark = ","), "–", "Yes", "Yes", as.character(ab$ninst), fmt_p(ab$hansen), fmt_p(ab$ar1), fmt_p(ab$ar2)),
    `Blundell-Bond` = c(format(bb_obs, big.mark = ","), "–", "Yes", "Yes", as.character(bb$ninst), fmt_p(bb$hansen), fmt_p(bb$ar1), fmt_p(bb$ar2)))
  bind_rows(body, diag)
}

# Build the sample exactly like the deck's panel_fixed: lag the DV on the full
# BpCR series first, THEN apply the control filters (so FE N matches Model 1/2/m6).
p <- read_csv("03_datasets/processed/reg_panel_urban.csv", show_col_types = FALSE) |>
  filter(year <= 2020, !is.na(bpcr), !is.na(lcrpgr_log)) |>
  arrange(iso3, year) |> group_by(iso3) |> mutate(bpcr_L = dplyr::lag(bpcr)) |> ungroup() |>
  filter(!is.na(ln_gdp_pc), !is.na(urban_pop_share),
         !is.na(ln_urban_density), !is.na(net_migr_pct))

main_tab   <- build_tab(p, "lag(bpcr,2:5)")
robust_tab <- build_tab(p |> filter(year >= 2000), "lag(bpcr,2:4)")
main_full  <- build_tab(p, "lag(bpcr,2:5)", full = TRUE)   # + Pooled OLS + Within R² (appendix)
main_combo <- build_combo(p, "lag(bpcr,2:5)")              # FE stepwise + AB + BB (final-model slide)

saveRDS(list(main = main_tab, robust = robust_tab, main_full = main_full, main_combo = main_combo),
        "03_datasets/processed/dynamic_gmm.rds")
cat("wrote dynamic_gmm.rds\n\nMAIN:\n"); print(as.data.frame(main_tab), row.names = FALSE)
cat("\nROBUSTNESS (2000-2020):\n"); print(as.data.frame(robust_tab), row.names = FALSE)
