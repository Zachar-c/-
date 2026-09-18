# 随机合成杀招最小闭环 Implementation Plan

> 审阅：✅ 2026-09-06 用户审订通过（定稿）。注：802 目录重建后 slice 配方链已删除，本文档保留为决策记录。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 通过真实随机路线和公开命令完成蛊虫获取、固定配方炼制、V1 战斗、组合杀招执行和 Ending，并让 slice 的获取与效果数据合同在加载阶段可验证。

**Architecture:** `RunController.submit_command()` 是唯一集成入口。新增一条独立固定配方，产出沿用 `GuInstance.transaction_ledger()` 写入 RunState；V1 从 `data/v1_battle.json` 组装杀招。只严格验证 slice 引用闭包的 `v1_effect`；未涉及的旧 Gu 保持现有 role fallback，避免全量迁移 214 个定义。

**Tech Stack:** Godot 4、GDScript、GUT、JSON catalog、`tools/test.ps1`、`tools/check.ps1`。

## Global Constraints

- 复用现有 `ActionPreviewService`、`Resolver`、`BattleCommandFacade` 和 `RunController.submit_command()`。
- 固定配方使用 `input_gu_ids -> output_gu_id`；`data/synthesis.json` 的 `material_cost -> temp_card_id` 不属于本 slice。
- 杀招使用 `v1_battle.kill_moves[].id` 和 `recipe`，不从显示名称、`combat` 或 `cards.json.kill_move_sequence` 推断。
- slice 成功炼制输出必须写入完整 Gu 实例账本：`gu_instances`、`cave_aperture.stored_gu_instance_ids`、`gu_ids`、`refined_gu_ids` 同步。
- slice 配方未知输出、未知效果、非法配方或非法杀招属于数据合同错误，必须在材料、元石或输入实例扣除前拒绝，不能通过重滚处理。
- slice 使用的 Gu 必须显式声明受支持的 V1 效果：`strike`、`shield`、`buff`、`heal`、`heal_and_strike`、`status` 或 `shift`。
- 不恢复旧 `deck` / `hand` / `discard` 领域模型。
- 不改变培养门槛、资源校验、战斗规则或 `insufficient_qi_quality`。
- 不覆盖工作树已有 L5/Ending、Battle UI 和相关测试修改；与现有修改合并。
- 集成测试只通过 `RunController.submit_command()` 推进，不直接调用 `Resolver.apply()`、`BattleCommandFacade.start()` 或内部状态写入推进流程。
- 随机重滚只允许更换全新 seed、`RunController` 和 `start_new_run()`；固定最大尝试次数，禁止无限循环。
- 获取范围只覆盖 slice 的起始蛊与炼制产物。商店、barter、全局 loot、caravan、`lifespan_deal` 不在本计划修改范围；它们只继续受 catalog 基础引用校验保护。

---

## 文件结构

- Modify: `data/gu.json` — 为 `pulse_drum_gu` 声明显式 V1 效果。
- Modify: `data/refinement_recipes.json` — 在根对象 `recipes` 数组增加独立固定 slice 配方。
- Modify: `data/v1_battle.json` — 增加一个可执行 V1 kill move。
- Modify: `scripts/domain/content_catalog.gd` — 校验 slice 配方、V1 effect、kill move 和跨文件引用。
- Modify: `scripts/domain/gu_instance.gd` — 在共享炼制账本创建 slice 输出前验证 definition。
- Modify: `scripts/domain/resolver.gd` — 在 `_add_gu_transaction()` 资源扣除前处理账本输出错误。
- Modify: `scripts/domain/v1_battle_resolver.gd` — 拒绝未知 effect；在杀招支付前验证已加载 effect。
- Modify: `scripts/domain/action_preview_service.gd` — V1 `gu_slots` 卡使用声明效果推导目标和摘要。
- Modify: `scripts/presentation/run_snapshot_builder.gd` — V1 杀招快照透出效果、目标和阻断原因。
- Modify: `tests/unit/test_content_catalog.gd` — slice 数据合同负例和 shipped 配置覆盖。
- Modify: `tests/unit/test_battle_synthesis.gd` — slice 输出账本和资源扣除前拒绝。
- Modify: `tests/unit/test_v1_battle_resolver.gd` — unknown effect 和 kill move effect 执行合同。
- Modify: `tests/unit/test_action_preview_service.gd` — V1 声明效果与目标预览。
- Modify: `tests/integration/test_drive_to_ending.gd` — 公开命令闭环、有限 seed 重滚证据。

