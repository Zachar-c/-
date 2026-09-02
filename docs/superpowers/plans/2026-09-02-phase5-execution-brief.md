# 阶段五执行交接单：炼蛊与蛊材（T5.1 + T5.2）

> 日期：2026-09-02
> 上级计划：[2026-09-01-gu-system-economy-combat-implementation.md](2026-09-01-gu-system-economy-combat-implementation.md)
> 权威规格：`docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md`——实现前**必须阅读** §5.1-§5.5（蛊方术语、标签候选池、成功失败与步骤、材料身份与替代、经济审计）、§6.1-§6.3（统一蛊材、向下折算、有损升炼）。本文是交接摘要，规格原文是唯一裁定依据。
> 仓库约束：遵守 `AGENTS.md` 全部条款。

---

## 0. 当前基线（开工前先核对）

- 分支 `master` @ `100856c`，工作树干净。开工前跑 `git status --short --branch`。
- 阶段一至四已合入。阶段四审查结论：**通过**（1 个 P2、2 个 P3，见任务 0）。全量 `-Suite all` 退出码 0、零失败（unit 1025/1024 + 1 pre-existing risky；integration 13/12 + 1 pre-existing pending）。
- 行数门禁：`resolver.gd` 2452 ≤ 2457、`battle_resolver.gd` 1514 ≤ 1516。
- **现有材料摸底**（T5.1 的改造对象）：
  - 材料数据在 `data/loot_tables.json` 的 `"materials"` 段（6 条：beast_blood / beast_bone / venom_sac 等，含 `name_zh / value / value_tier / use`）；`ContentCatalog` 把它索引为 `material_by_id` 并产出 `material_ids`（`content_catalog.gd:66-77`，`feed_points` 手工在列）。
  - `RunState.materials` 是扁平计数 Dictionary（键为材料 id，另有 `feed_points`）。
  - 消费点：`resolver.gd` 的 `_use_material` / `_sell_material`（第 101-102 行注册）、`refinement_recipes` 的材料计数（`state.materials` 直查，`_has_all_materials`）、`shops.json` 的 `material_purchase`（2 条）。
- **现有蛊方摸底**（T5.2 的改造对象）：`data/refinement_recipes.json` 共 24 条，`kind: combine / fixed / advance`，形状为 `input_gu_ids -> output_gu_id`；**部分条目仍带 `success_roll_max: 70` 与 `failure: destroy_inputs`（旧随机炼化路径）**——规格 §5.3 已废止"已知蛊方随机失败"，本批数据不得新增此类条目，存量条目的退役在 T10.1-⑧，本批不动其行为。
- 可复用模块（薄委托，禁止第二份实现）：`GuBalance`（`rank_multiplier` 等全部中央数值）、`GuInstance`（实例唯一形状拥有者——蛊方产物是**实例级**操作）、`CultivatorRules`。drift 门禁递归扫描全 `scripts/`（含 `battle2/`），新模块写公式必被门禁抓。

---

## 任务 0：阶段四收尾补丁（2 个小提交，先于 T5.1）

### P0.1 battle2 start_turn 透支与默认中止（提交 A，必做）

- **问题（P2）**：`battle2/turn_engine.gd` 的 `start_turn` 对 `ongoing` 条目**无条件自动续投入**（`_spend` 不检查余量），`thoughts_left` 可以被扣成负数；且没有任何"玩家声明停止投入"的路径。规格 §12.5 明确："跨回合动作下一回合**必须继续投入相应念头**；**不继续投入时默认中止**，已发生的客观结果保留，未完成的抽象进度清除"。当前实现语义是"永远自动续"，与规格相反。
- **修法**：`start_turn` 增加停止投入的裁定入口——建议签名 `start_turn(turn, capacity, continue_ids := null)`：`continue_ids` 为本回合选择继续的 ongoing id 集合（null 兼容旧调用=全部继续）；未被继续的条目移出 `ongoing`（默认中止，不返还已发生结果）；被继续但 `thoughts_left < 需求` 的条目同样中止且**不得把余量扣成负数**（先判后扣）。同步补测试：不足支付 → 条目中止、余量不为负；主动不续 → 默认中止。
- 验收：`tools/test.ps1 -Test "tests/unit/test_battle2_turn_ledger.gd"` + `-Suite all`。

### P0.2 EOF 换行守卫 + battle2 常量去重（提交 B，必做）

