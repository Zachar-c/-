# 个人 AI 开发环境

这是个人开发环境的最小实现，不是 Agent 平台。

## 当前状态

Phase 1：基础环境完成。默认链是 `Codex → OpenCode + Muse Spark 1.3`；WorkBuddy CLI/Worker Body 是免费额度执行候选，不是默认执行层。OpenCode + Muse Spark 1.3 在 Wiki / 知识工程线上已验证，在 Godot 软件工程线上仍为部分验证。

WorkBuddy 适配器已完成请求体构造和提交逻辑，首次真实任务仍需线上冒烟验证。云端 Worker 不能直接读取调用机器上的本地绝对路径。

## 当前关系

```text
L0 用户
  ↓
L1 ChatGPT / Sol（判断、设计、裁决）
  ↓
L2 Codex（仓库理解、任务拆解、验收）
  ↓
L3 廉价 / 免费模型（DeepSeek / GLM / Qwen / MiMo / WorkBuddy）
  ↓
写代码 / 搜索 / 扫描 / 跑测试 / 批处理
```

```text
Codex / gpt-5.6-luna（默认，可替换）
        |
        v
OpenCode + Muse Spark 1.3（默认，可替换）
        |  低价值任务可改为 run-l3-worker.ps1 自动下发到 L3 链
        v
当前仓库工作区
```

默认执行器不可用时，才按 `config/model-rules.json` 选择已配置的 WorkBuddy 免费/优惠候选；找不到可验证候选就停止报告，不静默接入新工具。

WorkBuddy Worker Body API 作为远程工作区入口：

```text
Codex → WorkBuddy Worker Body API → WorkBuddy 云端工作区
```

OpenCode + Muse Spark 1.3（按工作领域记录状态）：

```text
Codex Cloud / gpt-5.6-luna
        |
        v
OpenCode —— Wiki 已验证；Godot 低风险任务可用但需 Codex 审查
        |
        v
opencode/muse-spark-1.3-contributor-free（必须匹配精确模型 ID）
```

当前只保留三类可替换内容：执行工具、模型、机器配置。没有 Agent Interface、Executor Interface、Provider Strategy 或自研编排层。

Phase 2 的比较只记录：一次完成验收、测试最终通过、是否越界修改、Codex 返工次数、人工介入次数、最终 diff 质量。不建立 benchmark 平台，也不打伪精确分数。

## 目录

- [ARCHITECTURE.md](ARCHITECTURE.md)：一页架构约定
- [WORKER_PROTOCOL.md](WORKER_PROTOCOL.md)：Worker 输入输出与边界
- [WORKER_HANDOFF_TEMPLATE.md](WORKER_HANDOFF_TEMPLATE.md)：Caveman 短审阅包模板
- [visual-asset-task-packet-template.md](visual-asset-task-packet-template.md)：视觉资产任务包模板
- [REVIEW-SUBMISSION.md](REVIEW-SUBMISSION.md)：审阅提交说明
- [PRD.md](PRD.md)：**镜像上游**历史设计（`MyAIProductionSystem`），不是《问真》PRD
- `bootstrap.ps1` / `run-worker.ps1` / `run-workbuddy-cli-worker.ps1` / `run-workbuddy-worker.ps1` / `choose-worker-model.ps1`：执行入口
- `config/`：`common.json`、环境模板与 `jev.json`
- `tasks/`：Research Request 与任务包（按需点读）
- `reviews/`：Worker 审阅记录

### 2026-09-24 待评审资料

- [四道玩法设计请求](RESEARCH-REQUEST-2026-09-24-four-dao-design.md)
- [人道蛊、插件与侦查设计请求](RESEARCH-REQUEST-2026-09-24-human-gu-plugins-and-recon.md)
- [人道蛊、插件与侦查 L1 评审摘录](L1-REVIEW-2026-09-24-human-gu-plugins-and-recon.md)
- [人道蛊、插件与侦查数值请求](RESEARCH-REQUEST-2026-09-24-human-gu-plugins-numerics.md)

以上为日期限定的请求与评审记录；是否仍待裁定以各文件状态及后续裁定为准。

```text
ai-system/
├─ ARCHITECTURE.md
├─ WORKER_PROTOCOL.md
├─ WORKER_HANDOFF_TEMPLATE.md
├─ bootstrap.ps1 … choose-worker-model.ps1
├─ config/
├─ tasks/
└─ reviews/
```

### Jev System One（实验）

高速、低成本、类型化的任务分层提议层，**不替代** Codex / OpenCode / `choose-worker-model.ps1`。

```text
STATE(任务简报) → Jev Choice(cheap|standard|strong|gpt6)
  HIGH   → 映射到现有 WorkerClass normal|hard|escalate
  MEDIUM → 退回现有确定性规则
  LOW    → 升级 System 2 / 人类
Jev 不可用 → 永远退回现有逻辑
```

