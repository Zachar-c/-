# 复核清单（REVIEW_CHECKLIST）

> 10 条验收标准逐条勾选。每条给出 **证据位置**（命令 + 产物文件路径 + 实际结果摘要）。
> 所有命令均在工作区根目录执行，环境：Windows + Git Bash，Python 3.13.12，无 Godot，无第三方包。

---

## ☑ 1. 统一 schema 与逐字段说明表

- **状态**：通过
- **命令**：

  ```bash
  python world-model/tools/validate_world_model.py
  ```

- **产物**：
  - `world-model/schema/world-model.schema.json`（`$defs` 定义 10 类实体 + 11 个嵌套结构）
  - `world-model/schema/mini_schema.py`（标准库迷你校验器）
  - `world-model/schema/README.md`（逐字段说明表）
  - `world-model/reports/validation-report.md` §1

- **实际结果**：

  ```
  [PASS] 1. Schema 校验（schema/world-model.schema.json，自写迷你校验器）  检查 50843 条
  ```

  逐文件断言数：`realms.json` 1218 / `paths.json` 1680 / `gu.json` 41115 / `economy.json` 1517 /
  `regions.json` 2508 / `events.json` 661 / `loot.json` 1522 / `balance.json` 52 / `manifest.json` 134。

- **覆盖证明**：测试 `schema_field_tables_documented` 断言 `schema/README.md` 覆盖
  schema 里全部 10 个 `entity_type`，且含 `source_class` 与 `tunable` 的说明。

---

## ☑ 2. 机读数据独立可解析且格式统一

- **状态**：通过
- **命令**：

  ```bash
  python -c "import sys;sys.path.insert(0,'world-model');from engine.model import WorldModel;w=WorldModel();print(w.summary())"
  ```

- **产物**：`world-model/data/` 下 10 个文件，每个都是同一 envelope
  （`world_model_version` / `schema_id` / `schema_version` / `entity_type` / `generated_at` /
  `generator` / `source_refs` / `count` / `entities`）。

- **实际结果**：

  ```
  counts = balance=1, economy=1, event=12, faction=6, gu=802, loot=1, manifest=1,
           path=20, realm=36, region=7
  ```

  加载器对缺文件抛 `DataMissingError`、对坏 JSON / `entity_type` 不符 / `count` 不符 /
  重复 id / schema 违规抛 `DataFormatError`（4 条分支各有独立测试用例）。

---

## ☑ 3. 来源追溯字段与登记册一致

- **状态**：通过
- **命令**：

  ```bash
  python world-model/tests/run_tests.py traceability
  ```

- **产物**：每个实体的 `source_class` / `source_ids` / `canon_review_status` / `adaptation_note` / `tunable`；
  `world-model/docs/原著要素映射表.md`（966 行映射 + 覆盖统计表）。

- **实际结果**：

  ```
  PASS  traceability_fields_are_wellformed
  用例：1｜通过：1｜失败：0
  ```

  该用例遍历全部 10 类实体的**每一条**，断言：
  `source_class ∈ {canon, adaptation, original_game_content}`、
  `canon_review_status ∈ {draft, needs_source, approved, rejected}`、
  `tunable` 为 bool、每个 `source_ids` 元素都以 `CAN-` / `ADP-` / `GAME-` 开头、
  且 `canon` 类蛊虫 > 200 条。

  映射表覆盖统计：**合计 966 条**（canon 320 / adaptation 31 / original_game_content 615 /
  无编号的合理扩展 11）。

---

## ☑ 4. 种子化随机：同种子逐位可复现

- **状态**：通过
- **命令**：

  ```bash
  python world-model/runner/cli.py --seed 101 --auto --replay
  python world-model/runner/cli.py --seed 101 --auto --replay
  ```

- **产物**：`world-model/runs/run-101-*.jsonl`（3 个文件）、`world-model/reports/validation-report.md` §5

