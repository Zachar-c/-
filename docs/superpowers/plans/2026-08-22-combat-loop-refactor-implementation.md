# 南疆凡人 V2 战斗循环重构 Implementation Plan

> 日期：2026-08-22
> 状态：已归档
> 范围：连续节点与交锋循环重构实施计划；保留用于实现追踪。
> 基线：`branch=master @ 2e850dd`；该计划最终变更以此提交为准。
> 替代关系：相关实现已合入当前战斗与节点流程。


> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 固定种子 `101` 下交付连续节点会话、敌我交互、可胜可死可复盘的战斗闭环；炼蛊和连招留在节点现场而不自动跳图。

**Architecture:** `RunState` 是持久状态和不可变事件日志的唯一载体。`EncounterSessionResolver` 决定节点结束，`BattleResolver` 只管理战斗，`RunController` 只按会话和战斗结果路由。以 `docs/superpowers/specs/2026-08-22-combat-loop-refactor-design.md` 为当前循环优先规格；旧“四槽战斗”与“动作成功即完成节点”约束不适用。

**Tech Stack:** Godot `4.6.2` target (runtime `4.7.2`), GDScript, JSON, GUT, Windows keyboard/mouse, `gl_compatibility` renderer.

## Global Constraints

- 玩家界面仅中文；代码标识符、JSON 键、测试名、提交信息使用 ASCII。
- 保持 `Nanjiang Smoke (DEBUG)` 与 `renderer/rendering_method="gl_compatibility"`。
- 不修改 `vendor/godot-open-rpg/` 或受保护资料目录；不删除未知未提交工作。
- 所有已养且已炼化蛊虫均可催发；限制只能来自真元、目标、冷却、状态和局势。
- 关键改变经 `RunState.append_event(event)` 返回新状态；UI 不直接写状态。
- 后手必须有可读线索、确定窗口、确定条件和至少一种破解；不得随机不可避免致死。
- 玩家生命归零立即死亡；敌方死亡进入战后现场；不做濒死、复活或死亡惩罚。
- 本轮只做两个普通敌人、一个连续遭遇、炼蛊会话和最多三条连招快捷方式。

## Planned File Structure

```text
data/enemies.json
scripts/domain/result_feed.gd
scripts/domain/encounter_session_resolver.gd
scripts/domain/enemy_catalog.gd
scripts/domain/gu_effect_resolver.gd
scripts/domain/death_report_builder.gd
scripts/domain/refinement_session_resolver.gd
scripts/domain/combo_tracker.gd
scripts/domain/battle_resolver.gd
scripts/presentation/run_controller.gd
scripts/presentation/encounter_view.gd
scripts/presentation/battle_view.gd
tests/unit/test_result_feed.gd
tests/unit/test_encounter_session_resolver.gd
tests/unit/test_enemy_catalog.gd
tests/unit/test_gu_effect_resolver.gd
tests/unit/test_battle_loop.gd
tests/unit/test_death_report_builder.gd
tests/unit/test_refinement_session_resolver.gd
tests/unit/test_combo_tracker.gd
tests/integration/test_v2_combat_loop_flow.gd
```

### Task 1: 节点会话与结果记录

**Files:** Create `scripts/domain/result_feed.gd`, `scripts/domain/encounter_session_resolver.gd`, `tests/unit/test_result_feed.gd`, `tests/unit/test_encounter_session_resolver.gd`; modify `scripts/domain/run_state.gd`.

**Interfaces:** `ResultFeed.entry(action, text_key, changes, facts) -> Dictionary`; `EncounterSessionResolver.start(node) -> Dictionary`; `EncounterSessionResolver.apply(state, session, command, catalog) -> Dictionary`; add `health`, `max_health`, `encounter_session`, `encounter_results`, `saved_combos` to `RunState`.

- [ ] **Step 1: Write failing tests.** `deceive` must add two stones and return a feed while `session.completed == false`; `leave_node` must set `completed == true` and `completion_reason == "player_left"`.
- [ ] **Step 2: Verify red.** Run `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_encounter_session_resolver.gd -gexit -glog=2`; expected FAIL because session state is absent.
- [ ] **Step 3: Implement minimal session state.** `start(node)` returns `{ "node_id": node["id"], "kind": node["type"], "phase": "active", "completed": false, "completion_reason": "", "flags": {} }`. `contact_action` delegates to the existing local rule and returns a feed without completion. `leave_node` appends `node_left`, sets completion, and is the only ordinary completion route.
- [ ] **Step 4: Verify green.** Run the focused ResultFeed and session tests; expected PASS with old `RunState` unchanged.
- [ ] **Step 5: Commit.** `git add scripts/domain/result_feed.gd scripts/domain/encounter_session_resolver.gd scripts/domain/run_state.gd tests/unit/test_result_feed.gd tests/unit/test_encounter_session_resolver.gd`; commit message `feat: add persistent encounter sessions`.

