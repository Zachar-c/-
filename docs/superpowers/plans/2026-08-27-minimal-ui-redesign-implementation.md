# 《問眞》极简 UI 重设计实施计划

> 日期：2026-08-27
> 状态：已归档
> 范围：《問眞》极简 UI 重设计实施计划；保留用于实现追踪。
> 基线：`branch=master @ 418683c`；该计划最终变更以此提交为准。
> 替代关系：视觉母版批次已合入当前主线；后续以现行验收计划为准。


> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将已批准的大厅、地图、战斗三张母版生产化，以《問眞》的宣纸白、墨色、发丝线与克制语义色建立完整且可操作的极简 UI，并由三张母版推导其余游戏界面。

**Architecture:** 保留现有 Godot 4.7.2 + RUI 架构，手工编辑 `.guitkx` 和 `scripts/`，不编辑生成的 `ui/**/*.gd`。屏幕只消费 `RunSnapshotBuilder` 快照并通过 `RunCommandBuilder`/`RunController` 提交命令；多敌战斗先在 `BattleResolver`、预览服务和快照契约中落地，再由战斗屏消费，禁止表现层伪造敌人或计算领域结果。

**Tech Stack:** Godot 4.7.2、GDScript、Reactive UI Toolkit `.guitkx`、JSON 数据表、GUT、Windows Desktop 1920x1080 基准视口。

## Global Constraints

- 正式品牌名固定为横排繁体《問眞》；不得在玩家可见主标题中恢复《蛊路求生》。
- 参考《杀戮尖塔》的信息架构、敌人意图、固定信息位置与卡牌交互，不参考其暗色地牢、厚边框、拟物按钮和卡通风格。
- 高频决策信息常驻，中频信息使用 Tooltip，低频信息进入子视图；极简不等于隐藏决策信息。
- 视觉基线为宣纸白、近黑墨色、发丝线、朱砂危险色、契约蓝、异变黄；避免暗色单色界面、厚边框、圆角卡片堆叠和卡片嵌套。
- 顶栏必须把契约与本局异变分区显示；生命和护盾分条；敌人意图同时显示图标、精确数值和效果文字。
- UI 只读快照，通过 `RunController` 和既有命令构造器提交行为；不得直接修改 `RunState`、随机数、存档、目录数据或结局。
- 命令保留展示版本，过期命令必须原子拒绝；危险行动必须消费领域预检并经过二次确认。
- 多敌人必须先扩展领域状态和快照；不得在 UI 中复制单个敌人伪装 2/3 敌阵型。
- 生产 UI 只编辑 `.guitkx` 源和手写 `scripts/`；不得手改生成的 `ui/**/*.gd`。
- 保留用户未提交改动；判断真实差异使用 `git diff --ignore-cr-at-eol`，不得清理已知 autocrlf 行尾噪声。
- 每个任务先写失败测试，再实现最小改动；共享快照、控制器或导航变化后运行 `tools/check.ps1`。
- 每个视觉任务必须在 1920x1080、1366x768、1280x720 三个桌面视口检查文字包含、裁切、重叠、禁用态与反馈；不以未执行的 Playwright 检查作为完成证据。

---

## 文件责任图

- `scripts/presentation/gu_style.gd`：唯一语义色、间距、圆角、线宽和尺寸令牌来源。
- `assets/theme/gu_theme.tres`：Godot 原生控件字体、焦点、按钮和滚动条主题；不承载业务语义。
- `ui/widgets/gu_top_bar.guitkx`：跨地图、战斗、事件和节点页常驻状态，只消费 resources/contracts/anomalies/death_lines。
- `ui/widgets/gu_card.guitkx`：卡牌视觉壳；费用、标题、插画、正文和状态位置固定，不拥有战斗 FSM。
- `ui/widgets/gu_tooltip_view.guitkx`：固定五段 Tooltip。
- `ui/widgets/gu_confirm_dialog.guitkx`：受保护行动的统一确认层。
- `scripts/domain/battle_resolver.gd`：多敌实体、稳定目标、伤害结算、敌方回合和战斗完成条件的唯一权威。
- `scripts/domain/action_preview_service.gd`：卡牌可执行性、目标类型、不可用原因、确定性代价和风险预览。
- `scripts/presentation/run_snapshot_builder.gd`：把领域战斗、地图和大厅数据投影为只读屏幕契约。
- `scripts/presentation/run_command_builder.gd`：把 UI 回调转换为带版本和目标 ID 的命令。
- `ui/screens/hall_view.guitkx`、`map_screen.guitkx`、`battle_screen.guitkx`：三张母版的生产实现。
- `ui/screens/{encounter,shop,npc,rest,refine,reward,ending}_screen.guitkx`：从三张母版推导的次级界面。

