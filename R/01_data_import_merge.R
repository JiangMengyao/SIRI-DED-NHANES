# ============================================================
# Script: 01_data_import_merge.R
# Purpose: Import and merge NHANES 2005-2008 XPT data files
# Project: SIRI and Dry Eye Disease (NHANES 2005-2008)
# Data: NHANES 2005-2006 and 2007-2008 cycles
# ============================================================

# --- Code Block 1 ---
# 安装并加载必要的包
install.packages("haven")
library(haven)

# 设置工作目录（根据你的实际路径修改）
setwd("/Users/mayiding/Desktop/第一篇/NHANCE数据")

# ==================== 导入2005-2006周期数据 ====================
demo_d <- read_xpt("2005-2006数据/xpt/DEMO_D.xpt")
cbc_d  <- read_xpt("2005-2006数据/xpt/CBC_D.xpt")
viq_d  <- read_xpt("2005-2006数据/xpt/VIQ_D.xpt")
bmx_d  <- read_xpt("2005-2006数据/xpt/BMX_D.xpt")
bpx_d  <- read_xpt("2005-2006数据/xpt/BPX_D.xpt")
smq_d  <- read_xpt("2005-2006数据/xpt/SMQ_D.xpt")
alq_d  <- read_xpt("2005-2006数据/xpt/ALQ_D.xpt")
diq_d  <- read_xpt("2005-2006数据/xpt/DIQ_D.xpt")
glu_d  <- read_xpt("2005-2006数据/xpt/GLU_D.xpt")
ghb_d  <- read_xpt("2005-2006数据/xpt/GHB_D.xpt")
crp_d  <- read_xpt("2005-2006数据/xpt/CRP_D.xpt")

# ==================== 导入2007-2008周期数据 ====================
demo_e <- read_xpt("2007-2008数据/DEMO_E.xpt")
cbc_e  <- read_xpt("2007-2008数据/CBC_E.xpt")
viq_e  <- read_xpt("2007-2008数据/VIQ_E.xpt")
bmx_e  <- read_xpt("2007-2008数据/BMX_E.xpt")
bpx_e  <- read_xpt("2007-2008数据/BPX_E.xpt")
smq_e  <- read_xpt("2007-2008数据/SMQ_E.xpt")
alq_e  <- read_xpt("2007-2008数据/ALQ_E.xpt")
diq_e  <- read_xpt("2007-2008数据/DIQ_E.xpt")
glu_e  <- read_xpt("2007-2008数据/GLU_E.xpt")
ghb_e  <- read_xpt("2007-2008数据/GHB_E.xpt")
crp_e  <- read_xpt("2007-2008数据/CRP_E.xpt")

# 检查数据导入是否成功
cat("2005-2006 DEMO样本量:", nrow(demo_d), "\n")
cat("2007-2008 DEMO样本量:", nrow(demo_e), "\n")


# --- Code Block 2 ---
# R语言版本
# 1. 检查样本量
cat("各数据集样本量:\n")
cat("DEMO_D:", nrow(demo_d), "\n")
cat("CBC_D:", nrow(cbc_d), "\n")
cat("VIQ_D:", nrow(viq_d), "\n")

# 2. 检查SEQN变量是否存在且唯一
cat("\nSEQN唯一性检查:\n")
cat("DEMO_D SEQN唯一:", length(unique(demo_d$SEQN)) == nrow(demo_d), "\n")
cat("CBC_D SEQN唯一:", length(unique(cbc_d$SEQN)) == nrow(cbc_d), "\n")

# 3. 查看关键变量
names(cbc_d)  # 查看血常规变量名
names(viq_d)  # 查看视力问卷变量名

# 4. 检查血常规计算SIRI所需变量
cat("\n计算SIRI所需变量:\n")
cat("白细胞计数(LBXWBCSI)存在:", "LBXWBCSI" %in% names(cbc_d), "\n")
cat("中性粒细胞%(LBXNEPCT)存在:", "LBXNEPCT" %in% names(cbc_d), "\n")
cat("单核细胞%(LBXMOPCT)存在:", "LBXMOPCT" %in% names(cbc_d), "\n")
cat("淋巴细胞%(LBXLYPCT)存在:", "LBXLYPCT" %in% names(cbc_d), "\n")