### Task 2: 控制器按会话路由

**Files:** Modify `scripts/domain/resolver.gd`, `scripts/presentation/run_controller.gd`, `scripts/presentation/encounter_view.gd`; create `tests/integration/test_v2_combat_loop_flow.gd`.

**Interfaces:** `RunController` owns `current_session: Dictionary` and `session_results: Array[Dictionary]`. `Resolver.apply()` never completes nodes for `buy_gu`, `sell_gu`, `exchange_gu`, `refine_gu`, `cultivate_rank_two`, `choose_action`, or `resolve_contact`.

- [ ] **Step 1: Write failing test.** Start `ridge_caravan`, buy `caravan_thorn_offer`, assert `current_view_name() == "Encounter"` and `current_session["completed"] == false`.
- [ ] **Step 2: Verify red.** Run `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_v2_combat_loop_flow.gd -gexit -glog=2`; expected FAIL because controller returns to map.
- [ ] **Step 3: Implement.** Delete `_completes_current_node()` and resolver `_complete_result()` completion for ordinary commands. Route non-battle actions through `EncounterSessionResolver.apply`, accumulate feeds, and return to map only when `current_session["completed"]` is true. Add `EncounterView.render_session(session, state, feeds)`.
- [ ] **Step 4: Verify green.** Run the integration test and all unit tests; expected PASS with deceive, buying and refinement remaining on site.
- [ ] **Step 5: Commit.** `git add scripts/domain/resolver.gd scripts/presentation/run_controller.gd scripts/presentation/encounter_view.gd tests/integration/test_v2_combat_loop_flow.gd`; commit `fix: route by explicit encounter session`.

### Task 3: 敌人数据与可见意图

**Files:** Create `data/enemies.json`, `scripts/domain/enemy_catalog.gd`, `tests/unit/test_enemy_catalog.gd`, `tests/unit/test_battle_loop.gd`; modify `scripts/domain/content_catalog.gd`, `scripts/domain/battle_resolver.gd`.

**Interfaces:** `EnemyCatalog.load_all() -> Dictionary` includes `enemy_by_id`; `validate(catalog) -> Array[String]` rejects reactions lacking `clue`, `window`, `trigger`, `counter_status`; `BattleResolver.start(encounter, state, catalog)` returns `player`, `enemy`, `visible_intent`, `clues`, `log`, `phase`, `result`.

- [ ] **Step 1: Write failing tests.** Catalog contains `neutral_stone_wanderer` and `ridge_hound`; removing a reaction `counter_status` produces exactly one validation error; started battle exposes health, intent and clues.
- [ ] **Step 2: Verify red.** Run `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_enemy_catalog.gd -gexit -glog=2`; expected FAIL because enemies are simple HP targets.
- [ ] **Step 3: Implement.** Stone wanderer has visible `stone_dust`, `steady_stance`, `stone_palm`, one `before_damage` stone-shell guard broken by `bound`. Ridge hound has `lowered_shoulders`, `pounce`, one counter-bite for unguarded direct strike. Both are `common`, one main routine, one reaction. Battle snapshots must copy `state.health`, `state.essence`, all `refined_gu_ids`, and visible enemy data.
- [ ] **Step 4: Verify green.** Run enemy catalog and battle-loop tests; expected PASS.
- [ ] **Step 5: Commit.** `git add data/enemies.json scripts/domain/enemy_catalog.gd scripts/domain/content_catalog.gd scripts/domain/battle_resolver.gd tests/unit/test_enemy_catalog.gd tests/unit/test_battle_loop.gd`; commit `feat: add readable enemy intent data`.

### Task 4: 蛊虫效果、反制、敌方回合与死亡

**Files:** Create `scripts/domain/gu_effect_resolver.gd`, `tests/unit/test_gu_effect_resolver.gd`; modify `data/gu.json`, `scripts/domain/battle_resolver.gd`, `scripts/domain/run_state.gd`, `tests/unit/test_battle_loop.gd`.

