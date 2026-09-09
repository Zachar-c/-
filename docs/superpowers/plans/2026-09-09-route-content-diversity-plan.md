# 路线内容多样性实施计划（2026-09-09）

> 用途：修复体验断层——`pacing.json` 内容池只配战斗模板，导致 12 种玩法类型、21 个节点模板整局零生成。本计划为唯一实施依据，工单可单独派发；控制器负责验收、聚焦提交与回写状态。
>
> 并行约束：与 `docs/superpowers/plans/2026-09-05-architecture-refactor-master-plan.md`（架构重构）互不干扰——本计划**只改 `data/pacing.json`、验证工具与测试**，不触碰领域逻辑层（`scripts/domain/*`、`scripts/presentation/run_controller.gd` 的 travel 分发已完整支持全部节点类型，无需改代码）。
>
> 审计证据：`tools/verify_master_flow.gd`（Npc 目标恒红）+ 155 节点路线类型分布（seed 20260908）= combat 113 / rest 20 / shop 15 / refinement 5 / inheritance 1 / ascension 1。

## 1. 问题基线（审计结论）

- **路线生成只产出 6 种类型**：combat、rest、shop、refinement、inheritance、ascension。
- 战斗占比 **73%**（113/155）；L1/L2 池全战斗，L3-L5 池全战斗。
- **21 个模板 / 12 种类型零生成**（代码与 UI 屏均完整支持，仅池子未接入）：

| 类型 | 模板 | 对应屏 | 现状 |
|---|---|---|---|
| contact（NPC 接触） | neutral_wanderer、wandering_peddler | Npc 屏 | 整局不可达 |
| event（事件） | echo_cave、gu_rot_pact | Encounter + Dialogue | 整局不可达 |
| market（黑市） | village_short_work、ridge_market | Shop 屏 | 整局不可达 |
| caravan（车队） | ridge_caravan、caravan_missing_goods | Shop 屏 | 整局不可达 |
| commission（雇佣） | herbalist_commission | Encounter 屏 | 整局不可达 |
| wild_gu（奇遇） | blood_moss_grove | Encounter 屏 | 整局不可达 |
| hazard（凶险） | toxic_mountain_path、flooded_cave、black_mud_marsh | Encounter 屏 | 整局不可达 |
| earth_vein（灵脉） | earth_vein_contest、sealed_earth_vein、poison_fog_vein | Encounter 屏 | 整局不可达 |
| seclusion（闭关） | body_imprint_ritual | Encounter 屏 | 整局不可达 |
| cultivation（修炼） | cultivation_spring | Encounter 屏 | 整局不可达 |
| ledger（账册） | stage_one_ledger | Encounter 屏 | 整局不可达 |
| pursuit（追猎） | greedy_wanderer | Battle 屏（战斗变体） | 整局不可达 |

- 影响：NPC 交易、事件抉择、黑市、车队、奇遇等玩法**代码存在但玩家永远见不到**；路线单调、战斗刷屏。

## 2. 目标与验收标准

- **T1 内容可达**：任意 seed 完整路线中，12 种类型全部至少出现一次（多 seed 累计覆盖）。
- **T2 开局可见**：任意 seed 前 2 层（L1+L2）至少出现 1 个 contact 或 event 节点，玩家开局即有 NPC/事件交互。
- **T3 战斗占比**：单局战斗节点占比从 73% 降至 **55%–60%**。
- **T4 回归绿**：`verify_master_flow.gd` 全目标（Battle/Rest/Shop/Refine/Encounter/Npc）绿；全量 unit + integration 绿；pacing_density 断言与数据同步。
- **T5 确定性**：相同 seed 产出相同路线（现有种子化机制，不得引入非种子随机）。

## 3. 方案设计

### 3.1 各层 pool 扩展（核心改动）

按玩法阶段解锁，非战斗类型混入各层池（模板名前缀取自 nodes.json）：

| 层 | 现有 pool（战斗 3 个） | 新增非战斗池（各层共 4 个） | 阶段主题 |
|---|---|---|---|
| L1 | beast_swarm_pass、iron_hide_ambush、scout_crossing_raid | toxic_mountain_path、flooded_cave、cultivation_spring、black_mud_marsh | 初入荒山：凶险+修炼 |
| L2 | iron_hide_ambush、scout_crossing_raid、beast_swarm_pass | echo_cave、blood_moss_grove、village_short_work、herbalist_commission | 事件+奇遇+黑市+雇佣 |
| L3 | scout_crossing_raid、faction_guard_checkpoint、wolf_pack_trail | gu_rot_pact、ridge_caravan、greedy_wanderer、body_imprint_ritual | 事件+车队+追猎+闭关 |
| L4 | faction_guard_checkpoint、wolf_pack_trail、scout_crossing_raid | ridge_market、caravan_missing_goods、earth_vein_contest、sealed_earth_vein | 黑市+车队+灵脉 |
| L5 | wolf_pack_trail、faction_guard_checkpoint、iron_hide_ambush | poison_fog_vein、greedy_wanderer、body_imprint_ritual、earth_vein_contest | 深脉：灵脉+追猎 |

> 池大小 3+4=7：`_pick_pool_template` 从 pool 中按 `used_in_row`/`reserved_templates` 去重选择，池扩大会降低同层重复感。战斗权重仍高于单类非战斗（每类 1 个 vs 战斗 3 个），战斗占比由锚点数量与池配比共同决定，实施后以实测路线校准。

### 3.2 anchor 保底（保证开局可见）

在 `layers.<N>.anchors` 中追加：

| 层 | 新增 anchor | 位置 |
|---|---|---|
| L1 | neutral_wanderer（contact） | mid |
| L2 | echo_cave（event） | quarter |
| L3 | ridge_caravan（caravan） | quarter |
| L4 | ridge_market（market） | mid |
| L5 | earth_vein_contest（earth_vein） | quarter |

