# RESEARCH REQUEST · Lab 预算推导 vs 历史数值实现 · 逐项兼容审查

> **STATUS: ANSWERED（2026-09-21）· L1 裁决已落地**
> 裁决摘要：P0-C1 A（20× 显式投影）· P0-D2 A（fallback=legacy）· P0-H1 B（推导基线+override>20%）·
> P1 冻结 LAB_PRICING_V1 / THREAT_V1 / lab 念头 2 / kitDpr=静态估算器 / 碎石 1→2 分层 /
> 两 scope 各自单源 · P2 补 rankMultiplier、V4 HP 降级 snapshot、意图伤害同 HP 原则。
> `balance.js` 身份 = P3 实验参考实现（20× 投影），非最终量纲规范。
> 实现见 `game/wenzhen-web-lab/js/balance.js`；Godot priceGu **不同步**（J3: NO）。
>
> 日期：2026-09-21　发起：L2 Orchestrator
> 送审：L1（ChatGPT）　抄送：L0（产品取舍项）
>
> 背景：L0 要求「数值必须在原型解决并留扩展空间」。L2 已在
> `game/wenzhen-web-lab/js/balance.js` 落地推导框架。
> 本件**不请求再发明公式**，只请求你逐项裁定：
> **哪些历史实现被推导框架兼容继承、哪些是有意偏离、哪些是缺口必须补。**
>
> 对照文件：
> - 新：`game/wenzhen-web-lab/js/balance.js`、`tools/check_balance.mjs`、`js/mvp_content.js`
> - 旧/全仓：`game/data/balance.json`、`game/scripts/domain/gu_balance.gd`、
>   `game/data/v1_battle.json`、`game/world-model/rulings/RUL-2026-09-19-008.json`、
>   `RUL-2026-09-19-009.json`、`game/world-model/reports/effect-budget-census.md`、
>   `docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md` §10、
>   lab 旧 V4 冻结表（见 handoff）

---

## 0. 总判读（先读这三句）

1. **形状兼容**：推导框架采用与 RUL-008 相同的管线形状
   `Rank → Effect Budget → Archetype → Modifier → Final Effect`，
   并承认「转数是层级轴、每转 ×2、作用于效果预算、不直接乘所有伤害」。
2. **量纲有意分层**：lab 是「一转早期 10 分钟切片」压缩仿真，
   伤害/气血用 lab 单位，**不是** `human_base_health=100` 世界。
   两套量纲之间目前只有备忘换算，**没有**经你裁定的正式换算（见 C1）。
3. **最大兼容风险**：P3 Effect Budget 量纲换算（预算 40 ↔ amount 2）**仍然悬空**。
   lab 自建了 PP 量纲（1 PP ≈ 1 lab 伤），等于**擅自填了 P3 的空**。
   本件首要请你确认：lab PP 是否可作 P3 的**试验田**，还是必须先冻结等待你的公式。

---

## 1. 逐项对照表

图例：`兼容` 形状/语义一致 · `缩放` 同一语义不同量纲 · `偏离` 有意不同 · `新增` 历史无 · `缺口` 应对齐但未做 · `冲突` 不可同时为真

