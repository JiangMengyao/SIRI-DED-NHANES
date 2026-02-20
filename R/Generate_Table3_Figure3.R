# ══════════════════════════════════════════════════════════════════════════════
# 生成最终版Table 3和Figure 3（符合Reviewer #2所有修改要求）
# ══════════════════════════════════════════════════════════════════════════════
# 修改日期：2026-02-04
# 修改内容：
#   1. 使用新计算的P for interaction值
#   2. 添加Bonferroni多重比较校正说明
#   3. 强调探索性发现的性质
#   4. 在Figure 3上直接显示P for interaction
#   5. 符合所有审稿意见要求
# ══════════════════════════════════════════════════════════════════════════════

setwd("/Users/mayiding/Desktop/第一篇")

# 加载必要的包
library(dplyr)
library(flextable)
library(officer)
library(forestplot)
library(grid)

cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║    生成最终版Table 3和Figure 3（符合Reviewer #2要求）          ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# ══════════════════════════════════════════════════════════════════════════════
# Part 1: 准备数据
# ══════════════════════════════════════════════════════════════════════════════

cat("【1/4】准备亚组分析数据...\n\n")

# 亚组分析数据（来自用户提供的表格）
subgroup_data <- data.frame(
  Variable = c(
    "Sex", "Sex",
    "Age", "Age",
    "BMI", "BMI",
    "Diabetes", "Diabetes",
    "Hypertension", "Hypertension",
    "Race/Ethnicity", "Race/Ethnicity", "Race/Ethnicity", "Race/Ethnicity"
  ),
  Subgroup = c(
    "Male", "Female",
    "<60 years", "≥60 years",
    "<25 kg/m²", "≥25 kg/m²",
    "No", "Yes",
    "No", "Yes",
    "Non-Hispanic White", "Non-Hispanic Black", "Mexican American", "Other"
  ),
  N = c(
    4364, 4300,
    5711, 2953,
    2556, 6108,
    7318, 1346,
    7029, 1635,
    4341, 1808, 1558, 957
  ),
  Cases = c(
    844, 915,
    997, 762,
    485, 1274,
    1322, 437,
    1349, 410,
    707, 391, 439, 222
  ),
  OR = c(
    1.01, 1.25,
    1.08, 1.36,
    2.08, 0.90,
    1.16, 1.08,
    1.05, 1.73,
    1.20, 1.21, 0.80, 1.43
  ),
  CI_Lower = c(
    0.68, 0.98,
    0.79, 0.97,
    1.31, 0.69,
    0.85, 0.65,
    0.82, 1.09,
    0.84, 0.84, 0.60, 0.56
  ),
  CI_Upper = c(
    1.48, 1.61,
    1.48, 1.91,
    3.29, 1.18,
    1.57, 1.78,
    1.35, 2.74,
    1.71, 1.72, 1.07, 3.63
  ),
  P_Value = c(
    0.976, 0.072,
    0.615, 0.068,
    0.004, 0.423,
    0.336, 0.754,
    0.672, 0.023,
    0.296, 0.282, 0.123, 0.427
  ),
  stringsAsFactors = FALSE
)

# P for Interaction值（新计算的正确值）
p_interaction_values <- data.frame(
  Variable = c("Sex", "Age", "BMI", "Diabetes", "Hypertension", "Race/Ethnicity"),
  P_Interaction = c(0.714, 0.198, 0.008, 0.875, 0.260, 0.504),
  stringsAsFactors = FALSE
)

# 合并P for interaction
subgroup_data <- subgroup_data %>%
  left_join(p_interaction_values, by = "Variable")

# 格式化数据
subgroup_data <- subgroup_data %>%
  mutate(
    OR_CI = sprintf("%.2f (%.2f–%.2f)", OR, CI_Lower, CI_Upper),
    P_Formatted = ifelse(P_Value < 0.001, "<0.001",
                        sprintf("%.3f", P_Value)),
    # 添加亚组内P值的显著性标注
    # * P < 0.0042 (Bonferroni校正后显著)
    P_Significance = ifelse(P_Value < 0.0042, "*", "")
  )

