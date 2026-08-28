# 南疆凡人 V2 首个纵向切片 Implementation Plan

> 日期：2026-08-22
> 状态：已归档
> 范围：南疆 V2 首个纵向切片实施计划；保留用于实现追踪。
> 基线：`branch=master @ 2e850dd`；该计划最终变更以此提交为准。
> 替代关系：相关实现已合入当前原型。


> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付一个固定种子、可手工游玩的第一阶段闭环：在分叉路线中选择，处理一场中立蛊师遭遇，战斗或脱身，完成商队调整、炼蛊或二转突破，并结算一次养蛊总账。

**Architecture:** `RunState.append_event()` 是唯一状态写入入口。路线、战斗、商队、炼蛊、修行和总账均以纯 GDScript 返回新状态；`RunController` 只提交命令与切换展示。固定种子 `101` 生成可重放的有向分支图。

**Tech Stack:** Godot 4.6.2, GDScript, JSON, GUT 9.x, Windows keyboard/mouse, `gl_compatibility` renderer.

## Global Constraints

- 玩家界面仅使用中文；代码标识符、JSON 键、测试名、提交信息保持 ASCII。
- 调试窗口标题保持 `Nanjiang Smoke (DEBUG)`，`renderer/rendering_method="gl_compatibility"` 不变。
- 不修改 `vendor/godot-open-rpg/` 或受保护资料目录。
- 不做卡组、抽牌、预设正确杀招、战前蛊槽或蛊虫持有数量上限。
- 所有已养且已炼化的蛊虫，只要真元、冷却、目标与局势条件满足，就能在战斗中催发。
- 关键状态变化必须写入不可变结构化事件；UI 不得直接修改 `RunState`。
- 固定一转初阶、丙等资质、真元容量四成四；本切片允许二转，不能开放三转。
- 仅结算第一阶段养蛊总账；资金不足时给出卖蛊、换蛊、炼蛊或附条件援助的明确处理。

---

## Planned File Structure

```text
data/gu.json                             # 蛊虫的养护、价格、效果和来源字段
data/first_run.json                      # 固定种子 101 的分支和连接
data/nodes.json                          # 首轮节点公开信息、接触与奖励
data/refinement_recipes.json             # 合炼/升炼配方和失败后果
scripts/domain/run_state.gd              # 阶段、资质、养护、路线状态
scripts/domain/map_generator.gd          # 有向分叉路线和可达节点
scripts/domain/resolver.gd               # 接触、交易、炼蛊、修行、总账命令
scripts/domain/battle_resolver.gd        # 全体已养蛊虫均可用的战斗
scripts/domain/content_catalog.gd        # 配方及报价读取和校验
scripts/presentation/*.gd                # 展示状态、提交命令，不写规则
tests/unit/test_v2_*.gd                  # 纯规则回归测试
tests/integration/test_v2_first_slice_flow.gd
```

### Task 1: 第一阶段的路线、状态与养护账本

**Files:**
- Modify: `scripts/domain/run_state.gd`
- Modify: `scripts/domain/map_generator.gd`
- Modify: `data/first_run.json`
- Modify: `data/nodes.json`
- Create: `tests/unit/test_v2_run_state.gd`
- Create: `tests/unit/test_v2_map_generator.gd`

**Interfaces:**
- Produces `RunState.estimate_feeding(catalog: Dictionary) -> int`.
- Produces `MapGenerator.reachable_nodes(route: Array[Dictionary], state: RunState) -> Array[Dictionary]`.
- Adds `aptitude`, `essence_capacity`, `refined_gu_ids`, `route_progress`, and `node_flags` to all state snapshots.

- [ ] **Step 1: Write failing tests**

```gdscript
func test_new_v2_run_records_bing_aptitude_and_next_feeding() -> void:
    var state := RunState.new_run(101)
    assert_eq(state.aptitude, "bing")
    assert_eq(state.essence_capacity, 4)
    assert_eq(state.estimate_feeding(ContentCatalog.load_all()), 1)

func test_only_connected_visible_nodes_are_reachable() -> void:
    var state := RunState.new_run(101)
    var route := MapGenerator.build(101, true)
    var ids := MapGenerator.reachable_nodes(route, state).map(func(node): return node["id"])
    assert_eq(ids, ["neutral_wanderer", "ridge_caravan"])
```

- [ ] **Step 2: Verify red**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_v2_run_state.gd -gexit -glog=2`

Expected: FAIL because V2 state and branch interfaces do not exist.

- [ ] **Step 3: Implement minimal state and branch graph**

```gdscript
func estimate_feeding(catalog: Dictionary) -> int:
    var total := 0
    for gu_id in refined_gu_ids:
        total += int(catalog["gu_by_id"].get(gu_id, {}).get("feeding_cost", 0))
    return total
