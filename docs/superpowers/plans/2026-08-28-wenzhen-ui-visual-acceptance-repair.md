# 《問眞》UI 视觉验收修复实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 逐一重建并由用户签核大厅、地图、战斗三张核心母版，再用已签核母版推导全部子界面，使 Godot 实机画面达到用户认可的构图、信息密度和《問眞》视觉语言。

**Architecture:** 将已批准 HTML 母版视为构图与信息归属的裁决依据，但只在 Godot 4.7.2 + RUI 中生产化。自动测试负责锁定布局几何、资产非空、命令边界和极限数据；Godot 三视口截图负责提供视觉证据；用户对每批截图的明确“认可”是进入下一批的硬门禁，自动测试和执行者自评都不能代替用户签核。

**Tech Stack:** Godot 4.7.2、GDScript、Reactive UI Toolkit `.guitkx`、GUT、Windows Desktop、PNG/WebP 角色与场景资产、TTF/OTF 中文字体。

## Global Constraints

- 开始任一 Task 前必须阅读 `AGENTS.md`、`docs/superpowers/specs/2026-08-27-minimal-ui-redesign-design.md`、本计划的 Global Constraints、文件责任图和该 Task 全文。
- 开始任一 Task 前运行 `git status --short` 和 `git diff --ignore-cr-at-eol --name-only`；保留全部已有改动，不清理 autocrlf 噪声，不覆盖其他会话的真实差异。
- 旧计划 Task 8 当前没有验收报告，也没有用户视觉签核，状态固定为“未完成”；现有 48 张截图只是失败基线，不是验收证据。
- 视觉裁决依据固定为 `.superpowers/brainstorm/1529-1787814710/content/hall-master-v4-breathing.html`、`map-master-v3-focus.html`、`battle-master-v4-sts-architecture.html` 和用户附图 `C:/Users/Zachary/AppData/Local/Temp/codex-clipboard-187a1ca3-a01b-4cb9-b0fe-c0795789ff9b.png`。
- 正式品牌固定为横排繁体《問眞》；标题上下留白不得截断人物头部、视线、姿态或动作方向的空间延伸。
- 参考《杀戮尖塔》的信息架构、固定信息位置、多分支地图、敌人意图和卡牌交互，不参考其暗色地牢、厚边框、拟物按钮、卡通比例或美术风格。
- 视觉固定为宣纸白、近黑墨色、1px 发丝线和克制朱砂；契约蓝与异变黄只表达各自语义；禁止装饰性卡片堆叠、卡片嵌套、Emoji 图标和纯文字人物占位。
- UI 只读取 snapshot 并提交 command，不得直接修改 `RunState`、随机数、存档、敌人、地图可达性或结局；保留 stale-command 原子拒绝、危险预检、死亡可预见和二次确认。
- 多敌必须来自真实领域状态，每名敌人独立显示意图、生命、护盾和状态；不得由 UI 复制单敌或隐藏公开意图。
- 生产 UI 只编辑 `.guitkx` 源文件；禁止手动编辑生成的 `ui/**/*.gd`。需要布局或输入行为时，优先使用 `.guitkx` 和既有手写 presentation helper。
- 不得修改 `分支：六卷精编版/` 和 `肉鸽设计-原始数据/`。
- 每个实现 Task 必须先写能因当前缺陷失败的测试并实际看到预期失败，再做最小实现；测试未运行或未通过时不得声称完成。
- 所有视觉 Task 必须捕获 1920x1080、1366x768、1280x720；最终回归另加 2560x1440。不得用 HTML 截图替代 Godot 实机截图。
- 每批截图必须包含默认、极限数据、Tooltip/确认/禁用或空状态中的相关状态；截图索引必须写明场景、分辨率、数据夹具和母版对应点。
- 每个“用户视觉签核门”都必须停止执行并展示该批截图。只有用户明确回复“认可”或等价批准措辞，才可在验收记录写 `APPROVED` 并进入下一 Task；沉默、执行者自评、测试通过、旧对话中的总体认可均不能代替本批签核。
- 用户提出视觉修改时，在当前 Task 内新增失败断言或截图状态、修复并重新提交整批截图；不得把未解决反馈挂到后续 Task。
- 当前工作树含跨 Task 未提交真实改动。只有 `git diff --ignore-cr-at-eol` 能证明暂存内容完全属于当前 Task 时才允许提交；否则记录完成证据但不提交，不得使用 `git add ui/screens` 等宽泛暂存命令。

---

## 已知失败基线

- 大厅 `.superpowers/ui_captures/wenzhen/01_hall_with_save_1920x1080.png`：内容缩在左上，无角色/地点主视觉，《問眞》没有建立第一视口横向构图。
- 地图 `.superpowers/ui_captures/wenzhen/07_map_current_1920x1080.png`：节点仍按层横排成卡片，无真实连线路径画布、候选路径聚焦和约 2.5 层镜头。
- 战斗 `.superpowers/ui_captures/wenzhen/22_battle_3_enemies_1920x1080.png`：HUD、战场、手牌只是小面板，无可辨角色与敌阵，手牌不是下视界主要决策空间。
- 子界面 `.superpowers/ui_captures/wenzhen/34_shop_1920x1080.png`、`40_refine_1920x1080.png`、`31_ending_1920x1080.png`：只完成局部去卡片化，没有继承母版的角色关系、操作台比例和路线叙事。

## 文件责任图