### Task 1: 锁定《問眞》视觉令牌与基础主题

**Files:**
- Modify: `scripts/presentation/gu_style.gd`
- Modify: `assets/theme/gu_theme.tres`
- Modify: `ui/widgets/gu_button.guitkx`
- Modify: `ui/widgets/gu_panel.guitkx`
- Test: `tests/unit/test_wenzhen_visual_tokens.gd`

**Interfaces:**
- Consumes: 设计规格中的宣纸、墨、朱砂、契约蓝、异变黄语义。
- Produces: `GuStyle.PAPER_BG`、`INK_PRIMARY`、`INK_MUTED`、`HAIRLINE`、`CINNABAR`、`CONTRACT_BLUE`、`ANOMALY_YELLOW`、`SPACE_1..SPACE_6`、`RADIUS_SMALL`；`GuButton` 的 `tone/size/icon/disabled` props 保持兼容。

- [ ] **Step 1: 写视觉令牌失败测试**

```gdscript
func test_wenzhen_tokens_are_light_high_contrast_and_semantic() -> void:
	assert_gt(GuStyle.PAPER_BG.get_luminance(), 0.82)
	assert_lt(GuStyle.INK_PRIMARY.get_luminance(), 0.18)
	assert_eq(GuStyle.HAIRLINE, 1)
	assert_ne(GuStyle.CONTRACT_BLUE, GuStyle.ANOMALY_YELLOW)
	assert_ne(GuStyle.CINNABAR, GuStyle.ANOMALY_YELLOW)
	assert_lte(GuStyle.RADIUS_SMALL, 8)
```

- [ ] **Step 2: 运行测试并确认因新令牌不存在而失败**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_visual_tokens.gd`

Expected: FAIL，指出 `PAPER_BG` 或 `HAIRLINE` 未定义。

- [ ] **Step 3: 用语义令牌替换旧暗色基础，不删除兼容别名**

```gdscript
const PAPER_BG := Color("f4f1e8")
const PAPER_RAISED := Color("fbfaf5")
const INK_PRIMARY := Color("171713")
const INK_MUTED := Color("68675f")
const HAIRLINE_COLOR := Color("2d2c27", 0.22)
const CINNABAR := Color("a52b24")
const CONTRACT_BLUE := Color("356b8c")
const ANOMALY_YELLOW := Color("a36f16")
const HAIRLINE := 1
const RADIUS_SMALL := 4
const SPACE_1 := 4
const SPACE_2 := 8
const SPACE_3 := 12
const SPACE_4 := 16
const SPACE_5 := 24
const SPACE_6 := 32

# Compatibility aliases for screens migrated in later tasks.
const PAPER := PAPER_BG
const INK := INK_PRIMARY
const DANGER := CINNABAR
```

- [ ] **Step 4: 把按钮和面板改为发丝线、低圆角和清晰焦点态**

`GuButton` 的默认态使用纸色背景或透明背景，hover 只改变纸色/下划线，focus 必须有 2px 可见墨色轮廓；`GuPanel` 只提供内容边界，不增加阴影、厚边框或嵌套卡片外观。

- [ ] **Step 5: 运行令牌测试与现有打磨测试**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_visual_tokens.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_t6e_polish.gd`

Expected: 两个测试文件 PASS；旧测试若锁定旧暗色具体值，应改成语义和对比度断言，不得放宽 Tooltip 顺序或危险态断言。

- [ ] **Step 6: 提交视觉令牌任务**

```bash
git add scripts/presentation/gu_style.gd assets/theme/gu_theme.tres ui/widgets/gu_button.guitkx ui/widgets/gu_panel.guitkx tests/unit/test_wenzhen_visual_tokens.gd
git commit -m "feat(ui): establish Wen Zhen visual tokens"
```

### Task 2: 重建公共 HUD、卡牌、Tooltip 与确认层

**Files:**
- Modify: `ui/widgets/gu_top_bar.guitkx`
- Modify: `ui/widgets/gu_card.guitkx`
- Modify: `ui/widgets/gu_tooltip_view.guitkx`
- Modify: `ui/widgets/gu_confirm_dialog.guitkx`
- Modify: `ui/widgets/gu_resource_chip.guitkx`
- Modify: `ui/widgets/gu_stat_bar.guitkx`
- Test: `tests/unit/test_wenzhen_shared_widgets.gd`
- Test: `tests/unit/test_t5a_confirm_toast.gd`
- Test: `tests/unit/test_t6e_polish.gd`

