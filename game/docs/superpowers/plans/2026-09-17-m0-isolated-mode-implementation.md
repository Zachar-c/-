# M0 Isolated Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立一个不影响完整运行流的 M0 独立垂直切片，真实验证四场战斗、三选一奖励、Build 变化、Boss 胜利和死亡重开。

**Architecture:** `RunController.start_m0_run()` 负责初始化 M0 状态和模式标志；`M0RunFlow` 负责最小四节点路线；`M0RewardResolver` 负责确定性奖励选项及一次性应用。M0 复用现有 travel/battle/ending 管线，只有 Reward 选择、最小路线和 Boss 终点在 `m0_mode` 下启用。

**Tech Stack:** Godot 4.7 GDScript、GUT 集成测试、现有 `RunController` / `RunBattleFlow` / `BattleCommandFacade`。

## Global Constraints

- M0 内容上限：1 个玩家、6 种蛊虫、3 种普通敌人、1 个 Boss、真元、HP、三选一奖励、4 场战斗。
- 普通战斗默认必须真实击败，不能用撤退作为成功路径。
- 奖励选择必须一次性入账，未选择不得离开奖励屏。
- 完整运行流默认行为保持不变。
- M0 入口、奖励选择和存档恢复必须经现有表现层命令面与领域 `Resolver.apply` 路由。
- 不实现 M1 的永久成长、复杂地图、完整炼蛊、喂养、剧情树和美术扩展。

---

### Task 1: Add the red M0 acceptance test

**Files:**
- Create: `tests/integration/test_m0_core_loop.gd`

**Interfaces:**
- Consumes: `RunController.start_m0_run(seed)`, `RunController.submit_command`, current battle snapshots.
- Produces: a failing executable specification for M0’s four-fight and reward contract.

- [ ] **Step 1: Write the failing test**

Create tests that call the desired M0 API before it exists:

```gdscript
func test_m0_four_fights_rewards_build_and_boss_win() -> void:
    var controller: RunController = autofree(RUN_CONTROLLER.new())
    controller.start_m0_run(101)
    var battle_count := 0
    var selected_builds: Array[String] = []
    while controller.current_view_name() != "Ending" and battle_count < 4:
        _travel_to_next_m0_node(controller)
        assert_eq(controller.current_view_name(), "Battle")
        assert_true(_fight_without_retreat(controller))
        battle_count += 1
        if battle_count < 4:
            assert_eq(controller.current_view_name(), "Reward")
            var options := controller.m0_reward_options
            assert_eq(options.size(), 3)
            var chosen := str(options[0].get("id", ""))
            var before := _build_signature(controller)
            var picked := controller.submit_command({"type": "m0_reward_take", "reward_id": chosen})
            assert_true(bool(picked.get("ok", false)))
            assert_ne(_build_signature(controller), before)
            selected_builds.append(_build_signature(controller))
            var left := controller.submit_command({"type": "leave_encounter"})
            assert_true(bool((left.get("result", left) as Dictionary).get("ok", false)))
    assert_eq(battle_count, 4)
    assert_eq(controller.current_view_name(), "Ending")
    assert_true(_has_event(controller.state.event_log, "battle_finished", "battle_victory"))
    assert_true(_has_event(controller.state.event_log, "m0_boss_defeated", "m0_boss_defeated"))

func test_m0_death_can_restart_as_a_fresh_run() -> void:
    var controller: RunController = autofree(RUN_CONTROLLER.new())
    controller.start_m0_run(2026)
    controller.force_death_for_test("m0_restart_probe")
    assert_eq(controller.current_view_name(), "Ending")
    controller._show_title()
    controller.start_m0_run(2027)
    assert_eq(controller.current_view_name(), "Map")
    assert_eq(controller.state.terminal_state, "active")
    assert_eq(controller.state.node_flags.get("m0_battles_completed", 0), 0)
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
& .\\tools\\godot.ps1 --headless --path . -s addons/gut/gut_cmdln.gd -gtest res://tests/integration/test_m0_core_loop.gd -gexit -glog=2
```

Expected: fail because `RunController.start_m0_run` and M0 reward state do not exist, not because of a parse error in the test.

---

### Task 2: Add the M0 route and start entry point

**Files:**
- Create: `scripts/presentation/m0_run_flow.gd`
- Modify: `scripts/presentation/run_controller.gd`
- Test: `tests/integration/test_m0_core_loop.gd`

**Interfaces:**
- `M0RunFlow.build_route() -> Array[Dictionary]` returns exactly four linear combat nodes.
- `RunController.start_m0_run(seed_value: int) -> void` starts M0 with `m0_mode == true`.

- [ ] **Step 1: Implement the minimal route builder**

Use four nodes with ids `m0_fight_1`, `m0_fight_2`, `m0_elite`, `m0_boss`; enemy ids are `ridge_hound`, `iron_hide_boar`, `ridge_elite_scout`, `miasma_vein_lord`. The final node carries `layer_boss = 1` and no successor.

- [ ] **Step 2: Implement `start_m0_run`**

Load and validate the normal catalog, create a normal `RunState`, then replace its starter inventory with only three M0 starters (`small_light_gu`, `stone_shell_gu`, `moonlight_gu`). Set `m0_mode`, clear M0 counters/options, install the route, clear current node/battle, and show Map. Do not call the full `start_new_run` starter injection path.

- [ ] **Step 3: Run the focused test**

Run the same focused command. Expected: it advances farther but remains red at the missing reward option/selection behavior.

---

