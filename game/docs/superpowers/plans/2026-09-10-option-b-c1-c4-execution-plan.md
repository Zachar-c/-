# 方案 B 执行计划 — 分区重排 + 留白卡面（C1–C4）

> **v2 · 可行性审阅后修订**（2026-09-10）  
> 审阅结论：**需修改后执行**。本版已吸收 B1/B2/B3 阻塞项与 §非阻塞澄清。  
> 原始 v1：同目录历史；本文件为**唯一执行基准**。

- **裁定**：用户选定方案 B
- **基线**：`master` @ `88c53bb`（已核对与当前 HEAD 一致）
- **范围**：C1 三处遮挡；C2 战斗线框 v3（110×154）；C3 卡面留白（1:1 + 下方信息）；C4 Encounter 线框复核/批准
- **红线**：不写 `MOUSE_FILTER_IGNORE`；**不改** `scenes/ui/widgets/gu_panel.tscn`；不改领域/快照键；**不在用户要求时推送**
- **交互门**：`$GODOT --headless --path . -s tools/verify_interaction_loop.gd`  
  实测基线：8 屏 `dead=[] no_ui_click=[] occluded=[]`，仅 `occluded_known` Rest 2 / Shop 7 / Settings 10

---

## 0. 设计约束

1. 1280×720 问真视觉；卡面 **110×154** 不改；插画 **1:1 不裁（98×98）**。
2. 信息区 = 154 − 98 ≈ **56px** → 文案压到 **最多 2 行**，超出按现有截断规则截断。
3. 线框 HTML 为唯一批准基准；tscn 实现与线框 1:1。
4. 本批 **不改命令面 / 快照键 / 存档格式**。

---

## 1. 阻塞项（v1 误写，已纠正）

| # | v1 错误 | 正确口径 |
|---|---------|----------|
| **B1** | Rest「调 `offset_top`」 | `primary_decision_surface` 在 **VBoxContainer** 内，`offset_*` 无效。改为 **StageContent 内插 spacer**；**禁止改**共享 `scenes/ui/widgets/gu_panel.tscn`（8 屏实例） |
| **B2** | Settings「移到 TopBar 同级 + min size」 | `BackRow` 本就 `parent="."`，与 TopBar 同级——该选项是**无操作**。唯一有效：**挂到非拉伸父节点**（如 `SettingsStage/Content` Control）并用 **anchors 重算** 右下定位 |
| **B3** | 「`_load_gu_illustration` + `definition_id`→png」 | 该函数**全仓不存在**；卡面纯 Label。图仅 **14 张按道命名**（非 802 蛊 id）。口径：**按道映射 + 其余占位**；参考仍存活的 `gu_card_view.gd` `_load_gu_texture()` |

**非阻塞补齐**：修完须清 `tools/verify_interaction_loop.gd` 的 `KNOWN_OCCLUDED` 三条白名单；C3 必跑 `tools/verify_card_shape_budget.gd`；路径用 `scenes/ui/widgets/gu_panel.tscn`。

---

## 2. 原子任务（执行顺序）

```
T1 诊断（必做）
   ├─ T2 Settings | T3 Shop(待§6) | T4 Rest   ← 可并行，须一起进 T5
   └─ T5 C1 收口（清白名单+报告+提交）

T6 battle 线框 v3          ∥ 与 T1–T5 并行
T7 encounter v1 复核 → v1.1? → 等用户「过」

T8 道映射常量(待§6) → T9 TextureRect+占位 → T10 接线+单测 → T11 回归
T12 整批收口（unit/integration/check + open-items）
```

---

### T1 — 取遮挡诊断详情（第一步）

- **前置**：无  
- **文件**：`tools/verify_interaction_loop.gd`（临时，用完还原）  
- **步骤**：
  1. 跑门禁，确认基线 Rest 2 / Shop 7 / Settings 10 且 8 屏三键空；不一致则**停下报告**。  
  2. 在 `print("AUDIT[%s] ...")` **下方临时**加 `print("KNOWN_DETAIL[%s]: %s" % [label, str(known)])`。  
  3. 再跑门禁，抄下三屏「按钮路径(文本) ← 遮挡者」。  
  4. `git checkout -- tools/verify_interaction_loop.gd` 还原。  
- **判定**：拿到三屏详情；`git status` 不含该文件。  
- **失败**：`NO_MASTER` / 缺屏 → 记录并上报，不改判定逻辑。  
- **复杂度**：低 ｜ **可并行**：否  

### T2 — C1a Settings `BackRow` 换非拉伸父节点

