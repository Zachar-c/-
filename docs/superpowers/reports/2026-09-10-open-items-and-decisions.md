# 待办 / 待排 / 待裁定清单（2026-09-10）

> 口径：只列**当前仍需动作**的事项。已闭环的放 §5 作对照，不占待办。
> 优先级：**P0** 阻断玩法或用错会伤人 · **P1** 本批收尾（半成品挂在那） · **P2** 队列 · **P3** 债务/长期挂账。
> 数据来源：`AGENTS.md`、`docs/superpowers/plans/2026-09-10-tech-debt-atomic-execution.md`（执行板 §6）、
> `docs/superpowers/plans/2026-09-09-visual-route-batch-plan.md`（§1.5 原子队列）、
> `docs/superpowers/reports/2026-09-10-battle-hand-overhaul-acceptance.md`、`PONYTAIL-DEBT.md`，
> 以及本轮对代码/数据/测试的**实测探测**（下文标注为「实测」的均已核对到文件）。

---

## 0. 速览

| 类别 | 数量 | 含义 |
|---|---|---|
| **A. 已排出（等执行）** | 7 | 计划/优先级都已定，不需你决策，只等排期开工 |
| **B. 等待你排出** | 4 组 | 可开工但需要你给顺序或时间窗（多与美术/真窗有关） |
| **C. 需要你决策** | 6 | 卡在我这里，等你一句话才能动 |
| **D. 状态漂移（需你点头才修）** | 3 | 我在核对中发现文档与代码不一致，未擅自动 |

---

## A. 已排出——等执行（**不需要你决策**）

| # | 事项 | 状态 | 优先级 | 下一步行动 | 依赖 / 验证门 |
|---|---|---|---|---|---|
| A1 | **E5a** `verify_pacing_density` 扩 4 分类统计 | **已收口**（2026-09-10）：逐层四分类 + 40 种子聚合战斗占比门禁；单种子稀疏只标 `sparse`。门：`godot --headless --path . -s tools/verify_pacing_density.gd` → `E5a PASS` | P1 | 无（闭环） | AGG battle_share≈0.593 ∈ [0.50,0.60] |
| A2 | **E5b** `route_diversity` 全模板可达冒烟 | **已收口**（2026-09-10）：新建 `tools/verify_route_diversity.gd`，20 种子断言 `category_pools` 30 模板 + 关底台必现。门：`E5b PASS` | P1 | 无（闭环） | pool 30/30 appeared |
| A3 | **E6** 敌人按层品质随机 | **已收口**（2026-09-10）：实现落在 tip `c806215`（`enemy_roll` / `enemy_weights` / `EnemyCatalog.roll_enemy_ids` / 非锚点抽取 / facade 优先读 roll）；本会话启用 `tests/unit/test_enemy_roll.gd`（原 `_disabled_` 前缀）**15/15 绿**；unit 1214 + integration 31 全绿。**不再需要** per-enemy `weight`（tier 权重 + 层 rank 带）；`enemies.json` 排除令已解除 | P1 | 无（闭环） | 验证：`-gtest=res://tests/unit/test_enemy_roll.gd` |
| A4 | **E7** 商店按层随机 | **已落地**（AGENTS：`shop_stock` + `test_shop_roll.gd` 9/9 绿，2026-09-10 核） | P2 | 无（闭环；open-items 原「shop_roll 不存在」过期） | 验证：`-gtest=res://tests/unit/test_shop_roll.gd` |
| A5 | **E 线全量回归** | **已收口**（2026-09-10）：push 后 unit **1214** + integration **31** 全绿；E5a/E5b 工具 PASS | P2 | 无（闭环） | 本地=origin `fcff146` |
| A6 | **D1b 实现批**（古方知识模型） | **已落地并核验**（2026-09-10）：`SynthesisRules.pair_output_id/preview/execute`、零门槛 `refine_free_pair`、首炼授古方、`？？？` 三层揭示、黑市 `gu_fang_unlock`、炼蛊屏 pair 面板；`mx_` 固定方已清零；名方仍在。相关单测 knowledge/refine 21 绿。open-items 原「排队中」过期 | P2 | 无（闭环） | `-gtest=res://tests/unit/test_synthesis_knowledge.gd` |
| A7 | **`run_controller.gd` 减行 &lt;900** | **已收口**（2026-09-10）：1111 → **888**；外提 rejection/opening/settings/battle/travel/dialogue/ending + `_set_view`。unit 1214 + integration 31 绿 | P3 | 无（闭环） | 绝对行数 888 |

> 另有一项**长期挂账**（不单独占行）：验证遗留 —— Dialogue Manager invalid UID、ObjectDB/RID 泄漏
> （2026-09-06 复测 20601 实例仍复现）。状态：未修，P3，无明确下一步，等有人踩到再收。

---

## B. 等待你排出（可开工，但需要你给顺序或时间窗）

