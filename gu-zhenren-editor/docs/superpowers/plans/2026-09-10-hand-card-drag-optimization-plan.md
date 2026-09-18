# 手牌拖拽优化实施计划（Smart Drag And Drop Cards 改版）

- **日期**：2026-09-10
- **状态**：已落地（headless 回归全绿，见 §11；未提交）
- **需求来源**：用户裁定（本日会话），参考开源项目 Smart Drag And Drop Cards
- **需求澄清结论（用户裁定）**：
  1. 指向性卡（`target_type == "single_enemy"`）：点击武装；按住拖动**不出影卡**，从卡牌延伸**瞄准矢量线**到鼠标，悬停敌人高亮，松手命中敌人即出牌。
  2. 无指向性卡：点击直接出牌（保留现状）；按住拖出**固定距离**松手即出牌，不足距离回弹。
  3. 拖拽手感参数：脚本常量（不入 JSON）。
  4. 验收：headless 回归门（AI 契约默认口径）。
  5. 范围：仅战斗手牌，不扩炼蛊/背包等其他屏。

---

## 1. 交互规格（两种手势，按 `target_type` 分流）

```
按下可执行手牌卡（button_down）
  └─ 记录候选：_drag_candidate_card / _drag_press_pos / _drag_source_rect
位移 < 6px（DRAG_START_THRESHOLD_PX）松手
  └─ 普通点击：走按钮 pressed 原路径
     指向卡 → 武装 target_select（等点敌人名）
     无指向卡 → 直接出牌（危险卡进确认流）
位移 ≥ 6px：
  ├─ 指向卡 → 瞄准模式（_aim_active）：
  │    · 生成 AimLineOverlay（viewport 层，墨线从源卡中心 → 鼠标）
  │    · 不生成影卡、不压暗源卡（卡不"离手"）
  │    · 每帧：命中敌人 → 线变玉绿 + 敌人卡放置高亮（Jade 描边）
  │    · 松手：命中敌方卡 → 出牌（危险卡进确认流）；未命中 → 取消（线移除）
  └─ 无指向卡 → 拖拽模式（_drag_active）：
       · 生成半透明影卡（alpha 0.72，跟随鼠标平滑插值，源卡压暗 0.45）
       · 悬停敌人 → 放置高亮 + 影卡 1.06 倍吸附缩放
       · 松手：拖出 ≥ 64px（DRAG_CAST_DISTANCE_PX）→ 出牌（销毁影卡）
               不足 64px → 回弹动画（影卡飞回源卡原位并淡出，0.22s）+ ui_cancel 音效
拖拽/瞄准中：右键 或 Esc → 取消（影卡回弹 / 瞄准线移除）
```

不变量（回归测试既有断言）：
- 松手命中敌方卡 → 出牌并按该目标提交（指向卡拖到敌人 = 瞄准释放，行为兼容）。
- 松手未命中敌方卡 → 不提交。
- 同卡同目标对每次快照只提交一次（`_submitted_card_keys` 去重）。
- 按住期间不得重建手牌（`_refresh` 破坏接收输入的按钮）；出牌刷新只发生在松手后。

## 2. 可调参数（脚本常量，`battle_screen_view.gd` 顶部）

| 常量 | 值 | 含义 |
|---|---|---|
| `DRAG_START_THRESHOLD_PX` | 6.0 | 拖拽/瞄准触发灵敏度（低于视为普通点击） |
| `DRAG_PROXY_ALPHA` | 0.72 | 影卡半透明度 |
| `DRAG_FOLLOW_SMOOTH` | 0.45 | 影卡每帧跟随插值权重（帧率无关：`1-(1-s)^(delta*60)`） |
| `DRAG_REBOUND_TIME` | 0.22 | 无效落点回弹时长（秒） |
| `DRAG_CAST_DISTANCE_PX` | 64.0 | 无指向卡拖出该距离松手即出牌 |

## 3. 涉及文件

| 文件 | 改动 |
|---|---|
| `scripts/presentation/screens/battle_screen_view.gd` | 常量、拖拽状态机、瞄准线、回弹（**§6.1 待补 AimLineOverlay**） |
| `scripts/presentation/widgets/gu_battle_hand_view.gd` | 新增 `card_rect` / `set_card_dimmed` / `create_drag_proxy`（已完成） |
| `scripts/presentation/widgets/gu_enemy_actor_view.gd` | 新增 `set_drop_highlight` 放置高亮态（已完成） |
| `tests/unit/test_wenzhen_card_fsm.gd` | 新增/改写 3 个拖拽用例（§8） |
| `docs/contracts/2026-09-02-domain-ui-contract.md` 等 | §9 契约核对回写（待办） |

