# 网页端决定性实验 · 加深规则（2026-09-20 起）

> **L0 裁决**：交接文档 §八「三选一」选定 **方案 1 决定性实验**。本文件是实验的排期、计量口径与验收方式。
> 目的只有一个：**回答「规则变复杂后，Web 侧是否还保持改写速度」**——这是载体裁决（是否弃 Godot 全转 Web）的依据。

## 0 边界

- **只动 `game/wenzhen-web-lab/`**。Godot 线（`scripts/`、`scenes/`、`data/`、`world-model/`）**只读**，作为规格来源。
- **只搬已有的，不新设计**：每个子系统必须能在 Godot 侧找到对应实现与数据；找不到就停下上报，不许自创规则。
- 不做预抽象：不引入 Manager / EventBus / 状态管理 / 构建步骤（沿用交接 §九 纪律）。
- 数据仍只有一条来源 `tools/build_data.mjs`；手改 `js/data.js` 会被下次生成覆盖。
- 保持「双击即开」：不引入 ES module、不加新依赖、assets 走相对路径。

## 1 计量口径（本实验的核心产出）

每个步骤记录三项，**不记录「测试是否全绿」**（那是另一个维度）：

| 项 | 怎么量 |
|---|---|
| 改动规模 | 该步骤对 `js/` 的手写净增改行数（`git diff --stat` 口径，排除 `js/data.js` 生成物） |
| 交付耗时 | 从派发到「截图肉眼确认可用」的墙钟时间 |
| 返工次数 | 「改完才发现不对」的次数（含视觉不对、规则错译、双击打不开） |

**判据**：若第 4 步相对第 1 步**单位规则成本没有明显上升**，说明 Web 侧的改写速度随复杂度保持；若显著上升，说明它只在玩具规模下快。

## 2 步骤（按规则密度排序）

| # | 子系统 | 规格来源（Godot，只读） | 验收（必须真看图） |
|---|---|---|---|
| S1 | **多敌遭遇** | `scripts/domain/v1_battle_resolver.gd`（`enemies[]`、目标选择、多敌回合）、`scripts/domain/battle_command_facade.gd`、`data/enemies.json` | 页面上能选一场 2+ 敌遭遇，逐敌显示意图/反击/阶段，能选目标，一敌死其余继续 |
| S2 | **剑道刻痕** | `data/v1_battle.json` 的 `km_sword_mark_seek_*`、`data/gu.json` 的 `sword_mark_cost`、对应结算代码 | 刻痕可累积/消耗/触发阈值，面板可读 |
| S3 | **念头与魂魄** | `data/v1_battle.json`（念头消耗）、`scripts/domain/` 对应结算 | 念头/魂魄可消耗、可回复，且与杀招/观察联动 |
| S4 | **掉落与地图节点** | `data/nodes.json`（节点图、choices、next_ids）、`data/loot_tables.json`（含 pity） | 从单场战斗扩成可行走的短流程，战后掉落按表结算（含保底） |

每步完成后：
1. 用 `node ../wenzhen-web/tools/drive.mjs "<file://…>?silent=1" "<计划>" "1280,720"` 端到端真点；
2. **看图确认**（不能只凭 `dataset.ready===1`）；
3. 覆盖页（本页验了什么/没验什么）同步更新；
4. 把三项计量写进本文件 §3。

## 3 计量记录

| 步骤 | 改动规模 | 交付耗时 | 返工次数 | 证据 |
|---|---|---|---|---|
| S1 多敌 | 待填 | 待填 | 待填 | 待填 |
| S2 刻痕 | 待填 | 待填 | 待填 | 待填 |
| S3 念头/魂魄 | 待填 | 待填 | 待填 | 待填 |
| S4 掉落/节点 | 待填 | 待填 | 待填 | 待填 |

## 3.5 覆盖页待更正清单（本页自身的真实性维护）

覆盖页（`tools/build_data.mjs` 的 `mechanisms`）是对外宣称「验了什么/没验什么」的地方，
错一条就等于骗人。以下两条是 2026-09-20 复核发现的**已过时声明**：

1. **多敌遭遇**（S1 就地更正）：原写「data/nodes.json 的节点是 enemy_kind 单敌结构，未见多敌编组数据」。
   **已证伪** —— 数据里有 `enemy_kinds`（`data/nodes.json` → `beast_swarm_pass`，
   值 `["ridge_hound","neutral_stone_wanderer"]`），运行时也有完整语义
   （`battle_command_facade.gd:152-160`、`v1_battle_resolver.gd:820-826`、`v1_grammar_pipeline.gd:103-124`）。
   当时只查了 `enemy_kind` 单数字段。→ S1 把它移进 `covered`。
2. **多阶段 AI / 焚元**（待 S2 一并更正）：现写「enemy_catalog.gd 只做 schema 校验，运行时未实现——本页是首个实现」。
   **已过时** —— Godot 侧运行时已实现：`v1_battle_resolver.gd` 的 `active_phase_index` /
   `select_enemy_intent` / `_merge_phase_intent`，以及意图发出即焚元（`essence_burn`）。
   但该实现目前**只在工作区、尚未提交**（`git status`：`M scripts/domain/v1_battle_resolver.gd`，
   139 行；配套新增 `tests/unit/test_enemy_phases_runtime.gd` 与 `test_enemy_data_runtime_contract.gd`）。
   注意：本页原实现**没有错**，只是"本页是首个实现"这句现在不成立了；更正口径应写成
   「Godot 侧 SIDE-FIX（2026-09-19）已补运行时；本页是当时按数据自带的 `_phases_note` 独立实现的对照」。
   **未提交这件事本身属仓库状态问题，不在本实验范围**，只作登记。

## 4 结论（实验做完再写）

待填：Web 侧改写速度是否随规则复杂度保持、在什么规模开始变慢、对载体裁决意味着什么。
**本文件不出载体结论**——那是 L0 的裁决，这里只呈报计量与观察。
