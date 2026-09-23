# AI 开发环境架构

## 当前状态

Phase 1：基础环境完成。默认链是 `Codex → OpenCode + Muse Spark 1.3`。WorkBuddy CLI/Worker Body 保留为免费额度执行候选；OpenCode + Muse Spark 1.3 在 Wiki / 知识工程线上已验证，在 Godot 软件工程线上仍为部分验证。

WorkBuddy CLI 桥接器已完成启动逻辑，但仍需要用一个真实任务完成首次冒烟。没有完成冒烟前，不宣称 Worker 已经稳定完成任务。

模型选择只维护两条静态 fallback 链：`normal` 和 `hard`。Codex 判断任务类别，选择器按配置顺序跳过未启用、未登录或不在时间窗口内的候选；固定积分池始终放在链尾。不维护性能分数、余额状态、健康评分或自动学习，也不静默切换到链外模型。

## 当前主线

Codex（默认规划与审查）负责理解需求、拆任务、确定边界和最终 Review。OpenCode + Muse Spark 1.3 是默认施工线；WorkBuddy CLI/Worker Body 只在已登录且可验证时复用其免费/优惠额度，不把候选职位先写成生产事实。

```text
Codex / gpt-5.6-luna（默认，可替换）
        ↓
OpenCode + Muse Spark 1.3（默认，可替换）
        ↓
当前仓库工作区
        ↓
测试与 Review
```

默认执行器不可用时，才查找 `config/model-rules.json` 中已配置的 WorkBuddy 候选；候选按 `normal` / `hard` 静态链执行，固定池在链尾。没有可验证候选则停止，不新增 Router 或 Provider。

WorkBuddy Worker Body API 仍可用于已经绑定仓库的云端工作区；它不读取调用机器的本地绝对路径。桥接脚本只投递任务体，不伪造本地文件访问。

## 按工作领域记录执行状态

执行器状态不做全局合并：同一执行器在不同工作领域分别记录。当前只保留文档状态，不新增 capability matrix、数据库或评分系统。

```text
OpenCode + Muse Spark 1.3
  Wiki / 知识工程：VERIFIED
  Godot 软件工程：PARTIALLY VERIFIED

WorkBuddy
  Godot 软件工程：CANDIDATE / BLOCKED

Claude Code
  Godot 软件工程：CANDIDATE / UNVERIFIED

TRAE Local API
  API / tool-call：PARTIALLY VERIFIED
  Claude Code E2E：BLOCKED
```

OpenCode + Muse Spark 1.3 已可用于需 Codex 审查的低风险 Godot 任务；当前仍是 PARTIALLY VERIFIED，尚未证明独立完成，不把 Wiki 线上证据重新验证一遍。

```text
Codex / gpt-5.6-luna
        ↓
OpenCode
        ↓
opencode/muse-spark-1.3-contributor-free
```

豆包标准版当前只记录为候选阻塞：`doubao2api` 运行时已安装，但桌面端登录态不能直接复用为网页 Cookie，尚未通过 Worker smoke；不作为可调用免费 Worker。

模型名称必须来自 OpenCode 当前模型目录的精确返回值。配置中的 `verifyExactModel=true` 禁止自动降级到相近模型。

## 配置边界

```text
common.json       共享角色、命令约定和模型目标
home.json         家庭机器路径与开关
work.json         公司机器路径与开关
secrets.json      本机凭据引用或 Secret 名称
```

共享文件不保存 API key、Token、密码、机器绝对路径或账号信息。WorkBuddy 访问令牌只从本机 Secret/进程环境读取；OpenCode 登录状态由本机 CLI 管理。

## 一个真实任务的完成标准

1. Codex 写出任务简报和验收命令。
2. 一个 Worker 领取任务，不扩展范围。
3. Worker 修改代码并运行指定测试。
4. Codex 检查 diff、测试结果和剩余风险。
5. 任务以一个小而可回退的 Git 提交结束。

没有第二个调度器、没有 Provider Router、没有通用 Agent 注册表。默认大脑和默认执行器都可替换；替换只从已配置且已验证的候选中选择，不抽象成新的 Agent 平台。

## Jev System One（实验，非默认）

唯一允许的实验旁路是 `jev_systemone.py`：对「任务该走 normal / hard / escalate」做类型化 Choice 提议（OpenRouter `POST /api/alpha/decisions`，model `typesafe/jev-1.13`），结果只是 decision proposal + confidence。它不写代码、不改架构、不替代 Codex/OpenCode、不进入无 fallback 的关键路径。现有 `choose-worker-model.ps1` 静态链仍是执行选择权威；Jev 仅在高置信时把任务映射到既有 `WorkerClass` 接口。