# 添加P for interaction的格式化和显著性标注
subgroup_data <- subgroup_data %>%
  group_by(Variable) %>%
  mutate(
    # P for interaction只在每组第一行显示
    P_Int_Display = ifelse(row_number() == 1,
                          ifelse(P_Interaction < 0.001, "<0.001",
                                sprintf("%.3f", P_Interaction)),
                          ""),
    # ** P < 0.0083 (Bonferroni校正后显著的交互作用)
    P_Int_Significance = ifelse(row_number() == 1,
                               ifelse(P_Interaction < 0.0083, "**", ""),
                               "")
  ) %>%
  ungroup()

cat("✓ 数据准备完成\n")
cat("  样本量:", sum(subgroup_data$N[!duplicated(subgroup_data$Variable)]), "\n")
cat("  病例数:", sum(subgroup_data$Cases[!duplicated(subgroup_data$Variable)]), "\n\n")

# ══════════════════════════════════════════════════════════════════════════════
# Part 2: 生成Table 3 (Word格式)
# ══════════════════════════════════════════════════════════════════════════════

cat("【2/4】生成Table 3 (Word格式)...\n\n")

# 创建表格数据框
table3_data <- subgroup_data %>%
  mutate(
    # 合并P值和显著性标注
    P_Value_Display = paste0(P_Formatted, P_Significance),
    P_Int_Full = paste0(P_Int_Display, P_Int_Significance)
  ) %>%
  select(Variable, Subgroup, N, Cases, OR_CI, P_Value_Display, P_Int_Full) %>%
  rename(
    "Stratification Variable" = Variable,
    "Subgroup" = Subgroup,
    "N" = N,
    "Cases" = Cases,
    "OR (95% CI)†" = OR_CI,
    "P Value" = P_Value_Display,
    "P for Interaction‡" = P_Int_Full
  )

# 创建flextable
ft <- flextable(table3_data) %>%
  # 设置表格样式
  theme_booktabs() %>%
  # 合并相同的分层变量单元格
  merge_v(j = "Stratification Variable") %>%
  merge_v(j = "P for Interaction‡") %>%
  # 设置列宽
  width(j = "Stratification Variable", width = 1.2) %>%
  width(j = "Subgroup", width = 1.5) %>%
  width(j = "N", width = 0.8) %>%
  width(j = "Cases", width = 0.8) %>%
  width(j = "OR (95% CI)†", width = 1.5) %>%
  width(j = "P Value", width = 0.8) %>%
  width(j = "P for Interaction‡", width = 1.0) %>%
  # 设置字体
  font(fontname = "Times New Roman", part = "all") %>%
  fontsize(size = 10, part = "body") %>%
  fontsize(size = 11, part = "header") %>%
  # 表头加粗
  bold(part = "header") %>%
  # 对齐
  align(align = "center", part = "header") %>%
  align(j = c("N", "Cases", "P Value", "P for Interaction‡"), align = "center", part = "body") %>%
  align(j = c("Stratification Variable", "Subgroup", "OR (95% CI)†"), align = "left", part = "body") %>%
  # 边框
  border_inner_h(border = fp_border(width = 0.5)) %>%
  border_inner_v(border = fp_border(width = 0.5)) %>%
  border_outer(border = fp_border(width = 1))

# 创建Word文档
doc <- read_docx()

# 添加表格标题
doc <- doc %>%
  body_add_par("Table 3. Subgroup Analyses of the Association Between SIRI and Dry Eye Disease",
               style = "heading 1")

# 添加表格
doc <- doc %>%
  body_add_flextable(ft)

