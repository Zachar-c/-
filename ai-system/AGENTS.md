# AI system context

本目录保存 AI 执行环境、Worker 约定和模型配置，不是《问真》的产品规格或 Agent 平台。产品权威仍是 `docs/PRODUCT_REQUIREMENTS_v1.0.md`；协作边界见 `docs/AI_DEVELOPMENT_PROTOCOL_v1.0.md`。

## 角色

- Codex 负责理解任务、选择范围、编排和复核。
- Worker 负责有边界的搜索、编辑、编码、测试或蒸馏。
- L0/L1 的产品意图、重大取舍、数值和多方向模型不由 Worker 代决。

## 配置使用

- `config/common.json` 是共享默认配置，`config/model-rules.json` 是候选链配置；需要模型选择时按当前入口读取，不把配置中的候选状态当成永久事实。
- 模型不可用时，只使用已配置且实际可验证的候选；不伪造额度、不静默跨链、不新增 Provider、Router 或调度抽象。
- 普通代码、文档和只读检查不需要加载本目录的全部配置或任务历史。

## 执行纪律

开始 Worker 任务前读取目标目录规则和 `WORKER_PROTOCOL.md`；任务包使用 `WORKER_HANDOFF_TEMPLATE.md`，只传相关上下文。

Worker 保护用户改动，不读取或提交 secrets，默认不 commit、merge、push。遇到范围冲突、架构/产品判断或无法验证时返回证据与阻塞点，暂停当前批次；普通工程问题直接完成并报告真实测试结果。

详细任务、Research Request 和历史执行记录按当前任务点读，不作为每次会话的常驻提示。
