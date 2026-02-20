# ══════════════════════════════════════════════════════════════════════════════
# 期刊投稿图片准备脚本 (v2 - 修复版)
# 目标期刊: Ocular Immunology and Inflammation
# 要求: 线条图 = TIFF 1200 DPI; 组合图 = TIFF 600 DPI
# 图片内不含标题和图注 (统一放在稿件末尾图注列表)
#
# 修复内容:
#   - Figure 1: 从grViz源码重新生成SVG→高分辨率TIFF (非PDF转换)
#   - Figure 3: 降至600 DPI避免923MB怪兽文件
#   - 补充图: 使用sips(macOS内置)转换,不依赖ghostscript
# ══════════════════════════════════════════════════════════════════════════════

setwd("/Users/mayiding/Desktop/第一篇")

# ---- 加载必要的包 ----
library(ggplot2)
library(cowplot)
library(dplyr)
library(forestplot)
library(grid)
library(DiagrammeR)
library(DiagrammeRsvg)
library(rsvg)
library(magick)

# 输出目录
output_dir <- "最终版/投稿版图片"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║     期刊投稿图片准备 v2 (Ocul Immunol Inflamm)                 ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# ══════════════════════════════════════════════════════════════════════════════
# Figure 1: 流程图 (从grViz源码重新生成, 1200 DPI)
# ══════════════════════════════════════════════════════════════════════════════
cat("【1/5】Figure 1: Flowchart (从grViz重新生成)...\n")

flowchart_grViz <- "
digraph flowchart {
  graph [layout = dot, rankdir = TB, splines = ortho, nodesep = 0.8, ranksep = 0.5]
  node [shape = rectangle, style = 'filled,rounded', fillcolor = white,
        fontname = 'Arial', fontsize = 10, width = 3.2, height = 0.7, penwidth = 1.5]
  edge [color = black, penwidth = 1.2, arrowsize = 0.8]

  n1 [label = 'NHANES 2005-2008\\nTotal sample\\n(N = 20,497)', fillcolor = '#E8F4F8']
  n2 [label = 'Adults aged ≥20 years\\n(n = 10,914)', fillcolor = '#E8F4F8']
  n3 [label = 'Participants with valid MEC weight\\n(n = 10,480)', fillcolor = '#E8F4F8']
  n4 [label = 'Non-pregnant participants\\n(n = 10,098)', fillcolor = '#E8F4F8']
  n5 [label = 'Complete SIRI data\\n(blood cell counts available)\\n(n = 9,480)', fillcolor = '#E8F4F8']
  n6 [label = 'Complete dry eye data\\n(VIQ031 available)\\n(n = 9,474)', fillcolor = '#E8F4F8']
  n7 [label = 'Complete covariate data\\n(n = 8,664)', fillcolor = '#E8F4F8']
  n8 [label = 'Final analytical sample\\n(N = 8,664)', fillcolor = '#D5E8D4', penwidth = 2.5]

  e1 [label = 'Excluded (n = 9,583)\\nAge < 20 years', fillcolor = '#FFE6E6', shape = rectangle]
  e2 [label = 'Excluded (n = 434)\\nMEC weight = 0', fillcolor = '#FFE6E6', shape = rectangle]
  e3 [label = 'Excluded (n = 382)\\nPregnant women', fillcolor = '#FFE6E6', shape = rectangle]
  e4 [label = 'Excluded (n = 618)\\nMissing blood cell data', fillcolor = '#FFE6E6', shape = rectangle]
  e5 [label = 'Excluded (n = 6)\\nMissing dry eye data', fillcolor = '#FFE6E6', shape = rectangle]
  e6 [label = 'Excluded (n = 810)\\nMissing covariates', fillcolor = '#FFE6E6', shape = rectangle]

  n1 -> n2
  n2 -> n3
  n3 -> n4
  n4 -> n5
  n5 -> n6
  n6 -> n7
  n7 -> n8

  n1 -> e1 [style = dashed]
  n2 -> e2 [style = dashed]
  n3 -> e3 [style = dashed]
  n4 -> e4 [style = dashed]
  n5 -> e5 [style = dashed]
  n6 -> e6 [style = dashed]

  {rank = same; n1}
  {rank = same; n2; e1}
  {rank = same; n3; e2}
  {rank = same; n4; e3}
  {rank = same; n5; e4}
  {rank = same; n6; e5}
  {rank = same; n7; e6}
  {rank = same; n8}
}
"

