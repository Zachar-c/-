# Q8 Playable Core Loop — Vertical Slice 交付报告

> **任务**：`Q8-Playable-Core-Loop-Vertical-Slice`（用户 2026-09-15 任务书）
> **基线 HEAD**：`7e6ac907`（开工时）
> **侦察记录**：`docs/q8g/PLAYABLE_CORE_LOOP_RECON.md`（Phase 0，含 Ownership 5 步声明）
> **性质**：把现有 Battle → Loot → Map → Refine 串成玩家看得懂、可操作、可重复的闭环。
> **不扩展经济统计、不新增成长线、不改命令面。**

---

## 0. 一句话结论

```text
地图上能直接看到「当前构筑目标 / 还缺什么 / 去哪推进」；
战斗产出在 Reward 屏接到目标进度；
炼蛊台把目标配方置顶并在点击前显示全部成本；
执行真实 promotion 后，地图目标从「十斤之力蛊（二转）」推进到「一钧之力蛊（三转）」。
六道 Gate（A–F）在 tools/verify_core_loop.gd 上一次跑通，含确定性回放。
```

---

## 1. 实际修改文件

| # | 文件 | 变更 | 类型 |
|---|---|---|---|
| 1 | `scripts/presentation/snapshots/build_goal_projection.gd` | **新增**：构筑目标只读投影（目标选择 / 需求评估 / 单配方需求视图 / 节点相关性）。纯函数，无状态。 | 新增（快照区） |
| 2 | `scripts/presentation/snapshots/map_snapshot.gd` | +`build_goal`；每节点 +`build_relevance` | **Shared** |
| 3 | `scripts/presentation/snapshots/reward_snapshot.gd` | +`build_progress`（由已入账 loot 反推 before/after） | **Shared** |
| 4 | `scripts/presentation/snapshots/refine_snapshot.gd` | +`build_goal` / `goal_recipe_id`；每条配方 +成本/缺失/可执行/`is_goal`；按目标优先级稳定排序 | **Shared** |
| 5 | `scripts/presentation/screens/map_screen_view.gd` | 渲染右栏「构筑目标区」+ 检视器「与目标」行 | Presentation |
| 6 | `scenes/ui/screens/map_screen.tscn` | +`map_build_goal` 面板与 4 个标签（全部 `mouse_filter=2`） | Presentation |
| 7 | `scripts/presentation/screens/reward_screen_view.gd` | 渲染「构筑进度」块 | Presentation |
| 8 | `scenes/ui/screens/reward_screen.tscn` | +`BuildProgressBox` 与 4 个标签 | Presentation |
| 9 | `scripts/presentation/screens/refine_screen_view.gd` | 目标横幅 + 配方卡成本明细 + 不可执行置灰 | Presentation |
| 10 | `scenes/ui/screens/refine_screen.tscn` | +`GoalBanner` 标签 | Presentation |
| 11 | `docs/contracts/2026-09-02-domain-ui-contract.md` | 三屏新键登记 + Playable Core Loop 只读投影键集 | **Shared 契约** |
| 12 | `docs/contracts/2026-09-02-page-inventory-requirements.md` | Map / Reward / Refine 逐屏需求补目标语义 | **Shared 契约** |
| 13 | `tests/unit/test_build_goal_projection.gd` | **新增** 13 例：目标选择规则 / 契约形状 / 信息纪律 / 节点相关性 | 测试 |
| 14 | `tests/unit/test_core_loop_snapshots.gd` | **新增** 9 例：三屏新键 + 跨屏一致性 + 显示与库存一致 | 测试 |
| 15 | `tools/verify_core_loop.gd` | **新增**：真实两轮闭环 driver（Gate A–F） | 验收 |
| 16 | `docs/q8g/PLAYABLE_CORE_LOOP_RECON.md` | Phase 0 侦察记录 + Ownership 声明 | 文档 |
| 17 | `docs/q8g/PLAYABLE_CORE_LOOP_REPORT.md` | 本报告 | 文档 |

## 2. 新增快照字段

### `build_goal`（Map / Refine）

```text
available / school / title / recipe_id / recipe_kind / recipe_name
input_gu_id / input_gu_name / input_instance_id / input_gu_ready
output_gu_id / output_name
materials[{id, name, owned, required, complete}]
stone_owned / stone_required / missing_materials[] / missing_stone
ready / missing_summary / recommended_node_types[] / progress_text
chain_index / chain_length
```