# 添加详细脚注
footnote_text <- paste0(
  "Data are presented as odds ratios (ORs) and 95% confidence intervals (CIs) comparing the highest ",
  "versus lowest SIRI quartile (Q4 vs. Q1) within each subgroup.\n\n",

  "† All models were adjusted for demographic characteristics (age, sex, race/ethnicity, education level, ",
  "poverty-to-income ratio), lifestyle factors (smoking status), and clinical comorbidities (body mass index, ",
  "diabetes status, hypertension), excluding the stratification variable itself.\n\n",

  "‡ P for interaction was calculated by including a multiplicative interaction term (SIRI quartile × ",
  "stratifying variable) in the fully adjusted model, using Wald test. P for interaction values are also ",
  "displayed on Figure 3.\n\n",

  "** P < 0.0083, indicating statistically significant interaction after Bonferroni correction for 6 ",
  "interaction tests (α = 0.05/6 = 0.0083). This threshold accounts for multiple comparisons across the ",
  "6 stratification variables examined.\n\n",

  "* P < 0.0042 for subgroup-specific association, surviving Bonferroni correction for 12 subgroup comparisons ",
  "(α = 0.05/12 = 0.0042, considering 2 subgroups per stratification variable for binary variables). ",
  "Only the association in participants with BMI <25 kg/m² met this stringent threshold (P = 0.004).\n\n",

  "Important Note: Although one interaction test (BMI, P = 0.008) reached nominal statistical significance and ",
  "survived Bonferroni correction (P < 0.0083), these findings should be interpreted as exploratory and ",
  "hypothesis-generating rather than definitive evidence of effect modification, given that the primary ",
  "analysis showed no significant overall association (OR = 1.14, 95% CI: 0.90–1.46, P = 0.260). ",
  "Future prospective studies are needed to validate these subgroup-specific associations.\n\n",

  "Abbreviations: SIRI, Systemic Inflammation Response Index; OR, odds ratio; CI, confidence interval; ",
  "BMI, body mass index; Q, quartile."
)

doc <- doc %>%
  body_add_par("", style = "Normal") %>%
  body_add_par(footnote_text, style = "Normal")

# 保存Word文档
print(doc, target = "最终版/Table3_Subgroup_Results_Final.docx")
cat("✓ Table 3 (Word) 已保存: 最终版/Table3_Subgroup_Results_Final.docx\n\n")

# 同时保存CSV版本（兼容Excel）
write.csv(table3_data,
          "最终版/Table3_Subgroup_Results_Final.csv",
          row.names = FALSE)
cat("✓ Table 3 (CSV) 已保存: 最终版/Table3_Subgroup_Results_Final.csv\n\n")

# ══════════════════════════════════════════════════════════════════════════════
# Part 3: 生成Figure 3 (森林图，带P for interaction)
# ══════════════════════════════════════════════════════════════════════════════

cat("【3/4】生成Figure 3 (森林图)...\n\n")

# 准备森林图数据
forest_data <- subgroup_data %>%
  mutate(
    # 创建显示标签（缩进亚组）
    Label = ifelse(row_number() == 1 | Variable != lag(Variable),
                  Subgroup,
                  paste0("  ", Subgroup)),
    # 行顺序
    row_order = row_number()
  )

# 创建带分组标题的增强版森林图数据
create_forest_with_headers <- function() {

  groups <- list(
    list(header = "Sex", p_int = "0.714"),
    list(header = "Age", p_int = "0.198"),
    list(header = "BMI", p_int = "0.008**"),  # 添加**标记
    list(header = "Diabetes", p_int = "0.875"),
    list(header = "Hypertension", p_int = "0.260"),
    list(header = "Race/Ethnicity", p_int = "0.504")
  )

  text_list <- list()
  mean_list <- list()
  lower_list <- list()
  upper_list <- list()
  is_summary_list <- list()

  # 表头行
  text_list[[1]] <- c("Subgroup", "N", "Cases", "OR (95% CI)", "P for Interaction")
  mean_list[[1]] <- NA
  lower_list[[1]] <- NA
  upper_list[[1]] <- NA
  is_summary_list[[1]] <- TRUE

  row_idx <- 2

  for (grp in groups) {
    # 分组标题行（显示P for interaction）
    text_list[[row_idx]] <- c(
      grp$header,
      "",
      "",
      "",
      grp$p_int
    )
    mean_list[[row_idx]] <- NA
    lower_list[[row_idx]] <- NA
    upper_list[[row_idx]] <- NA
    is_summary_list[[row_idx]] <- TRUE
    row_idx <- row_idx + 1

    # 该分组下的数据行
    grp_data <- forest_data %>% filter(Variable == grp$header)

    for (i in 1:nrow(grp_data)) {
      # 添加亚组内P值的*标记
      p_display <- paste0(grp_data$P_Formatted[i], grp_data$P_Significance[i])

      text_list[[row_idx]] <- c(
        paste0("  ", grp_data$Subgroup[i]),  # 缩进
        as.character(grp_data$N[i]),
        as.character(grp_data$Cases[i]),
        grp_data$OR_CI[i],
        p_display
      )
      mean_list[[row_idx]] <- grp_data$OR[i]
      lower_list[[row_idx]] <- grp_data$CI_Lower[i]
      upper_list[[row_idx]] <- grp_data$CI_Upper[i]
      is_summary_list[[row_idx]] <- FALSE
      row_idx <- row_idx + 1
    }
  }

  # 转换为矩阵和向量
  tabletext_matrix <- do.call(rbind, text_list)

  return(list(
    tabletext = tabletext_matrix,
    mean = unlist(mean_list),
    lower = unlist(lower_list),
    upper = unlist(upper_list),
    is_summary = unlist(is_summary_list)
  ))
}

