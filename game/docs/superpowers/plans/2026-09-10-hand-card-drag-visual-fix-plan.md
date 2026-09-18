# 手牌拖拽 / 悬停解释栏 视觉修复计划（真机冒烟评审整改）

- **日期**：2026-09-10
- **状态**：已落地（四态渲染 + 全量门全绿，见 §7；未提交）
- **触发**：真机冒烟测试评审——「卡牌鼠标拖动效果」「鼠标悬停解释栏效果」不达预期
- **参考**：Slay the Spire 实机截图 4 张（用户提供）
  1. 无指向卡拖动：卡体**不透明、放大、浮起**跟随鼠标，原卡位暗下去
  2. 指向卡未命中：一条**粗弧形矢量箭**从卡延伸到鼠标，自由态冷色
  3. 指向卡命中：同一支箭转为**朱砂红**，敌人被框选高亮
  4. 鼠标悬停：**悬停卡本体抬升放大**，解释栏贴在卡旁（不追鼠标、不盖住卡）
- **范围**：仅战斗手牌（`battle_screen_view.gd` / `gu_battle_hand_view.gd` / `AimLineOverlay`）。不新增快照键、不新增命令、不改 `play_card` 签名。

---

## 1. 现场勘查（当前实现的实际渲染，非推测）

新增探针 `tools/verify_hand_drag_render.gd`（真实窗口 + 合成快照 + 真实鼠标事件，四态落图到 `.preview/hand_*.png`），采到的现状：

| 态 | 现状截图 | 问题 |
|---|---|---|
| `hover` | `.preview/hand_hover.png` | ① 解释栏**盖住被悬停的那张卡**；② 面板内**重复标题结构**：外层 `hand_tooltip_title` 已显示「石皮蛊 · 土道」，内层 `TooltipView` 的空 TitleLabel 又占一行，造成「一阶」上方一大段空白；③ 面板只有 3 行内容却占据舞台中部大片区域 |
| `drag_free` | `.preview/hand_drag_free.png` | ① 影卡是 **alpha 0.72 的半透明小卡**（168×74 原尺寸），读作「鬼影」而非「离手的卡」；② **解释栏在拖拽期间不收起**，与影卡重叠把影卡吞掉；③ 跟随有拖尾感（每帧 0.45 插值） |
| `aim_free` | `.preview/hand_aim_free.png` | ① 瞄准线是 **2px 细线**，在米色纸面上几乎不可见（截图里只有一条极淡的对角线）；② 起点在卡心，被解释栏挡住；③ 解释栏同样不收起，盖住舞台 |
| `aim_hot` | `.preview/hand_aim_hot.png` | 同上，只换成玉绿；参考图要求的是**粗箭 + 明显箭头**，当前完全无箭头 |

结论：「不达预期」不是手感问题，是**呈现层缺件**——影卡没有「离手感」、瞄准没有「箭」、解释栏没有「锚」且不该在拖拽时存在。

---

## 2. 目标规格（逐条对齐参考图）

### F1 悬停 / 解释栏（参考 4）

| 编号 | 目标 | 现状 |
|---|---|---|
| F1.a | 拖拽或瞄准期间**解释栏一律收起** | 全程常驻 |
| F1.b | 解释栏**锚定被悬停卡**：默认卡**上方**（手牌在屏幕底部，只有上方有空间），优先与卡右对齐、越界翻左/右，最后钳进视口；**不跟鼠标** | 跟鼠标，且盖住卡 |
| F1.c | ~~去掉重复标题行~~ **已核实非缺陷，不改** | 用探针几何体检（§7.3）证实：内层隐藏的 TitleLabel 不占位，标题→品质 15px、品质→效果 4px、效果→代价 4px，节奏正常；缩略图上的"大段空白"是观察误判 |
| F1.d | 悬停卡**抬升放大**（`HOVER_CARD_SCALE = 1.12`，`pivot` 在卡底边中点 → 向上浮出），离开即复位；鼠标离开整片手牌也要复位 | 无 |

### F2 无指向卡拖动（参考 1）

