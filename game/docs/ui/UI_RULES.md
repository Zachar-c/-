# UI 规则（問眞极简）

> **效力**：本文件是《蛊路求生》UI 的唯一权威规范。新增或改动 UI 前必读。
> **可执行部分**：`tests/unit/test_ui_rules_guard.gd` 把能静态判定的条目钉成断言，违规即红。
> 若你加了新规则，**必须同时改本文件与那个守卫测试**，两边是一套，只改一边等于没改。
>
> 最后更新：2026-08-30

---

## §0 技术栈：只有一套

UI 一律走 **Godot 官方 `.tscn` 节点树 + 命令式 `refresh(snapshot)`**。

| 层 | 位置 | 说明 |
|---|---|---|
| 屏幕 | `scenes/ui/screens/*.tscn` + `scripts/presentation/screens/*_view.gd` | 每屏一个场景 + 一个绑定脚本 |
| 组件 | `scenes/ui/widgets/*.tscn` + `scripts/presentation/widgets/*_view.gd` | 跨屏复用 |
| 样式 | `scripts/presentation/gu_style.gd` | 唯一色板 / 字体 / 间距来源 |
| 主题 | `scripts/presentation/wenzhen_master_theme.gd` | 按钮等控件样式套用 |

**已废弃**：RUITK 与 `.guitkx` 声明式 UI。剩余未迁移的屏见 §8 迁移队列，迁移完即整体删除。

**路由**：`scripts/presentation/run_screen_router.gd` 的 `RunScreenRouter.MASTER_SCENE_PATHS` 是唯一路由表，
协议为 `instantiate() → mount_snapshot(snapshot, commands)`。`SCREEN_PATHS`（`.guitkx` 路由）
在迁移完前并存，迁移完删。（W12 split：原位于 `run_controller.gd`，2026-09-10 迁至 router。）

---

## §1 设计原则（不可协商）

1. **纸纹只是低对比细颗粒，绝不损害可读性。** 底纹 opacity ≤ 0.06。
2. **不要渐变文字、不要彩色辉光、不要玻璃卡片。** 层级靠留白 + 1px 发丝线表达。
   **卡面例外（2026-09-11 用户裁定）**：卡牌组件（`gu_card.tscn`）的悬停辉光
   （`card_hover_glow.gdshader`）、稀有度闪箔 / 裸眼视差（`card_holo_foil.gdshader` /
   `card_parallax.gdshader`）是卡面专属装饰——低强度、金色系、仅 epic+ 明显；
   屏面、面板、按钮一律不适用本例外。
3. **圆角上限 8px**，优先方角或 2px 微圆角。超 8 即视为浮动卡片。
4. **分区用留白 + 发丝线，不用悬浮卡片。** 见 §3。
5. **美术（角色 / 蛊虫 / 场景）是第一视觉信号，UI 退居其后。**

---

## §2 色板 token（不可变）

**任何调用点都不许写裸 `Color(0.x, 0.x, 0.x, a)`，一律引用 `GuStyle`。**
整数写法的 `Color(0, 0, 0, 0)`（透明）与 `Color(1, 1, 1, 1)`（纯白）是唯一豁免。

### 纸面 / 墨色

| Token | 值 | 用途 |
|---|---|---|
| `PAPER_BG` | `#ece9df` | 主表面、宣纸白 |
| `PAPER_RAISED` | `#e6e2d7` | 次级纸面 |
| `PAPER_DEEP` | `#ddd8cc` | 禁用层、轻分区 |
| `INK_PRIMARY` | `#171814` | 主文字、主结构线 |
| `INK_SOFT` | `#686960` | 次要文字、已知但不紧急 |
| `HAIRLINE_COLOR` | `#aaa89f` | 发丝分隔线 |
| `HAIRLINE` | `1` | 发丝线宽 1px |

### 语义强调色