## 4. 已完成改动（本会话已落盘，未提交）

### 4.1 `gu_battle_hand_view.gd`（已验证可编译）
- `card_rect(card_id) -> Rect2`：按 `card_box_<id>` 查卡体全局矩形（回弹落点）。
- `set_card_dimmed(card_id, dimmed)`：拖拽期间压暗源卡（`modulate.a` 0.45 / 1.0）。
- `create_drag_proxy(card) -> Control`：按卡面同款样式（`MasterTheme.apply_button(btn, "card")`、168×74、字号 10）生成克隆 Button；`mouse_filter = IGNORE` 不挡命中检测。

### 4.2 `gu_enemy_actor_view.gd`（已验证可编译）
- 新增成员 `_selected`、`_drop_highlight`；`setup()` 存 `_selected` 并重置 `_drop_highlight = false`。
- `set_drop_highlight(on)`：开关放置高亮并重刷 `_apply_actor_style(_selected)`。
- `_apply_actor_style`：`lit = selected or _drop_highlight`；lit 时玉绿 2px 描边 + 立绘 alpha 1.0。

### 4.3 `battle_screen_view.gd`（已完成，可编译）
已落地：参数常量（§2）、成员（`_drag_active`/`_aim_active`/`_drag_active_card_id`/`_drag_proxy`/`_aim_line`/`_drag_press_pos`/`_drag_source_rect`/`_drop_hot_enemy`）、`_on_card_drag_start`、`_input`（双手势分流 + 右键/Esc 取消 + 抬起吞并）、`_drag_begin`（指向卡建瞄准线 / 无指向卡建影卡）、`_drag_end`（清高亮 + 恢复源卡 + 命中销毁 / 未命中回弹）、`_process`（影卡跟随 / 调 `_process_aim`）、`_process_aim`、`_set_drop_hot`、`_exit_tree`、内部类 `AimLineOverlay`。
实施期两处偏离原稿（详见 §11）：`_aim_line` 用内部类类型标注（`AimLineOverlay`）而非 `Control`；无指向卡真拖拽后的抬起一律吞并。

## 5. 领域-表现边界（红线自查）

- 不新增快照键、不新增命令、不修改 `play_card` 命令签名；手势仅是既有 `play_card(card_id, target_id)` 的表现层入口。
- 瞄准线/影卡/回弹均为纯表现层对象（挂 viewport，`mouse_filter=IGNORE`），不落事件日志、不进存档（表现层装饰，非玩法随机，符合 2026-09-09 W14 豁免口径）。
- 按住期间零 `_refresh()`；出牌/确认仍走 `_play_card` → `_submit_card`（去重、音效、墨迹扩散不变）。

## 6. 待完成改动（按序执行）

### 6.1 【已完成】`battle_screen_view.gd` 文件末尾追加内部类

原稿给出字面 Color 默认值，但 `tests/unit/test_ui_rules_guard.gd:test_no_hardcoded_colors_in_new_stack` 禁止新体系硬编码色值（UI_RULES §2），故默认值改为 `GuStyle.INK_PRIMARY`（gu_style.gd 是全局 `class_name`，内部类可直接引用）。落定代码（文件末尾 `_make_panel_fully_transparent` 之后）：

```gdscript
## 指向性卡牌瞄准矢量线：viewport 层覆盖件，画一条从源卡中心到鼠标的墨线
## （命中敌人时玉绿）。不接收输入、不参与布局；生命周期由宿主 _drag_end/_exit_tree 管理。
class AimLineOverlay extends Control:
	var line_from := Vector2.ZERO
	var line_to := Vector2.ZERO
	# 默认值只兜底首帧；宿主 _process_aim 每帧都会 set_line 传入 GuStyle token。
	# 必须走 token：test_ui_rules_guard 禁止新体系硬编码色值（UI_RULES §2）。
	var line_color := GuStyle.INK_PRIMARY

	func _init() -> void:
		name = "battle_aim_line"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 100
		# 盖满视口，避免绘制内容落在自身矩形外（无裁剪时虽仍可见，但明确尺寸更稳）。
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func set_line(from: Vector2, to: Vector2, color: Color) -> void:
		line_from = from
		line_to = to
		line_color = color
		queue_redraw()

	func _draw() -> void:
		draw_line(line_from, line_to, line_color, 2.0)
		draw_circle(line_to, 3.0, line_color)
```