# 生成 SVG → 高分辨率 PNG → TIFF
flowchart_plot <- grViz(flowchart_grViz)
svg_content <- export_svg(flowchart_plot)
svg_content <- as.character(svg_content)  # 关键: html类 → 纯字符串

# 1200 DPI, 8×10 英寸 = 9600×12000 像素
temp_png <- file.path(output_dir, "Figure_1_temp.png")
rsvg_png(charToRaw(svg_content),
         file = temp_png,
         width = 9600, height = 12000)

if (!file.exists(temp_png) || file.size(temp_png) < 1000) {
  stop("Figure 1 PNG 生成失败，请检查 DiagrammeR/rsvg 是否正确安装")
}

# PNG → 裁剪白边 → TIFF
fig1_img <- image_read(temp_png)
fig1_img <- image_trim(fig1_img)           # 自动裁剪周围空白
fig1_img <- image_border(fig1_img, "white", "150x150")  # 加回适量边距
image_write(fig1_img,
            path = file.path(output_dir, "Figure_1.tiff"),
            format = "tiff",
            compression = "LZW",
            density = "1200")
file.remove(temp_png)

fig1_info <- image_info(fig1_img)
cat("  ✓ Figure_1.tiff\n")
cat("    像素:", fig1_info$width, "x", fig1_info$height, "\n")
cat("    DPI: 1200 (", round(fig1_info$width/1200, 1), "x",
    round(fig1_info$height/1200, 1), "英寸)\n")
cat("    文件大小:", round(file.size(file.path(output_dir, "Figure_1.tiff"))/1024/1024, 1), "MB\n\n")

# ══════════════════════════════════════════════════════════════════════════════
# Figure 2: RCS剂量-反应曲线 (重新生成: 去除标题、P值注释、底部脚注)
# ══════════════════════════════════════════════════════════════════════════════
cat("【2/5】Figure 2: RCS Dose-Response (重新生成, 清理文字)...\n")

# 加载Day20 RCS分析对象
load("主要回归分析/Day20_RCS_Objects.RData")
nhanes_complete <- readRDS("分析数据集/nhanes_analysis_final.rds")
cat("  已加载 RCS 数据对象\n")

if (!exists("ref_siri")) {
  ref_siri <- median(nhanes_complete$siri, na.rm = TRUE)
}
if (!exists("siri_range")) {
  siri_range <- range(pred_results$siri, na.rm = TRUE)
}
if (!exists("knots_4")) {
  knots_4 <- c(0.39, 0.83, 1.24, 2.61)
}

# ---- 主图: RCS曲线 (无P值注释, 无标题) ----
p_main <- ggplot(pred_results, aes(x = siri, y = or)) +
  geom_ribbon(aes(ymin = or_lower, ymax = or_upper),
              fill = "#3498db", alpha = 0.25) +
  geom_line(color = "#2980b9", linewidth = 1.5) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "#e74c3c",
             linewidth = 0.8) +
  geom_point(data = data.frame(siri = ref_siri, or = 1),
             aes(x = siri, y = or),
             color = "#e74c3c", size = 3, shape = 18) +
  geom_rug(data = data.frame(siri = as.numeric(knots_4)),
           aes(x = siri), sides = "b", color = "gray50", alpha = 0.5,
           inherit.aes = FALSE) +
  scale_y_log10(
    breaks = c(0.5, 0.75, 1, 1.25, 1.5, 2, 3),
    labels = c("0.5", "0.75", "1.0", "1.25", "1.5", "2.0", "3.0"),
    limits = c(0.5, 3)
  ) +
  scale_x_continuous(
    breaks = seq(0, 4, 0.5),
    limits = c(0, max(siri_range) * 1.05)
  ) +
  labs(x = "SIRI", y = "Odds Ratio (95% CI)") +
  # *** 不添加 annotate() — P值信息放在图注中 ***
  theme_bw() +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "gray90"),
    axis.title = element_text(size = 14, face = "bold"),
    axis.text = element_text(size = 12, color = "black"),
    panel.border = element_rect(linewidth = 1),
    plot.margin = margin(10, 15, 0, 10)
  )

