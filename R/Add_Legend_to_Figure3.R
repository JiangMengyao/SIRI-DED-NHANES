# ══════════════════════════════════════════════════════════════════════════════
# 为Figure 3添加完整图例（Times New Roman, 9号字）
# ══════════════════════════════════════════════════════════════════════════════

setwd("/Users/mayiding/Desktop/第一篇")

library(forestplot)
library(grid)
library(dplyr)

cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║           为Figure 3添加完整图例（带图例文本）                 ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# ══════════════════════════════════════════════════════════════════════════════
# 1. 准备数据（与之前相同）
# ══════════════════════════════════════════════════════════════════════════════

cat("【1/3】准备数据...\n")

# 亚组分析数据
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
  N = c(4364, 4300, 5711, 2953, 2556, 6108, 7318, 1346, 7029, 1635, 4341, 1808, 1558, 957),
  Cases = c(844, 915, 997, 762, 485, 1274, 1322, 437, 1349, 410, 707, 391, 439, 222),
  OR = c(1.01, 1.25, 1.08, 1.36, 2.08, 0.90, 1.16, 1.08, 1.05, 1.73, 1.20, 1.21, 0.80, 1.43),
  CI_Lower = c(0.68, 0.98, 0.79, 0.97, 1.31, 0.69, 0.85, 0.65, 0.82, 1.09, 0.84, 0.84, 0.60, 0.56),
  CI_Upper = c(1.48, 1.61, 1.48, 1.91, 3.29, 1.18, 1.57, 1.78, 1.35, 2.74, 1.71, 1.72, 1.07, 3.63),
  P_Value = c(0.976, 0.072, 0.615, 0.068, 0.004, 0.423, 0.336, 0.754, 0.672, 0.023, 0.296, 0.282, 0.123, 0.427),
  stringsAsFactors = FALSE
)

# P for Interaction值
p_interaction_values <- data.frame(
  Variable = c("Sex", "Age", "BMI", "Diabetes", "Hypertension", "Race/Ethnicity"),
  P_Interaction = c(0.714, 0.198, 0.008, 0.875, 0.260, 0.504),
  stringsAsFactors = FALSE
)

subgroup_data <- subgroup_data %>%
  left_join(p_interaction_values, by = "Variable") %>%
  mutate(
    OR_CI = sprintf("%.2f (%.2f–%.2f)", OR, CI_Lower, CI_Upper),
    P_Formatted = ifelse(P_Value < 0.001, "<0.001", sprintf("%.3f", P_Value)),
    P_Significance = ifelse(P_Value < 0.0042, "*", "")
  )

forest_data <- subgroup_data %>%
  mutate(
    Label = ifelse(row_number() == 1 | Variable != lag(Variable),
                  Subgroup, paste0("  ", Subgroup)),
    row_order = row_number()
  )

