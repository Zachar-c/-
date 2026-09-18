# 万物皆蛊 —— 道痕 / 兼修代价 / 道痕伤势 的统一语义映射与重构方案

- 日期：2026-09-11
- 背景：`docs/superpowers/reports/2026-09-11-lore-alignment-audit.md` 指出「身体层整体缺失」——
  道痕、兼修代价、道痕伤势在原文里本是一体，我们却只留了一个无规则效果的 `school` 标签
- 本文目标：按「**万物皆为蛊虫**」把这三项**统一转译到"蛊"这一载体的语义上**，并给出
  模块调整清单、复用/新增边界、分阶段计划
- 前置原则（项目既有，非本文发明）：规格总纲第 2 条
  >「**万物皆可由蛊承载，但不能无来源地抽象。** 资质、肉身改造、侦察、交易能力和修行服务应优先落到
  > 具体蛊虫、杀招、蛊方、人物或场景行为上。」
  本文即这条原则在「身体层」的一次具体执行。

---

## 0. 关于"该事件"的语义确认（请校正）

> **2026-09-11 更正（依据 `reports/2026-09-11-gu-ontology.md`）**：本文初版把道痕描述为
> "蛊的残留 / 无主蛊意"，**层级方向错了**。原文（「凡蛊只是天地法则的一块细微碎片，
> 仙蛊则是大道一角，天地至理的完整一段」）表明：**道痕（法则碎片）是更基本的单位，
> 蛊是成规模的碎片聚合体**；身体上的道痕与蛊**同源**，只是规模与受控性不同。
> 下文表格中"残留"一类比喻应按此理解（复用结论不变，措辞以本体论为准）。

本文将「万物皆为蛊虫」理解为**一个世界观的统摄命题**（一切现象都可归因为蛊及其法则碎片的活动），
因而"统一转译"＝**把机制表达为"蛊的某种存在形式"，而不是新建独立系统**。

据此，身体层的一切概念都被视为**蛊的不同状态**：

| 蛊的状态 | 语义 | 对应机制 |
|---|---|---|
| 有主之蛊 | 蛊师持有的蛊（法则碎片的可用形态） | `gu_instances`（已实现） |
| **无主之蛊 / 残留** | 附着于身体、不再受控的蛊意 | **道痕** |
| **多道残留相斥** | 不同法则碎片在同一身体上互斥 | **兼修代价** |
| **残留之蛊的伤口** | 残留持续压制身体自愈 | **道痕伤势** |
| **以蛊洗蛊** | 用相应道途的蛊冲刷、带走残留 | **洗净**（原文：以蛊虫冲刷身体洗净残留道痕） |
| **以蛊观蛊** | 用蛊显化、读取他人身上的残留 | **线迹式侦查** |

> 若你说的"该事件"指的是别的东西（例如某个具体的事件节点/事件系统），请指出——
> 本文的映射表可以整体平移，只需换掉"残留"这一层比喻。

---

## 1. 现状：可复用的资产（都已存在于代码中）

这一节是"优先复用"的前提——**下列资产全部已在库里，不需要新建系统**。

| 资产 | 位置 | 语义 | 与道痕的亲和度 |
|---|---|---|---|
| **肉身印记** `body_imprints` | `run_state.gd`（字段）、`social_command_rules.gd:457-475`（表）、`_take_body_imprint` | 已进 RunState 的身体性获得物；每条 = `id + facts[] + 代价(injury/lifespan_debt)` | **极高**：`iron_bone` 就是"获得防御事实 + 潜行缺陷事实"的成对代价；`ice_skin` 带 `injury:1`；`three_watch` 带 `lifespan_debt:1` |
| **诅咒通道** `curse.json` + `curse_registry` + `remove_curse` | `data/curse.json`、`scripts/domain/curse_registry.gd`、`refine_command_rules` 的移除命令 | 有 `intensity` + `escalation_per_stage`（随层升级）+ `removal_base_cost`（付费移除）的状态；现有三条：**蛊蚀**、元石滞胀、**经脉封蛊** | **极高**：命名本身已是蛊语义；"有强度、会恶化、要花钱洗掉"正是道痕伤势的形态 |
| **事实记录** `known_facts` | `run_state.gd`；消费方 `journal_builder` / `death_report_builder` / `encounter_session_resolver` | 无规则效果的"知道了什么" | 高：道痕的**种类与可观测性**记录 |
| **流派标签** `school` | `gu.json` / `schools.json` / 快照 | 蛊与流派的关联 | 高：道痕的"道"直接取蛊的 `school`，不必新造罗盘 |
| **流派规则钩子** `school_rules.gd`（4 函数） | `scripts/domain/school_rules.gd` | `blood_stacks` / `add_blood_stacks`（**跨回合层数的先例**）、`material_fuel`、`is_soul` | 高：道痕层数/排斥直接照抄 `blood_stacks` 的形状 |
| **代价通道** `injury` / `lifespan_debt` / `life_cost` | `run_state.gd`、蛊槽字段 | 已知的真实代价，且已有 `life_cost_depleted` 显式死因 | 高 |
| **侦察语义** `recon` role + `marked` 状态 | `v1_battle.json` 的 role 表、战斗 statuses | "看见/标记" | 中：观测道痕可落在此 |

