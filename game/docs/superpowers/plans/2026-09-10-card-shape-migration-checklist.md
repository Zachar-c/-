# 手牌换卡形（168×74 横向 → 110×154 竖长）改造清单

- **日期**：2026-09-10
- **状态**：清单已出，**未实施**（等用户批准）
- **范围**：卡面尺寸与手牌排布，**不动快照键、不动命令面**
- **实测工具**：`tools/verify_card_shape_budget.gd`（新，可复跑）

---

## 0. 一句话结论

换卡形**不是 UI 换皮，是破坏性视觉变更**：它钉在已批准的线框稿 v2 和页面需求单里，会牵连 7 个代码文件、4 个测试/探针、1 份线框稿。

好消息有两个：

1. **布局高度账实测有余量**——720p 下不撞车，也不会切掉任何内容（见 §2）。
2. **契约键面零变化**——卡形是纯表现层属性，不产生新快照键/命令，`2026-09-02-domain-ui-contract.md` 无需改动。

坏消息有一个：**换形本身不自动提容量**。容量来自"重叠排布"，不是来自"卡变窄"。

---

## 1. 先厘清一件事：容量从哪来

实测手牌容器宽 **1040px**（`HandMargin` 左 30 / 右 210，右侧 210 是给右下 `OpsDock` 让位的，不能动用）。

| 排布方式 | 168 宽（现状） | 110 宽（竖长） | 提升 |
|---|---|---|---|
| 不重叠（现役 `HBox` + 8px 间距） | **6.0 张** | **8.9 张** | +48% |
| 负边距重叠（扇形，步进下限 45%） | **12.5 张** | **19.8 张** | +58% |

两个结论：

- **只换形、保持 HBox**：容量 6 → 8.9 张，是真实收益，但远不到"能放很多牌"。
- **要拿到 19.8 张**，必须同时换成重叠排布（`GuTallFanHandView` 已就绪）。**卡变窄只是让重叠排布更划算**，不是重叠本身。

> 所以「换卡形」实际上是**两件事捆一起**：换尺寸 + 换排布骨架。下面分级标注，两者可分开落地。

---

## 2. 布局高度账（实测，非估算）

`Root` 是 `VBoxContainer`，`BattleStage` 吃剩余（`size_flags_vertical=3`）、`HandStage` 按内容撑——**手牌区每长高 1px 就从战场区扣 1px**。

实测（1280×720）：

```
卡高        74 → 154   (+80)
HandStage  132 → 212   (+80)
BattleStage 526 → 446  (−80)   ← 收缩量 == 增长量，已验证
卡带         (202,630 696×74) → (318,550 464×154)
敌人面板     1040×342（不动，battle_field 是绝对定位，不参与流式重排）
```

判定结果（两条都过）：

- ✓ `HandStage` 底边 720.0 ≤ 720 —— 手牌区未出屏
- ✓ 卡带与所有战场控件**无交叠**（`OpsDock` / `ModeHost` / `HintHost` 逐个做了矩形相交检测）
- ✓ 手牌区顶边 508，战场最靠下的 `ModeHost` 底边 507 —— 卡带从 550 起，**留 43px**

### 但有一个隐藏风险：悬停抬升会吃掉这 43px

竖长卡悬停时"向上长高"的量比横向卡大得多：

| 组件 | 抬升公式 | 顶边位置 | 与 `ModeHost`（底 507） |
|---|---|---|---|
| 现役 `GuBattleHandView`（`HOVER_CARD_SCALE=1.12`） | 154×0.12 ≈ 18.5px | 550−18.5 = **531** | 留 24px ✓ |
| `GuTallFanHandView`（`HOVER_LIFT=42` + `HOVER_SCALE=1.15`） | 42 + 154×0.15 ≈ 65px | 550−65 = **485** | **撞进 22px** ✗ |

**动作项**：若采用扇形组件，`HOVER_LIFT` 必须从 42 降到 ≤ 20（或改为"只放大不抬升"），否则悬停卡会压住模式按钮区。这是换形清单里最容易漏的一条——它是**两个组件参数叠加**出来的，单看任何一个都看不出来。

