# Day 15：样本筛选与权重计算操作详解

> **任务目标**：完成样本筛选流程记录（用于论文Figure 1）与NHANES复杂调查设计权重计算，生成可直接用于加权统计分析的最终分析数据集。
> 
> **预计用时**：3-4小时
> 
> **前置条件**：
> - 已完成Day 13数据导入与合并，生成`nhanes_siri_dryeye.rds`文件（20,497人）
> - 已完成Day 14变量计算与清洗，生成`nhanes_analysis_final.rds`文件（9,467人）
> 
> **技术要求**：R语言基础操作（dplyr包、survey包）
> 
> ⚠️ **重要提示**：本日需要加载**两个数据文件**：
> - **流程图生成**：使用Day 13原始数据（20,497人），记录完整筛选过程
> - **权重分析与建模**：使用Day 14已处理数据（9,467人），保留敏感性分析变量

---

## 目录

1. [整体流程概览](#一整体流程概览)
2. [样本筛选原理与逻辑](#二样本筛选原理与逻辑)
3. [样本筛选实现](#三样本筛选实现)
4. [NHANES权重系统详解](#四nhanes权重系统详解)
5. [权重计算与验证](#五权重计算与验证)
6. [复杂调查设计设置](#六复杂调查设计设置)
7. [最终分析数据集生成](#七最终分析数据集生成)
8. [常见问题与解决方案](#八常见问题与解决方案)
9. [质量检查清单](#九质量检查清单)

---

## 一、整体流程概览

### 1.1 Day 15 核心任务流程图

```
┌─────────────────────────────────────────────────────────────┐
│           【任务A：流程图生成 - 使用Day 13数据】              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Day 13 原始合并数据集 (20,497人)                            │
│          ↓                                                   │
│  ==================== 样本筛选记录 ====================      │
│          ↓                                                   │
│    纳入标准：年龄≥20岁                                       │
│          ↓                                                   │
│    排除标准1：MEC权重=0者                                    │
│          ↓                                                   │
│    排除标准2：妊娠女性                                       │
│          ↓                                                   │
│    排除标准3：SIRI数据缺失者                                 │
│          ↓                                                   │
│    排除标准4：干眼症变量缺失者                               │
│          ↓                                                   │
│    输出：flowchart_data.csv（用于论文Figure 1）              │
│                                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│        【任务B：权重分析 - 使用Day 14数据】                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Day 14 已处理数据集 (9,467人)                               │
│  （包含blood_disorder, siri_outlier, dry_eye_c1/c2等变量）   │
│          ↓                                                   │
│  ==================== 权重计算阶段 ====================      │
│          ↓                                                   │
│    验证2年权重（WTMEC2YR）                                   │
│          ↓                                                   │
│    验证4年合并权重（WTMEC4YR = WTMEC2YR / 2）                │
│          ↓                                                   │
│    权重分布检验                                              │
│          ↓                                                   │
│  ==================== 复杂调查设计设置 ====================  │
│          ↓                                                   │
│    设置PSU（主抽样单元）                                     │
│          ↓                                                   │
│    设置Strata（分层变量）                                    │
│          ↓                                                   │
│    设置权重变量                                              │
│          ↓                                                   │
│    创建survey design对象                                     │
│          ↓                                                   │
│  ==================== 数据质量验证 ====================      │
│          ↓                                                   │
│    权重有效性验证                                            │
│          ↓                                                   │
│    代表性检验                                                │
│          ↓                                                   │
│    保存最终分析数据集                                        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 本日核心任务清单

| 任务类别 | 具体任务 | 数据源 | 目的 |
|---------|---------|--------|------|
| **流程图生成** | 记录筛选过程 | Day 13 (20,497人) | 用于论文Figure 1 |
| **权重验证** | 检验权重分布 | Day 14 (9,467人) | 确保权重无异常 |
| **设计设置** | 创建survey design | Day 14 (9,467人) | 启用复杂调查分析 |
| **敏感性分析准备** | 创建子数据集 | Day 14 (9,467人) | 验证结果稳健性 |
| **数据保存** | 保存最终数据集 | Day 14 (9,467人) | 供后续分析使用 |

> ⚠️ **为什么使用两个数据源？**
> - **Day 13 数据**：包含完整的20,497人，用于展示筛选过程
> - **Day 14 数据**：包含敏感性分析变量（`blood_disorder`, `siri_outlier`, `dry_eye_c1`, `dry_eye_c2`），用于后续分析

---

## 二、样本筛选原理与逻辑

### 2.1 为什么需要样本筛选？

在NHANES研究中，样本筛选不是"随意丢弃数据"，而是**有科学依据的人群界定过程**。

| 筛选目的 | 具体说明 | 审稿人视角 |
|---------|---------|-----------|
| **定义目标人群** | 明确研究对象特征 | "你研究的是谁？" |
| **控制混杂因素** | 排除特殊人群 | "妊娠会影响炎症指标吗？" |
| **确保数据质量** | 排除关键缺失 | "缺失过多如何保证结论？" |
| **满足统计要求** | 确保权重有效 | "权重=0能代表总体吗？" |

### 2.2 纳入排除标准的科学依据

#### 2.2.1 纳入标准

| 标准 | 具体条件 | 科学依据 |
|-----|---------|---------|
| **年龄** | ≥20岁 | NHANES成人定义；青少年干眼症患病率低且机制不同 |
| **血常规检测** | CBC数据完整 | 计算SIRI暴露变量的必要条件 |
| **视力问卷** | VIQ031非缺失 | 定义干眼症结局的必要条件 |

#### 2.2.2 排除标准

| 标准 | 具体条件 | 科学依据 | NHANES变量 |
|-----|---------|---------|-----------|
| **权重为0** | WTMEC2YR = 0 | 未完成MEC检查，无法代表总体 | WTMEC2YR |
| **妊娠** | RIDEXPRG = 1 | 妊娠改变免疫状态和泪液分泌 | RIDEXPRG |
| **眼部手术史** | 既往眼科手术 | 手术直接影响干眼症，非炎症相关 | 问卷相关变量 |
| **血液系统疾病** | 极端血细胞值 | 扭曲SIRI计算 | 见Day 14标记 |

> 📌 **关键原则**：排除标准应在分析前**预先设定**，而非看到结果后调整。这是"科学研究"与"数据挖掘"的本质区别。

### 2.3 论文Methods部分标准表述

**英文版本**：

> **Study Population**
> 
> This cross-sectional study included adults aged 20 years or older from NHANES 2005-2008. Participants were excluded if they: (1) had zero MEC examination weights, indicating non-completion of the mobile examination center assessment; (2) were pregnant at the time of examination; (3) had missing data for complete blood count required for SIRI calculation; or (4) had missing data for dry eye symptom assessment (VIQ031). A total of XX participants were included in the final analysis.

**中文版本**：

> **研究人群**
> 
> 本横断面研究纳入NHANES 2005-2008年龄≥20岁的成年人。排除标准包括：(1) MEC检查权重为0者（未完成移动体检中心评估）；(2) 检查时处于妊娠状态的女性；(3) 血常规数据缺失无法计算SIRI者；(4) 干眼症症状评估（VIQ031）数据缺失者。最终纳入XX名参与者进行分析。

---

## 三、样本筛选实现

### 3.1 加载数据与环境准备

> ⚠️ **重要**：本日需要加载**两个数据文件**，分别用于不同任务！

```r
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
```

**输出结果**：

```
==================== 数据加载验证 ====================

【Day 13 原始数据】用于流程图生成
样本量: 20497 （应为 20,497）
变量数: 46

【Day 14 已处理数据】用于权重分析
样本量: 9467 （应为 9,467）
变量数: 58

【敏感性分析变量检查】
✓ blood_disorder 存在
✓ siri_outlier 存在
✓ dry_eye_c1 存在
✓ dry_eye_c2 存在

【Day 13 关键变量缺失情况】
年龄缺失: 0 
权重缺失: 0 
权重=0: 785 
SIRI缺失: 3870 
干眼症变量缺失: 6066
```

> 📌 **注意**：
> - 后续 **3.2 节（筛选流程记录）** 使用 `nhanes_raw`（Day 13 数据）
> - 后续 **第五节（权重计算）及之后** 使用 `nhanes_analysis`（Day 14 数据）

### 3.2 逐步筛选过程（带详细记录）- 使用 Day 13 数据

> 📌 **本节使用 `nhanes_raw`（Day 13 数据）记录筛选过程，仅用于生成流程图**
> 
> 后续分析将使用 `nhanes_analysis`（Day 14 数据），无需重复筛选

```r
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
```

**实际输出结果**：

```
==================== 筛选流程汇总表 ====================
  step                        description remaining excluded
1    0            NHANES 2005-2008 总样本     20497       NA
2    1                纳入年龄≥20岁成年人     10914     9583
3    2                    排除MEC权重=0者     10480      434
4    3                       排除妊娠女性     10098      382
5    4     要求SIRI数据完整（血常规完整）      9480      618
6    5 要求干眼症变量完整（VIQ031非缺失）      9474        6

==================== 筛选记录完成 ====================
流程图最终样本量: 9474 
总筛选比例: 46.2 %

==================== 数据一致性验证 ====================
流程图筛选后人数: 9474 
Day 14 数据人数: 9467 
✓ 样本量基本一致，差异在可接受范围内
（注：Day 14 可能额外排除了 dry_eye_a=NA 的样本，如 VIQ031=9 的情况）
```

> 📌 **注意**：
> - 初始数据检查显示权重=0有785人，但步骤2只排除434人，是因为其中351人已在步骤1（<20岁）被排除
> - 筛选是**逐步累积**的，每步排除人数基于前一步的剩余样本
> - 流程图人数（9,474）与 Day 14 数据人数（9,467）略有差异，是因为 Day 14 额外排除了 `dry_eye_symptom=9`（不知道）的样本
> - **实际分析使用 Day 14 数据（9,467人）**，流程图数据仅用于论文 Figure 1 展示

## 结论

| 项目                 | 说明                               |
| :------------------- | :--------------------------------- |
| 是否有问题           | ❌ 没有问题                         |
| 论文流程图用哪个数字 | 可以用 9,474（Day 13），或细分展示 |
| 实际分析用哪个数据   | Day 14 数据（9,467人），           |

### 3.3 筛选流程图数据（用于论文Figure 1）

```r
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
```

---

## 四、NHANES权重系统详解

### 4.1 为什么NHANES必须使用权重？

NHANES不是简单随机抽样（SRS），而是采用**复杂多阶段概率抽样设计**：

```
美国总人口
    ↓
第1阶段：选择PSU（县/县组）← 分层
    ↓
第2阶段：选择区段（segment）
    ↓
第3阶段：选择住户（dwelling units）
    ↓
第4阶段：选择个人 ← 过度抽样
```

| 设计特征 | 具体说明 | 对分析的影响 |
|---------|---------|-------------|
| **分层抽样** | 按地理区域和城乡分层 | 需要strata变量 |
| **聚类抽样** | 同一PSU内个体相关 | 需要cluster变量 |
| **过度抽样** | 老年人、少数族裔过度抽样 | 需要权重调整 |
| **非响应调整** | 校正未响应者 | 已包含在权重中 |
| **后分层调整** | 匹配人口普查数据 | 已包含在权重中 |

> 🚨 **不使用权重的后果**：
> - OR估计有偏
> - 标准误估计不正确
> - P值不可靠
> - **结论不能推广到美国总体**

### 4.2 NHANES权重变量类型

| 权重变量 | 全称 | 适用场景 | 使用条件 |
|---------|------|---------|---------|
| **WTINT2YR** | Interview Weight | 仅使用问卷数据 | 家庭访谈完成 |
| **WTMEC2YR** | MEC Exam Weight | 使用MEC检查数据 | MEC检查完成 |
| **WTMEC4YR** | 4-Year MEC Weight | 合并2个周期 | WTMEC2YR / 2 |
| **其他子样本权重** | 如WTSAF2YR | 特定检测子样本 | 按变量文档选择 |

### 4.3 权重选择决策树

```
你的分析是否使用了MEC检查数据？
（如血常规、血压测量等）
        │
    ┌───┴───┐
   是       否
    │        │
    ▼        ▼
使用WTMEC   使用WTINT
    │
    ▼
是否合并多个调查周期？
        │
    ┌───┴───┐
   是       否
    │        │
    ▼        ▼
权重除以    使用原始
周期数      2年权重
```

**本研究的选择**：
- ✅ 使用血常规数据（MEC检测）→ 需要WTMEC
- ✅ 合并2005-2006和2007-2008两个周期 → 权重除以2
- 📌 **最终使用：WTMEC4YR = WTMEC2YR / 2**

### 4.4 权重=0的含义与处理

#### 为什么会出现权重=0？

| 原因 | 具体情况 | 占比 |
|-----|---------|-----|
| **未完成MEC检查** | 只完成家庭访谈，未到MEC | 主要原因 |
| **不属于抽样框** | 如机构人口 | 少数 |
| **子样本未抽中** | 部分检测采用子样本设计 | 特定变量 |

#### 为什么必须排除权重=0？

这是**方法学硬性要求**：

| 问题 | 说明 |
|-----|------|
| ❌ 不能用于加权分析 | survey包会报错或产生错误结果 |
| ❌ 不能代表美国总体 | 这些人不在推断目标人群中 |
| ❌ 破坏复杂抽样设计 | 导致方差估计错误 |

#### 论文标准表述

> Participants with zero MEC examination weights were excluded because they did not complete the mobile examination center assessment or were not eligible for the laboratory subsample. According to NHANES analytic guidelines, individuals with zero weights cannot be incorporated into weighted analyses or generalized to the U.S. population.

---

## 五、权重计算与验证

> 📌 **从本节开始，使用 `nhanes_analysis`（Day 14 数据）进行分析**
> 
> Day 14 数据已完成筛选（9,467人），并包含敏感性分析所需的变量（`blood_disorder`, `siri_outlier`, `dry_eye_c1`, `dry_eye_c2`）

### 5.1 4年权重计算验证 - 使用 Day 14 数据

```r
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
```

=================== 数据一致性验证 ====================
> cat("流程图筛选后人数:", n_final_flowchart, "\n")
> 流程图筛选后人数: 9474 
> cat("Day 14 数据人数:", nrow(nhanes_analysis), "\n")
> Day 14 数据人数: 9467 
>
> if (abs(n_final_flowchart - nrow(nhanes_analysis)) <= 10) {
> +     cat("✓ 样本量基本一致，差异在可接受范围内\n")
+ } else {
+     cat("⚠️ 样本量差异较大，请检查筛选条件是否一致\n")
+     cat("（注：Day 14 可能额外排除了 dry_eye_a=NA 的样本）\n")
+ }
✓ 样本量基本一致，差异在可接受范围内
> # ⚠️ 使用 nhanes_analysis（Day 14 数据，9,467人）
>
> cat("==================== 权重计算验证（Day 14 数据）====================\n")
> ==================== 权重计算验证（Day 14 数据）====================
> cat("当前使用数据:", nrow(nhanes_analysis), "人\n")
> 当前使用数据: 9467 人
>
> # 检查原始2年权重
> cat("\n【原始2年权重（WTMEC2YR）分布】\n")

【原始2年权重（WTMEC2YR）分布】
> summary(nhanes_analysis$weight_2yr)
> Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
> 1430   19745   29083   41845   63441  192771 
>
> # 检查4年权重（已在Day 13计算）
> cat("\n【4年权重（WTMEC4YR）分布】\n")

【4年权重（WTMEC4YR）分布】
> summary(nhanes_analysis$weight_4yr)
> Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
> 715.1  9872.7 14541.4 20922.4 31720.4 96385.4 
>
> # 验证计算正确性
> # 4年权重应该 = 2年权重 / 2
> weight_check <- all.equal(
> +     nhanes_analysis$weight_4yr, 
> +     nhanes_analysis$weight_2yr / 2,
> +     tolerance = 1e-10
+ )
>
> cat("\n【权重计算验证】\n")

【权重计算验证】
> if (isTRUE(weight_check)) {
> +     cat("✓ 权重计算正确：WTMEC4YR = WTMEC2YR / 2\n")
+ } else {
+     cat("⚠️ 权重计算需要检查\n")
+     # 如果需要重新计算
+     nhanes_analysis$weight_4yr <- nhanes_analysis$weight_2yr / 2
+     cat("已重新计算4年权重\n")
+ }
✓ 权重计算正确：WTMEC4YR = WTMEC2YR / 2
>
> # 计算权重总和（应近似等于美国成年人口数）
> total_weight <- sum(nhanes_analysis$weight_4yr, na.rm = TRUE)
> cat("\n【权重总和】\n")

【权重总和】
> cat("权重总和:", format(total_weight, big.mark = ","), "\n")
> 权重总和: 198,072,765 
> cat("（应近似代表美国成年人口）\n")
> （应近似代表美国成年人口）
>
> # 验证敏感性分析变量存在
> cat("\n【敏感性分析变量确认】\n")

【敏感性分析变量确认】
> cat("blood_disorder 标记人数:", sum(nhanes_analysis$blood_disorder == 1, na.rm = TRUE), "\n")
> blood_disorder 标记人数: 21 
> cat("siri_outlier 标记人数:", sum(nhanes_analysis$siri_outlier == 1, na.rm = TRUE), "\n")
> siri_outlier 标记人数: 105 

### 5.2 权重分布检验

```r
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
```

![截屏2026-01-27 22.28.47](assets/截屏2026-01-27 22.28.47.png)

### 5.3 权重分布可视化

```r
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
```

---

## 六、复杂调查设计设置

### 6.1 survey包核心概念

NHANES复杂调查设计包含三个核心要素：

| 要素 | 变量名 | 作用 | 对分析的影响 |
|-----|-------|------|-------------|
| **Strata（分层）** | SDMVSTRA | 标识抽样分层 | 提高估计精度 |
| **PSU（聚类）** | SDMVPSU | 标识主抽样单元 | 校正聚类效应 |
| **Weight（权重）** | WTMEC4YR | 调整抽样概率 | 确保代表性 |

### 6.2 创建survey design对象

```r
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
```

==================== Survey Design 创建成功 ====================
> print(nhanes_design)
> Stratified 1 - level Cluster Sampling design (with replacement)
> With (62) clusters.
> svydesign(id = ~psu, strata = ~strata, weights = ~weight_4yr, 
> data = nhanes_analysis, nest = TRUE)

### 6.3 验证survey design

```r
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
```

### ![截屏2026-01-27 22.33.29](assets/截屏2026-01-27 22.33.29.png)6.4 保存survey design对象

```r
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
```

---

## 七、最终分析数据集生成

### 7.0 重新计算SIRI四分位组（重要！）

> ⚠️ **关键步骤**：由于Day 14计算SIRI四分位数切点时使用的样本量与最终分析样本不同，**必须在最终样本上重新计算四分位组**，否则各组人数会不均匀。

```r
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
```

**实际输出**：

```
==================== 重新计算SIRI四分位组 ====================
> 
> # 1. 检查当前分组是否均匀
> current_dist <- prop.table(table(nhanes_analysis$siri_quartile)) * 100
> cat("当前各组占比:\n")
当前各组占比:

  Q1   Q2   Q3   Q4 
15.8 25.6 29.7 28.9 
> 
> # 2. 在最终分析样本上重新计算四分位数切点
新的SIRI四分位数切点:
> cat("  Q1上限 (25%):", round(siri_quartiles_new[1], 4), "\n")
  Q1上限 (25%): 0.7081 
> cat("  Q2上限 (50%):", round(siri_quartiles_new[2], 4), "\n")
  Q2上限 (50%): 1.0309 
> cat("  Q3上限 (75%):", round(siri_quartiles_new[3], 4), "\n")
  Q3上限 (75%): 1.4792 
> 
> # 3. 重新创建分组变量
> 
> # 4. 验证修复结果
> cat("\n修复后SIRI分组分布:\n")

修复后SIRI分组分布:
> print(table(nhanes_analysis$siri_quartile))

  Q1   Q2   Q3   Q4 
2367 2367 2366 2367 
> cat("\n各组占比:\n")

各组占比:

Q1 Q2 Q3 Q4 
25 25 25 25 
> 
> # 5. 更新survey design对象
> nhanes_design <- svydesign(
+     id = ~psu,
+     strata = ~strata,
+     weights = ~weight_4yr,
+     data = nhanes_analysis,
+     nest = TRUE
+ )
> 
> cat("\n✓ SIRI四分位组已在最终样本上重新计算\n")

✓ SIRI四分位组已在最终样本上重新计算
```

### 7.1 创建敏感性分析子集

```r
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
```

### ![截屏2026-01-27 22.36.38](assets/截屏2026-01-27 22.36.38.png)7.2 保存最终分析数据集

```r
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
```

==================== 数据保存完成 ====================
> cat("主分析数据集: nhanes_analysis_weighted.rds/csv/dta\n")
> 主分析数据集: nhanes_analysis_weighted.rds/csv/dta
> cat("敏感性分析数据集: nhanes_sa_exp1/2/3.rds\n")
> 敏感性分析数据集: nhanes_sa_exp1/2/3.rds
> cat("筛选记录: screening_log.csv\n")
> 筛选记录: screening_log.csv
> cat("Survey design: nhanes_survey_design.rds\n")
> Survey design: nhanes_survey_design.rds

### 7.3 最终数据质量报告

```r
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
```

---

## 表 1. 样本筛选与权重计算结果汇总

### A. 样本筛选结果

| 指标           | 数值   |
| -------------- | ------ |
| 初始样本量     | 20,497 |
| 最终分析样本量 | 9,474  |
| 样本保留比例   | 46.2%  |

------

### B. 权重计算结果（NHANES 4-year）

| 指标         | 说明 / 数值              |
| ------------ | ------------------------ |
| 权重类型     | WTMEC4YR（4年 MEC 权重） |
| 计算方法     | WTMEC2YR ÷ 2             |
| 权重中位数   | 14,541                   |
| 加权人口估计 | 198,072,765              |

------

### C. Survey 设计完整性检查

| 项目               | 状态              |
| ------------------ | ----------------- |
| Survey design 对象 | ✓ 已创建          |
| PSU 变量           | ✓ 完整            |
| Strata 变量        | ✓ 完整            |
| 权重变量           | ✓ 完整（无 0 值） |

------

### D. 敏感性分析样本量

| 数据集  | 样本量 | 排除条件         |
| ------- | ------ | ---------------- |
| 主分析  | 9,474  | 无               |
| SA-Exp1 | 9,446  | 排除血液系统疾病 |
| SA-Exp2 | 9,362  | 排除 SIRI 极端值 |
| SA-Exp3 | 9,347  | 同时排除上述两者 |

------

📌 **一句话总结（可直接写进方法部分）**

> After sample selection, a total of 9,474 participants were included in the main analysis. Appropriate 4-year MEC weights were constructed, and all survey design variables (PSU, strata, and weights) were complete and valid. Sensitivity analyses were conducted using three alternative exclusion criteria.

## 八、常见问题与解决方案

### 审稿人常见问题预案

| 审稿人问题 | 回答要点 |
|-----------|---------|
| "为什么排除权重为0的样本？" | NHANES官方指南要求；无法代表目标人群 |
| "缺失率较高如何处理？" | 完整案例分析 + 多重插补敏感性分析 |
| "为什么使用4年权重而非2年？" | 合并两个周期需要调整权重避免重复计算 |
| "样本是否代表美国人群？" | 使用复杂调查权重，验证人口学分布 |

---

## 九、质量检查清单

### Day 15 完成检查表

| 类别 | 检查项 | 状态 |
|------|-------|------|
| **样本筛选** | | |
| | 年龄≥20岁筛选完成 | ☐ |
| | 权重=0排除完成 | ☐ |
| | 妊娠女性排除完成 | ☐ |
| | SIRI缺失排除完成 | ☐ |
| | 干眼症缺失排除完成 | ☐ |
| | 每步筛选人数记录 | ☐ |
| | 流程图数据生成 | ☐ |
| **权重计算** | | |
| | 4年权重计算正确（WTMEC2YR/2） | ☐ |
| | 权重分布检验完成 | ☐ |
| | 无权重=0残留 | ☐ |
| | 无权重缺失 | ☐ |
| **SIRI四分位组** | | |
| | **在最终样本上重新计算四分位数切点** | ☐ |
| | **各组人数均匀（各约25%）** | ☐ |
| | 切点值已记录 | ☐ |
| **Survey Design** | | |
| | PSU变量完整 | ☐ |
| | Strata变量完整 | ☐ |
| | design对象创建成功 | ☐ |
| | 设计验证通过 | ☐ |
| **敏感性分析准备** | | |
| | SA-Exp1数据集创建 | ☐ |
| | SA-Exp2数据集创建 | ☐ |
| | SA-Exp3数据集创建 | ☐ |
| **数据保存** | | |
| | 主分析数据集保存（.rds/.csv/.dta） | ☐ |
| | Survey design对象保存 | ☐ |
| | 敏感性分析数据集保存 | ☐ |
| | 筛选记录保存 | ☐ |



---

> **文档版本**：v1.1
> 
> **创建日期**：2026年1月27日
> 
> **最后更新**：2026年1月27日
> 
> **更新说明（v1.1）**：
> - 修正数据源使用逻辑：流程图生成使用 Day 13 数据，权重分析使用 Day 14 数据
> - 更新任务清单，明确两个数据源的用途
> - 更新附录完整代码，区分两个任务的数据源
> - 添加数据一致性验证步骤
> 
> **作者**：[根据执行计划方案编写]
> 
> **备注**：本文档为Day 15详细操作指南，是数据准备阶段的最后一步。完成本日任务后，数据已完全准备就绪，可直接进入Day 16-17的描述性分析阶段。
