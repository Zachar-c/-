# 阶段七执行交接单：核心蛊与构筑倾斜（T7.1 + T7.2）

> 日期：2026-09-02
> 上级计划：[2026-09-01-gu-system-economy-combat-implementation.md](2026-09-01-gu-system-economy-combat-implementation.md)
> 权威规格：`docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md`——实现前**必须阅读** §1.1-§1.4（确认核心、核心权益、更换核心、构筑节奏）、§2.1（实例字段，`core_state` 占位已就位）。本文是交接摘要，规格原文是唯一裁定依据。
> 仓库约束：遵守 `AGENTS.md` 全部条款。

---

## 0. 当前基线（开工前先核对）

- 分支 `master` @ `1b7102b`，工作树干净。开工前跑 `git status --short --branch`。
- 阶段一至六已合入。阶段六审查结论：**通过**（1 个 P2、2 个 P3，见任务 0）。全量 `-Suite all` 退出码 0、零失败（unit 1069/1068 + 1 pre-existing risky；integration 13/12 + 1 pre-existing pending）。行数门禁：`resolver.gd` 2452、`battle_resolver.gd` 1514。
- **可直接复用**：`GuInstance` 的 `core_state`（占位 Dictionary，T7.1 起实装）、`modifications`（实例级改造及来源——更换核心移除专属改造的操作对象）；`RunState.settle_layer`（大层切换唯一入口）；`RecipeRules`（枢纽蛊"分支蛊方/专属异炼"标记要与蛊方数据对齐）；`CultivatorRules/GuBalance`（倾斜不得触碰基础数值的对照基准）。
- **数据摸底**：`data/school_pools.json` 存在（池结构，尚无核心倾斜键）；`data/nodes.json` 33 个节点、已有 `ascension_grants` 数据驱动授予模式——T7.2 的 `core_replacement_token` 授予键照此模式添加；`data/gu.json` 条目尚无"通用核心/传承枢纽"深度标记。
- **挂账延续**（写进完成报告即可，不在本批处理）：`CultivatorRules.wisdom_bonus` 统计全目录而非持有实例；`GuInstance.SAVE_KEYS` 的 `uses_left` 无默认值；`start_turn(continue_ids)` 依赖 ongoing 条目携带稳定 `"id"`；`RunState.materials` 经 `feeding_rules._deduct` 可出现小数计数（计量单位裁定挂 T9.2 对接前）。

---

## 任务 0：阶段六收尾补丁（2 个小提交，先于 T7.1）

### P0.1 饿死蛊的死亡物化（提交 A，必做，P2）

- **问题**：`feeding_rules._settle_instance` 对 `hunger >= 2` 只产生 `gu_starved` 事件并把 `hunger_phase` 继续累加，实例**仍以活物身份留在 `gu_instances`**（`state` 仍是 "refined"）：`refined_instances()` 照常把它算作可催动资产、下一大层结算会再次对它结算并**重复产生 starved 事件**（hunger 3、4、…），死亡从未在领域状态中发生。规格 §7.2："下一次结算仍未补足则蛊虫死亡"；AGENTS 红线：不允许静默致死、死亡必须有精准死因。
- **修法（推荐）**：第二次未补足结算时把实例**从 `gu_instances` 移除**，死亡记录完全由不可变事件承载（`gu_starved` 事件携带完整实例快照 + 精准死因，供结局归因）；同一次结算内对已死实例不再重复结算（幂等）。`RunState.settle_layer` 同步：死亡实例不进入 `updated_instances`；`sync_legacy_gu_projections()` 已有调用会自动收缩 `gu_ids`。若你选择"标记 state=dead 留尸"方案，必须同步扩展 `GuInstance.REFINE_STATES` 与 `validate_instance`、并让 `refined_instances()`/喂养结算跳过死实例——两案择一，裁定与理由写进报告。
- 先红后绿：`test_feeding_rules.gd` 补断言——二次未补足后实例不在 `gu_instances`（或为 dead 且被 `refined_instances` 排除）；第三大层结算不再产生第二个 starved 事件；事件含精准死因与实例快照。
- 验收：`tools/test.ps1 -Test "tests/unit/test_feeding_rules.gd"` + `-Suite all`。