# --- Code Block 3 ---
# ==================== 修正后的完整合并代码 ====================
library(dplyr)

# ==================== 合并2005-2006周期数据 ====================

demo_d_select <- demo_d %>%
  select(SEQN, RIAGENDR, RIDAGEYR, RIDRETH1, DMDEDUC2, INDFMPIR,
         SDMVPSU, SDMVSTRA, WTMEC2YR, RIDEXPRG)

cbc_d_select <- cbc_d %>%
  select(SEQN, LBXWBCSI, LBXNEPCT, LBXMOPCT, LBXLYPCT)

# 修正：使用VIQ031和VIQ041
viq_d_select <- viq_d %>%
  select(SEQN, VIQ031, VIQ041)

bmx_d_select <- bmx_d %>%
  select(SEQN, BMXBMI, BMXWT, BMXHT)

bpx_d_select <- bpx_d %>%
  select(SEQN, BPXSY1, BPXDI1, BPXSY2, BPXDI2, BPXSY3, BPXDI3)

smq_d_select <- smq_d %>%
  select(SEQN, SMQ020, SMQ040)

alq_d_select <- alq_d %>%
  select(SEQN, ALQ101, ALQ110, ALQ120Q, ALQ120U, ALQ130)

diq_d_select <- diq_d %>%
  select(SEQN, DIQ010, DIQ160, DIQ170)

glu_d_select <- glu_d %>%
  select(SEQN, LBXGLU)

ghb_d_select <- ghb_d %>%
  select(SEQN, LBXGH)

crp_d_select <- crp_d %>%
  select(SEQN, LBXCRP)

data_2005_2006 <- demo_d_select %>%
  left_join(cbc_d_select, by = "SEQN") %>%
  left_join(viq_d_select, by = "SEQN") %>%
  left_join(bmx_d_select, by = "SEQN") %>%
  left_join(bpx_d_select, by = "SEQN") %>%
  left_join(smq_d_select, by = "SEQN") %>%
  left_join(alq_d_select, by = "SEQN") %>%
  left_join(diq_d_select, by = "SEQN") %>%
  left_join(glu_d_select, by = "SEQN") %>%
  left_join(ghb_d_select, by = "SEQN") %>%
  left_join(crp_d_select, by = "SEQN")

data_2005_2006$cycle <- "2005-2006"
data_2005_2006$cycle_num <- 1

cat("2005-2006周期合并后样本量:", nrow(data_2005_2006), "\n")

# ==================== 合并2007-2008周期数据 ====================

demo_e_select <- demo_e %>%
  select(SEQN, RIAGENDR, RIDAGEYR, RIDRETH1, DMDEDUC2, INDFMPIR,
         SDMVPSU, SDMVSTRA, WTMEC2YR, RIDEXPRG)

cbc_e_select <- cbc_e %>%
  select(SEQN, LBXWBCSI, LBXNEPCT, LBXMOPCT, LBXLYPCT)

# 修正：使用VIQ031和VIQ041
viq_e_select <- viq_e %>%
  select(SEQN, VIQ031, VIQ041)

bmx_e_select <- bmx_e %>%
  select(SEQN, BMXBMI, BMXWT, BMXHT)

bpx_e_select <- bpx_e %>%
  select(SEQN, BPXSY1, BPXDI1, BPXSY2, BPXDI2, BPXSY3, BPXDI3)

smq_e_select <- smq_e %>%
  select(SEQN, SMQ020, SMQ040)

alq_e_select <- alq_e %>%
  select(SEQN, ALQ101, ALQ110, ALQ120Q, ALQ120U, ALQ130)

diq_e_select <- diq_e %>%
  select(SEQN, DIQ010, DIQ160, DIQ170)

glu_e_select <- glu_e %>%
  select(SEQN, LBXGLU)

ghb_e_select <- ghb_e %>%
  select(SEQN, LBXGH)

crp_e_select <- crp_e %>%
  select(SEQN, LBXCRP)

