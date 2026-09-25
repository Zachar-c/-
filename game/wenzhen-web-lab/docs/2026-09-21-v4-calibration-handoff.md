# Handoff · V4 数值校准（10 分钟循环的第一道产品验收门）

> **状态（2026-09-25，休眠资产收口）**：本文件归档为历史记录，**不再是 V4 校准状态出处**。
> V4/V4.1 冻结裁定与现行代码锚点见 [`V4-CALIBRATION-STATE.md`](V4-CALIBRATION-STATE.md)；
> `tools/autoplay.mjs` 验收门与 `mvp.html`/`index.html` 入口已按 2026-09-25 L0 收敛批删除，文中相关条目仅作历史。

MVP 完成时的记录在
[`2026-09-21-mvp-handoff.md`](2026-09-21-mvp-handoff.md)，那边不再同步数值校准部分。

```text
TASK v4-calibration
PHASE 10 分钟循环 · 数值校准
STATUS BALANCE FRAMEWORK v1 + L1 兼容裁决已落地 · 门 30/41（1/3 clear）
TYPE architecture + implementation + measurement

> **L1 2026-09-21 兼容审查裁决已实现**（RR `RESEARCH-REQUEST-2026-09-21-balance-compat-audit.md` = ANSWERED）：
> `LAB_BUDGET_PROJECTION=20` · `LAB_PRICING_V1` · `THREAT_V1` · H1 override>20% 必须写 reason ·
> E4 定价/期望分离 · 两 scope 各自单源（WORLD→LAB 单向投影）·
> `balance.js` 身份 = **P3 实验参考实现**，非最终量纲规范。
>
> 毕业链：`priceGu → encounter → autoplay → L0 体验`
> 当前：静态门 **17/17**；autoplay **1/3 clear**（sacrifice）；**未达 L0 试玩线**。

> **L0 2026-09-21 指令**：数只蛊就会打架，扩到成百上千必须在原型解决并留扩展空间。
> 已落地 `js/balance.js` + `tools/check_balance.mjs`：敌方 HP/威胁由
> 「kit 吞吐 × 目标回合 × 反制税」推导，content 禁止手写 HP。
> 扩到 N 只蛊：只声明 `(rank, role, archetype, costs, modifier)`，`priceGu()` 出数，
> `check_balance` 咬窗口。对齐全仓 RUL-008 预算形状（40/80/160/320/640）。

> 2026-09-21 L1 裁决 V4.1（`RESEARCH-REQUEST-2026-09-21-v4-structural-blockers.md`）：
> - **Q1-D 主刀「逆息」**：1 念头 / 气血 -2 / 真元 +3，CD 2 回合；当回合禁收势与生机草。
>   拒绝战斗内常规回蓝、月芒降费、炼蛊不耗材。
> - **Q2-B 主刀**：反制序列确定性降档（猎犬 50% / 山猪 1/3 铁皮 / Boss 与悍客主要伤害意图 50%）。
> - **Q2-A 必做**：迎击只吞直接攻击；autoplay 不得整回合 fallback。
> - **Q2-C**：回合窗口改为 猎犬 3–5 / 山猪 4–6 / 悍客 4–6 / Boss 6–9 / 全局 17–24。
> - **Q3**：`crossbow_shot` / `thunder_pounce_2` 补既有反制序列，不新增类型。
> - **Q4**：维持「读对 + 做对」（learned 也算读对）。
> - 逆息 ≤2/局；多种子门：每路线独立 ≥70%，stalemate = 0/30。

GOAL
把 10 分钟循环从「88/88 证明按钮能按」推进到「证明这个游戏数学上还能玩」：
落地 L1 冻结规则 V4 的三刀，并让真实 DOM 自动走盘成为必过的产品验收门。
目标不是让自动策略每次都赢，而是让一局能活着走到交易、炼蛊、构筑和 Boss 都发生之后。

BASELINE
提交 e78c5c2（已推送 origin/master）。本文件与同批的口径修正落在其后的提交。

DELTA
~ js/mvp_logic.js
  ~ startTurn：不再每回合重置 revealed，改由 knownCounters 计算（V4-1 同类反制永久识别）
  + counterHandled()：正确处理当前反制 → 本次伤害 -3 且取消意图附带特殊效果，下限 0（V4-2）
  + applyVictoryRecovery()：普通战胜利 +2 气血 / +2 真元，全仓唯一回血途径（V4-3）
~ js/mvp_content.js
  ~ 敌方伤害冻结表：悍客 crossbow_shot 5→4；狼王 phaseOne thunder_pounce 4→5、phaseTwo 4→6
  + victoryRecovery { hp: 2, qi: 2 }
  敌方 HP 一律未动（猎犬 10 / 山猪 15 / 悍客 18 / 狼王 28）；念头仍为 2
~ js/mvp.js
  ~ 观察与识破改走 knownCounters；收势/减伤接线；战后回复；支持 ?seed=N
  ~ Mvp.stats() 暴露逐场指标（HP/Qi/Stone/turnCount/observeCount/damageTaken/guUsage/knownCounters）
  ~ 修正观察计数口径（见 DECISIONS 4）
~ tests/mvp_logic.test.mjs　88 → 98（+10 条 V4 用例）
+ tools/autoplay.mjs　新增：真实 DOM 验收门
~ docs/2026-09-21-mvp-handoff.md　V4 段收敛为指针，避免同一状态在两个文件里各自演化
+ docs/2026-09-21-v4-calibration-handoff.md（本文件）

DECISIONS
1. 减伤门槛取「读对 + 做对」：反制未识破时不给 -3。若只按行为判定，
   不看信息、靠运气撞对动作也能白拿减伤，信息就不再是资源。代价是漏一次观察就吃满伤害。
   **待 L1 确认**；若要求纯行为判定，回退面是 counterHandled() 的首行一句。
2. autoplay 探针加硬门：拿不到 Mvp.stats() 直接失败，不允许静默退化。
   （顶层 `const Mvp = ...` 不会挂到 globalThis，探针曾因此读到 null 而报出「看着能跑、其实什么都没测到」的结果。）
3. 只测量不改数：autoplay 判定验收区间，但绝不修改任何数值。
4. 观察计数口径修正（本次）：只有「本来存在隐藏反制、且尚未识破」时才计一次信息税。
   原实现按 `!revealed` 计数，而**无敌方反制的回合 revealed 恒为 false**，
   于是山猪蓄势回合里当光道支援用的小光蛊也被算成「观察」——
   secure 的山猪战因此报 6 次观察（实际只买了 1 次信息）。修正后为 1 次。
   这是测量口径问题，不是玩法问题；PASS/FAIL 数不受影响。

VERIFY
tests: node --test 显式 8 个测试文件 → tests 105 / pass 105 / fail 0
syntax: node --check js/mvp_logic.js / js/mvp.js / js/mvp_content.js / tools/autoplay.mjs → OK

V4.1 SEED 101 门（2026-09-21 实现后）
gate: node tools/autoplay.mjs --route all --seed 101 → **26/40，exit 3**

已闭合：
- **stalemate = 0/3**（逆息消灭 soft-lock，Q1-D 生效）
- 三线均进入 Boss（Boss 开战不满血满真元 3/3 PASS）
- 猎犬 5 回合（窗口 3~5 PASS）· 总回合 22/23/22（17~24 PASS）
- 逆息不再空转成回蓝循环（secure 0 / sacrifice 1）

仍未达标（**非实现缺口，是冻结伤害表 × 回合窗口的算术冲突**）：
| 项 | 窗口 | 实测 | 算术下界 |
| --- | --- | --- | --- |
| 猎犬 | 3–5 | 5 | 10 HP / 月光 2–3 ≈ 4–5（贴边） |
| 山猪 | 4–6 | 5–8 | 15 HP，1/3 铁皮回合 0 输出 |
| 悍客 | 4–6 | 9–13 | 18 HP / 月光 2–3 ≈ **6–7 下界**（即便零反制） |
| Boss | 6–9 | 未杀死 | 28 HP / 月光 2–3 ≈ **9–14 下界** |
| 全程通关 | 3/3 clear | 0/3 | 入 Boss 仅剩 3–7 HP |
| debt 逆息 | ≤2 | 4 | 借月+还债后仅剩月芒（CD2） |

**结论**：Q1 软锁与 Q2 反制密度已按 V4.1 解决；
`悍客 4–6 / Boss 6–9 / 三线通关` 在**不改伤害表**的前提下数学不可达。
待 L1 裁决：① 上调回合窗口 ② 或上调月光/白豕伤害 ③ 或下调悍客/Boss HP。
**L2 未改任何冻结数字。**
```