- `docs/superpowers/reports/2026-08-28-wenzhen-ui-visual-acceptance.md`：唯一验收账本；记录母版要求、命令、截图、用户原话、状态和残余风险。
- `tests/helpers/wenzhen_layout_assertions.gd`：共享几何断言，只读取 Control 的全局矩形、可见性、文字和纹理，不包含业务逻辑。
- `tests/unit/test_wenzhen_visual_acceptance_contract.gd`：截图场景覆盖、资产清单、字体与正式图标契约。
- `scripts/ui_capture.gd`：唯一实机截图驱动；使用正式 snapshot/command 形状和确定性夹具，不增加生产 `force_*` 接口。
- `assets/wenzhen/fonts/`：经许可证核验并打包的标题字体和正文字体。
- `assets/wenzhen/icons/`：同一线性风格的正式图标，图标语义由文件名固定。
- `assets/wenzhen/hall/`：大厅人物与地点主视觉；保留人物朝向的负空间。
- `assets/wenzhen/actors/`：玩家与敌人透明背景立绘或序列帧；不得使用文字框、矩形或纯色剪影。
- `assets/wenzhen/cards/`：蛊牌插画；允许同一原型复用，但不得为空白色块。
- `assets/wenzhen/assets_manifest.json`：每项资产的 ID、相对路径、用途、来源、许可证、作者/生成方式和朝向。
- `scripts/presentation/gu_style.gd`：视觉 token 和稳定尺寸的唯一来源，不承载页面构图。
- `ui/widgets/gu_top_bar.guitkx`：跨局内页面的全局状态栏，只展示跨场景事实。
- `ui/widgets/gu_card.guitkx`、`gu_enemy_actor.guitkx`、`gu_battle_hand.guitkx`：卡牌固定信息、敌方局部信息和下视界操作台。
- `scripts/presentation/route_tree_canvas.gd`：只绘制 snapshot 已给出的节点、连线和相机状态，不计算可达性。
- `ui/screens/hall_view.guitkx`：大厅以及流派、契约、图鉴、手记、设置等大厅子视图。
- `ui/screens/map_screen.guitkx`：多分支路线镜头和节点详情。
- `ui/screens/battle_screen.guitkx`：上 HUD、中战场、下手牌的固定三视界。
- `ui/screens/encounter_screen.guitkx`、`npc_screen.guitkx`、`shop_screen.guitkx`：人物/事件型子界面。
- `ui/screens/rest_screen.guitkx`、`refine_screen.guitkx`、`reward_screen.guitkx`：选择/操作台型子界面。
- `ui/screens/ending_screen.guitkx`：路线与六要素纵向复盘。

## Task 1: 建立可证伪的视觉验收基线

**Files:**
- Create: `docs/superpowers/reports/2026-08-28-wenzhen-ui-visual-acceptance.md`
- Create: `tests/helpers/wenzhen_layout_assertions.gd`
- Create: `tests/unit/test_wenzhen_visual_acceptance_contract.gd`
- Modify: `scripts/ui_capture.gd`

**Interfaces:**
- Consumes: 现有 `RunController._snapshot_for(view_name)`、`_build_commands(view_name)` 和 `.superpowers/ui_captures/wenzhen/`。
- Produces: `WenzhenLayoutAssertions.rect(node) -> Rect2`、`assert_inside(test, child, parent, margin)`、`assert_no_overlap(test, a, b, allowance)`；截图名由批次、场景、状态和宽高组成，例如 `core_hall_running_1920x1080.png`；验收状态只允许 `PENDING/CHANGES_REQUESTED/APPROVED`。

- [ ] **Step 1: 写当前必然失败的验收契约测试**

```gdscript
func test_capture_matrix_covers_every_required_screen_and_viewport() -> void:
	var required := ["hall", "map", "battle", "encounter", "npc", "shop", "rest", "refine", "reward", "school", "contract", "codex", "journal", "settings", "ending"]
	for scene_name in required:
		assert_true(UiCapture.capture_ids().has(scene_name), "missing capture: %s" % scene_name)
	assert_eq(UiCapture.viewport_sizes(), [Vector2i(1920, 1080), Vector2i(1366, 768), Vector2i(1280, 720)])

func test_old_task_8_cannot_be_marked_approved_without_user_quote() -> void:
	var report := FileAccess.get_file_as_string("res://docs/superpowers/reports/2026-08-28-wenzhen-ui-visual-acceptance.md")
	assert_true(report.contains("Status: PENDING"))
	assert_false(report.contains("Status: APPROVED\nUser quote: (missing)"))
```

- [ ] **Step 2: 运行测试并确认因覆盖清单和报告不存在而失败**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_visual_acceptance_contract.gd`

Expected: FAIL，明确指出缺少验收报告或 `school/contract/codex/journal/settings` 捕获 ID。

- [ ] **Step 3: 实现只读几何断言 helper**

```gdscript
extends RefCounted
class_name WenzhenLayoutAssertions

static func rect(node: Control) -> Rect2:
	return node.get_global_rect()

static func assert_inside(test: GutTest, child: Control, parent: Control, margin := 0.0) -> void:
	var inner := parent.get_global_rect().grow(-margin)
	test.assert_true(inner.encloses(child.get_global_rect()), "%s must stay inside %s" % [child.name, parent.name])

static func assert_no_overlap(test: GutTest, a: Control, b: Control, allowance := 0.0) -> void:
	var intersection := a.get_global_rect().intersection(b.get_global_rect())
	test.assert_lte(intersection.get_area(), allowance, "%s overlaps %s" % [a.name, b.name])
