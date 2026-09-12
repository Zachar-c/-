# Q8_RETROSPECTIVE.md — Q8 封版复盘（2026-09-12）

> 范围：Q8 Grammar V2 设计冻结 → 8 步实施 → Q8-POST 验收收口。
> 性质：阶段总账 + 实施回顾 + 失败归因 + 缺陷修复 + 边界登记 + 封版判定。
> 前置：`Q8_SESSION_HANDOFF.md`（实施期交接）、`GU_EFFECT_GRAMMAR_V2_FINAL.md`（语法唯一权威）。
> 本文件是 Q8 阶段的**封版依据**。

---

## 0. 一句话结论

Q8 Grammar V2 **已完成实施并通过验收收口**：unit 1342/1342（44527 asserts）、integration 32/32、
交互门 17 屏三键全空、契约漂移 ok、启动探针 exit 0。
实施期遗留的 1 条存量失败已归因并修复，实施期新发现的战斗语义缺陷（HP=0 敌人仍行动）已修复并加回归测试。
**Q8 封版，可进入 Q8-F 经济阶段。**

---

## 1. 阶段时间线

| 时点 | 事件 | 产出 |
|---|---|---|
| 2026-09-12 上午 | Q8 三阶段审计 + V2 原案 | `CURRENT_EFFECT_CAPABILITY_MATRIX.md`（17 能力 + G1-G10 缺口）、`GU_EFFECT_GRAMMAR_V2.md` |
| 2026-09-12 中午 | R1 修订案 + 行为词典 | `GU_EFFECT_GRAMMAR_V2_REVISED.md`、`WORLD_BEHAVIOR_TAXONOMY.md` |
| 2026-09-12 下午 | R2 验收裁定 + 硬约束 H1-H4 | `GU_EFFECT_GRAMMAR_V2_FINAL.md` §12、`Q8_GRAMMAR_DECISION_LOG.md` D1-D12 |
| 2026-09-12 傍晚 | 8 步实施（Step 1-8） | `v1_grammar_pipeline.gd` 新 + 4 测试文件 + gu.json 9 只 |
| 2026-09-12 晚 | 会话交接 | `Q8_SESSION_HANDOFF.md` |
| 2026-09-12 夜 | 提交 Q8 本体 + 调研产物 | `7cb3267` / `b1d5e95` |
| 2026-09-12 夜 | **Q8-POST 验收收口**（本文件） | 失败归因 + HP=0 修复 + 全量复验 + 封版 |

---

## 2. 8 步实施回顾

| 步 | 内容 | 验收证据 |
|---|---|---|
| 1 | 48 只显式蛊逐只对拍基线（非抽样） | `test_q8_grammar_baseline.gd`，46 行 BASELINE，453 asserts 零漂移 |
| 2 | Grammar resolver 管线骨架 | `v1_grammar_pipeline.gd`（gate 段独立文件，零循环依赖） |
| 3 | selector / condition / consume_status | SELECTOR_MATRIX 冻结矩阵；非法组合零消耗拒绝 |
| 4 | sealed 门禁 / weaken_intent（H3 数据化） | 敌意图带 `damage_intent` 属性，禁硬编码 skip |
| 5 | delay（先付费后延迟） | `delayed_effects` 表；gate 形态锁 schema 级最前 |
| 6 | 12 只验证蛊数据（gu.json 9 只改动） | `test_q8_12_gu_slice.gd` 13 tests |
| 7 | 6 个决策场景回放（S1–S6） | `test_q8_scenarios.gd` 12 tests |
| 8 | 全量验证 | 见 §5 终验 |

**硬约束落地核对（FINAL §12）**：

| 约束 | 落地情况 | 证据 |
|---|---|---|
| H1 成本提交顺序 | ✅ `condition` miss 短路在 cost commit 之前 | 管线测试「condition miss 零成本端到端含 log 无 spent 断言」 |
| H2 consume_status 原子事务 | ✅ 验证→计算→提交→清除，同一副本 | `test consume 原子 9-5=4+清零+单次扣费` |
| H3 sealed 数据化 | ✅ 门禁读 `damage_intent`，非伤害意图不受门禁 | `test sealed 门禁 80 满血+消费清` + 非伤害意图不门禁 |
| H4 enemy_first 语义 | ✅ 行动队列第一个 `hp > 0`（Q8-POST 后全引擎统一） | `test_q8_post_survivability.gd::test_selector_and_action_queue_agree_on_zero_hp` |

---

## 3. 数据结构与新增面

### 引擎（`v1_battle_resolver.gd`）
- `play_gu` 在 cost commit 前插 gate（H1 骨架）。
- `_apply_effect` 重排为阶段标注：`selector → modifier.prepare → operation → modifier.commit`。
- `strike` 分支：`prepare`（consume 定参）→ `resolve_targets` 循环 → `commit`（清状态）。
- 敌意图加 `damage_intent`（bool）语义属性 + 每敌 `intent_weaken`（int）。
- 新增 `_fire_delayed_effects` / `_clear_enemy_status` / `_enemy_is_alive`。

