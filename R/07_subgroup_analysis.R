# ============================================================
# Script: 07_subgroup_analysis.R
# Purpose: Table 3 and Figure 3: Stratified analyses with interaction tests
# Project: SIRI and Dry Eye Disease (NHANES 2005-2008)
# Data: NHANES 2005-2006 and 2007-2008 cycles
# ============================================================

# --- Code Block 1 ---
# 错误做法：对子集使用普通glm
glm(dry_eye ~ siri_quartile, data = subset(data, gender == "Female"))

# 正确做法：使用svyglm + subset参数
svyglm(dry_eye ~ siri_quartile, design = subset(nhanes_design, gender == "Female"))


# --- Code Block 2 ---
# ==================== 环境设置 ====================
# 设置工作目录
setwd("/Users/mayiding/Desktop/第一篇")

# 安装必要的包（如未安装）
required_packages <- c(
  "survey",       # 复杂调查分析
  "dplyr",        # 数据处理
  "ggplot2",      # 可视化
  "forestplot",   # 专业森林图
  "meta",         # Meta分析工具（备用）
  "tidyr",        # 数据整理
  "broom",        # 模型结果整理
  "flextable",    # 表格导出
  "officer",      # Word导出
  "gridExtra",    # 图形排列
  "scales"        # 坐标轴刻度
)

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

cat("所有包加载完成！\n")


# --- Code Block 3 ---
# ==================== 加载数据 ====================

# 加载Day 18-19保存的回归分析对象
load("描述性分析/Day18-19_Regression_Objects.RData")

# ==================== 数据验证 ====================
cat("\n==================== 数据加载验证 ====================\n")
cat("分析样本量:", nrow(nhanes_complete), "\n")
cat("干眼症病例数:", sum(nhanes_complete$dry_eye_a == 1, na.rm = TRUE), "\n")
cat("干眼症患病率:", round(mean(nhanes_complete$dry_eye_a == 1, na.rm = TRUE) * 100, 1), "%\n")

# 验证survey design
cat("\nSurvey design状态:\n")
print(nhanes_design_complete)

# 验证SIRI四分位分布
cat("\nSIRI四分位组分布:\n")
print(table(nhanes_complete$siri_quartile))


# --- Code Block 4 ---
# ==================== 定义亚组分层变量 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    定义亚组分层变量                            ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 1. 性别（已有gender_cat变量）
cat("\n【1. 性别】\n")
print(table(nhanes_complete$gender_cat, useNA = "ifany"))

# 2. 年龄分组（<60岁 vs ≥60岁）
nhanes_complete$age_group <- ifelse(nhanes_complete$age < 60, "<60 years", "≥60 years")
nhanes_complete$age_group <- factor(nhanes_complete$age_group, 
                                     levels = c("<60 years", "≥60 years"))
cat("\n【2. 年龄分组】\n")
print(table(nhanes_complete$age_group, useNA = "ifany"))

# 3. BMI分组（<25 vs ≥25）
nhanes_complete$bmi_group <- ifelse(nhanes_complete$bmi < 25, 
                                     "Normal (<25)", 
                                     "Overweight/Obese (≥25)")
nhanes_complete$bmi_group <- factor(nhanes_complete$bmi_group,
                                     levels = c("Normal (<25)", "Overweight/Obese (≥25)"))
cat("\n【3. BMI分组】\n")
print(table(nhanes_complete$bmi_group, useNA = "ifany"))

# 4. 糖尿病状态（二分类：有/无，将前驱糖尿病归入"无"或单独考虑）
# 方案A：正常+前驱 vs 糖尿病
nhanes_complete$diabetes_group <- ifelse(nhanes_complete$diabetes_status == "Diabetes",
                                          "Yes", "No")
nhanes_complete$diabetes_group <- factor(nhanes_complete$diabetes_group,
                                          levels = c("No", "Yes"))
cat("\n【4. 糖尿病（二分类）】\n")
print(table(nhanes_complete$diabetes_group, useNA = "ifany"))

# 5. 高血压状态（已有hypertension变量，0/1或No/Yes）
# 确保为因子格式
if (!is.factor(nhanes_complete$hypertension)) {
  nhanes_complete$hypertension <- factor(nhanes_complete$hypertension,
                                          levels = c(0, 1),
                                          labels = c("No", "Yes"))
}
cat("\n【5. 高血压】\n")
print(table(nhanes_complete$hypertension, useNA = "ifany"))

# 6. 种族（简化分类）
# 保留原有race_cat，或创建简化版本
cat("\n【6. 种族】\n")
print(table(nhanes_complete$race_cat, useNA = "ifany"))

# 创建简化种族变量（合并小样本组）
nhanes_complete$race_simple <- as.character(nhanes_complete$race_cat)
nhanes_complete$race_simple <- ifelse(nhanes_complete$race_simple %in% 
                                        c("Other Hispanic", "Other Race"),
                                       "Other",
                                       nhanes_complete$race_simple)
nhanes_complete$race_simple <- factor(nhanes_complete$race_simple,
                                       levels = c("Non-Hispanic White", 
                                                  "Non-Hispanic Black",
                                                  "Mexican American",
                                                  "Other"))
cat("\n【6b. 种族（简化版）】\n")
print(table(nhanes_complete$race_simple, useNA = "ifany"))


# --- Code Block 5 ---
# ==================== 检查亚组样本量和事件数 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    各亚组样本量与事件数                        ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 创建汇总函数
check_subgroup <- function(data, var_name, var_label) {
  result <- data %>%
    group_by(!!sym(var_name)) %>%
    summarise(
      N = n(),
      Cases = sum(dry_eye_a == 1, na.rm = TRUE),
      Controls = sum(dry_eye_a == 0, na.rm = TRUE),
      Prevalence = round(mean(dry_eye_a == 1, na.rm = TRUE) * 100, 1)
    ) %>%
    mutate(Variable = var_label) %>%
    rename(Subgroup = !!sym(var_name))
  
  return(result)
}

# 检查各亚组
subgroup_summary <- bind_rows(
  check_subgroup(nhanes_complete, "gender_cat", "Sex"),
  check_subgroup(nhanes_complete, "age_group", "Age"),
  check_subgroup(nhanes_complete, "bmi_group", "BMI"),
  check_subgroup(nhanes_complete, "diabetes_group", "Diabetes"),
  check_subgroup(nhanes_complete, "hypertension", "Hypertension"),
  check_subgroup(nhanes_complete, "race_simple", "Race/Ethnicity")
)

