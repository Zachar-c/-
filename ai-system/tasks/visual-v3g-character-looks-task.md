# L3 任务包 · v3-G1 人物外貌（≥30 人）

```text
WORKFLOW ROLE: L3 Visual Lore Research Worker（READ ONLY 输入 / 只写一个产出文件）
UPSTREAM: Codex Orchestrator（L2）
DOWNSTREAM: Codex Review（L2） → L1（ChatGPT）方向裁决 → L0 批准

PROJECT GOAL:
为《问真》确定视觉设计自由度边界：原著哪些必须忠于，哪些可以自由创造。
CURRENT PHASE:
V2 需求重构期。L0 已禁止开发，只允许研究/采集/归纳。

TASK PURPOSE:
L1 的 v3 任务书 G 节要求采集 ≥30 名人物的**直接外貌描写**，
回答「原著人物造型到底有多大自由度，是否存在统一的『古装仙侠制服』」。

TASK:
定向检索原文，取 30 名有直接外貌描写的人物，覆盖：
男女兼有（各 ≥10）；凡人 / 蛊师 / 蛊仙三档都有人；五域（南疆 / 北原 / 西漠 / 东海 / 中洲）每域 ≥3 人。
逐人记录 9 个字段：
姓名 / 身份与所属地域 / 服饰 / 发型 / 身体特征 / 装饰 / 气质 / 超凡痕迹（非人特征、异化、道痕等）/ 原文证据（行号 + ≤60 字短引）/ CANON CONSTRAINT

然后回答（写在文件末尾，标【分析】）：
1. 这些描写里有没有反复出现的固定套装/固定色/固定配饰？
2. **不要判断谁漂亮**，只写原著写了什么。

检索线索（自行扩展）：`身穿` `穿着` `一身` `长发` `头发` `面容` `相貌` `眉眼` `气质` `腰间` `袖` `袍` `裙` `甲` `面具` `纹` `须`。

SCOPE:
读：根目录 `蛊真人-clean.txt`、`ai-system/tasks/visual-v3-schema.md`（公共约定，必读）。
写：`ai-system/tasks/visual-v3g-character-looks.md`（唯一产物）。

DO NOT:
- 不得修改 wiki、game、任何已存在任务文件。
- 不得提画风结论，不得推荐配色、UI、角色造型、美少女化、美术方案。
- 不得judge美丑，不得把转述当引文。

DECISION AUTHORITY:
选哪 30 人、如何分域统计，自行判断；须写明选取口径与五域分布。

ESCALATE WHEN:
某域（尤其西漠/东海）确实找不到 ≥3 名有直接外貌描写的人物——停手上报实际分布，不要用其他域补足。

DELIVERABLE:
`ai-system/tasks/visual-v3g-character-looks.md`：选取口径与五域分布 / 30 条记录 / 是否存在统一制服的结论【分析】/ 自查表。

ACCEPTANCE:
- ≥30 人，性别与身份档位分布达标；每条有行号 + ≤60 字原文连续短引。
- 原文没写的字段写「原文未提供」。
- 无画风词、无美术建议、无美丑判断；自查表齐全。

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
