# Q7 辅助蛊实义化实施计划（2026-09-12，待批复）

> 状态：**仅供审阅，未实施**。批复后按阶段执行，每阶段独立提交、先测试后实现。
> 取证口径：`data/gu.json` 802 只中 recon/logistics 共 **151 只**（19 流派），`v1_effect` **全部为空**；
> 战斗核经 `default_v1_effect` 走 `data/v1_battle.json → default_effect_by_role` 兜底
> （recon→`status/marked/1`，logistics→`status/bound/1`）；`bound` 全仓无消费者（死状态）；
> `sword_intent` 机具（cap 5、回合末减半）在 `school_rules.gd` 落桩但**零生产调用点**。

---

## 一、实施步骤

### 阶段 0：数值表 + 语义裁定（先审后动，剑道落地任务书 T1 惯例）

- **目标**：把"每只辅助蛊落到哪个通道、数值多少"变成一张可批复的表，避免边写边定。
- **工作项**：
  1. 产出 `辅助蛊语义分配表`：151 只按 流派×role×rank 列出（兜底通道 → 目标通道 → 数值 → rank 缩放）。
  2. 向用户提交 4 个裁定点（见 三-4）：sword_intent 消费语义 / logistics 默认通道 / recon 双通道与否 / rank 缩放是否沿用 RANK_SCALED_KINDS。
- **交付物**：分配表（本文件附录或独立 spec）+ 4 个裁定的推荐方案。
- **验收**：用户批复分配表，无"未裁定先动数据"。

### 阶段 A：剑意接线（唯一引擎改动面，最小侵入）

- **目标**：`sword_intent` 从契约桩变成活通道——有生产者、有衰减、有消费者。
- **工作项**（先写失败测试再实现）：
  1. `_apply_effect` 新增 kind `"sword_intent"`（amount → `SchoolRulesScript.add_sword_intent(next, amount)`），登记 `V1_EFFECT_KIND_IDS`。
  2. `end_turn` 回合末调用 `decay_sword_intent`（跨回合 50% 减半，函数已有）。
  3. 消费端（按批复 D1）：剑道 strike 伤害 += sword_intent 层数（实现点：`_strike_enemy` 调用侧按 slot.school=="sword" 加成，或 `_apply_effect` strike 分支内联）。
  4. 快照/预览暴露 `sword_intent` 层数（battle_snapshot 增键 → **Shared 区，走 5 步协议**，同步回写 domain-ui 契约文档）。
- **交付物**：resolver/school_rules 改动 + `test_sword_intent_wiring.gd`（生产→衰减→消费→跨回合存续四断言）+ 快照键契约回写。
- **验收**：新测试红→绿；剑道契约 27/27 不回归；unit 全量不新增红。
- **回滚**：单提交 revert。

### 阶段 B1：剑道 10 只显式 v1_effect（recon5 + logistics5）

- **目标**：剑道辅助蛊按五类语义逐只归位，摆脱兜底。
- **工作项**：
  1. 按分配表给 `sword_rec_5_*`（5 只）与 `sword_log_1_*`（5 只）写显式 `v1_effect`（通道：sword_intent / support_bonus / life_cost+CONSUME_ON_USE；mark_sword 属 T10 长线，本批只留接口位）。
  2. 起势链通道（双剑蛊同轮）确认无需新数据——已有，分配表仅登记哪些蛊入起势档。
  3. `content_catalog.validate` 全量过 + rank 门禁复核。
- **交付物**：gu.json 10 条显式 effect + `test_q7_sword_support_gu.gd`（逐只断言效果与文案一致）。
- **验收**：逐只效果断言绿；战斗内实际结算=卡面文案（透明度红线）。

### 阶段 B2：全流派兜底升级（141 只，数据驱动一次到位）

- **目标**：不逐只手写 141 条——升级 `default_effect_by_role`，让兜底本身落到活通道。
- **工作项**：
  1. recon 兜底：`status/marked/1` **+** `support_school: <own school>/support_bonus: 1`（刻痕+支援双活通道；support 键随任意 kind 生效的机制已存在，零引擎改动）。
  2. logistics 兜底：`bound`（死状态）替换为批复 D2 选定通道（推荐 heal 1，后勤=恢复语义）。
  3. `content_catalog` 对 `default_effect_by_role` 增加与 `_validate_v1_effect` 同口径的校验（含 support 键）。
  4. 特例豁免名单：个别流派若语义不符（如 refine/light 的 14/13 只），走 per-gu 显式 override，数量控制在个位数。
- **交付物**：v1_battle.json 兜底表更新 + catalog 校验 + `test_q7_role_defaults.gd`（每流派抽一只断言兜底效果）。
- **验收**：151 只中 ≥140 只经兜底获得活通道；无任何蛊"烧真元无事发生"。
- **风险**：数值平衡面——heal/shield 入兜底会改变全流派战斗强度，需 seed 对照（改前后各跑一次既有 seed 抽查）。

### 阶段 C：文案=结算逐只核对（透明度红线）