| # | 事项 | 状态 | 优先级 | 卡在哪 | 你只需给 |
|---|---|---|---|---|---|
| B1 | **V2→V4 线框稿**（Npc / Ending / ContentError） | **可开工**（C4 Encounter v1 已获批准，风格基线就绪） | P1 | 等你排期/直接派发 | 无（已解除阻塞） |
| B2 | **V5–V8 tscn 实施**（4 屏） | 未开工 | P1 | 依赖 B1 对应线框稿批准 | 同上，逐屏批准 |
| B3 | **真窗键鼠验收**（AI 契约：只有你主动要求才做） | 挂起 | P1 | 契约规定无你指令不做 | 指定要验哪几项 |
| B3a | └ W10 `continue_run` 真窗验收 | 挂起（执行板 C 轨遗留） | P1 | 同上 | — |
| B3b | └ S 阶段全流程真窗验收 | 挂起 | P2 | 依赖 D1b | — |
| B3c | └ 手牌**动态**手感（跟手度 / 回弹 0.22s / 弧箭粗细） | 挂起（本轮只有静态截图） | P2 | 同上 | — |
| B4 | **卡面版式与插画** | 未开工 | P2 | 需先定版式比例（插画区/信息区），才谈出图 | 美术方向一句话 |

---

## C. 需要你决策（**卡在我这里**）

| # | 事项 | 我的建议 | 不决策的后果 |
|---|---|---|---|
| **C1** | **三处既有遮挡怎么修**（已进 `KNOWN_OCCLUDED` 留档，见验收报告 §4） | ✅ **已闭环**（方案 B，`cfd7c9f`）：BackRow 换父+anchors；Shop **删** orphan SealMargin；Rest StageContent spacer+pass-through。门禁 8 屏三键全 0，白名单已清 | — |
| **C2** | **战斗屏线框稿 v3** | ✅ **已出**（`ee67581`）：`2026-09-10-battle-wireframe-v3.html`，卡 110×154；旧稿 DEPRECATED | 等你过目线框 |
| **C3** | **`assets/wenzhen/gu/*.png` 全是 1:1 方图** | ✅ **已按道映射实现**（`ee67581`）：98×98 keep-aspect + 信息带；`school_id` 进手牌快照；`test_tall_fan_card_art.gd` 3/3 | 真窗手感待你要求 |
| **C4** | **V1 Encounter 线框稿批准**（`2026-09-09-encounter-wireframe-v1.html`） | ✅ **已批准**（2026-09-10 用户「过」） | B1 V2–V4 可开工 |
| **C5** | **是否推送** | ✅ 已闭环（本会话多次随用户指令推送；本地=origin `8420f73`） | — |
| **C6** | **`AGENTS.md` 当前待办是否本轮同步**（见 D1） | ✅ 已闭环（E1–E7 / D1b / A7 状态已写入 AGENTS） | — |

---

## D. 状态漂移（我在核对中发现，**未擅自修改**，等你点头）

| # | 漂移点 | 实测证据 | 建议 |
|---|---|---|---|
| **D1** | `AGENTS.md` §当前待办 把 **E1–E7** 列为整批待开工 | 实测：**E1a/E1b/E2a/E2b/E3a/E3b/E4a/E4b/E4c 均已落地**（`pacing.json` 5 层 `category_weights` 齐备；`map_generator` 已按分类抽取；`test_category_route.gd` 6 用例；`mode_groups` 已进契约；`rest/refinement/cultivation` 已统一走 Rest 屏）。真正剩的只有 **E5/E6/E7** | 把该条收敛为"E5/E6/E7 收尾"，并删掉已完成的 V1 描述里的过时措辞 |
| **D2** | 同条**交互闭环契约**只写 `dead=[] no_ui_click=[]` | 本轮已扩为追加 `occluded=[]`（`AGENTS.md:112` 已更新，但 `:58` 那处待办描述未同步） | 同步为三键口径 |
| **D3** | `PONYTAIL-DEBT.md` 已清账条目仍在讲 **`gu_battle_hand_view` 补 `_gui_input`** | 该组件已随本批删除（`6c96623`）；它引用的两个测试**仍存活**（`test_wenzhen_card_fsm.gd:95/130`），锁的行为也仍成立——只是描述的实现位置过期 | 把该行改为现役组件 `GuTallFanHandView`，并补上本轮新增的三条回归（影卡不透明放大 / 弧箭起点与转色 / 解释栏不挡卡） |

---

## E. 本轮已闭环（对照用，**不占待办**）

- 手牌改造全链：拖拽/悬停呈现 → 瞄准线（带点 id 根因）→ 竖长卡扇形迁移（容量 12.5→19.8）→
  右栏按钮可达性（两轮，含我第一轮的**错误结论**）→ 交付门加 `occluded` 维度。
  提交 `6c96623`，验收报告 `docs/superpowers/reports/2026-09-10-battle-hand-overhaul-acceptance.md`。
- 技术债三轨：A @ `49ffbe5`（resolver 2407→205）、B @ `fc7cb3e`（builder 2373→767）、C @ `158aef4`，
  执行板 §6 看板全 done（唯 `run_controller` 行数项转入 A7）。
- E 线：E1–E4 全部落地（见 D1 证据）。
- `ponytail:` 标记 3 处 == 台账 3 行，**无未登记债务**。

---

## 建议的下一批（等你确认即可开工）

若要"最短路径清空 P1"：**先 A1+A2（E5 收尾，独立、无阻塞）→ 再 A3+A4（E6/E7）→ 顺带 C6 同步 AGENTS.md**。
线上 V 线（B1/B2）与真窗验收（B3）由你另行发令穿插，两者不冲突。