data_2007_2008 <- demo_e_select %>%
  left_join(cbc_e_select, by = "SEQN") %>%
  left_join(viq_e_select, by = "SEQN") %>%
  left_join(bmx_e_select, by = "SEQN") %>%
  left_join(bpx_e_select, by = "SEQN") %>%
  left_join(smq_e_select, by = "SEQN") %>%
  left_join(alq_e_select, by = "SEQN") %>%
  left_join(diq_e_select, by = "SEQN") %>%
  left_join(glu_e_select, by = "SEQN") %>%
  left_join(ghb_e_select, by = "SEQN") %>%
  left_join(crp_e_select, by = "SEQN")

data_2007_2008$cycle <- "2007-2008"
data_2007_2008$cycle_num <- 2

cat("2007-2008周期合并后样本量:", nrow(data_2007_2008), "\n")


# --- Code Block 4 ---
# ==================== 两个周期合并检查 ====================
cat("\n==================== 2005-2006 合并检查 ====================\n")

# 1. 检查样本量
cat("原始DEMO_D样本量:", nrow(demo_d), "\n")
cat("合并后样本量:", nrow(data_2005_2006), "\n")
cat("样本量一致:", nrow(demo_d) == nrow(data_2005_2006), "\n")

# 2. 关键变量缺失
cat("\n关键变量缺失情况:\n")
cat("  LBXWBCSI(白细胞)缺失:", sum(is.na(data_2005_2006$LBXWBCSI)), "\n")
cat("  LBXNEPCT(中性粒%)缺失:", sum(is.na(data_2005_2006$LBXNEPCT)), "\n")
cat("  LBXMOPCT(单核%)缺失:", sum(is.na(data_2005_2006$LBXMOPCT)), "\n")
cat("  LBXLYPCT(淋巴%)缺失:", sum(is.na(data_2005_2006$LBXLYPCT)), "\n")
cat("  VIQ031(干眼症状)缺失:", sum(is.na(data_2005_2006$VIQ031)), "\n")

# 3. SEQN重复检查
cat("\nSEQN重复:", any(duplicated(data_2005_2006$SEQN)), "\n")


cat("\n==================== 2007-2008 合并检查 ====================\n")

# 1. 检查样本量
cat("原始DEMO_E样本量:", nrow(demo_e), "\n")
cat("合并后样本量:", nrow(data_2007_2008), "\n")
cat("样本量一致:", nrow(demo_e) == nrow(data_2007_2008), "\n")

# 2. 关键变量缺失
cat("\n关键变量缺失情况:\n")
cat("  LBXWBCSI(白细胞)缺失:", sum(is.na(data_2007_2008$LBXWBCSI)), "\n")
cat("  LBXNEPCT(中性粒%)缺失:", sum(is.na(data_2007_2008$LBXNEPCT)), "\n")
cat("  LBXMOPCT(单核%)缺失:", sum(is.na(data_2007_2008$LBXMOPCT)), "\n")
cat("  LBXLYPCT(淋巴%)缺失:", sum(is.na(data_2007_2008$LBXLYPCT)), "\n")
cat("  VIQ031(干眼症状)缺失:", sum(is.na(data_2007_2008$VIQ031)), "\n")

# 3. SEQN重复检查
cat("\nSEQN重复:", any(duplicated(data_2007_2008$SEQN)), "\n")


cat("\n==================== 汇总 ====================\n")
cat("2005-2006 样本量:", nrow(data_2005_2006), "\n")
cat("2007-2008 样本量:", nrow(data_2007_2008), "\n")
cat("合计样本量:", nrow(data_2005_2006) + nrow(data_2007_2008), "\n")


# --- Code Block 5 ---
# 比较两个周期的变量名
cat("==================== 变量名一致性检查 ====================\n")

vars_d <- names(data_2005_2006)
vars_e <- names(data_2007_2008)

# 找出不一致的变量名
only_in_d <- setdiff(vars_d, vars_e)
only_in_e <- setdiff(vars_e, vars_d)

if (length(only_in_d) > 0) {
  cat("仅在2005-2006中存在的变量:", paste(only_in_d, collapse = ", "), "\n")
}
if (length(only_in_e) > 0) {
  cat("仅在2007-2008中存在的变量:", paste(only_in_e, collapse = ", "), "\n")
}

# 比较共同变量的类型
common_vars <- intersect(vars_d, vars_e)
for (v in common_vars) {
  type_d <- class(data_2005_2006[[v]])[1]
  type_e <- class(data_2007_2008[[v]])[1]
  if (type_d != type_e) {
    cat("变量类型不一致:", v, "(D:", type_d, "/ E:", type_e, ")\n")
  }
}