---

### Task 1: Lock slice contracts with failing tests

**Files:**
- Modify: `tests/unit/test_content_catalog.gd`
- Modify: `tests/unit/test_battle_synthesis.gd`

**Interfaces:**
- Consumes: `ContentCatalog.load_all()`, `ContentCatalog.validate(catalog)`, `GuInstance.transaction_ledger()`.
- Produces: Tests for fixed mapping, malformed catalog data, and no-mutation output rejection.

- [ ] **Step 1: Add shipped mapping test**

```gdscript
func test_shipped_synthesis_kill_move_contract_is_explicit() -> void:
	var catalog := ContentCatalog.load_all()
	var recipe: Dictionary = catalog["refinement_by_id"]["slice_bright_thread"]
	var kill_move_id := str(recipe.get("kill_move_id", ""))
	assert_false(kill_move_id.is_empty())
	var kill_move: Dictionary ={}
	for value in catalog["v1_battle"].get("kill_moves", []):
		if str((value as Dictionary).get("id", "")) == kill_move_id:
			kill_move = value
			break
	assert_false(kill_move.is_empty())
	assert_true((kill_move.get("recipe", []) as Array).has(str(recipe["output_gu_id"])))
	var output: Dictionary = catalog["gu_by_id"][str(recipe["output_gu_id"])]
	var effect: Dictionary = output["v1_effect"]
	assert_true(effect.has("kind"))
```

- [ ] **Step 2: Add catalog negative tests**

```gdscript
func test_validation_rejects_unknown_slice_recipe_input() -> void:
	var catalog := ContentCatalog.load_all()
	(catalog["refinement_by_id"]["slice_bright_thread"] as Dictionary)["input_gu_ids"] = ["missing_input_gu"]
	assert_true(_has_hint(ContentCatalog.validate(catalog), "unknown gu"))

func test_validation_rejects_unknown_slice_kill_move_effect() -> void:
	var catalog := ContentCatalog.load_all()
	(catalog["v1_battle"]["kill_moves"] as Array).append({
		"id": "bad_effect_kill_move",
		"recipe": ["pulse_drum_gu"],
		"effect": {"kind": "unknown_effect"},
	})
	assert_true(_has_hint(ContentCatalog.validate(catalog), "effect"))

func test_validation_rejects_invalid_slice_v1_effect() -> void:
	var catalog := ContentCatalog.load_all()
	(catalog["gu_by_id"]["pulse_drum_gu"] as Dictionary)["v1_effect"] = {"kind": "status", "name": "bound", "amount": -1}
	assert_true(_has_hint(ContentCatalog.validate(catalog), "v1_effect"))
```

- [ ] **Step 3: Add pure ledger rejection test**

`tests/unit/test_battle_synthesis.gd` owns `func catalog() -> Dictionary`; call it explicitly:

```gdscript
func test_unknown_transaction_output_is_rejected_before_ledger_mutation() -> void:
	var state := RunState.new_run(101)
	var cat := catalog()
	var before_instances := state.gu_instances.duplicate(true)
	var before_aperture := state.cave_aperture.duplicate(true)
	var result := GuInstance.transaction_ledger(
		state.gu_instances, state.cave_aperture, "missing_output_gu", cat, ["small_light_gu"])
	assert_true(result.has("error"))
	assert_eq(str(result["error"]), "unknown_gu_definition")
	assert_eq(state.gu_instances, before_instances)
	assert_eq(state.cave_aperture, before_aperture)
```

This validates pure helper inputs. Task 4 adds Resolver-level state and event-log no-mutation assertions.

- [ ] **Step 4: Run tests red**

```text
powershell.exe -File tools/test.ps1 -Test tests/unit/test_content_catalog.gd
powershell.exe -File tools/test.ps1 -Test tests/unit/test_battle_synthesis.gd
```

Expected: FAIL because slice data, validation, and ledger guard do not exist.

