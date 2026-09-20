# L3 任务包 · v3-D1 五域组织制度（≥25 个组织案例）

```text
WORKFLOW ROLE: L3 Visual Lore Research Worker（READ ONLY 输入 / 只写一个产出文件）
UPSTREAM: Codex Orchestrator（L2）
DOWNSTREAM: Codex Review（L2） → L1（ChatGPT）方向裁决 → L0 批准

PROJECT GOAL:
为《问真》确定视觉设计自由度边界：原著哪些必须忠于，哪些可以自由创造。
CURRENT PHASE:
V2 需求重构期。L0 已禁止开发，只允许研究/采集/归纳。

TASK PURPOSE:
L1 v3 任务书 D 节。**L1 明确要求：停止用「宗门」单词计数推断制度**，改为逐域取组织案例。
本子包承担：南疆 / 北原 / 西漠 / 东海 / 中洲，**每域 ≥5 个组织案例（合计 ≥25）**。

TASK:
定向检索原文，逐域取组织案例，每条记录 9 个字段：
组织名称 / 类型（家族 / 门派 / 部族 / 联盟 / 其他）/ 权力来源 / 传承方式 /
人才进入方式 / 建筑·服饰·仪式的直接描写 / 血缘的重要程度 / 原文证据（行号 + ≤60 字短引）/ CANON CONSTRAINT

特别验证（写在小结里，给支持度 SUPPORTED / PARTIAL / NOT_SUPPORTED）：
> 中洲的宗派制度与其他四域的家族/血缘体系，到底有何结构差异？

检索线索（自行扩展）：`家族` `族长` `族老` `宗祠` `祠堂` `门派` `宗派` `部族` `联盟` `散修`
`弟子` `招收` `长老` `大殿` `仪式` `祭祀` `谱系` `血脉`。

SCOPE:
读：根目录 `蛊真人-clean.txt`、`ai-system/tasks/visual-v3-schema.md`（公共约定，必读）。
写：`ai-system/tasks/visual-v3d-five-regions-org.md`（唯一产物）。

DO NOT:
- 不得修改 wiki、game、任何已存在任务文件。
- 不得用单个词的命中计数代替制度判断（L1 明确否定了这种做法）。
- 不得提画风结论，不得推荐配色、UI、角色造型、美术方案。
- 不得把转述当引文；不得把归纳写成事实。

DECISION AUTHORITY:
每域选哪些组织自行判断；须给出五域分布与小域的处理说明。

ESCALATE WHEN:
某域确实找不到 ≥5 个有直接描写的组织——停手上报实际分布，不要用其他域补足。

DELIVERABLE:
`ai-system/tasks/visual-v3d-five-regions-org.md`：检索口径 / 五域分布 / ≥25 条记录 / 中洲 vs 其余四域结构差异的支持度结论 / 自查表。

ACCEPTANCE:
- ≥25 条且五域各 ≥5；每条有行号 + ≤60 字原文连续短引。
- 原文没写的字段写「原文未提供」；无画风词、无美术建议；自查表齐全。

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
