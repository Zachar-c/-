# Architecture Correction Plan（2026-09-12）

> 性质：只读纠偏审查产物。未改任何代码。等待用户批准后按 Migration Plan 分批执行。
> 证据：run_controller.gd（903 行逐函数）、run_state.gd（全读）、save_repository.gd、v1_battle_resolver.gd、run_battle_flow.gd 及三路只读探查（含行号）。

---

## 1. Current Architecture（实测依赖关系）

```
scenes/main.tscn（只挂 RunController/AudioDirector/TransitionLayer）
  └─ RunController（presentation，903 行）
       ├─ state: RunState                      ← 运行态唯一权威（不可变）
       ├─ route/current_node/current_battle/
       │   current_session/last_*（临时镜像）  ← ⚠ 见 §2
       ├─ submit_command ──┬─ save/load → RunSaveFlow → SaveRepository
       │                   ├─ battle 命令 → RunBattleFlow → BattleCommandFacade → V1.start/_apply
       │                   ├─ 节点会话 → EncounterSessionResolver.apply
       │                   └─ 其余 → Resolver.apply → _dispatch 表 → 命令族静态函数
       └─ _render → RunSnapshotBuilder(13 模块) + RunCommandBuilder
                      → RunScreenRouter.mount_screen(.tscn 屏, 快照只读)
```

- 领域层（scripts/domain/，58+ 文件）：纯函数 + 静态规则，零 signal、零 UI 节点引用（仅 dialogue_manager_adapter 一处 autoload 查找）。
- 存档：RunState.to_save_data → save_repository（SAVE_VERSION 4，键排序 XOR checksum，tmp+rename 原子写；大厅档/Run 档分文件）。
- RNG：MapGenerator/各规则统一 SeededRoll；controller.roll_seed 只产开局种子。

## 2. State Ownership（谁拥有/读/写）

| 状态 | 权威所有者 | 读者 | 写者 | 判定 |
|---|---|---|---|---|
| RunState（run 级全部字段） | RunState 实例（controller.state 持引用） | 快照/流模块只读 | 仅领域规则函数经 `append_event→_copy` | ✅ 单一真状态，`_apply_after` 白名单 + `event_log/seed` 受保护（run_state.gd:365-375） |
| v1 战斗 Dictionary | **controller.current_battle**（run_battle_flow.gd:90 写入） | 战斗快照 | BattleCommandFacade | ⚠ 不在 RunState、不序列化——战斗期第二真状态（见 P1-2） |
| encounter 会话 | RunState.encounter_session（:43） | 同上 | EncounterSessionResolver | ⚠ controller.current_session（:62）是**镜像副本**（run_controller.gd:236-237 同步赋值）——重复状态（P1-1） |
| 地图 route | controller.route（:183） | MapGenerator.visible_nodes | start_new_run 重建 | ⚠ 不在 RunState；存档后靠种子确定性重建（隐式契约，P2） |
| battle2 ledger | RunState.battle2_ledger（持久）+ current_battle2_ledger（运行时，:59/:66） | facade | 五个 accepted turn 位点 | ✅ 有注释定界，暂不动 |
| 大厅 MetaProgress / AppSettings | meta / app_settings | 大厅快照 | RunSaveFlow / RunSettingsFlow | ✅ 与 RunState 分离正确 |
| 快照 | builder 即时投影 | screens 只读 | —（never mutates，battle_snapshot.gd:20） | ✅ 不是状态，是投影 |

**结论**：RunState 是唯一权威，无三套互相同步的真状态；例外是战斗期 `current_battle` 与 `current_session` 镜像两处，均为 P1 级可控债。

## 3. Command Flow（实测）

UI 屏（快照里拿 commands 字典）→ `RunController.submit_command`（唯一入口）→ 四路分发：
1. `save_run/load_run` → RunSaveFlow（controller 内联特判，run_controller.gd:199-211）
2. `travel/dialogue_branch/action_card(event)` → RunTravelFlow / RunDialogueFlow
3. 战斗命令（**硬编码类型表** `use_gu/use_inheritance/end_turn/retreat/basic_attack/basic_dodge/refine/play_kill_move`，run_controller.gd:232）→ RunBattleFlow
4. 节点会话（current_node 非空）→ EncounterSessionResolver；兜底 → Resolver.apply（路由核，205 行 `_dispatch` 表 → 16 命令族）

**问题**：执行器选择（"这命令归谁"）发生在表现层 controller，且战斗命令类型表硬编码——新增战斗命令必须改 run_controller.gd:232（表现层）+ 领域两处，三点同步。

## 4. Event Flow（实测）

- 领域→表现：无事件总线。两条既有通道：① 快照全量投影（每屏）；② 快照 `_gui_state.feedback` 键 + controller.last_feedback（命令级反馈）。
- 战斗动效：battle_screen_view 靠上一帧 diff（`_prev_enemy_hp` 等）驱动红闪/墨迹/盖印——能用但脆，快照 feedback 键是现成的显式替代通道。
- 事件日志（RunState.event_log）：append-only 不可变，只用于存档/归因/测试，不驱动 UI ✅。

