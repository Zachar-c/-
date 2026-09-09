# 技术债实施计划 — 原子任务拆解（可直接派发）

- **源计划**：`docs/superpowers/plans/2026-09-09-tech-debt-remediation-plan.md`
- **拆解日**：2026-09-09
- **基线核对**：`master` @ `04c389d` 附近；`resolver.gd` 2407 行 / 114 静态函数；`run_snapshot_builder.gd` 2058 行；`run_controller.gd` 1407 行
- **本文件用途**：把**尚未闭环**工单拆成「单一动作、输入/输出、成功验证、时间」四件套；执行模型**只按步骤机械执行**，不得自行改方案、扩范围或跳过验证。

---

## 0. 执行铁律（每个子任务共同约束）

| 规则 | 内容 |
|------|------|
| R0 | **一子任务一会话/一次派发**；完成前不开始下一子任务。 |
| R1 | 只改子任务「输出」列点名的文件；发现无关改动：**保护并忽略**。 |
| R2 | 开工前执行：`git status --short --branch`；有未提交业务改动且将冲突时 **停止并报用户**。 |
| R3 | 并行视觉会话冲突门：执行前看 `scripts/presentation/screens/` 与 `run_snapshot_builder.gd` / `run_controller.gd` 的 mtime；**30 分钟内有修改则不执行 W12 相关步**。 |
| R4 | 大改（W11.3 / W12）必须在**独立 worktree** 中做；禁止 `reset --hard`、`filter-branch`、`stash` 滥用、重写历史。 |
| R5 | 每子任务结束：跑该任务列出的验证命令；把输出贴进回执；**禁止为变绿改断言**（除非子任务明确写「先改契约文档再改测试」）。 |
| R6 | 验证命令统一用：`powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite unit`（下文简称 `unit`）；`-Suite integration`（`integration`）；`tools/check.ps1`（`check`）。 |
| R7 | **禁止执行**源计划中已闭环的 W1–W9、W13、W14（见 §5 已闭环清单）。 |
| R8 | 提交信息 ASCII；文件内玩家可见中文 UTF-8；不提交 `.claude/`、`build/`、截图、`.git.broken-*`。 |

**全局完成定义（整批）**：§1–§4 所选范围内子任务全部 ✅ + `unit` + `integration` + `check` 全绿 + 关键提交已推送且 `git ls-remote origin refs/heads/master` = 本地 HEAD（或 worktree 分支已合入 master）。

---

## 1. 轨道 A — W11.3 `resolver.gd` 按命令族拆分

### A0. 范围与目标（执行模型只读，不改）

| 项 | 值 |
|----|-----|
| 目标 | `scripts/domain/resolver.gd` 降至 **< 1200 行**；`Resolver.apply` 行为不变；命令面与事件日志语义不变 |
| 前置 | W4 契约测试已合入（源计划：已闭环 `04c389d`）；W11 措施 1/2/4 已闭环 |
| 方法 | 抽出独立 `class_name` 模块，`resolver.gd` 保留 `apply` / `_handler_for` 薄路由 + 跨族共享私有助手 |
| 禁止 | 改平衡数值；改命令 type 字符串；合并/删除命令；改 public API 名称（`apply`、`price_for`、`service_price_for`、`recipe_unlocked`、`gain_notoriety`、`notoriety`、`roll_chance`、`shop_layer_price`、`shop_max_tier`、`sell_price_for`、`scavenge_pending_recipes`、`apply_social_action`、`service_use_count`、`service_limit`） |
| 预估总时 | 8h–14h（分 8 个子任务） |

### A1. 建立 worktree 与基线快照

| 字段 | 内容 |
|------|------|
| **目标** | 只读基线可复现，后续每步可 diff。 |
| **输入** | 干净 `master`；已有 unit 全绿。 |
| **操作步骤** | 1) `git worktree add .worktrees/resolver-split -b chore/w11-resolver-split master`<br>2) 在该 worktree 内：`powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite unit`<br>3) 记录：`resolver.gd` 行数、`git rev-parse HEAD`、unit 结果写入回执文件 `docs/audits/W11.3-baseline.txt`（或会话回执，勿提交无关噪音） |
| **输出** | worktree 路径；分支名 `chore/w11-resolver-split`；基线记录 |
| **成功标准** | unit 全绿；`Get-Content scripts/domain/resolver.gd \| Measure-Object -Line` 结果写入回执（期望 2407） |
| **时间** | 0.3h |
| **验证命令** | `tools/test.ps1 -Suite unit`；行数测量命令 |
| **失败即停** | unit 有红 → 不进入 A2，先在 master 查清是否与拆分无关的既有红灯 |

