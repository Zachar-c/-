# REVIEW PACKET

## 0. Review Request

TASK:
Phase 2 首个真实 Godot Worker 任务

PHASE/BATCH:
Phase 2 / Executor 实证第 1 轮

STATUS:
PARTIAL

REVIEW TYPE:
implementation

REQUESTED DECISION:
是否批准当前小补丁，并接受“WorkBuddy 仍是候选、OpenCode 仅为备用线”的阶段结论。

---

## 1. Goal

本次原始目标：

- Codex 选择一个真实、低风险 Godot 任务。
- 在独立 worktree 中验证 Worker 执行、测试和 diff review 闭环。
- 核对模型名与 WorkBuddy 的生产层状态。

明确不属于本次范围：

- 新增 Provider、Router、Adapter 或动态学习。
- CCR、TRAE adapter、Claude Code 生产化。
- 提交、push、merge。

---

## 2. Delta Since Last Review

ADDED:
- `phase2-first-godot-task.md`：真实任务 brief。
- `phase2-first-godot-task-result.md`：本轮执行记录。
- `run_controller` 目录复用回归测试。

CHANGED:
- 全部配置/文档统一为 `opencode/muse-spark-1.3-contributor-free`。
- WorkBuddy CLI 从默认执行层降为优先验证候选。
- `RunController` 开局复用已加载目录；空目录仍加载，已有目录重新校验。

REMOVED:
- NONE。

UNCHANGED BUT VERIFIED:
- `normal / hard` 静态选择器。
- 不伪造余额、不静默跳链外模型。

---

## 3. Current State

- Codex 规划/审查：VERIFIED。
- WorkBuddy CLI：PARTIALLY VERIFIED；存在 CLI，但真实任务遇到 401 与挂起。
- OpenCode + Muse Spark：PARTIALLY VERIFIED；能产出补丁，但本轮未自主完成协议摘要与验收。
- TRAE Local API：PARTIALLY VERIFIED；本地 API/tool-call 可用，Claude CLI 端到端 BLOCKED。
- 当前默认生产执行层：UNVERIFIED；没有冻结。

---

## 4. Files Changed

modified: 2 in worker worktree; added: 1 test. 另有 ai-system 配置、文档和本审阅记录。

```text
game/scripts/presentation/run_controller.gd
- 移除 normal/M0 开局的重复全量目录解析。
- 保留空目录加载与已有目录校验。

game/tests/unit/test_run_controller_catalog_reuse.gd
- 覆盖目录复用、headless fallback、非法内容拒绝。

ai-system/config/common.json
- 修正精确模型 ID与 WorkBuddy 候选状态。
```

---

## 5. Verification Evidence

### Automated Checks

```text
command: Godot GUT focused test
result: 5/5 tests, 15 asserts passed

command: 5 relevant RunController/runtime test files
result: all passed

command: Godot GUT -gdir res://tests/unit
result: 217 scripts, 1586 tests, 52688 asserts passed
```

### Real Runtime Checks

```text
scenario: WorkBuddy domestic Hy4 executes real task
expected: Worker summary and patch
actual: 401 Authentication required
result: FAIL

scenario: WorkBuddy domestic DeepSeek executes fallback
expected: Worker summary and patch
actual: ~2 minutes no result; stopped
result: FAIL

scenario: OpenCode + muse-spark executes task in isolated worktree
expected: bounded patch
actual: bounded patch produced; Codex 修正校验边界并完成验证
result: PARTIAL
```

### Not Verified

- WorkBuddy CLI 首次真实任务成功。
- OpenCode Worker 无 Codex 接管的一次通过。
- Claude Code CLI 经 TRAE 稳定施工。

---

## 6. Git Evidence

```text
git status:
main ahead of origin/main with existing dirty changes preserved;
worker branch codex/phase2-first-godot-task has the two task files changed.

git diff --stat:
worker: run_controller.gd 21 lines changed; one added test file.

git diff --check:
PASS in worker worktree

commit: NONE
push: NONE
```

---

## 7. Known Problems

ISSUE:
WorkBuddy 国内 CLI 返回 401；DeepSeek fallback 挂起。
影响：真实生产执行链尚未打通。
NEW OR PRE-EXISTING:
new
BLOCKING:
yes
RECOMMENDED ACTION:
保持候选状态，不继续扩展；以后仅在明确授权时复验。

ISSUE:
`game/tools/test.ps1` 包装器在本机环境未正常产出 GUT 结果。
影响：使用直接 Godot 命令完成验证。
NEW OR PRE-EXISTING:
pre-existing/environmental
BLOCKING:
no
RECOMMENDED ACTION:
暂不改测试基础设施。

---

## 8. Assumptions / Unproven Claims

UNPROVEN:
OpenCode + Muse Spark 能稳定完成后续长任务。

EVIDENCE SO FAR:
本轮产生了范围内补丁，完整 unit 通过。

MISSING:
Worker 自己返回协议摘要并一次通过验收。

UNPROVEN:
WorkBuddy 的免费额度/模型优先顺序可长期保持。

EVIDENCE SO FAR:
选择器输出了当前静态 fallback 链。

MISSING:
稳定的 CLI 认证与真实任务成功记录。

---

## 9. Decisions Needed From Reviewer

D1:
是否批准 `RunController` 补丁？
推荐：YES
理由：范围小，新增回归覆盖，完整 unit 全通过。

D2:
是否把 WorkBuddy CLI 升级为默认生产执行层？
推荐：NO
理由：真实任务仍被 401/挂起阻断。

D3:
是否继续为 Claude Code → TRAE 开发 adapter？
推荐：NO
理由：Gate A 端到端复验未完成，且本轮目标已足够判断风险。

D4:
是否批准合并 worktree？
推荐：等待 D1 明确批准后再执行；当前不合并。

---

## 10. Proposed Next Step

如果审阅通过，只执行：

1. 按审阅意见确认或修改当前 worktree 补丁。
2. 用户明确授权后，才考虑合并/提交。
3. 保留 WorkBuddy 候选与 OpenCode 备用定位，不扩建基础设施。
4. STOP。

---

## 11. Reviewer Fast Path

RECOMMENDED VERDICT:
APPROVE_WITH_CHANGES

WHY:
补丁范围受控，完整 unit 通过，未越界。
WorkBuddy 真实链路仍失败，不能升级默认执行层。
OpenCode 只证明了备用施工能力，未证明无人接管一次通过。

MUST FIX BEFORE NEXT PHASE:
1. 保持当前执行器状态定义，不得宣称 WorkBuddy 已是默认层。
2. 只有明确批准后才合并 worktree。

CAN DEFER:
1. WorkBuddy CLI 认证与稳定性复验。
2. Claude Code → TRAE 的后续适配。
