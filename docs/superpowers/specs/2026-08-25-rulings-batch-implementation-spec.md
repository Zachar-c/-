# 裁定批次实施规格（终局门禁 / 休息点 / 寿元里程碑 / 资质真元）

> 日期：2026-08-25
> 依据：评审 §4 P5–P12 用户裁定（2026-08-25 二答）；P7/P10/P11 已完结不重复。
> 基线：工作树 @ `39b749b`；224 unit + 6 integration 全绿；`check.ps1` exit 0。
> 实施方式：T9→T12 依序、失败测试先行、独立小提交；P12 仅记录不写码。

## T9 终局门禁（P5-A）

### 规则（已裁定）

升仙窗口前必经 BOSS 战：`miasma_vein_lord`（P6 已提供数据）被击败后记 `node_flags["boss_defeated"]`；`attempt_ascension` 前置检查该标记，未击败 → 拒绝 `boss_undefeated`（UI 文案"终局强敌未除，升仙窗口尚不安全"）。三支结局不变。

### 改动点

| 文件 | 改动 |
| --- | --- |
| `data/nodes.json` | 新增阶段五节点 `final_boss_stand`（type `combat`，choices `fight`/`retreat`，on_skip `gain_pursuit`，next_ids 空——网络化阶段收敛负责接 `ascension_window`）；`_generated_stage_picks` 阶段五强制并入该节点（与 `poison_fog_vein` 并列） |
| `scripts/presentation/run_controller.gd` | `_start_battle` 敌人映射：`final_boss_stand` → `miasma_vein_lord`；`_finish_battle_in_session` 胜利且敌方为 boss → `Resolver.apply(state, {"type": "record_boss_defeated"}, catalog)` 后接事件 |
| `scripts/domain/resolver.gd` | 新命令 `record_boss_defeated`：写 `node_flags["boss_defeated"]`（append_event，reason `boss_defeated_recorded`）；`_attempt_ascension` 前置检查 |
| `scripts/domain/action_preview_service.gd` | 升仙卡片：未击败 boss → `executable=false` + 文案（`_append_ascension_cards` 或 attempt 卡片处） |

### 测试（tests/unit/test_boss_gate.gd）

1. 无标记 attempt_ascension → `boss_undefeated`，状态不变。
2. `record_boss_defeated` 后 → 可冲击（原有三种结果路径保留）。
3. `record_boss_defeated` 事件含 before/after 与 reason。
4. 预览：未击败时升仙卡不可执行，文案含"终局强敌"。
5. 已有烟雾结局测试（test_smoke_outcomes）同步标记后仍三支全过（实施时确认其构造方式）。

## T10 休息点节点（P6-A）

### 规则（已裁定）

新增 `rest` 节点类型：**节点效果允许恢复，NPC 交互行为禁止恢复**（口径写评审 §6.6）。休息点每节点限一次：气血 +2（上限 `max_health`）、真元 +2（上限 `essence_max`）、**寿元不恢复**（寿元是货币线）。

### 改动点

| 文件 | 改动 |
| --- | --- |
| `data/nodes.json` | 新增 `rest_hollow`（stage `one`，type `rest`，choices `rest`/`leave`，summary 文案，on_skip `none`） |
| `scripts/domain/resolver.gd` | 新命令 `rest`：校验所在节点 type 为 rest、`node_flags` 未用过（用过 → `rest_already_used`）；恢复气血/真元（钳制上限）；append_event reason `rest_recovered` |
| `scripts/domain/action_preview_service.gd` | match 增 `"rest"` 分支：恢复卡（executable=未用过，展示"气血 +2 / 真元 +2"，预期收益文案）；第 32 行 leave 白名单同步 |
| `scripts/domain/display_text.gd` | 节点标签/动作文案（如有集中表） |

### 测试（tests/unit/test_rest_node.gd）

1. 受伤后 rest → 气血/真元恢复且不超上限；寿元不变。
2. 第二次 rest → `rest_already_used`。
3. 非 rest 节点 rest 命令 → 拒绝。
4. 预览：rest 节点出现恢复卡；用过节点卡片不可执行。
5. 渲染回归：`test_v3_ui_sync` 每节点类型有按钮（rest 自动覆盖）。

## T11 寿元里程碑（P8-A）

### 规则（已裁定）

起始 60 不变；两处里程碑收入（入表可配）：结清阶段账（`stage_one_ledger` 结算成功）＋10；击杀 BOSS（`record_boss_defeated` 成功）＋10。其余不增。

### 改动点

