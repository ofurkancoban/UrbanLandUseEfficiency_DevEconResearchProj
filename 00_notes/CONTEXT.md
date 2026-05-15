# Project Context — SDG 11.3.1 Seminar Paper

**Read this together with `ROADMAP_SDG_11_3_1.md`.** This file captures the decisions, reasoning, and findings from the initial planning conversation. Roadmap = what we're doing. Context = why we made the choices we made, and gotchas to remember.

---

## Course context

- **Course:** Development Economics, Summer term 2026, Carl von Ossietzky Universität Oldenburg.
- **Instructors:** Prof. Dr. Jürgen Bitzer, Dr. Bernhard C. Dannemann.
- **Format:** Seminar paper + presentation. See syllabus PDF (`Development-Economics-SS2026.pdf`) for full grading rubric.
- **Deliverables expected from the student:**
  1. 15-min presentation on a chosen development indicator.
  2. 3-min discussion opener on another student's presentation.
  3. Written elaboration, ≤ 12 pages incl. references and tables.
  4. Reproducible code files (no formatting requirement, but they need to actually reproduce the results).
- **Grade:** 50% presentation + opener, 50% written paper. All parts must pass.
- **Methodological requirement from the syllabus (p. 2):**
  - "Students have to carry out a simple OLS panel regression with the chosen indicator as dependent variable. For this, explanatory variables have to be identified and the mechanism how they determine the dependent variable have to be discussed."
  - The syllabus also explicitly references Hughes et al. (2017) and Ayaburi et al. (2020) as templates for *critically assessing* an indicator's strengths and limitations. The paper should follow that template alongside the empirical analysis.

---

## Indicator: SDG 11.3.1

- **Name:** Ratio of land consumption rate to population growth rate (LCRPGR).
- **Goal:** SDG 11 — Make cities and human settlements inclusive, safe, resilient, sustainable.
- **Target 11.3:** Enhance inclusive and sustainable urbanization.
- **Custodian agency:** UN-Habitat.
- **Metadata file in repo:** `Metadata-11-03-01.pdf` — read it. The whole computation method is in Section 4.c.

### Formula (replicate exactly — do not "improve")

$$LCR = \frac{V_{present} - V_{past}}{V_{past}} \cdot \frac{1}{t}$$

$$PGR = \frac{\ln(Pop_{t+n}/Pop_t)}{y}$$

$$LCRPGR = \frac{LCR}{PGR}$$

**Critical asymmetry to keep:** LCR uses arithmetic growth, PGR uses continuous (log) growth. UN-Habitat's own metadata fixes this — replicate it, don't normalize. The paper's critique section will discuss this asymmetry as one of the indicator's quirks.

### Interpretation

- LCRPGR > 1: built-up area expands faster than population → sprawl signal.
- LCRPGR = 1: proportional growth.
- 0 < LCRPGR < 1: densification (population grows faster than urban footprint).
- LCRPGR ≤ 0: undefined / breakdown — typically when population is shrinking. **Drop or flag these.**

---

## The data we have

193 country-level CSVs (one per country), each containing ADM1 (subnational) rows.

### Sample files inspected during planning

| File | Rows (ADM1 units) | Notes |
|---|---|---|
| `007_Argentina.csv` | 24 | Provinces |
| `179_Turkey.csv` | 80 | Provinces (iller) |
| `183_United_Kingdom.csv` | 4 | England, Scotland, Wales, Northern Ireland — very coarse compared to others |

**ADM1 units are NOT comparable across countries.** UK has 4 huge units; Turkey has 80 provinces; Argentina has 24 provinces. This is the main reason we aggregate to country level for the main analysis.

### Columns in every CSV

For each year in {1975, 1980, 1985, 1990, 1995, 2000, 2005, 2010, 2015, 2018, 2020, 2025, 2030}:

- `Built_GHSL_<year>` — built-up area in m², from GHSL.
- `Pop_GHSL_<year>` — population, from GHSL.
- `Pop_GPW_<year>` — population, from Gridded Population of the World.
- `Pop_WorldPop_<year>` — population, from WorldPop.

Plus identifiers: `ADM0_CODE`, `ADM0_NAME`, `ADM1_CODE`, `NAME_1`, `Country_ISO`, `Country_Name`.

### Key data decisions (with reasoning)