```

Seed `101` begins at `trailhead`, reaches only `neutral_wanderer` and `ridge_caravan`, then reveals successors solely when the chosen node is event-backed complete.

- [ ] **Step 4: Verify green**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_v2_run_state.gd -gexit -glog=2`
Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_v2_map_generator.gd -gexit -glog=2`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/run_state.gd scripts/domain/map_generator.gd data/first_run.json data/nodes.json tests/unit/test_v2_run_state.gd tests/unit/test_v2_map_generator.gd
git commit -m "feat: add v2 stage one branch state"
```

### Task 2: 中立遭遇和全蛊可用的抽象战斗

**Files:**
- Modify: `scripts/domain/battle_resolver.gd`
- Modify: `scripts/domain/resolver.gd`
- Modify: `data/gu.json`
- Create: `tests/unit/test_v2_battle_resolver.gd`

**Interfaces:**
- `BattleResolver.start(encounter, state)` returns `available_gu_ids` equal to all `state.refined_gu_ids`.
- `BattleResolver.take_turn(...)` resolves deterministic enemy intent and returns `victory`, `retreated`, `defeat`, or `ongoing`.
- `Resolver.apply(state, {"type":"resolve_contact", "approach":...}, catalog)` supports `negotiate`, `deceive`, `fight`, and `retreat`.

- [ ] **Step 1: Write failing tests**

```gdscript
func test_battle_makes_every_refined_gu_available_without_slot_cap() -> void:
    var state := RunState.new_run(101)
    state.refined_gu_ids = ["small_light_gu", "thorn_whip_gu", "stone_shell_gu", "mist_step_gu", "blood_moss_gu"]
    var battle := BattleResolver.start({"enemy_kind": "greedy_wanderer"}, state)
    assert_eq(battle["available_gu_ids"], state.refined_gu_ids)

func test_deceiving_neutral_wanderer_changes_future_reward_without_battle() -> void:
    var result := Resolver.apply(RunState.new_run(101), {"type":"resolve_contact", "approach":"deceive", "node_id":"neutral_wanderer"}, ContentCatalog.load_all())
    assert_true(result["result"]["ok"])
    assert_true(result["state"].known_facts.has("wanderer_misdirected"))
    assert_eq(result["state"].stone, 14)
```

- [ ] **Step 2: Verify red**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_v2_battle_resolver.gd -gexit -glog=2`

Expected: FAIL because battle uses fixed `slots` and contact commands do not exist.

- [ ] **Step 3: Implement minimal rules**

Replace every `slots` check with `available_gu_ids` derived only from `refined_gu_ids`. Add `intent_id` and `intent_damage`; after a legal Gu action resolve that intent. `stone_shell_gu` cancels one hit, `mist_step_gu` opens retreat, attack Gu reduce enemy wound. `negotiate` consumes one information and yields a guarded offer; `deceive` adds two stones and `wanderer_misdirected`; `fight` starts battle; `retreat` loses one stone and adds `wanderer_alerted`.

- [ ] **Step 4: Verify green and commit**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_v2_battle_resolver.gd -gexit -glog=2`

```bash
git add scripts/domain/battle_resolver.gd scripts/domain/resolver.gd data/gu.json tests/unit/test_v2_battle_resolver.gd
git commit -m "feat: add v2 free gu combat and contact"
```

### Task 3: 商队、炼蛊、二转与阶段总账

**Files:**
- Create: `data/refinement_recipes.json`
- Modify: `scripts/domain/content_catalog.gd`
- Modify: `scripts/domain/resolver.gd`
- Create: `tests/unit/test_v2_economy_resolver.gd`

**Interfaces:**
- Commands: `buy_gu`, `sell_gu`, `exchange_gu`, `refine_gu`, `cultivate_rank_two`, `settle_feeding`.
- Invalid resources, inputs, offers or nodes return reject reasons with no state mutation.

- [ ] **Step 1: Write failing tests**

```gdscript
func test_caravan_exchange_replaces_two_low_rank_gu_with_a_rare_gu() -> void:
    var state := RunState.new_run(101)
    state.refined_gu_ids = ["small_light_gu", "trail_eye_gu", "stone_shell_gu"]
    var result := Resolver.apply(state, {"type":"exchange_gu", "offer_id":"caravan_mist_exchange"}, ContentCatalog.load_all())
    assert_true(result["state"].refined_gu_ids.has("mist_step_gu"))
    assert_false(result["state"].refined_gu_ids.has("trail_eye_gu"))

func test_failed_refinement_destroys_declared_input_gu() -> void:
    var state := RunState.new_run(101)
    state.refined_gu_ids = ["small_light_gu", "trail_eye_gu"]
    var result := Resolver.apply(state, {"type":"refine_gu", "recipe_id":"bright_thread_risk", "roll":99}, ContentCatalog.load_all())
    assert_eq(result["state"].refined_gu_ids, [])
    assert_eq(result["state"].event_log.back()["reason"], "refinement_failed_destroyed_inputs")

func test_stage_ledger_blocks_progress_until_paid_or_adjusted() -> void:
    var state := RunState.new_run(101)
    state.stone = 0
    var result := Resolver.apply(state, {"type":"settle_feeding"}, ContentCatalog.load_all())
    assert_false(result["result"]["ok"])
    assert_eq(result["result"]["reason"], "feeding_shortfall")
```