# 打印汇总表
cat("\n")
print(subgroup_summary, n = 20)

# 检查样本量是否充足
cat("\n【样本量检查】\n")
insufficient <- subgroup_summary %>%
  filter(Cases < 50 | N < 200)

if (nrow(insufficient) > 0) {
  cat("⚠️ 以下亚组样本量可能不足（事件数<50或总数<200）:\n")
  print(insufficient)
} else {
  cat("✓ 所有亚组样本量充足\n")
}


# --- Code Block 6 ---
# ==================== 更新Survey Design ====================

# 添加新变量后需要重新创建survey design
options(survey.lonely.psu = "adjust")

nhanes_design_subgroup <- svydesign(
  id = ~psu,
  strata = ~strata,
  weights = ~weight_4yr,
  data = nhanes_complete,
  nest = TRUE
)

cat("\n✓ Survey design已更新\n")


# --- Code Block 7 ---
# ==================== 创建亚组分析函数 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    亚组分析函数定义                            ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 定义亚组回归分析函数
# 参数：
#   design: survey design对象
#   subset_expr: 子集条件表达式
#   subgroup_name: 亚组名称
#   covariates: 协变量（需排除分层变量本身）

run_subgroup_analysis <- function(design, subset_expr, subgroup_name, covariates) {
  
  # 创建子集设计
  sub_design <- subset(design, eval(parse(text = subset_expr)))
  
  # 获取子集样本量和事件数
  sub_data <- sub_design$variables
  n_total <- nrow(sub_data)
  n_cases <- sum(sub_data$dry_eye_a == 1, na.rm = TRUE)
  
  # 构建模型公式（使用SIRI四分位作为分类变量）
  # 为简化展示，亚组分析通常使用Q4 vs Q1的对比，或者连续变量
  # 这里使用siri_quartile作为分类变量
  formula <- as.formula(paste0("dry_eye_a ~ siri_quartile + ", 
                                paste(covariates, collapse = " + ")))
  
  # 尝试拟合模型
  tryCatch({
    model <- svyglm(formula, design = sub_design, family = quasibinomial())
    
    # 提取Q4 vs Q1的OR（Q4是第4行，索引为siri_quartileQ4）
    coef_summary <- summary(model)$coefficients
    conf_int <- confint(model)
    
    # 查找Q4的行
    q4_row <- grep("siri_quartileQ4", rownames(coef_summary))
    
    if (length(q4_row) > 0) {
      or <- exp(coef_summary[q4_row, "Estimate"])
      ci_lower <- exp(conf_int[q4_row, 1])
      ci_upper <- exp(conf_int[q4_row, 2])
      p_value <- coef_summary[q4_row, "Pr(>|t|)"]
    } else {
      # 如果Q4不存在（可能因为样本量不足）
      or <- NA
      ci_lower <- NA
      ci_upper <- NA
      p_value <- NA
    }
    
    result <- data.frame(
      Subgroup = subgroup_name,
      N = n_total,
      Cases = n_cases,
      OR = or,
      CI_Lower = ci_lower,
      CI_Upper = ci_upper,
      P_Value = p_value,
      Status = "Success"
    )
    
  }, error = function(e) {
    result <- data.frame(
      Subgroup = subgroup_name,
      N = n_total,
      Cases = n_cases,
      OR = NA,
      CI_Lower = NA,
      CI_Upper = NA,
      P_Value = NA,
      Status = paste("Error:", e$message)
    )
    return(result)
  })
  
  return(result)
}

# 备用函数：使用SIRI作为连续变量（每SD增加）
run_subgroup_analysis_continuous <- function(design, subset_expr, subgroup_name, covariates) {
  
  # 创建子集设计
  sub_design <- subset(design, eval(parse(text = subset_expr)))
  
  # 获取子集信息
  sub_data <- sub_design$variables
  n_total <- nrow(sub_data)
  n_cases <- sum(sub_data$dry_eye_a == 1, na.rm = TRUE)
  
  # 计算该亚组的SIRI标准差
  siri_sd <- sd(sub_data$siri, na.rm = TRUE)
  
  # 创建标准化SIRI变量
  sub_data$siri_per_sd <- sub_data$siri / siri_sd
  
  # 更新设计对象中的数据
  sub_design$variables <- sub_data
  
  # 构建模型公式
  formula <- as.formula(paste0("dry_eye_a ~ siri_per_sd + ", 
                                paste(covariates, collapse = " + ")))
  
  # 拟合模型
  tryCatch({
    model <- svyglm(formula, design = sub_design, family = quasibinomial())
    
    coef_summary <- summary(model)$coefficients
    conf_int <- confint(model)
    
    or <- exp(coef_summary["siri_per_sd", "Estimate"])
    ci_lower <- exp(conf_int["siri_per_sd", 1])
    ci_upper <- exp(conf_int["siri_per_sd", 2])
    p_value <- coef_summary["siri_per_sd", "Pr(>|t|)"]
    
    result <- data.frame(
      Subgroup = subgroup_name,
      N = n_total,
      Cases = n_cases,
      OR = or,
      CI_Lower = ci_lower,
      CI_Upper = ci_upper,
      P_Value = p_value,
      SIRI_SD = siri_sd,
      Status = "Success"
    )
    
  }, error = function(e) {
    result <- data.frame(
      Subgroup = subgroup_name,
      N = n_total,
      Cases = n_cases,
      OR = NA,
      CI_Lower = NA,
      CI_Upper = NA,
      P_Value = NA,
      SIRI_SD = NA,
      Status = paste("Error:", e$message)
    )
  })
  
  return(result)
}

cat("✓ 亚组分析函数已定义\n")


# --- Code Block 8 ---
# ==================== 执行亚组分析 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    执行亚组分析                                ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 定义基础协变量（Model 3，不含饮酒）
base_covariates <- c("age", "gender_cat", "race_cat", "education_cat", 
                     "pir", "bmi", "smoking_status", "diabetes_status", "hypertension")

# 初始化结果列表
subgroup_results <- list()

# ------------------
# 1. 性别亚组
# ------------------
cat("\n【1. 性别亚组分析】\n")
# 男性
covars_sex <- setdiff(base_covariates, "gender_cat")  # 排除性别本身
subgroup_results[["Male"]] <- run_subgroup_analysis(
  design = nhanes_design_subgroup,
  subset_expr = "gender_cat == 'Male'",
  subgroup_name = "Male",
  covariates = covars_sex
)
cat("  男性分析完成\n")