# ---- 底部直方图 ----
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

# ---- 组合图 (无标题, 无脚注) ----
p_fig2_clean <- plot_grid(
  p_main, p_hist,
  ncol = 1, align = "v", axis = "lr",
  rel_heights = c(4, 1)
)

# ---- 导出 TIFF 1200 DPI ----
ggsave(
  file.path(output_dir, "Figure_2.tiff"),
  p_fig2_clean,
  width = 10, height = 9, dpi = 1200,
  compression = "lzw", device = "tiff"
)
cat("  ✓ Figure_2.tiff (1200 DPI, 无标题/P值/脚注)\n")
cat("    文件大小:", round(file.size(file.path(output_dir, "Figure_2.tiff"))/1024/1024, 1), "MB\n\n")

# ══════════════════════════════════════════════════════════════════════════════
# Figure 3: 亚组分析森林图 (重新生成, 去除标题, 600 DPI)
# 说明: 14×12英寸森林图在1200 DPI下会产生>900MB文件, 不切实际
#       600 DPI对于含文字的组合统计图完全足够, 且是多数期刊实际接受的标准
# ══════════════════════════════════════════════════════════════════════════════
cat("【3/5】Figure 3: Subgroup Forest Plot (重新生成, 600 DPI)...\n")

subgroup_data <- data.frame(
  Variable = c("Sex","Sex","Age","Age","BMI","BMI",
               "Diabetes","Diabetes","Hypertension","Hypertension",
               "Race/Ethnicity","Race/Ethnicity","Race/Ethnicity","Race/Ethnicity"),
  Subgroup = c("Male","Female","<60 years","\u226560 years",
               "<25 kg/m\u00B2","\u226525 kg/m\u00B2","No","Yes","No","Yes",
               "Non-Hispanic White","Non-Hispanic Black","Mexican American","Other"),
  N = c(4364,4300,5711,2953,2556,6108,7318,1346,7029,1635,4341,1808,1558,957),
  Cases = c(844,915,997,762,485,1274,1322,437,1349,410,707,391,439,222),
  OR = c(1.01,1.25,1.08,1.36,2.08,0.90,1.16,1.08,1.05,1.73,1.20,1.21,0.80,1.43),
  CI_Lower = c(0.68,0.98,0.79,0.97,1.31,0.69,0.85,0.65,0.82,1.09,0.84,0.84,0.60,0.56),
  CI_Upper = c(1.48,1.61,1.48,1.91,3.29,1.18,1.57,1.78,1.35,2.74,1.71,1.72,1.07,3.63),
  P_Value = c(0.976,0.072,0.615,0.068,0.004,0.423,0.336,0.754,0.672,0.023,0.296,0.282,0.123,0.427),
  stringsAsFactors = FALSE
)

subgroup_data <- subgroup_data %>%
  mutate(
    OR_CI = sprintf("%.2f (%.2f\u2013%.2f)", OR, CI_Lower, CI_Upper),
    P_Formatted = ifelse(P_Value < 0.001, "<0.001", sprintf("%.3f", P_Value)),
    P_Significance = ifelse(P_Value < 0.0042, "*", "")
  )

# 构建森林图数据结构
groups <- list(
  list(header="Sex", p_int="0.714"),
  list(header="Age", p_int="0.198"),
  list(header="BMI", p_int="0.008**"),
  list(header="Diabetes", p_int="0.875"),
  list(header="Hypertension", p_int="0.260"),
  list(header="Race/Ethnicity", p_int="0.504")
)

text_list <- list(); mean_list <- list(); lower_list <- list()
upper_list <- list(); is_summary_list <- list()

