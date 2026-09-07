# 模块接口：运行状态（run_state）

> 契约层级：领域层。单局状态的唯一权威载体；所有状态读取/持久化经本模块，禁止在 resolver/UI 直接改状态键。
> 仓库路径：`scripts/domain/run_state.gd`；存档：`scripts/domain/save_repository.gd`

## 职责

持有单局全部可变状态（资源/蛊仓/地图位置/事件日志），提供回合边界结算、事件记录、存档序列化/反序列化。

## 公开接口

| 入口 | 输入 | 输出 | 说明 |
|---|---|---|---|
| `RunState.new_run(run_seed, meta)` | 种子 | RunState | **唯一创建路径**；meta 为空则内建（测试用） |
| `is_terminal()` | — | bool | 终局判定（死亡/通关） |
| `finalize_death()` | — | RunState | 死亡收尾（记日志+终局标记） |
| `append_event(event)` | `{type, ...}` | RunState | 事件日志追加（返回新状态，不可变风格） |
| `refined_instances()` | — | Array | 已炼化蛊实例投影（战斗槽构建用） |
| `sync_legacy_gu_projections()` | — | void | 旧字段投影同步（gu_ids/equipped_gu_ids 遗留维护） |
| `settle_layer(state, new_layer, pantry, catalog, options)` | 新层号 | RunState | 大层推进结算（开新层奖励等） |
| `highest_owned_rank(gu_id)` | 蛊定义 ID | int | 图鉴/收藏册查询 |
| `to_save_data()` | — | Dictionary | 存档序列化 |
| `next_gu_instance_id(instances)` | 实例仓 | String | 实例 ID 分配（唯一性） |

## 关键数据契约

- 状态键：`{run_seed, stone, essence, life_time, soul, thoughts, gu_instances{}, refined_gu_ids[], event_log[], run_buff_ids[], cave_aperture{stored_gu_instance_ids[]}, flags, ...}`
- 实例仓：`gu_instances[instance_id] = {instance_id, definition_id, state, rank, ...}`
- 事件：`event_log[]` 每项 `{type, ...}`，追加即返回新状态（防引用共享）

## 信号

无（普通 class，非 Node）。

## 依赖

- `content_catalog.gd`（settle_layer 取层奖励表）；`seeded_roll.gd`（资源初始化）
- 存档侧：`save_repository.gd`（save_run/load_run/diagnose_run_file，路径 `user://`）

## 强制规则（Agent 生成代码必读）

1. 状态变更必须经 RunState 方法或领域 resolver 返回的新状态；表现层禁止写 `state.stone += x` 类直改。
2. 新增状态键必须：RunState 初始化 + `to_save_data/from_save_data` + 存档迁移兼容，三处同步。
3. 实例 ID 分配只用 `next_gu_instance_id`，禁止手写自增 ID 字符串。
4. 事件只经 `append_event` 写入，日志文本保持可读、不可变追加。
