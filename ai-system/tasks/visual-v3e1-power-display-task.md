# L3 任务包 · v3-E1 力量表现（一至七转，≥25 例）

```text
WORKFLOW ROLE: L3 Visual Lore Research Worker（READ ONLY 输入 / 只写一个产出文件）
UPSTREAM: Codex Orchestrator（L2）
DOWNSTREAM: Codex Review（L2） → L1（ChatGPT）方向裁决 → L0 批准

PROJECT GOAL:
为《问真》确定视觉设计自由度边界：原著哪些必须忠于，哪些可以自由创造。
CURRENT PHASE:
V2 需求重构期。L0 已禁止开发，只允许研究/采集/归纳。

TASK PURPOSE:
L1 的 v3 任务书 E 节要求用 ≥50 个战斗/催动案例检验一个命题：
「《蛊真人》的力量倾向具体化而非统一粒子特效」。
本子包承担其中 25 例：**一至五转 ≥15 例，六至七转 ≥10 例**。

TASK:
定向检索原文，取 25 个「力量出现」的案例，逐例记录 12 个字段：
力量来源 / 视觉起点 / 过程 / 命中表现 / 环境变化 / 身体变化 / 残留 /
是否纯能量表现 / 是否实体或半实体 / 是否只有结果没有过程描写 / 原文证据（行号 + ≤60 字短引）/ CANON CONSTRAINT

然后给出命题支持度（只能三选一）：SUPPORTED / PARTIAL / NOT_SUPPORTED，并列出**反例**（反例同样要行号+短引）。

⚠️ 不要检验「原著没有光效」——该命题已被 L1 明确废弃，本轮不要再论证它。

检索线索（自行扩展）：`杀招` `催动` `一掌` `一拳` `刀光` `剑光` `爆` `轰` `喷` `射出` `打在` `命中` `伤口` `残骸` `焦` `碎` `塌`。

SCOPE:
读：根目录 `蛊真人-clean.txt`、`ai-system/tasks/visual-v3-schema.md`（公共约定，必读）。
写：`ai-system/tasks/visual-v3e1-power-display.md`（唯一产物）。

DO NOT:
- 不得修改 wiki、game、任何已存在任务文件。
- 不得提画风结论（水墨/黑暗/二次元/赛博/写实），不得推荐配色、UI、角色造型、美术方案。
- 不得把采集包「转述」当引文；不得把归纳写成事实。
- 不得只挑支持命题的案例：反例必须如实列出。

DECISION AUTHORITY:
选哪些案例、如何判定「是否纯能量表现」，自行判断；须写明判定口径。

ESCALATE WHEN:
六至七转案例在原文中确实稀少到凑不出 10 例——停手上报实际数量，不要用五转以下补足。

DELIVERABLE:
`ai-system/tasks/visual-v3e1-power-display.md`：判定口径 / 25 条案例 / 命题支持度与反例 / 自查表。

ACCEPTANCE:
- ≥25 例，转数分布达标；每条有行号 + ≤60 字原文连续短引。
- 命题支持度必须三选一，并给出反例（哪怕 0 个也要写「未发现反例」并说明检索方式）。
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
