# Presentation Outline: SDG 11.3.1 (LCRPGR) Seminar Paper

**Course:** Development Economics, Summer Term 2026  
**Institution:** Carl von Ossietzky Universität Oldenburg  
**Instructors:** Prof. Dr. Jürgen Bitzer, Dr. Bernhard C. Dannemann  
**Presenter:** [Student Name]  
**Duration:** 15 Minutes (Strictly timed)

---

## Presentation Structure Overview

```mermaid
gantt
    title 15-Minute Presentation Time Allocation
    dateFormat  m:s
    axisFormat %M:%S
    
    Title & Intro                 :active, 0:00, 1m 30s
    Indicator & Critique          : 1:30, 4m 00s
    Data & GPW Red Flag           : 5:30, 3m 00s
    Theoretical Mechanisms        : 8:30, 2m 00s
    Empirical Strategy & Results   : 10:30, 3m 30s
    Discussion & Conclusion       : 14:00, 1m 00s
```

---

## Slide 1: Title Slide
* **Slide Title:** **Analyzing Global Urban Sprawl: An Empirical Investigation of SDG Indicator 11.3.1**
* **Subtitle:** Land Consumption Rate vs. Population Growth Rate (LCRPGR) in a Cross-Country Panel (1975–2020)
* **Presenter Info:** [Your Name], Matriculation Number: [XXXXX]
* **Course Info:** Seminar in Development Economics, SS 2026
* **Visuals:** 
  - A clean, modern title layout with a subtle, stylized abstract grid vector graphic in the background (representing urban growth/pixels).
  - Logo/name of Carl von Ossietzky Universität Oldenburg.
* **Suggested Timing:** **0:00 - 0:30** (30 seconds)
* **Core Talking Points:**
  - "Good morning, everyone, and welcome to my presentation. Today, I am presenting my research on Sustainable Development Goal Target 11.3, specifically focusing on Indicator 11.3.1, the Ratio of Land Consumption Rate to Population Growth Rate, or LCRPGR."
  - "In this presentation, I will critically assess the construction of this indicator, explain why certain datasets commonly used in global mapping can lead to major empirical anomalies, outline the economic mechanisms behind land expansion, and present panel regression results for the period 1975 to 2020."
* **Instructor-Focused Tip:** Start confidently and set the academic tone immediately. The instructors appreciate structured, formal openings that outline exactly what is coming.

---

## Slide 2: Introduction & Research Question
* **Slide Title:** **Introduction & Motivation**
* **Key Content:**
  - **The Trend:** Global urban population is projected to reach 6.7 billion by 2050 (UN-Habitat, 2023).
  - **The Challenge:** Land consumption is outpacing population growth in many regions, threatening ecosystems, infrastructure efficiency, and climate resilience (Angel et al., 2011).
  - **The Research Question:** *What country-level economic and structural factors explain the cross-country variation in LCRPGR between 1975 and 2020?*
* **Visuals:**
  - Two contrasting icons: a skyscraper/horizontal expansion icon (representing land) and a group of people icon (representing population).
  - Bullet points highlighting the tension between horizontal expansion (sprawl) and vertical densification.
* **Suggested Timing:** **0:30 - 1:30** (1 minute)
* **Core Talking Points:**
  - "Urbanization is one of the most defining global transformations of the 21st century. However, physical urban expansion does not always align with demographic changes."
  - "If cities expand horizontally too quickly, they create urban sprawl, which leads to high infrastructure costs, increased energy consumption, and loss of agricultural land."
  - "Our research question seeks to understand what country-level economic and structural factors—such as income, agricultural dependency, population density, and institutional capacity—explain why some countries sprawl while others density over a 45-year window."

---

