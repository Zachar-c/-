# S2–S5 五流派收口批 实施计划（就地执行）

- 日期：2026-08-25
- 分支/工作树：`task1-vendor-open-rpg` 就地执行（用户裁定不另开分支），仓库工作树 `.worktrees/task1-vendor-open-rpg`，基线 `bb0b46f`
- 优先级顺序：**S5 → S3 → S2 → 全局冒烟 (T5)**（S4 领域侧已由用户 `1c9d3ec` 交付：三死线常驻预警+危险高亮+精准死因+结算归因面板，本批不再实施）
- 执行方式：子代理逐任务（fresh implementer + task reviewer），控制器沿 `.superpowers/sdd/progress.md` 记账
- 目标：五流派（血/气/力/魂/炼）内容与机制收口，冒烟矩阵全绿

## 运行中更新（2026-08-25）

- 用户并行交付 `1c9d3ec`（S4）：`run_snapshot_builder.gd`、`display_text.gd`、`data/names.json`、`ui/screens/battle_screen.guitkx`/`encounter_screen.guitkx`/`ending_screen.guitkx`、`ui/widgets/gu_death_line_warning.guitkx`、`smoke_render.gd`。**尚未推远端**（远端仍 `bb0b46f`）。
- **T1 首轮实现者失败**：遗留 3 个测试文件的 S5 规格测试（RED，未提交），失败点=在内存 tuned 的 loot 表把 `gu_pool.weights` 设为 `{"common":1}` 后，部分种子仍卷出 rare 桶 → 续跑必须定位 `loot_resolver.gd` 真实的稀有度来源并正确强制 common-only；未产生任何数据/实现改动。RED 规格测试已提交 @ <以提交时为准>。
- 保护文件增补 `scripts/domain/map_generator.gd`（用户并行改动，1c9d3ec 未含）。
- 编辑器刷新产生的 `addons/**/*.import`、`assets/**/*.import` 为噪音，永不 stage。
- **T1 两次实现者失败后拆解（2026-08-25）**：T1a 数据+校验（refine 系加入、soul `name_zh`→`name`、五系存在+display-name 校验）→ T1b 专属池表 `school_pools.json` + 池校验（4 条 hint）→ T1c loot 学院过滤。**loot 真因已定位**：`loot_resolver.gd` `_roll_gu` L94–99 纯种子选桶、无学院维度（非稀有度问题）；修复=按 `state.school` 专属池与桶取交集，无交集回退全桶（qi 用例）。

## 全局约束（每个任务都绑定）

1. **工作树纪律（最高优先）**：以下文件属于用户并行会话的未提交改动，**任何任务不得读写、不得 git add、不得删除**：
   - `ui/screens/map_screen.guitkx`
   - `ui/widgets/gu_resource_chip.guitkx`
   - `ui/widgets/gu_top_bar.guitkx`
   - `scripts/domain/map_generator.gd`（2026-08-25 复核发现新增）
   - 禁止 `git add -A` / `git add .` / `git commit -a` / `git checkout` / `git reset --hard` / `git clean`。只对**自己新增/修改的文件**显式 `git add <path>` 后提交。commit 后 `git status` 必须仍显示这些保护文件为未提交修改。
2. **标识符 ASCII**：JSON 键、`id`、测试名、commit message 一律 ASCII；玩家可见中文仅放 UTF-8 文本表（`names.json`/`gu_names.json`）。
3. **数据驱动**：蛊、节点、NPC、敌人、商店、配方、专属池一律 JSON 配置；数值/配置 JSON 是唯一真值来源，经 `content_catalog.gd` 类 Schema 校验拦截。
4. **TDD**：先写可失败测试，再最小实现；测试可纯 GDScript 领域逻辑，UI 不直接改状态。
5. **验证命令**：工作树根 `tools/test.ps1 -Suite unit` / `tools/test.ps1 -Suite integration` / `tools/check.ps1`。Godot 控制台：`%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`（或经 `tools/godot.ps1`）。新建 `.gd` 若 headless 未刷新类缓存：`<godot> --headless --editor --quit --path .` 重建。
6. **回归基线**：unit 397 / integration 6（全绿，若实测不同以实测为准并记录）。
7. 不触碰 `分支：六卷精编版/`、`豆包/`、`旧稿归档_不采用/`、`重写稿/`、`肉鸽设计-原始数据/`（只读语料/清单）。

## 现况盘点（2026-08-25 控制器核实）