- **实际结果**（两次连跑的输出）：

  ```
  重放种子 101：content_sha256 = 584e141d68f085e7d1e49019f86d44c67ba3930b662d12dc1ed29b913a8c689d
  历史台账 run-101-20260917T022256Z.jsonl：content_sha256 = 584e141d68f085e7d1e49019f86d44c67ba3930b662d12dc1ed29b913a8c689d
  比对结果：一致（同种子逐字节可复现）｜content_sha256 = 584e141d68f085e7d1e49019f86d44c67ba3930b662d12dc1ed29b913a8c689d
  ```
  ```
  历史台账 run-101-20260917T022308Z.jsonl：content_sha256 = 584e141d68f085e7d1e49019f86d44c67ba3930b662d12dc1ed29b913a8c689d
  比对结果：一致（同种子逐字节可复现）｜content_sha256 = 584e141d68f085e7d1e49019f86d44c67ba3930b662d12dc1ed29b913a8c689d
  ```

  台账逐字段比对（`engine.persistence.compare_ledgers`）：

  ```
  {'identical': True, 'left_sha256': '584e141d…689d', 'right_sha256': '584e141d…689d',
   'left_entries': 281, 'right_entries': 281, 'first_diff_line': None,
   'left_header_ok': True, 'right_header_ok': True}
  ```

  LCG 位级对齐（校验报告 §5，12 条断言全 PASS）：`SeededRng(101)` 前 5 次 `%100` = `[71, 18, 66, 7, 82]`；
  `seed 0` 与 `seed 2147483647` 归一为同一状态；负种子取绝对值；
  `tick` 语义为「流位置」而非仿射混入（相邻抽取差值集合 > 1）；层号进 salt（L1 与 L2 同序号不同值）。

- **额外**：测试 `ledger_is_independent_of_hall_progress` 断言「起始大厅进度不同（空 vs 已玩 7 局）
  的两局同种子台账逐字节一致」——这是本项目发现并修掉的一个真实确定性缺陷。

---

## ☑ 5. 数值集中可调（单点调参）

- **状态**：通过
- **命令**：

  ```bash
  python world-model/tools/simulate_balance.py --runs 60 --hp-mult 1.5 2.0
  ```

- **产物**：`world-model/data/balance.json`、`world-model/reports/balance-simulation.md` §二

- **实际结果**：`balance.json` 是唯一参数表（`growth` / `run` / `economy` / `loot` /
  `combat_gate` / `faction` / `formulas`）。引擎通过 `WorldModel.b(...)` 读取，**无硬编码调参值**。
  灵敏度扫描证明只需改一个字段即可大幅改变难度：

  | `run.difficulty.enemy_hp_mult` | 局数 | 通关率 | 平均行动回合 |
  | --- | --- | --- | --- |
  | 1.0（默认） | 200 | 67.0% | 67.5 |
  | 1.5 | 50 | 70.0% | 118.2 |
  | 2.0 | 50 | 42.0% | 145.9 |

  覆盖只存在于内存（`WorldModel.set_override`），**不写回任何文件**。
  同步：`data/balance.json` 的 `formulas` 字段把 9 条关键公式写成书面记录，便于与
  `engine/rules.py` 逐条对照（校验器与测试都断言双方一致，如 `essence_max(1,'bing') == 20`）。

---

## ☑ 6. 完整一局可跑到结算，并落盘台账与存档

- **状态**：通过
- **命令**：

  ```bash
  python world-model/runner/cli.py --seed 101 --auto
  ```

- **产物**：
  - `world-model/runs/run-101-20260917T022256Z.jsonl`（281 条事件）
  - `world-model/saves/hall.json`（大厅永久存档）
  - 局结束时按规范**删除**进行中存档 `run.json`（`AGENTS.md`：Run 结束时删除进行中 Run 存档）

- **实际结果**：

  ```
  开局：丙等一转散修（固定身份），携小光蛊一只。种子 101。
  世界模型 v1.0.0｜数据指纹 36138703634c92f4…
  ================ 结算 ================
  结局：通关（登临蛊仙之窗）
  到达：第 5 层 第 10 行
  节点 48 个｜战斗 14 场／81 回合｜最后节点 final_boss_stand（combat）
  终局：2 转 bing 等｜蛊虫 21 只｜气血 64｜寿元 60｜魂 1｜元石 27
  台账：…\world-model\runs\run-101-20260917T022256Z.jsonl
  台账内容哈希 content_sha256 = 584e141d68f085e7d1e49019f86d44c67ba3930b662d12dc1ed29b913a8c689d
  本局新增图鉴 14 只蛊 / 配方 1 条
  大厅累计 17 只蛊 / 配方 1 条（跨局只保留知识，零永久数值成长）
  退出码 = 0
  ```

