# 风险登记册（RISK_REGISTER）

> 每条：**风险 | 等级 | 影响 | 证据/来源 | 建议处置 | 状态**
> 状态取值：`待用户确认` / `已缓解` / `已接受`。
> 等级：`高` / `中` / `低`。

---

## RISK-01 版权与授权：同人原型、设定使用权待确认

| 项 | 内容 |
| --- | --- |
| **等级** | **高** |
| **影响** | 本项目是《蛊真人》同人肉鸽原型。世界模型把原著设定（境界、道途、蛊虫命名、地理、势力、敌人）结构化重述为可机读数据，并在 `data/gu.json` 中收录 **276 条 `source_class: canon` 的蛊虫条目**。若未取得原著授权，公开发行/商业化该数据集与可玩原型存在权利风险。 |
| **证据/来源** | `data/gu.json` 的 `gu_stats.by_source_class = {canon: 276, original_game_content: 526}`；`docs/lore/canon-index.md` 的证据列指向 `分支：六卷精编版/蛊真人-clean.txt` 的行号；仓库根 `LICENSE` 与 `THIRD_PARTY_NOTICES.md` 未覆盖原著设定使用权。 |
| **建议处置** | ① 明确本包**仅供内部研发与授权范围内的用途**，在对外分发前完成法务确认；② 若需公开，先把 `canon` 条目替换为 `adaptation` / `original_game_content` 命名，或取得授权；③ 保持「不复制正文段落、单条摘录 ≤80 字」的现状（本包已遵守：`schema/README.md` 与 `docs/*.md` 中最长的引用是 `CAN-BEAST-TIER-001` 的短引）。 |
| **状态** | **待用户确认** |

## RISK-02 数值待确认：原型大量数值是 provisional

| 项 | 内容 |
| --- | --- |
| **等级** | **中** |
| **影响** | 世界模型忠实转述了原型的 provisional 数值，它们**不是平衡结论**。典型证据：`battle_stone_rewards.provisional_note` 明写「Q8-G 1-C provisional…数值 provisional、F8 校准」；`refinement_recipes.json` 的 `promotion` 配方来源写明「成本为 provisional，仅用于验证 promotion schema 与成本红线，尚未平衡」；`loot_tables.json` 的 `material_pity.note` 写明带段→f 段映射为 provisional。 |
| **证据/来源** | `world-model/data/balance.json` → `economy.battle_stone_rewards.provisional_note`；`data/gu.json` 中 `promotion` 类配方的 `source` 原文；`reports/balance-simulation.md` 的「待确认项」表。 |
| **建议处置** | ① 把这些数值全部当作**占位值**，在 F8 校准前不要据此下平衡结论；② `balance.json` 是唯一调参入口，校准只需改一处并重跑 `simulate_balance.py`；③ 改完后同步更新 `reports/` 两份报告。 |
| **状态** | **待用户确认** |

## RISK-03 扩展设定待确认：原创内容与原著混在同一张表里

| 项 | 内容 |
| --- | --- |
| **等级** | **中** |
| **影响** | 世界模型里有 **526 条 `original_game_content` 的蛊**、**4 个原创势力**、**12 条原创事件**、**75 种游戏扩展蛊材**。虽然每一条都有 `source_class` / `source_ids` / `adaptation_note` 三重标注，但使用者若不看这些字段，容易把扩展内容误读成原著设定。 |
| **证据/来源** | `docs/原著要素映射表.md` 的覆盖统计表：`gu` 802 条中 526 条为原创、`event` 12/12 为原创、`loot` 80 条中 75 条为原创；`paths.json` 的 `adaptation_note` 明写「道标签为开放集合…为游戏规则，不是原著规则」。 |
| **建议处置** | ① 任何对外消费方都必须先读 `source_class`；② `schema/README.md` 已把该字段标为必填并解释语义；③ 建议在面向玩家的图鉴/文案中显式标注扩展性质（`ADP-FACTION-001` 的不可越界项已要求）。 |
| **状态** | **已缓解**（有完整标注机制），但**扩展内容是否保留仍待用户确认** |

## RISK-04 Godot 原型不可端到端验证（本机无引擎）

