# ============================================================
# Script: 05_main_regression.R
# Purpose: Table 2: Survey-weighted logistic regression (Models 1-3), trend tests
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
  "dplyr",        # 数据处理
  "broom",        # 模型结果整理
  "gtsummary",    # 专业表格生成
  "flextable",    # 表格导出Word
  "ggplot2",      # 可视化
  "car",          # 多重共线性检验
  "tidyr",        # 数据整理
  "knitr",        # 表格展示
  "kableExtra"    # 表格美化
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

# 方法1：加载Day 16-17保存的关键对象（推荐）
load("描述性分析/Day16-17_Key_Objects.RData")

# 或方法2：分别加载数据文件
# nhanes_data <- readRDS("分析数据集/nhanes_analysis_weighted.rds")
# nhanes_design <- readRDS("分析数据集/nhanes_survey_design.rds")

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
# ==================== 协变量完整性检查 ====================

# 定义所有协变量
covariates_model2 <- c("age", "gender_cat", "race_cat", "education_cat", "pir")

# 注意：不包含drinking_status（因缺失率>70%）
covariates_model3 <- c(covariates_model2, "bmi", "smoking_status", 
                       "diabetes_status", "hypertension")

cat("\n==================== 协变量缺失情况 ====================\n")

# 检查每个变量的缺失率
missing_summary <- data.frame(
  Variable = character(),
  N_Total = integer(),
  N_Missing = integer(),
  Pct_Missing = numeric(),
  stringsAsFactors = FALSE
)

for (var in c("siri_quartile", "dry_eye_a", covariates_model3)) {
  if (var %in% names(nhanes_data)) {
    n_total <- nrow(nhanes_data)
    n_missing <- sum(is.na(nhanes_data[[var]]))
    pct_missing <- round(n_missing / n_total * 100, 2)
    
    missing_summary <- rbind(missing_summary, data.frame(
      Variable = var,
      N_Total = n_total,
      N_Missing = n_missing,
      Pct_Missing = pct_missing
    ))
  }
}

print(missing_summary)

# 创建完整案例标记
nhanes_data$complete_model3 <- complete.cases(
  nhanes_data[, c("siri_quartile", "dry_eye_a", covariates_model3)]
)

cat("\n完整案例数（Model 3）:", sum(nhanes_data$complete_model3), "\n")
cat("完整案例占比:", round(sum(nhanes_data$complete_model3)/nrow(nhanes_data)*100, 1), "%\n")


# --- Code Block 4 ---
# ==================== 创建分析数据子集 ====================

# 仅保留完整案例用于回归分析
nhanes_complete <- nhanes_data %>%
  filter(complete_model3 == TRUE)

cat("\n分析样本量:", nrow(nhanes_complete), "\n")

# 重新创建survey design（基于完整案例）
options(survey.lonely.psu = "adjust")

nhanes_design_complete <- svydesign(
  id = ~psu,
  strata = ~strata,
  weights = ~weight_4yr,
  data = nhanes_complete,
  nest = TRUE
)

cat("\nSurvey design（完整案例）已创建\n")

# 验证各组样本量
cat("\n各SIRI组样本量（完整案例）:\n")
print(table(nhanes_complete$siri_quartile))


# --- Code Block 5 ---
# ==================== 设置因子变量参考类别 ====================

# SIRI四分位组：Q1为参考
nhanes_complete$siri_quartile <- relevel(
  factor(nhanes_complete$siri_quartile), 
  ref = "Q1"
)

# 性别：男性为参考
nhanes_complete$gender_cat <- relevel(
  factor(nhanes_complete$gender_cat), 
  ref = "Male"
)

# 种族：非西班牙裔白人为参考
nhanes_complete$race_cat <- relevel(
  factor(nhanes_complete$race_cat), 
  ref = "Non-Hispanic White"
)

# 教育：高中以下为参考
nhanes_complete$education_cat <- relevel(
  factor(nhanes_complete$education_cat), 
  ref = "Less than high school"
)

# BMI分类：正常为参考
nhanes_complete$bmi_cat3 <- relevel(
  factor(nhanes_complete$bmi_cat3), 
  ref = "Normal (<25)"
)

