# 《蛊真人》肉鸽世界模型 + 可运行底座

`world-model/` 是一个**独立、只读上游、零第三方依赖**的子项目：把《蛊真人》的世界观落成一套
可机读、数值化、可运行的世界模型，并用一个**不依赖 Godot** 的轻量运行器证明这套模型能跑通完整一局肉鸽。

- 零第三方依赖：只用 Python 标准库（本机无 `jsonschema`、无 `pytest`，校验器与测试都是自己写的）。
- 不依赖 Godot：整条链路是纯 Python，Godot 只作为**只读数据来源**。
- 上游只读：`world-model/` 从不写 `../data/`、`../scripts/`、`../scenes/`、`../docs/`、`../project.godot`
  等任何既有文件。

---

## 一、目录结构

```
world-model/
├── VERSION                        语义化版本，唯一来源（1.0.0）
├── README.md                      本文件
├── HANDOFF.md                     交接清单
├── RISK_REGISTER.md               风险登记册
├── REVIEW_CHECKLIST.md            10 条验收标准逐条勾选（含证据位置）
├── CHANGELOG.md                   变更记录
├── schema/
│   ├── world-model.schema.json    统一 JSON Schema（draft-07 风格，$defs 定义 10 类实体）
│   ├── mini_schema.py             只用标准库的迷你校验器（$ref/allOf/anyOf/oneOf/if-then-else…）
│   └── README.md                  **逐字段说明表**（字段名/类型/取值范围/必填/含义/可调参）
├── data/                          机读世界模型（10 个文件，全部由构建脚本派生）
│   ├── realms.json                境界：1–9 转 × 4 小境界（36 条）
│   ├── paths.json                 道途/流派（20 条）
│   ├── gu.json                    蛊虫（802 条，含升炼配方边与商店/掉落交叉引用）
│   ├── economy.json               资源与经济（8 资源 / 37 商店报价 / 5 层预算 / 黑市汇率）
│   ├── factions.json              势力与关系（4 原创势力 + 兽潮压力源 + 全局恶名轴）
│   ├── regions.json               地域与关卡（宏观区域 + 5 层 + 升仙之窗；含 32 敌人 / 37 节点 / 5 NPC）
│   ├── events.json                事件卡（12 条，含延迟代价与诅咒绑定）
│   ├── loot.json                  遗物/战利品（80 蛊材 + 2 遗物 + 保底 + 稀有度权重）
│   ├── balance.json               **集中参数表（单点调参入口）**
│   └── manifest.json              数据清单 + 每文件 sha256 + 版本 + 生成时间
├── engine/                        纯 Python 引擎（只依赖标准库）
│   ├── errors.py                  异常类型（DataMissingError/DataFormatError/SaveCorruptError/
│   │                              ResourceExhausted/NumericOverflow/GuBacklash/…）
│   ├── rng.py                     确定性 Lehmer LCG + mixed_seed + Stream（层号进 salt）
│   ├── model.py                   加载并校验世界模型，暴露只读访问器
│   ├── rules.py                   修炼/蛊虫/战斗/掉落/失败与继承规则（全部读 balance）
│   ├── run.py                     肉鸽运行结构（开局/层级推进/Boss/结算/Meta 继承）
│   └── persistence.py             存档（原子写+校验和）、台账、大厅存档、损坏恢复
├── runner/cli.py                  命令行运行器（交互 / --auto / --replay / --status）
├── tools/
│   ├── build_world_model.py       从只读上游 ../data/*.json 派生 data/*.json
│   ├── build_mapping_table.py     从 data/*.json 生成 docs/原著要素映射表.md
│   ├── validate_world_model.py    schema/引用/数值/环 四类校验 → reports/validation-report.md
│   └── simulate_balance.py        批量模拟 → reports/balance-simulation.md
├── tests/run_tests.py             断言式测试入口（38 个用例）
├── docs/
│   ├── 世界模型总纲.md            世界层级、境界、道途、时间线与地理势力
│   ├── 原著要素映射表.md          966 行映射（8 类实体全覆盖，标注 CAN-/ADP-/GAME-）
│   ├── 肉鸽运行结构.md            开局 → 层级 → 遭遇 → Boss → 结算 → 轮回
│   └── 数值与成长曲线.md          成长曲线、强度上限、掉落权重、经济通胀 + 构筑可行性
├── reports/                       校验报告与平衡报告（构建产物）
├── saves/                         存档（hall.json 大厅永久存档；run.json 进行中 Run）
└── runs/                          每局台账 run-<seed>-<timestamp>.jsonl
```

---

## 二、启动方式（精确命令）

> 工作目录无所谓，所有脚本都按自身路径解析 `world-model/`。
> **必须用 `python`（3.9+）**，实测环境为 Python 3.13.12。

