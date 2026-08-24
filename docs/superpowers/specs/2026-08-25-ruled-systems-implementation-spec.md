# 已裁定系统实施规格（一心多用 / 交易预检 / 恶名 / 全局图鉴）

> 日期：2026-08-25
> 依据：`docs/superpowers/specs/2026-08-25-nanjiang-card-roguelike-vision-review.md` §6 裁定记录（P1–P4 已裁定并批数）。
> 基线：工作树 `task1-vendor-open-rpg` @ `9011572`；测试基线 171 unit + 6 integration 全绿；`tools/check.ps1` 无头启动 exit 0。
> 实施方式：四个 Task 按依赖顺序逐个落地，每个 Task 独立小提交；先写可失败测试，再最小实现；每 Task 完成后跑全量测试与启动检查。
> 任务顺序：T1 一心多用 → T2 交易死亡预检 → T3 恶名系统（含最小先手权）→ T4 全局图鉴接线。

## T1 魂魄一心多用（战斗/炼蛊容量）

### 规则（已批准）

- 战斗操作上限 `battle_ops_cap = maxi(1, cultivator.soul)`（1:1；初始魂魄 4 → 4 次/回合）。
- 炼蛊同时投入上限 `craft_cap` 阶梯表：魂魄 1–2 → 2 件；3–4 → 3 件；5+ → 4 件（材料与蛊虫合并计件，当前实现只计蛊虫实例）。
- 现有 `soul_control_limit`（固定 2）废弃；反噬公式数量项改为与新战斗上限比较。

### 改动点（代码事实）

| 文件 | 改动 |
| --- | --- |
| `scripts/domain/soul_capacity.gd`（新建，`class_name SoulCapacity`） | 纯静态函数：`battle_ops_cap(state) -> int`、`craft_cap(state) -> int`、`craft_cap_for_soul(soul:int) -> int`（阶梯表）；无状态、可测 |
| `scripts/domain/run_state.gd` | `new_run` 删除/保留 `soul_control_limit` 默认值（改为不再写入派生语义；save 兼容读取）；新增 `global_codex_ids`（T4） |
| `scripts/domain/battle_resolver.gd` | `start()` 写 `battle["soul_ops_cap"]`（与预览共用口径）；`_backlash_for_activation` 数量项 `active_ids.size() > SoulCapacity.battle_ops_cap(state)`；`action_energy` 相关不动 |
| `scripts/domain/action_preview_service.gd` | 第 115 行 `soul_control_limit` 投影检查改用 `battle_ops_cap`；反噬风险文案同步 |
| `scripts/domain/resolver.gd` | `_apply_free_mix` / `_apply_fixed_recipe`：`selected.size() > SoulCapacity.craft_cap(state)` → 拒绝 `refinement_capacity_exceeded`；`_apply_combine_recipe` 配方定长不设上限（数据层保证配方输入 ≤ 4） |
| `scripts/domain/save_repository.gd` | `soul_control_limit` 读档兼容（缺失时按派生兜底） |

### 测试（tests/unit/test_soul_capacity.gd）

1. battle_ops_cap = soul（soul 4 → 4；soul 1 → 1）。
2. 生存兜底下限：soul 0（死亡边界外）→ 返回 1 不越界。
3. craft_cap 阶梯：soul 1→2、soul 2→2、soul 3→3、soul 4→3、soul 5→4。
4. 反噬数量项按新上限：soul 4 时激活 5 蛊 → 反噬数量差 1（沿用现有公式）。
5. free_mix 投入超 craft_cap → `refinement_capacity_exceeded`；投入 ≤ cap 正常。
6. fixed 配方投入数超 cap → 拒绝；配方 3 输入 soul 4（cap 3）可炼。
7. 预览：soul 4 时第 5 张并发卡出现"魂魄反噬"风险（现行文案）。

## T2 交易死亡预检

### 规则（已批准）

任何消耗寿元/魂魄的交易命令：结算后值 < 1 → 拒绝，返回明确 feed（`lifespan_trade_warning` / `soul_trade_warning`），**不允许静默致死**；UI 预览把此类交易显示为不可执行并给出文案。预检模式沿用 `_accept_event` 的 health 预检先例（`state.health <= health_cost` → `insufficient_health`）。

### 改动点（代码事实）