# 女性
subgroup_results[["Female"]] <- run_subgroup_analysis(
  design = nhanes_design_subgroup,
  subset_expr = "gender_cat == 'Female'",
  subgroup_name = "Female",
  covariates = covars_sex
)
cat("  女性分析完成\n")

# ------------------
# 2. 年龄亚组
# ------------------
cat("\n【2. 年龄亚组分析】\n")
# <60岁
subgroup_results[["Age <60"]] <- run_subgroup_analysis(
  design = nhanes_design_subgroup,
  subset_expr = "age_group == '<60 years'",
  subgroup_name = "<60 years",
  covariates = base_covariates
)
cat("  <60岁分析完成\n")

# ≥60岁
subgroup_results[["Age ≥60"]] <- run_subgroup_analysis(
  design = nhanes_design_subgroup,
  subset_expr = "age_group == '≥60 years'",
  subgroup_name = "≥60 years",
  covariates = base_covariates
)
cat("  ≥60岁分析完成\n")

# ------------------
# 3. BMI亚组
# ------------------
cat("\n【3. BMI亚组分析】\n")
covars_bmi <- setdiff(base_covariates, "bmi")  # 排除BMI连续变量
# 正常体重
subgroup_results[["BMI Normal"]] <- run_subgroup_analysis(
  design = nhanes_design_subgroup,
  subset_expr = "bmi_group == 'Normal (<25)'",
  subgroup_name = "BMI <25",
  covariates = covars_bmi
)
cat("  正常体重分析完成\n")

# 超重/肥胖
subgroup_results[["BMI Overweight"]] <- run_subgroup_analysis(
  design = nhanes_design_subgroup,
  subset_expr = "bmi_group == 'Overweight/Obese (≥25)'",
  subgroup_name = "BMI ≥25",
  covariates = covars_bmi
)
cat("  超重/肥胖分析完成\n")

# ------------------
# 4. 糖尿病亚组
# ------------------
cat("\n【4. 糖尿病亚组分析】\n")
covars_dm <- setdiff(base_covariates, "diabetes_status")
# 无糖尿病
subgroup_results[["DM No"]] <- run_subgroup_analysis(
  design = nhanes_design_subgroup,
  subset_expr = "diabetes_group == 'No'",
  subgroup_name = "No diabetes",
  covariates = covars_dm
)
cat("  无糖尿病分析完成\n")

# 有糖尿病
subgroup_results[["DM Yes"]] <- run_subgroup_analysis(
  design = nhanes_design_subgroup,
  subset_expr = "diabetes_group == 'Yes'",
  subgroup_name = "Diabetes",
  covariates = covars_dm
)
cat("  有糖尿病分析完成\n")

# ------------------
# 5. 高血压亚组
# ------------------
cat("\n【5. 高血压亚组分析】\n")
covars_htn <- setdiff(base_covariates, "hypertension")
# 无高血压
subgroup_results[["HTN No"]] <- run_subgroup_analysis(
  design = nhanes_design_subgroup,
  subset_expr = "hypertension == 'No'",
  subgroup_name = "No hypertension",
  covariates = covars_htn
)
cat("  无高血压分析完成\n")

# 有高血压
subgroup_results[["HTN Yes"]] <- run_subgroup_analysis(
  design = nhanes_design_subgroup,
  subset_expr = "hypertension == 'Yes'",
  subgroup_name = "Hypertension",
  covariates = covars_htn
)
cat("  有高血压分析完成\n")

# ------------------
# 6. 种族亚组
# ------------------
cat("\n【6. 种族亚组分析】\n")
covars_race <- setdiff(base_covariates, "race_cat")

# 非西班牙裔白人
subgroup_results[["NHW"]] <- run_subgroup_analysis(
  design = nhanes_design_subgroup,
  subset_expr = "race_simple == 'Non-Hispanic White'",
  subgroup_name = "Non-Hispanic White",
  covariates = covars_race
)
cat("  非西班牙裔白人分析完成\n")

# 非西班牙裔黑人
subgroup_results[["NHB"]] <- run_subgroup_analysis(
  design = nhanes_design_subgroup,
  subset_expr = "race_simple == 'Non-Hispanic Black'",
  subgroup_name = "Non-Hispanic Black",
  covariates = covars_race
)
cat("  非西班牙裔黑人分析完成\n")

# 墨西哥裔美国人
subgroup_results[["MA"]] <- run_subgroup_analysis(
  design = nhanes_design_subgroup,
  subset_expr = "race_simple == 'Mexican American'",
  subgroup_name = "Mexican American",
  covariates = covars_race
)
cat("  墨西哥裔美国人分析完成\n")

# 其他
subgroup_results[["Other Race"]] <- run_subgroup_analysis(
  design = nhanes_design_subgroup,
  subset_expr = "race_simple == 'Other'",
  subgroup_name = "Other",
  covariates = covars_race
)
cat("  其他种族分析完成\n")

# ------------------
# 合并结果
# ------------------
subgroup_results_df <- bind_rows(subgroup_results)

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    亚组分析结果汇总                            ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")
print(subgroup_results_df)


