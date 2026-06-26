# Urban Land-Use Efficiency: A Stable Metric for SDG 11.3.1 and Its Economic Drivers

> ⚠️ **Work in progress — not finalised.** This project is **actively under
> development** for an ongoing seminar (SoSe 2026). Code, data, results, and the
> written paper may still change. Please treat everything here as preliminary and
> do not cite it as a completed work.

Development Economics seminar, University of Oldenburg (SoSe 2026).
Author: Ömer Furkan Çoban.
Project date: 13.06.2026.

This project

- (1) shows that the **official SDG 11.3.1 indicator (LCRPGR) is
  statistically unstable**,
- (2) proposes a stable, log-based replacement, the
  **Built-up per Capita Rate (BpCR)**, and
- (3) estimates the **economic drivers** of
  urban land use across a harmonised satellite panel of **193 UN member states,
  1985–2020**, using two-way fixed effects and dynamic-panel GMM, with a
  **heterogeneity analysis** by development group and a **sub-national German
  case study** (supplementary).

---

## 1. Motivation

By 2050 roughly two-thirds of humanity will live in cities. Cities *must* grow to
house more people, that is normal. The development-policy question is not whether
land expands, but **how much land each new urban resident consumes**: if built-up
area grows in step with population the city stays compact; if it grows much faster,
the city **sprawls**, paving over farmland, locking in car dependence, and raising
per-capita emissions and the per-capita cost of infrastructure.

SDG **target 11.3** asks countries to keep land consumption in line with
population growth, and **indicator 11.3.1** operationalises this as the ratio of
the Land Consumption Rate to the Population Growth Rate (**LCRPGR**). It is the
official global yardstick, so its statistical properties matter for how every
country is judged.

## 2. The problem: LCRPGR is an unstable yardstick

$\text{LCRPGR} = \text{LCR} / \text{PGR}$, where $\text{LCR}$ is the (arithmetic) growth rate of built-up area
and $\text{PGR}$ is the (logarithmic) population growth rate. Two flaws follow:

1. **Division by a near-zero denominator.** When population is roughly flat
   ($\text{PGR} \approx 0$) the ratio explodes towards $\pm\infty$ and flips sign, so small, ordinary
   demographic differences produce wild, uninterpretable values.
2. **Arithmetic-vs-log asymmetry.** The numerator uses arithmetic growth while the
   denominator uses logarithmic growth, so the ratio is not symmetric and does not
   aggregate cleanly over time.

The result is a metric whose tails are dominated by an arithmetic artefact rather
than by real land-use behaviour.

## 3. The contribution: Built-up per Capita Rate (BpCR)

We measure the **log change in built-up area per person**:

$$
\text{BpCR} = \frac{1}{z}\,\ln\!\left(\frac{V_t/P_t}{V_{t-z}/P_{t-z}}\right) = \text{LCR}_{\log} - \text{PGR}_{\log}
$$

where $V$ = urban built-up area, $P$ = urban population, $z$ = period length.
Because it is the **difference of two logarithmic growth rates**, BpCR is:

- **finite and well-defined for every country-period** (no division by ~0),
- **symmetric** (densification and sprawl are mirror images around 0),
- **additively decomposable** ($`\text{BpCR} = \text{LCR}_{\log} - \text{PGR}_{\log}`$), and
- **directly interpretable**: $\text{BpCR} > 0$ = sprawl (more land per resident),
  $\text{BpCR} < 0$ = densification, $\text{BpCR} = 0$ = land grows exactly with population.

BpCR reproduces the same policy signal as LCRPGR where LCRPGR is well-behaved, but
without the instability. It complements, rather than contradicts, the indicator.

## 4. Data sources

Everything is fetched by code; nothing is placed manually. The analysis uses a
single, **urban-scale** panel built under the EU/UN **Degree of Urbanisation**
(urban = `GHS-SMOD ≥ 21`), so built-up and population are measured consistently.

| Source                                   | Variable                                               | Access                     |
| ---------------------------------------- | ------------------------------------------------------ | -------------------------- |
| **GHS-BUILT-S** R2023A (GHSL, JRC) | Urban built-up area`V`                               | Google Earth Engine        |
| **GHS-POP** R2023A (GHSL, JRC)     | Urban & total population`P`                          | Google Earth Engine        |
| **GHS-SMOD** R2023A (GHSL, JRC)    | Degree of Urbanisation mask; map overlay               | GEE + JRC download         |
| **GAUL 2024 L1** (FAO)             | Reporting units (193 states)                           | public GEE`sat-io` asset |
| **GAUL 2025 L1/L2** (FAO)          | Map boundaries (choropleth fill + WMS)                 | FAO GeoServer WFS/WMS      |
| **UN SNAAMA**                      | GDP per capita (constant 2020 US$)                     | UN download                |
| **UN DESA WPP 2024**               | International net migration; national total population | UN download                |
| **UN M49 / `countrycode`**       | Region & development group                             | R package                  |