- **前置**：T1  
- **文件**：`scenes/ui/screens/settings_screen.tscn`（约 317–329 `BackRow`/`BackButton`）  
- **步骤**：
  1. `BackRow` 的 `parent="."` → `parent="SettingsStage/Content"`（`Content` 为 **Control**，约 L180，非容器）。  
  2. 删除四行 `offset_*`，改为右下 anchors：  
     `anchor_left/top/right/bottom = 1.0`，`offset_left = -80.0`，`offset_top = -30.0`，`offset_right = 0.0`，`offset_bottom = 0.0`。  
  3. **不加** `mouse_filter = 2`；**不改** TopBar / SealPanelContainer / Nav。  
  4. 跑门禁：`AUDIT[Settings] ... occluded=[] occluded_known=0`。  
- **判定**：occluded_known=0；返回按钮仍可见（clickable 不降）。  
- **失败**：错位/仍被挡 → 还原 tscn，改「根与内容间插 VBox 包 Nav+SettingsStage、BackRow 留外面」；两次失败停下，**禁止 IGNORE**。  
- **复杂度**：中 ｜ **可并行**：是（与 T3/T4 文件不重叠）  

### T3 — C1b Shop 删孤儿 `SealMargin`（**待 §6-2 答复**）

- **前置**：T1；用户答复为「删」  
- **文件**：`scenes/ui/screens/shop_screen.tscn`（约 L58–71）  
- **步骤**：
  1. 确认孤儿：parent=`Root/ShopStage/SealPanelContainer` 无对应声明；真声明在 L110 `.../StageContent/TitleRow`。  
  2. **只删** L58–71 的 `SealMargin` + `SealLabel` 两块。  
  3. 不动 `SealSpacer` 与 TitleRow 下 Seal 子树。  
  4. 门禁：`AUDIT[Shop] ... occluded=[] occluded_known=0`。  
- **判定**：occluded_known=0；`TitleRow/SealPanelContainer` 仍在；购买/离开 clickable 不降。  
- **失败**：若用户选「并入」→ parent 改到 TitleRow/SealPanelContainer 并删 SealSpacer；两者都新增 occluded → 还原上报。  
- **复杂度**：低 ｜ **可并行**：是  

### T4 — C1c Rest 决策面板下移（**按 B1 禁改 gu_panel**）

- **前置**：T1  
- **文件**：`scenes/ui/screens/rest_screen.tscn`；**只读** `scenes/ui/widgets/gu_panel.tscn`  
- **步骤**：
  1. **禁止修改** `gu_panel.tscn`。  
  2. 在 `StageContent` 内、`primary_decision_surface` **之前**插入：  
     `[node name="TopSpacer" type="Control" parent="Root/RestStage/StageContent"]` + `layout_mode = 2` + `custom_minimum_size = Vector2(0, 8)`。  
  3. 8px 不够则 y=16→24；**不用 offset_top**；**不改实例 theme_override**。  
  4. 门禁：`AUDIT[Rest] ... occluded=[] occluded_known=0`。  
- **判定**：occluded_known=0；手记/图鉴可点；三选一仍可见。  
- **失败**：24px 仍挡 → 还原 spacer，试 `Root` 上 `theme_override_constants/separation = 8`；仍不行停下（改共享组件需你另行裁定并回归另外 7 屏）。  
- **复杂度**：中 ｜ **可并行**：是  

### T5 — C1 收口：清白名单 + 报告 + 提交

- **前置**：T2、T3、T4 全完成  
- **文件**：`tools/verify_interaction_loop.gd`（`KNOWN_OCCLUDED`）、验收报告 §4  
- **步骤**：
  1. 门禁 8 屏三键空且 **occluded_known 全 0**（其余屏不回归）。  
  2. `KNOWN_OCCLUDED` 删三条，**保留空字典** `{}`（勿删常量）。  
  3. 再跑门禁，结果与 1 一致（证明非白名单蒙混）。  
  4. 报告 §4 写「已清零（C1）」。  
  5. 一次提交：`chore(ui): fix C1 occlusions (settings/shop/rest)`，仅三屏 tscn + 工具 + 报告。  
- **判定**：`git show --stat` 合预期；两次门禁一致全 0。  
- **失败**：第 3 步新 occluded → 回退 T5，回对应子任务。  
- **复杂度**：低 ｜ **可并行**：否  

### T6 — C2 战斗线框 v3（110×154）

