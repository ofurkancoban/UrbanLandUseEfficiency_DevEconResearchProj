# Seminar Paper Roadmap — SDG 11.3.1 (LCRPGR)
**Development Economics, SS 2026 — Bitzer & Dannemann**
**Author:** [your name]

---

## 0. Project at a glance

**Indicator:** SDG 11.3.1 — Ratio of land consumption rate to population growth rate (LCRPGR).
**Custodian agency:** UN-Habitat.
**Why it matters:** It is the SDG framework's only quantitative measure of *land-use efficiency* in cities. A ratio > 1 means built-up area grows faster than population (sprawl); a ratio < 1 means densification.

**Research question:** *What country-level economic and structural factors explain cross-country variation in LCRPGR between 1975 and 2020?*

**Deliverables (from the syllabus, p. 2):**
1. 15-minute presentation + 3-minute discussion opener for another student's paper.
2. Written elaboration up to 12 pages (incl. references, tables).
3. Reproducible code files (R or any language — no formatting requirement).
4. Grade split: 50% presentation + opener, 50% written paper. All parts must pass.

---

## 1. The indicator — definition, formula, data

### 1.1 Formula

Annual land consumption rate (LCR):
$$LCR = \frac{V_{present} - V_{past}}{V_{past}} \cdot \frac{1}{t}$$

Annual population growth rate (PGR):
$$PGR = \frac{\ln(Pop_{t+n}/Pop_t)}{y}$$

LCRPGR:
$$LCRPGR = \frac{LCR}{PGR}$$

Note the asymmetry: LCR uses simple (arithmetic) growth, PGR uses continuous (log) growth. UN-Habitat's own metadata fixes this; do not "improve" it — replicate it exactly.

### 1.2 Data sources in the uploaded CSVs

Each CSV contains ADM1 (subnational) rows for one country. Columns:

| Column family | What it is | Source |
|---|---|---|
| `Built_GHSL_<year>` | Built-up area in m², per ADM1 unit | GHSL (JRC) |
| `Pop_GHSL_<year>` | Population, per ADM1 unit | GHSL (JRC) |
| `Pop_GPW_<year>` | Population, per ADM1 unit | Gridded Population of the World (CIESIN) |
| `Pop_WorldPop_<year>` | Population, per ADM1 unit | WorldPop |
| `ADM0_*`, `ADM1_CODE`, `NAME_1`, `Country_*` | Identifiers | — |

Years available: 1975, 1980, 1985, 1990, 1995, 2000, 2005, 2010, 2015, 2018, 2020, 2025, 2030.

### 1.3 Choices made (and to defend in the paper)

| Choice | Decision | Justification |
|---|---|---|
| Geographic unit | **Country-year panel** (aggregate ADM1 → ADM0) | Lecture asks for OLS panel; cross-country variation aligns with development-economics tradition; ADM1 not consistently defined across countries (UK has 4 mega-units, Turkey has 80 provinces). |
| Population source | **GHSL primary**, WorldPop for robustness, GPW dropped | GPW values in the dataset are implausible (Turkey 2000 → 4.7B people, clear unit/aggregation error). GHSL is internally consistent with built-up area (same producer). WorldPop only starts in 2000. |
| Period length | **5 years** (UN-Habitat-recommended minimum) | More periods → more observations; matches metadata Section 3.c. |
| Time span | **1975–2020 only** | 2025 and 2030 are projections; using them as outcomes biases results toward modeling assumptions, not reality. |
| Projection years | Excluded from estimation | See above. |
| 2018 column | Excluded from main analysis | Off-grid year, harder to match WDI 5-year cells. Mention in footnote. |

This yields a panel of **193 countries × 9 five-year periods** (1975–80, 1980–85, …, 2015–20) ≈ 1,737 country-period observations. After dropping missing covariates, expect ~1,200–1,400 usable rows.

---

## 2. Literature anchors

These are the papers to cite explicitly — your literature review (~1.5 pages) should be organized around the four mechanisms below, with these as the backbone.

### 2.1 Foundational / theoretical

