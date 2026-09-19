# AI 开发环境 Phase 1/2 Review Submission

> 状态：待审阅
>
> 日期：2026-09-19
>
> 本文件是当前实现与下一步计划的评审提交件，不代表已经提交 Git，也不代表已推送远程。

## 1. 本次提交的范围

本次只提交 AI 开发环境的当前状态和最小下一步计划，目标是把已有资源整合成可实际使用的 Worker 链路。

本次不做以下事情：

- 不引入 CCR。
- 不引入 `llm-router` 或其他新的路由平台。
- 不新增 Agent、Executor、Brain、Provider 等抽象接口。
- 不为 Codex 增加 Responses API 适配层。
- 不建设独立的 benchmark、积分统计或自动学习系统。
- 不把未完成的 Claude Code/第三方桥接链路宣布为生产能力。

## 2. 当前架构

```text
Codex / GPT-5.6-Luna
        │
        │ 需求理解、拆解、审查、最终决策
        ▼
本地 Worker 执行层
  ├─ WorkBuddy CLI：当前优先验证的生产执行候选
  ├─ OpenCode + muse-spark-1.3-contributor-free：按领域记录
  │    ├─ Wiki / 知识工程：VERIFIED
  │    └─ Godot 软件工程：PARTIALLY VERIFIED
  └─ Claude Code：Godot 候选执行入口，尚未完成端到端验收
        │
        ├─ WorkBuddy 本地模型槽位
        ├─ WorkBuddy Worker Body 云端桥接（可选）
        └─ TRAE Local API（本机候选，尚未提升为生产入口）
```

核心约束仍然是：执行工具与模型分离，配置与密钥分离，公司/家庭环境通过覆盖配置复用。

## 3. 已实现的内容

### 3.1 Worker 任务契约

- `WORKER_PROTOCOL.md`：定义 Codex 交给 Worker 的任务边界、输入、输出、验收和失败报告。
- `WORKER_HANDOFF_TEMPLATE.md`：提供实际交接模板。
- Worker 只负责施工、运行测试和返回结果；最终判断仍由 Codex 完成。

### 3.2 执行入口

- `run-worker.ps1`：统一 Worker 入口。
- `run-workbuddy-cli-worker.ps1`：本地 WorkBuddy CLI 执行入口。
- `run-workbuddy-worker.ps1`：WorkBuddy Worker Body API 的可选桥接入口。
- OpenCode + `opencode/muse-spark-1.3-contributor-free`：Wiki 线上 VERIFIED；Godot 线上 PARTIALLY VERIFIED。

### 3.3 配置和密钥隔离

- `config/common.json`：共享配置。
- `config/home.example.json`：家庭环境示例。
- `config/model-rules.json`：四个已配置模型槽位的静态 fallback 规则。
- 本地 `home.json`、`work.json`、`secrets.json` 以及 `*.local.json` 被 `.gitignore` 忽略。
- 不把 API Key、登录状态或本机认证数据库纳入仓库。

### 3.4 模型选择规则

当前刻意收敛为两条固定链，不再维护复杂评分算法：

```text
normal:
  1. 海外 DeepSeek V4.1
  2. 国内 Hy4 夜间免费窗口
  3. 海外 Hy4
  4. 国内 DeepSeek V4.1 固定池

hard:
  1. 海外 Hy4
  2. 国内 Hy4 夜间免费窗口
  3. 海外 DeepSeek V4.1
  4. 国内 DeepSeek V4.1 固定池
```

选择器 `choose-worker-model.ps1` 只做以下工作：

- 根据 `normal` 或 `hard` 读取静态链。
- 跳过未配置、禁用、不在时间窗口或明确未就绪的候选。
- 支持手动排除当前失败候选后继续选择下一项。
- 输出主候选、fallback 链和被跳过原因。

它不伪造剩余额度，不自动学习性能，不静默切换到链外模型，也不把一次模型失败误判成额度耗尽。

## 4. 已完成的验证

| 项目 | 当前结论 | 备注 |
|---|---|---|
| PowerShell 解析 | 通过 | 选择器和 WorkBuddy CLI 脚本已检查 |
| JSON 配置解析 | 通过 | `common.json`、`model-rules.json` |
| 选择器场景 | 通过 | normal/hard、时间窗口、仅单侧 Worker、手动排除均已验证 |
| `git diff --check` | 通过 | 现有 `ai-system/PRD.md` 有既存换行格式警告，不是本次新错误 |
| 国内 WorkBuddy CLI | 已有过 smoke 验证 | 旧记录为桥接可用、成本显示为 0；仍需用真实任务复验 |
| 海外 WorkBuddy CLI | 未通过认证 | 当前返回 401；GUI 登录态没有自动共享给 CLI |
| WorkBuddy Worker Body | 入口已实现，未完成真实调用验收 | 需要有效 token 和 workspace 配置 |
| OpenCode + `opencode/muse-spark-1.3-contributor-free` / Wiki | VERIFIED | 已有长期 Wiki Batch 生产记录 |
| OpenCode + `opencode/muse-spark-1.3-contributor-free` / Godot | PARTIALLY VERIFIED | #001/#002 两个受控任务；可用于低风险任务但仍需 Codex 审查 |
| TRAE Local API `/health` | 通过 | 本机 `localhost:19900` |
| TRAE Local API `/v1/status` | 通过 | 国内版自动认证状态有效，未读取或暴露 token 内容 |
| TRAE Local API `/v1/models` | 通过 | 能列出可用模型槽位 |
| TRAE Anthropic tool-call smoke | 通过 | `deepseek-v4-flash` 成功返回工具调用 |
| TRAE 上游 `npm test` | 未通过 | 上游 package script 指向缺失的 `tests/test-all.js` |
| Claude Code → TRAE Local API | 待验证 | CLI 端到端测试 30 秒无返回，当前不宣称可用 |