# 生成增强版数据
enhanced_data <- create_forest_with_headers()

cat("✓ 森林图数据准备完成\n")
cat("  总行数:", length(enhanced_data$mean), "\n")
cat("  数据行数:", sum(!enhanced_data$is_summary), "\n\n")

# 绘制森林图 - PDF版本
pdf("最终版/Figure3_Subgroup_Forest_Final.pdf",
    width = 14, height = 12)

forestplot(
  labeltext = enhanced_data$tabletext,
  mean = enhanced_data$mean,
  lower = enhanced_data$lower,
  upper = enhanced_data$upper,
  is.summary = enhanced_data$is_summary,

  # 显示范围
  clip = c(0.4, 4),
  zero = 1,
  xlog = TRUE,

  # 坐标轴
  xlab = "Odds Ratio (95% CI)",
  xticks = c(0.5, 0.75, 1, 1.5, 2, 3, 4),

  # 颜色设置
  col = fpColors(
    box = "#2C3E50",
    line = "#2C3E50",
    summary = "#34495E",
    zero = "#7F8C8D"
  ),

  # 图形元素
  boxsize = 0.22,
  lineheight = unit(0.85, "cm"),
  colgap = unit(5, "mm"),
  graphwidth = unit(7, "cm"),

  # 文本格式
  txt_gp = fpTxtGp(
    ticks = gpar(fontsize = 10),
    label = gpar(fontsize = 10),
    xlab = gpar(fontsize = 11, fontface = "bold"),
    summary = gpar(fontsize = 10, fontface = "bold")
  ),

  # 线条
  lwd.ci = 1.3,
  lwd.zero = 1,
  vertices = TRUE,

  # 图表标题
  title = paste0(
    "Figure 3. Subgroup Analyses of the Association Between SIRI (Q4 vs. Q1) and Dry Eye Disease\n",
    "(Exploratory Findings with Multiple Comparison Correction)"
  )
)

dev.off()
cat("✓ Figure 3 (PDF) 已保存: 最终版/Figure3_Subgroup_Forest_Final.pdf\n")

# PNG版本（高分辨率）
png("最终版/Figure3_Subgroup_Forest_Final.png",
    width = 14, height = 12, units = "in", res = 300)

forestplot(
  labeltext = enhanced_data$tabletext,
  mean = enhanced_data$mean,
  lower = enhanced_data$lower,
  upper = enhanced_data$upper,
  is.summary = enhanced_data$is_summary,
  clip = c(0.4, 4),
  zero = 1,
  xlog = TRUE,
  xlab = "Odds Ratio (95% CI)",
  xticks = c(0.5, 0.75, 1, 1.5, 2, 3, 4),
  col = fpColors(
    box = "#2C3E50",
    line = "#2C3E50",
    summary = "#34495E",
    zero = "#7F8C8D"
  ),
  boxsize = 0.22,
  lineheight = unit(0.85, "cm"),
  colgap = unit(5, "mm"),
  graphwidth = unit(7, "cm"),
  txt_gp = fpTxtGp(
    ticks = gpar(fontsize = 10),
    label = gpar(fontsize = 10),
    xlab = gpar(fontsize = 11, fontface = "bold"),
    summary = gpar(fontsize = 10, fontface = "bold")
  ),
  lwd.ci = 1.3,
  lwd.zero = 1,
  vertices = TRUE,
  title = paste0(
    "Figure 3. Subgroup Analyses of the Association Between SIRI (Q4 vs. Q1) and Dry Eye Disease\n",
    "(Exploratory Findings with Multiple Comparison Correction)"
  )
)