### A2. 抽出 `rest` 命令族 → `scripts/domain/rest_rules.gd`

| 字段 | 内容 |
|------|------|
| **目标** | 休息簇离开 `resolver.gd`，dispatch 指向新模块。 |
| **输入** | `resolver.gd` 中下列函数（原样搬移，不改逻辑）：`_rest`、`_rest_skip`、`_rest_upgrade`、`_rest_heal`、`_rest_removal`、`_rest_remove_card`、`_rest_remove_imprint`、`_rest_remove_curse`、`_rest_visit_key`、`_rest_mode_key`、`_rest_visit_consumed`、`_is_rest_node`、`_is_rest_class_node`、`_consume_rest_visit`、`_consume_rest_visit_if_rest_class`、常量 `REST_REMOVAL_MODES`、`REST_NODE_TYPE`、`REST_CLASS_TYPES` |
| **操作步骤** | 1) 新建 `class_name RestRules extends RefCounted`，粘贴上述函数为 `static func`（下划线前缀可保留或改为无下划线公开，**二选一后全局一致**；推荐保留原名减少 diff）<br>2) 需要的 `preload`（如 `ResolverHelpers`）按编译错误逐个补<br>3) `resolver.gd` 的 `_dispatch` 中 `"rest"` 改为 `RestRules._rest(...)`（或等价公开名）<br>4) 删除 `resolver.gd` 内已搬函数<br>5) **不**搬 `_accepted`/`_rejected`：RestRules 内使用 `Resolver._accepted` 不可行（私有）→ 在 RestRules 本地复制极薄 `_accepted`/`_rejected` **或** 预先在 A2 之前把这两个函数改为 `static func` 包装进 `ResolverHelpers`（推荐后者，见 A2.0 可选前置，若做则单独提交） |
| **输出** | 新文件 `rest_rules.gd`；`resolver.gd` 变短；dispatch 仍响应 `rest` |
| **成功标准** | `unit` 全绿；`integration` 中 rest 相关测试全绿；`grep` 确认 `resolver.gd` 无 `_rest(` 函数定义 |
| **时间** | 1.5h |
| **验证命令** | `unit`；`integration`；`powershell -File tools/test.ps1 -Test tests/unit/test_rest_*.gd`（若有） |
| **回执必填** | 拆分后 `resolver.gd` 行数；新文件行数 |

**A2.0 可选前置（若执行则先单独提交）**：把 `Resolver._accepted` / `_rejected` 移入 `resolver_helpers.gd` 并 `static` 导出，`resolver` 与后续模块统一调用。验证：`unit` 全绿。

### A3. 抽出 `shop` 命令族 → `scripts/domain/shop_command_rules.gd`

| 字段 | 内容 |
|------|------|
| **目标** | 商店簇离开 resolver。 |
| **输入** | `_shop_purchase`、`_shop_material_purchase`、`_shop_gu_fang_unlock`、`_shop_recipe_unlock`、`_shop_soul_boost`、`_shop_resource_trade`、`_shop_lifespan_deal`、`_shop_barter`、`_current_shop_layer`、`shop_layer_price`（**公开 API，迁移后由 resolver 转发一行**）、`shop_max_tier`（同上）、`_offer`、`_raise_aptitude`（若编译依赖紧耦合则一并迁） |
| **操作步骤** | 1) 新建模块，搬移函数<br>2) `shop_layer_price` / `shop_max_tier` 在 `resolver.gd` 留一行转发：`static func shop_layer_price(...): return ShopCommandRules.shop_layer_price(...)`（**禁止**改外部调用点）<br>3) dispatch 的 `shop_purchase` / `shop_lifespan_deal` / `shop_barter` / `raise_aptitude` 指向新模块<br>4) 已有 `shop_rules.gd`（若存在定价 helper）只被调用，**不删除** |
| **输出** | `shop_command_rules.gd`；resolver 转发 API 保持 |
| **成功标准** | `unit` 全绿；`grep -n "func shop_layer_price\|func shop_max_tier" scripts/domain/resolver.gd` 仍有转发定义 |
| **时间** | 1.5h |
| **验证命令** | `unit`；商店相关测试单跑 |

### A4. 抽出 `refine` 命令族 → `scripts/domain/refine_command_rules.gd`

