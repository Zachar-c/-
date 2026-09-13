# Q8-G 1-D：掉落分层 / 材料获取通道（施工与验收记录）

> - **上游**：1-C CLOSED + 材料前置批债务账本（#1 蛊可达性 / #2 新材料通道 / #3 中高档实例已注册）
> - **范围**：品质带材料接入战斗掉落池（加权）+ 普通战基础蛊概率开启 + 材料池校验同步 + 可达性测试。**不含**：精英"定向候选"选择 UI（Batch 0 Q6 上层体验，登记后续）、采集/交易节点通道
> - **状态**：✅ **CLOSED（2026-09-13 审阅：有条件通过，三项必修已落实）**——①接线计数精确化 ②Gate B 升级为三 tier 实掉落验证 ③Material Reachability Matrix。聚焦 13/13（453 asserts）、全量 unit 1436/1436

> **⚠️ provisional 施工规则声明（审阅裁定）**：品质带 → tier 的映射（common→crude、elite→plain+refined、boss→refined+prized）是 **provisional 施工规则，不是 F8 裁定前的最终经济裁定**——它决定"玩家在什么难度下获得什么品质"，属经济循环的一部分。F8 可整体改写映射，接线测试随规则一起更新，不构成兼容性契约。同时："Boss = 高阶材料主通道"是 Batch 0 Q6 的**世界模型方向**；"Boss → prized"是 **provisional game design**——两层不得混称。

---

## 1. 变更清单

| 文件 | 变更 |
|---|---|
| `data/loot_tables.json` | 三 tier 材料池接入品质带材料（加权条目）；common `gu_chance_pct` 0 → **6** |
| `scripts/domain/loot_resolver.gd` | `_roll_materials` 加权化：池条目支持旧式字符串（weight 1，完全向后兼容）与新式 `{id, weight}`；`_material_entries` 归一化；保底 force 块改 id 查找 |
| `scripts/domain/content_catalog.gd` | 材料池条目校验：字符串或 {id, weight}，id 必须在注册表、weight 正整数 |
| `tests/unit/test_material_drop_channels.gd` | 新增 10 条测试 |

## 2. 品质带 → tier 映射（provisional 设计提案，F8 校准）

| tier | 接入材料 | 权重 | 世界语义（Gate 0 可解释） |
|---|---|---|---|
| common | **crude ×19**（18 全梯派 + bone 档1） | w3 | 普通战拾取基础资源（Batch 0 Q6："普通战……小概率基础材料"） |
| elite | **plain ×18**（w3）+ **refined ×18**（w1） | — | 精英战收益上探（refined 同时留在 boss 池） |
| boss | **refined ×18**（w2）+ **prized ×18**（w3） | — | "Boss = 高阶材料主通道"为世界模型方向；"Boss → prized"为 provisional game design（Batch 0 Q6：Boss 关键材料为主） |

- 旧 7 种材料保留原位（legacy 字符串，weight 1，行为不变）。
- **bone 档 2–4 与 light 全档未接线**（既有债务维持；bone 暂缓、light 谱系待裁）。
- 权重语义（审阅修正）：**"本派 crude 在 common 材料池的单次抽样中权重占比 3/60 ≈ 5%；不等同于单场战斗获得概率"**——实际获得还取决于材料 roll 触发、池内旧 7 种材料、其他 18 派、roll 次数、layer 与其他 tier。
- ⚠️ 语义边界（Gate 0）：战斗掉落是材料的**临时通用通道**（"战后拾取"可解释）；gather/trade 类材料的专属节点通道（采集点/商人）登记为后续工作，不在本批。

### 2.1 Material Reachability Matrix（注册表层，与 seed 无关；测试 `test_material_reachability_matrix` 自动验证）

| 来源 \ 品质 | crude | plain | refined | prized |
|---|---|---|---|---|
| **common** | 19（18 全梯派 + bone 档1） | — | — | — |
| **elite** | — | 18 派 | 18 派 | — |
| **boss** | — | — | 18 派 | 18 派 |