## 5. Responsibility Problems（≤10）

| # | 级 | Current | Problem | Why / Risk |
|---|---|---|---|---|
| 1 | **P0** | 多 Agent 并行无成文所有权表，历史上 4 次并行会话物理删除文件 | 流程债先于代码债 | 再来一次删除事故成本远高于任何重构 |
| 2 | P1 | 战斗命令类型表硬编码在 run_controller.gd:232（表现层） | 执行器选择混入 Controller；新增战斗命令三点同步 | 扩杀招/战斗命令时必改表现层，边界最常被踩的位置 |
| 3 | P1 | controller.current_session 与 state.encounter_session 平行 | 重复状态，两处赋值必须同步（:236-237） | 漂移后 UI 显示与领域态不一致类 bug |
| 4 | P1 | current_battle 在 Controller，不入 RunState | 战斗期第二真状态；存档时 v1 战斗态是否完整可恢复未审计（battle2_ledger 已序列化，v1 battle dict 未） | 战斗中存档→读档行为存疑，需专项核实 |
| 5 | P1 | status/buff 结算内联 v1_battle_resolver + curse_registry 直写 cultivator.statuses + 7 处零散读点 | 无生命周期钩子、无统一归属 | 每加一种状态改 2+ 文件（与上份报告一致，Q7 时收敛） |
| 6 | P1 | content_catalog.gd 1540 行三职责合一 | load/validate/白名单不分 | 补流派 6 触点持续加压 |
| 7 | P2 | controller 持 route/current_node/last_*（约 8 个临时字段） | 临时会话状态与领域态混在同一对象，但均有注释定界 | 认知负担；非正确性问题 |
| 8 | P2 | route 不入 RunState，读档靠种子重建 | 隐式契约：MapGenerator 若引入非种子随机即静默破坏 | 现为确定性 ✅，登记即可 |
| 9 | P2 | id 特判链：action_preview_service（thorn_whip_gu ×3、match action_id ×2）、inheritance_claim_rules、social_command_rules | 新内容可能触 if-else 扩展点 | 仅 3 文件，规模小，登记不动 |
| 10 | P2 | Q8 死路径 / regen_pct 双源 / v1_effect 7 kinds 封闭枚举 | 死代码与同名异义误导后来者 | 与上份报告一致，清理批次处理 |

**run_controller God Object 判定：否**。903 行中约 460 行是 W12/A7 拆分后的一行委托（save/debug/settings/battle/dialogue/ending 全有对应 run_*_flow 模块），真实逻辑集中在：命令分发（~110 行）、开局流程（~30 行）、视图切换/渲染/BGM/淡入（~170 行）、UI 绑定（~30 行）。它承担的是**编排 + 表现会话状态**，未拥有领域规则——结构符合"Controller 只编排"目标，不拆。

## 6. Recommended Boundaries（最终职责，均为现状确认或微调，非重设计）

| 模块 | 最终职责 | 现状差距 |
|---|---|---|
| run_controller | 编排：命令入口、视图切换、渲染调度、临时会话字段持有 | 仅收走 :232 硬编码类型表（迁 run_command_builder 或独立 router） |
| resolver.gd | Command Router/Validator：_dispatch 表路由到命令族 | ✅ 已达标，不动 |
| 命令族（rest/shop/refine/…） | 规则执行：State+Command→新 State+Events | ✅ 不动 |
| v1_battle_resolver | 战斗内实际发生什么（纯函数，battle=Dictionary） | ✅ 边界正确；status 内联结算待 Q7 表驱动化 |
| RunState | 唯一权威运行态，copy-on-write | ✅ 不动；battle2 双字段已有定界注释 |
| snapshot builder | 每屏只读投影 | ✅ 不动；feedback 键逐步承接战斗动效触发 |
| save_repository | RunState→序列化→checksum→原子写 | ✅ 审计通过，不动 |
| screens/widgets | 只读快照 + 提交 commands | ✅ 不动；动效 diff 渐迁 feedback 键 |

## 7. File Ownership（Agent Contract 终稿）

| 角色 | 可写 | 只读 | 禁区 |
|---|---|---|---|
| **Logic Agent** | `scripts/domain/**`、`data/*.json`、领域侧 unit 测试 | snapshots 键定义、契约文档 | `presentation/**`、`scenes/**`、`.tscn` |
| **Visual Agent** | `scenes/**`、`ui/widgets/*.guitkx`、`scripts/presentation/screens|widgets`、theme/美术资产 | 快照键定义 | `scripts/domain/**`、任何对 state 的写入 |
| **Test Agent** | `tests/**`、`tools/**` | 全部源码 | 生产代码（报告问题，不代修） |
| **Astra** | 架构级变更、跨界文件、终审 | — | 不做日常业务编码 |