```

- [ ] **Step 4: 将捕获脚本改成公开静态场景矩阵**

`capture_ids()` 返回文件责任图列出的 16 个屏幕 ID；`viewport_sizes()` 返回三个固定视口；每个条目还要声明 `states`，大厅含有档/无档，地图含当前/候选聚焦/历史收束，战斗含 1/2/3/4 敌与 5/7 手牌，所有子界面至少含默认与危险/空/极限状态之一。捕获脚本只构造 snapshot 形状并挂载正式组件，不直接写领域状态。

- [ ] **Step 5: 创建验收账本并录入失败基线**

报告为每一批建立 `Status: PENDING`、`Automated evidence`、`Screenshot index`、`User quote`、`Requested changes`、`Residual risk` 六个固定字段；录入“已知失败基线”的六张截图，并明确写“旧 Task 8 未完成”。

- [ ] **Step 6: 验证验收基础**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_visual_acceptance_contract.gd`

Run: `git diff --check -- docs/superpowers/reports/2026-08-28-wenzhen-ui-visual-acceptance.md tests/helpers/wenzhen_layout_assertions.gd tests/unit/test_wenzhen_visual_acceptance_contract.gd scripts/ui_capture.gd`

Expected: PASS；报告所有批次仍为 `PENDING`，没有伪造用户引语。

## Task 2: 修复全屏壳、字体、图标和正式视觉资产契约

**Files:**
- Create: `assets/wenzhen/assets_manifest.json`
- Create: `assets/wenzhen/fonts/LXGWWenKai-Regular.ttf`
- Create: `assets/wenzhen/fonts/NotoSansSC-Regular.ttf`
- Create: `assets/wenzhen/fonts/OFL-LXGW-WenKai.txt`
- Create: `assets/wenzhen/fonts/OFL-Noto-Sans-SC.txt`
- Create: `assets/wenzhen/icons/map.svg`
- Create: `assets/wenzhen/icons/deck.svg`
- Create: `assets/wenzhen/icons/settings.svg`
- Create: `assets/wenzhen/icons/journal.svg`
- Create: `assets/wenzhen/icons/codex.svg`
- Create: `assets/wenzhen/icons/intent_attack.svg`
- Create: `assets/wenzhen/icons/intent_defend.svg`
- Create: `assets/wenzhen/icons/intent_buff.svg`
- Create: `assets/wenzhen/icons/intent_debuff.svg`
- Create: `assets/wenzhen/hall/first-life-character.webp`
- Create: `assets/wenzhen/hall/qing-mao-mountain.webp`
- Create: `assets/wenzhen/actors/player-fang-yuan.webp`
- Create: `assets/wenzhen/actors/enemy-ridge-hound.webp`
- Create: `assets/wenzhen/actors/enemy-beast-swarm.webp`
- Create: `assets/wenzhen/actors/enemy-bandit.webp`
- Create: `assets/wenzhen/actors/enemy-elder.webp`
- Create: `assets/wenzhen/cards/gu-blood-fang.webp`
- Create: `assets/wenzhen/cards/gu-moonlight.webp`
- Create: `assets/wenzhen/cards/gu-stone-skin.webp`
- Create: `assets/wenzhen/cards/gu-soul-call.webp`
- Create: `assets/wenzhen/cards/gu-blood-sacrifice.webp`
- Modify: `scripts/presentation/gu_style.gd`
- Modify: `assets/theme/gu_theme.tres`
- Modify: `ui/widgets/gu_top_bar.guitkx`
- Modify: `ui/widgets/gu_card.guitkx`
- Modify: `ui/widgets/gu_enemy_actor.guitkx`
- Test: `tests/unit/test_wenzhen_visual_acceptance_contract.gd`

**Interfaces:**
- Consumes: 规格 token `PAPER #ECE9DF`、`INK #171814`、`RULE #AAA89F`、`CINNABAR #9C332D`、`CONTRACT_BLUE #315F73`、`ANOMALY_YELLOW #936F1E`、`JADE #3F7063`。
- Produces: `GuStyle.TITLE_FONT`、`BODY_FONT`、`SCREEN_MARGIN=32`、`TOP_BAR_HEIGHT=72`；manifest 中每项固定含 `id/path/kind/source/license/author/facing`。

- [ ] **Step 1: 扩充资产和全屏几何失败测试**

```gdscript
func test_required_visual_assets_are_real_and_licensed() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/wenzhen/assets_manifest.json"))
	for kind in ["font_title", "font_body", "hall_character", "hall_place", "player_actor", "enemy_actor", "card_art", "icon"]:
		assert_true(_entries_of_kind(manifest, kind).size() > 0, "missing %s" % kind)
	for item in manifest.get("assets", []):
		assert_true(ResourceLoader.exists("res://" + str(item["path"])))
		assert_false(str(item.get("license", "")).is_empty())

func test_shared_shell_fills_viewport_without_corner_shrinkage() -> void:
	var host := _mount_shell(Vector2i(1920, 1080))
	assert_gte(host.get_global_rect().size.x, 1888.0)
	assert_gte(host.get_global_rect().size.y, 1048.0)
```

