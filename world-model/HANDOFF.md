# 交接清单（HANDOFF）

> 交付内容：《蛊真人》肉鸽**可机读世界模型 + 可运行底座**，落在 `world-model/`。
> 阅读顺序建议：`README.md` → `docs/世界模型总纲.md` → `REVIEW_CHECKLIST.md` → `RISK_REGISTER.md`。

---

## 一、已完成

### 1. 统一 schema（验收 A1）

- `schema/world-model.schema.json`：draft-07 风格统一 JSON Schema，`$defs` 定义 10 类实体
  （`realm` / `path` / `gu` / `economy` / `faction` / `region` / `event` / `loot` / `balance` / `manifest`），
  含嵌套 `$defs`（`recipe_edge` / `shop_offer` / `npc` / `node_template` / `enemy` / `resource` /
  `exchange_rate` / `relation_level` / `event_option` / `material` / `manifest_entry`）。
- `schema/mini_schema.py`：**只用标准库**的迷你校验器，支持
  `$ref` / `type`（含类型数组）/ `enum` / `const` / `required` / `properties` /
  `additionalProperties`（bool 与 schema）/ `patternProperties` / `items` / `minItems` / `maxItems` /
  `uniqueItems` / `minProperties` / `maxProperties` / `minimum` / `maximum` /
  `exclusiveMinimum` / `exclusiveMaximum` / `multipleOf` / `minLength` / `maxLength` / `pattern` /
  `allOf` / `anyOf` / `oneOf` / `not` / `if-then-else`。
- `schema/README.md`：**逐字段说明表**（字段名 / 类型 / 取值范围 / 是否必填 / 含义 / 是否可调参），
  覆盖 10 类实体 + 全部嵌套结构，并提供关键公式表与异常约定表。测试
  `schema_field_tables_documented` 断言该表覆盖 schema 里所有实体类型。

### 2. 机读数据（10 个文件）

| 文件 | 条数 | 说明 |
| --- | --- | --- |
| `realms.json` | 36 | 1–9 转 × 4 小境界；一至五转带原著真元品阶，六转以上 `essence_tier` 留空 |
| `paths.json` | 20 | 道途/流派，含起始蛊、蛊池、冲突流派、兼修罚值 |
| `gu.json` | **802** | 全部蛊虫；每只带 `effect` + `effect_source` + 升炼配方边 + 商店/掉落交叉引用 |
| `economy.json` | 1 | 8 种资源、37 条商店报价、5 层预算、黑市汇率、通胀参数、材料参考价 |
| `factions.json` | 6 | 2 个原著依据势力 + 2 个原创势力 + 兽潮压力源 + 全局恶名轴 |
| `regions.json` | 7 | 宏观区域（含 32 敌人 / 37 节点模板 / 5 NPC）+ 5 层 + 升仙之窗 |
| `events.json` | 12 | 事件 + 诅咒池，每条含 `options[]`（接受/离开，带 `precheck_required`） |
| `loot.json` | 1 | 80 蛊材（7 核心 + 73 派生）+ 2 遗物 + 3 档掉落 + 保底 + 稀有度权重 |
| `balance.json` | 1 | **集中参数表**：成长/运行/经济/掉落/战斗门禁/势力 + 公式表 |
| `manifest.json` | 1 | 10 个文件的 sha256、字节数、实体数、版本、生成时间、零第三方依赖声明 |

全部实体统一带 `source_class` / `source_ids` / `canon_review_status` / `adaptation_note` / `tunable`，
字段命名与 `docs/lore/content-source-schema.md` 一致。

### 3. 规则与公式层（`engine/`，纯 Python）

| 模块 | 内容 |
| --- | --- |
| `errors.py` | 7 个异常类型 + 基类，各带 `code` 与 `as_dict()` |
| `rng.py` | Lehmer LCG（与 `scripts/domain/rng.gd` 位级一致）+ `mixed_seed` + `Stream`（层号进 salt、tick = 流位置） |
| `model.py` | 加载 + schema 校验 + 只读访问器 + `b(...)` 参数读取 + 内存覆盖（灵敏度扫描用） |
| `rules.py` | 修炼晋升（真元上限/恢复/门槛/洗髓换骨）、蛊虫全生命周期（获取/炼化/喂养/升炼/自由混合/反噬）、战斗结算（质量门禁/行动点/意图相位冷却/封蛊/护盾/三轴死亡）、掉落与权重（分档/保底/归一）、失败与继承 |
| `run.py` | 肉鸽运行结构：开局构建、5 层 × 行 × 节点推进、锚点、Boss 席位与池、12 类节点结算、阶段总账、僵局保护、结算与 Meta 继承、自动决策器 |
| `persistence.py` | 存档原子写（tmp→rename）+ 版本 + 校验和、台账写入与比对、损坏隔离恢复、大厅存档 |

### 4. 可玩运行器（`runner/cli.py`）