| 文件 | 改动 |
| --- | --- |
| `scripts/domain/resolver.gd` | `_shop_lifespan_deal`：先 `lifespan - cost < 1` → `lifespan_trade_warning`，再付（去掉 `maxi(0, …)` 语义）；其余扣寿元/魂魄的交易路径（实现时 `grep "lifespan|soul"` 逐点确认，包括遭遇动作的魂魄消耗）同规则；消耗寿元/魂魄的免费事件与反噬结算**不属本任务**（反噬已有 `maxi(0, …)` 术内钳制） |
| `scripts/domain/action_preview_service.gd` | 店铺卡片（`shop.lifespan_deal` 等）：预览含"交易后寿元/魂魄"投影；投影 < 1 → `executable=false` + 明确文案（格式照抄"真元不足"文案惯例） |

### 测试（tests/unit/test_trade_death_precheck.gd）

1. lifespan 5 买 cost 5 → 接受，剩余 0 → **拒绝**（`lifespan_trade_warning`），资源不变。
2. lifespan 6 买 cost 5 → 接受，剩余 1，事件 `shop_lifespan_deal_paid`。
3. 预览卡片：cost 10 / lifespan 5 → executable=false + 文案含"寿元将耗尽"。
4. 遭遇动作扣魂魄路径：结算后魂魄 < 1 → 拒绝（若有此路径）。
5. 回归：免费/事件扣寿元（非交易）行为不变。

## T3 恶名系统（含最小先手权）

### 规则（已批准）

- 状态：`cultivator.notorious`（int，默认 0；入 save/load 与事件日志）。
- 触发：击杀中立/商人 NPC（含交易后动手）胜利 ＋2/次；背弃承诺/撕毁交易（leave 时存在未结债务）＋1/次——数值入数据表可配。
- 效应（每 1 恶名）：交易价格 +10%（上限 +60%）；中立遭遇直接敌视概率 +15%；敌视战斗敌方先手概率 +10%。
- 洗名：支付 10 寿元 → −2（黑市新 offer kind `wash_notoriety`；预检联动 T2）；事件洗名留数据口。

### 改动点（代码事实）

| 文件 | 改动 |
| --- | --- |
| `data/reputation.json`（新建） | `gains: {kill_neutral_npc: 2, broken_trust: 1}`；`price_pct_per_point: 10`、`price_cap_pct: 60`、`hostile_chance_pct_per_point: 15`、`first_move_chance_pct_per_point: 10`、`wash_lifespan_cost: 10`、`wash_reduce: 2`；ContentCatalog 加载+索引+整数校验（沿用 `_is_integral`） |
| `scripts/domain/run_state.gd` | `cultivator.notorious` 默认 0；save/load 随 cultivator 字典自动携带 |
| `scripts/domain/resolver.gd` | 新增 `_notoriety_gain(state, amount, reason)`（append_event，reason `notoriety_gained`，记录 before/after）；胜利分支/背约分支调用；商店/车队价格 `ceili(base * (1.0 + min(0.60, 0.10 * notorious)))`；新增 `wash_notoriety` 命令（寿元预检 → 减恶名）；`_finalize_if_dead` 不变 |
| `scripts/domain/encounter_session_resolver.gd` | 遭遇 `begin` 时：notorious > 0 → 种子掷骰 `hostile_chance = 15% * notorious`，命中则中立立场直接置 `hostile` 并记事件的 feed `reputation_hostile_stance`（掷骰函数沿用 `_free_mix_seed` 风格，种子可复现）；战斗胜利后若目标为中立/商人 → +2 |
| `scripts/domain/battle_resolver.gd` | 最小先手权（评审 C3 最小集）：`start(encounter, state, catalog)` 读取 `encounter.get("first_mover", "player")`；遭遇层在敌视立场且掷骰命中 `10% * notorious` 时传 `first_mover: "enemy"`；`first_mover == "enemy"` → 先结算一次敌意图伤害（复用 `_end_turn` 的敌意图结算，抽成 `_apply_enemy_intents(battle, state) -> {battle, state, intents}`），记事件/日志 `battle_enemy_first_move`，随后照常玩家回合；`turn` 计数不变 |
| `scripts/domain/action_preview_service.gd` | 商店卡片价格显示上浮后数值；洗名卡片投影（寿元）|
| `data/shops.json` | 新增 `wash_notoriety` offer（lifespan_cost 10） |
| `scripts/domain/content_catalog.gd` | reputation 加载/校验；shop offer 校验扩展 |

