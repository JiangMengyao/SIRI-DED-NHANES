# ============================================================
# Script: 02_variable_calculation.R
# Purpose: SIRI calculation, DED definition, covariate encoding
# Project: SIRI and Dry Eye Disease (NHANES 2005-2008)
# Data: NHANES 2005-2006 and 2007-2008 cycles
# ============================================================

# --- Code Block 1 ---
# 设置工作目录到数据导入与合并文件夹
setwd("/Users/mayiding/Desktop/第一篇/数据导入与合并")

# 确认当前工作目录
getwd()

# 加载必要的包
library(dplyr)
library(haven)

# 然后使用相对路径加载
nhanes_data <- readRDS("分析数据集/nhanes_siri_dryeye.rds")

cat("数据加载成功！样本量:", nrow(nhanes_data), "\n")


# --- Code Block 2 ---
# ==================== 计算绝对值 ====================
# 公式：绝对值 = 百分比 × 白细胞总数 / 100

nhanes_data <- nhanes_data %>%
  mutate(
    # 中性粒细胞绝对值 (10^9/L)
    neutrophil_abs = neutrophil_pct * wbc / 100,
    
    # 单核细胞绝对值 (10^9/L)
    monocyte_abs = monocyte_pct * wbc / 100,
    
    # 淋巴细胞绝对值 (10^9/L)
    lymphocyte_abs = lymphocyte_pct * wbc / 100
  )

# 检查计算结果
cat("\n==================== 血细胞绝对值计算结果 ====================\n")
cat("中性粒细胞绝对值范围:", range(nhanes_data$neutrophil_abs, na.rm = TRUE), "\n")
cat("单核细胞绝对值范围:", range(nhanes_data$monocyte_abs, na.rm = TRUE), "\n")
cat("淋巴细胞绝对值范围:", range(nhanes_data$lymphocyte_abs, na.rm = TRUE), "\n")


# --- Code Block 3 ---
# ====分布统计 ====================\n")
summary(nhanes_data$siri)

# 详细分布信息
cat("\nSIRI详细分布:\n")
cat("  缺失值数量:", sum(is.na(nhanes_data$siri)), "\n")
cat("  有效值数量:", sum(!is.na(nhanes_data$siri)), "\n")
cat("  最小值:", min(nhanes_data$siri, na.rm = TRUE), "\n")
cat("  第25百分位:", quantile(nhanes_data$siri, 0.25, na.rm = TRUE), "\n")
cat("  中位数:", median(nhanes_data$siri, na.rm = TRUE), "\n")
cat("  均值:", mean(nhanes_data$siri, na.rm = TRUE), "\n")
cat("  第75百分位:", quantile(nhanes_data$siri, 0.75, na.rm = TRUE), "\n")
cat("  最大值:", max(nhanes_data$siri, na.rm = TRUE), "\n")
cat("  Inf数量:", sum(is.infinite(nhanes_data$siri)), "\n")


# --- Code Block 4 ---
# ==================== SIRI四分位数分组 ====================
# ⚠️ 注意：此处为临时分组，需在Day 16-17最终样本上重新计算

# 计算四分位数切点
siri_quartiles <- quantile(nhanes_data$siri, 
                           probs = c(0.25, 0.50, 0.75), 
                           na.rm = TRUE)

cat("\n==================== SIRI四分位数切点（临时值）====================\n")
cat("Q1 (≤25%):", siri_quartiles[1], "\n")
cat("Q2 (25-50%):", siri_quartiles[2], "\n")
cat("Q3 (50-75%):", siri_quartiles[3], "\n")

# 创建分组变量
nhanes_data <- nhanes_data %>%
  mutate(
    siri_quartile = case_when(
      siri <= siri_quartiles[1] ~ "Q1",
      siri <= siri_quartiles[2] ~ "Q2",
      siri <= siri_quartiles[3] ~ "Q3",
      siri > siri_quartiles[3] ~ "Q4",
      TRUE ~ NA_character_
    ),
    # 转换为有序因子
    siri_quartile = factor(siri_quartile, 
                           levels = c("Q1", "Q2", "Q3", "Q4"),
                           ordered = TRUE)
  )