# 吸烟：从不为参考
nhanes_complete$smoking_status <- relevel(
  factor(nhanes_complete$smoking_status), 
  ref = "Never"
)

# 注意：饮酒变量（drinking_status）因缺失率>70%未纳入模型

# 糖尿病：正常为参考
nhanes_complete$diabetes_status <- relevel(
  factor(nhanes_complete$diabetes_status), 
  ref = "Normal"
)

# 高血压：无为参考（确保是因子）
nhanes_complete$hypertension <- factor(
  nhanes_complete$hypertension,
  levels = c(0, 1),
  labels = c("No", "Yes")
)

cat("参考类别设置完成\n")

# 更新survey design
nhanes_design_complete <- svydesign(
  id = ~psu,
  strata = ~strata,
  weights = ~weight_4yr,
  data = nhanes_complete,
  nest = TRUE
)


# --- Code Block 6 ---
# ==================== 定义模型公式 ====================

# 结局变量
outcome <- "dry_eye_a"

# 暴露变量
exposure <- "siri_quartile"

# Model 1: 粗模型（仅暴露变量）
formula_model1 <- as.formula(paste(outcome, "~", exposure))

# Model 2: 调整人口学变量
covars_model2 <- "age + gender_cat + race_cat + education_cat + pir"
formula_model2 <- as.formula(paste(outcome, "~", exposure, "+", covars_model2))

# Model 3: 调整所有协变量（不含饮酒变量，因缺失率>70%）
covars_model3 <- paste(covars_model2, 
                       "+ bmi + smoking_status + diabetes_status + hypertension")
formula_model3 <- as.formula(paste(outcome, "~", exposure, "+", covars_model3))

# 打印模型公式确认
cat("\n==================== 模型公式 ====================\n")
cat("\nModel 1 (粗模型):\n")
print(formula_model1)
cat("\nModel 2 (调整人口学变量):\n")
print(formula_model2)
cat("\nModel 3 (完全调整，不含饮酒):\n")
print(formula_model3)


# --- Code Block 7 ---
# ==================== 运行三个Logistic回归模型 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    主要Logistic回归分析                        ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# Model 1: 粗模型
cat("\n【Model 1: 粗模型】\n")
model1 <- svyglm(formula_model1, 
                  design = nhanes_design_complete, 
                  family = quasibinomial())
cat("Model 1 运行完成\n")

# Model 2: 调整人口学变量
cat("\n【Model 2: 调整人口学变量】\n")
model2 <- svyglm(formula_model2, 
                  design = nhanes_design_complete, 
                  family = quasibinomial())
cat("Model 2 运行完成\n")

# Model 3: 完全调整模型
cat("\n【Model 3: 完全调整模型】\n")
model3 <- svyglm(formula_model3, 
                  design = nhanes_design_complete, 
                  family = quasibinomial())
cat("Model 3 运行完成\n")

cat("\n所有模型运行完成！\n")


# --- Code Block 8 ---
# ==================== 提取OR值和95%置信区间 ====================

# 创建函数提取OR和CI
extract_or <- function(model, model_name) {
  # 获取系数和置信区间
  coef_summary <- summary(model)$coefficients
  conf_int <- confint(model)
  
  # 提取SIRI相关系数（Q2, Q3, Q4 vs Q1）
  siri_rows <- grep("siri_quartile", rownames(coef_summary))
  
  results <- data.frame(
    Model = model_name,
    SIRI_Group = gsub("siri_quartile", "", rownames(coef_summary)[siri_rows]),
    Beta = coef_summary[siri_rows, "Estimate"],
    SE = coef_summary[siri_rows, "Std. Error"],
    OR = exp(coef_summary[siri_rows, "Estimate"]),
    CI_Lower = exp(conf_int[siri_rows, 1]),
    CI_Upper = exp(conf_int[siri_rows, 2]),
    P_Value = coef_summary[siri_rows, "Pr(>|t|)"]
  )
  
  return(results)
}

# 提取三个模型的结果
results_model1 <- extract_or(model1, "Model 1")
results_model2 <- extract_or(model2, "Model 2")
results_model3 <- extract_or(model3, "Model 3")