### 测试（tests/unit/test_notoriety.gd）

1. 击杀中立商人胜利 → notorious +2，事件 reason `notoriety_gained`。
2. 背约离开 → +1；无债务离开 → 0。
3. 价格：notorious 2 → cost 10 变 12；notorious 6 → 上限 +60%（16）；notorious 8 → 仍 +60%。
4. 中立遭遇敌视掷骰：种子固定命中/不命中两例；notorious 0 永不敌视。
5. 敌视 + 命中 → battle first_mover = enemy，首回合先结算敌意图，日志含 `battle_enemy_first_move`；未命中 → player。
6. 洗名：10 寿元 → −2；寿元不足 → 拒绝；寿元预检联动 T2（剩余 < 1 拒绝）。
7. 竞争性用例：无事件日志伪条目。

## T4 全局图鉴接线（豁免局外成长条款）

### 规则（已批准）

- 已解锁蛊方/配方录入 `meta_progress` 全局图鉴；后续对局可见、可炼（门禁豁免）。
- 对局内配方门禁仍以局内 knowledge 为准；盲盒产出（mutate_to 等）随 `refined_gu_ids` 已入图鉴。
- 豁免范围仅限图鉴解锁，不开放其他局外成长。

### 改动点（代码事实）

| 文件 | 改动 |
| --- | --- |
| `scripts/domain/run_state.gd` | 新增 `global_codex_ids: Array[String]`；`new_run(seed, meta = null)` 从 meta 拷贝 `recipe_codex_ids + gu_codex_ids` 快照（保存进 run save，可复现）；`from_save_data`/`to_save_data` 同步 |
| `scripts/presentation/run_controller.gd` | `start_new_run` 把已加载的 meta 传入 `RunState.new_run(seed, meta)` |
| `scripts/domain/resolver.gd` | `_apply_fixed_recipe` 门禁改为：`locked` 且（无局内 knowledge 且 `global_codex_ids` 不含 recipe_id 且不含 output_gu_id）→ `refinement_recipe_locked`；炼蛊成功（fixed/combine）把 recipe_id 记入 `state.unlocked_recipe_ids`（新增字段，事件日志补录口径：以 unlock 事件为准） |
| `scripts/domain/meta_progress.gd` | `record_run_end` 扩展：`recipe_codex_ids += run.unlocked_recipe_ids`；gu_codex 逻辑不变 |
| 存档路径（run_controller/save_repository） | 局结束时 `record_run_end` + `save_meta_file`（沿用现有 meta 落盘路径；实现时确认写出时机） |
| `scripts/domain/action_preview_service.gd` | 配方可见性：knowledge 满足 或 codex 含 recipe_id/output_gu_id 才显示（locked 配方） |

### 测试（tests/unit/test_global_codex.gd）

1. `global_codex_ids` 含 recipe_id → locked 配方可炼（`refinement_succeeded`）。
2. 不含且无 knowledge → `refinement_recipe_locked`。
3. 含 output_gu_id 不含 recipe_id → 可炼（按输出蛊解锁）。
4. `new_run(seed, meta)` 快照拷贝；`to_save_data`/`from_save_data` 往返一致。
5. 炼蛊成功 → `unlocked_recipe_ids` 记录；`record_run_end` 后 meta.recipe_codex_ids 含该配方。
6. 预览：locked 配方在 codex 解锁后可见。

## 验收与风险

- 每 Task：失败测试先行 → 最小实现 → 全量 `tools/test.ps1`（unit + integration）→ `tools/check.ps1` 无头启动 → 独立小提交（ASCII 信息）。
- 回归清单：`grep soul_control_limit` 全量替换（battle_resolver 383/405/465、action_preview 115、run_state 62、save_repository 173–175、既有测试）；shops/caravan 价格函数互斥（旧断言若断言原价需更新）；遭遇/battle 既有测试不得因 first_mover 默认 player 而失败。
- 边界约定：新增 JSON 数值一律 `_is_integral` 校验；所有状态变化（恶名、洗名、敌视翻转、全局图鉴解锁）入不可变事件日志；UI 只展示投影与风险，不做状态裁决；全部随机走种子。

> 本规格待用户批准后进入 TDD 实施；T1–T4 依序提交，不合并。