**Interfaces:**
- Consumes: Task 1 `GuStyle` 令牌。
- Produces: `GuTopBar(resources, contracts, anomalies, death_lines, layer, on_menu, on_view)`；`GuCard(title, cost, quality, art_id, body, upgraded, disabled, disabled_reason, selected, danger, curse_warning, sealed)`；`GuTooltipView(title, quality, effect, synergy, cost, curse_warning)`；`GuConfirmDialog(title, message, consequences, confirm_label, cancel_label, on_confirm, on_cancel)`。

- [ ] **Step 1: 写公共组件结构失败测试**

```gdscript
func test_top_bar_separates_contracts_from_anomalies() -> void:
	var host := _mount("res://ui/widgets/gu_top_bar.gd", {
		"resources": {"hp": 8, "max_hp": 10},
		"contracts": [{"id": "c1", "name": "孤行"}],
		"anomalies": [{"id": "sys:risk", "name": "险象"}],
	})
	assert_true(_has_text(host, "契约"))
	assert_true(_has_text(host, "本局异变"))
	assert_lt(_text_x(host, "契约"), _text_x(host, "本局异变"))

func test_card_keeps_cost_title_art_and_body_in_fixed_order() -> void:
	var host := _mount("res://ui/widgets/gu_card.gd", {
		"title": "月光蛊", "cost": "1", "art_id": "moonlight", "body": "造成 6 点伤害。"
	})
	assert_true(_vertical_order(host, ["1", "月光蛊", "moonlight", "造成 6 点伤害。"]))
```

- [ ] **Step 2: 运行测试并确认旧组件缺少新 props/分区而失败**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_shared_widgets.gd`

Expected: FAIL，指出缺少固定卡牌区域或顶栏分区标签。

- [ ] **Step 3: 实现固定信息位置和爆量折叠规则**

顶栏资源常驻左侧；契约蓝区与异变黄区相邻但分隔；超过 6 个条目时显示前 5 个和 `+N` 聚合入口。卡牌费用固定左上、标题固定顶部、插画区域使用稳定 `aspect_ratio`、正文固定下部；禁用态保持正文可读并显示 `disabled_reason` Tooltip。

- [ ] **Step 4: 把确认层改为消费结构化后果**

```gdscript
var consequences = props.get("consequences", [])
var consequence_rows = []
for item in consequences:
	consequence_rows.append(<Label text={ str(item) } />)
```

保留 `warning_note` 兼容入口并在内部转换为单条 `consequences`；危险确认按钮使用朱砂，取消按钮保持墨色主次清晰。

- [ ] **Step 5: 运行公共组件和既有透明度测试**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_shared_widgets.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_t5a_confirm_toast.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_t6e_polish.gd`

Expected: 全部 PASS；Tooltip 仍按品质、效果、联动、代价、诅咒警示排序，空段隐藏。

- [ ] **Step 6: 提交公共组件任务**

```bash
git add ui/widgets tests/unit/test_wenzhen_shared_widgets.gd tests/unit/test_t5a_confirm_toast.gd tests/unit/test_t6e_polish.gd
git commit -m "feat(ui): rebuild shared decision widgets"
```

### Task 3: 将大厅母版生产化

**Files:**
- Modify: `ui/screens/hall_view.guitkx`
- Modify: `scripts/presentation/run_snapshot_builder.gd`
- Test: `tests/unit/test_wenzhen_hall_screen.gd`
- Test: `tests/unit/test_contracts_meta_hall.gd`
- Test: `tests/unit/test_journal_hall.gd`
- Test: `tests/unit/test_settings_dda.gd`

**Interfaces:**
- Consumes: 现有 Title 快照和命令 `continue_run/open_schools/open_contracts/open_journal/open_codex/open_settings/toggle_dda/quit`。
- Produces: Title 快照新增 `brand_title: "問眞"`、`primary_action: "continue_run"|"open_schools"`、`run_summary: Dictionary`，且不改变大厅永久存档结构。

- [ ] **Step 1: 写大厅单主动作失败测试**

```gdscript
func test_hall_uses_wenzhen_brand_and_one_primary_action() -> void:
	var snapshot := controller._snapshot_for("Title")
	assert_eq(snapshot["brand_title"], "問眞")
	assert_eq(snapshot["primary_action"], "continue_run" if snapshot["has_save"] else "open_schools")
	var host := _mount_hall(snapshot, controller._build_commands("Title"))
	assert_eq(_buttons_with_role(host, "primary").size(), 1)
```