> `_aim_line` 成员声明同步改为 `var _aim_line: AimLineOverlay = null`——原稿的 `: Control` 会让 `_aim_line.set_line(...)` 在静态分析期报「Function not found in base Control」。`_drag_begin` 里用 `var overlay := AimLineOverlay.new()` 推断类型，避免把 `Control` 赋给内部类类型。

### 6.2 【已完成】`_exit_tree` 补瞄准线清理（回弹中的影卡与瞄准线都挂 viewport，不随本屏释放）

```gdscript
## 屏幕退出时清残留拖拽呈现对象（挂在 viewport 上，不随本屏释放）。
func _exit_tree() -> void:
	if _drag_proxy != null and is_instance_valid(_drag_proxy):
		_drag_proxy.queue_free()
	_drag_proxy = null
	if _aim_line != null and is_instance_valid(_aim_line):
		_aim_line.queue_free()
	_aim_line = null
```

### 6.3 【已完成】契约核对与回写

- 核对结果：`docs/contracts/2026-09-02-domain-ui-contract.md` 无 drag/拖拽正文（仅 `dragon_fish_replacement` 子串误命中）；`docs/contracts/module-interfaces/` 无 `play_card / 手牌 / GuBattleHand` 相关页 → **键面零变化**（无新快照键、无新命令、无公开组件签名变化），契约漂移门 `check_contract_drift.gd` 报 `ok (157 identifiers resolved)`。
- 已回写：`docs/contracts/2026-09-02-page-inventory-requirements.md` P4 Battle 验收段追加「手牌手势（2026-09-10 双入口口径）」一条，说明指向卡=瞄准线 / 无指向卡=定距拖出 / 影卡与瞄准线属纯表现层装饰 / 真拖拽抬起一律吞并。

## 7. 当前工作树状态（收口后）

```
已修改（未提交，本任务全部改动）：
  scripts/presentation/screens/battle_screen_view.gd      ← 已落地（§4.3 / §6.1 / §6.2）
  scripts/presentation/widgets/gu_battle_hand_view.gd     ← 已完成（§4.1）
  scripts/presentation/widgets/gu_enemy_actor_view.gd     ← 已完成（§4.2）
  tests/unit/test_wenzhen_card_fsm.gd                     ← 已按 §8 改写（13/13 绿）
  docs/contracts/2026-09-02-page-inventory-requirements.md ← §6.3 手势口径回写
未跟踪：tools/_reg*.log（既有遗留 + 本次验收日志，勿提交）
```

- 上述 5 个文件的改动是本任务的一部分，**不得还原**。
- 收口验收数字与偏离见 §11。

## 8. 单测计划（`tests/unit/test_wenzhen_card_fsm.gd`）

现有用例 `test_drag_proxy_spawns_after_threshold_and_rebounds_off_enemies` 用的月光蛊是指向卡（新口径走瞄准线，不出影卡），**必须改写**。三个用例：