# 验证分组结果
cat("\n==================== SIRI分组分布 ====================\n")
table(nhanes_data$siri_quartile, useNA = "ifany")


# --- Code Block 5 ---
# ==================== 血细胞绝对值异常检查 ====================

cat("\n==================== 血细胞绝对值分布检查 ====================\n")

# 1. 中性粒细胞
cat("\n【中性粒细胞】正常范围: 1.8-7.8 × 10^9/L\n")
summary(nhanes_data$neutrophil_abs)
cat("低于1.8的人数:", sum(nhanes_data$neutrophil_abs < 1.8, na.rm = TRUE), "\n")
cat("高于7.8的人数:", sum(nhanes_data$neutrophil_abs > 7.8, na.rm = TRUE), "\n")
cat("高于15的人数:", sum(nhanes_data$neutrophil_abs > 15, na.rm = TRUE), "\n")

# 2. 单核细胞
cat("\n【单核细胞】正常范围: 0.12-0.80 × 10^9/L\n")
summary(nhanes_data$monocyte_abs)
cat("高于0.8的人数:", sum(nhanes_data$monocyte_abs > 0.8, na.rm = TRUE), "\n")
cat("高于2.5的人数:", sum(nhanes_data$monocyte_abs > 2.5, na.rm = TRUE), "\n")

# 3. 淋巴细胞
cat("\n【淋巴细胞】正常范围: 1.0-4.8 × 10^9/L\n")
summary(nhanes_data$lymphocyte_abs)
cat("高于4.8的人数:", sum(nhanes_data$lymphocyte_abs > 4.8, na.rm = TRUE), "\n")
cat("高于10的人数:", sum(nhanes_data$lymphocyte_abs > 10, na.rm = TRUE), "\n")
cat("高于20的人数:", sum(nhanes_data$lymphocyte_abs > 20, na.rm = TRUE), "\n")

# 4. 查看极端淋巴细胞值的具体情况
cat("\n【淋巴细胞 > 20 的样本详情】\n")
extreme_lymph <- nhanes_data %>% 
  filter(lymphocyte_abs > 20) %>%
  select(id, age, gender, wbc, lymphocyte_pct, lymphocyte_abs)
print(extreme_lymph)


# --- Code Block 6 ---
# ==================== 标记可疑血液系统疾病 ====================

nhanes_data <- nhanes_data %>%
  mutate(
    blood_disorder = case_when(
      # 1. 白细胞极端异常（可能是白血病）
      wbc > 25 ~ 1,        # WBC > 25 × 10^9/L
      wbc < 2.5 ~ 1,       # WBC < 2.5 × 10^9/L
      
      # 2. 淋巴细胞极端升高（可能是CLL/淋巴瘤）
      lymphocyte_abs > 10 ~ 1,
      
      # 3. 单核细胞极端升高（可能是CMML）
      monocyte_abs > 2.5 ~ 1,
      
      # 4. 中性粒细胞极端升高
      neutrophil_abs > 15 ~ 1,
      
      # 正常
      TRUE ~ 0
    )
  )

cat("\n==================== 血液系统疾病筛查结果 ====================\n")
cat("被标记为可疑血液病的人数:", sum(nhanes_data$blood_disorder == 1, na.rm = TRUE), "\n")