# --- Code Block 9 ---
# ==================== 交互作用检验 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    交互作用检验                                ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 定义交互作用检验函数
# 使用SIRI四分位的数值编码与分层变量的交互项
test_interaction <- function(design, stratify_var, stratify_label) {
  
  # 创建交互模型公式
  # 使用siri_q_num（SIRI四分位的数值编码，1-4）作为趋势变量
  formula_interaction <- as.formula(paste0(
    "dry_eye_a ~ siri_q_num * ", stratify_var, " + ",
    "age + gender_cat + race_cat + education_cat + pir + ",
    "bmi + smoking_status + diabetes_status + hypertension"
  ))
  
  # 根据分层变量调整公式（避免重复包含）
  if (stratify_var == "gender_cat") {
    formula_interaction <- as.formula(paste0(
      "dry_eye_a ~ siri_q_num * gender_cat + ",
      "age + race_cat + education_cat + pir + ",
      "bmi + smoking_status + diabetes_status + hypertension"
    ))
  } else if (stratify_var == "age_group") {
    formula_interaction <- as.formula(paste0(
      "dry_eye_a ~ siri_q_num * age_group + ",
      "gender_cat + race_cat + education_cat + pir + ",
      "bmi + smoking_status + diabetes_status + hypertension"
    ))
  } else if (stratify_var == "bmi_group") {
    formula_interaction <- as.formula(paste0(
      "dry_eye_a ~ siri_q_num * bmi_group + ",
      "age + gender_cat + race_cat + education_cat + pir + ",
      "smoking_status + diabetes_status + hypertension"
    ))
  } else if (stratify_var == "diabetes_group") {
    formula_interaction <- as.formula(paste0(
      "dry_eye_a ~ siri_q_num * diabetes_group + ",
      "age + gender_cat + race_cat + education_cat + pir + ",
      "bmi + smoking_status + hypertension"
    ))
  } else if (stratify_var == "hypertension") {
    formula_interaction <- as.formula(paste0(
      "dry_eye_a ~ siri_q_num * hypertension + ",
      "age + gender_cat + race_cat + education_cat + pir + ",
      "bmi + smoking_status + diabetes_status"
    ))
  } else if (stratify_var == "race_simple") {
    formula_interaction <- as.formula(paste0(
      "dry_eye_a ~ siri_q_num * race_simple + ",
      "age + gender_cat + education_cat + pir + ",
      "bmi + smoking_status + diabetes_status + hypertension"
    ))
  }
  
  # 拟合交互模型
  result <- tryCatch({
    model_int <- svyglm(formula_interaction,
                         design = design,
                         family = quasibinomial())

    # 提取交互项的P值
    coef_summary <- summary(model_int)$coefficients

    # 查找交互项（包含":"的行）
    int_rows <- grep(":", rownames(coef_summary))

    if (length(int_rows) > 0) {
      # 使用Wald检验整体检验交互项
      # 提取交互项名称
      int_terms <- rownames(coef_summary)[int_rows]

      # 构建检验公式
      test_formula <- as.formula(paste0("~ ", paste(int_terms, collapse = " + ")))

      # 执行Wald检验
      wald_test <- regTermTest(model_int, test_formula, method = "Wald")
      p_interaction <- wald_test$p
    } else {
      p_interaction <- NA
    }

    data.frame(
      Variable = stratify_label,
      P_Interaction = p_interaction
    )

  }, error = function(e) {
    data.frame(
      Variable = stratify_label,
      P_Interaction = NA
    )
  })

  return(result)
}

# 确保siri_q_num变量存在（Day 18-19应该已创建）
if (!"siri_q_num" %in% names(nhanes_complete)) {
  nhanes_complete$siri_q_num <- as.numeric(nhanes_complete$siri_quartile)
}

# 更新survey design
nhanes_design_subgroup <- svydesign(
  id = ~psu,
  strata = ~strata,
  weights = ~weight_4yr,
  data = nhanes_complete,
  nest = TRUE
)

# 执行各变量的交互检验
cat("\n计算交互作用P值...\n")

interaction_results <- bind_rows(
  test_interaction(nhanes_design_subgroup, "gender_cat", "Sex"),
  test_interaction(nhanes_design_subgroup, "age_group", "Age (<60 vs ≥60)"),
  test_interaction(nhanes_design_subgroup, "bmi_group", "BMI (<25 vs ≥25)"),
  test_interaction(nhanes_design_subgroup, "diabetes_group", "Diabetes"),
  test_interaction(nhanes_design_subgroup, "hypertension", "Hypertension"),
  test_interaction(nhanes_design_subgroup, "race_simple", "Race/Ethnicity")
)

# 格式化P值
interaction_results$P_Interaction_Formatted <- sapply(
  interaction_results$P_Interaction,
  function(p) {
    if (is.na(p)) return("NA")
    else if (p < 0.001) return("<0.001")
    else return(round(p, 3))
  }
)

cat("\n交互作用检验结果:\n")
print(interaction_results)

# 检查是否有显著交互作用
sig_interactions <- interaction_results %>%
  filter(P_Interaction < 0.05)

if (nrow(sig_interactions) > 0) {
  cat("\n⚠️ 发现显著交互作用 (P < 0.05):\n")
  print(sig_interactions)
} else {
  cat("\n✓ 未发现显著交互作用 (所有P ≥ 0.05)\n")
}

# 边缘显著
marginal_interactions <- interaction_results %>%
  filter(P_Interaction >= 0.05 & P_Interaction < 0.10)

if (nrow(marginal_interactions) > 0) {
  cat("\n📌 边缘显著交互作用 (0.05 ≤ P < 0.10):\n")
  print(marginal_interactions)
}


# --- Code Block 10 ---
# ==================== 合并结果 ====================

# 为亚组结果添加分组标签
subgroup_final <- subgroup_results_df %>%
  mutate(
    Variable = case_when(
      Subgroup %in% c("Male", "Female") ~ "Sex",
      Subgroup %in% c("<60 years", "≥60 years") ~ "Age",
      Subgroup %in% c("BMI <25", "BMI ≥25") ~ "BMI",
      Subgroup %in% c("No diabetes", "Diabetes") ~ "Diabetes",
      Subgroup %in% c("No hypertension", "Hypertension") ~ "Hypertension",
      Subgroup %in% c("Non-Hispanic White", "Non-Hispanic Black", 
                      "Mexican American", "Other") ~ "Race/Ethnicity",
      TRUE ~ "Other"
    )
  )

# 合并交互P值
subgroup_with_interaction <- subgroup_final %>%
  left_join(interaction_results, by = "Variable")

# 格式化输出
subgroup_with_interaction <- subgroup_with_interaction %>%
  mutate(
    OR_CI = ifelse(is.na(OR), "NC",
                   paste0(round(OR, 2), " (", 
                          round(CI_Lower, 2), "-", 
                          round(CI_Upper, 2), ")")),
    P_Formatted = ifelse(is.na(P_Value), "NC",
                         ifelse(P_Value < 0.001, "<0.001", 
                                round(P_Value, 3)))
  )

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    亚组分析完整结果                            ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

print(subgroup_with_interaction %>% 
        select(Variable, Subgroup, N, Cases, OR_CI, P_Formatted, P_Interaction_Formatted))