```bash
# 0) 从只读上游重建数据（可选；data/ 已随仓库提交）
python world-model/tools/build_world_model.py

# 1) 校验世界模型（退出码 0 = 全部通过）
python world-model/tools/validate_world_model.py

# 2) 跑测试（退出码 0 = 全部通过）
python world-model/tests/run_tests.py

# 3) 自动打完一局并落盘台账与存档
python world-model/runner/cli.py --seed 101 --auto

# 4) 同种子重放并与历史台账比对（退出码 0 = 逐字节一致）
python world-model/runner/cli.py --seed 101 --auto --replay

# 5) 平衡模拟（默认 200 局；--hp-mult 做灵敏度扫描）
python world-model/tools/simulate_balance.py --runs 200
python world-model/tools/simulate_balance.py --runs 60 --hp-mult 1.5 2.0

# 6) 查看存档摘要
python world-model/runner/cli.py --status

# 7) 交互式打一局（stdin 逐行命令）
python world-model/runner/cli.py --seed 101
```

交互命令：`help` / `status` / `map` / `save` / `<数字>` / `next` / `skip` / `quit`。

---

## 三、依赖

| 项 | 要求 |
| --- | --- |
| Python | ≥ 3.9（实测 3.13.12） |
| 第三方包 | **零**（无 `jsonschema`、无 `pytest`、无 `networkx`；`manifest.json` 的 `third_party_dependencies` 恒为空数组并由测试断言） |
| Godot | **不需要**（本机未安装，整条链路不依赖引擎） |
| 网络 | 不需要（完全离线） |
| 操作系统 | Windows / PowerShell 实测；代码只用 `pathlib`，跨平台可用 |

---

## 四、参数调整指引

**所有数值都能在单点调整**（验收 A5）。改完之后：

```bash
python world-model/tools/build_world_model.py        # 只读上游变化时才需要
python world-model/tools/validate_world_model.py     # 确保权重守恒与引用完整
python world-model/tools/simulate_balance.py --runs 200
```

| 想改什么 | 改哪个文件的哪个字段 |
| --- | --- |
| 真元基数 / 资质系数 / 转数系数 | `data/balance.json` → `growth.essence_base`、`growth.aptitude_factor`、`growth.cultivation_factor` |
| 战斗真元上限 / 每回合恢复 | `growth.stage_base_battle`、`growth.regen_pct_battle` |
| 每回合行动点数 | `run.action_points_by_soul`（一个按 `min_soul` 降序的档位表） |
| 开局属性（气血/寿元/魂/元石/起始蛊） | `run.starter` |
| 突破成本与资质硬门槛 | `run.cultivate_stone_cost`、`growth.aptitude_hard_gate` |
| 洗髓换骨代价 | `growth.aptitude_reroll` |
| 整体难度（唯一旋钮） | `run.difficulty.enemy_hp_mult` / `run.difficulty.enemy_damage_mult`（默认 1.0 = 原型口径） |
| 每层行数 / 宽度 / 分类权重 / 锚点 | `data/regions.json` 对应 `layer_N` 实体的 `rows_min`/`rows_max`/`row_nodes_min`/`row_nodes_max`/`category_weights`/`anchors` |
| 每层元石预算 / 商店加价 / 货架档位 | `regions.json` 的 `stone_budget`/`shop_price_pct`/`shop_max_tier`（真源在 `pacing.json`，改后者需重跑构建） |
| Boss 池 | `regions.json` 的 `boss_pool`；或改上游 `../data/nodes.json` 后重跑构建 |
| 战斗产石 | `economy.battle_stone_rewards.base_by_tier` / `layer_step_pct` |
| 蛊价值锚与回购 | `economy.gu_value_by_rank` / `public_buyback_ratio` / `low_liquidity_ratio` / `demand_price_tiers` |
| 出蛊概率 / 蛊材数 / 稀有度权重 | `loot.gu_chance_pct_by_tier` / `material_count_by_tier` / `rarity_weights_by_layer` |
| 保底 | `loot.pity_threshold` / `loot.material_pity` |
| 黑市汇率 | `economy.black_market_exchange` |
| 恶名效果 | `faction.reputation_effects` / `faction.reputation_gains` |
| 死亡轴阈值 | `run.stats_hp_death_threshold` / `stats_lifespan_death_threshold` / `stats_soul_death_threshold` |
| 僵局回合上限 | `run.max_battle_rounds` / `run.stalemate_rule` |
| 封蛊上限 | `run.max_seal_turns` |
| 事件代价与收益 | `data/events.json` 各事件的 `health_cost` / `stone_gain` / `delayed_soul_cost` / `curse_id` |
| 节点选项集 | `data/regions.json` → `south_jiang.node_templates[].choices` |
| 敌人血量/意图/相位 | `data/regions.json` → `south_jiang.enemy_roster[].hp` / `intent` / `phases` |
| 蛊虫效果 | `data/gu.json` → 各蛊的 `effect`（注意 `effect_source: role_default` 的 742 只是角色兜底，不是独立效果） |
| 炼蛊配方 | `data/gu.json` → 各蛊的 `refine_as_output`（真源在 `../data/refinement_recipes.json`，改后者需重跑构建） |