# 查看标记原因分布
cat("\n标记原因分布:\n")
cat("WBC > 25:", sum(nhanes_data$wbc > 25, na.rm = TRUE), "人\n")
cat("WBC < 2.5:", sum(nhanes_data$wbc < 2.5, na.rm = TRUE), "人\n")
cat("淋巴细胞 > 10:", sum(nhanes_data$lymphocyte_abs > 10, na.rm = TRUE), "人\n")
cat("单核细胞 > 2.5:", sum(nhanes_data$monocyte_abs > 2.5, na.rm = TRUE), "人\n")
cat("中性粒细胞 > 15:", sum(nhanes_data$neutrophil_abs > 15, na.rm = TRUE), "人\n")


# --- Code Block 7 ---
# ==================== SIRI极端值标记 ====================

# 计算SIRI的1%和99%分位数
siri_p1 <- quantile(nhanes_data$siri, 0.01, na.rm = TRUE)
siri_p99 <- quantile(nhanes_data$siri, 0.99, na.rm = TRUE)

cat("\n==================== SIRI分位数 ====================\n")
cat("SIRI 1%分位数:", round(siri_p1, 4), "\n")
cat("SIRI 99%分位数:", round(siri_p99, 4), "\n")

nhanes_data <- nhanes_data %>%
  mutate(
    siri_outlier = case_when(
      siri < siri_p1 ~ 1,   # 极低SIRI
      siri > siri_p99 ~ 1,  # 极高SIRI
      TRUE ~ 0
    )
  )

cat("SIRI极端值人数:", sum(nhanes_data$siri_outlier == 1, na.rm = TRUE), "\n")


# --- Code Block 8 ---
# ==================== 干眼症结局变量定义 ====================

nhanes_data <- nhanes_data %>%
  mutate(
    # ========== 方案A：主分析定义（症状型）==========
    # 阳性：有时(3)/经常(4)/总是(5)
    # 阴性：从不(1)/很少(2)
    # 缺失：不知道(9)/原始缺失
    dry_eye_a = case_when(
      dry_eye_symptom %in% c(3, 4, 5) ~ 1,  # 阳性
      dry_eye_symptom %in% c(1, 2) ~ 0,      # 阴性
      dry_eye_symptom == 9 ~ NA_real_,       # 不知道 → 缺失
      TRUE ~ NA_real_                         # 其他 → 缺失
    ),
    
    # ========== SA-Out1：严格定义（B类敏感性分析）==========
    # 阳性：经常(4)/总是(5)
    # 阴性：从不(1)/很少(2)/有时(3)
    dry_eye_c1 = case_when(
      dry_eye_symptom %in% c(4, 5) ~ 1,       # 阳性
      dry_eye_symptom %in% c(1, 2, 3) ~ 0,    # 阴性
      TRUE ~ NA_real_
    ),
    
    # ========== SA-Out2：症状+用药定义（B类敏感性分析）==========
    # 阳性：症状≥3 且 使用人工泪液
    # 阴性：症状1-2 或 (症状≥3但不用药)
    dry_eye_c2 = case_when(
      dry_eye_symptom %in% c(3, 4, 5) & artificial_tears == 1 ~ 1,  # 阳性
      dry_eye_symptom %in% c(1, 2) ~ 0,                              # 阴性
      dry_eye_symptom %in% c(3, 4, 5) & artificial_tears == 2 ~ 0,   # 有症状但不用药
      TRUE ~ NA_real_
    )
  )

# ==================== 验证结局变量 ====================
cat("\n==================== 干眼症结局变量分布 ====================\n")

# 方案A
cat("\n方案A（主分析：症状型定义 VIQ031≥3）:\n")
table(nhanes_data$dry_eye_a, useNA = "ifany")
prevalence_a <- mean(nhanes_data$dry_eye_a, na.rm = TRUE) * 100
cat("患病率:", round(prevalence_a, 2), "%\n")

# 方案C1
cat("\n方案C1（敏感性：严格定义 VIQ031≥4）:\n")
table(nhanes_data$dry_eye_c1, useNA = "ifany")
prevalence_c1 <- mean(nhanes_data$dry_eye_c1, na.rm = TRUE) * 100
cat("患病率:", round(prevalence_c1, 2), "%\n")