# --- Code Block 11 ---
# ==================== 准备森林图数据 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    准备森林图数据                              ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 创建森林图数据框
forest_data <- subgroup_with_interaction %>%
  filter(!is.na(OR)) %>%  # 排除无法计算的亚组
  select(Variable, Subgroup, N, Cases, OR, CI_Lower, CI_Upper, P_Value, P_Interaction_Formatted) %>%
  # 添加行顺序
  mutate(
    row_order = case_when(
      Variable == "Sex" & Subgroup == "Male" ~ 1,
      Variable == "Sex" & Subgroup == "Female" ~ 2,
      Variable == "Age" & Subgroup == "<60 years" ~ 3,
      Variable == "Age" & Subgroup == "≥60 years" ~ 4,
      Variable == "BMI" & Subgroup == "BMI <25" ~ 5,
      Variable == "BMI" & Subgroup == "BMI ≥25" ~ 6,
      Variable == "Diabetes" & Subgroup == "No diabetes" ~ 7,
      Variable == "Diabetes" & Subgroup == "Diabetes" ~ 8,
      Variable == "Hypertension" & Subgroup == "No hypertension" ~ 9,
      Variable == "Hypertension" & Subgroup == "Hypertension" ~ 10,
      Variable == "Race/Ethnicity" & Subgroup == "Non-Hispanic White" ~ 11,
      Variable == "Race/Ethnicity" & Subgroup == "Non-Hispanic Black" ~ 12,
      Variable == "Race/Ethnicity" & Subgroup == "Mexican American" ~ 13,
      Variable == "Race/Ethnicity" & Subgroup == "Other" ~ 14,
      TRUE ~ 99
    )
  ) %>%
  arrange(row_order)

# 添加分组行（用于分隔）
cat("\n森林图数据准备完成\n")
print(forest_data)


# --- Code Block 12 ---
# ==================== ggplot2森林图 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    绘制森林图                                  ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

library(ggplot2)

# 创建用于绘图的数据
forest_plot_data <- forest_data %>%
  mutate(
    # 创建显示标签
    label = paste0(Subgroup, " (n=", N, ")"),
    # 创建OR文本
    OR_text = paste0(round(OR, 2), " (", round(CI_Lower, 2), "-", round(CI_Upper, 2), ")"),
    # 转换为因子以固定顺序（反转顺序以便从上到下显示）
    label_factor = factor(label, levels = rev(label))
  )

# 添加分组标签（只在每组第一行显示）
forest_plot_data <- forest_plot_data %>%
  group_by(Variable) %>%
  mutate(
    var_label = ifelse(row_number() == 1, Variable, "")
  ) %>%
  ungroup()

# 获取每个变量的P for interaction（只在每组第一行显示）
forest_plot_data <- forest_plot_data %>%
  group_by(Variable) %>%
  mutate(
    P_int_display = ifelse(row_number() == 1, P_Interaction_Formatted, "")
  ) %>%
  ungroup()

# 绘制森林图
p_forest <- ggplot(forest_plot_data, aes(x = OR, y = label_factor)) +
  # 置信区间线段
  geom_errorbarh(aes(xmin = CI_Lower, xmax = CI_Upper), 
                 height = 0.2, color = "steelblue", linewidth = 0.8) +
  # OR点
  geom_point(size = 3, color = "steelblue", shape = 18) +
  # 参考线（OR = 1）
  geom_vline(xintercept = 1, linetype = "dashed", color = "gray50") +
  # X轴对数刻度
  scale_x_log10(
    breaks = c(0.5, 0.75, 1, 1.25, 1.5, 2, 2.5),
    labels = c("0.5", "0.75", "1.0", "1.25", "1.5", "2.0", "2.5"),
    limits = c(0.4, 3)
  ) +
  # 坐标轴标签
  labs(
    x = "Odds Ratio (95% CI)",
    y = "",
    title = "Figure 3. Subgroup Analysis of SIRI and Dry Eye Disease",
    subtitle = "OR for highest (Q4) vs lowest (Q1) quartile of SIRI"
  ) +
  # 主题设置
  theme_bw() +
  theme(
    plot.title = element_text(size = 14, face = "bold", hjust = 0),
    plot.subtitle = element_text(size = 11, hjust = 0, color = "gray40"),
    axis.text.y = element_text(size = 10, hjust = 0),
    axis.text.x = element_text(size = 10),
    axis.title.x = element_text(size = 12, face = "bold"),
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    plot.margin = margin(10, 80, 10, 10)  # 为右侧注释留空间
  )

# 显示图形
print(p_forest)

# 保存图形
ggsave("亚组分析/Figure3_Forest_Plot_Basic.png", 
       p_forest, width = 10, height = 8, dpi = 300)

cat("\n基础森林图已保存: Figure3_Forest_Plot_Basic.png\n")


# --- Code Block 13 ---
# ==================== forestplot包专业森林图 ====================

library(forestplot)

# 准备forestplot所需的表格数据
# 创建表头
tabletext <- cbind(
  c("Subgroup", forest_plot_data$label),
  c("N", as.character(forest_plot_data$N)),
  c("Cases", as.character(forest_plot_data$Cases)),
  c("OR (95% CI)", forest_plot_data$OR_text),
  c("P interaction", c(
    forest_plot_data$P_int_display[1],  # Sex
    "",
    forest_plot_data$P_int_display[3],  # Age
    "",
    forest_plot_data$P_int_display[5],  # BMI
    "",
    forest_plot_data$P_int_display[7],  # Diabetes
    "",
    forest_plot_data$P_int_display[9],  # Hypertension
    "",
    forest_plot_data$P_int_display[11], # Race
    "", "", ""
  ))
)

# 准备OR和CI数据（第一行是表头，用NA）
mean_values <- c(NA, forest_plot_data$OR)
lower_values <- c(NA, forest_plot_data$CI_Lower)
upper_values <- c(NA, forest_plot_data$CI_Upper)

# 绘制专业森林图
png("亚组分析/Figure3_Forest_Plot_Professional.png", 
    width = 12, height = 10, units = "in", res = 300)

forestplot(
  tabletext,
  mean = mean_values,
  lower = lower_values,
  upper = upper_values,
  is.summary = c(TRUE, rep(FALSE, nrow(forest_plot_data))),  # 表头加粗
  zero = 1,
  xlog = TRUE,
  clip = c(0.3, 4),
  xticks = c(0.5, 0.75, 1, 1.5, 2, 3),
  xlab = "Odds Ratio (95% CI)",
  col = fpColors(
    box = "steelblue",
    line = "steelblue",
    summary = "darkblue",
    zero = "gray50"
  ),
  txt_gp = fpTxtGp(
    label = gpar(cex = 0.9),
    ticks = gpar(cex = 0.8),
    xlab = gpar(cex = 1, fontface = "bold")
  ),
  boxsize = 0.15,
  lineheight = unit(1, "cm"),
  graphwidth = unit(8, "cm"),
  title = "Figure 3. Subgroup Analysis of SIRI and Dry Eye Disease\nOR for highest (Q4) vs lowest (Q1) quartile of SIRI"
)

