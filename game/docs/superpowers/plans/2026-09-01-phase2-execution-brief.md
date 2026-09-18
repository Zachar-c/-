# 阶段二执行交接单：中央数值实装（T2.1 + T2.2）

> 日期：2026-09-01
> 上级计划：[2026-09-01-gu-system-economy-combat-implementation.md](2026-09-01-gu-system-economy-combat-implementation.md)（10 阶段 / 20 提交任务）
> 权威规格：`docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md`——实现前**必须阅读** §10（数值与防御）、§11.2/§11.4（真元成本与自然恢复）、§14.1-§14.3（肉身与超载）、§17.1（中央平衡配置清单）、§18（迁移纪律）。本文是交接摘要，规格原文是唯一裁定依据。
> 仓库约束：遵守 `AGENTS.md` 全部条款（命令边界、事件日志不可变、种子化确定性、预检同源、只读目录禁区等）。

---

## 0. 当前基线（开工前先核对）

- 分支 `master` @ `a346382`，工作树干净，与 `origin/master` 同步。开工前跑 `git status --short --branch` 确认。
- 阶段一（T1.1 `1ae8cd9`、T1.2 `740e4c7`）已合入：`SAVE_VERSION=4`、`data/balance.json`、`scripts/domain/gu_balance.gd`、ContentCatalog balance Schema、resolver 行数门禁（cap 2502/1516）。
- **全量回归当前 11 个失败（962 测试 / 950 绿）**，分两类：
  1. **T1.1 回归 ×3**：`tests/unit/test_save_repository.gd:42/50/58` 断言 `load_run_from_data(...).is_empty()`，但 T1.1 把失败路径改为返回非空拒载字典 `{"ok": false, reason, message}`。
  2. **9/1 批次遗留旧红 ×8**（先于阶段一存在）：
     - `scripts/ui/hand_panel.gd` 解析错误：第 18/30 行引用类型 `GuHandCardView` 报"Could not find type"，但 `scripts/ui/card_view.gd` 确实声明了 `class_name GuHandCardView`——**先怀疑 `.godot/global_script_class_cache.cfg` 陈旧缓存**（删除 `.godot` 重建再跑），确认是缓存则零代码改动；确认是真问题再改代码。连带 `tests/unit/test_hand_panel.gd`、`tests/unit/test_card_theme_tokens.gd` 的主题断言失败（gu_theme 挂载、HandBox separation=12 等）。
     - `tests/unit/test_soul_capacity.gd:52` 调用 `BattleResolver._backlash_for_activation()`，该静态函数已被 9/1 战斗整合删除（现仅有 backlash 诅咒伤害相关新逻辑，`battle_resolver.gd:550` 附近）。先在 9/1 合并提交（`a2d981f`/`d5b47f9`/`02e7d3b`）里找替代物；是改名则改测试指向，是语义被替代则最小适配。**不得整文件删除**（soul_capacity 的清退属于阶段十 T10.1-③）。

---

## 任务 0：阶段一收尾补丁（两个独立小提交，先于 T2.1）

> 目的：把全量回归修到全绿，否则 T2.1/T2.2 的退出条件（全量绿）无法成立。这是补丁，不是新任务；不得夹带任何 T2.x 内容。

### P0.1 存档失败契约收口（提交 A）

- 问题：`save_repository.gd` 中 `load_run()`（第 41 行）失败仍返回 `{}`，而 `load_run_from_data()`（第 84 行）失败返回非空拒载字典——同一模块两种失败契约。真实载入路径上 `schema_v4_required` 永远到不了 UI（`run_controller._save_load_feedback` 显示的是 diagnosis 通道的笼统文案）；而 `run_controller._restore_game`（第 444 行）用 `is_empty()` 判失败并直接取 `loaded["state"]`，一旦接通拒载字典即崩溃。
- 修法（二选一，以改动小、调用方清晰为准）：
  - 方案 1：`load_run()` 失败时透传拒载字典；`_restore_game` 改为先判 `ok` 字段；`_save_load_feedback` 优先展示拒载字典的中文 message（含"大厅进度、蛊方图鉴与已解锁信息已保留"）。
  - 方案 2：`load_run_from_data()` 失败恢复返回 `{}`（拒载信息走 diagnosis 通道），撤掉非空拒载字典，`test_save_gate_v4.gd` 相应改为断言 diagnosis 的 reason/message。
- 同步修复 `tests/unit/test_save_repository.gd:42/50/58` 三处断言为契约一致的写法（如断言 `ok == false` + reason）。
- 验收：`tools/test.ps1 -Test "tests/unit/test_save_repository.gd"` + `-Test "tests/unit/test_save_gate_v4.gd"` 全绿；schema_v4 场景的玩家可见文案在选定的方案里可达（写一条断言证明）。

### P0.2 9/1 批次遗留旧红最小修复（提交 B）

- 按 §0 所述顺序处理 hand_panel 缓存问题与 test_soul_capacity 陈旧调用；只做让旧测试恢复通过的最小改动。
- hand_panel 主题断言若在缓存重建后仍红，逐条核对 `gu_theme.tres` 挂载与 separation 值的实际来源再修；不得改测试数值迁就实现。
- 验收：`tools/test.ps1 -Test "tests/unit/test_hand_panel.gd"` + `-Test "tests/unit/test_card_theme_tokens.gd"` + `-Test "tests/unit/test_soul_capacity.gd"` 全绿。
- **退出条件（任务 0 完成）**：`tools/test.ps1 -Suite all` 全量 0 失败。此后任何 T2.x 提交都必须保持全绿。