- `data/gu.json`：**200 蛊**，五系各 40（`school` ∈ blood/force/qi/refine/soul），rarity ∈ common(120)/rare(60)/epic(20)，无 legendary 实体。
- `data/schools.json`：**只 4 系**（blood/qi/force/soul），**缺 `refine`（炼道）**；每系有 `name`/`summary`/`starter_gu_ids`(5)，**但 soul 误用 `name_zh` 键**（不一致 bug）。
- `scripts/domain/content_catalog.gd`（或其同类）校验：每系必须有 `starter_gu_ids` 且引用的蛊存在；漏一系即报错。
- `scripts/presentation/run_controller.gd::_inject_school_starters` 读 `schools[school].starter_gu_ids`，注入 `school_starters_injected` 事件（reason="school_starters_injected"）。
- 派单后控制器会核对 `git status` 只含任务自身文件 + 那 3 个 `ui/` 文件。

---

## Task 1 — S5 五流派初始卡组与专属池数据表

**目标**：补全五系初始卡组（5 系 × 5 蛊）与五系专属池数据表，目录校验与现有系同样严格。

**范围**：
1. `data/schools.json`：
   - 修复 soul 键不一致：`name_zh` → `name`（值保持 `魂道`）。
   - 新增 `refine`（炼道）系：`name`=`炼道`、`summary`（贴合已定“战斗内简易炼蛊”方向，措辞与其余系一致风格）、`starter_gu_ids` = 从现有 40 个 `gen_refine_*` 蛊中选 5 个（角色分布尽量错开：attack/defense/movement/healing/recon/logistics），所选蛊必须存在且 `card_blueprint_ids` 在 `data/cards.json` 可解析。
2. 五系专属池数据表：新增 `data/school_pools.json`（或并入 schools.json，实现者自裁并说明理由）：每系一个专属池（排除其他系），用作该系奖励/开局侧抽取时的权重或白名单。落地方式实现者先读 `data/loot_tables.json` + `scripts/domain/loot_resolver.gd` 决定最小一致接法（例：同系奖励时专属池条目加权/优先；绝不跨系）。
3. 文案补齐：所选 5 个 refine starter 与专属池条目在 `data/gu_names.json`（及 `names.json` 相关表）有中文名；缺失则补。
4. 校验与目录：`content_catalog` 类校验覆盖 refine 系必填、专属池 id 存在且所属系正确、与 gu 的 `school` 字段一致。
5. 测试：新增/更新 `tests/unit/test_school_starter_data.gd`、`test_school_framework.gd`、`test_content_catalog.gd`、`test_free_mix_ominous.gd` 等对 **5 系** 的断言（任何写死 4 系的计数断言改为 5 / 数据驱动），并加专属池隔离断言（A 系专属不含 B 系蛊、专属池条目 id 属于对应系）。跑 unit+integration 全绿。

**验收**：unit+integration 全绿；初始卡组五系各 5；专属池每系非空且被奖励路径使用（有测试证明隔离/加权生效）；目录校验对缺 refine 系或错配专属池会报错。

**交付物**：数据文件改动 + 以 `git add <自身文件>` 提交（ASCII message，前缀 `feat(s5):`）。

---

## Task 2 — S3 材料收口 + 气道材料保底

**目标**：局内材料入资源表（一等公民资源），气道专属材料掉落带保底。

**范围**：
1. 盘点现有材料模型：`data/shop`/`material` 相关表、`RunState` 资源字段、掉落产出。若材料目前只是零散物品，收口为 `RunState` 资源表字段（沿 `STATE_FIELDS` 单一真值源——见 `scripts/domain/run_state.gd` 现有 `STATE_FIELDS` 驱动 `_copy/to_save_data/_apply_after`）。
2. 气道材料保底：气道类材料掉落带保底计数器（沿 `data/loot_tables.json` 已有 `pity` 形态与 `scripts/domain/loot_resolver.gd` 的保底实现），多次未出气道材料后强制补给，计数只抬品质/类别下限不指名具体条目。
3. 校验/目录：材料条目、资源键、保底配置纳入 `content_catalog` 校验。
4. 测试：新增 `tests/unit/test_material_model.gd`（资源化、保存/恢复、上限）、`test_material_pity.gd`（保底触发与重置、商店旁路不计）。全绿。

**验收**：材料作为资源进出流通、存档往返不丢、气道材料保底生效且有测试；unit+integration 全绿。

**交付物**：领域 + 数据改动，`git add <自身文件>` 提交（`feat(s3):`）。

---

## Task 3 — S2 炼道流派战斗内炼蛊