## Slide 3: Defining the Indicator: SDG 11.3.1
* **Slide Title:** **SDG Indicator 11.3.1: Formulas & Mechanics**
* **Key Content:**
  - **Land Consumption Rate (LCR):**
    $$LCR = \frac{V_{present} - V_{past}}{V_{past}} \cdot \frac{1}{t}$$
  - **Population Growth Rate (PGR):**
    $$PGR = \frac{\ln(Pop_{t+n}/Pop_t)}{y}$$
  - **The Ratio (LCRPGR):**
    $$LCRPGR = \frac{LCR}{PGR}$$
  - **Methodological Oddity (Formula Asymmetry):** 
    - LCR is calculated using an *arithmetic* (linear) growth formula.
    - PGR is calculated using a *continuous* (exponential/log-based) growth formula.
* **Visuals:**
  - Two math cards side-by-side: Left card for $LCR$ (Arithmetic), right card for $PGR$ (Log-based).
  - A highlight box pointing out the formula asymmetry as defined by the UN-Habitat Metadata.
* **Suggested Timing:** **1:30 - 2:30** (1 minute)
* **Core Talking Points:**
  - "Let us look at how the UN-Habitat officially defines this indicator. The Land Consumption Rate, or LCR, measures the percentage change in built-up area over a period, divided by the number of years."
  - "In contrast, the Population Growth Rate, or PGR, uses a continuous, log-based formula."
  - "This creates a mathematical asymmetry: we are dividing a linear growth rate by a logarithmic growth rate. In my paper and code, I replicate this formula exactly as instructed by the custodian agency, but this mathematical inconsistency is a major point of critical assessment in the literature."

---

## Slide 4: Interpreting LCRPGR
* **Slide Title:** **Interpretation & Mathematical Edge Cases**
* **Key Content:**
  - **LCRPGR > 1 (Urban Sprawl):** Built-up area expands faster than population growth (e.g., suburbanization, low-density zoning).
  - **LCRPGR = 1 (Proportional Growth):** Balanced expansion.
  - **0 < LCRPGR < 1 (Densification):** Population grows faster than built-up area (e.g., vertical development, infill).
  - **LCRPGR ≤ 0 (Breakdown / Flagged Cases):**
    - Occurs when population is shrinking ($PGR < 0$) while built-up area continues to expand ($LCR > 0$), resulting in a negative ratio.
    - Also breaks down when population growth is flat ($PGR \approx 0$).
* **Visuals:**
  - A simple horizontal classification line or matrix visualizing the different regimes: Sprawl ($>1$), Densification ($0 < x < 1$), and the breakdown zone ($x \le 0$).
* **Suggested Timing:** **2:30 - 3:30** (1 minute)
* **Core Talking Points:**
  - "How do we interpret these ratios? A ratio greater than one signals that urban land is being consumed faster than the population is growing. This is a classic indicator of urban sprawl."
  - "Conversely, a ratio between zero and one indicates densification—a key goal for sustainable cities."
  - "However, the ratio breaks down mathematically when the denominator, population growth, is negative or close to zero. For example, in shrinking cities in Eastern Europe or Japan, $PGR$ is negative. This flips the sign of the indicator, rendering it meaningless or highly distorted. In our empirical panel, we identify and drop or winsorize these edge cases to avoid regression bias."

---

## Slide 5: Critical Assessment Framework
* **Slide Title:** **Critical Assessment of SDG 11.3.1**
* **Key Content:**
  - **Hughes et al. (2017) & Ayaburi et al. (2020) Template:** Evaluating indicators on clarity, reliability, and policy actionability.
  - **Interpretation Ambiguity:**
    - Is LCRPGR $< 1$ always good? It could reflect overcrowding, slums, and inadequate housing supply rather than "efficient densification."
    - Is LCRPGR $> 1$ always bad? It could represent rising living standards where families transition to larger, healthier housing spaces.
  - **The Definition of 'Urban':** Historically, different countries used disparate definitions of what constitutes a city, rendering pre-2020 data less comparable.
* **Visuals:**
  - A split slide layout comparing the positive and negative policy interpretations of LCRPGR values.
