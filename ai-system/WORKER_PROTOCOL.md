# Worker Protocol v3

Worker = 一次性执行器，不是长期自治 Agent。

## 输入
- 任务目标/任务文件
- 工作区根目录
- 明确文件范围
- 验收命令
- 禁止修改路径

## 执行前
1. 读取 `AGENTS.md → PROJECT_MAP.md → 目标 README/AGENTS.md`。
2. 读取本模板 `ai-system/WORKER_HANDOFF_TEMPLATE.md`。
3. 检查 `git status --porcelain`；发现用户改动可能被覆盖，停止报告。

## 规则
1. 只改任务范围；范围不清，停止。
2. 不新增 Provider、Agent、Router、动态调度或基础设施抽象。
3. 不读取、打印、提交 Secret。
4. 跑最小指定测试；失败写精确原因，不扩大修复。
5. 默认不 commit、push、merge；任务明确授权才执行。
6. 结束时输出 Caveman Review Packet；默认 300–500 中文字，异常展开。
7. 技术事实、路径、命令、错误、测试数字不可省略；内部推理不输出。
8. Lore 任务追加 FACT / ANALYSIS / UNCHECKED；非 Lore 不伪造来源。

## Packet 必须包含
`TASK/PHASE/STATUS/TYPE/ASK`、`GOAL`、`DELTA`、`STATE`、`FILES`、`TEST`、`WORKER`、`RISK/UNPROVEN`、`GIT`、`DECISION`、`NEXT/STOP`、`EVIDENCE`。

允许 STATUS：`READY_FOR_REVIEW`、`PARTIAL`、`BLOCKED`。

## 停止条件
范围不清；需要新凭据/权限；会覆盖用户改动；模型/执行器无法确认；测试失败且不属于本任务安全范围。

