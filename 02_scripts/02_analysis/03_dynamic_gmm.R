# ==============================================================================
# File:          03_dynamic_gmm.R
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
# Description:   Performs dynamic-panel GMM estimations (Arellano-Bond diff +
#                Blundell-Bond system) for BpCR inertia, plus panel unit-root
#                tests and the incremental (difference-in-) Hansen test.
#                Urban density enters with a one-period lag in all main
#                specifications to break the mechanical population link with
#                the per-capita dependent variable.
# ==============================================================================
suppressMessages({library(plm); library(fixest); library(dplyr); library(readr); library(tidyr); library(here)})
setwd(here::here())  # project root (portable; works for any clone location)

stars <- function(p) ifelse(is.na(p), "", ifelse(p < .01, "***", ifelse(p < .05, "**", ifelse(p < .1, "*", ""))))
fc    <- function(est, se, p) {
  ifelse(is.na(est), "", sprintf("%+.4f%s<br>(%.4f)", est, stars(p), se))
}

# Urban density and urban population share enter lagged (t-1): both share the
# urban population count with the per-capita dependent variable, so their
# contemporaneous coefficients are mechanically biased; the one-period lag is
# predetermined with respect to the period-t population shock.
ctl  <- "ln_urban_density_L + net_migr_pct + ln_gdp_pc + urban_pop_share_L"
terms_keep <- c("lag(bpcr, 1)", "ln_urban_density_L", "net_migr_pct", "ln_gdp_pc", "urban_pop_share_L")
term_lab   <- c("BpCR[t−1]", "ln(Urban Density)[t−1]", "Net Migration (% Pop)",
                "ln(GDP per capita)", "Urban Pop. Share[t−1]")
fe_terms   <- c("bpcr_L", "ln_urban_density_L", "net_migr_pct", "ln_gdp_pc", "urban_pop_share_L")

fmt_w <- function(x) ifelse(is.na(x), "–", sprintf("%.3f", x))
fmt_p <- function(x) ifelse(is.na(x), "–", sprintf("%.2f", x))

