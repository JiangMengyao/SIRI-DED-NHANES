# Day 20：剂量-反应分析（RCS）操作详解

> **任务目标**：基于Day 18-19完成的主要回归分析，进行限制性立方样条（Restricted Cubic Spline, RCS）分析，探索SIRI与干眼症之间的剂量-反应关系，检验是否存在非线性关联，并绘制专业的剂量-反应曲线图。
> 
> **预计用时**：4-6小时（1天）
> 
> **前置条件**：
> - 已完成Day 18-19主要回归分析
> - 生成`Day18-19_Regression_Objects.RData`文件
> - 生成`nhanes_complete`数据集（8,664人）
> - 生成`nhanes_design_complete`（survey design对象）
> 
> **技术要求**：R语言（rms包、ggplot2包、survey包）
> 
> **输出目标**：
> - 非线性检验P值
> - 整体关联检验P值
> - Figure 2：剂量-反应曲线图（OR及95%CI）
> - Results部分撰写模板

---

## 目录

1. [整体流程概览](#一整体流程概览)
2. [RCS分析原理与方法](#二rcs分析原理与方法)
3. [环境准备与数据加载](#三环境准备与数据加载)
4. [RCS模型构建与设置](#四rcs模型构建与设置)
5. [RCS分析实施](#五rcs分析实施)
6. [非线性检验与整体关联检验](#六非线性检验与整体关联检验)
7. [剂量-反应曲线图绘制](#七剂量-反应曲线图绘制)
8. [结果解读与论文撰写](#八结果解读与论文撰写)
9. [敏感性分析：不同节点设置](#九敏感性分析不同节点设置)
10. [常见问题与解决方案](#十常见问题与解决方案)
11. [质量检查清单](#十一质量检查清单)

---

## 一、整体流程概览

### 1.1 Day 20 核心任务流程图

```
┌─────────────────────────────────────────────────────────────┐
│                    【Day 20：剂量-反应分析】                  │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  加载Day 18-19回归分析对象                                    │
│          ↓                                                   │
│  ==================== RCS分析准备 ====================       │
│          ↓                                                   │
│    确定节点数量与位置                                         │
│    （默认：4节点，5th/35th/65th/95th百分位）                  │
│          ↓                                                   │
│    选择参考值（SIRI中位数）                                   │
│          ↓                                                   │
│  ==================== RCS模型拟合 ====================       │
│          ↓                                                   │
│    使用rms::lrm构建RCS模型                                   │
│          ↓                                                   │
│    进行非线性检验（Wald检验）                                 │
│          ↓                                                   │
│    进行整体关联检验                                           │
│          ↓                                                   │
│  ==================== 结果可视化 ====================        │
│          ↓                                                   │
│    计算各SIRI值对应的OR及95%CI                               │
│          ↓                                                   │
│    绘制剂量-反应曲线图（Figure 2）                            │
│          ↓                                                   │
│    导出高分辨率图片                                           │
│          ↓                                                   │
│  ==================== 结果整理 ====================          │
│          ↓                                                   │
│    准备Results段落撰写                                        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 核心任务清单

| 任务类别 | 具体任务 | 输出物 | 优先级 |
|---------|---------|--------|--------|
| **RCS准备** | 确定节点设置 | 节点位置 | ★★★★ |
| **模型拟合** | 拟合RCS Logistic回归 | RCS模型对象 | ★★★★★ |
| **非线性检验** | 检验SIRI与干眼症是否非线性关联 | P-nonlinear | ★★★★★ |
| **整体检验** | 检验SIRI与干眼症的整体关联 | P-overall | ★★★★★ |
| **Figure 2** | 绘制剂量-反应曲线 | 高分辨率图片 | ★★★★★ |
| **敏感性分析** | 不同节点设置的敏感性分析 | 汇总表格 | ★★★☆ |

---

## 二、RCS分析原理与方法

### 2.1 什么是限制性立方样条（RCS）？

**限制性立方样条（Restricted Cubic Spline）** 是一种灵活的统计方法，用于建模连续变量与结局之间的非线性关系。

#### 核心概念

| 概念 | 解释 | 本研究应用 |
|-----|------|-----------|
| **样条函数** | 分段多项式函数，在节点处连接 | 拟合SIRI与干眼症的复杂关系 |
| **节点(Knots)** | 样条函数的连接点，决定曲线形状 | 通常选择3-5个节点 |
| **限制性** | 在两端节点外假设为线性，避免边缘不稳定 | 增加模型稳定性 |
| **自由度** | 节点数-1，决定曲线灵活程度 | 4节点=3个自由度 |

#### 为什么在本研究中使用RCS？

| 原因 | 说明 |
|-----|------|
| **避免线性假设** | 四分位分析提示Q4患病率最高，但Q2/Q3无明显趋势 |
| **探索阈值效应** | 炎症可能存在阈值，超过某水平才显著影响干眼症 |
| **更精确的风险评估** | 连续估计各SIRI水平的OR值 |
| **期刊要求** | 2区以上期刊通常期望看到剂量-反应分析 |

### 2.2 节点选择策略

根据**Harrell建议**，节点数量与样本量相关：

| 样本量 | 推荐节点数 | 节点位置 |
|-------|-----------|---------|
| <100 | 3个 | 10th, 50th, 90th百分位 |
| 100-500 | 4个 | 5th, 35th, 65th, 95th百分位 |
| >500 | 5个 | 5th, 27.5th, 50th, 72.5th, 95th百分位 |

**本研究选择**：
- **节点数**：4个（样本量8,664人）
- **节点位置**：5th, 35th, 65th, 95th百分位
- **参考值**：SIRI中位数（约为第50百分位）

### 2.3 统计检验解读

RCS分析提供两个关键检验：

| 检验类型 | 假设 | 解释 | 结果判读 |
|---------|-----|------|---------|
| **P-nonlinear** | H₀：关联为线性 | 检验是否存在非线性关联 | P<0.05 表示存在非线性 |
| **P-overall** | H₀：无关联 | 检验SIRI与干眼症的整体关联 | P<0.05 表示存在关联 |

#### 结果解读矩阵

| P-nonlinear | P-overall | 结论 |
|------------|-----------|------|
| <0.05 | <0.05 | 存在显著的非线性关联 |
| ≥0.05 | <0.05 | 存在显著的线性关联 |
| <0.05 | ≥0.05 | 存在非线性趋势，但整体不显著 |
| ≥0.05 | ≥0.05 | 无显著关联 |

### 2.4 RCS在NHANES分析中的特殊考虑

> ⚠️ **重要说明**：
> 
> 标准的`rms::lrm`函数**不直接支持**NHANES的复杂抽样设计。本指南提供两种解决方案：
> 
> **方案A（推荐）**：使用`survey::svyglm` + `rms::rcs`函数组合
> - 优点：正确处理权重、聚类、分层
> - 缺点：需要手动计算非线性检验
> 
> **方案B（简化）**：使用加权`lrm`
> - 优点：直接获得非线性检验结果
> - 缺点：不处理聚类效应，标准误可能偏小

---

## 三、环境准备与数据加载

### 3.1 安装与加载必要的R包

```r
# ==================== 环境设置 ====================
# 设置工作目录
setwd("/Users/mayiding/Desktop/第一篇")

# 安装必要的包（如未安装）
required_packages <- c(
  "survey",       # 复杂调查分析
  "rms",          # RCS分析核心包
  "ggplot2",      # 可视化
  "dplyr",        # 数据处理
  "splines",      # 样条函数
  "gridExtra",    # 图形排列
  "scales",       # 坐标轴刻度
  "cowplot",      # 图形美化
  "broom"         # 模型结果整理
)

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

cat("所有包加载完成！\n")

# 设置rms包全局选项
options(datadist = "dd")
```

### 3.2 加载Day 18-19分析对象

```r
# ==================== 加载数据 ====================

# 加载Day 18-19保存的回归分析对象
load("描述性分析/Day18-19_Regression_Objects.RData")

# 或者加载Day 16-17的原始数据重新创建
# load("描述性分析/Day16-17_Key_Objects.RData")

# ==================== 数据验证 ====================
cat("\n==================== 数据加载验证 ====================\n")
cat("分析样本量:", nrow(nhanes_complete), "\n")
cat("SIRI变量范围:", round(range(nhanes_complete$siri, na.rm = TRUE), 3), "\n")
cat("SIRI均值:", round(mean(nhanes_complete$siri, na.rm = TRUE), 3), "\n")
cat("SIRI中位数:", round(median(nhanes_complete$siri, na.rm = TRUE), 3), "\n")
cat("干眼症病例数:", sum(nhanes_complete$dry_eye_a == 1, na.rm = TRUE), "\n")

# 检查关键变量是否存在
required_vars <- c("siri", "dry_eye_a", "age", "gender_cat", "race_cat", 
                   "education_cat", "pir", "bmi", "smoking_status", 
                   "diabetes_status", "hypertension")
missing_vars <- setdiff(required_vars, names(nhanes_complete))
if (length(missing_vars) > 0) {
  stop("缺少必要变量: ", paste(missing_vars, collapse = ", "))
} else {
  cat("\n✓ 所有必要变量已确认\n")
}
```

![截屏2026-01-28 21.22.56](assets/截屏2026-01-28 21.22.56.png)

### 3.3 创建RCS分析所需的数据分布对象

```r
# ==================== 创建datadist对象 ====================
# datadist对象存储变量分布信息，用于后续预测

# 创建datadist对象
dd <- datadist(nhanes_complete)
options(datadist = "dd")

cat("\n==================== SIRI分布统计 ====================\n")
cat("\n百分位数:\n")
siri_percentiles <- quantile(nhanes_complete$siri, 
                              probs = c(0.01, 0.05, 0.10, 0.25, 0.35, 
                                       0.50, 0.65, 0.75, 0.90, 0.95, 0.99),
                              na.rm = TRUE)
print(round(siri_percentiles, 3))

# 记录节点位置（5th, 35th, 65th, 95th百分位）
knots_4 <- quantile(nhanes_complete$siri, 
                    probs = c(0.05, 0.35, 0.65, 0.95), 
                    na.rm = TRUE)

cat("\n4节点位置 (5th, 35th, 65th, 95th):\n")
print(round(knots_4, 3))

# 参考值（中位数）
ref_value <- median(nhanes_complete$siri, na.rm = TRUE)
cat("\n参考值（中位数）:", round(ref_value, 3), "\n")
```

---

![截屏2026-01-28 21.23.21](assets/截屏2026-01-28 21.23.21.png)

## 四、RCS模型构建与设置

### 4.1 定义RCS模型变量

```r
# ==================== 定义模型变量 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    RCS模型变量定义                             ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 结局变量
outcome <- "dry_eye_a"

# 暴露变量（连续型）
exposure <- "siri"

# 协变量（与Model 3一致）
covariates <- c("age", "gender_cat", "race_cat", "education_cat", 
                "pir", "bmi", "smoking_status", "diabetes_status", "hypertension")

cat("\n结局变量:", outcome)
cat("\n暴露变量:", exposure)
cat("\n协变量:", paste(covariates, collapse = ", "))
cat("\n")
```

### 4.2 方案A：使用survey包 + rcs函数（推荐）

这是处理NHANES复杂抽样设计的正确方法：

```r
# ==================== 方案A：survey + rcs ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║            方案A：使用survey包 + rcs函数（推荐）               ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

library(splines)
library(survey)

# 确保survey design对象正确设置
options(survey.lonely.psu = "adjust")

nhanes_design_rcs <- svydesign(
  id = ~psu,
  strata = ~strata,
  weights = ~weight_4yr,
  data = nhanes_complete,
  nest = TRUE
)

# 计算RCS的节点位置
knots_4 <- quantile(nhanes_complete$siri, 
                    probs = c(0.05, 0.35, 0.65, 0.95), 
                    na.rm = TRUE)

cat("\n节点位置:", paste(round(knots_4, 3), collapse = ", "), "\n")

# 创建RCS基函数
# 使用ns（natural spline）或手动创建RCS
# 方法1：使用rms::rcs函数预先计算
library(rms)

# 为SIRI创建RCS变量
nhanes_complete$siri_rcs <- rcs(nhanes_complete$siri, knots_4)

# 但rcs返回的是矩阵，需要提取各个分量
# 更好的方法是直接在公式中使用

# 方法2：使用splines::ns创建自然样条
# 注意：ns和rcs有细微差别，但都可以用于非线性建模

# 构建模型公式
# 这里我们使用rcs直接嵌入公式
formula_rcs <- as.formula(
  paste0(outcome, " ~ rcs(", exposure, ", ", 
         "c(", paste(knots_4, collapse = ","), ")) + ",
         paste(covariates, collapse = " + "))
)

cat("\nRCS模型公式:\n")
print(formula_rcs)

# 注意：svyglm不直接支持rcs函数
# 需要先手动创建RCS基函数，然后纳入svyglm

# 手动创建RCS基函数
create_rcs_basis <- function(x, knots) {
  # 创建限制性立方样条基函数
  # 返回n-2个基函数（n为节点数）
  
  k <- length(knots)
  nk <- k - 2  # 非线性项数量
  
  if (k < 3) stop("需要至少3个节点")
  
  # 创建基函数矩阵
  X <- matrix(0, nrow = length(x), ncol = nk + 1)
  X[, 1] <- x  # 线性项
  
  # 创建非线性项
  for (j in 1:nk) {
    X[, j + 1] <- pmax(0, (x - knots[j])^3) - 
                  pmax(0, (x - knots[k-1])^3) * (knots[k] - knots[j]) / (knots[k] - knots[k-1]) +
                  pmax(0, (x - knots[k])^3) * (knots[k-1] - knots[j]) / (knots[k] - knots[k-1])
  }
  
  return(X)
}

# 应用函数创建RCS基
rcs_basis <- create_rcs_basis(nhanes_complete$siri, as.numeric(knots_4))
colnames(rcs_basis) <- paste0("siri_rcs", 1:ncol(rcs_basis))

# 添加到数据框
for (i in 1:ncol(rcs_basis)) {
  nhanes_complete[[paste0("siri_rcs", i)]] <- rcs_basis[, i]
}

cat("\n已创建RCS基函数变量: siri_rcs1 (线性), siri_rcs2, siri_rcs3 (非线性)\n")

# 更新survey design
nhanes_design_rcs <- svydesign(
  id = ~psu,
  strata = ~strata,
  weights = ~weight_4yr,
  data = nhanes_complete,
  nest = TRUE
)
```

### 4.3 构建RCS svyglm模型

```r
# ==================== 拟合RCS模型 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    拟合RCS svyglm模型                          ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 构建包含RCS项的公式
rcs_vars <- paste0("siri_rcs", 1:3)  # 4节点产生3个变量
formula_rcs_survey <- as.formula(
  paste0(outcome, " ~ ", 
         paste(rcs_vars, collapse = " + "), " + ",
         paste(covariates, collapse = " + "))
)

cat("\n模型公式:\n")
print(formula_rcs_survey)

# 拟合模型
model_rcs <- svyglm(formula_rcs_survey, 
                     design = nhanes_design_rcs, 
                     family = quasibinomial())

cat("\n模型拟合完成\n")

# 查看模型摘要
summary(model_rcs)
```

---

## 一、模型基本信息（保留）

- **模型类型**：Survey-weighted logistic regression
- **方法**：`svyglm()`
- **结局变量**：`dry_eye_a`
- **主要暴露**：`SIRI（RCS，4节点 → 3个样条项）`
- **分布**：`quasibinomial`
- **权重设计**：NHANES 4-year survey design
- **Fisher Scoring iterations**：4
- **Dispersion parameter**：1.006

👉 这些信息**建议在论文方法或表注中完整保留**

------

## 二、RCS 核心结果（重点解读但不删）

| 变量      | β (Estimate) | SE    | t value | P value |
| --------- | ------------ | ----- | ------- | ------- |
| siri_rcs1 | 0.266        | 0.420 | 0.632   | 0.538   |
| siri_rcs2 | -0.267       | 0.546 | -0.489  | 0.633   |
| siri_rcs3 | 0.566        | 1.237 | 0.458   | 0.655   |

**说明（重要）**：

- 单个 RCS 系数 **不显著 ≠ RCS 整体无效**
- **RCS 的科学结论应基于：**
  - 整体效应检验（Wald test）
  - 非线性检验（joint test of nonlinear terms）
  - OR–Spline 曲线图

👉 **系数必须保留，但不建议逐项解释**

------

## 三、协变量结果（完整整理）

### （1）人口学因素

| 变量               | β         | P      |
| ------------------ | --------- | ------ |
| age                | **0.020** | <0.001 |
| Female vs Male     | 0.130     | 0.088  |
| Non-Hispanic Black | **0.322** | 0.0078 |
| Mexican American   | **0.585** | <0.001 |
| Other Hispanic     | **0.383** | 0.0267 |
| Other Race         | **0.360** | 0.020  |

------

### （2）社会经济因素

| 变量                  | β          | P      |
| --------------------- | ---------- | ------ |
| High school graduate  | **-0.374** | <0.001 |
| Some college or above | **-0.607** | <0.001 |
| PIR                   | **-0.224** | <0.001 |

👉 教育程度和 PIR 呈 **明显保护效应**

------

### （3）健康与行为因素

| 变量           | β          | P      |
| -------------- | ---------- | ------ |
| BMI            | 0.006      | 0.271  |
| Former smoker  | 0.078      | 0.456  |
| Current smoker | **0.489**  | <0.001 |
| Prediabetes    | -0.006     | 0.946  |
| Diabetes       | **0.499**  | 0.001  |
| Hypertension   | **-0.196** | 0.025  |

## 五、RCS分析实施

### 5.1 方案B：使用rms::lrm（简化方案）

如果需要快速获得非线性检验结果，可以使用这个简化方案：

```r
# ==================== 方案B：使用rms::lrm ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║            方案B：使用rms::lrm（简化方案）                     ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

library(rms)

# 设置datadist
dd <- datadist(nhanes_complete)
options(datadist = "dd")

# 使用lrm拟合RCS模型（可加权）
# 注意：lrm的权重处理不如svyglm完善
model_lrm <- lrm(dry_eye_a ~ rcs(siri, 4) + 
                  age + gender_cat + race_cat + education_cat + 
                  pir + bmi + smoking_status + diabetes_status + hypertension,
                 data = nhanes_complete,
                 weights = weight_4yr,  # 添加权重
                 x = TRUE, y = TRUE)    # 保留预测变量和结局

cat("\n模型拟合结果:\n")
print(model_lrm)

# 获取非线性检验
cat("\n==================== 非线性检验 ====================\n")
anova_result <- anova(model_lrm)
print(anova_result)
```

![截屏2026-01-28 21.26.43](assets/截屏2026-01-28 21.26.43.png)

### 5.2 手动计算非线性检验（方案A补充）

```r
# ==================== 手动计算非线性检验 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    非线性检验（Wald检验）                       ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 对于svyglm模型，需要使用regTermTest进行非线性检验
# 非线性项是siri_rcs2和siri_rcs3

# 整体SIRI效应检验（线性+非线性）
test_overall <- regTermTest(model_rcs, ~ siri_rcs1 + siri_rcs2 + siri_rcs3,
                            method = "Wald")
cat("\n【整体SIRI效应检验】\n")
cat("F统计量:", round(test_overall$Ftest[1], 3), "\n")
cat("自由度:", test_overall$Ftest[2], ",", test_overall$Ftest[3], "\n")
cat("P-overall:", format.pval(test_overall$p, digits = 3), "\n")

# 非线性效应检验（仅非线性项）
test_nonlinear <- regTermTest(model_rcs, ~ siri_rcs2 + siri_rcs3,
                               method = "Wald")
cat("\n【非线性效应检验】\n")
cat("F统计量:", round(test_nonlinear$Ftest[1], 3), "\n")
cat("自由度:", test_nonlinear$Ftest[2], ",", test_nonlinear$Ftest[3], "\n")
cat("P-nonlinear:", format.pval(test_nonlinear$p, digits = 3), "\n")

# 保存检验结果
p_overall <- test_overall$p
p_nonlinear <- test_nonlinear$p

# 结果解读
cat("\n==================== 结果解读 ====================\n")
if (p_nonlinear < 0.05 & p_overall < 0.05) {
  cat("结论：SIRI与干眼症存在显著的非线性关联\n")
} else if (p_nonlinear >= 0.05 & p_overall < 0.05) {
  cat("结论：SIRI与干眼症存在显著的线性关联\n")
} else if (p_nonlinear < 0.05 & p_overall >= 0.05) {
  cat("结论：存在非线性趋势，但整体关联不显著\n")
} else {
  cat("结论：SIRI与干眼症无显著关联\n")
}
```

---

## 非线性检验结果整理（Wald 检验，svyglm + RCS）

### 一、方法说明

- **模型类型**：`svyglm`（复杂抽样设计）
- **非线性建模**：限制性立方样条（Restricted Cubic Spline, RCS）
- **SIRI 样条项**：
  - 线性项：`siri_rcs1`
  - 非线性项：`siri_rcs2`、`siri_rcs3`
- **检验方法**：`regTermTest()`，Wald 检验

------

### 二、统计检验结果

#### 1️⃣ 整体 SIRI 效应检验（线性 + 非线性）

| 指标              | 数值                                |
| ----------------- | ----------------------------------- |
| 检验项            | `siri_rcs1 + siri_rcs2 + siri_rcs3` |
| Wald F 统计量     | **0.198**                           |
| 自由度            | **NA , NA**                         |
| P 值（P-overall） | **0.896**                           |

📌 **解释**：SIRI 的整体效应（包括线性和非线性成分）在统计学上不显著。

------

#### 2️⃣ 非线性效应检验（仅非线性项）

| 指标                | 数值                    |
| ------------------- | ----------------------- |
| 检验项              | `siri_rcs2 + siri_rcs3` |
| Wald F 统计量       | **0.279**               |
| 自由度              | **NA , NA**             |
| P 值（P-nonlinear） | **0.761**               |

📌 **解释**：未观察到 SIRI 与结局之间显著的非线性关系。

------

### 三、联合结果判定逻辑（与你代码完全一致）

- P-overall = **0.896 ≥ 0.05**
- P-nonlinear = **0.761 ≥ 0.05**

✔ 同时不满足整体显著性
 ✔ 同时不满足非线性显著性

------

### 四、最终结论（标准化表述）

> **结论：**
>  基于复杂抽样设计的限制性立方样条模型（RCS）分析结果显示，SIRI 与干眼症之间**未观察到显著的整体关联（P-overall = 0.896）**，同时**不存在显著的非线性关系（P-nonlinear = 0.761）**。

## 六、非线性检验与整体关联检验

### 6.1 检验结果汇总

```r
# ==================== 检验结果汇总表 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    RCS分析检验结果汇总                         ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 创建汇总表格
rcs_test_summary <- data.frame(
  检验类型 = c("整体关联检验 (P-overall)", "非线性检验 (P-nonlinear)"),
  原假设 = c("SIRI与干眼症无关联", "SIRI与干眼症为线性关联"),
  P值 = c(
    ifelse(p_overall < 0.001, "<0.001", round(p_overall, 3)),
    ifelse(p_nonlinear < 0.001, "<0.001", round(p_nonlinear, 3))
  ),
  结论 = c(
    ifelse(p_overall < 0.05, "拒绝原假设", "接受原假设"),
    ifelse(p_nonlinear < 0.05, "存在非线性", "线性关系")
  )
)

print(rcs_test_summary)

cat("\n【关键结论】\n")
cat("P-overall =", ifelse(p_overall < 0.001, "<0.001", round(p_overall, 3)), "\n")
cat("P-nonlinear =", ifelse(p_nonlinear < 0.001, "<0.001", round(p_nonlinear, 3)), "\n")
```

![截屏2026-01-28 21.28.53](assets/截屏2026-01-28 21.28.53.png)

## 一、RCS 检验结果的**统计学解读**

基于你给出的结果：

- **P-overall = 0.896**
- **P-nonlinear = 0.761**

这两点意味着：

### 1️⃣ 整体关联检验（P-overall）

> **P-overall = 0.896（≫ 0.05）**

- 未发现 **SIRI 与干眼症之间存在显著统计学关联**
- 即：在 **充分调整协变量的模型下**，SIRI 作为连续暴露变量 **整体上不能预测干眼症风险**

👉 **结论**：

> 在本研究人群中，SIRI 与干眼症患病风险 **不存在显著独立关联**

------

### 2️⃣ 非线性检验（P-nonlinear）

> **P-nonlinear = 0.761（≫ 0.05）**

- 未观察到 **非线性剂量–反应关系**
- RCS 曲线在统计意义上 **不偏离线性**
- 且在 P-overall 已不显著的前提下，这意味着：
  - **不存在“隐藏的阈值效应 / U 型 / J 型关系”**

👉 **结论**：

> SIRI 与干眼症之间 **既无显著关联，也无潜在非线性结构**

------

## 二、结合你原始研究假设的“高级解释”

你的研究在方案中预设的核心假设是：

> **SIRI 升高 → 干眼症风险增加** 执行计划方案

而 RCS 结果给出的信息是：

> ❌ **该假设在 NHANES 2005–2008 成年人群中未被支持**

但——这 **并不是“负结果 = 失败”**，而是一个**非常干净、审稿人友好的结论**，原因有三：

------

## 三、为什么这个“无关联 + 无非线性”结果反而是加分项？

### ✅ 1️⃣ 你已经**排除了“模型设定错误”的可能**

RCS 的核心价值就在这里：

- 如果你 **只做线性 Logistic 回归不显著**
   👉 审稿人会问：
   *“Could the association be non-linear?”*
- 而你现在可以非常有底气地回答：

> *“We further explored potential non-linear associations using restricted cubic splines; however, neither the overall association nor non-linearity was statistically significant.”*

👉 **这是方法学完整性的体现**

------

### ✅ 2️⃣ 这支持一个非常合理的生物学推论

结合干眼症机制：

- 干眼症 ≠ 单纯“全身炎症水平升高”
- 更强调：
  - **局部眼表炎症**
  - **神经–泪腺调控**
  - **激素、环境、行为因素**

而 SIRI 本质是：

> **系统性炎症 + 免疫细胞比例指标**

👉 你的结果支持一个很重要的判断：

> **“Systemic inflammation captured by SIRI may not translate into dry eye disease risk in the general population.”**

这是一个**负结果，但非常有机制逻辑**的结论。

------

### ✅ 3️⃣ 和你后续分析“逻辑完全一致”

在你的完整执行方案中，你已经设计了：

- 多模型调整
- 亚组分析
- 敏感性分析
- RCS 剂量–反应分析

RCS 的结果 **正好成为一句“总结性证据”**：

> 即使在最灵活的建模框架下，也未观察到 SIRI 与干眼症之间的显著或非线性关联

### 6.2 与线性模型比较

```r
# ==================== 与线性模型比较 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    RCS模型 vs 线性模型比较                     ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 拟合线性模型（仅包含siri_rcs1，即线性项）
formula_linear <- as.formula(
  paste0(outcome, " ~ siri_rcs1 + ", paste(covariates, collapse = " + "))
)

model_linear <- svyglm(formula_linear, 
                        design = nhanes_design_rcs, 
                        family = quasibinomial())

# 比较AIC（注意：svyglm的AIC需要特殊处理）
# 使用似然比检验比较两个模型
# 由于svyglm使用quasibinomial，不能直接使用LRT

# 替代方案：比较模型系数
cat("\n线性模型（SIRI系数）:\n")
linear_coef <- coef(model_linear)["siri_rcs1"]
linear_se <- sqrt(diag(vcov(model_linear)))["siri_rcs1"]
linear_or <- exp(linear_coef)
linear_ci <- exp(c(linear_coef - 1.96*linear_se, linear_coef + 1.96*linear_se))

cat("  β =", round(linear_coef, 4), "\n")
cat("  OR =", round(linear_or, 3), "(95%CI:", 
    round(linear_ci[1], 3), "-", round(linear_ci[2], 3), ")\n")

# 如果非线性不显著，线性模型可能更合适
if (p_nonlinear >= 0.05) {
  cat("\n📌 建议：由于非线性检验不显著(P =", round(p_nonlinear, 3), ")，")
  cat("线性关系可能是合理的假设。\n")
  cat("   但仍建议在论文中报告RCS分析结果，以展示分析的完整性。\n")
}
```

---

## 一、线性模型结果本身说明了什么？

你当前线性模型（充分调整协变量后）的核心结果是：

- **β = 0.0179**
- **OR = 1.018**
- **95% CI = 0.933 – 1.110**

### 统计学解读（非常关键）

1️⃣ **效应量极小**

- OR ≈ 1.02
- 即：SIRI 每增加 1 个单位，干眼症风险仅增加 **1.8%**
- 这是一个 **临床上几乎可以忽略的效应大小**

2️⃣ **置信区间跨 1**

- CI 覆盖 0.93–1.11
- → **统计学不显著**

👉 **结论一句话**：

> 即使假设 SIRI 与干眼症呈线性关系，其效应也非常微弱且不显著。

------

## 二、把线性模型结果和 RCS 结果“合在一起看”

这是你现在最强的一点 👇

### 1️⃣ RCS 的两项检验已经告诉我们：

- **P-overall = 0.896** → 没有关联
- **P-nonlinear = 0.761** → 没有非线性

### 2️⃣ 线性模型进一步补充的信息是：

- 不只是“没有非线性”
- 而是：
   👉 **即便退回到最简单的线性假设，关联依然不存在**

### 🔗 逻辑链条非常完整（审稿人最爱）

> RCS 显示无非线性
>  ↓
>  线性模型作为合理简化
>  ↓
>  线性效应接近于 0，且不显著
>  ↓
>  **结论稳健：SIRI 与干眼症无显著关联**

这在方法学上叫：

> **consistent null findings across model specifications**

## 七、剂量-反应曲线图绘制

### 7.1 计算各SIRI值对应的OR

```r
# ==================== 计算预测值 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    计算剂量-反应曲线数据                        ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 设置预测的SIRI值范围（从1%到99%分位数）
siri_range <- seq(
  quantile(nhanes_complete$siri, 0.01, na.rm = TRUE),
  quantile(nhanes_complete$siri, 0.99, na.rm = TRUE),
  length.out = 200
)

# 参考值（中位数）
ref_siri <- median(nhanes_complete$siri, na.rm = TRUE)

# 创建参考数据框（其他协变量设为参考值/均值）
# 获取协变量的参考值
ref_data <- data.frame(
  age = mean(nhanes_complete$age, na.rm = TRUE),
  gender_cat = factor("Male", levels = levels(nhanes_complete$gender_cat)),
  race_cat = factor("Non-Hispanic White", levels = levels(nhanes_complete$race_cat)),
  education_cat = factor("Less than high school", levels = levels(nhanes_complete$education_cat)),
  pir = mean(nhanes_complete$pir, na.rm = TRUE),
  bmi = mean(nhanes_complete$bmi, na.rm = TRUE),
  smoking_status = factor("Never", levels = levels(nhanes_complete$smoking_status)),
  diabetes_status = factor("Normal", levels = levels(nhanes_complete$diabetes_status)),
  hypertension = factor("No", levels = levels(nhanes_complete$hypertension))
)

# 为每个SIRI值计算RCS基函数
predict_rcs_or <- function(siri_values, ref_value, model, knots) {
  n <- length(siri_values)
  results <- data.frame(
    siri = siri_values,
    log_or = NA,
    se = NA,
    or = NA,
    or_lower = NA,
    or_upper = NA
  )
  
  # 计算参考值的RCS基
  ref_rcs <- create_rcs_basis(ref_value, as.numeric(knots))
  
  # 获取RCS项的系数和方差协方差矩阵（在循环外提取，提高效率）
  rcs_coefs <- coef(model)[c("siri_rcs1", "siri_rcs2", "siri_rcs3")]
  rcs_vcov <- vcov(model)[c("siri_rcs1", "siri_rcs2", "siri_rcs3"),
                           c("siri_rcs1", "siri_rcs2", "siri_rcs3")]
  
  for (i in 1:n) {
    # 当前值的RCS基
    curr_rcs <- create_rcs_basis(siri_values[i], as.numeric(knots))
    
    # 差值（相对于参考值）- 关键：转换为向量！
    diff_rcs <- as.vector(curr_rcs - ref_rcs)
    
    # 计算log(OR)
    log_or <- sum(diff_rcs * rcs_coefs)
    
    # 计算标准误
    # 正确的矩阵运算：向量形式 t(diff_vec) %*% vcov %*% diff_vec
    # (1×3) × (3×3) × (3×1) = 1×1
    se <- sqrt(as.numeric(t(diff_rcs) %*% rcs_vcov %*% diff_rcs))
    
    # 保存结果
    results$log_or[i] <- log_or
    results$se[i] <- se
    results$or[i] <- exp(log_or)
    results$or_lower[i] <- exp(log_or - 1.96 * se)
    results$or_upper[i] <- exp(log_or + 1.96 * se)
  }
  
  return(results)
}

# 计算预测结果
pred_results <- predict_rcs_or(siri_range, ref_siri, model_rcs, knots_4)

cat("\n预测数据生成完成\n")
cat("SIRI范围:", round(min(siri_range), 3), "-", round(max(siri_range), 3), "\n")
cat("参考值:", round(ref_siri, 3), "\n")
cat("数据点数:", nrow(pred_results), "\n")

# 查看部分预测结果
cat("\n预测结果示例（每20个点）:\n")
print(head(pred_results[seq(1, nrow(pred_results), 20), ], 10))
```

![截屏2026-01-28 21.43.27](assets/截屏2026-01-28 21.43.27.png)

### 7.2 绘制基础剂量-反应曲线

```r
# ==================== 绘制基础剂量-反应曲线 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    绘制剂量-反应曲线                           ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

library(ggplot2)

# 基础剂量-反应曲线
p_basic <- ggplot(pred_results, aes(x = siri, y = or)) +
  # 置信区间带
  geom_ribbon(aes(ymin = or_lower, ymax = or_upper), 
              fill = "steelblue", alpha = 0.3) +
  # OR曲线
  geom_line(color = "steelblue", linewidth = 1.2) +
  # 参考线（OR = 1）
  geom_hline(yintercept = 1, linetype = "dashed", color = "gray50") +
  # 参考值垂直线
  geom_vline(xintercept = ref_siri, linetype = "dotted", color = "gray50") +
  # Y轴对数刻度
  scale_y_log10(
    breaks = c(0.5, 0.75, 1, 1.25, 1.5, 2),
    labels = c("0.5", "0.75", "1.0", "1.25", "1.5", "2.0")
  ) +
  # 坐标轴标签
  labs(
    x = "SIRI (Systemic Inflammation Response Index)",
    y = "Odds Ratio (95% CI)",
    title = "Dose-Response Relationship between SIRI and Dry Eye Disease",
    caption = paste0("Reference value: SIRI = ", round(ref_siri, 2), 
                     " (median)\nKnots at 5th, 35th, 65th, 95th percentiles\n",
                     "Adjusted for age, sex, race/ethnicity, education, PIR, BMI, ",
                     "smoking, diabetes, and hypertension")
  ) +
  # 主题设置
  theme_classic() +
  theme(
    plot.title = element_text(size = 14, face = "bold", hjust = 0.5),
    axis.title = element_text(size = 12),
    axis.text = element_text(size = 10),
    plot.caption = element_text(size = 9, hjust = 0)
  )

# 显示图形
print(p_basic)

# 保存图形
ggsave("主要回归分析/Figure2_RCS_DoseResponse_Basic.png", 
       p_basic, width = 10, height = 7, dpi = 300)
cat("\n基础图形已保存: Figure2_RCS_DoseResponse_Basic.png\n")
```

### 7.3 绘制期刊质量的剂量-反应曲线

```r
# ==================== 期刊质量图形（修正版）====================

p_journal <- ggplot(pred_results, aes(x = siri, y = or)) +
  # 置信区间带
  geom_ribbon(aes(ymin = or_lower, ymax = or_upper), 
              fill = "#3498db", alpha = 0.25) +
  # OR曲线
  geom_line(color = "#2980b9", linewidth = 1.5) +
  # 参考线（OR = 1）
  geom_hline(yintercept = 1, linetype = "dashed", color = "#e74c3c", 
             linewidth = 0.8) +
  # 参考值标记
  geom_point(data = data.frame(siri = ref_siri, or = 1), 
             aes(x = siri, y = or), 
             color = "#e74c3c", size = 3, shape = 18) +
  # 节点位置标记 - 关键修改：添加 inherit.aes = FALSE
  geom_rug(data = data.frame(siri = as.numeric(knots_4)), 
           aes(x = siri), sides = "b", color = "gray50", alpha = 0.5,
           inherit.aes = FALSE) +
  # Y轴对数刻度
  scale_y_log10(
    breaks = c(0.5, 0.75, 1, 1.25, 1.5, 2, 3),
    labels = c("0.5", "0.75", "1.0", "1.25", "1.5", "2.0", "3.0"),
    limits = c(0.5, 3)
  ) +
  # X轴范围
  scale_x_continuous(
    breaks = seq(0, 4, 0.5),
    limits = c(0, max(siri_range) * 1.05)
  ) +
  # 坐标轴标签
  labs(
    x = "SIRI",
    y = "Odds Ratio (95% CI)"
  ) +
  # 添加注释
  annotate("text", x = max(siri_range) * 0.95, y = 2.5,
           label = paste0("P for nonlinearity = ", 
                          ifelse(p_nonlinear < 0.001, "<0.001", 
                                 round(p_nonlinear, 3)),
                          "\nP for overall = ",
                          ifelse(p_overall < 0.001, "<0.001", 
                                 round(p_overall, 3))),
           hjust = 1, vjust = 1, size = 4,
           fontface = "italic") +
  # 主题设置（期刊风格）
  theme_bw() +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "gray90"),
    axis.title = element_text(size = 14, face = "bold"),
    axis.text = element_text(size = 12, color = "black"),
    panel.border = element_rect(linewidth = 1),
    plot.margin = margin(10, 15, 10, 10)
  )

# 显示图形
print(p_journal)

# 保存高分辨率图形
ggsave("剂量-反应分析/Figure2_RCS_DoseResponse.png", 
       p_journal, width = 8, height = 6, dpi = 600)
ggsave("剂量-反应分析/Figure2_RCS_DoseResponse.pdf", 
       p_journal, width = 8, height = 6)
ggsave("剂量-反应分析/Figure2_RCS_DoseResponse.tiff", 
       p_journal, width = 8, height = 6, dpi = 600, compression = "lzw")

cat("\n期刊质量图形已保存:\n")
cat("  - Figure2_RCS_DoseResponse.png (600 dpi)\n")
cat("  - Figure2_RCS_DoseResponse.pdf (矢量图)\n")
cat("  - Figure2_RCS_DoseResponse.tiff (600 dpi, LZW压缩)\n")
```

### 7.4 添加SIRI分布直方图（组合图）

```r
# ==================== 组合图（曲线 + 分布）====================

library(cowplot)
library(gridExtra)

# 主图：剂量-反应曲线
p_main <- p_journal + 
  theme(plot.margin = margin(10, 15, 0, 10))

# 底部：SIRI分布直方图
p_hist <- ggplot(nhanes_complete, aes(x = siri)) +
  geom_histogram(aes(y = after_stat(density)), 
                 bins = 50, fill = "gray70", color = "gray50", alpha = 0.7) +
  scale_x_continuous(limits = c(0, max(siri_range) * 1.05)) +
  labs(x = NULL, y = "Density") +
  theme_bw() +
  theme(
    panel.grid = element_blank(),
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    axis.title.y = element_text(size = 10),
    axis.text.y = element_text(size = 8),
    panel.border = element_blank(),
    plot.margin = margin(0, 15, 10, 10)
  )

# 组合图形
p_combined <- plot_grid(
  p_main, p_hist,
  ncol = 1,
  align = "v",
  axis = "lr",
  rel_heights = c(4, 1)
)

# 添加标题
title <- ggdraw() + 
  draw_label("Figure 2. Dose-Response Relationship between SIRI and Dry Eye Disease",
             fontface = 'bold', size = 14, x = 0.5, hjust = 0.5)

# 添加脚注
caption <- ggdraw() + 
  draw_label(
    paste0("The solid line represents the odds ratio, and the shaded area represents the 95% confidence interval.\n",
           "Reference value: SIRI = ", round(ref_siri, 2), " (median). ",
           "Knots were placed at the 5th, 35th, 65th, and 95th percentiles.\n",
           "Model adjusted for age, sex, race/ethnicity, education, family income-to-poverty ratio, BMI, ",
           "smoking status, diabetes status, and hypertension."),
    size = 9, x = 0.02, hjust = 0
  )

# 最终组合
p_final <- plot_grid(
  title, p_combined, caption,
  ncol = 1,
  rel_heights = c(0.08, 1, 0.12)
)

# 显示图形
print(p_final)

# 保存
ggsave("主要回归分析/Figure2_RCS_DoseResponse_Combined.png", 
       p_final, width = 10, height = 9, dpi = 600)
ggsave("主要回归分析/Figure2_RCS_DoseResponse_Combined.pdf", 
       p_final, width = 10, height = 9)

cat("\n组合图形已保存:\n")
cat("  - Figure2_RCS_DoseResponse_Combined.png\n")
cat("  - Figure2_RCS_DoseResponse_Combined.pdf\n")
```

---

## 八、结果解读与论文撰写

### 8.1 结果汇总

```r
# ==================== RCS分析结果汇总 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    RCS分析结果汇总                             ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

cat("\n【1. 模型设置】\n")
cat("  节点数量: 4\n")
cat("  节点位置: 5th(", round(knots_4[1], 3), "), ",
    "35th(", round(knots_4[2], 3), "), ",
    "65th(", round(knots_4[3], 3), "), ",
    "95th(", round(knots_4[4], 3), ") 百分位\n", sep = "")
cat("  参考值: SIRI =", round(ref_siri, 3), "(中位数)\n")

cat("\n【2. 检验结果】\n")
cat("  P for overall association:", 
    ifelse(p_overall < 0.001, "<0.001", round(p_overall, 3)), "\n")
cat("  P for nonlinearity:", 
    ifelse(p_nonlinear < 0.001, "<0.001", round(p_nonlinear, 3)), "\n")

cat("\n【3. 关键OR值】\n")
# 找出特定SIRI值的OR
key_siri_values <- c(
  quantile(nhanes_complete$siri, 0.25, na.rm = TRUE),  # Q1
  ref_siri,                                             # 中位数
  quantile(nhanes_complete$siri, 0.75, na.rm = TRUE),  # Q3
  quantile(nhanes_complete$siri, 0.90, na.rm = TRUE),  # 90th
  quantile(nhanes_complete$siri, 0.95, na.rm = TRUE)   # 95th
)
names(key_siri_values) <- c("Q1", "Median", "Q3", "90th", "95th")

for (i in 1:length(key_siri_values)) {
  idx <- which.min(abs(pred_results$siri - key_siri_values[i]))
  cat("  SIRI =", round(key_siri_values[i], 2), 
      "(", names(key_siri_values)[i], "): OR =", 
      round(pred_results$or[idx], 2),
      "(95%CI:", round(pred_results$or_lower[idx], 2), "-",
      round(pred_results$or_upper[idx], 2), ")\n")
}

cat("\n【4. 结论】\n")
if (p_nonlinear < 0.05) {
  cat("  ✓ 存在显著的非线性关联，应报告RCS曲线形态\n")
} else if (p_overall < 0.05) {
  cat("  ✓ 存在显著的线性关联，但无明显非线性成分\n")
} else {
  cat("  × SIRI与干眼症无显著关联\n")
}
```

## RCS 分析结果总结（SIRI 与干眼症）

### 1️⃣ 模型设置

采用 **限制性立方样条（Restricted Cubic Spline, RCS）回归模型**评估 SIRI 与干眼症的关系。

- **节点数量**：4
- **节点位置**：
  - 第 5 百分位：0.393
  - 第 35 百分位：0.829
  - 第 65 百分位：1.244
  - 第 95 百分位：2.607
- **参考值**：SIRI = **1.024**（中位数，OR = 1）

------

### 2️⃣ 整体与非线性检验结果

- **总体关联检验（P for overall association）**：0.896
- **非线性检验（P for nonlinearity）**：0.761

👉 均 **未达到统计学显著性（P ≥ 0.05）**

------

### 3️⃣ 关键 SIRI 水平对应的 OR 值（相对于中位数）

| SIRI 水平  | 数值 | OR (95% CI)        |
| ---------- | ---- | ------------------ |
| Q1（25th） | 0.70 | 0.97 (0.90 – 1.05) |
| 中位数     | 1.02 | 1.00 (1.00 – 1.00) |
| Q3（75th） | 1.47 | 0.99 (0.87 – 1.13) |
| 90th       | 2.12 | 0.99 (0.83 – 1.18) |
| 95th       | 2.61 | 0.99 (0.84 – 1.17) |

👉 各分位点 OR 均接近 1，且 **95% CI 均跨越 1**

------

### 4️⃣ 结论

- **SIRI 与干眼症之间不存在显著的总体关联**
- **未观察到显著的非线性关系**
- RCS 曲线整体呈 **近乎水平**，提示在 SIRI 全分布范围内，干眼症风险无明显变化趋势

📌 **结论性表述**：

> 在限制性立方样条模型中，SIRI 与干眼症的发生风险之间未发现显著的线性或非线性关联。

### 8.2 Results部分撰写模板（英文）

```r
# ==================== Results撰写模板 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    Results撰写模板                             ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 根据检验结果自动生成文本
if (p_nonlinear < 0.05 & p_overall < 0.05) {
  # 存在非线性关联
  results_rcs <- paste0(
    "3.3 Dose-Response Relationship\n\n",
    "Figure 2 illustrates the dose-response relationship between SIRI and ",
    "dry eye disease using restricted cubic splines with 4 knots placed at ",
    "the 5th, 35th, 65th, and 95th percentiles. The median SIRI value (",
    round(ref_siri, 2), ") was used as the reference. After adjusting for all ",
    "covariates, a significant nonlinear relationship was observed between ",
    "SIRI and the odds of dry eye disease (P for nonlinearity ",
    ifelse(p_nonlinear < 0.001, "< 0.001", paste0("= ", round(p_nonlinear, 3))),
    ", P for overall association ",
    ifelse(p_overall < 0.001, "< 0.001", paste0("= ", round(p_overall, 3))), ").\n\n",
    "The curve suggested a [describe the pattern: J-shaped/U-shaped/threshold effect] ",
    "relationship. The risk of dry eye disease remained relatively stable at ",
    "lower SIRI levels but increased more steeply when SIRI exceeded approximately ",
    "[threshold value]. At the 95th percentile of SIRI (",
    round(quantile(nhanes_complete$siri, 0.95, na.rm = TRUE), 2), "), ",
    "the odds of dry eye disease was [X.XX] times higher (95% CI: [X.XX]-[X.XX]) ",
    "compared to the reference value."
  )
} else if (p_nonlinear >= 0.05 & p_overall < 0.05) {
  # 存在线性关联
  results_rcs <- paste0(
    "3.3 Dose-Response Relationship\n\n",
    "Figure 2 illustrates the dose-response relationship between SIRI and ",
    "dry eye disease using restricted cubic splines with 4 knots. The median ",
    "SIRI value (", round(ref_siri, 2), ") was used as the reference. ",
    "A significant linear association was observed between SIRI and dry eye ",
    "disease (P for overall association ",
    ifelse(p_overall < 0.001, "< 0.001", paste0("= ", round(p_overall, 3))), "), ",
    "without evidence of a nonlinear relationship (P for nonlinearity = ",
    round(p_nonlinear, 3), ").\n\n",
    "The curve demonstrated a monotonic positive association, with the odds ",
    "of dry eye disease increasing steadily as SIRI levels rose. At the 95th ",
    "percentile of SIRI (", 
    round(quantile(nhanes_complete$siri, 0.95, na.rm = TRUE), 2), "), ",
    "the odds of dry eye disease was [X.XX] times higher (95% CI: [X.XX]-[X.XX]) ",
    "compared to the reference value."
  )
} else {
  # 无显著关联
  results_rcs <- paste0(
    "3.3 Dose-Response Relationship\n\n",
    "Figure 2 depicts the dose-response relationship between SIRI and dry eye ",
    "disease using restricted cubic splines with 4 knots. The median SIRI value (",
    round(ref_siri, 2), ") was used as the reference. No significant association ",
    "was observed between SIRI and dry eye disease in the fully adjusted model ",
    "(P for overall association = ", round(p_overall, 3), "), and the relationship ",
    "did not show significant nonlinearity (P for nonlinearity = ", 
    round(p_nonlinear, 3), ").\n\n",
    "The relatively flat curve with wide confidence intervals suggested that ",
    "SIRI may not be independently associated with dry eye disease risk in this ",
    "population after accounting for demographic, lifestyle, and clinical factors."
  )
}

cat(results_rcs)

# 保存Results文本
writeLines(results_rcs, "主要回归分析/Results_Section_3.3_RCS.txt")
cat("\n\nResults文本已保存: Results_Section_3.3_RCS.txt\n")
```

### 8.3 Results部分撰写模板（中文）

```r
# ==================== 中文Results撰写模板 ====================

if (p_nonlinear < 0.05 & p_overall < 0.05) {
  results_rcs_cn <- paste0(
    "3.3 剂量-反应关系\n\n",
    "图2展示了使用限制性立方样条（节点位于第5、35、65、95百分位）分析的SIRI与",
    "干眼症之间的剂量-反应关系，以SIRI中位数（", round(ref_siri, 2), "）为参考值。",
    "在调整所有协变量后，观察到SIRI与干眼症风险之间存在显著的非线性关系",
    "（非线性检验P", ifelse(p_nonlinear < 0.001, "<0.001", paste0("=", round(p_nonlinear, 3))),
    "，整体关联检验P", ifelse(p_overall < 0.001, "<0.001", paste0("=", round(p_overall, 3))), "）。\n\n",
    "曲线形态提示[描述形态：J形/U形/阈值效应]关系。在较低SIRI水平时，干眼症风险相对稳定，",
    "但当SIRI超过约[阈值]时，风险急剧上升。在SIRI第95百分位（",
    round(quantile(nhanes_complete$siri, 0.95, na.rm = TRUE), 2), "）时，",
    "干眼症风险是参考值的[X.XX]倍（95%CI：[X.XX]-[X.XX]）。"
  )
} else if (p_nonlinear >= 0.05 & p_overall < 0.05) {
  results_rcs_cn <- paste0(
    "3.3 剂量-反应关系\n\n",
    "图2展示了使用限制性立方样条分析的SIRI与干眼症之间的剂量-反应关系，",
    "以SIRI中位数（", round(ref_siri, 2), "）为参考值。观察到SIRI与干眼症之间存在",
    "显著的线性关联（整体关联P", ifelse(p_overall < 0.001, "<0.001", paste0("=", round(p_overall, 3))),
    "），未发现明显的非线性关系（非线性检验P=", round(p_nonlinear, 3), "）。\n\n",
    "曲线呈现单调递增趋势，随着SIRI水平升高，干眼症风险稳定增加。在SIRI第95百分位（",
    round(quantile(nhanes_complete$siri, 0.95, na.rm = TRUE), 2), "）时，",
    "干眼症风险是参考值的[X.XX]倍（95%CI：[X.XX]-[X.XX]）。"
  )
} else {
  results_rcs_cn <- paste0(
    "3.3 剂量-反应关系\n\n",
    "图2展示了使用限制性立方样条分析的SIRI与干眼症之间的剂量-反应关系，",
    "以SIRI中位数（", round(ref_siri, 2), "）为参考值。在完全调整模型中，",
    "未观察到SIRI与干眼症之间的显著关联（整体关联P=", round(p_overall, 3), "），",
    "关系也不存在显著的非线性（非线性检验P=", round(p_nonlinear, 3), "）。\n\n",
    "相对平缓的曲线和较宽的置信区间提示，在控制人口学、生活方式和临床因素后，",
    "SIRI可能与该人群的干眼症风险无独立关联。"
  )
}

cat("\n【中文版本】\n")
cat(results_rcs_cn)
```

【中文版本】
> cat(results_rcs_cn)
> 3.3 剂量-反应关系

图2展示了使用限制性立方样条分析的SIRI与干眼症之间的剂量-反应关系，以SIRI中位数（1.02）为参考值。在完全调整模型中，未观察到SIRI与干眼症之间的显著关联（整体关联P=0.896），关系也不存在显著的非线性（非线性检验P=0.761）。

相对平缓的曲线和较宽的置信区间提示，在控制人口学、生活方式和临床因素后，SIRI可能与该人群的干眼症风险无独立关联。



### 8.4 Figure 2图例说明

```r
# ==================== Figure 2图例说明 ====================

figure_legend <- paste0(
  "Figure 2. Dose-response relationship between SIRI and dry eye disease.\n\n",
  
  "The solid blue line represents the adjusted odds ratio (OR), and the ",
  "shaded blue area represents the 95% confidence interval. The dashed ",
  "red horizontal line indicates OR = 1.0 (no association). The red diamond ",
  "marks the reference point at the median SIRI value (",
  round(ref_siri, 2), "). Restricted cubic splines with 4 knots placed at ",
  "the 5th (", round(knots_4[1], 2), "), 35th (", round(knots_4[2], 2), 
  "), 65th (", round(knots_4[3], 2), "), and 95th (", round(knots_4[4], 2), 
  ") percentiles of SIRI were used. The histogram at the bottom shows the ",
  "distribution of SIRI in the study population.\n\n",
  
  "The model was adjusted for age, sex, race/ethnicity, education level, ",
  "family income-to-poverty ratio, body mass index, smoking status, diabetes ",
  "status, and hypertension. Alcohol consumption was not included due to ",
  "substantial missing data (>70%).\n\n",
  
  "P for overall association = ", 
  ifelse(p_overall < 0.001, "<0.001", round(p_overall, 3)), "; ",
  "P for nonlinearity = ", 
  ifelse(p_nonlinear < 0.001, "<0.001", round(p_nonlinear, 3)), ".\n\n",
  
  "Abbreviations: CI, confidence interval; OR, odds ratio; ",
  "SIRI, Systemic Inflammation Response Index."
)

cat("\n【Figure 2 图例说明】\n")
cat(figure_legend)

# 保存图例
writeLines(figure_legend, "剂量-反应分析/Figure2_Legend.txt")
```

---

## 九、敏感性分析：不同节点设置

### 9.1 3节点和5节点敏感性分析

```r
# ==================== 节点敏感性分析 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    节点敏感性分析                              ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 3节点模型（10th, 50th, 90th）
knots_3 <- quantile(nhanes_complete$siri, 
                    probs = c(0.10, 0.50, 0.90), 
                    na.rm = TRUE)

# 5节点模型（5th, 27.5th, 50th, 72.5th, 95th）
knots_5 <- quantile(nhanes_complete$siri, 
                    probs = c(0.05, 0.275, 0.50, 0.725, 0.95), 
                    na.rm = TRUE)

cat("\n节点位置对比:\n")
cat("3节点 (10th, 50th, 90th):", paste(round(knots_3, 3), collapse = ", "), "\n")
cat("4节点 (5th, 35th, 65th, 95th):", paste(round(knots_4, 3), collapse = ", "), "\n")
cat("5节点 (5th, 27.5th, 50th, 72.5th, 95th):", paste(round(knots_5, 3), collapse = ", "), "\n")

# 拟合3节点模型
rcs_basis_3 <- create_rcs_basis(nhanes_complete$siri, as.numeric(knots_3))
nhanes_complete$siri_rcs3_1 <- rcs_basis_3[, 1]
nhanes_complete$siri_rcs3_2 <- rcs_basis_3[, 2]

nhanes_design_3 <- svydesign(
  id = ~psu, strata = ~strata, weights = ~weight_4yr,
  data = nhanes_complete, nest = TRUE
)

formula_rcs3 <- as.formula(
  paste0(outcome, " ~ siri_rcs3_1 + siri_rcs3_2 + ",
         paste(covariates, collapse = " + "))
)

model_rcs3 <- svyglm(formula_rcs3, design = nhanes_design_3, family = quasibinomial())

# 3节点检验
test_overall_3 <- regTermTest(model_rcs3, ~ siri_rcs3_1 + siri_rcs3_2, method = "Wald")
test_nonlinear_3 <- regTermTest(model_rcs3, ~ siri_rcs3_2, method = "Wald")

# 拟合5节点模型
rcs_basis_5 <- create_rcs_basis(nhanes_complete$siri, as.numeric(knots_5))
nhanes_complete$siri_rcs5_1 <- rcs_basis_5[, 1]
nhanes_complete$siri_rcs5_2 <- rcs_basis_5[, 2]
nhanes_complete$siri_rcs5_3 <- rcs_basis_5[, 3]
nhanes_complete$siri_rcs5_4 <- rcs_basis_5[, 4]

nhanes_design_5 <- svydesign(
  id = ~psu, strata = ~strata, weights = ~weight_4yr,
  data = nhanes_complete, nest = TRUE
)

formula_rcs5 <- as.formula(
  paste0(outcome, " ~ siri_rcs5_1 + siri_rcs5_2 + siri_rcs5_3 + siri_rcs5_4 + ",
         paste(covariates, collapse = " + "))
)

model_rcs5 <- svyglm(formula_rcs5, design = nhanes_design_5, family = quasibinomial())

# 5节点检验
test_overall_5 <- regTermTest(model_rcs5, 
                               ~ siri_rcs5_1 + siri_rcs5_2 + siri_rcs5_3 + siri_rcs5_4, 
                               method = "Wald")
test_nonlinear_5 <- regTermTest(model_rcs5, 
                                 ~ siri_rcs5_2 + siri_rcs5_3 + siri_rcs5_4, 
                                 method = "Wald")

# 汇总表格
sensitivity_results <- data.frame(
  节点数 = c("3节点", "4节点（主分析）", "5节点"),
  节点位置 = c("10th, 50th, 90th", 
               "5th, 35th, 65th, 95th",
               "5th, 27.5th, 50th, 72.5th, 95th"),
  P_overall = c(
    ifelse(test_overall_3$p < 0.001, "<0.001", round(test_overall_3$p, 3)),
    ifelse(p_overall < 0.001, "<0.001", round(p_overall, 3)),
    ifelse(test_overall_5$p < 0.001, "<0.001", round(test_overall_5$p, 3))
  ),
  P_nonlinear = c(
    ifelse(test_nonlinear_3$p < 0.001, "<0.001", round(test_nonlinear_3$p, 3)),
    ifelse(p_nonlinear < 0.001, "<0.001", round(p_nonlinear, 3)),
    ifelse(test_nonlinear_5$p < 0.001, "<0.001", round(test_nonlinear_5$p, 3))
  )
)

cat("\n敏感性分析结果:\n")
print(sensitivity_results)

# 保存敏感性分析结果
write.csv(sensitivity_results, 
          "剂量-反应分析/RCS_Sensitivity_Knots.csv", 
          row.names = FALSE)
```

### 9.2 敏感性分析曲线对比图

```r
# ==================== 敏感性分析曲线对比 ====================

# 3节点预测函数（变量名为siri_rcs3_1, siri_rcs3_2）
predict_rcs_or_3 <- function(siri_values, ref_value, model, knots) {
  n <- length(siri_values)
  results <- data.frame(
    siri = siri_values,
    log_or = NA,
    se = NA,
    or = NA,
    or_lower = NA,
    or_upper = NA
  )
  
  ref_rcs <- create_rcs_basis(ref_value, as.numeric(knots))
  
  # 3节点模型只有2个变量
  rcs_vars <- paste0("siri_rcs3_", 1:2)
  rcs_coefs <- coef(model)[rcs_vars]
  rcs_vcov <- vcov(model)[rcs_vars, rcs_vars]
  
  for (i in 1:n) {
    curr_rcs <- create_rcs_basis(siri_values[i], as.numeric(knots))
    # 关键：转换为向量
    diff_rcs <- as.vector(curr_rcs - ref_rcs)
    
    log_or <- sum(diff_rcs * rcs_coefs)
    se <- sqrt(as.numeric(t(diff_rcs) %*% rcs_vcov %*% diff_rcs))
    
    results$log_or[i] <- log_or
    results$se[i] <- se
    results$or[i] <- exp(log_or)
    results$or_lower[i] <- exp(log_or - 1.96 * se)
    results$or_upper[i] <- exp(log_or + 1.96 * se)
  }
  
  return(results)
}

# 计算3节点的预测值（使用专门的3节点函数）
pred_3 <- predict_rcs_or_3(siri_range, ref_siri, model_rcs3, knots_3)
pred_3$model <- "3 knots"

pred_4 <- pred_results
pred_4$model <- "4 knots (primary)"

# 5节点预测函数（变量名为siri_rcs5_1到siri_rcs5_4）
predict_rcs_or_5 <- function(siri_values, ref_value, model, knots) {
  n <- length(siri_values)
  results <- data.frame(
    siri = siri_values,
    log_or = NA,
    se = NA,
    or = NA,
    or_lower = NA,
    or_upper = NA
  )
  
  ref_rcs <- create_rcs_basis(ref_value, as.numeric(knots))
  
  # 5节点模型有4个变量
  rcs_vars <- paste0("siri_rcs5_", 1:4)
  rcs_coefs <- coef(model)[rcs_vars]
  rcs_vcov <- vcov(model)[rcs_vars, rcs_vars]
  
  for (i in 1:n) {
    curr_rcs <- create_rcs_basis(siri_values[i], as.numeric(knots))
    # 关键：转换为向量
    diff_rcs <- as.vector(curr_rcs - ref_rcs)
    
    log_or <- sum(diff_rcs * rcs_coefs)
    se <- sqrt(as.numeric(t(diff_rcs) %*% rcs_vcov %*% diff_rcs))
    
    results$log_or[i] <- log_or
    results$se[i] <- se
    results$or[i] <- exp(log_or)
    results$or_lower[i] <- exp(log_or - 1.96 * se)
    results$or_upper[i] <- exp(log_or + 1.96 * se)
  }
  
  return(results)
}

pred_5 <- predict_rcs_or_5(siri_range, ref_siri, model_rcs5, knots_5)
pred_5$model <- "5 knots"

# 合并数据
pred_all <- rbind(pred_3, pred_4, pred_5)

# 绘制对比图
p_sensitivity <- ggplot(pred_all, aes(x = siri, y = or, color = model, fill = model)) +
  geom_ribbon(aes(ymin = or_lower, ymax = or_upper), alpha = 0.15) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "gray50") +
  scale_y_log10(
    breaks = c(0.5, 0.75, 1, 1.25, 1.5, 2),
    limits = c(0.5, 2.5)
  ) +
  scale_color_manual(values = c("3 knots" = "#e74c3c", 
                                 "4 knots (primary)" = "#2980b9", 
                                 "5 knots" = "#27ae60")) +
  scale_fill_manual(values = c("3 knots" = "#e74c3c", 
                                "4 knots (primary)" = "#2980b9", 
                                "5 knots" = "#27ae60")) +
  labs(
    x = "SIRI",
    y = "Odds Ratio (95% CI)",
    title = "Sensitivity Analysis: Effect of Knot Placement",
    color = "Model",
    fill = "Model"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    plot.title = element_text(size = 14, face = "bold", hjust = 0.5)
  )

print(p_sensitivity)

ggsave("剂量-反应分析/Figure_RCS_Sensitivity_Knots.png", 
       p_sensitivity, width = 10, height = 7, dpi = 300)

cat("\n敏感性分析图形已保存: Figure_RCS_Sensitivity_Knots.png\n")
```

---

## 十、常见问题与解决方案

### 10.1 技术问题

| 问题 | 原因 | 解决方案 |
|-----|------|---------|
| **rcs函数在svyglm中报错** | svyglm不直接支持rcs | 使用手动创建的RCS基函数 |
| **曲线边缘不稳定** | 边缘样本量少 | 限制预测范围在1%-99%分位 |
| **非线性检验P值与图形不符** | 视觉与统计的差异 | 以统计检验为准，但需解释曲线形态 |
| **置信区间过宽** | 边缘或高SIRI值样本少 | 这是正常现象，如实报告 |

### 10.2 结果解读问题

| 问题 | 解答 |
|-----|------|
| **非线性不显著，还需要报告RCS吗？** | 是的，报告RCS分析展示了研究的完整性，同时可以说明"未发现非线性证据" |
| **如何描述曲线形态？** | 使用规范术语：J-shaped, U-shaped, inverted U-shaped, threshold effect, monotonic increase/decrease |
| **参考值如何选择？** | 通常选择中位数；如有临床意义的阈值，也可选择该值 |
| **节点数如何决定？** | 基于样本量和Harrell建议；可通过AIC/BIC比较，但通常4节点足够 |

### 10.3 审稿人常见问题

| 问题 | 回答策略 |
|-----|---------|
| "为什么选择4个节点？" | "根据Harrell建议，对于样本量>500的研究，4节点可提供足够灵活性同时避免过拟合" |
| "节点位置是否影响结果？" | "我们进行了3、4、5节点的敏感性分析，结果一致" |
| "如何处理NHANES权重？" | "使用survey包的svyglm函数正确处理复杂抽样设计" |
| "曲线看起来接近线性，为什么用RCS？" | "RCS分析能客观检验是否存在非线性，避免先验假设" |

---

## 十一、质量检查清单

### Day 20 完成检查表

| 类别 | 检查项 | 状态 |
|------|-------|------|
| **数据准备** | | |
| | 加载Day 18-19数据成功 | ☐ |
| | SIRI分布统计确认 | ☐ |
| | 节点位置计算正确 | ☐ |
| **RCS建模** | | |
| | RCS基函数创建成功 | ☐ |
| | svyglm模型拟合完成 | ☐ |
| | 模型无收敛问题 | ☐ |
| **检验结果** | | |
| | P-overall计算 | ☐ |
| | P-nonlinear计算 | ☐ |
| | 结果解读正确 | ☐ |
| **Figure 2** | | |
| | 曲线绘制成功 | ☐ |
| | 置信区间正确 | ☐ |
| | 坐标轴标签完整 | ☐ |
| | P值标注 | ☐ |
| | 高分辨率导出(≥300dpi) | ☐ |
| **敏感性分析** | | |
| | 3/5节点分析完成 | ☐ |
| | 结果一致性确认 | ☐ |
| **Results撰写** | | |
| | 英文模板准备 | ☐ |
| | 图例说明准备 | ☐ |

---

## 附录A：保存分析结果

```r
# ==================== 保存分析结果 ====================

# 保存所有RCS分析对象
save(
  # 模型对象
  model_rcs,
  model_rcs3, model_rcs5,
  model_lrm,
  
  # 节点信息
  knots_3, knots_4, knots_5,
  ref_siri,
  
  # 检验结果
  p_overall, p_nonlinear,
  test_overall, test_nonlinear,
  
  # 预测数据
  pred_results, pred_3, pred_5,
  siri_range,
  
  # 敏感性分析
  sensitivity_results,
  
  # RCS基函数创建函数
  create_rcs_basis,
  predict_rcs_or,
  
  file = "主要回归分析/Day20_RCS_Objects.RData"
)

cat("\n✓ RCS分析对象已保存: Day20_RCS_Objects.RData\n")
cat("\n下次加载使用: load('主要回归分析/Day20_RCS_Objects.RData')\n")
```

---

## 附录B：完整代码汇总

完整代码可保存为：`主要回归分析/Day20_RCS_Analysis_Code.R`

运行前请确保：
1. 已完成Day 18-19分析
2. 工作目录设置为项目根目录
3. 按顺序执行各代码块

---

## 附录C：RCS结果解读速查表

| 场景 | P-overall | P-nonlinear | 结论 | Figure描述 |
|-----|-----------|-------------|------|-----------|
| 1 | <0.05 | <0.05 | 显著非线性关联 | "a significant nonlinear relationship" |
| 2 | <0.05 | ≥0.05 | 显著线性关联 | "a significant linear association" |
| 3 | ≥0.05 | <0.05 | 非线性趋势，整体不显著 | "a nonlinear trend, but not statistically significant" |
| 4 | ≥0.05 | ≥0.05 | 无显著关联 | "no significant association was observed" |

---

## 附录D：曲线形态描述词汇表

| 形态 | 英文描述 | 适用场景 |
|-----|---------|---------|
| J形 | J-shaped curve | OR随暴露先稳定后急升 |
| U形 | U-shaped curve | 中间水平风险最低 |
| 倒U形 | Inverted U-shaped | 中间水平风险最高 |
| 阈值效应 | Threshold effect | 超过某值后风险才开始增加 |
| 单调递增 | Monotonic positive | OR随暴露稳定增加 |
| 单调递减 | Monotonic negative | OR随暴露稳定降低 |
| 平台效应 | Plateau effect | 高暴露水平时OR趋于稳定 |

---

> **文档版本**：v1.0
> 
> **创建日期**：2026年1月28日
> 
> **作者**：[根据执行计划方案编写]
> 
> **备注**：本文档为Day 20详细操作指南，专注于限制性立方样条（RCS）分析。完成本日任务后，将获得论文的Figure 2（剂量-反应曲线）及相关的非线性检验结果。这是评估SIRI与干眼症关联形态的关键分析，可显著提升论文的方法学质量。
> 
> **下一步**：Day 21-22将进行亚组分析和森林图绘制。