- [ ] **Step 5: Commit**

```text
git add tests/unit/test_content_catalog.gd tests/unit/test_battle_synthesis.gd
git commit -m "test(slice): lock synthesis contracts"
```

---

### Task 2: Add deterministic slice data chain

**Files:**
- Modify: `data/gu.json`
- Modify: `data/refinement_recipes.json`
- Modify: `data/v1_battle.json`

**Interfaces:**
- Consumes: Fresh no-school starters `small_light_gu` and `trail_eye_gu`.
- Produces: `small_light_gu + trail_eye_gu -> pulse_drum_gu -> km_bright_thread`.

- [ ] **Step 1: Add recipe inside `recipes` array**

Insert this object at end of root `recipes` array in `data/refinement_recipes.json`; preserve root object and `caravan_offers`:

```json
{
  "id": "slice_bright_thread",
  "kind": "fixed",
  "default_unlocked": true,
  "input_gu_ids": ["small_light_gu", "trail_eye_gu"],
  "output_gu_id": "pulse_drum_gu",
  "kill_move_id": "km_bright_thread"
}
```

Do not modify legacy `bright_thread_risk`; its random-failure tests remain valid.

- [ ] **Step 2: Add explicit output effect**

Add to `pulse_drum_gu` in `data/gu.json`:

```json
"v1_effect": {
  "kind": "status",
  "name": "bound",
  "amount": 1
}
```

- [ ] **Step 3: Add kill move with single damage source**

Add root `kill_moves` array in `data/v1_battle.json`:

```json
"kill_moves": [
  {
    "id": "km_bright_thread",
    "label": "明丝合击",
    "tag": "control",
    "recipe": ["pulse_drum_gu"],
    "true_qi_cost": 2,
    "thought_cost": 1,
    "life_cost": 0,
    "damage": 3,
    "effect":{}
  }
]
```

`damage` is sole damage source. Empty effect is permitted for this move; `play_kill_move()` must skip effect validation when effect is empty. Do not use `strike` plus `damage` together.

- [ ] **Step 4: Run parse/catalog test and commit**

```text
powershell.exe -File tools/test.ps1 -Test tests/unit/test_content_catalog.gd
git add data/gu.json data/refinement_recipes.json data/v1_battle.json
git commit -m "feat(slice): define reachable synthesis kill move chain"
```

Expected: JSON parses. Validator assertions may remain red until Task 3.

---

### Task 3: Validate slice catalog contract

**Files:**
- Modify: `scripts/domain/content_catalog.gd`
- Test: `tests/unit/test_content_catalog.gd`

**Interfaces:**
- Consumes: `catalog["gu_by_id"]`, `catalog["refinement_recipes"]`, `catalog["v1_battle"]`.
- Produces: `ContentCatalog.validate(catalog) -> Array[String]` errors for invalid slice mappings and effect shapes.

- [ ] **Step 1: Define V1 schema helpers**

```gdscript
const V1_EFFECT_KIND_IDS := ["strike", "shield", "buff", "heal", "heal_and_strike", "status", "shift"]
const V1_STATUS_IDS := ["marked", "bound"]

static func _validate_v1_effect(effect: Variant, owner: String) -> Array[String]:
static func _validate_slice_contract(catalog: Dictionary) -> Array[String]:
static func _validate_v1_kill_moves(catalog: Dictionary) -> Array[String]:
```

Reuse `_is_integral()` and existing error style. Do not add a global Gu-ID format migration in this slice.

- [ ] **Step 2: Validate effect shape**

Reject unknown kind, non-dictionary effect, missing required fields, wrong types, negative numeric values, blank buff names, and unknown status names. Required shape:

```text
strike/shield/heal/shift: amount
buff/status: name + amount
heal_and_strike: heal + amount
```

- [ ] **Step 3: Compute and validate slice closure**

Find recipe ID `slice_bright_thread`; its closure is its `input_gu_ids`, `output_gu_id`, matching `kill_move_id`, and matching kill move `recipe`. Require every referenced Gu to exist and declare valid explicit `v1_effect`. Require recipe mapping and kill move recipe to match output Gu.

Other recipes and legacy Gu remain valid without explicit effects.

- [ ] **Step 4: Validate V1 kill moves**