**Interfaces:** `GuEffectResolver.apply(battle, gu, mode) -> Dictionary` returns `ok`, `battle`, `events`, `window`; `BattleResolver.take_turn(battle, command, state, catalog)` accepts `use_gu`, `end_turn`, `retreat` and returns `battle`, `state`, `feeds`, `finished`, `result`.

- [ ] **Step 1: Write failing tests.** Direct `thorn_whip_gu` strike triggers stone shell; bind then strike prevents the guard and kills a wounded enemy; ending turn against lethal hound returns `death`.
- [ ] **Step 2: Verify red.** Run `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_battle_loop.gd -gexit -glog=2`; expected FAIL because no reaction or enemy phase exists.
- [ ] **Step 3: Implement.** Define `small_light_gu` reveal; `thorn_whip_gu` modes `bind`/`strike`; `stone_shell_gu` protection; `mist_step_gu` retreat setup. Validate ownership, essence, target, cooldown and mode. Resolve `before_damage` reactions. `use_gu` retains player phase unless finished; `end_turn` executes intent, appends health/essence event, rotates intent; failed retreat executes enemy pressure.
- [ ] **Step 4: Verify green.** Run Gu effect and battle loop tests; expected PASS showing order-dependent result and logged lethal final blow.
- [ ] **Step 5: Commit.** `git add data/gu.json scripts/domain/gu_effect_resolver.gd scripts/domain/battle_resolver.gd scripts/domain/run_state.gd tests/unit/test_gu_effect_resolver.gd tests/unit/test_battle_loop.gd`; commit `feat: add enemy turns and reaction windows`.

### Task 5: 死因复盘和敌语

**Files:** Create `scripts/domain/death_report_builder.gd`, `tests/unit/test_death_report_builder.gd`; modify `data/enemies.json`, `scripts/presentation/run_controller.gd`, `scripts/presentation/ending_view.gd`.

**Interfaces:** `DeathReportBuilder.build(battle, state, enemy) -> Dictionary` returns `final_blow`, `known_facts`, `taunt`. Death view only permits restart and never returns to map.

- [ ] **Step 1: Write failing tests.** Report source is `stone_palm`; it includes visible `stone_dust`; text excludes hidden data. Exhausted state selects: `见光便扑？这点真元，也敢替我试蛊。下辈子先照照脚下的石粉。`.
- [ ] **Step 2: Verify red.** Run `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_death_report_builder.gd -gexit -glog=2`; expected FAIL because no report exists.
- [ ] **Step 3: Implement.** Add six to eight enemy taunts per initial enemy, keyed by visible final blow, exhausted essence, revealed reaction, ignored clue or failed retreat. Builder reads only log, clues, revealed reactions, visible player resources and final blow; selects first matching entry then neutral fallback.
- [ ] **Step 4: Verify green.** Run death builder and flow integration tests; expected PASS with explainable final blow and taunt.
- [ ] **Step 5: Commit.** `git add data/enemies.json scripts/domain/death_report_builder.gd scripts/presentation/run_controller.gd scripts/presentation/ending_view.gd tests/unit/test_death_report_builder.gd tests/integration/test_v2_combat_loop_flow.gd`; commit `feat: add explainable death reports`.

### Task 6: 玩家战斗界面与战后现场

**Files:** Modify `scripts/presentation/battle_view.gd`, `scripts/presentation/encounter_view.gd`, `scripts/presentation/display_text.gd`, `scripts/presentation/run_controller.gd`, `tests/integration/test_v2_combat_loop_flow.gd`.

**Interfaces:** `BattleView.render_battle(battle, feeds)` displays both sides' health/essence, intent, clues, log, usable Gu, `收势`, legal retreat. `victory`/`retreated` changes session to `post_battle`, never completion.

- [ ] **Step 1: Write failing test.** A prepared wanderer victory must yield `current_view_name() == "Encounter"`, `current_session["phase"] == "post_battle"`, and `completed == false`.
- [ ] **Step 2: Verify red.** Run the integration test; expected FAIL because finished battles jump to map.
- [ ] **Step 3: Implement.** Use stable controls for resource bars, intent/clue rows, scrolling log, all-Gu action grid, `收势`, and legal retreat. Post-battle encounter renders outcome feeds plus `离开此地`; no raw internal keys reach player text.
- [ ] **Step 4: Verify green.** Run flow integration, then `godot --headless --path . --quit-after 3`; expected PASS without controller blockage.
- [ ] **Step 5: Commit.** `git add scripts/presentation/battle_view.gd scripts/presentation/encounter_view.gd scripts/presentation/display_text.gd scripts/presentation/run_controller.gd tests/integration/test_v2_combat_loop_flow.gd`; commit `feat: present combat loop feedback`.