逐场指标（口径修正后，seed 101）：

```text
[secure]    lost      步数 223 总回合 14 观察 3 受伤 17
  battle_1   6回合 观察2 受伤5  → 战后 HP24 Qi12 元石6   识破 draw_light/intercept
  battle_2   8回合 观察1 受伤12 → 战后 HP14 Qi9  元石6   识破 iron
  终局 HP0 Qi0 元石6（未走到 Boss）

[sacrifice] stalemate 步数 900 总回合 18 观察 5 受伤 23
  battle_1   6回合 观察2 受伤5  → 战后 HP24 Qi12 元石6
  battle_2   5回合 观察1 受伤10 → 战后 HP18 Qi11 元石13
  elite      7回合 观察2 受伤8  → 战后 HP14 Qi2  元石21
  终局 HP24 Qi1 元石21 · Boss 开战 HP14/24 Qi2/12

[debt]      stalemate 步数 900 总回合 17 观察 3 受伤 11
  battle_1   6回合 观察2 受伤5  → 战后 HP24 Qi12 元石6
  battle_2  11回合 观察1 受伤6  → 战后 HP19 Qi2  元石9
  终局 HP13 Qi0 元石9（未走到 Boss）
```

**已达标 9 项**：猎犬后 HP≥18（三路线均 24）／山猪后 HP≥12（14/18/19）／悍客后 HP≥8（sacrifice 14）／
总回合 13~20（14/18/17）／Boss 开战不满血满真元（sacrifice HP14/24 · Qi2/12，落在 L1 预测的 12~19）／
Boss 结束至少一路 HP≤8 或 Qi≤3／三条路线资源轨迹明显不同（3 种签名）／无 console 错误／
无横向溢出（1280/1280）。观察成本 1~2 次/场，符合 L1「1~2 次观察」的设计意图。