- `--seed N` 交互式（`help`/`status`/`map`/`save`/数字/`next`/`skip`/`quit`）；
- `--auto` 无人值守打完整局并落盘台账与存档；
- `--replay` 按种子重放并逐字节比对历史台账；
- `--status` 打印世界模型摘要 + 存档摘要 + 大厅进度；
- 任何非法输入都回显明确提示，不抛未捕获异常。

### 5. 校验脚本（`tools/validate_world_model.py`）

5 大类、**64,556 条断言**、0 失败：schema / 引用完整性 / 数值越界 / 环与链深度 / 确定性自检。
报告写入 `reports/validation-report.md`，含逐项检查条数、失败条数与观察备注。

### 6. 平衡模拟器（`tools/simulate_balance.py`）

200 局基线 + 100 局灵敏度扫描，报告写入 `reports/balance-simulation.md`，
含胜率、平均局时长（节点/战斗/回合）、构筑分布、卡点位置、异常终止数，
并给出 6 条「结论/待确认项」。灵敏度扫描用 `WorldModel.set_override` 做**内存覆盖**，不写回文件。

### 7. 文档

| 文件 | 内容 |
| --- | --- |
| `docs/世界模型总纲.md` | 世界层级、境界体系、道途/流派、蛊虫、时间线与地理势力、数据流；每段标注来源类别 |
| `docs/原著要素映射表.md` | **966 行**映射，覆盖 8 类实体 + 遗物/档位，逐条标注 CAN-/ADP-/GAME- 或「原著未明确，属合理扩展」 |
| `docs/肉鸽运行结构.md` | 开局 → 地图层级 → 遭遇配比 → Boss/阶段节点 → 战斗 → 结算 → 轮回（含 Mermaid 流程图） |
| `docs/数值与成长曲线.md` | 成长曲线、强度上限、行动经济、经济与通胀、掉落权重、常见构筑可行性 |

### 8. 测试（`tests/run_tests.py`）

**39 个用例、0 失败**，覆盖：schema/加载、种子可复现性（同种子同台账 + 大厅进度无关性）、
完整一局跑到结算、Boss 池约束、僵局有界、三轴死亡、
**6 条异常路径各至少触发一次**（资源枯竭 / 蛊虫反噬 / 数值溢出 / 数据缺失 / 数据格式 / 存档损坏）、
Meta 继承（只保留知识 + 零数值成长）、规则精细断言、manifest 哈希、CLI 端到端（含 `--replay` 与非法参数）。

### 9. 交接运维文件

`README.md`（含精确启动命令、依赖、参数调整指引、版本规则、回滚方式）、
`RISK_REGISTER.md`（17 条风险）、`REVIEW_CHECKLIST.md`（10 条验收逐条勾选 + 证据位置）、
`CHANGELOG.md`、`VERSION`、`.gitignore`。

---

## 二、未完成 / 未做

| 项 | 原因 | 影响 |
| --- | --- | --- |
| **多敌遭遇的 tier 结算** | 上游已知缺陷：`LootResolver` 只读 `battle.enemy_kind`，而 `BattleCommandFacade` 仅在 `enemy_roll.size()==1` 时写该键 ⇒ `beast_swarm_pass`（唯一多敌模板）即使两只都是精英也按 common 结算。修它要动 `LootResolver`（红线）。 | 世界模型把 `beast_swarm_pass` 当单敌处理并沿用其 `enemy_kind`；**不影响本包自洽性**，但多敌遭遇的奖励偏低。见 RISK 备注。 |
| **战斗中的护盾衰减** | 原型语义未在本包确认（本包的护盾在同一场战斗内不衰减）。 | 玩家防御构筑略强于原型（若原型有衰减）。属口径待确认项。 |
| **连携判定只用流派** | `support_school` 目前只按「持有另一只同流派存活蛊」判定，未实现标签级联动。 | 连携覆盖比原型窄；`ADP-GU-SYNERGY-001` 的标签联动未完全落地。 |
| **遗物的钩子未全部执行** | `loot.relics` 的 `hooks`（`on_battle_start` / `on_estimate_feeding`）只在数据层登记，引擎尚未逐条消费。 | 遗物目前是「收集品 + 部分数值占位」，不是完整机制。 |
| **升仙窗口未做成完整抉择** | `regions.json` 的 `ascension_window` 只登记为数据（`choices` / `on_skip`），运行器在打完第 5 层 Boss 后直接判 `ascended`。 | 升仙的「三气平衡」抉择未实现。**首发本来就不做**（`ADP-ASCENSION-001`），故不视为缺陷。 |
| **与 Godot 运行时的对拍** | 本机无引擎（见 RISK-04）。 | 一致性只保证到「数据同源 + RNG 语义同源」层。 |
| **`docs/lore` 的 Stage 0 世界模型裁定** | 本包是**工程侧的世界模型落地**，与 `docs/superpowers/specs/2026-09-16-wenzhen-world-model-correction-design.md` 的 `world_claim` 冻结流程是**两条独立的工作流**。 | 本包不替代、也不声称完成 Stage 0 的 24 条 `world_claim` 冻结。若 Stage 0 裁定与 `data/*.json` 冲突，**以上游 spec 与用户裁定为准**，本包应重新派生。 |

