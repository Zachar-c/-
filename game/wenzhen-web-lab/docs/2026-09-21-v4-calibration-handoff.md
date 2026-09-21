# Handoff · V4 数值校准（10 分钟循环的第一道产品验收门）

本文件是 **V4 校准状态的唯一出处**。MVP 完成时的记录在
[`2026-09-21-mvp-handoff.md`](2026-09-21-mvp-handoff.md)，那边不再同步数值校准部分。

```text
TASK v4-calibration
PHASE 10 分钟循环 · 数值校准
STATUS BLOCKED（两个结构性阻塞已上抛 L1，等裁决；lab 内未自行改数）
TYPE implementation + measurement

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
tests: node --test 显式 8 个测试文件 → tests 98 / pass 98 / fail 0
       （Node 22.22.2 下 `node --test <目录>` 报 MODULE_NOT_FOUND，必须显式列文件）
syntax: node --check js/mvp_logic.js / js/mvp.js / js/mvp_content.js / tools/autoplay.mjs → 全部 OK
gate:  node tools/autoplay.mjs --route all --seed 101 → exit 3（19/34）
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
4. **多局达标率尚未实现**：L1 的口径是「每路线 10 局、≥7/10 通关；固定种子则代表 seed 都须有解」，
   当前 autoplay 的 `--seed` 只接受单值，测不了达标率。这条验收项现在**没有自动化手段**，只有单种子结果。
5. 意图预览仍显示原始伤害（如「预计 5 伤」），不反映 -5→-2 后的实际值 —— 减伤没有回显到预览（未改）。
6. 观察成本只在 seed 101 上验过，换种子未跑。
7. `mvp.html` 与 `index.html` 逐字节相同（两个重复入口）；按 L1 指示暂不删，待 V4 数值通过后清理。

NEXT
1. **L1 裁决两个杠杆**（二者耦合，先定哪个都行，但别只改一个就重跑）：
   - 解僵局：战斗内加真元回复／月芒可吃小光支援降费／炼蛊台不消耗月光与小光／给「空过 + 回气」加反僵局约束。
   - 解回合数：放宽「迎击」读法（攻击被吞但回合不空）／降低迎击出现频率／放宽回合数目标。
     注意：若迎击不再吃掉整个回合，战斗变短、真元也更撑得住，可能**同时**缓解僵局。
2. 裁决后按 L1 口径重跑：`node tools/autoplay.mjs --route all --seed 101`，并把多局达标率（≥7/10）补成工具能力。
3. 验收门通过后才交 L0 试玩（记录具体体验问题，再决定是否调数值或循环）。
4. 收尾项（不阻塞）：删 `mvp.html` 重复入口；意图预览回显减伤后的实际伤害。