When `kill_moves` exists, require unique nonblank IDs, nonempty unique existing Gu recipe entries, nonnegative integral costs/damage, and a valid effect only when effect dictionary is nonempty. `effect: {}` is valid for damage-only move.

- [ ] **Step 5: Run tests and commit**

```text
powershell.exe -File tools/test.ps1 -Test tests/unit/test_content_catalog.gd
git add scripts/domain/content_catalog.gd tests/unit/test_content_catalog.gd
git commit -m "feat(slice): validate V1 synthesis data contract"
```

Expected: PASS.

---

### Task 4: Harden slice refinement ledger

**Files:**
- Modify: `scripts/domain/gu_instance.gd`
- Modify: `scripts/domain/resolver.gd`
- Test: `tests/unit/test_battle_synthesis.gd`

**Interfaces:**
- Consumes: `GuInstance.transaction_ledger()`, Resolver `_add_gu_transaction()`.
- Produces: Unknown refinement output rejection before input consumption, stone mutation, event append, or instance creation.

- [ ] **Step 1: Add shared output guard**

```gdscript
static func output_definition_error(output_gu_id: String, catalog: Dictionary) -> String:
	if output_gu_id.strip_edges().is_empty():
		return "unknown_gu_definition"
	var gu_by_id: Variant = catalog.get("gu_by_id", {})
	if not gu_by_id is Dictionary or not (gu_by_id as Dictionary).has(output_gu_id):
		return "unknown_gu_definition"
	return ""
```

`transaction_ledger()` calls it before `consume_definition_instances()` and returns `{"error": "unknown_gu_definition"}` on failure. Successful return adds `"error": ""` beside existing `instances` and `aperture`.

- [ ] **Step 2: Reject in Resolver before side effects**

In `_add_gu_transaction()`, branch on `ledger["error"]` before `_without_gu()`, `append_event()`, stone deduction, or projection sync:

```gdscript
if not str(ledger.get("error", "")).is_empty():
	return _rejected(state, str(ledger["error"]))
```

- [ ] **Step 3: Add Resolver-level no-mutation test**

Invoke the existing refinement command route with a copied catalog whose `slice_bright_thread.output_gu_id` is `missing_output_gu`. Assert rejection `unknown_gu_definition`, unchanged materials, stone, `event_log`, `gu_instances`, aperture, and legacy projections.

- [ ] **Step 4: Add success ledger assertions**

For successful `slice_bright_thread`, assert output instance exists, `state == "refined"`, rank is 1..5, aperture contains instance ID, and legacy `gu_ids`/`refined_gu_ids` contain `pulse_drum_gu`.

- [ ] **Step 5: Run tests and commit**

```text
powershell.exe -File tools/test.ps1 -Test tests/unit/test_battle_synthesis.gd
git add scripts/domain/gu_instance.gd scripts/domain/resolver.gd tests/unit/test_battle_synthesis.gd
git commit -m "fix(slice): reject unknown refinement output before spend"
```

Expected: PASS.

---

### Task 5: Make V1 execution and snapshots declaration-driven

**Files:**
- Modify: `scripts/domain/v1_battle_resolver.gd`
- Modify: `scripts/domain/action_preview_service.gd`
- Modify: `scripts/presentation/run_snapshot_builder.gd`
- Test: `tests/unit/test_v1_battle_resolver.gd`
- Test: `tests/unit/test_action_preview_service.gd`

**Interfaces:**
- Consumes: V1 slot `effect`, V1 kill move `effect`, `preview_battle_actions()`, run snapshot V1 battle builder.
- Produces: Unknown effects reject before costs; V1 cards and kill moves expose effect/target/block fields aligned with execution.

- [ ] **Step 1: Add resolver effect reason**

```gdscript
static func effect_reason(effect: Variant) -> String:
	if not effect is Dictionary:
		return "unknown_effect"
	var data: Dictionary = effect
	if data.is_empty():
		return ""
	var kind := str(data.get("kind", ""))
	if not ["strike", "shield", "buff", "heal", "heal_and_strike", "status", "shift"].has(kind):
		return "unknown_effect"
	return ""
```

Extend field checks to match Task 3. Empty effect is allowed only for damage-only kill moves, never a Gu slot.