# 方案C2
cat("\n方案C2（敏感性：症状+用药定义）:\n")
table(nhanes_data$dry_eye_c2, useNA = "ifany")
prevalence_c2 <- mean(nhanes_data$dry_eye_c2, na.rm = TRUE) * 100
cat("患病率:", round(prevalence_c2, 2), "%\n")


# --- Code Block 9 ---
# ==================== 性别编码 ====================
# 原始编码：1=男, 2=女

nhanes_data <- nhanes_data %>%
  mutate(
    # 分类变量（因子）
    gender_cat = factor(gender, 
                        levels = c(1, 2), 
                        labels = c("Male", "Female")),
    # 二分类数值变量（用于回归）
    female = ifelse(gender == 2, 1, 0)
  )

# 验证
cat("\n性别分布:\n")
table(nhanes_data$gender_cat, useNA = "ifany")


# --- Code Block 10 ---
# ==================== 年龄分组 ====================
# 分组方案：20-39 / 40-59 / ≥60

nhanes_data <- nhanes_data %>%
  mutate(
    age_group = cut(age, 
                    breaks = c(20, 40, 60, Inf),
                    labels = c("20-39", "40-59", "≥60"),
                    right = FALSE,      # 左闭右开
                    include.lowest = TRUE)
  )

# 验证
cat("\n年龄分组分布:\n")
table(nhanes_data$age_group, useNA = "ifany")


# --- Code Block 11 ---
# ==================== 种族编码 ====================
# 原始编码：
# 1 = 墨西哥裔美国人
# 2 = 其他西班牙裔
# 3 = 非西班牙裔白人
# 4 = 非西班牙裔黑人
# 5 = 其他种族（含多种族）

nhanes_data <- nhanes_data %>%
  mutate(
    race_cat = factor(race, 
                      levels = c(3, 4, 1, 2, 5),  # 重排序，白人作为参考
                      labels = c("Non-Hispanic White",
                                "Non-Hispanic Black",
                                "Mexican American",
                                "Other Hispanic",
                                "Other Race"))
  )

# 验证
cat("\n种族分布:\n")
table(nhanes_data$race_cat, useNA = "ifany")


# --- Code Block 12 ---
# ==================== 教育水平编码 ====================
# 原始编码：
# 1 = 小于9年级
# 2 = 9-11年级（未完成高中）
# 3 = 高中毕业/GED
# 4 = 大学未毕业/AA学位
# 5 = 大学毕业及以上
# 7 = 拒绝回答
# 9 = 不知道

nhanes_data <- nhanes_data %>%
  mutate(
    # 先清洗特殊编码
    education_clean = case_when(
      education %in% c(7, 9) ~ NA_real_,  # 拒绝/不知道 → 缺失
      TRUE ~ education
    ),
    # 重新分组为3类
    education_cat = case_when(
      education_clean %in% c(1, 2) ~ "Less than high school",
      education_clean == 3 ~ "High school graduate",
      education_clean %in% c(4, 5) ~ "Some college or above",
      TRUE ~ NA_character_
    ),
    education_cat = factor(education_cat,
                           levels = c("Less than high school",
                                     "High school graduate",
                                     "Some college or above"))
  )

# 验证
cat("\n教育水平分布:\n")
table(nhanes_data$education_cat, useNA = "ifany")


# --- Code Block 13 ---
# ==================== 家庭收入比（PIR）====================
# INDFMPIR：家庭收入与贫困线之比
# 范围：0-5（5表示≥5倍贫困线）
# 保持连续变量，但可创建分类版本

nhanes_data <- nhanes_data %>%
  mutate(
    pir_cat = case_when(
      pir < 1 ~ "Below poverty",
      pir >= 1 & pir < 3 ~ "Low-middle income",
      pir >= 3 ~ "High income",
      TRUE ~ NA_character_
    ),
    pir_cat = factor(pir_cat,
                     levels = c("Below poverty", 
                               "Low-middle income", 
                               "High income"))
  )

