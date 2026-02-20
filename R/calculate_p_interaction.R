# ==================== 计算亚组分析的P for Interaction ====================
# 目标：为每个分层变量计算交互作用P值
# 方法：在完全调整模型中加入 SIRI × 分层变量 的交互项，进行Wald检验

setwd("/Users/mayiding/Desktop/第一篇")

# 加载必要的包
library(survey)
library(dplyr)

cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║          计算P for Interaction（交互作用P值）                 ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# 加载数据
cat("加载数据...\n")
if (file.exists("亚组分析/Day21-22_Subgroup_Objects.RData")) {
  load("亚组分析/Day21-22_Subgroup_Objects.RData")
  cat("✓ Day21-22_Subgroup_Objects.RData 加载成功\n")
} else {
  stop("❌ 找不到亚组分析数据文件")
}

# 检查数据
cat("\n数据集: nhanes_complete\n")
cat("  样本量:", nrow(nhanes_complete), "\n")
cat("  变量数:", ncol(nhanes_complete), "\n")

# ==================== 定义交互作用检验函数 ====================

calculate_interaction_p <- function(design, outcome, exposure, stratify_var,
                                   covariates, stratify_label) {

  cat("\n【", stratify_label, "】\n", sep = "")

  # 检查变量是否存在
  if (!stratify_var %in% names(design$variables)) {
    cat("  ❌ 变量", stratify_var, "不存在\n")
    return(data.frame(Variable = stratify_label, P_Interaction = NA))
  }

  # 检查变量类型和取值
  var_values <- unique(design$variables[[stratify_var]])
  var_values <- var_values[!is.na(var_values)]
  cat("  变量取值:", paste(var_values, collapse = ", "), "\n")

  # 如果是连续变量或有多个水平，转换为因子
  if (length(var_values) > 2) {
    # 对于多分类变量（如race），保持原样
    cat("  变量类型: 多分类变量\n")
  } else if (length(var_values) == 2) {
    # 对于二分类变量，转换为因子
    cat("  变量类型: 二分类变量\n")
    design$variables[[stratify_var]] <- factor(design$variables[[stratify_var]])
  } else {
    cat("  ❌ 变量只有一个取值，无法进行交互检验\n")
    return(data.frame(Variable = stratify_label, P_Interaction = NA))
  }

  # 构建交互项公式
  # 完全调整模型 + 交互项
  formula_str <- paste0(
    outcome, " ~ ", exposure, " * ", stratify_var, " + ",
    paste(covariates, collapse = " + ")
  )

  cat("  公式:", formula_str, "\n")

  # 拟合包含交互项的模型
  tryCatch({
    model_int <- svyglm(
      as.formula(formula_str),
      design = design,
      family = quasibinomial()
    )

    # 检查模型是否成功
    if (is.null(coef(model_int))) {
      cat("  ❌ 模型拟合失败\n")
      return(data.frame(Variable = stratify_label, P_Interaction = NA))
    }

    # 获取交互项系数名称
    coef_names <- names(coef(model_int))
    interaction_terms <- grep(paste0(exposure, ".*:", stratify_var, "|",
                                    stratify_var, ".*:", exposure),
                             coef_names, value = TRUE)

    if (length(interaction_terms) == 0) {
      cat("  ❌ 未找到交互项\n")
      return(data.frame(Variable = stratify_label, P_Interaction = NA))
    }

    cat("  交互项:", paste(interaction_terms, collapse = ", "), "\n")

    # 使用regTermTest进行Wald检验
    library(survey)
    test_formula <- as.formula(paste0("~ ", exposure, ":", stratify_var))

    wald_test <- regTermTest(model_int, test_formula, method = "Wald")
    p_value <- wald_test$p

    cat("  P for interaction =", sprintf("%.4f", p_value), "\n")

    return(data.frame(
      Variable = stratify_label,
      P_Interaction = p_value,
      Interaction_Terms = paste(interaction_terms, collapse = "; ")
    ))

  }, error = function(e) {
    cat("  ❌ 错误:", conditionMessage(e), "\n")
    return(data.frame(Variable = stratify_label, P_Interaction = NA))
  })
}

