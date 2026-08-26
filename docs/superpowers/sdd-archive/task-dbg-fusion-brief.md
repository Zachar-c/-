# T5-D × DBG1 融合对接简报（给 UI 会话）

## 裁定（2026-08-26 用户）
调试台融合：**面板 UI 用你方 T5-D（db5ee21），领域核心换用 master 上的 DebugActions 服务**（@`1cd79ea`，已含审查修复：跳达标记/essence 双取钳制/拒绝审计）。

## 领域 API（scripts/domain/debug_actions.gd @master）
```
DebugActions.apply(state, catalog, action: Dictionary, allowed: bool, route: Array = []) -> Dictionary
```
- `allowed` 传 `OS.is_debug_build()`（可经你方 `_debug_enabled_for_test` 注入）。
- `route` 仅 jump_to_node 需要（传 controller 当前 route 数组；缺省拒绝 missing_route_context）。
- 返回沿用 resolver 形态 `{ok, result, state, feeds}`。
- **审计语义变化**：所有操作（含拒绝）写入事件日志——action=`debug_<op>`/`debug_rejected`、source="debug"、载荷在 `after._debug`。你方原"不写事件日志"裁定由本融合取代；print("[debug]") 可继续保留作控制台跟踪。
- 操作白名单与 schema：
  - `{"op":"add_gu","definition_id":X}` — 走 DeckCapacity 正式门禁，槽满拒 deck_capacity_exceeded
  - `{"op":"set_resources","essence"/"stones"/"health"/"soul":n}` — 任意子集；essence 钳 cave_aperture.essence_max（回退 essence_capacity）；stones 钳非负无上限（你方 99999 展示帽保留在你的输入层）；health/soul 下限 1 禁静默致死
  - `{"op":"jump_to_node","node_id":X}` — 节点须在 route；落地写 flags[target]="debug_arrived"；有会话先以 debug_abandoned 关闭；terminal 态拒绝。你方"仅可见节点/禁战斗中跳转"限制请在调用前自行校验后放行
  - `{"op":"query_loot_state"}` / `{"op":"dump_snapshot"}` — 只读，terminal 态可用
- 已知边界：query 的 excluded 恒 []（池排除权属 §16.1 P1 待实现）；health 只写顶层标量（与既有伤害路径一致），encounter 页若读 cultivator.health 出现旧值属领域普遍行为非调试特有。

## 你侧改造点（预计小）
1. debug_panel.guitkx 五个操作按钮的执行体改为组 action 字典 → controller.debug_command → DebugActions.apply。
2. 删除 run_controller 内的资源设置/跳层/快照的自实现逻辑（298 行中领域部分），保留面板挂载与输入采集。
3. 快照展示可直接用 dump_snapshot 返回的 to_save_data() 字典。

## master 侧状态
- DebugActions＋debug.json＋14 个测试已在 master（545 unit + 10 integration 全绿），当前无 UI 调用方（等你的面板接线激活）。
- 我方 overlay（dbg1-impl 分支）按裁定废弃不合并，分支将删除。