# 验证
cat("\n家庭收入分布:\n")
cat("连续变量(PIR):\n")
summary(nhanes_data$pir)
cat("\n分类变量:\n")
table(nhanes_data$pir_cat, useNA = "ifany")


# --- Code Block 14 ---
# ==================== 吸烟状态编码 ====================
# SMQ020: 一生中是否吸过至少100支烟
#   1 = 是
#   2 = 否
#   7 = 拒绝
#   9 = 不知道
#
# SMQ040: 现在吸烟情况（仅SMQ020=1时询问）
#   1 = 每天
#   2 = 有时
#   3 = 完全不吸

nhanes_data <- nhanes_data %>%
  mutate(
    smoking_status = case_when(
      # 从不吸烟：从未吸过100支
      smoked_100 == 2 ~ "Never",
      # 曾经吸烟：吸过100支但现在不吸
      smoked_100 == 1 & smoke_now == 3 ~ "Former",
      # 现在吸烟：吸过100支且现在仍吸
      smoked_100 == 1 & smoke_now %in% c(1, 2) ~ "Current",
      # 拒绝/不知道 → 缺失
      smoked_100 %in% c(7, 9) ~ NA_character_,
      TRUE ~ NA_character_
    ),
    smoking_status = factor(smoking_status,
                            levels = c("Never", "Former", "Current"))
  )

# 验证
cat("\n吸烟状态分布:\n")
table(nhanes_data$smoking_status, useNA = "ifany")


# --- Code Block 15 ---
# ==================== 饮酒状态编码 ====================
# ALQ101: 过去12个月是否有喝过酒
# ALQ110: 过去12个月喝酒次数
# ALQ120Q/U: 平均每次喝多少（数量/单位）
# ALQ130: 过去12个月是否有过狂饮（男≥5杯，女≥4杯）

# 简化定义（根据数据可用性调整）
nhanes_data <- nhanes_data %>%
  mutate(
    drinking_status = case_when(
      # 不饮酒：过去12个月没喝过
      alcohol_12mo == 2 ~ "None",
      # 轻度饮酒：喝过但无狂饮
      alcohol_12mo == 1 ~ "Light-Moderate",  # 可进一步细分
      # 缺失
      alcohol_12mo %in% c(7, 9) ~ NA_character_,
      TRUE ~ NA_character_
    ),
    drinking_status = factor(drinking_status,
                             levels = c("None", "Light-Moderate"))
  )

# 验证
cat("\n饮酒状态分布:\n")
table(nhanes_data$drinking_status, useNA = "ifany")


# --- Code Block 16 ---
# ==================== BMI分组 ====================
# WHO标准分类

nhanes_data <- nhanes_data %>%
  mutate(
    bmi_cat = case_when(
      bmi < 18.5 ~ "Underweight (<18.5)",
      bmi >= 18.5 & bmi < 25 ~ "Normal (18.5-24.9)",
      bmi >= 25 & bmi < 30 ~ "Overweight (25-29.9)",
      bmi >= 30 ~ "Obese (≥30)",
      TRUE ~ NA_character_
    ),
    # 简化版（3分类，合并低体重和正常）
    bmi_cat3 = case_when(
      bmi < 25 ~ "Normal (<25)",
      bmi >= 25 & bmi < 30 ~ "Overweight (25-30)",
      bmi >= 30 ~ "Obese (≥30)",
      TRUE ~ NA_character_
    ),
    bmi_cat3 = factor(bmi_cat3,
                      levels = c("Normal (<25)", 
                                "Overweight (25-30)", 
                                "Obese (≥30)"))
  )

# 验证
cat("\nBMI分布:\n")
cat("连续变量:\n")
summary(nhanes_data$bmi)
cat("\n分类变量(3类):\n")
table(nhanes_data$bmi_cat3, useNA = "ifany")


