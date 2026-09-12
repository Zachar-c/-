# Q8_BEHAVIOR_BASELINE.md — 48 只显式蛊行为基线（Q8-IMPLEMENT Step 1 交付）

> - **日期**：2026-09-12
> - **定位**：Q8-IMPLEMENT 第 1 步交付物。把 48 只显式 `v1_effect` 蛊的**当前引擎行为**逐只锁成机器可读基线（不是抽样）；Grammar resolver 接管分发层后（Step 2–5），基线测试必须逐只保持绿——这是 R1/R2 行为保持承诺的验收面。
> - **基线宿主**：`tests/unit/test_q8_grammar_baseline.gd`（`BASELINE` 常量 46 行 + 2 专测）。
> - **验收命令**：`tools\godot.ps1 --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_q8_grammar_baseline.gd -gexit` → **4 tests / 378 asserts 全绿**。

## 1. 对拍范围与形态

| 分组 | 数量 | kind 分布 | 覆盖方式 |
| --- | --- | --- | --- |
| legacy 显式蛊 | 8 | strike 5 / shield 1 / heal_and_strike 1 / aoe strike 1 | 46 表 6 只 + 专测 2 只 |
| sword 显式蛊 | 40 | strike 16 / shield 6 / heal 10 / shift 5 / sword_intent 5 | 46 表 40 只 |
| **合计** | **48** | strike 21 / shield 7 / heal 10 / shift 5 / sword_intent 5 / heal_and_strike 1 | 46 表 + 2 专测 + 支援链 1 |

每只断言 7 维：playable、`true_qi`、`thoughts`、敌 hp、玩家 hp、`player.shield`、`battle.sword_intent`、`battle.turn_supports`。

## 2. 基线推导规则（全部带引擎锚点）

- **显式效果不做转数缩放**：`RANK_SCALED_KINDS = ["strike","shield","heal"]` 只作用于 role fallback（v1_battle_resolver.gd:25、145-146）。rank 4 的 sword_atk_4_01_gu 打出就是 5，不是 5+3。
- **成本链**：`true_qi_cost → essence_cost → 缺省 1`（v1_battle_resolver.gd:178）；`thought_cost` 缺省 1；`life_cost` 现数据全 0。
- **shift 转译**：历史 shift → shield，缺省 amount 1（v1_battle_resolver.gd:419-424）。
- **sword_intent**：battle 级键，cap 5（school_rules.gd:36）。
- **support 登记**：打出后 `turn_supports[school] += bonus`（v1_battle_resolver.gd:432-437）；同蛊自己的 strike 读不到自己这发（读在登记前，L393，支援链专测验证）。
- **heal_and_strike**：遗留复合通道（v1_battle_resolver.gd:414），blood_bat_gu heal 1 + strike 1。

## 3. 对拍过程新核实的三条引擎事实（2026-09-12 探针）

1. **转数门同时卡定义 rank**：`insufficient_qi_quality` 不仅看实例 rank，定义 rank 2+ 的蛊一转玩家同样被拒（探针：sword_atk_2_12 定义 r2 被拒、test_slay_gu 定义 r10 却通过——后者疑似带例外字段，待 Grammar 层实现时一并核）。对拍统一 `cultivation = 10` 解除门槛；效果数值与实例 rank 无关，不影响基线有效性。
2. **thought_cost 显式特例**：`sword_atk_2_20_gu` / `sword_atk_2_33_gu` 数据显式声明 `thought_cost: 2`（46 表中仅此两只），引擎正确按 2 结算。
3. **aoe 现状形态**：`test_slay_gu` v1_effect 带 `"aoe": true`，引擎**真实解析**该键（v1_battle_resolver.gd:399-405）：对全部存活敌逐个结算并落 `strike_aoe` 事件——双敌全灭是群体打击的正确结果。目标语义（enemy_first / enemy_all）与 aoe 键在 Grammar selector 集合中的归属于 Step 3 重新裁定，基线按现状固化。

## 4. 对拍面之外的基线参考（不在 48 内，行为冻结同承诺）

- **role fallback 4 类**（data/v1_battle.json `default_effect_by_role`）：attack = strike 2、defense = shield 3、healing = heal 2、recon = marked 1 + support self 1；fallback 走转数缩放 `base + (rank-1)`，support_bonus 梯度见 v1_battle_resolver.gd:147-148。已由 `test_q7_role_defaults.gd` 覆盖。
- **杀招 26 只**：走 `steps` 多段线（specs/2026-09-11-sword-kill-move-list.md v2），不进本次 48 对拍；其行为对拍在 Step 6（12 只验证蛊）/ T7 契约测试阶段随杀招线执行。
- **遗留兼容通道**：shift（5 只已对拍）/ buff / heal_and_strike（已对拍）/ sword_intent（5 只已对拍）——FINAL §6 表。

## 5. 与后续步骤的接口

- Step 2（Grammar resolver）落地时：**只许换内胆，不许动行为**——本测试逐只保持绿是合入前置条件。
- Step 3 selector 实现时需复核：aoe 键处置（§3.3）、`enemy_first` 按 §12-H4 语义（行动队列第一个存活目标）。
- 数据侧迁移（显式化 6 只 fallback 主蛊等）属后续批次；迁移前逐只对拍规则见 FINAL §6。