# 创建带分组标题的森林图数据
create_forest_with_headers <- function() {
  groups <- list(
    list(header = "Sex", p_int = "0.714"),
    list(header = "Age", p_int = "0.198"),
    list(header = "BMI", p_int = "0.008**"),
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
    text_list[[row_idx]] <- c(grp$header, "", "", "", grp$p_int)
    mean_list[[row_idx]] <- NA
    lower_list[[row_idx]] <- NA
    upper_list[[row_idx]] <- NA
    is_summary_list[[row_idx]] <- TRUE
    row_idx <- row_idx + 1

    grp_data <- forest_data %>% filter(Variable == grp$header)

    for (i in 1:nrow(grp_data)) {
      p_display <- paste0(grp_data$P_Formatted[i], grp_data$P_Significance[i])
      text_list[[row_idx]] <- c(
        paste0("  ", grp_data$Subgroup[i]),
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

  tabletext_matrix <- do.call(rbind, text_list)

  return(list(
    tabletext = tabletext_matrix,
    mean = unlist(mean_list),
    lower = unlist(lower_list),
    upper = unlist(upper_list),
    is_summary = unlist(is_summary_list)
  ))
}

enhanced_data <- create_forest_with_headers()
cat("✓ 数据准备完成\n\n")

# ══════════════════════════════════════════════════════════════════════════════
# 2. 生成带完整图例的Figure 3 PDF
# ══════════════════════════════════════════════════════════════════════════════

cat("【2/3】生成带完整图例的Figure 3 PDF...\n")

# 准备图例文本（分段，便于排版）
legend_lines <- c(
  "Figure 3. Forest Plot of Subgroup Analyses of the Association Between SIRI and Dry Eye Disease",
  "",
  "Odds ratios (ORs) and 95% confidence intervals (CIs) for the association between the highest versus lowest SIRI quartile (Q4 vs. Q1) and dry eye",
  "disease within pre-specified subgroups. The vertical dashed line represents OR = 1.0 (null effect). Horizontal lines represent 95% CIs. All analyses",
  "used survey-weighted logistic regression adjusted for Model 3 covariates (age, sex, race/ethnicity, education level, poverty-to-income ratio, body",
  "mass index, smoking status, diabetes status, and hypertension), excluding the stratification variable.",
  "",
  "P for Interaction: Values displayed after each subgroup category header indicate whether the SIRI-DED association differs significantly across that",
  "subgroup. These were calculated by including the product term of SIRI quartile (ordinal) and the stratification variable in the fully adjusted model.",
  "",
  "Multiple Comparison Adjustment: Given 6 stratification variables (representing 12 subgroup-specific comparisons) and 6 interaction tests,",
  "Bonferroni correction was applied: (1) Subgroup-specific associations: α = 0.05/12 = 0.0042 (marked with *); (2) Interaction tests: α = 0.05/6 =",
  "0.0083 (marked with **). ** P < 0.0083 for interaction test, indicating statistically significant effect modification after Bonferroni correction. Only",
  "the BMI interaction (P = 0.008) reached this threshold. * P < 0.0042 for subgroup-specific association, surviving Bonferroni correction. Only the",
  "association in BMI <25 kg/m² participants (P = 0.004) met this criterion.",
  "",
  "Interpretation: These subgroup analyses are exploratory in nature. Although the BMI interaction test survived Bonferroni correction (P = 0.008 <",
  "0.0083), this finding should be interpreted cautiously given that: (1) the primary analysis showed no significant overall association (Q4 vs. Q1: OR",
  "= 1.14, 95% CI: 0.90–1.46, P = 0.260); (2) multiple testing increases the likelihood of chance findings; and (3) biological mechanisms linking SIRI",
  "preferentially to DED risk in normal-weight versus overweight individuals remain unclear. These results should primarily serve as hypothesis-",
  "generating observations requiring validation in independent prospective cohorts.",
  "",
  "Abbreviations: SIRI, Systemic Inflammation Response Index; OR, odds ratio; CI, confidence interval; BMI, body mass index; Q, quartile; DED, dry",
  "eye disease."
)

# 打开PDF设备（更大的页面以容纳图例）
pdf("最终版/Figure3_Subgroup_Forest_with_Legend_Final.pdf",
    width = 14, height = 16)  # 增加高度以容纳图例

# 创建布局：上部森林图，下部图例
pushViewport(viewport(layout = grid.layout(2, 1, heights = unit(c(12, 4), "inches"))))

# ═════ 第1部分：森林图 ═════
pushViewport(viewport(layout.pos.row = 1, layout.pos.col = 1))

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
  new_page = FALSE
)

popViewport()

# ═════ 第2部分：图例文本 ═════
pushViewport(viewport(layout.pos.row = 2, layout.pos.col = 1))

# 设置文本区域的边距
pushViewport(viewport(x = 0.05, y = 0.5, width = 0.9, height = 0.9, just = c("left", "center")))

# 添加图例文本（每行）
y_pos <- 1.0
line_spacing <- 0.04

for (i in seq_along(legend_lines)) {
  # 空行减少间距
  if (legend_lines[i] == "") {
    y_pos <- y_pos - line_spacing * 0.5
  } else {
    # 标题行加粗
    if (i == 1) {
      grid.text(
        legend_lines[i],
        x = 0, y = y_pos,
        just = c("left", "top"),
        gp = gpar(fontfamily = "Times", fontsize = 9, fontface = "bold")
      )
    } else {
      grid.text(
        legend_lines[i],
        x = 0, y = y_pos,
        just = c("left", "top"),
        gp = gpar(fontfamily = "Times", fontsize = 9)
      )
    }
    y_pos <- y_pos - line_spacing
  }
}

popViewport()
popViewport()
popViewport()

dev.off()

cat("✓ Figure 3 (带图例PDF) 已保存: 最终版/Figure3_Subgroup_Forest_with_Legend_Final.pdf\n\n")

# ══════════════════════════════════════════════════════════════════════════════
# 3. 生成带完整图例的PNG版本
# ══════════════════════════════════════════════════════════════════════════════

cat("【3/3】生成带完整图例的Figure 3 PNG...\n")

png("最终版/Figure3_Subgroup_Forest_with_Legend_Final.png",
    width = 14, height = 16, units = "in", res = 300)

# 创建相同的布局
pushViewport(viewport(layout = grid.layout(2, 1, heights = unit(c(12, 4), "inches"))))

# 森林图
pushViewport(viewport(layout.pos.row = 1, layout.pos.col = 1))

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
  new_page = FALSE
)

popViewport()

# 图例文本
pushViewport(viewport(layout.pos.row = 2, layout.pos.col = 1))
pushViewport(viewport(x = 0.05, y = 0.5, width = 0.9, height = 0.9, just = c("left", "center")))

y_pos <- 1.0
line_spacing <- 0.04

for (i in seq_along(legend_lines)) {
  if (legend_lines[i] == "") {
    y_pos <- y_pos - line_spacing * 0.5
  } else {
    if (i == 1) {
      grid.text(
        legend_lines[i],
        x = 0, y = y_pos,
        just = c("left", "top"),
        gp = gpar(fontfamily = "Times", fontsize = 9, fontface = "bold")
      )
    } else {
      grid.text(
        legend_lines[i],
        x = 0, y = y_pos,
        just = c("left", "top"),
        gp = gpar(fontfamily = "Times", fontsize = 9)
      )
    }
    y_pos <- y_pos - line_spacing
  }
}

popViewport()
popViewport()
popViewport()

dev.off()

cat("✓ Figure 3 (带图例PNG) 已保存: 最终版/Figure3_Subgroup_Forest_with_Legend_Final.png\n\n")

# ══════════════════════════════════════════════════════════════════════════════
# 完成总结
# ══════════════════════════════════════════════════════════════════════════════

cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                  带图例的Figure 3生成完成！                    ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("生成的文件:\n")
cat("  • PDF版本: 最终版/Figure3_Subgroup_Forest_with_Legend_Final.pdf (14×16英寸)\n")
cat("  • PNG版本: 最终版/Figure3_Subgroup_Forest_with_Legend_Final.png (300 DPI)\n\n")

cat("图例特点:\n")
cat("  • 字体: Times New Roman\n")
cat("  • 字号: 9号\n")
cat("  • 位置: 森林图下方\n")
cat("  • 内容: 完整的图例说明（包含所有脚注和解释）\n\n")

cat("✓ 全部完成！可直接用于期刊投稿。\n\n")