# --- Code Block 17 ---
# ==================== 糖尿病状态定义 ====================
# 综合定义（问卷 + 实验室指标）
#
# DIQ010: 医生是否告知有糖尿病
#   1 = 是
#   2 = 否
#   3 = 临界/前驱糖尿病
#
# 辅助指标：
# - 空腹血糖 LBXGLU ≥ 126 mg/dL
# - 糖化血红蛋白 LBXGH ≥ 6.5%

nhanes_data <- nhanes_data %>%
  mutate(
    diabetes_status = case_when(
      # 确诊糖尿病：医生告知 或 血糖/HbA1c达标
      diabetes_told == 1 ~ "Diabetes",
      glucose >= 126 ~ "Diabetes",
      hba1c >= 6.5 ~ "Diabetes",
      # 前驱糖尿病：医生告知临界 或 指标在临界范围
      diabetes_told == 3 ~ "Prediabetes",
      glucose >= 100 & glucose < 126 ~ "Prediabetes",
      hba1c >= 5.7 & hba1c < 6.5 ~ "Prediabetes",
      # 正常
      diabetes_told == 2 & (is.na(glucose) | glucose < 100) & 
        (is.na(hba1c) | hba1c < 5.7) ~ "Normal",
      TRUE ~ NA_character_
    ),
    diabetes_status = factor(diabetes_status,
                             levels = c("Normal", "Prediabetes", "Diabetes")),
    # 二分类版本（用于简化分析）
    diabetes_binary = ifelse(diabetes_status == "Diabetes", 1, 0)
  )

# 验证
cat("\n糖尿病状态分布:\n")
table(nhanes_data$diabetes_status, useNA = "ifany")


# --- Code Block 18 ---
# ==================== 高血压状态定义 ====================
# 综合定义（问卷 + 血压测量）
# 血压测量取平均值（排除第一次测量）

nhanes_data <- nhanes_data %>%
  mutate(
    # 计算平均收缩压和舒张压（取第2、3次平均，如缺失则用可用值）
    sbp_mean = case_when(
      !is.na(BPXSY2) & !is.na(BPXSY3) ~ (BPXSY2 + BPXSY3) / 2,
      !is.na(BPXSY2) ~ BPXSY2,
      !is.na(BPXSY3) ~ BPXSY3,
      !is.na(sbp1) ~ sbp1,
      TRUE ~ NA_real_
    ),
    dbp_mean = case_when(
      !is.na(BPXDI2) & !is.na(BPXDI3) ~ (BPXDI2 + BPXDI3) / 2,
      !is.na(BPXDI2) ~ BPXDI2,
      !is.na(BPXDI3) ~ BPXDI3,
      !is.na(dbp1) ~ dbp1,
      TRUE ~ NA_real_
    ),
    # 高血压定义：SBP≥140 或 DBP≥90 或 正在服用降压药
    hypertension = case_when(
      sbp_mean >= 140 ~ 1,
      dbp_mean >= 90 ~ 1,
      # 如有降压药变量可添加
      TRUE ~ 0
    )
  )

# 验证
cat("\n高血压状态分布:\n")
table(nhanes_data$hypertension, useNA = "ifany")
cat("\n血压均值分布:\n")
summary(nhanes_data$sbp_mean)
summary(nhanes_data$dbp_mean)


# --- Code Block 19 ---
# ==================== 样本筛选 ====================

cat("\n==================== 样本筛选流程 ====================\n")

# 初始样本
n_total <- nrow(nhanes_data)
cat("1. 初始样本量:", n_total, "\n")

# 筛选1：年龄≥20岁
nhanes_analysis <- nhanes_data %>% filter(age >= 20)
n_age <- nrow(nhanes_analysis)
cat("2. 筛选年龄≥20岁:", n_age, "(排除", n_total - n_age, "人)\n")

