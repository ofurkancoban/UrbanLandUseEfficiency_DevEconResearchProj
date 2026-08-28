# Urban Land-Use Efficiency: A Stable Metric for SDG 11.3.1, and Why Per-Capita Designs Cannot Cleanly Identify Its Drivers

Development Economics Seminar, University of Oldenburg (SoSe 2026).
Author: Ömer Furkan Çoban.
Project Date: 13.06.2026.

This project

- (1) shows that the **official SDG 11.3.1 indicator (LCRPGR) is
  statistically unstable**,
- (2) adopts the stable, log-based replacement proposed by Lu & Weng (2026), the
  **Built-up per Capita Rate (BpCR)** (the general case for a log alternative is
  made by both Nicolau et al. (2019) and Lu & Weng), and
  shows what it is worth: on identical data, the official ratio leaves every
  driver undetectable at the 5% level while BpCR recovers precise ones, and
- (3) estimates the **economic drivers** of
  urban land use across a harmonised satellite panel of **193 UN member states,
  1985–2020**, using two-way fixed effects and dynamic-panel GMM, with a
  **heterogeneity analysis** by development group and a **sub-national German
  case study** (supplementary), and shows that a **per-capita design can
  manufacture the very drivers it appears to detect**: urban density's
  celebrated "compact-city" coefficient turns out to be an artefact of the
  metric's own arithmetic, not a behavioural effect.

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
\text{BpCR} = \frac{1}{z}\,\ln\left(\frac{V_t/P_t}{V_{t-z}/P_{t-z}}\right) = \text{LCR}_{\log} - \text{PGR}_{\log}
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

Coverage: **193 UN member states**. BpCR is observed at nine 5-year epochs,
**1980–2020**, formed from the 1975–2020 GHSL grids; after the lagged dependent
variable and complete-case filtering the estimation sample is **1,499**
country-periods on 192 countries over eight epochs, **1985–2020**. Full
bibliographic citations are in `04_presentation/references.bib`.

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
is small. The comparison is about **detectability, not explained variance**: with
identical data, controls and fixed effects, *no* driver is distinguishable from
zero under the official ratio (largest $|t| = 1.66$), while the same net-migration
variable goes from $t = -1.12$ under LCRPGR to $t = -5.04$ under BpCR. We do not
quote a ratio of the two within $R^2$ values (0.003 vs 0.212): they are shares of
the variance of *different* dependent variables, so their quotient is not a
meaningful quantity.

**Sprawl is the global norm.** A majority of countries show $\text{BpCR} > 0$ over
1985–2020: built-up area is growing faster than urban population for most of the
world.

**Economic drivers (final model; dependent variable BpCR):**

The full model's Arellano-Bond and Blundell-Bond columns **fail their Hansen
over-identification test** (p = 0.05 and p = 0.01), so no coefficient from that
specification, not ρ and not the controls, is read as consistent. The control
coefficients below are therefore read from the **fixed-effects column**, which
needs no instrument validity; GMM is used only where a moment-valid
specification exists.

| Driver                        | Coef. (FE)     | Reading                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| ----------------------------- | -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| BpCR (t−1), ρ               | — (bracketed) | Path-dependence.**No single point estimate is reported.** The full-model AB ρ (0.21) comes from the Hansen-failing specification above and is not read. Stripping out the arithmetically entangled density/urban-share controls restores moment validity and lifts ρ: across those clean specifications it ranges **0.34–0.46**, close to the Nickell (1981)-implied value (0.45); Blundell-Bond lands nearby (0.46) but its own Hansen test also fails, so that is read as coincidence, not corroboration. First-stage F = 14.4 rules out weak instruments. **Persistence is substantial, plausibly a third to a half of one period's growth.** |
| Int'l net migration (% pop)   | −0.0064\*\*\* | **The robust correlate.** A Hansen-valid GMM specification (migration entered alone with the lagged DV, Hansen p = 0.17) returns −0.0063, closely matching. Consistent with in-migrants being absorbed into the existing stock faster than built-up grows: urban population moves +0.88 pp/yr with migration, built-up only +0.24 pp/yr. Passes a Wooldridge lead test and is close to invariant under a predetermined treatment, but migrants may select into fast-building economies, so this is a conditional association, not a causal effect.                                                                                                             |
| ln(Urban density) (t−1)      | +0.014\*\*\*   | *Not* a compact-city effect: see the timing artefact below. The full model's AB (+0.037) and BB (−0.001) estimates come from the same Hansen-failing specification and carry no independent weight; density never enters a moment-valid GMM specification, so its magnitude is read from FE and the clean $t-2$ timing only.                                                                                                                                                                                                                                                                                                                                     |
| ln(GDP per capita)            | −0.003 (n.s.) | Sign negative in every specification and group, but never significant once migration is measured over the right window.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Urban population share (t−1) | +0.011 (n.s.)  | The*level* of urbanisation adds nothing once the rest is controlled: urban **form**, not stage, drives land use.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |

Estimation sample 1,499 country-periods; Arellano-Bond uses 1,307 and Blundell-Bond
1,500 observations (15 vs 21 collapsed instruments). AR(2) passes comfortably
(p = 0.76) throughout. The weak-instrument objection that difference GMM invites is
addressed directly rather than assumed away: first-stage F = 14.4, and in the
clean AR(1) the estimator moves *away* from the within estimate by exactly the
Nickell-predicted amount, which weak instruments could not do (they would pull it
toward within). The full model's low ρ and its failing Hansen test are both
caused by the entangled density/urban-share controls, not by the instruments.
`*** p<0.01, ** p<0.05, * p<0.1`.

