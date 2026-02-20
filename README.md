# SIRI and Dry Eye Disease: NHANES 2005-2008

## Overview

This repository contains the complete R analysis code for the study:

**"No Association Between the Systemic Inflammation Response Index and Dry Eye Disease in US Adults: A Cross-Sectional Analysis of NHANES 2005-2008"**

Submitted to *Ocular Immunology and Inflammation*.

## Study Summary

We investigated whether the Systemic Inflammation Response Index (SIRI), a peripheral blood-based inflammatory marker, is associated with dry eye disease (DED) prevalence in a nationally representative sample of US adults (n = 8,664). After full adjustment, no significant association was observed (OR = 1.14, 95% CI: 0.90-1.46, P = 0.260). The restricted cubic spline analysis showed a flat dose-response curve (P = 0.896), and all sensitivity analyses supported the null finding.

## Data Source

All data are publicly available from the [NHANES website](https://www.cdc.gov/nchs/nhanes/index.htm). This study used the 2005-2006 and 2007-2008 survey cycles.

**Key NHANES files used:**
- Demographics (DEMO_D, DEMO_E)
- Complete Blood Count (CBC_D, CBC_E)
- Vision Questionnaire (VIQ_D, VIQ_E)
- Body Measures (BMX_D, BMX_E)
- Blood Pressure (BPX_D, BPX_E)
- Diabetes Questionnaire (DIQ_D, DIQ_E)
- Smoking Questionnaire (SMQ_D, SMQ_E)
- Glycohemoglobin (GHB_D, GHB_E)
- Fasting Glucose (GLU_D, GLU_E)

## Repository Structure

```
SIRI-DED-NHANES/
├── README.md
├── R/                          # Executable R scripts
│   ├── calculate_p_interaction.R
│   ├── calculate_p_interaction_refined.R
│   ├── Generate_Table3_Figure3.R
│   ├── Generate_Supplementary_Materials.R
│   ├── Generate_DAG.R
│   ├── Add_Legend_to_Figure3.R
│   └── Prepare_Figures_for_Submission.R
└── docs/                       # Step-by-step analysis documentation
    ├── 01_Data_Import_Merging.md
    ├── 02_Variable_Calculation.md
    ├── 03_Sample_Selection_Weighting.md
    ├── 04_Descriptive_Analysis.md
    ├── 05_Main_Regression.md
    ├── 06_Dose_Response_RCS.md
    ├── 07_Subgroup_Analysis.md
    └── 08_Sensitivity_Analysis.md
```

### R Scripts (`R/`)

| Script | Description |
|--------|-------------|
| `calculate_p_interaction.R` | Calculate P for interaction in subgroup analyses |
| `calculate_p_interaction_refined.R` | Refined interaction testing approach |
| `Generate_Table3_Figure3.R` | Generate Table 3 (subgroup results) and Figure 3 (forest plot) |
| `Generate_Supplementary_Materials.R` | Generate supplementary tables and figures |
| `Generate_DAG.R` | Generate Supplementary Figure S1 (directed acyclic graph) |
| `Add_Legend_to_Figure3.R` | Add formatted legend to Figure 3 |
| `Prepare_Figures_for_Submission.R` | Convert all figures to submission-ready TIFF format |

### Analysis Documentation (`docs/`)

The `docs/` folder contains comprehensive step-by-step operational guides for the entire analysis pipeline, from raw NHANES data import through final results generation. Each document includes embedded R code with detailed explanations.

| Document | Analysis Phase |
|----------|---------------|
| `01_Data_Import_Merging.md` | NHANES XPT file import and cross-cycle merging |
| `02_Variable_Calculation.md` | SIRI calculation, DED definition, covariate encoding |
| `03_Sample_Selection_Weighting.md` | Inclusion/exclusion criteria, 4-year survey weight calculation |
| `04_Descriptive_Analysis.md` | Table 1 generation, weighted descriptive statistics |
| `05_Main_Regression.md` | Table 2: Survey-weighted logistic regression (Models 1-3), trend tests |
| `06_Dose_Response_RCS.md` | Figure 2: Restricted cubic spline analysis |
| `07_Subgroup_Analysis.md` | Table 3 & Figure 3: Stratified analyses with Bonferroni correction |
| `08_Sensitivity_Analysis.md` | Table 4: Multiple sensitivity analyses |

## Software Requirements

- R version 4.3.0 or later
- Key R packages: `survey`, `ggplot2`, `dplyr`, `rms`, `magick`, `DiagrammeR`

## Reproducibility

All analyses account for the NHANES complex multistage sampling design using sampling weights (`WTMEC4YR`), stratification variables (`SDMVSTRA`), and primary sampling units (`SDMVPSU`).

## License

This code is provided for academic and research purposes. The NHANES data are in the public domain.

## Contact

[To be completed by authors]