**目标**：炼道流派战斗内简易炼蛊可玩（方向：定向/组合/盲盒；炸炉入反噬；失败补偿永不到 100% 且 Run 内清零；空位校验；预览+二次确认只影响 UI 层提示，领域层命令与校验独立可测）。依赖 T1（refine 系补齐）与 T2（材料资源化）。

**范围**（实现者先读 `scripts/domain/battle_resolver.gd`、`scripts/domain/resolver.gd` 现有命令表 `_dispatch` 与 `curse_registry.gd` 反噬机制再定接法）：
1. 战斗内炼蛊命令（如 `battle_synthesize`）：消耗材料与蛊位，产出新蛊实例（或临时卡）；盲盒分支带炸炉失败入反噬；失败补偿计数器按 §16.18：永不到 100%、Run 清零、`synthesis.json` 类配置驱动成功率，契约修改经 `meta_rules`。
2. 空位/容量校验：蛊槽硬上限与魂魄派生投入上限校验，失败有明确文案；消耗寿元/魂魄类代价先预检（死亡可预见）。
3. 数据表 `data/synthesis.json`（或扩展配方表）落地成功率/失败补偿/炸炉率；目录校验。
4. 测试：`tests/unit/test_battle_synthesis.gd`（定向成功、盲盒失败入反噬、补偿计数、Run 内清零、空位校验、预检文案），+ 更新 `test_v3_soul_and_backlash` 类回归。全绿。

**验收**：战斗内能炼、失败有反噬与补偿、边界有测、unit+integration 全绿。

**交付物**：领域 + 数据改动，`git add <自身文件>` 提交（`feat(s2):`）。

---

## Task 4 — S4 死线数据/精准死因领域侧

**目标**：三死线（寿元/魂魄/反噬）可视化所需的**领域数据侧**与**精准死因归因**收口。UI 可视化由用户并行接管（`.guitkx`，本任务禁碰 `ui/`）。

**范围**：
1. 盘点现有：`data/names.json`、`RunSnapshotBuilder`（`scripts/presentation/run_snapshot_builder.gd`）是否已产出 death_lines 数据与阈值；`test_death_report_builder.gd`/`test_lifespan_pacing.gd`/`test_trade_death_precheck.gd` 现有覆盖。**先读 + 复跑，把缺口（不是重写）补成：** snapshots 的 death_lines 阈值与当前值一致从领域导出、反噬结算前预检已有文案。
2. 精准死因：死亡结算页死因从不可变事件日志归因（`ending`/`blow_text`），死因字段驱动（`ending_type` 字段化，结局结算统一走 `RunSnapshotBuilderScript.ending`）。补测试：多原因时归因优先级、日志缺事件时回退文案。
3. UI 层只读消费：若需暴露给 `.guitkx` 的新字段（非 UI 文件改动），仅补 snapshots 字段；`ui/` 任何 `.guitkx`/`.tscn`/`.gd` 不做改动。

**验收**：unit+integration 全绿；死线阈值/当前值、死因归因均有测试覆盖；`git status` 不含 `ui/` 改动。

**交付物**：领域 + 测试改动，`git add <自身文件>` 提交（`feat(s4):`）。

---

## Task 5 — 全局冒烟矩阵（五流派横切）

**目标**：跑通跨五流派最小闭环冒烟并成文。

**范围**：
1. 全量回归：`tools/check.ps1`（unit + integration）全绿并记录数字。
2. 横切冒烟：对五派各跑最小闭环验收（开局契约→流派选择→获取蛊→商店→（炼道）合成/炼蛊→战斗（含杀招/Boss）→结局结算→大厅清零），尽量以现有 integration（`tests/integration/test_v3_roguelike_vertical_slice.gd` 等）与领域层命令串驱动，不足处补验收测试或脚本命令；记录矩阵结果到本计划同目录的 `2026-08-25-five-schools-smoke-matrix.md`。
3. 结果：记录每系通过/失败与失败原因；失败必须修复至全绿（修复经 review）。

**验收**：五派冒烟矩阵全部 PASS；全量 suite 数字记录；矩阵文档提交。

**交付物**：冒烟矩阵文档 + 必要修复，`git add <自身文件>` 提交（`test(smoke):`）。

---

## 终审与收尾（控制器执行）

- 全批终审：`requesting-code-review` 模板对 S5→T5 全部 diff 做一次全批 review（`docs/superpowers/plans/2026-08-25-review-optimization-plan.md` 曾有 B1–B5 上下文）。
- 推送 `task1-vendor-open-rpg`；更新 master 侧 AGENTS.md 同步进展（master 未提交改动保留）。