---

## T2.1 数值公式与锚点（提交 C）

- **范围**：仅 `scripts/domain/gu_balance.gd` 函数体实装 + `data/balance.json` 参考值复核 + 新增 `tests/unit/test_central_numbers.gd`。不改任何现有调用行为（公式挂接到战斗/蛊师在 T3.2/T4.x 才发生）。
- **必须同时纠正阶段一审查发现的骨架偏差**（否则 T2.1 锚点断言无法成立）：
  1. `natural_recovery(aptitude)`：现骨架签名是 `natural_recovery(cat)` 且返回 `0.1*0.1=0.01`（这是"恢复成本"）。规格 §11.4 是按资质的恢复速率，锚点 `0.7/1.0/1.5`。按规格改签名与语义。
  2. `beast_scale(rank)`：现返回 `2^rank`（1..32）。锚点要求气血/力量/承载 `100..3200`（即 `human_base_health * rank_step_ratio^rank`），同级重击 `20..640`、固定防御 `4..128`。按规格 §14.3 实装，具体以规格原文为准。
  3. `actual_cost_percent(native, gu_rank, cultivator_rank)`：现骨架是 `base_percent * weight`，未实现 §11.2 高转真元向下折算（如 2 转蛊师催 1 转 10% 蛊 = `0.1*2/4=5%`）。按规格改签名与公式。
  4. `human_standard_heal` 第 38 行写死字面量 `0.2`——必须改为读取 `standard_hit_ratio` 键，消除该参数的第二定义点（单一真值红线）。
- **逐数断言（test_central_numbers.gd，先红后绿）**：`rank_multiplier(1..5)=1/2/4/8/16`；`standard_gu_power=40/80/160/320/640`；固定防御 `4/8/16/32/64/128`；治疗 `20/40/60/80/100`；`beast_scale` 气血/力量/承载 `100..3200`、同级重击 `20..640`、固定防御 `4..128`；徒手 `100*0.2=20`；超载公式（§14.2：只按超出承载部分自伤）；自然恢复 `0.7/1.0/1.5`。
- 所有函数保持纯静态、参数取自 `cat["balance"]`（经 ContentCatalog Schema 校验），不得写死数组。
- 验收：`tools/test.ps1 -Test "tests/unit/test_central_numbers.gd"` + `-Test "tests/unit/test_resolver_growth_gate.gd"` + `-Suite all`。
- 退出条件：锚点与规格 §10/§14 表逐位一致；全量绿；resolver/battle_resolver 行数不增。

## T2.2 内容数据档位化（提交 D）

- **范围**：`data/gu.json`、`data/enemies.json`、`data/loot_tables.json`、`data/shops.json` 条目改声明 `rank / power_tier / cost_tier / feed_tier / value_tier` + 例外条目附 `override_reason`（规格 §17.1 末段）；`ContentCatalog` Schema：非 override 条目出现跨转数值字面量（如敌人直接写 `3200` 气血）即拒绝。
- **先红后绿**：新增 `tests/unit/test_content_tier_schema.gd`——先造一条写死数值的假条目跑红，修数据后跑绿；同时更新 `tests/unit/test_content_catalog.gd`。
- **最小实现**：Schema 键 + 现有内容表逐条补 tier 字段。数值仍由 GuBalance 公式导出，**本批不切换任何运行时行为**（行为切换在 T4.x/T10.1）。
- 验收：`tools/test.ps1 -Test "tests/unit/test_content_tier_schema.gd"` + `-Test "tests/unit/test_content_catalog.gd"` + `-Suite all`。
- 退出条件：全量内容表过 Schema；无内容对象复制中央最终值。

---

## 全局纪律（每一批）

1. 每任务独立提交，禁止跨任务混合：`feat(spec-v4): T2.1 ...` / `test(spec-v4): T2.1 先红测试`；补丁提交用 `fix(spec-v4): P0.x ...`。
2. 先红后绿：每条新测试必须先在现状下失败（把红的输出留档进提交说明或完成报告）。
3. resolver 增长门禁：`resolver.gd` 不得新增行数（当前 2501 / cap 2502，仅 1 行余量），`battle_resolver.gd` ≤ 1516；T2.x 不应触碰这两个文件。
4. 禁区：`分支：六卷精编版/`、`肉鸽设计-原始数据/`、`豆包/`、`旧稿归档_不采用/`、`重写稿/`、`.worktrees/`、`vendor/` 一律只读。
5. 标识符 ASCII，玩家可见中文 UTF-8；数值一律进 `balance.json` 过 Schema，不写进代码。
6. 测试基线只增不回退：任务 0 完成后的全量绿是底线，T2.x 任一提交不得引入新失败。
7. 不夹带：发现跨阶段缺陷（含 §0 未列出的新问题）记录到完成报告，不在 T2.x 提交内顺手修。

## 完成报告要求（供审查）

逐项列出：每个提交的 hash 与改动文件清单；每条验收命令及结果（通过/失败数）；P0.1 选定的方案与理由；hand_panel 问题最终定性（缓存 or 代码）与处理方式；`test_soul_capacity.gd` 的替代函数定位结论；未验证风险与遗留问题。全量 `-Suite all` 的最终汇总数字（Tests/Passing/Failing）必须如实附上。