- **前置**：无（可与 T1–T5 并行）  
- **文件**：新建 `docs/superpowers/specs/2026-09-10-battle-wireframe-v3.html`；标注旧稿  
- **步骤**：
  1. 以 `2026-09-07-battle-wireframe.html` 为底，沿用纸底/墨/朱砂，**不引入新主题**。  
  2. `.card`：`168×74` → **`width: 110px; height: 154px`**；全文同步。  
  3. 五区：顶栏资源 / 敌人意图带 / 中部说明+杀招焦点（不挡手牌）/ 右上操作坞 / 底部扇形（弧起点=卡面中心）。  
  4. 顶部注释：`card_size = Vector2(110, 154)`（对齐 `gu_tall_fan_hand_view.gd:107`）。  
  5. 旧稿标题下：`> DEPRECATED：…用 2026-09-10-battle-wireframe-v3.html`。  
  6. **不改任何 .tscn**。  
- **判定**：无横向溢出；grep 无 `168px; height: 74px`；旧稿有 DEPRECATED；`git status` 无 tscn。  
- **失败**：溢出缩间距，**不改 110×154**。  
- **复杂度**：中 ｜ **可并行**：是  

### T7 — C4 Encounter 线框复核 → v1.1 → 等批准

- **前置**：无  
- **文件**：`2026-09-09-encounter-wireframe-v1.html`（或 v1.1）  
- **步骤**：
  1. 按 B 复核：行动卡禁用置灰、离开语义、迷雾/揭示与地图一致。  
  2. 一致则**不动文件**，只报「复核通过，可批准」；不一致另存 v1.1 并列改动。  
  3. **不改** `encounter_screen.tscn`、**不改**命令面。  
  4. 提交后**停下等「过」**。  
- **判定**：明确「过 / 改」；未「过」不得开 B1 的 V2–V4 / V5–V8。  
- **失败**：需改命令才能对齐 → 停下上报。  
- **复杂度**：低 ｜ **可并行**：是  

### T8 — C3 前置：道映射常量（**待 §6-3 口径确认**）

- **前置**：T1；用户认可「按道映射 + 其余占位」  
- **文件**：`gu_tall_fan_hand_view.gd`；**只读** `gu_card_view.gd:66` 一带  
- **步骤**：
  1. 顶部加 `const DAO_TEXTURE := { ... }`，覆盖现有 14 张 `assets/wenzhen/gu/gu_<dao>.png`。  
  2. **先 grep** `data/schools.json` / catalog 确认道 id 拼写与 14 键一致；拼错=100% 占位。  
  3. 本任务只落常量 + 路径存在性自检（下一任务实现加载分支）。  
- **判定**：键名数据侧可 grep 到；14 路径真实；`--check-only --script` 过。  
- **失败**：无法一一对应 → 只保留能对上的键，其余占位；**不编造**、**不改数据**。  
- **复杂度**：中 ｜ **可并行**：否  

### T9 — C3 卡面 TextureRect 98×98 + 占位

- **前置**：T8  
- **文件**：`gu_tall_fan_hand_view.gd`（卡面构建约 294–360）  
- **步骤**：
  1. 卡面顶部插 `TextureRect`，`custom_minimum_size = Vector2(98, 98)`，`stretch_mode = 5`（keep aspect centered）；**禁止裁剪**。  
  2. 占位用网点/印章风格（MasterTheme / 既有 ColorRect），**不新增主题色**。  
  3. 下方信息：名 / 转 / 效果 **≤2 行** + 费用状态；总高仍 154。  
  4. **不改** `card_size`、领域键、快照键。  
- **判定**：check-only 过；节点树含 TextureRect+Label；插画区 98×98 未拉伸。  
- **失败**：信息放不下 → 缩字号/减行；**不**压插画区、**不**改卡高。  
- **复杂度**：中 ｜ **可并行**：否  

### T10 — C3 接线加载 + 单测

- **前置**：T9  
- **文件**：`gu_tall_fan_hand_view.gd`；新建 `tests/unit/test_tall_fan_card_art.gd`  
- **步骤**：
  1. 实现：卡槽道 id → `DAO_TEXTURE` → `load()` → TextureRect；取不到 → 占位（**新增**函数，v1 写的 `_load_gu_illustration` 不存在）。  
  2. 单测：① 有图道 texture 非 null；② 无图/未知道占位非 null；③ Label 非空。  
  3. `-gtest=res://tests/unit/test_tall_fan_card_art.gd`  
- **判定**：3 用例绿；无领域/快照键 diff。  
- **失败**：运行时 null → 查 `res://` 与 `.import`；不改资源目录。  
- **复杂度**：中 ｜ **可并行**：否  

### T11 — C3 回归：预算 + FSM + 交互门