---

## 3. A 级：不改就出错（阻断）

### 3.1 `scripts/presentation/widgets/gu_battle_hand_view.gd`

| 行 | 现状 | 动作 |
|---|---|---|
| L84 | `card_box.custom_minimum_size = Vector2(168, 74)` | 提为常量，改为 `Vector2(110, 154)` |
| L93 | `btn.custom_minimum_size = Vector2(168, 74)` | 同上 |
| L96 | 二次覆盖（`apply_button` 会写死尺寸，必须在其后覆盖） | 保留这个顺序，否则被 §3.4 的默认值打回 |
| L169 | `create_drag_proxy`：`var base := Vector2(168, 74) * factor` | 改为基于卡尺寸常量 |
| L178 | `int(round(10.0 * factor))` 字号基准 | 竖长卡字号要重定（**不能靠缩放 Control**，字会虚） |
| L254 | `_card_face_text()` 4 行排版（名称/道阶/效果/费用） | **卡宽 168→110 后每行可容字数掉 ~35%**，效果行 `>12 字` 截断阈值必须重算，否则溢出被 `clip_text` 静默切掉 |
| L12 | `HOVER_CARD_SCALE = 1.12` | 抬升量随卡高线性放大（见 §2），需复验 |

### 3.2 `scenes/ui/widgets/gu_battle_hand.tscn`

`CardRow` 是 `HBoxContainer`。**扇形必须把卡容器换成普通 `Control`**——`HBox` 会在下一帧把 `position` 改回去，和自由摆放直接打架（`GuTallFanHandView` 内部已用普通 `Control`）。

保留 `HBox` 则本项跳过（代价：容量停在 8.9 张）。

### 3.3 `scenes/ui/screens/battle_screen.tscn`

`HandArea/CenterWrap` 是 `CenterContainer`，会把手牌组件宽度压成内容宽。扇形组件靠 `size.x` 算步进，**宽度塌了步进就算不出来**（整排会挤成一坨）。

动作：换扇形时给组件 `size_flags_horizontal = 3`，并去掉 / 绕过 `CenterWrap`。

### 3.4 `scripts/presentation/wenzhen_master_theme.gd`（L118–124）

```
min_size := ... (card 分支) Vector2(120, 110)
"font_size": ... (card 分支) 16
```

`MasterTheme.apply_button(btn, "card")` 会把这两个值写进按钮。现役 `gu_battle_hand_view` 是靠"**调用后再覆盖**"绕过的（L95→L96）。换形后必须同步改这两处，否则**任何忘了二次覆盖的新卡**都会悄悄变成 120×110 —— 这是最隐蔽的一处。

### 3.5 `scripts/presentation/screens/battle_screen_view.gd`

| 位置 | 现状 | 风险 |
|---|---|---|
| `_tooltip_anchor_position()` | 抬升补偿用 `GuBattleHandView.HOVER_CARD_SCALE`（**跨类引用别家 const**） | 换组件后这行编译不过 / 补偿值失真 |
| `_aim_origin()` / `_drag_source_rect` | 依赖 `_hand.card_rect(card_id)` | 竖长卡上沿位置不同，瞄准线起点需复验 |
| `DRAG_CAST_DISTANCE_PX` / `DRAG_PROXY_GRAB` | 相对卡尺寸调出的经验值 | 卡高翻倍后手感比例变了，需重调 |

---

## 4. B 级：测试与探针（不改会假绿）

| 文件 | 位置 | 问题 |
|---|---|---|
| `tests/unit/test_wenzhen_card_fsm.gd` | L279 | `assert_gt(proxy.custom_minimum_size.x, 168.0, "…larger than the 168x74 source card")` —— **断言写死了 168**，换形后必然失败（其实是好事，它会提醒你） |
| `tests/unit/test_wenzhen_battle_screen.gd` | L198+ | 按 `card_body_c0` 名查找（与尺寸无关），但**悬停/解释栏位置断言依赖卡高**，需复验 |
| `tools/verify_hand_drag_render.gd` | 五态探针 | 拖拽落点按卡中心推算；`DRAG_CAST_DISTANCE_PX` 与卡高比例变化后需重采 |
| `tools/verify_aim_line_real_run.gd` | 真实对局探针 | 同上；另需确认 `AimLayer` 覆盖层与新卡形的起点一致性 |
| `tools/verify_interaction_loop.gd` | 全屏交互回归门 | 手牌区高 +80px 后必须重跑，确认无遮挡 / 无出屏 / 无死按钮 |