- [ ] **Step 2: Verify red**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_v2_economy_resolver.gd -gexit -glog=2`

Expected: FAIL because the commands and recipes do not exist.

- [ ] **Step 3: Implement data-driven economy**

`buy_gu` spends authored cost. `sell_gu` removes named refined Gu and pays declared value. `exchange_gu` atomically consumes declared inputs and adds output. `refine_gu` uses declared inputs and `roll`; failure destroys every input. `cultivate_rank_two` costs five stones, requires a cultivation node, assigns `cultivation = 2`, restores essence to capacity, and logs `rank_two_breakthrough`.

- [ ] **Step 4: Implement stage ledger**

At `stage_one_ledger`, charge `estimate_feeding`. Payment marks `one_paid`. A shortfall stays visible and only permits sell, exchange, refinement or a one-time caravan debt action that adds `caravan_favor_debt`; no silent debt or automatic deletion.

- [ ] **Step 5: Verify green and commit**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_v2_economy_resolver.gd -gexit -glog=2`
Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit -glog=2`

```bash
git add data/refinement_recipes.json scripts/domain/content_catalog.gd scripts/domain/resolver.gd tests/unit/test_v2_economy_resolver.gd
git commit -m "feat: add v2 trade refinement and ledger"
```

### Task 4: 中文手玩界面及全流程验收

**Files:**
- Modify: `scripts/presentation/run_controller.gd`
- Modify: `scripts/presentation/map_view.gd`
- Modify: `scripts/presentation/encounter_view.gd`
- Modify: `scripts/presentation/battle_view.gd`
- Modify: `scripts/presentation/display_text.gd`
- Create: `tests/integration/test_v2_first_slice_flow.gd`
- Modify: `README.md`

**Interfaces:**
- Controller permits的 travel 等于 `MapGenerator.reachable_nodes(route, state)`。
- 地图显示修为、资质、真元容量、元石、伤势与 `下次养护：预计 X 元石`。
- 战斗按钮来自 `battle.available_gu_ids`。

- [ ] **Step 1: Write a failing integration test**

```gdscript
func test_seed_101_can_finish_one_branch_and_reach_stage_ledger() -> void:
    var controller := preload("res://scripts/presentation/run_controller.gd").new()
    controller.start_new_run(101)
    controller.submit_command({"type":"travel", "node_id":"neutral_wanderer"})
    controller.submit_command({"type":"resolve_contact", "node_id":"neutral_wanderer", "approach":"deceive"})
    controller.submit_command({"type":"travel", "node_id":"ridge_caravan"})
    controller.submit_command({"type":"buy_gu", "offer_id":"caravan_thorn_offer"})
    assert_eq(controller.current_node_id_for_test(), "stage_one_ledger")
    controller.free()
```

- [ ] **Step 2: Verify red**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_v2_first_slice_flow.gd -gexit -glog=2`

Expected: FAIL because controller accepts arbitrary travel and cannot resolve the V2 loop.

- [ ] **Step 3: Wire presentation**

Render two visible route choices with public summary and pressure. Render encounter-specific buttons for contact, buy/sell/exchange, refine, cultivate and pay bill. Render every battle Gu in a wrapping grid. After completion expose only declared successors; after first-stage terminal node enter `stage_one_ledger`.

- [ ] **Step 4: Verify automated and manual acceptance**

Run:

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit -glog=2
godot --headless --path . --quit-after 3
git diff --check
```

Manual fixed seed `101`:
1. 选择中立散修后欺瞒，确认元石与结果变化。
2. 进入山脊商队，买卖或交换蛊虫，确认养护预估变化。
3. 进入战斗分支，确认所有已养蛊虫都出现，不存在四槽上限。
4. 用风险配方测试成功与失败，确认失败毁输入蛊。
5. 到达阶段养蛊总账，测试付款和资金不足后的调整路径。

- [ ] **Step 5: Commit**

```bash
git add scripts/presentation tests/integration/test_v2_first_slice_flow.gd README.md
git commit -m "feat: add playable v2 first slice"
```

## Plan Self-Review

- **Spec coverage:** 分支、接触后果、全蛊战斗、商队交易、炼蛊、二转与阶段养护总账均有独立可失败测试和同晚手工路径。
- **Deliberate limits:** 三阶段、四势力、三转资格、遗藏首领、撤离、升仙均不提前进入本轮。
- **Consistency:** `refined_gu_ids` 同时供战斗与养护使用；全部改变通过事件；可达性由事件记录的节点标记推导。
- **Placeholder scan:** 无未决定的依赖、接口或规则占位。