- [ ] **Step 2: 运行测试并确认品牌字段不存在而失败**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_hall_screen.gd`

Expected: FAIL at `brand_title`。

- [ ] **Step 3: 扩展大厅只读快照**

```gdscript
out["brand_title"] = "問眞"
out["primary_action"] = "continue_run" if out["has_save"] else "open_schools"
out["run_summary"] = {
	"route": str(state.current_node_id) if state != null else "",
	"rank": int(state.rank) if state != null else 0,
	"hp": int(state.hp) if state != null else 0,
}
```

字段取值必须来自当前真实 `RunState` 属性；若属性名不同，使用现有 snapshot resource helper，不在 UI 重算。

- [ ] **Step 4: 按“这一世的第一页”实现大厅**

横排《問眞》置于开放留白中，不用卡片包裹；有存档时“继续此世”为唯一主动作并显示三行 run 摘要，无存档时“开始此世”为唯一主动作。手记、图鉴、设置作为低权重文字/图标入口；流派与契约选择继续使用现有权威子视图，不改开局流程。

- [ ] **Step 5: 运行大厅关联测试**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_hall_screen.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_contracts_meta_hall.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_journal_hall.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_settings_dda.gd`

Expected: 全部 PASS；继续 Run 仍优先，图鉴只读，DDA 开关仍写大厅设置。

- [ ] **Step 6: 提交大厅任务**

```bash
git add ui/screens/hall_view.guitkx scripts/presentation/run_snapshot_builder.gd tests/unit/test_wenzhen_hall_screen.gd
git commit -m "feat(ui): produce Wen Zhen hall master"
```

### Task 4: 将多分支聚焦地图母版生产化

**Files:**
- Modify: `scripts/presentation/run_snapshot_builder.gd`
- Modify: `ui/screens/map_screen.guitkx`
- Modify: `scripts/presentation/route_tree_canvas.gd`
- Test: `tests/unit/test_wenzhen_map_screen.gd`
- Test: `tests/unit/test_five_layer_map_contract.gd`
- Test: `tests/unit/test_map_network.gd`
- Test: `tests/unit/test_t5a_confirm_toast.gd`

**Interfaces:**
- Consumes: `MapGenerator.visible_nodes(route, state, 2)` 的 `reachable` 标记和现有 `travel/view_node/save_run` 命令。
- Produces: Map 节点项固定含 `id/type/label/layer/next_ids/reachable/visited/current/visibility`；`visibility` 仅为 `past/current/reachable/lookahead`。

- [ ] **Step 1: 写地图快照和视口失败测试**

```gdscript
func test_map_snapshot_preserves_branches_and_visibility_roles() -> void:
	var snapshot := controller._snapshot_for("Map")
	assert_true(snapshot["nodes"].all(func(n): return n.has("next_ids") and n.has("visibility")))
	assert_true(snapshot["nodes"].any(func(n): return n["visibility"] == "lookahead" and not n["reachable"]))

func test_map_hides_unchosen_siblings_behind_history_summary() -> void:
	var host := _mount_progressed_map()
	assert_lte(_visible_past_node_buttons(host).size(), 1)
	assert_true(_has_text(host, "已行之路"))
```

- [ ] **Step 2: 运行测试并确认 `next_ids/visibility` 尚未投影而失败**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_map_screen.gd`

Expected: FAIL on missing map snapshot fields。

- [ ] **Step 3: 扩展 Map 快照而不改变地图生成**

```gdscript
nodes.append({
	"id": str(n["id"]),
	"type": str(n.get("type", "event")),
	"label": _node_label(n),
	"layer": int(n.get("layer", -1)),
	"next_ids": Array(n.get("next_ids", [])).duplicate(),
	"reachable": bool(n.get("reachable", false)),
	"visited": state.node_flags.has(str(n["id"])),
	"current": str(n["id"]) == str(state.current_node_id),
	"visibility": _map_visibility(n, state),
})
```

`_map_visibility` 只根据 `node_flags/current/reachable/layer` 分类，不改变路径可达性。

- [ ] **Step 4: 实现约 2.5 层聚焦视口和历史收束**

地图画布大于视口并支持滚动/拖动；当前层位于视口中下部，完整显示可达层与两层 lookahead，第三层只露出提示边缘。已走路径收为一条细墨线和“已行之路”，同层未选历史分支不再保留大节点卡；未来所有已知分支与连线保持可见，只有 `reachable=true` 的直接邻居可提交 travel。

- [ ] **Step 5: 运行地图领域与 UI 测试**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_map_screen.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_five_layer_map_contract.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_map_network.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_t5a_confirm_toast.gd`

Expected: 全部 PASS；多分支、收敛 Boss 路径、仅直接邻居可达和存档反馈不变。

- [ ] **Step 6: 提交地图任务**

```bash
git add scripts/presentation/run_snapshot_builder.gd ui/screens/map_screen.guitkx scripts/presentation/route_tree_canvas.gd tests/unit/test_wenzhen_map_screen.gd
git commit -m "feat(ui): produce focused branching map master"
```

### Task 5: 在领域与快照中落地真实多敌战斗契约

