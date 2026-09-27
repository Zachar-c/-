# RESEARCH REQUEST · lab role 曲线公式投影 policy（批B 换基激活前置）

> 提交人：L2 Orchestrator
> 上抛对象：**L1（研究院）**
> 日期：2026-09-26
> STATUS：**RULED（2026-09-26）**——裁定全文登记于 [`game/world-model/rulings/RUL-2026-09-26-001.json`](../game/world-model/rulings/RUL-2026-09-26-001.json)：公式 `world_amount / √20 → ceil → min 1`，policy=`sqrt_budget_scalar_projection_v1`；Q3 改伤随表（旧压缩表解冻重基）；Q4 MVP 例外重基（五字段记录）。批B 执行包已按裁定解锁（`ai-system/tasks/p3b1-role-curves.md`）。
> BLOCKS：批B 剩余面（`ai-system/tasks/p3b1-role-curves.md` 2026-09-26 收敛版）——换基激活 → Enemy HP envelope 重推导 → ⑤ 代表性 encounter 窗口验收
> 上位裁定：`RUL-2026-09-25-001` Q2（真源=balance.json、Web 走显式投影、「WORLD 曲线不直接复制到 LAB」）

---

## 0. 一句话问题

lab 的 role 曲线投影（`PROJ-LAB-ROLE-CURVE-001`）目前钉在旧基线值、policy=`legacy_lab_fallback_baseline_pending_l1`；请给出「WORLD curve → explicit projection policy → LAB PP → LAB amount」的**具体公式**（含取整规则），Worker 据此换基并重推导敌方侧。

## 1. 现状（`[仓内事实]`，已核文件）

| 项 | 现值 | 位置 |
|---|---|---|
| WORLD 真源（Q2 裁定值） | attack `[4,6,8,11,16]`、defense `[4,6,8,11,16]`、healing `[3,4,6,8,12]`、logistics `[2,3,4,6,8]`、movement `[1,1,2,2,3]`、recon `[1,1,1,1,1]` | `game/data/balance.json` `effect_budget.default_amount_by_role` |
| LAB 投影当前值（旧基线） | attack `[2,3,4,5,6]`、defense `[3,4,5,6,7]`、healing `[2,3,4,5,6]`、logistics `[1,2,3,4,5]`、movement/recon `[1,1,1,1,1]` | `game/wenzhen-web-lab/data/projections.json:59-77`（policy=`legacy_lab_fallback_baseline_pending_l1`，rationale 明写「L1 重派 lab 曲线后替换为公式投影」） |
| LAB 预算投影 | `LAB_BUDGET_PROJECTION=20`：labBudget(r)=worldBudget(r)/20 → `2/4/8/16/32` | `js/balance.js:49` + `PROJ-LAB-BUDGET-001` |
| PP 相对尺（检测用） | damage 1 / block 1.2 / heal 1.5 / inspect 1.5 / support 1.2 / suppress 2.5 | `js/balance.js:128-135` LAB_PRICING_V1 |
| LAB 分层常量 | playerHp 24（全仓 100）· thoughtsPerTurn 2（全仓 3）· 1石→2 Qi（全仓 5） | `PROJ-LAB-HP-001` / `PROJ-LAB-THOUGHT-001` / `PROJ-LAB-QI-EX-001` |
| 消费机制 | `defaultBattleEffect`/`resolveEffectAmount` 纯映射读投影表，rank 钳位 1–5，无独立规则 | `tools/build_data.mjs:161-192` |
| MVP 例外 | 月光/小光/月芒/白豕（+玉皮/石壳/生机草）lab 量纲覆写，pinned 值带 overrideReason | `PROJ-LAB-MVP-GU-EXCEPTION-001` + `js/mvp_content.js` |
| 敌方攻击压缩表 | `{1:2, 2:3, 3:3, 4:4, 5:4}`（按装载蛊转数压缩投影，构建期校验 Σ==intent.damage、≤lab attack 曲线、单调不减） | `PROJ-LAB-ENEMY-ATTACK-001` + `tools/build_data.mjs:44-52` |
| 代表性 encounter 窗口（L1 V4.1，冻结） | battle_1 `[3,5]` / battle_2 `[4,6]` / elite `[4,6]` / boss `[6,9]`；targetTurns=4/5/5/7.5 | `tools/check_balance.mjs:92-97` + `js/mvp_content.js:134-138` |
| 威胁预算（L1 P1-H2 冻结） | handleRate=0.35；survivalRate 猎犬 0.20/山猪 0.25/悍客 0.30/狼王 0.35 | `js/balance.js:284-292` |
| 参考吞吐 | refKit=kitDpr(开局 owned, actions)→refDpr；四代表性敌 HP=`deriveEnemyHp(refDpr, targetTurns, zeroRate, margin 1.08)` 推导（非手写） | `js/mvp_content.js:129-146` |
| 真实敌池 | 45 只 hp 手写于 `game/data/enemies.json`（如 ridge_hound 3 / iron_hide_boar 5 / soul_path_reaper 16），无 override 字段；override 登记在 `balanceReport.overrideReasons` | enemies.json + check_balance.mjs:115 |