* **Suggested Timing:** **3:30 - 4:30** (1 minute)
* **Core Talking Points:**
  - "Following the academic framework of Hughes et al. (2017) and Ayaburi et al. (2020), we must critically assess the indicator."
  - "A key issue is interpretation ambiguity. A low ratio can hide a crisis of urban congestion and informal settlements, while a high ratio might simply reflect rising middle-class income and a healthy demand for larger housing units."
  - "Furthermore, what constitutes 'urban' built-up land has varied across national borders, though the recent endorsement of the Degree of Urbanization (DEGURBA) classification in 2020 aims to standardize this."

---

## Slide 6: Data Sources & The GPW Red Flag
* **Slide Title:** **Data Sources & Data Cleaning**
* **Key Content:**
  - **Geographic Unit:** Subnational ADM1 units are not comparable (e.g., UK has 4 mega-regions, Turkey has 80 provinces). The panel is aggregated to **country-period level (ADM0)**.
  - **Built-up Area:** Global Human Settlement Layer (`Built_GHSL`).
  - **Demographics:** `Pop_GHSL` (primary, internally consistent) and `Pop_WorldPop` (robustness checks).
  - **⚠️ The GPW Data Quality Red Flag (Broken GPW Values):**
    - Gridded Population of the World (`Pop_GPW`) columns in this dataset contain severe errors.
    - *Example (Year 2000 sums):*
      - **Turkey:** GHSL $\approx$ 62.46 Million vs. **GPW $\approx$ 4,696.64 Million** (75x error!)
      - **Argentina:** GHSL $\approx$ 36.71 Million vs. **GPW $\approx$ 2,549.44 Million**
      - **United Kingdom:** GHSL $\approx$ 58.29 Million vs. **GPW $\approx$ 3,000.18 Million**
* **Visuals:**
  - A stark, high-contrast data comparison table showing the GHSL sums vs. GPW sums for the year 2000 to highlight the red flag.
* **Suggested Timing:** **4:30 - 5:30** (1 minute)
* **Core Talking Points:**
  - "Let's discuss our data. Our raw dataset consists of 193 country-level CSV files containing subnational ADM1 rows."
  - "Because subnational administrative boundaries vary wildly across countries, we aggregate the data to the country level (ADM0) to ensure cross-country comparability."
  - "During data cleaning, we uncovered a major data quality issue: the GPW population data in this dataset is broken. For the year 2000, Turkey's population sums to 4.7 billion, and the UK sums to 3 billion. This is likely due to an double-summing or unit-conversion error in the raw file construction. Therefore, we explicitly exclude GPW and use the internally consistent GHSL population data."
* **Instructor-Focused Tip:** Emphasizing this GPW error demonstrates excellent research integrity and data-literacy skills, which both instructors (as empirical economists) will highly value.

---

## Slide 7: Empirical Sensitivity of LCRPGR
* **Slide Title:** **Sensitivity of LCRPGR to Population Datasets**
* **Key Content:**
  - **Case Study: Turkey (2000–2020):**
    - Same Land Consumption Rate ($LCR = 2.10\%$ annual growth).
    - Different Population Growth Rates ($PGR$) and LCRPGR outcomes:
  
  | Population Source | Annual PGR (%) | Computed LCRPGR | Empirical Note |
  | :--- | :--- | :--- | :--- |
  | **GHSL** (Primary) | **1.37%** | **1.54** | Plausible, reflects moderate sprawl |
  | **WorldPop** (Alt) | **0.60%** | **3.51** | Overestimates sprawl due to footprint definition |
  | **GPW** (Broken) | **0.62%** | **3.41** | Numerator divided by broken scale |
  
  - **Takeaway:** Choosing different global population databases dramatically shifts the indicator's value, presenting a challenge for international benchmarking.
* **Visuals:**
  - A clean bar chart or summary table comparing the calculated LCRPGR values for Turkey across the three data sources.