| Reference | What it gives you |
|---|---|
| **Angel, S., Parent, J., Civco, D. L., Blei, A., Potere, D. (2011).** "The dimensions of global urban expansion: Estimates and projections for all countries, 2000–2050." *Progress in Planning*, 75(2), 53–107. | The definitional paper for global land-consumption monitoring. Establishes that built-up area grows ~2× faster than urban population globally. |
| **Brueckner, J. K. (2000).** "Urban sprawl: diagnosis and remedies." *International Regional Science Review*, 23(2), 160–171. | Theoretical mechanism #1: income → housing demand → outward expansion. The monocentric-city framework that underpins almost all sprawl economics. |
| **Glaeser, E. L., Kahn, M. E. (2004).** "Sprawl and urban growth." *Handbook of Regional and Urban Economics*, vol. 4. | Empirical decomposition of sprawl drivers; good for the "why does this happen" narrative. |

### 2.2 Empirical / SDG-monitoring

| Reference | What it gives you |
|---|---|
| **Mahtta, R. et al. (2022).** "Building up or spreading out? Typologies of urban growth across 478 cities of 1 million+." *Environmental Research Letters*, 17(6). | Most recent typology of urban-growth patterns globally. Shows that LCRPGR alone hides 3D growth (vertical densification). |
| **Liu, X. et al. (2020).** "High-spatiotemporal-resolution mapping of global urban change from 1985 to 2015." *Nature Sustainability*, 3, 564–570. | Validates GHSL-style products and discusses measurement uncertainty. |
| **Melchiorri, M. et al. (2019).** "Unveiling 25 years of planetary urbanization with remote sensing: Perspectives from the Global Human Settlement Layer." *Remote Sensing*, 11(5). | Direct documentation of your data source (GHSL). |
| **UN-Habitat (2023).** *World Cities Report 2022* | Official narrative on SDG 11; cite for stylized facts. |

### 2.3 Mechanism / structural-transformation lit

| Reference | What it gives you |
|---|---|
| **Todaro & Smith (2020), Ch. 7 ("Urbanization and rural-urban migration")** | The Todaro model and structural-transformation framing — your course textbook. Use it explicitly to motivate agriculture-share and urbanization-rate regressors. |
| **Henderson, J. V. (2003).** "The urbanization process and economic growth: The so-what question." *Journal of Economic Growth*, 8(1), 47–71. | The classic on urbanization-growth links. |
| **Jedwab, R., Vollrath, D. (2015).** "Urbanization without growth in historical perspective." *Explorations in Economic History*, 58, 1–21. | Important counter-narrative: many developing countries urbanize without GDP-per-capita growth, which complicates the income-sprawl story. |

### 2.4 Indicator critique (Hughes-Ayaburi style, the kind the syllabus asks for)

The syllabus (p. 2) explicitly cites Hughes et al. (2017) and Ayaburi et al. (2020) as templates for *critically assessing* an indicator. For SDG 11.3.1, the critiques to anchor are:

- **Interpretation ambiguity** (UN-Habitat metadata 4.b): LCRPGR < 1 may mean "good densification" or "harmful congestion"; LCRPGR > 1 may mean "harmful sprawl" or "healthy housing-supply response." Cannot be read in isolation.
- **Negative/zero PGR**: ratio undefined or sign-flipped when population shrinks (Eastern Europe, Japan); these get dropped or distorted in cross-country aggregation.
- **Measurement-source sensitivity**: as we showed above, the choice of population dataset can change a country's LCRPGR by 2× or more. This is the empirical "money shot" of your paper's critique section.
- **Definition of "city"**: DEGURBA was only endorsed in 2020; pre-2020 figures used a patchwork of national definitions. Cross-country comparability before 2020 is genuinely weak.

---

## 3. Empirical strategy

### 3.1 Estimating equation (main)

$$LCRPGR_{i,t} = \alpha + \beta_1 \ln(GDPpc)_{i,t-1} + \beta_2 \text{Urban}_{i,t-1} + \beta_3 \text{AgriShare}_{i,t-1} + \beta_4 \ln(\text{Density})_{i,t-1} + \mathbf{Z}_{i,t-1}'\boldsymbol{\gamma} + \delta_t + \mu_i + \varepsilon_{i,t}$$

- $i$ = country, $t$ = 5-year period ending in 1980, 1985, …, 2020.
- $LCRPGR_{i,t}$ = ratio computed over the 5 years ending at $t$.
- All regressors are measured at the **start** of the 5-year window (lagged), to mitigate reverse-causality.
- $\delta_t$ = period FE; $\mu_i$ = country FE (in the two-way-FE specification).

