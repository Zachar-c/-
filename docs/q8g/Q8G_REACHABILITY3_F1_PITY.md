# Q8-G Reachability-3 / F1 Pity：按 tier 独立材料保底计数（实施记录）

> - **性质**：R15 ② 层实施记录；上游裁定（2026-09-13）：Reachability-2 ✅ 关闭——输入蛊假设被证伪，真断点为 f1 断档沿顺序 promotion 链传导；本批立项 **F1 Pity 独立计数器**。
> - **目标句**：让 f1 的 pity 状态独立于 f2/f3/f4，不再因其他带段掉落而清零。**不扩产量、不动 Soul、不动 promotion 规则、不动 starter/商店。**
> - **状态**：✅ 已实施 + 测量（数据见 §4）。

---

## 1. Schema 决策（裁定授权本批选定）

两个候选：`pity_f1/pity_f23/pity_f4` 三字段 vs 泛化 `pity_by_band` 字典。**选定：`state.material_pity_by_tier: Dictionary`，按 loot tier 键控（`common/elite/boss`）**。理由：

- 与既有配置 `pity.material_pity.target_bands_by_tier`（common→crude、elite→plain/refined、boss→prized）**一一对应**，键集天然等于掉落池集合，resolver 在战斗结算处已知 tier，无需再建 band→tier 映射；
- 语义与 f1/f2_3/f4 分组完全等价（带段组 ↔ tier 是 1:1 的），文档与调试面板按 f 段解读；
- 单字典字段进 `RunState.STATE_FIELDS`，序列化/拷贝/读档/事件 after 自动生效，旧档缺键自动跳过（默认 0），零迁移代码。

## 2. 语义（三条硬规则）

1. **本组清零**：本 tier 战斗掉中该组目标（本派链路材料 × 允许带段）→ 该组计数归 0；
2. **本组推进**：本 tier 战斗未掉中目标 → 该组 +1（无材料掉落的战斗不变，与既有口径一致）；
3. **跨组零影响**：其他 tier 的任何掉落（含 f2/f3 命中）对 f1 计数**既不清零也不推进**——这是 Reachability-2 定位的根因修复点，已落为关键测试。

硬约束保持：pity 只从该池已声明的合法候选中补目标（`_material_pity_targets` 未动），不生成新材料、不跨 tier 拉取；threshold 3 全组共享。

## 3. 改动面

| 文件 | 变更 |
|---|---|
| `scripts/domain/run_state.gd` | `material_pity: int` → `material_pity_by_tier: Dictionary`（STATE_FIELDS 同步；旧档兼容：加载循环跳过缺键） |
| `scripts/domain/loot_resolver.gd` | `_roll_materials` 按 tier 取计数；`_next_material_pity` 改按 tier 推进/清零；`_apply_loot` 事件 before/after 落 `material_pity_by_tier` 全量字典（pity determinism 不放松） |
| `scripts/domain/debug_actions.gd`、`scripts/presentation/snapshots/{debug_snapshot,reward_snapshot}.gd` | 调试/提示显示改读 common（f1）计数，键名 `material_pity` 保持，表现层契约零变更 |
| `tests/unit/test_loot_pity.gd` | material 段重写：分 tier 强制/清零/推进 + **关键测试 `test_elite_f23_hit_leaves_common_f1_counter_untouched`** + 字典存档 round trip + 带流派重放确定性（记录全字典） |
| `tests/unit/{test_debug_actions,test_shop_affordability}.gd`、`tests/integration/test_long_run_soak.gd` | 字典形态同步 |
| `data/loot_tables.json` | 仅 note 更新（配置 shape 不变） |

## 4. 测量数据（8 种子同集，R5 sweep，2026-09-13）

