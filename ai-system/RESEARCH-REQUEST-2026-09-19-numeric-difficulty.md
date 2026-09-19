# RESEARCH REQUEST · 2026-09-19 · 数值与难度体系

> ⚠️ **本文件已作废（2026-09-19，L2）——请勿送 L1**
>
> - **RR-1 已作废** → 由 `RESEARCH-REQUEST-2026-09-19-soul-numeric-model.md` 取代。
>   原因是原 RR-1 写于魂道原文核验之前，其 KNOWN FACTS 有多条基于后来被推翻的口径
>   （把游戏占位数据当原著依据、把两处门槛差异当成待裁决的「冲突」）。
> - **RR-2 已作废** → 由 `RESEARCH-REQUEST-2026-09-19-rank-foundation.md` 取代（L0 指示「并进」）：
>   - 「三条转数曲线是否统一」→ 已被新件的 Q1/Q5 覆盖，且原文侧已证实「原文不给倍数」
>   - 「难度分档形态 + 是否废弃 `enemy_hp_mult`」→ 新件 Q10
>   - 「玩家气血 80 还是 100」→ 新件 Q11（新件 §5.5 补充了更完整的事实）
>   - 原 RR-2 的 CONSTRAINTS 引用 Q8-G 任务书红线，该冻结令已于 2026-09-17 全部作废，已弃用
> - **RR-3（独立评审 + 数据可追溯性）尚未重写**，暂时不要送 L1。
> - 全部内容保留作历史参考。

> 提交人：Codex Orchestrator（L2）
> 上游：用户（L0，产品意图）
> 目的：三个问题分别交 **研究院 / 架构委员会 / 独立评审**。
> 只提供决策所需信息；证据均已在仓库内可复核，未改动任何生产数值。

---

## RR-1 · 研究院：魂道的闭环结构与跨轴机会成本

> ⚠️ **本 RR 已由 `RUL-2026-09-19-004` 改写（2026-09-19）**。
> 原设问「魂应定位成生命周期风险资源还是可经营资源」已由 L0 裁定，**不再是开放问题**：
> **魂是可成长的 Build Axis，并对应魂道玩法**，同时承担魂魄生存值 / 魂道能力资源 /
> 魂道攻击防御基础 / 长期成长属性；**不得再设计成固定 1–4 的风险条**。
> 上一轮「魂 = 风险资源、上限暂保留 4、starting_soul 作为主要难度旋钮」**撤回**。
>
> **本 RR 现在处于「暂缓送审」状态**：按 L0 指令，先做完只读 **Soul System Audit**，
> 拿到仓库事实后再提给 L1。

```text
CURRENT PHASE
RUL-2026-09-19-004 已生效。Soul System Audit（只读）为当前前置任务。

QUESTION（审计完成后提问，问题本身已被 L0 指定）
1. soul 的「当前值」与「上限」是否应分离？分离后各自承担什么？
2. 魂道构筑如何形成 获得 → 养魂 → 使用 → 强化 的闭环？
3. 魂与肉身 / 真元等 Build Axis 的机会成本与克制关系应如何设计？
4. 在此结构下，难度分档还应不应该碰魂？若不碰，挂在哪条轴？

WHY CODEX CANNOT DECIDE
跨轴设计问题（魂道闭环 × 三轴死亡 × 行动经济 × 其余 Build Axis 的机会成本）。
仓库事实能回答「现在有什么」，不能裁决「应该长成什么样」。

KNOWN FACTS（已由 L2 初步定位，完整清单待 Soul System Audit 产出）
- 魂道作为流派**已存在**：`data/gu.json` 中 `school == "soul"` 共 **40 只**（1–5 转：
  11/10/9/4/6），role 分布 attack 17 / defense 5 / movement 5 / healing 5 / recon 4 / logistics 4
- 但**只有 1 只有显式 `v1_effect`**，其余 39 只走 role 兜底表 ⇒ 魂道目前基本没有战斗实现
- 魂道相关 id 前缀在数据中大量存在：`soul_atk_` 109 / `soul_def_` 39 / `soul_mov_` 35 /
  `soul_heal_` 24 / `soul_log_` 20 / `soul_rec_` 16
- 行动点门槛的原始设计意图**有成文记录**：
  `docs/wiki/concepts/world-model-translation.md:21`「魂魄底蕴 | 行动次数分档 |
  1/10/100/10000 底蕴 → 2/3/4/5/6 次」；另 `docs/superpowers/specs/2026-09-01-v1-battle-schema.md:74`
  记 ≥10000 → 6
- 存在**两套魂系统**：legacy `soul`/`soul_max`（活）与 `SoulRules` 五量
  （`soul_magnitude` 8 / `soul_safe_capacity` 8 / `soul_calm` 8 / `soul_nature` 5 / `beast_nature`），
  后者**零消费者**（旧裁定 No-Go 暂不接线）
- 消耗/攻击魂的通道：`soul_drain` 16（敌方意图）、`soul_cost` 15、`soul_boost` 20、`soul_pill` 6

CONFLICTS
- 魂同时被当作「行动点驱动器」与「死亡轴」；上限 4 使行动点高收益档全部不可达
- legacy `soul`（1–4 量级）与 `SoulRules` 五量（`soul_safe_capacity` 等，量级完全不同）并存且互不相通
- `docs/wiki/concepts/world-model-translation.md` 记的门槛是 1/10/100/10000，
  而 `world-model/data` 的实际表是 10/100/1000/10000 且额外多一档 1000 —— **两处不一致，待审计确认哪个是原意**

CONSTRAINTS
- 禁止直接删除高魂 AP 档位
- 禁止继续以 `max_soul = 4` 为前提调难度
- 禁止把 `starting_soul` 定为主要 difficulty knob
- 禁止仅把魂视为第三死亡条
- 只读审计先行；数值后置

DESIRED OUTPUT
待 Soul System Audit 完成后：魂道的闭环结构方案（获得/养魂/使用/强化各挂什么），
以及魂与其余 Build Axis 的机会成本与克制关系。
```