- [ ] **Step 2: 运行测试并确认当前只有旧按钮/血条位图而失败**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_visual_acceptance_contract.gd`

Expected: FAIL，指出 manifest、打包字体、人物或卡图缺失。

- [ ] **Step 3: 建立正式资产清单**

标题使用 `LXGWWenKai-Regular.ttf`，正文使用 `NotoSansSC-Regular.ttf`；两者必须从各自官方发布源取得并连同原始 OFL 文本入库，manifest 写明官方 URL、作者和 `SIL Open Font License 1.1`。九个图标统一为 24x24、1.5px 线宽、`currentColor` 语义；两张大厅图、五张角色图长边至少 1600px，敌人透明背景可辨姿态；五张卡图至少 512x320。AI 生成位图的 `source` 写 `generated`、`license` 写实际生成服务授予项目的可用条款、`author` 写生成工具及日期，不能伪造传统画师署名；网络占位图不得进入生产 manifest。

- [ ] **Step 4: 让共享组件消费资产 ID 而非占位文字**

`GuCard.art_id` 经 manifest resolver 得到纹理，加载失败显示带资源 ID 的开发期错误面，不显示纯色空白；`GuEnemyActor.actor_id` 同理。正式图标按钮必须有可读 `tooltip_text` 和键盘焦点态；顶栏高度固定 72px，根 Control 使用 full rect anchors。

- [ ] **Step 5: 验证基础资产与既有公共组件**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_visual_acceptance_contract.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_visual_tokens.gd`

Expected: PASS；字体和位图均由 `res://assets/wenzhen/` 加载，截图像素不是纯色/透明占位。

## Task 3: 按认可母版重建大厅并取得用户签核

**Files:**
- Modify: `ui/screens/hall_view.guitkx`
- Modify: `tests/unit/test_wenzhen_hall_screen.gd`
- Modify: `scripts/ui_capture.gd`
- Modify: `docs/superpowers/reports/2026-08-28-wenzhen-ui-visual-acceptance.md`

**Interfaces:**
- Consumes: Title snapshot 的 `brand_title/has_save/primary_action/run_summary` 和既有大厅 commands。
- Produces: 命名区域 `hall_identity/hall_art/hall_primary/hall_archive`；唯一主动作保持 `continue_run|open_schools`。

- [ ] **Step 1: 写能否定当前左上角小面板的布局测试**

```gdscript
func test_hall_matches_approved_horizontal_composition() -> void:
	var host := _mount_hall(Vector2i(1920, 1080), _running_snapshot())
	var identity := _named(host, "hall_identity")
	var art := _named(host, "hall_art")
	var primary := _named(host, "hall_primary")
	assert_gte(host.get_global_rect().size.x, 1888.0)
	assert_lt(identity.get_global_rect().get_center().x, primary.get_global_rect().get_center().x)
	assert_gte(art.get_global_rect().size.x, host.get_global_rect().size.x * 0.30)
	assert_gte(art.get_global_rect().size.y, host.get_global_rect().size.y * 0.62)
	assert_eq(_primary_buttons(host).size(), 1)
	assert_eq(_visible_text(host, "問眞"), 1)
```

- [ ] **Step 2: 运行并确认当前大厅因尺寸、主视觉或命名区域失败**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_hall_screen.gd`

Expected: FAIL，至少命中 `hall_art` 缺失或画面占比不足。

- [ ] **Step 3: 实现母版不可变构图**

横排《問眞》作为最大一级标题；标题上下各保留不小于标题字高 0.65 倍的净空；人物/地点占首屏宽度 30% 以上、高度 62% 以上，主体不被裁切且朝向页面决策区；有档时唯一主动作“续入此世”，无档时唯一主动作“开启今世”；run 摘要只保留地点、阶段、生命/寿元风险、关键契约/异变和最近不可逆选择；图鉴、手记、设置退到边缘档案导航。禁止用大卡片包裹标题或主动作。

- [ ] **Step 4: 捕获大厅完整状态矩阵**

Run: `powershell -ExecutionPolicy Bypass -File tools/godot.ps1 --path . -s res://scripts/ui_capture.gd -- --batch hall`

Expected: 生成有档、无档、长摘要、键盘焦点四种状态，每种 1920x1080、1366x768、1280x720，共 12 张；无裁切、重叠、空白纹理。

- [ ] **Step 5: 更新报告并执行用户视觉签核门**

在报告列出 12 张截图和母版逐项对照；向用户展示至少三个分辨率的有档大厅和 1920x1080 无档大厅，然后停止。用户要求修改则写 `Status: CHANGES_REQUESTED` 并回到 Step 1；只有用户明确认可后，原样记录其回复并写 `Status: APPROVED`。

## Task 4: 按认可母版重建多分支地图并取得用户签核

**Files:**
- Modify: `ui/screens/map_screen.guitkx`
- Modify: `scripts/presentation/route_tree_canvas.gd`
- Modify: `tests/unit/test_wenzhen_map_screen.gd`
- Modify: `scripts/ui_capture.gd`
- Modify: `docs/superpowers/reports/2026-08-28-wenzhen-ui-visual-acceptance.md`

**Interfaces:**
- Consumes: Map snapshot 节点 `id/type/label/layer/next_ids/reachable/visited/current/visibility`；不改变 `travel/view_node/save_run`。
- Produces: 命名区域 `map_camera/map_world/map_paths/map_inspector`；候选聚焦只改变显示权重，不改变可达性。

- [ ] **Step 1: 写真实拓扑和 2.5 层镜头失败测试**

```gdscript
func test_map_uses_connected_canvas_instead_of_layer_card_rows() -> void:
	var host := _mount_progressed_map(Vector2i(1920, 1080))
	assert_true(_named(host, "map_world").get_global_rect().size.y > _named(host, "map_camera").get_global_rect().size.y)
	assert_gte(_visible_path_segments(host).size(), 6)
	assert_gte(_out_degree(host, "current"), 2)
	assert_lte(_visible_layer_span(host), 3)
	assert_gte(_visible_layer_span_fraction(host), 2.35)
	assert_lte(_visible_layer_span_fraction(host), 2.75)

func test_progressed_map_hides_unchosen_historical_siblings() -> void:
	var host := _mount_progressed_map(Vector2i(1920, 1080))
	assert_eq(_visible_visited_route_count(host), 1)
	assert_eq(_visible_unchosen_past_nodes(host), 0)
```