# 筛选2：排除MEC权重=0
nhanes_analysis <- nhanes_analysis %>% filter(weight_4yr > 0)
n_weight <- nrow(nhanes_analysis)
cat("3. 排除权重=0:", n_weight, "(排除", n_age - n_weight, "人)\n")

# 筛选3：排除妊娠女性
nhanes_analysis <- nhanes_analysis %>% 
  filter(is.na(pregnant) | pregnant != 1)
n_preg <- nrow(nhanes_analysis)
cat("4. 排除妊娠女性:", n_preg, "(排除", n_weight - n_preg, "人)\n")

# 筛选4：SIRI有效（血常规完整）
nhanes_analysis <- nhanes_analysis %>% filter(!is.na(siri))
n_siri <- nrow(nhanes_analysis)
cat("5. SIRI有效:", n_siri, "(排除", n_preg - n_siri, "人)\n")

# 筛选5：干眼症变量有效
nhanes_analysis <- nhanes_analysis %>% filter(!is.na(dry_eye_a))
n_dryeye <- nrow(nhanes_analysis)
cat("6. 干眼症变量有效:", n_dryeye, "(排除", n_siri - n_dryeye, "人)\n")

cat("\n==================== 最终分析样本 ====================\n")
cat("最终样本量:", n_dryeye, "\n")
cat("筛选比例:", round(n_dryeye/n_total*100, 1), "%\n")


# --- Code Block 20 ---
# 生成流程图所需数据
flowchart_data <- data.frame(
  step = c("NHANES 2005-2008总样本",
           "年龄≥20岁",
           "排除权重=0",
           "排除妊娠女性",
           "SIRI数据完整",
           "干眼症数据完整"),
  n = c(n_total, n_age, n_weight, n_preg, n_siri, n_dryeye),
  excluded = c(NA, n_total - n_age, n_age - n_weight, 
               n_weight - n_preg, n_preg - n_siri, n_siri - n_dryeye)
)

print(flowchart_data)


# --- Code Block 21 ---
# ==================== 数据质量检查函数 ====================

check_final_data <- function(data) {
  cat("==================== 最终数据质量报告 ====================\n\n")
  
  # 1. 基本信息
  cat("1. 数据维度\n")
  cat("   样本量:", nrow(data), "\n")
  cat("   变量数:", ncol(data), "\n\n")
  
  # 2. 暴露变量（SIRI）
  cat("2. 暴露变量（SIRI）\n")
  cat("   缺失:", sum(is.na(data$siri)), "\n")
  cat("   范围:", range(data$siri, na.rm = TRUE), "\n")
  cat("   四分位组分布:\n")
  print(table(data$siri_quartile, useNA = "ifany"))
  cat("\n")
  
  # 3. 结局变量（干眼症）
  cat("3. 结局变量（干眼症）\n")
  cat("   方案A分布:\n")
  print(table(data$dry_eye_a, useNA = "ifany"))
  cat("   方案A患病率:", round(mean(data$dry_eye_a, na.rm = TRUE)*100, 2), "%\n\n")
  
  # 4. 关键协变量完整性
  cat("4. 关键协变量缺失率\n")
  key_vars <- c("age", "gender", "race", "education_cat", "pir", 
                "bmi", "smoking_status", "diabetes_status", "hypertension")
  
  for (v in key_vars) {
    if (v %in% names(data)) {
      miss <- sum(is.na(data[[v]]))
      pct <- round(miss/nrow(data)*100, 1)
      cat("  ", v, ":", miss, "(", pct, "%)\n")
    }
  }
  
  # 5. 抽样设计变量
  cat("\n5. 抽样设计变量\n")
  cat("   PSU缺失:", sum(is.na(data$psu)), "\n")
  cat("   Strata缺失:", sum(is.na(data$strata)), "\n")
  cat("   权重缺失:", sum(is.na(data$weight_4yr)), "\n")
  cat("   权重=0:", sum(data$weight_4yr == 0, na.rm = TRUE), "\n")
  
  cat("\n==================== 检查完成 ====================\n")
}