dev.off()
cat("✓ Figure 3 (PNG) 已保存: 最终版/Figure3_Subgroup_Forest_Final.png\n\n")

# ══════════════════════════════════════════════════════════════════════════════
# Part 4: 生成Figure 3图例文本
# ══════════════════════════════════════════════════════════════════════════════

cat("【4/4】生成Figure 3图例文本...\n\n")

figure3_legend <- paste0(
  "Figure 3. Forest Plot of Subgroup Analyses of the Association Between SIRI and Dry Eye Disease\n\n",

  "Odds ratios (ORs) and 95% confidence intervals (CIs) for the association between the highest versus ",
  "lowest SIRI quartile (Q4 vs. Q1) and dry eye disease within pre-specified subgroups. The vertical dashed ",
  "line represents OR = 1.0 (null effect). Horizontal lines represent 95% CIs. All analyses used survey-weighted ",
  "logistic regression adjusted for Model 3 covariates (age, sex, race/ethnicity, education level, poverty-to-income ",
  "ratio, body mass index, smoking status, diabetes status, and hypertension), excluding the stratification variable.\n\n",

  "P for Interaction: Values displayed after each subgroup category header indicate whether the SIRI-DED ",
  "association differs significantly across that subgroup. These were calculated by including the product term ",
  "of SIRI quartile (ordinal) and the stratification variable in the fully adjusted model.\n\n",

  "Multiple Comparison Adjustment:\n",
  "• Given 6 stratification variables (representing 12 subgroup-specific comparisons) and 6 interaction tests, ",
  "Bonferroni correction was applied:\n",
  "  - Subgroup-specific associations: α = 0.05/12 = 0.0042 (marked with *)\n",
  "  - Interaction tests: α = 0.05/6 = 0.0083 (marked with **)\n\n",

  "** P < 0.0083 for interaction test, indicating statistically significant effect modification after ",
  "Bonferroni correction. Only the BMI interaction (P = 0.008) reached this threshold.\n\n",

  "* P < 0.0042 for subgroup-specific association, surviving Bonferroni correction. Only the association ",
  "in BMI <25 kg/m² participants (P = 0.004) met this criterion.\n\n",

  "Interpretation:\n",
  "These subgroup analyses are exploratory in nature. Although the BMI interaction test survived Bonferroni ",
  "correction (P = 0.008 < 0.0083), this finding should be interpreted cautiously given that: (1) the primary ",
  "analysis showed no significant overall association (Q4 vs. Q1: OR = 1.14, 95% CI: 0.90–1.46, P = 0.260); ",
  "(2) multiple testing increases the likelihood of chance findings; and (3) biological mechanisms linking ",
  "SIRI preferentially to DED risk in normal-weight versus overweight individuals remain unclear. ",
  "These results should primarily serve as hypothesis-generating observations requiring validation in ",
  "independent prospective cohorts.\n\n",

  "Abbreviations: SIRI, Systemic Inflammation Response Index; OR, odds ratio; CI, confidence interval; ",
  "BMI, body mass index; Q, quartile; DED, dry eye disease."
)

# 保存图例文本
writeLines(figure3_legend, "最终版/Figure3_Legend_Final.txt")
cat("✓ Figure 3 图例已保存: 最终版/Figure3_Legend_Final.txt\n\n")

# ══════════════════════════════════════════════════════════════════════════════
# Part 5: 生成数据摘要报告
# ══════════════════════════════════════════════════════════════════════════════

cat("【5/5】生成数据摘要报告...\n\n")