---

## 5. C 级：契约、线框稿与美术（不回写就是契约漂移）

### 5.1 必须回写

- `docs/contracts/2026-09-02-page-inventory-requirements.md` P4 Battle —— 页面需求里的卡形与手势口径
- `docs/superpowers/specs/2026-09-07-battle-wireframe.html:75` —— **已批准**的线框稿 v2 在 CSS 里写死 `.card { width:168px; height:74px }`。改卡形 = 线框稿作废，必须出 **v3** 并重新走逐屏批准（AGENTS.md 当前待办 V0 项正在做这件事）

### 5.2 无需改动（明确记下来，避免过度施工）

- `docs/contracts/2026-09-02-domain-ui-contract.md` —— **键面零变化**。卡形不影响任何快照键或命令，`play_card(card_id, target_id)` 语义不变。
- `docs/contracts/module-interfaces/` —— 接口签名不变。
- 领域层 / 存档 / 事件日志 —— 完全不受影响（这是纯表现层改动）。

### 5.3 美术（最容易被低估的一项）

- **现有蛊虫插画全是方图**：`assets/wenzhen/gu/*.png` 共 14 张，尺寸 1024×1024 或 1254×1254。塞进 **110×154（1:1.4）** 要么裁掉左右各 ~25%，要么留白。
- **插画钩子是死代码**：`gu_battle_hand_view.gd:232 _load_gu_illustration()` **全仓库无调用点**。也就是说现役卡面是**纯 4 行文字、无插画**。竖长卡面积比横向卡大 2.8 倍，没有插画会露出大片空白 —— 需要先定卡面版式（插画区 + 信息区比例），再决定是否出 1:1.4 竖版图。
- 敌人插画已有 1024×1536（2:3）的竖版，可作参考比例。

---

## 6. 建议实施顺序（每步独立可回滚）

| 步 | 内容 | 单独收益 | 风险 |
|---|---|---|---|
| **S1** | 只改尺寸常量 + 卡面排版（§3.1、§3.4、§4 的断言） | 容量 6 → 8.9 张；线框稿失效 | 低，纯参数 |
| **S2** | 换排布骨架（§3.2、§3.3 + 组件替换 + §3.5）+ 调 `HOVER_LIFT` | 容量 → 19.8 张 | 中，牵动解释栏锚点与瞄准线起点 |
| **S3** | 线框稿 v3 + 页面需求回写 + 卡面版式与插画（§5） | 视觉定稿 | 需用户逐屏批准 |

> S1 和 S2 之间可以停下来看效果——**S1 已经能验证"竖长卡看着对不对"**，不必先啃骨架替换。

---

## 7. 复现命令

```
tools\godot.ps1 --path . -s tools/verify_card_shape_budget.gd
```

输出即 §2 全部数字；`FAILED=0` 表示"未出屏 + 无碰撞 + 卡带在屏内"。换形落地后应重跑，且**应当仍然 `FAILED=0`**。

---

## 8. 落地记录（2026-09-10 用户批准后实施）

**S1 + S2 已合并落地**（不做 S1 单独中间态：S1 的卡面/尺寸改动会随 S2 的组件替换一起重写，分两次做等于白做一遍）。

### 8.1 实测数字（`tools/verify_card_shape_budget.gd`，判**现役**一侧）

```
手牌区 HandStage      132 → 206 (+74)
战场区 BattleStage    526 → 452 (−74)    ← 收缩量 == 增长量，已断言
卡带                          (317,544 464×165)，底边 709 ≤ 720
与战场控件碰撞         []（逐个矩形相交检测）
ModeHost 底边 513 ／ 卡带顶边 544         → 留 31px
敌人卡 342 ≥ 最小高 306                   → 未裁剪
扇形容量（步进下限 45%）  旧 168 宽 12.5 张 → 现役 110 宽 19.8 张
FAILED=0
```