# 运行检查
check_final_data(nhanes_analysis)


# --- Code Block 22 ---
# 为每个标签设置不同的 y 位置
label_y <- c(y_top * 1.05, y_top * 1.10, y_top * 1.05)

p1 <- ggplot(nhanes_analysis, aes(x = siri)) +
  geom_histogram(bins = 50, fill = "steelblue", alpha = 0.7) +
  geom_vline(xintercept = siri_quartiles, linetype = "dashed", color = "red") +
  annotate(
    "text",
    x = siri_quartiles,
    y = label_y,
    label = c("Q1", "Median", "Q3"),
    color = "red",
    size = 3
  ) +
  labs(title = "SIRI Distribution", x = "SIRI", y = "Count") +
  theme_minimal() +
  coord_cartesian(clip = "off")  # 允许文字超出绘图区

print(p1)
ggsave("分析数据集/siri_distribution.png", p1, width = 8, height = 5)


# --- Code Block 23 ---
# ==================== 编码一致性检查 ====================

cat("\n==================== 编码一致性检查 ====================\n")

# 检查因子水平
cat("\n1. 因子变量水平顺序:\n")
cat("SIRI分组:", levels(nhanes_analysis$siri_quartile), "\n")
cat("性别:", levels(nhanes_analysis$gender_cat), "\n")
cat("年龄组:", levels(nhanes_analysis$age_group), "\n")
cat("种族:", levels(nhanes_analysis$race_cat), "\n")
cat("教育:", levels(nhanes_analysis$education_cat), "\n")
cat("吸烟:", levels(nhanes_analysis$smoking_status), "\n")
cat("BMI:", levels(nhanes_analysis$bmi_cat3), "\n")
cat("糖尿病:", levels(nhanes_analysis$diabetes_status), "\n")

# 检查是否有残留特殊编码
cat("\n2. 特殊编码残留检查:\n")
check_special <- function(var, data) {
  vals <- unique(data[[var]])
  special <- vals[vals %in% c(7, 9, 77, 99, 777, 999)]
  if (length(special) > 0) {
    cat("  ", var, ": 发现特殊编码", special, "\n")
  }
}

# 对原始数值变量检查
numeric_vars <- c("education", "smoked_100", "smoke_now", 
                  "alcohol_12mo", "diabetes_told")
for (v in numeric_vars) {
  if (v %in% names(nhanes_analysis)) {
    check_special(v, nhanes_analysis)
  }
}


# --- Code Block 24 ---
# ==================== 保存最终分析数据集 ====================

# 保存为RDS格式（推荐，保留所有属性）
saveRDS(nhanes_analysis, "分析数据集/nhanes_analysis_final.rds")
cat("已保存: nhanes_analysis_final.rds\n")

# 保存为CSV格式（备用）
write.csv(nhanes_analysis, "分析数据集/nhanes_analysis_final.csv", 
          row.names = FALSE)
cat("已保存: nhanes_analysis_final.csv\n")

# 保存为Stata格式
library(haven)
write_dta(nhanes_analysis, "分析数据集/nhanes_analysis_final.dta")
cat("已保存: nhanes_analysis_final.dta\n")

cat("\n==================== 数据准备完成 ====================\n")
cat("最终分析数据集信息:\n")
cat("  样本量:", nrow(nhanes_analysis), "\n")
cat("  变量数:", ncol(nhanes_analysis), "\n")
cat("  SIRI有效:", sum(!is.na(nhanes_analysis$siri)), "\n")
cat("  干眼症阳性:", sum(nhanes_analysis$dry_eye_a == 1, na.rm = TRUE), "\n")
cat("  干眼症患病率:", round(mean(nhanes_analysis$dry_eye_a, na.rm = TRUE)*100, 2), "%\n")