### Task 7: 连续炼蛊和连招快捷方式

**Files:** Create `scripts/domain/refinement_session_resolver.gd`, `scripts/domain/combo_tracker.gd`, `tests/unit/test_refinement_session_resolver.gd`, `tests/unit/test_combo_tracker.gd`; modify `scripts/domain/encounter_session_resolver.gd`, `scripts/domain/battle_resolver.gd`, `scripts/domain/run_state.gd`, `scripts/presentation/encounter_view.gd`, `scripts/presentation/battle_view.gd`.

**Interfaces:** `RefinementSessionResolver.apply(state, session, command, catalog)` accepts `browse_recipes`, `refine_gu`, `leave_node`; `ComboTracker.record(sequence, command, outcome) -> Array[String]`; `ComboTracker.save(saved, sequence)` keeps at most three entries.

- [ ] **Step 1: Write failing tests.** `bright_thread_risk` at `roll: 99` destroys input Gu but leaves the refinement session open; a saved `small_light_gu -> thorn_whip_gu` sequence with insufficient essence executes only the first Gu and returns `insufficient_essence`.
- [ ] **Step 2: Verify red.** Run refinement and combo test files; expected FAIL because refinement auto-completes and shortcut does not exist.
- [ ] **Step 3: Implement.** Refinement displays inputs, success rate, destruction risk, executes declared recipe, logs feed, and stays in phase `refinement` until leaving. Record successful `use_gu`; after victory offer only `保留为常用顺序` or `不保留`. Saved entry is `{ "gu_ids": Array[String], "conditions_changed": bool }`; shortcut reuses normal `take_turn`, stops at first invalid result/interruption, and grants no numerical bonus.
- [ ] **Step 4: Verify green.** Run focused refinement and combo tests; expected PASS with declared destruction and visible stop reason.
- [ ] **Step 5: Commit.** `git add scripts/domain/refinement_session_resolver.gd scripts/domain/combo_tracker.gd scripts/domain/encounter_session_resolver.gd scripts/domain/battle_resolver.gd scripts/domain/run_state.gd scripts/presentation/encounter_view.gd scripts/presentation/battle_view.gd tests/unit/test_refinement_session_resolver.gd tests/unit/test_combo_tracker.gd`; commit `feat: add continuous refinement and combo shortcuts`.

### Task 8: 全量验证与手工验收

**Files:** Modify `docs/superpowers/specs/2026-08-22-combat-loop-refactor-design.md`, `README.md`.

**Interfaces:** README records runtime, seed `101`, launch/test commands, covered routes and intentionally absent systems.

- [ ] **Step 1: Run full suite.** `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit -glog=2`; expected PASS.
- [ ] **Step 2: Run boot and whitespace checks.** `godot --headless --path . --quit-after 3` and `git diff --check`; expected clean exit and no whitespace errors.
- [ ] **Step 3: Manually inspect seed 101.** Deceive and remain in encounter; direct strike triggers stone guard; reveal/bind before strike changes outcome; enemy intent can kill and produces factual taunt; victory stays post-battle; refinement failure stays open; saved combo stops with Chinese reason.
- [ ] **Step 4: Update only after real verification.** Set design status to `已实现并完成固定种子验收` only after Steps 1--3 pass. README states runtime, launcher, test command, seed, and absent later stages/factions/boss/ascension.
- [ ] **Step 5: Commit.** `git add docs/superpowers/specs/2026-08-22-combat-loop-refactor-design.md README.md`; commit `docs: verify combat loop refactor`.

## Plan Self-Review

- **Spec coverage:** Tasks 1--2 stop automatic exits; 3--4 add readable enemies, multi-Gu player actions, reaction windows, enemy turns, retreat and lethal death; 5 creates factual death reports; 6 exposes actionable feedback; 7 adds continuous refinement and low-friction combo reuse; 8 requires automated and in-window acceptance.
- **Scope control:** No map expansion, large event pool, factions, endgame, fixed slots, automatic killer moves, meta progression or visual replacement.
- **Type consistency:** Node commands use `EncounterSessionResolver.apply`; combat uses `BattleResolver.take_turn`; only session completion returns to map; death uses `DeathReportBuilder.build`.
- **Compatibility:** This plan supersedes only old four-slot and auto-completion language; repository protections stay intact.
- **Placeholder scan:** Each task states test, expected red failure, implementation boundary, green command, and commit scope.