- **进行中存档同样验证**（交互式 `save` + `quit`）：

  ```bash
  printf '1\n2\n1\nsave\nquit\n' | python world-model/runner/cli.py --seed 555
  ```
  ```
  已存档（台账 run-555-20260917T022302Z-1.jsonl）。
  ```

  ```bash
  python world-model/runner/cli.py --status
  ```
  ```
  进行中存档：种子 555｜active｜第 1 层｜已访 1 节点｜战斗 1 场
    气血 78/80｜寿元 60｜魂 1｜元石 12｜1 转
  大厅：累计 2 局｜图鉴 17 只蛊｜已解锁配方 1 条｜结局分布 {'death': 1, 'ascended': 1}
  ```

- **测试**：`full_run_reaches_settlement`、`layer_traversal_visits_one_node_per_row`、
  `boss_row_uses_layer_boss_pool`、`battle_bounds_and_no_stalemate_in_the_wild` 全 PASS。

---

## ☑ 7. 校验脚本：退出码 0 + 报告写明实际检查/失败条数

- **状态**：通过
- **命令**：

  ```bash
  python world-model/tools/validate_world_model.py; echo "EXIT=$?"
  ```

- **产物**：`world-model/reports/validation-report.md`

- **实际结果**：

  ```
  [PASS] 1. Schema 校验（schema/world-model.schema.json，自写迷你校验器）  检查 50843 条
  [PASS] 2. 引用完整性（gu ↔ recipes ↔ materials ↔ shops ↔ schools ↔ enemies ↔ nodes ↔ loot）  检查 5667 条
  [PASS] 3. 数值越界（rank/value/cost/hp/权重/概率范围、权重守恒与归一）  检查 7934 条
  [PASS] 4. 死循环 / 环检测与升炼链深度  检查 100 条
  [PASS] 5. 确定性自检（LCG 位级一致、tick 流语义、层号入盐）  检查 12 条
  检查总数 64556，失败 0
  EXIT=0
  ```

  报告含实体计数表、逐节「实际检查条数 / 失败条数」、失败明细（`<details>`）与备注观察。
  关键图论事实：**升炼图 88 节点 / 97 条有向边 / 环 0 个 / 最长链 5 步**；
  377 条同名升阶配方按「同定义 +1 转」解读（不是环）；1 条纯材料炼制。

---

## ☑ 8. 测试脚本：退出码 0 + 通过/失败用例数

- **状态**：通过
- **命令**：

  ```bash
  python world-model/tests/run_tests.py; echo "EXIT=$?"
  ```

- **产物**：`world-model/tests/run_tests.py`（38 个用例）

- **实际结果**：

  ```
  用例：38｜通过：38｜失败：0
  EXIT=0
  ```

  覆盖要求逐条对应：

  | 要求 | 用例 |
  | --- | --- |
  | schema / 加载 | `schema_files_present`、`schema_documents_all_pass`、`world_model_loads_and_exposes_accessors`、`schema_field_tables_documented` |
  | 种子可复现性（同种子两次台账一致） | `lcg_matches_reference_implementation`、`same_seed_produces_identical_ledger`、`ledger_is_independent_of_hall_progress`、`different_seeds_diverge`、`ledger_file_roundtrips_and_replays`、`tick_is_stream_position_not_affine_mix`、`layer_goes_into_salt` |
  | 完整一局能跑到结算 | `full_run_reaches_settlement`、`layer_traversal_visits_one_node_per_row`、`boss_row_uses_layer_boss_pool` |
  | 异常路径：资源枯竭 | `exception_resource_exhausted_fires` |
  | 异常路径：蛊虫反噬 | `exception_gu_backlash_fires` |
  | 异常路径：数值溢出 | `exception_numeric_overflow_fires` |
  | 异常路径：数据文件缺失 | `exception_data_missing_fires` |
  | 异常路径：数据格式错误 | `exception_data_format_fires`（4 条分支） |
  | 异常路径：存档损坏 | `exception_save_corrupt_fires`（4 条分支）、`save_recovery_quarantines_corrupt_file` |
  | Meta 继承生效 | `meta_inheritance_keeps_knowledge_only`、`missing_hall_file_yields_empty_meta` |
  | 其它 | `three_death_axes_are_wired`、`cultivation_hard_gate_blocks_bing_rank_three`、`essence_formulas_match_the_locked_spec`、`feeding_ledger_pays_then_backlashes`、`loot_weights_are_normalised_and_pity_fires`、`refinement_graph_is_acyclic_and_lifts_rank`、`action_points_follow_soul_ladder`、`enemy_profiles_scale_by_layer`、`realm_table_matches_canon_essence_grades`、`gu_table_faithfully_flags_role_defaults`、`traceability_fields_are_wellformed`、`manifest_hashes_match_files`、`cli_auto_run_writes_ledger_and_save`、`invalid_input_does_not_crash` |