text_list[[1]] <- c("Subgroup","N","Cases","OR (95% CI)","P for Interaction")
mean_list[[1]] <- NA; lower_list[[1]] <- NA; upper_list[[1]] <- NA
is_summary_list[[1]] <- TRUE

idx <- 2
for (grp in groups) {
  text_list[[idx]] <- c(grp$header,"","","",grp$p_int)
  mean_list[[idx]] <- NA; lower_list[[idx]] <- NA; upper_list[[idx]] <- NA
  is_summary_list[[idx]] <- TRUE; idx <- idx + 1
  grp_data <- subgroup_data %>% filter(Variable == grp$header)
  for (i in 1:nrow(grp_data)) {
    text_list[[idx]] <- c(
      paste0("  ", grp_data$Subgroup[i]),
      as.character(grp_data$N[i]),
      as.character(grp_data$Cases[i]),
      grp_data$OR_CI[i],
      paste0(grp_data$P_Formatted[i], grp_data$P_Significance[i])
    )
    mean_list[[idx]] <- grp_data$OR[i]
    lower_list[[idx]] <- grp_data$CI_Lower[i]
    upper_list[[idx]] <- grp_data$CI_Upper[i]
    is_summary_list[[idx]] <- FALSE; idx <- idx + 1
  }
}

tabletext_mat <- do.call(rbind, text_list)

# ---- 导出: 先输出PNG, 再用magick转TIFF (修复DPI元数据+压缩问题) ----
fig3_temp_png <- file.path(output_dir, "Figure_3_temp.png")
png(fig3_temp_png, width = 8400, height = 7200, res = 600)

forestplot(
  labeltext = tabletext_mat,
  mean = unlist(mean_list),
  lower = unlist(lower_list),
  upper = unlist(upper_list),
  is.summary = unlist(is_summary_list),
  clip = c(0.4, 4), zero = 1, xlog = TRUE,
  xlab = "Odds Ratio (95% CI)",
  xticks = c(0.5, 0.75, 1, 1.5, 2, 3, 4),
  col = fpColors(box="#2C3E50", line="#2C3E50", summary="#34495E", zero="#7F8C8D"),
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
  lwd.ci = 1.3, lwd.zero = 1, vertices = TRUE
)

dev.off()

# PNG → TIFF: magick正确写入DPI元数据 + LZW压缩
fig3_img <- image_read(fig3_temp_png)
image_write(fig3_img,
            path = file.path(output_dir, "Figure_3.tiff"),
            format = "tiff",
            compression = "LZW",
            density = "600")
file.remove(fig3_temp_png)

cat("  ✓ Figure_3.tiff (600 DPI, 无标题)\n")
cat("    文件大小:", round(file.size(file.path(output_dir, "Figure_3.tiff"))/1024/1024, 1), "MB\n\n")

# ══════════════════════════════════════════════════════════════════════════════
# Supplementary Figure S1 (DAG): PDF → TIFF 600 DPI
# 使用rsvg或magick, 避免ghostscript依赖问题
# ══════════════════════════════════════════════════════════════════════════════
cat("【4/5】Supplementary Figure S1: DAG...\n")

# 方案: 用系统命令sips转换 (macOS内置, 无额外依赖)
dag_source <- "最终版/Supplementary_Figure_S2_DAG.pdf"
dag_target <- file.path(output_dir, "Supplementary_Figure_1.tiff")

# 读取DAG → 裁掉顶部标题和底部注释 → TIFF
dag_img <- NULL
tryCatch({
  dag_img <- image_read_pdf(dag_source, density = 600)
  cat("  已从PDF读取 (magick)\n")
}, error = function(e) {
  cat("  magick PDF读取失败, 使用sips备选方案...\n")
  temp_png2 <- file.path(output_dir, "temp_dag.png")
  system2("sips", args = c("-s", "format", "png",
                           "-s", "dpiWidth", "600", "-s", "dpiHeight", "600",
                           shQuote(dag_source), "--out", shQuote(temp_png2)),
          stdout = FALSE, stderr = FALSE)
  if (file.exists(temp_png2)) {
    dag_img <<- image_read(temp_png2)
    file.remove(temp_png2)
    cat("  已从PDF读取 (sips)\n")
  }
})