# --- Code Block 6 ---
library(dplyr)

# ==================== 确保变量名和类型一致 ====================
# 确保两个数据集有完全相同的列
common_vars <- intersect(names(data_2005_2006), names(data_2007_2008))

data_2005_2006_aligned <- data_2005_2006 %>% select(all_of(common_vars))
data_2007_2008_aligned <- data_2007_2008 %>% select(all_of(common_vars))

# ==================== 纵向合并 ====================
nhanes_combined <- bind_rows(data_2005_2006_aligned, data_2007_2008_aligned)

cat("==================== 合并结果 ====================\n")
cat("2005-2006样本量:", nrow(data_2005_2006_aligned), "\n")
cat("2007-2008样本量:", nrow(data_2007_2008_aligned), "\n")
cat("合并后总样本量:", nrow(nhanes_combined), "\n")
cat("总样本量验证:", nrow(data_2005_2006_aligned) + nrow(data_2007_2008_aligned), "\n")

# ==================== 计算4年权重 ====================
# 关键步骤：合并多周期时权重需要调整
nhanes_combined <- nhanes_combined %>%
  mutate(
    # 4年权重 = 2年权重 / 2
    WTMEC4YR = WTMEC2YR / 2
  )

cat("\n权重计算完成:\n")
cat("WTMEC4YR范围:", range(nhanes_combined$WTMEC4YR, na.rm = TRUE), "\n")


# --- Code Block 7 ---
nhanes_final <- nhanes_combined %>%
  rename(
    # 人口学变量
    id = SEQN,
    gender = RIAGENDR,
    age = RIDAGEYR,
    race = RIDRETH1,
    education = DMDEDUC2,
    pir = INDFMPIR,
    pregnant = RIDEXPRG,
    
    # 抽样设计变量
    psu = SDMVPSU,
    strata = SDMVSTRA,
    weight_2yr = WTMEC2YR,
    weight_4yr = WTMEC4YR,
    
    # 血常规变量（计算SIRI用）
    wbc = LBXWBCSI,
    neutrophil_pct = LBXNEPCT,
    monocyte_pct = LBXMOPCT,
    lymphocyte_pct = LBXLYPCT,
    
    # 干眼症相关（修正：VIQ031和VIQ041）
    dry_eye_symptom = VIQ031,
    artificial_tears = VIQ041,
    
    # 体测
    bmi = BMXBMI,
    weight_kg = BMXWT,
    height = BMXHT,
    
    # 血压
    sbp1 = BPXSY1,
    dbp1 = BPXDI1,
    
    # 吸烟
    smoked_100 = SMQ020,
    smoke_now = SMQ040,
    
    # 饮酒
    alcohol_ever = ALQ101,
    alcohol_12mo = ALQ110,
    
    # 糖尿病
    diabetes_told = DIQ010,
    
    # 血糖和糖化血红蛋白
    glucose = LBXGLU,
    hba1c = LBXGH,
    
    # C反应蛋白
    crp = LBXCRP
  )

cat("变量重命名完成！\n")
cat("数据维度:", dim(nhanes_final), "\n")