| Decision | Choice | Reasoning |
|---|---|---|
| **Geographic unit** | Country-year panel (sum ADM1 → ADM0) | Lecture asks for OLS panel. ADM1 units not comparable across countries (see above). |
| **Built-up area source** | `Built_GHSL` — only option, no alternatives in the data. | UN-Habitat's official recommendation in any case. |
| **Population source (main)** | `Pop_GHSL` | Same provider as built-up area → internal consistency. All years populated (1975–2020). |
| **Population source (robustness)** | `Pop_WorldPop` | Academic standard but only starts in 2000. Use for 2000–2020 sub-sample sensitivity check. |
| **Population source (excluded)** | `Pop_GPW` | The values in our CSVs are clearly broken. Turkey 2000 sums to ~4.7 billion people. Argentina sums to ~2.5 billion. UK to ~3 billion. Almost certainly a unit-conversion or repeated-aggregation error during dataset construction. **Do not use.** |
| **Period length** | 5 years | UN-Habitat metadata recommends 5- or 10-year cycles (Section 3.c). 5 years gives more periods → more observations for the regression. |
| **Time span** | 1975–2020 only | 2025 and 2030 values are projections, not measurements. Using them as outcomes would bias the regression toward whatever model produced the projections. |
| **2018 column** | Excluded from main panel | Off the 5-year grid; just a snapshot UN-Habitat publishes. Mention in a footnote. |

### GPW red flag — concrete numbers

The student should be aware that this was caught by inspection. From the planning analysis:

| Country | Year | `Pop_GHSL` sum | `Pop_GPW` sum |
|---|---|---|---|
| Turkey | 2000 | 62.46 M | **4,696.64 M** |
| Argentina | 2000 | 36.71 M | **2,549.44 M** |
| UK | 2000 | 58.29 M | **3,000.18 M** |

Real Turkey population in 2000 was ~64 million. So GHSL is right; GPW in this dataset is off by ~75×. Could be sums of density values rather than counts, or a join error that multiplies. Either way, do not use it.

### Sensitivity of LCRPGR to population source (Turkey, 2000–2020)

Same LCR (2.10%/year), three different PGRs depending on which series:

| Pop source | PGR (annual) | LCRPGR |
|---|---|---|
| GHSL | 1.37% | **1.54** |
| GPW | 0.62% | 3.41 (with broken denominator) |
| WorldPop | 0.60% | 3.51 |

GHSL and WorldPop differ on the *level* of population for Turkey (GHSL captures total population; WorldPop in this dataset appears to be urban-only or differently clipped), which inflates LCRPGR under WorldPop. This is exactly the kind of measurement issue the indicator-critique section should highlight.

---

## Expected sample size

- 193 countries × 9 five-year periods (1975–80, ..., 2015–20) = 1,737 country-period observations.
- After dropping (a) countries with broken / missing data, (b) periods with PGR very close to zero, (c) missing WDI covariates, expect **~1,200–1,400 usable observations**.

---

## The empirical specification (locked-in choices)

### Dependent variable
- Primary: `LCRPGR_i,t`
- Secondary (robustness / interpretation): `built_up_per_capita_i,t` and its change

### Estimating equation

$$LCRPGR_{i,t} = \alpha + \beta_1 \ln(GDPpc)_{i,t-1} + \beta_2 \text{Urban}_{i,t-1} + \beta_3 \text{AgriShare}_{i,t-1} + \beta_4 \ln(\text{Density})_{i,t-1} + \mathbf{Z}'_{i,t-1}\boldsymbol{\gamma} + \delta_t + \mu_i + \varepsilon_{i,t}$$

- All regressors lagged to start-of-window (mitigates reverse causality).
- Three specifications side-by-side in the main table: pooled OLS, period FE, two-way FE.
- Cluster SEs by country in all specs.

### Regressors — locked decisions

**Core (4 — always in the model):**

| Variable | WDI code | Expected sign | Mechanism |
|---|---|---|---|
| `ln_gdp_pc` | `NY.GDP.PCAP.PP.KD` | + | Brueckner monocentric-city: income → larger housing → outward expansion |
| `urban_share` | `SP.URB.TOTL.IN.ZS` | + (saturating) | Active urbanization phase drives greenfield consumption |
| `agri_share` | `NV.AGR.TOTL.ZS` | − | Structural transformation; Todaro Ch. 7 |
| `ln_pop_density` | `EN.POP.DNST` | − | High initial density → vertical growth dominates |

**Extended (2 — picked from the candidate list):**

| Variable | Source | Mechanism |
|---|---|---|
| `gov_effectiveness` | WGI (Worldwide Governance Indicators, World Bank) | Institutional capacity for planning constrains uncoordinated expansion |
| `motorization` | WDI `IS.VEH.NVEH.P3` (motor vehicles per 1000 people) | Direct Brueckner mechanism: car access unlocks low-density suburbs |

Why these two and not others: they cleanly represent two *different* mechanisms (demand-side income channel via cars, supply-side institutional channel via governance), are well-documented in the sprawl literature, and are publicly available without manual scraping. Household size (a tempting addition) requires UN DESA manual work and was deferred.

---

## Things the student already validated in planning

These are sanity checks already done — no need to redo, but worth knowing what was checked:

1. **The LCRPGR formula works as expected on the Turkey data.** Country-aggregated Turkey 2000–2020 gives LCR ≈ 2.10%/yr, PGR ≈ 1.37%/yr, LCRPGR ≈ 1.54. Plausible and consistent with UN-Habitat's narrative of moderate sprawl in Turkey.
2. **Per-period country-level LCRPGR for Turkey traces a sensible time path** — low (< 1, densification) in the late-1970s/1980s, jumps above 1 around 1990–95 (post-liberalization construction boom), stays around 1.0–1.8 through 2020.
3. **GPW is broken** in our specific dataset (see numbers above).

---

## What the next code work needs to do

In rough order:

1. **`01_build_panel.R` (or `.py`)** — Read all 193 CSVs from `data/raw/`, sum ADM1 rows to ADM0, reshape to long country-year format, write `data/panel_raw.csv`.
   - Columns: `iso3`, `country`, `year`, `built_m2`, `pop_ghsl`, `pop_worldpop` (skip `pop_gpw` entirely or write it to a separate file with a `BROKEN_DO_NOT_USE` warning).
   - Keep only years in {1975, 1980, ..., 2020}. Drop 2018, 2025, 2030.
2. **`02_compute_indicator.R`** — For each country, compute `lcr`, `pgr`, `lcrpgr`, `bu_per_capita` for each 5-year window ending in `t`. Output: country-period panel with one row per (country, period).
   - Flag rows where `abs(pgr) < 0.001` (i.e. < 0.1% per year) — ratio unreliable here. Decide later whether to drop or winsorize.
3. **`03_fetch_covariates.R`** — Pull WDI series using `wbstats` (R) or `wbdata` (Python). Pull WGI separately (it's on World Bank's WGI page, not WDI). Cache to `data/wdi_covariates.csv`.
   - Series IDs are listed in the regressor table above.
4. **`04_merge_and_clean.R`** — Merge panel with covariates by ISO3 + year. Decide on missing-data handling (likely: linear interpolation within country for single missing 5-year cells, drop otherwise).
5. **`05_descriptives.R`** — Summary stats table; world choropleth for 2000–2020 LCRPGR; scatter of ln(GDPpc) vs LCRPGR with regional colors; trajectory plot for Argentina/Turkey/UK (the three example countries we have, so they have provenance the student knows).
6. **`06_regressions.R`** — Use `fixest::feols` (R, fast and clean) or `linearmodels.PanelOLS` (Python). Run the three specifications. Output regression table to LaTeX with `modelsummary`.
7. **`07_robustness.R`** — WorldPop alternative, drop near-zero PGR, secondary indicator, winsorization, region × period interactions.

---

## Tools/packages the student plans to use

R is the recommended path (matches the seminar's reading list mentioning Wickham et al., *R for Data Science*):

- `tidyverse` — data manipulation, ggplot
- `wbstats` — WDI / WGI API
- `countrycode` — ISO matching
- `fixest` — panel regressions (faster than `plm`, two-way FE built in, clustered SEs in one call)
- `modelsummary` — regression tables
- `sf` + `rnaturalearth` — the world map
- `ggplot2` — all figures

If the student prefers Python, the equivalents are `pandas`, `wbdata`, `linearmodels`, `stargazer` or `pystout`, `geopandas`. Both paths are fine. R is closer to what Bitzer/Dannemann typically demonstrate.

---

## Things NOT to do (mistakes to avoid)

- **Don't use `Pop_GPW`.** Even though it's in the data. It's broken. Documented above.
- **Don't use 2025 / 2030 values as outcomes.** They are projections.
- **Don't drop the formula asymmetry between LCR (arithmetic) and PGR (log).** Replicate UN-Habitat exactly. The asymmetry is itself a critique point for the paper.
- **Don't compute LCRPGR at ADM1 level for the main analysis.** ADM1 definitions are not comparable across countries. (A small case study using subnational Turkey could be a footnote or sidebar, but not the main spec.)
- **Don't run pooled OLS only.** Include FE specs — the syllabus calls for "panel regression," and FE is what makes it a real panel analysis.
- **Don't write a 5-page introduction.** 12-page budget is tight. See the page-budget table in `ROADMAP_SDG_11_3_1.md`.

---

## Files in this project (what the student is starting with)

```
sdg1131_paper/
├── ROADMAP_SDG_11_3_1.md         # the full plan
├── CONTEXT.md                    # this file
├── data/
│   └── raw/                      # 193 country CSVs go here
└── docs/
    ├── Metadata-11-03-01.pdf
    ├── Global-Indicator-Framework-after-2026-refinement_Eng.pdf
    └── Development-Economics-SS2026.pdf
```

---

## First message to Claude Code (suggested)

> "Read `ROADMAP_SDG_11_3_1.md` and `CONTEXT.md` and summarize back to me in 5 bullet points: what we're building, what data we have, what's already been decided, what to avoid, and what the first code step is. Then we'll start on `01_build_panel.R`."