dev.off()

cat("\n专业森林图已保存: Figure3_Forest_Plot_Professional.png\n")


# --- Code Block 14 ---
# ==================== 增强版ggplot2森林图 ====================

# 创建带分组标签的数据
forest_enhanced <- forest_plot_data %>%
  mutate(
    # 创建组合标签
    display_label = case_when(
      var_label != "" ~ paste0("  ", var_label, ": ", Subgroup),
      TRUE ~ paste0("      ", Subgroup)
    ),
    # 添加间隔行
    y_position = rev(1:nrow(forest_plot_data))
  )

# 创建分组背景
group_bg <- forest_enhanced %>%
  group_by(Variable) %>%
  summarise(
    ymin = min(y_position) - 0.4,
    ymax = max(y_position) + 0.4
  ) %>%
  mutate(
    fill = rep(c("gray95", "white"), length.out = n())
  )

# 绘制增强版森林图
p_forest_enhanced <- ggplot() +
  # 分组背景
  geom_rect(data = group_bg,
            aes(xmin = 0.3, xmax = 4, ymin = ymin, ymax = ymax, fill = fill),
            alpha = 0.5) +
  scale_fill_identity() +
  # 参考线
  geom_vline(xintercept = 1, linetype = "dashed", color = "#e74c3c", linewidth = 0.8) +
  # 置信区间
  geom_errorbarh(data = forest_enhanced,
                 aes(y = y_position, xmin = CI_Lower, xmax = CI_Upper),
                 height = 0.25, color = "#2980b9", linewidth = 0.9) +
  # OR点
  geom_point(data = forest_enhanced,
             aes(x = OR, y = y_position),
             size = 4, color = "#2980b9", shape = 18) +
  # Y轴标签
  scale_y_continuous(
    breaks = forest_enhanced$y_position,
    labels = forest_enhanced$Subgroup,
    expand = c(0.02, 0.02)
  ) +
  # X轴对数刻度
  scale_x_log10(
    breaks = c(0.5, 0.75, 1, 1.25, 1.5, 2, 3),
    labels = c("0.5", "0.75", "1.0", "1.25", "1.5", "2.0", "3.0"),
    limits = c(0.35, 4)
  ) +
  # 添加右侧注释（OR和CI）
  geom_text(data = forest_enhanced,
            aes(x = 3.5, y = y_position, label = OR_text),
            hjust = 0, size = 3.2, color = "gray30") +
  # 添加分组标题
  annotate("text", x = 0.38, y = max(forest_enhanced$y_position[forest_enhanced$Variable == "Sex"]) + 0.5,
           label = "Sex", hjust = 0, fontface = "bold", size = 3.5) +
  annotate("text", x = 0.38, y = max(forest_enhanced$y_position[forest_enhanced$Variable == "Age"]) + 0.5,
           label = "Age", hjust = 0, fontface = "bold", size = 3.5) +
  annotate("text", x = 0.38, y = max(forest_enhanced$y_position[forest_enhanced$Variable == "BMI"]) + 0.5,
           label = "BMI", hjust = 0, fontface = "bold", size = 3.5) +
  annotate("text", x = 0.38, y = max(forest_enhanced$y_position[forest_enhanced$Variable == "Diabetes"]) + 0.5,
           label = "Diabetes", hjust = 0, fontface = "bold", size = 3.5) +
  annotate("text", x = 0.38, y = max(forest_enhanced$y_position[forest_enhanced$Variable == "Hypertension"]) + 0.5,
           label = "Hypertension", hjust = 0, fontface = "bold", size = 3.5) +
  annotate("text", x = 0.38, y = max(forest_enhanced$y_position[forest_enhanced$Variable == "Race/Ethnicity"]) + 0.5,
           label = "Race/Ethnicity", hjust = 0, fontface = "bold", size = 3.5) +
  # 坐标轴标签
  labs(
    x = "Odds Ratio (95% CI)",
    y = ""
  ) +
  # 主题
  theme_minimal() +
  theme(
    axis.text.y = element_text(size = 10, hjust = 1),
    axis.text.x = element_text(size = 10),
    axis.title.x = element_text(size = 12, face = "bold", margin = margin(t = 10)),
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_line(color = "gray90"),
    plot.margin = margin(20, 120, 10, 10)
  ) +
  # 扩展绘图区域
  coord_cartesian(clip = "off")

# 显示
print(p_forest_enhanced)

# 保存
ggsave("亚组分析/Figure3_Forest_Plot_Enhanced.png",
       p_forest_enhanced, width = 12, height = 10, dpi = 600)
ggsave("亚组分析/Figure3_Forest_Plot_Enhanced.pdf",
       p_forest_enhanced, width = 12, height = 10)

cat("\n增强版森林图已保存:\n")
cat("  - Figure3_Forest_Plot_Enhanced.png\n")
cat("  - Figure3_Forest_Plot_Enhanced.pdf\n")


# --- Code Block 15 ---
# ==================== 整理Table 3数据 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    生成Table 3                                 ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 创建Table 3格式数据
table3_data <- subgroup_with_interaction %>%
  mutate(
    # 添加行顺序
    row_order = case_when(
      Variable == "Sex" & Subgroup == "Male" ~ 1,
      Variable == "Sex" & Subgroup == "Female" ~ 2,
      Variable == "Age" & Subgroup == "<60 years" ~ 3,
      Variable == "Age" & Subgroup == "≥60 years" ~ 4,
      Variable == "BMI" & Subgroup == "BMI <25" ~ 5,
      Variable == "BMI" & Subgroup == "BMI ≥25" ~ 6,
      Variable == "Diabetes" & Subgroup == "No diabetes" ~ 7,
      Variable == "Diabetes" & Subgroup == "Diabetes" ~ 8,
      Variable == "Hypertension" & Subgroup == "No hypertension" ~ 9,
      Variable == "Hypertension" & Subgroup == "Hypertension" ~ 10,
      Variable == "Race/Ethnicity" & Subgroup == "Non-Hispanic White" ~ 11,
      Variable == "Race/Ethnicity" & Subgroup == "Non-Hispanic Black" ~ 12,
      Variable == "Race/Ethnicity" & Subgroup == "Mexican American" ~ 13,
      Variable == "Race/Ethnicity" & Subgroup == "Other" ~ 14,
      TRUE ~ 99
    )
  ) %>%
  arrange(row_order) %>%
  select(Variable, Subgroup, N, Cases, OR_CI, P_Interaction_Formatted) %>%
  # 只在每组第一行显示P for interaction
  group_by(Variable) %>%
  mutate(
    P_Interaction_Display = ifelse(row_number() == 1, P_Interaction_Formatted, "")
  ) %>%
  ungroup() %>%
  select(-P_Interaction_Formatted) %>%
  rename(`P for Interaction` = P_Interaction_Display)