| # | 项目 | 历史实现 | Lab 推导框架 | 判定 | 请你裁定 |
| --- | --- | --- | --- | --- | --- |
| **A. Rank / 预算轴** | | | | | |
| A1 | Rank Power Budget 曲线 | `balance.json`：40/80/160/320/640；公式 `rank1 × step^(rank-1)`，`rank1=100×0.2×2` | `priceGu`：`budget = 2 × 2^(rank-1)` → 2/4/8/16/32 | **缩放** | lab 预算基数 2 相对全仓 40 的比例 **1/20** 是否认可为「lab 一转标准 PP」？还是应写成 `40/20` 显式投影？ |
| A2 | 每转 ×2、1→5 约 ×16 | RUL-008 D2 冻结 | `priceGu` 同用 `2^(rank-1)` | **兼容** | 确认即可 |
| A3 | 「预算不直接乘所有伤害」 | RUL-008 D2；伤害由 Effect Archetype 决定 | `priceGu` strike 取 `spendable×0.7` 再圆整，不是 `damage × rank_multiplier` | **兼容（形状）** | 0.7 主维度占比是 lab 权宜；P3 正式分配公式出来后应替换 |
| A4 | `rank_multiplier` = 1/2/4/8/16 | `gu_balance.gd` 无量纲步进 | 未导出同名函数（内部等价于 budget 比） | **缺口** | 是否要求 lab 导出 `rank_multiplier` 对齐命名？ |
| A5 | 转数语义（层级轴 ≠ 万能倍率） | RUL-008 D1 | 文件头注释已声明 | **兼容** | 确认即可 |
| **B. 人体 / HP 锚点** | | | | | |
| B1 | `human_base_health = 100` | `balance.json` / GuBalance | `LAB.playerHp = 24`，`fullGame.humanHp = 100` 仅备忘 | **缩放** | lab 24 是否产品认可的「10 分钟节奏常量」？与 100 的换算是否要进 `balance.json`？ |
| B2 | `standard_human_hp = 100`、`player_start_hp = 100` | RUL-009 D11；禁「丙等→HP×0.8」 | lab 不绑资质；HP 24 独立 | **兼容（RUL-009 分轴）** | 确认 lab 不触碰「资质→HP」禁令 |
| B3 | 资质/真元 与 肉身/HP 分轴 | RUL-009 D1 | lab 只有 HP/Qi 两条资源，无资质轴 | **兼容（子集）** | 扩全量时是否必须先接资质轴，还是 lab 形状可先扩？ |
| **C. 量纲换算（最重）** | | | | | |
| C1 | Rank Budget 40 ↔ effect `amount` 2 | P3 RR 已问，**未裁**；census 实测 gap 100×+ | lab 定义 `1 PP = 1 lab 伤`，并注「r1=40 → lab damage=2 = 0.05×预算」 | **冲突 / 擅自填空** | **请裁定**：① 接受 lab PP 作 P3 试验田 ② 或冻结 lab 自建 PP、等你给正式换算 |
| C2 | 徒手重击 = 20 | `unarmed_damage_ratio=0.2 × strength 100` | lab 无徒手 | **缺口** | lab 是否需要徒手参照？ |
| C3 | 固定防御 = 8/16/32/64/128 | `fixed_defense = standard_gu_power × 0.2` | lab 只有临时 block（石皮 5 / 玉皮 3），无固定防御层 | **偏离（有意）** | 10 分钟原型省略固定防御是否认可？扩全量时 block 是否要拆「临时/固定」两层？ |
| C4 | 标准治疗 = 20/40/60/80/100 | `human_base_health × 0.2 × rank` | lab 生机草 heal=1 | **缩放** | 同 C1，换算未裁 |
| **D. Effect 兜底曲线（741 只）** | | | | | |
| D1 | `default_effect_by_role` | attack strike 2 / defense shield 3 / heal 2 / shift 1 / status 1 / logistics heal 1；**线性 +1/转** | lab 无 role 兜底；`priceGu` 按 archetype 从预算出数 | **偏离（有意）** | lab `priceGu` 是否就是 P3 要的「统一管线」试验实现？741 只 fallback 是否按 `priceGu` 重标？ |
| D2 | fallback r5/r1 = 1–5× vs 预算 16× | census §1 已证实缺口 | `priceGu` r5/r1 = 16×（与预算同形） | **冲突（对历史）** | 历史 fallback 是「生存地板」还是 bug？lab 按 16× 是否正确目标？ |
| D3 | 手写 61 只与 fallback 两套世界 | census §2–3 | lab 全部走预算，无手写通道 | **兼容（目标态）** | 是否要求 Godot 侧也禁手写 `amount`，只留 modifier？ |
| **E. 蛊效果定价（PP）** | | | | | |
| E1 | 效果维度 11 个 | RUL-008 D7 | lab 只表达 damage/block/heal/inspect/support/suppress（6 个） | **缺口** | 范围/目标数/持续/穿透/控制等 5 维 lab 未建——扩全量前必须补还是可后补？ |
| E2 | 防御/治疗相对伤害的效率比 | 历史无统一 PP 权重 | `PP: damage 1 / block 1.2 / heal 1.5 / inspect 1.5 / support 1.2 / suppress 2.5` | **新增** | **请裁定权重**（L2 不得自定，此处是试验值） |
| E3 | 代价税 | `actual_cost_percent` 只管真元百分比 | `costTax = 1 + qi×0.15 + hp×0.25 + th×0.2 + cd×0.1` | **新增** | **请裁定税则**；与 `light_cost_ratio/heavy_cost_ratio` 何关系？ |
| E4 | `expectedDamagePerUse` 伤势/支援期望 | 历史按结算实值 | wounded 半程 0.5、supported 半程 0.5（启发式） | **新增** | 期望系数是否认可？还是只按 base 伤估 DPR？ |
| **F. 行动经济 / DPR** | | | | | |
| F1 | 念头 | `thought_base_capacity = 3`（balance.json）；v1 `thought_cost_default = 1` | lab `thoughtsPerTurn = 2` | **冲突** | lab 用 2 是否 10 分钟专用？扩全量必须回到 3 还是分场景？ |
| F2 | 冷却 | Godot `turn + cooldown + 1` 可用（CD N = N 回合空窗） | `cycle = 1 + cooldown`（同语义：CD2 → 1/3 出手率） | **兼容** | 确认公式一致 |
| F3 | 吞吐模型 | 历史无 kitDpr；靠仿真 | 贪心分配 2 念头 × 实例出手率 | **新增** | 模型 v1 是否可作标准？还是必须改用回合精确模拟？ |
| F4 | 支援（小光） | `support_bonus=1` + `light_cost_ratio=0.5`（真元折扣） | lab：`supportedDamage +1`、`supportedQi -1`（到 0） | **缩放 / 局部偏离** | 与 `light_cost_ratio=0.5` 的对应关系请裁定 |
| **G. 反制税 / 信息** | | | | | |
| G1 | 迎击吞直攻 | lab V4.1 语义；Godot 有 counter 体系（`action_preview_service` 等） | `counterZeroRate`: intercept/iron → 1.0（无压制） | **新增（lab）** | Godot 侧是否采用同一「零输出回合」税模型？ |
| G2 | 逐光/封脉不计零输出 | — | 权重 0（仍可输出） | **新增** | 是否认可？ |
| G3 | 有压制时 intercept/iron → 0.25 | — | `hasSuppress` 选项 | **新增** | 0.25 是否认可？ |
| G4 | 「读对+做对」才 -3 | lab Q4；V4 决策 1 | 未进 budget.js（在 mvp_logic） | **兼容（分工）** | 确认：减伤门槛属规则层，不属预算层 |
| **H. 遭遇推导** | | | | | |
| H1 | 敌人 HP | `enemies.json` 手写；`boss_layer_mult` hp 1.0–1.5（关卡轴，非转数） | `deriveEnemyHp = dpr × turns × (1-zero) × margin` | **偏离（有意）** | **请确认**：遭遇 HP 必须推导、禁止手写，是否升格为全仓红线？ |
| H2 | 敌人伤害 | 手写 intent damage；`boss_layer_mult.damage` | `deriveEnemyDamagePerTurn`（存活率/处理率） | **新增** | 威胁预算参数（survivalRate 0.2–0.4、handleRate 0.35）请裁定 |
| H3 | margin = 1.08 | — | lab 通用余量 | **新增** | 余量是否固定？按遭遇类型分层？ |
| H4 | 旧 V4 冻结 HP 10/15/18/28 | L1 冻结表 | 推导后 8/9/14/15 | **偏离** | 是否正式作废 V4 HP 表、改认推导？ |
| H5 | 旧回合窗 3–5/4–6/4–6/6–9 | L1 V4.1 | `targetTurns` 取窗中值 4/5/5/7.5 | **兼容** | 确认窗口仍为产品意图；HP 服从窗口 |
| **I. Lab 专有规则（全仓无）** | | | | | |
| I1 | 胜利回复 +2 HP / +2 Qi | 无 | V4 阀门 | **新增** | 扩全量是否保留？还是改为休整节点？ |
| I2 | 逆息（HP→Qi） | 无 | V4.1-Q1 防软锁 | **新增** | 是否进入正式机制？ |
| I3 | 碎石还元 1 石 → 2 Qi | 全仓 `stone_to_essence_per_stone = 5` | lab 1→2 | **冲突** | lab 比例是节奏裁剪还是错误？ |
| I4 | 炼蛊消耗月光+小光 | 无直接对应 | lab 场景规则 | **新增** | 合成代价模型是否要对齐 `synthesis.json`？ |
| **J. 工程门禁** | | | | | |
| J1 | 单一真源 | GuBalance + balance.json | MvpBalance + check_balance | **兼容（双真源分层）** | lab 真源是否允许并存？还是必须 import 全仓 balance.json？ |
| J2 | 写不进脚本的规则不许存在 | CONSTRAINTS-V2 R5 | `check_balance.mjs` 15 项 | **兼容** | 确认 |
| J3 | priceGu 工厂 | 无（手写 61 + fallback 741） | 声明定位出数 | **新增** | 是否要求 Godot/生成器同步实现 priceGu？ |

