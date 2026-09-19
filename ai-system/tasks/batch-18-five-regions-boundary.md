# Batch 18：五域与界壁的来源边界收紧

## 目标

围绕现有 Wiki 的“地域与界壁”入口做一次小批量结构整理。目标是让五域相关信息可导航、可分层，但不补写没有逐段核验的地域设定。

## 允许修改的文件（仅限以下五个）

- `lore/wiki/world/index.md`
- `lore/wiki/world/south-jiang.md`
- `lore/wiki/events/central-plain-refinement-conference.md`
- `lore/wiki/events/fate-war.md`
- `lore/wiki/log.md`

禁止修改其他文件；禁止新增 Wiki 页面、来源文件、索引系统或游戏代码。

## 具体要求

1. 先读取根目录 `AGENTS.md`、`PROJECT_MAP.md`、`lore/wiki/README.md`、`lore/wiki/AGENTS.md`，再读取 `ai-system/WORKER_PROTOCOL.md` 与 `ai-system/WORKER_HANDOFF_TEMPLATE.md`。
2. 修改前执行 `git status --porcelain`，保护当前已有的 Batch 11–17 及其他用户改动；不要重写、回滚或格式化无关文件。
3. `lore/wiki/world/index.md`：补充一个明确的“地域与界壁”导航层，链接现有南疆、中洲炼蛊大会、宿命大战页面；写清当前 Wiki 只覆盖已建入口，五域完整地图、距离、势力谱系仍未完成，不得让读者推断缺失地域已被完整建模。
4. `lore/wiki/world/south-jiang.md`：只做与新导航层一致的互链或边界措辞调整；现有 `canon-index` 事实不要改写成笔记事实，也不要新增南疆地理结论。
5. `lore/wiki/events/central-plain-refinement-conference.md`：审查 `## 原著明确内容`。当前条目主要来自 notes 锚点；若没有逐段原文或 canon-index 证据，应保持内容不变地移入 `## 资料整理`，并在“原著明确内容”保留范围说明。保留 Run 1 / Run 2 的区分、锚点和待核对边界；不要把整理转述升级为原著事实。
6. `lore/wiki/events/fate-war.md`：只审查五域界壁、Run 1 / Run 2 和战场范围相关的来源层级。不能把不同轮回或“五域大战/宿命大战”命名合并。必要时把未逐段核验的句子移入 `## 资料整理` 或 `## 待核对`，保留原有锚点和限制语句；不得补写 H2 断点后的结局。
7. 更新 `lore/wiki/log.md`，登记 Batch 18 的目标、实际移动/互链、未处理的来源缺口和未触碰范围。不要覆盖 Batch 11–17 日志。
8. Lore 内容必须分成：原著明确内容、资料整理、分析与解读、待核对。`资料整理` 不得作为原著事实引用来源。

## 验收命令

从仓库根目录运行：

- `pwsh -NoProfile -File lore/wiki/tools/check.ps1`
- `git diff --check`
- `git status --short -- lore/wiki`

逐项记录结果。不要提交、推送或合并。

## 交付

严格按 `ai-system/WORKER_HANDOFF_TEMPLATE.md` 输出完整 Review Handoff。必须明确列出：实际新增/修改/删除/未完成、允许文件范围、来源层级变化、Run 1/Run 2 是否保持分离、验收结果、遗留风险和最终 `STATUS`。