Coverage: **193 UN member states**, 5-year epochs **1985–2020**. Full bibliographic
citations are in `04_presentation/references.bib`.

> Earlier WDI-population / WGI-governance machinery has been removed; the project
> now relies on the GHSL satellite panel with UN controls only.

## 5. Methodology

**Panel construction (metadata-faithful).** Built-up and population are summed to
the national level *first*, then rates and ratios are formed (never average
ratios; per the UN-Habitat metadata). Both LCRPGR and BpCR are computed on the
identical urban panel so the comparison is like-for-like.

**Specification.** One specification, run with each metric as the dependent
variable:

$$
\text{Metric}_{it} = \rho\,\text{Metric}_{i,t-1} + \beta_1 \ln(\text{UrbDens}) + \beta_2\,\text{UrbShare} + \beta_3 \ln(\text{GDPpc}) + \beta_4\,\text{NetMigr} + \mu_i + \delta_t + \varepsilon_{it}
$$

with country fixed effects $\mu_i$, period fixed effects $\delta_t$, and SEs clustered by
country.

**Two-stage strategy.**

1. **Static** (drop the lagged DV) to isolate *metric* effects: LCRPGR vs BpCR.
2. **Dynamic** (add the lagged DV) for path-dependence. The lagged-dependent-
   variable coefficient is **downward-biased under fixed effects (Nickell bias)**,
   so it is corrected with **Arellano-Bond difference GMM** and **Blundell-Bond
   system GMM**, instrumenting with deeper lags. Validity is checked with the
   **Sargan/Hansen** over-identification test and the **AR(2)** serial-correlation
   test (both p > 0.10 = instruments valid).

## 6. Key findings

**The metric matters.** On the same data, LCRPGR's instability shows up in its
extreme tails, whereas BpCR is well-behaved across all country-periods; sprawl is
real and measurable but is over- and under-stated by LCRPGR exactly where $\text{PGR}$
is small. On identical data, replacing LCRPGR with BpCR raises the within-country
explanatory power **roughly twenty-fold** (within $R^2$ about 0.003 → 0.065) and
turns uninformative coefficients into significant, interpretable ones.

**Sprawl is the global norm.** A majority of countries show $\text{BpCR} > 0$ over
1985–2020: built-up area is growing faster than urban population for most of the
world.

**Economic drivers (Arellano-Bond GMM; dependent variable BpCR):**

| Driver                      | Coef.          | Reading                                                                                                                     |
| --------------------------- | -------------- | --------------------------------------------------------------------------------------------------------------------------- |
| BpCR (t−1), ρ             | +0.61\*\*\*    | Strong path-dependence; ~60% of last period's BpCR persists. GMM ρ ≈ 3× the FE estimate, confirming the FE Nickell bias. |
| ln(Urban density)           | −0.052\*\*\*  | Compact-city effect: denser cities consume less new land per resident.                                                      |
| Int'l net migration (% pop) | −0.0005\*     | In-migrants pack into the existing stock faster than built-up grows.                                                        |
| ln(GDP per capita)          | −0.014\*\*    | Within-country, richer countries**densify, not sprawl**: growth ≠ sprawl.                                            |
| Urban population share      | −0.031 (n.s.) | The*level* of urbanisation adds nothing once the rest is controlled: urban **form**, not stage, drives land use.    |

Estimation sample 1,499 country-periods; Arellano-Bond uses 1,351 and Blundell-Bond
1,544 observations (15 vs 21 collapsed instruments). Sargan/Hansen and AR(2) tests
pass (instruments valid). `*** p<0.01, ** p<0.05, * p<0.1`.

> The within-country income → densification result **complements** the
> cross-sectional income → sprawl literature: across countries richer places have
> sprawled historically, but *within* a country, getting richer over time is
> associated with denser, not more sprawling, urban land use.

**Heterogeneity (by UN development group).** The income–densification link is
negative in all three groups, most precise in the developed and developing
economies; the compact-city density effect is strongest in the least-developed
countries (where urban form is still being set); and international net migration
densifies in the developed and developing groups but not in LDCs, where internal
rural-to-urban migration (unobserved here) dominates. A sub-national German
case study (`05_paper/supplementary.qmd`) reproduces the metric breakdown and the
income–densification result at the *Kreis* level.

