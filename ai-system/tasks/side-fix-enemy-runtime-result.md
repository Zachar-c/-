# Caveman Review Packet

```text
TASK side-fix-enemy-runtime
PHASE P3-side (P3-B unopened, awaiting L1 effect-budget ruling)
STATUS READY_FOR_SIDE_FIX_REVIEW
TYPE bugfix
ASK L2 Review → P3-B: (1) accept phases/essence_burn wiring + sparked exemption; (2) confirm fixture update is stale-fixture not semantic conflict; (3) forward sparked + balance observations to L1/L0.

GOAL
Wire data-declared but runtime-dead enemy wiring (phases GO, essence_burn GO per RUL-2026-09-19-010),
take evidence on sparked (GO only with defined semantics), add minimal data→runtime contract test.
Out of scope: balance tuning, P3 gu numbers, data edits, web-lab edits.

DELTA
+ phases runtime (select phase by hp ratio / cooldown gate / cooldown_wait / phase_shift log)
+ essence_burn settle (facade whitelist + resolver deduct, floor 0, essence_burn log)
+ contract test (field completeness + consumption markers + exempt tables + negative control)
+ behavior tests (8 phases/burn/seal/cooldown cases)
~ one stale exact-dict fixture in test_battle_command_facade
= data/enemies.json zero change; wenzhen-web-lab zero change; sparked NOT implemented (exempt, pending L1)

STATE
OpenCode + Muse Spark 1.3 / Godot domain: PARTIALLY VERIFIED (low-risk task, needs Codex Review)

FILES
game/scripts/domain/v1_battle_resolver.gd — phases helpers (active_phase_index/select_enemy_intent/_merge_phase_intent/_intent_ready/_hp_ratio), _resolve_enemy_intent phase+cooldown hook, attack-branch essence_burn settle, intent carries id/cooldown/essence_burn, enemy carries phases/phase_index/last_fired
game/scripts/domain/battle_command_facade.gd — intent whitelist +id/cooldown/essence_burn, phases passthrough (deep copy)
game/tests/unit/test_enemy_phases_runtime.gd — NEW, 8 tests
game/tests/unit/test_enemy_data_runtime_contract.gd — NEW, 7 tests
game/tests/unit/test_battle_command_facade.gd — fixture: expected intent dict +id/cooldown/essence_burn defaults

TEST
focused new: phases 8/8 PASS (31 asserts); contract 7/7 PASS (31 asserts) — console exe, GUT text
related: test_battle_command_facade 33/33 PASS; test_world_model_bridge 10/10 PASS (30 asserts)
full: unit 221 scripts / 1619 tests / 54126 asserts ALL PASS (console exe; pre-existing ObjectDB 8 / resources 2 warnings remain)
SABOTAGE negative: bridge 6/10 pass + 4 failing (gate bites) → restored to false, re-verified 10/10
contract negative: erased intent.essence_burn → missing=[intent.essence_burn]; erased reaction.clue exemption → missing=[reaction.clue]
accept: python game/world-model/tools/accept.py --smoke 10 → exit 0 (64635 checks/0 fail, smoke 10/10)
drift: check_upstream_drift.py → exit 0 (5204 items/0 drift)
diff-check: game/data zero change; game/wenzhen-web-lab untouched; no commit/push

WORKER
OpenCode + Muse Spark 1.3 (normal)
core patch: YES
tests: YES
protocol: YES
Codex takeover: NONE
independent: YES

RISK
Full-unit run had 1 failure (test_layer_boss_scaling exact intent dict) — root-caused as stale fixture (new keys id/cooldown/essence_burn), fixture updated, full suite re-run 1619/1619 green. No semantic conflict.
Pre-existing non-blocking: GUT exit warnings (8 ObjectDB / 2 resources) match game/AGENTS known residual risk.
UNPROVEN NONE (all semantics traced to _phases_note + rules.js; no invented numbers)

GIT
status: scripts+tests modified per scope; game/AGENTS.md + RESEARCH-REQUEST dirty PRE-EXISTING (untouched); validation-report.md timestamp-only side effect of accept run
commit: NONE
merge: NONE
push: NO

DECISION
D1 sparked counter_status | recommend NO (stay exempt) | zero semantic definition in scripts/docs/wiki/data-notes; web-lab explicitly excluded it as drift; inventing risks permanent wrong mechanic
D2 single-intent cooldown gate | recommend YES (implemented) | same _phases_note semantics; 28 cooldown-0 enemies zero drift (proven by test_zero_cooldown_enemies_unaffected)

NEXT
1. L2 review packet → P3-B
2. L1 ruling: sparked semantics; balance: burn 2 vs per-turn regen (mechanic works, threat nil — needs regen/burn numbers, out of scope here)
3. Follow-up (not this task): battle enemies never carry reactions → in-battle _live_counter_labels only sees counter_revealed; map-node fight preview reads catalog reactions directly
STOP

EVIDENCE
_phases_note == rules.js (no conflict, verified verbatim): game/data/enemies.json miasma_vein_lord._phases_note vs game/wenzhen-web-lab/js/rules.js:46/63/71
sparked zero-definition: scripts/docs/wiki grep zero; build_data.mjs:79 exclusion note; dist guarded 24/bound 11/sparked 1
console exe: WinGet Godot_v4.7.2-stable_win64_console.exe (GODOT_PATH points at non-console build — V1 pitfall confirmed avoided)
snapshot: game/world-model/.snapshots/20260919T233735-side-fix-enemy
```