* **Suggested Timing:** **5:30 - 6:30** (1 minute)
* **Core Talking Points:**
  - "To demonstrate how sensitive this indicator is to population data sources, let's look at Turkey between 2000 and 2020."
  - "Using the exact same land built-up growth rate of 2.10%, the calculated LCRPGR varies from 1.54 under GHSL to 3.51 under WorldPop. WorldPop appears to measure urban-only demographics or uses a different clipping mask, resulting in a lower population growth rate, which inflates the final ratio."
  - "This highlights that international policy targets cannot be evaluated in a vacuum without establishing strict standards for the underlying population grids."

---

## Slide 8: Literature & Theoretical Mechanisms
* **Slide Title:** **Literature & Economic Mechanisms**
* **Key Content:**
  1. **The Income/Demand Channel (Brueckner, 2000):**
     - Rising GDP per capita $\rightarrow$ higher demand for housing space and automobile access $\rightarrow$ horizontal expansion (Expected sign: **Positive**).
  2. **Structural Transformation (Todaro & Smith, 2020):**
     - Shift from agriculture to industry/services drives rural-to-urban migration and greenfield conversion (Expected sign: **Negative** for agricultural share).
  3. **Agglomeration & Density (Glaeser & Kahn, 2004):**
     - High initial population density increases the marginal cost of land, driving vertical growth and infill (Expected sign: **Negative**).
  4. **Institutional Capacity (Angel et al., 2011):**
     - Effective governance and planning institutions constrain uncoordinated sprawl (Expected sign: **Negative**).
* **Visuals:**
  - A grid layout or flowchart representing the four mechanisms, with clear '+' and '-' indicators indicating their expected effects on LCRPGR.
* **Suggested Timing:** **6:30 - 8:30** (2 minutes)
* **Core Talking Points:**
  - "Now, let's connect this to economic theory. We anchor our analysis in four core economic mechanisms."
  - "First, the classic Brueckner monocentric city model predicts that rising income shifts housing demand outward, leading to a positive coefficient on GDP per capita."
  - "Second, structural transformation, as outlined by Todaro and Smith, shifts labor out of agriculture, freeing up land at the urban periphery. Thus, a higher agricultural share should be negatively associated with LCRPGR."
  - "Third, initial density increases the cost of outward sprawl, encouraging infill and vertical development."
  - "Finally, institutional capacity, proxied by government effectiveness, allows for the enforcement of urban growth boundaries, which should limit horizontal expansion."

---

## Slide 9: Empirical Strategy: Regression Model
* **Slide Title:** **Empirical Specification**
* **Estimating Equation:**
  $$LCRPGR_{i,t} = \alpha + \beta_1 \ln(GDPpc)_{i,t-1} + \beta_2 \text{Urban}_{i,t-1} + \beta_3 \text{AgriShare}_{i,t-1} + \beta_4 \ln(\text{Density})_{i,t-1} + \mathbf{Z}'_{i,t-1}\boldsymbol{\gamma} + \delta_t + \mu_i + \varepsilon_{i,t}$$
* **Key Design Choices:**
  - **Lagged Covariates ($t-1$):** Regressors are measured at the start of each 5-year window to mitigate reverse causality.
  - **Fixed Effects:**
    - **Period FE ($\delta_t$):** Controls for global macro trends (e.g., changes in satellite resolution, global economic shocks).
    - **Country FE ($\mu_i$):** Controls for time-invariant country characteristics (e.g., geography, culture, historical planning systems).
  - **Standard Errors:** Clustered at the country level to allow for serial correlation within countries.
* **Visuals:**
  - The formal regression equation with colored boxes or callouts pointing to the dependent variable, lagged regressors, period FE, and country FE.
