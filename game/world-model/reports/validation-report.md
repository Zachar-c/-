# 世界模型校验报告

- 生成时间：2026-09-20T01:12:01
- 数据目录：`world-model/data/`
- 检查总数：**64635**
- 失败总数：**0**
- 结论：**全部通过**

## 实体计数

| 文件 | entity_type | 实体数 |
| --- | --- | --- |
| realms.json | realm | 36 |
| paths.json | path | 20 |
| gu.json | gu | 802 |
| economy.json | economy | 1 |
| factions.json | faction | 6 |
| regions.json | region | 7 |
| events.json | event | 12 |
| loot.json | loot | 1 |
| balance.json | balance | 1 |
| manifest.json | manifest | 1 |

## 1. Schema 校验（schema/world-model.schema.json，自写迷你校验器）

- 实际检查条数：50878
- 失败条数：0

## 2. 引用完整性（gu ↔ recipes ↔ materials ↔ shops ↔ schools ↔ enemies ↔ nodes ↔ loot）

- 实际检查条数：5669
- 失败条数：0

## 3. 数值越界（rank/value/cost/hp/权重/概率范围、权重守恒与归一、价值锚一致性）

- 实际检查条数：7949
- 失败条数：0

## 6. Rank Power Budget 与转数曲线归位（RUL-2026-09-19-008 P2）

- 实际检查条数：27
- 失败条数：0

## 4. 死循环 / 环检测与升炼链深度

- 实际检查条数：100
- 失败条数：0

## 5. 确定性自检（LCG 位级一致、tick 流语义、层号入盐）

- 实际检查条数：12
- 失败条数：0

## 备注与观察（非失败项）

### 1. Schema 校验（schema/world-model.schema.json，自写迷你校验器）

- realms.json: 1218 条断言，0 条失败
- paths.json: 1680 条断言，0 条失败
- gu.json: 41116 条断言，0 条失败
- economy.json: 1550 条断言，0 条失败
- factions.json: 436 条断言，0 条失败
- regions.json: 2509 条断言，0 条失败
- events.json: 661 条断言，0 条失败
- loot.json: 1522 条断言，0 条失败
- balance.json: 52 条断言，0 条失败
- manifest.json: 134 条断言，0 条失败

### 3. 数值越界（rank/value/cost/hp/权重/概率范围、权重守恒与归一、价值锚一致性）

- 越界但已标记的调试实体（不进入内容池）：test_slay_gu(rank=10, canon_review_status=needs_source)
- 黑市 lifespan 20 → soul 1（反向 soul 1 → lifespan 10）
- 黑市 soul 1 → lifespan 10（反向 lifespan 20 → soul 1）
- 黑市 health 20 → soul 1（反向 soul 1 → health 10）
- 黑市 soul 1 → health 10（反向 health 20 → soul 1）
- 黑市 health 20 → lifespan 10（无反向报价）
- 黑市双向兑换率不对称（约 100 倍往返损耗）是已登记风险项 RISK-06，不是校验失败。

### 6. Rank Power Budget 与转数曲线归位（RUL-2026-09-19-008 P2）

- rank_power_budget 1-5 转 = 40/80/160/320/640（rank1=100*0.2*2，步进比 2，零数值漂移）。
- 归位轴：能力预算 rank_power_budget｜真元 essence_budget｜经济 economy＋敌人关卡 enemy_level_system＋进度奖励 progression_reward＋并列参照 parallel_reference。

### 4. 死循环 / 环检测与升炼链深度

- 纯材料炼制（无输入蛊）：stone_shell_bone_forge
- 同名升阶（advance，输入=输出同一定义）配方 377 条，按“同定义 +1 转”解读，不是环。
- 升炼图：节点 88 个、有向边 97 条、环 0 个。
- 最长升炼链深度：5 步（自 blood_droplet_gu 起，按转数严格递增的 DAG 计）。
- 蛊定义转数分布：1 转 220 只，2 转 157 只，3 转 180 只，4 转 97 只，5 转 147 只，10 转 1 只