---

## 2. 数值对照速查（实测，非估计）

### 2.1 预算曲线

| rank | 全仓 Rank Power Budget | lab `priceGu.budget` | 比 |
| ---: | ---: | ---: | ---: |
| 1 | 40 | 2 | 1/20 |
| 2 | 80 | 4 | 1/20 |
| 3 | 160 | 8 | 1/20 |
| 4 | 320 | 16 | 1/20 |
| 5 | 640 | 32 | 1/20 |

→ **形状完全一致（×2/转）**，基数固定 20 倍缩放。当前仅写在注释，**未进数据表**。

### 2.2 一转攻击标价

| 来源 | 数值 |
| --- | --- |
| 全仓 fallback `attack/strike` r1 | `amount = 2` |
| 全仓手写 strike r1 上限 | 4（`force_gu` 等） |
| lab 月光 `damage` | 2（支援 3） |
| lab `priceGu({rank:1,strike,qi:1})` | `damage = 2`（budget 2 × tax 1.15 × 0.7 ≈ 1.6 → round 2） |
| 全仓 `standard_gu_power(1)` | 40 |
| 徒手重击 | 20 |

→ lab 与 **v1 fallback / 手写 amount 同量级**，与 **GuBalance 预算 40 不同量级**（即 P3 缺口的两套世界）。