> 上表 `CONFLICTS` 第三条已记入待验证项：L0 问题 2「AP 门槛的原始设计意图」需要审计确认
> 是 `1/10/100/10000`（wiki 译本口径）还是 `10/100/1000/10000`（当前数据口径）。

---

## RR-2 · 架构委员会：难度分档形态 + 三条转数曲线是否统一

```text
CURRENT PHASE
同上。难度旋钮已被证明打在错的轴上；三条转数曲线并存但从未对账。

QUESTION
(a) 难度分档应做成「整体缩放」（一档一个系数）还是「每档各调几个旋钮」？
    现有唯一旋钮 `enemy_hp_mult` 是否应保留，还是废弃？
(b) 三条转数曲线保留多轴，还是统一成单轴？
    局外真元 ×3（1/3/9/27/81）｜战斗真元 10-30-60-100-150｜通用倍率 ×2（1/2/4/8/16）

WHY CODEX CANNOT DECIDE
存在多个合理方向，且互相耦合：分档形态取决于魂轴方案（RR-1），
而转数曲线统一会波及受影响的全部数值。属于架构级取舍，非仓库事实可裁决。

KNOWN FACTS
- `enemy_hp_mult` 灵敏度**非单调**：1.0→67.0%，**1.5→70.0%（更简单）**，2.0→42.0%
  原因：战斗拖长反而带来更多掉落与魂恢复机会；而战斗本身几乎不致死（2/200）
- 三条曲线服务对象（据派生模型命名）：`essence_max_out_of_run` / `essence_max_battle` / `rank_multiplier`
  1–2 转三者不冲突；**3 转起分叉**（丙等三转：局外 180 vs 战斗 120）
- `rank_step_ratio = 2` 是唯一被代码消费的通用倍率（`gu_balance.gd:28-35`）
- 量纲双轨：参照系 `standard_gu_power` 40–640 / `beast_scale` 100–3200
  vs 实战敌我 HP 3–20、蛊伤 1–8（文档自述并有意冻结，未对账）

CONFLICTS
- 主文档把 `world-model/data/balance.json` 写成「单点调参入口」，
  但该目录是从上游 `game/data/` **派生**的镜像（`build_world_model.py` 文件头明确只读上游），
  照它改会被覆盖并触发漂移告警。
- 无任何一处文档把三条曲线并列对账。

CONSTRAINTS
- Q8-G 任务书红线：**不得破坏「低转蛊通过成本效率进入高转构筑」**
- 现有玩家开局气血无单一来源：`build_world_model.py:897` 硬编码 80，
  而上游 `human_base_health = 100`（`cultivator_rules.gd:79` 消费它作蛊师肉身气血）——须一并裁决

DESIRED OUTPUT
1. 分档形态建议（整体缩放 vs 多旋钮），含是否保留 `enemy_hp_mult`
2. 三条转数曲线：保留多轴（并补一张并列对账表）或统一单轴，二选一 + 理由
3. 玩家气血取值裁决（80 还是 100，以及谁是真源）
```

