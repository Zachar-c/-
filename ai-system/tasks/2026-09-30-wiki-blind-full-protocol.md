# 全库盲测协议（2026-09-30）

> 目的：测量 Wiki 能否替代原文阅读；**不是**估算全库覆盖率，也不批准结构迁移。
> 对照首轮：`%TEMP%\wenzhen-wiki-loss-20260930`（6 窗 12 题，严格分 1/24）。

## 隔离

| 角色 | 可读 | 禁止 |
|---|---|---|
| 出题官 | `source/蛊真人-epub-canon.txt` | wiki、game、旧题库 |
| 答题者 | `lore/wiki/**` 只读 | source、game、答案 |
| 评分官 | 题+答卷+答案钥匙+wiki+source | 改仓库 |

## 采样

10 窗 × 2 题 = 20 题，覆盖：青茅山 → 北原/王庭 → 真阳楼 → 三王 → 命运战争 → 东海 → 南疆 → 天庭 → 终局。

## 评分

每题 2 分点，每点 1 分，**不给半分**。

分类（每点独立标）：

| 代码 | 含义 |
|---|---|
| `ANSWERED` | 答题者完整满足 rubric |
| `MISSING` | Wiki 确无该知识（评分官回源/wiki 双查后仍无） |
| `RETRIEVAL_FAIL` | Wiki 有，答题者未找到/未用上 |
| `PARTIAL_SUMMARY` | 有结果缺条件/因果/边界 |
| `AMBIGUOUS` | 题干指代不清导致无法判 |
| `POST_HOC` | 事后补找不计分 |

**总分只报 `ANSWERED`。** 事后 Wiki 检索只用于分类，不补分。

## 产物

`%TEMP%\wenzhen-wiki-blind-full-20260930\`：
- samples.json / questions.json / answer-key.json
- wiki-answers.json / scored-results.json / report.md

## 边界

- 单次、单模型、有限检索；不能外推全库覆盖率。
- 不因结果批准/否定全库 IA；结构决策仍按 A/B 证据。
- 未找到 ≠ 不存在。