| 编号 | 目标 | 现状 |
|---|---|---|
| F2.a | 影卡**不透明**（alpha 1.0）+ **放大 1.5×**（`DRAG_PROXY_SCALE`）；**按字号重建卡面**（168×74 → 252×111，字号 10 → 15）而非缩放 Control，保证字不虚 | 半透明、原尺寸 |
| F2.b | 影卡加**离手边框 + 投影**（墨框 2px + StyleBoxFlat shadow），读作「浮起的卡」 | 无 |
| F2.c | 跟随更跟手：`DRAG_FOLLOW_SMOOTH` 0.45 → 0.80 | 拖尾感 |
| F2.d | 拖出 ≥ `DRAG_CAST_DISTANCE_PX`（64px）时影卡**转为可出牌态**（朱砂描边 + 1.04 微放大），给出「松手即出」的确定反馈；回到阈值内即复位 | 无 |
| F2.e | 源卡槽位保持压暗 0.45 | 已有 |

### F3 指向卡瞄准（参考 2/3）

| 编号 | 目标 | 现状 |
|---|---|---|
| F3.a | 细线 → **粗弧形矢量箭**：二次贝塞尔（控制点上抬 `clamp(dist*0.32, 40, 150)`，20 段采样）+ 箭身（宽 9，外发光带 15/alpha 0.18）+ **实心三角箭头**（长 30 / 半宽 15，按末段切向摆正） | 2px 直线 + 3px 圆点 |
| F3.b | 起点改为源卡**上沿中点**（箭从卡上射出） | 卡心 |
| F3.c | 自由态 `GuStyle.INK_PRIMARY`（墨），锁定态 `GuStyle.CINNABAR`（朱砂）；命中敌人时敌卡放置高亮保持现有玉绿描边 | 玉绿细线 |

> 颜色取向说明：参考图用「银灰 → 红」。本项目墨/朱砂语言里，**朱砂=攻击/危险**、玉绿=可交互/选中，故取「墨 → 朱砂」，与既有 `CINNABAR` 语义一致，也保住敌人卡玉绿放置高亮的既有语言（不改）。

---

## 3. 改动文件

| 文件 | 改动 |
|---|---|
| `scripts/presentation/widgets/gu_battle_hand_view.gd` | `create_drag_proxy(card, scale)` 改按比例重建（尺寸+字号）；新增 `set_card_hovered(card_id, on)` 抬升放大；新增 `set_proxy_ready(proxy, on)`（朱砂可出牌态）；`mouse_exited` 接 hover 结束 |
| `scripts/presentation/screens/battle_screen_view.gd` | 常量（`DRAG_PROXY_SCALE` / `DRAG_FOLLOW_SMOOTH` / `HOVER_*` / `AIM_*`）；`_drag_begin` 收起解释栏 + 建不透明影卡；`_process` 跟手 + 可出牌态；`_drag_end` 复位；`AimLineOverlay` 改为曲线箭（`set_aim()` + `curve_points()` 供测试）；`_position_tooltip` 改为锚定卡矩形 |
| `tests/unit/test_wenzhen_card_fsm.gd` | 新增 4 个用例（见 §4） |
| `tools/verify_hand_drag_render.gd` | 新增四态渲染探针（已落，作为交付证据） |
| `docs/contracts/2026-09-02-page-inventory-requirements.md` | 若 §6.3 口径需要（手势外观），补一句「影卡不透明放大 / 瞄准为弧形箭 / 解释栏锚定卡」 |

**不动**：快照键、命令面、`play_card` 签名、`TooltipView` 五段结构（`test_t6e_polish` / `test_wenzhen_battle_screen` 钉死）、`mouse_filter = IGNORE` 浮层约定（已钉死）。

---

## 4. 测试计划（先红后绿）

`tests/unit/test_wenzhen_card_fsm.gd` 新增：

1. `test_drag_proxy_is_opaque_and_larger_than_source_card`
   跨阈值后：`proxy.modulate.a == 1.0` 且 `proxy.size.x > 168`。
2. `test_aim_line_is_a_curved_arrow_from_card_top`
   瞄准中：`_aim_line.curve_points().size() >= 8`；首点接近源卡上沿中点；末点接近鼠标；命中敌人时 `color == GuStyle.CINNABAR`，自由时 `== GuStyle.INK_PRIMARY`。
3. `test_tooltip_hides_during_drag_and_anchors_above_card`
   ① 悬停 → 解释栏可见，且其矩形**与悬停卡矩形不相交**、完全落在视口内；② 按住拖动 → 解释栏不可见。