**未达标（上抛，未自决）**

1. **僵局 soft-lock（结构性问题，不是「难」）**：炼蛊台**消耗**月光蛊 + 小光蛊，
   此后唯一输出只剩月芒蛊（3 真元 + 1 气血，CD 2）；而真元战斗内不回复，噬元/焚元还在抽。
   真元归零后玩家可进入「没有任何可用输出手段、但收势(-2) + 生机草蛊(+1) 又刚好压过
   被处理过的敌方伤害」的状态 —— 既打不死也死不了。sacrifice / debt 均在此打满 900 步上限，
   autoplay 把它标成 `stalemate`。
2. **回合数约为目标 2 倍**：反制序列使「不能出手」的回合占比过高。seed 101 下猎犬与狼王的反制在
   `逐光 / 迎击` 之间交替（T1逐光 T2迎击 T3逐光 T4迎击…），山猪三分之二回合带铁皮。
   按「迎击不能硬打」的读法，这些回合伤害为 0。实测猎犬 6（目标 2~3）、山猪 5~11（3~4）、悍客 7（3~5）。
   **与加不加回血无关**（L1 已预判）。
3. **内容缺口**：悍客 `crossbow_shot` 与狼王二阶段 `thunder_pounce_2` 都没有 counterPool，
   按统一规则天生不可减免，故 L1 期望的「悍客 1 / 狼王重击 2~3」需先给这两个意图补反制才能达成。
4. **三条路线 0/3 通关** —— 这一条是 1 与 2 的合并结果，不是独立问题。

RISK
1. **本文件描述的状态不是可试玩版**：0/3 通关。此时让 L0 试玩，会产出一个被曲解的负反馈
   （「交易犹豫 / 构筑差异」这类目标信号根本来不及出现）。
2. **secure 是三条路线里唯一真的打输的**（HP0），且它不是僵局：secure 保留石皮蛊但没有白豕蛊，
   输出最低，山猪战拖到 8 回合、吃 12 点受伤。原因记在这里，避免下次误判成又一个僵局。
3. 敌对意图与反制序列是本 lab 的场景配置，**不应回写为正式 Godot 数值结论**。
4. ~~多局达标率尚未实现~~ **已补工具能力（2026-09-21）**：autoplay 支持
   `--seeds 101-110 --min-clear-rate 0.7`，多种子时按每路线通关率判定。
   但**达标率数据尚未采集**——在 L1 裁决前跑多种子只会把当前结构性 FAIL 乘以 N。
5. ~~意图预览仍显示原始伤害~~ **已回显减伤区间（2026-09-21）**：`previewEnemyDamage`
   与结算同一条公式，显示 `预计 min~max 伤`（及当前路径投影值）。
6. 观察成本只在 seed 101 上验过，换种子未跑（见 4）。
7. `mvp.html` 与 `index.html` 逐字节相同（两个重复入口）；按 L1 指示暂不删，待 V4 数值通过后清理。

> **L0 纠偏（2026-09-21）**：公理 `docs/ORIGINAL_POWER_SYSTEM_AXIOMS.md`；
> 数值工具已 DEMOTE 为校验器。Lab 新机制三问：`docs/lab-mechanics-three-questions.md`。

### 多种子实测（2026-09-21，seeds 101–105）

```text
secure   0/5 clear   sacrifice 5/5 clear   debt   0/5 clear
stalemate 0/15      五种子逐场指标完全一致
```

**发现：V4.1 起 lab 对 `?seed=N` 实际无响应**（反制改为确定性 `counterSequence` 后，
唯一 RNG `pickVariant` 已不用；固定路线亦无掉落随机）。
→ `--seeds` 在加回有意义方差之前，只是同一局的复制；「≥7/10」无信息量。
方差应加在何处（意图微扰 / 掉落 / 交易顺序）属产品，待 L1/L0。

NEXT
1. **通关缺口（产品/威胁预算，非实现 bug）**：
   - secure：保炉留月光，Boss 17 HP 进场仍被磨死（差 1 血反杀，已修逆息自杀窗）。
   - debt：借月+还债后仅剩月芒 CD2，Boss 16 HP 进场被磨死。
   - sacrifice：**cleared**（白豕持续输出）。
   → 构筑强度差导致 1/3 clear。L1 窗口「4–6 回合」也被强线打穿（山猪 3 回合）。
   **请 L1/L0 裁**：窗口是否容纳构筑差，或 Boss 威胁再降一档。
2. 三线 clear 后：`--seeds 101-110` 采多种子，再交 L0 五问试玩。
3. 收尾：删 `mvp.html`（待门通过）。