- [ ] **Step 2: Reject before payment**

`play_gu()` calls `effect_reason(slot.get("effect",{}))` before `_spend_costs()`. `play_kill_move()` calls `effect_reason(km.get("effect",{}))` after locating `km` but before any resource check or deduction. `kill_move_reason()` uses same call. Never re-read catalog or `cards.json` during execution.

- [ ] **Step 3: Keep compatibility bounded**

Explicit `v1_effect` wins. Retain role fallback only for non-slice legacy Gu required by existing tests; mark it compatibility behavior. Slice closure without explicit effect must not be reported playable.

- [ ] **Step 4: Update V1 Gu preview**

For V1 `gu_slots`, derive summary and structured fields directly from slot `effect`:

```text
strike/status/heal_and_strike: target_type = single_enemy
shield/buff/heal/shift: target_type = self
valid_target_ids: all living enemy IDs for single_enemy, [] for self
block_reason: effect_reason(slot.effect) before normal resource reason
```

Keep legacy hand-card preview branch unchanged.

- [ ] **Step 5: Update V1 kill move snapshot**

In `run_snapshot_builder.gd` V1 kill move builder, add fields:

```text
"effect": kill_move.effect
"target_type": "single_enemy" when effect kind is strike/status/heal_and_strike or damage > 0
"valid_target_ids": current living enemy IDs for single_enemy
"block_reason": V1BattleResolver.kill_move_reason(...)
```

A damage-only kill move reports `single_enemy` because V1 resolves damage against current enemy. No separate display source exists.

- [ ] **Step 6: Add tests**

```gdscript
func test_unknown_gu_effect_is_rejected_without_spending_cost() -> void:
	var run := _run_with_gu([{ "definition_id": "small_light_gu", "rank": 1 }])
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 0)])
	battle["gu_slots"][0]["effect"] = {"kind": "unknown_effect"}
	var before_qi := int(battle["player"]["true_qi"])
	var out := V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_false(out["result"]["ok"])
	assert_eq(str(out["result"]["reason"]), "unknown_effect")
	assert_eq(int(out["battle"]["player"]["true_qi"]), before_qi)
```

Use existing `_run_with_gu()` helper only after confirming it creates entries in `gu_instances` and `stored_gu_instance_ids`; otherwise add instances through `GuInstance.new_instance()` and call `sync_legacy_gu_projections()` in helper. Add preview assertions for `pulse_drum_gu`: `status`, `bound`, `single_enemy`, and living enemy IDs.

- [ ] **Step 7: Run tests and commit**

```text
powershell.exe -File tools/test.ps1 -Test tests/unit/test_v1_battle_resolver.gd
powershell.exe -File tools/test.ps1 -Test tests/unit/test_action_preview_service.gd
git add scripts/domain/v1_battle_resolver.gd scripts/domain/action_preview_service.gd scripts/presentation/run_snapshot_builder.gd tests/unit/test_v1_battle_resolver.gd tests/unit/test_action_preview_service.gd
git commit -m "feat(slice): execute and preview explicit V1 effects"
```

Expected: PASS.

---

### Task 6: Add public-command integration acceptance

**Files:**
- Modify: `tests/integration/test_drive_to_ending.gd`

**Interfaces:**
- Consumes: `RunController.start_new_run(seed)`, map snapshot `next_ids`, emitted refinement/battle commands, `RunController.submit_command()`, `current_view_name()`.
- Produces: Trace proving input acquisition, refinement, output instance, battle entry, Gu use, kill move, and ending/legal terminal result.

- [ ] **Step 1: Add bounded trace**

Use `MAX_SYNTHESIS_SLICE_ATTEMPTS := 8`. Each attempt creates a fresh controller and calls `start_new_run(seed)` once. Record:

```gdscript
{
	"seed": seed_value,
	"input_gu_ids": [],
	"recipe_id": "slice_bright_thread",
	"output_gu_id": "pulse_drum_gu",
	"output_instance_id": "",
	"kill_move_id": "km_bright_thread",
	"kill_move_accepted": false,
	"entered_battle": false,
	"ending_view": false,
	"failure_class": "",
}
```

- [ ] **Step 2: Obtain inputs from public run state**