- [ ] **Step 2: 运行并确认当前横排节点卡片缺少连线画布而失败**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_map_screen.gd`

Expected: FAIL，指出 `map_world` 不大于镜头、路径段不足或层级跨度错误。

- [ ] **Step 3: 实现大画布、小镜头和候选聚焦**

当前节点置于镜头中下部并保持可读尺寸；未来完整拓扑在大于视口的画布上由 1px 路径连接；直接可达节点保持主权重，选择某候选后只将其可达未来路径升为朱砂/墨色，其他未来保留但降权；已走层级只留实际路线与“已行之路”，同层未选历史节点隐藏；不可达节点不绑定 travel command。窄屏保持节点物理尺寸，通过平移检查未来，不压缩整张图。

- [ ] **Step 4: 捕获地图完整状态矩阵**

Run: `powershell -ExecutionPolicy Bypass -File tools/godot.ps1 --path . -s res://scripts/ui_capture.gd -- --batch map`

Expected: 当前镜头、候选 A 聚焦、候选 B 聚焦、未来平移、历史收束、长节点名六种状态，各三视口，共 18 张；每张连线与节点非空，未来分支没有被详情面板遮挡。

- [ ] **Step 5: 运行地图规则回归**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_map_screen.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_map_network.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_five_layer_map_contract.gd`

Expected: PASS；直接邻居门禁、Boss 收敛和 seeded topology 不变。

- [ ] **Step 6: 更新报告并执行用户视觉签核门**

展示 1920x1080 的当前、候选聚焦、历史收束，以及 1280x720 的候选聚焦。用户要求修改则记录并回到 Step 1；只有明确认可后写 `APPROVED`，才可进入战斗重建。

## Task 5: 按认可母版重建三视界战斗并取得用户签核

**Files:**
- Modify: `ui/screens/battle_screen.guitkx`
- Modify: `ui/widgets/gu_enemy_actor.guitkx`
- Modify: `ui/widgets/gu_battle_hand.guitkx`
- Modify: `ui/widgets/gu_card.guitkx`
- Modify: `tests/unit/test_wenzhen_battle_screen.gd`
- Modify: `tests/unit/test_wenzhen_card_fsm.gd`
- Modify: `scripts/ui_capture.gd`
- Modify: `docs/superpowers/reports/2026-08-28-wenzhen-ui-visual-acceptance.md`

**Interfaces:**
- Consumes: Battle snapshot 的 `player/enemies/hand/piles/soul_ops/resources/contracts/anomalies/death_lines` 和既有版本化 commands。
- Produces: 固定区域 `battle_hud/battle_field/battle_hand`；每个敌人节点名使用 `enemy_actor_` 加真实 `enemy_id`，例如 `enemy_actor_battle_7_e2`；FSM 仍为 `idle/hover/drag_start/dragging/target_select/play_success/drag_cancel`。

- [ ] **Step 1: 写画面比例、复数敌阵和手牌可读性失败测试**

```gdscript
func test_battle_three_planes_occupy_the_full_screen() -> void:
	var host := _mount_battle(_snapshot_with_enemies(3), Vector2i(1920, 1080))
	var hud := _named(host, "battle_hud").get_global_rect()
	var field := _named(host, "battle_field").get_global_rect()
	var hand := _named(host, "battle_hand").get_global_rect()
	assert_lte(hud.size.y / host.size.y, 0.10)
	assert_gte(field.size.y / host.size.y, 0.48)
	assert_gte(hand.size.y / host.size.y, 0.27)
	assert_lt(_player_rect(host).get_center().x, _enemy_group_rect(host).get_center().x)

func test_three_enemy_formation_and_seven_cards_remain_readable() -> void:
	var host := _mount_battle(_snapshot_with_enemies_and_cards(3, 7), Vector2i(1366, 768))
	assert_eq(_enemy_actor_count(host), 3)
	assert_eq(_visible_intent_count(host), 3)
	assert_true(_enemy_rects_do_not_overlap_local_info(host))
	for card in _cards(host):
		assert_gte(card.get_global_rect().size.x, 118.0)
		assert_true(_card_regions_visible(card, ["cost", "title", "art", "effect"]))
```

- [ ] **Step 2: 运行并确认当前小型面板、人物占位和小卡失败**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_battle_screen.gd`

Expected: FAIL，至少中视界/下视界占比、敌阵局部信息或卡宽不满足。

- [ ] **Step 3: 实现固定上中下三视界**

上视界仅放全局资源、契约、异变、死亡线和低频图标入口；中视界左侧为真实玩家立绘，右侧为真实敌方阵型，生命/护盾/状态贴各自角色，公开意图在各敌人头顶；下视界中央为 5 至 7 张可读卡牌，真元靠左，抽/弃/耗牌堆分列，结束回合固定右下。1 敌居右中放大；2 敌前后错位；3 敌浅弧排列；4+ 两排紧凑排列，禁止用“余敌 N”代替公开意图。

- [ ] **Step 4: 保持卡牌 FSM 与视觉层解耦**

Hover 只抬升并打开独立 Tooltip；Dragging 不改变手牌快照；TargetSelect 只高亮 `valid_target_ids` 且不遮挡意图；ESC、右键和拖回手牌均进入 DragCancel；不可支付牌不能进入 DragStart；危险牌在合法目标确定后显示领域预检确认，取消后原位归还。所有提交继续携带 `state_version/card_id/target_id`。

