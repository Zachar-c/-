---
title: 知识库维护计划
description: 本知识库的建设进度与后续维护任务的追踪页（llmwiki plan.md 规范）
date: 2026-09-25
tags: [plan, maintenance, tracker]
---

本页按 LLM Wiki 规范追踪知识库建设与维护工作。状态字形：`- [ ]` 待办 · `- [~]` 进行中 · `- [x]` 完成 · `- [!]` 受阻（注明原因）。

## 阶段一：初次编译（2026-09-12）

- [x] 扫描全部散落文档（docs/ 130+、根级 9、memory/ 2）并识别主题
- [x] 下载 lucasastorian/llmwiki 并提取其规范（GUIDE_TEXT：结构/引用/lint/routine）
- [x] 编写 overview.md（HUB）与 9 个 concepts 页、6 个 entities 页、timeline.md
- [x] 全部页面带 frontmatter + 脚注引用源文档 + 交叉链接
- [x] 编写 maintenance.md（更新机制 + lint 清单 + routine 提示词）
- [x] lint 自查（frontmatter 完整性、链接无悬空、引用可解析）
  - What: 2026-09-25 以 lint.mjs 全量核 19 页：frontmatter、页面链接、孤儿页全过；唯一实质缺口为 5 处 MEMORY.md 脚注——kill-move [^3] 重锚到 sword-cosmology spec，其余 4 处标 [失源] 并登记已知缺口
  - Why: 交叉链接数量多，人工核对易漏；lint.mjs 可随维护例程复跑

## 阶段二：接入审阅（等待外部架构审阅者）

- [ ] 审阅计划产出后，将"下一阶段建议"编入 concepts 页（新裁定新页面）
- [ ] 审阅结论中"应停止/重构/推翻"项同步到 timeline.md 关键裁定节

## 阶段三：持续维护（例行）

- [ ] 每次合入 master 的功能批次后，按 maintenance.md routine 更新受影响页面
- [ ] 补齐 [PROTOTYPE] 系统升级后的页面（遗物/DDA/盲合/养蛊）
- [ ] regen_pct 双表冲突裁定后更新 [资源模型](concepts/resource-model.md)

## 已知缺口（诚实登记）

- [!] MEMORY.md（项目工作记忆）从未入库且已无副本——4 处脚注失源
  - What: 2026-09-25 lint 确认 git 全历史与工作树均无该文件（.workbuddy/memory/MEMORY.md 为同名异实的 monorepo 约定文档，非本源）；涉及 agent-ownership [^2]、data-tables [^4]、verification-toolchain [^3]、timeline [^2]，主张保留并标 [失源]，后续优先重锚到 AGENTS.md 工具规则与 specs
  - Why: 引用必须指向真实存在的文件（lint 规则）；失源主张需显式降级而非静默保留
- [!] reports/ 目录在仓库中不存在——工作记忆提到的 Q7 复盘等归档文件未找到，相关页面未引用它们
  - What: 以 AGENTS.md、MEMORY.md、审计报告为替代来源
  - Why: 引用必须指向真实存在的文件（lint 规则）
- [ ] 16 份 HTML 线框稿未编译进知识库（视觉资产，属 Visual Agent 域）