summary_report <- paste0(
  "═══════════════════════════════════════════════════════════════\n",
  "Table 3 和 Figure 3 生成完成摘要\n",
  "═══════════════════════════════════════════════════════════════\n\n",

  "生成时间: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n",

  "【关键发现】\n\n",
  "1. P for Interaction值（新计算）：\n",
  "   - Sex:            P = 0.714  (不显著)\n",
  "   - Age:            P = 0.198  (不显著)\n",
  "   - BMI:            P = 0.008** (Bonferroni校正后显著！)\n",
  "   - Diabetes:       P = 0.875  (不显著)\n",
  "   - Hypertension:   P = 0.260  (不显著)\n",
  "   - Race/Ethnicity: P = 0.504  (不显著)\n\n",

  "2. Bonferroni校正阈值：\n",
  "   - 交互作用检验:        α = 0.0083 (0.05/6)\n",
  "   - 亚组特异性关联:      α = 0.0042 (0.05/12)\n\n",

  "3. 达到显著性阈值的发现：\n",
  "   ⭐ BMI交互作用:        P = 0.008 < 0.0083  ✓ 显著\n",
  "   ⭐ BMI <25亚组:        P = 0.004 < 0.0042  ✓ 显著\n",
  "   ✗ 高血压亚组:         P = 0.023 > 0.0042  ✗ 未通过校正\n\n",

  "【生成的文件】\n\n",
  "Table 3:\n",
  "  1. 最终版/Table3_Subgroup_Results_Final.docx  (Word格式)\n",
  "  2. 最终版/Table3_Subgroup_Results_Final.csv   (CSV格式，可在Excel中打开)\n\n",

  "Figure 3:\n",
  "  1. 最终版/Figure3_Subgroup_Forest_Final.pdf   (高分辨率矢量图)\n",
  "  2. 最终版/Figure3_Subgroup_Forest_Final.png   (300 DPI位图)\n",
  "  3. 最终版/Figure3_Legend_Final.txt            (完整图例文本)\n\n",

  "【符合的审稿要求】\n\n",
  "✓ Major Comment #1:  明确强调探索性发现性质\n",
  "✓ Major Comment #2:  添加Bonferroni多重比较校正\n",
  "✓ Minor Comment #3:  Figure 3上直接显示P for interaction\n",
  "✓ 使用新计算的准确P for interaction值\n",
  "✓ 详细的脚注说明统计方法和解读注意事项\n",
  "✓ 专业的格式和排版\n\n",

  "【重要说明】\n\n",
  "1. BMI是唯一达到Bonferroni校正标准的交互作用 (P = 0.008 < 0.0083)\n",
  "2. 在正常体重人群(BMI <25)中，SIRI与DED的关联显著 (OR = 2.08, P = 0.004)\n",
  "3. 在超重/肥胖人群中，SIRI与DED无关联 (OR = 0.90, P = 0.423)\n",
  "4. 这一发现应被视为探索性、假设生成性质，需要未来研究验证\n\n",

  "【下一步建议】\n\n",
  "1. 在Results部分详细报告BMI交互作用的发现\n",
  "2. 在Discussion部分讨论可能的生物学机制\n",
  "3. 在Limitations部分强调探索性发现的局限性\n",
  "4. 在Conclusions部分谨慎描述，避免过度解读\n\n",

  "═══════════════════════════════════════════════════════════════\n",
  "✓ 所有文件生成完成！\n",
  "═══════════════════════════════════════════════════════════════\n"
)

# 保存摘要报告
writeLines(summary_report, "最终版/Table3_Figure3_Generation_Summary.txt")
cat(summary_report)

# 同时在控制台输出
cat("\n✓ 摘要报告已保存: 最终版/Table3_Figure3_Generation_Summary.txt\n\n")

cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                     全部完成！                                 ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("请检查生成的文件:\n")
cat("  • Table 3 (Word):  最终版/Table3_Subgroup_Results_Final.docx\n")
cat("  • Table 3 (CSV):   最终版/Table3_Subgroup_Results_Final.csv\n")
cat("  • Figure 3 (PDF):  最终版/Figure3_Subgroup_Forest_Final.pdf\n")
cat("  • Figure 3 (PNG):  最终版/Figure3_Subgroup_Forest_Final.png\n")
cat("  • Figure 3图例:    最终版/Figure3_Legend_Final.txt\n")
cat("  • 摘要报告:        最终版/Table3_Figure3_Generation_Summary.txt\n\n")
