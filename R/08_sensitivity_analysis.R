# ============================================================
# Script: 08_sensitivity_analysis.R
# Purpose: Table 4: Multiple sensitivity analyses
# Project: SIRI and Dry Eye Disease (NHANES 2005-2008)
# Data: NHANES 2005-2006 and 2007-2008 cycles
# ============================================================

# --- Code Block 1 ---
# ❌ 错误做法：排除后直接用glm
data_no_outlier <- data %>% filter(siri_outlier == 0)
glm(dry_eye ~ siri_quartile, data = data_no_outlier)

# ✓ 正确做法：先排除再重新设置survey design
data_no_outlier <- data %>% filter(siri_outlier == 0)
design_no_outlier <- svydesign(
  id = ~psu, strata = ~strata, weights = ~weight_4yr,
  nest = TRUE, data = data_no_outlier
)
svyglm(dry_eye ~ siri_quartile, design = design_no_outlier)


# --- Code Block 2 ---
# ==================== 环境设置 ====================
# 设置工作目录
setwd("/Users/mayiding/Desktop/第一篇")

# 清空环境（可选）
# rm(list = ls())

# 安装必要的包（如未安装）
required_packages <- c(
  "survey",       # 复杂调查分析
  "dplyr",        # 数据处理
  "tidyr",        # 数据整理
  "ggplot2",      # 可视化
  "mice",         # 多重插补
  "mitools",      # 插补结果合并
  "broom",        # 模型结果整理
  "kableExtra",   # 表格美化
  "flextable",    # 表格导出
  "officer",      # Word导出
  "forestplot",   # 森林图
  "scales"        # 坐标轴刻度
)

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

cat("✓ 所有包加载完成！\n")


# --- Code Block 3 ---
# ==================== 加载数据 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    加载分析对象                                ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 加载Day 18-19保存的回归分析对象
load("描述性分析/Day18-19_Regression_Objects.RData")

# ==================== 数据验证 ====================
cat("\n【数据加载验证】\n")
cat("分析样本量:", nrow(nhanes_complete), "\n")
cat("干眼症病例数:", sum(nhanes_complete$dry_eye_a == 1, na.rm = TRUE), "\n")
cat("干眼症患病率:",
    round(mean(nhanes_complete$dry_eye_a == 1, na.rm = TRUE) * 100, 1), "%\n")

# 验证SIRI四分位分布
cat("\n【SIRI四分位组分布】\n")
siri_q_table <- table(nhanes_complete$siri_quartile)
print(siri_q_table)
cat("各组占比:", round(prop.table(siri_q_table) * 100, 1), "%\n")

# 验证标记变量是否存在
cat("\n【关键变量检查】\n")
if ("blood_disorder" %in% names(nhanes_complete)) {
  cat("✓ blood_disorder变量存在\n")
  cat("  可疑血液病:", sum(nhanes_complete$blood_disorder == 1, na.rm = TRUE), "人\n")
} else {
  cat("⚠️ blood_disorder变量不存在，需要创建\n")
}

if ("siri_outlier" %in% names(nhanes_complete)) {
  cat("✓ siri_outlier变量存在\n")
  cat("  SIRI极端值:", sum(nhanes_complete$siri_outlier == 1, na.rm = TRUE), "人\n")
} else {
  cat("⚠️ siri_outlier变量不存在，需要创建\n")
}

# 验证结局变量
cat("\n【干眼症定义变量检查】\n")
if ("dry_eye_c1" %in% names(nhanes_complete)) {
  cat("✓ dry_eye_c1（严格定义）存在\n")
  cat("  患病率:", round(mean(nhanes_complete$dry_eye_c1 == 1, na.rm = TRUE) * 100, 1), "%\n")
} else {
  cat("⚠️ dry_eye_c1变量不存在，需要创建\n")
}

if ("dry_eye_c2" %in% names(nhanes_complete)) {
  cat("✓ dry_eye_c2（症状+用药）存在\n")
  cat("  患病率:", round(mean(nhanes_complete$dry_eye_c2 == 1, na.rm = TRUE) * 100, 1), "%\n")
} else {
  cat("⚠️ dry_eye_c2变量不存在，需要创建\n")
}

cat("\n✓ 数据加载完成！\n")


# --- Code Block 4 ---
# ==================== 创建标记变量（如需要） ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    创建标记变量                                ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 创建blood_disorder标记（如不存在）
if (!"blood_disorder" %in% names(nhanes_complete)) {
  nhanes_complete <- nhanes_complete %>%
    mutate(
      blood_disorder = case_when(
        wbc > 25 | wbc < 2.5 ~ 1,           # 白细胞异常
        lymphocyte_abs > 10 ~ 1,            # 淋巴细胞异常高
        monocyte_abs > 2.5 ~ 1,             # 单核细胞异常高
        neutrophil_abs > 15 ~ 1,            # 中性粒细胞异常高
        TRUE ~ 0
      )
    )
  cat("✓ blood_disorder变量已创建\n")
}

# 创建siri_outlier标记（如不存在）
if (!"siri_outlier" %in% names(nhanes_complete)) {
  siri_p01 <- quantile(nhanes_complete$siri, 0.01, na.rm = TRUE)
  siri_p99 <- quantile(nhanes_complete$siri, 0.99, na.rm = TRUE)

  nhanes_complete <- nhanes_complete %>%
    mutate(
      siri_outlier = case_when(
        siri < siri_p01 ~ 1,
        siri > siri_p99 ~ 1,
        TRUE ~ 0
      )
    )

  cat("✓ siri_outlier变量已创建\n")
  cat("  1%分位数:", round(siri_p01, 3), "\n")
  cat("  99%分位数:", round(siri_p99, 3), "\n")
}

# 创建dry_eye_c1（严格定义，如不存在）
if (!"dry_eye_c1" %in% names(nhanes_complete)) {
  nhanes_complete <- nhanes_complete %>%
    mutate(
      dry_eye_c1 = case_when(
        viq031 %in% c(4, 5) ~ 1,      # 经常/总是 = 阳性
        viq031 %in% c(1, 2, 3) ~ 0,   # 从不/很少/有时 = 阴性
        TRUE ~ NA_real_
      )
    )
  cat("✓ dry_eye_c1变量已创建\n")
}

# 创建dry_eye_c2（症状+用药，如不存在）
if (!"dry_eye_c2" %in% names(nhanes_complete)) {
  nhanes_complete <- nhanes_complete %>%
    mutate(
      dry_eye_c2 = case_when(
        viq031 %in% c(3, 4, 5) & viq041 == 1 ~ 1,  # 有症状且用药
        viq031 %in% c(1, 2) ~ 0,                    # 无症状
        viq031 %in% c(3, 4, 5) & viq041 == 2 ~ 0,  # 有症状但不用药
        TRUE ~ NA_real_
      )
    )
  cat("✓ dry_eye_c2变量已创建\n")
}

cat("\n✓ 所有标记变量准备完成！\n")


# --- Code Block 5 ---
# ==================== SA-Exp1：排除可疑血液病 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                SA-Exp1：排除可疑血液病                         ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# Step 1：检查血液病标记
cat("\n【Step 1：检查血液病标记】\n")
blood_disorder_table <- table(nhanes_complete$blood_disorder, useNA = "always")
print(blood_disorder_table)

n_blood_disorder <- sum(nhanes_complete$blood_disorder == 1, na.rm = TRUE)
cat("可疑血液病人数:", n_blood_disorder, "人\n")

# Step 2：创建排除血液病的子集
cat("\n【Step 2：创建子集】\n")
data_sa_exp1 <- nhanes_complete %>%
  filter(blood_disorder == 0 | is.na(blood_disorder))

n_sa_exp1 <- nrow(data_sa_exp1)
n_excluded <- nrow(nhanes_complete) - n_sa_exp1

cat("主分析样本量:", nrow(nhanes_complete), "\n")
cat("SA-Exp1样本量:", n_sa_exp1, "\n")
cat("排除人数:", n_excluded, "\n")
cat("保留比例:", round(n_sa_exp1 / nrow(nhanes_complete) * 100, 1), "%\n")

# Step 3：重新设置调查设计
cat("\n【Step 3：重新设置survey design】\n")
options(survey.lonely.psu = "adjust")

design_sa_exp1 <- svydesign(
  id = ~psu,
  strata = ~strata,
  weights = ~weight_4yr,
  nest = TRUE,
  data = data_sa_exp1
)

cat("✓ Survey design已更新\n")

# Step 4：运行Logistic回归（Model 3）
cat("\n【Step 4：运行Model 3】\n")
model_sa_exp1 <- svyglm(
  dry_eye_a ~ siri_quartile +
    age + gender_cat + race_cat + education_cat + pir +
    bmi_cat + smoking_status + drinking_status + diabetes_status + hypertension,
  design = design_sa_exp1,
  family = quasibinomial()
)

cat("✓ 模型拟合完成\n")

# Step 5：提取结果
cat("\n【Step 5：提取SIRI四分位结果】\n")
coef_summary <- summary(model_sa_exp1)$coefficients

# 提取Q2, Q3, Q4的结果
quartiles <- c("Q2", "Q3", "Q4")
result_sa_exp1 <- data.frame(
  Quartile = quartiles,
  OR = NA,
  CI_Lower = NA,
  CI_Upper = NA,
  P_Value = NA
)