| 字段 | 内容 |
|------|------|
| **目标** | 炼蛊/材料/卡牌服务簇离开 resolver。 |
| **输入** | `_refine_gu`、`_recipe_material_pieces`、`_has_all_materials`、`_spend_materials`、`_apply_combine_recipe`、`_codex_unlocks_recipe`、`recipe_unlocked`（**公开，resolver 转发**）、`_apply_fixed_recipe`、`_selected_input_instance_ids`、`_refinement_roll`、`_apply_free_mix`、`_cultivate_rank_two`、`_disable_card`、`_upgrade_card`、`_copy_card`、`_destroy_gu`、`_cursed_drop_block`、`_destroyed_gu_payload`、`service_use_count`、`service_limit`、`service_price_for`、`_bump_service_flag`、`_remove_card_command`、`_remove_imprint_command`、`_settle_node_feeding`、`_settle_feeding`、`_buy_gu`、`_sell_gu`、`_exchange_gu`、`_add_gu_transaction`、`_has_all_gu`、`_without_gu`、`_scavenge`、`scavenge_pending_recipes`（转发）、`_sell_material`、`_use_material` |
| **操作步骤** | 1) 同 A2 模式新建模块<br>2) 公开 API 在 resolver 留转发<br>3) dispatch 中对应 type 改调新模块<br>4) `refine_gu` / `refine_free_pair` / `cultivate_rank_two` 的 **rest-class 消费包装**（dispatch 内联 lambda）仍留在 `resolver.gd`，只把核心函数搬走 |
| **输出** | `refine_command_rules.gd`；dispatch 包装仍在 resolver |
| **成功标准** | `unit`+`integration` 全绿；`test_legacy_abolition` 仍绿 |
| **时间** | 2h |
| **验证命令** | `unit`；`integration` |

### A5. 抽出 `npc` / 社交 / 事件 → `scripts/domain/social_command_rules.gd`

| 字段 | 内容 |
|------|------|
| **目标** | NPC/事件/契约/诅咒命令簇离开 resolver。 |
| **输入** | `apply_social_action`（**公开，转发**）、`_npc_by_id`、`_npc_trade`、`_current_node_declares_npc`、`_npc_reaction`、`_accept_event`、`_gain_curse_command`、`_remove_curse_command`、`_swear_contracts`、`_contract_entry_by_id`、`_resolve_contact`、`_record_neutral_npc_kill`、`_wash_notoriety`、`gain_notoriety`（**转发**）、`notoriety`（**转发**）、`_choose_action`、`_standard_action_transition`、`_buy_opportunity`、`_take_body_imprint`、`_use_gu`、`_retreat`、`_spend_lifespan`、`_accept_debt`、`_finalize_if_dead`、`_claim_inheritance`、`_ascension_*` 与 `_attempt_ascension`、`_record_boss_defeated`、`_record_layer_boss_defeated`、`_gain_relic`、`_can_gain_relic`、`_gain_force_power`、`_complete_node`、`_travel`、`_resource_transition`、`_spend_stone_for_fact`、`_fact_transition`、`_facts_with`、`_facts_with_values`、`_grant_lifespan_milestone`、`roll_chance`（**转发**）、`price_for` / `sell_price_for`（**转发**，实现可迁 `economy_rules` 若已重复则合并——**仅当 diff 显示与 economy_rules 逻辑一致时合并，否则原样搬**） |
| **操作步骤** | 1) 新建模块搬移<br>2) 公开 API resolver 一行转发<br>3) dispatch 全量改指向<br>4) 常量 `STANDARD_ACTIONS`、`BODY_IMPRINTS`、`OPPORTUNITY_TYPES`、`APTITUDE_LADDER`、`FORCED_DROP_CURSE_ID` 随使用点迁移或留在 resolver 顶部并被新模块 `preload` 引用（**推荐迁到使用方**） |
| **输出** | `social_command_rules.gd`；resolver 主要是路由 |
| **成功标准** | `unit`+`integration` 全绿；`resolver.gd` 行数 **< 1200** |
| **时间** | 2.5h |
| **验证命令** | 行数测量；`unit`；`integration`；`check` |

### A6. 收口：更新 PONYTAIL-DEBT 与模块契约文档

