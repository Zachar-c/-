# 《問眞》文档待治理清单（2026-08-28 摸底）

- 日期：2026-08-28
- 来源：扫描 `docs/`、`AGENTS.md`、`README.md` 后的现状记录。
- 目的：把"文档体系标准与维护规范"识别出的漂移/破损/不一致落到具体行项，**不执行原地修复**——每个变更都需独立用户裁决。
- 配套规范：`docs/superpowers/specs/2026-08-28-doc-system-standard-design.md`（§6 与本文档互为索引）。
- 状态字段：`PENDING` 待裁决、`WONTFIX` 用户已拒绝、`DEFER` 留待后续批。

## 1. 链接失效 / 路径漂移

### 1.1 引用 `docs/GDD.md` 失效 [PENDING]

- 引用方（路径相对仓库根）：
  - `docs/项目决策浓缩对话.md` —— 顶部引用 `GDD.md`（仓库内不存在）
  - `docs/superpowers/plans/2026-08-21-nanjiang-roguelite-smoke-implementation.md` —— 顶部引用 `../../GDD.md`
  - `docs/superpowers/specs/2026-08-21-nanjiang-roguelite-smoke-design.md` —— 顶部引用 `../../GDD.md`
- 现状：仓库不存在 `docs/GDD.md`。
- 候选治理路径：
  - **A**：把链接改为机制先行规格书 `docs/superpowers/specs/2026-08-25-mechanics-first-lockdown-design.md`。
  - **B**：新增一份 `docs/GDD.md` 作为门面文档，摘要各 spec。
  - **C**：删除链接，仅在引用方注明"以当前生效 spec 为准"。
- 风险：A 影响历史交接语义（项目决策浓缩对话的"逐字聊记录"定位可能弱化）；B 工作量大；C 简单但需要同步 README 导航。
- 建议：方案 C（最小变更），同步在 README.md 顶部加入 §"权威基线 = 机制先行规格书"。

### 1.2 `docs/knowledge-base/` 空目录 [PENDING]

- 现状：`docs/knowledge-base/` 创建于 2026-08-25，至今无任何文件。
- 候选治理路径：
  - **A**：删除空目录（连同父 `.gitkeep`）。
  - **B**：保留作为未来跨项目知识入口，本批不引入内容。
  - **C**：降级为 `docs/lore/README.md` 风格的索引文件，转写 lore 导航。
- 建议：方案 B（与 §1.3 lore 职责区分）；新增 `docs/knowledge-base/README.md` 注明"预留位/不在本批范围"。

### 1.3 `docs/superpowers/specs/2026-08-26-ui-sts-redesign-design.md` 链路漂移 [DEFER]

- 现状：已被 `2026-08-27-minimal-ui-redesign-design.md` 与 `2026-08-28-p0-1-wenzhen-theme-migration-design.md` 部分取代，但未显式标记状态=已归档。
- 建议：在该文档首屏"状态"字段改为"已归档（被 2026-08-27 极简 UI 重设计 + 2026-08-28 问眞主题迁移取代）"。

### 1.4 `addons/reactive_ui_toolkit/CHANGELOG.md` 引用缺失 [WONTFIX]

- 引用：`MIGRATION-0.9.md`、`MIGRATION-0.10.md`（同文件两处）。
- 现状：该 addon 由上游维护；本规范不约束第三方域。
- 处理：跳过；如需，可向 RUITK 维护者反馈。

## 2. 作品名口径漂移

### 2.1 `docs/项目决策浓缩对话.md` 全篇仍用《蛊路求生》[PENDING]

- 现状：H1、§"这是谁的游戏"、Q&A 全部使用《蛊路求生》；未提《問眞》。
- 建议：在 H1 后追加一行"现行品牌《問眞》（前称《蛊路求生》/旧名 Nanjiang Smoke）"，正文不动。
- 风险：低；属于"门面勘误"。

### 2.2 多份 UI spec 并存两种写法 [PENDING]

- `2026-08-26-ui-sts-redesign-design.md` H1：《蛊路求生》UI 视觉设计规格。
- `2026-08-27-minimal-ui-redesign-design.md` H1：《問眞》极简 UI 重设计规格。
- `2026-08-28-p0-1-wenzhen-theme-migration-design.md` H1：P0-1 问眞主题迁移收尾设计。
- 建议：把 §2.1 中第 26 份改为"《問眞》UI 视觉设计规格（v3，已被 27/28 批取代）"；在首屏元数据加"替代关系"段。