### 8.2 计划里没预见到、实施中才暴露的三件事

1. **弧高会再吃掉 22px**。原预算只算了「卡高 +80」，但扇形弧高要么让手牌盒再长高 22px（顶掉 ModeHost），
   要么让两端卡向上溢出。**解法**：手牌盒只预留**卡高**，坐标对齐到「中间卡顶边 = 手牌盒顶边」，
   弧高由两端卡向上溢出——而两端在水平方向是空的（ModeHost 居中 448..832、OpsDock 靠右 1090+）。
   这条如果按原计划直接落地，会在真机上出现"手牌面板压住模式按钮"。
2. **`HOVER_LIFT` 必须重算**：`42 + 卡高×0.15` = 65px 抬升会撞进 ModeHost；改为 `18`，实测卡带顶 544 时仍留 31px。
3. **「取消目标」出口不能跟着组件一起消失**。原出口在手牌组件的取消行里；手牌换组件后它没了，
   指向卡两步确认就没有退出口。已移到 `ModeHost`（模式状态本来就归宿主），并用组件的
   `cancel_requested` 信号承接卡体上的右键/Esc。

### 8.3 实际改动

| 项 | 结果 |
|---|---|
| 生产手牌组件 | `GuBattleHandView` → **`GuTallFanHandView`**（`gu_battle_hand.tscn` → `gu_tall_fan_hand.tscn`） |
| 删除 | `gu_battle_hand_view.gd`、`gu_battle_hand.tscn`、`gu_fan_hand_view.gd`（含内建 tooltip）、`verify_fan_hand_render.gd` |
| 宿主瘦身 | `battle_screen_view.gd` **净删约 280 行**（手势机件 + 瞄准内部类 + 拖拽常量 + `_interaction_dict`） |
| 宿主接管 | `_wire_hand()`：注入 `target_provider`（命中检测）、接 `card_chosen`→`_play_card`、`hover_changed`→解释栏、`aim_target_changed`→`_set_drop_hot`、`cancel_requested`→`_reset_interaction` |
| 兼容命名 | 卡体沿用 `card_box_<清洗 id>` / `card_body_<清洗 id>`，影卡 `battle_drag_proxy`，弧箭 `battle_aim_line` → **7 个依赖节点名的测试文件里 6 个零改动** |
| 布局 | `battle_screen.tscn` 去掉 `CenterWrap`（它会把手牌宽度压成内容宽，扇形算不出步进），手牌改由 `HandArea` 直接布局（`size_flags_horizontal = 3`） |
| 组件补齐 | 影卡**朱砂就绪态**、未命中**回弹**、瞄准起点**兜底偏移**（这三条原在宿主侧，是本会话已验证行为，换组件时逐条搬过来） |
| 组件修 bug | 点击路径未校验 `executable` → 禁用卡会提交（`test_battle_command_facade` 抓到） |

### 8.4 未完成（S3）

- **线框稿 v3**：`2026-09-07-battle-wireframe.html:75` 的 `.card{width:168px;height:74px}` 已失效，需出 v3 并逐屏批准。
- **卡面版式与插画**：现役卡面是纯文字四行，竖长卡下方有大片空白；`assets/wenzhen/gu/*.png` 全是 1:1 方图，
  塞进 1:1.4 要裁 25%。版式（插画区/信息区比例）待用户定向后出图。
- **真窗手感**：跟手度、回弹、弧箭粗细仍以静态截图判断，按 AI 契约待用户主动要求再做键鼠复测。

---

## 9. 回归修复：右栏操作按钮"看着置灰、点了没反应"（2026-09-10 真机反馈）

### 9.1 现象

行动值耗尽后，「结束回合 / 炼蛊 / 撤退」看着置灰且无法点击。用户描述为"被错误置灰禁用"。

### 9.2 根因：不是 `disabled`，是**被透明面板吃掉输入**

