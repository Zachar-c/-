# Batch 19：界壁阶段关系核验

## 目标

核验并收紧“界壁缩减”与“大战后五域界壁彻底消弭”两类表述的时间点、轮次和证据层级。只解决这个窄问题，不扩展为五域百科或完整地图。

## 允许修改的文件（仅限以下四个）

- `lore/wiki/events/central-plain-refinement-conference.md`
- `lore/wiki/events/fate-war.md`
- `lore/wiki/world/index.md`
- `lore/wiki/log.md`

禁止修改其他文件；禁止新增 Wiki 页面、来源文件、索引系统、游戏代码或基础设施。

## 执行要求

1. 先读 `AGENTS.md` → `PROJECT_MAP.md` → `lore/wiki/README.md` → `lore/wiki/AGENTS.md`，再读 `ai-system/WORKER_PROTOCOL.md` 与 `ai-system/WORKER_HANDOFF_TEMPLATE.md`。
2. 修改前执行 `git status --porcelain`。当前已有其他项目改动，必须保留；不要回滚、格式化或覆盖它们。
3. 回查本地 `source/蛊真人-clean.txt`、现有 `notes:` 锚点、`memory:` 和 `game/docs/lore/canon-index.md`。本地 source 只读，不得提交。
4. 只围绕以下问题查证：
   - “五域界壁因地脉合一缩减”（中洲炼蛊大会页当前 G 313034–313036 笔记锚点）究竟对应哪一轮、哪个事件阶段；
   - “大战后五域界壁彻底消弭”（宿命大战页 Run 1 时间线当前表述）是否有逐段原文或 canon-index 证据；
   - 两句是否可以建立明确先后关系，还是只能并列保留并标记未核验。
5. 若找到逐段原文证据：只补最小必要来源定位和限定语，明确轮次/阶段，不把一次轮回的结果写进另一轮。
6. 若找不到逐段原文证据：把确定性过高的句子降为 `## 资料整理` 或 `## 待核对`，保留原锚点、Run 1 / Run 2 区分和“不能合并”的限制；不得删除线索。
7. `lore/wiki/world/index.md`：把“南疆”作为地域/世界规则入口，把中洲炼蛊大会、宿命大战明确标成“用于核验界壁变化的事件入口”，避免三者被视为同类地域页面。
8. 更新 `lore/wiki/log.md`，记录证据结果、是否建立阶段模型、未解决缺口和未触碰范围。不要改写已提交的 Batch 11–18 记录。
9. 不要建立“五域完整模型”，不要新增中洲/北原/东海/西漠薄页面，不要补写 H2 断点后剧情。

## 验收命令

从仓库根目录运行：

- `pwsh -NoProfile -File lore/wiki/tools/check.ps1`
- `git diff --check`
- `git status --short -- lore/wiki`

必须逐项记录结果。不要提交、推送或合并；本批提交由协调方另行处理。

## 交付

严格按 `ai-system/WORKER_HANDOFF_TEMPLATE.md` 输出完整 Review Handoff。报告必须说明：实际查到的原文/索引证据、界壁两阶段是否能建立关系、Run 1 / Run 2 是否保持分离、事实与资料整理/待核对的层级变化、所有验收结果和最终 `STATUS`。