# 合并结果
all_results <- rbind(results_model1, results_model2, results_model3)

# 格式化显示
cat("\n==================== 主要回归分析结果 ====================\n")
print(all_results)


# --- Code Block 9 ---
# ==================== 详细模型结果 ====================

# Model 1 详细结果
cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    Model 1: 粗模型结果                         ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")
cat("\n")

# 显示完整摘要
summary(model1)

# 计算并显示OR
or_model1 <- exp(coef(model1))
ci_model1 <- exp(confint(model1))

cat("\nOR值及95%CI:\n")
for (i in 2:length(or_model1)) {  # 跳过截距
  var_name <- names(or_model1)[i]
  if (grepl("siri_quartile", var_name)) {
    cat(var_name, ": OR =", round(or_model1[i], 2), 
        "(95%CI:", round(ci_model1[i, 1], 2), "-", 
        round(ci_model1[i, 2], 2), ")\n")
  }
}

# Model 2 详细结果
cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    Model 2: 调整人口学变量                      ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")
cat("\n")

summary(model2)

or_model2 <- exp(coef(model2))
ci_model2 <- exp(confint(model2))

cat("\nOR值及95%CI:\n")
for (i in 2:length(or_model2)) {
  var_name <- names(or_model2)[i]
  if (grepl("siri_quartile", var_name)) {
    cat(var_name, ": OR =", round(or_model2[i], 2), 
        "(95%CI:", round(ci_model2[i, 1], 2), "-", 
        round(ci_model2[i, 2], 2), ")\n")
  }
}

# Model 3 详细结果
cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    Model 3: 完全调整模型                        ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")
cat("\n")

summary(model3)

or_model3 <- exp(coef(model3))
ci_model3 <- exp(confint(model3))

cat("\nOR值及95%CI:\n")
for (i in 2:length(or_model3)) {
  var_name <- names(or_model3)[i]
  if (grepl("siri_quartile", var_name)) {
    cat(var_name, ": OR =", round(or_model3[i], 2), 
        "(95%CI:", round(ci_model3[i, 1], 2), "-", 
        round(ci_model3[i, 2], 2), ")\n")
  }
}


# --- Code Block 10 ---
# ==================== 趋势检验 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    趋势检验（P for trend）                      ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 方法1：将SIRI四分位组作为连续变量（1, 2, 3, 4）
nhanes_complete$siri_q_num <- as.numeric(nhanes_complete$siri_quartile)

# 更新survey design
nhanes_design_trend <- svydesign(
  id = ~psu,
  strata = ~strata,
  weights = ~weight_4yr,
  data = nhanes_complete,
  nest = TRUE
)

# 趋势检验模型（使用数值变量）
# Model 1 趋势
trend_model1 <- svyglm(dry_eye_a ~ siri_q_num, 
                        design = nhanes_design_trend, 
                        family = quasibinomial())
p_trend_model1 <- summary(trend_model1)$coefficients["siri_q_num", "Pr(>|t|)"]

# Model 2 趋势
trend_model2 <- svyglm(
  as.formula(paste("dry_eye_a ~ siri_q_num +", covars_model2)), 
  design = nhanes_design_trend, 
  family = quasibinomial()
)
p_trend_model2 <- summary(trend_model2)$coefficients["siri_q_num", "Pr(>|t|)"]

# Model 3 趋势
trend_model3 <- svyglm(
  as.formula(paste("dry_eye_a ~ siri_q_num +", covars_model3)), 
  design = nhanes_design_trend, 
  family = quasibinomial()
)
p_trend_model3 <- summary(trend_model3)$coefficients["siri_q_num", "Pr(>|t|)"]

# 输出趋势检验结果
cat("\n趋势检验P值:\n")
cat("  Model 1:", ifelse(p_trend_model1 < 0.001, "<0.001", round(p_trend_model1, 3)), "\n")
cat("  Model 2:", ifelse(p_trend_model2 < 0.001, "<0.001", round(p_trend_model2, 3)), "\n")
cat("  Model 3:", ifelse(p_trend_model3 < 0.001, "<0.001", round(p_trend_model3, 3)), "\n")