# --- Code Block 8 ---
nhanes_final <- nhanes_final %>%
  mutate(
    # ==================== 性别编码 ====================
    # 原始：1=男, 2=女
    gender_cat = factor(gender, levels = c(1, 2), labels = c("Male", "Female")),
    female = ifelse(gender == 2, 1, 0),
    
    # ==================== 年龄分组 ====================
    age_group = cut(age, 
                    breaks = c(20, 40, 60, Inf),
                    labels = c("20-39", "40-59", "≥60"),
                    right = FALSE),
    
    # ==================== 种族编码 ====================
    # 原始：1=墨西哥裔美国人, 2=其他西班牙裔, 3=非西班牙裔白人, 
    #      4=非西班牙裔黑人, 5=其他种族
    race_cat = factor(race, 
                      levels = c(1, 2, 3, 4, 5),
                      labels = c("Mexican American", 
                                "Other Hispanic",
                                "Non-Hispanic White",
                                "Non-Hispanic Black",
                                "Other Race")),
    
    # ==================== 教育水平 ====================
    # 原始：1=<9年级, 2=9-11年级, 3=高中毕业, 4=大学未毕业, 5=大学毕业及以上
    # 7=拒绝, 9=不知道 → 设为缺失
    education_clean = case_when(
      education %in% c(7, 9) ~ NA_real_,
      TRUE ~ education
    ),
    education_cat = case_when(
      education_clean %in% c(1, 2) ~ "Less than high school",
      education_clean == 3 ~ "High school graduate",
      education_clean %in% c(4, 5) ~ "Some college or above",
      TRUE ~ NA_character_
    ),
    
    # ==================== BMI分组 ====================
    bmi_cat = case_when(
      bmi < 25 ~ "Normal (<25)",
      bmi >= 25 & bmi < 30 ~ "Overweight (25-30)",
      bmi >= 30 ~ "Obese (≥30)",
      TRUE ~ NA_character_
    ),
    
    # ==================== 吸烟状态 ====================
    # SMQ020: 1=是(吸过100支), 2=否, 7=拒绝, 9=不知道
    # SMQ040: 1=每天吸, 2=有时吸, 3=完全不吸
    smoking_status = case_when(
      smoked_100 == 2 ~ "Never",
      smoked_100 == 1 & smoke_now == 3 ~ "Former",
      smoked_100 == 1 & smoke_now %in% c(1, 2) ~ "Current",
      smoked_100 %in% c(7, 9) ~ NA_character_,
      TRUE ~ NA_character_
    ),
    
    # ==================== 干眼症结局变量 ====================
    # VIQ031: 1=是, 2=否, 7=拒绝, 9=不知道
    # 方案A：症状阳性定义
    dry_eye_a = case_when(
      dry_eye_symptom == 1 ~ 1,
      dry_eye_symptom == 2 ~ 0,
      dry_eye_symptom %in% c(7, 9) ~ NA_real_,
      TRUE ~ NA_real_
    ),
    
    # 方案B：症状阳性 + 使用人工泪液
    dry_eye_b = case_when(
      dry_eye_symptom == 1 & artificial_tears == 1 ~ 1,
      dry_eye_symptom == 2 ~ 0,
      dry_eye_symptom == 1 & artificial_tears == 2 ~ 0,
      TRUE ~ NA_real_
    ),
    
    # ==================== 妊娠状态 ====================
    # 1=是, 2=否
    is_pregnant = ifelse(pregnant == 1, 1, 0)
  )


# --- Code Block 9 ---
nhanes_final <- nhanes_final %>%
  mutate(
    # 计算绝对值（如果原始数据只有百分比）
    neutrophil_abs = neutrophil_pct * wbc / 100,
    monocyte_abs = monocyte_pct * wbc / 100,
    lymphocyte_abs = lymphocyte_pct * wbc / 100,
    
    # 计算SIRI
    # SIRI = (中性粒细胞 × 单核细胞) / 淋巴细胞
    siri = (neutrophil_abs * monocyte_abs) / lymphocyte_abs
  )

# SIRI分位数分组
siri_quantiles <- quantile(nhanes_final$siri, probs = c(0.25, 0.50, 0.75), na.rm = TRUE)

nhanes_final <- nhanes_final %>%
  mutate(
    siri_quartile = case_when(
      siri <= siri_quantiles[1] ~ "Q1",
      siri <= siri_quantiles[2] ~ "Q2",
      siri <= siri_quantiles[3] ~ "Q3",
      siri > siri_quantiles[3] ~ "Q4",
      TRUE ~ NA_character_
    ),
    siri_quartile = factor(siri_quartile, levels = c("Q1", "Q2", "Q3", "Q4"))
  )

# 查看SIRI分布
cat("\n==================== SIRI分布 ====================\n")
summary(nhanes_final$siri)
cat("\nSIRI四分位数切点:\n")
print(siri_quantiles)


# --- Code Block 10 ---
# 创建保存目录（如果不存在）
if (!dir.exists("分析数据集")) {
  dir.create("分析数据集")
  cat("已创建文件夹: 分析数据集\n")
}

# 保存为R数据格式
saveRDS(nhanes_final, "分析数据集/nhanes_siri_dryeye.rds")
cat("已保存: nhanes_siri_dryeye.rds\n")