### 新模块（`v1_grammar_pipeline.gd`）
- `gate_miss_reason`：四段资格序 trigger → condition → selector 合法性（SELECTOR_MATRIX）→ consume_status 资格。
- 三谓词：`self_hp_below` / `enemies_alive_gte` / `turn_gte`（未知谓词返回 false，不静默放行）。
- `resolve_targets` / `first_alive_index`（H4 基元）/ `alive_count` / `consume_final_amount`。

### 数据（`gu.json`，9 只）
A4 marked1+support1 / B1 strike4+condition / B2 strike2+consume / B3 strike3+delay /
B4 strike2+support"blood" / C1 status sealed / C2 weaken_intent / D1 strike8+life_cost 2 / D2 strike6+qi6+thought2。

### 白名单（`content_catalog.gd`）
`V1_EFFECT_KIND_IDS` += `weaken_intent`；`V1_STATUS_IDS` += `sealed`；`weaken_intent` 进 amount 校验组。

### 契约与文案
`domain-ui-contract.md` Battle 行回写 4 键；`snapshot_text_util.gd` 增 weaken_intent 文案 + `sealed → 「封印」`。

---

## 4. Q8-POST 验收收口（本次）

### 4.1 失败归因（用户要求的严格区分）

**实施期交接记录为「1335/1337，2 个失败」。实测修正：**

| 项 | 内容 |
|---|---|
| 实测读数 | **1337 tests / 1336 passed / 1 failing**（非 2 个） |
| 唯一失败项 | `test_t5a_confirm_toast::test_npc_talk_buttons_use_snapshot_labels_and_unique_action_ids` |
| 归因方法 | `git worktree add ../q8post-baseline 552aa99`（Q8 之前）+ 拷 `.godot` + 单跑同条测试 |
| 基线结果 | **同样失败**，且是**完全相同的 4 条断言** |
| 结论 | **Q8 之前已有失败，非 Q8 引入** |

**进一步定性（本次新增结论）**：该测试**不是时序 flaky，是稳定失败**——
主仓单跑连续 2 次均挂；基线单跑亦挂。交接文档记的「全量跑靠时序运气过」已不成立。

**根因（诊断探针实证）**：测试断言「每个 talk label 本身是可点按钮」，
但实现（`npc_screen_view._build_talk_row`）渲染的是
**「标题 Label（= 快照 label）+ 固定文案「执行」按钮」的卡片行**——
按钮文案恒为「执行」，不存在文案为 label 的按钮。
即：**测试断言与实现形态不匹配（断言过时），非实现缺陷、非 Q8 回归。**

探针输出（`button text=[执行] ×4` + `label 文本正常渲染`）已作为判定依据，
探针文件为一次性工具，用后即删。

**处置**：按真实契约重写断言（① label 作为可见文本出现；② 按行序点「执行」派发各自 action_id）。
修复后 9/9 绿，且**断言强度提升**（原仅断按钮存在，现断 label 可见 + 每行独立 id）。

### 4.2 HP=0 敌人仍继续行动（战斗语义完整性缺陷）

**缺陷本体：存活判定存在两个事实来源。**

| 文件 | 原判定口径 |
|---|---|
| `v1_grammar_pipeline.gd` | `hp > 0`（H4 落档定义） |
| `action_preview_service.gd` | `alive && hp > 0` |
| `battle_snapshot.gd` | `alive && hp > 0` |
| **`v1_battle_resolver.gd`** | **仅 `alive` 字段** ← 缺陷源 |

一旦 `hp` 归零而 `alive` 未同步，selector 认为敌已死、行动队列认为敌还活着；
更严重的是 **`_check_victory` 永远看不到全灭 → 敌人打不死、战斗不结束**（结果不可预见）。

**TDD 先行**：`tests/unit/test_q8_post_survivability.gd`（5 tests）先跑出 3 red：
- `test_zero_hp_enemy_does_not_act`：甲 hp=0 仍打出 7 伤
- `test_zero_hp_single_enemy_is_victory`：唯一敌 hp=0，phase 仍 `player_action`，玩家被打到 74
- `test_selector_and_action_queue_agree_on_zero_hp`：管线认甲死、行动队列认甲活

**修复口径**：`hp > 0` 为存活唯一事实来源（与管线 / 预览 / 快照三方对齐）。
引入 `_enemy_is_alive(enemy)`，替换 resolver 内全部 5 处判定：
`_current_enemy_index` / `_enemy_index` / `end_turn` 行动循环 / `_settle_marks` / `_check_victory`。
`alive` 字段保留（快照与表现层消费，写入口仍同步），但不再是权威判定。

