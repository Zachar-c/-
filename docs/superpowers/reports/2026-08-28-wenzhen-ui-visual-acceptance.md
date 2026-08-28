# 《問眞》UI Visual Acceptance

- 日期：2026-08-28
- 状态：CHANGES_REQUESTED（用户视觉签核未通过）
- 范围：记录《問眞》大厅、地图、战斗及子界面视觉验收证据。
- 计划：[《問眞》UI 视觉验收修复实施计划](../plans/2026-08-28-wenzhen-ui-visual-acceptance-repair.md)
- 基线：`branch=master @ 418683c`


This is the sole visual-acceptance ledger for the 2026-08-28 repair plan. Automated checks and executor review cannot replace an explicit user approval for any batch.

## Known Failed Baseline

The previous Task 8 has no acceptance report and no user visual signoff. It remains incomplete. The following existing captures are failed baseline evidence only, not acceptance evidence:

- `.superpowers/ui_captures/wenzhen/01_hall_with_save_1920x1080.png`: left-corner shrinkage; no hall master composition.
- `.superpowers/ui_captures/wenzhen/07_map_current_1920x1080.png`: layer-card map instead of a route canvas.
- `.superpowers/ui_captures/wenzhen/22_battle_3_enemies_1920x1080.png`: small panels instead of a three-plane battle view.
- `.superpowers/ui_captures/wenzhen/34_shop_1920x1080.png`: does not inherit the approved people-and-decision composition.
- `.superpowers/ui_captures/wenzhen/40_refine_1920x1080.png`: operating surface lacks the required proportion and risk visibility.
- `.superpowers/ui_captures/wenzhen/31_ending_1920x1080.png`: conclusion does not present the route as the primary reading structure.

## Batch: Hall Master

Status: CHANGES_REQUESTED

Automated evidence: 2026-08-28 fresh Hall structural check completed with exit code 0: `tests/unit/test_wenzhen_hall_screen.gd` 3/3 passed (34 assertions). The generated RUI siblings were rebuilt through `scripts/guitkx_build.gd` immediately before verification. The GUT harness still emits pre-existing orphan/RID/resource cleanup diagnostics; the Hall test process exited 0.

Screenshot index: Fresh real-renderer Godot captures: `01-03_core_hall_running_{1920x1080,1366x768,1280x720}.png`; `04-06_core_hall_no_save_{1920x1080,1366x768,1280x720}.png`; `07-09_core_hall_long_summary_{1920x1080,1366x768,1280x720}.png`; `10-12_core_hall_keyboard_focus_{1920x1080,1366x768,1280x720}.png`. All are under `.superpowers/ui_captures/wenzhen/`.

User quote: "不认可，主界面我也不认可，我都给你html了，怎么还是这样，是godot的编译干扰吗"

Requested changes: Rebuild from the approved Hall HTML as a composition-equivalent Godot screen. Preserve its page-like three-column geometry, title scale and whitespace, single central chapter action, and quiet right archive navigation. Do not reduce the HTML to copied labels inside generic containers.

Residual risk: Structure and screenshots now exist, but automated evidence cannot replace explicit visual signoff against the approved Hall HTML. Do not begin Battle before the user signs off Hall and Map.

## Batch: Map Master

Status: CHANGES_REQUESTED

Automated evidence: 2026-08-28 fresh Map structural check completed with exit code 0: `tests/unit/test_wenzhen_map_screen.gd` 3/3 passed (31 assertions). This includes the HTML-required 970px internal route world, bottom alignment in the clipped camera, fixed depth rail, and visible route geometry. Generated RUI siblings were rebuilt through `scripts/guitkx_build.gd` first. The target test emitted pre-existing RUI stylebox and GUT/RID/resource cleanup diagnostics, but exited 0.

Screenshot index: Fresh Godot capture matrix, all generated on 2026-08-28: `01-03_core_map_current_{1920x1080,1366x768,1280x720}.png`; `04-06_core_map_candidate_a_focus_{1920x1080,1366x768,1280x720}.png`; `07-09_core_map_candidate_b_focus_{1920x1080,1366x768,1280x720}.png`; `10-12_core_map_future_camera_{1920x1080,1366x768,1280x720}.png`; `13-15_core_map_collapsed_history_{1920x1080,1366x768,1280x720}.png`; `16-18_core_map_long_label_{1920x1080,1366x768,1280x720}.png`. All are under `.superpowers/ui_captures/wenzhen/`. Older filename-collision captures are excluded from this matrix.

User quote: "不认可，主界面我也不认可，我都给你html了，怎么还是这样，是godot的编译干扰吗"

Requested changes: Rebuild from the approved Map HTML as a composition-equivalent Godot route camera. Preserve the masthead, marker row, title position, bottom-aligned oversized map world, 2.5-layer camera, depth rail, node sizes, branch emphasis, and quiet bottom inspector. Do not substitute a generic bordered panel or move the world origin to the top of the camera.

Residual risk: The current Map implementation uses real topology and has passed the rebuilt geometry check, but automated checks and real-renderer captures do not replace human visual approval against the approved Map HTML. Known non-fatal diagnostics include RUI stylebox warnings plus GUT child-cleanup and DummyTexture/font RID/ObjectDB/resource leak messages. Both Hall and Map must be explicitly approved before Task 5 Battle Master.

## Batch: Battle Master

Status: PENDING

Automated evidence: NOT RUN. Task 5 layout, card FSM, multi-enemy, and capture checks are pending.

Screenshot index: Pending `core_battle_*` captures at 1920x1080, 1366x768, and 1280x720.

User quote: Pending user signoff.

Requested changes: None recorded.

Residual risk: The three-plane battle composition and real multi-enemy layouts have not been implemented or reviewed.

## Batch: Encounter, NPC, Shop

Status: PENDING

Automated evidence: NOT RUN. Task 6 checks are pending.

Screenshot index: Pending `people_trade_*` captures at 1920x1080, 1366x768, and 1280x720.

User quote: Pending user signoff.

Requested changes: None recorded.

Residual risk: Narrative, NPC, and trade decision surfaces have not been derived from approved masters.

## Batch: Rest, Refine, Reward

Status: PENDING

Automated evidence: NOT RUN. Task 7 checks are pending.

Screenshot index: Pending `decision_tools_*` captures at 1920x1080, 1366x768, and 1280x720.

User quote: Pending user signoff.

Requested changes: None recorded.

Residual risk: Required choice, refinement risk, and full-satchel handling have not been reviewed.

## Batch: Archives, Settings, Ending

Status: PENDING

Automated evidence: NOT RUN. Task 8 checks are pending.

Screenshot index: Pending `archives_ending_*` captures at 1920x1080, 1366x768, and 1280x720.

User quote: Pending user signoff.

Requested changes: None recorded.

Residual risk: Archive reading layouts, settings controls, and route-based ending review have not been implemented or reviewed.

## Final Signoff

FINAL STATUS: PENDING

Automated evidence: NOT RUN. Task 9 regression and release export are pending.

Screenshot index: Pending final four-viewport capture matrix.

User quote: Pending user signoff.

Requested changes: None recorded.

Residual risk: No batch has received user approval. Overall visual repair is incomplete.