# 添加分组标题行
# 创建最终表格
table3_final <- table3_data %>%
  rename(
    `Subgroup Variable` = Variable,
    `Category` = Subgroup,
    `n` = N,
    `Cases` = Cases,
    `OR (95% CI)` = OR_CI
  )

cat("\nTable 3 数据:\n")
print(table3_final)


# --- Code Block 16 ---
# ==================== 导出Table 3 ====================

library(flextable)
library(officer)

# 创建flextable
table3_flex <- flextable(table3_final) %>%
  # 设置表头
  set_header_labels(
    `Subgroup Variable` = "Subgroup",
    `Category` = "",
    `n` = "n",
    `Cases` = "Cases",
    `OR (95% CI)` = "OR (95% CI)*",
    `P for Interaction` = "P for interaction"
  ) %>%
  # 合并相同的亚组变量
  merge_v(j = "Subgroup Variable") %>%
  # 对齐方式
  align(align = "center", part = "header") %>%
  align(j = c("n", "Cases", "OR (95% CI)", "P for Interaction"),
        align = "center", part = "body") %>%
  align(j = "Subgroup Variable", align = "left", part = "body") %>%
  align(j = "Category", align = "left", part = "body") %>%
  # 加粗表头
  bold(part = "header") %>%
  # 设置字体大小
  fontsize(size = 10, part = "all") %>%
  # 自适应宽度
  autofit() %>%
  # 添加表格标题
  set_caption(caption = "Table 3. Subgroup Analysis of the Association between SIRI and Dry Eye Disease") %>%
  # 添加脚注
  add_footer_lines(values = c(
    "*OR for highest (Q4) vs lowest (Q1) quartile of SIRI, adjusted for all covariates except the stratifying variable.",
    "Models adjusted for age, sex, race/ethnicity, education, family income-to-poverty ratio, BMI, smoking status, diabetes, and hypertension where applicable.",
    "Abbreviations: CI, confidence interval; OR, odds ratio; SIRI, Systemic Inflammation Response Index."
  ))

# 保存为Word
save_as_docx(table3_flex, path = "亚组分析/Table3_Subgroup_Analysis.docx")
cat("\nTable 3已保存为Word: Table3_Subgroup_Analysis.docx\n")

# 保存为Excel
writexl::write_xlsx(table3_final, "亚组分析/Table3_Subgroup_Analysis.xlsx")
cat("Table 3已保存为Excel: Table3_Subgroup_Analysis.xlsx\n")

# 保存为HTML
table3_html <- flextable::save_as_html(table3_flex, 
                                        path = "亚组分析/Table3_Subgroup_Analysis.html")
cat("Table 3已保存为HTML: Table3_Subgroup_Analysis.html\n")


# --- Code Block 17 ---
# ==================== 结果汇总 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    亚组分析结果解读                            ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 计算各亚组OR范围
or_range <- range(forest_data$OR, na.rm = TRUE)

cat("\n【1. 总体发现】\n")
cat("  分析样本量:", sum(forest_data$N), "\n")
cat("  总干眼症病例:", sum(forest_data$Cases), "\n")
cat("  分析亚组数:", nrow(forest_data), "\n")
cat("  OR值范围:", round(or_range[1], 2), "至", round(or_range[2], 2), "\n")

cat("\n【2. 显著亚组（P < 0.05）】\n")
sig_subgroups <- forest_data %>% filter(!is.na(P_Value) & P_Value < 0.05)
if (nrow(sig_subgroups) > 0) {
  for (i in 1:nrow(sig_subgroups)) {
    cat("  ", sig_subgroups$Subgroup[i], ": OR =", round(sig_subgroups$OR[i], 2),
        "(95%CI:", round(sig_subgroups$CI_Lower[i], 2), "-", 
        round(sig_subgroups$CI_Upper[i], 2), ")\n")
  }
} else {
  cat("  无显著亚组\n")
}

cat("\n【3. 交互作用检验】\n")
for (i in 1:nrow(interaction_results)) {
  p_val <- interaction_results$P_Interaction[i]
  status <- ifelse(p_val < 0.05, "✗ 显著", 
                   ifelse(p_val < 0.10, "~ 边缘显著", "✓ 不显著"))
  cat("  ", interaction_results$Variable[i], ": P =", 
      interaction_results$P_Interaction_Formatted[i], "(", status, ")\n")
}

cat("\n【4. 核心结论】\n")
# 根据结果自动生成结论
if (all(interaction_results$P_Interaction >= 0.05, na.rm = TRUE)) {
  cat("  未发现显著的效应修饰作用，SIRI与干眼症的关联在各亚组中相对一致。\n")
} else {
  sig_vars <- interaction_results$Variable[interaction_results$P_Interaction < 0.05]
  cat("  发现", paste(sig_vars, collapse = "、"), "对SIRI与干眼症关联存在显著的效应修饰作用。\n")
}


# --- Code Block 18 ---
# ==================== Results撰写模板 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    Results撰写模板                             ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# 根据实际结果生成文本
results_subgroup <- paste0(
  "3.4 Subgroup Analysis\n\n",
  
  "Table 3 and Figure 3 present the results of subgroup analyses stratified by ",
  "sex, age, BMI, diabetes status, hypertension, and race/ethnicity. ",
  "The association between SIRI (highest vs. lowest quartile) and dry eye disease ",
  "was examined within each subgroup after adjusting for relevant covariates.\n\n"
)