| 字段 | 内容 |
|------|------|
| **目标** | 文档与代码一致。 |
| **输入** | A2–A5 产出的新文件名与公开 API 列表。 |
| **操作步骤** | 1) `PONYTAIL-DEBT.md`：删除或改写 `resolver.gd:4` 行号门限行，改为「拆分后单文件门限 1200」<br>2) `docs/contracts/module-interfaces/07-domain-action-router.md`：更新文件清单（resolver + 新模块）与数据流<br>3) `MODULE-INVENTORY.md` A2 行更新规模描述（可选，一句即可） |
| **输出** | 3 个文档 diff |
| **成功标准** | 文档中出现的新文件名在 `scripts/domain/` 真实存在；无残留「resolver 2407 行」过时描述 |
| **时间** | 0.5h |
| **验证命令** | `rg "resolver.gd" PONYTAIL-DEBT.md docs/contracts/module-interfaces/07-domain-action-router.md` 人工读一遍 |

### A7. 全量回归与合入

| 字段 | 内容 |
|------|------|
| **目标** | 合并回 master。 |
| **操作步骤** | 1) worktree 内：`unit` → `integration` → `check`<br>2) 按步或 squash 提交（推荐 **A2/A3/A4/A5/A6 各一提交**，信息：`refactor(domain): extract rest/shop/refine/social command modules from resolver`）<br>3) 推送分支；用户批准后 merge 到 master<br>4) `git worktree remove .worktrees/resolver-split` |
| **输出** | master 上 resolver < 1200 行 + 新模块 |
| **成功标准** | master 上三件套绿；`git ls-remote` 对齐 |
| **时间** | 1h |
| **验证命令** | 三件套；`ls -lt scripts/domain/*_command_rules.gd scripts/domain/rest_rules.gd` |

### A8. （并入 A5 同批，已基本完成）确认 school_rules 无再删项

| 字段 | 内容 |
|------|------|
| **目标** | 避免误删活代码。 |
| **输入** | `scripts/domain/school_rules.gd` 现有 4 个函数（`blood_stacks` / `add_blood_stacks` / `material_fuel` / `is_soul`）。 |
| **操作步骤** | 1) `rg "SchoolRules\." scripts/` 列出引用<br>2) 若 4 函数均仍被引用 → **不删除**，回执写「W13 已闭环，无需再动」<br>3) 仅当发现零引用函数时再删并跑 unit |
| **成功标准** | 无误删；unit 绿 |
| **时间** | 0.2h |
| **验证命令** | `rg "SchoolRules\." scripts/` |

---

## 2. 轨道 B — W12 `run_snapshot_builder` / `run_controller` 拆分

### B0. 范围与目标

| 项 | 值 |
|----|-----|
| 目标 | 1) `run_snapshot_builder.gd` 按屏拆出 builder，聚合入口 `for_screen` 行为不变<br>2) `run_controller.gd` 拆出「视图挂载 / 命令分发 / 存档生命周期」三职责，**不改对外方法名**（`submit_command`、`start_new_run`、`save_current_run`、`load_saved_run`、`ensure_ui` 等） |
| 前置 | **W4 契约测试已存在**；轨道 A 完成或至少不冲突；无并行视觉会话正在改这两文件 |
| 禁止 | 改快照键名；改 UI 消费契约；修 W10（继续交给视觉会话） |
| 预估 | 每屏 2–3h × 5 屏 + controller 3–4h |

### B1. worktree 与契约测试基线

| 字段 | 内容 |
|------|------|
| **步骤** | 1) `git worktree add .worktrees/snapshot-split -b chore/w12-snapshot-split master`<br>2) 跑 `unit`（含 `test_snapshot_contract`）全绿并记录 HEAD |
| **成功标准** | 契约测试绿 |
| **时间** | 0.3h |

### B2. 抽出 `hall` 快照 → `scripts/presentation/snapshots/hall_snapshot.gd`

| 字段 | 内容 |
|------|------|
| **目标** | `hall()` 及仅 hall 使用的私有函数迁出。 |
| **输入** | `run_snapshot_builder.gd` 中 `hall`、`_run_route_label`、`_rank_cn`、`_lifespan_remaining`、`_curse_count`、`_cn_number`、`_latest_journal_title`、`_school_display_name`、`_contract_selection_state`、`_available_contracts`、`_codex`、`_journal`（**以编译依赖为准：只搬 hall 调用闭包内的函数**） |
| **操作步骤** | 1) 新建 `HallSnapshot.build(controller) -> Dictionary`<br>2) `for_screen("Hall")` 改为 `return HallSnapshot.build(controller)`<br>3) 删除原 `hall` 主体<br>4) 共享小函数（如 `_cn_number`）若 map 等也用 → 抽到 `snapshot_text_util.gd`，**禁止**复制两份 |
| **输出** | `hall_snapshot.gd` + 可选 `snapshot_text_util.gd` |
| **成功标准** | `test_snapshot_contract` 中 Hall 段绿；`unit` 全绿 |
| **时间** | 2h |
| **验证** | `-Test tests/unit/test_snapshot_contract.gd` + `unit` |