# 方法2：使用SIRI组中位数作为连续变量（更精确）
siri_medians <- nhanes_complete %>%
  group_by(siri_quartile) %>%
  summarise(siri_median = median(siri, na.rm = TRUE)) %>%
  arrange(siri_quartile)

nhanes_complete$siri_q_median <- siri_medians$siri_median[match(
  nhanes_complete$siri_quartile, 
  siri_medians$siri_quartile
)]

# 更新design
nhanes_design_trend2 <- svydesign(
  id = ~psu,
  strata = ~strata,
  weights = ~weight_4yr,
  data = nhanes_complete,
  nest = TRUE
)

# 使用组中位数的趋势检验
trend_model3_median <- svyglm(
  as.formula(paste("dry_eye_a ~ siri_q_median +", covars_model3)), 
  design = nhanes_design_trend2, 
  family = quasibinomial()
)
p_trend_median <- summary(trend_model3_median)$coefficients["siri_q_median", "Pr(>|t|)"]

cat("\nModel 3 趋势检验（使用组中位数）:", 
    ifelse(p_trend_median < 0.001, "<0.001", round(p_trend_median, 3)), "\n")


# --- Code Block 11 ---
# ==================== 连续变量分析（每SD增加） ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    连续变量分析（每SD增加）                     ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 计算SIRI的标准差
siri_sd <- sd(nhanes_complete$siri, na.rm = TRUE)
siri_mean <- mean(nhanes_complete$siri, na.rm = TRUE)

cat("\nSIRI描述性统计:\n")
cat("  均值:", round(siri_mean, 3), "\n")
cat("  标准差:", round(siri_sd, 3), "\n")

# 创建标准化SIRI变量（Z-score）
nhanes_complete$siri_z <- (nhanes_complete$siri - siri_mean) / siri_sd

# 或者直接除以SD（更常用的方法）
nhanes_complete$siri_per_sd <- nhanes_complete$siri / siri_sd

# 更新survey design
nhanes_design_cont <- svydesign(
  id = ~psu,
  strata = ~strata,
  weights = ~weight_4yr,
  data = nhanes_complete,
  nest = TRUE
)

# 连续变量模型
# Model 1
cont_model1 <- svyglm(dry_eye_a ~ siri_per_sd, 
                       design = nhanes_design_cont, 
                       family = quasibinomial())

# Model 2
cont_model2 <- svyglm(
  as.formula(paste("dry_eye_a ~ siri_per_sd +", covars_model2)), 
  design = nhanes_design_cont, 
  family = quasibinomial()
)

# Model 3
cont_model3 <- svyglm(
  as.formula(paste("dry_eye_a ~ siri_per_sd +", covars_model3)), 
  design = nhanes_design_cont, 
  family = quasibinomial()
)

# 提取结果
extract_continuous_or <- function(model, model_name) {
  coef_val <- coef(model)["siri_per_sd"]
  ci_val <- confint(model)["siri_per_sd", ]
  p_val <- summary(model)$coefficients["siri_per_sd", "Pr(>|t|)"]
  
  data.frame(
    Model = model_name,
    OR = exp(coef_val),
    CI_Lower = exp(ci_val[1]),
    CI_Upper = exp(ci_val[2]),
    P_Value = p_val
  )
}

cont_results <- rbind(
  extract_continuous_or(cont_model1, "Model 1"),
  extract_continuous_or(cont_model2, "Model 2"),
  extract_continuous_or(cont_model3, "Model 3")
)

cat("\n每SD增加的SIRI与干眼症关联:\n")
cat("(1 SD =", round(siri_sd, 3), ")\n\n")

for (i in 1:nrow(cont_results)) {
  cat(cont_results$Model[i], ": OR =", round(cont_results$OR[i], 2),
      "(95%CI:", round(cont_results$CI_Lower[i], 2), "-",
      round(cont_results$CI_Upper[i], 2), "),",
      "P =", ifelse(cont_results$P_Value[i] < 0.001, "<0.001", 
                    round(cont_results$P_Value[i], 3)), "\n")
}


