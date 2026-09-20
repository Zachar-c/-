# L3 任务包 · v3-C1 炼蛊与杀招的组合关系（炼蛊 ≥15 + 杀招 ≥20）

```text
WORKFLOW ROLE: L3 Visual Lore Research Worker（READ ONLY 输入 / 只写一个产出文件）
UPSTREAM: Codex Orchestrator（L2）
DOWNSTREAM: Codex Review（L2） → L1（ChatGPT）方向裁决 → L0 批准

PROJECT GOAL:
为《问真》确定视觉设计自由度边界：原著哪些必须忠于，哪些可以自由创造。
CURRENT PHASE:
V2 需求重构期。L0 已禁止开发，只允许研究/采集/归纳。

TASK PURPOSE:
L1 v3 任务书 C 节（本批非常重要）。L1 原话：
「不得先接受任何人的理论」——请只从原文找证据，验证
> 炼蛊 / 杀招 / 蛊阵 / 蛊屋 能否合理抽象为「规则模块的不同组合形态」？
本子包承担前两组：**炼蛊 ≥15 例 + 杀招 ≥20 例**（蛊阵/蛊屋由 v3-C2 承担）。

TASK:
定向检索原文，取案例，逐例记录：
组成单位 / 组合是否固定 / 是否可移动 / 是否需要持续操控 / 是否能拆解 / 是否能改良 /
是否存在核心蛊 / 原著如何描述其关系 / 原文证据（行号 + ≤60 字短引）/ CANON CONSTRAINT
（对某一组不适用的字段，写「不适用」并说明理由；原文没写的写「原文未提供」。）

两组分别小结，给出支持度（只能三选一）：SUPPORTED / PARTIAL / NOT_SUPPORTED，并附反例。
**禁止提前设计**：不要写「应该怎么建」，只写原著里是什么关系。

检索线索（自行扩展）：
- 炼蛊：`炼蛊` `炼制` `合炼` `蛊方` `材料` `投入` `火候` `失败` `反噬` `化身`
- 杀招：`杀招` `核心蛊` `组合` `催动` `合击` `两蛊` `数蛊`

SCOPE:
读：根目录 `蛊真人-clean.txt`、`ai-system/tasks/visual-v3-schema.md`（公共约定，必读）。
写：`ai-system/tasks/visual-v3c1-refine-and-killer-moves.md`（唯一产物）。

DO NOT:
- 不得修改 wiki、game、任何已存在任务文件。
- 不得引用任何人的既有理论（包括既有 wiki 与采集件的结论）作为依据，只能引原文。
- 不得提画风结论，不得推荐配色、UI、角色造型、美术方案。
- 不得把转述当引文；不得把归纳写成事实。

DECISION AUTHORITY:
选哪些案例自行判断；须写明检索口径与两组各自的案例数。

ESCALATE WHEN:
某一组（尤其炼蛊）可用案例确实不足配额——停手上报实际数量，不要用另一组凑数。

DELIVERABLE:
`ai-system/tasks/visual-v3c1-refine-and-killer-moves.md`：检索口径 / 炼蛊 ≥15 例 / 杀招 ≥20 例 /
两组各自的支持度结论与反例 / 自查表。

ACCEPTANCE:
- 炼蛊 ≥15、杀招 ≥20；每条有行号 + ≤60 字原文连续短引。
- 支持度必须三选一；反例如实列出（0 个也要说明检索方式）。
- 无画风词、无美术建议、无提前设计；自查表齐全。

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