### P0.2 gu_estimate 魔法数入库（提交 B，必做，P3）

- `market_rules.gd` 的 `gu_estimate` 用了写死系数 `6.5`——既非规格数字也非 balance.json 键，违反"调参数值必须落在 JSON 过 Schema"。新增 `balance.json` 键 `gu_estimate_ratio`（初值 6.5）+ Schema 正数守卫 + `market_rules` 取参 + 测试改键随动断言（沿用 T2.1 config-driven 风格）。同函数里的 4.0/1.0 是 §9.3 规格锚定值，可保留字面量但加注释声明来源。
- 验收：`tools/test.ps1 -Test "tests/unit/test_market_rules.gd"` + `-Suite all`。

---

## T7.1 核心确认与权益倾斜（提交 C）

- **固定接口**：新增 `scripts/domain/core_gu_rules.gd`（`class_name CoreGuRules`，纯静态、确定性）：
  1. **确认规则**（§1.1）：`can_confirm(state, instance)`——每局同时只能有一只核心蛊；**第一大层中段起**才可确认（层进度判定写清依据）；可以**推迟**（少享受倾斜是唯一代价）；**系统不得自动确认**（任何路径无"默认核心"）；所有战斗蛊均可确认。
  2. **深度标记**（§1.1，验收 #1 前半）：`core_depth(definition, catalog)` 返回 `common_core` / `hub_core`——传承枢纽蛊在数据中声明分支蛊方或专属异炼（`gu.json` 增量字段如 `core_depth: "hub"` + 依据清单；Schema 守卫声明引用存在）。标记表达内容深度差异，**不否定普通蛊成为核心的资格**；快照展示差异挂 T9.1。
  3. **池倾斜**（§1.2）：`tilt_pool(pools, core, cat)`——对 `school_pools.json` 的候选分布适度提高与核心主功能、道标签、食性、已有构筑相容的蛊/蛊材/蛊方/交易机会权重或出现率；**只改善候选分布**：不保证毕业、不指定必得产物、不直给任何无来源基础数值；输出是排序/权重建议，不改 GuBalance 任何输出。
  4. **通用升阶保留原蛊身份**（§1.2）：升阶（同名升阶既有语义）不改变 `definition_id`/实例身份，任何核心不掉队——与 `highest_owned_rank` 既有行为对齐，写断言钉住。
  5. **core_state 实装**（§2.1）：确认后实例 `core_state` 记录 `{"confirmed_layer": n, "depth": ..., "confirmed_at_event": id}` 等事实；`replace_core` 时清空重置（T7.2）。
- **先红后绿**：新增 `tests/unit/test_core_gu_confirm.gd`——**挂接验收 #1**：任意战斗蛊可确认；通用/枢纽深度标记正确且枢纽依据可枚举；同局第二只确认被拒（每局一只）；第一层中段前拒绝、可推迟且无自动确认路径；倾斜只改池分布——**断言倾斜前后 `GuBalance` 全部投影输出逐位不变**；升阶保留身份。
- **最小实现**：纯模块 + `school_pools.json` 倾斜键 + `gu.json` 深度标记样例；确认入口挂炼蛊台/传承节点的命令面在 T9.2。
- 验收：`tools/test.ps1 -Test "tests/unit/test_core_gu_confirm.gd"` + `-Suite all`。
- 退出条件：#1 绿；倾斜不触碰任何基础数值（断言在测试内）；resolver 行数不增。

## T7.2 核心更换凭证（提交 D）