for (i in 1:3) {
  q_name <- paste0("siri_quartile", quartiles[i])
  if (q_name %in% rownames(coef_summary)) {
    est <- coef_summary[q_name, "Estimate"]
    se <- coef_summary[q_name, "Std. Error"]
    pval <- coef_summary[q_name, "Pr(>|t|)"]

    result_sa_exp1$OR[i] <- exp(est)
    result_sa_exp1$CI_Lower[i] <- exp(est - 1.96 * se)
    result_sa_exp1$CI_Upper[i] <- exp(est + 1.96 * se)
    result_sa_exp1$P_Value[i] <- pval
  }
}

# 格式化输出
result_sa_exp1 <- result_sa_exp1 %>%
  mutate(
    OR_CI = sprintf("%.2f (%.2f-%.2f)", OR, CI_Lower, CI_Upper),
    P_Formatted = ifelse(P_Value < 0.001, "<0.001",
                         sprintf("%.3f", P_Value))
  )

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("                    SA-Exp1 结果汇总                            \n")
cat("═══════════════════════════════════════════════════════════════\n")
print(result_sa_exp1 %>% select(Quartile, OR_CI, P_Formatted))

# 提取Q4结果用于汇总
or_q4_exp1 <- result_sa_exp1$OR[3]
ci_lower_q4_exp1 <- result_sa_exp1$CI_Lower[3]
ci_upper_q4_exp1 <- result_sa_exp1$CI_Upper[3]
p_q4_exp1 <- result_sa_exp1$P_Value[3]

cat("\n📊 【关键结果】Q4 vs Q1:\n")
cat("   OR =", sprintf("%.2f", or_q4_exp1), "\n")
cat("   95%CI =", sprintf("%.2f-%.2f", ci_lower_q4_exp1, ci_upper_q4_exp1), "\n")
cat("   P =", sprintf("%.3f", p_q4_exp1), "\n")

cat("\n✓ SA-Exp1分析完成！\n")


# --- Code Block 6 ---
# ==================== SA-Exp2：排除SIRI极端值 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                SA-Exp2：排除SIRI极端值                         ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# Step 1：检查极端值标记
cat("\n【Step 1：检查SIRI极端值标记】\n")
outlier_table <- table(nhanes_complete$siri_outlier, useNA = "always")
print(outlier_table)

n_outlier <- sum(nhanes_complete$siri_outlier == 1, na.rm = TRUE)
cat("SIRI极端值人数:", n_outlier, "人\n")

# 显示极端值范围
siri_p01 <- quantile(nhanes_complete$siri, 0.01, na.rm = TRUE)
siri_p99 <- quantile(nhanes_complete$siri, 0.99, na.rm = TRUE)
cat("SIRI 1%分位数:", round(siri_p01, 3), "\n")
cat("SIRI 99%分位数:", round(siri_p99, 3), "\n")

# Step 2：创建排除极端值的子集
cat("\n【Step 2：创建子集】\n")
data_sa_exp2 <- nhanes_complete %>%
  filter(siri_outlier == 0)

n_sa_exp2 <- nrow(data_sa_exp2)
n_excluded <- nrow(nhanes_complete) - n_sa_exp2

cat("主分析样本量:", nrow(nhanes_complete), "\n")
cat("SA-Exp2样本量:", n_sa_exp2, "\n")
cat("排除人数:", n_excluded, "\n")
cat("保留比例:", round(n_sa_exp2 / nrow(nhanes_complete) * 100, 1), "%\n")

# Step 3：重新设置调查设计
cat("\n【Step 3：重新设置survey design】\n")
design_sa_exp2 <- svydesign(
  id = ~psu,
  strata = ~strata,
  weights = ~weight_4yr,
  nest = TRUE,
  data = data_sa_exp2
)

cat("✓ Survey design已更新\n")

# Step 4：运行Logistic回归（Model 3）
cat("\n【Step 4：运行Model 3】\n")
model_sa_exp2 <- svyglm(
  dry_eye_a ~ siri_quartile +
    age + gender_cat + race_cat + education_cat + pir +
    bmi_cat + smoking_status + drinking_status + diabetes_status + hypertension,
  design = design_sa_exp2,
  family = quasibinomial()
)

cat("✓ 模型拟合完成\n")

# Step 5：提取结果
cat("\n【Step 5：提取SIRI四分位结果】\n")
coef_summary <- summary(model_sa_exp2)$coefficients

result_sa_exp2 <- data.frame(
  Quartile = quartiles,
  OR = NA,
  CI_Lower = NA,
  CI_Upper = NA,
  P_Value = NA
)

for (i in 1:3) {
  q_name <- paste0("siri_quartile", quartiles[i])
  if (q_name %in% rownames(coef_summary)) {
    est <- coef_summary[q_name, "Estimate"]
    se <- coef_summary[q_name, "Std. Error"]
    pval <- coef_summary[q_name, "Pr(>|t|)"]

    result_sa_exp2$OR[i] <- exp(est)
    result_sa_exp2$CI_Lower[i] <- exp(est - 1.96 * se)
    result_sa_exp2$CI_Upper[i] <- exp(est + 1.96 * se)
    result_sa_exp2$P_Value[i] <- pval
  }
}

result_sa_exp2 <- result_sa_exp2 %>%
  mutate(
    OR_CI = sprintf("%.2f (%.2f-%.2f)", OR, CI_Lower, CI_Upper),
    P_Formatted = ifelse(P_Value < 0.001, "<0.001",
                         sprintf("%.3f", P_Value))
  )

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("                    SA-Exp2 结果汇总                            \n")
cat("═══════════════════════════════════════════════════════════════\n")
print(result_sa_exp2 %>% select(Quartile, OR_CI, P_Formatted))

# 提取Q4结果
or_q4_exp2 <- result_sa_exp2$OR[3]
ci_lower_q4_exp2 <- result_sa_exp2$CI_Lower[3]
ci_upper_q4_exp2 <- result_sa_exp2$CI_Upper[3]
p_q4_exp2 <- result_sa_exp2$P_Value[3]

cat("\n📊 【关键结果】Q4 vs Q1:\n")
cat("   OR =", sprintf("%.2f", or_q4_exp2), "\n")
cat("   95%CI =", sprintf("%.2f-%.2f", ci_lower_q4_exp2, ci_upper_q4_exp2), "\n")
cat("   P =", sprintf("%.3f", p_q4_exp2), "\n")

cat("\n✓ SA-Exp2分析完成！\n")


# --- Code Block 7 ---
# ========================================
# 提取主分析的Q4结果（用于敏感性分析比较）
# ========================================

# 首先检查加载的对象中有哪些模型
cat("\n=== 可用的对象 ===\n")
print(ls())

# 提取主分析Model 3的Q4结果
# （假设您的主分析模型名为 model_3 或 model_full）

# 尝试找到主分析模型
if(exists("model_3")) {
  main_model <- model_3
  cat("\n使用 model_3 作为主分析模型\n")
} else if(exists("model_full")) {
  main_model <- model_full
  cat("\n使用 model_full 作为主分析模型\n")
} else if(exists("model2")) {
  main_model <- model2
  cat("\n使用 model2 作为主分析模型\n")
} else {
  cat("\n请检查主分析模型的名称\n")
  cat("可用的对象：", ls(), "\n")
  stop("未找到主分析模型")
}

# 提取Q4的系数和标准误
coef_main <- summary(main_model)$coefficients
print(coef_main)

# 提取Q4相关结果
est_main <- coef_main["siri_quartileQ4", "Estimate"]
se_main <- coef_main["siri_quartileQ4", "Std. Error"]
p_q4_main <- coef_main["siri_quartileQ4", "Pr(>|t|)"]

# 计算OR和95%CI
or_q4_main <- exp(est_main)
ci_lower_q4_main <- exp(est_main - 1.96 * se_main)
ci_upper_q4_main <- exp(est_main + 1.96 * se_main)

# 显示结果
cat("\n=== 主分析Q4结果 ===\n")
cat(sprintf("OR: %.3f\n", or_q4_main))
cat(sprintf("95%% CI: %.3f - %.3f\n", ci_lower_q4_main, ci_upper_q4_main))
cat(sprintf("P值: %.4f\n", p_q4_main))
# ========================================
# A型敏感性分析比较表
# ========================================

# 创建比较表
comparison_a <- data.frame(
  分析类型 = c("主分析", "SA-Exp1：排除血液疾病", "SA-Exp2：排除SIRI极端值", "SA-Exp3：同时排除"),
  样本量 = c(nrow(nhanes_complete), n_sa_exp1, n_sa_exp2, n_sa_exp3),
  排除数量 = c(0, n_blood_disorder, n_outlier, n_excluded),
  OR_Q4 = sprintf("%.3f", c(or_q4_main, or_q4_exp1, or_q4_exp2, or_q4_exp3)),
  CI_95 = c(
    sprintf("%.3f-%.3f", ci_lower_q4_main, ci_upper_q4_main),
    sprintf("%.3f-%.3f", ci_lower_q4_exp1, ci_upper_q4_exp1),
    sprintf("%.3f-%.3f", ci_lower_q4_exp2, ci_upper_q4_exp2),
    sprintf("%.3f-%.3f", ci_lower_q4_exp3, ci_upper_q4_exp3)
  ),
  P值 = sprintf("%.4f", c(p_q4_main, p_q4_exp1, p_q4_exp2, p_q4_exp3)),
  OR变化百分比 = c(
    "-",
    sprintf("%.1f%%", abs(or_q4_exp1 - or_q4_main) / or_q4_main * 100),
    sprintf("%.1f%%", abs(or_q4_exp2 - or_q4_main) / or_q4_main * 100),
    sprintf("%.1f%%", abs(or_q4_exp3 - or_q4_main) / or_q4_main * 100)
  ),
  stringsAsFactors = FALSE
)