- [ ] **Step 5: 捕获战斗完整状态矩阵**

Run: `powershell -ExecutionPolicy Bypass -File tools/godot.ps1 --path . -s res://scripts/ui_capture.gd -- --batch battle`

Expected: 1/2/3/4 敌、5/7 手牌、Hover、TargetSelect、不可支付、危险确认、长意图/多状态共 11 种状态，各三视口，共 33 张；角色纹理非空，意图、生命、护盾和状态无互相遮挡。

- [ ] **Step 6: 运行战斗行为回归**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_battle_screen.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_card_fsm.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_multi_enemy_battle.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_v3_ui_sync.gd`

Expected: PASS；非法目标、过期命令、不可支付和危险确认均保持原子门禁。

- [ ] **Step 7: 更新报告并执行用户视觉签核门**

展示 1920x1080 单敌、双敌、三敌、七手牌目标选择和危险确认，以及 1280x720 三敌。用户要求修改则记录并回到 Step 1；只有明确认可后写 `APPROVED`，三张核心母版才算可用于推导子界面。

## Task 6: 推导事件、NPC、商店并取得用户签核

**Files:**
- Modify: `ui/screens/encounter_screen.guitkx`
- Modify: `ui/screens/npc_screen.guitkx`
- Modify: `ui/screens/shop_screen.guitkx`
- Modify: `tests/unit/test_wenzhen_secondary_screens.gd`
- Modify: `scripts/ui_capture.gd`
- Modify: `docs/superpowers/reports/2026-08-28-wenzhen-ui-visual-acceptance.md`

**Interfaces:**
- Consumes: 已签核大厅的叙事留白、已签核战斗的左右人物关系、现有各屏 snapshot/commands。
- Produces: 三屏统一命名区域 `subject_region/decision_region/detail_layer`，不增加导航状态。

- [ ] **Step 1: 写人物关系、交易信息和单决策面失败测试**

```gdscript
func test_people_and_trade_screens_derive_from_approved_masters() -> void:
	for fixture in _people_screen_fixtures():
		var host := _mount(fixture)
		assert_lt(_named(host, "subject_region").get_global_rect().get_center().x, _named(host, "decision_region").get_global_rect().get_center().x)
		assert_gte(_named(host, "subject_region").get_global_rect().size.x, host.size.x * 0.28)
		assert_eq(_primary_decision_regions(host), 1)
		assert_eq(_card_inside_card_count(host), 0)

func test_shop_keeps_price_limits_and_inflation_on_each_offer() -> void:
	var host := _mount_shop(_max_shop_snapshot())
	for offer in _offer_rows(host):
		assert_true(_has_local_fields(offer, ["price", "remaining", "inflation"]))
```

- [ ] **Step 2: 运行并确认现有子界面没有真实人物区或本地交易信息而失败**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_secondary_screens.gd`

Expected: FAIL，明确指出 `subject_region`、局部价格字段或嵌套卡片问题。

- [ ] **Step 3: 实现三屏推导规则**

事件使用大厅叙事留白，已知后果贴选择项常驻；NPC/商店左侧为人物、立场和关系，右侧为交涉/商品/服务；价格、剩余次数、通胀和支付类型贴各交易项；寿元、魂魄、反噬等危险选择复用朱砂确认层。Tooltip 只放解释，不隐藏做决定所需的精确后果。

- [ ] **Step 4: 验证并捕获三屏**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_secondary_screens.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_t5a_confirm_toast.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/godot.ps1 --path . -s res://scripts/ui_capture.gd -- --batch people_trade`

Expected: PASS；事件默认/危险、NPC 默认/无货、商店最大货架/危险支付各三视口，共 18 张。

- [ ] **Step 5: 更新报告并执行用户视觉签核门**

展示每屏 1920x1080 默认态、商店 1280x720 最大货架和事件危险确认。未明确认可不得进入 Task 7。

## Task 7: 推导休整、炼蛊、奖励并取得用户签核

**Files:**
- Modify: `ui/screens/rest_screen.guitkx`
- Modify: `ui/screens/refine_screen.guitkx`
- Modify: `ui/screens/reward_screen.guitkx`
- Modify: `tests/unit/test_wenzhen_secondary_screens.gd`
- Modify: `scripts/ui_capture.gd`
- Modify: `docs/superpowers/reports/2026-08-28-wenzhen-ui-visual-acceptance.md`

**Interfaces:**
- Consumes: 已签核大厅的单主动作纪律、已签核战斗的下视界操作台和固定卡牌位置、现有各屏 snapshot/commands。
- Produces: `choice_surface` 用于休整/奖励，`refine_inputs/refine_output/refine_risk` 用于炼蛊。

- [ ] **Step 1: 写互斥选择、炼蛊同屏预览和槽满取舍失败测试**

```gdscript
func test_rest_refine_reward_have_one_complete_decision_surface() -> void:
	var rest := _mount_rest(_required_choice_snapshot())
	assert_eq(_visible_mutually_exclusive_choices(rest), 2)
	assert_eq(_primary_decision_regions(rest), 1)
	var refine := _mount_refine(_curse_inheritance_snapshot())
	for region in ["refine_inputs", "refine_output", "refine_risk"]:
		assert_true(_named(refine, region).is_visible_in_tree())
	var reward := _mount_reward(_full_inventory_snapshot())
	assert_true(_has_explicit_replace_or_decline(reward))
```