TRAE Local API 的本地副本位于仓库外：

```text
C:\Users\90877\local-tools\trae-local-api
```

其本地 `.env` 未使用手工 token；本地桥接服务当前监听 `localhost:19900`。这是候选实验环境，不属于仓库交付物。

上游项目公开说明了本地 OpenAI/Anthropic 接口、`/v1/messages`、`/v1/chat/completions`、模型列表和 Claude Code 兼容方向，但它不是 TRAE 官方 API，且认证实现依赖本地 IDE 状态。因此这里只把它记录为候选，不把上游说明当成本机生产验收结果。

## 5. 当前可以声称与不能声称的内容

### 可以声称

- 当前已经有一个轻量 Worker Protocol 和可执行的本地入口。
- 四个 WorkBuddy 模型槽位已经被收敛为可审阅的静态 fallback 配置。
- Codex 仍然是默认大脑，模型池只服务于执行层。
- TRAE Local API 的本地 API 层和 Anthropic tool-call 层已经通过基础验证。
- 配置、密钥和家庭/工作环境覆盖方向已经保留。

### 不能声称

- 不能声称 Claude Code 已经是默认生产执行层。
- 不能声称 CCR 已安装、可用或已接入。
- 不能声称 TRAE 已经通过 Claude Code CLI 端到端验收。
- 不能声称 WorkBuddy Worker Body 已经完成真实云端任务闭环。
- 不能声称四个模型已有精确余额、自动健康评分或性能学习能力。
- 不能声称 Muse 已经独立完成 Godot 任务；#001/#002 均仍保留 Codex 审查，其中 #002 的核心实现由 Worker 完成。

## 6. 当前风险和阻塞

1. **TRAE 桥接不是官方 API。** 它依赖 TRAE 本地登录状态和第三方项目对内部接口的适配；不使用手工 token 提取、账号池、绕风控或并发规避方案。
2. **Claude Code CLI 端到端未完成。** 目前只能证明 TRAE API 能返回 Anthropic tool call，不能证明 Claude CLI 会稳定使用它。
3. **海外 WorkBuddy CLI 认证未打通。** GUI 可用不等于 CLI 自动继承登录态。
4. **Worker Body 需要实际凭证和 workspace。** 在没有可用本地 secret 的情况下，只能保留适配器，不能伪造成功结果。
5. **Godot 执行器仍未完成独立性证明。** OpenCode + Muse 已有两个受控真实任务，可用于低风险任务但仍需 Codex 审查；不宣布唯一生产执行器。

## 7. 建议的 Phase 2 最小计划

这不是自动执行清单，而是待审阅计划。用户批准前不继续扩张基础设施。

### Gate A：决定是否收编 TRAE

只做一次有边界的 Claude Code 端到端复验：

1. 使用当前本机 TRAE 登录态和 `localhost:19900`。
2. 先执行只读、无文件修改的 tool-call 任务。
3. 若仍无法在明确时间内完成，记录为“API 可用、Claude CLI 不兼容”，停止投入，不再修建 adapter。

### Gate B：选择一个真实 Godot 小任务

任务约束：

- 当前确实存在的小 Bug 或 TODO。
- 修改不超过约 3–5 个文件。
- 有明确、可重复的验收方式。
- 不涉及存档格式、核心数据结构或大规模场景重构。
- 能在独立 Git worktree 中执行和审查。

### Gate C：只跑一次真实执行闭环

```text
Codex 定义任务
  ↓
选择 normal 或 hard
  ↓
静态 fallback 链选择 Worker/模型
  ↓
独立 worktree 执行
  ↓
测试与 diff review
  ↓
Codex 决定接受、返工或停止
```

只记录六项结果：

- 一次完成验收：是/否。
- 测试最终通过：是/否。
- 是否越界修改：是/否。
- Codex 返工次数。
- 人工介入次数。
- 最终 diff 质量描述。

跑完第一个真实任务后先停下来审阅，不自动增加 Provider、Router、状态机或 benchmark 平台。

## 8. 请审阅并给出方向

请重点确认以下四点：

1. 是否批准当前 `normal / hard` 静态 fallback 链作为 V1 基线？
2. TRAE Local API 是否继续保留为候选，还是直接从执行候选中移除？
3. Claude Code CLI 的端到端复验是否只允许再做这一轮，失败即停止？
4. Phase 2 的第一个真实 Godot 小任务由你指定，还是由 Codex 从当前仓库选择一个符合约束的任务？

在收到方向前，当前建议保持：

- 不提交 Git。
- 不推送远程。
- 不启用 CCR。
- 不新增调度层。
- 不扩展模型和 Provider 数量。