---

## 三、已知限制

1. **`effect_source: role_default` 的 742 只蛊**在战斗里按角色等价，构筑深度只来自 57 只独立效果蛊
   + 376 条升炼链（见 RISK-05）。
2. **兽骨占配方材料 96%**（378/392），晋升经济实际上是单点资源（见 RISK-07）。
3. **黑市双向汇率不对称约 100 倍**（见 RISK-06）。
4. **终局 Boss `miasma_vein_lord` 数值倒挂**（rank 3 / hp 14 × 1.5 = 21 < L4 候选 26），
   这是上游问题，本包原样转述（见 RISK-09）。
5. **僵局保护是原创规则**（`max_battle_rounds = 40` + 撤退），原型没有（见 RISK-11）。
6. **RNG tick 语义与任务描述里的旧口径不一致**：本包采用仓库自己 2026-09-10 修正后的
   「tick = 流位置」语义（见 RISK-12）。
7. **行号漂移**：本包只引用 CAN-/ADP-/GAME- 编号，不内嵌 `文件名:行号`，因此不受行号漂移影响；
   但「回查原文」这一步仍依赖 `canon-index.md` 的行号有效（见 RISK-10）。
8. **平衡结论基于脚本化 `--auto` 决策器**，不是人工最优解：通关率 67.0% 是**决策器**的成绩，
   真人玩家的通关率会不同。
9. **`docs/原著要素映射表.md` 有 966 行**，由 `tools/build_mapping_table.py` 生成；
   手改会被下次重新生成覆盖。

---

## 四、下一步建议（按优先级）

### P0 · 需要用户先裁定

1. **RISK-01 授权**：本包能否对外分发？决定 276 条 `canon` 蛊虫条目的去留。
2. **RISK-02 数值**：本轮是否做 F8 校准？（`balance.json` 是单点入口，改一处即可）
3. **RISK-05 内容**：742 只兜底蛊是否补独立效果？决定构筑多样性上限。
4. **RISK-06 黑市汇率**：不对称是刻意还是漏校准？
5. **RISK-09 终局 Boss**：改 `enemies.json` 的 hp/rank，还是给 L5 启用 `boss_pool`？
6. **RISK-11 僵局规则**：保留 `max_battle_rounds` 保护，还是等原型补规则？

### P1 · 工程加固

7. 把 `manifest.json` 加上 `upstream_sha256`（上游哈希），让派生漂移自动可检（RISK-13）。
8. 消费 `loot.relics` 的 `hooks`，让遗物成为真正的机制而不是数据占位。
9. 把连携判定从「同流派」扩展到「标签级」（`ADP-GU-SYNERGY-001` 的完整落地）。
10. 在上游修掉多敌 tier 结算缺陷后，把 `beast_swarm_pass` 改为真正的多敌战斗。

### P2 · 平衡与内容

11. 让「气血/寿元」两条死亡轴真正构成压力（当前 92% 死于魂轴）：
    调 `run.lifespan_milestones`（5 层 +100 寿元 vs 起点 60）或事件代价分布。
12. 给层间加递增压力，让难度曲线不再是平的（调 `regions.json` 各层的 `enemy_rank_min/max`）。
13. 收紧持蛊数量（均值 19.2 只 vs 原著「四五只」）：调 `loot.tiers[*].gu_chance_pct`。
14. 打破兽骨单点：给 `advance` 配方按流派分配不同材料（需改上游 `refinement_recipes.json`）。

### P3 · 与上游对齐

15. 在装有 Godot 的机器上做一次「同种子对拍」：导出原型 5 局的地图/Boss/掉落序列与本包台账比对。
16. 若 Stage 0 的 `world_claim` 裁定与本包数据冲突，按裁定重新派生（改上游 + 重跑构建 + 重跑校验）。

---

## 五、快速验收（复制粘贴）

```bash
cd <repo root>
python world-model/tools/validate_world_model.py          # 期望：检查总数 64556，失败 0
python world-model/tests/run_tests.py                     # 期望：用例 38，通过 38，失败 0
python world-model/runner/cli.py --seed 101 --auto        # 期望：结算 + 台账落盘
python world-model/runner/cli.py --seed 101 --auto --replay   # 期望：比对结果：一致
python world-model/tools/simulate_balance.py --runs 200   # 期望：报告 + 通关率 67.0%
python world-model/runner/cli.py --status                 # 期望：世界模型摘要 + 存档摘要
```

`--seed 101` 的确定台账指纹（可用于跨机器核对）：

```
content_sha256 = 584e141d68f085e7d1e49019f86d44c67ba3930b662d12dc1ed29b913a8c689d
结局 = 通关（ascended）｜节点 48｜战斗 14 场 / 81 回合｜终局 2 转｜蛊虫 21 只
data_digest 前 16 位 = 36138703634c92f4
```

> 若指纹不同，说明 `world-model/data/` 已被改动；请先重跑
> `python world-model/tools/build_world_model.py` 再对照。