| 项 | 内容 |
| --- | --- |
| **等级** | **中** |
| **影响** | 本机**没有安装 Godot**，因此 `world-model/` 无法与 Godot 原型做端到端一致性验证。世界模型是否与 Godot 运行时逐位一致**未经验证**；两边若同时演进会漂移。 |
| **证据/来源** | 全流程只用 `python`；`world-model/` 不 import 任何 Godot 相关模块；`tools/build_world_model.py` 只做**静态 JSON 派生**，不做行为比对。 |
| **建议处置** | ① 需要时在有引擎的机器上跑一次「同种子对拍」：用原型导出 5 局的地图/Boss/掉落序列，与 `world-model` 的台账比对；② 在此之前，把 `world-model` 当作**独立可运行的世界模型**，其与原型的一致性只保证到「数据同源 + RNG 语义同源」这一层；③ RNG 已做位级对齐（见 RISK-09）。 |
| **状态** | **待用户确认**（是否需要对拍，由用户决定） |

## RISK-05 角色兜底蛊同质化：742 只蛊只有角色兜底效果

| 项 | 内容 |
| --- | --- |
| **等级** | **中** |
| **影响** | 802 只蛊里 **742 只（92.5%）的 `effect` 是按 `role` 兜底的**（attack→strike 2、defense→shield 3、healing→heal 2、movement→shift 1、recon→status、logistics→heal 1）。同 role 的 379 只攻击蛊在战斗里**完全等价**，构筑深度只来自已有的 57 只独立效果蛊 + 376 条升炼链。 |
| **证据/来源** | `world-model/data/gu.json` 的 `gu_stats.by_effect_source = {explicit: 57, role_default: 742, combat_effects: 3}`；测试 `gu_table_faithfully_flags_role_defaults` 断言 `role_default > 700` 且**不许假装有独立效果**。 |
| **建议处置** | ① 本模型**不掩盖**这一事实，`effect_source` 是必填字段；② 后续内容批次的优先项应是「给流派代表蛊写独立效果」，而不是「再加派生蛊」；③ 平衡模拟显示这 742 只蛊**在实践中几乎不被选中**（主蛊 Top 10 全是独立效果蛊或有连携的蛊），所以它对当前可玩性的影响有限，但对**构筑多样性**是硬上限。 |
| **状态** | **已缓解**（已如实标注并量化），**内容补齐待用户排期** |

## RISK-06 黑市兑换率不对称（约 100 倍往返损耗）

| 项 | 内容 |
| --- | --- |
| **等级** | **中** |
| **影响** | 同一对资源的双向兑换率不对称：`寿元 20 → 魂 1` 与 `魂 1 → 寿元 10`，往返一次损失约 100 倍；`气血 20 → 魂 1` 与 `魂 1 → 气血 10` 同理。若这是刻意的「黑市吃人」，它成立了；若是未校准的漏洞，玩家可以用不存在的套利路径刷资源（实测**没有**套利空间，只有单向巨额损耗）。 |
| **证据/来源** | `world-model/data/economy.json` → `black_market_exchange` 5 条；`black_market_asymmetry_note` 已显式记录；`PROJECT_WORLD_MODEL_AUDIT.md` 附录 B 的黑市段；校验报告 §3 的备注里逐条列出了正反向比率。 |
| **建议处置** | ① 明确设计意图：不对称是**刻意的极高摩擦**（防套利），还是漏了校准；② 若要收敛，改 `balance.json` → `economy.black_market_exchange` 一处即可；③ 在 UI 上必须**同时显示两个方向的比率**，否则玩家会误判（`AGENTS.md`：禁止隐藏关键成本）。 |
| **状态** | **待用户确认** |

## RISK-07 兽骨单点经济

| 项 | 内容 |
| --- | --- |
| **等级** | **中** |
| **影响** | **392 条配方里 378 条吃 `beast_bone`（约 96%）**，其余材料（兽血 3 / 野猪王牙 2 / 月露 1 / 毒囊 1）总计不到 10 条。这意味着**晋升经济 ≈ 兽骨 + 6/10 元石**，任何兽骨掉率调整都会直接决定整局成长速度；同时 `advance` 类配方的材料去重后只剩 5 种，材料系统的多样性实际上是名义上的。 |
| **证据/来源** | `world-model/data/gu.json` 中 `refine_as_output` 的 `materials` 字段聚合统计；`PROJECT_WORLD_MODEL_AUDIT.md` 附录 C 明写「材料去重仅 5 种：兽骨 378 / 兽血 3 / 野猪王牙 2 / 月露 1 / 毒囊 1（**兽骨占 98%**）」。 |
| **建议处置** | ① 把兽骨当作**核心资源**而非普通掉落来设计（它的掉率 = 全局成长速度旋钮）；② 若要打破单点，需要给 `advance` 配方按流派分配不同材料（属于内容改动，需改只读上游 `refinement_recipes.json` 后重跑构建）；③ 调 `loot.tiers[*].material_pool` 中 `beast_bone` 的权重即可做短期缓解。 |
| **状态** | **待用户确认** |