**Files:**
- Modify: `scripts/domain/battle_resolver.gd`
- Modify: `scripts/domain/action_preview_service.gd`
- Modify: `scripts/presentation/run_snapshot_builder.gd`
- Modify: `scripts/presentation/run_command_builder.gd`
- Modify: `scripts/presentation/run_controller.gd`
- Modify: `data/enemies.json`
- Test: `tests/unit/test_multi_enemy_battle.gd`
- Test: `tests/unit/test_v3_battle_card_actions.gd`
- Test: `tests/unit/test_action_preview_service.gd`
- Test: `tests/unit/test_v3_ui_sync.gd`

**Interfaces:**
- Consumes: 旧入口 `BattleResolver.start({"enemy_kind": String}, state, catalog)`。
- Produces: 新入口兼容 `enemy_kinds: Array[String]`；battle `enemies: Array[Dictionary]`，每项含 `enemy_id/kind/name/hp/max_hp/shield/statuses/visible_intent/alive`；卡牌预览含 `target_type: "none"|"single_enemy"|"all_enemies"|"self"` 和 `valid_target_ids`；命令含 `action_id/state_version/target_id`。

- [ ] **Step 1: 写多敌领域失败测试**

```gdscript
func test_multi_enemy_battle_has_stable_ids_and_independent_intents() -> void:
	var battle := BattleResolver.start({"enemy_kinds": ["ridge_hound", "beast_swarm"]}, run, catalog)
	assert_eq(battle["enemies"].size(), 2)
	assert_eq(battle["enemies"][0]["enemy_id"], "%s:e0" % battle["battle_id"])
	assert_eq(battle["enemies"][1]["enemy_id"], "%s:e1" % battle["battle_id"])
	assert_true(battle["enemies"][0]["visible_intent"].has("type"))
	assert_true(battle["enemies"][1]["visible_intent"].has("type"))

func test_single_target_card_only_damages_selected_living_enemy() -> void:
	var before := _two_enemy_battle()
	var target_id := before["enemies"][1]["enemy_id"]
	var result := BattleResolver.apply_action_card(before, run, _play_first_attack(before, target_id), catalog)
	assert_eq(result["battle"]["enemies"][0]["hp"], before["enemies"][0]["hp"])
	assert_lt(result["battle"]["enemies"][1]["hp"], before["enemies"][1]["hp"])
```

