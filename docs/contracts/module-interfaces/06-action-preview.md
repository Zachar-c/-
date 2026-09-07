# 模块接口：行动预览（action_preview_service）

> 契约层级：领域层。UI 唯一命令来源：为当前节点/战斗生成「可执行命令卡片」集合；表现层只渲染卡片并提交，禁止自行发明命令。
> 仓库路径：`scripts/domain/action_preview_service.gd`

## 职责

把「当前状态 + 当前节点」翻译为 UI 可展示、可提交的命令卡片（含禁用态与原因），并过滤站位/消耗后不可用的选项。

## 公开接口

| 入口 | 输入 | 输出 | 说明 |
|---|---|---|---|
| `preview_actions(state, node, catalog, knowledge)` | 状态 + 节点 + 目录 | `Array[Dictionary]`（卡片） | **节点行动唯一来源**（商店/休整/遗葬/NPC 等） |
| `preview_battle_actions(battle, state, catalog)` | battle + 状态 | `Array[Dictionary]`（战斗卡片） | 战斗行动唯一来源（出蛊/杀招/拳脚/结束回合/撤退） |
| `find_card(state, node, action_id, catalog)` | action_id | Dictionary（卡片） | 按 ID 取卡片（校验/回显用） |

## 关键数据契约（卡片字典）

- `{id, type, label, executable: bool, block_reason, remedy_hints[], costs{...}, requires, target_type}`
- 命令 `type` 全集必须与 `docs/contracts/2026-09-02-domain-ui-contract.md` 命令面一致
- 战斗卡片 `target_type`：`"enemy"`/`"self"`/`"none"`（蛊定义 `v1_effect.kind` 推导）
- 撤退卡片：Boss 战 `executable=false` + `block_reason="退无可退"`

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