| 文件 | 改动 |
| --- | --- |
| `data/pacing.json`（新建） | `{"lifespan_milestones": {"stage_one_ledger": 10, "boss_defeated": 10}}`；ContentCatalog 加载 + 整数校验（非负） |
| `scripts/domain/resolver.gd` | `_settle_feeding` 成功后按表加寿元（append_event reason `lifespan_milestone_gained`，targets 记里程碑 id）；`record_boss_defeated` 同（两处共用助手 `_grant_lifespan_milestone(state, catalog, milestone_id)`） |

### 测试（tests/unit/test_lifespan_pacing.gd）

1. 结清阶段账（stone 足够）→ 寿元 +10，事件 reason `lifespan_milestone_gained`。
2. 重复结算/未到达节点 → 不重复加。
3. `record_boss_defeated` → 寿元 +10。
4. 表缺失数值（tuned 目录删条目）→ 不加、不报错。
5. 表负数 → catalog 校验报错。

## T12 资质→真元上限公式（P9-自定义）

### 规则（用户裁定，数值表草案待批）

- 等级挡位：一转→低阶、二转→中阶、三转→高阶、四转与以上→巅峰；
- `essence_max = floor(挡位基础真元 × 资质百分比 / 100)`；
- 资质为百分比（甲 140% / 乙 120% / 丙 100% / 丁 80% / 戊 60%）；丙为凡人基准；
- 数值表（草案）：低阶 4 / 中阶 6 / 高阶 9 / 巅峰 12 —— 初始状态（丙资质、一转）= 4，与现状一致，零回归；
- 资质获得途径后续设计，本批只落地公式与数据口。

### 改动点

| 文件 | 改动 |
| --- | --- |
| `data/aptitude.json`（新建） | `{"stage_essence_base": {"low": 4, "mid": 6, "high": 9, "peak": 12}, "rank_tier": {"1": "low", "2": "mid", "3": "high", "4": "peak"}, "aptitude_pct": {"jia": 140, "yi": 120, "bing": 100, "ding": 80, "wu": 60}}`；ContentCatalog 加载 + `_is_integral` 校验 |
| `scripts/domain/essence_capacity.gd`（新建，`class_name EssenceCapacity`） | `essence_max(state, catalog) -> int`（公式纯函数）；`rank_tier(cultivation)`、`aptitude_pct(aptitude)` 助手 |
| `scripts/domain/run_state.gd` | `new_run` 不再写死 4，改为 `EssenceCapacityScript.essence_max(...)`——但 new_run 在 catalog 之外！**决策**：`new_run` 保持默认（后续由 controller 用 catalog 刷新）？否——改为：`new_run(run_seed, meta=null, catalog={})` 可选 catalog；空 catalog 用默认表值（与现状一致 4）。`_cultivate_rank_two`（resolver）突破后按目录刷新 `cave_aperture.essence_max` |
| `scripts/domain/save_repository.gd` | 读档后 essence_max 兜底按公式重算（catalog 传入处）——若改动面大则记录为后续 |
| 展示 | 预览/HUD 显示 essence_max（现有 HUD 已显示真元，改值自动体现） |

### 测试（tests/unit/test_essence_capacity.gd）

1. `essence_capacity.essence_max`：丙/一转 = 4；丙/二转 = 6；乙/三转 = floor(9×1.2)=10；甲/巅峰 = floor(12×1.4)=16。
2. 突破（cultivate_rank_two）后 essence_max 上升且 essence 现值不丢。
3. 新开 run（默认目录）essence_max=4 与旧行为一致。
4. 表缺失键 → 回退默认（4）。

## P12 节点预算（用户裁定：取消冒烟预算约束）

- 记录：非首局生成不再约束 10–14；T5 锚点保底与收敛规则保留；不加断言。
- 评审 §4 P12 行标注"已裁定：取消约束"；AGENTS.md 任务入口随后更新。

## 验收与风险

- 每 Task 独立提交；失败测试先行；全量 `tools/test.ps1`（224+6 基线）→ `check.ps1`。
- 回归重点：`test_smoke_outcomes`（T9 门禁可能影响，按其构造补标记）、`test_v3_ui_sync`（T10 新节点渲染）、`test_v2_economy_resolver`（T11 settle_feeding 加收益可能改变其断言——若断言 stone 之外字段需核对）、`test_v3_run_state_gu_instances`（T12 essence_max 默认值不变应无影响）。
- 边界：新 JSON 数值 `_is_integral`；寿命/门禁/恢复全部入事件日志；UI 只投影。

> 本规格待批准；P9 数值表（挡位基础/资质百分比）为草案，批准时如有异议可在批注中给出替换数值。