### 3.2 Specifications to estimate

Report all three in one table, side by side:

1. **Pooled OLS** (baseline). Robust SEs clustered by country.
2. **Period FE only** (cross-country variation drives identification).
3. **Two-way FE** (country + period). Identification is from within-country changes over time. This is the strongest spec given the syllabus calls for "simple OLS panel regression" — FE is OLS with dummies.

A useful pedagogical move: show how β₁ (income) changes as you add fixed effects. Discuss what each coefficient is "saying" identification-wise.

### 3.3 Regressors — core + extended

**Core (always in):**

| Variable | WDI / source | Expected sign | Mechanism |
|---|---|---|---|
| `ln_gdp_pc` | WDI `NY.GDP.PCAP.PP.KD` | + | Brueckner: income → housing space → outward expansion |
| `urban_share` | WDI `SP.URB.TOTL.IN.ZS` | + (then flat) | Active urbanization phase drives built-up consumption; saturates in rich economies |
| `agri_share` | WDI `NV.AGR.TOTL.ZS` | – | Structural transformation: lower agri share = more advanced urbanization stage, less greenfield demand |
| `ln_pop_density` | WDI `EN.POP.DNST` (lagged) | – | High initial density → higher marginal cost of sprawl, more vertical growth |

**Extended (pick 2–3):**

| Variable | Source | Mechanism |
|---|---|---|
| `gov_effectiveness` | WGI | Weak planning institutions → uncontrolled expansion |
| `motorization` | WDI `IS.VEH.NVEH.P3` | Car ownership unlocks low-density suburbs (Brueckner direct) |
| `manuf_share` | WDI `NV.IND.MANF.ZS` | Industrial parks at urban edge drive horizontal expansion |
| `household_size` | UN DESA / Demographic Yearbook | Shrinking households → more housing units per person |

**Recommendation: take motorization + government effectiveness.** They are easy to fetch from public APIs and map cleanly to two distinct, well-cited mechanisms (one on the demand side, one on the institutional side).

### 3.4 Robustness checks (mention in paper, even if compact)

1. Re-estimate with **WorldPop population** instead of GHSL for the 2000–2020 sub-sample.
2. Drop countries with PGR < 0.1%/year (avoids dividing by ≈0).
3. Estimate on the **secondary indicator** `built_up_per_capita` change instead of LCRPGR (UN-Habitat recommends this as an interpretation aid; metadata Section 4.c.f).
4. Winsorize LCRPGR at 1st/99th percentile (some country-periods will have crazy ratios; censor not drop).
5. Region dummies × period interactions (sprawl drivers may differ by region).

---

## 4. Tables and figures for the paper

Aim for **3 figures + 3 tables**. More than that and you blow the 12-page budget on whitespace.

### Figures
1. **World map of LCRPGR, 2000–2020.** Choropleth; immediately tells the reader the geography of sprawl.
2. **Scatter: ln(GDP per capita) vs LCRPGR**, pooled, with regional colors. Shows the headline cross-country relationship.
3. **Within-country trajectories: Argentina, Turkey, UK (your three sample countries).** Lines for LCR, PGR, and the ratio over 1975–2020. Tells the "case study" story and grounds the country-year panel.

### Tables
1. **Summary statistics.** Mean, SD, min, max, N for the outcome and all regressors, full sample and by income group.
2. **Main regression table.** Three columns (pooled, period FE, two-way FE) for the core spec; two extra columns adding extended regressors.
3. **Robustness table.** Each row a robustness variant, columns = β₁, β₂, β₃, β₄ (and SEs).

---

## 5. Paper structure (12-page budget)

| Section | Pages | Content |
|---|---|---|
| 1. Introduction | 1.0 | Motivating question + headline finding + roadmap. |
| 2. The indicator | 1.5 | Definition, formula, data sources, critique of construction (this is where the Hughes/Ayaburi-style indicator critique lives). |
| 3. Literature & mechanisms | 1.5 | Four mechanisms, each one paragraph, with citations. |
| 4. Data | 1.5 | GHSL primary, WorldPop alt, GPW excluded (with the dramatic Turkey example as Figure 0). Variable construction. Sample. |
| 5. Empirical strategy | 1.0 | Equation, FE choice, identification discussion. |
| 6. Results | 2.0 | Main table + Figure 2 + Figure 3 + interpretation. |
| 7. Robustness | 1.0 | Compact discussion + table. |
| 8. Discussion & limitations | 1.0 | Indicator critique revisited in light of results. Policy reading. |
| 9. Conclusion | 0.5 | One paragraph. |
| References | ~1.0 | ~20 entries. |