### Task 3: Implement deterministic three-choice rewards

**Files:**
- Create: `scripts/domain/m0_reward_resolver.gd`
- Modify: `scripts/presentation/run_controller.gd`
- Modify: `scripts/presentation/run_battle_flow.gd`
- Test: `tests/integration/test_m0_core_loop.gd`

**Interfaces:**
- `M0RewardResolver.build_options(state: RunState, battle_index: int, catalog: Dictionary) -> Array[Dictionary]` returns three unique option dictionaries.
- `M0RewardResolver.apply_choice(state: RunState, option: Dictionary, catalog: Dictionary) -> Dictionary` returns `{state, ok, reason}`.
- `RunController.m0_reward_options: Array[Dictionary]` stores the pending choices during Reward.

- [x] **Step 1: Implement option generation**

Generate three deterministic options from seed plus battle index: one Gu option drawn from the M0 six-Gu pool, one heal option, and one stone option. Never duplicate ids; include `id`, `kind`, `title`, `description`, and the application payload. No global RNG and no redraw on snapshot refresh.

- [x] **Step 2: Implement one-time application**

For a Gu option, add one valid instance through `GuInstance.transaction_ledger`, sync legacy projections, and append `m0_reward_chosen`. For heal and stone options, update the corresponding state fields through the same event path. Reject unknown options and duplicate choices without changing state.

- [x] **Step 3: Hook victory into M0 Reward**

After ordinary victory settlement, if `controller.m0_mode` is true and the node is not `m0_boss`, build exactly three options and show Reward. On `m0_boss` victory, append the M0 boss-defeated event and show Ending immediately.

- [x] **Step 4: Enforce the reward gate**

Intercept `m0_reward_take` in `RunController.submit_command`; reject `leave_encounter` while options remain. On accepted choice, mark the one-shot selection, keep the three cards disabled for UI feedback, and allow leaving; clear the options when returning to Map. Record an M0 battle counter after each victory.

- [x] **Step 5: Run the focused test**

Run the focused M0 command. Expected: domain test reaches the reward assertions; UI rendering is still the remaining red surface.

---

### Task 4: Connect Reward UI and restart surface

**Files:**
- Modify: `scripts/presentation/snapshots/reward_snapshot.gd`
- Modify: `scripts/presentation/run_command_builder.gd`
- Modify: `scripts/presentation/screens/reward_screen_view.gd`
- Modify: `scenes/ui/screens/reward_screen.tscn`（静态骨架保持不变，动态选项由视图创建）
- Modify: `scenes/ui/screens/hall_screen.tscn`
- Modify: `scripts/presentation/screens/hall_screen_view.gd`
- Modify: `scripts/presentation/run_save_flow.gd`
- Modify: `scripts/domain/resolver.gd`
- Modify: `tests/unit/test_t6e_polish.gd` only if its current auto-loot assertions need a M0-mode branch.

**Interfaces:**
- Reward snapshot adds `m0_mode`, `choice_rewards`, and `choice_selected` only for M0.
- Reward command surface adds `choose_reward` while preserving the existing `close` command outside M0.

- [x] **Step 1: Add choice data to the snapshot**

Expose pending options without mutating state. Keep existing `rewards` and build-progress output for the full run.

- [x] **Step 2: Render three selectable cards**

For M0, render three buttons/cards with title, kind, description, and disabled state after selection. Keep the existing Continue button disabled until a choice has been accepted; full-run Reward remains unchanged.

- [x] **Step 3: Add command wiring**

`run_command_builder.gd` must expose `choose_reward(id)` on M0 Reward; it submits `{type: "m0_reward_take", reward_id: id}`. Ending screen keeps the existing return-to-hall behavior, so a death can restart through the M0 entry point.

- [x] **Step 4: Run the focused M0 and existing Reward tests**

Run the M0 integration test and the relevant Reward/UI unit tests. Expected: green without changing full-run auto-loot behavior.

- [x] **Step 5: Verify entry, save/restore and interaction feedback**

大厅按钮可达 M0；M0 标记随既有 v4 存档恢复；动态奖励按钮使用公共按钮样式与 `ui_click` 音效接线。UI 交互门检查 `dead/no_ui_click/occluded`。

---

### Task 5: Verify the M0 gate and update the contract

**Files:**
- Modify: `docs/superpowers/specs/2026-09-17-m0-core-loop-contract.md`
- Test: `tests/integration/test_m0_core_loop.gd`

- [x] **Step 1: Add different-seed strategy evidence**

Run M0 with two seeds, choose a deterministic but different reward index, and assert the resulting Build signatures differ while both complete four fights.

- [x] **Step 2: Run fresh verification**

```powershell
& .\\tools\\godot.ps1 --headless --path . -s addons/gut/gut_cmdln.gd -gtest res://tests/integration/test_m0_core_loop.gd -gexit -glog=2
& .\\tools\\godot.ps1 --headless --path . -s addons/gut/gut_cmdln.gd -gdir res://tests/integration -gexit -glog=1
git diff --check
```

Expected: M0 test passes; integration suite passes; no diff whitespace errors. Existing orphan warnings are reported separately, not treated as M0 failures unless a new leak is introduced.

- [x] **Step 3: Mark the contract accurately**

The automated engineering gate is green. Human playtesting remains explicitly listed in the contract as an experience observation, not as an unverified success claim.

Change the M0 document from “暂不放行” to “通过” only if the test output proves all five conditions. Otherwise list the exact remaining blocker and keep the gate closed.