`tools/dbg_ops_grey.gd`（新，真控制器打到战斗 → 花光行动 → 摊开全量状态）给出的判据：

```
三个按钮 disabled=false  visible=true  modulate=(1,1,1,1)  父链 modulate 全为 1  无可见覆盖层
遮挡：HandStage(mf=0 rect=0,514 1280x206) 盖住按钮中心点
```

`HandStage` 是**通栏透明面板**（`bg_color` 全透明、无边框），横向铺满 1280、纵向覆盖到屏幕下沿；
`HandMargin` 的 `right = 210` 只把**卡**让开，并不改变面板自身矩形。Control 默认
`mouse_filter = STOP`，于是它吃掉右栏按钮的 hover 与点击 → 按钮不亮、点了没反应，看起来像"灰了"。

**本次改造加重了它**：手牌区高度 `132 → 206`，顶边从 588 升到 514，覆盖范围从"只压住撤退"
扩大到"三个全压住"。

### 9.3 修复

`battle_screen_view._ready()`：`_hand_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE`
（`mouse_filter` 只作用于节点自身，子节点照常收事件，手牌交互不受影响）。

### 9.4 为什么以前没被发现 —— 以及补上的两道闸

- 交互闭环审计只查"**有没有接线**"（`dead` / `no_ui_click`），查不出"**够不够得着**"；
  按钮接线齐全、属性正常，只是摸不到。
- **闸 1（工具）**：`tools/verify_interaction_loop.gd` 新增 `occluded` 维度——对每个可点按钮，
  沿 DFS 先序（≈ CanvasItem 绘制顺序）找**绘制在它之后**且 `mouse_filter=STOP`、且矩形含其中心的控件。
  实测该检测能抓到本次问题（修复前 Battle `occluded=[结束回合←HandStage, 炼蛊←HandStage, 撤退←HandStage]`，
  修复后 `[]`）。
- **闸 2（测试）**：`test_wenzhen_battle_screen.test_ops_buttons_stay_reachable_when_hand_stage_covers_their_band`
  ——用同一套遮挡逻辑断言三个按钮可达。已做红→绿验证：撤掉修复 11/12 失败，带修复 12/12 通过。

### 9.5 审计顺带暴露的两处**既有**遮挡（不在本次范围，未修，仅标注）

| 屏 | 被盖住的控件 | 遮挡物 | 性质 |
|---|---|---|---|
| Rest | 顶栏 `BagButton` / `SettingsButton` | `primary_decision_surface`（mf=STOP，rect `122,39 1120×414`） | 内容面板的矩形上沿伸进顶栏带（顶栏 0..62），且 `RestStage` 声明在 `TopBar` **之后** → 绘制在顶层。疑似真缺陷（顶栏那两个按钮可能一直点不到）。 |
| Settings | 顶栏 `BagButton` / `SettingsButton` / `NavQuit` | `SealPanelContainer` / `SettingsStage`（均为全屏 rect） | `SealPanelContainer` 在 tscn 里只有 44×44（`offset 1216,64..1260,108`），审计时被**封蜡动画**在运行期撑成全屏 → 属瞬态；`SettingsStage` 全屏 `mf=STOP` 压住 `NavQuit` 则**疑似真缺陷**。 |

两处都建议按 §9.3 同思路处理（装饰层 IGNORE / 收紧矩形），但需先确认是否有意为之，故未擅自修改。

---

## 10. 二次返工：右栏按钮**仍然**点不了（2026-09-10 真机复报）

### 10.1 为什么上一轮"修好了"却没修好

上一轮把 `HandStage.mouse_filter` 改成 `IGNORE`，审计随即报 `occluded=[]`——**但那是假阴性**，
审计的判定本身有两处错：

1. **只认 `STOP`**。`HandMargin` 是 `PASS`，因此被跳过。而 **`PASS` 的语义是"自己也收，并把事件
   继续交给父节点"，并不会让给身后被压住的兄弟节点**——它照样截获点击。
   （我先前误以为 PASS 可穿透，这个错误结论已从长期备忘与技能里更正。）
