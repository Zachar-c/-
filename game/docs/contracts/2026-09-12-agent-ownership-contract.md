# Agent Ownership Contract（2026-09-12，用户批准 M0 落档）

> 目的：多 Agent 并行施工的单写者纪律。历史上并行会话曾 4 次物理删除文件；
> 本契约是硬门槛：**本契约落档前，任何 Agent 不得开始新功能开发。**
> 依据：`docs/superpowers/plans/2026-09-12-architecture-correction-plan.md`（已批准 M0–M3）。

## 1. File Ownership

| 角色 | 可写 | 只读 | 禁区 |
|---|---|---|---|
| **Logic Agent** | `scripts/domain/**`、`data/*.json`、领域侧 unit 测试 | `snapshots/*` 键定义、契约文档 | `scripts/presentation/**`、`scenes/**`、`*.tscn` |
| **Visual Agent** | `scenes/**`、`ui/widgets/*.guitkx`、`scripts/presentation/screens|widgets`、主题/美术资产 | 快照键定义、本契约 | `scripts/domain/**`、任何对 `state` 的直接写入 |
| **Test Agent** | `tests/**`、`tools/**` | 全部源码（只读） | 生产代码（发现问题报告，不代修） |
| **Astra** | 架构级变更、跨界文件、终审 | — | 不做日常业务编码 |

**按系统边界而非扩展名划分**：`battle_screen.tscn` 与 `battle_screen_view.gd` 同归 Visual；
`battle_snapshot.gd` 同归 Shared。

## 2. Shared 单写者区（同一阶段只有一个实际修改责任方）

- `scripts/presentation/run_controller.gd`
- `scripts/presentation/run_snapshot_builder.gd` 与 `scripts/presentation/snapshots/*`（快照键 = 领域-UI 契约）
- `scripts/domain/resolver.gd`（路由核）
- `scripts/domain/run_state.gd`（STATE_FIELDS 字段面）
- `scripts/domain/save_repository.gd`
- `docs/contracts/*`（含本契约）
- `project.godot`、`scenes/main.tscn`

跨区改动（Logic 想动 Shared、Visual 想动快照键等）必须交 Astra 预审。

## 3. Shared 文件修改协议（硬性 5 步，不得"顺手改一行"绕过）

任何 Agent 修改 §2 所列文件前：

1. **声明文件**（完整路径）；
2. **说明原因**（对应哪个已批准任务/规格）；
3. **说明预期影响**（哪些屏/命令/测试受影响）；
4. **提交前运行指定测试**（至少：受影响模块聚焦测试 + `tools/test.ps1 -Suite unit`）；
5. **单独 commit**（一个 Shared 文件批次一个提交，不与其他改动混提）。

违反 1–3 任意一步的改动一律回退；并发会话同时命中同一 Shared 文件时，后到者必须等待先到者合入。

## 4. Astra 升级触发

快照键/命令面增删、新屏、RunState 字段变化、补流派（6 触点面）、
domain+presentation 跨界改动、worktree 合并前、Milestone Review。

## 5. 明确禁止（与 AGENTS.md 红线呼应）

- 禁止引入全局 EventBus；表现反馈走快照 `feedback` 键与命令结果。
- 禁止重建 Snapshot / Save / Test 体系（"Do Not Change" 清单见纠偏计划 §9）。
- 禁止 UI 直接写领域状态；禁止领域层引用 UI 节点。
