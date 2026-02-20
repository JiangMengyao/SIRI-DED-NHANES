# ============================================================
# Script: 06_dose_response_rcs.R
# Purpose: Figure 2: Restricted cubic spline (RCS) analysis
# Project: SIRI and Dry Eye Disease (NHANES 2005-2008)
# Data: NHANES 2005-2006 and 2007-2008 cycles
# ============================================================

# --- Code Block 1 ---
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


# --- Code Block 2 ---
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


# --- Code Block 3 ---
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


# --- Code Block 4 ---
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


# --- Code Block 5 ---
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


# --- Code Block 6 ---
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


# --- Code Block 7 ---
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


# --- Code Block 8 ---
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


# --- Code Block 9 ---
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


# --- Code Block 10 ---
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


# --- Code Block 11 ---
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


# --- Code Block 12 ---
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


# --- Code Block 13 ---
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


# --- Code Block 14 ---
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


# --- Code Block 15 ---
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


# --- Code Block 16 ---
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


# --- Code Block 17 ---
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


# --- Code Block 18 ---
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


# --- Code Block 19 ---
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


# --- Code Block 20 ---
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


# --- Code Block 21 ---
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