- **目标**：卡面文字与实际结算一致（红线"UI 缺陷要断言界面不要只断字段"）。
- **工作项**：`DisplayText` / action_preview 对新通道的文案模板；151 只按分配表核对（兜底类按 role 文案模板批量核对，剑道 10 只逐只核对）。
- **交付物**：文案模板 + 文案断言并入 B1/B2 测试文件。
- **验收**：无"文案说 X 结算做 Y"。

### 阶段 D：全量回归 + 收尾

- **交付物**：unit 全量 / integration / 交互门三绿；剑道 27 契约回归；Q8 死路径顺带清理（`_distance_adjusted_damage`/`_enemy_pursuit`，属 Triggered 清单，本批顺带）。
- **每阶段一提交**；B2 数值若需回调，走独立"调参提交"。

## 二、代码关系

```
data/gu.json (151 只 recon/logistics, v1_effect 空)
   └─▶ v1_battle_resolver._build_gu_slots (:159-161)
         └─ 空效果 ─▶ default_v1_effect (:138) ─▶ role_default_table ─▶ data/v1_battle.json default_effect_by_role
   └─▶ 显式 v1_effect 优先（B1 剑道 10 只走此路）

结算链（本计划触及点）：
v1_battle_resolver._apply_effect (:380)
   ├─ match kind：新增 "sword_intent" 分支（阶段 A1）      ← 唯一新增 kind
   ├─ support_school/support_bonus 尾块 (:418-424) 已存在  ← B2 recon 兜底零改动复用
   └─ _strike_enemy (:454) ← 消费端剑意加成（阶段 A3，批复 D1）
v1_battle_resolver.end_turn (:619)
   └─ 新增 decay_sword_intent 调用（阶段 A2）
SchoolRules.add_sword_intent/decay_sword_intent (school_rules.gd:35/40)  ← 已落桩，只接线
content_catalog.V1_EFFECT_KIND_IDS (:1160) ← 登记 "sword_intent"；default_effect_by_role 校验（B2-3）
battle_snapshot.build_battle ← sword_intent 层数新键（Shared 区，5 步协议）
action_preview_service / DisplayText ← 文案模板（阶段 C）
```

- **依赖方向**：resolver → school_rules（已有 preload 先例）；catalog 校验 → v1_battle.json；snapshot → battle dict。无反向依赖，无新平行状态（sword_intent 存 battle dict，随战斗生命周期）。
- **集成点**：4 处生产文件（v1_battle_resolver / content_catalog / v1_battle.json / gu.json）+ 2 处 Shared（battle_snapshot、契约文档）+ 测试 3 个新文件。
- **不触碰**：M4 纪律延续——不加 status framework、不加生命周期钩子、marked/bound 集合不扩（bound 仅从兜底表退役，kill-move 等显式引用不动）。

## 三、需求逻辑

### 1. 需求点 → 设计 → 动作对照

| 需求点（出处：Q7 规格 + 审计债 #3） | 设计方案 | 实施动作 |
|---|---|---|
| 剑道辅助蛊五类语义各归其位（增加叠层速度/增强下一击/双剑同轮/代价型/底蕴） | 五通道映射：sword_intent 接线 / support_bonus（已有）/ 起势链（已有）/ life_cost+CONSUME_ON_USE（已有）/ mark_sword 留接口 | 阶段 A（接线）+ B1（10 只数据） |
| `bound` 是死状态（全仓无消费者）→ logistics 兜底形同虚设 | 兜底表换活通道（推荐 heal） | 阶段 B2-2 |
| 空效果蛊"占槽烧真元无事发生" | 兜底表升级为双活通道（recon=刻痕+支援） | 阶段 B2-1 |
| 全流派 151 只不宜逐只手写 | **数据驱动**：改兜底表而非 151 条数据；per-gu 只留个位数特例 | 阶段 B2 vs B1 的分工 |
| 卡面文案=实际结算（红线 §信息透明） | 文案模板 + 断言并入测试 | 阶段 C |
| M4 复审纪律：不借机造 status framework | 引擎改动仅 1 个新 kind + 1 个 decay 调用 + 1 个消费点 | 全程约束 |

### 2. 为什么这个形状

- **151 只里 141 只走兜底表**是本计划的杠杆点：改一行兜底 = 141 只同时实义化；逐只显式化是 141 条数据 × 文案 × 测试，ROI 不成立。
- **sword_intent 是唯一真正缺的引擎件**（桩已落、零调用），接线成本 3 个函数级改动，消费语义是唯一需要你裁定的设计判断。
- **T10 mark_sword 不在本批实施**（长线道痕，1 道≈0.1%，属剑道底蕴成长），只留 effect 接口位——避免本批范围膨胀。

### 3. 明确不做

- 不做新 status kind 之外的 framework（无 trigger/priority/condition 系统）。
- 不做全流派逐只文案特调（模板化）。
- 不动杀招结算、不动 resource/buff 语义、不做流派克制网。

### 4. 待你批复的 4 个裁定点

