# T1 · 剑道「式」数值表（2026-09-11）

> **性质**：可审阅中间产物（任务书 §5 第一步）。**表审通过前不写 `gu.json`。**
> **口径**：`amount = 兜底 base + (rank − 1)`（attack 2 / defense 3 / healing 2）⇒ **显式化前后逐只行为保持**（红线 11）。
> `shift` / `status` 不随转数放大（`RANK_SCALED_KINDS` 仅 strike/shield/heal）。
> **引擎事实依据**：任务书 §0 F1–F4。既有支援先例仅 1 条：`small_light_gu`（light, rank1, strike 1 + support_bonus 2）。
> **成本现值**：40 只定义全部无成本字段 ⇒ 实际生效 `true_qi_cost=1, thought_cost=1, life_cost=0`（槽位默认）。

## 待审决策点（3 个，请先裁定再落库）

| # | 决策 | 选项 | 我的建议 |
|---|---|---|---|
| **D1** | **T6 残锋的批次 1 形态**。任务书横幅已裁定残锋≠`life_cost`（是"永久耗道痕降转"），但残锋结算需引擎改动（=T16，P2）。批次 1 是纯数据批 | **A**：批次 1 只抬起势蛊 `thought_cost`，rank4–5 attack 加**预留字段**（如 `sword_mark_cost: true`，引擎暂不读），残锋结算归 T16；**B**：批次 1 先用 `life_cost:1` 当代理代价（引擎已有预检），T16 再换 | **A**。理由：横幅明说"不是 life_cost"；B 会让玩家先适应一套将被撤掉的代价语义。风险：A 在批次 1 里 rank4–5 attack **无新增代价**，"叠满再放无脑最优"的缓解推迟到 P2 |
| **D2** | **起势档大小**（`support_bonus` 值） | 1 或 2 | **1**。先例 `small_light_gu` 是 bonus 2 + amount **压低到 1**（用伤害换支援）；剑道行为保持 amount 不压低，若再 bonus 2，rank1 起势蛊=2 伤+给后手 +2，单回合期望 4+，过强。bonus 1 时起势+主力连打期望 = base+1 |
| **D3** | **T5：10 只 recon/logistics 归宿** | (a) 改 `buff{name:"force"}`；(b) 保留 status 定位情报/门禁；(c) 暂不动标 P2 | **recon=(b)、logistics=(c)**。理由：recon 的 `marked` 留作情报语义成立（UI 已转"标记"文本）；logistics 的 `bound` 全仓无读取点=真死数据，但 (a) 的 buff 只强化**免费 basic_attack**，与剑道"用法>数值"哲学相悖且数值收益低，宁可留到破锋(P2)一并设计。**此裁定若通过，批次 1 对这 10 只零改动** |

---

## §1 attack 15 只（kind=strike，base 2）

| id | 名 | rank | amount | support_bonus | 成本（批次 1 后） | 式定位 |
|---|---|---|---|---|---|---|
| sword_atk_1_05_gu | 锋蛊 | 1 | 2 | **1** | 不变 | 起势·starter（双锋引材料） |
| sword_atk_1_06_gu | 刃蛊 | 1 | 2 | **1** | 不变 | 起势（双锋引材料） |
| sword_atk_2_12_gu | 古剑蛊 | 2 | 3 | — | 不变 | 直刺 |
| sword_atk_2_13_gu | 断剑蛊 | 2 | 3 | — | 不变 | 直刺 |
| sword_atk_2_19_gu | 斩剑蛊 | 2 | 3 | — | 不变 | 直刺 |
| sword_atk_2_20_gu | 藏锋蛊 | 2 | 3 | **1** | thought_cost 1→**2** | 起势（高阶，念头代价抬高） |
| sword_atk_2_26_gu | 剑青锋蛊 | 2 | 3 | — | 不变 | 直刺 |
| sword_atk_2_27_gu | 剑利剑蛊 | 2 | 3 | — | 不变 | 直刺 |
| sword_atk_2_33_gu | 剑匕蛊 | 2 | 3 | **1** | thought_cost 1→**2** | 起势（高阶） |
| sword_atk_2_34_gu | 剑刺剑蛊 | 2 | 3 | — | 不变 | 直刺 |
| sword_atk_2_40_gu | 锋刃蛊 | 2 | 3 | — | 不变 | 直刺 |
| sword_atk_4_01_gu | 剑气蛊 | 4 | 5 | — | 按 D1-A 预留残锋标记 | 主力 |
| sword_atk_5_02_gu | 飞剑蛊 | 5 | 6 | — | 按 D1-A 预留残锋标记 | 主力 |
| sword_atk_5_03_gu | 剑鞘蛊 | 5 | 6 | — | 按 D1-A 预留残锋标记 | 主力 |
| sword_atk_5_04_gu | 剑蛊 | 5 | 6 | — | 按 D1-A 预留残锋标记 | 主力 |