- **固定接口**：`core_gu_rules.gd` 增补（§1.3）：
  1. `grant_replacement_token(state, node, rng_free_source)`：第二/第三大层重大构筑节点**保证**提供一次凭证选择；凭证与异炼、稀有蛊等其他重大收益**互斥竞争**（节点选项二选一，选择凭证即放弃当次强化）；高代价事件/黑市禁忌可小概率提前或替代提供更换机会（概率类由既有种子化池管理承接，本批只留数据入口）——但**不得绕过单局成功更换次数上限**；已通过随机机缘更换过的，后续保证节点改发其他同级收益、不再生成无用凭证。
  2. `replace_core(state, old_instance_id, new_instance_id, cost)`：**移除旧核心的专属改造**（`modifications` 中来源为核心专属的条目）；旧蛊保留转数与普通身份（只清 `core_state` 与专属改造，不动 rank/`state`）；新核心从当前状态起步，**不继承**旧核心路线、专属改造或已消费的成长资源（新 `core_state` 重新确认事实）；`cost` 的来源（凭证/元石/蛊材/寿元/魂魄/禁忌条件）必须作为结构化字段**提前公开**在预检结果中。
  3. **单局成功次数硬上限**（默认 1）：`can_replace` 预检拒绝超额更换（§17.3 预检同源；拒绝 reason 进中文映射挂 T9.2）。
- **数据驱动**：`nodes.json` 增 `core_replacement_token` 授予键（参照 `ascension_grants` 既有模式）——第二/三大层至少各 1 个重大节点携带；Schema 守卫授予键形状与节点层归属。
- **先红后绿**：新增 `tests/unit/test_core_gu_replace.gd`——**挂接验收 #2**：更换后旧核心专属改造被移除、普通转数与身份保留；新核心不继承路线/改造/已消费资源；每局成功次数硬上限有拒绝路径；凭证与当次强化互斥；已随机更换后保证节点改发同级收益（凭证不再生成）；代价来源在预检结果中可见。
- **最小实现**：纯模块 + `nodes.json` 授予键；确认/更换命令入口挂 T9.2；寿元/魂魄类代价的实际结算模块在阶段八，本批只做结构化声明与校验。
- 验收：`tools/test.ps1 -Test "tests/unit/test_core_gu_replace.gd"` + `-Suite all`。
- 退出条件：#2 绿；一局成功次数硬上限有拒绝路径；倾斜与更换全程不触碰 `GuBalance` 数值；resolver 行数不增。

---

## 全局纪律（每一批）

1. 每任务独立提交：`feat(spec-v4): T7.x ...` / `test(spec-v4): T7.x 先红测试`；补丁提交 `fix(spec-v4): P0.x ...`。
2. 先红后绿：红证据写进提交说明。
3. resolver 门禁：`resolver.gd` ≤ 2457（当前 2452）、`battle_resolver.gd` ≤ 1516（当前 1514）；T7.x 不触碰这两个文件。
4. 禁区目录只读；标识符 ASCII、玩家文案 UTF-8；调参进 balance.json 过 Schema（本批预计新增 `gu_estimate_ratio` 一个键）。
5. **倾斜红线**：核心倾斜是分布改善，不是数值外挂——任何"倾斜提升战斗力"的实现一律拒绝；基础数值唯一来源仍是 GuBalance。
6. 测试基线只增不回退；跨阶段缺陷记录报告，不夹带；EOF 换行有 `test_domain_hygiene.gd` 兜底。
7. 核心确认/更换都写不可变结构化事件日志（§17.3 清单动作），确认无自动路径。

## 完成报告要求（供审查）

逐项列出：每个提交 hash 与文件清单；每条验收命令与结果；死亡物化方案裁定（移除 vs 死亡标记）与理由；`core_depth` 数据声明格式与样例；倾斜的权重/排序机制说明（T9.1 快照展示要用）；`nodes.json` 授予键样例；`-Suite all` 最终数字；挂账项延续记录；未验证风险与遗留问题。
