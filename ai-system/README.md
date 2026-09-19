# 个人 AI 开发环境

这是个人开发环境的最小实现，不是 Agent 平台。

## 当前状态

Phase 1：基础环境完成。默认链是 `Codex → OpenCode + Muse Spark 1.3`；WorkBuddy CLI/Worker Body 是免费额度执行候选，不是默认执行层。OpenCode + Muse Spark 1.3 在 Wiki / 知识工程线上已验证，在 Godot 软件工程线上仍为部分验证。

WorkBuddy 适配器已完成请求体构造和提交逻辑，首次真实任务仍需线上冒烟验证。云端 Worker 不能直接读取调用机器上的本地绝对路径。

## 当前关系

```text
Codex / gpt-5.6-luna（默认，可替换）
        |
        v
OpenCode + Muse Spark 1.3（默认，可替换）
        |
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

```text
ai-system/
├─ ARCHITECTURE.md       # 一页架构约定
├─ WORKER_PROTOCOL.md    # Worker 输入输出与边界
├─ WORKER_HANDOFF_TEMPLATE.md # Caveman 短审阅包模板
├─ bootstrap.ps1         # 检查工具、配置和模型，不安装依赖
├─ run-worker.ps1        # 用 OpenCode 在本地启动一次 Worker
├─ run-workbuddy-cli-worker.ps1 # 用 WorkBuddy CLI 在本地启动一次 Worker
├─ run-workbuddy-worker.ps1 # 将 Worker Body 投递到 WorkBuddy 云端
├─ choose-worker-model.ps1 # 按 normal/hard 静态 fallback 链选择模型
└─ config/
   ├─ common.json        # 可共享配置
   ├─ home.example.json  # 家庭环境模板
   ├─ work.example.json  # 公司环境模板
   └─ secrets.example.json
```

## 使用

```powershell
pwsh -File ai-system/bootstrap.ps1 -Profile home
pwsh -File ai-system/bootstrap.ps1 -Profile home -VerifyModel
pwsh -File ai-system/run-worker.ps1 -Profile home -TaskFile path/to/task.md

# Codex 只指定 normal 或 hard；选择器按配置中的静态 fallback 链输出顺序
pwsh -File ai-system/choose-worker-model.ps1 -WorkerClass normal -DomesticReady -OverseasReady
pwsh -File ai-system/choose-worker-model.ps1 -WorkerClass hard -DomesticReady -OverseasReady

# 规则输出 domestic/deepseekV41 后再执行；国内 DeepSeek 为 0.03 倍优惠
pwsh -File ai-system/run-workbuddy-cli-worker.ps1 -Body domestic -ModelSlot deepseekV41 -TaskFile path/to/task.md -AutoApprove

# 23:00–08:00 规则会把复杂任务优先选到国内 Hy4 preview
pwsh -File ai-system/run-workbuddy-cli-worker.ps1 -Body domestic -ModelSlot hunyuan4 -TaskFile path/to/task.md -AutoApprove

# WorkBuddy Worker Body：任务文件会作为 POST /openapi/v2/tasks 的 prompt
$env:WORKBUDDY_ACCESS_TOKEN = '<local-only-token>'
pwsh -File ai-system/run-workbuddy-worker.ps1 -TaskFile path/to/task.md -Title 'Godot task'
```

`config/home.json`、`config/work.json` 和 `config/secrets.json` 只存在于本机，不提交到 Git。WorkBuddy Token 只放本机 Secret 或进程环境，不写入共享配置。

如需调用 WorkBuddyAI 的同类 CLI，可传入它的 `codebuddy` 路径：

```powershell
pwsh -File ai-system/run-workbuddy-cli-worker.ps1 `
  -CliPath "$env:LOCALAPPDATA\Programs\WorkBuddyAI\resources\app.asar.unpacked\cli\bin\codebuddy" `
  -Body overseas -ModelSlot deepseekV41 -TaskFile path/to/task.md -AutoApprove
```

如果本机没有 OpenCode CLI，Bootstrap 会报告缺失；不会把桌面端、其他模型或其他 Provider 静默当成替代品。需要替代时，只从已配置且已验证的候选中选择。

WorkBuddy CLI 复用本机登录态和免费额度，不把凭据写入仓库。WorkBuddy 云端适配只负责把现有 Worker Protocol 投递到任务 API，不改变 Worker 契约，也不保存 OAuth 凭据；云端任务需要 WorkBuddy 侧已经绑定或同步目标仓库。

模型规则选择：

```powershell
# normal: 日常代码、审查、批处理
pwsh -File ai-system/choose-worker-model.ps1 -WorkerClass normal -OverseasReady -DomesticReady

# hard: 复杂代码、Godot 核心改动、架构任务
pwsh -File ai-system/choose-worker-model.ps1 -WorkerClass hard -OverseasReady -DomesticReady

# 某个候选本次任务失败后，显式排除它并取下一个
pwsh -File ai-system/choose-worker-model.ps1 -WorkerClass hard -OverseasReady -DomesticReady -ExcludeCandidate overseas/hunyuan4
```

当前只维护两条静态链：

```text
normal:
  overseas DeepSeek daily
  → domestic Hy4 night-free
  → overseas Hy4 daily
  → domestic DeepSeek fixed-pool

hard:
  overseas Hy4 daily
  → domestic Hy4 night-free
  → overseas DeepSeek daily
  → domestic DeepSeek fixed-pool
```

选择器只做三件事：读取链、跳过未启用/未登录/不在时间窗口内的候选、输出 primary 和剩余 fallbackChain。它不维护性能分数、余额状态、健康评分或自动学习。模型失败、额度错误和重试由调用方/Worker 执行层处理；不静默切换到链外模型。

## 当前接入状态

| 入口 | 状态 | 说明 |
|---|---|---|
| 国内 WorkBuddy | CLI 已接通 | `Hy4 preview` 夜间免费；`Deepseek-V4.1-Flash` 低价优惠；两者均有额度限制 |
| 海外 WorkBuddyAI | GUI 模型已确认，CLI 待认证 | `Hy4 preview`、`Deepseek-V4.1-Flash` 均显示免费，但 CLI 当前返回 401；GUI 登录态尚未共享给 CLI |
| WorkBuddy CLI 冒烟 | 已完成 | 已验证返回 `BRIDGE_READY`，本次成本为 0 |
| WorkBuddy Worker Body API | 适配器已完成 | 需要访问令牌和云端绑定工作区 |
| OpenCode + Muse Spark 1.3 / Wiki | VERIFIED | 已有长期 Wiki Batch 生产记录 |
| OpenCode + Muse Spark 1.3 / Godot | PARTIALLY VERIFIED | #001/#002 两个受控任务完成；可用于低风险任务，但仍需 Codex 审查 |
| 豆包标准版 / doubao2api | BLOCKED | 运行时已安装；桌面端登录态不能直接复用为网页 Cookie，尚未形成可调用 Worker |
| TRAE Local API | 本机候选，API 层已验证 | 外部工具目录运行于 `localhost:19900`；CN 自动认证、`/v1/status`、`/v1/models`、Anthropic tool-call smoke 已通过；Claude Code CLI 端到端仍待验证 |
| FreeLLMAPI | 作为模型端点，不是 Worker | 当前无凭据请求返回 401，不宣称已接通 |
| Claude Code | 暂不启用 | 当前不经过 CCR；直连 FreeLLMAPI 需单独验证 |
| ZCode | 暂不桥接 | 当前只确认桌面 GUI，未确认稳定 CLI/API |