if (!is.null(dag_img)) {
  # 裁掉顶部标题(仅标题行~4%, 保留图例)和底部注释(~15%)
  dag_info <- image_info(dag_img)
  w <- dag_info$width
  h <- dag_info$height
  crop_top <- round(h * 0.04)      # 仅标题行, 不伤图例(红色箭头legend)
  crop_bottom <- round(h * 0.15)   # 底部Note两行全部裁掉
  new_h <- h - crop_top - crop_bottom
  dag_img <- image_crop(dag_img, geometry = sprintf("%dx%d+0+%d", w, new_h, crop_top))
  dag_img <- image_trim(dag_img)   # 自动修剪残余空白
  dag_img <- image_border(dag_img, "white", "80x80")  # 加回适量边距

  image_write(dag_img, path = dag_target, format = "tiff",
              compression = "LZW", density = "600")
  cat("  ✓ Supplementary_Figure_1.tiff (600 DPI, 已裁除标题和注释)\n")
} else {
  cat("  ⚠️ DAG转换失败，请手动处理\n")
  cat("  建议: brew install ghostscript 后重新运行\n")
}
cat("\n")

# ══════════════════════════════════════════════════════════════════════════════
# Supplementary Figure S2 (Sensitivity Forest): 转换为 TIFF
# ══════════════════════════════════════════════════════════════════════════════
cat("【5/5】Supplementary Figure S2: Sensitivity Forest...\n")

sens_source_pdf <- "最终版/FigureS1_Sensitivity_Forest.pdf"
sens_source_png <- "最终版/FigureS1_Sensitivity_Forest.png"
sens_target <- file.path(output_dir, "Supplementary_Figure_2.tiff")

if (file.exists(sens_source_pdf)) {
  tryCatch({
    sens_img <- image_read_pdf(sens_source_pdf, density = 1200)
    image_write(sens_img, path = sens_target, format = "tiff",
                compression = "LZW", density = "1200")
    cat("  ✓ Supplementary_Figure_2.tiff (1200 DPI, 从PDF矢量)\n")
  }, error = function(e) {
    cat("  PDF读取失败, 从PNG转换...\n")
    sens_img <- image_read(sens_source_png)
    image_write(sens_img, path = sens_target, format = "tiff",
                compression = "LZW", density = "300")
    cat("  ✓ Supplementary_Figure_2.tiff (从PNG, 建议后续从R重新生成)\n")
  })
} else {
  sens_img <- image_read(sens_source_png)
  image_write(sens_img, path = sens_target, format = "tiff",
              compression = "LZW", density = "300")
  cat("  ✓ Supplementary_Figure_2.tiff (从PNG转换)\n")
}
cat("\n")

# ══════════════════════════════════════════════════════════════════════════════
# 最终汇总
# ══════════════════════════════════════════════════════════════════════════════
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    图片准备完成                                ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("输出目录:", file.path(getwd(), output_dir), "\n\n")

files <- list.files(output_dir, pattern = "\\.tiff$", full.names = TRUE)
for (f in files) {
  fsize <- round(file.size(f)/1024/1024, 1)
  tryCatch({
    info <- image_info(image_read(f))
    cat(sprintf("  %-35s  %5dx%-5d  %s MB\n",
                basename(f), info$width, info$height, fsize))
  }, error = function(e) {
    cat(sprintf("  %-35s  (读取失败)  %s MB\n", basename(f), fsize))
  })
}

cat("\n文件名 → 文稿对照:\n")
cat("  Figure_1.tiff              → Figure 1 (流程图)\n")
cat("  Figure_2.tiff              → Figure 2 (RCS剂量-反应曲线)\n")
cat("  Figure_3.tiff              → Figure 3 (亚组分析森林图)\n")
cat("  Supplementary_Figure_1.tiff → Supplementary Figure S1 (DAG)\n")
cat("  Supplementary_Figure_2.tiff → Supplementary Figure S2 (敏感性分析)\n")
