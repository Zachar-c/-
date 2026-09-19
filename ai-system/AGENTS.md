# AI System Agent Context

本目录是个人开发环境的执行约定，不是 Agent 平台。

## 命名消歧（2026-09-20）

`ai-system/PRD.md` **不是《问真》的 PRD**。它是本目录镜像来源项目 `my-ai-production-system`
的文档（`MyAIProductionSystem`，Vue3/FastAPI/Chroma），2026-09-18 已标注为历史设计记录。
它属镜像上游内容，**不得改名**（改名会破坏 `PROJECT_MAP.md` 登记的镜像映射）。

《问真》的产品权威只有 `docs/PRODUCT_REQUIREMENTS_v1.0.md`；层级与变更控制见根 `AGENTS.md`
的「文档权威链」「变更控制」两节。本目录的 `WORKER_PROTOCOL.md` 是执行纪律，**不是**产品规格。

## 默认角色

```text
Codex（默认大脑）
  ↓
OpenCode + Muse Spark 1.3（默认执行器）
  ↓
当前工作区 / 独立 worktree
```

- Codex 负责需求理解、拆解、边界、审查和最终决定。
- OpenCode + `opencode/muse-spark-1.3-contributor-free` 负责默认施工。
- 两者都是默认选择，不是永久绑定；不可用时才查找已配置且已验证的替代品。
- 不为可替换性新增 Brain/Executor/Provider 接口或调度框架。

## 免费 Worker 复用

- WorkBuddy 国内/海外四个已登记模型槽位是免费或优惠额度候选，不是默认大脑。
- 选择顺序只读 `config/model-rules.json` 的 `normal` / `hard` 静态链。
- 跳过未登录、不可用或不在时间窗口内的候选；固定池放链尾。
- 只在当前调用入口真实可用时复用额度；不伪造余额，不静默跳到链外模型。
- 默认执行器不可用时，按已配置候选顺序尝试；没有可验证候选就停止并报告，不自行接入新 Provider。
- Agent 不应把大量规划 token 花在模型挑选上：Codex 只给出 `normal` 或 `hard`，选择器负责静态链。

## 当前领域状态

```text
OpenCode + Muse Spark 1.3
  Wiki / 知识工程：VERIFIED
  Godot 软件工程：PARTIALLY VERIFIED；低风险任务可用，仍需 Codex Review

WorkBuddy
  Godot：CANDIDATE / BLOCKED；国内 CLI 曾有 401/挂起，未升为默认

Doubao / doubao2api
  本地运行时：已安装
  豆包桌面登录态复用：BLOCKED；当前未形成可调用 Worker

Claude Code / TRAE
  Godot：CANDIDATE / UNVERIFIED；暂不重开验证
```

不要把某个执行器的 Wiki 证据外推成其所有领域都已验证。

## 执行前后

执行前读取根 `AGENTS.md`、`PROJECT_MAP.md`、目标目录规则和本目录 `WORKER_PROTOCOL.md`。
执行后只提交事实、测试、diff 和 Caveman Review Packet；默认不 commit、merge、push。
Secrets 只在本机配置或进程环境中存在，不写入仓库。

## 停止条件

任务完成并通过验收后停止。不要因为发现免费额度、模型或 Agent 还能接入，就扩大任务、建设 Router 或继续搜索资源。
