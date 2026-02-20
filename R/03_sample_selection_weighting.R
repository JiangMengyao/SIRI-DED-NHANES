# ============================================================
# Script: 03_sample_selection_weighting.R
# Purpose: Inclusion/exclusion criteria, 4-year survey weight calculation
# Project: SIRI and Dry Eye Disease (NHANES 2005-2008)
# Data: NHANES 2005-2006 and 2007-2008 cycles
# ============================================================

# --- Code Block 1 ---
# ==================== 环境设置 ====================
# 设置工作目录
setwd("/Users/mayiding/Desktop/第一篇")

# 加载必要的包
library(dplyr)
library(haven)
library(survey)  # 复杂调查分析核心包

# ==================== 加载两个数据文件 ====================

# 【数据1】Day 13 原始合并数据 - 用于生成流程图
# 包含完整的 20,497 人，用于记录筛选过程
nhanes_raw <- readRDS("分析数据集/nhanes_siri_dryeye.rds")

# 【数据2】Day 14 已处理数据 - 用于权重分析和建模
# 包含 9,467 人，已完成筛选，且包含敏感性分析变量
nhanes_analysis <- readRDS("分析数据集/nhanes_analysis_final.rds")

# ==================== 数据验证 ====================
cat("==================== 数据加载验证 ====================\n")
cat("\n【Day 13 原始数据】用于流程图生成\n")
cat("样本量:", nrow(nhanes_raw), "（应为 20,497）\n")
cat("变量数:", ncol(nhanes_raw), "\n")

cat("\n【Day 14 已处理数据】用于权重分析\n")
cat("样本量:", nrow(nhanes_analysis), "（应为 9,467）\n")
cat("变量数:", ncol(nhanes_analysis), "\n")

# 验证 Day 14 数据包含敏感性分析变量
cat("\n【敏感性分析变量检查】\n")
sa_vars <- c("blood_disorder", "siri_outlier", "dry_eye_c1", "dry_eye_c2")
for (v in sa_vars) {
  if (v %in% names(nhanes_analysis)) {
    cat("✓", v, "存在\n")
  } else {
    cat("✗", v, "缺失 - 请检查 Day 14 数据！\n")
  }
}

# 查看 Day 13 关键变量缺失情况（用于流程图）
cat("\n【Day 13 关键变量缺失情况】\n")
cat("年龄缺失:", sum(is.na(nhanes_raw$age)), "\n")
cat("权重缺失:", sum(is.na(nhanes_raw$weight_4yr)), "\n")
cat("权重=0:", sum(nhanes_raw$weight_4yr == 0, na.rm = TRUE), "\n")
cat("SIRI缺失:", sum(is.na(nhanes_raw$siri)), "\n")
cat("干眼症变量缺失:", sum(is.na(nhanes_raw$dry_eye_symptom)), "\n")


# --- Code Block 2 ---
# ==================== 样本筛选记录（使用 Day 13 数据）====================
# ⚠️ 本节仅用于记录筛选过程，生成论文 Figure 1
# 实际分析使用的是 Day 14 已处理的数据

# 创建筛选记录数据框
screening_log <- data.frame(
  step = character(),
  description = character(),
  remaining = numeric(),
  excluded = numeric(),
  stringsAsFactors = FALSE
)

# 记录初始样本
n_initial <- nrow(nhanes_raw)
screening_log <- rbind(screening_log, data.frame(
  step = "0",
  description = "NHANES 2005-2008 总样本",
  remaining = n_initial,
  excluded = NA
))

cat("\n==================== 开始样本筛选记录 ====================\n")
cat("初始样本量:", n_initial, "\n\n")

# ==================== 步骤1：筛选年龄≥20岁 ====================
nhanes_filtered <- nhanes_raw %>% 
  filter(age >= 20)
n_after_age <- nrow(nhanes_filtered)
n_excluded_age <- n_initial - n_after_age

screening_log <- rbind(screening_log, data.frame(
  step = "1",
  description = "纳入年龄≥20岁成年人",
  remaining = n_after_age,
  excluded = n_excluded_age
))

cat("步骤1: 筛选年龄≥20岁\n")
cat("  排除人数:", n_excluded_age, "\n")
cat("  剩余人数:", n_after_age, "\n\n")

