# 模块接口：行动预览（action_preview_service）

> 契约层级：领域层。UI 唯一命令来源：为当前节点/战斗生成「可执行命令卡片」集合；表现层只渲染卡片并提交，禁止自行发明命令。
> 仓库路径：`scripts/domain/action_preview_service.gd`

## 职责

把「当前状态 + 当前节点」翻译为 UI 可展示、可提交的命令卡片（含禁用态与原因），并过滤站位/消耗后不可用的选项。

## 公开接口

| 入口 | 输入 | 输出 | 说明 |
|---|---|---|---|
| `preview_actions(state, node, catalog, knowledge)` | 状态 + 节点 + 目录 | `Array[Dictionary]`（卡片） | **节点行动唯一来源**（商店/休整/遗葬/NPC 等） |
| `preview_battle_actions(battle, state, catalog)` | battle + 状态 | `Array[Dictionary]`（战斗卡片） | **战斗行动唯一来源**（出蛊/杀招/拳脚/结束回合/撤退） |
| `find_card(state, node, action_id, catalog)` | action_id | Dictionary（卡片） | 按 ID 取卡片（校验/回显用） |

## 关键数据契约（卡片字典）

- `{id, type, label, executable: bool, block_reason, remedy_hints[], costs{...}, requires, target_type}`
- 命令 `type` 全集必须与 `docs/contracts/2026-09-02-domain-ui-contract.md` 命令面一致
- 战斗卡片（第三阶段 Task 3，2026-09-17）**十键契约**：每张卡必须齐备
  `{id, type, executable, block_reason, costs, target_type, valid_target_ids, command, state_version, expected_phase}`
  - `id`：`gu.<instance_id>` / `basic_attack` / `kill_move.<id>` / `battle.end_turn` / `battle.retreat`
  - `type`：`use_gu` / `basic_attack` / `play_kill_move` / `end_turn` / `retreat`
  - `costs` 与既有消费面读的 `cost` 同值双写；`reason` 保留领域原始原因码（`block_reason` 是其玩家文案）
  - `state_version` = `state.event_log.size()`（与手牌版本同源）；`expected_phase` = 快照期 `battle.phase`
- 战斗卡片 `target_type`：`"single_enemy"` / `"none"`；仅 `v1_effect.kind == "strike"` 的蛊与拳脚需要选敌，`valid_target_ids` = 当前存活敌人 id 列表（其余为空）
- 杀招卡片 `command.confirmed = false`：UI 确认后补 `confirmed = true` 才下发（T16 残锋降转不得静默惩罚）
- 终局（`phase != player_action`）或撤离后（`flags.session_closed`）**不再产出任何战斗卡**；快照对缺卡的卡位一律置灰，不放行
- 撤退卡片：Boss 战 `executable=false` + `block_reason="退无可退"`；元石/地形条件与领域**同源**——预览与执行都调 `BattleCommandFacade.retreat_gate`，卡片的 `executable`/`reason` 就是门禁的 `ok`/`reason`（`F-01` 已于 2026-09-17 落地修复，独立复验二次结论回收后于 2026-09-18 判定 `CLOSED`）。

## 信号

无（纯函数式 domain 模块）。

## 依赖

- `content_catalog.gd`（蛊定义/配方/商店表）；`run_state.gd`（状态读取）
- `resolver.gd`（命令合法性与 `_is_fight_command` 判定）、`v1_battle_resolver.gd`（战斗门禁 `can_play_gu/basic_attack_reason/kill_move_reason`）

## 强制规则（Agent 生成代码必读）

1. UI 的所有按钮/卡片必须来自 `preview_actions/preview_battle_actions` 返回；禁止 UI 手写命令字典。
2. 新增可执行动作必须：先实现领域路由（resolver/facade），再在预览服务产出卡片，三处（领域/预览/契约）同步。
3. 禁用态语义只经 `block_reason`/`remedy_hints` 表达，UI 不重复推导。
4. 预览与执行共用同一套门禁函数（`can_play_gu` 等），禁止预览宽松、执行严格的漂移。
5. 战斗屏可执行性、结构化命令与目标面只有本服务一个来源：`battle_snapshot` 只读取结论并透传（`_battle_gates/_apply_battle_gate`），禁止快照或 UI 再调 resolver 重算。

## 独立审查状态（2026-09-17 审查，2026-09-18 收口）

- 报告：`docs/superpowers/reports/2026-09-17-battle-core-audit.md`。
- `F-01` **CLOSED**（修复已落地，独立复验二次结论已回收于 2026-09-18；证据：可写 `user://` 下全量 unit 1581/1581 / integration 56/56）：撤离门禁唯一来源 `BattleCommandFacade.retreat_gate`（Boss → 地形/追击 → 元石），预览只转呈结论、执行复用同一纯门禁；`PREVIEW_ONLY_GATES` 豁免已删除。
- `F-02` **CLOSED**（修复已落地，独立复验二次结论已回收于 2026-09-18；证据同上，见审查报告 §9）：Gu / 基础攻击 / 杀招的嵌套 `command` 全部带 `state_version` + `expected_phase`；提交路径已接 `CommandSpecRegistry` preflight，过期命令按 `battle_*_stale` 拒绝且零副作用。
- **卡 id 形状统一（2026-09-17 第三轮）**：本服务产出的现行 id（`battle.end_turn` / `battle.retreat`，不含 battle_id 段）是唯一规范形；旧信封 `battle.<battle_id>.<card>` 由 `BattleCommandFacade.canonical_action_card_id` 归一后再路由，两代形状都通过 controller preflight。归一不读 `battle.battle_id`（生产战斗从不设置该键，按它判定会让兼容分支永远不可达）。
- 仍开放：`F-03`～`F-06`（计划复选框回写、表现层残留 preload、回放断言强度、提交边界），均为 P2 技术债。