* **Suggested Timing:** **8:30 - 9:30** (1 minute)
* **Core Talking Points:**
  - "To test these mechanisms, we estimate an OLS panel regression on our country-period panel."
  - "Our dependent variable is the LCRPGR of country $i$ over the 5-year window ending at period $t$. All explanatory variables are lagged to the beginning of the window, $t-1$, which helps mitigate reverse causality."
  - "We include period fixed effects to capture global time trends, and country fixed effects to control for time-invariant country-specific factors like topography or deep historical planning laws. Standard errors are clustered at the country level."

---

## Slide 10: Regression Variables & Sources
* **Slide Title:** **Variables and Data Coverage**
* **Key Content:**
  
  | Variable Type | Indicator Name | Source | Expected Sign |
  | :--- | :--- | :--- | :--- |
  | **Dependent ($Y$)** | LCRPGR | Calculated (GHSL) | — |
  | **Core Regressor** | $\ln$(GDP per Capita, PPP) | WDI (`NY.GDP.PCAP.PP.KD`) | **+** |
  | **Core Regressor** | Urban Population Share (%) | WDI (`SP.URB.TOTL.IN.ZS`) | **+** |
  | **Core Regressor** | Agricultural Share of GDP (%) | WDI (`NV.AGR.TOTL.ZS`) | **-** |
  | **Core Regressor** | $\ln$(Population Density) | WDI (`EN.POP.DNST`) | **-** |
  | **Extended ($Z$)** | Government Effectiveness | WGI (`GE.EST`) | **-** |
  | **Extended ($Z$)** | Motorization (Vehicles/1000) | WDI (`IS.VEH.NVEH.P3`) | **+** |
  
  - **Methodological Challenge:** WGI Government Effectiveness only starts in 1996. Including it cuts out pre-1996 waves. We handle this by reporting specifications with and without the governance proxy side-by-side.
* **Visuals:**
  - A clean, structured variable matrix illustrating sources, codes, and expected signs.
* **Suggested Timing:** **9:30 - 10:30** (1 minute)
* **Core Talking Points:**
  - "This table displays the specific indicators used from the World Development Indicators and the Worldwide Governance Indicators."
  - "Note our governance proxy: Government Effectiveness. Because the WGI dataset begins in 1996, including it cuts out our early panel waves from 1975 to 1995. To maintain transparency, we report our regressions in stages: first on the full historical sample without governance, and then on the post-1996 subsample including governance."

---

## Slide 11: Descriptives & Visualizations
* **Slide Title:** **Descriptive Overview of Global Sprawl**
* **Key Content:**
  - **Visualizing the Panel:** Global variation in urban expansion.
  - **Key Figures to Present:**
    - **Figure 1 (Map):** Global choropleth of LCRPGR (2000–2020) revealing high-sprawl clusters in suburban regions of North America and parts of East Asia, contrasted with densification in sub-Saharan Africa.
    - **Figure 2 (Scatter):** Income vs. LCRPGR showing a positive relationship at low-to-middle income levels, which flattens out in high-income economies.
    - **Figure 3 (Trajectories):** Distinct country paths for Turkey (moderate sprawl $\approx 1.5$), Argentina (fluctuating), and the UK (low-density growth with coarser administrative division).
* **Visuals:**
  - A placeholder grid representing the layout of the three figures: the map, the scatterplot, and the country trajectory lines.
* **Suggested Timing:** **10:30 - 11:30** (1 minute)
* **Core Talking Points:**
  - "Before diving into the regression coefficients, let us explore the raw data visually."
  - "Our global choropleth map reveals that urban sprawl is not uniform. High-income regions like North America show high sprawl ratios, whereas fast-growing urban centers in sub-Saharan Africa show low ratios, indicating rapid densification—likely driven by lack of affordable suburban transit."
  - "Our country trajectory plots show that Turkey has followed a moderate sprawl path, with LCRPGR consistently hovering between 1.0 and 1.8 since the 1990s construction boom."

---