4. `test_hover_lifts_card_and_mouse_exit_resets`
   `mouse_entered` → 卡 `scale.x > 1.0`；`mouse_exited` → 复位 1.0 且解释栏隐藏。

回归：既有 13 个用例（含 `test_drag_card_onto_enemy_submits_with_that_target`、`test_drag_release_off_enemies_does_not_submit`、`test_drag_proxy_spawns_after_threshold_and_rebounds_off_enemies`）必须保持绿。

---

## 5. 验收

```powershell
# 1) 聚焦 + 全量
powershell -File tools/test.ps1 -Test tests/unit/test_wenzhen_card_fsm.gd
powershell -File tools/test.ps1 -Suite unit
powershell -File tools/test.ps1 -Suite integration
powershell -File tools/check.ps1
# 2) 交互闭环门
powershell -File tools/godot.ps1 --headless --path . -s tools/verify_interaction_loop.gd
# 3) 四态渲染（真实窗口，肉眼级）
powershell -File tools/godot.ps1 --path . -s tools/verify_hand_drag_render.gd
#    产出 .preview/hand_hover.png / hand_drag_free.png / hand_aim_free.png / hand_aim_hot.png
```

门槛：单测/集成全绿；闭环 `dead=[]` 且 `no_ui_click=[]`；四态截图与参考图逐条对齐（影卡不透明放大 / 箭可见且有箭头 / 解释栏不盖卡且拖拽时收起）。

---

## 6. 风险与边界

1. 影卡按字号重建而非缩放 → 卡面 4 行文案在 252×111 下需重新核字号与行距（`_card_face_text` 复用，字号 15）。
2. 悬停抬升用 `scale`（不参与布局），相邻卡会有 ~10px 视觉重叠，与参考图一致；不影响点击（命中区随 transform 缩放）。
3. 解释栏改为锚定卡后，`_position_tooltip` 不再依赖鼠标位；既有「跟鼠标」行为被有意替换，`test_t6e_polish` 未钉位置，仅钉五段与底色。
4. 拖拽期间收起解释栏需要显式收（拖拽不触发 `_refresh`），在 `_drag_begin` 内 `_hovered_card = {}` + `_refresh_tooltip()`。
5. 真窗手感（跟手度/箭宽/放大倍数）本次以四态截图为准，仍属静态观感验证；动态跟手度需用户实机确认。
6. 探针依赖真实窗口与 `Input.warp_mouse`：合成 `InputEventMouseMotion` 在本环境下不更新 `gui.last_mouse_pos`（已实测），故位移必须走 `warp_mouse`，探针里已注释说明。

---

## 7. 实施记录（2026-09-10 收口）

### 7.1 落地内容

**`gu_battle_hand_view.gd`**
- `HOVER_CARD_SCALE = 1.12` + `_hovered_id`：`set_card_hovered(card_id, on)` 抬升/复位悬停卡（pivot 在卡底边中点 → 只向上浮出，scale 不参与 HBox 布局，相邻卡不被挤走）；`_build_card` 里按 `_hovered_id` 恢复（刷新重建不丢悬停态）。
- `create_drag_proxy(card, scale)`：由「缩放 Control」改为**按比例重建**（168×74 → 252×111，字号 10 → 15，`apply_button` 之后再覆盖 `custom_minimum_size`），不透明 + 墨框 2px + `SHADOW_LARGE_*` 投影。
- `set_proxy_ready(proxy, ready)` + `_lifted_box(ready)`：跨过出牌距离转朱砂描边。
- 卡面 `mouse_exited` → `_on_hover.call({})`（空字典 = 无悬停卡）。