### 2.3 敌方 HP

| 敌 | V4 手写 | 推导 | 公式 |
| --- | ---: | ---: | --- |
| 猎犬 | 10 | 8 | `2.5 × 4 × (1-0.25) × 1.08` |
| 山猪 | 15 | 9 | `2.5 × 5 × (1-0.33) × 1.08` |
| 悍客 | 18 | 14 | `2.5 × 5 × (1-0) × 1.08` |
| 狼王 | 28 | 15 | `2.5 × 7.5 × (1-0.25) × 1.08` |

`refDpr = 2.5` = 月光 `expectedDamagePerUse`（base 2 + 支援半程 +0.5）× CD0 × 1 念头。

### 2.4 意图伤害（仍为 V4 冻结，**未**进威胁推导）

| 意图 | 伤害 | 威胁预算（check_balance） | 判定 |
| --- | ---: | ---: | --- |
| 蓄扑 | 4 | 5.54 | 窗内 |
| 獠牙 5/6 | 5.5 均 | 4.43 | 窗内（均伤×占比） |
| 弩箭 | 4 | 4.43 | 窗内 |
| 雷冠 5/6 | 5.5 均 | 3.94 | 窗内（+0.6 爆发缓冲） |

→ **伤害表仍是手写**；威胁预算只做上限咬合，不做下限/推导。是否要求意图伤害也改为推导？

---

## 3. 分歧分级（请按此回复）

### P0 · 不裁定则扩全量会重蹈两套世界

| ID | 问题 | 选项 |
| --- | --- | --- |
| **C1** | PP 量纲（lab 1 伤 vs 预算 40） | A. lab PP 作 P3 试验田并记录 20× 投影　B. 冻结 lab 自建 PP，等正式换算　C. 整体重标 lab 到 40 量纲 |
| **D2** | fallback 线性 +1/转（≤5×）vs 预算 16× | A. fallback 是地板，生成器应走 priceGu 16×　B. 维持 fallback，priceGu 仅用于新手写 |
| **H1** | 敌人 HP 是否强制推导 | A. 全仓红线：HP 只推导不手写　B. 允许手写但必须过 checkEncounter　C. 仅 lab 强制 |

### P1 · 不裁定则 lab 扩展会漂