Confirm opening state actually contains instances for `small_light_gu` and `trail_eye_gu`; no-school starter injection already supplies both. Follow only current `next_ids`; do not sell or consume inputs. Search reachable refinement nodes from snapshots. If seed has no reachable refinement node, classify `route_unavailable` and rebuild controller with next seed. Do not claim `refinement_hollow` exists on every generated map.

- [ ] **Step 3: Refine using emitted command**

Find executable preview card whose command contains `type == "refine_gu"` and `recipe_id == "slice_bright_thread"`; submit exact card command through controller. Read output instance ID from actual `gu_instances`. Assert ledger and legacy projections.

- [ ] **Step 4: Enter battle and use output**

Continue via reachable travel and emitted public fight command to an ordinary battle. Locate output Gu card in controller snapshot, assert `status/bound`, `single_enemy`, and valid target IDs. Submit emitted Gu command. Before attempting kill move assert battle remains active; status effect must not end battle.

- [ ] **Step 5: Execute damage-only kill move**

Refresh snapshot, locate `km_bright_thread`, submit emitted `play_kill_move` command. Select battle enemy with health greater than 3 if multiple route options exist; otherwise submit command and record actual result. Accepted victory after command is valid. Rejected command records actual reason and becomes `battle_command_failure` unless legal battle terminal occurred first.

- [ ] **Step 6: Finish real run**

For successful kill move attempt, reuse existing public driver toward final Boss and ascension. Assert `controller.current_view_name() == "Ending"` or record controller-reported legal terminal. Never set terminal state directly.

- [ ] **Step 7: Classify and reroll**

Use only `route_unavailable`, `acquisition_unavailable`, `preview_contract_failure`, `synthesis_execution_failure`, `battle_command_failure`, `ending_observation_failure`, `catalog_contract_failure`. Catalog error fails immediately. Only route/resource classes reroll. Maximum attempts fails with all trace summaries.

- [ ] **Step 8: Run integration test and commit**

```text
powershell.exe -File tools/test.ps1 -Test tests/integration/test_drive_to_ending.gd
git add tests/integration/test_drive_to_ending.gd
git commit -m "test(slice): drive public synthesis kill move flow"
```

Expected: PASS with one trace containing seed, input IDs, recipe, output instance, kill move, accepted command, and Ending observation or legal terminal.

---

### Task 7: Full verification

**Files:**
- No source changes unless a test exposes defect from Tasks 1-6.

- [ ] **Step 1: Run focused tests**

```text
powershell.exe -File tools/test.ps1 -Test tests/unit/test_content_catalog.gd
powershell.exe -File tools/test.ps1 -Test tests/unit/test_battle_synthesis.gd
powershell.exe -File tools/test.ps1 -Test tests/unit/test_v1_battle_resolver.gd
powershell.exe -File tools/test.ps1 -Test tests/unit/test_action_preview_service.gd
powershell.exe -File tools/test.ps1 -Test tests/integration/test_drive_to_ending.gd
```

- [ ] **Step 2: Run complete suites and check**

```text
powershell.exe -File tools/test.ps1 -Suite unit
powershell.exe -File tools/test.ps1 -Suite integration
powershell.exe -File tools/check.ps1
```

- [ ] **Step 3: Review scope and report**

```text
git diff --stat master...
git status --short
```

Report exact results, successful trace evidence, reroll classifications, and known ceiling: legacy Gu outside slice may retain role fallback until separately migrated.

---

## Self-Review

- **Spec coverage:** Tasks 1-3 lock input/output/kill-move/effect data contracts. Task 4 protects true refinement output ownership. Task 5 aligns V1 execution, preview, and snapshot. Task 6 proves public-command integration and Ending. Task 7 runs required verification.
- **Placeholder scan:** No `TBD`, `TODO`, or unspecified implementation step remains.
- **Type consistency:** `ContentCatalog.validate()` returns `Array[String]`; `GuInstance.output_definition_error()` returns `String`; `transaction_ledger()` returns dictionary with `error`; `V1BattleResolver.effect_reason()` returns `String`; integration reads actual instance IDs.
- **Scope check:** No new service or domain model. Existing ledger, preview, resolver, facade, controller, and test boundaries remain.