# --- Code Block 12 ---
# ==================== 各组病例数统计 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    各SIRI组病例数统计                          ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 未加权病例数
case_counts <- nhanes_complete %>%
  group_by(siri_quartile) %>%
  summarise(
    N_Total = n(),
    N_Cases = sum(dry_eye_a == 1, na.rm = TRUE),
    N_Controls = sum(dry_eye_a == 0, na.rm = TRUE)
  ) %>%
  mutate(
    Case_Pct = round(N_Cases / N_Total * 100, 1)
  )

cat("\n各组病例数（未加权）:\n")
print(case_counts)

# 加权患病率
dryeye_by_siri <- svyby(~dry_eye_a, ~siri_quartile, 
                         nhanes_design_complete, 
                         svymean, na.rm = TRUE)

cat("\n各组加权患病率:\n")
for (i in 1:4) {
  q_name <- paste0("Q", i)
  prev <- dryeye_by_siri$dry_eye_a[i] * 100
  se <- dryeye_by_siri$se[i] * 100
  cat("  ", q_name, ":", round(prev, 1), "% (SE:", round(se, 1), "%)\n")
}


# --- Code Block 13 ---
# ==================== 整理Table 2数据 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    Table 2: 主要回归分析结果                    ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 创建格式化函数
format_or <- function(or, ci_low, ci_high, digits = 2) {
  paste0(round(or, digits), " (", 
         round(ci_low, digits), "-", 
         round(ci_high, digits), ")")
}

format_p <- function(p) {
  if (p < 0.001) return("<0.001")
  else if (p < 0.01) return(paste0(round(p, 3)))
  else return(round(p, 2))
}

# 创建Table 2数据框
table2_data <- data.frame(
  SIRI_Group = c("Q1 (Reference)", "Q2", "Q3", "Q4", 
                 "P for trend", "Per 1-SD increase"),
  Cases_Total = c(
    paste0(case_counts$N_Cases[1], "/", case_counts$N_Total[1]),
    paste0(case_counts$N_Cases[2], "/", case_counts$N_Total[2]),
    paste0(case_counts$N_Cases[3], "/", case_counts$N_Total[3]),
    paste0(case_counts$N_Cases[4], "/", case_counts$N_Total[4]),
    "", ""
  ),
  Model1_OR = character(6),
  Model2_OR = character(6),
  Model3_OR = character(6),
  stringsAsFactors = FALSE
)

# 填充Q1参考值
table2_data$Model1_OR[1] <- "1.00 (Reference)"
table2_data$Model2_OR[1] <- "1.00 (Reference)"
table2_data$Model3_OR[1] <- "1.00 (Reference)"

# 填充Q2-Q4的OR值
for (i in 1:3) {  # Q2, Q3, Q4
  # Model 1
  table2_data$Model1_OR[i+1] <- format_or(
    results_model1$OR[i], 
    results_model1$CI_Lower[i], 
    results_model1$CI_Upper[i]
  )
  
  # Model 2
  table2_data$Model2_OR[i+1] <- format_or(
    results_model2$OR[i], 
    results_model2$CI_Lower[i], 
    results_model2$CI_Upper[i]
  )
  
  # Model 3
  table2_data$Model3_OR[i+1] <- format_or(
    results_model3$OR[i], 
    results_model3$CI_Lower[i], 
    results_model3$CI_Upper[i]
  )
}

# 填充P for trend
table2_data$Model1_OR[5] <- format_p(p_trend_model1)
table2_data$Model2_OR[5] <- format_p(p_trend_model2)
table2_data$Model3_OR[5] <- format_p(p_trend_model3)

# 填充每SD增加
table2_data$Model1_OR[6] <- format_or(
  cont_results$OR[1], cont_results$CI_Lower[1], cont_results$CI_Upper[1]
)
table2_data$Model2_OR[6] <- format_or(
  cont_results$OR[2], cont_results$CI_Lower[2], cont_results$CI_Upper[2]
)
table2_data$Model3_OR[6] <- format_or(
  cont_results$OR[3], cont_results$CI_Lower[3], cont_results$CI_Upper[3]
)

# 更改列名
names(table2_data) <- c(
  "SIRI Group", 
  "Cases/Total",
  "Model 1 OR (95% CI)",
  "Model 2 OR (95% CI)",
  "Model 3 OR (95% CI)"
)

