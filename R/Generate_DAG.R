# ══════════════════════════════════════════════════════════════════════════════
# 重新生成 Supplementary Figure S2 (DAG图) - 标题更新为S2
# ══════════════════════════════════════════════════════════════════════════════
# 更新日期：2026-02-04
# 原因：解决编号冲突，将DAG图从S1更新为S2
# ══════════════════════════════════════════════════════════════════════════════

setwd("/Users/mayiding/Desktop/第一篇")

cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║          重新生成 Supplementary Figure S2 (DAG图)             ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# 创建替代方案：使用base R绘制简化版DAG
pdf("最终版/Supplementary_Figure_S2_DAG.pdf", width = 12, height = 8)

# 创建空白画布
par(mar = c(1, 1, 2, 1))
plot(0, 0, type = "n", xlim = c(0, 10), ylim = c(0, 10),
     axes = FALSE, xlab = "", ylab = "",
     main = "Supplementary Figure S2. Conceptual Directed Acyclic Graph (DAG) for Covariate Selection")

# 定义节点位置
nodes <- data.frame(
  name = c("Age", "Sex", "Race", "Education", "PIR",
           "Smoking", "BMI", "Diabetes", "HTN", "SIRI", "DED"),
  x = c(1, 1, 1, 3, 3, 5, 5, 5, 5, 7, 9),
  y = c(9, 7, 5, 9, 7, 9, 7, 5, 3, 6, 6),
  color = c("#FFF9E6", "#FFF9E6", "#FFF9E6", "#F0F9E6", "#F0F9E6",
            "#F5E6FF", "#FFE6F0", "#FFE6F0", "#FFE6F0", "#E8F4F8", "#FFE8E8")
)

# 绘制节点
for (i in 1:nrow(nodes)) {
  rect(nodes$x[i] - 0.4, nodes$y[i] - 0.3,
       nodes$x[i] + 0.4, nodes$y[i] + 0.3,
       col = nodes$color[i], border = "black", lwd = 1.5)
  text(nodes$x[i], nodes$y[i], nodes$name[i],
       cex = 0.9, family = "Times")
}

# 绘制边（箭头）
# 人口学 → SIRI
arrows(1.4, 9, 6.6, 6.3, length = 0.1, lwd = 1)
arrows(1.4, 7, 6.6, 6, length = 0.1, lwd = 1)
arrows(1.4, 5, 6.6, 5.7, length = 0.1, lwd = 1)

# 人口学 → DED
arrows(1.4, 9, 8.6, 6.3, length = 0.1, lwd = 1, col = "gray60")
arrows(1.4, 7, 8.6, 6, length = 0.1, lwd = 1, col = "gray60")
arrows(1.4, 5, 8.6, 5.7, length = 0.1, lwd = 1, col = "gray60")

# 社会经济 → SIRI
arrows(3.4, 9, 6.6, 6.3, length = 0.1, lwd = 1)
arrows(3.4, 7, 6.6, 6, length = 0.1, lwd = 1)

# 社会经济 → DED
arrows(3.4, 9, 8.6, 6.3, length = 0.1, lwd = 1, col = "gray60")
arrows(3.4, 7, 8.6, 6, length = 0.1, lwd = 1, col = "gray60")

# 生活方式 → 代谢
arrows(5.4, 9, 5, 7.3, length = 0.1, lwd = 1)
arrows(5.4, 9, 5, 5.3, length = 0.1, lwd = 1)
arrows(5.4, 9, 5, 3.3, length = 0.1, lwd = 1)

# 代谢 → SIRI
arrows(5.4, 7, 6.6, 6.3, length = 0.1, lwd = 1)
arrows(5.4, 5, 6.6, 6, length = 0.1, lwd = 1)
arrows(5.4, 3, 6.6, 5.7, length = 0.1, lwd = 1)

# 代谢 → DED (虚线，表示不确定)
arrows(5.4, 7, 8.6, 6.3, length = 0.1, lwd = 1, col = "gray60", lty = 2)
arrows(5.4, 5, 8.6, 6, length = 0.1, lwd = 1, col = "gray60", lty = 2)
arrows(5.4, 3, 8.6, 5.7, length = 0.1, lwd = 1, col = "gray60", lty = 2)

# SIRI → DED (主要路径，加粗红色)
arrows(7.4, 6, 8.6, 6, length = 0.15, lwd = 3, col = "red")

# 添加图例
legend("topleft",
       legend = c("Main causal pathway (SIRI -> DED)",
                  "Confounder pathways",
                  "Potential mediator pathways (uncertain)"),
       col = c("red", "black", "gray60"),
       lty = c(1, 1, 2),
       lwd = c(3, 1, 1),
       cex = 0.8,
       bty = "n")

# 添加注释
text(5, 0.5,
     "Note: Solid arrows indicate established relationships; dashed arrows indicate uncertain relationships.\nMetabolic variables (BMI, Diabetes, Hypertension) may act as confounders or partial mediators.",
     cex = 0.7, family = "Times", adj = 0.5)

dev.off()

cat("\n✓ Supplementary Figure S2 (DAG) 已重新生成\n")
cat("  文件: 最终版/Supplementary_Figure_S2_DAG.pdf\n")
cat("  标题已更新: Supplementary Figure S2\n\n")

cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                     完成！                                     ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")
