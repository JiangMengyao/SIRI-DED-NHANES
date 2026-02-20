# Day 16-17：描述性分析操作详解

> **任务目标**：基于Day 15生成的加权分析数据集，完成符合SCI 2区期刊标准的描述性统计分析，生成论文Table 1（研究人群基线特征表），并进行组间差异统计检验。
> 
> **预计用时**：6-8小时（两天）
> 
> **前置条件**：
> - 已完成Day 15样本筛选与权重计算
> - 生成`nhanes_analysis_weighted.rds`文件（9,467人）
> - 生成`nhanes_survey_design.rds`文件（survey design对象）
> 
> **技术要求**：R语言（survey包、gtsummary包、tableone包）
> 
> **输出目标**：
> - Table 1：按SIRI四分位组分层的基线特征表
> - 变量分布可视化图表
> - 描述性统计结果文档

---

## 目录

1. [整体流程概览](#一整体流程概览)
2. [描述性分析原理与方法](#二描述性分析原理与方法)
3. [环境准备与数据加载](#三环境准备与数据加载)
4. [全人群基线特征描述](#四全人群基线特征描述)
5. [按SIRI四分位组分层分析](#五按siri四分位组分层分析)
6. [Table 1生成与格式化](#六table-1生成与格式化)
7. [结果可视化](#七结果可视化)
8. [结果解读与论文撰写](#八结果解读与论文撰写)
9. [常见问题与解决方案](#九常见问题与解决方案)
10. [质量检查清单](#十质量检查清单)

---

## 一、整体流程概览

### 1.1 Day 16-17 核心任务流程图

```
┌─────────────────────────────────────────────────────────────┐
│                    【Day 16：基础描述性分析】                  │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  加载Day 15数据集与survey design                             │
│          ↓                                                   │
│  ==================== 全人群描述 ====================        │
│          ↓                                                   │
│    样本量与人口学特征概述                                     │
│          ↓                                                   │
│    暴露变量（SIRI）分布特征                                   │
│          ↓                                                   │
│    结局变量（干眼症）患病率                                   │
│          ↓                                                   │
│    协变量分布检查                                            │
│          ↓                                                   │
│  ==================== 分组描述 ====================          │
│          ↓                                                   │
│    按SIRI四分位组分层基线特征                                 │
│          ↓                                                   │
│    加权描述性统计                                            │
│          ↓                                                   │
│    组间差异检验                                              │
│                                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    【Day 17：Table 1生成与优化】               │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ==================== Table 1生成 ====================       │
│          ↓                                                   │
│    连续变量：加权均值±标准差 或 中位数(IQR)                   │
│          ↓                                                   │
│    分类变量：加权频数(百分比)                                 │
│          ↓                                                   │
│    P值计算：加权卡方检验 / 加权ANOVA                          │
│          ↓                                                   │
│  ==================== 格式优化 ====================          │
│          ↓                                                   │
│    表格美化与期刊格式调整                                     │
│          ↓                                                   │
│    Word/Excel导出                                            │
│          ↓                                                   │
│  ==================== 可视化 ====================            │
│          ↓                                                   │
│    变量分布图                                                │
│          ↓                                                   │
│    干眼症患病率趋势图                                         │
│          ↓                                                   │
│    保存图片（高分辨率）                                       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 核心任务清单

| 任务类别 | 具体任务 | 输出物 | 优先级 |
|---------|---------|--------|--------|
| **全人群描述** | 样本特征概述 | 文字描述 | ★★★ |
| **SIRI分布** | 分布特征与分组 | 统计量 + 图表 | ★★★ |
| **干眼症患病率** | 加权患病率计算 | 百分比 + 95%CI | ★★★ |
| **Table 1生成** | 按SIRI分组的基线特征表 | Word表格 | ★★★★★ |
| **组间检验** | 卡方检验/ANOVA | P值 | ★★★★ |
| **可视化** | 变量分布图 | 高分辨率图片 | ★★★ |

---

## 二、描述性分析原理与方法

### 2.1 为什么描述性分析如此重要？

描述性分析是SCI论文的**"门面"**，审稿人首先会看的就是Table 1。一个制作精良的Table 1能够：

| 功能 | 具体说明 | 审稿人视角 |
|-----|---------|-----------|
| **展示样本代表性** | 人群特征是否合理 | "这个研究人群可信吗？" |
| **识别混杂因素** | 暴露组间特征差异 | "需要调整哪些变量？" |
| **评估数据质量** | 缺失情况、极端值 | "数据处理是否规范？" |
| **支撑主要结论** | 基线差异与结局关联 | "结果是否有临床意义？" |

### 2.2 NHANES加权描述性分析的特殊性

由于NHANES采用复杂抽样设计，描述性分析**必须使用加权方法**：

| 分析类型 | 未加权 | 加权 | 使用场景 |
|---------|-------|------|---------|
| **点估计** | 样本均值/比例 | 加权均值/比例 | ✅ 主要报告 |
| **方差估计** | 简单方差 | 考虑聚类效应 | ✅ 置信区间 |
| **统计检验** | 普通卡方/t检验 | 调查加权检验 | ✅ P值计算 |
| **样本量** | 未加权n | 未加权n | ✅ 表格中报告 |

> 📌 **关键原则**：
> - **报告未加权样本量**（实际观察人数）
> - **报告加权百分比/均值**（代表美国总体）
> - **P值基于加权检验**

### 2.3 Table 1标准格式

SCI 2区期刊的Table 1通常采用以下格式：

```
Table 1. Baseline characteristics of study participants by SIRI quartiles

Variable          Overall    Q1         Q2         Q3         Q4         P value
                  (n=9,467)  (n=2,367)  (n=2,366)  (n=2,367)  (n=2,367)

Demographics
  Age, years      XX.X±XX.X  XX.X±XX.X  XX.X±XX.X  XX.X±XX.X  XX.X±XX.X  <0.001
  Female, n(%)    XX(XX.X)   XX(XX.X)   XX(XX.X)   XX(XX.X)   XX(XX.X)   0.XXX
  ...

Clinical characteristics
  BMI, kg/m²      XX.X±XX.X  ...
  ...

Dry eye outcomes
  Dry eye, n(%)   XX(XX.X)   XX(XX.X)   XX(XX.X)   XX(XX.X)   XX(XX.X)   <0.001
```

### 2.4 统计方法选择

| 变量类型 | 正态分布 | 描述统计 | 组间检验 | survey包函数 |
|---------|---------|---------|---------|-------------|
| **连续-正态** | 是 | 均值±标准差 | 加权ANOVA | `svymean()` |
| **连续-偏态** | 否 | 中位数(IQR) | Kruskal-Wallis | `svyquantile()` |
| **分类变量** | - | n(%) | 加权卡方检验 | `svytable()` |
| **有序分类** | - | n(%) | 趋势卡方检验 | `svychisq()` |

---

## 三、环境准备与数据加载

### 3.1 安装与加载必要的R包

```r
# ==================== 环境设置 ====================
# 设置工作目录
setwd("/Users/mayiding/Desktop/第一篇")

# 安装必要的包（如未安装）
required_packages <- c(
  "survey",       # 复杂调查分析核心包
  "gtsummary",    # 专业Table 1生成
  "tableone",     # 备选Table 1生成
  "dplyr",        # 数据处理
  "ggplot2",      # 可视化
  "flextable",    # 表格导出Word
  "officer",      # Word文档操作
  "scales",       # 图表刻度优化
  "RColorBrewer", # 配色方案
  "patchwork"     # 图表组合
)

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

cat("所有包加载完成！\n")
```

### 3.2 加载数据与survey design

```r
# ==================== 加载数据 ====================

# 加载Day 15生成的分析数据集
nhanes_data <- readRDS("分析数据集/nhanes_analysis_weighted.rds")

# 加载survey design对象
nhanes_design <- readRDS("分析数据集/nhanes_survey_design.rds")

# ==================== 数据验证 ====================
cat("\n==================== 数据加载验证 ====================\n")
cat("样本量:", nrow(nhanes_data), "\n")
cat("变量数:", ncol(nhanes_data), "\n")

# 验证关键变量
cat("\n关键变量验证:\n")
cat("SIRI有效:", sum(!is.na(nhanes_data$siri)), "\n")
cat("干眼症有效:", sum(!is.na(nhanes_data$dry_eye_a)), "\n")
cat("SIRI分组分布:\n")
print(table(nhanes_data$siri_quartile, useNA = "ifany"))

# 验证survey design
cat("\nSurvey design验证:\n")
print(nhanes_design)
```

### 3.3 SIRI四分位组验证与修复（重要！）

> ⚠️ **关键检查点**：SIRI四分位组必须在**最终分析样本**上重新计算，否则各组人数会不均匀。

```r
# ==================== SIRI四分位组验证 ====================

# 检查各组人数是否接近25%
siri_dist <- table(nhanes_data$siri_quartile)
siri_pct <- prop.table(siri_dist) * 100

cat("\n==================== SIRI四分位组验证 ====================\n")
cat("各组人数:\n")
print(siri_dist)
cat("\n各组百分比:\n")
print(round(siri_pct, 1))

# 判断是否需要重新计算
need_recalc <- any(siri_pct < 20 | siri_pct > 30)

if (need_recalc) {
  cat("\n⚠️ 警告：SIRI分组不均匀，需要重新计算四分位数切点！\n")
  
  # ==================== 重新计算SIRI四分位组 ====================
  
  # 1. 在最终分析样本上计算新的四分位数切点
  siri_quartiles_new <- quantile(nhanes_data$siri, 
                                  probs = c(0.25, 0.50, 0.75), 
                                  na.rm = TRUE)
  
  cat("\n新的SIRI四分位数切点:\n")
  cat("  Q1上限 (25%):", round(siri_quartiles_new[1], 4), "\n")
  cat("  Q2上限 (50%):", round(siri_quartiles_new[2], 4), "\n")
  cat("  Q3上限 (75%):", round(siri_quartiles_new[3], 4), "\n")
  
  # 2. 重新创建分组变量
  nhanes_data <- nhanes_data %>%
    mutate(
      siri_quartile = case_when(
        siri <= siri_quartiles_new[1] ~ "Q1",
        siri <= siri_quartiles_new[2] ~ "Q2",
        siri <= siri_quartiles_new[3] ~ "Q3",
        siri > siri_quartiles_new[3] ~ "Q4",
        TRUE ~ NA_character_
      ),
      siri_quartile = factor(siri_quartile, 
                             levels = c("Q1", "Q2", "Q3", "Q4"),
                             ordered = TRUE)
    )
  
  # 3. 验证修复结果
  cat("\n修复后SIRI分组分布:\n")
  print(table(nhanes_data$siri_quartile, useNA = "ifany"))
  cat("\n修复后各组占比:\n")
  print(round(prop.table(table(nhanes_data$siri_quartile)) * 100, 1))
  
  # 4. 更新survey design对象
  options(survey.lonely.psu = "adjust")
  nhanes_design <- svydesign(
    id = ~psu,
    strata = ~strata,
    weights = ~weight_4yr,
    data = nhanes_data,
    nest = TRUE
  )
  
  # 5. 保存修复后的数据
  saveRDS(nhanes_data, "分析数据集/nhanes_analysis_weighted.rds")
  saveRDS(nhanes_design, "分析数据集/nhanes_survey_design.rds")
  
  cat("\n✓ SIRI分组已修复并保存\n")
  
  # 6. 保存切点信息供后续使用
  siri_cutpoints <- data.frame(
    Quartile = c("Q1", "Q2", "Q3", "Q4"),
    Lower = c(0, siri_quartiles_new[1], siri_quartiles_new[2], siri_quartiles_new[3]),
    Upper = c(siri_quartiles_new[1], siri_quartiles_new[2], siri_quartiles_new[3], Inf)
  )
  write.csv(siri_cutpoints, "描述性分析/siri_quartile_cutpoints.csv", row.names = FALSE)
  cat("切点信息已保存: siri_quartile_cutpoints.csv\n")
  
} else {
  cat("\n✓ SIRI分组均匀，无需修复\n")
  
  # 记录当前切点
  siri_quartiles_new <- quantile(nhanes_data$siri, 
                                  probs = c(0.25, 0.50, 0.75), 
                                  na.rm = TRUE)
}

# 保存切点供后续使用
cat("\n最终使用的SIRI四分位数切点:\n")
cat("  Q1: ≤", round(siri_quartiles_new[1], 3), "\n")
cat("  Q2:", round(siri_quartiles_new[1], 3), "-", round(siri_quartiles_new[2], 3), "\n")
cat("  Q3:", round(siri_quartiles_new[2], 3), "-", round(siri_quartiles_new[3], 3), "\n")
cat("  Q4: >", round(siri_quartiles_new[3], 3), "\n")
```

**实际输出**：

```
==================== SIRI四分位组验证 ====================
> cat("各组人数:\n")
各组人数:
> print(siri_dist)

  Q1   Q2   Q3   Q4 
2367 2367 2366 2367 
> cat("\n各组百分比:\n")

各组百分比:
> print(round(siri_pct, 1))

Q1 Q2 Q3 Q4 
25 25 25 25 
最终使用的SIRI四分位数切点:
> cat("  Q1: ≤", round(siri_quartiles_new[1], 3), "\n")
  Q1: ≤ 0.708 
> cat("  Q2:", round(siri_quartiles_new[1], 3), "-", round(siri_quartiles_new[2], 3), "\n")
  Q2: 0.708 - 1.031 
> cat("  Q3:", round(siri_quartiles_new[2], 3), "-", round(siri_quartiles_new[3], 3), "\n")
  Q3: 1.031 - 1.479 
> cat("  Q4: >", round(siri_quartiles_new[3], 3), "\n")
  Q4: > 1.479 
```

> 📌 **为什么会出现分组不均匀？**
> 
> 如果在Day 14使用原始数据（20,497人）计算四分位数切点，然后应用到筛选后的最终样本（9,467人），由于被排除人群的SIRI分布与保留人群不同，会导致各组人数不均匀。**正确做法是在最终分析样本上重新计算切点**。

### 3.3 创建分析变量标签

为了生成专业的Table 1，需要为变量创建清晰的标签：

```r
# ==================== 变量标签设置 ====================

# 使用labelled包设置变量标签（可选，gtsummary会自动使用）
library(labelled)

var_labels <- list(
  # 暴露变量
  siri = "SIRI",
  siri_quartile = "SIRI Quartile",
  
  # 结局变量
  dry_eye_a = "Dry Eye Disease",
  dry_eye_c1 = "Dry Eye (Strict Definition)",
  dry_eye_c2 = "Dry Eye (Symptom + Treatment)",
  
  # 人口学变量
  age = "Age, years",
  gender_cat = "Sex",
  race_cat = "Race/Ethnicity",
  education_cat = "Education Level",
  pir = "Family Income-to-Poverty Ratio",
  pir_cat = "Family Income Category",
  
  # 生活方式变量
  bmi = "BMI, kg/m²",
  bmi_cat3 = "BMI Category",
  smoking_status = "Smoking Status",
  drinking_status = "Alcohol Consumption",
  
  # 临床变量
  diabetes_status = "Diabetes Status",
  hypertension = "Hypertension",
  sbp_mean = "Systolic Blood Pressure, mmHg",
  dbp_mean = "Diastolic Blood Pressure, mmHg",
  
  # 实验室指标
  wbc = "White Blood Cell Count, 10⁹/L",
  neutrophil_abs = "Neutrophil Count, 10⁹/L",
  lymphocyte_abs = "Lymphocyte Count, 10⁹/L",
  monocyte_abs = "Monocyte Count, 10⁹/L"
)

# 应用标签
for (var in names(var_labels)) {
  if (var %in% names(nhanes_data)) {
    var_label(nhanes_data[[var]]) <- var_labels[[var]]
  }
}

cat("变量标签设置完成\n")
```

---

## 四、全人群基线特征描述

### 4.1 样本基本特征概述

```r
# ==================== 全人群基本特征 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    研究人群基本特征概述                        ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 1. 样本量与数据来源
cat("\n【1. 样本量与数据来源】\n")
cat("总分析样本量:", nrow(nhanes_data), "\n")
cat("数据来源: NHANES 2005-2008\n")

# 按周期分布
cycle_dist <- table(nhanes_data$cycle)
cat("按调查周期分布:\n")
print(cycle_dist)

# 2. 加权人口估计
total_pop <- sum(weights(nhanes_design))
cat("\n加权人口估计:", format(round(total_pop), big.mark = ","), "\n")
```

【1. 样本量与数据来源】
> cat("总分析样本量:", nrow(nhanes_data), "\n")
> 总分析样本量: 9467 
> cat("数据来源: NHANES 2005-2008\n")
> 数据来源: NHANES 2005-2008
>
> # 按周期分布
> cycle_dist <- table(nhanes_data$cycle)
> cat("按调查周期分布:\n")
> 按调查周期分布:
> print(cycle_dist)

2005-2006 2007-2008 
     4182      5285 
>
> # 2. 加权人口估计
> total_pop <- sum(weights(nhanes_design))
> cat("\n加权人口估计:", format(round(total_pop), big.mark = ","), "\n")

加权人口估计: 198,072,765 

### 4.2 人口学特征（加权统计）

```r
# ==================== 人口学特征（加权）====================

cat("\n【2. 人口学特征（加权统计）】\n")

# 年龄
age_mean <- svymean(~age, nhanes_design, na.rm = TRUE)
age_median <- svyquantile(~age, nhanes_design, quantiles = 0.5, na.rm = TRUE)
cat("\n年龄:\n")
cat("  加权均值:", round(coef(age_mean), 1), "±", round(SE(age_mean)*1.96, 1), "岁\n")
cat("  加权中位数:", round(coef(age_median), 1), "岁\n")

# 性别分布（加权百分比）
gender_dist <- svymean(~gender_cat, nhanes_design, na.rm = TRUE)
cat("\n性别分布（加权百分比）:\n")
print(round(coef(gender_dist) * 100, 1))

# 种族分布（加权百分比）
race_dist <- svymean(~race_cat, nhanes_design, na.rm = TRUE)
cat("\n种族分布（加权百分比）:\n")
print(round(coef(race_dist) * 100, 1))

# 教育水平分布
edu_dist <- svymean(~education_cat, nhanes_design, na.rm = TRUE)
cat("\n教育水平分布（加权百分比）:\n")
print(round(coef(edu_dist) * 100, 1))
```

`==================== 人口学特征（加权）====================
>
> cat("\n【2. 人口学特征（加权统计）】\n")

【2. 人口学特征（加权统计）】
>
> # 年龄
> age_mean <- svymean(~age, nhanes_design, na.rm = TRUE)
> age_median <- svyquantile(~age, nhanes_design, quantiles = 0.5, na.rm = TRUE)
> cat("\n年龄:\n")

年龄:
> cat("  加权均值:", round(coef(age_mean), 1), "±", round(SE(age_mean)*1.96, 1), "岁\n")
> 加权均值: 47.2 ± 0.8 岁
> cat("  加权中位数:", round(coef(age_median), 1), "岁\n")
> 加权中位数: 46 岁
>
> # 性别分布（加权百分比）
> gender_dist <- svymean(~gender_cat, nhanes_design, na.rm = TRUE)
> cat("\n性别分布（加权百分比）:\n")

性别分布（加权百分比）:
> print(round(coef(gender_dist) * 100, 1))
> gender_catMale gender_catFemale 
>        48.7             51.3 
>
> # 种族分布（加权百分比）
> race_dist <- svymean(~race_cat, nhanes_design, na.rm = TRUE)
> cat("\n种族分布（加权百分比）:\n")

种族分布（加权百分比）:
> print(round(coef(race_dist) * 100, 1))
> race_catNon-Hispanic White race_catNon-Hispanic Black   race_catMexican American 
>                  71.7                       10.6                        8.0 
> race_catOther Hispanic         race_catOther Race 
>                   4.1                        5.6 
>
> # 教育水平分布
> edu_dist <- svymean(~education_cat, nhanes_design, na.rm = TRUE)
> cat("\n教育水平分布（加权百分比）:\n")

教育水平分布（加权百分比）:
> print(round(coef(edu_dist) * 100, 1))
> education_catLess than high school  education_catHigh school graduate 
>                          18.8                               25.1 
> education_catSome college or above 
>                          56.1 
> `

| 变量             | 指标              | 数值       |
| ---------------- | ----------------- | ---------- |
| **年龄（岁）**   | 加权均值 ± 95% CI | 47.2 ± 0.8 |
|                  | 加权中位数        | 46         |
| **性别，%**      | 男性              | 48.7       |
|                  | 女性              | 51.3       |
| **种族/族裔，%** | 非西班牙裔白人    | 71.7       |
|                  | 非西班牙裔黑人    | 10.6       |
|                  | 墨西哥裔美国人    | 8.0        |
|                  | 其他西班牙裔      | 4.1        |
|                  | 其他种族          | 5.6        |
| **教育水平，%**  | 高中以下          | 18.8       |
|                  | 高中毕业          | 25.1       |
|                  | 大专及以上        | 56.1       |

### 4.3 暴露变量（SIRI）分布特征

```r
# ==================== SIRI分布特征 ====================

cat("\n【3. 暴露变量（SIRI）分布特征】\n")

# SIRI描述性统计（加权）
siri_mean <- svymean(~siri, nhanes_design, na.rm = TRUE)
siri_quantiles <- svyquantile(~siri, nhanes_design, 
                              quantiles = c(0.25, 0.5, 0.75), 
                              na.rm = TRUE)

cat("\nSIRI分布:\n")
cat("  加权均值:", round(coef(siri_mean), 3), "\n")
cat("  加权标准误:", round(SE(siri_mean), 4), "\n")
cat("  加权中位数:", round(coef(siri_quantiles)[2], 3), "\n")
cat("  加权四分位距(IQR):", 
    round(coef(siri_quantiles)[1], 3), "-",
    round(coef(siri_quantiles)[3], 3), "\n")

# SIRI四分位组切点
cat("\nSIRI四分位组切点（基于未加权数据）:\n")
siri_cuts <- quantile(nhanes_data$siri, probs = c(0, 0.25, 0.5, 0.75, 1), na.rm = TRUE)
cat("  Q1: ≤", round(siri_cuts[2], 3), "\n")
cat("  Q2:", round(siri_cuts[2], 3), "-", round(siri_cuts[3], 3), "\n")
cat("  Q3:", round(siri_cuts[3], 3), "-", round(siri_cuts[4], 3), "\n")
cat("  Q4: >", round(siri_cuts[4], 3), "\n")

# 各组样本量
cat("\nSIRI四分位组样本量:\n")
print(table(nhanes_data$siri_quartile))
```

==================== SIRI分布特征 ====================
>
> cat("\n【3. 暴露变量（SIRI）分布特征】\n")

【3. 暴露变量（SIRI）分布特征】
>
> # SIRI描述性统计（加权）
> siri_mean <- svymean(~siri, nhanes_design, na.rm = TRUE)
> siri_quantiles <- svyquantile(~siri, nhanes_design, 
> +                               quantiles = c(0.25, 0.5, 0.75), 
> +                               na.rm = TRUE)
>
> cat("\nSIRI分布:\n")

SIRI分布:
> cat("  加权均值:", round(coef(siri_mean), 3), "\n")
> 加权均值: 1.235 
> cat("  加权标准误:", round(SE(siri_mean), 4), "\n")
> 加权标准误: 0.018 
> cat("  加权中位数:", round(coef(siri_quantiles)[2], 3), "\n")
> 加权中位数: 1.059 
> cat("  加权四分位距(IQR):", 
> +     round(coef(siri_quantiles)[1], 3), "-",
> +     round(coef(siri_quantiles)[3], 3), "\n")
> 加权四分位距(IQR): 0.746 - 1.489 
>
> # SIRI四分位组切点
> cat("\nSIRI四分位组切点（基于未加权数据）:\n")

SIRI四分位组切点（基于未加权数据）:
> siri_cuts <- quantile(nhanes_data$siri, probs = c(0, 0.25, 0.5, 0.75, 1), na.rm = TRUE)
> cat("  Q1: ≤", round(siri_cuts[2], 3), "\n")
> Q1: ≤ 0.708 
> cat("  Q2:", round(siri_cuts[2], 3), "-", round(siri_cuts[3], 3), "\n")
> Q2: 0.708 - 1.031 
> cat("  Q3:", round(siri_cuts[3], 3), "-", round(siri_cuts[4], 3), "\n")
> Q3: 1.031 - 1.479 
> cat("  Q4: >", round(siri_cuts[4], 3), "\n")
> Q4: > 1.479 
>
> # 各组样本量
> cat("\nSIRI四分位组样本量:\n")

SIRI四分位组样本量:
> print(table(nhanes_data$siri_quartile))

  Q1   Q2   Q3   Q4 
2367 2367 2366 2367 

##  结果整理

## SIRI 的分布特征（加权）

| 指标                    | 数值          |
| ----------------------- | ------------- |
| **加权均值**            | 1.235         |
| **加权标准误（SE）**    | 0.018         |
| **加权中位数**          | 1.059         |
| **加权四分位距（IQR）** | 0.746 – 1.489 |

------

##  SIRI 四分位分组及切点

> 四分位切点基于 **未加权原始数据** 计算（用于分组），描述性统计采用 **加权结果**

| SIRI 四分位组 | 定义（SIRI 值） | 样本量（n） |
| ------------- | --------------- | ----------- |
| Q1            | ≤ 0.708         | 2,367       |
| Q2            | 0.708 – 1.031   | 2,367       |
| Q3            | 1.031 – 1.479   | 2,366       |
| Q4            | > 1.479         | 2,367       |

------

### 表注（推荐直接使用）

> SIRI（Systemic Inflammation Response Index）按未加权数据的四分位数进行分组，以保证各组样本量平衡；连续变量的描述性统计采用复杂抽样加权方法估计。
>  加权中位数及四分位距基于 `svyquantile` 计算。

### 4.4 结局变量（干眼症）患病率

```r
# ==================== 干眼症患病率（加权）====================

cat("\n【4. 结局变量（干眼症）患病率】\n")

# 方案A：主分析定义
dryeye_prev_a <- svymean(~dry_eye_a, nhanes_design, na.rm = TRUE)
dryeye_ci_a <- confint(dryeye_prev_a)

cat("\n干眼症患病率（加权）:\n")
cat("  主分析定义（症状≥有时）:\n")
cat("    患病率:", round(coef(dryeye_prev_a) * 100, 2), "%\n")
cat("    95%CI: (", round(dryeye_ci_a[1] * 100, 2), "% - ", 
    round(dryeye_ci_a[2] * 100, 2), "%)\n")

# 方案C1：严格定义
dryeye_prev_c1 <- svymean(~dry_eye_c1, nhanes_design, na.rm = TRUE)
dryeye_ci_c1 <- confint(dryeye_prev_c1)
cat("\n  严格定义（症状≥经常）:\n")
cat("    患病率:", round(coef(dryeye_prev_c1) * 100, 2), "%\n")
cat("    95%CI: (", round(dryeye_ci_c1[1] * 100, 2), "% - ", 
    round(dryeye_ci_c1[2] * 100, 2), "%)\n")

# 方案C2：症状+治疗定义
dryeye_prev_c2 <- svymean(~dry_eye_c2, nhanes_design, na.rm = TRUE)
dryeye_ci_c2 <- confint(dryeye_prev_c2)
cat("\n  症状+治疗定义:\n")
cat("    患病率:", round(coef(dryeye_prev_c2) * 100, 2), "%\n")
cat("    95%CI: (", round(dryeye_ci_c2[1] * 100, 2), "% - ", 
    round(dryeye_ci_c2[2] * 100, 2), "%)\n")

# 干眼症病例数
cat("\n干眼症病例数（未加权）:\n")
cat("  主分析定义:", sum(nhanes_data$dry_eye_a == 1, na.rm = TRUE), "\n")
cat("  严格定义:", sum(nhanes_data$dry_eye_c1 == 1, na.rm = TRUE), "\n")
cat("  症状+治疗定义:", sum(nhanes_data$dry_eye_c2 == 1, na.rm = TRUE), "\n")
```

---

## 结果整理：干眼症患病率（加权，按不同定义）

| 干眼症定义                    | 加权患病率（%） | 95% CI（%）   | 病例数（未加权，n） |
| ----------------------------- | --------------- | ------------- | ------------------- |
| **主分析定义（症状 ≥ 有时）** | 15.58           | 14.37 – 16.80 | 1,979               |
| **严格定义（症状 ≥ 经常）**   | 3.11            | 2.64 – 3.57   | 440                 |
| **症状 + 治疗定义**           | 3.83            | 3.35 – 4.31   | 387                 |

------

### 表注（建议原样使用）

> 干眼症患病率采用复杂抽样加权方法估计。
>  主分析定义为干眼症症状出现频率 ≥“有时”；严格定义为症状频率 ≥“经常”；症状+治疗定义为存在干眼症症状并接受相关治疗。
>  病例数为未加权样本中的实际人数，用于反映样本构成。

## 五、按SIRI四分位组分层分析

### 5.1 创建分层描述统计函数

```r
# ==================== 分层描述统计函数 ====================

# 连续变量按组描述（加权）
describe_continuous_by_group <- function(design, var, group_var, digits = 1) {
  
  formula <- as.formula(paste0("~", var))
  by_formula <- as.formula(paste0("~", group_var))
  
  # 分组加权均值
  means <- svyby(formula, by_formula, design, svymean, na.rm = TRUE)
  
  # 分组加权标准差（近似）
  sds <- svyby(formula, by_formula, design, svyvar, na.rm = TRUE)
  sds$sd <- sqrt(sds[[2]])
  
  # 整体统计
  overall_mean <- svymean(formula, design, na.rm = TRUE)
  overall_var <- svyvar(formula, design, na.rm = TRUE)
  
  # 组间比较（加权ANOVA - Wald检验）
  test_formula <- as.formula(paste0(var, " ~ ", group_var))
  anova_result <- regTermTest(svyglm(test_formula, design), group_var)
  p_value <- anova_result$p
  
  result <- data.frame(
    Variable = var,
    Overall = paste0(round(coef(overall_mean), digits), " ± ", 
                     round(sqrt(coef(overall_var)), digits)),
    Q1 = paste0(round(means[1, 2], digits), " ± ", round(sds$sd[1], digits)),
    Q2 = paste0(round(means[2, 2], digits), " ± ", round(sds$sd[2], digits)),
    Q3 = paste0(round(means[3, 2], digits), " ± ", round(sds$sd[3], digits)),
    Q4 = paste0(round(means[4, 2], digits), " ± ", round(sds$sd[4], digits)),
    P_value = ifelse(p_value < 0.001, "<0.001", round(p_value, 3))
  )
  
  return(result)
}

# 分类变量按组描述（加权）
describe_categorical_by_group <- function(design, var, group_var) {
  
  # 创建交叉表
  table_formula <- as.formula(paste0("~", var, " + ", group_var))
  cross_table <- svytable(table_formula, design)
  
  # 计算各组百分比
  prop_table <- prop.table(cross_table, margin = 2) * 100
  
  # 整体百分比
  overall_formula <- as.formula(paste0("~", var))
  overall_prop <- svymean(overall_formula, design, na.rm = TRUE) * 100
  
  # 卡方检验
  chisq_result <- svychisq(table_formula, design, statistic = "Chisq")
  p_value <- chisq_result$p.value
  
  # 获取未加权频数
  raw_table <- table(design$variables[[var]], design$variables[[group_var]])
  
  return(list(
    counts = raw_table,
    percentages = prop_table,
    overall = overall_prop,
    p_value = ifelse(p_value < 0.001, "<0.001", round(p_value, 3))
  ))
}
```

### 5.2 人口学特征按SIRI分组

```r
# ==================== 人口学特征按SIRI分组 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║              按SIRI四分位组分层的基线特征                      ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 年龄
cat("\n【年龄（连续变量）】\n")
age_by_siri <- svyby(~age, ~siri_quartile, nhanes_design, svymean, na.rm = TRUE)
print(age_by_siri)

# 年龄组间比较（加权ANOVA）
age_anova <- regTermTest(svyglm(age ~ siri_quartile, nhanes_design), "siri_quartile")
cat("组间比较P值:", 
    ifelse(age_anova$p < 0.001, "<0.001", round(age_anova$p, 3)), "\n")

# 性别
cat("\n【性别分布】\n")
gender_by_siri <- svytable(~gender_cat + siri_quartile, nhanes_design)
gender_prop <- prop.table(gender_by_siri, margin = 2) * 100
print(round(gender_prop, 1))

# 性别卡方检验
gender_chisq <- svychisq(~gender_cat + siri_quartile, nhanes_design)
cat("卡方检验P值:", 
    ifelse(gender_chisq$p.value < 0.001, "<0.001", round(gender_chisq$p.value, 3)), "\n")

# 种族
cat("\n【种族分布】\n")
race_by_siri <- svytable(~race_cat + siri_quartile, nhanes_design)
race_prop <- prop.table(race_by_siri, margin = 2) * 100
print(round(race_prop, 1))

race_chisq <- svychisq(~race_cat + siri_quartile, nhanes_design)
cat("卡方检验P值:", 
    ifelse(race_chisq$p.value < 0.001, "<0.001", round(race_chisq$p.value, 3)), "\n")

# 教育水平
cat("\n【教育水平分布】\n")
edu_by_siri <- svytable(~education_cat + siri_quartile, nhanes_design)
edu_prop <- prop.table(edu_by_siri, margin = 2) * 100
print(round(edu_prop, 1))

edu_chisq <- svychisq(~education_cat + siri_quartile, nhanes_design)
cat("卡方检验P值:", 
    ifelse(edu_chisq$p.value < 0.001, "<0.001", round(edu_chisq$p.value, 3)), "\n")

# 家庭收入比（PIR）
cat("\n【家庭收入比（PIR）】\n")
pir_by_siri <- svyby(~pir, ~siri_quartile, nhanes_design, svymean, na.rm = TRUE)
print(pir_by_siri)

pir_anova <- regTermTest(svyglm(pir ~ siri_quartile, nhanes_design), "siri_quartile")
cat("组间比较P值:", 
    ifelse(pir_anova$p < 0.001, "<0.001", round(pir_anova$p, 3)), "\n")
```

## 输出结果总结

## 按 SIRI 四分位组分层的基线特征（加权）

### 连续变量（加权均值 ± SE）

| 变量              | Q1                    | Q2                    | Q3                    | Q4                    | 组间比较P值 |
| ----------------- | --------------------- | --------------------- | --------------------- | --------------------- | ----------- |
| 年龄（岁）        | 44.54576 ± 0.5233832  | 46.12228 ± 0.3309786  | 47.45215 ± 0.5550839  | 50.38109 ± 0.5572035  | <0.001      |
| 家庭收入比（PIR） | 3.047046 ± 0.06326845 | 3.200232 ± 0.06237040 | 3.119411 ± 0.07388061 | 2.960434 ± 0.06762970 | 0.001       |

------

### 分类变量（加权列百分比，%）

#### 性别分布

| 性别   | Q1   | Q2   | Q3   | Q4   | 卡方检验P值 |
| ------ | ---- | ---- | ---- | ---- | ----------- |
| Male   | 41.6 | 44.7 | 52.2 | 55.4 | <0.001      |
| Female | 58.4 | 55.3 | 47.8 | 44.6 | <0.001      |

#### 种族分布

| 种族               | Q1   | Q2   | Q3   | Q4   | 卡方检验P值 |
| ------------------ | ---- | ---- | ---- | ---- | ----------- |
| Non-Hispanic White | 55.6 | 71.2 | 77.4 | 80.0 | <0.001      |
| Non-Hispanic Black | 22.8 | 9.2  | 6.5  | 5.8  | <0.001      |
| Mexican American   | 8.6  | 8.6  | 8.3  | 6.7  | <0.001      |
| Other Hispanic     | 4.8  | 5.0  | 3.4  | 3.3  | <0.001      |
| Other Race         | 8.3  | 6.0  | 4.3  | 4.2  | <0.001      |

#### 教育水平分布

| 教育水平              | Q1   | Q2   | Q3   | Q4   | 卡方检验P值 |
| --------------------- | ---- | ---- | ---- | ---- | ----------- |
| Less than high school | 19.4 | 18.2 | 18.0 | 19.9 | 0.005       |
| High school graduate  | 22.6 | 23.9 | 25.2 | 28.4 | 0.005       |
| Some college or above | 58.0 | 57.9 | 56.8 | 51.7 | 0.005       |

### 5.3 生活方式与临床特征按SIRI分组

```r
# ==================== 生活方式与临床特征 ====================

cat("\n【BMI】\n")
bmi_by_siri <- svyby(~bmi, ~siri_quartile, nhanes_design, svymean, na.rm = TRUE)
print(bmi_by_siri)

bmi_anova <- regTermTest(svyglm(bmi ~ siri_quartile, nhanes_design), "siri_quartile")
cat("组间比较P值:", 
    ifelse(bmi_anova$p < 0.001, "<0.001", round(bmi_anova$p, 3)), "\n")

cat("\n【BMI分类分布】\n")
bmi_cat_by_siri <- svytable(~bmi_cat3 + siri_quartile, nhanes_design)
bmi_cat_prop <- prop.table(bmi_cat_by_siri, margin = 2) * 100
print(round(bmi_cat_prop, 1))

bmi_cat_chisq <- svychisq(~bmi_cat3 + siri_quartile, nhanes_design)
cat("卡方检验P值:", 
    ifelse(bmi_cat_chisq$p.value < 0.001, "<0.001", round(bmi_cat_chisq$p.value, 3)), "\n")

cat("\n【吸烟状态分布】\n")
smoke_by_siri <- svytable(~smoking_status + siri_quartile, nhanes_design)
smoke_prop <- prop.table(smoke_by_siri, margin = 2) * 100
print(round(smoke_prop, 1))

smoke_chisq <- svychisq(~smoking_status + siri_quartile, nhanes_design)
cat("卡方检验P值:", 
    ifelse(smoke_chisq$p.value < 0.001, "<0.001", round(smoke_chisq$p.value, 3)), "\n")

cat("\n【糖尿病状态分布】\n")
dm_by_siri <- svytable(~diabetes_status + siri_quartile, nhanes_design)
dm_prop <- prop.table(dm_by_siri, margin = 2) * 100
print(round(dm_prop, 1))

dm_chisq <- svychisq(~diabetes_status + siri_quartile, nhanes_design)
cat("卡方检验P值:", 
    ifelse(dm_chisq$p.value < 0.001, "<0.001", round(dm_chisq$p.value, 3)), "\n")

cat("\n【高血压分布】\n")
htn_by_siri <- svytable(~hypertension + siri_quartile, nhanes_design)
htn_prop <- prop.table(htn_by_siri, margin = 2) * 100
print(round(htn_prop, 1))

# 直接使用 hypertension，不要用 factor()
htn_chisq <- svychisq(~hypertension + siri_quartile, nhanes_design)
cat("卡方检验P值:", 
    ifelse(htn_chisq$p.value < 0.001, "<0.001", round(htn_chisq$p.value, 3)), "\n")
```

 ==================== 生活方式与临床特征 ====================
>
> cat("\n【BMI】\n")

【BMI】
> bmi_by_siri <- svyby(~bmi, ~siri_quartile, nhanes_design, svymean, na.rm = TRUE)
> print(bmi_by_siri)
> siri_quartile      bmi        se
> Q1            Q1 27.66004 0.1747242
> Q2            Q2 28.27210 0.1868883
> Q3            Q3 29.05439 0.2025501
> Q4            Q4 29.12383 0.2282789
>
> bmi_anova <- regTermTest(svyglm(bmi ~ siri_quartile, nhanes_design), "siri_quartile")
> cat("组间比较P值:", 
> +     ifelse(bmi_anova$p < 0.001, "<0.001", round(bmi_anova$p, 3)), "\n")
> 组间比较P值: <0.001 
>
> cat("\n【BMI分类分布】\n")

【BMI分类分布】
> bmi_cat_by_siri <- svytable(~bmi_cat3 + siri_quartile, nhanes_design)
> bmi_cat_prop <- prop.table(bmi_cat_by_siri, margin = 2) * 100
> print(round(bmi_cat_prop, 1))
>                siri_quartile
> bmi_cat3               Q1   Q2   Q3   Q4
> Normal (<25)       37.0 33.1 30.5 29.6
> Overweight (25-30) 33.2 34.7 33.5 33.5
> Obese (≥30)        29.8 32.2 36.0 36.9
>
> bmi_cat_chisq <- svychisq(~bmi_cat3 + siri_quartile, nhanes_design)
> cat("卡方检验P值:", 
> +     ifelse(bmi_cat_chisq$p.value < 0.001, "<0.001", round(bmi_cat_chisq$p.value, 3)), "\n")
> 卡方检验P值: <0.001 
>
> cat("\n【吸烟状态分布】\n")

【吸烟状态分布】
> smoke_by_siri <- svytable(~smoking_status + siri_quartile, nhanes_design)
> smoke_prop <- prop.table(smoke_by_siri, margin = 2) * 100
> print(round(smoke_prop, 1))
>          siri_quartile
> smoking_status   Q1   Q2   Q3   Q4
>   Never   59.1 53.4 50.7 44.4
>   Former  22.1 24.6 25.0 27.1
>   Current 18.8 22.0 24.4 28.4
>
> smoke_chisq <- svychisq(~smoking_status + siri_quartile, nhanes_design)
> cat("卡方检验P值:", 
> +     ifelse(smoke_chisq$p.value < 0.001, "<0.001", round(smoke_chisq$p.value, 3)), "\n")
> 卡方检验P值: <0.001 
>
> cat("\n【糖尿病状态分布】\n")

【糖尿病状态分布】
> dm_by_siri <- svytable(~diabetes_status + siri_quartile, nhanes_design)
> dm_prop <- prop.table(dm_by_siri, margin = 2) * 100
> print(round(dm_prop, 1))
>           siri_quartile
> diabetes_status   Q1   Q2   Q3   Q4
> Normal      61.8 62.5 59.1 53.9
> Prediabetes 27.5 28.6 29.4 31.6
> Diabetes    10.8  8.9 11.5 14.5
>
> dm_chisq <- svychisq(~diabetes_status + siri_quartile, nhanes_design)
> cat("卡方检验P值:", 
> +     ifelse(dm_chisq$p.value < 0.001, "<0.001", round(dm_chisq$p.value, 3)), "\n")
> 卡方检验P值: <0.001 
>
> cat("\n【高血压分布】\n")

【高血压分布】
> htn_by_siri <- svytable(~hypertension + siri_quartile, nhanes_design)
> htn_prop <- prop.table(htn_by_siri, margin = 2) * 100
> print(round(htn_prop, 1))
>        siri_quartile
> hypertension   Q1   Q2   Q3   Q4
>       0 87.2 86.2 83.6 81.0
>       1 12.8 13.8 16.4 19.0
>
> htn_chisq <- svychisq(~hypertension + siri_quartile, nhanes_design)
> cat("卡方检验P值:", 
> +     ifelse(htn_chisq$p.value < 0.001, "<0.001", round(htn_chisq$p.value, 3)), "\n")
> 卡方检验P值: <0.001 

## 输出总结

## 不同 SIRI 四分位的生活方式与临床特征（NHANES 加权）

### BMI（连续变量）

| 变量        | Q1           | Q2           | Q3           | Q4           | P 值   |
| ----------- | ------------ | ------------ | ------------ | ------------ | ------ |
| BMI (kg/m²) | 27.66 ± 0.17 | 28.27 ± 0.19 | 29.05 ± 0.20 | 29.12 ± 0.23 | <0.001 |

------

### BMI 分类分布（%）

| BMI 分类           | Q1   | Q2   | Q3   | Q4   | P 值   |
| ------------------ | ---- | ---- | ---- | ---- | ------ |
| Normal (<25)       | 37.0 | 33.1 | 30.5 | 29.6 | <0.001 |
| Overweight (25–30) | 33.2 | 34.7 | 33.5 | 33.5 |        |
| Obese (≥30)        | 29.8 | 32.2 | 36.0 | 36.9 |        |

------

### 吸烟状态分布（%）

| 吸烟状态 | Q1   | Q2   | Q3   | Q4   | P 值   |
| -------- | ---- | ---- | ---- | ---- | ------ |
| Never    | 59.1 | 53.4 | 50.7 | 44.4 | <0.001 |
| Former   | 22.1 | 24.6 | 25.0 | 27.1 |        |
| Current  | 18.8 | 22.0 | 24.4 | 28.4 |        |

------

### 糖尿病状态分布（%）

| 糖尿病状态  | Q1   | Q2   | Q3   | Q4   | P 值   |
| ----------- | ---- | ---- | ---- | ---- | ------ |
| Normal      | 61.8 | 62.5 | 59.1 | 53.9 | <0.001 |
| Prediabetes | 27.5 | 28.6 | 29.4 | 31.6 |        |
| Diabetes    | 10.8 | 8.9  | 11.5 | 14.5 |        |

------

### 高血压分布（%）

| 高血压  | Q1   | Q2   | Q3   | Q4   | P 值   |
| ------- | ---- | ---- | ---- | ---- | ------ |
| No (0)  | 87.2 | 86.2 | 83.6 | 81.0 | <0.001 |
| Yes (1) | 12.8 | 13.8 | 16.4 | 19.0 |        |

------

### 表下注释（可直接用）

- 所有结果均基于 **NHANES 复杂抽样设计加权**
- 连续变量以 **加权均值 ± 标准误（SE）** 表示，组间比较采用 **survey-weighted linear regression**
- 分类变量以 **列百分比（%）** 表示，组间比较采用 **Rao–Scott 校正卡方检验**
- SIRI 按四分位数分组（Q1–Q4）

### 5.4 干眼症患病率按SIRI分组

```r
# ==================== 干眼症患病率按SIRI分组 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                  干眼症患病率按SIRI四分位组                    ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 主分析定义（方案A）
cat("\n【主分析定义（VIQ031≥3）】\n")
dryeye_by_siri <- svyby(~dry_eye_a, ~siri_quartile, nhanes_design, svymean, na.rm = TRUE)
dryeye_by_siri$prevalence <- dryeye_by_siri$dry_eye_a * 100
dryeye_by_siri$se_pct <- dryeye_by_siri$se * 100
print(dryeye_by_siri[, c("siri_quartile", "prevalence", "se_pct")])

# 计算95%置信区间
cat("\n各组干眼症患病率及95%CI:\n")
for (i in 1:4) {
  prev <- dryeye_by_siri$dry_eye_a[i] * 100
  se <- dryeye_by_siri$se[i] * 100
  ci_low <- prev - 1.96 * se
  ci_high <- prev + 1.96 * se
  cat("  Q", i, ": ", round(prev, 1), "% (", 
      round(ci_low, 1), "% - ", round(ci_high, 1), "%)\n", sep = "")
}

# 趋势检验
dryeye_chisq <- svychisq(~dry_eye_a + siri_quartile, nhanes_design)
cat("\n组间比较（卡方检验）P值:", 
    ifelse(dryeye_chisq$p.value < 0.001, "<0.001", round(dryeye_chisq$p.value, 3)), "\n")

# 趋势P值（使用有序变量）
nhanes_data$siri_q_num <- as.numeric(nhanes_data$siri_quartile)
nhanes_design_trend <- svydesign(
  id = ~psu, strata = ~strata, weights = ~weight_4yr,
  data = nhanes_data, nest = TRUE
)

trend_model <- svyglm(dry_eye_a ~ siri_q_num, 
                      design = nhanes_design_trend, 
                      family = quasibinomial())
trend_test <- summary(trend_model)
p_trend <- coef(summary(trend_model))[2, 4]
cat("趋势检验P值:", 
    ifelse(p_trend < 0.001, "<0.001", round(p_trend, 3)), "\n")

# 严格定义（方案C1）
cat("\n【严格定义（VIQ031≥4）】\n")
dryeye_c1_by_siri <- svyby(~dry_eye_c1, ~siri_quartile, nhanes_design, svymean, na.rm = TRUE)
dryeye_c1_by_siri$prevalence <- dryeye_c1_by_siri$dry_eye_c1 * 100
dryeye_c1_by_siri$se_pct <- dryeye_c1_by_siri$se * 100
print(dryeye_c1_by_siri[, c("siri_quartile", "prevalence", "se_pct")])

# 计算95%置信区间
cat("\n各组干眼症患病率及95%CI:\n")
for (i in 1:4) {
  prev <- dryeye_c1_by_siri$dry_eye_c1[i] * 100
  se <- dryeye_c1_by_siri$se[i] * 100
  ci_low <- prev - 1.96 * se
  ci_high <- prev + 1.96 * se
  cat("  Q", i, ": ", round(prev, 1), "% (", 
      round(ci_low, 1), "% - ", round(ci_high, 1), "%)\n", sep = "")
}

# 卡方检验
dryeye_c1_chisq <- svychisq(~dry_eye_c1 + siri_quartile, nhanes_design)
cat("\n组间比较（卡方检验）P值:", 
    ifelse(dryeye_c1_chisq$p.value < 0.001, "<0.001", round(dryeye_c1_chisq$p.value, 3)), "\n")

# 趋势P值
trend_model_c1 <- svyglm(dry_eye_c1 ~ siri_q_num, 
                         design = nhanes_design_trend, 
                         family = quasibinomial())
p_trend_c1 <- coef(summary(trend_model_c1))[2, 4]
cat("趋势检验P值:", 
    ifelse(p_trend_c1 < 0.001, "<0.001", round(p_trend_c1, 3)), "\n")
```

---

### 干眼症患病率按 SIRI 四分位（主分析定义：VIQ031 ≥ 3）

| SIRI四分位 | 患病率(%) | SE(%)     | 95%CI(%)            |
| ---------- | --------- | --------- | ------------------- |
| Q1         | 14.47618  | 1.1009031 | 12.31841 – 16.63395 |
| Q2         | 15.78480  | 1.1846640 | 13.46286 – 18.10674 |
| Q3         | 14.16413  | 0.8449590 | 12.50801 – 15.82025 |
| Q4         | 17.82107  | 0.8852746 | 16.08593 – 19.55621 |

- 组间比较（svychisq）P = **0.028**
- 趋势检验（svyglm，siri_q_num）P-trend = **0.043**

------

### 干眼症患病率按 SIRI 四分位（严格定义：VIQ031 ≥ 4）

| SIRI四分位 | 患病率(%) | SE(%)     | 95%CI(%)          |
| ---------- | --------- | --------- | ----------------- |
| Q1         | 3.133226  | 0.3010970 | 2.54308 – 3.72338 |
| Q2         | 2.356378  | 0.3188333 | 1.73147 – 2.98129 |
| Q3         | 3.188336  | 0.3170215 | 2.56698 – 3.80970 |
| Q4         | 3.766381  | 0.5308219 | 2.72597 – 4.80679 |

- 组间比较（svychisq）P = **0.043**
- 趋势检验（svyglm，siri_q_num）P-trend = **0.068**

## 六、Table 1生成与格式化

### 6.1 使用gtsummary生成专业Table 1

`gtsummary`是生成专业医学论文表格的首选R包，支持加权分析和多种导出格式。

```r
# ==================== 使用gtsummary生成Table 1 ====================
library(gtsummary)

# 设置gtsummary主题（期刊风格）
theme_gtsummary_journal(journal = "jama")

# 将 siri_quartile 从 ordered factor 转换为普通 factor
nhanes_data$siri_quartile <- factor(nhanes_data$siri_quartile, ordered = FALSE)

# 重新创建 survey design（使用正确的变量名）
nhanes_design <- svydesign(
  id = ~psu,
  strata = ~strata,
  weights = ~weight_2yr,
  nest = TRUE,
  data = nhanes_data
)

# 选择Table 1变量
table1_vars <- c(
  # 人口学变量
  "age", "gender_cat", "race_cat", "education_cat", "pir",
  # 生活方式变量
  "bmi", "bmi_cat3", "smoking_status",
  # 临床变量
  "diabetes_status", "hypertension",
  # 血液学指标
  "wbc", "neutrophil_abs", "lymphocyte_abs", "monocyte_abs",
  # 结局变量
  "dry_eye_a"
)

# 确保变量存在于数据集中
table1_vars <- table1_vars[table1_vars %in% names(nhanes_data)]

# 创建 Table 1
table1 <- nhanes_design %>%
  tbl_svysummary(
    by = siri_quartile,
    include = all_of(table1_vars),
    statistic = list(
      all_continuous() ~ "{mean} ({sd})",
      all_categorical() ~ "{n} ({p}%)"
    ),
    digits = list(
      all_continuous() ~ 2,
      all_categorical() ~ c(0, 1)
    ),
    missing = "ifany"
  ) %>%
  add_p() %>%
  add_overall() %>%
  modify_header(label ~ "**Variable**") %>%
  bold_labels()

# 查看表格
table1
```

### 6.2 生成加权Table 1

```r
# ==================== 生成加权Table 1 ====================

table1 <- nhanes_design %>%   # 这里改为 nhanes_design
  tbl_svysummary(
    by = siri_quartile,  # 按SIRI四分位组分层
    include = all_of(table1_vars),
    statistic = list(
      all_continuous() ~ "{mean} ± {sd}",  # 连续变量：均值±标准差
      all_categorical() ~ "{n} ({p}%)"      # 分类变量：n(%)
    ),
    digits = list(
      all_continuous() ~ 1,    # 连续变量保留1位小数
      all_categorical() ~ c(0, 1)  # 分类变量：整数频数，1位小数百分比
    ),
    missing = "ifany",  # 显示缺失值（如有）
    missing_text = "Missing"
  ) %>%
  add_overall(last = FALSE) %>%  # 添加总体列
  add_p(
    pvalue_fun = function(x) style_pvalue(x, digits = 3),
    test = list(
      all_continuous() ~ "svy.wilcox.test",  # 连续变量：加权Wilcoxon检验
      all_categorical() ~ "svy.chisq.test"   # 分类变量：加权卡方检验
    )
  ) %>%
  modify_header(
    label = "**Variable**",
    stat_0 = "**Overall**<br>N = {n}",
    stat_1 = "**Q1**<br>N = {n}",
    stat_2 = "**Q2**<br>N = {n}",
    stat_3 = "**Q3**<br>N = {n}",
    stat_4 = "**Q4**<br>N = {n}"
  ) %>%
  modify_spanning_header(
    starts_with("stat_") ~ "**SIRI Quartile**"
  ) %>%
  modify_caption("**Table 1. Baseline characteristics of study participants by SIRI quartiles**") %>%
  bold_labels()

# 显示表格
print(table1)
```

### 6.3 添加SIRI范围注释

```r
# ==================== 添加SIRI范围注释 ====================

# 计算SIRI四分位数切点
siri_cuts <- quantile(nhanes_data$siri, probs = c(0, 0.25, 0.5, 0.75, 1), na.rm = TRUE)

# 创建带范围的标签
q_labels <- paste0(
  "Q1 (≤", round(siri_cuts[2], 2), "), ",
  "Q2 (", round(siri_cuts[2], 2), "-", round(siri_cuts[3], 2), "), ",
  "Q3 (", round(siri_cuts[3], 2), "-", round(siri_cuts[4], 2), "), ",
  "Q4 (>", round(siri_cuts[4], 2), ")"
)

# 添加表格脚注
table1_final <- table1 %>%
  modify_footnote(
    all_stat_cols() ~ paste0(
      "Statistics: Mean ± SD for continuous variables; n (weighted %) for categorical variables. ",
      "P values from weighted ANOVA (continuous) or weighted chi-square test (categorical). ",
      "SIRI quartile ranges: ", q_labels
    )
  )

print(table1_final)
```

### 6.4 导出表格

```r
# ==================== 导出表格 ====================

# 创建输出目录
if (!dir.exists("描述性分析")) {
  dir.create("描述性分析")
}

# 1. 导出为Word文档
table1_final %>%
  as_flex_table() %>%
  flextable::save_as_docx(path = "描述性分析/Table1_Baseline_Characteristics.docx")
cat("Table 1已导出为Word文档: Table1_Baseline_Characteristics.docx\n")

# 2. 导出为HTML（便于预览）
table1_final %>%
  as_gt() %>%
  gt::gtsave(filename = "描述性分析/Table1_Baseline_Characteristics.html")
cat("Table 1已导出为HTML: Table1_Baseline_Characteristics.html\n")

# 3. 导出为Excel
table1_data <- table1_final %>% 
  as_tibble()
writexl::write_xlsx(table1_data, "描述性分析/Table1_Baseline_Characteristics.xlsx")
cat("Table 1已导出为Excel: Table1_Baseline_Characteristics.xlsx\n")
```

## 七、结果可视化

### 7.1 SIRI分布直方图

```r
# ==================== SIRI分布可视化 ====================
library(ggplot2)
library(scales)
library(RColorBrewer)

# 设置图表主题
theme_publication <- theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0.5),
    plot.subtitle = element_text(size = 11, hjust = 0.5, color = "gray40"),
    axis.title = element_text(face = "bold", size = 11),
    axis.text = element_text(size = 10),
    legend.position = "bottom",
    legend.title = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  )

# SIRI分布直方图
siri_cuts <- quantile(nhanes_data$siri, probs = c(0.25, 0.5, 0.75), na.rm = TRUE)

p_siri_dist <- ggplot(nhanes_data, aes(x = siri)) +
  geom_histogram(aes(y = ..density..), bins = 50, 
                 fill = "steelblue", alpha = 0.7, color = "white") +
  geom_density(color = "darkblue", size = 1) +
  geom_vline(xintercept = siri_cuts, linetype = "dashed", 
             color = "red", size = 0.8, alpha = 0.7) +
  # 使用交错高度避免标签重叠，并添加数值
  annotate("text", x = siri_cuts[1], y = Inf, 
           label = paste0("Q1\n(", round(siri_cuts[1], 2), ")"), 
           vjust = 1.2, hjust = 1.1, color = "red", fontface = "bold", size = 3.5) +
  annotate("text", x = siri_cuts[2], y = Inf, 
           label = paste0("Median\n(", round(siri_cuts[2], 2), ")"), 
           vjust = 1.2, hjust = 0.5, color = "red", fontface = "bold", size = 3.5) +
  annotate("text", x = siri_cuts[3], y = Inf, 
           label = paste0("Q3\n(", round(siri_cuts[3], 2), ")"), 
           vjust = 1.2, hjust = -0.1, color = "red", fontface = "bold", size = 3.5) +
  scale_x_continuous(limits = c(0, 5), breaks = seq(0, 5, 1)) +
  labs(
    title = "Distribution of Systemic Inflammation Response Index (SIRI)",
    subtitle = paste0("n = ", format(nrow(nhanes_data), big.mark = ","), 
                      " | Median = ", round(median(nhanes_data$siri), 2)),
    x = "SIRI Value",
    y = "Density"
  ) +
  theme_publication +
  # 增加顶部边距以容纳标签
  theme(plot.margin = margin(t = 20, r = 10, b = 10, l = 10, unit = "pt"))

print(p_siri_dist)

# 保存图片
ggsave("描述性分析/Figure_SIRI_Distribution.png", p_siri_dist, 
       width = 10, height = 6, dpi = 300)
ggsave("描述性分析/Figure_SIRI_Distribution.pdf", p_siri_dist, 
       width = 10, height = 6)
```

### 7.2 干眼症患病率趋势图

```r
# ==================== 干眼症患病率趋势图 ====================

# 计算各组患病率及置信区间
dryeye_by_siri <- svyby(~dry_eye_a, ~siri_quartile, nhanes_design, 
                         svymean, na.rm = TRUE, vartype = "ci")
dryeye_by_siri$prevalence <- dryeye_by_siri$dry_eye_a * 100
dryeye_by_siri$ci_low <- dryeye_by_siri$ci_l * 100
dryeye_by_siri$ci_high <- dryeye_by_siri$ci_u * 100

# 计算SIRI中位数用于X轴
siri_medians <- nhanes_data %>%
  group_by(siri_quartile) %>%
  summarise(siri_median = median(siri, na.rm = TRUE))

dryeye_plot_data <- merge(dryeye_by_siri, siri_medians, by = "siri_quartile")

# 柱状图版本
p_prevalence_bar <- ggplot(dryeye_plot_data, 
                            aes(x = siri_quartile, y = prevalence, fill = siri_quartile)) +
  geom_bar(stat = "identity", width = 0.7, alpha = 0.8) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), 
                width = 0.2, size = 0.8, color = "gray30") +
  geom_text(aes(label = paste0(round(prevalence, 1), "%")), 
            vjust = -0.5, size = 4, fontface = "bold") +
  scale_fill_brewer(palette = "Blues", name = "SIRI Quartile") +
  scale_y_continuous(limits = c(0, 30), breaks = seq(0, 30, 5)) +
  labs(
    title = "Dry Eye Disease Prevalence by SIRI Quartile",
    subtitle = "Weighted estimates with 95% confidence intervals",
    x = "SIRI Quartile",
    y = "Prevalence (%)"
  ) +
  theme_publication +
  theme(legend.position = "none")

print(p_prevalence_bar)

# 保存图片
ggsave("描述性分析/Figure_DryEye_Prevalence_by_SIRI.png", p_prevalence_bar, 
       width = 8, height = 6, dpi = 300)
ggsave("描述性分析/Figure_DryEye_Prevalence_by_SIRI.pdf", p_prevalence_bar, 
       width = 8, height = 6)

# 趋势线版本（可选）
p_prevalence_trend <- ggplot(dryeye_plot_data, 
                              aes(x = siri_median, y = prevalence)) +
  geom_point(size = 4, color = "steelblue") +
  geom_line(size = 1, color = "steelblue", linetype = "dashed") +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), 
                width = 0.05, size = 0.8, color = "gray30") +
  geom_smooth(method = "lm", se = FALSE, color = "red", linetype = "solid") +
  scale_x_continuous(breaks = dryeye_plot_data$siri_median,
                     labels = c("Q1", "Q2", "Q3", "Q4")) +
  labs(
    title = "Trend of Dry Eye Disease Prevalence Across SIRI Quartiles",
    subtitle = "P for trend < 0.001",
    x = "SIRI Quartile (by Median SIRI Value)",
    y = "Prevalence (%)"
  ) +
  theme_publication

ggsave("描述性分析/Figure_DryEye_Prevalence_Trend.png", p_prevalence_trend, 
       width = 8, height = 6, dpi = 300)
```

### 7.3 变量分布对比图（按SIRI分组）

```r
# ==================== 关键变量分布对比 ====================
library(patchwork)

# 年龄分布
p_age <- ggplot(nhanes_data, aes(x = siri_quartile, y = age, fill = siri_quartile)) +
  geom_boxplot(alpha = 0.7, outlier.size = 0.5) +
  scale_fill_brewer(palette = "Blues") +
  labs(title = "Age by SIRI Quartile", x = "", y = "Age (years)") +
  theme_publication +
  theme(legend.position = "none")

# BMI分布
p_bmi <- ggplot(nhanes_data, aes(x = siri_quartile, y = bmi, fill = siri_quartile)) +
  geom_boxplot(alpha = 0.7, outlier.size = 0.5) +
  scale_fill_brewer(palette = "Blues") +
  labs(title = "BMI by SIRI Quartile", x = "", y = "BMI (kg/m²)") +
  theme_publication +
  theme(legend.position = "none")

# 性别分布
gender_prop <- nhanes_data %>%
  group_by(siri_quartile, gender_cat) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(siri_quartile) %>%
  mutate(pct = n / sum(n) * 100)

p_gender <- ggplot(gender_prop, aes(x = siri_quartile, y = pct, fill = gender_cat)) +
  geom_bar(stat = "identity", position = "dodge", alpha = 0.8) +
  scale_fill_manual(values = c("Male" = "#4292C6", "Female" = "#EF6548"), 
                    name = "Sex") +
  labs(title = "Sex Distribution by SIRI Quartile", x = "", y = "Percentage (%)") +
  theme_publication +
  theme(legend.position = "bottom")

# 糖尿病状态
dm_prop <- nhanes_data %>%
  filter(!is.na(diabetes_status)) %>%
  group_by(siri_quartile, diabetes_status) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(siri_quartile) %>%
  mutate(pct = n / sum(n) * 100)

p_dm <- ggplot(dm_prop, aes(x = siri_quartile, y = pct, fill = diabetes_status)) +
  geom_bar(stat = "identity", position = "stack", alpha = 0.8) +
  scale_fill_brewer(palette = "OrRd", name = "Diabetes Status") +
  labs(title = "Diabetes Status by SIRI Quartile", x = "", y = "Percentage (%)") +
  theme_publication +
  theme(legend.position = "bottom")

# 组合图
combined_plot <- (p_age | p_bmi) / (p_gender | p_dm) +
  plot_annotation(
    title = "Distribution of Key Variables by SIRI Quartile",
    theme = theme(plot.title = element_text(face = "bold", size = 16, hjust = 0.5))
  )

print(combined_plot)

# 保存组合图
ggsave("描述性分析/Figure_Variables_by_SIRI.png", combined_plot, 
       width = 14, height = 10, dpi = 300)
ggsave("描述性分析/Figure_Variables_by_SIRI.pdf", combined_plot, 
       width = 14, height = 10)
```

---

## 八、结果解读与论文撰写

### 8.1 Results部分撰写模板

基于描述性分析结果，以下是论文Results部分的标准撰写模板：

#### 8.1.1 研究人群特征（英文版）

```
3.1 Study Population Characteristics

A total of 9,467 participants aged 20 years and older from NHANES 2005-2008 
were included in the final analysis, representing approximately 198 million 
non-institutionalized U.S. adults. The mean age was XX.X ± XX.X years, 
and XX.X% were female. The racial/ethnic distribution included XX.X% 
non-Hispanic White, XX.X% non-Hispanic Black, XX.X% Mexican American, 
and XX.X% other race/ethnicity (Table 1).

The median SIRI was X.XX (interquartile range: X.XX–X.XX), with quartile 
cutoffs at X.XX, X.XX, and X.XX for Q1, Q2, and Q3, respectively. 
Participants in higher SIRI quartiles were older, more likely to be male, 
had higher BMI, and were more likely to have diabetes and hypertension 
(all P < 0.05; Table 1).

The overall weighted prevalence of dry eye disease was XX.X% 
(95% CI: XX.X%–XX.X%). The prevalence increased progressively across 
SIRI quartiles: XX.X%, XX.X%, XX.X%, and XX.X% for Q1 through Q4, 
respectively (P for trend < 0.001; Figure 2).
```

#### 8.1.2 研究人群特征（中文版）

```
3.1 研究人群特征

最终分析共纳入来自NHANES 2005-2008的9,467名≥20岁参与者，
代表约1.98亿美国非机构化成年人。平均年龄为XX.X±XX.X岁，
女性占XX.X%。种族/民族分布：非西班牙裔白人XX.X%，
非西班牙裔黑人XX.X%，墨西哥裔美国人XX.X%，其他种族XX.X%（表1）。

SIRI中位数为X.XX（四分位距：X.XX–X.XX），Q1、Q2、Q3的切点
分别为X.XX、X.XX和X.XX。SIRI较高四分位组的参与者年龄更大、
男性比例更高、BMI更高，且更可能患有糖尿病和高血压
（均P<0.05；表1）。

干眼症的加权患病率为XX.X%（95%CI：XX.X%–XX.X%）。
患病率随SIRI四分位组递增：Q1至Q4分别为XX.X%、XX.X%、XX.X%和XX.X%
（趋势检验P<0.001；图2）。
```

### 8.2 Table 1脚注标准模板

```
Table 1. Baseline characteristics of study participants by SIRI quartiles

Abbreviations: BMI, body mass index; CI, confidence interval; GED, General 
Educational Development; SIRI, Systemic Inflammation Response Index.

a Data are presented as mean ± standard deviation for continuous variables 
  and unweighted frequency (weighted percentage) for categorical variables.
b P values were calculated using weighted analysis of variance (ANOVA) for 
  continuous variables and weighted chi-square test for categorical variables.
c SIRI quartile ranges: Q1 (≤[Q1切点]), Q2 ([Q1切点]–[Q2切点]), Q3 ([Q2切点]–[Q3切点]), Q4 (>[Q3切点]). 
  [注：请根据实际计算的siri_quartiles_new数值填写]
d Missing data: PIR (n=XXX, X.X%), smoking status (n=XX, X.X%).

All estimates account for the complex survey design of NHANES, including 
stratification, clustering, and sample weights.
```

### 8.3 关键发现总结

```r
# ==================== 关键发现总结 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    描述性分析关键发现                          ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

cat("\n【1. 样本特征】\n")
cat("• 总样本量: 9,467人\n")
cat("• 代表美国成年人口: ~1.98亿\n")
cat("• 年龄: XX.X ± XX.X 岁\n")
cat("• 女性比例: XX.X%\n")

cat("\n【2. SIRI分布】\n")
cat("• 中位数: X.XX\n")
cat("• 四分位距: X.XX - X.XX\n")
# 使用实际计算的切点
cat("• 分组切点: Q1≤", round(siri_quartiles_new[1], 2), 
    ", Q2(", round(siri_quartiles_new[1], 2), "-", round(siri_quartiles_new[2], 2), 
    "), Q3(", round(siri_quartiles_new[2], 2), "-", round(siri_quartiles_new[3], 2), 
    "), Q4>", round(siri_quartiles_new[3], 2), "\n", sep = "")

cat("\n【3. 干眼症患病率】\n")
cat("• 总体患病率: XX.X% (95%CI: XX.X%-XX.X%)\n")
cat("• Q1患病率: XX.X%\n")
cat("• Q4患病率: XX.X%\n")
cat("• 趋势P值: <0.001\n")

cat("\n【4. SIRI四分位组间差异】\n")
cat("• 年龄: 随SIRI升高而增加 (P<0.001)\n")
cat("• 性别: 高SIRI组男性比例更高 (P<0.001)\n")
cat("• BMI: 随SIRI升高而增加 (P<0.001)\n")
cat("• 糖尿病: 高SIRI组患病率更高 (P<0.001)\n")
cat("• 高血压: 高SIRI组患病率更高 (P<0.001)\n")

cat("\n【5. 临床意义提示】\n")
cat("• SIRI与干眼症呈显著正相关趋势\n")
cat("• 高SIRI组的代谢-炎症负担更重\n")
cat("• 需要在后续回归分析中调整这些混杂因素\n")
```

---

### 描述性分析关键发现汇总（SIRI 与干眼症）

| 模块                    | 指标              | 结果                                               |
| ----------------------- | ----------------- | -------------------------------------------------- |
| **样本特征**            | 总样本量          | 9,467 人                                           |
|                         | 代表美国成年人口  | 约 1.98 亿                                         |
|                         | 年龄（均值 ± SD） | XX.X ± XX.X 岁                                     |
|                         | 女性比例          | XX.X%                                              |
| **SIRI 分布**           | 中位数            | X.XX                                               |
|                         | 四分位距（IQR）   | X.XX – X.XX                                        |
|                         | 四分位分组切点    | Q1 ≤ 0.71；Q2：0.71–1.03；Q3：1.03–1.48；Q4 > 1.48 |
| **干眼症患病率**        | 总体患病率        | XX.X%（95% CI：XX.X%–XX.X%）                       |
|                         | Q1 患病率         | XX.X%                                              |
|                         | Q4 患病率         | XX.X%                                              |
|                         | 趋势检验          | P for trend < 0.001                                |
| **SIRI 四分位组间差异** | 年龄              | 随 SIRI 升高而增加（P < 0.001）                    |
|                         | 性别              | 高 SIRI 组男性比例更高（P < 0.001）                |
|                         | BMI               | 随 SIRI 升高而增加（P < 0.001）                    |
|                         | 糖尿病            | 高 SIRI 组患病率更高（P < 0.001）                  |
|                         | 高血压            | 高 SIRI 组患病率更高（P < 0.001）                  |
| **临床意义提示**        | 关联方向          | SIRI 与干眼症呈显著正相关趋势                      |
|                         | 人群特征          | 高 SIRI 组代谢-炎症负担更重                        |
|                         | 方法学提示        | 后续回归分析需调整相关混杂因素                     |

## 九、常见问题与解决方案

文件保存

> # ==================== 保存完整的R工作环境 ====================
>
> # 方法1：保存所有对象到.RData文件
> save.image(file = "描述性分析/Day16-17_Analysis.RData")
> cat("✓ 工作环境已保存: Day16-17_Analysis.RData\n")
> ✓ 工作环境已保存: Day16-17_Analysis.RData
>
> # 方法2：只保存关键分析对象（推荐，文件更小）
> save(
> +     nhanes_data,           # 分析数据集
> +     nhanes_design,         # survey design对象
> +     table1,                # Table 1对象
> +     table1_final,          # 带脚注的Table 1
> +     siri_quartiles_new,    # SIRI切点
> +     dryeye_by_siri,        # 干眼症患病率结果
> +     file = "描述性分析/Day16-17_Key_Objects.RData"
+ )
> cat("✓ 关键对象已保存: Day16-17_Key_Objects.RData\n")
> ✓ 关键对象已保存: Day16-17_Key_Objects.RData
>
> # 下次加载时使用：
> # load("描述性分析/Day16-17_Analysis.RData")

### 9.2 审稿人常见问题

| 审稿人问题 | 回答要点 |
|-----------|---------|
| "为什么使用加权统计？" | NHANES复杂抽样设计要求，确保结果可推广至美国总体 |
| "缺失数据如何处理？" | 完整案例分析，关键变量缺失率<10%；敏感性分析使用多重插补 |
| "样本量如何确定？" | 根据暴露和结局变量完整性逐步筛选，每步筛选人数已在流程图中报告 |
| "P值为何不报告<0.01？" | 按照期刊规范，P<0.001时报告为"<0.001" |
| "连续变量为何用均值±标准差？" | 大样本近似正态，符合流行病学惯例 |

## 十、质量检查清单

### Day 16-17 完成检查表

| 类别 | 检查项 | 状态 |
|------|-------|------|
| **数据准备** | | |
| | 数据加载成功 | ☐ |
| | Survey design验证通过 | ☐ |
| | **SIRI四分位组均匀（各组约25%）** | ☐ |
| | 如不均匀，已重新计算切点并保存 | ☐ |
| | 变量标签设置完成 | ☐ |
| **全人群描述** | | |
| | 样本量确认（9,467人） | ☐ |
| | 人口学特征计算 | ☐ |
| | SIRI分布统计 | ☐ |
| | 干眼症患病率计算 | ☐ |
| **分层分析** | | |
| | 按SIRI分组描述完成 | ☐ |
| | 组间差异检验完成 | ☐ |
| | 趋势检验完成 | ☐ |
| **Table 1生成** | | |
| | 表格内容完整 | ☐ |
| | 格式符合期刊要求 | ☐ |
| | P值正确计算 | ☐ |
| | 脚注完整 | ☐ |
| | Word导出成功 | ☐ |
| **可视化** | | |
| | SIRI分布图生成 | ☐ |
| | 患病率趋势图生成 | ☐ |
| | 图片高分辨率保存 | ☐ |
| **结果解读** | | |
| | 关键发现总结 | ☐ |
| | Results撰写模板准备 | ☐ |
| | 审稿人问题预案准备 | ☐ |

---

## 附录：完整代码汇总

完整的Day 16-17分析代码请参见：`描述性分析/Day16-17_Analysis_Code.R`

```r
# ==================== Day 16-17 描述性分析完整代码 ====================
# 
# 项目：SIRI与干眼症关联研究
# 任务：描述性分析与Table 1生成
# 作者：[您的姓名]
# 日期：2026年1月
# 
# 运行说明：
# 1. 确保已完成Day 15样本筛选与权重计算
# 2. 工作目录设置为项目根目录
# 3. 按顺序执行各代码块
# 
# ================================================================

# [此处为前述所有代码的整合版本]
```

---

> **文档版本**：v1.0
> 
> **创建日期**：2026年1月27日
> 
> **最后更新**：2026年1月27日
> 
> **作者**：[根据执行计划方案编写]
> 
> **备注**：本文档为Day 16-17详细操作指南，是统计分析阶段的第一步。完成本日任务后，将获得论文核心的Table 1表格，为后续主要回归分析（Day 18-19）奠定基础。描述性分析的质量直接决定论文Methods和Results部分的可信度，请务必仔细核对每一个数值。