# 显示表格
cat("\n")
print(table2_data)


# --- Code Block 14 ---
# ==================== 使用kable格式化表格 ====================

library(knitr)
library(kableExtra)

# 创建美化的Table 2
table2_kable <- kable(table2_data, 
                       caption = "Table 2. Association between SIRI and Dry Eye Disease",
                       align = c("l", "c", "c", "c", "c"),
                       format = "html") %>%
  kable_styling(
    bootstrap_options = c("striped", "hover", "condensed"),
    full_width = FALSE,
    font_size = 14
  ) %>%
  add_header_above(c(" " = 2, "Odds Ratio (95% CI)" = 3)) %>%
  footnote(
    general = c(
      "Model 1: Unadjusted (crude model)",
      "Model 2: Adjusted for age, sex, race/ethnicity, education, and family income-to-poverty ratio",
      "Model 3: Additionally adjusted for BMI, smoking status, diabetes status, and hypertension",
      "Alcohol consumption was not included due to substantial missing data (>70%)",
      paste0("SIRI quartile ranges: Q1 (≤", round(quantile(nhanes_complete$siri, 0.25), 2), 
             "), Q2 (", round(quantile(nhanes_complete$siri, 0.25), 2), "-",
             round(quantile(nhanes_complete$siri, 0.50), 2), "), Q3 (",
             round(quantile(nhanes_complete$siri, 0.50), 2), "-",
             round(quantile(nhanes_complete$siri, 0.75), 2), "), Q4 (>",
             round(quantile(nhanes_complete$siri, 0.75), 2), ")")
    ),
    general_title = "Notes: "
  )

# 保存为HTML
save_kable(table2_kable, file = "描述性分析/Table2_Main_Regression.html")
cat("\nTable 2已保存为HTML: Table2_Main_Regression.html\n")


# --- Code Block 15 ---
# ==================== 导出为Word文档 ====================

library(flextable)
library(officer)

# 创建flextable
table2_flex <- flextable(table2_data) %>%
  set_header_labels(
    `SIRI Group` = "SIRI Group",
    `Cases/Total` = "Cases/Total",
    `Model 1 OR (95% CI)` = "Model 1",
    `Model 2 OR (95% CI)` = "Model 2",
    `Model 3 OR (95% CI)` = "Model 3"
  ) %>%
  add_header_row(
    values = c("", "", "OR (95% CI)", "", ""),
    colwidths = c(1, 1, 1, 1, 1)
  ) %>%
  merge_h(part = "header") %>%
  align(align = "center", part = "all") %>%
  align(j = 1, align = "left", part = "body") %>%
  bold(part = "header") %>%
  fontsize(size = 10, part = "all") %>%
  autofit() %>%
  set_caption(caption = "Table 2. Association between SIRI and Dry Eye Disease") %>%
  add_footer_lines(values = c(
    "Model 1: Unadjusted (crude model)",
    "Model 2: Adjusted for age, sex, race/ethnicity, education, and family income-to-poverty ratio",
    "Model 3: Additionally adjusted for BMI, smoking status, diabetes status, and hypertension",
    "Alcohol consumption was not included due to substantial missing data (>70%)",
    "Abbreviations: CI, confidence interval; OR, odds ratio; SIRI, Systemic Inflammation Response Index"
  ))

# 保存为Word
save_as_docx(table2_flex, path = "描述性分析/Table2_Main_Regression.docx")
cat("Table 2已保存为Word: Table2_Main_Regression.docx\n")

# 保存为Excel
table2_data_export <- table2_data
writexl::write_xlsx(table2_data_export, "描述性分析/Table2_Main_Regression.xlsx")
cat("Table 2已保存为Excel: Table2_Main_Regression.xlsx\n")


# --- Code Block 16 ---
# ==================== 结果解读 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    主要回归分析结果解读                         ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 提取Q4 vs Q1的最终调整OR（Model 3）
q4_or <- results_model3$OR[3]  # Q4的OR
q4_ci_low <- results_model3$CI_Lower[3]
q4_ci_high <- results_model3$CI_Upper[3]
q4_p <- results_model3$P_Value[3]