自动守护五条：每个材料至少一条 acquisition path；暂缓派（bone 档 2–4）不得意外接入；light 全档零泄漏；每 tier 池非空；高品质至少有一条 elite/boss path。bone 档 1 进 common 为**有意豁免**（其世界语义裁定未阻塞基础资源）。

## 3. 普通战基础蛊（Batch 0 Q6 落地）

- 事实核查：8 只非 starter 的 1→2 输入蛊**早已全部在各自 `school_pools.json` 流派池中**（逐只验证）——债务 #1 的真实缺口是 common `gu_chance_pct = 0`（普通战完全不掉蛊，违背 Q6"低概率获得基础型蛊"）。
- 修复：`gu_chance_pct 0 → 6`（provisional）。掉落路径：6% 触发 → rarity 权重（common 80）→ `_pick_from_bucket` 流派过滤 → 本流派 r1 蛊。至此 **19 派的 1→2 输入全部战斗可达**。

## 4. 验证记录

| Gate | 检查 | 结果 |
|---|---|---|
| Schema | 全量 validate 清洁；加权条目（含未知 id 反例）被正确校验 | ✅ |
| 接线矩阵 | 18 全梯派 × 4 档在指定 tier 出现/不出现；bone 仅档 1；legacy 7 种原位未动 | ✅ |
| 权重 | 派级 w3 / 混合档 w1-w2 / legacy w1 逐项断言 | ✅ |
| 确定性 | 同 seed 两次结算材料序列逐字一致（10 seeds） | ✅ |
| Gate B（三 tier 实掉落验证） | common 60 seeds → crude surfaced >5；elite 120 seeds → plain >2 + refined >1；boss 120 seeds → refined >1 + prized >2（固定 seed 区间，F8 改权重则数字随迁） | ✅ |
| 可达性矩阵 | 注册表层矩阵 + 防泄漏守护（light/bone）自动验证 | ✅ |
| 蛊可达 | common chance 6% + 8 只输入蛊逐只在派池 | ✅ |
| 聚焦测试 | `test_material_drop_channels.gd` **13/13（453 asserts）** | ✅ |
| 全量 unit | **1436/1436** | ✅ |
| 交互闭环 | 不适用（纯掉落数据与领域逻辑，无 UI 交互面变化） | — |

## 5. 债务账本更新

| # | 项 | 状态 |
|---|---|---|
| 1 | 8 只非 starter 蛊可达 | ✅ **清偿**（派池既有 + common chance 开启） |
| 2 | 新材料获取通道 | ✅ **首通道落地**（战斗拾取，73 条加权接线）；节点通道（采集/交易）登记后续 |
| 3 | 中高档品质实例 | ✅ 已注册（1-B1-a~d），本批接线 |
| 4 | 品质带↔转数映射 | ⏸ F8 / Batch 2 |
| 5 | light 材料注册 | ⏸ 谱系待裁 |
| 6 | bone 论证 | ⏸ 单独补批 |
| 8 | 精英"定向候选"选择体验（Batch 0 Q6 上层）| 登记后续（当前为池内随机） |
| 9 | 采集/交易节点通道（gather/trade 类材料的专属获取）| 登记后续 |

## 6. Batch 1 状态

```
1-B0-R ✅ → 1-B0-M ✅ → 1-B1 ✅ → 1-C ✅ → 1-D ✅（本轮）
→ Batch 1 总验收（Gate A/B/C 三问）→ Batch 2（gu_value → 商店定价）
```
Gate A（战斗合理赚钱）与 Gate B（高转可玩获得）的数据前提已齐：产石 ✅ + 材料通道 ✅ + promotion 链 ✅。总验收建议以确定性模拟（F8 口径）跑通"单流派局 3-5 小时内完成至少一条 1→5 链"后正式裁定。
