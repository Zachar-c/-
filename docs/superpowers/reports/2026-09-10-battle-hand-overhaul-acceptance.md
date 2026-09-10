# 战斗手牌改造与右栏按钮可达性修复 · 验收报告

> 日期：2026-09-10
> 分支：`master`（本地 == `origin/master` 提交前状态）
> 范围：手牌拖拽呈现 → 瞄准线缺失 → 竖长卡扇形迁移 → 右栏操作按钮"点不了"（两轮）
> 状态：用户真机验收通过；全量回归绿；已提交

---

## 1. 这一批到底动了什么

一次真机冒烟评审（"卡牌鼠标拖动效果、悬停解释栏不达预期"）牵出了后面四轮问题。按因果顺序：

| # | 诉求 | 根因 | 结论 |
|---|---|---|---|
| 1 | 拖拽/悬停呈现不达预期 | 呈现层缺件：影卡 0.72 透明原尺寸、解释栏全程常驻盖卡、瞄准线 2px 细线 | 影卡按比例重建放大 1.5×、解释栏改为锚定卡上方、细线改弧形矢量箭 |
| 2 | 指向性卡"缺失瞄准引导线" | 蛊卡 id 含点（`gu.gu_001`），**Godot 节点名不能含 `.`**（被清洗成 `_`），按名反查永远 null → 起点取不到、退化成鼠标位，曲线长度 0 = 什么都不画 | 组件内建 id→卡体映射；覆盖层移入 `AimLayer`(CanvasLayer 90) |
| 3 | 卡面太宽放不下手牌 → 换竖长卡 | 容量来自重叠排布而非单纯变窄 | 换 `GuTallFanHandView`（竖长卡 110×154 + 底部横扇），容量 12.5 → **19.8 张** |
| 4 | "行动值耗尽后 结束回合/炼蛊/撤退 被错误置灰禁用" | **不是 disabled**，是透明容器截获输入（两轮才挖到底） | 见 §3 |

---

## 2. 交互闭环契约的两道新闸

这一批最大的产出不是某一行修复，而是**把"能看见但点不到"变成可检测的维度**。

### 闸 1：审计 `tools/verify_interaction_loop.gd`

新增 `occluded` 维度：对每个可点按钮，求其中心点的**实际 GUI 命中者**；命中者既不是按钮、
也不是按钮的祖先 → 事件到不了按钮 → 判红。

判定必须复刻引擎 `Viewport::_gui_find_control_at_pos`，两个易错点：

- **命中顺序是「子节点逆序」深度优先**：先递归子树、子树无命中再判自身。（不是"先序找第一个"）
- **`PASS` 同样遮挡，只有 `IGNORE` 让路**。`MOUSE_FILTER_PASS` 的语义是"自己也收，并把事件
  继续交给**父节点**"，**不会**让给身后被压住的兄弟节点。

同时新增 `KNOWN_OCCLUDED` 留档表：既有未修项按 `occluded_known` 计数呈现，**新出现的遮挡一律判红**。
这样门不会因为历史问题永远红，也不会放行新回归。

### 闸 2：真实点击回归用例

`tests/unit/test_wenzhen_battle_screen.gd`
`test_ops_buttons_accept_real_clicks_despite_transparent_hand_containers`

在 `SubViewport` 里对三个按钮**真的 push 按下 + 松开**，断言 `end_turn` / `refine` / `flee`
真的被触发。**红→绿已验证**：撤销修复 → 三个全部触发 `[]` 且打印命中者 `HandMargin`；带修复 12/12。

> 教训：**"没被别的控件盖住"只是代理指标，而代理本身也会写错**（本批就是代理写错导致第一次
> "验收通过"是假的）。最稳的断言是**真的点一下**，断言业务回调被触发。

---

## 3. 右栏按钮不可达：两轮定位过程（含一次错误结论）

### 第一轮（错误）