目标选择（固定优先级、纯函数、确定性）：

```text
① 本流派 promotion 链中第一条「尚未完成」（产出蛊未持有）的配方
   —— 按 input_min_rank 升序、id 升序
② 链已走完 → 回退到「已解锁、输入蛊在手的关键炼蛊配方」（fixed / advance）
③ 都没有 → available=false，title="暂无可执行构筑目标"
```

信息纪律：**不含任何内部保底计数**；不承诺掉落；未揭示节点一律 `build_relevance.code == "unknown"`。

### `build_progress`（Reward）

```text
available / title / recipe_id
lines[{id, name, gained, owned_before, owned_after, required, complete}]
stone_gained / stone_before / stone_after / stone_required
ready_before / ready_after / became_ready / next_step_text
```

`before` 由「当前库存 − 本场入账」反推（`loot.material_ids` 计数、`loot.stone_reward`），**不重抽、不改状态**。

### 节点 `build_relevance`（Map，每节点）

```text
{code: advance|execute|trade|none|unknown, text: String}
```

`code` 语义：`advance` = 可能补齐缺料/元石；`execute` = 炼蛊台可执行当前目标；
`trade` = 可购买/交换；`none` = 无直接关系；`unknown` = 未揭示（**不反推内容**）。

### Refine 配方行新增

```text
recipe_kind / is_goal / executable
materials[{id,name,owned,required,complete}] / missing[] / missing_summary
stone_owned / stone_required / input_gu_id / input_gu_name / input_owned
```

排序：`is_goal`(0) → 同流派 promotion 链(1) → 其他可执行(2) → 不可执行(3)，同级按原序稳定。

## 3. 新增 / 修改 UI 路由

```text
新增路由：无。
新增命令：无。
```

本任务是**信息投影**，不是命令面扩容：闭环所需的 `travel` / 战斗命令 / `refine_gu` / `leave_encounter`
全部既有。三屏只是把已有状态换成玩家能读的形式。

UI 侧改动：

- Map：右栏新增「构筑目标区」面板（无交互，`mouse_filter=2` 不截获点击）；检视器追加「与目标：<文案>」。
- Reward：奖励卡下方新增「构筑进度」块（本场 +N、before→after、是否变为可执行、下一步）。
- Refine：配方列表上方新增目标横幅；每条配方卡在**点击前**显示材料/元石/输入蛊成本与缺失项；
  `executable=false` 时「确认炼蛊」置灰（避免把不可执行配方伪装成可执行）。

## 4. 真实走通的 command sequence

driver：`tools/verify_core_loop.gd`（`godot --headless --path . -s tools/verify_core_loop.gd`）。
全部经 `controller.submit_command(...)`，无任何直接写 `state` 字段。

闭环 seed = **404**，school = **force**（预登记列表顺序搜索，见 §9 风险 R1）：

```text
start_new_run(404, "force")
→ travel{L1R0N0}                 视图 Encounter（起始 cultivation 节点）
→ travel{L1R1N1}                 视图 Battle
   use_gu×n / basic_attack×n      → 战斗结束 → 视图 Reward
   leave_encounter               → 视图 Map
   （战利品 #1：mat_force_1 ×1, mat_slave_1 ×1, 元石 +3）
→ travel{L1R2N1} → Battle → Reward
   （战利品 #2：mat_qi_1 ×1, mat_force_1 ×1, 元石 +3）
   leave_encounter → Map
→ travel{L1R3N3} → Battle → Reward
   （战利品 #3：mat_gold_3 ×1, mat_wisdom_3 ×1, 元石 +8）
   leave_encounter → Map
→ travel{L1R4N0}                 视图 Rest（炼蛊台的第二入口）
   controller.open_refine_subview()   → 视图 Refine（E4a 子屏，与休息屏「炼蛊」卡同一路由）
→ refine_gu{recipe_id=promote_force_atk_1_05_to_force_atk_2_06,
            input_instance_ids=[gu_005]}
   → result.ok=true
     actual_changes: stone -10 / gu_gained force_atk_2_06_gu / gu_lost force_atk_1_05_gu
→ leave_encounter                 → 视图 Map
→ build_goal：promote_force_atk_1_05_to_force_atk_2_06
             → promote_force_atk_2_06_to_force_atk_3_07（二转 → 三转）
```