1. **EOF 问题第三次复发**：本批新建的 `battle2/turn_engine.gd`、`action_resolver.gd`、`body_rules.gd` 三个文件全部缺 EOF 换行（阶段三修过一次、纪律里写了、还是漏）。补换行之后，**加一条常驻守卫**：新增 `tests/unit/test_domain_hygiene.gd`，递归扫描 `res://scripts/` 下全部 `.gd` 文件，断言文件以换行结尾（人肉纪律已证伪，改为测试钉死）。
2. **常量重复**：`BASIC_ACTIONS` 在 `turn_engine.gd` 与 `action_resolver.gd` 各定义一份；`DISTANCE_TOUCH` 在 `action_resolver.gd` 与 `body_rules.gd` 各一份（和阶段三 `SERVICE_USE_FLAG_PREFIX` 同款问题）。收敛为单一 owner（建议 `battle2` 内一处共享常量，其余引用），防漂移。
- 验收：`tools/test.ps1 -Test "tests/unit/test_domain_hygiene.gd"` + 全量绿。

### 挂账（延续记录，不在本批处理）

- `CultivatorRules.wisdom_bonus` 统计全目录而非持有实例（智道内容批次落地时改）。
- `GuInstance.SAVE_KEYS` 的 `uses_left` 无默认值（有限次数生命周期内容落地时补）。

---

## T5.1 蛊材统一表与升炼（提交 C）

- **固定接口**：
  1. **材料表单一来源**：在现有 `loot_tables.json` 的 `materials` 段**扩展**规格 §6.1 声明字段（推荐路径，改动面最小；如选新建 `materials.json` 并重指 `ContentCatalog` 索引亦可，但**不得两处并存真值**）：`rank`（1-9 转整数）、`dao_tags`（开放集合数组）、`diet_tags`（数组）、`is_common`（bool）、`is_exclusive`（bool）、`divisible`（bool）、`public_liquidity`（(0,1] 浮点）、`reference_value`（正整数；与现有 `value` 的关系在报告中说明裁定）。现有 6 条材料逐条补齐；食料（含 `feed_points` 语义）并入同一体系。
  2. **Schema**：`ContentCatalog.validate` 校验新字段（rank 1..9、liquidity 范围、bool 类型；非 override 条目**禁止手写跨转数值**——延续 T2.2 的档位纪律）。存量条目缺字段的默认裁定写进报告。
  3. **规则模块**：新增 `scripts/domain/material_rules.gd`（`class_name MaterialRules`，纯静态、确定性）：
     - `downscale_feed(material, need_rank, cat)`（§6.2 高转向下折算喂养当量）：可分割材料**精确扣取**（按转数价值比逐转折算，余量保留）；不可分割材料（完整兽骨、魂核类）超出本次需求的价值**浪费且不退回库存**；**点名专属食料不可凭价值或转数替代**（必须同名匹配）；
     - `refine_up(input_value, from_rank, to_rank, cat)`（§6.3 有损升炼）：`output = input × material_refine_efficiency`（0.5）**逐转结算**，跨多转逐级乘；相邻转价值倍率 2.0 → 等效数量比 4:1；`to_rank < from_rank` 或跨级 > 1 时逐级循环，不提供跳级无损。
- **先红后绿**：新增 `tests/unit/test_material_rules.gd`——**挂接验收 #9**：可分割高转材料向下喂养精确扣取、余量保留；不可分割余量浪费且不退回；点名专属食料拒绝价值替代；`refine_up` 逐级锚点（如 1 转 10 份 ×0.5 → 2 转当量 5 份 ×0.5 → 3 转 2.5 份；数量比 4:1）；折算读 `balance.json`（改 `rank_step_ratio`/`material_refine_efficiency` 投影随动，延续 T2.1 的 config-driven 断言风格）。
- **最小实现**：纯规则 + 数据字段 + Schema；**不切换任何运行时行为**（`use_material`/喂养/交易仍走旧路径，行为切换在 T6.1 与阶段九）。
- 验收：`tools/test.ps1 -Test "tests/unit/test_material_rules.gd"` + `-Test "tests/unit/test_content_catalog.gd"` + `-Test "tests/unit/test_content_tier_schema.gd"` + `-Suite all`。
- 退出条件：#9 绿；材料表单一来源成立（全仓无第二份材料价值真值）；resolver 行数不增。

## T5.2 蛊方统一与替代身份（提交 D）