## RISK-08 双套 `regen_pct` 并存（既有口径差异）

| 项 | 内容 |
| --- | --- |
| **等级** | **低** |
| **影响** | 原型的 `data/aptitude.json` 里 `regen_pct` = 甲40/乙30/丙20/丁10（局外），`data/v1_battle.json` 里 = 甲35/乙30/丙25/丁18（战斗）。两套同名不同值的表并存，容易误用。 |
| **证据/来源** | `world-model/data/balance.json` → `growth.regen_pct_out_of_run` 与 `growth.regen_pct_battle` 两个独立键；`PROJECT_WORLD_MODEL_AUDIT.md` §26 记录过该冲突。 |
| **建议处置** | ① 本模型**不合并**两套表（合并会改变既有实现语义），而是拆成两个不同名的键并各自注明用途；② `engine/rules.py` 只在相应场景读对应键；③ 若最终裁定合并，改 `balance.json` 一处即可。 |
| **状态** | **已缓解**（已拆名 + 注释），**是否合并待用户确认** |

## RISK-09 终局 Boss 数值倒挂

| 项 | 内容 |
| --- | --- |
| **等级** | **中** |
| **影响** | 第 5 层终局 Boss `miasma_vein_lord` 是 **rank 3 / hp 14 却是全场最弱的层主**：有效 HP `14 × 1.5 = 21`，低于第 4 层候选 `clan_patriarch` 的 `19 × 1.35 ≈ 26`。也就是说**打到最后一关遇到的是最弱的 Boss**，终局张力被削弱。 |
| **证据/来源** | `world-model/data/regions.json` → `layer_5.final_boss = miasma_vein_lord`、`layer_4.boss_pool` 含 `clan_patriarch`；`v1_battle.boss_layer_mult.five = {hp: 1.5}`；`../AGENTS.md` 当前待办里已把「`miasma_vein_lord` 强度倒挂」登记为已知问题。 |
| **建议处置** | ① 这是**上游平衡问题，不是世界模型引入的**；本模型原样转述并显式记录；② 修法有两种：提高 `miasma_vein_lord` 的 hp/rank（改上游 `enemies.json`），或让 L5 也用滑动窗口池（改 `regions.json` 的 `boss_pool`）；③ 本模型已为 L5 保留 `boss_pool` 字段（当前为空 = 固定），填入即可启用随机化。 |
| **状态** | **待用户确认** |

## RISK-10 行号漂移导致原著可追溯性脆弱

| 项 | 内容 |
| --- | --- |
| **等级** | **中** |
| **影响** | `docs/lore/canon-index.md` 的 `CAN-` 条目用 `文件名:行号` 定位原文（如 `蛊真人-clean.txt:3610-3614`）。**原文文件一旦替换或重新分卷，所有行号全部失效**，`world-model` 的 `source_ids` 就会指向错误位置。本包的 `source_ids` 直接依赖这套行号体系。 |
| **证据/来源** | `docs/lore/canon-index.md` 开篇自述「行号指向当前仓库版本的原文，原文替换后需要重新校验」；`docs/lore/README.md` 记录 `lore_engine/` 的 SQLite 中间层（含 source/citation/checkpoint）正是为缓解此问题而建。 |
| **建议处置** | ① 用 `lore_engine` 的 SQLite 中间层承担精确定位，`CAN-` 编号只作为稳定句柄；② `world-model` 已经只引用 **CAN-/ADP-/GAME- 编号**而不内嵌行号，所以行号漂移**不会**破坏世界模型自身的引用完整性——受影响的只是「回查原文」这一步；③ 若要加固，可把 `lore_engine` 的条目哈希写进 `manifest.json`。 |
| **状态** | **已缓解**（只引用编号、不内嵌行号），**进一步加固待用户确认** |

## RISK-11 战斗僵局与回合上界（本模型新增的原创规则）