旧基线的来历：旧 WORLD 曲线是 `base + (rank-1)` 线性（attack 2 起 → [2,3,4,5,6]），lab 历史上**逐字**采用世界值；V4.1 校准围绕它定窗。即旧 lab 值=旧世界曲线 verbatim——但 Q2 已裁「WORLD 曲线**不直接复制**到 LAB」，新曲线的对接必须经显式 policy。

## 2. 请裁决的问题

**Q1 · 公式**：给出六条 role 的 `lab_amount(role, rank) = f(world_curve, lab anchors)` 显式公式。
候选与已知影响（供参考，不是选择题全集）：

- **P-A · HP 比例缩放**：`lab = world × (lab_playerHp / world_human_base_health) = world × 0.24`，取整规则待定。attack → 约 [1, 1.4, 1.9, 2.6, 3.8]——相对旧基线整体下调，节奏变慢，敌方 HP envelope 随之下调。
- **P-B · 预算份额**：`lab = labBudget(r) × share(role, r)`，share 需另定（旧基线隐含份额随 rank 递减 100%→18.75%，无冻结公式）。
- **P-C · 逐字（world verbatim 经显式登记）**：attack → [4,6,8,11,16]。与 ANSWER Q2「不直接复制」冲突——列出仅供确认排除或给出豁免理由。
- **P-D · 其他**（L1 自定；例如以「代表性 encounter 窗口 + 威胁预算」为目标反解可行带，再在带内取最简公式）。

**Q2 · 取整与钳位**：非整数怎么处理（四舍五入/向下取/最小 1）；recon（恒 1）与 movement（有意偏离 sqrt）是否照抄 WORLD 值还是参与同一公式。

**Q3 · 敌方压缩表口径**：换基后 `PROJ-LAB-ENEMY-ATTACK-001` 的目标关系——「敌方 DPR ≈ 玩家参考吞吐 1/4」是否维持？压缩表 ≤ lab attack 曲线与 Σ==intent.damage 两条不变量的锚定方向（改表随伤 or 改伤随表）。

**Q4 · MVP 例外的关系**：月光线 pinned 值是 refDpr 的输入（敌 HP envelope 的推导源）。换基后 pinned 值与公式值的关系——维持例外原值（envelope 随旧吞吐，敌 HP 不动，⑤ 平凡成立）还是随公式走（envelope 重算，⑤ 有实义）？

## 3. 约束（L0/L1 已冻结，公式必须兼容）

1. `balance.json` 30 值真源不动；`LAB_BUDGET_PROJECTION=20`、PP 权重、playerHp 24、thoughtsPerTurn 2 不动（都是已登记投影）。
2. 四个代表性 encounter 窗口（L1 V4.1）与威胁预算（P1-H2）是验收门——公式落地后必须仍可满足（敌方可重推导）。
3. Enemy HP 重推导纪律（ANSWER Q2）：「新 kit → 重新推导 target encounter envelope」，**不因此手调全部敌人**；偏差 >20% 走 override_reason 门。
4. 「完整整局必须通关」不作为 role curve 单项硬门禁（RUL Q2）。
5. No Silent Fallback：投影必须有 parent/policy/validation/forbidWriteBack，公式可自动断言（check_projection）。

## 4. 期望产出

1. 一条公式（或批准的候选），含取整规则与 movement/recon 处理；六条 lab 曲线的逐值结果表。
2. Q3 的锚定方向裁定；Q4 的 MVP 例外关系裁定。
3. 一段可直接写进 `PROJ-LAB-ROLE-CURVE-001.policy/rationale` 的 policy 陈述（Worker 照抄登记）。

## 5. 附注

- 本件只裁 lab 投影 policy；WORLD 曲线本身（RUL-011 B3）与魂轴（Q3 刷新件已另发）不在范围内。
- 若你认为窗口/威胁预算与新公式数学不可兼容，请直接给出不可行结论与放宽建议——那也是有效答复。