- [ ] **Step 2: 运行并确认现有炼蛊比例和奖励取舍不足而失败**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_secondary_screens.gd`

Expected: FAIL，指出命名操作台区域、同屏风险或显式槽满取舍缺失。

- [ ] **Step 3: 实现三屏推导规则**

休整将互斥选项平铺为一个决策面，不做多层卡片；炼蛊沿用战斗下视界，把输入、产物、成功率、诅咒继承、精确代价和失败结果同屏显示，模式使用分段控件；奖励复用完整卡面，槽满时先选择替换/拆解/放弃并走确认，空池只显示不阻断的小字说明。

- [ ] **Step 4: 验证并捕获三屏**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_secondary_screens.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_rest_hard_choice.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_v3_refinement_and_knowledge.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/godot.ps1 --path . -s res://scripts/ui_capture.gd -- --batch decision_tools`

Expected: PASS；休整二选一、炼蛊默认/诅咒继承/危险确认、奖励默认/槽满/空池各三视口，共 21 张。

- [ ] **Step 5: 更新报告并执行用户视觉签核门**

展示三屏 1920x1080 默认态、炼蛊危险确认和 1280x720 槽满奖励。未明确认可不得进入 Task 8。

## Task 8: 推导大厅档案、开局选择、设置和结算并取得用户签核

**Files:**
- Modify: `ui/screens/hall_view.guitkx`
- Modify: `ui/screens/ending_screen.guitkx`
- Modify: `tests/unit/test_wenzhen_hall_screen.gd`
- Modify: `tests/unit/test_wenzhen_secondary_screens.gd`
- Modify: `scripts/ui_capture.gd`
- Modify: `docs/superpowers/reports/2026-08-28-wenzhen-ui-visual-acceptance.md`

**Interfaces:**
- Consumes: 大厅内现有 `School/Contract/Codex/Journal/Settings` 模式及 commands，Ending snapshot 的六要素、路线、契约和 DDA 复盘。
- Produces: 阅读型区域 `archive_nav/archive_content`、开局选择 `opening_choices/opening_commit`、设置列表 `settings_list`、结算 `ending_route/ending_review`。

- [ ] **Step 1: 写档案阅读、设置控件和结算路线失败测试**

```gdscript
func test_hall_subviews_use_reading_and_standard_control_layouts() -> void:
	for mode in ["school", "contract", "codex", "journal", "settings"]:
		var host := _mount_hall_mode(mode)
		assert_eq(_card_inside_card_count(host), 0)
		assert_gte(_main_content_width(host), host.size.x * 0.56)
	assert_true(_settings_use_native_control_kinds(_mount_hall_mode("settings"), ["slider", "toggle", "segmented"]))

func test_ending_reads_as_route_and_chapters_not_dashboard_cards() -> void:
	var host := _mount_ending(_max_recap_snapshot())
	assert_true(_named(host, "ending_route").is_visible_in_tree())
	assert_true(_named(host, "ending_review").is_visible_in_tree())
	assert_eq(_dashboard_card_grid_count(host), 0)
	assert_true(_six_review_elements_visible(host))
```

- [ ] **Step 2: 运行并确认当前子视图/结算没有完整阅读构图而失败**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_hall_screen.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_secondary_screens.gd`

Expected: FAIL，指出阅读区域、标准控件或路线章节缺失。

- [ ] **Step 3: 实现大厅子视图和结算推导规则**

流派/契约保持一个选择主体和一个提交动作，代价与收益同屏；图鉴/手记改为内容优先的阅读界面，筛选和导航安静常驻；设置只用标准列表、滑块、开关、分段控件和图标按钮；结算以实际路线为纵向骨架，六要素、关键选择、得失、解锁、契约与 DDA 按章节展开，不做仪表盘卡片矩阵，不出现读档/回滚入口。

- [ ] **Step 4: 验证并捕获全部大厅子视图和结算**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_hall_screen.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_wenzhen_secondary_screens.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_t5c_ending_review.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_settings_dda.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/godot.ps1 --path . -s res://scripts/ui_capture.gd -- --batch archives_ending`

Expected: PASS；流派、契约、图鉴列表/详情、手记列表/详情、设置、普通结算、长路线结算各三视口，共 30 张。

- [ ] **Step 5: 更新报告并执行用户视觉签核门**

展示每个子视图 1920x1080、1280x720 设置和长路线结算。用户提出修改时整批重新捕获；只有明确认可后写 `APPROVED`。

## Task 9: 全流程、极限数据、四视口和发布构建回归

**Files:**
- Modify: `tests/integration/test_wenzhen_ui_flow.gd`
- Modify: `scripts/playthrough_smoke.gd`
- Modify: `scripts/ui_capture.gd`
- Modify: `docs/superpowers/reports/2026-08-28-wenzhen-ui-visual-acceptance.md`

**Interfaces:**
- Consumes: Tasks 3-8 全部已签核屏幕，正式 controller commands 和 Release 导出链路。
- Produces: 大厅到结算的行为证据、2560x1440 补充截图、Release 调试门禁证据。

- [ ] **Step 1: 补强集成测试，使其验证真实可见状态而非字符串存在**

```gdscript
func test_signed_off_hall_map_battle_and_ending_flow_uses_formal_commands() -> void:
	controller.start_new_run(101, "force", [])
	assert_eq(controller.current_view_name(), "Map")
	_travel_to_multi_enemy_combat_with_formal_commands(controller)
	var before := controller._snapshot_for("Battle")
	assert_gte(before.get("enemies", []).size(), 2)
	_play_valid_target_card_with_snapshot_version(controller, before)
	assert_eq(controller.current_view_name(), "Battle")
	_reach_protected_ending_with_formal_commands(controller)
	assert_eq(controller.current_view_name(), "Ending")
```