### 2.3 文件名残留 `nanjiang` / `nanjiang-roguelite` [WONTFIX]

- 现状：`2026-08-21/22/...` 多份文件名以 `nanjiang-roguelite*` 命名。
- 建议：保留；新文件不再沿用此命名（规范 §2.1）。

## 3. 元数据缺失

> 下列文件首屏缺"日期/状态/范围/替代关系"元数据，且文档体量较大，建议按规范 §4 补齐：

| 文件 | 建议状态 |
| --- | --- |
| `docs/visual-reference-index.md` | 生效基线（视觉裁决） |
| `docs/项目决策浓缩对话.md` | 已归档（待新摘要替代） |
| `docs/superpowers/specs/2026-08-21-nanjiang-roguelite-smoke-design.md` | 已归档 |
| `docs/superpowers/specs/2026-08-22-chinese-only-interface-design.md` | 已归档 |
| `docs/superpowers/specs/2026-08-22-combat-loop-refactor-design.md` | 已归档 |
| `docs/superpowers/specs/2026-08-22-nanjiang-roguelite-v2-design.md` | 已归档 |
| `docs/superpowers/specs/2026-08-23-gu-card-roguelike-design.md` | 已归档 |
| `docs/superpowers/specs/2026-08-25-relic-hook-system-design.md` | 已归档 |
| `docs/superpowers/plans/2026-08-21-nanjiang-roguelite-smoke-implementation.md` | 已归档 |
| `docs/superpowers/plans/2026-08-22-chinese-only-interface-implementation.md` | 已归档 |
| `docs/superpowers/plans/2026-08-22-nanjiang-v2-first-vertical-slice.md` | 已归档 |
| `docs/superpowers/plans/2026-08-23-gu-card-roguelike-implementation.md` | 已归档 |
| `docs/superpowers/plans/2026-08-25-five-school-expansion-plan.md` | 已归档 |
| `docs/superpowers/plans/2026-08-25-p0-lockdown-batch-plan.md` | 已归档 |
| `docs/superpowers/plans/2026-08-25-ui-rui-overhaul-plan.md` | 已归档 |
| `docs/superpowers/plans/2026-08-27-minimal-ui-redesign-implementation.md` | 已批准（实施完毕转归档） |
| `docs/superpowers/plans/2026-08-27-novel-to-game-phase-0-1-implementation.md` | 已批准 |
| `docs/superpowers/plans/2026-08-28-wenzhen-ui-visual-acceptance-repair.md` | 进行中 |
| `docs/superpowers/sdd-archive/progress.md` | 进行中 |
| `docs/superpowers/sdd-archive/task-2-brief.md` ~ `task-5-brief.md` | 已归档 |

[PENDING] —— 是否一次性补齐，由用户裁决；若补，建议作为单独"元数据补齐批"。

## 4. 章节结构漂移

### 4.1 spec/plans 的"基线 commit" 表达不一致 [PENDING]

- 现状：部分 spec 用 `master @f8c2d60`、部分用 `master @`f71670e``、部分写"工作树 @`029...`"。
- 建议：统一为"`branch=<name>` @`<7位 SHA>`"格式（见规范 §5）。

### 4.2 plan 顶部的"For agentic workers"提示 [WONTFIX]

- 现状：`subagent-driven-development`/`executing-plans` 推荐语固化在 plan 顶部。
- 建议：保留；属于计划文档的可执行性提示，不属元数据。

## 5. 归档与目录边界

### 5.1 `.superpowers/sdd/` 与 `docs/superpowers/sdd-archive/` 边界 [PENDING]

- 现状：两目录并存；`.superpowers/sdd/progress.md` 与 `docs/superpowers/sdd-archive/progress.md` 角色未明示。
- 建议：规范 §1.3 已写明；归档时机见规范 §8。需要控制台定期执行搬运。

### 5.2 旧"豆腐包 / 旧稿"目录已删除但无 README [WONTFIX]

- 现状：`豆包/`、`旧稿归档_不采用/`、`重写稿/` 在 2026-08-25 收敛裁定后从工作区与 git 历史移除。
- 建议：无需操作；如未来再出现，按 `AGENTS.md` 工作边界治理。

## 6. 关联阅读

- 规范：`docs/superpowers/specs/2026-08-28-doc-system-standard-design.md`
- 用户基线：`AGENTS.md`
- 机制基线：`docs/superpowers/specs/2026-08-25-mechanics-first-lockdown-design.md`
- 现行作品名首屏：待 `README.md` 顶部"作品名口径"行更新（链接 2.1）。