## FIX 收尾（side-fix-enemy-runtime-fix，console 版 Godot 实测全绿）

A. `phase.reactions` 移入豁免表（`test_enemy_data_runtime_contract.gd`）：运行时只读顶层
`reactions`（`action_preview_service.gd:338/:1056`），`phases[i].reactions` 零读取（resolver 只碰
`until_hp_ratio`/`intents`）；5 个带 phases 的 Boss 逐阶段反应表与顶层逐字相同（已用脚本实测），
故为潜在缺口非在爆 bug；接线语义（替换/追加）待设计裁决，未接线。
B. 焚元结算移出 `"attack"` 分支 → `_resolve_enemy_intent` 尾部（`v1_battle_resolver.gd`），对任何 kind
生效；`cooldown_wait` 与 sealed 门禁吞掉意图的提前返回都在它之前，故被吞意图不焚元；注释同步改写。
新增合成夹具 `kind: seal + essence_burn: 2`（`test_enemy_phases_runtime.gd::test_non_attack_kind_burn_still_deducts`），
`paralyzing_howl`（缺省 attack）行为不变。
C. 本包 EVIDENCE/TEST 行 drift 数字 `204` → `5204`（L2 实测值；结论 0 漂移/exit 0 不变）。
复跑证据（console 版 Godot，GUT 文本为准）：
- contract `test_enemy_data_runtime_contract.gd` 7/7 PASS（31 asserts）
- phases `test_enemy_phases_runtime.gd` 9/9 PASS（33 asserts，含新增 seal-kind 焚元用例）
- 负控：临时删 `v1_battle_resolver.gd` 内 `essence_burn` 字样 →
  `test_consumption_markers_exist_in_sources` 变红（`must contain consumption point essence_burn`，at line 156），
  另带 `test_facade_carries_phases_and_burn_fields` 变红（top intent burn key 缺省 0 丢失）；恢复后双套件重跑全绿
- 相关：`test_battle_command_facade` 33/33 PASS（129 asserts）、`test_q8_scenarios` 全过（54 asserts）、
  `test_q8_post_survivability` 全过（13 asserts)
- `git status`：`game/data/**` 零改动；`game/wenzhen-web-lab/**` 未动（untracked 既有状态，未触碰）
- 快照：`game/world-model/.snapshots/20260920T000443-side-fix-fix`；无 commit/push