# 显示比较表
cat("\n" , rep("=", 80), "\n", sep="")
cat("A型敏感性分析结果比较（Q4 vs Q1）\n")
cat(rep("=", 80), "\n", sep="")
print(comparison_a, row.names = FALSE)

# 判断稳健性
cat("\n=== 稳健性评估 ===\n")
for(i in 2:4) {
  or_change <- abs(as.numeric(comparison_a$OR_Q4[i]) - or_q4_main) / or_q4_main * 100
  
  cat(sprintf("\n%s:\n", comparison_a$分析类型[i]))
  cat(sprintf("  OR变化: %.1f%%", or_change))
  
  if(or_change < 30) {
    cat(" ✓ (变化<30%，结果稳健)\n")
  } else {
    cat(" ✗ (变化≥30%，需关注)\n")
  }
  
  # 检查方向一致性
  if((or_q4_main > 1 && as.numeric(comparison_a$OR_Q4[i]) > 1) ||
     (or_q4_main < 1 && as.numeric(comparison_a$OR_Q4[i]) < 1)) {
    cat("  方向一致: ✓\n")
  } else {
    cat("  方向一致: ✗\n")
  }
  
  # 检查显著性
  if(as.numeric(comparison_a$P值[i]) < 0.05) {
    cat("  统计显著: ✓ (P<0.05)\n")
  } else {
    cat("  统计显著: ✗ (P≥0.05)\n")
  }
}

# 保存结果
save(comparison_a, 
     file = "敏感性分析/SA_A型比较表.RData")

cat("\n比较表已保存至: 敏感性分析/SA_A型比较表.RData\n")


# --- Code Block 8 ---
# ==================== SA-Out1：严格干眼症定义 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║            SA-Out1：严格干眼症定义（VIQ031≥4）                ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# Step 1：检查dry_eye_c1变量
cat("\n【Step 1：检查结局变量】\n")
cat("主分析定义（dry_eye_a）：VIQ031 ≥ 3\n")
cat("严格定义（dry_eye_c1）：VIQ031 ≥ 4（经常/总是）\n\n")

# 主分析患病率
prev_a <- mean(nhanes_complete$dry_eye_a == 1, na.rm = TRUE)
n_cases_a <- sum(nhanes_complete$dry_eye_a == 1, na.rm = TRUE)

# 严格定义患病率
prev_c1 <- mean(nhanes_complete$dry_eye_c1 == 1, na.rm = TRUE)
n_cases_c1 <- sum(nhanes_complete$dry_eye_c1 == 1, na.rm = TRUE)

cat("主分析：病例数 =", n_cases_a, "，患病率 =",
    round(prev_a * 100, 1), "%\n")
cat("严格定义：病例数 =", n_cases_c1, "，患病率 =",
    round(prev_c1 * 100, 1), "%\n")
cat("病例数减少：", n_cases_a - n_cases_c1, "人\n")

# Step 2：使用主分析的survey design（样本不变）
cat("\n【Step 2：使用主分析survey design】\n")
cat("注意：样本量不变，仅结局定义改变\n")

# Step 3：运行Logistic回归（Model 3）
cat("\n【Step 3：运行Model 3】\n")
model_sa_out1 <- svyglm(
  dry_eye_c1 ~ siri_quartile +
    age + gender_cat + race_cat + education_cat + pir +
    bmi_cat + smoking_status + drinking_status + diabetes_status + hypertension,
  design = nhanes_design_complete,  # 使用主分析的design
  family = quasibinomial()
)

cat("✓ 模型拟合完成\n")

# Step 4：提取结果
cat("\n【Step 4：提取SIRI四分位结果】\n")
coef_summary <- summary(model_sa_out1)$coefficients

# 定义quartiles如果还没有
quartiles <- c("Q2", "Q3", "Q4")

result_sa_out1 <- data.frame(
  Quartile = c("Q1", quartiles),
  OR = c(1.00, NA, NA, NA),
  CI_Lower = c(NA, NA, NA, NA),
  CI_Upper = c(NA, NA, NA, NA),
  P_Value = c(NA, NA, NA, NA)
)

for (i in 1:3) {
  q_name <- paste0("siri_quartile", quartiles[i])
  if (q_name %in% rownames(coef_summary)) {
    est <- coef_summary[q_name, "Estimate"]
    se <- coef_summary[q_name, "Std. Error"]
    pval <- coef_summary[q_name, "Pr(>|t|)"]

    result_sa_out1$OR[i+1] <- exp(est)
    result_sa_out1$CI_Lower[i+1] <- exp(est - 1.96 * se)
    result_sa_out1$CI_Upper[i+1] <- exp(est + 1.96 * se)
    result_sa_out1$P_Value[i+1] <- pval
  }
}

result_sa_out1 <- result_sa_out1 %>%
  mutate(
    OR_CI = ifelse(Quartile == "Q1", "1.00 (Ref)",
                   sprintf("%.2f (%.2f-%.2f)", OR, CI_Lower, CI_Upper)),
    P_Formatted = ifelse(is.na(P_Value), "Ref",
                         ifelse(P_Value < 0.001, "<0.001",
                                sprintf("%.3f", P_Value)))
  )

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("                    SA-Out1 结果汇总                            \n")
cat("═══════════════════════════════════════════════════════════════\n")
print(result_sa_out1 %>% select(Quartile, OR_CI, P_Formatted))

# 提取Q4结果
or_q4_out1 <- result_sa_out1$OR[4]
ci_lower_q4_out1 <- result_sa_out1$CI_Lower[4]
ci_upper_q4_out1 <- result_sa_out1$CI_Upper[4]
p_q4_out1 <- result_sa_out1$P_Value[4]

cat("\n📊 【关键结果】Q4 vs Q1:\n")
cat("   OR =", sprintf("%.2f", or_q4_out1), "\n")
cat("   95%CI =", sprintf("%.2f-%.2f", ci_lower_q4_out1, ci_upper_q4_out1), "\n")
cat("   P =", sprintf("%.3f", p_q4_out1), "\n")

# 与主分析对比
or_change <- (or_q4_out1 - or_q4_main) / or_q4_main * 100
cat("\n📌 【与主分析对比】\n")
cat("   OR变化：", sprintf("%+.1f%%", or_change), "\n")
if (abs(or_change) < 20) {
  cat("   ✓ OR变化<20%，结果稳健\n")
} else {
  cat("   ⚠️ OR变化≥20%，需在Discussion中讨论\n")
}

cat("\n✓ SA-Out1分析完成！\n")


# --- Code Block 9 ---
# ==================== SA-Out2：症状+用药定义 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║            SA-Out2：症状+用药定义                              ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# Step 1：检查dry_eye_c2变量
cat("\n【Step 1：检查结局变量】\n")
cat("定义：VIQ031 ≥ 3（有症状）且 VIQ041 = 1（使用人工泪液）\n\n")

# 患病率
prev_c2 <- mean(nhanes_complete$dry_eye_c2 == 1, na.rm = TRUE)
n_cases_c2 <- sum(nhanes_complete$dry_eye_c2 == 1, na.rm = TRUE)
n_missing_c2 <- sum(is.na(nhanes_complete$dry_eye_c2))

cat("病例数：", n_cases_c2, "\n")
cat("患病率：", round(prev_c2 * 100, 1), "%\n")
cat("缺失数：", n_missing_c2, "\n")

if (n_missing_c2 > 0.2 * nrow(nhanes_complete)) {
  cat("⚠️ 警告：缺失率 >20%，需在论文中说明\n")
}

# Step 2：运行Logistic回归（Model 3）
cat("\n【Step 2：运行Model 3】\n")
model_sa_out2 <- svyglm(
  dry_eye_c2 ~ siri_quartile +
    age + gender_cat + race_cat + education_cat + pir +
    bmi_cat + smoking_status + drinking_status + diabetes_status + hypertension,
  design = nhanes_design_complete,
  family = quasibinomial()
)

cat("✓ 模型拟合完成\n")

# Step 3：提取结果
cat("\n【Step 3：提取SIRI四分位结果】\n")
coef_summary <- summary(model_sa_out2)$coefficients

# 定义quartiles如果还没有
quartiles <- c("Q2", "Q3", "Q4")

result_sa_out2 <- data.frame(
  Quartile = c("Q1", quartiles),
  OR = c(1.00, NA, NA, NA),
  CI_Lower = c(NA, NA, NA, NA),
  CI_Upper = c(NA, NA, NA, NA),
  P_Value = c(NA, NA, NA, NA)
)