cat("\n【核心发现】\n")
cat("\n1. 主要关联效应:\n")
cat("   与SIRI最低四分位组(Q1)相比，最高四分位组(Q4)的干眼症风险:\n")
cat("   • 粗OR (Model 1):", round(results_model1$OR[3], 2), "\n")
cat("   • 调整人口学因素后 (Model 2):", round(results_model2$OR[3], 2), "\n")
cat("   • 完全调整后 (Model 3):", round(q4_or, 2), 
    "(95%CI:", round(q4_ci_low, 2), "-", round(q4_ci_high, 2), ")\n")

cat("\n2. 剂量-反应关系:\n")
cat("   • P for trend:", ifelse(p_trend_model3 < 0.001, "<0.001", round(p_trend_model3, 3)), "\n")
if (p_trend_model3 < 0.05) {
  cat("   • 结论：存在显著的剂量-反应关系\n")
} else {
  cat("   • 结论：剂量-反应关系不显著\n")
}

cat("\n3. 连续变量分析:\n")
cat("   SIRI每增加1个标准差(", round(siri_sd, 3), "):\n", sep = "")
cat("   • 干眼症风险:", round(cont_results$OR[3], 2), 
    "(95%CI:", round(cont_results$CI_Lower[3], 2), "-", 
    round(cont_results$CI_Upper[3], 2), ")\n")

cat("\n4. 调整效应变化:\n")
or_change_m1_m3 <- (results_model1$OR[3] - results_model3$OR[3]) / results_model1$OR[3] * 100
cat("   • 从Model 1到Model 3，Q4的OR变化:", round(or_change_m1_m3, 1), "%\n")
if (abs(or_change_m1_m3) > 10) {
  cat("   • 提示：存在较明显的混杂效应\n")
} else {
  cat("   • 提示：混杂效应较小\n")
}


# --- Code Block 17 ---
# ==================== 生成Results文本 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    Results撰写模板（自动填充）                   ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 生成可直接复制的Results段落
results_text <- paste0(
  "3.2 Association between SIRI and Dry Eye Disease\n\n",
  
  "Table 2 presents the association between SIRI quartiles and the risk ",
  "of dry eye disease. In the unadjusted model (Model 1), compared with ",
  "participants in the lowest SIRI quartile (Q1), those in the highest ",
  "quartile (Q4) had significantly higher odds of dry eye disease ",
  "(OR = ", round(results_model1$OR[3], 2), ", 95% CI: ",
  round(results_model1$CI_Lower[3], 2), "-", round(results_model1$CI_Upper[3], 2), ").\n\n",
  
  "After adjusting for demographic variables including age, sex, ",
  "race/ethnicity, education level, and family income-to-poverty ratio ",
  "(Model 2), the association ",
  ifelse(results_model2$P_Value[3] < 0.05, "remained significant", "was attenuated"),
  " (OR = ", round(results_model2$OR[3], 2), ", 95% CI: ",
  round(results_model2$CI_Lower[3], 2), "-", round(results_model2$CI_Upper[3], 2), ").\n\n",
  
  "In the fully adjusted model (Model 3), additionally controlling for ",
  "BMI, smoking status, diabetes, and hypertension, participants in the ",
  "highest SIRI quartile ",
  ifelse(results_model3$P_Value[3] < 0.05, 
         "still showed significantly elevated odds of dry eye disease",
         "showed non-significantly elevated odds of dry eye disease"),
  " compared with those in the lowest quartile ",
  "(OR = ", round(results_model3$OR[3], 2), ", 95% CI: ",
  round(results_model3$CI_Lower[3], 2), "-", round(results_model3$CI_Upper[3], 2), "). ",
  ifelse(p_trend_model3 < 0.05, 
         "A significant dose-response relationship was observed",
         "No significant dose-response relationship was observed"),
  " (P for trend ", ifelse(p_trend_model3 < 0.001, "< 0.001", paste0("= ", round(p_trend_model3, 3))), ").\n\n",
  
  "When SIRI was analyzed as a continuous variable, each standard ",
  "deviation increase in SIRI (1 SD = ", round(siri_sd, 2), ") was associated with ",
  ifelse(cont_results$OR[3] > 1, "a ", ""),
  round((cont_results$OR[3] - 1) * 100, 0), "% ",
  ifelse(cont_results$OR[3] > 1, "increase", "decrease"),
  " in the odds of dry eye disease ",
  "(OR = ", round(cont_results$OR[3], 2), ", 95% CI: ",
  round(cont_results$CI_Lower[3], 2), "-", round(cont_results$CI_Upper[3], 2), ") ",
  "in the fully adjusted model.\n\n",
  
  "Note: Alcohol consumption was not included in the final model due to ",
  "substantial missing data (>70%)."
)