2. **顺序用"DFS 先序找第一个 STOP"近似**，而引擎是 `Viewport::_gui_find_control_at_pos`：
   **子节点逆序**深度优先，先递归子树、子树无命中再判自身。

### 10.2 根因（`tools/dbg_ops_grey.gd` 全量摊开实测）

```
HandStage    mf=2(Ignore) rect=(0,514 1280x206)
HandMargin   mf=1(PASS)   rect=(0,514 1280x206)   ← 内边距只作用于子节点，自身仍满幅
battle_hand  mf=1(PASS)   rect=(30,524 1040x186)
HandArea     mf=1(PASS)   rect=(30,556 1040x154)

「结束回合」rect=(1094,522 160x52)  最上层命中=HandMargin
「炼蛊」    rect=(1094,584 160x32)  最上层命中=HandMargin
「撤退」    rect=(1094,626 160x32)  最上层命中=HandMargin
```

`HandMargin` 的 `margin_right = 210` 只是把**卡**让开，**容器自身的矩形没有任何变化**，
仍然横跨 1280 并纵向叠到屏幕下沿，正好包住右栏 OpsDock 整列。

### 10.3 修复

`battle_screen.tscn`：手牌区**整条容器链**（`HandStage` / `HandMargin` / `battle_hand` / `HandArea`）
声明 `mouse_filter = 2`（IGNORE），并在 `battle_screen_view._ready()` 留注说明为什么不能改回
`STOP`/`PASS`。原先写在代码里的那一行 `_hand_stage.mouse_filter = ...` 撤掉，改为单一来源（场景）。

`mouse_filter` 只作用于节点自身，卡的 hover / 点击 / 拖拽/瞄准手势全部不受影响（已由探针与单测复核）。

### 10.4 工具与测试的两处加固

- `tools/verify_interaction_loop.gd`：`_occluder_for` 重写为与引擎一致的算法，并返回结构体；
  同时新增 `KNOWN_OCCLUDED` 留档表——**新出现的遮挡判红，既有未修的按 `occluded_known` 计数呈现**，
  门不再因为既有问题永远红。
- `tests/unit/test_wenzhen_battle_screen.gd`：
  `test_ops_buttons_accept_real_clicks_despite_transparent_hand_containers` ——
  在 `SubViewport` 里对三个按钮**真的 push 按下+松开**，断言 `end_turn` / `refine` / `flee`
  真的被触发。已做**红→绿**验证：撤销修复后三个按钮全部触发 `[]` 并打印命中者 `HandMargin`，
  带修复 12/12 通过。

### 10.5 审计顺带暴露的三处**既有**遮挡（本批未修，需产品决策）

| 屏 | 被盖住 | 遮挡物 | 性质 / 建议 |
|---|---|---|---|
| Rest | 顶栏 `Bag` / `Settings` | `PanelMargin`（`gu_panel` 内层，mf=PASS）`123,40 1118x412` | **布局问题**：决策面板上沿伸进顶栏带。应把面板下移，而不是给它加 IGNORE（面板主体本就该吃掉"点在纸面空白上"的点击）。 |
| Shop | 4 个「购买此蛊」+「离开黑市」+ 顶栏两个 | `Root_ShopStage_SealPanelContainer#SealMargin`，整屏 `32,16 1216x680` | **坏场景**：`shop_screen.tscn` 里 `SealMargin` 的 `parent="Root/ShopStage/SealPanelContainer"`，而该 `SealPanelContainer` 只在 `StageContent/TitleRow` 下声明过一次 → **孤儿节点**被引擎整屏挂载。需决定这个节点的归处。 |
| Settings | 整页内容（`静音`/`分辨率`/`保存`/`读档` 全部） | `BackRow`（HBoxContainer，被打成整屏 `32,16 1216x680`） | **容器语义**：`BackRow` 是 root `MarginContainer` 的直接子节点，被容器接管矩形——tscn 里写的 `offset_*`（80×30 小框）**完全无效**。只有它自己的「返回」能点。 |

三处都已核实**不是动画瞬态**（把审计等待从 0.8s 拉到 2.5s 后依然复现），且工作树里这三个场景
**均未改动**，属修前既有。