# 添加显著发现
sig_subgroups <- forest_data %>% filter(!is.na(P_Value) & P_Value < 0.05)
if (nrow(sig_subgroups) > 0) {
  results_subgroup <- paste0(results_subgroup,
    "Significant associations were observed in the following subgroups: "
  )
  for (i in 1:nrow(sig_subgroups)) {
    results_subgroup <- paste0(results_subgroup,
      sig_subgroups$Subgroup[i], " (OR = ", round(sig_subgroups$OR[i], 2),
      ", 95% CI: ", round(sig_subgroups$CI_Lower[i], 2), "-", 
      round(sig_subgroups$CI_Upper[i], 2), ")",
      ifelse(i < nrow(sig_subgroups), "; ", ".\n\n")
    )
  }
} else {
  results_subgroup <- paste0(results_subgroup,
    "No statistically significant associations were observed in any subgroup ",
    "(all P ≥ 0.05).\n\n"
  )
}

# 添加交互作用结果
sig_interactions <- interaction_results %>% filter(P_Interaction < 0.05)
if (nrow(sig_interactions) > 0) {
  results_subgroup <- paste0(results_subgroup,
    "Significant interaction was observed for ",
    paste(sig_interactions$Variable, collapse = " and "),
    " (P for interaction ",
    ifelse(any(sig_interactions$P_Interaction < 0.001), "< 0.001", 
           paste0("= ", round(min(sig_interactions$P_Interaction), 3))),
    "), suggesting that the association between SIRI and dry eye disease ",
    "differed significantly across these subgroups.\n\n"
  )
} else {
  results_subgroup <- paste0(results_subgroup,
    "No significant interactions were detected (all P for interaction ≥ 0.05), ",
    "indicating that the association between SIRI and dry eye disease was ",
    "relatively consistent across all examined subgroups.\n\n"
  )
}

# 边缘显著交互作用
marginal <- interaction_results %>% filter(P_Interaction >= 0.05 & P_Interaction < 0.10)
if (nrow(marginal) > 0) {
  results_subgroup <- paste0(results_subgroup,
    "A marginally significant interaction was observed for ",
    paste(marginal$Variable, collapse = " and "),
    " (P for interaction = ",
    paste(round(marginal$P_Interaction, 3), collapse = ", "),
    "), which may warrant further investigation in future studies."
  )
}

cat(results_subgroup)

# 保存Results文本
writeLines(results_subgroup, "亚组分析/Results_Section_3.4_Subgroup.txt")
cat("\n\nResults文本已保存: Results_Section_3.4_Subgroup.txt\n")


# --- Code Block 19 ---
# ==================== 中文版Results ====================

results_subgroup_cn <- paste0(
  "3.4 亚组分析\n\n",
  
  "表3和图3展示了按性别、年龄、BMI、糖尿病状态、高血压和种族/民族分层的亚组分析结果。",
  "在各亚组中，分析了SIRI（最高四分位组 vs 最低四分位组）与干眼症的关联，",
  "并调整了相应的协变量。\n\n"
)

# 根据结果添加内容
if (nrow(sig_subgroups) > 0) {
  results_subgroup_cn <- paste0(results_subgroup_cn,
    "在以下亚组中观察到显著关联：")
  for (i in 1:nrow(sig_subgroups)) {
    results_subgroup_cn <- paste0(results_subgroup_cn,
      sig_subgroups$Subgroup[i], "（OR = ", round(sig_subgroups$OR[i], 2),
      "，95% CI: ", round(sig_subgroups$CI_Lower[i], 2), "-", 
      round(sig_subgroups$CI_Upper[i], 2), "）",
      ifelse(i < nrow(sig_subgroups), "；", "。\n\n")
    )
  }
} else {
  results_subgroup_cn <- paste0(results_subgroup_cn,
    "在任何亚组中均未观察到统计学显著的关联（所有P ≥ 0.05）。\n\n"
  )
}

if (nrow(sig_interactions) > 0) {
  results_subgroup_cn <- paste0(results_subgroup_cn,
    "在", paste(sig_interactions$Variable, collapse = "和"),
    "方面观察到显著的交互作用（交互P ",
    ifelse(any(sig_interactions$P_Interaction < 0.001), "< 0.001", 
           paste0("= ", round(min(sig_interactions$P_Interaction), 3))),
    "），提示SIRI与干眼症的关联在不同亚组中存在显著差异。\n\n"
  )
} else {
  results_subgroup_cn <- paste0(results_subgroup_cn,
    "未检测到显著的交互作用（所有交互P ≥ 0.05），",
    "表明SIRI与干眼症的关联在所有检验的亚组中相对一致。\n\n"
  )
}

cat("\n【中文版本】\n")
cat(results_subgroup_cn)


# --- Code Block 20 ---
# ==================== Figure 3图例 ====================

figure3_legend <- paste0(
  "Figure 3. Forest plot of subgroup analyses for the association between SIRI ",
  "and dry eye disease.\n\n",
  
  "The diamond represents the odds ratio (OR) for the highest (Q4) versus lowest (Q1) ",
  "quartile of SIRI, and the horizontal line represents the 95% confidence interval. ",
  "The dashed vertical line indicates OR = 1.0 (no association). ",
  "Models were adjusted for age, sex, race/ethnicity, education level, family income-to-poverty ratio, ",
  "body mass index, smoking status, diabetes status, and hypertension, except for the stratifying variable.\n\n",
  
  "P for interaction was calculated by including a multiplicative interaction term ",
  "(SIRI quartile × stratifying variable) in the fully adjusted model.\n\n",
  
  "Abbreviations: BMI, body mass index; CI, confidence interval; OR, odds ratio; ",
  "SIRI, Systemic Inflammation Response Index."
)

cat("\n【Figure 3 图例说明】\n")
cat(figure3_legend)

# 保存图例
writeLines(figure3_legend, "亚组分析/Figure3_Legend.txt")


# --- Code Block 21 ---
# ==================== 保存分析结果 ====================

# 保存所有亚组分析对象
save(
  # 亚组分析结果
  subgroup_results,
  subgroup_results_df,
  subgroup_with_interaction,
  
  # 交互作用检验
  interaction_results,
  
  # 森林图数据
  forest_data,
  forest_plot_data,
  
  # Table 3数据
  table3_data,
  table3_final,
  
  # 更新后的数据和设计
  nhanes_complete,
  nhanes_design_subgroup,
  
  file = "亚组分析/Day21-22_Subgroup_Objects.RData"
)

cat("\n✓ 亚组分析对象已保存: Day21-22_Subgroup_Objects.RData\n")
cat("\n下次加载使用: load('亚组分析/Day21-22_Subgroup_Objects.RData')\n")