| 项 | 内容 |
| --- | --- |
| **等级** | **低** |
| **影响** | 原型口径下，若敌人当前**所有意图都在 cooldown**，该回合不出手（`cooldown_wait`）。双方都无法终结战斗时会出现理论上不收敛的僵局。本模型为此新增了**原创规则** `run.max_battle_rounds = 40` + `stalemate_rule: retreat_with_cost`（超限即撤退，付 `retreat_stone_cost`，不足则改付气血 10%）。这是**世界模型对原型的偏离**。 |
| **证据/来源** | `world-model/data/balance.json` → `run.max_battle_rounds` / `run.stalemate_rule` / `run.stalemate_note_zh`；`../data/enemies.json` 的 `_phases_note` 原文「while every intent of the active phase rests the boss shows cooldown_wait and attacks nothing that turn」；模拟 200 局中出现 `battle_stalemate` 的场次由报告统计。 |
| **建议处置** | ① 明确这是**为有限收束而加的原创规则**，已在 `docs/肉鸽运行结构.md` §3.4 显式标注为「原创规则，原型没有这条」；② 若原型后续补了僵局规则，把 `max_battle_rounds` 调到与之一致或删除该保护；③ 灵敏度扫描里 `enemy_hp_mult=1.5` 曾把平均行动回合推到 1696（保护生效前），是这条规则必要性的直接证据。 |
| **状态** | **已缓解**（有界且已登记），**是否保留待用户确认** |

## RISK-12 RNG tick 语义与原型旧实现的偏离

| 项 | 内容 |
| --- | --- |
| **等级** | **低** |
| **影响** | 任务描述里写的口径是「tick 只做仿射混入」，但仓库自己的 `scripts/domain/rng.gd` 在 2026-09-10 已把这条口径判为**缺陷**并改为「tick = 流位置（`discard(tick)`）」。原因是仿射混入会让相邻 tick 恒差 `97 × 48271 mod M`，抽出等差阶梯而非随机序列。本模型采用了**修正后的语义**，因此与旧口径不一致。 |
| **证据/来源** | `scripts/domain/rng.gd` 的 `discard` 注释与 `scripts/domain/seeded_roll.gd` 的 `index()` 长注释（列出 `bound=4 → 每 tick 恒 +3` 等实测）；`world-model/engine/rng.py` 的模块 docstring；校验器 §5 的 `tick_is_stream_position_not_affine_mix` 断言（要求相邻抽取差值的集合 >1 个）。 |
| **建议处置** | ① 保留修正语义（它才是可用的随机），并在 `engine/rng.py` 与校验报告里显式说明偏离；② `mixed_seed()` 仍保留仿射形式，`tick=0` 时与旧实现**逐字节一致**，因此不破坏任何既有地图种子；③ 层号进 `salt`（`Stream(seed, salt, layer)` 拼 `L<layer>:` 前缀），满足任务对「层号必须进盐」的要求。 |
| **状态** | **已缓解**（已显式偏离 + 说明 + 断言） |

## RISK-13 派生数据与只读上游的漂移

| 项 | 内容 |
| --- | --- |
| **等级** | **低** |
| **影响** | `world-model/data/*.json` 是从 `../data/*.json` 派生的快照。上游改动后若不重跑构建，两边会漂移，且**漂移不会自动报错**。 |
| **证据/来源** | `manifest.json` 为每个数据文件记录 `sha256`，但**不记录上游文件的哈希**（上游仍在冻结期，读值会变）。`manifest.read_only_upstream` 列出了 20 个上游文件。 |
| **建议处置** | ① 凡是改动上游 `data/*.json` 的 PR，必须同时重跑 `build_world_model.py` 并提交新的 `data/` 与 `manifest.json`；② `validate_world_model.py` 会检出**由漂移引起的引用失败**（如新增蛊但配方未同步）；③ 若要强约束，可在 `manifest` 里加 `upstream_sha256` 字段（当前未加，因为上游处于设计冻结期、会频繁调整）。 |
| **状态** | **已缓解**（有 manifest 哈希 + 校验器），**上游哈希待用户决定是否加入** |

---

## 风险汇总

| 等级 | 条数 | 编号 |
| --- | --- | --- |
| **高** | 1 | RISK-01（版权/授权） |
| **中** | 7 | RISK-02、RISK-03、RISK-04、RISK-05、RISK-06、RISK-07、RISK-09、RISK-10 |
| **低** | 4 | RISK-08、RISK-11、RISK-12、RISK-13 |

**状态统计**：`待用户确认` 8 条 / `已缓解` 5 条。

**最需要用户先裁定的三件事**：