把 `HandStage.mouse_filter` 从 `STOP` 改成 `IGNORE`，审计随即报 `occluded=[]` —— **假阴性**。
用户复报后才发现审计自身有两处错（见 §2 的两个易错点），漏掉了 `PASS` 的 `HandMargin`。

### 第二轮（真根因，实测）

`tools/dbg_ops_grey.gd` 把全量状态摊开：

```
HandStage    mf=2(Ignore) rect=(0,514 1280x206)
HandMargin   mf=1(PASS)   rect=(0,514 1280x206)   ← 元凶
battle_hand  mf=1(PASS)   rect=(30,524 1040x186)
HandArea     mf=1(PASS)   rect=(30,556 1040x154)

「结束回合」rect=(1094,522 160x52)  最上层命中=HandMargin
「炼蛊」    rect=(1094,584 160x32)  最上层命中=HandMargin
「撤退」    rect=(1094,626 160x32)  最上层命中=HandMargin
```

**`margin_right = 210` 只把卡让开，不改容器自身矩形** —— `HandMargin` 仍横跨 1280、纵向叠到
屏幕下沿，正好包住右栏 OpsDock 整列。按钮 `disabled=false`、`modulate=1`、父链无压暗、
无可见覆盖层，**查属性一律正常**。

### 修复

`battle_screen.tscn`：手牌**整条容器链**声明 `mouse_filter = 2`（`HandStage` / `HandMargin` /
`battle_hand` / `HandArea`）。代码里原先那行运行时赋值撤掉，单一来源放场景。
`mouse_filter` 只作用于节点自身，卡的 hover / 点击 / 拖拽瞄准手势全不受影响。

---

## 4. 审计顺带暴露的三处既有遮挡（本批未修，已留档）

三处均已核实**不是动画瞬态**（把审计等待从 0.8s 拉到 2.5s 仍复现）；**已于 C1（2026-09-10）全部修复**，`KNOWN_OCCLUDED` 清空：

| 屏 | 被盖住 | 原遮挡物 | 修复 |
|---|---|---|---|
| **Settings** | 整页内容（静音 / 分辨率 / 保存 / 读档） | `BackRow` 被 root `MarginContainer` 拉伸整屏 | `BackRow` 挂到 `SettingsStage/Content` + anchors 右下；装饰层 `SettingsStage`/`Content`/`SealPanelContainer`/`SealCenter`/`Nav` 设 `mouse_filter=IGNORE` 让顶栏可点；`settings_screen_view.gd` 路径同步 |
| **Shop** | 4×「购买此蛊」+「离开黑市」+ 顶栏两个 | 孤儿 `SealMargin` 整屏 | **删除**孤儿节点块（TitleRow 内印章保留） |
| **Rest** | 顶栏 手记 / 图鉴 | `PanelMargin` 压顶栏 | `StageContent` 设 `mouse_filter=IGNORE`（决策面板自身仍吃点击）+ `TopSpacer` 16px |

---

## 5. 验证证据

| 门 | 命令 | 结果 |
|---|---|---|
| 交互闭环（全屏） | `-s tools/verify_interaction_loop.gd` | 8 屏全部 `dead=[] no_ui_click=[] occluded=[]`；`occluded_known` **全 0**（C1 已清白名单） |
| 战斗屏（含真实点击） | `-gtest tests/unit/test_wenzhen_battle_screen.gd` | **12/12** |
| 手牌 FSM | `-gtest tests/unit/test_wenzhen_card_fsm.gd` | **18/18** |
| 扇形组件协议 | `-gtest tests/unit/test_tall_fan_hand_view.gd` | **2/2** |
| UI 规则守卫 | `-gtest tests/unit/test_ui_rules_guard.gd` | **7/7** |
| 单元全量 | `-gdir res://tests/unit` | **1178/1178**，35227 断言 |
| 集成 | `-gdir res://tests/integration` | **31/31** |
| 契约漂移 | `-s tools/check_contract_drift.gd` | ok（157 标识符） |
| 五态渲染探针 | `-s tools/verify_hand_drag_render.gd` | 5/5 ok，`FAILED=0` |
| 布局预算探针 | `-s tools/verify_card_shape_budget.gd` | `FAILED=0`（手牌区 / 战场区 / 卡带 / 敌人卡全部合规） |
| 狐狸生成 | `-s scripts/guitkx_build.gd` | 0 errors |
| 启动探针 | `--quit-after 3` | exit 0 |
| 空白检查 | `git diff --check` | 干净 |