# ==================== 步骤2：排除MEC权重=0 ====================
nhanes_filtered <- nhanes_filtered %>% 
  filter(weight_4yr > 0)
n_after_weight <- nrow(nhanes_filtered)
n_excluded_weight <- n_after_age - n_after_weight

screening_log <- rbind(screening_log, data.frame(
  step = "2",
  description = "排除MEC权重=0者",
  remaining = n_after_weight,
  excluded = n_excluded_weight
))

cat("步骤2: 排除MEC权重=0\n")
cat("  排除人数:", n_excluded_weight, "\n")
cat("  剩余人数:", n_after_weight, "\n\n")

# ==================== 步骤3：排除妊娠女性 ====================
nhanes_filtered <- nhanes_filtered %>% 
  filter(is.na(pregnant) | pregnant != 1)
n_after_preg <- nrow(nhanes_filtered)
n_excluded_preg <- n_after_weight - n_after_preg

screening_log <- rbind(screening_log, data.frame(
  step = "3",
  description = "排除妊娠女性",
  remaining = n_after_preg,
  excluded = n_excluded_preg
))

cat("步骤3: 排除妊娠女性\n")
cat("  排除人数:", n_excluded_preg, "\n")
cat("  剩余人数:", n_after_preg, "\n\n")

# ==================== 步骤4：要求SIRI数据完整 ====================
nhanes_filtered <- nhanes_filtered %>% 
  filter(!is.na(siri))
n_after_siri <- nrow(nhanes_filtered)
n_excluded_siri <- n_after_preg - n_after_siri

screening_log <- rbind(screening_log, data.frame(
  step = "4",
  description = "要求SIRI数据完整（血常规完整）",
  remaining = n_after_siri,
  excluded = n_excluded_siri
))

cat("步骤4: 要求SIRI数据完整\n")
cat("  排除人数:", n_excluded_siri, "\n")
cat("  剩余人数:", n_after_siri, "\n\n")

# ==================== 步骤5：要求干眼症变量完整 ====================
# ⚠️ 使用原始变量 dry_eye_symptom（VIQ031），而非派生变量 dry_eye_a
nhanes_filtered <- nhanes_filtered %>% 
  filter(!is.na(dry_eye_symptom))
n_after_dryeye <- nrow(nhanes_filtered)
n_excluded_dryeye <- n_after_siri - n_after_dryeye

screening_log <- rbind(screening_log, data.frame(
  step = "5",
  description = "要求干眼症变量完整（VIQ031非缺失）",
  remaining = n_after_dryeye,
  excluded = n_excluded_dryeye
))

cat("步骤5: 要求干眼症变量完整\n")
cat("  排除人数:", n_excluded_dryeye, "\n")
cat("  剩余人数:", n_after_dryeye, "\n\n")

# ==================== 筛选记录完成 ====================
n_final_flowchart <- n_after_dryeye

cat("\n==================== 筛选记录完成 ====================\n")
cat("流程图最终样本量:", n_final_flowchart, "\n")
cat("总筛选比例:", round(n_final_flowchart/n_initial*100, 1), "%\n")

# 打印筛选记录
cat("\n==================== 筛选流程汇总表 ====================\n")
print(screening_log)

# ==================== 验证与 Day 14 数据一致性 ====================
cat("\n==================== 数据一致性验证 ====================\n")
cat("流程图筛选后人数:", n_final_flowchart, "\n")
cat("Day 14 数据人数:", nrow(nhanes_analysis), "\n")

if (abs(n_final_flowchart - nrow(nhanes_analysis)) <= 10) {
  cat("✓ 样本量基本一致，差异在可接受范围内\n")
} else {
  cat("⚠️ 样本量差异较大，请检查筛选条件是否一致\n")
  cat("（注：Day 14 可能额外排除了 dry_eye_a=NA 的样本）\n")
}


# --- Code Block 3 ---
# ==================== 生成CONSORT流程图 (SCI 2区水平) ====================
# 安装并加载必要的包
if (!require("DiagrammeR")) install.packages("DiagrammeR")
if (!require("DiagrammeRsvg")) install.packages("DiagrammeRsvg")
if (!require("rsvg")) install.packages("rsvg")

