# 2026-09-22 · Web 可玩游戏 · 最终验收记录

入口：`game/wenzhen-web-lab/lab.html`。证据分级见实施计划 §2。

## 复跑数字（本机）

| 集合 | 结果 |
|---|---|
| lab_combat + gu_rules + rules + mvp_logic | 56 / 56 pass |
| lab_transactions + gu_rules + loot + shop + run_flow | 39 / 39 pass |
| autoplay smoke seed 101 | PASS · NORMAL_RUN · outcome=defeat（魂魄耗尽）· completed=14 · softlocks=0 |
| autoplay lifecycle seed 101 | PASS · FIXTURE_INTEGRATION · 刷新可续 |
| autoplay full 101–102 balanced | PASS 2/2 合法终局（defeat / defeat）· softlocks=0 |
| autoplay full seed 103 refine | PASS · outcome=defeat（气血耗尽）· completed=10 |

## G01–G10

| ID | 状态 | 证据 |
|---|---|---|
| G01 | PASS | 大厅文案改为玩家目标与续玩说明；新入口无「拼装局/覆盖」 |
| G02 | PASS | lifecycle 套件：战斗中刷新恢复、继续、再开局按钮 |
| G03 | PASS | 节点只走 availableNodeIds；未完成战斗不可逃逸（view_only） |
| G04 | PASS | observe 保留反制；拳脚被反击吞掉只结算一次；lab_combat 3/3 |
| G05 | PASS（fixture） | lab_transactions 7 条账本：扣款一次、卖出不重入、奖励只领一次、缺料不扣 |
| G06 | PASS | killMoveRecipeInstances 实例占用；缺件拒绝装备并卸下 |
| G07 | **BLOCKED** | 自动走盘仅得 defeat 轨迹（魂魄/气血耗尽），尚无完整获胜轨迹；未改数值。需人工/更优策略获胜录像或 L1 平衡裁定 |
| G08 | PASS | 演武/覆盖收进 `?debug=1`；逆息按钮禁用并给原因；画像路径 `../assets/...` |
| G09 | PASS | 同 seed 可复现；101/102/103 起始节点与结局不同 |
| G10 | 待发行副本复验 | `package_lab.mjs` + README.html；见下 |

## 工程修复（本批）

1. `observe` 误传 `state` 给 `revealCounter` 清掉反制 → 改为对 target 调用
2. 拳脚绕过生效反击 → 与杀招同口径拦截
3. `killMoveRecipeInstances` 重复配方槽位抢占同一实例 → 调用内 reserved
4. 杀招装备/卖出/合炼用 `owned>0` 代替实例校验 → 统一走 `killMoveRecipeInstances`
5. `buyOffer` 增加元石硬门禁
6. 敌人画像路径、大厅文案、演武/覆盖隐藏、逆息禁用原因

## 遗留

- G07 获胜轨迹未闭合 → 整体交付状态 **BLOCKED**（不用 ACCEPTED_WITH_GAPS）
- 11 条经济警报仍在，未改价
- 整局成长循环（购买→炼化→合炼→杀招→大小突破）NORMAL_RUN 账本需人工完整跑一遍并截图