## 5. 两轮资源 → 目标 → 炼蛊闭环证据

### 第一轮：战斗 → 材料 → 目标进度（Gate B）

```text
开局：兽筋 0/1 · 元石 12/10 · 输入蛊已拥有        缺 兽筋
战利品 #1（mat_force_1 ×1, 元石 +3） → 兽筋 1/1 · 元石 15/10   ready_after=true
战利品 #2（mat_force_1 ×1, 元石 +3） → 兽筋 2/1 · 元石 18/10   ready_after=true
战利品 #3（mat_gold_3 ×1, 元石 +8）  → 兽筋 2/1 · 元石 26/10   ready_after=true
```

一致性断言（全 PASS）：Reward 快照显示的材料数与真实 `state.materials` 一致（2/2）、
元石与真实 `state.stone` 一致（26/26）—— **显示与库存无偏差**。

### 第二轮：目标完成 → 真实 promotion → 构筑变化 → 地图目标变化（Gate C + D）

```text
执行：promote_force_atk_1_05_to_force_atk_2_06
输入实例：gu_005（斤力蛊）→ 产出蛊：force_atk_2_06_gu（十斤之力蛊）

[PASS] 材料 mat_force_1 真实扣除 1          （实际扣除=1）
[PASS] 元石真实扣除 10                      （实际扣除=10）
[PASS] 输入蛊实例被真实消费                  （gu_005 state=consumed 且移出蛊仓）
[PASS] 产出蛊真实进入库存                    （force_atk_2_06_gu）
[PASS] 产出蛊为新增（此前不持有）
[PASS] 事件日志记录 promotion_succeeded      （事件数 46 → 50）
[PASS] 蛊仓可用实例数守恒（-1 输入 +1 产出）  （5 → 5）

炼蛊前目标：十斤之力蛊（二转）
炼蛊后目标：一钧之力蛊（三转）
炼蛊后进度：荒兽筋 0/1 · 元石 16/18 · 输入蛊已拥有
[PASS] 地图目标已改变（推进到下一条 promotion）
[PASS] 节点相关性随新目标重算
```

## 6. 单测结果

| 套件 | 命令 | 退出码 | 结果 |
|---|---|---|---|
| 新增投影单测 | `-gtest res://tests/unit/test_build_goal_projection.gd` | 0 | **13 / 13** |
| 新增三屏契约单测 | `-gtest res://tests/unit/test_core_loop_snapshots.gd` | 0 | **9 / 9** |
| unit 全量 | `-gdir res://tests/unit -gexit -glog=2` | 0 | **1467 / 1467 通过，0 失败**（Asserts 51208） |

用例数变化：1445 → **1467**（+22 = 新增两个测试文件 13 + 9），既有断言**未删除或放宽**。

覆盖要点：目标选择规则（首条未完成 promotion / 链推进 / 回退 / 无目标）、
确定性（同 seed 同 school 投影一致）、
契约形状（`build_goal` 声明键、`materials[]` 子键、Phase 4 配方行键）、
信息纪律（不含 pity、未揭示节点 `unknown`、不承诺掉落）、
跨屏一致性（Reward 显示 == 真实库存；Refine 材料 owned == 真实库存）。

## 7. integration 结果

```text
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir res://tests/integration -gexit -glog=2
退出码 0    Tests 32 / Passing 32 / Failing 0（Asserts 1476，42.6s）
```

## 8. interaction loop 结果

```text
godot --headless --path . -s tools/verify_interaction_loop.gd
退出码 0
```

**Gate E 要求的三键全部为空**（含 `occluded_known=0`）：

```text
Map     dead=[] no_ui_click=[] occluded=[] occluded_known=0
Reward  dead=[] no_ui_click=[] occluded=[] occluded_known=0
Refine  dead=[] no_ui_click=[] occluded=[] occluded_known=0
（其余 12 个审计标签同样三键全 0）
```

`Reward → Map` / `Map → Refine` / `Refine → Map` 三条跳转由闭环 driver 实际走通（§4）。
本轮新增元素**全部是无交互文本**，未新增按钮，因此未引入新的点击音效接线需求；
既有按钮的视觉 + 听觉反馈沿用 `MasterTheme.apply_button`，交互门未报 `dead`。