**真机**：用户复测通过。

---

## 6. 本批新增/删除的文件

**新增**

- `scripts/presentation/widgets/gu_tall_fan_hand_view.gd` — 竖长卡底部横向扇形手牌组件
- `scenes/ui/widgets/gu_tall_fan_hand.tscn`
- `tests/unit/test_tall_fan_hand_view.gd` — 瞄准广播→敌人高亮接线协议
- `tools/verify_hand_drag_render.gd` — 五态渲染探针（SubViewport + 真实点击路径）
- `tools/verify_tall_fan_render.gd` — 扇形五态探针（真实敌人卡 + 高亮断言）
- `tools/verify_aim_line_real_run.gd` — 真实对局瞄准线探针
- `tools/verify_card_shape_budget.gd` — 布局预算实测（现役 vs 旧形态）
- `tools/dbg_ops_grey.gd` — 按钮不可达诊断（全量摊开 + 引擎命中算法）
- `docs/superpowers/plans/2026-09-10-*.md` × 4（拖拽优化 / 视觉修复 / 卡形迁移清单 / 解释栏双实现对比）

**删除**

- `scripts/presentation/widgets/gu_battle_hand_view.gd`、`scenes/ui/widgets/gu_battle_hand.tscn`
  （被扇形组件取代；含内建 tooltip 的 `gu_fan_hand_view.gd` 同批作废）

**关键修改**

- `scripts/presentation/screens/battle_screen_view.gd`（**净删约 280 行**：手势机件移入组件）
- `scenes/ui/screens/battle_screen.tscn`（手牌容器链 IGNORE；去 `CenterWrap`；`AimLayer`）
- `tests/unit/test_wenzhen_battle_screen.gd`（可达性 → **真实点击**用例）
- `tools/verify_interaction_loop.gd`（`occluded` 维度 + 引擎算法 + 留档表）
- `docs/contracts/2026-09-02-page-inventory-requirements.md`（手牌手势口径 + 可达性验收项）
- `AGENTS.md`（交付门加入 `occluded=[]`）

---

## 7. 沉淀

- **长期备忘** `.workbuddy/memory/MEMORY.md`：新增 4 条——`PASS` 也遮挡（并更正了此前写反的结论）、
  容器会接管子节点矩形、`tscn` 孤儿节点被整屏挂载、断言补间要等真实时间。
- **技能** `~/.workbuddy/skills/godot-ui-interaction-verification/`：新增"按钮点了没反应"完整排查法
  （引擎命中的正确算法、`PASS` 语义、容器拉伸、孤儿节点），并新增"回归测试别只断言代理指标"一节。

---

## 8. 未完成

1. ~~三处既有遮挡~~ **已闭环（C1，2026-09-10）**。
2. **线框稿 v3**：`2026-09-07-battle-wireframe.html:75` 的 `.card{width:168px;height:74px}` 已随换卡形失效。（C2 进行中）
3. **卡面版式与插画**：现役是纯文字四行，竖长卡下方留白明显；`assets/wenzhen/gu/*.png` 全是 **1:1 方图**，
   塞进 1:1.4 要裁 25%。（C3 按道映射+占位进行中）
4. **真窗动态手感**（跟手度 / 回弹 0.22s / 弧箭粗细）：按 AI 契约待用户主动要求做键鼠复测。