起势 4 只 / 直刺 7 只 / 主力 4 只。起势蛊全部排在前置位（F4：支援只惠及本回合**后续**同流派蛊）。

## §2 defense 5 只（kind=shield，base 3；不写 support）

| id | 名 | rank | amount | 备注 |
|---|---|---|---|---|
| sword_def_1_07_gu | 鞘蛊 | 1 | 3 | starter |
| sword_def_3_14_gu | 软剑蛊 | 3 | 5 | 软剑卸力，贴合剑道防御意象 |
| sword_def_3_21_gu | 剑光蛊 | 3 | 5 | |
| sword_def_3_28_gu | 剑古剑蛊 | 3 | 5 | |
| sword_def_3_35_gu | 剑斩剑蛊 | 3 | 5 | |

## §3 healing 5 只（kind=heal，base 2；不写 support）

| id | 名 | rank | amount | 备注 |
|---|---|---|---|---|
| sword_heal_1_09_gu | 意蛊 | 1 | 2 | starter |
| sword_heal_4_16_gu | 双剑蛊 | 4 | 5 | |
| sword_heal_4_23_gu | 剑刃蛊 | 4 | 5 | |
| sword_heal_4_30_gu | 剑软剑蛊 | 4 | 5 | |
| sword_heal_4_37_gu | 剑藏锋蛊 | 4 | 5 | |

## §4 movement 5 只（kind=shift，amount=1，**不随转数放大**；不写 support）

| id | 名 | rank | amount | 备注 |
|---|---|---|---|---|
| sword_mov_1_08_gu | 芒蛊 | 1 | 1 | starter |
| sword_mov_3_15_gu | 重剑蛊 | 3 | 1 | |
| sword_mov_3_22_gu | 剑锋蛊 | 3 | 1 | |
| sword_mov_3_29_gu | 剑断剑蛊 | 3 | 1 | |
| sword_mov_3_36_gu | 剑飞剑蛊 | 3 | 1 | |

shift 无 rank 加值（F1/RANK_SCALED_KINDS），显式化后与兜底完全一致。

## §5 recon 5 + logistics 5（按 D3 建议则批次 1 零改动，仅登记现状）

**recon（status marked，amount 1，UI 已转"标记"文本）**

| id | 名 | rank |
|---|---|---|
| sword_rec_1_10_gu | 青锋蛊 | 1 |
| sword_rec_5_17_gu | 匕蛊 | 5 |
| sword_rec_5_24_gu | 剑芒蛊 | 5 |
| sword_rec_5_31_gu | 剑重剑蛊 | 5 |
| sword_rec_5_38_gu | 剑剑光蛊 | 5 |

**logistics（status bound，amount 1，全仓无读取点=死效果）**

| id | 名 | rank |
|---|---|---|
| sword_log_1_11_gu | 利剑蛊 | 1 |
| sword_log_1_18_gu | 刺剑蛊 | 1 |
| sword_log_1_25_gu | 剑意蛊 | 1 |
| sword_log_1_32_gu | 剑双剑蛊 | 1 |
| sword_log_1_39_gu | 锋剑蛊 | 1 |

## §6 行为保持自检（T2 落库后由 T7 用例 2 钉死）

- 同 role 内相邻 rank amount 差恰为 1（strike/shield/heal 三族）。
- 显式化前后：每只蛊在战斗中的效果 kind/amount 逐只相同（对照本表与兜底公式）。
- 本批**唯一**新增差异 = 4 只起势蛊的 `support_bonus:1` + 2 只高阶起势的 `thought_cost:2` + （若 D1-A）4 只主力的残锋预留标记。