**修复后**：5/5 绿；Q8 五套 55/55（565 asserts，**48 只行为基线零漂移**）；
战斗与快照全族 82/82（470 asserts）无回归。

---

## 5. 终验证据（Q8-POST 后）

| 门 | 命令 | 结果 |
|---|---|---|
| Q8 五套 | `-gtest=res://tests/unit/test_q8_grammar_pipeline.gd,...5 个` | **55/55，565 asserts** |
| 战斗+快照族 | 10 文件 | **82/82，470 asserts** |
| **unit 全量** | `-gdir res://tests/unit` | **1342/1342，44527 asserts，0 failing**（4m38s） |
| integration 全量 | `-gdir res://tests/integration` | **32/32，1477 asserts** |
| 交互门 | `-s tools/verify_interaction_loop.gd` | **17 屏 `dead=[]` / `no_ui_click=[]` / `occluded=[]` / `occluded_known=0`** |
| 契约漂移 | `-s tools/check_contract_drift.gd` | ok（168 标识符） |
| 启动探针 | `--quit-after 3` | exit 0（RID/ObjDB 泄漏为已知遗留） |
| 空白检查 | `git diff --check` | 干净 |

> unit 从 1337 → 1342：+5 为本次新增存活测试；失败由 1 → 0（t5a 存量失败修复）。
> 尚存 `Orphans 3`，与既有 `Orphans 1` 同性质（已知遗留，非本次引入）。

---

## 6. 已知边界与登记（不在本阶段处理）

### 6.1 S5 selector 缺口（用户裁定：不扩 selector）

切片文档 §F-S5「selector 指定乙」在 FINAL §5 冻结三选择器
（`self` / `enemy_first` / `enemy_all`）下**不可表达**：
`enemy_all` 被 SELECTOR_MATRIX 拒绝；per-target 指定属未批空间。

**裁定（用户 2026-09-12）**：现在不扩 selector。Q8 目标是证明最小模型，不是扩大 DSL。
S5 保留为「当前 selector 能力边界已知」，回放以 H4 语义落（甲 hp 0 → enemy_first 跳乙）。
`test_q8_post_survivability.gd` 已把「管线与行动队列同源」钉死——边界有测试守着。

> 这反而是一次有效验证：**Grammar 已经开始暴露真正的设计边界。**

### 6.2 引擎事实（记录，未处理）

- 缺省 `thought_cost = 1` 对所有蛊生效（FINAL §4 缺省链 qi=essence_cost→1 / thought=1 / life=0）。
- `life_cost` 现网数据仍全 0（三轴死亡半轴休眠）——属 Q8-F/经济阶段议题。
- `enemies.json` 敌人无 true_qi / soul / lifespan 字段（G4 敌侧资源面空白）。

### 6.3 未来项禁令（FINAL §12 持续生效）

一律不实现、不预留钩子：`on_kill`、`on_turn_end`、敌三轴、tag 网络、新 Buff、
新操作、per-target selector、shift 语义改动、durability 内容化。

---

## 7. 协作纪律（本阶段踩过，持续生效）

1. **同文件多处 Edit 必须串行**：并行发多个同文件 Edit 会报成功但只部分落盘（读-改-写竞态）。
   本次 Q8-POST 全程逐条串行 Edit，落点以 `grep` 核对为证。
2. **新增 JSON 键必须同步 `content_catalog` 白名单**：`run_controller.start_new_run` 把 validate
   当启动闸，1 条校验错误 → `state=Nil` → 全域 controller 测试雪崩（实施期 91 failing 事故）。
3. **区分存量 vs 新增失败必须跑 worktree 基线对比**，勿凭印象（本次归因即用此法）。
4. **GUT 跑法**：单文件必须 `-s addons/gut/gut_cmdln.gd -gtest=res://... -gexit`（直调挂 banner）；
   目录跑 `-gdir res://tests/unit`；unit 全量约 5 分钟须后台跑。

---

## 8. 封版判定

| 项 | 判定 |
|---|---|
| Q8 Grammar 设计 | ✅ 冻结（FINAL + DECISION_LOG） |
| Q8 8 步实施 | ✅ 完成 |
| 实施期遗留失败 | ✅ 归因（存量）+ 修复（按真实契约重写断言） |
| 实施期发现缺陷 | ✅ HP=0 敌人仍行动已修复 + 回归测试守护 |
| 全量验证 | ✅ unit / integration / 交互门 / 契约 / 探针 全绿 |
| S5 selector 边界 | ✅ 已登记，不扩张（用户裁定） |

**Q8 封版。可进入 Q8-F 经济阶段。**

> 提交状态：Q8 本体已提交（`7cb3267`）；Q8-POST 改动（`v1_battle_resolver.gd` 存活判定统一 +
> `test_t5a_confirm_toast.gd` 断言修正 + `test_q8_post_survivability.gd` 新增）待提交。