> **注意**：`data/*.json` 是**派生文件**。想改 `gen` 类的机械派生值（如批量蛊、层预算、配方），
> 应该改**只读上游** `../data/*.json`，然后重跑 `build_world_model.py`。
> 想改 `balance.json` 里的**调参值**，直接改它即可（它在上游是 `../data/balance.json` 的投影，
> 但 `world-model/engine` 只读世界模型自有的那份）。

---

## 五、版本号规则

- 采用**语义化版本** `MAJOR.MINOR.PATCH`。
- **单一来源文件**：`world-model/VERSION`（只有一行）。
- 构建脚本读取该文件并写入：
  - 每个 `data/*.json` 的 `world_model_version` 字段；
  - `manifest.json` 的 `version` 字段。
- 运行器把 `wm.version` 与 `wm.data_digest`（所有数据文件的 sha256 聚合）写进台账 header，
  所以**任何数据改动都会改变台账指纹**，可被 `--replay` 检出。
- 版本升级约定：改世界规则（新增/删除实体、改 schema 形状）→ `MINOR`；
  只调参数 → `PATCH`；schema 不兼容变更 → `MAJOR`。
- 改版本号只需改 `VERSION` 并重跑 `build_world_model.py`，其余自动同步。

---

## 六、回滚方式

### 6.1 整体回滚（删除整个子项目）

`world-model/` 是一个**完全自包含**的新增目录：它没有修改任何既有文件，也没有被既有代码引用。

```bash
# 若已提交
git rm -r world-model
# 若还没提交，仅需删除工作区目录
rm -rf world-model
```

删除后仓库其余部分（Godot 项目、`data/`、`scripts/`、`docs/`）**行为完全不变**——
因为 `world-model/` 只有「读」这一个方向的依赖。

### 6.2 回滚某个参数

- `data/balance.json` 是普通 JSON，直接改回目标值即可，不需要重跑构建。
- 若参数的真源在只读上游（如 `pacing.json` 的层预算），改回 `../data/*.json` 后重跑
  `python world-model/tools/build_world_model.py`。
- 回滚后请重跑 `validate_world_model.py` 与 `simulate_balance.py`，
  并把 `reports/` 的两份报告一起提交，避免报告与数据漂移。
- **难度旋钮**的临时回滚不需要改文件：`simulate_balance.py --hp-mult` 只做内存覆盖
  （`WorldModel.set_override`），**从不写回任何文件**。

### 6.3 回滚运行产物

`saves/` 与 `runs/` 是**运行产物**，删掉即回到全新状态：

```bash
rm -rf world-model/saves world-model/runs     # 清空存档与台账
```

删除后大厅进度（图鉴/配方解锁）清零，重开一局即可。

### 6.4 只回滚某一层数据文件

十个数据文件互相独立但有一致性约束（引用完整性）。只回滚单个文件可能触发
`validate_world_model.py` 的引用失败；建议**一并回滚**，或只回滚 `balance.json`（它是叶子，无被引用）。

---

## 七、数据事实速查

| 项 | 值 |
| --- | --- |
| 蛊虫总数 | **802**（全部写入 `data/gu.json`） |
| 有独立效果的蛊 | 57（`effect_source: explicit`） |
| 只有组合效果的蛊 | 3（`effect_source: combat_effects`） |
| **`role_default` 兜底的蛊** | **742**（如实标注，不假装有独立效果） |
| 境界 | 36（1–9 转 × 4 小境界） |
| 道途/流派 | 20 |
| 敌人 | 32（杂兵 13 / 精英 12 / 层主 7） |
| 节点模板 | 37 |
| 商店报价 | 37 |
| 事件卡 | 12 |
| 蛊材 | 80（7 种核心 + 73 种派生） |
| 遗物 | 2 |
| NPC | 5 |
| 势力 | 6 |
| 炼蛊配方边 | 439 只蛊有产物配方；升炼图 88 节点 / 97 有向边 / **0 环** / 最长链 5 步 |
| 校验检查总条数 | **64,556**（0 失败） |
| 测试用例 | **38**（0 失败） |
| 平衡模拟 | 200 局基线 + 100 局灵敏度（0 异常终止） |

---

## 八、许可与来源

- 世界观与设定归纳来自本仓库的只读资料（`../data/*.json`、`../docs/lore/*.md`、
  `../肉鸽设计-原始数据/*.md`、`../PROJECT_WORLD_MODEL_AUDIT.md`）。
- **不复制原著正文段落**；单条引用摘录不超过 80 字，均为设定归纳与结构化改写。
- 版权与授权状态见 `RISK_REGISTER.md` 的 RISK-01。
