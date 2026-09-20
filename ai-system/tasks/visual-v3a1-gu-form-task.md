# L3 任务包 · v3-A1 蛊的本体形态（一至三转凡蛊，≥20 只）

```text
WORKFLOW ROLE: L3 Visual Lore Research Worker（READ ONLY 输入 / 只写一个产出文件）
UPSTREAM: Codex Orchestrator（L2）
DOWNSTREAM: Codex Review（L2） → L1（ChatGPT）方向裁决 → L0 批准

PROJECT GOAL:
为《问真》确定视觉设计自由度边界：原著哪些必须忠于，哪些可以自由创造、现代化、重新设计。
CURRENT PHASE:
V2 需求重构期。L0 已禁止开发，只允许研究/采集/归纳。

TASK PURPOSE:
L1 的 v3 任务书 A 节要求：定向检索原文收集 ≥60 只蛊的本体形态，回答「蛊是否存在统一视觉语法」。
本子包承担其中 20 只：**一至三转凡蛊**。

TASK:
定向检索原文，取 20 只有形体描写的一至三转凡蛊，逐只记录 14 个字段（见下）。
字段：蛊名 / 转数 / 流派 / 本体是否直接描写 / 外形 / 材质 / 尺度 /
      是否生命化 / 是否器物化 / 是否植物化 / 是否人形拟人 / 是否抽象概念化 /
      催动时是否改变形态 / 原文证据（行号 + ≤60 字短引）/ CANON CONSTRAINT（HARD/SOFT/OPEN）
（三个「是否」类字段只答 是 / 否 / 原文未提供，不解释。）

检索线索（自行扩展，不要只搜这些）：`一转蛊` `二转蛊` `三转蛊`；
蛊名构词（X 蛊）；形体词 `外形` `巴掌` `拳头` `寸许` `通体` `表面` `像是` `好似` `仿佛` `一节` `一截`。

SCOPE:
读：根目录 `蛊真人-clean.txt`、`ai-system/tasks/visual-v3-schema.md`（公共约定，必读）。
写：`ai-system/tasks/visual-v3a1-gu-form.md`（唯一产物）。

DO NOT:
- 不得修改 wiki（lore/wiki/**）、game/**、任何已存在的任务文件。
- 不得提画风结论（水墨/黑暗/二次元/赛博/写实），不得推荐配色、UI、角色造型、美术方案。
- 不得把采集包的「转述」当引文写进「」；转述只能写成不带引号的转述句。
- 不得跨转数凑数。

DECISION AUTHORITY:
选哪 20 只、如何分类，自行判断；须在文件开头写明选取口径。

ESCALATE WHEN:
一至三转蛊的形体描写确实稀少（可采 < 20 只）——停手上报实际可采数量，不要用四转以上补足。

DELIVERABLE:
`ai-system/tasks/visual-v3a1-gu-form.md`：
选取口径 / 20 条记录（按公共约定 §0、§1 写）/ A1 段小结（回答「一至三转凡蛊是否有统一视觉语法」，没有就写「没有」）/ 自查表。

ACCEPTANCE:
- ≥20 只且全为一至三转；每条有行号 + ≤60 字原文连续短引。
- 原文没写的字段一律写「原文未提供」，不得留空、不得外推。
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