### 验证汇总

| # | 命令 | 退出码 | 结果 |
|---|---|---|---|
| 1 | `-s tools/verify_core_loop.gd`（闭环 driver，Gate A–F） | 0 | **RESULT: PASS**；闭环 seed=404；Gate F 回放轨迹 4/4 一致 |
| 2 | `-gtest res://tests/unit/test_build_goal_projection.gd` | 0 | **13 / 13** |
| 3 | `-gtest res://tests/unit/test_core_loop_snapshots.gd` | 0 | **9 / 9**（Asserts 3349） |
| 4 | `-gdir res://tests/unit -gexit -glog=2` | 0 | **Tests 1467 / Passing 1467 / Failing 0**（Asserts 51208，189.1s） |
| 5 | `-gdir res://tests/integration -gexit -glog=2` | 0 | **Tests 32 / Passing 32 / Failing 0**（Asserts 1476，42.6s） |
| 6 | `-s tools/verify_interaction_loop.gd`（Gate E） | 0 | 15 个审计标签全部 `dead=[] no_ui_click=[] occluded=[] occluded_known=0` |
| 7 | `-s tools/check_contract_drift.gd` | 0 | `contract drift: ok (200 identifiers resolved)`（原 168，新增键已登记） |
| 8 | `git diff --check` | 0 | 无空白错误 |

`run_gut_checked.ps1` 的严格判定（`Parse Error / Ignoring script / Nothing was run / SCRIPT ERROR`）
在 unit 与 integration 上均为 **PASS**。

交互门逐屏（Gate E 证据）：

```text
AUDIT[Map]      total=14 clickable=11 dead=[] no_ui_click=[] occluded=[] occluded_known=0
AUDIT[Reward]   total=3  clickable=3  dead=[] no_ui_click=[] occluded=[] occluded_known=0
AUDIT[Refine]   total=481 clickable=11 dead=[] no_ui_click=[] occluded=[] occluded_known=0
（其余 12 个审计标签同样三键全 0）
```

Map 的 `total` 由 7 增至 14 —— 新增的构筑目标面板（1 Panel + 1 Margin + 1 VBox + 4 Label）全部
`mouse_filter=2`，不计入 `clickable`，也未产生任何遮挡。

## 9. 未验证风险

```text
R1  driver 的 seed 选择是「预登记列表 + 确定性顺序搜索」，取第一个能在单局内闭合的 seed（404）。
    这不是任意 seed 都成立：生产 pacing.ending_after_stage == "one"，单局只跑 L1（8–11 行、
    ~7 个战斗节点），而炼蛊台固定落在 L1 中段（探针实测 row 4–5，地图无回溯）。
    因此「第一条 promotion 所需 crude 材料必须在炼蛊台之前掉落」是一个窄窗口。
    20 个预登记 seed 中只有 1 个同时满足「材料早掉 + 路径通向炼蛊台」。
    ⇒ 这是被记录的产品观察（首局可能凑不齐第一条 promotion），不是 driver 缺陷；
      但意味着「20–40 分钟内至少 1 次真实炼蛊」在当前 L1 拓扑下不是必然事件。
R2  driver 用了玩家看不到的信息：选路时按 route 节点的 enemy_roll 偏好 common 结算的战斗节点。
    玩家只能看到节点类型。因此 driver 的路径不代表真实玩家路径，闭环的「可达性」被高估。
R3  本轮只验证 1 个 seed × 1 个流派（force）。sword / 其他 19 个流派未跑同一 driver。
R4  Reward 的 before/after 是「当前库存 − 本场入账」的反推；若同场还有非战利品来源的材料变化
    （事件支付等）未建模，理论上会偏。本轮闭环路径未出现该情形。
R5  UI 侧只做了 headless 验证（快照键 + 交互门 + 命令接线）；未开真实视窗看排版，
    新增面板在 1280×720 下是否与既有右栏元素重叠**未肉眼确认**（已按 x=0.88–0.995 / y=256–460 布局，
    与 map_inventory y=195–243 不重叠）。
R6  Gate E 的「视觉 + 听觉反馈」由既有交互门覆盖；本轮新增元素全部为无交互文本，未新增按钮，
    因此未引入新的点击音效接线需求。
```