cat(results_text)

# 保存Results文本
writeLines(results_text, "描述性分析/Results_Section_3.2.txt")
cat("\n\nResults文本已保存: Results_Section_3.2.txt\n")


# --- Code Block 18 ---
# ==================== 模型诊断 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    模型诊断与质量检查                          ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 1. 检查多重共线性（使用普通glm估计VIF）
cat("\n【1. 多重共线性检查】\n")
# 注意：VIF需要使用普通glm计算，svyglm不直接支持

# 创建临时普通glm模型用于VIF计算
temp_glm <- glm(formula_model3, 
                data = nhanes_complete, 
                family = binomial())

# 计算VIF
library(car)
vif_values <- vif(temp_glm)

cat("各变量方差膨胀因子(VIF):\n")
print(vif_values)

# VIF > 5 或 > 10 提示多重共线性问题
if (any(vif_values > 5)) {
  cat("\n⚠️ 警告：存在VIF > 5的变量，可能存在多重共线性\n")
} else {
  cat("\n✓ 所有变量VIF < 5，无明显多重共线性问题\n")
}

# 2. 检查模型拟合
cat("\n【2. 模型拟合检验】\n")
# 使用Hosmer-Lemeshow检验需要额外处理加权数据
# 这里报告伪R²

# 计算McFadden's R²
null_model <- svyglm(dry_eye_a ~ 1, 
                      design = nhanes_design_complete, 
                      family = quasibinomial())

pseudo_r2_model3 <- 1 - (logLik(model3) / logLik(null_model))
cat("Model 3 伪R²:", round(as.numeric(pseudo_r2_model3), 4), "\n")

# 3. 检查样本量是否足够
cat("\n【3. 样本量检查】\n")
cat("分析样本量:", nrow(nhanes_complete), "\n")
cat("干眼症病例数:", sum(nhanes_complete$dry_eye_a == 1), "\n")
cat("Model 3估计参数数:", length(coef(model3)), "\n")
cat("每参数事件数(EPV):", 
    round(sum(nhanes_complete$dry_eye_a == 1) / length(coef(model3)), 1), "\n")

if (sum(nhanes_complete$dry_eye_a == 1) / length(coef(model3)) >= 10) {
  cat("✓ EPV ≥ 10，样本量充足\n")
} else {
  cat("⚠️ EPV < 10，可能存在过拟合风险\n")
}


# --- Code Block 19 ---
# ==================== 保存分析结果 ====================

# 保存所有回归模型对象
save(
  model1, model2, model3,
  cont_model1, cont_model2, cont_model3,
  trend_model1, trend_model2, trend_model3,
  results_model1, results_model2, results_model3,
  cont_results,
  table2_data,
  p_trend_model1, p_trend_model2, p_trend_model3,
  nhanes_complete,
  nhanes_design_complete,
  file = "描述性分析/Day18-19_Regression_Objects.RData"
)

cat("\n✓ 回归分析对象已保存: Day18-19_Regression_Objects.RData\n")
cat("\n下次加载使用: load('描述性分析/Day18-19_Regression_Objects.RData')\n")


# --- Code Block 20 ---
# ==================== Day 18-19 主要回归分析完整代码 ====================
# 
# 项目：SIRI与干眼症关联研究
# 任务：主要Logistic回归分析
# 前置条件：已完成Day 16-17描述性分析
# 
# 运行说明：
# 1. 确保已完成Day 16-17描述性分析
# 2. 工作目录设置为项目根目录
# 3. 按顺序执行各代码块
# 
# ================================================================

# [包含前述所有代码的完整版本]
# 可保存为：描述性分析/Day18-19_Analysis_Code.R