```powershell
$env:JEV_API_KEY = '<local-only>'
& $env:MIMO_PYTHON ai-system/jev_systemone.py --task-file path/to/task.md --mode auto --log
& $env:MIMO_PYTHON -m unittest discover -s ai-system/tests -v
& $env:MIMO_PYTHON ai-system/eval/run_worker_tier_eval.py --mode auto
```

官方契约（2026-09-22）：经 **OpenRouter Decisions API** 调用 Jev，**一个 OpenRouter key 即可**，无需单独 TypeSafe 账号。

```text
POST https://openrouter.ai/api/alpha/decisions
Authorization: Bearer $OPENROUTER_API_KEY
model: typesafe/jev-1.13   # 或 ~typesafe/jev-latest
body: { state, questions: { task_tier: { type: choice, instructions, criteria } } }
```

环境变量 `OPENROUTER_API_KEY`（兼容 `JEV_API_KEY` / `TYPESAFE_API_KEY`）。Key 不进仓库。

## 使用

```powershell
pwsh -File ai-system/bootstrap.ps1 -Profile home
pwsh -File ai-system/bootstrap.ps1 -Profile home -VerifyModel
pwsh -File ai-system/run-worker.ps1 -Profile home -TaskFile path/to/task.md

# Codex 只指定 normal 或 hard；选择器按配置中的静态 fallback 链输出顺序
pwsh -File ai-system/choose-worker-model.ps1 -WorkerClass normal -DomesticReady -OverseasReady
pwsh -File ai-system/choose-worker-model.ps1 -WorkerClass hard -DomesticReady -OverseasReady

# 规则输出 domestic/deepseekV32Volc 后再执行
pwsh -File ai-system/run-workbuddy-cli-worker.ps1 -Body domestic -ModelSlot deepseekV32Volc -TaskFile path/to/task.md -AutoApprove

# 也可指定 glm-5.1 / kimi-k2.5 / minimax-m2.7
pwsh -File ai-system/run-workbuddy-cli-worker.ps1 -Body domestic -ModelSlot glm51 -TaskFile path/to/task.md -AutoApprove

# WorkBuddy Worker Body：任务文件会作为 POST /openapi/v2/tasks 的 prompt
$env:WORKBUDDY_ACCESS_TOKEN = '<local-only-token>'
pwsh -File ai-system/run-workbuddy-worker.ps1 -TaskFile path/to/task.md -Title 'Godot task'
```

`config/home.json`、`config/work.json` 和 `config/secrets.json` 只存在于本机，不提交到 Git。WorkBuddy Token 只放本机 Secret 或进程环境，不写入共享配置。

如需调用 WorkBuddyAI 的同类 CLI，可传入它的 `codebuddy` 路径：

```powershell
pwsh -File ai-system/run-workbuddy-cli-worker.ps1 `
  -CliPath "$env:LOCALAPPDATA\Programs\WorkBuddyAI\resources\app.asar.unpacked\cli\bin\codebuddy" `
  -Body overseas -ModelSlot deepseekV32Volc -TaskFile path/to/task.md -AutoApprove
```

如果本机没有 OpenCode CLI，Bootstrap 会报告缺失；不会把桌面端、其他模型或其他 Provider 静默当成替代品。需要替代时，只从已配置且已验证的候选中选择。

WorkBuddy CLI 复用本机登录态和免费额度，不把凭据写入仓库。WorkBuddy 云端适配只负责把现有 Worker Protocol 投递到任务 API，不改变 Worker 契约，也不保存 OAuth 凭据；云端任务需要 WorkBuddy 侧已经绑定或同步目标仓库。

模型规则选择：

```powershell
# cheap: 低价值任务（扫文档、批处理、只读检查）
pwsh -File ai-system/choose-worker-model.ps1 -WorkerClass cheap -MimoReady -OverseasReady -DomesticReady

# normal: 日常代码、审查、批处理
pwsh -File ai-system/choose-worker-model.ps1 -WorkerClass normal -MimoReady -OverseasReady -DomesticReady

# hard: 复杂代码、Godot 核心改动、架构任务
pwsh -File ai-system/choose-worker-model.ps1 -WorkerClass hard -OverseasReady -DomesticReady

# 某个候选本次任务失败后，显式排除它并取下一个
pwsh -File ai-system/choose-worker-model.ps1 -WorkerClass cheap -MimoReady -ExcludeCandidate 'local/mimo-v2.6-flash'
```

当前维护三条静态链（模型 ID 以 `codebuddy --help` / `mimo models` 实机返回为准，2026-09-30）：

```text
cheap:
  local MiMoCode xiaomi/mimo-v2.6-flash
  → local MiMoCode xiaomi/mimo-v2.5
  → domestic WorkBuddy deepseek-v3-2-volc
  → domestic WorkBuddy glm-5.1
  → overseas WorkBuddyAI deepseek-v3-2-volc

normal:
  local MiMoCode xiaomi/mimo-v2.6-pro
  → domestic WorkBuddy deepseek-v3-2-volc
  → domestic WorkBuddy glm-5.1
  → domestic WorkBuddy kimi-k2.5
  → overseas WorkBuddyAI deepseek-v3-2-volc

hard:
  domestic WorkBuddy glm-5.1
  → domestic WorkBuddy kimi-k2.5
  → domestic WorkBuddy minimax-m2.7
  → domestic WorkBuddy deepseek-v3-2-volc
```