### B3. 抽出 `map` 快照 → `map_snapshot.gd`

| 字段 | 内容 |
|------|------|
| **输入** | `map`、`_map_visibility`、`_node_actions`（若仅 map 用） |
| **步骤** | 同 B2 模式；`for_screen("Map")` 转发 |
| **成功标准** | 契约 Map 键不变；unit 绿 |
| **时间** | 1.5h |

### B4. 抽出 `battle` 快照 → `battle_snapshot.gd`

| 字段 | 内容 |
|------|------|
| **输入** | `battle`、`battle_turn_supports`、`_v1_enemies`、`_v1_intent_to_screen`、`_v1_player`、`_v1_actions`、`_v1_buffs_to_statuses`、`_buff_label`、`_v1_hand`、`_v1_slot_note`、`_v1_effect_text`、`_status_label`、`_v1_cost_text`、`_v1_life_cost_risk`、`_gu_quality`、`_v1_reject_text`、`_v1_kill_moves`、`_find_v1_slot`、`kill`（若同文件） |
| **步骤** | 新建 `BattleSnapshot`；`for_screen` Battle/Kill 转发；**不**改 V1 数值 |
| **成功标准** | battle 契约键绿；`test_v1_*` 相关 unit 绿 |
| **时间** | 2.5h |

### B5. 抽出 `rest` / `shop` / `refine` / `npc` / `reward` / `encounter` / `settings` 快照

| 字段 | 内容 |
|------|------|
| **拆分粒度** | 每个函数一个子提交，顺序建议：`rest` → `shop` → `refine` → `npc` → `reward` → `encounter` → `settings` → `content_error` / `debug` |
| **每个子步骤** | 1) 只搬该屏函数 + 其私有闭包依赖<br>2) `for_screen` 改一行转发<br>3) 跑 `test_snapshot_contract` + `unit`<br>4) 一屏一提交 |
| **时间** | 合计 4–5h |
| **成功标准** | 每步后契约测试绿；最终 `run_snapshot_builder.gd` < 800 行（目标），`for_screen` 保持唯一入口 |

### B6. Controller：抽出存档生命周期 → `scripts/presentation/run_save_flow.gd`

| 字段 | 内容 |
|------|------|
| **目标** | 存读档与离开地图流程离开 controller 主文件。 |
| **输入** | `save_current_run`、`load_saved_run`、`_save_load_feedback`、`_restore_game`、`request_map_leave`、`cancel_map_leave`、`save_and_leave_map`、`leave_map_without_save`（**controller 上保留同名 public 包装**，内部调用 RunSaveFlow） |
| **步骤** | 1) 新建 `RunSaveFlow`（持有对 controller 的弱引用或传入 state/catalog）<br>2) controller 方法改为一行委托<br>3) 跑存档相关 unit + `integration` |
| **成功标准** | public API 签名不变；save/load 测试绿 |
| **时间** | 1.5h |

### B7. Controller：抽出调试面板挂载 → `run_debug_facade.gd`

| 字段 | 内容 |
|------|------|
| **输入** | `debug_*` 方法族、`_debug_*` 私有、`_debug_enabled`、`debug_panel_mounted`、F12 处理中调试段 |
| **步骤** | 同委托模式；**保留** `OS.is_debug_build` 门控在 controller 入口或 facade 入口（一处即可，注释写明） |
| **成功标准** | Release 门控行为不变；`test_debug_actions*` 绿 |
| **时间** | 1h |

### B8. Controller：抽视图挂载表 → `run_screen_router.gd`

| 字段 | 内容 |
|------|------|
| **输入** | `_mount_screen` / `_show_*` / `_view_name` 切换相关私有（以文件内 `for_screen` 调用点为准） |
| **步骤** | 新建 router；controller `submit_command` 仍负责调 Resolver，成功后调 router 刷新快照并挂屏 |
| **成功标准** | `test_wenzhen_ui_flow` / master flow 相关 integration 绿；`run_controller.gd` < 900 行目标 |
| **时间** | 2h |