---

## ☑ 9. 平衡模拟器：胜率 / 平均局时长 / 构筑分布 / 卡点

- **状态**：通过
- **命令**：

  ```bash
  python world-model/tools/simulate_balance.py --runs 200
  ```

- **产物**：`world-model/reports/balance-simulation.md`

- **实际结果**：

  ```
  基线：200 局，种子 900000…
    通关率 67.0%｜死亡 33.0%｜异常 0｜平均节点 39.6
  报告：…\world-model\reports\balance-simulation.md
  EXIT=0
  ```

  | 指标 | 值 |
  | --- | --- |
  | 胜率 | 67.0%（通关 134 / 死亡 66 / 其它 0） |
  | 平均访问节点 | 39.6（2–54） |
  | 平均战斗场次 | 12.8（0–23） |
  | 平均玩家行动回合 | 67.5（0–159） |
  | 平均敌方回合 | 25.0 |
  | 构筑分布 | 流派 100% `light`；主蛊 Top5 = `moonlight_gu`×86、`white_jade_gu`×46、`small_light_gu`×19、`force_atk_4_02_gu`×16、`moon_glow_gu`×15；不同主蛊 14 种 |
  | 卡点位置 | 第 1 层 21% / 第 2 层 20% / 第 3 层 18% / 第 4 层 21% / 第 5 层 20%，**92% 死在 `event` 节点、92% 死于魂轴** |
  | 异常终止 | **0** |

- **明确失衡项结论**（报告 §三，共 6 条）：

  1. 通关率 67.0% 处于可接受区间（已缓解）
  2. **死亡轴单一化**：92% 死于「魂魄崩散而亡」，集中在 `event` 节点（61/66）— 待用户确认
  3. **卡点均匀分布**：死亡在 5 层几乎等量 — 待用户确认
  4. **成长不足**：21.5% 的通关局停留在 1 转 — 待用户确认
  5. **持有蛊虫数量偏高**：均值 19.2 只（原著「四五只」，`CAN-GU-CARE-001`）— 待用户确认
  6. **难度旋钮有效**：`enemy_hp_mult` 1.0→2.0 可把通关率压到 42.0% — 已缓解

---

## ☑ 10. 干净环境启动：不依赖 Godot、不依赖第三方包

- **状态**：通过
- **命令**：

  ```bash
  cd /tmp && rm -rf wm-cleanenv && mkdir wm-cleanenv && cp -r "<repo>/world-model" wm-cleanenv/
  cd wm-cleanenv && rm -rf world-model/saves world-model/runs world-model/reports
  find . -name "__pycache__" -type d -exec rm -rf {} +
  python -I -c "<导入审计>"          # -I = 隔离模式，忽略 PYTHONPATH 与 user site
  python -I world-model/tools/validate_world_model.py
  python -I world-model/tests/run_tests.py
  python -I world-model/runner/cli.py --seed 101 --auto
  python -I world-model/runner/cli.py --seed 101 --auto --replay
  python -I world-model/runner/cli.py --status
  command -v godot || echo "godot: NOT FOUND"
  ```

- **产物**：临时目录结构与本仓库一致