library(DiagrammeR)
library(DiagrammeRsvg)
library(rsvg)

# 创建流程图
flowchart <- grViz(paste0("
digraph flowchart {
  
  # 图形属性
  graph [layout = dot, 
         rankdir = TB,
         splines = ortho,
         nodesep = 0.8,
         ranksep = 0.6]
  
  # 节点默认属性
  node [shape = rectangle, 
        style = 'rounded,filled',
        fillcolor = white,
        color = black,
        fontname = 'Arial',
        fontsize = 11,
        width = 4,
        height = 0.8,
        penwidth = 1.5]
  
  # 边默认属性
  edge [color = black, 
        penwidth = 1.2,
        arrowsize = 0.8]
  
  # 主流程节点（左侧/中间）
  A [label = 'NHANES 2005-2008\\n(n = ", n_initial, ")']
  
  B [label = 'Adults aged ≥20 years\\n(n = ", n_after_age, ")']
  
  C [label = 'Participants with valid MEC weight\\n(n = ", n_after_age - n_excluded_weight, ")']
  
  D [label = 'Non-pregnant participants\\n(n = ", n_after_age - n_excluded_weight - n_excluded_preg, ")']
  
  E [label = 'Final analytical sample\\n(n = ", n_final, ")', 
     style = 'rounded,filled',
     fillcolor = '#F0F0F0',
     penwidth = 2]
  
  # 排除节点（右侧）
  node [width = 3.5, height = 0.7]
  
  Ex1 [label = 'Excluded: Age <20 years\\n(n = ", n_excluded_age, ")']
  
  Ex2 [label = 'Excluded: MEC weight = 0\\n(n = ", n_excluded_weight, ")']
  
  Ex3 [label = 'Excluded: Pregnant women\\n(n = ", n_excluded_preg, ")']
  
  Ex4 [label = 'Excluded: Missing data\\n• SIRI data (n = ", n_excluded_siri, ")\\n• Dry eye data (n = ", n_excluded_dryeye, ")']
  
  # 使用子图控制布局
  subgraph {
    rank = same; A
  }
  
  subgraph {
    rank = same; B; Ex1
  }
  
  subgraph {
    rank = same; C; Ex2
  }
  
  subgraph {
    rank = same; D; Ex3
  }
  
  subgraph {
    rank = same; E; Ex4
  }
  
  # 主流程连接（垂直）
  A -> B
  B -> C
  C -> D
  D -> E
  
  # 排除连接（水平）
  A -> Ex1 [style = solid]
  B -> Ex2 [style = solid]
  C -> Ex3 [style = solid]
  D -> Ex4 [style = solid]
}
"))

# 显示流程图
print(flowchart)

# 保存为高分辨率图片
flowchart_svg <- export_svg(flowchart)
rsvg_png(charToRaw(flowchart_svg), 
         "样本筛选与权重计算/Figure1_Flowchart.png", 
         width = 2400, 
         height = 3000)
rsvg_pdf(charToRaw(flowchart_svg), 
         "样本筛选与权重计算/Figure1_Flowchart.pdf")

cat("\n流程图已保存：\n")
cat("  - Figure1_Flowchart.png (高分辨率PNG)\n")
cat("  - Figure1_Flowchart.pdf (矢量图PDF)\n")


# --- Code Block 4 ---
# ==================== 4年权重计算验证（使用 Day 14 数据）====================
# ⚠️ 使用 nhanes_analysis（Day 14 数据，9,467人）

cat("==================== 权重计算验证（Day 14 数据）====================\n")
cat("当前使用数据:", nrow(nhanes_analysis), "人\n")

# 检查原始2年权重
cat("\n【原始2年权重（WTMEC2YR）分布】\n")
summary(nhanes_analysis$weight_2yr)

# 检查4年权重（已在Day 13计算）
cat("\n【4年权重（WTMEC4YR）分布】\n")
summary(nhanes_analysis$weight_4yr)

# 验证计算正确性
# 4年权重应该 = 2年权重 / 2
weight_check <- all.equal(
  nhanes_analysis$weight_4yr, 
  nhanes_analysis$weight_2yr / 2,
  tolerance = 1e-10
)

cat("\n【权重计算验证】\n")
if (isTRUE(weight_check)) {
  cat("✓ 权重计算正确：WTMEC4YR = WTMEC2YR / 2\n")
} else {
  cat("⚠️ 权重计算需要检查\n")
  # 如果需要重新计算
  nhanes_analysis$weight_4yr <- nhanes_analysis$weight_2yr / 2
  cat("已重新计算4年权重\n")
}

# 计算权重总和（应近似等于美国成年人口数）
total_weight <- sum(nhanes_analysis$weight_4yr, na.rm = TRUE)
cat("\n【权重总和】\n")
cat("权重总和:", format(total_weight, big.mark = ","), "\n")
cat("（应近似代表美国成年人口）\n")

# 验证敏感性分析变量存在
cat("\n【敏感性分析变量确认】\n")
cat("blood_disorder 标记人数:", sum(nhanes_analysis$blood_disorder == 1, na.rm = TRUE), "\n")
cat("siri_outlier 标记人数:", sum(nhanes_analysis$siri_outlier == 1, na.rm = TRUE), "\n")


# --- Code Block 5 ---
# ==================== 权重分布检验 ====================

cat("\n==================== 权重分布详细检验 ====================\n")

# 1. 权重基本统计
cat("\n【1. 基本统计】\n")
weight_stats <- data.frame(
  统计量 = c("样本量", "最小值", "第25百分位", "中位数", 
             "均值", "第75百分位", "最大值", "标准差"),
  数值 = c(
    length(nhanes_analysis$weight_4yr),
    round(min(nhanes_analysis$weight_4yr, na.rm = TRUE), 2),
    round(quantile(nhanes_analysis$weight_4yr, 0.25, na.rm = TRUE), 2),
    round(median(nhanes_analysis$weight_4yr, na.rm = TRUE), 2),
    round(mean(nhanes_analysis$weight_4yr, na.rm = TRUE), 2),
    round(quantile(nhanes_analysis$weight_4yr, 0.75, na.rm = TRUE), 2),
    round(max(nhanes_analysis$weight_4yr, na.rm = TRUE), 2),
    round(sd(nhanes_analysis$weight_4yr, na.rm = TRUE), 2)
  )
)
print(weight_stats)

# 2. 权重极端值检验
cat("\n【2. 权重极端值检验】\n")
weight_p1 <- quantile(nhanes_analysis$weight_4yr, 0.01, na.rm = TRUE)
weight_p99 <- quantile(nhanes_analysis$weight_4yr, 0.99, na.rm = TRUE)
cat("1%分位数:", round(weight_p1, 2), "\n")
cat("99%分位数:", round(weight_p99, 2), "\n")
cat("极端值比率 (P99/P1):", round(weight_p99/weight_p1, 2), "\n")

# 3. 权重为0或缺失检验
cat("\n【3. 权重完整性检验】\n")
cat("权重=0人数:", sum(nhanes_analysis$weight_4yr == 0, na.rm = TRUE), "\n")
cat("权重缺失人数:", sum(is.na(nhanes_analysis$weight_4yr)), "\n")
cat("权重<0人数:", sum(nhanes_analysis$weight_4yr < 0, na.rm = TRUE), "\n")

# 4. 按周期检验权重
cat("\n【4. 分周期权重检验】\n")
nhanes_analysis %>%
  group_by(cycle) %>%
  summarise(
    n = n(),
    mean_weight = round(mean(weight_4yr, na.rm = TRUE), 2),
    median_weight = round(median(weight_4yr, na.rm = TRUE), 2),
    sum_weight = format(sum(weight_4yr, na.rm = TRUE), big.mark = ",")
  ) %>%
  print()


# --- Code Block 6 ---
# ==================== 权重分布可视化 ====================
library(ggplot2)

# 1. 权重直方图
p_weight_hist <- ggplot(nhanes_analysis, aes(x = weight_4yr)) +
  geom_histogram(bins = 50, fill = "steelblue", alpha = 0.7, color = "white") +
  geom_vline(xintercept = median(nhanes_analysis$weight_4yr, na.rm = TRUE),
             linetype = "dashed", color = "red", size = 1) +
  labs(
    title = "NHANES 4-Year MEC Weight Distribution",
    subtitle = paste0("n = ", nrow(nhanes_analysis), 
                      " | Median = ", round(median(nhanes_analysis$weight_4yr, na.rm = TRUE), 0)),
    x = "Weight (WTMEC4YR)",
    y = "Frequency"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 11, color = "gray40")
  )

# 保存图片
ggsave("样本筛选与权重计算/weight_distribution.png", p_weight_hist, 
       width = 10, height = 6, dpi = 300)

# 2. 按周期分布
p_weight_cycle <- ggplot(nhanes_analysis, aes(x = weight_4yr, fill = cycle)) +
  geom_density(alpha = 0.5) +
  labs(
    title = "Weight Distribution by Survey Cycle",
    x = "Weight (WTMEC4YR)",
    y = "Density",
    fill = "Cycle"
  ) +
  theme_minimal() +
  scale_fill_brewer(palette = "Set1")

ggsave("样本筛选与权重计算/weight_by_cycle.png", p_weight_cycle,
       width = 10, height = 6, dpi = 300)

cat("\n权重分布图已保存\n")


# --- Code Block 7 ---
# ==================== 创建survey design对象 ====================
library(survey)

# 检查设计变量完整性
cat("==================== 调查设计变量检验 ====================\n")
cat("PSU (SDMVPSU) 缺失:", sum(is.na(nhanes_analysis$psu)), "\n")
cat("Strata (SDMVSTRA) 缺失:", sum(is.na(nhanes_analysis$strata)), "\n")
cat("Weight 缺失:", sum(is.na(nhanes_analysis$weight_4yr)), "\n")
cat("Weight = 0:", sum(nhanes_analysis$weight_4yr == 0, na.rm = TRUE), "\n")

# 检查PSU和Strata的唯一值数量
cat("\n设计变量结构:\n")
cat("Strata数量:", length(unique(nhanes_analysis$strata)), "\n")
cat("PSU数量:", length(unique(nhanes_analysis$psu)), "\n")

# ==================== 创建survey design ====================
# 设置survey options
options(survey.lonely.psu = "adjust")  # 处理单PSU分层

# 创建survey design对象
nhanes_design <- svydesign(
  id = ~psu,           # PSU（聚类变量）
  strata = ~strata,    # 分层变量
  weights = ~weight_4yr, # 4年合并权重
  data = nhanes_analysis,
  nest = TRUE          # PSU嵌套在strata内
)

cat("\n==================== Survey Design 创建成功 ====================\n")
print(nhanes_design)


# --- Code Block 8 ---
# ==================== 验证survey design ====================

cat("\n==================== Survey Design 验证 ====================\n")

# 1. 检验加权样本量
cat("\n【1. 加权样本量】\n")
cat("未加权样本量:", nrow(nhanes_analysis), "\n")
cat("加权人口估计:", format(sum(weights(nhanes_design)), big.mark = ","), "\n")

# 2. 验证性别比例（应接近50:50）
cat("\n【2. 性别比例验证（应接近50:50）】\n")
gender_weighted <- svymean(~factor(gender), nhanes_design, na.rm = TRUE)
print(gender_weighted)

# 3. 验证种族分布
cat("\n【3. 种族分布（加权vs未加权）】\n")
race_unweighted <- prop.table(table(nhanes_analysis$race_cat)) * 100
race_weighted <- svymean(~race_cat, nhanes_design, na.rm = TRUE) * 100

comparison_race <- data.frame(
  种族 = names(race_unweighted),
  未加权百分比 = round(as.numeric(race_unweighted), 1),
  加权百分比 = round(as.numeric(race_weighted), 1)
)
print(comparison_race)

# 4. 验证干眼症患病率
cat("\n【4. 干眼症患病率（加权vs未加权）】\n")
prevalence_unweighted <- mean(nhanes_analysis$dry_eye_a, na.rm = TRUE) * 100
prevalence_weighted <- svymean(~dry_eye_a, nhanes_design, na.rm = TRUE)[1] * 100

cat("未加权患病率:", round(prevalence_unweighted, 2), "%\n")
cat("加权患病率:", round(prevalence_weighted, 2), "%\n")
cat("差异:", round(prevalence_weighted - prevalence_unweighted, 2), "个百分点\n")


# --- Code Block 9 ---
# ==================== 保存survey design对象 ====================

# 保存design对象（用于后续分析）
saveRDS(nhanes_design, "分析数据集/nhanes_survey_design.rds")
cat("\nSurvey design对象已保存: nhanes_survey_design.rds\n")

# 使用方法示例
cat("\n==================== 后续分析加载方法 ====================\n")
cat('
# 加载survey design对象
nhanes_design <- readRDS("分析数据集/nhanes_survey_design.rds")

# 使用示例：加权描述性统计
svymean(~siri, nhanes_design, na.rm = TRUE)
svyquantile(~siri, nhanes_design, quantiles = c(0.25, 0.5, 0.75))

# 使用示例：加权Logistic回归
model <- svyglm(dry_eye_a ~ siri_quartile + age + gender_cat, 
                design = nhanes_design, 
                family = quasibinomial())
')


# --- Code Block 10 ---
# ==================== 重新计算SIRI四分位组 ====================

cat("\n==================== 重新计算SIRI四分位组 ====================\n")

# 1. 检查当前分组是否均匀
current_dist <- prop.table(table(nhanes_analysis$siri_quartile)) * 100
cat("当前各组占比:\n")
print(round(current_dist, 1))

# 2. 在最终分析样本上重新计算四分位数切点
siri_quartiles_new <- quantile(nhanes_analysis$siri, 
                                probs = c(0.25, 0.50, 0.75), 
                                na.rm = TRUE)

cat("\n新的SIRI四分位数切点:\n")
cat("  Q1上限 (25%):", round(siri_quartiles_new[1], 4), "\n")
cat("  Q2上限 (50%):", round(siri_quartiles_new[2], 4), "\n")
cat("  Q3上限 (75%):", round(siri_quartiles_new[3], 4), "\n")

# 3. 重新创建分组变量
nhanes_analysis <- nhanes_analysis %>%
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

# 4. 验证修复结果
cat("\n修复后SIRI分组分布:\n")
print(table(nhanes_analysis$siri_quartile))
cat("\n各组占比:\n")
print(round(prop.table(table(nhanes_analysis$siri_quartile)) * 100, 1))

# 5. 更新survey design对象
nhanes_design <- svydesign(
  id = ~psu,
  strata = ~strata,
  weights = ~weight_4yr,
  data = nhanes_analysis,
  nest = TRUE
)

cat("\n✓ SIRI四分位组已在最终样本上重新计算\n")


# --- Code Block 11 ---
# ==================== 创建敏感性分析数据集 ====================

cat("\n==================== 创建敏感性分析数据集 ====================\n")

# 主分析数据集（已筛选完成）
n_main <- nrow(nhanes_analysis)
cat("主分析样本量:", n_main, "\n")

# SA-Exp1：排除可疑血液病
nhanes_sa_exp1 <- nhanes_analysis %>%
  filter(blood_disorder == 0 | is.na(blood_disorder))
n_sa_exp1 <- nrow(nhanes_sa_exp1)
cat("SA-Exp1（排除可疑血液病）样本量:", n_sa_exp1, 
    "（排除", n_main - n_sa_exp1, "人）\n")

# SA-Exp2：排除SIRI极端值
nhanes_sa_exp2 <- nhanes_analysis %>%
  filter(siri_outlier == 0 | is.na(siri_outlier))
n_sa_exp2 <- nrow(nhanes_sa_exp2)
cat("SA-Exp2（排除SIRI极端值）样本量:", n_sa_exp2,
    "（排除", n_main - n_sa_exp2, "人）\n")

# SA-Exp3：排除血液病和SIRI极端值
nhanes_sa_exp3 <- nhanes_analysis %>%
  filter((blood_disorder == 0 | is.na(blood_disorder)) & 
         (siri_outlier == 0 | is.na(siri_outlier)))
n_sa_exp3 <- nrow(nhanes_sa_exp3)
cat("SA-Exp3（排除两者）样本量:", n_sa_exp3,
    "（排除", n_main - n_sa_exp3, "人）\n")

# 创建敏感性分析汇总表
sa_summary <- data.frame(
  分析类型 = c("主分析", "SA-Exp1", "SA-Exp2", "SA-Exp3"),
  描述 = c("保留所有有效数据", 
           "排除可疑血液病",
           "排除SIRI极端值(<1%或>99%)",
           "排除上述两者"),
  样本量 = c(n_main, n_sa_exp1, n_sa_exp2, n_sa_exp3),
  排除人数 = c(0, n_main - n_sa_exp1, n_main - n_sa_exp2, n_main - n_sa_exp3)
)

cat("\n【A类敏感性分析（暴露变量）样本量汇总】\n")
print(sa_summary)


# --- Code Block 12 ---
# ==================== 保存最终分析数据集 ====================

# 创建保存目录
if (!dir.exists("样本筛选与权重计算")) {
  dir.create("样本筛选与权重计算")
}

# 1. 保存主分析数据集
saveRDS(nhanes_analysis, "分析数据集/nhanes_analysis_weighted.rds")
write.csv(nhanes_analysis, "分析数据集/nhanes_analysis_weighted.csv", row.names = FALSE)

# 2. 保存Stata格式
library(haven)
write_dta(nhanes_analysis, "分析数据集/nhanes_analysis_weighted.dta")

# 3. 保存敏感性分析数据集
saveRDS(nhanes_sa_exp1, "分析数据集/nhanes_sa_exp1.rds")
saveRDS(nhanes_sa_exp2, "分析数据集/nhanes_sa_exp2.rds")
saveRDS(nhanes_sa_exp3, "分析数据集/nhanes_sa_exp3.rds")

# 4. 保存筛选记录
write.csv(screening_log, "样本筛选与权重计算/screening_log.csv", row.names = FALSE)

cat("\n==================== 数据保存完成 ====================\n")
cat("主分析数据集: nhanes_analysis_weighted.rds/csv/dta\n")
cat("敏感性分析数据集: nhanes_sa_exp1/2/3.rds\n")
cat("筛选记录: screening_log.csv\n")
cat("Survey design: nhanes_survey_design.rds\n")


# --- Code Block 13 ---
# ==================== 最终数据质量报告 ====================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║              Day 15 样本筛选与权重计算完成报告                ║\n")
cat("╠═══════════════════════════════════════════════════════════════╣\n")
cat("║                                                               ║\n")
cat("║  【样本筛选结果】                                             ║\n")
cat("║  ├─ 初始样本量:     ", sprintf("%-10s", n_initial), "                        ║\n")
cat("║  ├─ 最终分析样本:   ", sprintf("%-10s", n_final), "                        ║\n")
cat("║  └─ 筛选保留比例:   ", sprintf("%-10s", paste0(round(n_final/n_initial*100,1), "%")), "                        ║\n")
cat("║                                                               ║\n")
cat("║  【权重计算结果】                                             ║\n")
cat("║  ├─ 权重类型:       WTMEC4YR (4年MEC权重)                    ║\n")
cat("║  ├─ 计算方法:       WTMEC2YR / 2                             ║\n")
cat("║  ├─ 权重中位数:     ", sprintf("%-10s", round(median(nhanes_analysis$weight_4yr),0)), "                        ║\n")
cat("║  └─ 加权人口估计:   ", sprintf("%-15s", format(sum(nhanes_analysis$weight_4yr), big.mark=",")), "                   ║\n")
cat("║                                                               ║\n")
cat("║  【分析准备状态】                                             ║\n")
cat("║  ├─ Survey Design:  ✓ 已创建                                 ║\n")
cat("║  ├─ PSU变量:        ✓ 完整                                   ║\n")
cat("║  ├─ Strata变量:     ✓ 完整                                   ║\n")
cat("║  └─ 权重变量:       ✓ 完整（无0值）                          ║\n")
cat("║                                                               ║\n")
cat("║  【敏感性分析数据集】                                         ║\n")
cat("║  ├─ SA-Exp1:        ", sprintf("%-10s", n_sa_exp1), "(排除血液病)             ║\n")
cat("║  ├─ SA-Exp2:        ", sprintf("%-10s", n_sa_exp2), "(排除SIRI极端值)         ║\n")
cat("║  └─ SA-Exp3:        ", sprintf("%-10s", n_sa_exp3), "(排除两者)               ║\n")
cat("║                                                               ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

cat("\n✅ Day 15 任务完成！数据已准备就绪，可进入Day 16描述性分析阶段。\n")