**`battle_screen_view.gd`**
- 常量：`DRAG_PROXY_SCALE=1.5`、`DRAG_FOLLOW_SMOOTH 0.45→0.80`、`DRAG_PROXY_GRAB=(0.5,0.72)`，移除 `DRAG_PROXY_ALPHA`。
- `_drag_begin`：先 `_hovered_card={}` + `_refresh_tooltip()`（手势期必收解释栏），影卡从源卡原位起手、按 `DRAG_PROXY_GRAB` 追手。
- `_process`：跟手权重提高；跨 `DRAG_CAST_DISTANCE_PX` 时切可出牌态（仅在跨阈值那一帧重建 StyleBox）；放置区/可出牌任一成立即 1.06 微放大。
- `AimLineOverlay` 重写：内部类自带几何常量（内部类不继承外部作用域，裸引用外部 const 会解析失败）；二次贝塞尔 20 段 + 箭身 9px + 外发光带 15px/α0.18 + 实心箭头（长 30 / 半宽 15，按末段切向摆正）；`set_aim(from, to, hot)`、`points()`、`is_hot()`、`color()` 供测试与探针读取。
- `_aim_origin()`：箭从源卡**上沿中点**射出。
- `_position_tooltip` / `_tooltip_anchor_position`：锚定悬停卡上方（含抬升放大补偿 `anchor.size.y × (HOVER_CARD_SCALE-1)`），宽度按内容自适应（去掉原先强塞的 280 宽），越界钳进视口；`_refresh_tooltip` 在 `_drag_active/_aim_active` 期间强制收起。

### 7.2 验收证据（全绿）

| 门 | 命令 | 结果 |
|---|---|---|
| 聚焦 | `-gtest res://tests/unit/test_wenzhen_card_fsm.gd` | **17/17 passed**（原 13 + 新增 4） |
| 单元全量 | `-gdir res://tests/unit` | **1174/1174 passed**，35192 asserts，176 scripts |
| 集成 | `-gdir res://tests/integration` | **31/31 passed**，1254 asserts |
| 契约漂移 | `-s tools/check_contract_drift.gd` | `contract drift: ok (157 identifiers resolved)` |
| 交互闭环 | `-s tools/verify_interaction_loop.gd` | `AUDIT[Battle] total=17 clickable=11 dead=[] no_ui_click=[]`；全屏 `dead=[]`、`no_ui_click=[]` |
| 启动探针 | `--headless --path . --quit-after 3` | exit 0 |
| 四态渲染 | `-s tools/verify_hand_drag_render.gd` | `.preview/hand_hover.png` / `hand_drag_near.png` / `hand_drag_free.png` / `hand_aim_free.png` / `hand_aim_hot.png`，`FAILED=0`（5 态全部 `ok=true`） |
| 空白检查 | `git diff --check` | 干净 |

### 7.3 四态几何体检（.preview 截图之外的数据佐证）
悬停态实测（1280×720 设计视口）：
```
card_body_c1 rect=P(454.12, 620.33) S(191.76, 84.47)   # 悬停卡（含 MasterTheme 按钮 1.03 hover 缩放 × 抬升 1.12）
tip_rect      =P(455.92, 467.17) S(280.00, 136.00)
  hand_tooltip_title  y 478.17..501.17
  QualityLabel        y 516.17..533.17   # 与标题间距 15px（TooltipMargin 10 + separation 4）
  EffectLabel         y 537.17..557.17   # 与品质间距 4px
  CostLabel           y 561.17..581.17   # 与效果间距 4px
```
→ 解释栏底边 603.17，悬停卡视觉上沿 620.33，**净空 17px、零重叠**；宽度 280 由内容最小值决定（不再是硬编码）。

### 7.4 遗留与边界

- 新增交互态断言：影卡不透明且 >168 宽、弧箭 ≥9 点且起点在卡上沿、命中转朱砂、解释栏在卡上方且不与卡相交、拖拽期收起、悬停抬升/离开复位。
- 真窗**动态**手感（跟手度、回弹、箭宽）仍以静态四态截图为准；需要真实鼠标连拖的观感由用户实机复核。
- 既有 `MasterTheme.apply_button` 会给卡面按钮叠加 hover 1.03 / pressed 0.97 缩放，与本次抬升 1.12 叠加成约 1.15 —— 属既有交互语言，未改动。
- 悬停卡刷新重建时 Godot 会发 `mouse_exited`（鼠标未动也会收一次解释栏），下次移动即恢复；已知取舍，未额外补偿。

### 7.5 探针输入路径的踩坑记录（供后续写渲染探针复用）
写这个探针时试了三条注入鼠标位移的路，只有第三条可靠：

