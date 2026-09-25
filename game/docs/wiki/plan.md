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
- [x] 用 lore 原著蒸馏替换世界观/设计知识（2026-09-25）
  - What: overview / world-model-translation / gu-and-synthesis / resource-model / kill-move-system 改为「原著真源=lore/wiki + 游戏裁定分列」；combat-system、gameplay-loop 标明纯实现/纯游戏；agent-ownership 标历史（RUL-2026-09-17-003 作废）；删除 `2^(gu-cultivator)` 等旧转数倍率口径
  - Why: L0 要求以《蛊真人》原著蒸馏合理替换项目设计知识；L5/L6 分层，原著事实不得在 game 侧二次发明
- [x] 统一 game wiki lint 入口（2026-09-25）
  - What: 合并 `.workbuddy/wiki_lint.mjs` 与 `lint-acceptance.py` 为本目录唯一 `lint.mjs`（自定位；含 frontmatter/链接/孤儿/脚注源/可视化/mermaid）；两份临时脚本已删除。`node lint.mjs` 硬错误 0，WARN 2（kill-move-system、meta-progression 缺可视化）
  - Why: 维护文档约定 `node lint.mjs`（本目录），此前实现散落在 `.workbuddy/` 与一次性 Python 脚本，属重复实现

## 阶段二：接入审阅（等待外部架构审阅者）

- [ ] 审阅计划产出后，将"下一阶段建议"编入 concepts 页（新裁定新页面）
- [ ] 审阅结论中"应停止/重构/推翻"项同步到 timeline.md 关键裁定节

## 阶段三：持续维护（例行）

- [ ] 每次合入 master 的功能批次后，按 maintenance.md routine 更新受影响页面
- [ ] 补齐 [PROTOTYPE] 系统升级后的页面（遗物/DDA/盲合/养蛊）
- [ ] regen_pct 双表冲突裁定后更新 [资源模型](concepts/resource-model.md)

## 阶段四：原文对应位置验收与修正（2026-09-25）

- [x] 产出页 ↔ 原文/现网对应位置验收
  - What: 逐页核对 19 页脚注与主张。原著锚点 9 组（养蛊容量/炼化意志/合炼秘方/九转四小境/真元五档/资质分级/十绝体/元石抽真元/杀招组合与代价/推演底蕴灵感）全部追到 `蛊真人-clean.txt` 行号（3900-3926、1830-1834、15724-15734、4673-4675、87532、70356、1154-1158、1354-1360、22770-22778、1526-1530、105506、106762、98114、123492），内容一一对应；游戏侧主张追到 AGENTS.md / 09-01 规格 / audit 各节与现网 data/、scripts/
  - Why: 上午验收只查链接与结构；本次按用户要求把每条主张钉到原文/现网对应位置
- [x] 修正数据漂移（audit 2026-09-12 快照 vs 现网 data/）
  - What: 开局 HP 80→100（data/balance.json `player_start_hp`，RUL-2026-09-19-009）；配方 392→469（+promotion 76 类）；shops 33→38 offers；contracts 6→5（contract_cap 6）；events 2→24（D4 事件池）；v1_effect 48→62；enemies 30→32 条。pacing 敌权重 75/25/0 与现网一致，未改动
  - Why: AGENTS.md 规定工程事实以 data/ 与代码为真源；审计报告是快照，数字已过期
- [x] 修正引用位置（脚注指向过时/错误小节）
  - What: gameplay-loop [^4] E1-E7→audit §4（条目已从 AGENTS.md 当前待办移除）；combat-system [^2] §15→§15/§14/§20/§21（行动次数分档/反制/duplicate 写回分属 §20/§14/§21）；meta-progression [^2] 补 route 白名单代码现源（scripts/domain/content_catalog.gd、meta_progress.gd）；kill-move [^3] 补 §14 与 counter_revealed 代码字段；verification-toolchain 标注 §22 为 2026-09-12 快照、verify_interaction_loop 清理事实以 AGENTS.md 工具规则为准
  - Why: 引用必须指向真实承载该事实的位置（lint 规则精神）
- [x] lint 复跑：FAIL 0 / WARN 1（meta-progression 无可视化，既有登记）

## 已知缺口（诚实登记）

- [!] MEMORY.md（项目工作记忆）从未入库且已无副本——4 处脚注失源
  - What: 2026-09-25 lint 确认 git 全历史与工作树均无该文件（.workbuddy/memory/MEMORY.md 为同名异实的 monorepo 约定文档，非本源）；涉及 agent-ownership [^2]、data-tables [^4]、verification-toolchain [^3]、timeline [^2]，主张保留并标 [失源]，后续优先重锚到 AGENTS.md 工具规则与 specs
  - Why: 引用必须指向真实存在的文件（lint 规则）；失源主张需显式降级而非静默保留
- [!] reports/ 目录在仓库中不存在——工作记忆提到的 Q7 复盘等归档文件未找到，相关页面未引用它们
  - What: 以 AGENTS.md、MEMORY.md、审计报告为替代来源
  - Why: 引用必须指向真实存在的文件（lint 规则）
- [ ] 16 份 HTML 线框稿未编译进知识库（视觉资产，属 Visual Agent 域）