for (i in 1:3) {
  q_name <- paste0("siri_quartile", quartiles[i])
  if (q_name %in% rownames(coef_summary)) {
    est <- coef_summary[q_name, "Estimate"]
    se <- coef_summary[q_name, "Std. Error"]
    pval <- coef_summary[q_name, "Pr(>|t|)"]

    result_sa_out2$OR[i+1] <- exp(est)
    result_sa_out2$CI_Lower[i+1] <- exp(est - 1.96 * se)
    result_sa_out2$CI_Upper[i+1] <- exp(est + 1.96 * se)
    result_sa_out2$P_Value[i+1] <- pval
  }
}

result_sa_out2 <- result_sa_out2 %>%
  mutate(
    OR_CI = ifelse(Quartile == "Q1", "1.00 (Ref)",
                   sprintf("%.2f (%.2f-%.2f)", OR, CI_Lower, CI_Upper)),
    P_Formatted = ifelse(is.na(P_Value), "Ref",
                         ifelse(P_Value < 0.001, "<0.001",
                                sprintf("%.3f", P_Value)))
  )

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("                    SA-Out2 结果汇总                            \n")
cat("═══════════════════════════════════════════════════════════════\n")
print(result_sa_out2 %>% select(Quartile, OR_CI, P_Formatted))

# 提取Q4结果
or_q4_out2 <- result_sa_out2$OR[4]
ci_lower_q4_out2 <- result_sa_out2$CI_Lower[4]
ci_upper_q4_out2 <- result_sa_out2$CI_Upper[4]
p_q4_out2 <- result_sa_out2$P_Value[4]

cat("\n📊 【关键结果】Q4 vs Q1:\n")
cat("   OR =", sprintf("%.2f", or_q4_out2), "\n")
cat("   95%CI =", sprintf("%.2f-%.2f", ci_lower_q4_out2, ci_upper_q4_out2), "\n")
cat("   P =", sprintf("%.3f", p_q4_out2), "\n")

cat("\n✓ SA-Out2分析完成！\n")

# ==================== B类敏感性分析汇总 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                B类敏感性分析结果对比                           ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

comparison_b <- data.frame(
  Analysis = c("主分析（dry_eye_a）", "SA-Out1（严格）", "SA-Out2（症状+药）"),
  Definition = c("VIQ031≥3", "VIQ031≥4", "VIQ031≥3 & VIQ041=1"),
  Prevalence = c(
    round(prev_a * 100, 1),
    round(prev_c1 * 100, 1),
    round(prev_c2 * 100, 1)
  ),
  Cases = c(n_cases_a, n_cases_c1, n_cases_c2),
  OR_Q4 = c(or_q4_main, or_q4_out1, or_q4_out2),
  CI_Lower = c(ci_lower_q4_main, ci_lower_q4_out1, ci_lower_q4_out2),
  CI_Upper = c(ci_upper_q4_main, ci_upper_q4_out1, ci_upper_q4_out2),
  P_Value = c(p_q4_main, p_q4_out1, p_q4_out2)
) %>%
  mutate(
    Prev_Str = paste0(Prevalence, "%"),
    OR_CI = sprintf("%.2f (%.2f-%.2f)", OR_Q4, CI_Lower, CI_Upper),
    P_Formatted = ifelse(P_Value < 0.001, "<0.001",
                         sprintf("%.3f", P_Value))
  )

cat("\n")
print(comparison_b %>% select(Analysis, Definition, Prev_Str, Cases, OR_CI, P_Formatted))

# 稳健性评估
cat("\n\n【稳健性评估】\n")
for(i in 2:3) {
  or_change <- abs(comparison_b$OR_Q4[i] - or_q4_main) / or_q4_main * 100
  
  cat(sprintf("\n%s:\n", comparison_b$Analysis[i]))
  cat(sprintf("  OR变化: %.1f%%", or_change))
  
  if(or_change < 30) {
    cat(" ✓ (变化<30%，结果稳健)\n")
  } else {
    cat(" ✗ (变化≥30%，需关注)\n")
  }
  
  # 检查方向一致性
  if((or_q4_main > 1 && comparison_b$OR_Q4[i] > 1) ||
     (or_q4_main < 1 && comparison_b$OR_Q4[i] < 1)) {
    cat("  方向一致: ✓\n")
  } else {
    cat("  方向一致: ✗\n")
  }
  
  # 检查显著性
  if(comparison_b$P_Value[i] < 0.05) {
    cat("  统计显著: ✓ (P<0.05)\n")
  } else {
    cat("  统计显著: ✗ (P≥0.05)\n")
  }
}

# 保存结果
save(comparison_b, result_sa_out1, result_sa_out2,
     file = "敏感性分析/SA_B类分析结果.RData")

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("✓ B类敏感性分析（结局变量相关）全部完成！\n")
cat("═══════════════════════════════════════════════════════════════\n")


# --- Code Block 10 ---
# ==================== 多重插补敏感性分析 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                多重插补处理缺失数据                            ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

library(mice)
library(mitools)

# Step 1：检查缺失模式
cat("\n【Step 1：检查缺失模式】\n")
vars_for_imputation <- c(
  "dry_eye_a", "siri_quartile",
  "age", "gender_cat", "race_cat", "education_cat", "pir",
  "bmi_cat", "smoking_status", "drinking_status", "diabetes_status", "hypertension"
)

missing_data <- nhanes_complete %>% select(all_of(vars_for_imputation))
missing_pattern <- md.pattern(missing_data, plot = FALSE)

cat("缺失模式前5行：\n")
print(head(missing_pattern, 5))

# 计算各变量缺失率
missing_rate <- colSums(is.na(missing_data)) / nrow(missing_data) * 100
cat("\n【各变量缺失率】\n")
print(round(missing_rate, 2))

# Step 2：运行多重插补
cat("\n【Step 2：运行多重插补（m=5）】\n")
cat("这可能需要几分钟时间...\n")

# 设置不插补的变量（结局和暴露）
imp_method <- rep("pmm", length(vars_for_imputation))
names(imp_method) <- vars_for_imputation
imp_method["dry_eye_a"] <- ""  # 不插补结局
imp_method["siri_quartile"] <- ""  # 不插补暴露

# 运行插补
imp <- mice(
  missing_data,
  m = 5,                # 5次插补
  maxit = 20,           # 20次迭代
  method = imp_method,
  seed = 123,
  print = FALSE
)

cat("✓ 多重插补完成\n")

# Step 3：在每个插补数据集上运行模型
cat("\n【Step 3：在5个插补数据集上运行模型】\n")

# 在每个插补数据集上分析
results_mi_list <- list()

for (i in 1:5) {
  data_imp_i <- complete(imp, i)

  # 合并权重变量
  data_imp_i <- data_imp_i %>%
    mutate(
      row_id = row_number()
    ) %>%
    left_join(
      nhanes_complete %>%
        mutate(row_id = row_number()) %>%
        select(row_id, psu, strata, weight_4yr),
      by = "row_id"
    )

  # 设置调查设计
  design_imp_i <- svydesign(
    id = ~psu,
    strata = ~strata,
    weights = ~weight_4yr,
    nest = TRUE,
    data = data_imp_i
  )

  # 运行模型
  model_imp_i <- svyglm(
    dry_eye_a ~ siri_quartile +
      age + gender_cat + race_cat + education_cat + pir +
      bmi_cat + smoking_status + drinking_status + diabetes_status + hypertension,
    design = design_imp_i,
    family = quasibinomial()
  )

  # 提取Q4结果
  coef_sum <- summary(model_imp_i)$coefficients
  est <- coef_sum["siri_quartileQ4", "Estimate"]
  se <- coef_sum["siri_quartileQ4", "Std. Error"]

  results_mi_list[[i]] <- data.frame(
    imputation = i,
    estimate = est,
    se = se,
    or = exp(est)
  )

  cat("  插补", i, "完成：OR =", sprintf("%.2f", exp(est)), "\n")
}

# Step 4：合并结果（Rubin's rules）
cat("\n【Step 4：使用Rubin规则合并结果】\n")

results_mi_df <- do.call(rbind, results_mi_list)

# 计算合并估计
pooled_est <- mean(results_mi_df$estimate)
within_var <- mean(results_mi_df$se^2)
between_var <- var(results_mi_df$estimate)
total_var <- within_var + (1 + 1/5) * between_var
pooled_se <- sqrt(total_var)

# 计算OR和95%CI
or_mi <- exp(pooled_est)
ci_lower_mi <- exp(pooled_est - 1.96 * pooled_se)
ci_upper_mi <- exp(pooled_est + 1.96 * pooled_se)