| Token | 值 | 语义 |
|---|---|---|
| `CINNABAR` | `#9c332d` | 朱砂：危险 / 不可逆 / 死亡线 |
| `CONTRACT_BLUE` | `#315f73` | 契约规则 |
| `ANOMALY_YELLOW` | `#936f1e` | DDA / 异变 / 险象 |
| `JADE` | `#3f7063` | 护盾 / 正向 / 可恢复 |

### 淡染层（TINT_*）

语义色的半透明变体，**只做徽章 / 警示条 / 死线行的底，绝不当文字色**。
半透明是为了让下层纸纹透出来，符合原则 2（不搞玻璃卡片）。

| Token | 值 | 用途 |
|---|---|---|
| `TINT_BLOOD` | `0.55, 0.18, 0.15, 0.25` | 危险死线行、结算危险块 |
| `TINT_BLOOD_DEEP` | `0.5, 0.12, 0.1, 0.85` | 确认弹窗警示条（近实） |
| `TINT_CONTRACT` | `0.3, 0.4, 0.5, 0.25` | 契约徽章底 |
| `TINT_ANOMALY` | `0.5, 0.35, 0.15, 0.25` | 异变 / DDA 徽章底 |

### 稀有度

`RARITY_COMMON`(=INK_SOFT) / `RARITY_RARE`(=CONTRACT_BLUE) / `RARITY_EPIC`(#76528f) /
`RARITY_LEGENDARY`(#8c6b25)。**稀有度是识别色，不是表面色。**

> 语义色不要挪用：屏幕标题用 `INK_PRIMARY`，不要拿 `ANOMALY_YELLOW` 当装饰色。
> `ANOMALY_YELLOW` 只表示「异常 / 凶险」，否则玩家学不会这套颜色语言。

---

## §3 圆角与描边

- **圆角 ≤ 8px**。徽章类统一 4，面板类 8，卡片 8。
- 层级靠 **1px 发丝线 + 留白**，不靠底色深浅。
- **禁止纸中纸**：容器已经提供纸面，再套一层带底色的会造成明暗倒挂。
  滚动容器（`gu_scroll_box`）必须是透明无边框的。
- `PAPER_DEEP` 是**禁用层** token，不做卡牌 / 面板底色。

---

## §4 字体

- **唯一字体**：`LXGWZhiSongCL-Regular.ttf`（霞鹜智宋 CL），`GuStyle.TITLE_FONT` / `BODY_FONT` 都指向它。
- 中文正文必须走同一套宋体。引擎默认回退是无衬线，与宣纸 + 宋标题断风格。
- **字体只能在 `gu_style.gd` 里 `preload`**，其他文件一律引用 `GuStyle.BODY_FONT` / `TITLE_FONT`。
  （守卫 `test_fonts_only_preloaded_in_gu_style` 强制）

### 卡面例外：毛笔字体（2026-09-11 用户裁定）

- `MaShanZheng-Regular.ttf`（马善政毛笔楷，SIL OFL 1.1）注册为 `GuStyle.TITLE_BRUSH_FONT`，
  **仅用于大尺寸卡牌标题**（`gu_card_view.gd`，216×300 基线，19px）；正文 / 屏面标题仍走霞鹜智宋。
  **小尺寸例外（2026-09-11 用户反馈"看不清"）**：竖长战斗手牌卡（`GuTallFanHandView`，
  126×176 基线）标题仅 14px 空间，毛笔体在该字号不可读；毛笔体不得用于 16px 以下的文字。
- 许可副本 `assets/wenzhen/fonts/OFL1.1_MaShanZheng.txt` 随字体存放，随包导出。
- OFL 允许改名与子集化，但本项目仍原名原样分发，不做子集。

### 文字样式：高锐度无衬线 + 禁用文字阴影（2026-09-11 用户裁定）

- **全部文字阴影移除**（`font_shadow_color` 一律不得再设）：卡面标题（横/竖卡）、
  全局与大厅按钮文字阴影均已删除；`INK_TEXT_SHADOW` / `BTN_SHADOW_RUST` token 已删除。
  面板 / 卡体的 StyleBox DropShadow **不是**文字阴影，保留不受影响。
- 小字号卡面文本（竖卡标题/标签/描述）统一走 `GuStyle.CARD_UI_FONT`——系统
  **微软雅黑 UI**（回退 Microsoft YaHei → Noto Sans CJK SC → PingFang SC → Segoe UI），
  hinting=normal + 灰度 AA + **subpixel 关闭**（扇形手牌为旋转渲染，亚像素定位
  重采样后产生彩边发虚；整像素定位最锐）。
- 毛笔体（上节）与霞鹜智宋仅用于大字号场景；16px 以下文本一律 `CARD_UI_FONT`。

### ⚠️ 许可：是 IPA，不是 OFL

上游常把霞鹜智宋标成 OFL-1.1，**这是错的**。它衍生自 IPAex 明朝 / IPAmj 明朝，
实际许可为 **IPA Font License 1.0**，与 SIL OFL 1.1 **互不相容**。

字体内嵌版权原文：

```
Copyright(c) 2024 LXGW; Information-technology Promotion Agency, Japan (IPA), 2003-2019.
You must accept "https://opensource.org/licenses/IPA/" to use this product.
```

对我们的硬约束：

- 不得改名字体、不得子集化后再发布（Article 3.2(1)(2)）
- 不得删除内嵌版权声明
- 商用、嵌入、数字分发均允许（2.2 / 2.3 / 2.5）
- 必须随附许可协议副本 → 已放在 `assets/wenzhen/fonts/IPA_FONT_LICENSE.txt`

许可证是 `.txt`，不受 `export_presets.cfg` 里 `exclude_filter` 的 `*.md` 影响，会随字体打包。

---

## §5 屏幕约定

### 根节点

每个屏幕 `.tscn` 的**根节点必须是 `MarginContainer`**，且带 `margin_left = 32`
（即 `GuStyle.SCREEN_MARGIN`），上下为 16 / 24。历史上一批屏直接贴窗口边缘，就是这个漏了。

```
XxxScreen (MarginContainer, 32 / 16 / 32 / 24)
└── Root (VBoxContainer)
    ├── TopBar            ← 实例 gu_top_bar.tscn
    ├── ...屏特有内容
    └── ConfirmDialog     ← 实例 gu_confirm_dialog.tscn，默认隐藏
```

### 节点命名

| 约定 | 例子 | 理由 |
|---|---|---|
| 主决策面叫 `primary_decision_surface` | shop / rest / refine | 各屏一致，断言与截图脚本能通用 |
| 顶栏实例名 `TopBar` | 全部屏 | |
| 确认弹窗实例名 `ConfirmDialog` | 全部屏 | |
| 节点名全 ASCII，中文只出现在 `text` | `LeaveButton` | 路径不受编码影响 |

### 种类固定 vs 数量不定

- **种类固定**（4 种资源 chip、3 条死线）→ **预置在节点树里**，靠 `visible` 控制。
- **数量不定**（货架卡、服务行、战利品）→ 代码生成，函数内先 `add_child` 再配内容（见 §8 坑 2）。

### 空值不渲染

空字符串的 Label 会白占一行。条件槽位（回退小字、保底提示、死因）**空则隐藏**，
且 `text` 一并清空——只设 `visible = false` 会留下「代价：」这类前缀，被按文本查找的断言误命中。

---

## §6 图标系统

### 组件

`scenes/ui/widgets/gu_icon.tscn` + `scripts/presentation/widgets/gu_icon_view.gd`。
用法：`icon.setup("danger")` 或 `icon.setup("shield", GuStyle.CONTRACT_BLUE, GuIconView.SIZE_BLOCK)`。

尺寸档位：`SIZE_SMALL`(16) / `SIZE_BODY`(20) / `SIZE_BLOCK`(24)。

### 注册表

`GuIconView.ICON_PATHS` 是唯一映射表（语义名 → SVG 文件）。新增图标 = 丢一个 SVG 进
`assets/wenzhen/icons/` + 在表里加一行。**别处不许直接 `load()` 图标文件**（守卫强制）。

语义默认色：`danger` / `curse` / `poison` / `death` → `CINNABAR`；`warning` → `ANOMALY_YELLOW`；
`check` → `JADE`；`shield` → `CONTRACT_BLUE`；其余 `INK_PRIMARY`。

### ⚠️ 图标必须画成白描边

`CanvasItem.modulate` 是**乘法**：黑色 × 任何色 = 黑色，染不上 token 色；白色 × 目标色 = 目标色。
所以 `assets/wenzhen/icons/*.svg` 一律 `stroke="#FFFFFF"`，靠 `modulate` 染色。
**GuIcon 必须始终显式给 color**，缺省走 `INK_PRIMARY`——绝不能放任默认白（白在纸面上不可见）。

### 素材来源与将来替换

现为**本项目程序化自绘**：24 viewBox 线性描边，`svg/scale=4.0` 导入（96px），零许可负担。

将来若要换成 [game-icons.net](https://game-icons.net) 素材，注意：

- 它是 **CC BY 3.0**——与 MIT / Apache / ISC / CC0 不同，**CC BY 是署名强需求**，
  光放许可证文件不够，**必须在游戏内「关于 / 许可」界面可见地署名**。
- 换素材时保持「白描边 + `ICON_PATHS` 映射」约定，`GuIconView` 无需改动。

---

## §7 间距、字号

### 间距（`GuStyle.SPACE_*`）

`SPACE_1`=4 / `SPACE_2`=8 / `SPACE_3`=12 / `SPACE_4`=16 / `SPACE_5`=24 / `SPACE_6`=32。
另有 `SCREEN_MARGIN`=32、`TOP_BAR_HEIGHT`=72。

### 字号：5 档，不要更多

| 档 | px | 用途 |
|---|---|---|
| 屏幕标题 | 28 | 每屏主标题 |
| 区块标题 | 18 | 面板 / 分组标题 |
| 行 | 15 | 列表行、卡片标题 |
| 正文 | 13 | 正文、按钮 |
| 注释 | 12 | 辅助说明、徽章小字 |

历史上出现过 9 档字号，已收敛到 5 档。新增文本先在这 5 档里选，不要自己发明。

---

## §8 迁移队列与已踩的坑

### 队列（先易后难）

```
已迁移：Shop  Rest  Reward  Npc  Encounter  Refine  Ending
待迁移：battle  map  hall  content_error  debug_panel
```

`battle` / `map` / `hall` 的 `wenzhen_*_master.tscn` 里保留了手工搭的**静态骨架**
（hall 的 `Folio` / `HallSheet` 已设 `visible = false`）。这些节点**留作转换骨架**，
转的时候接上 `mount_snapshot` 即可，不要从零搭。

⚠️ 这些静态按钮**没有接 `pressed` 信号**（`apply_static_theme()` 只套了主题）。
转换时必须接线，否则就是死按钮。

### 坑 1：`%` unique-name 在子场景实例里解析失败

`instantiate()` 出的子场景，owner 链不指向自身根，`%NodeName` 查不到。
**一律用显式 `get_node("路径")`。** 附带好处：节点树结构一目了然。

### 坑 2：`@onready` 只有 `add_child` 触发 `_ready()` 后才有值

动态创建组件时，`instantiate()` 后立刻访问 `@onready` 成员 = null。

**固定模式**：build 函数签名 `(list, data) -> void`，**函数体第一行就 `list.add_child(node)`**，
不返回节点。让调用方在外面 add_child 是错的。

### 坑 3：`-s` 模式下 `_ready()` 推迟到首帧

`mount_snapshot` 会早于 `@onready`。生产环境（`add_child` 同步触发）没这问题，
但让组件免疫调用时序更稳妥：加 `_ready_done` 标志，未就绪时只收数据，`_ready()` 里补刷新。

### 坑 4：裸调用含 `await` 的协程会静默挂起

```gdscript
_verify_tscn_rest(...)      # 错：在第一个 await 处挂起，后面断言全跳过，退出码照样 0
await _verify_tscn_rest(...)  # 对
```

**退出码 0 不等于验证通过**——这条是白屏事故的直接教训。

### 坑 5：`main.tscn` 里硬编码 `uid=` 会让 Godot 删掉整条 `ext_resource`

曾因保留旧的 `uid="uid://..."` 导致 `run_controller.gd` 的 ext_resource 被 Godot 丢弃，
`RunController` 退化成无脚本空 Node，游戏白屏。

**手写 `.tscn` 时不要写 `uid=`，让 Godot 自动分配。**

### 坑 6：`Object.get("变量名")` 对普通成员变量恒返回 null

`get()` 只走 property 系统。想判断 `_ready()` 有没有执行，看 `get_child_count()`，别用 `get()`。

### 坑 7：GDScript 的 `%` 运算符遇数组会展开

`"..." % offenders` 在 `offenders` 是**空数组**时 = 0 个参数 → "not enough arguments for format string"。
用字符串拼接（`+ str(x)`）代替。

---

## §9 验证约定

**改主场景、路由、或任何 `.tscn` 后，必须做渲染级验证，不能只看出退出码。**

| 工具 | 命令 | 用途 |
|---|---|---|
| `scripts/acceptance_driver.gd` | `godot --path . -s res://scripts/acceptance_driver.gd -- --mode=render scene=res://scenes/main.tscn` | 统计渲染像素颜色分布（原 render_probe）。`UNIQUE <= 1` 判 `BLANK` 并返回 1。主场景基线 **461 色** |
| `scripts/acceptance_driver.gd` | `godot --headless --path . -s res://scripts/acceptance_driver.gd -- --mode=smoke` | 逐屏挂载 + 结构断言 + 主场景推进（原 smoke_render + integration_smoke） |
| GUT 守卫 | `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_ui_rules_guard.gd -gexit` | 规则合规 |
| `scripts/acceptance_driver.gd` | `PLAYTHROUGH_SEED=42 godot --headless ... -s res://scripts/acceptance_driver.gd -- --mode=play` | 真实流程（原 playthrough_smoke） |

**为什么必须有 `render` 像素模式**：白屏是静默失败——`--quit-after` 退出码 0、
旧 smoke 挂载绕开 `main.tscn`、GUT 不加载主场景、play 用 `RunController.new()`，
四者全绿但游戏是白的。只有像素统计能抓到。

新增 `.tscn` 屏时：在 `_verify_tscn_screens` 的 cases 表里加一行，并写对应的 `_verify_tscn_xxx`。
含 `await` 的验证函数**必须 `await` 调用**（坑 4）。

---

## §10 第三方资源与许可

完整声明见 `THIRD_PARTY_NOTICES.md`。要点：

| 资源 | 许可 | 状态 | 注意 |
|---|---|---|---|
| LXGW ZhiSong CL | **IPA Font License 1.0** | 已落地使用 | **不是 OFL**，见 §4 |
| Ma Shan Zheng（马善政） | SIL OFL 1.1 | 已落地使用（卡面标题） | 许可副本 `OFL1.1_MaShanZheng.txt`，见 §4 卡面例外 |
| GUT | MIT | 已落地 | 测试框架 |
| game-icons.net | CC BY 3.0 | 未引用 | 若引入**必须游戏内署名** |
| Remix Icon / Lucide / Kenney | Apache-2.0 / ISC / CC0 | 未引用 | |
| Noto Serif SC / AR PL UMing | OFL-1.1 / Arphic | 未引用 | 当前单字体已够，不必再加 |

**加任何新资源前**：确认许可 → 在 `THIRD_PARTY_NOTICES.md` 登记 → 确认许可证文件会随包导出
（`export_presets.cfg` 的 `exclude_filter` 含 `*.md`，用 `.txt` 存许可证）。

> 网络受限时无法下载外部素材，图标走程序化自绘（§6）。这是有意选择：零许可负担、
> 零署名义务、风格统一，且将来可一键替换。