| seed | 派 | f1/f2/f3/f4 掉落 | 探访 | gu/mat/full_ready | 尝试/成功 | Gate B/C |
|---|---|---|---|---|---|---|
| 20260927 | force | **0**/5/5/2 | 4 | 4/3/0 | 0/0 | FAIL/FAIL |
| 11 | force | 2/3/4/1 | 1 | 1/0/0 | 0/0 | FAIL/FAIL |
| 33 | force | 1/2/1/1 | 2 | 2/1/1 | 1/1 | FAIL/FAIL |
| 55 | force | 3/2/1/2 | 5 | 5/4/3 | 3/3 | PASS/FAIL |
| 20260927 | sword | 1/1/1/1 | 4 | 4/3/2 | 1/1 | FAIL/FAIL |
| 11 | sword | **0**/1/0/2 | 2 | 2/2/0 | 0/0 | FAIL/FAIL |
| 33 | sword | **0**/1/3/1 | 2 | 2/1/0 | 0/0 | FAIL/FAIL |
| 55 | sword | 3/5/2/3 | 5 | 5/5/4 | 4/4 | PASS/**PASS** |

**Gate B 2/8（较 R4 阶段 4/8 回退）、Gate C 1/8。**

## 5. 根因修正（Reachability-2 归因的补充与修正，探针证据）

分 tier 计数器按裁定语义正确工作（单元测试全绿），但**没有**消除 f1 断档，且 Gate B 回退。在 `settle_victory` 处加临时探针（已移除）逐场观察 8 种子后，根因修正如下：

1. **掉落池 tier 跟随 E6 滚出的实际敌人，而非节点模板**。`battle["enemy_kind"]` = `enemy_roll` 结果（E6）或 DDA swap 结果；多敌战斗 `enemy_kind` 为空 → `_enemy_tier("")` 兜底 common。
2. **高频敌人多为 elite tier**：最常见的狼 `thunder_crown_wolf` 在 `enemies.json` 标注 **elite**。8 种子实测每局战斗落池分布：**common 仅 1–4 场（中位 2），elite 2–11，boss 2–5**。
3. 因此 f1（crude 带，唯一来源 = common 池）的自然供给与 pity 触发机会都被结构性压扁：common 战斗不足 threshold(3) 场，分 tier 计数器根本积累不起来——**Reachability-2 的"共享计数器被 elite f2/f3 清零"只是次因，主因是 common 池战斗稀缺**。
4. Gate B 回退的机制：旧共享计数器被所有战斗喂大，实际为 elite/boss 强制提供了"跨池补贴"；分 tier 后 elite 组只由 elite 战斗喂（f2/f3 命中即清零），强制频率下降，各局强制材料总量减少（如 force 55：f2/f3 掉落 ×5/×4 → ×2/×1，promotion 4→3）。

## 6. 待裁定（本批不擅自实施，数据已备齐）

f1 断档的真修复超出"F1 Pity 独立计数器"的授权范围，候选：

- **(A) 数据层**：修正 `enemies.json` 高频敌人的 tier 标注（如 `thunder_crown_wolf` elite→common）或调 `pacing.enemy_weights` 让 common 滚动占多数 → common 池战斗回归正常占比。⚠️ 影响面宽：tier 同时决定石头奖励（`battle_stone_rewards`）、精英绑定代价、战斗难度（E6/E1/1-C 范围），动数据须过相应门并重测石头经济。
- **(B) P2-b 带段通道再分配**：crude(f1) 以小权重挂入 elite 池 → elite 战斗也能补 f1。⚠️ 改变 1-D"f1 唯一来源 = common"的设计，且 `target_bands_by_tier.elite` 需扩 crude，偏离裁定写明的"elite→f2/f3"映射。
- **(C) 语义扩展**：f1 计数改为"全战斗 f1 连续缺失计数"（任何战斗无 f1 即 +1，f1 掉落清零；强制仍只在 common 战斗——硬限不破）。⚠️ 与关键测试"elite f2/f3 命中 → 不影响 f1 计数"的字面语义冲突（该场战斗会使 f1 +1），需改写测试口径并获追认。
- **(D) 接受现状**：f1 稀缺定性为 F8 平衡议题，回退共享计数器（恢复 Gate B 4/8）或保留分 tier（Gate B 2/8）二选一。

Agent 建议：**(A) 为治本方向**（世界模型上"常见野兽"本就应是 common 池主力，elite 标注更像是 E6 施工时的 tier 权重素材错位），但属 E6 数据变更，须单独裁定并重跑石头经济与 E2a 门。

## 7. 验证

- 聚焦：`test_loot_pity` 14/14（新增关键测试 + 存档 round trip）、`test_debug_actions` 13/13、`test_shop_affordability` 4/4、`test_content_catalog` 21/21、`test_material_drop_channels` 10/10、`test_long_run_soak` 1/1。
- 全量 unit：**1439/1439 通过**（GUT "All tests passed"、退出码 0）；净增 2 条（分 tier 存档 round trip + 跨组零影响关键测试）。退出时 RID/ObjectDB 泄漏与 `test_slay_gu_final_chapter.gd:149` 的 float→Dictionary SCRIPT ERROR 均为**既有遗留**（后者：该测试遍历 loot_tables 顶层 values，撞上 R-4 加入的标量字段 `school_material_resonance`，非致命、不判失败）。

## 8. 状态

⏳ **待裁定**：分 tier 计数器已按裁定落地并测试，但测量证明它治不了 f1 断档（根因在掉落池 tier 归因，见 §5）；四个候选方向（§6）待用户选择后再立实施批。Gate B 当前校准口径回落到 2/8，**Batch 1 Final Gate 维持 🔴**。