## Slide 12: Main Regression Results
* **Slide Title:** **Main Empirical Findings**
* **Key Content:**
  
  | Explanatory Var. | (1) Pooled OLS | (2) Period FE | (3) Two-Way FE |
  | :--- | :---: | :---: | :---: |
  | **$\ln$(GDP per Capita)** | **$+$** (Significant) | **$+$** (Significant) | **$+$ / Close to 0** |
  | **Urban Share (%)** | **$+$** | **$+$** | **$+$** |
  | **Agricultural Share (%)** | **$-$** | **$-$** | **$-$** |
  | **$\ln$(Population Density)** | **$-$** (Significant) | **$-$** (Significant) | **$-$** (Significant) |
  | *Fixed Effects* | *None* | *Period* | *Country & Period* |
  
  - **Key Finding #1:** Income ($\ln$ GDPpc) is positively associated with sprawl in pooled and cross-sectional models, supporting the Brueckner model, but this effect weakens in the Two-Way FE model.
  - **Key Finding #2:** Initial population density is the most robust and consistent constraint on land consumption rate (highly significant negative coefficient across all specifications).
* **Visuals:**
  - A structured regression table highlighting the key coefficients for GDP per capita and Population Density using bold text or color indicators.
* **Suggested Timing:** **11:30 - 13:00** (1.5 minutes)
* **Core Talking Points:**
  - "Here are the main regression results. Columns 1, 2, and 3 report the pooled OLS, period fixed effects, and two-way fixed effects specifications."
  - "As we move from Pooled OLS to Two-Way FE, we see a fascinating shift. The coefficient on GDP per capita is positive and statistically significant in columns 1 and 2, which supports the income-sprawl hypothesis."
  - "However, in column 3, when we control for country fixed effects, the income effect becomes much smaller and loses significance. This suggests that the cross-sectional difference in income levels explains sprawl, but within-country growth over short 5-year periods does not immediately trigger massive physical sprawl."
  - "In contrast, initial population density remains strongly negative and highly significant across all models. High density is a powerful, persistent physical constraint on horizontal land consumption."

---

## Slide 13: Robustness Checks
* **Slide Title:** **Robustness & Sub-Sample Checks**
* **Key Content:**
  - **WorldPop Population Check:** Re-estimating the models using WorldPop instead of GHSL for the 2000–2020 period confirms that results are qualitatively similar, though coefficients shift slightly due to data density variations.
  - **Excluding Low PGR Countries:** Dropping observations where annual population growth is near zero ($|PGR| < 0.1\%$) to prevent extreme division outliers.
  - **Winsorization:** Winsorizing the LCRPGR variable at the 1st and 99th percentiles confirms that our results are not driven by extreme outliers.
  - **Secondary Outcome:** Using the annual change in built-up area per capita as the dependent variable yields consistent economic relationships.
* **Visuals:**
  - A summary chart showing the stability of coefficients across the different robustness runs.
* **Suggested Timing:** **13:00 - 14:00** (1 minute)
* **Core Talking Points:**
  - "To ensure our results are robust, we ran several sensitivity checks."
  - "First, we re-estimated our model using WorldPop population data. The main coefficients—specifically on density and agricultural share—remain consistent."
  - "Second, we dropped country-periods where population growth was flat to prevent division-by-zero distortion. This slightly reduced our sample size but did not alter our core findings."
  - "Finally, winsorizing the top and bottom 1% of LCRPGR values confirms that the results are not driven by measurement anomalies or statistical outliers."

---

## Slide 14: Discussion & Policy Implications
* **Slide Title:** **Discussion & Policy Relevance**
* **Key Content:**
  - **Planning vs. Market Forces:** Sprawl is driven by market forces (income, cars), but can be mitigated by active zoning, density policies, and public transport infrastructure.
  - **Limitations of SDG 11.3.1:**
    - It is a 2D metric. A city that grows vertically (high densification) looks identical to a city that is simply overcrowded and under-resourced.
    - Standardizing "urban boundaries" remains a critical challenge for global custody agencies.
  - **Policy Recommendation:** Countries should not target LCRPGR $= 1$ blindly. Instead, they should pair it with qualitative indicators of housing affordability and infrastructure density.