```gdscript
const NON_TARGET_CARD := {"id": "c2", "name": "凝气蛊", "cost": 1,
		"effect": "强化自身", "executable": true, "target_type": "none"}

# 用例 1（改写既有）：无指向卡位移超阈值出影卡；拖出不足 DRAG_CAST_DISTANCE_PX
# 松手 → 回弹销毁、不出牌。
func test_drag_proxy_spawns_after_threshold_and_rebounds_off_enemies() -> void:
	var played: Array = []
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.gui_disable_input = false
	add_child(viewport)
	_hosts.append(viewport)
	var host := _mount_in(viewport, func(card_id, target_id): played.append([card_id, target_id]),
			NON_TARGET_CARD)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	var card_button := _button(host, "凝气蛊")
	assert_not_null(card_button)
	var from := card_button.get_global_rect().get_center()
	_viewport_mouse_motion(viewport, from)
	_viewport_mouse_button(viewport, from, true)
	# 超阈值（6px）出影卡
	_viewport_mouse_motion(viewport, from + Vector2(30, 0))  # < 64px 出牌距离
	await get_tree().process_frame
	assert_not_null(_find_viewport_child(viewport, "battle_drag_proxy"),
			"drag proxy must spawn once motion exceeds threshold")
	_viewport_mouse_button(viewport, from + Vector2(30, 0), false)
	assert_true(played.is_empty(), "release below cast distance must not submit")
	# 回弹后销毁（回弹 0.22s）
	await get_tree().create_timer(0.4).timeout
	assert_null(_find_viewport_child(viewport, "battle_drag_proxy"),
			"drag proxy must be freed after rebound")


# 用例 2（新增）：无指向卡拖出固定距离松手即出牌（空目标提交）。
func test_nontarget_card_drag_beyond_cast_distance_releases_to_play() -> void:
	var played: Array = []
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.gui_disable_input = false
	add_child(viewport)
	_hosts.append(viewport)
	var host := _mount_in(viewport, func(card_id, target_id): played.append([card_id, target_id]),
			NON_TARGET_CARD)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	var card_button := _button(host, "凝气蛊")
	assert_not_null(card_button)
	var from := card_button.get_global_rect().get_center()
	_viewport_mouse_motion(viewport, from)
	_viewport_mouse_button(viewport, from, true)
	_viewport_mouse_motion(viewport, from + Vector2(140, 0))  # > 64px
	_viewport_mouse_button(viewport, from + Vector2(140, 0), false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(played, [["c2", ""]], "release beyond cast distance must play the card")


# 用例 3（新增）：指向卡按住拖动 → 瞄准线出现且无影卡；未命中敌人松手 → 取消、不出牌。
func test_target_card_aim_line_spawns_and_cancels_off_enemies() -> void:
	var played: Array = []
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.gui_disable_input = false
	add_child(viewport)
	_hosts.append(viewport)
	var host := _mount_in(viewport, func(card_id, target_id): played.append([card_id, target_id]))
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	var card_button := _button(host, "月光蛊")
	assert_not_null(card_button)
	var from := card_button.get_global_rect().get_center()
	_viewport_mouse_motion(viewport, from)
	_viewport_mouse_button(viewport, from, true)
	_viewport_mouse_motion(viewport, from + Vector2(80, -60))
	await get_tree().process_frame
	assert_not_null(_find_viewport_child(viewport, "battle_aim_line"),
			"targeted card must spawn aim line, not a drag proxy")
	assert_null(_find_viewport_child(viewport, "battle_drag_proxy"),
			"targeted card must not spawn a drag proxy")
	_viewport_mouse_button(viewport, from + Vector2(80, -60), false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(played.is_empty(), "aim release off enemies must not submit")
	assert_null(_find_viewport_child(viewport, "battle_aim_line"),
			"aim line must be removed after release")


func _find_viewport_child(viewport: SubViewport, name_prefix: String) -> Node:
	for child in viewport.get_children():
		if str(child.name).begins_with(name_prefix):
			return child
	return null
```

同时**删除**旧的 `_find_proxy`（被 `_find_viewport_child` 取代）。既有用例 `test_drag_card_onto_enemy_submits_with_that_target`（指向卡拖到敌人提交）**不改**，作为瞄准释放的兼容回归。既有拖拽音效（ui_click/ui_cancel）与出牌音效不需断言（装饰反馈）。

## 9. 验收命令（headless 回归门）

```powershell
# 1) 聚焦：拖拽用例 13/13 通过
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_card_fsm.gd
# 2) 全量回归
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite unit
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite integration
powershell -ExecutionPolicy Bypass -File tools/check.ps1
# 3) 交互闭环门（dead=[] 且 no_ui_click=[] 方可交付）
powershell -File tools/godot.ps1 --headless --path . -s tools/verify_interaction_loop.gd
```

基线参考：聚焦用例在本会话已跑过一版 11/11 通过（影子拖拽旧口径）；全量 unit 1167、integration 31 为既有基线，不得低于。

## 10. 已知风险与边界

1. **重复提交**：只要进入过真拖拽（`was_dragging`），抬起一律 `set_input_as_handled()` 拦住 GUI 的 `pressed`——含「拖出 ≥64px 出牌」与「不足 64px 回弹」两种落点（原稿只吞前者，回弹落点会双发，见 §11.1）；未达阈值的普通点击不吞，照旧出牌。`_submitted_card_keys` 再兜底去重。
2. **按住期间刷新**：手势全程不调 `_refresh()`；出牌/确认刷新只发生在松手后（与既有约定一致）。
3. **屏幕中途退出**：影卡/瞄准线挂 viewport，`_exit_tree` 负责回收（§6.2 未完成前存在泄漏）。
4. **回弹中二次拖拽**：允许（独立影卡，同名自动改名 `@battle_drag_proxy@*`），`_find_viewport_child` 用 `begins_with` 匹配兼容。
5. **多敌人命中**：`_enemy_at` 按字典序首个命中矩形返回（既有行为，不改）；死亡敌人不拦截命中（既有行为，目标合法性由领域 `valid_target_ids` 裁决）。
6. 真窗手感（跟手度、回弹时长、瞄准线粗细）未经真窗验证；按 AI 契约，用户主动要求时再做键鼠复测。