**结论**：身体层**不需要新系统**。缺的是把这几样资产**按"蛊的残留"这一语义连起来**。

---

## 2. 语义映射表（核心交付）

| # | 原文概念 | 统一语义（蛊） | 复用 | 需要新增 | 边界说明 |
|---|---|---|---|---|---|
| M1 | **道痕** | **法则碎片**（世界与蛊的共同基本单位）：身体上的道痕 = 与蛊同源、但规模更小且不受控的碎片。`mark_<school>` = 某道途的碎片印记 | `state.body_imprints` 容器与"id + facts + 代价"结构；`school` 作为道归属 | **数据**：为 20 道各注册一条印记 id（命名 `mark_<school>`）；层数用 `count(同 school 印记)` 或新增一个轻量计数键 | 复用 `body_imprints` 的**结构**，不新建 `dao_marks` 系统；若需层数>1 才考虑加一个 `school_marks: {school: int}` 键。**道痕是双面的**：同道越深→共鸣增幅越强（「道痕越多，我使用力道仙蛊就越加厉害」），多道混杂→互相排斥成伤 |
| M2 | **兼修代价**（多道相斥） | 同一身体上不同 school 的残留**互相排斥** | `BODY_IMPRINTS` 里 `iron_bone` 的"获得 + 缺陷成对 fact"模式；`school` | **1 个域函数**：`school_rules.cross_school_penalty(state, catalog)`（仿 `blood_stacks`）；负面效果落 `known_facts`（记录）+ 现有代价通道（数值） | 只做"**两种以上残留 → 生成缺陷 fact + 一条可移除的状态**"，**不引入全局克制倍率**（规格 §2.3） |
| M3 | **道痕伤势**（难缠、抵消恢复、阻止疗伤） | 残留之蛊的**伤口**：持续压制自愈 | **`curse.json` 通道**（`intensity` / `escalation_per_stage` / `removal_base_cost`）+ `remove_curse` 命令 | **数据 1–2 条**（如 `mark_wound`「道痕伤势」）；若必须"抑制治疗"这一具体效果，则需扩 `CURSE_EFFECT_IDS`（3 处白名单 + 1 个函数）——**列为可选** | 首选**零引擎**：用 `escalation_per_stage` 表达"越拖越坏"，用现有 effect 近似；新增 effect 种类只在确实需要"治疗抑制"时才做 |
| M4 | **洗净**（以蛊冲刷身体） | 用相应道途的蛊**带走残留** | `remove_curse` 命令 + 现有用蛊路径（`play_gu` / 休息期用蛊） | **数据**：1–2 条"冲刷"配方（输入 = 同道蛊 + 蛊材，输出 = 移除一条 `mark_*`） | 复用现有配方/移除通道，不新建"净化"系统 |
| M5 | **观测道痕**（线迹蛊） | 用蛊**显化**他人残留 | `recon` role + `marked` 状态 + `known_facts`（情报） | **数据**：1 条显式 `v1_effect`（或一条 recon 蛊的 `synergy_hooks`） | 让"情报"仍经既有侦察通道，不新增信息旁路键 |

### 映射后的因果链（可直接读成一句话）

```
用异道的蛊（M4 冲刷）→ 带走身体上的残留（M1 道痕）
多道残留并存（M2）→ 互相排斥 → 生成缺陷 fact + 可移除状态
残留久留不洗（M3）→ 伤势升级（escalation_per_stage）→ 压制恢复
对手身上有残留（M5）→ 用蛊显化 → 读出他的道途与深浅
```

---

## 3. 需要调整的模块（清单与改法）

| 模块 | 现状 | 调整 | 类型 |
|---|---|---|---|
| `scripts/domain/school_rules.gd` | 4 函数 | 增 `school_marks(state)`、`cross_school_penalty(state, catalog)`（照 `blood_stacks` 形状：纯函数、读 state、返回 int/Array） | **新增函数**（复用同文件） |
| `scripts/domain/social_command_rules.gd` | `BODY_IMPRINTS` 表 + `_take_body_imprint` | 表里登记 `mark_<school>` 条目（数据式扩展）；`_take_body_imprint` 逻辑不动 | **改数据表** |
| `data/curse.json` | 3 条（蛊蚀 / 元石滞胀 / 经脉封蛊） | 增 `mark_wound`（道痕伤势）等 1–2 条 | **改数据** |
| `scripts/domain/curse_registry.gd` | `EFFECT_KINDS` 白名单 3 项 | **仅在需要"治疗抑制"时**扩一项 + 一个函数 | 可选扩展 |
| `scripts/domain/content_catalog.gd` | `CURSE_EFFECT_IDS` 校验 | 同上，与 registry 同步 | 可选扩展 |
| `refinement_recipes` | 386 条 | 增 1–2 条"冲刷"配方（M4） | **改数据** |
| `scripts/presentation/snapshots/hall_snapshot.gd` / `battle_snapshot.gd` | 已有 `body_imprints` / `known_facts` / curse 投影 | 增加道痕投影键（哪个道、几层、排斥中） | **改快照**（+契约回写） |
| 契约文档 | — | §快照键与命令面补道痕相关键 | **改文档** |

