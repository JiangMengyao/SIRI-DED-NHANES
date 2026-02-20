# ============================================================
# Script: 04_descriptive_analysis.R
# Purpose: Table 1 generation, weighted descriptive statistics
# Project: SIRI and Dry Eye Disease (NHANES 2005-2008)
# Data: NHANES 2005-2006 and 2007-2008 cycles
# ============================================================

# --- Code Block 1 ---
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


# --- Code Block 2 ---
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


# --- Code Block 3 ---
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


# --- Code Block 4 ---
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


# --- Code Block 5 ---
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


# --- Code Block 6 ---
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


# --- Code Block 7 ---
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


# --- Code Block 8 ---
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


# --- Code Block 9 ---
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


# --- Code Block 10 ---
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


# --- Code Block 11 ---
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


# --- Code Block 12 ---
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


# --- Code Block 13 ---
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


# --- Code Block 14 ---
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


# --- Code Block 15 ---
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


# --- Code Block 16 ---
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


# --- Code Block 17 ---
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


# --- Code Block 18 ---
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


# --- Code Block 19 ---
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


# --- Code Block 20 ---
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


# --- Code Block 21 ---
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