---

## RR-3 · 独立评审：本批产出复核 + 数据可追溯性治理

```text
CURRENT PHASE
阶段性成果（数值对账 + 难度探针）已完成并通过 L2 Review，需独立高阶复核。

QUESTION
1. 复核本批结论与证据是否成立、有无过度归纳
2. `world-model/data/` 在 git 中只有一条整体导入提交，导致**世界模型数据变更不可追溯**——
   应如何治理？（是否单独立项）

WHY CODEX CANNOT DECIDE
阶段性大成果需独立 Review；可追溯性是仓库结构问题，涉及导入策略取舍。

KNOWN FACTS
本批产出（均未提交、未推送）：
- `game/world-model/reports/numeric-status-audit.md`（只读对账）：C1–C10 矛盾 + G1–G10 真空
- `game/world-model/reports/difficulty-axis-probe.md` + `tools/probe_difficulty_axes.py`
- `ai-system/tasks/numeric-difficulty-axis-probe-result.md`（Worker Packet + L2 Review 段）

对账关键发现（每条均可复核）：
- 蛊有**两套不可比的伤害通道**：显式 61 只手写且**无转数放大**，兜底 741 只走 `base+(rank-1)`
  ⇒ 实测**三转 `water_atk_3_05_gu` strike 2 弱于一转 `blood_farewell_gu` strike 4**（转数与伤害倒挂）
- 商店买价与 `gu_value` 完全脱钩（`price_for` 从不读 `gu_value`）
- 显式效果只数：文档记 48，实测 **61**；兽骨依赖：文档记 96%，实测 **81.4%**（`advance` 内仍 99%）
- 配方 468 条：`advance 377` / `promotion 76`（19 流派 × 4 步，**缺 `bone`**）/ `fixed 14` / `free_mix 1`
- `docs/q8g/` 只有 Batch 0 与 1-A 文档，但 76 条 `promotion` 已落地 ⇒ 文档记录落后于数据
- `data/gu.json` 残留测试蛊 `test_slay_gu`（rank 10 / amount 999 / tag `test`）

L2 已做的两处更正（请复核其正确性）：
- **证伪 Worker 归因**：Worker 称 1pp 基线漂移来自提交 `343ff44`；
  实测该提交只改 `engine/rules.py`，而 `data_digest` 只覆盖 `world-model/data/`（`engine/model.py:58-85`），
  且 `git log -- game/world-model/data/` 仅 `ebb7f81`（整体导入）⇒ **无法从历史定位**
- **修 L2 层缺陷**：报告原 §六 系手工追加、脚本不生成，按文档命令复跑即被抹掉；
  已折入 `render()` 并改为从 `balance-simulation.md` 解析基线值（不硬编码）

治理事实：
- 本机 Windows PowerShell 5.1 + gb2312 控制台 ⇒ `run-worker.ps1`/`bootstrap.ps1` 读含中文的
  `config/*.json` 时乱码、`ConvertFrom-Json` 抛异常，**Worker 派单链路原本整体不可用**
  （已修：显式 `-Encoding UTF8`；并发现本仓 `.ps1` 必须纯 ASCII，否则 PS 5.1 解析报错）
- `world-model/data/` 只有一个导入提交；`game/data/` 同样（`ebb7f81`）⇒ 数据变更无史可查

CONFLICTS
- 世界模型自述「一切从上游派生」，但 `run.starter.hp` 是硬编码字面量（同段的 `thought_max` 却派生）
- 08-09/09-12 的裁定文件多已被 2026-09-17 裁定作废，现行有效约束是
  `world-model/governance/CONSTRAINTS-V2.md` 的 6 条可执行规则

CONSTRAINTS
只读评审；不得改动生产数值；改动须走 `accept.py`。

DESIRED OUTPUT
1. 本批结论的 PASS / 需修正清单（含是否过度归纳）
2. 数据可追溯性的治理建议：是否单独立项、以何种最小方式解决
3. 是否批准把 L2 的两处更正作为定论写入仓库记录
```

---

## 附：本轮不建议上抛的事项（L2 可自行闭环）

- Web 原型 4 个自编值的回归（`game/wenzhen-web-lab/js/main.js`）
- 文档过期数字修正（显式效果 48→61、兽骨 96%→81.4%、调参入口方向、上游同名 `regen_pct`）
- 以上均为仓库内可验证的小任务，按 L2 规划派 L3 Worker 即可，不占用 L1。