# 保存为CSV（备用）
write.csv(nhanes_final, "分析数据集/nhanes_siri_dryeye.csv", row.names = FALSE)
cat("已保存: nhanes_siri_dryeye.csv\n")

# 保存为Stata格式
library(haven)
write_dta(nhanes_final, "分析数据集/nhanes_siri_dryeye.dta")
cat("已保存: nhanes_siri_dryeye.dta\n")

cat("\n==================== 保存完成 ====================\n")
cat("变量数:", ncol(nhanes_final), "\n")
cat("样本量:", nrow(nhanes_final), "\n")
cat("保存路径:", getwd(), "/分析数据集/\n")


# --- Code Block 11 ---
# ==================== 数据质量检验函数 ====================
check_data_quality <- function(data) {
  cat("==================== 数据质量检查报告 ====================\n\n")
  
  # 1. 样本量
  cat("1. 总样本量:", nrow(data), "\n\n")
  
  # 2. SIRI检查
  cat("2. SIRI变量检查:\n")
  cat("   - 缺失数:", sum(is.na(data$siri)), "\n")
  cat("   - 有效数:", sum(!is.na(data$siri)), "\n")
  if (sum(!is.na(data$siri)) > 0) {
    cat("   - 最小值:", min(data$siri, na.rm = TRUE), "\n")
    cat("   - 最大值:", max(data$siri, na.rm = TRUE), "\n")
    cat("   - 中位数:", median(data$siri, na.rm = TRUE), "\n")
    cat("   - Inf数量:", sum(is.infinite(data$siri)), "\n")
  }
  cat("\n")
  
  # 3. 干眼症检查（使用dry_eye_symptom，即VIQ031重命名后的变量）
  cat("3. 干眼症变量检查:\n")
  cat("   - dry_eye_symptom缺失数:", sum(is.na(data$dry_eye_symptom)), "\n")
  cat("   - 有效数:", sum(!is.na(data$dry_eye_symptom)), "\n")
  if (sum(!is.na(data$dry_eye_symptom)) > 0) {
    cat("   - 分布:\n")
    print(table(data$dry_eye_symptom, useNA = "ifany"))
  }
  cat("\n")
  
  # 4. 如果创建了dry_eye_a变量
  if ("dry_eye_a" %in% names(data)) {
    cat("4. 干眼症二分类变量(dry_eye_a):\n")
    cat("   - 缺失数:", sum(is.na(data$dry_eye_a)), "\n")
    cat("   - 阳性数:", sum(data$dry_eye_a == 1, na.rm = TRUE), "\n")
    cat("   - 阴性数:", sum(data$dry_eye_a == 0, na.rm = TRUE), "\n")
    cat("   - 患病率:", round(mean(data$dry_eye_a, na.rm = TRUE) * 100, 2), "%\n\n")
  }
  
  # 5. 权重检查
  cat("5. 权重变量检查:\n")
  cat("   - 4年权重缺失:", sum(is.na(data$weight_4yr)), "\n")
  cat("   - 权重为0:", sum(data$weight_4yr == 0, na.rm = TRUE), "\n")
  if (sum(!is.na(data$weight_4yr)) > 0) {
    cat("   - 权重范围:", range(data$weight_4yr, na.rm = TRUE), "\n")
  }
  cat("\n")
  
  # 6. 周期分布
  cat("6. 周期分布:\n")
  print(table(data$cycle, useNA = "ifany"))
  
  # 7. 关键协变量缺失汇总
  cat("\n7. 关键变量缺失汇总:\n")
  key_vars <- c("age", "gender", "race", "bmi", "wbc", 
                "neutrophil_pct", "monocyte_pct", "lymphocyte_pct",
                "dry_eye_symptom", "siri")
  
  for (v in key_vars) {
    if (v %in% names(data)) {
      miss_n <- sum(is.na(data[[v]]))
      miss_pct <- round(miss_n / nrow(data) * 100, 1)
      cat("   ", v, ": ", miss_n, " (", miss_pct, "%)\n", sep = "")
    }
  }
  
  cat("\n==================== 检查完成 ====================\n")
}

# 运行检查
check_data_quality(nhanes_final)