* **Visuals:**
  - A diagram showing the overlap of LCRPGR with local indicators (e.g., Housing Affordability Index, Public Transit Access) to form a balanced policy dashboard.
* **Suggested Timing:** **14:00 - 15:00** (1 minute)
* **Core Talking Points:**
  - "What are the policy implications of our findings?"
  - "Because initial density is a primary constraint on land consumption, cities that start dense tend to stay dense. This highlights the importance of proactive planning in early urbanization stages."
  - "For policy-makers, our critical assessment shows that targeting an LCRPGR of one blindly can be counterproductive. If a country artificially restricts built-up expansion while population is booming, it may lead to severe housing shortages and skyrocketing rent rather than sustainable development."
  - "Therefore, SDG 11.3.1 should be used as part of a broader dashboard that includes housing affordability and public transit accessibility."

---

## Slide 15: Conclusion
* **Slide Title:** **Conclusion**
* **Key Lessons:**
  - **Empirical:** Higher initial population density and agricultural share are associated with lower LCRPGR (less sprawl); income drives sprawl primarily across countries rather than within short-term country trajectories.
  - **Methodological:** The choice of population dataset is a major source of measurement sensitivity. Standardizing global grids is crucial.
  - **Data Quality:** The Gridded Population of the World (GPW) series in this dataset contains significant scaling errors and was excluded.
* **Visuals:**
  - Three simple checkmarks or takeaway boxes summarizing the empirical, methodological, and data findings.
* **Suggested Timing:** **15:00 - 15:30** (30 seconds)
* **Core Talking Points:**
  - "To conclude, our study provides robust panel evidence on the economic drivers of urban land consumption."
  - "Methodologically, we warn researchers and policy-makers about the high sensitivity of LCRPGR to the underlying population grids, and we document a severe error in the GPW population series."
  - "Ultimately, sustainable urbanization requires a balance between land conservation and housing affordability, which a single ratio cannot fully capture."
  - "Thank you for your attention. I am now open to your questions."

---

## Strategic Q&A Prep (Instructor-Specific)

### Prof. Dr. Jürgen Bitzer (Focus: Econometric Identification & Data)
1. **Q: Why did you lag all your covariates to $t-1$? Does that completely solve endogeneity?**
   - *Answer:* "Lagging the covariates ensures that the economic conditions at the *start* of the 5-year period explain the subsequent land expansion rate, which prevents direct reverse-causality. However, it does not completely eliminate endogeneity from omitted variables, which is why we include country fixed effects to control for time-invariant unobservables."
2. **Q: In your Two-Way FE specification, your GDP per capita coefficient drops in size and loses significance. Why?**
   - *Answer:* "In the Two-Way FE model, we are identifying off within-country changes over time. Within a single country, a 5-year window is too short for a change in GDP per capita to translate into massive physical urban restructuring. The positive relationship in Pooled OLS is driven by cross-sectional differences between rich and poor countries, rather than short-term macro fluctuations."

### Dr. Bernhard C. Dannemann (Focus: Spatial Data & Indicators)
1. **Q: You chose GHSL population over WorldPop and GPW. What is the spatial difference, and why does GPW break?**
   - *Answer:* "GHSL population is produced by the same team that produces the built-up area grids, using consistent spatial boundaries, which reduces mismatch errors. GPW in this dataset contains severe double-summing or scaling errors (e.g., Turkey's population summing to 4.7 billion in 2000), making it unusable. WorldPop has high quality but only starts in 2000, so we reserved it for robustness checks on the 2000–2020 sub-sample."
2. **Q: How does the asymmetry between LCR (arithmetic) and PGR (logarithmic) affect your analysis?**
   - *Answer:* "It introduces a slight non-linear distortion at extreme growth rates. While we must replicate this to match the UN-Habitat standard, we highlight this formula asymmetry as a key limitation of the official indicator's construction."