- **前置**：T10  
- **文件**：`tools/verify_card_shape_budget.gd`、手牌相关 unit、交互门  
- **步骤**：
  1. `$GODOT --headless --path . -s tools/verify_card_shape_budget.gd`；预算数字可更新，**不改判定逻辑**。  
  2. 跑 `test_tall_fan_hand_view.gd`、`test_wenzhen_card_fsm.gd`。  
  3. 交互门 Battle 屏三键空。  
  4. 提交 `feat(card): square art + info band`。  
- **判定**：三项绿；提交仅卡面相关文件。  
- **失败**：红 → `git revert` 该提交（**不用** reset --hard），重做 T9/T10。  
- **复杂度**：中 ｜ **可并行**：否  

### T12 — 整批收口

- **前置**：T5、T6、T11（T7 若有 v1.1 一并）  
- **步骤**：
  1. `tools/test.ps1 -Suite unit` + `-Suite integration`（约 3 分钟）。  
  2. `tools/check.ps1`（ObjectDB/RID WARNING 为已知噪音，**rc=0 即过**）。  
  3. 回写 open-items：C1 闭环（附提交）、C2 线框已出、C3 按道映射+占位、C4 待你「过」。  
  4. 提交 docs；**不推送**（除非你要求）。  
- **判定**：三件套绿；状态与实际一致。  
- **失败**：定位回退到具体 W 包；禁止删按钮/加 IGNORE。  
- **复杂度**：低 ｜ **可并行**：否  

---

## 3. 预计触碰文件

| 路径 | 任务 |
|------|------|
| `tools/verify_interaction_loop.gd` | T1 临时 / T5 清白名单 |
| `scenes/ui/screens/settings_screen.tscn` | T2 |
| `scenes/ui/screens/shop_screen.tscn` | T3 |
| `scenes/ui/screens/rest_screen.tscn` | T4 |
| `docs/superpowers/specs/2026-09-10-battle-wireframe-v3.html`（新） | T6 |
| `docs/superpowers/specs/2026-09-07-battle-wireframe.html` | T6 DEPRECATED |
| `docs/superpowers/specs/2026-09-09-encounter-wireframe-v1.html`（或 v1.1） | T7 |
| `scripts/presentation/widgets/gu_tall_fan_hand_view.gd` | T8–T10 |
| `tests/unit/test_tall_fan_card_art.gd`（新） | T10 |
| `tools/verify_card_shape_budget.gd` | T11 |
| `docs/.../2026-09-10-battle-hand-overhaul-acceptance.md` | T5 |
| `docs/superpowers/reports/2026-09-10-open-items-and-decisions.md` | T12 |
| **只读不改** `scenes/ui/widgets/gu_panel.tscn` | T4 红线 |

---

## 4. 整批验收门

1. 交互门：8 屏三键空，**SETTINGS/SHOP/REST 的 occluded_known=0**（白名单已清）。  
2. unit + integration 全绿；`check.ps1` rc=0。  
3. battle v3 与实现 110×154 一致；encounter 获你「过」。  
4. 卡面：有道图显示方图、无图占位，信息 ≤2 行，无 25% 裁切。  
5. 全程无 IGNORE、无删按钮、无 `gu_panel.tscn` 修改、无命令面改动。

---

## 5. 风险与回滚

| 风险 | 应对 |
|------|------|
| Settings 换父错位 | 仅动 BackRow；失败走二次方案（插 VBox），再失败上报 |
| 删 SealMargin 误伤印章 | 只删 parent 指向缺失节点的孤儿块 |
| Rest spacer 不够 | 8→16→24；再试 Root separation；改共享组件需你批准 |
| 卡面加图后弧/FSM 错位 | T11 必跑 shape_budget + FSM + 交互门 |
| 道 id 拼写与 14 图不符 | T8 先 grep 数据，对不上只保留可对键 |

按任务独立 commit；坏哪包 revert 哪包。

---

## 6. 待你确认（仍未答复）

| # | 问题 | 推荐 |
|---|------|------|
| **§6-2** | Shop orphan SealMargin：**删** / 并入 TitleRow | **删**（TitleRow 已有完整印章） |
| **§6-3** | C3 插画：**按道映射 + 其余网点/印章占位** 可否 | 可 |
| **§6-4** | C4：现在批 encounter v1，还是先做 C1–C3 | **先 C1–C3**，C4 可并行 T7 复核后等「过」 |

回复示例：`§6-2 删；§6-3 可；§6-4 先 C1–C3` → 即按 T1 开工。  
也可：`过` = 三条全按推荐。

**未收到上述确认前，不写实现代码。**
