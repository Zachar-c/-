# Q8_SESSION_HANDOFF.md — Q8-IMPLEMENT 会话交接（2026-09-12）

> 接手者从这里开始。本文档覆盖 2026-09-12 会话完成的 Q8-IMPLEMENT 全程（8/8 步）、
> 改动面、验证状态、遗留与下一步。所有断言可在列出的验证命令中复现。

## 0. 一句话状态

Q8 Grammar V2（效果语法管线）已按用户批准的 8 步序全部实施并通过全量验证：
**未提交，全部改动在工作树**（master 分支，HEAD=552aa99），等待用户验收后合入。

## 1. 本次会话完成了什么（8 步序）

| 步 | 内容 | 验收 |
|---|---|---|
| 1 | 48 只显式蛊逐只对拍基线（非抽样） | `test_q8_grammar_baseline.gd` 46 行 BASELINE 表，453 asserts 零漂移 |
| 2 | Grammar resolver 管线骨架 | `scripts/domain/v1_grammar_pipeline.gd`（gate 段独立文件） |
| 3 | selector（self/enemy_first/enemy_all）/ condition 三谓词 / consume_status | SELECTOR_MATRIX 冻结矩阵，非法组合零消耗拒绝 |
| 4 | sealed 门禁 / weaken_intent（H3 数据化） | 敌意图带 `damage_intent` 属性，禁硬编码 skip |
| 5 | delay（先付费后延迟） | `delayed_effects` 表，gate 形态锁 schema 级最前 |
| 6 | 12 只验证蛊数据（gu.json 9 只改动） | `test_q8_12_gu_slice.gd` 13 tests 全绿 |
| 7 | 6 个决策场景回放（S1–S6） | `test_q8_scenarios.gd` 12 tests 全绿 |
| 8 | 全量验证 | unit 1335/1337、integration 32/32、check 链全绿、交互门 17 屏三键全空 |

## 2. 硬约束（全程生效，接手者不得违反）

见 `GU_EFFECT_GRAMMAR_V2_FINAL.md` §12（本会话落档）：

- **H1 成本提交顺序**：`can_activate → trigger → condition(false→结束) → cost commit → selector → modifier → operation`。condition 落空必须短路在 cost commit 之前，禁 cost-then-check。
- **H2 consume_status 原子事务**：验证→计算→提交结算→清除，同一次确定性结算（纯函数同副本天然原子），禁 clear-then-strike。
- **H3 sealed 数据化**：门禁读意图 `damage_intent` 属性裁决，禁 `if sealed > 0: skip()` 硬编码。非伤害意图不受门禁、不消耗 sealed。
- **H4 enemy_first** = 「当前敌人行动队列的第一个存活目标」，不是数组第一个元素。

未来项禁令（一律不实现、不预留钩子）：on_kill、on_turn_end、敌三轴、tag 网络、新 Buff、新操作、per-target selector、shift 语义改动、durability 内容化。

## 3. 改动面（未提交，全部在工作树）

**修改：**
- `scripts/domain/v1_battle_resolver.gd` — play_gu 插 gate；`_apply_effect` 重排（strike/consume/weaken/delay 分支）；`_build_enemies` 加 `damage_intent`/`intent_weaken`；`_resolve_enemy_intent` H3 重写；`_fire_delayed_effects`/`_clear_enemy_status` 新增
- `scripts/domain/content_catalog.gd` — `V1_EFFECT_KIND_IDS` += weaken_intent；`V1_STATUS_IDS` += sealed；weaken_intent 进 amount 校验组
- `scripts/presentation/snapshots/snapshot_text_util.gd` — weaken_intent 文案分支 + sealed→「封印」
- `data/gu.json` — 9 只显式效果（A4/B1/B2/B3/B4/C1/C2/D1/D2；A1–A3 已显式未动）
- `docs/contracts/2026-09-02-domain-ui-contract.md` — Battle 行回写 `intent.damage_intent`/`intent_weaken`/`statuses.sealed`/`delayed_effects`
- `tests/unit/test_battle_command_facade.gd` — 期望字典补 `damage_intent: false`