- [ ] **Step 2: 运行集成测试并确认新增可见状态/流程断言先失败**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/integration/test_wenzhen_ui_flow.gd`

Expected: 新增断言在夹具或正式命令流尚未覆盖处 FAIL；不得通过新增生产 `force_*` 方法解决。

- [ ] **Step 3: 最小修复捕获夹具和试玩脚本**

只允许修复测试目录数据、正式命令调用顺序、等待帧和截图状态构造；若发现生产行为缺陷，回到拥有该文件的前置 Task 修复并重新走对应用户签核，不在本 Task 偷渡 UI 重构。

- [ ] **Step 4: 运行完整自动验证**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/integration/test_wenzhen_ui_flow.gd`

Run: `powershell -ExecutionPolicy Bypass -File tools/check.ps1`

Run: `git diff --ignore-cr-at-eol --check`

Expected: integration PASS；完整 unit/integration 无新增失败或 risky；空白检查无新增错误。

- [ ] **Step 5: 运行四视口总捕获和像素检查**

Run: `powershell -ExecutionPolicy Bypass -File tools/godot.ps1 --path . -s res://scripts/ui_capture.gd -- --batch final --viewports 1920x1080,1366x768,1280x720,2560x1440`

Expected: 16 个屏幕 ID 全部生成四视口默认态；核心三屏额外生成其极限态；像素检查拒绝纯色、全透明、缺失人物纹理和空路径画布。

- [ ] **Step 6: 运行 Windows Release 导出**

Run: `powershell -ExecutionPolicy Bypass -File tools/export.ps1`

Expected: `build/win/gu-zhenren.exe` 生成；Release 中 F12 不显示调试面板；包内不含 `tests/`、`docs/`、`.superpowers/`、语料和 UI 捕获。

- [ ] **Step 7: 更新验收报告的命令与风险证据**

逐条记录命令、退出码、测试统计、截图索引、Release 路径、调试门禁结果和残余风险。未执行的检查必须写 `NOT RUN`，不得写“通过”。

## Task 10: 用户最终总签核与完成裁定

**Files:**
- Modify: `docs/superpowers/reports/2026-08-28-wenzhen-ui-visual-acceptance.md`

**Interfaces:**
- Consumes: Tasks 3-8 六个 `APPROVED` 批次和 Task 9 全部自动证据。
- Produces: 唯一合法的最终状态 `FINAL STATUS: APPROVED BY USER`。

- [ ] **Step 1: 验证所有分批门禁已真实签核**

Run: `rg -n "^Batch:|^Status:|^User quote:" docs/superpowers/reports/2026-08-28-wenzhen-ui-visual-acceptance.md`

Expected: 大厅、地图、战斗、事件/NPC/商店、休整/炼蛊/奖励、大厅子视图/结算六批均为 `Status: APPROVED`，且每批 `User quote` 非空。

- [ ] **Step 2: 向用户展示最终核心与子界面索引**

展示三张 1920x1080 核心默认态、三张核心极限态、每个子界面一张代表图，以及 1280x720 总览；同时简述完整测试和 Release 结果。然后停止，等待用户最终裁定。

- [ ] **Step 3: 处理最终反馈或记录最终认可**

用户要求任何修改时写 `FINAL STATUS: CHANGES REQUESTED`，将反馈路由回拥有该界面的 Task，修复后重跑该 Task 至 Task 10 的全部门禁。只有用户明确表示三大界面及其推导子界面整体认可时，原样记录回复并写 `FINAL STATUS: APPROVED BY USER`。

- [ ] **Step 4: 最终差异审查**

Run: `git diff --ignore-cr-at-eol --name-only`

Run: `git diff --ignore-cr-at-eol --check`

Expected: 修改范围只落在本计划责任文件及被前置真实缺陷要求回修的既有责任文件；受保护目录零差异；无新增空白错误。

- [ ] **Step 5: 仅在可安全隔离时提交**

只对 `git diff --ignore-cr-at-eol --name-only` 显示且已由本计划责任图确认归属的文件逐一执行 `git add`，再用 `git diff --cached --ignore-cr-at-eol` 核对；若暂存会夹带执行前已有改动，则不提交并在报告列明。可安全隔离时提交信息为：

```bash
git commit -m "fix(ui): complete user-approved Wen Zhen visual redesign"
```

## 完成定义

- 大厅、地图、战斗分别有本轮 Godot 实机截图和用户明确 `APPROVED`；大厅是横排《問眞》与人物/地点的第一视口，地图是真实多分支路径镜头，战斗是上状态、中角色敌阵、下中央手牌的完整三视界。
- 事件、NPC、商店、休整、炼蛊、奖励、流派、契约、图鉴、手记、设置、结算全部由已签核母版推导，并分别包含在用户签核批次中。
- 三视口分批截图与四视口总截图无文字裁切、主体截断、图层遮挡、空白资产、比例过小或旧暗色卡片墙残留。
- 1/2/3/4+ 敌均来自真实领域快照，公开意图、生命、护盾和状态逐敌可读；5/7 张手牌保持费用、名称、插画和核心效果可读。
- 所有界面只读 snapshot 并提交版本化 command；地图可达性、战斗目标、危险后果、随机性和结局仍由领域权威决定。
- 聚焦测试、完整 `tools/check.ps1`、集成流程、像素检查和 Windows Release 导出均有本轮实际通过证据。
- 验收报告最终包含用户对三大界面、三组子界面和整体方案的原样认可；在 `FINAL STATUS: APPROVED BY USER` 之前，任何执行者都不得声称 Task 8、UI 修复或整体重设计已完成。