# 计算P值
z_value <- pooled_est / pooled_se
p_mi <- 2 * (1 - pnorm(abs(z_value)))

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("                多重插补结果（Q4 vs Q1）                        \n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("合并OR：", sprintf("%.2f", or_mi), "\n")
cat("95%CI：", sprintf("%.2f-%.2f", ci_lower_mi, ci_upper_mi), "\n")
cat("P值：", sprintf("%.3f", p_mi), "\n")

cat("\n📌 【与完整案例分析对比】\n")
cat("完整案例：OR =", sprintf("%.2f", or_q4_main), "\n")
cat("多重插补：OR =", sprintf("%.2f", or_mi), "\n")
or_diff <- (or_mi - or_q4_main) / or_q4_main * 100
cat("差异：", sprintf("%+.1f%%", or_diff), "\n")

if (abs(or_diff) < 10) {
  cat("✓ 差异<10%，缺失数据未引入明显偏倚\n")
} else {
  cat("⚠️ 差异≥10%，需在Discussion中讨论缺失机制\n")
}

# 保存结果
save(results_mi_df, or_mi, ci_lower_mi, ci_upper_mi, p_mi,
     file = "敏感性分析/SA_多重插补结果.RData")

cat("\n✓ 多重插补分析完成！\n")


# --- Code Block 11 ---
# ==================== 额外调整CRP ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                额外调整CRP（控制炎症混杂）                     ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# Step 1：检查CRP变量
cat("\n【Step 1：检查CRP变量】\n")
cat("CRP变量名:", "crp", "\n")

if ("crp" %in% names(nhanes_complete)) {
  n_crp_available <- sum(!is.na(nhanes_complete$crp))
  crp_missing_rate <- sum(is.na(nhanes_complete$crp)) / nrow(nhanes_complete) * 100

  cat("CRP可用：", n_crp_available, "人\n")
  cat("CRP缺失率：", round(crp_missing_rate, 1), "%\n")

  if (crp_missing_rate > 30) {
    cat("⚠️ 警告：CRP缺失率 >30%，结果解释需谨慎\n")
  }

  # CRP分布
  cat("\nCRP分布（mg/L）：\n")
  cat("  中位数：", round(median(nhanes_complete$crp, na.rm = TRUE), 2), "\n")
  cat("  25%分位：", round(quantile(nhanes_complete$crp, 0.25, na.rm = TRUE), 2), "\n")
  cat("  75%分位：", round(quantile(nhanes_complete$crp, 0.75, na.rm = TRUE), 2), "\n")

} else {
  cat("⚠️ CRP变量不存在，无法进行此敏感性分析\n")
  cat("可以跳过此步骤\n")
}

# Step 2：运行Model 3 + CRP
cat("\n【Step 2：运行Model 3 + CRP】\n")

if ("crp" %in% names(nhanes_complete)) {

  model_sa_crp <- svyglm(
    dry_eye_a ~ siri_quartile +
      age + gender_cat + race_cat + education_cat + pir +
      bmi_cat + smoking_status + drinking_status + diabetes_status + hypertension +
      crp,  # 额外调整CRP
    design = nhanes_design_complete,
    family = quasibinomial()
  )

  cat("✓ 模型拟合完成\n")

  # Step 3：提取结果
  cat("\n【Step 3：提取SIRI四分位结果】\n")
  coef_summary <- summary(model_sa_crp)$coefficients

  # 定义quartiles如果还没有
  quartiles <- c("Q2", "Q3", "Q4")

  result_sa_crp <- data.frame(
    Quartile = c("Q1", quartiles),
    OR = c(1.00, NA, NA, NA),
    CI_Lower = c(NA, NA, NA, NA),
    CI_Upper = c(NA, NA, NA, NA),
    P_Value = c(NA, NA, NA, NA)
  )

  for (i in 1:3) {
    q_name <- paste0("siri_quartile", quartiles[i])
    if (q_name %in% rownames(coef_summary)) {
      est <- coef_summary[q_name, "Estimate"]
      se <- coef_summary[q_name, "Std. Error"]
      pval <- coef_summary[q_name, "Pr(>|t|)"]

      result_sa_crp$OR[i+1] <- exp(est)
      result_sa_crp$CI_Lower[i+1] <- exp(est - 1.96 * se)
      result_sa_crp$CI_Upper[i+1] <- exp(est + 1.96 * se)
      result_sa_crp$P_Value[i+1] <- pval
    }
  }

  result_sa_crp <- result_sa_crp %>%
    mutate(
      OR_CI = ifelse(Quartile == "Q1", "1.00 (Ref)",
                     sprintf("%.2f (%.2f-%.2f)", OR, CI_Lower, CI_Upper)),
      P_Formatted = ifelse(is.na(P_Value), "Ref",
                           ifelse(P_Value < 0.001, "<0.001",
                                  sprintf("%.3f", P_Value)))
    )

  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("              Model 3 + CRP 结果汇总                           \n")
  cat("═══════════════════════════════════════════════════════════════\n")
  print(result_sa_crp %>% select(Quartile, OR_CI, P_Formatted))

  # 提取Q4结果
  or_q4_crp <- result_sa_crp$OR[4]
  ci_lower_q4_crp <- result_sa_crp$CI_Lower[4]
  ci_upper_q4_crp <- result_sa_crp$CI_Upper[4]
  p_q4_crp <- result_sa_crp$P_Value[4]

  cat("\n📊 【关键结果】Q4 vs Q1:\n")
  cat("   Model 3：OR =", sprintf("%.2f", or_q4_main), "\n")
  cat("   Model 3 + CRP：OR =", sprintf("%.2f", or_q4_crp), "\n")

  or_attenuation <- (or_q4_main - or_q4_crp) / (or_q4_main - 1) * 100
  cat("\n📌 【效应衰减】\n")
  cat("   衰减比例：", sprintf("%.1f%%", or_attenuation), "\n")

  if (or_q4_crp > 1 && p_q4_crp < 0.05) {
    cat("   ✓ 调整CRP后SIRI效应仍然显著\n")
    cat("   → SIRI提供了超出一般炎症标志物的独立信息\n")
  } else if (or_q4_crp > 1 && p_q4_crp >= 0.05) {
    cat("   ⚠️ 调整CRP后显著性减弱但方向一致\n")
    cat("   → SIRI与CRP部分重叠，但有独立作用\n")
  } else {
    cat("   ⚠️⚠️ 调整CRP后关联消失\n")
    cat("   → SIRI可能主要反映一般炎症水平\n")
  }

  # 保存结果
  save(result_sa_crp, or_q4_crp, ci_lower_q4_crp, ci_upper_q4_crp, p_q4_crp,
       file = "敏感性分析/SA_CRP调整结果.RData")

  cat("\n✓ CRP调整分析完成！\n")

} else {
  cat("跳过CRP调整分析\n")
  or_q4_crp <- NA
  ci_lower_q4_crp <- NA
  ci_upper_q4_crp <- NA
  p_q4_crp <- NA
}


# --- Code Block 12 ---
# ==================== 单周期分析 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                单周期分析（验证时间一致性）                    ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# Step 1：检查周期变量
cat("\n【Step 1：检查周期分布】\n")

# 检查是否有cycle或year变量
has_cycle <- "cycle" %in% names(nhanes_complete)
has_year <- "year" %in% names(nhanes_complete)

cat("cycle变量存在：", has_cycle, "\n")
cat("year变量存在：", has_year, "\n\n")

if (has_cycle) {
  cycle_table <- table(nhanes_complete$cycle)
  print(cycle_table)
  available_cycles <- names(cycle_table)
  cat("\n可用周期：", paste(available_cycles, collapse = ", "), "\n")
  
} else if (has_year) {
  cat("尝试使用year变量创建周期分类\n")
  nhanes_complete <- nhanes_complete %>%
    mutate(cycle = case_when(
      year %in% c(2005, 2006) ~ "2005-2006",
      year %in% c(2007, 2008) ~ "2007-2008",
      TRUE ~ as.character(year)
    ))
  cycle_table <- table(nhanes_complete$cycle)
  print(cycle_table)
  has_cycle <- TRUE
  
} else {
  cat("❌ 无法确定周期信息，跳过单周期分析\n")
}

# 只有在有cycle变量时才继续
if (has_cycle) {
  
  # -------------------- 2005-2006周期 --------------------
  cat("\n【2005-2006周期分析】\n")
  
  # 根据cycle变量筛选
  data_2005_2006 <- nhanes_complete %>%
    filter(grepl("2005|2006", cycle))
  
  n_2005_2006 <- nrow(data_2005_2006)
  cat("样本量：", n_2005_2006, "\n")
  
  if (n_2005_2006 > 0) {
    # 检查是否有wtmec2yr权重变量
    if ("wtmec2yr" %in% names(data_2005_2006)) {
      weight_var <- "wtmec2yr"
    } else if ("weight_2yr" %in% names(data_2005_2006)) {
      weight_var <- "weight_2yr"
    } else {
      cat("⚠️ 找不到2年权重变量，使用4年权重\n")
      weight_var <- "weight_4yr"
    }
    
    # 重新设置survey design
    design_2005_2006 <- svydesign(
      id = ~psu,
      strata = ~strata,
      weights = as.formula(paste0("~", weight_var)),
      nest = TRUE,
      data = data_2005_2006
    )
    
    cat("✓ Survey design已设置（权重：", weight_var, "）\n")
    
    # 运行Model 3
    cat("运行Model 3...\n")
    model_2005_2006 <- svyglm(
      dry_eye_a ~ siri_quartile +
        age + gender_cat + race_cat + education_cat + pir +
        bmi_cat + smoking_status + drinking_status + diabetes_status + hypertension,
      design = design_2005_2006,
      family = quasibinomial()
    )
    
    # 提取Q4结果
    coef_sum <- summary(model_2005_2006)$coefficients
    if ("siri_quartileQ4" %in% rownames(coef_sum)) {
      est_2005 <- coef_sum["siri_quartileQ4", "Estimate"]
      se_2005 <- coef_sum["siri_quartileQ4", "Std. Error"]
      p_2005 <- coef_sum["siri_quartileQ4", "Pr(>|t|)"]
      
      or_2005 <- exp(est_2005)
      ci_lower_2005 <- exp(est_2005 - 1.96 * se_2005)
      ci_upper_2005 <- exp(est_2005 + 1.96 * se_2005)
      
      cat("\n📊 【2005-2006结果】Q4 vs Q1:\n")
      cat("   OR =", sprintf("%.2f (%.2f-%.2f)", or_2005, ci_lower_2005, ci_upper_2005), "\n")
      cat("   P =", sprintf("%.3f", p_2005), "\n")
    }
  } else {
    cat("⚠️ 2005-2006周期无数据，跳过\n")
    or_2005 <- NA
    ci_lower_2005 <- NA
    ci_upper_2005 <- NA
    p_2005 <- NA
  }
  
  # -------------------- 2007-2008周期 --------------------
  cat("\n【2007-2008周期分析】\n")
  
  data_2007_2008 <- nhanes_complete %>%
    filter(grepl("2007|2008", cycle))
  
  n_2007_2008 <- nrow(data_2007_2008)
  cat("样本量：", n_2007_2008, "\n")
  
  if (n_2007_2008 > 0) {
    # 检查权重变量
    if ("wtmec2yr" %in% names(data_2007_2008)) {
      weight_var <- "wtmec2yr"
    } else if ("weight_2yr" %in% names(data_2007_2008)) {
      weight_var <- "weight_2yr"
    } else {
      cat("⚠️ 找不到2年权重变量，使用4年权重\n")
      weight_var <- "weight_4yr"
    }
    
    design_2007_2008 <- svydesign(
      id = ~psu,
      strata = ~strata,
      weights = as.formula(paste0("~", weight_var)),
      nest = TRUE,
      data = data_2007_2008
    )
    
    cat("✓ Survey design已设置（权重：", weight_var, "）\n")
    
    cat("运行Model 3...\n")
    model_2007_2008 <- svyglm(
      dry_eye_a ~ siri_quartile +
        age + gender_cat + race_cat + education_cat + pir +
        bmi_cat + smoking_status + drinking_status + diabetes_status + hypertension,
      design = design_2007_2008,
      family = quasibinomial()
    )
    
    # 提取Q4结果
    coef_sum <- summary(model_2007_2008)$coefficients
    if ("siri_quartileQ4" %in% rownames(coef_sum)) {
      est_2007 <- coef_sum["siri_quartileQ4", "Estimate"]
      se_2007 <- coef_sum["siri_quartileQ4", "Std. Error"]
      p_2007 <- coef_sum["siri_quartileQ4", "Pr(>|t|)"]
      
      or_2007 <- exp(est_2007)
      ci_lower_2007 <- exp(est_2007 - 1.96 * se_2007)
      ci_upper_2007 <- exp(est_2007 + 1.96 * se_2007)
      
      cat("\n📊 【2007-2008结果】Q4 vs Q1:\n")
      cat("   OR =", sprintf("%.2f (%.2f-%.2f)", or_2007, ci_lower_2007, ci_upper_2007), "\n")
      cat("   P =", sprintf("%.3f", p_2007), "\n")
    }
  } else {
    cat("⚠️ 2007-2008周期无数据，跳过\n")
    or_2007 <- NA
    ci_lower_2007 <- NA
    ci_upper_2007 <- NA
    p_2007 <- NA
  }
  
  # -------------------- 一致性检验 --------------------
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("                单周期分析一致性检验                            \n")
  cat("═══════════════════════════════════════════════════════════════\n")
  
  comparison_cycle <- data.frame(
    Period = c("合并分析", "2005-2006", "2007-2008"),
    N = c(nrow(nhanes_complete), n_2005_2006, n_2007_2008),
    OR = c(or_q4_main, or_2005, or_2007),
    CI_Lower = c(ci_lower_q4_main, ci_lower_2005, ci_lower_2007),
    CI_Upper = c(ci_upper_q4_main, ci_upper_2005, ci_upper_2007),
    P = c(p_q4_main, p_2005, p_2007)
  ) %>%
    mutate(
      OR_CI = ifelse(is.na(OR), "N/A",
                     sprintf("%.2f (%.2f-%.2f)", OR, CI_Lower, CI_Upper)),
      P_Formatted = ifelse(is.na(P), "N/A",
                           ifelse(P < 0.001, "<0.001", sprintf("%.3f", P)))
    )
  
  print(comparison_cycle %>% select(Period, N, OR_CI, P_Formatted))
  
  # 检查一致性（仅当两个周期都有结果时）
  if (!is.na(or_2005) && !is.na(or_2007)) {
    or_range <- max(c(or_q4_main, or_2005, or_2007)) - min(c(or_q4_main, or_2005, or_2007))
    or_mean <- mean(c(or_q4_main, or_2005, or_2007))
    
    cat("\n📌 【一致性评估】\n")
    cat("OR范围：", sprintf("%.2f", or_range), "\n")
    cat("OR均值：", sprintf("%.2f", or_mean), "\n")
    cat("变异系数：", sprintf("%.1f%%", or_range / or_mean * 100), "\n")
    
    if (or_range / or_mean < 0.2) {
      cat("✓ 两个周期结果高度一致（变异<20%）\n")
    } else {
      cat("⚠️ 两个周期结果存在差异，需在Discussion中讨论\n")
    }
  }
  
  # 保存结果
  save(comparison_cycle, or_2005, or_2007, ci_lower_2005, ci_lower_2007,
       ci_upper_2005, ci_upper_2007, p_2005, p_2007,
       file = "敏感性分析/SA_单周期分析结果.RData")
  
  cat("\n✓ 单周期分析完成！\n")
  
} else {
  cat("\n跳过单周期分析（无周期信息）\n")
}


# --- Code Block 13 ---
# ==================== 创建敏感性分析汇总表（Table 4） ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                制作Table 4：敏感性分析汇总                     ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

library(kableExtra)
library(flextable)
library(officer)

# 汇总所有结果
table4_data <- tibble(
  编号 = c(
    "-",
    "SA-Exp1", "SA-Exp2", "SA-Exp3",
    "SA-Out1", "SA-Out2",
    "MI", "CRP", "2005-06", "2007-08"
  ),
  敏感性分析 = c(
    "主分析",
    "排除可疑血液病",
    "排除SIRI极端值",
    "排除血液病+极端值",
    "严格干眼症定义（VIQ031≥4）",
    "症状+用药定义",
    "多重插补处理缺失",
    "额外调整CRP",
    "单独分析2005-2006",
    "单独分析2007-2008"
  ),
  类型 = c(
    "-",
    "A类", "A类", "A类",
    "B类", "B类",
    "其他", "其他", "其他", "其他"
  ),
  样本量 = c(
    nrow(nhanes_complete),
    n_sa_exp1,
    n_sa_exp2,
    n_sa_exp3,
    nrow(nhanes_complete),
    nrow(nhanes_complete),
    nrow(nhanes_complete),
    sum(!is.na(nhanes_complete$crp)),
    n_2005_2006,
    n_2007_2008
  ),
  OR = c(
    or_q4_main,
    or_q4_exp1,
    or_q4_exp2,
    or_q4_exp3,
    or_q4_out1,
    or_q4_out2,
    or_mi,
    or_q4_crp,
    or_2005,
    or_2007
  ),
  CI_Lower = c(
    ci_lower_q4_main,
    ci_lower_q4_exp1,
    ci_lower_q4_exp2,
    ci_lower_q4_exp3,
    ci_lower_q4_out1,
    ci_lower_q4_out2,
    ci_lower_mi,
    ci_lower_q4_crp,
    ci_lower_2005,
    ci_lower_2007
  ),
  CI_Upper = c(
    ci_upper_q4_main,
    ci_upper_q4_exp1,
    ci_upper_q4_exp2,
    ci_upper_q4_exp3,
    ci_upper_q4_out1,
    ci_upper_q4_out2,
    ci_upper_mi,
    ci_upper_q4_crp,
    ci_upper_2005,
    ci_upper_2007
  ),
  P_Value = c(
    p_q4_main,
    p_q4_exp1,
    p_q4_exp2,
    p_q4_exp3,
    p_q4_out1,
    p_q4_out2,
    p_mi,
    p_q4_crp,
    p_2005,
    p_2007
  )
) %>%
  mutate(
    `OR (95%CI)` = sprintf("%.2f (%.2f-%.2f)", OR, CI_Lower, CI_Upper),
    `P值` = ifelse(P_Value < 0.001, "<0.001",
                   ifelse(P_Value < 0.01, sprintf("%.3f", P_Value),
                          sprintf("%.3f", P_Value)))
  ) %>%
  select(编号, 敏感性分析, 类型, 样本量, `OR (95%CI)`, `P值`)

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("            Table 4. 敏感性分析汇总                            \n")
cat("═══════════════════════════════════════════════════════════════\n")
print(table4_data)

# 保存为CSV
write.csv(table4_data,
          "敏感性分析/Table4_敏感性分析汇总.csv",
          row.names = FALSE,
          fileEncoding = "UTF-8")
cat("\n✓ CSV文件已保存：Table4_敏感性分析汇总.csv\n")

# 生成美化的HTML表格
table4_kable <- table4_data %>%
  kbl(caption = "Table 4. Sensitivity Analyses for the Association between SIRI and Dry Eye Disease (Q4 vs Q1)",
      align = c("l", "l", "c", "c", "c", "c"),
      escape = FALSE) %>%
  kable_classic(full_width = FALSE, html_font = "Cambria") %>%
  pack_rows("主分析", 1, 1, label_row_css = "background-color: #f0f0f0; font-weight: bold;") %>%
  pack_rows("A类：暴露变量相关", 2, 4, label_row_css = "background-color: #e6f2ff;") %>%
  pack_rows("B类：结局变量相关", 5, 6, label_row_css = "background-color: #e6ffe6;") %>%
  pack_rows("其他敏感性分析", 7, 10, label_row_css = "background-color: #fff5e6;") %>%
  footnote(
    general = c(
      "所有OR值对应SIRI Q4 vs Q1，调整Model 3的所有协变量（年龄、性别、种族、教育、家庭收入比、BMI、吸烟、饮酒、糖尿病、高血压）。",
      "A类：针对暴露变量（SIRI）或样本排除的敏感性分析。",
      "B类：针对结局变量（干眼症）定义调整的敏感性分析。",
      "MI = Multiple Imputation（多重插补）；CRP = C-reactive Protein（C反应蛋白）。"
    ),
    general_title = "注释：",
    footnote_as_chunk = TRUE
  )

# 保存为HTML
save_kable(table4_kable,
           "敏感性分析/Table4_敏感性分析汇总.html")
cat("✓ HTML文件已保存：Table4_敏感性分析汇总.html\n")

# 使用flextable导出为Word
table4_flex <- flextable(table4_data) %>%
  set_caption("Table 4. Sensitivity Analyses for the Association between SIRI and Dry Eye Disease (Q4 vs Q1)") %>%
  theme_vanilla() %>%
  autofit() %>%
  bold(part = "header") %>%
  bg(i = 1, bg = "#f0f0f0") %>%
  bg(i = 2:4, bg = "#e6f2ff") %>%
  bg(i = 5:6, bg = "#e6ffe6") %>%
  bg(i = 7:10, bg = "#fff5e6") %>%
  fontsize(size = 10, part = "all") %>%
  font(fontname = "Times New Roman", part = "all")

# 保存为Word
save_as_docx(table4_flex,
             path = "敏感性分析/Table4_敏感性分析汇总.docx")
cat("✓ Word文件已保存：Table4_敏感性分析汇总.docx\n")

cat("\n✓ Table 4制作完成！\n")


# --- Code Block 14 ---
# ==================== 准备森林图数据 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                准备敏感性分析森林图数据                        ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 从table4_data提取需要的数据
forest_data_sensitivity <- table4_data %>%
  mutate(
    OR_num = c(or_q4_main, or_q4_exp1, or_q4_exp2, or_q4_exp3,
               or_q4_out1, or_q4_out2, or_mi, or_q4_crp,
               or_2005, or_2007),
    CI_Lower_num = c(ci_lower_q4_main, ci_lower_q4_exp1, ci_lower_q4_exp2, ci_lower_q4_exp3,
                     ci_lower_q4_out1, ci_lower_q4_out2, ci_lower_mi, ci_lower_q4_crp,
                     ci_lower_2005, ci_lower_2007),
    CI_Upper_num = c(ci_upper_q4_main, ci_upper_q4_exp1, ci_upper_q4_exp2, ci_upper_q4_exp3,
                     ci_upper_q4_out1, ci_upper_q4_out2, ci_upper_mi, ci_upper_q4_crp,
                     ci_upper_2005, ci_upper_2007),
    # 添加行序号（反转顺序，从下到上显示）
    row_order = rev(1:10),
    # 创建显示标签
    label = 敏感性分析,
    label_factor = factor(label, levels = rev(label))
  )

cat("森林图数据准备完成\n")
print(forest_data_sensitivity %>% select(label, 类型, OR_num, `OR (95%CI)`))


# --- Code Block 15 ---
# ==================== 绘制ggplot2森林图 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                绘制敏感性分析森林图                            ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

library(ggplot2)
library(scales)

# 设置颜色方案
color_scheme <- c(
  "-" = "#E64B35",      # 主分析：红色
  "A类" = "#4DBBD5",    # A类：蓝色
  "B类" = "#00A087",    # B类：绿色
  "其他" = "#3C5488"    # 其他：深蓝
)

# 绘制森林图
p_forest_sensitivity <- ggplot(forest_data_sensitivity,
                               aes(x = OR_num, y = label_factor, color = 类型)) +
  # 置信区间线段
  geom_errorbarh(aes(xmin = CI_Lower_num, xmax = CI_Upper_num),
                 height = 0.3, linewidth = 1.2) +
  # OR点
  geom_point(size = 4, shape = 18) +
  # 参考线（OR = 1）
  geom_vline(xintercept = 1, linetype = "dashed", color = "gray40", linewidth = 0.8) +
  # X轴对数刻度
  scale_x_continuous(
    trans = "log10",
    breaks = c(0.5, 0.75, 1, 1.25, 1.5, 2),
    labels = c("0.5", "0.75", "1.0", "1.25", "1.5", "2.0"),
    limits = c(0.4, 2.5)
  ) +
  # 颜色设置
  scale_color_manual(values = color_scheme) +
  # 坐标轴标签
  labs(
    x = "Odds Ratio (95% CI)",
    y = "",
    title = "Figure S1. Sensitivity Analyses of SIRI and Dry Eye Disease Association",
    subtitle = "OR for highest (Q4) vs lowest (Q1) quartile of SIRI",
    color = "Analysis Type"
  ) +
  # 主题设置
  theme_bw(base_size = 12) +
  theme(
    plot.title = element_text(size = 14, face = "bold", hjust = 0),
    plot.subtitle = element_text(size = 11, hjust = 0, color = "gray40"),
    axis.text.y = element_text(size = 11, hjust = 0),
    axis.text.x = element_text(size = 10),
    axis.title.x = element_text(size = 12, face = "bold"),
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    legend.position = "bottom",
    legend.title = element_text(size = 11, face = "bold"),
    legend.text = element_text(size = 10),
    plot.margin = margin(10, 20, 10, 10)
  )

# 显示图形
print(p_forest_sensitivity)

# 保存图形
ggsave("敏感性分析/Figure_S1_Sensitivity_Forest_Plot.png",
       p_forest_sensitivity, width = 12, height = 8, dpi = 300)

ggsave("敏感性分析/Figure_S1_Sensitivity_Forest_Plot.pdf",
       p_forest_sensitivity, width = 12, height = 8)

cat("\n✓ 森林图已保存：\n")
cat("   - Figure_S1_Sensitivity_Forest_Plot.png\n")
cat("   - Figure_S1_Sensitivity_Forest_Plot.pdf\n")


# --- Code Block 16 ---
# ==================== Results部分文本模板 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                Results部分撰写模板                            ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

results_text <- "
### 3.5 Sensitivity Analyses

To test the robustness of our main findings, we conducted a comprehensive series of sensitivity analyses (Table 4, Figure S1).

**Exposure-related sensitivity analyses (Type A):** When excluding individuals with suspected hematologic disorders (n=35), the association remained in the same direction (SA-Exp1: OR {or_exp1}, 95%CI: {ci_exp1}, P={p_exp1}). Similar results were observed when excluding extreme SIRI values at the 1st and 99th percentiles (n=334) (SA-Exp2: OR {or_exp2}, 95%CI: {ci_exp2}) and when applying both exclusions simultaneously (n=357) (SA-Exp3: OR {or_exp3}, 95%CI: {ci_exp3}).

**Outcome-related sensitivity analyses (Type B):** Using a stricter definition of dry eye disease requiring frequent or constant symptoms (SA-Out1), the association was {direction_out1} (OR {or_out1}, 95%CI: {ci_out1}, P={p_out1}). When requiring both symptoms and artificial tear use (SA-Out2), the results remained {direction_out2} (OR {or_out2}, 95%CI: {ci_out2}).

**Other sensitivity analyses:** Multiple imputation for missing covariates yielded consistent results (pooled OR {or_mi}, 95%CI: {ci_mi}). After additional adjustment for CRP, the association {crp_result} (OR {or_crp}, 95%CI: {ci_crp}), {crp_interpretation}. Separate analyses for the 2005-2006 and 2007-2008 cycles showed {cycle_result} (2005-2006: OR {or_2005}, 95%CI: {ci_2005}; 2007-2008: OR {or_2007}, 95%CI: {ci_2007}).

Overall, these sensitivity analyses demonstrated {overall_conclusion} of the observed association between SIRI and dry eye disease.
"

# 填充实际数值
results_text_filled <- glue::glue(results_text,
  or_exp1 = sprintf("%.2f", or_q4_exp1),
  ci_exp1 = sprintf("%.2f-%.2f", ci_lower_q4_exp1, ci_upper_q4_exp1),
  p_exp1 = ifelse(p_q4_exp1 < 0.001, "<0.001", sprintf("%.3f", p_q4_exp1)),

  or_exp2 = sprintf("%.2f", or_q4_exp2),
  ci_exp2 = sprintf("%.2f-%.2f", ci_lower_q4_exp2, ci_upper_q4_exp2),

  or_exp3 = sprintf("%.2f", or_q4_exp3),
  ci_exp3 = sprintf("%.2f-%.2f", ci_lower_q4_exp3, ci_upper_q4_exp3),

  direction_out1 = ifelse(or_q4_out1 > or_q4_main, "slightly strengthened", "slightly attenuated"),
  or_out1 = sprintf("%.2f", or_q4_out1),
  ci_out1 = sprintf("%.2f-%.2f", ci_lower_q4_out1, ci_upper_q4_out1),
  p_out1 = ifelse(p_q4_out1 < 0.001, "<0.001", sprintf("%.3f", p_q4_out1)),

  direction_out2 = ifelse(p_q4_out2 < 0.05, "significant", "consistent in direction"),
  or_out2 = sprintf("%.2f", or_q4_out2),
  ci_out2 = sprintf("%.2f-%.2f", ci_lower_q4_out2, ci_upper_q4_out2),

  or_mi = sprintf("%.2f", or_mi),
  ci_mi = sprintf("%.2f-%.2f", ci_lower_mi, ci_upper_mi),

  crp_result = ifelse(p_q4_crp < 0.05, "persisted", "was attenuated but remained in the same direction"),
  or_crp = sprintf("%.2f", or_q4_crp),
  ci_crp = sprintf("%.2f-%.2f", ci_lower_q4_crp, ci_upper_q4_crp),
  crp_interpretation = ifelse(p_q4_crp < 0.05,
                              "suggesting that SIRI provides additional predictive information beyond general inflammation markers",
                              "indicating that SIRI may partially reflect general inflammatory status"),

  cycle_result = ifelse(abs(or_2005 - or_2007) / or_q4_main < 0.3,
                        "consistent associations across time periods",
                        "some variation across time periods"),
  or_2005 = sprintf("%.2f", or_2005),
  ci_2005 = sprintf("%.2f-%.2f", ci_lower_2005, ci_upper_2005),
  or_2007 = sprintf("%.2f", or_2007),
  ci_2007 = sprintf("%.2f-%.2f", ci_lower_2007, ci_upper_2007),

  overall_conclusion = ifelse(sum(c(or_q4_exp1, or_q4_exp2, or_q4_exp3, or_q4_out1, or_q4_out2) > 1) >= 4,
                              "the robustness",
                              "generally consistent directions, though with some variability in")
)

cat("\n")
cat("════════════════════════════使用）                     \n")
cat("═══════════════════════════════════════════════════════════════\n")
cat(results_text_filled)
cat("\n")

# 保存为文本文件
writeLines(results_text_filled, "文章/Results_Section_3.5_Sensitivity_Analyses.txt")
cat("\n✓ Results文本已保存：Results_Section_3.5_Sensitivity_Analyses.txt\n")


# --- Code Block 17 ---
# ==================== Discussion部分撰写要点 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                Discussion部分撰写要点                          ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

discussion_template <- "
### Discussion部分关于敏感性分析的内容

#### 在\"研究优势\"段落中：

Several sensitivity analyses were performed to ensure the robustness of our findings. First, we addressed potential confounding by hematologic disorders by excluding individuals with abnormal blood cell counts, and the results remained {stability_blood}. Second, we tested different definitions of dry eye disease, including stricter symptom criteria and requiring treatment use, which {stability_outcome}. Third, we controlled for CRP in addition to SIRI, {crp_finding}. Fourth, multiple imputation for missing data and separate analyses for each survey cycle demonstrated {temporal_finding}. These comprehensive sensitivity analyses {overall_assessment}.

#### 在\"研究局限性\"段落中：

...（其他局限性）...

Despite these limitations, our extensive sensitivity analyses demonstrated {robustness_level} across different analytical approaches, sample restrictions, and outcome definitions, which enhance confidence in the validity of our results.

#### 如果CRP调整后效应减弱（需要额外说明）：

The attenuation of the association after adjusting for CRP suggests that SIRI and CRP may share some common pathways in relation to dry eye disease. However, SIRI has practical advantages including lower cost, wider availability in routine clinical practice, and the ability to capture multiple aspects of immune dysregulation through the combination of neutrophil, monocyte, and lymphocyte counts.
"

# 根据实际结果填充模板
discussion_filled <- glue::glue(discussion_template,
  stability_blood = ifelse(abs(or_q4_exp1 - or_q4_main) / or_q4_main < 0.2,
                          "stable", "in the same direction"),

  stability_outcome = ifelse(all(c(or_q4_out1, or_q4_out2) > 1),
                             "all yielded consistent associations",
                             "generally supported the main findings"),

  crp_finding = ifelse(p_q4_crp < 0.05,
                      "confirming that SIRI provides unique information beyond general systemic inflammation",
                      "suggesting that SIRI may partially reflect general inflammatory status"),

  temporal_finding = ifelse(abs(or_2005 - or_2007) / or_q4_main < 0.3,
                           "temporal stability",
                           "reasonable consistency across time periods"),

  overall_assessment = ifelse(sum(c(or_q4_exp1, or_q4_exp2, or_q4_exp3, or_q4_out1, or_q4_out2) > 1) >= 4,
                              "strengthen the reliability of our conclusions",
                              "support the general consistency of our findings"),

  robustness_level = ifelse(sum(c(or_q4_exp1, or_q4_exp2, or_q4_exp3, or_q4_out1, or_q4_out2) > 1) >= 4,
                            "the robustness of the main findings",
                            "general consistency of the findings")
)

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("            Discussion部分文本要点（参考）                      \n")
cat("═══════════════════════════════════════════════════════════════\n")
cat(discussion_filled)
cat("\n")

# 保存为文本文件
writeLines(discussion_filled, "文章/Discussion_Sensitivity_Analyses_Points.txt")
cat("\n✓ Discussion要点已保存：Discussion_Sensitivity_Analyses_Points.txt\n")


# --- Code Block 18 ---
# ==================== 保存所有分析对象 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                保存敏感性分析对象                              ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 保存所有模型和结果
save(
  # A类模型
  model_sa_exp1, model_sa_exp2, model_sa_exp3,
  result_sa_exp1, result_sa_exp2, result_sa_exp3,

  # B类模型
  model_sa_out1, model_sa_out2,
  result_sa_out1, result_sa_out2,

  # 其他模型
  imp, results_mi_list,  # 多重插补
  model_sa_crp, result_sa_crp,  # CRP调整
  model_2005_2006, model_2007_2008,  # 单周期

  # 汇总数据
  table4_data,
  forest_data_sensitivity,
  comparison_a,
  comparison_b,
  comparison_cycle,

  # 关键结果
  or_q4_exp1, or_q4_exp2, or_q4_exp3,
  or_q4_out1, or_q4_out2,
  or_mi, or_q4_crp,
  or_2005, or_2007,

  file = "敏感性分析/Day23-24_Sensitivity_Objects.RData"
)

cat("\n✓ 所有对象已保存：Day23-24_Sensitivity_Objects.RData\n")

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("                                                                \n")
cat("        ✓✓✓ Day 23-24 敏感性分析全部完成！✓✓✓                 \n")
cat("                                                                \n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("═══════════════════════════════════════════════════════════════\n")

# 生成完成报告
completion_report <- sprintf("
╔═══════════════════════════════════════════════════════════════╗
║                    完成情况总结                                ║
╚═══════════════════════════════════════════════════════════════╝

【已完成的敏感性分析】
✓ A类（暴露变量）：3项
  - SA-Exp1: 排除可疑血液病
  - SA-Exp2: 排除SIRI极端值
  - SA-Exp3: 排除两者

✓ B类（结局变量）：2项
  - SA-Out1: 严格干眼症定义
  - SA-Out2: 症状+用药定义

✓ 其他类型：5项
  - 多重插补处理缺失
  - 额外调整CRP
  - 2005-2006单周期
  - 2007-2008单周期

【生成的文件】
✓ Table 4：敏感性分析汇总表（CSV/HTML/Word）
✓ Figure S1：敏感性分析森林图（PNG/PDF）
✓ Results文本模板
✓ Discussion要点文档
✓ RData对象文件

【稳健性评估】
- 方向一致性：%d/10项OR>1
- 主要结论：%s

【下一步工作】
→ Day 25：结果整理与图表制作
→ Day 26-35：论文撰写
→ Day 36-50：修改与投稿

祝研究顺利！🎯
",
sum(c(or_q4_exp1, or_q4_exp2, or_q4_exp3, or_q4_out1, or_q4_out2,
      or_mi, or_q4_crp, or_2005, or_2007) > 1, na.rm = TRUE),
ifelse(sum(c(or_q4_exp1, or_q4_exp2, or_q4_exp3, or_q4_out1, or_q4_out2) > 1) >= 4,
       "结果稳健，关联方向一致",
       "结果基本一致，部分分析存在差异")
)

cat(completion_report)

# 保存完成报告
writeLines(completion_report, "敏感性分析/Day23-24_Completion_Report.txt")