# ==================== 设置变量 ====================

outcome <- "dry_eye_a"  # 0/1编码的二分类变量，1759例病例
exposure <- "siri_quartile"

# 完全调整模型的协变量（根据实际变量名）
# 注意：不包括分层变量本身
base_covariates <- c("age", "pir", "education_cat", "smoking_status", "bmi")

# 定义分层变量
stratification_vars <- list(
  list(var = "gender", label = "Sex",
       covariates = c(base_covariates, "race_cat", "diabetes_binary", "hypertension")),

  list(var = "age_group", label = "Age",
       covariates = c("pir", "education_cat", "smoking_status", "bmi",
                      "gender", "race_cat", "diabetes_binary", "hypertension")),

  list(var = "bmi_group", label = "BMI",
       covariates = c("age", "pir", "education_cat", "smoking_status",
                      "gender", "race_cat", "diabetes_binary", "hypertension")),

  list(var = "diabetes_binary", label = "Diabetes",
       covariates = c(base_covariates, "gender", "race_cat", "hypertension")),

  list(var = "hypertension", label = "Hypertension",
       covariates = c(base_covariates, "gender", "race_cat", "diabetes_binary")),

  list(var = "race_cat", label = "Race/Ethnicity",
       covariates = c(base_covariates, "gender", "diabetes_binary", "hypertension"))
)

# ==================== 执行交互检验 ====================

cat("\n")
cat("════════════════════════════════════════════════════════════════\n")
cat("                      开始计算交互作用P值                        \n")
cat("════════════════════════════════════════════════════════════════\n")

# 检查关键变量是否存在
cat("\n检查关键变量...\n")
key_vars <- c(outcome, exposure)
for (var in key_vars) {
  if (var %in% names(nhanes_design_subgroup$variables)) {
    cat("  ✓", var, "\n")
  } else {
    stop("  ❌ 变量", var, "不存在")
  }
}

# 对每个分层变量计算交互作用P值
interaction_results_new <- list()

for (i in seq_along(stratification_vars)) {
  strat <- stratification_vars[[i]]

  result <- calculate_interaction_p(
    design = nhanes_design_subgroup,
    outcome = outcome,
    exposure = exposure,
    stratify_var = strat$var,
    covariates = strat$covariates,
    stratify_label = strat$label
  )

  interaction_results_new[[i]] <- result
}

# 合并结果
p_interaction_final <- bind_rows(interaction_results_new)

# ==================== 输出结果 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                  P for Interaction 计算完成                   ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("【最终结果汇总】\n\n")
print(p_interaction_final)

cat("\n【格式化输出（用于Table 3）】\n\n")
p_interaction_formatted <- p_interaction_final %>%
  mutate(
    P_Formatted = ifelse(is.na(P_Interaction), "NA",
                        ifelse(P_Interaction < 0.001, "<0.001",
                              sprintf("%.3f", P_Interaction))),
    Significance = case_when(
      is.na(P_Interaction) ~ "",
      P_Interaction < 0.0083 ~ "**",  # Bonferroni校正阈值
      P_Interaction < 0.05 ~ "*",
      P_Interaction < 0.10 ~ "†",     # 边缘显著
      TRUE ~ ""
    )
  ) %>%
  select(Variable, P_Interaction, P_Formatted, Significance)

print(p_interaction_formatted)

cat("\n【说明】\n")
cat("** : P < 0.0083 (Bonferroni校正后显著，6次检验)\n")
cat("*  : P < 0.05 (名义显著)\n")
cat("†  : P < 0.10 (边缘显著)\n")

# 保存结果
save(p_interaction_final, p_interaction_formatted,
     file = "亚组分析/P_Interaction_Results.RData")
cat("\n✓ 结果已保存: 亚组分析/P_Interaction_Results.RData\n")

# 输出CSV格式（便于复制到表格）
write.csv(p_interaction_formatted,
          "亚组分析/P_Interaction_Results.csv",
          row.names = FALSE)
cat("✓ 结果已保存: 亚组分析/P_Interaction_Results.csv\n")

cat("\n✓ 全部完成！\n")