## 10. 是否触碰 Shared 文件

```text
是。已按 docs/contracts/2026-09-12-agent-ownership-contract.md §3 完成 5 步声明
（落档于 docs/q8g/PLAYABLE_CORE_LOOP_RECON.md §9）：

  1. 声明文件      map_snapshot.gd / reward_snapshot.gd / refine_snapshot.gd
                   + domain-ui-contract.md / page-inventory-requirements.md
  2. 原因          Q8-Playable-Core-Loop-Vertical-Slice Phase 1–4
  3. 影响面        Map / Reward / Refine 三屏（仅新增只读键，不删改既有键）；命令面零变更
  4. 指定测试      两个新增单测 + unit 全量 + integration + 交互门 + 闭环 driver
  5. 单独 commit   建议 Commit A（快照/契约/测试）/ B（presentation）/ C（driver+报告）

run_controller.gd / run_snapshot_builder.gd / resolver.gd / run_state.gd /
save_repository.gd / main.tscn / project.godot 均**未修改**。
```

## 11. 是否触碰 domain / data

```text
否。
  scripts/domain/**   零修改（含 run_state.gd / resolver.gd / loot_resolver.gd /
                      map_generator.gd / refine_command_rules.gd / content_catalog.gd）
  data/**             零修改（含 nodes.json / loot_tables.json / pacing.json /
                      enemies.json / balance.json / refinement_recipes.json）
  RunState            零修改（无新增字段、无新事件类型）
  save_repository.gd  零修改
  project.godot       零修改

promotion 成本 / battle 数值 / E6 / pacing / 敌人 tier / 正式 pity / M-G-T 经济规则：全部未触碰。
未运行任何 M/G/T 组合；未把任何 hypothetical 数值写回配置。
```

## 12. 复现命令

```bash
GODOT="%LOCALAPPDATA%/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"

# 闭环 driver（Gate A–F）
"$GODOT" --headless --path . -s tools/verify_core_loop.gd

# 新增单测
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gtest res://tests/unit/test_build_goal_projection.gd -gexit -glog=2
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gtest res://tests/unit/test_core_loop_snapshots.gd -gexit -glog=2

# 全量回归
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir res://tests/unit -gexit -glog=2
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir res://tests/integration -gexit -glog=2

# 交互门（Gate E 的点击/遮挡部分）
"$GODOT" --headless --path . -s tools/verify_interaction_loop.gd

# 契约漂移 + 空白
"$GODOT" --headless --path . -s tools/check_contract_drift.gd
git diff --check
```

---

## 13. R2/R3 收尾复核（2026-09-15）

本节覆盖原 §9 中的两项风险：

- R2：driver 使用玩家不可见的 `enemy_roll` 选路；
- R3：只验证 force，未验证 sword。

使用：

```text
CORE_LOOP_FAITHFUL=1
```

该模式不读取或偏好节点的 `enemy_roll`，只按玩家可见的地图快照顺序选择可达节点。

### R2：玩家可见路线

```text
force：RESULT: PASS
sword：RESULT: PASS
```

两次闭环均完成：

```text
Map → Battle → Reward → Map → Refine → promotion → Map
```

并通过 Gate A–F。driver 不再使用玩家不可见的 `enemy_roll` 作为选路依据。

### R3：第二流派

`sword` 真实闭环验证通过：

```text
目标：藏锋蛊（二转）
输入蛊：sword_def_1_07_gu
材料：mat_sword_1
元石成本：6
真实 promotion：sword_def_1_07 → sword_atk_2_20
目标推进：二转目标 → 三转目标
Gate F：首轮/回放轨迹一致
```

R3 已关闭；本切片仍不是 19/20 流派的完整验收，只证明 force/sword 两条代表性链路可用。

### 当前仍保留的产品风险

```text
首局 promotion 窗口仍受生产 pacing ending_after_stage=one 限制；
20–40 分钟内必然完成 promotion 尚未成为正式保证；
新增 Map 面板只做 headless 排版/交互验证，未另做真窗肉眼复核；
```

这些是后续产品体验问题，不构成当前垂直切片代码失败，也不授权修改 pacing 或经济参数。