## 11. 实施记录（2026-09-10 收口）

### 11.1 与计划的两处偏离

1. **（原稿 bug，测试捕获）无指向卡「真拖拽过」的抬起必须吞并**
   原稿只在 `cast_ready`（拖出 ≥ 64px）分支调 `set_input_as_handled()`。结果是：位移超 6px 触发影卡、但松手仍在源卡矩形内时，GUI 仍把这次抬起当成一次点击发 `pressed` → **同一松手既回弹又出了一张牌**。现改为按 `was_dragging`（真拖拽过）而非 `cast_ready` 吞并抬起；未达 6px 阈值的普通点击不吞，照旧走按钮 `pressed`。`test_drag_proxy_spawns_after_threshold_and_rebounds_off_enemies` 的 `assert_true(played.is_empty(), "release below cast distance must not submit")` 就是这条的回归钉子（首跑即红）。
2. **（类型标注）`_aim_line` 改用内部类类型**
   `var _aim_line: Control = null` + `_aim_line.set_line(...)` 会让 GDScript 静态分析报「Function not found in base Control」；改为 `var _aim_line: AimLineOverlay = null`，`_drag_begin` 用 `var overlay := AimLineOverlay.new()` 断链。内部类可正常引用全局 `class_name GuStyle` 的常量（与计划 §6.1 备注的担心相反）。
   另：`line_color` 默认值必须走 `GuStyle.INK_PRIMARY`，字面 Color 会被 `test_ui_rules_guard` 判红（新体系禁止硬编码色值）。

### 11.2 验收证据（headless 回归门，全绿）

| 门 | 命令 | 结果 |
|---|---|---|
| 聚焦 | `-gtest res://tests/unit/test_wenzhen_card_fsm.gd` | **13/13 passed**，52 asserts |
| UI 规则守卫 | `-gtest res://tests/unit/test_ui_rules_guard.gd` | 全通过（硬编码色值告警已消除） |
| 单元全量 | `-gdir res://tests/unit` | **1170/1170 passed**，35161 asserts，176 scripts |
| 集成 | `-gdir res://tests/integration` | **31/31 passed**，1254 asserts |
| 启动探针 | `--headless --path . --quit-after 3` | exit 0 |
| 契约漂移 | `-s tools/check_contract_drift.gd` | `contract drift: ok (157 identifiers resolved)` |
| 交互闭环 | `-s tools/verify_interaction_loop.gd` | `AUDIT[Battle] total=17 clickable=11 dead=[] no_ui_click=[]`；全屏 `dead=[]`、`no_ui_click=[]` |
| 空白检查 | `git diff --check` | 干净 |

（本轮通过 repo 脚本 `tools/test.ps1` / `tools/check.ps1` 等价链路的各步骤判定；`check.ps1` = guitkx_build + 全量 test + 启动探针 + 契约漂移 + `git diff --check`，各步 exit 0。）

### 11.3 未验证 / 遗留

- 真窗手感未验证（跟手度、回弹时长、瞄准线粗细、右键/Esc 取消时的真实事件顺序）——按 AI 契约待用户主动要求再做键鼠复测。
- 无关既有告警：`tools/verify_interaction_loop.gd` 路径下 Shop 屏报 `Image.load` 失败一次（`gu_card_view.gd:26` ← `shop_screen_view.gd:160`），exit code 仍为 0，非本任务范围，未修复。
- 运行 GUT 会在仓库根生成 `Godot/app_userdata/蛊真人/logs/godot.log`（GUT temp 输出），本任务未清理。
- **同日追加视觉整改**（真机冒烟评审）：影卡不透明放大、瞄准改弧形箭、解释栏锚定悬停卡且手势期收起——见 `docs/superpowers/plans/2026-09-10-hand-card-drag-visual-fix-plan.md`。