*(All figures are reproduced from the committed data by the pipeline; coefficient
chips in the slides are generated directly from the GMM output, so they never go
stale.)*

## 7. Deliverables

| Output                   | Source                               | Build                                                 |
| ------------------------ | ------------------------------------ | ----------------------------------------------------- |
| Presentation (reveal.js) | `04_presentation/presentation.qmd` | `quarto render` → `presentation.html` / `.pdf` |
| Paper (PDF)              | `05_paper/paper.qmd`               | `quarto render` → `paper.pdf`                    |
| Supplementary (PDF)      | `05_paper/supplementary.qmd`       | `quarto render` → `supplementary.pdf`            |

## 8. Project structure

```
.
├── run_pipeline.R          # master orchestrator (download -> process -> render)
├── 00_notes/               # project notes, SDG 11.3.1 metadata
├── 01_literature/          # reference PDFs
├── 02_scripts/
│   ├── 00_setup/           # packages, encrypted-credential utils, GEE asset upload
│   ├── 01_data_preprocessing/  # 01-03 GEE collections; 04-07 web downloads (GAUL 2025, UN, GHS-SMOD)
│   └── 02_analysis/        # 01-03 panel + GMM; 04-06 deck figures; 07-08 paper figures; 09 German case study
├── 03_datasets/
│   ├── raw/                # GHSL/GAUL rasters & zonal stats - NOT committed; rebuilt with --gee
│   ├── processed/          # committed analysis panels (project runs from these)
│   └── config/             # encrypted credentials (*.enc) + un_member_iso3.csv
├── 04_outputs/figures/     # interactive HTML maps used by the deck
├── 04_presentation/        # deck, CSS, logos, shared references.bib
└── 05_paper/               # paper.qmd (references.bib -> ../04_presentation)
```

## 9. How to run

```bash
# Render from the committed processed data (no GEE needed) - the common case:
Rscript run_pipeline.R

# Rebuild everything from source, incl. GEE collection (slow; needs EE credentials):
Rscript run_pipeline.R --gee --force

# Build data/figures but skip rendering:
Rscript run_pipeline.R --no-render
```

The pipeline is **strictly sequential, auto-skips finished steps, and stops on
failure**. Because the repo ships the processed panels in `03_datasets/processed/`,
a fresh checkout goes straight to figures + render. Raw GHSL/GAUL data is not
committed; `--gee` re-collects it (GEE steps need Earth Engine credentials; the
web downloads do not).

## 10. Requirements

- **R** (≥ 4.2): `here`, `tidyverse`, `fixest`, `plm`, `modelsummary`, `gt`,
  `leaflet`, `plotly`, `terra`, `sf`, `countrycode` (see `02_scripts/00_setup/00_import.R`).
- **Quarto** (≥ 1.4) on `PATH`, plus LaTeX/TinyTeX for the paper PDF.
- **Google Earth Engine** account + the `rgee`/Python stack **only** for `--gee`.

## 11. Credentials & reproducing the raw collection

**No credentials are shipped with this repo**, and you do not need the author's.
The committed `processed/` data already lets you reproduce the entire analysis,
figures, and deck **without any Google account** (`Rscript run_pipeline.R`).

To rebuild the **raw** data from source (`--gee`), use **your own** free Google
Earth Engine + Drive. The setup scripts **fall back to your own login** whenever
the author's encrypted credentials are absent:

1. Create a (free) Earth Engine account and authenticate once:
   `earthengine authenticate` (or `ee$Authenticate()` in Python / `rgee::ee_Authenticate()`).
2. Point the pipeline at **your** Cloud project, e.g. in `~/.Renviron`:
   `GEE_PROJECT=your-ee-project`
3. Run `Rscript run_pipeline.R --gee`. When no `*.enc` is found the scripts
   automatically use your interactive Earth Engine / Google Drive login (your
   GEE exports land in your own Drive, then download locally).

> The author's own credentials live **only** locally as encrypted `*.enc` files
> (git-ignored). They are intentionally **not** published: the in-repo decryption
> password would otherwise make them readable, and live credentials on a public
> repo can be abused (GEE/Drive quota, billing) and are auto-revoked by Google.
> `02_scripts/00_setup/02_configure_secrets.R` shows how the author created them,
> should you wish to cache your own the same way.

## 12. Attribution

GHSL data © European Union, 1995–2025 (CC BY 4.0); cite Pesaresi et al. (2024).
GAUL © FAO (CC BY 4.0). UN data © United Nations. See `references.bib` for the
full, citable reference list.