选择器只做三件事：读取链、跳过未启用/未登录/不在时间窗口内的候选、输出 primary 和剩余 fallbackChain。它不维护性能分数、余额状态、健康评分或自动学习。模型失败、额度错误和重试由调用方/Worker 执行层处理；不静默切换到链外模型。

### L3 自动下发

层级为 L0 用户 → L1 ChatGPT → L2 Codex → L3 廉价模型。Codex 把边界清晰的低价值任务包（`tasks/*.md`）自动下发给 L3，不需要人工复制提示词。

```text
L2 Codex / MiMoCode（当前替位）
        |
        v
run-l3-worker.ps1  →  choose-worker-model.ps1 静态链
        |
        +-- run-mimocode-worker.ps1   (local/mimo-*)
        +-- run-workbuddy-cli-worker.ps1  (WorkBuddy / WorkBuddyAI)
        |
        v
失败 → 自动 Exclude → 下一个候选 → 全失败则 finalStatus=all-candidates-failed
```

这不是 Router / Provider 平台，只是 `choose-worker-model.ps1` 已预留的 caller 回退循环。`mimo run` 与 WorkBuddy CLI 在 API/登录失败时都可能仍返回退出码 0，runner 必须解析 JSONL / stderr 成功判据，不能只看 exit code。

注意：`xiaomi/*` 经 CLI/llm-server 返回的 402 `Insufficient account balance` 是 MiMo **反代防御**的伪装错误，不是真欠费；桌面官方客户端（`mimo-desktop`）可正常对话。CLI 无法使用桌面 provider，故本地 MiMo L3 在官方通道外记为 `anti-proxy-blocked` 并自动换候选。

```powershell
# DryRun：只输出会选中的候选与 fallback 链
pwsh -File ai-system/run-l3-worker.ps1 -TaskFile ai-system/tasks/l3-smoke-task.md -WorkerClass cheap -DryRun

# 真实下发：失败自动 Exclude 并沿 cheap 链回退
pwsh -File ai-system/run-l3-worker.ps1 -TaskFile ai-system/tasks/l3-smoke-task.md -WorkerClass cheap

# 只跑本地 MiMoCode 候选
pwsh -File ai-system/run-mimocode-worker.ps1 -TaskFile ai-system/tasks/l3-smoke-task.md -ModelSlot mimo-v2.6-flash -AutoApprove
```

## 当前接入状态

| 入口 | 状态 | 说明 |
|---|---|---|
| 国内 WorkBuddy CLI | 待 `/login` | CLI 可执行；模型列表为 `deepseek-v3-2-volc` / `glm-5.1` / `kimi-k2.5` / `minimax-m2.7` 等；当前报 `Authentication required`，需 TUI `/login` |
| 海外 WorkBuddyAI | CLI 未安装 | 本机仅有 WorkBuddy 国内；海外路径待安装后再验 |
| WorkBuddy Worker Body API | 适配器已完成 | 需要 `WORKBUDDY_ACCESS_TOKEN` 和云端绑定工作区 |
| MiMoCode CLI (`mimo run`) | anti-proxy-blocked | `xiaomi/*` 经 CLI/llm-server 返回 402 伪装「余额不足」，属反代防御；桌面 `mimo-desktop` 可用但 CLI 无法调用 |
| MiMoCode 桌面官方客户端 | 可用 | 仅人工/桌面会话；不作为无人值守 L3 执行器 |
| L3 自动下发 `run-l3-worker.ps1` | 管道已验证 | 已实测：候选失败 → Exclude → 换下一个 → 全失败报告；端到端出活取决于上游登录/通道 |
| OpenCode + Muse Spark 1.3 / Wiki | VERIFIED | 已有长期 Wiki Batch 生产记录 |
| OpenCode + Muse Spark 1.3 / Godot | PARTIALLY VERIFIED | #001/#002 两个受控任务完成；可用于低风险任务，但仍需 Codex 审查 |
| 豆包标准版 / doubao2api | BLOCKED | 运行时已安装；桌面端登录态不能直接复用为网页 Cookie，尚未形成可调用 Worker |
| TRAE Local API | 本机候选，API 层已验证 | 外部工具目录运行于 `localhost:19900`；CN 自动认证、`/v1/status`、`/v1/models`、Anthropic tool-call smoke 已通过；Claude Code CLI 端到端仍待验证 |
| FreeLLMAPI | 作为模型端点，不是 Worker | 当前无凭据请求返回 401，不宣称已接通 |
| Claude Code | 暂不启用 | 当前不经过 CCR；直连 FreeLLMAPI 需单独验证 |
| ZCode | 暂不桥接 | 当前只确认桌面 GUI，未确认稳定 CLI/API |