run_ols <- function(d) {   # pure pooled OLS (no FE): upper bound for rho (Bond 2002)
  d <- filter(d, !is.na(bpcr_L))
  m <- feols(bpcr ~ bpcr_L + ln_urban_density_L + net_migr_pct + ln_gdp_pc + urban_pop_share_L, d, vcov = ~iso3)
  ct <- coeftable(m)
  list(coef = setNames(fc(ct[fe_terms, 1], ct[fe_terms, 2], ct[fe_terms, 4]), fe_terms),
       nobs = nobs(m), nc = n_distinct(d$iso3), wr2 = unname(r2(m)["ar2"]),  # adjusted R^2 (no FE)
       cfe = "No", pfe = "No", sargan = NA, ar2 = NA)
}
run_fe <- function(d) {
  d <- filter(d, !is.na(bpcr_L))   # bpcr_L is lagged on the full series (deck-consistent)
  m <- feols(bpcr ~ bpcr_L + ln_urban_density_L + net_migr_pct + ln_gdp_pc + urban_pop_share_L |
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
  # pgmm assigns every country an identical nominal per-country row count
  # (a balanced-grid equation size), so data-sparse countries carry
  # structural exact-zero rows among their fitted residuals; count only the
  # genuinely non-zero (non-padded) rows. For "d" (Arellano-Bond) all rows
  # belong to the differenced equation; for "ld" (Blundell-Bond) the last 8
  # rows per country are the level-equation part.
  nz_all   <- sum(unlist(m$residuals) != 0)
  nz_level <- sum(unlist(lapply(m$residuals, utils::tail, n = 8L)) != 0)
  list(coef = vapply(terms_keep, function(v) fc(cf[v, 1], cf[v, 2], cf[v, 4]), character(1)),
       nobs = sum(lengths(m$residuals)), ninst = ncol(m$W[[1]]),
       nz_all = nz_all, nz_level = nz_level,
       # two-step estimation: the over-id statistic is the Hansen J (robust);
       # report AR(1) (expected significant) alongside AR(2) (should not be)
       hansen = s$sargan$p.value, ar1 = s$m1$p.value, ar2 = s$m2$p.value)
}
build_combo <- function(d, instr) {
  d2 <- filter(d, !is.na(bpcr_L))
  ff <- function(rhs) feols(as.formula(paste("bpcr ~", rhs, "| iso3 + factor(year)")), d2, vcov = ~iso3)
  b1 <- ff("bpcr_L")
  b2 <- ff("bpcr_L + ln_urban_density_L")
  b3 <- ff("bpcr_L + ln_urban_density_L + net_migr_pct")
  b4 <- ff("bpcr_L + ln_urban_density_L + net_migr_pct + ln_gdp_pc")
  b5 <- ff("bpcr_L + ln_urban_density_L + net_migr_pct + ln_gdp_pc + urban_pop_share_L")
  ab <- gmm_col(d, instr, "d"); bb <- gmm_col(d, instr, "ld")
  body <- tibble(Term = term_lab,
    `Base` = fe_col(b1), `+ Density` = fe_col(b2), `+ Net Migr.` = fe_col(b3),
    `+ GDP` = fe_col(b4), `+ Urban %` = fe_col(b5),
    `Arellano-Bond` = ab$coef, `Blundell-Bond` = bb$coef)
  # report the genuinely non-zero row count directly (not the inflated
  # balanced-grid equation size); see gmm_col() for how these are counted.
  ab_obs_str <- format(ab$nz_all, big.mark = ",")
  bb_obs_str <- format(bb$nz_level, big.mark = ",")
  fed <- function(m) c(format(nobs(m), big.mark = ","), fmt_w(unname(r2(m)["wr2"])), "Yes", "Yes", "–", "–", "–", "–")
  diag <- tibble(Term = c("Observations", "Within R²", "Country FE", "Period FE", "Instruments", "Hansen (p)", "AR(1) (p)", "AR(2) (p)"),
    `Base` = fed(b1), `+ Density` = fed(b2), `+ Net Migr.` = fed(b3), `+ GDP` = fed(b4), `+ Urban %` = fed(b5),
    `Arellano-Bond` = c(ab_obs_str, "–", "Yes", "Yes", as.character(ab$ninst), fmt_p(ab$hansen), fmt_p(ab$ar1), fmt_p(ab$ar2)),
    `Blundell-Bond` = c(bb_obs_str, "–", "Yes", "Yes", as.character(bb$ninst), fmt_p(bb$hansen), fmt_p(bb$ar1), fmt_p(bb$ar2)))
  bind_rows(body, diag)
}

# Build the sample exactly like the deck's panel_fixed: lag the DV on the full
# BpCR series first, THEN apply the control filters (so FE N matches Model 1/2/m6).
p <- read_csv("03_datasets/processed/reg_panel_urban.csv", show_col_types = FALSE) |>
  filter(year <= 2020, !is.na(bpcr), !is.na(lcrpgr_log)) |>
  arrange(iso3, year) |> group_by(iso3) |>
  mutate(bpcr_L = dplyr::lag(bpcr),
         ln_urban_density_L = dplyr::lag(ln_urban_density),
         urban_pop_share_L = dplyr::lag(urban_pop_share),
         # second lags: BpCR_t is built from P_t and P_{t-1} only, so a control
         # dated t-2 shares no term with it (and a persistent level shock at t-2
         # cancels in the difference). This is the mechanically clean timing.
         ln_urban_density_L2 = dplyr::lag(ln_urban_density, 2),
         urban_pop_share_L2 = dplyr::lag(urban_pop_share, 2),
         # GDP-per-capita lags, used only for the income timing check that mirrors
         # the density timing experiment (@sec-results, income robustness).
         ln_gdp_pc_L = dplyr::lag(ln_gdp_pc),
         ln_gdp_pc_L2 = dplyr::lag(ln_gdp_pc, 2)) |> ungroup() |>
  filter(!is.na(ln_gdp_pc), !is.na(urban_pop_share),
         !is.na(ln_urban_density), !is.na(net_migr_pct))

# ------------------------------------------------------------------------------
# Panel unit-root tests.
# Maddala-Wu (Fisher-type ADF, lags = 0) on the full unbalanced panel, dropping
# countries with fewer than 6 observations or a numerically constant series;
# Im-Pesaran-Shin (lags = 1) on the balanced sub-panel as a cross-check.
# ------------------------------------------------------------------------------
urt_vars <- c(bpcr = "BpCR", ln_urban_density = "ln(Urban Density)",
              ln_gdp_pc = "ln(GDP per capita)", urban_pop_share = "Urban Pop. Share",
              net_migr_pct = "Net Migration (% Pop)")
tab_ct   <- table(p$iso3)
bal_iso  <- names(tab_ct)[tab_ct == max(tab_ct)]
urt <- do.call(rbind, lapply(names(urt_vars), function(v) {
  ok <- p |> group_by(iso3) |>
    filter(sum(!is.na(.data[[v]])) >= 6, stats::sd(.data[[v]], na.rm = TRUE) > 1e-8) |>
    ungroup() |> filter(!is.na(.data[[v]])) |> mutate(t = as.integer(factor(year)))
  pd_mw <- plm::pdata.frame(as.data.frame(ok), index = c("iso3", "t"))
  mw <- plm::purtest(as.formula(paste(v, "~ 1")), data = pd_mw, index = c("iso3", "t"),
                test = "madwu", exo = "intercept", lags = 0L)
  okb <- p |> filter(iso3 %in% bal_iso, !is.na(.data[[v]])) |> mutate(t = as.integer(factor(year)))
  ips <- tryCatch({
    r <- plm::purtest(as.formula(paste(v, "~ 1")), data = plm::pdata.frame(as.data.frame(okb), index = c("iso3", "t")),
                 index = c("iso3", "t"), test = "ips", exo = "intercept", lags = 1L)
    c(stat = unname(r$statistic$statistic), p = unname(r$statistic$p.value))
  }, error = function(e) c(stat = NA_real_, p = NA_real_))
  data.frame(Variable = urt_vars[[v]], n_countries = dplyr::n_distinct(ok$iso3),
             mw_stat = unname(mw$statistic$statistic), mw_df = unname(mw$statistic$parameter),
             mw_p = unname(mw$statistic$p.value), ips_stat = ips["stat"], ips_p = ips["p"],
             row.names = NULL)
}))

# ------------------------------------------------------------------------------
# Net-migration robustness. The control is the five-year window mean of the UN
# annual net-migration rate (see 01_country_urban_panel.R). Because the raw
# annual series contains genuine but extreme crisis observations (Kuwait 1990,
# the Gulf War exodus, at -71% of population), we verify that the migration
# result is not carried by them: we re-estimate excluding the single most extreme
# country-period, excluding the two crisis countries outright, and using the
# endpoint-year rate instead of the window mean.
# ------------------------------------------------------------------------------
mig_ab <- function(d, mv) {
  d2 <- d |> arrange(iso3, year) |> mutate(t = as.integer(factor(year)), mig = .data[[mv]]) |>
    filter(!is.na(mig))
  pd <- pdata.frame(as.data.frame(d2), index = c("iso3", "t"))
  m <- pgmm(bpcr ~ lag(bpcr, 1) + ln_urban_density_L + mig + ln_gdp_pc + urban_pop_share_L |
              lag(bpcr, 2:5),
            data = pd, effect = "twoways", model = "twosteps", transformation = "d", collapse = TRUE)
  s <- summary(m, robust = TRUE)
  cf <- s$coefficients["mig", ]
  fe <- feols(bpcr ~ bpcr_L + ln_urban_density_L + mig + ln_gdp_pc + urban_pop_share_L |
                iso3 + factor(year), filter(d2, !is.na(bpcr_L)), vcov = ~iso3)
  cfe <- coeftable(fe)["mig", ]
  # Report each estimator's OWN realised N, taken from the fitted objects rather
  # than from nrow(): the two differ (the first-difference transformation costs
  # Arellano-Bond an epoch, and feols drops fixed-effect singletons), so a single
  # shared observation count would be wrong for at least one of the columns.
  c(AB = unname(fc(cf[1], cf[2], cf[4])), FE = unname(fc(cfe[1], cfe[2], cfe[4])),
    N_AB = format(sum(vapply(m$residuals, length, integer(1))), big.mark = ","),
    N_FE = format(unname(fe$nobs), big.mark = ","))
}
mig_variants <- list(
  `Window mean (baseline)`   = mig_ab(p, "net_migr_pct"),
  `Excl. Kuwait 1990`        = mig_ab(filter(p, !(iso3 == "KWT" & year == 1990)), "net_migr_pct"),
  `Excl. Kuwait and Liberia` = mig_ab(filter(p, !iso3 %in% c("KWT", "LBR")), "net_migr_pct"),
  `Endpoint-year rate`       = mig_ab(p, "net_migr_pct_yr")
)
mig_robust <- data.frame(
  Specification = names(mig_variants),
  `Arellano-Bond` = vapply(mig_variants, function(x) x[["AB"]], character(1)),
  `FE (within)`   = vapply(mig_variants, function(x) x[["FE"]], character(1)),
  `N (AB)`        = vapply(mig_variants, function(x) x[["N_AB"]], character(1)),
  `N (FE)`        = vapply(mig_variants, function(x) x[["N_FE"]], character(1)),
  check.names = FALSE, row.names = NULL, stringsAsFactors = FALSE
)

main_tab   <- build_tab(p, "lag(bpcr,2:5)")

# ------------------------------------------------------------------------------
# Accounting check underpinning the timing argument. By construction
#   BpCR_t = (1/z)[ln V_t - ln P_t - ln V_{t-1} + ln P_{t-1}],
# so urban population enters NEGATIVELY at t and POSITIVELY at t-1. Any control
# built from P inherits the sign of the date it is measured at: this is why the
# density coefficient flips when the control is lagged, and why t-2 (which shares
# no term with BpCR_t) is the only mechanically clean timing.
# ------------------------------------------------------------------------------
acct_check <- local({
  q <- p |> group_by(iso3) |> mutate(lnP = log(pop_urban), lnP_L = dplyr::lag(lnP)) |>
    ungroup() |> filter(!is.na(lnP), !is.na(lnP_L))
  m <- feols(bpcr ~ lnP + lnP_L | iso3 + factor(year), q, vcov = ~iso3)
  coeftable(m)[c("lnP", "lnP_L"), ]
})

# ------------------------------------------------------------------------------
# Migration channel decomposition. BpCR = LCR_log - PGR_log by construction, so
# a referee may ask whether the migration coefficient is definitional: migrants
# raise population, which lowers a per-capita quantity by arithmetic. Estimating
# the same two-way FE model on each component separately answers this. If land
# did not respond at all, the BpCR coefficient would equal minus the population
# coefficient; the gap between the two is the built-up response, i.e. exactly the
# quantity H4 is about.
# ------------------------------------------------------------------------------
pfe <- filter(p, !is.na(bpcr_L))
mig_decomp <- local({
  f_rhs <- "ln_urban_density_L + urban_pop_share_L + ln_gdp_pc + net_migr_pct | iso3 + factor(year)"
  cmp <- function(dv) {
    m <- feols(as.formula(paste(dv, "~", f_rhs)), pfe, vcov = ~iso3)
    coeftable(m)["net_migr_pct", ]
  }
  list(pgr = cmp("pgr_log"), lcr = cmp("lcr_log"), bpcr = cmp("bpcr"),
       urban_share_mean = mean(pfe$urban_pop_share, na.rm = TRUE))
})

# ------------------------------------------------------------------------------
# Why does the density coefficient jump from FE (+0.014) to Arellano-Bond
# (+0.037)? Under strict exogeneity the within and first-difference transforms
# are BOTH consistent and should agree, so a gap is diagnostic. We separate the
# transformation from the instruments:
#   (a) plain first-difference OLS, no instruments at all;
#   (b) GMM treating density as predetermined / endogenous instead of exogenous;
#   (c) the correlation that drives it: D(density_{t-1}) contains
#       ln P_{t-1} - ln P_{t-2}, which BpCR_{t-1} contains with the opposite
#       sign, so differencing correlates the regressor with eps_{t-1}, which sits
#       inside D(eps_t) with a minus sign -> upward bias on density.
# ------------------------------------------------------------------------------
exog_check <- local({
  w <- filter(p, !is.na(bpcr_L), !is.na(ln_urban_density_L), !is.na(urban_pop_share_L))
  fe <- feols(bpcr ~ bpcr_L + ln_urban_density_L + net_migr_pct + ln_gdp_pc + urban_pop_share_L |
                iso3 + factor(year), w, vcov = ~iso3)
  fdd <- w |> arrange(iso3, year) |> group_by(iso3) |>
    mutate(across(c(bpcr, bpcr_L, ln_urban_density_L, net_migr_pct, ln_gdp_pc, urban_pop_share_L),
                  ~ .x - dplyr::lag(.x), .names = "D_{.col}")) |> ungroup() |>
    filter(!is.na(D_bpcr), !is.na(D_ln_urban_density_L))
  fd <- feols(D_bpcr ~ D_bpcr_L + D_ln_urban_density_L + D_net_migr_pct + D_ln_gdp_pc +
                D_urban_pop_share_L | factor(year), fdd, vcov = ~iso3)
  gmm_var <- function(instr) {
    d2 <- p |> arrange(iso3, year) |> mutate(t = as.integer(factor(year)))
    pd <- pdata.frame(as.data.frame(d2), index = c("iso3", "t"))
    m <- pgmm(as.formula(paste("bpcr ~ lag(bpcr,1) +", ctl, "|", instr)),
              data = pd, effect = "twoways", model = "twosteps", transformation = "d", collapse = TRUE)
    summary(m, robust = TRUE)$coefficients["ln_urban_density_L", ]
  }
  qc <- p |> arrange(iso3, year) |> group_by(iso3) |>
    mutate(D_dL = ln_urban_density_L - dplyr::lag(ln_urban_density_L)) |> ungroup() |>
    filter(!is.na(D_dL), !is.na(bpcr_L))
  list(
    fe   = coeftable(fe)["ln_urban_density_L", ],
    fd   = coeftable(fd)["D_ln_urban_density_L", ],
    fe_migr = coeftable(fe)["net_migr_pct", ],
    fd_migr = coeftable(fd)["D_net_migr_pct", ],
    gmm_exo  = gmm_var("lag(bpcr,2:5)"),
    gmm_pred = gmm_var("lag(bpcr,2:5) + lag(ln_urban_density,2:5)"),
    gmm_endo = gmm_var("lag(bpcr,2:5) + lag(ln_urban_density,3:5)"),
    cor_Ddens_bpcrL = cor(qc$D_dL, qc$bpcr_L)
  )
})

# ------------------------------------------------------------------------------
# Exogeneity of the migration control. Migration is the paper's headline result
# and, like the other controls, is entered as strictly exogenous, so the
# assumption has to be probed rather than asserted.
#   (a) Wooldridge lead test. Unlike density (whose lead still carries P_t through
#       the persistence of the population stock), migration's lead shares no
#       accounting term with BpCR_t, so a significant lead here would be genuine
#       feedback. It is not significant.
#   (b) Re-estimate treating migration as predetermined, then as endogenous,
#       instrumenting it with its own lags instead of assuming exogeneity.
# ------------------------------------------------------------------------------
mig_exog <- local({
  pf <- p |> arrange(iso3, year) |> group_by(iso3) |>
    mutate(migr_F1 = dplyr::lead(net_migr_pct)) |> ungroup()
  w <- filter(pf, !is.na(bpcr_L), !is.na(ln_urban_density_L), !is.na(urban_pop_share_L), !is.na(migr_F1))
  lead_m <- feols(bpcr ~ bpcr_L + ln_urban_density_L + net_migr_pct + migr_F1 + ln_gdp_pc +
                    urban_pop_share_L | iso3 + factor(year), w, vcov = ~iso3)
  gv <- function(instr) {
    d2 <- p |> arrange(iso3, year) |> mutate(t = as.integer(factor(year)))
    pd <- pdata.frame(as.data.frame(d2), index = c("iso3", "t"))
    m <- pgmm(as.formula(paste("bpcr ~ lag(bpcr,1) +", ctl, "|", instr)),
              data = pd, effect = "twoways", model = "twosteps", transformation = "d", collapse = TRUE)
    sm <- summary(m, robust = TRUE)
    list(coef = sm$coefficients["net_migr_pct", ], hansen = sm$sargan$p.value)
  }
  list(
    lead      = coeftable(lead_m)["migr_F1", ],
    contemp   = coeftable(lead_m)["net_migr_pct", ],
    exo       = gv("lag(bpcr,2:5)"),
    predeterm = gv("lag(bpcr,2:5) + lag(net_migr_pct,2:5)"),
    endo      = gv("lag(bpcr,2:5) + lag(net_migr_pct,3:5)")
  )
})

# ------------------------------------------------------------------------------
# Persistence diagnostics. The Bond (2002) bracket says a consistent rho should
# lie between the downward-biased within estimate and the upward-biased pooled
# OLS estimate. We check membership, and we ask what the Nickell (1981) bias
# implies about the true rho given the within estimate and T, since with only
# eight epochs that bias is large and cannot be waved away. We also measure
# first-stage instrument strength so that "weak instruments" is a claim we can
# test rather than assume.
# ------------------------------------------------------------------------------
rho_check <- local({
  # fit the four estimators directly rather than parsing formatted table cells,
  # so this block does not depend on table-build order
  d0 <- filter(p, !is.na(bpcr_L))
  rhs <- paste("bpcr ~ bpcr_L +", ctl)
  ols <- coef(feols(as.formula(rhs), d0, vcov = ~iso3))[["bpcr_L"]]
  fe  <- coef(feols(as.formula(paste(rhs, "| iso3 + factor(year)")), d0, vcov = ~iso3))[["bpcr_L"]]
  gr <- function(tr) {
    d2 <- p |> arrange(iso3, year) |> mutate(t = as.integer(factor(year)))
    pd <- pdata.frame(as.data.frame(d2), index = c("iso3", "t"))
    m <- pgmm(as.formula(paste("bpcr ~ lag(bpcr,1) +", ctl, "| lag(bpcr,2:5)")),
              data = pd, effect = "twoways", model = "twosteps", transformation = tr, collapse = TRUE)
    unname(summary(m, robust = TRUE)$coefficients["lag(bpcr, 1)", 1])
  }
  ab <- gr("d"); bb <- gr("ld")
  # Nickell (1981) bias of the within estimator, one-way FE, no regressors
  nick <- function(rho, T) {
    a <- 1 - (1 / T) * (1 - rho^T) / (1 - rho)
    -((1 + rho) / (T - 1)) * a / (1 - (2 * rho / ((1 - rho) * (T - 1))) * a)
  }
  implied <- function(T) tryCatch(uniroot(function(r) r + nick(r, T) - fe, c(0.01, 0.95))$root,
                                  error = function(e) NA_real_)
  # first stage: does the level-lag ladder actually predict the differenced lag?
  q <- p |> arrange(iso3, year) |> group_by(iso3) |>
    mutate(D_bpcr_L = bpcr_L - dplyr::lag(bpcr_L),
           z2 = dplyr::lag(bpcr, 2), z3 = dplyr::lag(bpcr, 3),
           z4 = dplyr::lag(bpcr, 4), z5 = dplyr::lag(bpcr, 5)) |>
    ungroup() |> filter(!is.na(D_bpcr_L), !is.na(z2))
  fs <- feols(D_bpcr_L ~ z2 + z3 + z4 + z5 | factor(year), q, vcov = ~iso3)
  fsw <- fixest::wald(fs, keep = "z[2-5]", print = FALSE)
  list(ols = ols, fe = fe, ab = ab, bb = bb,
       ab_in_bracket = ab >= fe && ab <= ols,
       bb_in_bracket = bb >= fe && bb <= ols,
       implied_T8 = implied(8), implied_T7 = implied(7),
       first_stage_F = unname(fsw$stat), first_stage_p = unname(fsw$p))
})

# ------------------------------------------------------------------------------
# Where the persistence anomaly comes from. The Bond (2002) bracket assumes
# STRICTLY EXOGENOUS covariates, and we showed above that density (and urban
# share) are arithmetically entangled with BpCR, so the bracket may be
# mis-anchored in the full model rather than the estimator being inconsistent.
# Test: rebuild the bracket as controls are added, from the pure AR(1) upward.
# This also settles the weak-instrument objection: if the level-lag instruments
# were weak, difference GMM would collapse TOWARD the within estimate (Blundell
# and Bond 1998); instead, in the clean AR(1) it recovers the Nickell-implied
# value, which weak instruments could not do.
# ------------------------------------------------------------------------------
rho_ladder <- local({
  d0 <- filter(p, !is.na(bpcr_L), !is.na(ln_urban_density_L), !is.na(urban_pop_share_L))
  pdl <- pdata.frame(as.data.frame(p |> arrange(iso3, year) |> mutate(t = as.integer(factor(year)))),
                     index = c("iso3", "t"))
  one <- function(ctl, lab) {
    rhs <- if (nzchar(ctl)) paste("bpcr ~ bpcr_L +", ctl) else "bpcr ~ bpcr_L"
    ols <- coef(feols(as.formula(rhs), d0, vcov = ~iso3))[["bpcr_L"]]
    fe  <- coef(feols(as.formula(paste(rhs, "| iso3 + factor(year)")), d0, vcov = ~iso3))[["bpcr_L"]]
    fe_se <- coeftable(feols(as.formula(paste(rhs, "| iso3 + factor(year)")), d0, vcov = ~iso3))["bpcr_L", 2]
    gf <- function(tr) {
      fm <- if (nzchar(ctl)) paste("bpcr ~ lag(bpcr,1) +", ctl, "| lag(bpcr,2:5)") else
        "bpcr ~ lag(bpcr,1) | lag(bpcr,2:5)"
      m <- pgmm(as.formula(fm), data = pdl, effect = "twoways", model = "twosteps",
                transformation = tr, collapse = TRUE)
      sm <- summary(m, robust = TRUE)
      list(rho = unname(sm$coefficients["lag(bpcr, 1)", 1]),
           se  = unname(sm$coefficients["lag(bpcr, 1)", 2]),
           h   = unname(sm$sargan$p.value))
    }
    ab <- gf("d"); bb <- gf("ld")
    # report SEs: the bracket is a comparison of point estimates, and whether a
    # given "violation" is meaningful depends entirely on how precise they are
    data.frame(Specification = lab,
               `Pooled OLS` = sprintf("%.3f", ols),
               `FE (within)` = sprintf("%.3f (%.3f)", fe, fe_se),
               `Arellano-Bond` = sprintf("%.3f (%.3f)", ab$rho, ab$se),
               `Blundell-Bond` = sprintf("%.3f (%.3f)", bb$rho, bb$se),
               `AB in bracket` = ifelse(ab$rho >= fe && ab$rho <= ols, "Yes", "No"),
               `AB Hansen (p)` = sprintf("%.2f", ab$h),
               check.names = FALSE, stringsAsFactors = FALSE)
  }
  do.call(rbind, list(
    one("", "AR(1) only"),
    one("net_migr_pct", "+ Net migration"),
    one("net_migr_pct + ln_gdp_pc", "+ GDP per capita"),
    one(ctl, "+ Density, urban share (full)")
  ))
})

# ------------------------------------------------------------------------------
# Instrument-depth robustness. The pre-specified instrument set uses lags 2 to 5
# of BpCR. Its Hansen test is marginal, and dropping the deepest lags (which
# reach 20-25 years back at five-year epochs) restores it comfortably, so we
# report the full lag ladder rather than selecting the set that passes.
# ------------------------------------------------------------------------------
inst_row <- function(instr) {
  d2 <- p |> arrange(iso3, year) |> mutate(t = as.integer(factor(year)))
  pd <- pdata.frame(as.data.frame(d2), index = c("iso3", "t"))
  m <- pgmm(as.formula(paste("bpcr ~ lag(bpcr,1) +", ctl, "|", instr)),
            data = pd, effect = "twoways", model = "twosteps", transformation = "d", collapse = TRUE)
  s <- summary(m, robust = TRUE); cf <- s$coefficients
  c(vapply(terms_keep, function(v) unname(fc(cf[v, 1], cf[v, 2], cf[v, 4])), character(1)),
    Instruments = as.character(ncol(m$W[[1]])),
    `Hansen (p)` = fmt_p(s$sargan$p.value), `AR(2) (p)` = fmt_p(s$m2$p.value))
}
inst_sets <- c(`Lags 2-5 (baseline)` = "lag(bpcr,2:5)", `Lags 2-4` = "lag(bpcr,2:4)",
               `Lags 2-3` = "lag(bpcr,2:3)")
inst_robust <- data.frame(
  c(list(Term = c(term_lab, "Instruments", "Hansen (p)", "AR(2) (p)")),
    lapply(inst_sets, inst_row)),
  check.names = FALSE, row.names = NULL, stringsAsFactors = FALSE
)

main_tab   <- build_tab(p, "lag(bpcr,2:5)")
robust_tab <- build_tab(p |> filter(year >= 2000), "lag(bpcr,2:4)")
main_full  <- build_tab(p, "lag(bpcr,2:5)", full = TRUE)   # + Pooled OLS + Within R² (appendix)
main_combo <- build_combo(p, "lag(bpcr,2:5)")              # FE stepwise + AB + BB (final-model slide)

# ------------------------------------------------------------------------------
# Incremental (difference-in-) Hansen test: the Blundell-Bond system estimator
# adds level-equation moments whose validity requires the initial deviations to
# be uncorrelated with the country effects (mean stationarity of the process).
# The incremental statistic J(BB) - J(AB) tests exactly these added moments.
# ------------------------------------------------------------------------------
gmm_fit <- function(d, instr, tr) {
  d2 <- d |> arrange(iso3, year) |> mutate(t = as.integer(factor(year)))
  pd <- pdata.frame(as.data.frame(d2), index = c("iso3", "t"))
  m  <- pgmm(as.formula(paste("bpcr ~ lag(bpcr,1) +", ctl, "|", instr)),
             data = pd, effect = "twoways", model = "twosteps", transformation = tr, collapse = TRUE)
  list(s = summary(m, robust = TRUE), n_inst = ncol(m$W[[1]]), n_coef = length(coef(m)))
}
f_ab <- gmm_fit(p, "lag(bpcr,2:5)", "d")
f_bb <- gmm_fit(p, "lag(bpcr,2:5)", "ld")
s_ab <- f_ab$s
s_bb <- f_bb$s
inc_hansen <- list(
  J_ab = unname(s_ab$sargan$statistic), df_ab = unname(s_ab$sargan$parameter),
  p_ab = unname(s_ab$sargan$p.value),
  J_bb = unname(s_bb$sargan$statistic), df_bb = unname(s_bb$sargan$parameter),
  p_bb = unname(s_bb$sargan$p.value),
  # Hansen df = instruments - estimated coefficients. The system estimator adds
  # 6 level-equation moments but also estimates one extra parameter (the levels
  # intercept, which differencing removes), so its df rises by 5, not 6. No
  # instrument is collinear or dropped; these counts let the reader reconcile
  # the instrument columns in the GMM table with the incremental test's df.
  n_inst_ab = f_ab$n_inst, n_coef_ab = f_ab$n_coef,
  n_inst_bb = f_bb$n_inst, n_coef_bb = f_bb$n_coef
)
inc_hansen$d_inst <- inc_hansen$n_inst_bb - inc_hansen$n_inst_ab
inc_hansen$d_coef <- inc_hansen$n_coef_bb - inc_hansen$n_coef_ab
inc_hansen$dJ  <- inc_hansen$J_bb - inc_hansen$J_ab
inc_hansen$ddf <- inc_hansen$df_bb - inc_hansen$df_ab
inc_hansen$p   <- stats::pchisq(inc_hansen$dJ, inc_hansen$ddf, lower.tail = FALSE)

# ------------------------------------------------------------------------------
# Timing robustness: both urban density and urban population share carry the same
# urban population count as the per-capita dependent variable, so a common
# population shock biases whichever of them enters contemporaneously. We estimate
# the Arellano-Bond model under all four timing combinations to show where the
# mechanical negative sign lands; the all-lagged column is the preferred model.
# ------------------------------------------------------------------------------
timing_specs <- list(
  `Both t`               = c(dens = "ln_urban_density",    share = "urban_pop_share"),
  `Density t-1`          = c(dens = "ln_urban_density_L",  share = "urban_pop_share"),
  `Share t-1`            = c(dens = "ln_urban_density",    share = "urban_pop_share_L"),
  `Both t-1 (preferred)` = c(dens = "ln_urban_density_L",  share = "urban_pop_share_L")
)
timing_fit <- function(sp) {
  d2 <- p |> arrange(iso3, year) |> mutate(t = as.integer(factor(year)))
  pd <- pdata.frame(as.data.frame(d2), index = c("iso3", "t"))
  rhs <- paste(sp[["dens"]], "+ net_migr_pct + ln_gdp_pc +", sp[["share"]])
  m <- pgmm(as.formula(paste("bpcr ~ lag(bpcr,1) +", rhs, "| lag(bpcr,2:5)")),
            data = pd, effect = "twoways", model = "twosteps", transformation = "d", collapse = TRUE)
  s <- summary(m, robust = TRUE); cf <- s$coefficients
  g <- function(v) fc(cf[v, 1], cf[v, 2], cf[v, 4])
  c(g("lag(bpcr, 1)"), g(sp[["dens"]]), g("net_migr_pct"), g("ln_gdp_pc"), g(sp[["share"]]),
    format(sum(lengths(m$residuals)), big.mark = ","), fmt_p(s$sargan$p.value), fmt_p(s$m2$p.value))
}
# neutral row labels: the timing of each control varies by column, so the
# term labels must not hard-code a lag
timing_lab <- c("BpCR[t−1]", "ln(Urban Density)", "Net Migration (% Pop)",
                "ln(GDP per capita)", "Urban Pop. Share")
timing_tab <- as.data.frame(c(
  list(Term = c(timing_lab, "Observations", "Hansen (p)", "AR(2) (p)")),
  lapply(timing_specs, timing_fit)
), check.names = FALSE, stringsAsFactors = FALSE)

# Clean-timing check, fixed effects. The t-2 column cannot be estimated by
# difference GMM (double-lagging plus deep instruments exhausts the nine
# epochs), and it needs no instruments anyway, so we compare the three timings
# with the within estimator on one common sample where t, t-1 and t-2 all exist.
timing_fe <- local({
  cs <- p |> filter(!is.na(bpcr_L), !is.na(ln_gdp_pc), !is.na(net_migr_pct),
                    !is.na(ln_urban_density),    !is.na(urban_pop_share),
                    !is.na(ln_urban_density_L),  !is.na(urban_pop_share_L),
                    !is.na(ln_urban_density_L2), !is.na(urban_pop_share_L2))
  one <- function(dv, sv) {
    m <- feols(as.formula(paste("bpcr ~ bpcr_L +", dv, "+ net_migr_pct + ln_gdp_pc +", sv,
                                "| iso3 + factor(year)")), cs, vcov = ~iso3)
    ct <- coeftable(m)
    c(unname(fc(ct["bpcr_L", 1], ct["bpcr_L", 2], ct["bpcr_L", 4])),
      unname(fc(ct[dv, 1], ct[dv, 2], ct[dv, 4])),
      unname(fc(ct["net_migr_pct", 1], ct["net_migr_pct", 2], ct["net_migr_pct", 4])),
      unname(fc(ct["ln_gdp_pc", 1], ct["ln_gdp_pc", 2], ct["ln_gdp_pc", 4])),
      unname(fc(ct[sv, 1], ct[sv, 2], ct[sv, 4])),
      format(nobs(m), big.mark = ","))
  }
  data.frame(
    Term = c(timing_lab, "Observations"),
    `Both t` = one("ln_urban_density", "urban_pop_share"),
    `Both t-1` = one("ln_urban_density_L", "urban_pop_share_L"),
    `Both t-2 (clean)` = one("ln_urban_density_L2", "urban_pop_share_L2"),
    check.names = FALSE, row.names = NULL, stringsAsFactors = FALSE
  )
})

# ------------------------------------------------------------------------------
# Income timing check. GDP per capita = GDP / total population, so a contemporaneous
# income term shares (total) population with BpCR's urban-population term, the same
# family of entanglement that flips the density sign. We therefore subject income
# to the SAME t / t-1 / t-2 timing experiment as density, on one common sample, to
# see whether it inherits the sign-flip pathology or is stable. The density column
# is re-estimated on the identical sample as a contrast.
income_timing <- local({
  cs <- p |> filter(!is.na(bpcr_L), !is.na(net_migr_pct),
                    !is.na(ln_urban_density_L), !is.na(urban_pop_share_L),
                    !is.na(ln_gdp_pc), !is.na(ln_gdp_pc_L), !is.na(ln_gdp_pc_L2),
                    !is.na(ln_urban_density), !is.na(ln_urban_density_L2))
  inc <- function(iv) {
    m <- feols(as.formula(paste("bpcr ~ ln_urban_density_L + urban_pop_share_L + net_migr_pct +",
                                iv, "| iso3 + factor(year)")), cs, vcov = ~iso3)
    unname(fc(coeftable(m)[iv, 1], coeftable(m)[iv, 2], coeftable(m)[iv, 4]))
  }
  den <- function(iv) {
    m <- feols(as.formula(paste("bpcr ~", iv, "+ urban_pop_share_L + net_migr_pct + ln_gdp_pc",
                                "| iso3 + factor(year)")), cs, vcov = ~iso3)
    unname(fc(coeftable(m)[iv, 1], coeftable(m)[iv, 2], coeftable(m)[iv, 4]))
  }
  data.frame(
    Timing = c("Contemporaneous (t)", "Lagged (t-1)", "Twice lagged (t-2, clean)"),
    `Income (ln GDP p.c.)` = c(inc("ln_gdp_pc"), inc("ln_gdp_pc_L"), inc("ln_gdp_pc_L2")),
    `Density (contrast)`   = c(den("ln_urban_density"), den("ln_urban_density_L"), den("ln_urban_density_L2")),
    N = c(format(nrow(cs), big.mark = ","), "", ""),
    check.names = FALSE, row.names = NULL, stringsAsFactors = FALSE
  )
})

# headline contemporaneous coefficients (both controls at t), cited inline
s_cont <- {
  d2 <- p |> arrange(iso3, year) |> mutate(t = as.integer(factor(year)))
  pd <- pdata.frame(as.data.frame(d2), index = c("iso3", "t"))
  m  <- pgmm(as.formula(paste("bpcr ~ lag(bpcr,1) + ln_urban_density + net_migr_pct +",
                              "ln_gdp_pc + urban_pop_share | lag(bpcr,2:5)")),
             data = pd, effect = "twoways", model = "twosteps", transformation = "d", collapse = TRUE)
  summary(m, robust = TRUE)
}
dens_contemp  <- s_cont$coefficients["ln_urban_density", , drop = TRUE]
share_contemp <- s_cont$coefficients["urban_pop_share", , drop = TRUE]

# the mixed spec that lags density but not share: the mechanical negative
# migrates onto the share term (cited in the paper's timing discussion)
s_mixed <- {
  d2 <- p |> arrange(iso3, year) |> mutate(t = as.integer(factor(year)))
  pd <- pdata.frame(as.data.frame(d2), index = c("iso3", "t"))
  m  <- pgmm(as.formula(paste("bpcr ~ lag(bpcr,1) + ln_urban_density_L + net_migr_pct +",
                              "ln_gdp_pc + urban_pop_share | lag(bpcr,2:5)")),
             data = pd, effect = "twoways", model = "twosteps", transformation = "d", collapse = TRUE)
  summary(m, robust = TRUE)
}
share_mixed <- s_mixed$coefficients["urban_pop_share", , drop = TRUE]

# ------------------------------------------------------------------------------
# Does BpCR reproduce the LCRPGR policy signal where LCRPGR is well-behaved?
# LCRPGR = LCR / PGR is unstable when population growth is near zero. We restrict
# to country-periods where |PGR| is bounded away from zero (the region in which the
# ratio is meaningful) and measure how closely BpCR tracks the official ratio:
# the Pearson correlation, the Spearman rank correlation (does BpCR order countries
# the way LCRPGR does?), and the sprawl-classification agreement (does BpCR > 0 flag
# the same country-periods as the official LCRPGR > 1 threshold?). Computed on the
# full panel, not the estimation sample, since this is about the metric, not the model.
policy_signal <- local({
  d <- read_csv("03_datasets/processed/reg_panel_urban.csv", show_col_types = FALSE) |>
    filter(year <= 2020, !is.na(bpcr), !is.na(lcrpgr), !is.na(pgr_log))
  row <- function(thr, lab) {
    s <- filter(d, abs(pgr_log) >= thr)
    data.frame(
      Restriction = lab,
      N = format(nrow(s), big.mark = ","),
      Pearson  = sprintf("%+.2f", stats::cor(s$bpcr, s$lcrpgr)),
      Spearman = sprintf("%+.2f", stats::cor(s$bpcr, s$lcrpgr, method = "spearman")),
      `Sprawl agree` = sprintf("%.0f%%", 100 * mean((s$lcrpgr > 1) == (s$bpcr > 0))),
      check.names = FALSE, stringsAsFactors = FALSE
    )
  }
  rbind(
    row(0,     "All country-periods"),
    row(0.005, "$|\\text{PGR}| \\geq 0.5%$/yr"),
    row(0.010, "$|\\text{PGR}| \\geq 1%$/yr"),
    row(0.020, "$|\\text{PGR}| \\geq 2%$/yr")
  )
})

# ------------------------------------------------------------------------------
# Wild cluster bootstrap for the heterogeneity table. The development-group splits
# have as few as ~43 country clusters (LDC), where the asymptotic cluster-robust
# t-distribution is unreliable. We re-test the net-migration coefficient in each
# subgroup with the restricted wild cluster bootstrap of Cameron, Gelbach and Miller
# (2008): impose the null on the residuals, resample with cluster-level Rademacher
# weights, and compare the bootstrapped t to the observed one. This matches the
# static two-way FE specification and sample of tbl-hetero exactly.
hetero_wcb <- local({
  set.seed(20260716)
  ctl_o <- "ln_urban_density_L + urban_pop_share_L + ln_gdp_pc"
  wcr <- function(d, B = 999L) {
    full <- feols(as.formula(paste("bpcr ~ net_migr_pct +", ctl_o, "| iso3 + year")), d, vcov = ~iso3)
    tobs <- coeftable(full)["net_migr_pct", 1] / coeftable(full)["net_migr_pct", 2]
    rest <- feols(as.formula(paste("bpcr ~", ctl_o, "| iso3 + year")), d, vcov = ~iso3)
    yhat <- predict(rest); uhat <- resid(rest); cls <- unique(d$iso3)
    ts <- vapply(seq_len(B), function(b) {
      w <- setNames(sample(c(-1, 1), length(cls), replace = TRUE), cls)
      d$.ys <- yhat + w[d$iso3] * uhat
      fb <- feols(as.formula(paste(".ys ~ net_migr_pct +", ctl_o, "| iso3 + year")), d, vcov = ~iso3)
      coeftable(fb)["net_migr_pct", 1] / coeftable(fb)["net_migr_pct", 2]
    }, numeric(1))
    (1 + sum(abs(ts) >= abs(tobs))) / (B + 1)
  }
  d0 <- p |> filter(!is.na(ln_urban_density_L), !is.na(urban_pop_share_L),
                    !is.na(ln_gdp_pc), !is.na(net_migr_pct), !is.na(income_group))
  c(`All countries` = wcr(d0),
    Developed  = wcr(filter(d0, income_group == "Developed")),
    Developing = wcr(filter(d0, income_group == "Developing")),
    LDC        = wcr(filter(d0, income_group == "LDC")))
})

saveRDS(list(main = main_tab, robust = robust_tab, main_full = main_full, main_combo = main_combo,
             urt = urt, inc_hansen = inc_hansen, timing = timing_tab, timing_fe = timing_fe,
             mig_robust = mig_robust, inst_robust = inst_robust,
             mig_decomp = mig_decomp, acct_check = acct_check, rho_check = rho_check, rho_ladder = rho_ladder,
             exog_check = exog_check, mig_exog = mig_exog,
             dens_contemp = dens_contemp, share_contemp = share_contemp,
             share_mixed = share_mixed, income_timing = income_timing,
             policy_signal = policy_signal, hetero_wcb = hetero_wcb),
        "03_datasets/processed/dynamic_gmm.rds")
cat("wrote dynamic_gmm.rds\n\nMAIN:\n"); print(as.data.frame(main_tab), row.names = FALSE)
cat("\nROBUSTNESS (2000-2020):\n"); print(as.data.frame(robust_tab), row.names = FALSE)
cat("\nUNIT ROOT TESTS:\n"); print(urt, row.names = FALSE)
cat("\nINCREMENTAL HANSEN:\n"); str(inc_hansen)
cat("\nRHO LADDER (bracket as controls enter):\n"); print(rho_ladder, row.names = FALSE)
cat("\nPERSISTENCE / NICKELL DIAGNOSTICS:\n"); str(rho_check)
cat("\nMIGRATION EXOGENEITY CHECKS:\n"); str(mig_exog)
cat("\nSTRICT-EXOGENEITY / TRANSFORM CHECK (density):\n"); str(exog_check)
cat("\nACCOUNTING CHECK (BpCR on ln P_t, ln P_t-1):\n"); print(round(acct_check, 4))
cat("\nMIGRATION CHANNEL DECOMPOSITION:\n"); str(mig_decomp)
cat("\nINSTRUMENT ROBUSTNESS:\n"); print(inst_robust, row.names = FALSE)
cat("\nMIGRATION ROBUSTNESS:\n"); print(mig_robust, row.names = FALSE)
cat("\nTIMING (FE, common sample, incl. clean t-2):\n"); print(timing_fe, row.names = FALSE)
cat("\nTIMING ROBUSTNESS (AB):\n"); print(timing_tab, row.names = FALSE)
cat("\nCONTEMPORANEOUS AB:\n"); print(dens_contemp); print(share_contemp)
cat("\nMIXED (density t-1, share t) share coef:\n"); print(share_mixed)
cat("\nMAIN COMBO:\n"); print(as.data.frame(main_combo), row.names = FALSE)
