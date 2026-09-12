# Q8-G 1-C：战斗产石（施工与验收记录）

> - **上游**：Batch 0 §2–§4 冻结语义（战斗 = 主生产者；tier + layer 结构；生产者/转换器分离；数值 provisional 落 JSON）
> - **范围**：胜利结算石产出的领域接线 + 配置 + 校验 + 测试。**不含**：遭遇收入缩放（后续）、掉落池变更（1-D）、定价（Batch 2）
> - **状态**：✅ **CLOSED（2026-09-13 审阅正式关闭）**
>
> | 项 | 状态 |
> |---|---|
> | 战斗产石生产者 | ✅ |
> | tier 风险梯度 | ✅ |
> | layer 缩放 | ✅（单调不减，非逐层严格递增） |
> | 不可变事件日志 | ✅（append_event 即状态变更源——工程经验见 §3） |
> | stone_budget 第二 faucet | ⏸ 封闭是正确状态，不是缺功能 |
> | provisional 数值 | ✅ |
> | F8-lite 最小闭环 | ✅ 结构性验证成立（见 §4 降级说明） |
> | 完整经济可持续性 | ⏸ F8 |

---

## 1. 变更清单

| 文件 | 变更 |
|---|---|
| `data/balance.json` | 新增 `battle_stone_rewards`：`base_by_tier {common:3, elite:8, boss:15}` + `layer_step_pct 20`（全部 provisional，附 F8 校准说明） |
| `scripts/domain/loot_resolver.gd` | `settle_victory` 追加石产出：`_stone_reward(tier, layer)` = base + int(base × layer_step_pct × (layer−1)/100)；产石走不可变事件日志（`loot_stone_gained`，含 before/after stone） |
| `scripts/domain/content_catalog.gd` | `battle_stone_rewards` 校验：三 tier base 必须为正整数、layer_step_pct 非负整数（白名单红线同步） |
| `tests/unit/test_battle_stone_rewards.gd` | 新增 8 条测试 |

## 2. 冻结语义的落地对照

| Batch 0 冻结语义 | 实现 |
|---|---|
| 产出挂载 tier + layer，不按敌人 HP/伤害实时公式 | reward 纯函数：`base_by_tier[tier] + layer 修正`，与战斗过程/掉落 roll 完全解耦（确定性测试钉住） |
| 风险 ↑ → 收益 ↑ | 同层 common 3 < elite 8 < boss 15（测试断言） |
| 层级修正 | layer 1–5 单调不减，layer5 > layer1（测试断言） |
| 生产者 ≠ 转换器 | 石只在胜利结算净新增（事件 `loot_stone_gained`）；卖蛊/卖材料仍是转换，不计入生产口径 |
| 数值 provisional | 配置在 `balance.json` 并标 provisional_note；F8 校准只改数字不动契约 |
| 不接线清单 | `stone_budget` 仍未接线（第二 faucet 维持封闭） |

## 3. 实现要点（施工中真实踩到的坑）

`RunState.append_event` **本身会应用 event.after**——首版实现手工再 `next.stone += reward` 造成双重记账（e2e 测试当场抓住：0+3 变 6）。修复：只走事件 after 应用，不做手工赋值。这验证了"事件即状态变更"的既有架构约定。

## 4. F8-lite 循环验证（⚠️ 结论已按审阅降级：结构性验证成立）

- 10 场 layer-1 普通战斗产出 **30 石** ≥ 首步 promotion 石耗（10）。
- **准确表述（2026-09-13 审阅降级）**：在当前 provisional 数值下，基础战斗收入能够覆盖首步 promotion 的石耗，**最小经济闭环成立；不代表完整跑图经济可持续**——长期 promotion / 材料 / 商店 / 生命时间成本的覆盖，归 F8 在材料获取通道（1-D）接入后复跑。
- 测试注释已同步收紧（`test_f8_lite_...` 只声明 structural check）。

### 4.1 layer 取整注记（审阅补录，F8 调参时必看）

公式用 `int()` 取整，低值奖励会出现 3→3→4→4→5 而非逐层严格递增——当前测试口径为**单调不减**，这是有意选择。F8 调整参数时须继续守住三条：非负、单调不减、不因取整产生反常下降。

## 5. 验证记录

| 检查 | 结果 |
|---|---|
| 聚焦测试 `test_battle_stone_rewards.gd` | ✅ 8/8（含确定性跨种子、风险排序、层缩放、事件日志、elite cost 并存、F8-lite） |
| 全量 unit | ✅ **1426/1426**（两处下游硬编码账本已按产石更新：loot_tables 事件计数 +2；moonlight 全路线 935/885 → 938/888，注释标注产石来源） |
| 交互闭环 | 不适用（纯领域结算变更，无 UI 交互面变化） |

## 6. 债务与遗留

| # | 项 | 归属 |
|---|---|---|
| 1 | 产石数值（3/8/15 + 20%/层）provisional | F8 校准 |
| 2 | 遭遇收入随层缩放（Batch 0 §2.2）| 后续（数值后置裁决） |
| 3 | 新材料接入掉落池 | 1-D 掉落分层 |
| 4 | bone 论证 / 品质映射 | 维持既有登记 |