> L1 保底接触节点（Npc 屏开局可达）；L2 保底事件；中后期保底交易与灵脉。anchor 优先级高于 pool（`anchor_queue` 先行弹出），不依赖随机。

### 3.3 战斗占比控制

- 池扩展后预计战斗占比 ≈ 战斗池 3/(3+4) ≈ 43% 的池选 + anchor 中的战斗（每层 1 个 boss + pre_boss 战斗锚）+ rest 行距 2。
- **目标区间 55%–60%**：若实测低于 55%（节奏过松、升级来源不足），回收每层 1 个非战斗池模板（优先回收 hazard/earth_vein 中体验重复者）；若高于 60%，再补 1 个非战斗池模板。**以实测路线为准，参数留待校准，不预设死值。**

### 3.4 不改动的部分

- travel 分发（run_controller.gd L628-652）——已支持全部类型，零改动。
- 各屏 tscn / 对话数据——仅接入既有内容，不新增文案。
- `content_catalog.gd` NODE_KIND_IDS——已含全部类型，零改动。
- first_run.json（首局固定路线）——不在本计划范围，另行评估。

## 4. 实施工单（分批）

### 工单 R1：pacing.json 扩池 + 保底锚（数据层）

- 按 §3.1/§3.2 修改 `data/pacing.json` 五层 pool 与 anchors。
- 保持 JSON Schema 校验通过（`tools/check.ps1` 或对应数据校验）。
- 产出：pacing.json diff。

### 工单 R2：回归工具更新

- `tools/verify_master_flow.gd`：目标已含 Npc（无需改），验证修复 Rest 分支后仍绿。
- `tools/verify_pacing_density.gd`：将类型计数断言从"仅战斗/休息/商店/炼蛊/传承"扩展为全 12 类型计数，输出每层类型分布。
- 新增 `tools/verify_route_diversity.gd`（或并入 pacing_density）：
  - 断言任意 seed（探测集 ≥10 个）L1+L2 含 contact 或 event；
  - 断言多 seed 累计覆盖 12 类型；
  - 断言战斗占比在 [55, 60]（按当前层配置校准后锁定断言区间）。

### 工单 R3：单元测试补强

- `tests/unit/test_map_*.gd` 或新增 `test_route_diversity.gd`：
  - 确定性：固定 seed 的路线类型分布断言（不重复生成）；
  - 保底：L1 anchor 含 contact、L2 anchor 含 event；
  - 池选：pool 中新模板可被选中（多次 seed 覆盖统计）。
- 全量 unit + integration 回归。

### 工单 R4：全流程验收 + 提交

- `verify_master_flow` 全目标绿（含 Npc）。
- 全量测试绿 + `tools/check.ps1` 绿。
- 审计：随机 5 个 seed 的路线类型分布打印，人工核对阶段主题合理性（L1 无灵脉/车队，L5 无新手凶险等）。
- 聚焦提交（pacing.json、verify 工具、新测试），推送待用户确认。

## 5. 验证方案

| 验证项 | 命令/方式 | 通过标准 |
|---|---|---|
| 主流程冒烟 | `tools\godot.ps1 --headless --path . -s tools/verify_master_flow.gd` | 输出 `MASTER_FLOW_OK`，全目标覆盖 |
| 节奏密度 | `... -s tools/verify_pacing_density.gd` | 全类型计数 + 层分布输出，exit 0 |
| 全量单测 | `tools\test.ps1 -Suite unit` | 全绿，exit 0 |
| 集成 | `tools\test.ps1 -Suite integration` | 全绿，exit 0 |
| 完整质量门 | `tools\check.ps1` | 全绿 |
| 路线确定性 | 固定 seed 重复生成两次类型分布一致 | 一致 |

## 6. 风险与回退

| 风险 | 影响 | 应对 |
|---|---|---|
| 新类型节点进入后无法离开（如 Npc 屏离开按钮缺失） | 卡死 | R2 阶段用 verify_master_flow travel+leave 覆盖每类节点，发现即修（可能涉及小范围 UI/命令面改动，需同步契约文档） |
| 非战斗节点无对应领域结算（如 ledger/cultivation 无命令处理） | 假节点/死路 | 实施前先跑一次"全类型 travel 冒烟"（R2 前置），确认各类型 travel → leave 闭环；缺失者列入待办并回写契约 |
| 战斗占比波动 | 节奏失衡 | §3.3 校准机制，以实测路线为准回滚单层池改动 |
| 与并行重构计划文件冲突 | 合并冲突 | 本计划只动 pacing.json + tools + tests，与重构（scripts/domain、ui_masters）零重叠 |

## 7. 决策点（需用户拍板）

- **D1**：非战斗池模板的"阶段分配"（§3.1 表格）是否符合预期——尤其 L1 放凶险+修炼、L3 放车队+闭关的排布。
- **D2**：战斗占比目标 55%–60% 是否接受（当前 73%）。
- **D3**：Npc/事件/黑市等接入后，若发现屏内缺内容（如 Npc 屏无商人数据、事件无对话脚本），是"补数据让系统真正可用"（扩大范围）还是"先可达、内容后补"（本计划范围）。
- **D4**：pacing.json 改动 + 新验证工具/测试是否随本计划一起聚焦提交。

## 8. 状态跟踪

- [ ] R1 pacing.json 扩池 + 保底锚
- [ ] R2 回归工具更新（verify_pacing_density 扩展 / route_diversity / 全类型 travel 冒烟）
- [ ] R3 单元测试补强（确定性 + 保底 + 池选）
- [ ] R4 全流程验收 + 聚焦提交

> 完成一项勾选一项并回写本文件；状态以各工单内嵌进度为准。