### B9. W12 全量回归与合入

| 字段 | 内容 |
|------|------|
| **步骤** | `unit` + `integration` + `check`；按屏合并提交；merge master；remove worktree |
| **成功标准** | 三件套绿；契约文档无需改键（若改键则违反本轨道，回滚该步） |
| **时间** | 1h |

---

## 3. 轨道 C — W10 `continue_run`（仅视觉会话执行）

> **通用 AI 会话禁止改这两处接线**；只允许在源计划状态表催办。

| 字段 | 内容 |
|------|------|
| **问题** | `run_snapshot_builder.gd:918`：`primary_action = "continue_run" if has_save else "open_schools"`；`run_command_builder.gd:113`：`continue_run` → `_show_hall_subview("schools")`（与「读档继续」语义不符） |
| **负责人** | 视觉会话 |
| **决策点（视觉会话定，勿猜）** | 二选一并写进提交说明：<br>**方案甲**：按钮 = 读档继续 → `submit_command` 走 `load_saved_run` / 等价命令<br>**方案乙**：文案与语义都改为「选择流派」→ 快照 `primary_action` 改为 `open_schools` |
| **步骤** | 1) 定甲/乙<br>2) 只改快照键或 command builder **一处语义对齐**<br>3) 跑 `unit`，目标 `test_map_exit_persistence` 回绿<br>4) 真窗验收（用户键鼠）标注待办 |
| **成功标准** | `unit` 1100/1100 全绿（以当前仓库实际测试数为准） |
| **时间** | 视觉会话自估（约 0.5–1h） |
| **通用会话产出** | 仅状态表催办一行，无代码 |

---

## 4. 建议执行顺序与时间节点

```
Day0  A1 worktree+基线
Day0  A2 rest 拆分 → unit
Day1  A3 shop → A4 refine
Day2  A5 social → A6 文档 → A7 合入
Day3  B1 → B2 hall → B3 map
Day4  B4 battle → B5 rest/shop/refine
Day5  B5 剩余屏 → B6 save flow → B7 debug → B8 router → B9 合入
随时  C（W10）视觉会话并行；与 B 错峰改 presentation
```

里程碑：**A7 结束** resolver < 1200 且三件套绿；**B9 结束** 快照/controller 主文件显著变薄且契约键零漂移。

---

## 5. 已闭环清单（禁止重复执行）

| 工单 | 状态 | 提交 |
|------|------|------|
| W1 导出隔离 | ✅ | `d0ed0d2` |
| W2 停跟踪 build + gc | ✅ | `a4b5528` |
| W3a LICENSE | ✅ | `6841333` |
| W3b 关于署名守门 | ✅ | `9acc158` |
| W4 快照契约首版 | ✅ | `04c389d` |
| W5 重复加载实测 | ✅ 不改码 | `89f0202` |
| W6 display_text | ✅ | `6aefc1e` / `5bd9c1d` |
| W7 map fallback 警告 | ✅ | `7772b58` |
| W8 契约漂移守门 | ✅ | `7772b58` / `1a00ca5` |
| W9 分支卫生 | ✅ | `a4b5528` |
| W11 措施 1/2/4 | ✅ | `6753065` / `10122fb` |
| W13 school_rules 死函数 | ✅ | `10122fb` |
| W14 audio randi 豁免 | ✅ | `d322387` |
| W11 措施 3 resolver 拆分 | **待执行 → 轨道 A** | |
| W12 拆分 | **待执行 → 轨道 B** | |
| W10 continue_run | **视觉会话 → 轨道 C** | |

---

## 6. 回执模板（每个子任务复制一份填）

```
### <子任务ID> <标题>
- 开始时间:
- worktree/分支:
- 输入文件:
- 实际操作摘要（≤5 行）:
- 验证命令与结果:
- 输出文件:
- 成功标准是否满足: Y/N
- 提交 SHA:
- 未验证风险:
```

---

## 7. 回滚策略（执行模型遇红灯时）

1. **契约测试红且键名缺失/类型错**：回滚**当前屏/当前命令族**该次提交，不在红灯上叠提交。  
2. **unit 红在已有测试**：对比基线是否已红；基线红 → 不属本任务，停并报告。  
3. **integration 红**：优先恢复 `dispatch` 原样调用，再逐函数二分搬迁。  
4. **禁止**：改断言期望值、跳过测试、在 master 上直接大改、删除 `test_legacy_abolition` / `test_snapshot_contract`。