> **The compact-city coefficient is arithmetic, not (only) economics.** By
> construction
> $\text{BpCR}_t=\frac{1}{z}[\ln V_t-\ln P_t-\ln V_{t-1}+\ln P_{t-1}]$, so urban
> population enters *negatively* at $t$ and *positively* at $t-1$. Density and
> urban share are built from that same count, so each inherits the sign of the
> date it is measured at (verified directly: regressing BpCR on $\ln P_t$ and
> $\ln P_{t-1}$ gives −0.103 and +0.106, equal and opposite). Lagging by one
> period does not fix this, it flips the bias. Only a $t-2$ control shares no term
> with BpCR: there density is **+0.011** (significant), still not negative. **H2
> is not supported, but tentatively**: the measure used here is *settlement*
> density, not the more entangled *built-up* density the compact-city mechanism
> properly rests on, so the paper stops short of refuting compact cities
> outright.

**Heterogeneity (by UN development group).** These are **static FE** estimates (no
lagged DV), so they are not directly comparable to the dynamic FE/GMM figures in
the table above, but the estimator, controls, and sample are held identical
across the three groups. Net in-migration
is negative and significant in *all three* groups at nearly identical magnitudes
(−0.0065, −0.0062, −0.0066, against a pooled −0.0064), which is why we treat it as
the robust finding. Income is negative everywhere but significant nowhere. The
positive lagged-density coefficient (pooled static +0.010) is carried entirely by
the developing group (+0.017); the urban-share channel survives only in the LDCs
(+0.112). A sub-national German case study
(`05_paper/supplementary.qmd`) independently reproduces the timing artefact on
different data and at a different scale (density −0.029 at $t$, +0.031 at the
clean $t-2$), while internal migration turns out to be essentially zero within
districts.

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
# Interactive (recommended): asks once whether to reuse the committed panel
# (fast, no downloads) or re-download and rebuild every raw input from source.
Rscript run_pipeline.R

# Non-interactive, explicit: skip the prompt and reuse the committed panel.
Rscript run_pipeline.R --no-gee

# Non-interactive, explicit: skip the prompt and rebuild everything from
# source, incl. GEE collection (slow; needs EE credentials):
Rscript run_pipeline.R --gee --force

# Build data/figures but skip rendering:
Rscript run_pipeline.R --no-render
```

The pipeline is **strictly sequential, auto-skips finished steps, and stops on
failure**. Because the repo ships the processed panels in `03_datasets/processed/`,
a fresh checkout can go straight to figures + render, and running it from a
terminal will ask you to confirm that's what you want before proceeding. Piped
or non-interactive runs (cron, CI, `< /dev/null`) can't answer that prompt, so
they skip it and default to the committed panel automatically. Raw GHSL/GAUL
data is not committed; `--gee` (or answering "2" at the prompt) re-collects it
(GEE steps need Earth Engine credentials; the web downloads do not).

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

1. **Create a Google Cloud project** (free, no billing required for Earth
   Engine's non-commercial tier):
   - Go to [console.cloud.google.com/projectcreate](https://console.cloud.google.com/projectcreate),
     give it any name (e.g. `my-urban-lue`), and create it. Note the **Project ID**
     shown there (not the display name; it is what `GEE_PROJECT` needs below).
   - Enable the Earth Engine API for that project: open
     [console.cloud.google.com/apis/library/earthengine.googleapis.com](https://console.cloud.google.com/apis/library/earthengine.googleapis.com),
     select your new project, and click **Enable**.
   - Register the project for Earth Engine access at
     [code.earthengine.google.com/register](https://code.earthengine.google.com/register)
     (choose the **unpaid/non-commercial** option for academic/personal use) and
     pick the same project.
2. Create a (free) Earth Engine account and authenticate once:
   `earthengine authenticate` (or `ee$Authenticate()` in Python / `rgee::ee_Authenticate()`).
3. Point the pipeline at **your** Cloud project's **Project ID** from step 1, e.g.
   in `~/.Renviron`:
   `GEE_PROJECT=your-project-id`
4. Run `Rscript run_pipeline.R --gee`. When no `*.enc` is found the scripts
   automatically use your interactive Earth Engine / Google Drive login (your
   GEE exports land in your own Drive, then download locally).

> The author's own GEE project has since been deleted and its cached `*.enc`
> credentials removed, so the pipeline now always takes the "no vault found"
> fallback above regardless of who runs it. Encrypted `*.enc` credentials are
> git-ignored by design and were never published: the in-repo decryption
> password would otherwise make them readable, and live credentials on a public
> repo can be abused (GEE/Drive quota, billing) and are auto-revoked by Google.
> `02_scripts/00_setup/02_configure_secrets.R` shows how to cache your own the
> same way, if you want to skip re-authenticating on every `--gee` run.

## 12. Attribution

GHSL data © European Union, 1995–2025 (CC BY 4.0); cite Pesaresi et al. (2024).
GAUL © FAO (CC BY 4.0). UN data © United Nations. See `references.bib` for the
full, citable reference list.