| ID | 问题 | 选项 |
| --- | --- | --- |
| **E2/E3** | PP 权重与 costTax | 确认试验值 / 给正式值 |
| **F1** | 念头 2 vs 3 | lab 专用 2 / 回到 3 |
| **F3** | kitDpr 吞吐模型 | 认可 v1 / 改精确模拟 |
| **H2/H3** | 威胁参数与 margin | 确认 / 给正式值 |
| **I3** | 碎石 1→2 vs 全仓 1→5 | lab 节奏裁剪 / 对齐 5 |
| **J1** | lab 真源是否 import `balance.json` | 允许分层 / 强制单源 |

### P2 · 可后补

| ID | 问题 |
| --- | --- |
| **E1** | 11 维中 5 维未建（范围/多目标/持续/穿透/控制） |
| **C2/C3/C4** | 徒手、固定防御、标准治疗在 lab 缺席 |
| **A4** | `rank_multiplier` 命名对齐 |
| **H4** | V4 HP 表正式废止文案 |
| **意图伤害推导** | 是否纳入 deriveEnemyDamage |

---

## 4. 明确「未做、也不打算偷偷做」的清单

1. **未修改** `game/data/balance.json`、`gu_balance.gd`、`v1_battle.json`、任何 Godot 数值。
2. **未**把 lab PP 写回全仓；只在 `balance.js` 注释里留 20× 备忘。
3. **未**实现 P3 的正式 Effect Budget 分配公式（仍等你）。
4. **未**让 `priceGu` 覆盖 802 只 gu.json。
5. **未**统一石头→真元比（lab 1→2 vs 全仓 1→5）。
6. 意图伤害仍为 V4 冻结字面量；威胁预算只咬上限。

---

## 5. DESIRED OUTPUT

请按 **§3 分级** 回复，格式建议：

```text
P0-C1: B（冻结 lab PP）| 理由一句
P0-D2: A
P0-H1: A + 补充…
P1-E2: 权重改为 …
P1-E3: 税则改为 …
P1-F1: …
P1-F3: …
P1-H2: survivalRate=… handleRate=…
P1-I3: …
P1-J1: …
P2: 采纳 L2 清单 / 驳回某条
```

另请一句话裁定：**lab `balance.js` 是否可作为 P3 Effect 管线的参考实现**（在量纲换算裁定之后）。

---

## 附录 A · 实测导出（2026-09-21）

```text
refDpr = 2.5
plan = [moonlight_gu usesPerTurn=1 contrib=2.5]
enemyHp = {hound:8, boar:9, elite:14, boss:15}
targetTurns = {b1:4, b2:5, elite:5, boss:7.5}
priceGu(r1,strike,qi1) = {budget:2, tax:1.15, spendable:2.3, damage:2}
guBudget(moonlight) = {total:2.5, damage:2.5}
guBudget(moon_glow) = {total:6.5, damage:4, suppress:2.5}
guBudget(white_boar) = {total:3.5, damage:3.5}  # wounded 半程期望
check_balance = 15/15
tests = 111/111
```

## 附录 B · 历史公式摘录（便于你对照）

```text
# gu_balance.gd / balance.json / spec §10
rank_power_budget(r) = 40 × 2^(r-1)           # 40/80/160/320/640
standard_gu_power(r) = 100 × 0.2 × 2^r        # 恒等于上式
fixed_defense(r)     = standard_gu_power(r) × 0.2
human_standard_heal(r) = 100 × 0.2 × r        # 20/40/60/80/100
unarmed_raw_damage   = strength × 0.2 × action_mult
beast_scale(r)       = 100 × 2^r              # 并列参照，基数不同

# v1_battle.json default_effect_by_role（741 只 fallback）
attack  → strike amount = 2 + (rank-1)        # 2..6
defense → shield amount = 3 + (rank-1)        # 3..7
healing → heal    amount = 2 + (rank-1)       # 2..6
logistics → heal  amount = 1 + (rank-1)       # 1..5
movement → shift  amount = 1                  # 不随转
recon    → status amount = 1                  # 不随转

# lab balance.js（试验）
PP: damage 1, block 1.2, heal 1.5, inspect 1.5, support 1.2, suppress 2.5
costTax = 1 + 0.15 qi + 0.25 hp + 0.2 (th-1) + 0.1 cd
priceGu.budget = 2 × 2^(rank-1)
strike.damage = round(spendable × 0.7)
kitDpr: Σ min(n/(1+cd), thoughts/th) × expectedDamage
enemy.hp = round(dpr × turns × (1-zeroRate) × margin)
```
