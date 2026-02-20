# ============================================================================
# 亚组分析 - P for Interaction 计算
# 方法：完全调整模型中加入 SIRI_quartile × 分层变量 交互项，Wald 检验
# ============================================================================

library(survey)
library(dplyr)

# ========================= 1. 配置 ==========================================

CONFIG <- list(
  outcome  = "dry_eye_a",
  exposure = "siri_quartile",
  data_path = "亚组分析/Day21-22_Subgroup_Objects.RData",
  out_rdata = "亚组分析/P_Interaction_Results.RData",
  out_csv   = "亚组分析/P_Interaction_Results.csv"
)

# 全部协变量（完全调整模型）
ALL_COVARIATES <- c(
  "age", "pir", "education_cat", "smoking_status", "bmi",
  "gender", "race_cat", "diabetes_binary", "hypertension"
)

# 分层变量：只需写变量名和标签，协变量由 ALL_COVARIATES 自动排除当前分层变量
STRATA <- list(
  list(var = "gender",          label = "Sex"),
  list(var = "age_group",       label = "Age",
       exclude_extra = "age"),
  list(var = "bmi_group",       label = "BMI",
       exclude_extra = "bmi"),
  list(var = "diabetes_binary", label = "Diabetes"),
  list(var = "hypertension",    label = "Hypertension"),
  list(var = "race_cat",        label = "Race/Ethnicity")
)

# ========================= 2. 工具函数 ======================================

#' 为给定分层变量生成协变量向量（自动排除分层变量及其连续形式）
get_covariates <- function(strat) {
  exclude <- c(strat$var, strat$exclude_extra)
  setdiff(ALL_COVARIATES, exclude)
}

#' 对单个分层变量计算交互作用 P 值
#' @return 一行 data.frame: Variable, P_Interaction, Interaction_Terms
test_interaction <- function(design, outcome, exposure, strat) {
  stratify_var <- strat$var
  covariates   <- get_covariates(strat)

  # --- 校验 ---
  missing <- setdiff(c(outcome, exposure, stratify_var, covariates),
                     names(design$variables))
  if (length(missing) > 0) {
    warning("[", strat$label, "] 缺少变量: ", paste(missing, collapse = ", "))
    return(make_row(strat$label, NA_real_, NA_character_))
  }

  vals <- na.omit(unique(design$variables[[stratify_var]]))
  if (length(vals) < 2) {
    warning("[", strat$label, "] 变量仅有一个取值，跳过")
    return(make_row(strat$label, NA_real_, NA_character_))
  }

  # 二分类变量确保为 factor
  if (length(vals) == 2 && !is.factor(design$variables[[stratify_var]])) {
    design$variables[[stratify_var]] <- factor(design$variables[[stratify_var]])
  }

  # --- 拟合交互模型 ---
  formula_str <- paste0(
    outcome, " ~ ", exposure, " * ", stratify_var,
    " + ", paste(covariates, collapse = " + ")
  )
  model <- svyglm(as.formula(formula_str),
                   design = design, family = quasibinomial())

  # --- 提取交互项 & Wald 检验 ---
  coef_names <- names(coef(model))
  int_pattern <- paste0(exposure, ".*:", stratify_var, "|",
                        stratify_var, ".*:", exposure)
  int_terms <- grep(int_pattern, coef_names, value = TRUE)

  if (length(int_terms) == 0) {
    warning("[", strat$label, "] 模型中未发现交互项")
    return(make_row(strat$label, NA_real_, NA_character_))
  }

  wald <- regTermTest(model,
                      as.formula(paste0("~ ", exposure, ":", stratify_var)),
                      method = "Wald")

  make_row(strat$label, wald$p, paste(int_terms, collapse = "; "))
}

#' 构造一行结果（内部辅助）
make_row <- function(label, p, terms = NA_character_) {
  data.frame(Variable = label,
             P_Interaction = p,
             Interaction_Terms = terms,
             stringsAsFactors = FALSE)
}

#' 格式化 P 值并标注显著性
#' @param df  data.frame，至少包含 Variable 和 P_Interaction 两列
#' @return    data.frame，新增 P_Formatted 和 Significance 两列
format_p_results <- function(df) {
  df %>%
    mutate(
      P_Formatted = ifelse(is.na(P_Interaction), "NA",
                           ifelse(P_Interaction < 0.001, "<0.001",
                                  sprintf("%.3f", P_Interaction))),
      Significance = case_when(
        is.na(P_Interaction)      ~ "",
        P_Interaction < 0.0083    ~ "**",
        P_Interaction < 0.05      ~ "*",
        P_Interaction < 0.10      ~ "\u2020",
        TRUE                      ~ ""
      )
    ) %>%
    select(Variable, P_Interaction, P_Formatted, Significance)
}

# ========================= 3. 主流程 ========================================

main <- function() {
  cat("===== P for Interaction 计算 =====\n\n")

  # 加载数据
  if (!file.exists(CONFIG$data_path)) stop("找不到数据文件: ", CONFIG$data_path)
  load(CONFIG$data_path, envir = .GlobalEnv)
  cat("数据加载完成 | 样本量:", nrow(nhanes_complete),
      " | 变量数:", ncol(nhanes_complete), "\n\n")

  # 逐一计算交互 P 值
  results <- lapply(STRATA, function(strat) {
    cat("[", strat$label, "] 计算中...\n")
    tryCatch(
      test_interaction(nhanes_design_subgroup, CONFIG$outcome,
                       CONFIG$exposure, strat),
      error = function(e) {
        cat("  -> 错误:", conditionMessage(e), "\n")
        make_row(strat$label, NA_real_, NA_character_)
      }
    )
  })
  p_interaction_final <- bind_rows(results)

  # 格式化结果
  p_interaction_formatted <- format_p_results(p_interaction_final)

  # 输出
  cat("\n===== 结果汇总 =====\n\n")
  print(p_interaction_formatted)

  # 保存
  save(p_interaction_final, p_interaction_formatted, file = CONFIG$out_rdata)
  write.csv(p_interaction_formatted, CONFIG$out_csv, row.names = FALSE)
  cat("\n结果已保存:\n  ", CONFIG$out_rdata, "\n  ", CONFIG$out_csv, "\n")
}

main()