1. **RISK-01 授权**：本包能否对外分发（决定 276 条 canon 蛊虫条目的去留）。
2. **RISK-02 + RISK-09 数值**：provisional 数值与终局 Boss 倒挂是否在本轮校准。
3. **RISK-05 内容**：742 只兜底蛊是否要补独立效果（决定构筑多样性的上限）。

---

## 独立核验补充（2026-09-17，三路只读交叉核验后）

> 本节由外部独立核验得出，不改写上文任何原有条目；新增编号从 RISK-14 起。
> 核验明细见 `reports/independent-verification.md`。

### RISK-14 原著行号可追溯性脆弱 + 派生层来源字段缺失

| 项 | 内容 |
| --- | --- |
| **等级** | **中** |
| **影响** | ① 登记册只用 `文件名:行号` 定位，**未记原文校验锚点**（实测原文 SHA256 前缀 `BF78D414…`、437,060 行），原文替换后全表静默失效且检测不到；实测 41 条带行号条目严格命中 31/41（75.6%），偏差几乎全为正、属系统性偏置。② 派生层有 10 条标 `source_class: "canon"` 但 `source_ids` 为空，261 条程序化内容被冠以 `canon`；上游 `data/gu.json` / `enemies.json` / `npcs.json` 零来源字段。③ `data/loot_tables.json` 复用同名字段 `source_class` 表示「掉落来源」，与来源追溯语义冲突。 |
| **证据/来源** | `reports/independent-verification.md` §二；`docs/lore/canon-index.md`；实测 `蛊真人-clean.txt` SHA256 前缀与行数 |
| **建议处置** | ① 把上一节 RISK-10 的加固建议落为实施项：登记册头部写入原文 sha256 + 行数 + 取样锚点；② 派生层为 `canon` 且 `source_ids` 为空的条目补来源或改标 `adaptation`；③ `loot_tables.json` 的 `source_class` 改名为 `drop_source_class`；④ 本包引用的是 `CAN-/ADP-/GAME-` **编号**而非行号，故不受行号漂移影响（RISK-10 已缓解）。 |
| **状态** | **待用户确认** |

### RISK-15 外部消费方对炼蛊图与权重语义的误读风险

| 项 | 内容 |
| --- | --- |
| **等级** | **低** |
| **影响** | ① 377 条 `advance` 配方满足 `input_gu_ids == [output_gu_id]`（同名蛊升转）。本包将其解读为「同定义 +1 转」故不计为环，但外部消费方若按 `gu_id → gu_id` 建图会**全量误报环**。② `regions.json` 各层 `category_weights` 权重和为 **101**，包内校验器按 `abs(total-100) <= 1` 容差判 PASS；该字段是**相对权重**（`rng.next_index(total)`）而非概率向量，101 与 100 产出同分布——**实现上无害，但字段名易被误读为归一概率**。③ 包内数值校验只断言 `value > 0` 与量级范围，**未覆盖「与价值锚 `gu_value_by_rank` 一致」**；实测上游有 13 条策展蛊偏离锚（如 `white_jade_gu` r2 值 30）。 |
| **证据/来源** | `reports/validation-report.md` §3/§4；`reports/independent-verification.md` §三/§四；`data/gu.json` 的 `refine_as_output` 聚合 |
| **建议处置** | ① 在 `schema/README.md` 显式写明两个字段的语义（相对权重、同名自环为升转）；② 给校验器补一条「`value` 与锚一致（允许显式白名单）」的检查；③ 上游确有 13 条超标，是否收归锚值需产品裁定。 |
| **状态** | **已缓解**（语义已文档化），**校验器待补项** |

### RISK-16 上游实现未兑现宪章：5 条违反项 + 因果链 2 处硬断

| 项 | 内容 |
| --- | --- |
| **等级** | **中** |
| **影响** | 仓库的 Stage 0 世界规则基准 Gate 已于 2026-09-17 转为 GO，但生产 `data/` 与 `scripts/` **一行未改**。设计宪章 §5.3「应删除或禁用」7 条经独立核验仍有 **5 条明确存在**：流派当开局固定蛊包、`role` 兜底效果（745/802 走 `v1_battle.json.default_effect_by_role`）、寿元与魂在 `shops.json` 中当普通货币、后置任选「核心蛊」槽、NPC 无长期后果。因果链另有两处硬断：「炼化 / 认主」只是状态标签（新蛊直接置 `refined`）；「知识 / 操控 → 杀招」断裂（杀招是 `v1_battle.json` 写死的 26 条，玩家自定义组合仅有字段无写入方）。 |
| **证据/来源** | `reports/independent-verification.md` §五；宪章 `docs/superpowers/specs/2026-09-16-wenzhen-world-model-correction-design.md` §3.2/§5.3 |
| **建议处置** | ① 这属于**上游实现**问题，本包只读转述、遵守 Stage 0 冻结纪律未做任何修改；② 若要把世界模型真正作为游戏底座，需按宪章 §7 的阶段 1–3 顺序推进，优先补「炼化 / 认主」独立流程与「玩家自定义杀招编排」；③ 与本包 RISK-05（742 只兜底蛊）同源，建议合并排期。 |
| **状态** | **待用户确认** |

