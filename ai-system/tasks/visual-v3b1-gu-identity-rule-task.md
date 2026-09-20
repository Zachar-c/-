# L3 任务包 · v3-B1 蛊的规则身份（≥30 只高辨识度蛊）

```text
WORKFLOW ROLE: L3 Visual Lore Research Worker（READ ONLY 输入 / 只写一个产出文件）
UPSTREAM: Codex Orchestrator（L2）
DOWNSTREAM: Codex Review（L2） → L1（ChatGPT）方向裁决 → L0 批准

PROJECT GOAL:
为《问真》确定视觉设计自由度边界：原著哪些必须忠于，哪些可以自由创造。
CURRENT PHASE:
V2 需求重构期。L0 已禁止开发，只允许研究/采集/归纳。

TASK PURPOSE:
L1 v3 任务书 B 节：选 ≥30 只高辨识度蛊，判断
> 外形和功能之间到底有多强的对应关系？
目的是确定《问真》重新设计蛊形象时到底有多少视觉自由度。

TASK:
定向检索原文，取 30 只高辨识度蛊（读者能叫出名字、在剧情中有分量的），逐只记录：
蛊名 / 转数 / 流派 / 外形 / 功能 / 代价 / 喂养 / 限制 / 使用结果 /
原文证据（行号 + ≤60 字短引，外形与功能各至少要有一条）/ CANON CONSTRAINT

然后逐只给「外形—功能对应强度」判定（只能三选一）：
**强对应**（外形直接提示功能）/ **弱对应**（外形与功能有隐约关联）/ **无明显对应**（两者无关）。
并统计三类的比例。

⚠️ 判定口径必须写明：什么算「外形直接提示功能」，什么算「隐约关联」。不要含糊。

检索线索（自行扩展）：蛊名（X 蛊）+ `外形` `功能` `效用` `代价` `喂养` `限制` `后遗症`。

SCOPE:
读：根目录 `蛊真人-clean.txt`、`ai-system/tasks/visual-v3-schema.md`（公共约定，必读）。
写：`ai-system/tasks/visual-v3b1-gu-identity-rule.md`（唯一产物）。

DO NOT:
- 不得修改 wiki、game、任何已存在任务文件。
- 不得提画风结论，不得推荐配色、UI、角色造型、美术方案。
- 不得把转述当引文；不得把归纳写成事实。
- 不得为了凑「强对应」而放宽口径——如果多数是无明显对应，就如实写。

DECISION AUTHORITY:
选哪 30 只、如何判定对应强度，自行判断；判定口径必须写明。

ESCALATE WHEN:
找不到 30 只同时有外形与功能描写的蛊——停手上报实际可采数量，不要用只有名字的蛊凑数。

DELIVERABLE:
`ai-system/tasks/visual-v3b1-gu-identity-rule.md`：判定口径 / 30 条记录（含逐只对应强度）/
三类比例统计 / 结论（外形—功能对应到底有多强）/ 自查表。

ACCEPTANCE:
- ≥30 只；每条有行号 + ≤60 字原文连续短引；外形、功能各有证据。
- 每只有明确的对应强度判定；比例统计与记录一致。
- 无画风词、无美术建议；自查表齐全。

STATUS TARGET: READY_FOR_REVIEW
```

## 返回格式

```text
STATUS: DONE / PARTIAL / BLOCKED
CHANGED:
FOUND:
EVIDENCE:
TESTS:
RISKS:
QUESTIONS:
```