**新增：**
- `scripts/domain/v1_grammar_pipeline.gd`（管线 gate/resolve_targets/consume_final_amount/SELECTOR_MATRIX）
- `tests/unit/test_q8_grammar_baseline.gd` / `test_q8_grammar_pipeline.gd`（25 tests）/ `test_q8_12_gu_slice.gd`（13）/ `test_q8_scenarios.gd`（12）
- `docs/q8/Q8_BEHAVIOR_BASELINE.md`（48 只对拍推导）+ FINAL/决策日志增补

## 4. 验证状态（复现命令）

```powershell
# Q8 四测试 + 快照契约（秒级）
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_q8_grammar_pipeline.gd,res://tests/unit/test_q8_grammar_baseline.gd,res://tests/unit/test_q8_12_gu_slice.gd,res://tests/unit/test_q8_scenarios.gd -gexit
# unit 全量（约 5 分钟，后台跑）
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir res://tests/unit -gexit -glog=2
# integration 全量（约 1 分钟）
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir res://tests/integration -gexit -glog=2
# 交互门（约 2.5 分钟）
godot --headless --path . -s tools/verify_interaction_loop.gd
```

- unit：1337 tests / 1335 过（44507 asserts）
- integration：32/32（1477 asserts）
- 启动探针 exit 0、`check_contract_drift.gd` ok（168 标识符）、`git diff --check` 干净
- 交互门：17 屏 `dead=[] / no_ui_click=[] / occluded=[] / occluded_known=0`

## 5. 遗留与待裁定

1. **存量 flaky（非 Q8）**：`test_t5a_confirm_toast::test_npc_talk_buttons_use_snapshot_labels_and_unique_action_ids`——基线 worktree 单跑同样挂，全量跑靠时序运气过（`await 3` 帧不足）。建议单独修复，未擅动。
2. **S5 规格差异待用户裁定**：切片文档 §F-S5「selector 指定乙」在 FINAL §5 冻结三选择器下不可表达（enemy_all 被 SELECTOR_MATRIX 拒绝；per-target 指定属未批空间）。回放以 H4 语义落（甲死 → enemy_first 跳乙）。若需 per-target selector 属规格变更。
3. 引擎事实新增（回放中发现，未处理）：hp 0 的敌不经死亡清理仍照常行动；缺省 `thought_cost=1` 对所有蛊生效（FINAL §4 缺省链）。

## 6. 下一步（既定路线）

1. **Q8-F 经济**（任务 #13）——C/D 验证后启动
2. **Q8_RETROSPECTIVE**（任务 #15）
3. 存量 flaky 修复（可选）
4. 提交：Q8 改动未提交；提交时排除 `.claude/`、`data/dialogues/events.dialogue` 本地修改、截图目录与 `__pycache__`

## 7. 接手者必读坑（本会话踩过）

- **同文件多处 Edit 必须串行**：并行发多个同文件 Edit 全报成功但只有部分落盘（读-改-写竞态）。
- **数据键新增必须同步 content_catalog 白名单**：`run_controller.start_new_run` 把 validate 当启动闸，1 条校验错误 → state=Nil → 全域 controller 测试雪崩（本会话 91 failing 事故）。
- **转数门同时卡定义 rank**：rank2+ 定义蛊在 cultivation=1 时被拒 `insufficient_qi_quality`；测试 fixture 须 `run.cultivation = 10`。
- **GUT 单文件必须用** `-s addons/gut/gut_cmdln.gd -gtest=res://... -gexit`（直调形式挂 banner）。
- **GUT 目录跑**：`-gdir res://tests/unit` 空格分隔（= 形式被 PowerShell 拆开）。
- **unit 全量约 5 分钟**：必须后台跑；RID/ObjDB 泄漏为已知遗留（AGENTS.md 待办）。
- **区分存量 vs 新增失败**：跑 worktree 基线对比（`git worktree add ../x HEAD` + 拷 `.godot`），勿凭印象。
- PowerShell 工具本机输出通道曾失效（exit 0 无 stdout）；bash 调 ps1 被安全拦截——用 Godot 直调等价链（`tools/test.ps1`/`check.ps1` 核心见 §4）。
- 显式效果数据无 "self" 哨兵解析（哨兵仅 default_v1_effect 路径）；流派名写实际名（如 "blood"）。
- 手写 `.tscn` ext_resource 只写 path+id；本会话未动 tscn，纪律照旧。