| # | 裁定点 | 推荐 | 备选 |
|---|---|---|---|
| D1 | sword_intent 消费语义 | 见 §0-2 裁定：**不消费**，持续增益+回合末减半 | — |
| D2 | logistics 兜底通道（替换死 bound） | **heal 1**（已批复），rank 梯度经 RANK_SCALED_KINDS 免费获得 | — |
| D3 | recon 兜底形态 | **marked 1 + support 1**（已批复），允许 per-gu override | — |
| D4 | rank 缩放 | **沿用 RANK_SCALED_KINDS**（已批复）：strike/shield/heal | — |

---

## 0. 阶段 0 交付：批复记录 + 分配规则表（2026-09-12）

### 0-1 用户批复（2026-09-12，全阶段原则批准）

- 批准：阶段 0 / A sword_intent 最小接线 / B1 10 只显式化 / B2 兜底批量实义化 / C 文案一致性 / D 全量回归。
- 实施前置条件：①D1 明确消费语义；②strike 作用域显式化，禁止非目标伤害路径误吃剑意；③B2 增 role×rank/流派语义抽查；④C 阶段 effect→DisplayText 机器可验证一致；⑤Q8 死路径清理独立提交（不混入 Q7 批次）。
- 禁止项：新 status framework / EventBus / 生命周期钩子 / 重构 battle resolver / 重构 RunState / 借 Q7 扩 effect system / 借 Q7 重做架构。

### 0-2 D1 裁定（消费语义 + 作用域）

**不消费。** sword_intent 是持续增益：跨回合存续、回合末 `decay_sword_intent` 减半（衰减即代价）。出剑不改层数——与 T8 桩注释「跨回合存续、上限 5、回合末 50% 保留」一致，零新增状态语义。

**作用域（硬边界）**：加成只在 `_apply_effect` 的 `"strike"` 分支内计算（`slot.school=="sword"` 时 `amount += sword_intent`），随 amount 传入 `_strike_enemy`。`_strike_enemy` 本体零改动 ⇒ 以下路径**结构性吃不到**剑意：
- 杀招（直调 `_strike_enemy`，无 slot 语境）
- `_settle_marks` 刻痕划伤（T15 独立通道，规格明定不吃增益）
- `basic_attack`（拳脚非剑）
- `heal_and_strike` 的 strike 半边（避免复合叠加面）
- 敌人回合 / AOE strike 同 slot 语境按目标各结一次（十转杀蛊为剑道群体打击，属预期内）

### 0-3 分配规则表（规则即分配：19 流派 × 2 role 一次覆盖 151 只）

| role | 兜底 effect | rank 缩放 | 依据 |
|---|---|---|---|
| recon（含 sword_rec 之外的 136 只） | `{"kind":"status","name":"marked","amount":1,"support_school":"self","support_bonus":1}`；`"self"` 由 `default_v1_effect` 注入 definition.school（哨兵一行） | support_bonus **+（rank−1）**（default_v1_effect 内一行）；marked 恒 1（T15 cap 10 + 每回合 2 念头已限流，缩放会双重加压） | D3 批复；刻痕+支援双活通道 |
| logistics（含 sword_log 之外的 136 只外的对应只数） | `{"kind":"heal","amount":1}` | heal 已在 RANK_SCALED_KINDS ⇒ **1+(rank−1) 免费梯度**（rank4→4） | D2 批复 |
| sword_rec_5_*（5 只，rank 1/5） | B1 显式：`{"kind":"sword_intent","amount":N}`（N 按 rank 1→+1、5→+2） | **不进 RANK_SCALED_KINDS**（cap 5，显式数据自控，避免 rec_5 一击满层） | A 接线 + B1 |
| sword_log_1_*（5 只，rank 1） | B1 显式：`{"kind":"heal","amount":1}` + `life_cost`/`CONSUME_ON_USE` 按原配置（后勤=代价型恢复） | 显式数据自控 | B1 |
| 特例豁免 | per-gu override 白名单，预计 ≤5 只（refine/light 13-14 只大类若语义不符再议） | — | D3 授权 |

### 0-4 D2 同质化 / 梯度检查结论（实测 151 只 rank×rarity 分布）

- **rank↔rarity 完全相关**（rank 5=epic、3-4=rare/epic、1-2=common）：梯度经 rank 一根轴表达即可，**不引入 rarity 修饰**（YAGNI）。
- logistics 经 heal 免费获得 1→4 梯度 ✅；recon 经 support_bonus +（rank−1）获得 1→5 梯度 ✅；两 role 均无同 rank 跨流派同质化加压点——跨流派同质（同为 heal/support）是审计已知项（流派手感同质），差异化由各流派其它蛊承担，**本批不解决也不加剧**。
- 极值抽查：`wind/recon` 全部 rank 5（support 5 强但需五转资质门禁）；`human` 仅 1+1 只（样本过小不构成梯度问题）；`soul/logistics` rank 4 epic（heal 4，最高档，与稀有度匹配）。
- 结论：**梯度成立，无需额外数值**。