### RISK-17 原文语料含 782 处掩码，部分原著事实当前不可读证

| 项 | 内容 |
| --- | --- |
| **等级** | **中** |
| **影响** | `蛊真人-clean.txt` 全文含 **782 处 `**` 掩码**。`CAN-APTITUDE-001` 与 `GAME-CULTIVATOR-003` 所载「甲等八九成」正建立在被掩码的第 1358 行上，该数值在**当前原文无法直接读证**；本包 `realms.json` / `balance.json` 的资质口径（丁0.23 / 丙0.44 / 乙0.67 / 甲0.89）因此只有二手依据。 |
| **证据/来源** | `reports/independent-verification.md` §二第 3 点；`docs/lore/canon-index.md` 的 `CAN-APTITUDE-001` 行 |
| **建议处置** | ① 资质比例的最终依据应回到未掩码的原始语料或另行授权来源复核；② 本包已在 `realms.json` 把这批比例标为可用于世界观文案与校验参照，**不作为战斗数值的直接真值**（战斗数值走 `aptitude_factor` 整数口径）；③ 若用户可提供未掩码原文，可一次性回填并重跑校验。 |
| **状态** | **待用户确认** |

### 上游数据缺口（登记，不新增编号）

- `data/synthesis.json` 有 4 个卡片 id（`farewell_grip` / `light_probe` / `vitality_grass_remedy` / `blood_bat_bite`）共 6 处引用，**在上游无任何定义表**。
- **363 / 802（45%）** 的蛊不在任何配方中；**18 / 32** 敌人从未被任何节点引用；`gu_names.json` 有 25 组同表重名。
- 均为上游既有状态，本包只读转述。

### 核验后的风险汇总（含补充）

| 等级 | 条数 | 编号 |
| --- | --- | --- |
| **高** | 1 | RISK-01 |
| **中** | 11 | RISK-02、03、04、05、06、07、09、10、14、16、17 |
| **低** | 5 | RISK-08、11、12、13、15 |

---

## 补充：价值锚一致性检查已落地（2026-09-17 收口）

> 针对 RISK-15 的「校验器待补项」，本轮已实现并验证。

| 项 | 内容 |
| --- | --- |
| **改动** | `data/balance.json` 的 `economy` 新增 `gu_value_anchor_exceptions`（登记 13 条策展蛊）；`tools/validate_world_model.py` 第 3 节新增「价值锚一致性」检查；`data/manifest.json` 重算哈希。 |
| **规则** | 非测试蛊的 `value` 必须等于同转锚值 `gu_value_by_rank`；**例外必须显式登记**，未登记即判失败；已登记但取值等于锚值也判失败（防止白名单腐化）。 |
| **登记内容** | 13 条策展蛊（月光蛊 / 力量蛊 / 熊力蛊 / 白豕蛊 / 玉皮蛊 / 石皮蛊 / 爱别离蛊 / 血滴子 / 刀翅血蝠蛊 / 月芒蛊 / 月痕蛊 / 白玉蛊 / 月影蛊），理由：流派起始蛊或关键古方产物，交易价值高于同转基准锚。 |
| **实测结果** | 校验 **64,569 条 / 失败 0**、退出码 0（第 3 节由 7,934 → 7,947 条）；测试 **38 / 38**。 |
| **负控（反空转）** | 临时清空白名单 → 第 3 节 **FAIL(13)**、退出码 **1**；恢复后 → 退出码 **0**。证明该检查不是空转。 |
| **未变** | 13 条蛊的 `value` 数值**未修改**（不改上游语义）；是否需要收归锚值仍由产品裁定。 |

**RISK-15 状态更新**：`已缓解` → **已缓解（显式例外登记 + 负控验证通过）**，其中原先的「校验器待补项」**已关闭**。