**Shared 单写者区**（同一阶段只有一个修改责任方，跨界改动须 Astra 预审）：
`run_controller.gd`、`run_snapshot_builder.gd` + `snapshots/*`（快照键=领域-UI 契约）、`resolver.gd` 路由核、`run_state.gd`（STATE_FIELDS 面）、`save_repository.gd`、`docs/contracts/*`、`project.godot`、`master.tscn`（main.tscn）。

## 8. Migration Plan（分批，每批独立可回滚）

| 批 | 内容 | 文件 | 执行者 | 破坏风险 | 验证 | 回滚 |
|---|---|---|---|---|---|---|
| M0 | 所有权表+本计划落 docs/contracts，AGENTS.md 引用 | 契约文档、AGENTS.md | Astra | 零（纯文档） | — | git revert |
| M1 | **战斗中存档行为审计**：核实 current_battle 不序列化时 save_run→load_run 的实际表现；补一条 integration 测试钉住行为（无论修不修，先钉住） | tests/integration 新增 | Test Agent | 零（只加测试） | `tools/test.ps1 -Suite integration` | 删测试即可 |
| M2 | **收走 :232 硬编码**：战斗命令类型表迁为 BattleCommandFacade 暴露的 `is_battle_command(type)`（领域侧单一事实），controller 调用 | run_controller.gd、battle_command_facade.gd | Astra（Shared 区） | 低：纯等价搬移 | unit+integration 全量 + 交互门 | revert 单提交 |
| M3 | **去重 current_session**：controller.current_session 改为读 state.encounter_session（删镜像赋值），流模块同步改参 | run_controller.gd、run_snapshot_builder、encounter 相关流 | Astra | 中：会话流回归面大，需逐屏冒烟 | interaction_loop + encounter/refine/npc 聚焦测试 | revert 单提交 |
| M4 | （并入 Q7 批）**status handler 表驱动**：v1_effect status/buff 内联分支抽 kind→handler 字典，行为逐只不变契约测试护航 | v1_battle_resolver.gd、新 handler 模块、契约测试 | Logic Agent | 中 | 现有 1239 unit + 新增逐只对比测试 | revert 批次提交 |

每批之间必须独立提交、全绿后再开下一批；M3 若冒烟异常立即回滚并登记 KNOWN 留档。

## 9. Do Not Change（不完美但现在不动）

1. **resolver.gd 路由核 + _dispatch 表**——205 行已达标，非必要不碰。
2. **v1_battle_resolver 纯函数设计**——battle=Dictionary duplicate 流是本项目确定性地基。
3. **RunState._copy/append_event/STATE_FIELDS 机制**——审计通过，白名单+保护键设计正确。
4. **save_repository 全部**（SAVE_VERSION 4/checksum/tmp+rename）——单序列化路径，无平行存档态。
5. **快照 13 模块 + RunCommandBuilder**——投影纪律好，不引入事件总线。
6. **route 不入 RunState（种子重建）**——确定性成立即正确设计；只在 MapGenerator 引入非种子随机时才需升级（登记为守护条件）。
7. **controller 的 ~460 行一行委托**——保持公共 API 与测试调用点稳定，是拆分成功的痕迹，不是债。
8. **battle2 双字段（持久 ledger + 运行时 handle）**——注释已定界，等 T10 剑道线收敛后再评估。
9. **RUITK widgets 层（15 个 .guitkx→.gd）**——双源但已收敛，屏级已全迁 .tscn。
10. **id 特判 3 处（action_preview/inheritance/social）**——规模小、有测试覆盖，等内容扩到痛时再抽象。
11. **feedback toast/BGM/淡入等表现层细节**——交互门+线稿批准制兜着。

## 10. Next 5 Tasks（按 ROI）

| # | Task | Why | Files | Risk | Expected |
|---|---|---|---|---|---|
| 1 | M0：Ownership 契约落档 | 多 Agent 开工前唯一 P0 | docs/contracts/、AGENTS.md | 零 | 单写者纪律成文 |
| 2 | M1：战斗中存档行为测试钉住 | 澄清 P1-4 未知，防静默丢战斗态 | tests/integration | 零 | 行为被测试锁定 |
| 3 | M2：战斗命令类型表收进 facade | 消除表现层硬编码，新战斗命令回到"领域单点" | 2 文件 | 低 | 三点同步→单点 |
| 4 | M3：current_session 去重 | 消除双真状态漂移面 | 3-4 文件 | 中 | 单一来源 |
| 5 | M4（=Q7 批）：status handler 表驱动 | 同时消解 P1-5 与封闭枚举债 | v1_battle_resolver 等 | 中 | 新状态=数据+handler |

---

**裁决请求**：本计划不执行。请确认：① M0–M4 批次顺序；② M3 的会话去重是否本轮就做（也可降级为"登记不动"）；③ Ownership 表是否按 §7 原文落档。