- [ ] **Step 2: 运行测试并确认当前单敌 `enemy_hp` 模型失败**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_multi_enemy_battle.gd`

Expected: FAIL because `enemies` is missing or target is ignored。

- [ ] **Step 3: 以 `enemies` 为权威并提供单敌兼容投影**

`BattleResolver.start` 将单个 `enemy_kind` 规范化为一项 `enemy_kinds`。所有伤害、状态、意图、敌方回合与胜利判定遍历存活敌人；单敌旧字段只在兼容 helper 中镜像第一名存活敌人，旧测试迁移后不得继续作为写入权威。

```gdscript
static func _living_enemies(battle: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if bool(enemy.get("alive", true)) and int(enemy.get("hp", 0)) > 0:
			out.append(enemy)
	return out
```

- [ ] **Step 4: 增加稳定目标验证和原子拒绝**

`target_type=single_enemy` 且 `target_id` 缺失、未知或已死亡时返回 `battle_target_invalid`，不得扣费、移牌、推进 `hand_version` 或触发日志。无目标牌忽略空 `target_id`；全体牌由领域遍历存活敌人。

- [ ] **Step 5: 扩展快照、预览和命令版本**

`RunSnapshotBuilder.battle` 逐敌投影生命、护盾、状态和意图；投影牌堆数量、魂魄操作上限与已使用数。`RunCommandBuilder.play_card` 提交 `action_id/card_id/target_id/state_version`，`RunController` 不再依赖 `_ui_card_id` 临时写入来解释新命令，但保留旧测试入口兼容。

- [ ] **Step 6: 增加一个真实双敌 encounter 数据项**

在 `data/enemies.json` 或既有遭遇数据 schema 中加入只用于正常池的双敌组合，使用两个现有敌人 ID；不得复制敌人定义，不引入 UI 专用敌人。ContentCatalog 校验必须拒绝未知成员和重复 `enemy_id`。

- [ ] **Step 7: 运行领域、预览和同步回归**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_multi_enemy_battle.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_v3_battle_card_actions.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_action_preview_service.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_v3_ui_sync.gd`

Expected: 全部 PASS；同种子敌人顺序、意图与结算可复现，过期和非法目标原子拒绝。

- [ ] **Step 8: 提交多敌领域任务**

```bash
git add scripts/domain/battle_resolver.gd scripts/domain/action_preview_service.gd scripts/presentation/run_snapshot_builder.gd scripts/presentation/run_command_builder.gd scripts/presentation/run_controller.gd data/enemies.json tests/unit/test_multi_enemy_battle.gd tests/unit/test_v3_battle_card_actions.gd tests/unit/test_action_preview_service.gd tests/unit/test_v3_ui_sync.gd
git commit -m "feat(battle): support deterministic multi-enemy targets"
```

### Task 6: 将三层战斗母版与卡牌 FSM 生产化

**Files:**
- Modify: `ui/screens/battle_screen.guitkx`
- Create: `ui/widgets/gu_enemy_actor.guitkx`
- Create: `ui/widgets/gu_battle_hand.guitkx`
- Modify: `ui/widgets/gu_card.guitkx`
- Test: `tests/unit/test_wenzhen_battle_screen.gd`
- Test: `tests/unit/test_wenzhen_card_fsm.gd`
- Test: `tests/unit/test_t5b_death_cause_ui.gd`
- Test: `tests/unit/test_v3_ui_sync.gd`

**Interfaces:**
- Consumes: Task 5 battle snapshot `enemies/hand/piles/soul_ops/default_target_id` 和 commands `play_card/end_turn/ultimate/refine/flee`。
- Produces: 屏内纯交互状态 `idle/hover/drag_start/dragging/target_select/play_success/drag_cancel`，危险行动在合法目标确定后通过正交 `confirming` 标记挂起；`GuEnemyActor(enemy, selected, selectable, on_select)`；`GuBattleHand(cards, interaction, on_hover, on_press, on_drag, on_release, on_cancel)`。

- [ ] **Step 1: 写三层布局和 1/2/3/4+ 阵型失败测试**

```gdscript
func test_battle_screen_has_fixed_hud_field_and_hand_regions() -> void:
	var host := _mount_battle(_snapshot_with_enemies(3))
	assert_true(_named(host, "battle_hud").position.y < _named(host, "battle_field").position.y)
	assert_true(_named(host, "battle_field").position.y < _named(host, "battle_hand").position.y)
	assert_lt(_player_center(host).x, _enemy_group_center(host).x)

func test_three_enemies_keep_individual_intent_hp_and_status() -> void:
	var host := _mount_battle(_snapshot_with_enemies(3))
	assert_eq(_nodes_named_prefix(host, "enemy_actor_").size(), 3)
	for id in ["e0", "e1", "e2"]:
		assert_true(_actor_has(host, id, ["intent", "hp", "status"]))
```

- [ ] **Step 2: 写目标选择 FSM 失败测试**

```gdscript
func test_single_target_card_waits_for_enemy_and_can_cancel() -> void:
	var played: Array = []
	var host := _mount_target_battle(func(card_id, target_id): played.append([card_id, target_id]))
	_press_card(host, "c1")
	assert_true(_has_state(host, "target_select"))
	assert_true(played.is_empty())
	_press_cancel(host)
	assert_true(_has_state(host, "idle"))
	assert_true(played.is_empty())
```

- [ ] **Step 3: 运行两个新测试并确认旧战斗布局/FSM 失败**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_battle_screen.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_card_fsm.gd`

Expected: FAIL because named regions and target-select state do not exist。

- [ ] **Step 4: 实现固定三层战斗构图**

上视界为 `GuTopBar`；中视界左侧单一玩家角色，右侧敌群；下视界中央扇形/水平手牌，真元在左，抽牌/弃牌/消耗数量分列，结束回合固定右下。1 敌居右中，2 敌横排，3 敌浅弧排布，4+ 显示前三名加“余敌 N”聚合入口；点击聚合入口展开紧凑敌人名册，每个折叠敌人仍显示意图、生命、护盾、状态并可按 `enemy_id` 选中。聚合只改变展示，所有存活敌人始终保留在快照和合法目标列表中。

- [ ] **Step 5: 实现屏内交互 FSM，不写领域状态**

```gdscript
var interaction = useState({
	"mode": "idle",
	"card_id": "",
	"target_id": "",
	"confirming": false,
})
```

状态转换固定为：`idle -> hover -> drag_start -> dragging`；无目标牌合法释放进入 `play_success` 后回到 `idle`；单目标牌合法释放进入 `target_select`，选择 `valid_target_ids` 中的敌人后进入 `play_success`；非法释放、右键、ESC 或取消按钮进入 `drag_cancel`，归位动画结束后回到 `idle`。不可用牌只能在 `idle/hover` 间切换；危险牌在合法目标确定后设置 `confirming=true`，确认才提交并进入 `play_success`，取消则进入 `drag_cancel`。`play_success` 和 `drag_cancel` 只控制视觉反馈，不得提前改写手牌或资源。

- [ ] **Step 6: 逐敌绑定意图 Tooltip 和状态 Tooltip**

每名敌人的意图贴在角色上方，生命/护盾/状态贴角色下方；Tooltip 只解释快照字段，不推算下一回合。玩家与敌人的生命和护盾必须为独立条；反噬受击反馈只作用生命条。

- [ ] **Step 7: 运行战斗 UI 和危险层回归**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_battle_screen.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_card_fsm.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_t5b_death_cause_ui.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_v3_ui_sync.gd`

Expected: 全部 PASS；死亡线浮层、结束回合、意图数值文字和真实命令回调仍可用。

- [ ] **Step 8: 提交战斗母版任务**

```bash
git add ui/screens/battle_screen.guitkx ui/widgets/gu_enemy_actor.guitkx ui/widgets/gu_battle_hand.guitkx ui/widgets/gu_card.guitkx tests/unit/test_wenzhen_battle_screen.gd tests/unit/test_wenzhen_card_fsm.gd
git commit -m "feat(ui): produce three-band battle master"
```

### Task 7: 从三张母版推导所有次级界面

**Files:**
- Modify: `ui/screens/encounter_screen.guitkx`
- Modify: `ui/screens/shop_screen.guitkx`
- Modify: `ui/screens/npc_screen.guitkx`
- Modify: `ui/screens/rest_screen.guitkx`
- Modify: `ui/screens/refine_screen.guitkx`
- Modify: `ui/screens/reward_screen.guitkx`
- Modify: `ui/screens/ending_screen.guitkx`
- Test: `tests/unit/test_wenzhen_secondary_screens.gd`
- Test: `tests/unit/test_t5a_confirm_toast.gd`
- Test: `tests/unit/test_t5c_ending_review.gd`
- Test: `tests/unit/test_t6e_polish.gd`

**Interfaces:**
- Consumes: Tasks 1-2 公共令牌、顶栏、卡牌、Tooltip、确认层；各屏现有 snapshot 与 commands 不改名。
- Produces: 所有次级屏采用“常驻顶栏 + 单一决策主体 + 触发详情/确认层”结构，不增加新导航状态。

- [ ] **Step 1: 写次级屏信息密度失败测试**

```gdscript
func test_secondary_screens_keep_one_decision_surface_and_no_nested_cards() -> void:
	for fixture in _screen_fixtures():
		var host := _mount(fixture.path, fixture.props)
		assert_eq(_top_bar_count(host), 1, fixture.path)
		assert_eq(_primary_decision_regions(host), 1, fixture.path)
		assert_eq(_card_inside_card_count(host), 0, fixture.path)
```

- [ ] **Step 2: 运行测试并确认旧页面存在多面板/嵌套卡片而失败**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_secondary_screens.gd`

Expected: FAIL with one or more nested or competing regions。

- [ ] **Step 3: 推导事件、NPC 和商店**

事件与 NPC 使用中视界人物/对象 + 下方选择列；后果预览固定在选择项内，详情进 Tooltip。商店使用无卡片套卡片的货架列表，价格、剩余次数和通胀常驻；寿元、反噬和应急支付继续走结构化确认层。

- [ ] **Step 4: 推导休整、炼蛊和奖励**

休整保持强制二选一；炼蛊用分段控件切换定向/组合/盲炼，材料位、成功率、代价和失败后果常驻；奖励页保持单次取舍，满蛊槽必须先选择替换并确认，空池回退只显示小字提示。

- [ ] **Step 5: 推导统一结算页**

结算保持同一 `ending_type` 驱动和六要素复盘；路线、最高转数、关键决定、得失、解锁和契约/DDA 复盘按纵向章节展开，不恢复读档、回溯或撤销入口。

- [ ] **Step 6: 运行次级页面与不可逆流程测试**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_secondary_screens.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_t5a_confirm_toast.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_t5c_ending_review.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_t6e_polish.gd`

Expected: 全部 PASS；确认门禁、空池提示、六要素结算和无回溯入口不变。

- [ ] **Step 7: 提交次级页面任务**

```bash
git add ui/screens tests/unit/test_wenzhen_secondary_screens.gd
git commit -m "feat(ui): derive secondary screens from core masters"
```

### Task 8: 完成视觉、行为、长流程和发布构建验收

**Files:**
- Modify: `scripts/ui_capture.gd`
- Modify: `scripts/playthrough_smoke.gd`
- Create: `tests/integration/test_wenzhen_ui_flow.gd`
- Create: `docs/superpowers/reports/2026-08-27-wenzhen-ui-verification.md`

**Interfaces:**
- Consumes: Tasks 1-7 的全部生产界面与命令边界。
- Produces: 三视口截图、单/双/三敌截图、完整大厅到结算行为证据、Release 调试门禁证据和验收报告。

- [ ] **Step 1: 写端到端 UI 流程失败测试**

```gdscript
func test_hall_map_multi_enemy_battle_and_ending_flow() -> void:
	controller.start_new_run(101, "force", [])
	assert_eq(controller.current_view_name(), "Map")
	_travel_to_combat(controller)
	_start_two_enemy_battle(controller)
	assert_eq(controller._snapshot_for("Battle")["enemies"].size(), 2)
	_play_valid_target_card(controller)
	assert_eq(controller.current_view_name(), "Battle")
	_finish_battle_and_resolve_ending(controller)
	assert_eq(controller.current_view_name(), "Ending")
```

`_travel_to_combat`、`_start_two_enemy_battle`、`_play_valid_target_card` 与 `_finish_battle_and_resolve_ending` 均为该测试文件内的夹具 helper，只调用正式 controller commands 和确定性测试目录数据；不得向 `RunController` 增加 `force_*` 生产接口。

- [ ] **Step 2: 运行集成测试并确认截图/双敌夹具尚未接入而失败**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/integration/test_wenzhen_ui_flow.gd`

Expected: FAIL until the capture fixture and deterministic two-enemy path are wired。

- [ ] **Step 3: 扩展现有捕获脚本，不创建第二套 UI 驱动器**

捕获大厅有/无存档、地图当前/前瞻/历史收束、战斗单/双/三敌、目标选择、危险确认、商店、炼蛊、奖励和结算。输出到 `res://.superpowers/ui_captures/wenzhen/`；1920x1080、1366x768、1280x720 各一组。

- [ ] **Step 4: 运行完整自动验证**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/integration/test_wenzhen_ui_flow.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/check.ps1`

Run: `git diff --check`

Expected: integration PASS；unit/integration 基线全部通过（允许项目已记录的单个既有 risky，但不得新增）；`git diff --check` 无新增空白错误。

- [ ] **Step 5: 启动项目并逐张人工检查捕获结果**

Run: `powershell -ExecutionPolicy Bypass -File tools/play.ps1`

检查：三视口无文字溢出、无重叠、无空白画布；《問眞》横排且上下留白不截断人物延伸；地图当前决策清晰且只展示约 2.5 层；1/2/3 敌各自意图、生命、护盾和状态可读；手牌居中且目标高亮/取消/禁用/确认反馈完整。

- [ ] **Step 6: 验证 Windows Release 构建和调试门禁**

Run: `powershell -ExecutionPolicy Bypass -File tools/export.ps1`

Expected: `build/win/gu-zhenren.exe` 成功生成；Release 中 F12 不出现调试面板，发布包不包含测试、docs、语料或开发 UI 捕获。

- [ ] **Step 7: 写验收报告**

报告逐项记录命令、实际结果、截图路径、三视口结论、单/双/三敌结论、残余风险。Playwright 未安装时明确写“未执行 Playwright”，不得写为通过；Godot 捕获和人工检查是本计划的视觉证据。

- [ ] **Step 8: 提交最终验收任务**

```bash
git add scripts/ui_capture.gd scripts/playthrough_smoke.gd tests/integration/test_wenzhen_ui_flow.gd docs/superpowers/reports/2026-08-27-wenzhen-ui-verification.md
git commit -m "test(ui): verify Wen Zhen redesign end to end"
```

## 实施顺序与审查门

1. Task 1-2 先建立公共视觉语言；未通过公共组件测试，不进入母版页面。
2. Task 3-4 可在 Task 2 后并行，但合并前分别审查大厅单主动作与地图可达性。
3. Task 5 是 Task 6 的硬前置；多敌领域测试未通过时，不允许在战斗 UI 展示复数敌人。
4. Task 6 完成后，以三张核心母版作为 Task 7 的直接设计来源，不另造页面视觉体系。
5. Task 8 只做验收脚本、报告和必要的捕获接线，不在此阶段补功能设计。

## 完成定义

- 玩家第一眼看到的正式名称是横排《問眞》。
- 大厅只有一个当前主动作；地图在低复杂度视口中保留真实多分支；战斗严格保持上 HUD、中战场、下手牌。
- 1/2/3 敌都来自真实领域状态，每名敌人有唯一 ID、独立意图、生命/护盾和状态；目标牌不会误伤默认敌人。
- 所有决策必需信息无需打开低频子视图即可获得；复杂解释通过 Tooltip；不可逆行为通过预检和确认层。
- 全部屏幕只读快照并提交版本化命令，UI 没有领域状态写入或随机计算。
- 聚焦测试、完整 `tools/check.ps1`、`git diff --check` 和 Windows Release 导出均有实际通过证据。
- 三个桌面视口和单/双/三敌捕获经人工检查，无裁切、重叠、空白、信息归属错误或旧暗色视觉残留。