- **实际结果**：

  ```
  cwd=/tmp/wm-cleanenv
  === third-party import audit (isolated interpreter) ===
  site-packages on path: []
  non-stdlib top-level imports: []
  OK: 零第三方依赖

  === A7-1 validate ===   检查总数 64556，失败 0                        EXIT=0
  === A7-2 tests ===      用例：38｜通过：38｜失败：0                    EXIT=0
  === A7-3 cli auto ===   结局 通关｜节点 48｜战斗 14 场／81 回合        EXIT=0
                          content_sha256 = 584e141d68f085e7d1e49019f86d44c67ba3930b662d12dc1ed29b913a8c689d
  === A7-4 replay #1 ===  比对结果：一致（同种子逐字节可复现）           EXIT=0
  === A7-4 replay #2 ===  比对结果：一致（同种子逐字节可复现）           EXIT=0
  === A7-5 godot ===      godot: NOT FOUND (as expected)
                          godot on PATH: None / godot4: None / Godot: None
  === A7-6 status ===     世界模型摘要 + 实体计数正常                    EXIT=0
  ```

  **关键交叉验证**：干净环境（`/tmp/wm-cleanenv`）跑出的 `content_sha256`
  与本仓库跑出的**完全相同**（`584e141d…689d`），证明整条链路是**数据驱动**的，
  与工作目录、安装位置、外部环境无关。

- **依赖声明**：`manifest.json → third_party_dependencies == []`，
  且测试 `manifest_hashes_match_files` 断言该数组为空、每个文件的 sha256 与实际字节一致。

---

## 复核结论

| # | 验收项 | 结果 |
| --- | --- | --- |
| 1 | 统一 schema + 逐字段说明表 | ✅ 50843 条断言 |
| 2 | 机读数据独立可解析且格式统一 | ✅ 10 文件 / 880 实体 |
| 3 | 来源追溯字段与登记册一致 | ✅ 966 行映射，逐条标注 |
| 4 | 种子化随机逐位可复现 | ✅ 3 份台账同哈希 |
| 5 | 数值集中可调 | ✅ 单点覆盖 1.0→2.0 见效 |
| 6 | 完整一局 + 落盘 | ✅ 通关，281 条事件 |
| 7 | 校验退出码 0 + 条数 | ✅ 64556 / 0 |
| 8 | 测试退出码 0 + 用例数 | ✅ 38 / 38 |
| 9 | 平衡报告 | ✅ 6 条结论 |
| 10 | 干净环境零依赖启动 | ✅ site-packages 为空仍全绿 |

**未勾选 / 未验证项**：与 Godot 运行时的端到端对拍（本机无引擎，见 `RISK_REGISTER.md` RISK-04）；
遗物钩子未逐条消费；多敌遭遇 tier 结算沿用上游缺陷。以上均在 `HANDOFF.md` §二如实列出。

---

## 复核修正（2026-09-17 独立核验后）

> 本节由三路独立只读核验（原著映射核验 / 数据一致性审计 / 世界模型反方审稿）触发，
> 修正上文两条验收结论。明细见 `reports/independent-verification.md`。

| 验收项 | 原结论 | 修正后结论 | 依据 |
| --- | --- | --- | --- |
| **2. 来源追溯字段与登记册一致** | 通过 | **部分通过** | 字段机制成立（`source_ids` 悬空 0/4551）；但行号层严格命中仅 31/41（75.6%），无原文校验锚点，派生层有 10 条 `canon` 缺 `source_ids`、261 条程序化内容被冠以 `canon`。**本包映射表未声称行号精确**，降级针对的是上游登记册精度。 |
| **验收 A4 蛊虫消耗闭环** | 通过（附缺口） | **部分通过** | 「获取 / 晋升」完整；「喂养 / 反噬」部分；**「炼化 / 认主」缺口**——上游实现中新蛊直接置 `refined`，无独立炼化流程；「知识 / 操控 → 杀招」断裂（杀招为写死的 26 条）。本包已如实转述，未额外承诺。 |

### 复核补记

- 包内校验器**未发现悬空引用（0 条）**，此结论经数据一致性审计独立复算确认：21 条引用链、约 2,600 次引用全部命中。
- 审计提出的「权重和 101」经复核为**相对权重非概率向量**，实现上无害；校验器容差 ±1 已显式写明。
- 审计提出的「377 条 advance 自环」经复核为**同名蛊升转**，包内已显式说明该解读。
- 新增校验器待补项：`value` 与价值锚 `gu_value_by_rank` 的一致性检查（当前只查 `value > 0` 与量级）。

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