---

## 6. 12-week timeline

The seminar starts **13 April 2026** with topic distribution and runs through the term. Working backwards from a presentation that's most likely in **late May or June** (block seminar dates set on Day 1):

| Week | Dates (approx.) | Milestone |
|---|---|---|
| 0 — pre-seminar | now → 13 April | **You are here.** Indicator chosen, sample data inspected, roadmap drafted. |
| 1 | 13–19 April | Topic confirmed at first meeting. Collect remaining country CSVs into one combined panel. Fetch WDI covariates (`wbstats` or `WDI` package in R). |
| 2 | 20–26 April | Build full country-year panel. Compute LCR, PGR, LCRPGR, built-up per capita. Sanity-check against UN-Habitat published numbers for ~5 countries. |
| 3 | 27 Apr – 3 May | Descriptive statistics. Maps. Figures 2 and 3. Decide on final regressor set. |
| 4 | 4–10 May | First regression results. Show to instructor/peer. |
| 5 | 11–17 May | Robustness checks. Lock the main table. |
| 6 | 18–24 May | Draft paper sections 1, 2, 3, 4. |
| 7 | 25–31 May | Draft sections 5, 6, 7. |
| 8 | 1–7 June | Draft sections 8, 9. Polish figures. |
| 9 | 8–14 June | Build presentation slides. Practice. |
| 10 | 15–21 June | **Slack week.** Buffer for problems. |
| 11 | depending on date | Present. Final paper revisions after feedback. |
| 12 | end of term | Submit written elaboration + code. |

---

## 7. Code and reproducibility plan

Syllabus only says "code files for reproducing the data analysis (no specific formatting required)" — but Bitzer/Dannemann are empirical economists, so submit something that actually runs end-to-end. Suggested structure:

```
sdg1131_paper/
├── data/
│   ├── raw/                    # 193 country CSVs as-shipped
│   ├── wdi_covariates.csv      # downloaded once, cached
│   └── panel.csv               # built by 01_build_panel
├── code/
│   ├── 01_build_panel.R        # CSVs → long country-year panel
│   ├── 02_compute_indicator.R  # LCR, PGR, LCRPGR, BUpc
│   ├── 03_fetch_covariates.R   # WDI/WGI via API, cached
│   ├── 04_descriptives.R       # Figures 1, 3, Table 1
│   ├── 05_regressions.R        # plm or fixest; Tables 2, 3
│   └── 06_robustness.R
├── figures/                    # all .pdf/.png outputs
├── tables/                     # all .tex/.csv outputs
├── paper/
│   └── paper.tex (or .Rmd / .qmd)
└── README.md                   # one paragraph + run instructions
```

R packages to plan on: `tidyverse`, `WDI`, `countrycode`, `fixest` (faster than `plm`, handles two-way FE and clustered SEs in one call), `modelsummary` (regression tables), `sf` + `rnaturalearth` (map), `ggplot2`.

---

## 8. Risks and what to watch for

| Risk | Mitigation |
|---|---|
| Negative or near-zero PGR breaks the ratio | Drop |PGR| < 0.1%/yr; report how many countries this affects. |
| WDI series missing for some country-periods | Linear interpolation within country for ≤1 missing 5-year cell; drop otherwise. Document carefully. |
| Mechanical correlation between LCRPGR and PGR-related regressors | Discuss openly in section 5. This is a *feature* of the critique, not a bug to hide. |
| 12-page limit | Push lit review and robustness to compact form early; don't write 5-page intros. |
| Presentation overrun (15 min hard cap) | 1 slide per minute target. Cut anything that doesn't make the headline graph or headline result. |

---

## 9. Next steps

1. **Build the full panel** from all 193 country CSVs (script `01_build_panel.R`).
2. **Compute LCRPGR** at country level for all 5-year windows (script `02_compute_indicator.R`).
3. **Spot-check** the resulting values against UN-Habitat's published country averages for ~5 countries to catch any aggregation errors.
4. **Fetch WDI covariates** and merge.
5. First descriptive plots and one trial regression.