**不改的**：`v1_battle_resolver` 的结算主流程、`gu_instances` 账本、存档格式（除非加 `school_marks` 键）。

---

## 4. 复用与新增边界（明确画线）

**复用（不改结构，只填数据或用既有函数）**
- 道痕的**容器**＝`state.body_imprints`
- 道痕伤势的**恶化与移除**＝`curse.json` 的 `escalation_per_stage` / `removal_base_cost` + `remove_curse`
- 兼修代价的**表达模板**＝`iron_bone` 式的"获得 + 缺陷"成对 fact
- 道痕的**道归属**＝蛊的 `school` 字段
- 洗净＝既有移除/配方通道
- 观测＝既有 `recon` / `marked`

**新增（且仅此）**
1. `school_rules` 的 **2 个纯函数**（层数、跨道惩罚判定）
2. **数据条目**：`mark_<school>` 印记、`mark_wound` 诅咒、1–2 条冲刷配方
3. 快照的**投影键**（供 UI 展示"身上有哪几道残留"）
4. （可选，仅在必要时）1 个 curse effect kind

**明确不做（防范围失控）**
- ❌ 不新建 `DaoMarkSystem` / 不新建第二套状态机
- ❌ 不改 `gu_instances` 账本与蛊实例结算路径
- ❌ 不引入跨流派的**全局克制倍率**（规格 §2.3 红线）
- ❌ 不加局外成长（图鉴仍是唯一跨局解锁）
- ❌ 不新增平行计数器（层数优先从 `body_imprints` 派生，不得已才加 `school_marks` 键）

---

## 5. 分阶段实施与验收

| 阶段 | 内容 | 触及文件 | 验收 |
|---|---|---|---|
| **G1 数据先行**（零引擎） | 20 条 `mark_<school>` 印记登记；1 条 `mark_wound` 诅咒；1 条冲刷配方 | `social_command_rules.gd` 的 `BODY_IMPRINTS`、`data/curse.json`、`refinement_recipes` | 单测：取得印记 → 出现对应 fact；诅咒可被移除；配方真能冲掉一条残留 |
| **G2 跨道排斥** | `school_rules` 两函数 + 排斥落 fact/状态 | `school_rules.gd`、必要时 `curse.json` | 单测：单道无惩罚；两道并存→产生缺陷 fact；移除一道后惩罚消失（**确定性、同种子同结果**） |
| **G3 伤势语义** | `mark_wound` 接 `escalation_per_stage`；是否新增 effect 种类在此决策 | `curse.json`、可选 `curse_registry.gd` | 单测：强度随层上升；移除成本随强度变化；战斗中不可静默致死 |
| **G4 观测** | 1 条侦察蛊显化对手道痕 | `gu.json`（显式 `v1_effect` 或 `synergy_hooks`） | 单测：使用后目标道痕进入 `known_facts` |
| **G5 表现** | 快照投影 + 契约回写 | `hall_snapshot.gd`/`battle_snapshot.gd` + `docs/contracts/` | 契约漂移守门绿；`verify_interaction_loop` 三键全空 |

每阶段的通用门：`tools/test.ps1 -Suite unit` + `-Suite integration` 全绿。

---

## 6. 风险与合规

| 风险 | 应对 |
|---|---|
| **变成第二套系统**（最主要的失败模式） | 边界已画死：容器用 `body_imprints`、恶化用 curse、代价用既有通道；新增仅"数据 + 2 个纯函数 + 快照键" |
| **存档兼容** | 纯数据扩展不改变存档形状；**若**最终需要 `school_marks` 键，才提升 `SAVE_VERSION` 并按缺键空迁移 |
| **与 curse 语义混淆** | `mark_wound` 属"身体残留"语义，与"蛊蚀/经脉封蛊"并列而非替换；命名统一带 `mark_` 前缀便于筛选 |
| **惩罚过重导致无法游戏** | 排斥只做"缺陷 fact + 一条可移除状态"，不做数值碾压；且必须可被 G1 的冲刷配方解除 |
| **静默致死** | 伤势走 curse 通道（非致死通道）；任何致死仍须走既有预检 + 提示（红线） |

---

## 7. 与其他在办设计的关系

- 与**杀招**：原文「宗师可构思全新杀招」→ 道痕层数/炼道境界可作为"保存杀招"的解锁条件之一（G2 产出的层数正好是现成门槛信号）。
- 与**剑道**：剑道「剑意侵蚀」在本文语义下即"剑道残留反噬自己"——**同一套映射**，不需要为剑道单开机制。
- 与**评估报告**的 P1/P2/P3 建议：本文覆盖 P1（道痕）的全部，并为 P2（炼道境界闸门）提供数据基础（层数可作门槛）。