| 路径 | 结果 |
|---|---|
| `Input.parse_input_event(InputEventMouseMotion)` | **不更新 `gui.last_mouse_pos`**（根窗口下实测：`_input` 收到了 motion，但 `get_global_mouse_position()` 不动） |
| `root.push_input(event, true)` | 位置被 `get_global_mouse_position()` 再乘一次画布变换（本机 DPI 缩放下 ≈1.3），坐标跑偏；`push_input(event, false)` 又要自己凑 `final_transform` |
| `Input.warp_mouse` | 位置正确，但**是否产生真实移动事件取决于窗口管理器**，且跨状态残留按键状态（下一态的 `pressed` 被当重复按下丢掉），批量驱动不稳定 |
| **挂进 SubViewport 后 `vp.push_input(event)`** | ✅ 与单测同一条 GUI 管线，坐标精确（`mouse=(550,627)` 就是推的坐标）、跨态稳定；截图取 `vp.get_texture().get_image()` |

结论：**渲染探针要驱动合成鼠标，就把屏挂进 SubViewport**，不要在根窗口上折腾坐标换算。

---

## 8. 追加修复：真机「瞄准线缺失」根因（2026-09-10 第二报）

### 8.1 现象与定位

用户在真机反馈"指向性卡拖拽时缺失瞄准引导线"。用新增的**真实对局探针**
`tools/verify_aim_line_real_run.gd`（真 RunController 跑到战斗 + 真实鼠标 + 拖拽途中截图）复现：

```
[DUMP] parent=root  visible=true size=(1280,720) z=100      # 节点在、可见、矩形正常
[DUMP] first=(300.0, 430.0) last=(300.0, 430.0)            # ← 起终点都是鼠标位：曲线退化成一个点
```

起点本应是源卡上沿中点，却掉进了 `_aim_origin()` 的兜底分支。根因：

**真实蛊卡 id 形如 `gu.gu_001`（含点），而 Godot 节点名不允许 `.`（引擎清洗成 `_`）**，
于是 `GuBattleHandView.card_rect()` 里的 `get_node_or_null("card_box_" + card_id)` 永远返回 null。
同一根因连带三处静默失效：影卡回弹目标变成 (0,0)、源卡拖拽期不压暗、悬停不抬升。

> 为什么单测没拦住：探针/单测用的是 `c0/c1` 这类**无点 id**，按名反查能命中 → 一路绿灯。
> 教训：**交互断言的测试数据必须用真实形态的 id**。

### 8.2 修复

1. `gu_battle_hand_view.gd`：新增 `_card_nodes: Dictionary`（原始 id → 卡体 Control），建卡时登记；
   `card_rect` / `set_card_dimmed` / `set_card_hovered` / `_apply_hover_on` 全部改走 `_node_for(card_id)`，
   与节点名如何被清洗解耦。
2. `battle_screen_view._aim_origin()`：兜底路径**绝不允许返回鼠标位**（起点==终点=线消失），
   改为返回鼠标上方 `AIM_ORIGIN_FALLBACK_Y`(120px) 的位置，保证线永远可见。
3. 覆盖层改造（对齐用户技术要求）：`battle_screen.tscn` 新增 `AimLayer`（CanvasLayer，layer=90），
   瞄准线从 viewport 根移入其中 —— 保证画在本屏所有 UI 之上、且随屏自动释放。
4. 视觉语义（用户要求"无目标虚线/半透明，锁定醒目色"）：自由态改**虚线 + α0.85**，
   锁定态实线朱砂；Godot 无"曲线虚线"API，按弧长在采样点上手算切段（`_draw_dashed`）。

### 8.3 验收

| 门 | 结果 |
|---|---|
| 真机复现 → 修复后 | `first=(110,630)`（源卡上沿中点）/ `last=(300,430)`（鼠标），距离 275 → 曲线正常；`parent=AimLayer` |
| 真实对局截图 | `.preview/aim_real_free.png`（虚线墨箭）、`aim_real_hot.png`（实线朱砂箭 + 敌人高亮 + 源卡压暗） |
| 领域结算 | 松手命中敌人：hp+shield 4 → 3，松手后 `_aim_line = none` |
| 防回归 | 新增 `test_dotted_card_id_resolves_rect_and_keeps_aim_line_visible`（用 `gu.gu_001` 断言矩形与起点非退化） |
| 聚焦 | `test_wenzhen_card_fsm.gd` **18/18** |
| 全量 | unit **1175/1175**、integration **31/31**、契约漂移 ok(157)、交互闭环 `dead=[] no_ui_click=[]`、启动探针 0、`git diff --check` 干净 |