- **固定接口**：
  1. **Schema 扩展**（`refinement_recipes.json`，§5.1-§5.4）：新增可选声明段（存量条目不强制迁移，逐步补）：
     - `identity_requirements`：点名蛊（definition/instance 级）、点名蛊材、道标签、转数、媒介（同转媒介/元石/特定蛊/炼道手段）；
     - `allow_substitute`：明示替代关系（如"同道同转材料""任意媒介"）及其代价变化/成功条件变化/产物变化；
     - `stages`：每阶段 `thought`（念头）/`essence`（真元）/`duration`（跨回合轮数）/`interruptible`（打断点）/`failure_condition`——跨回合炼制每回合续占阶段声明念头（与 battle2 `ongoing` 语义对齐，接 T9.2 命令面）；
     - `candidate_pool`：标签蛊方的人工候选池（2-3 选一，条目是**人工定义的现有 gu id**，禁止程序化生成）；
     - 产物语义：`product_rule: "main_gu_transformation"`（主辅蛊原形消失、单产物实例）；`aux_core_warning: true`（核心蛊作辅蛊必须强警告 + 二次确认——数据标记，确认 UI 挂阶段九）。
  2. **Schema 守卫**：候选池条目必须存在于 `gu.json`；`product_rule` 产物必须在目录中；非盲炼/禁忌条目**不得声明随机失败字段**（新数据禁用 `success_roll_max`；存量豁免条目须带 `override_reason`，报告中列出存量清单）。
  3. **规则模块**：新增 `scripts/domain/recipe_rules.gd`（`class_name RecipeRules`，纯静态、**零随机**）：
     - `known_fixed_success(recipe, inputs, state)`：已解锁普通蛊方在条件完整、安全、未被打断时**确定成功**，不 roll、不吞料；
     - `resolve_candidates(recipe, inputs, catalog)`：标签蛊方只从 `candidate_pool` 确定性筛选出候选产物（2-3 选一的排序规则要确定性——按 id 或声明序，禁止随机洗牌）；
     - `check_identity(recipe, offered_inputs, materials, catalog)`（§5.4）：点名要求必须实际满足；**等值蛊材与元石不可替代**；仅 `allow_substitute` 明示的关系可换料，且替代的代价/条件/产物变化按声明返回。
- **先红后绿**：新增 `tests/unit/test_recipe_rules.gd`——**挂接验收 #7**（已知蛊方条件齐备确定成功且不吞料；标签蛊方只出人工候选池、池外产物拒绝）、**#8**（等值材料/元石替代点名要求被拒；`allow_substitute` 声明的关系放行且代价变化生效）；测试内断言 `recipe_rules.gd` 源码零随机 token（沿用 battle2 的源码审计风格）。
- **最小实现**：Schema + 规则模块 + 数据示例（至少 1 条带 `identity_requirements`、1 条带 `candidate_pool`、1 条带 `stages` 的完整样例供测试与阶段九对接）；`resolver.gd` 的 refine 命令**不动**（薄委托挂 T9.2，旧随机路径 T10.1-⑧ 删）。
- 验收：`tools/test.ps1 -Test "tests/unit/test_recipe_rules.gd"` + `-Suite all`。
- 退出条件：#7/#8 绿；`recipe_rules.gd` 零随机（grep 审计入报告）；resolver 行数不增。

---

## 全局纪律（每一批）

1. 每任务独立提交：`feat(spec-v4): T5.x ...` / `test(spec-v4): T5.x 先红测试`；补丁提交 `fix(spec-v4): P0.x ...`。
2. 先红后绿：红证据写进提交说明。
3. resolver 门禁：`resolver.gd` ≤ 2457（当前 2452）、`battle_resolver.gd` ≤ 1516（当前 1514）；T5.x 不触碰这两个文件。
4. 禁区目录只读；标识符 ASCII、玩家文案 UTF-8；调参进 `balance.json` 过 Schema。
5. 测试基线只增不回退；跨阶段缺陷记录报告，不夹带。
6. 确定性红线：material_rules / recipe_rules 零随机；折算与候选筛选全部确定性。
7. 新文件一律 EOF 换行（P0.2 之后有常驻守卫测试兜底）。

## 完成报告要求（供审查）

逐项列出：每个提交 hash 与文件清单；每条验收命令与结果；材料表路径裁定（扩展现有表 or 新建 materials.json）与理由；存量 6 条材料的字段补齐对照；存量 24 条蛊方中带随机失败字段的清单与豁免标注；`recipe_rules.gd` 零随机 grep 输出；样例蛊方数据形状说明（阶段九对接要用）；`-Suite all` 最终数字；未验证风险与遗留问题。
