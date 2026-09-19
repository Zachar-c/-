# 原文正典核验：魂道（只读检索，产出带行号的证据报告）

```text
WORKFLOW ROLE
L3 Worker

UPSTREAM
L2 Orchestrator

DOWNSTREAM
L2 Review → L1 研究院（魂道闭环设计）→ L0 数值裁定

PROJECT GOAL
把「魂」从一个固定 1–4 的风险条，重新建立成**可成长的 Build Axis（魂道玩法）**。
L0 已给出原文口径的产品意图（RUL-2026-09-19-005），但 L2 预检发现：
当前游戏里 40 只魂道蛊有 36 只在原文里没有着落。
在按原文重修魂道内容之前，必须先把**原文到底写了什么**核实清楚。

CURRENT PHASE
`RUL-2026-09-19-005`（`game/world-model/rulings/`）已生效，摘要：
- 魂魄的**当前值需要与上限值分离**
- AP 档位的原始设计意图 = 参照原文的 百人魂 / 千人魂 / 万人魂，各自对应一个档位
- 允许**改造现有魂道蛊虫的效果**，让它们利用自身积累的魂道打出更好效果
- 魂与肉身 / 真元 / 资质 / 修为**共用同一份资源池**（元石等），互相抢资源是设计意图
- 对 L0 汇报禁止使用「数据层 / 引擎层」这类工程术语

TASK PURPOSE
L2 已用整词统计做过一轮筛查，本任务做**语境级**核验：
把「原文怎么写的」落到**行号 + 原文短引**，并明确区分
「原文确有此机制」/「原文只有相关词但不是这个意思」/「原文查无此物」。

TASK
只读检索原文全文，逐条回答下列 8 个问题。**每条必须给出：行号 + 原文短引（≤60 字）
+ 判定（`CONFIRMED` / `NOT_FOUND` / `AMBIGUOUS`）+ 你的解读（与原文分开标注）。**

**Q1. `魂魄底蕴` 到底指什么？**（原文命中 187 次——本任务最重要的一问）
- 它是可增长的**存量数值**，还是身份/境界等级，还是泛称？
- 有没有「提升 / 增长 魂魄底蕴」的具体动作描述？谁做的、靠什么做的、代价是什么？
- 是否有量化的表述（如「百人魂」这种规模词）？
- **这一问决定「魂作为可成长属性」在原文是否站得住**，请多取样（≥10 处语境，覆盖不同章节）。

**Q2. `百人魂 / 千人魂 / 万人魂` 三档的完整语境**
- 各自在什么场景被提到？是境界、规模、还是别的度量？
- 如何达到？是否有更高档（如十万人魂）？三档之间差别是什么？
- 已知线索：`狼魂蛊` 段落出现「一只三转的狼魂蛊还不足以凝练方源的百人魂」。

**Q3. `狼魂蛊` → `狼魂` 的改造过程**
- 「人魂改造成兽魂」的原文表述是什么？代价、后果、限制？
- 原文有无「兽魂蛊」这个统称（三字命中 0），还是用「X魂蛊」这种族名（神魂蛊、龙魂蛊……）？
- 「自古奴魂不分家」的完整语境。
- 已知：三转狼魂蛊售价七千七百枚元石；效用可叠加；八只狼魂蛊仍不足以凝练百人魂。

**Q4. `挡尸蛊` / `撞魂` 对应原文哪个概念？**
- 这两个词在原文**零命中**。按概念检索：`尸` + `挡` / `撞` + `魂`。
- 候选线索：`僵尸蛊` 8 次、`尸蛊` 32 次。
- 若确实查无此物，明确写 `NOT_FOUND`，不要为凑答案做联想。

**Q5. 「能凝魂」名录的完整语境（15 只）**
- 原文：「神魂蛊、龙魂蛊、冰魂蛊、梦魂蛊、月魂蛊、将魂蛊、怨魂蛊、诗魂蛊、马魂蛊、英魂蛊、
  气魄蛊、体魄蛊、云魄蛊、风魄蛊、虎魄蛊种种。这些蛊虫，都能凝魂。」
- `凝魂` = 什么操作？产出什么？与 `壮魂` / `炼魂` / `安魂` 是同一体系吗？
- 这份名录是否还有上下文列出的更多名字？

**Q6. 落魄谷的「炼魂三首选」全貌**
- 原文片段：「壮魂首选荡魂山胆识蛊，炼魂首选落魄谷中的**雾、落魄风。安魂首选**湖中安魂汤。」
  （其中 `**` 是文本清洗残留的占位符，不是原文用字——请特别留意并说明它遮蔽了什么）
- `落魄谷` 是地名还是蛊名？（L2 预检：数据里的「落魄蛊」很可能是把地名误读成蛊）
- `炼魂` 的具体做法、代价、产出是什么？

**Q7. 魂道蛊的喂养 / 成长在原文如何运作**
- 「狼魂蛊效用可叠加」是一例，还有无其他机制（喂养、吞并、晋升）？
- 魂道蛊的转数晋升有无原文依据？

**Q8. 魂道与其他流派（白/黑/血/骨/奴/梦等）的克制与兑换关系**
- 原文有无明确表述「魂道克 X」「X 克魂道」或「拿 A 换魂」？
- 有无「魂道蛊贵/稀有」这类经济表述（狼魂蛊 7700 元石是一例）？

SCOPE
只读：`蛊真人-clean.txt`（**仓库根目录**，23,609,617 字节 ≈ 858 万字，UTF-8）、
      `game/data/`、`game/world-model/data/`、`lore/wiki/`
只写（仅此两处）：
- `game/world-model/reports/soul-canon-verification.md`（核验报告）
- `ai-system/tasks/canon-soul-verification-result.md`（Caveman Review Packet）

DO NOT
- **禁止修改任何其他文件**。本任务除上述两个新文件外**纯只读**。
- 特别禁止：`game/data/**`、`game/scripts/**`、`game/scenes/**`、`game/world-model/data/**`、
  `game/world-model/rulings/**`、`game/docs/**`、`lore/**`、`source/**`
- **禁止把 `蛊真人-clean.txt` 复制、移动、改名、提交或写入任何其他文件**
  （该文件已被 `.gitignore:13` 忽略，必须保持不被 Git 追踪）
- **禁止大段抄录原文**：报告中的原文引用**每条 ≤60 字**，只作证据用；
  禁止成段复制章节内容到报告里
- **禁止提出数值建议或内容设计建议**。本任务只回答「原文写了什么」。
  如需指出设计空间，写在 `[INFERRED]` 并标注「供 L1 参考，非建议」
- 禁止 commit / push / merge / stash / reset
- 禁止新增依赖（仅标准库）
- 禁止把 L2 的预检结论当事实照抄——**必须自己回到原文复核每一条**

DECISION AUTHORITY
可自行决定：检索方式、取样数量、报告章节组织、如何标注证据强度。
不可自行决定：魂的数值、魂道内容怎么改、哪些蛊该保留或删除。

ESCALATE WHEN
- Q1（魂魄底蕴是什么）在原文中找不到明确答案——这会让 RUL-2026-09-19-005 的核心主张悬空
- 发现原文存在与 L0 描述**方向相反**的表述（例如「魂魄不可增长」）
- 发现原文中魂道机制比预期复杂得多（例如存在完整修炼体系但与本仓设定冲突）
- 需要读 `蛊真人.txt`（未清洗版）才能判断——先上报，不要自行改读文件

DELIVERABLE
`game/world-model/reports/soul-canon-verification.md`，含：
1. Q1–Q8 逐条回答，每条：行号 + 原文短引（≤60 字）+ 判定 + 解读
2. **一张「原文魂道名词表」**：原文名词 → 命中次数 → 类别（蛊 / 地名 / 功法 / 度量 / 泛称）
   → 是否已在当前游戏数据中（对照 `game/data/gu_names.json` 的 802 条）
3. **一段「L0 主张复核表」**：`RUL-2026-09-19-005.canon_claims_pending_verification` 的
   6 条主张，逐条给出 `CONFIRMED` / `PARTIAL` / `CONTRADICTED` / `NOT_FOUND` 与证据行号
4. Caveman Review Packet（`ai-system/WORKER_HANDOFF_TEMPLATE.md`）

ACCEPTANCE
- Q1–Q8 每条都有回答，且**每条都带行号 + ≤60 字原文短引**；查无此物的必须明写 `NOT_FOUND`
- Q1 取样 ≥10 处不同章节的语境
- 报告中的每个原文数字（命中次数）可被独立复算
- 原文引用总量受控：单条 ≤60 字，全报告引用合计 ≤3000 字
- 顶部注明检索用的原文文件路径、字节数、检索方法
- `git status --porcelain` 显示**除两个新文件外零改动**；
  `git status --porcelain` 中**不得出现 `蛊真人-clean.txt`**
- 报告中不出现任何数值建议

STATUS TARGET
READY_FOR_CANON_REVIEW
```

## 技术事实（已由 L2 核实，Worker 不必重新考古）

| 事实 | 证据 |
|---|---|
| 原文文件位置 | 仓库根目录 `蛊真人-clean.txt`，23,609,617 字节，8,587,697 字符（UTF-8） |
| 该文件不受版本控制 | `.gitignore:13` 已忽略；`git status --porcelain` 中不出现 |
| 同目录另有未清洗版 | `蛊真人.txt`（`.gitignore:12`）；本任务**只需读 clean 版** |
| worktree 副本 | `.worktrees/phase2-*/蛊真人-clean.txt` 各有一份，**不要读**，避免版本混淆 |
| 裁定文件 | `game/world-model/rulings/RUL-2026-09-19-005.json`，JSON 已校验合法 |
| Python | `C:\Users\90877\.workbuddy\binaries\python\versions\3.13.12\python.exe`（实测 3.13.14）；`python` 不在 PATH |
| 终端编码坑 | Windows 控制台是 gb2312，**必须** `PYTHONIOENCODING=utf-8`，否则中文输出全乱码 |
| 本仓 `.ps1` 必须纯 ASCII | PS 5.1 对无 BOM 文件按 ANSI 解析，中文注释直接造成语法错误 |
| 文本清洗残留 | 原文里 `**` 是清洗占位符（例：「\*\*魂首选荡魂山胆识蛊」），**不是**原文用字，遇到须说明 |

### L2 预检结果（供参考，**必须自行复核**）

**方法说明**：用 `gu_names.json` 的 776 个名字做**最长匹配切词**统计整词频次。
不能直接 `text.count(名字)`——短名会被长名包含。已证反例：`灯蛊` 裸数 40，
其中 39 来自 `魂灯蛊`、1 来自 `兜率灯蛊`，**独立出现 0 次**。

| 检索词 | 裸数 | 整词 | L2 判定 |
|---|---|---|---|
| 魂魄底蕴 | 187 | — | 待 Q1 定性（本任务最重要） |
| 百人魂 / 千人魂 / 万人魂 | 44 / 30 / 62 | — | 确为原文概念 |
| 狼魂蛊 | 50 | — | 真蛊名，证据充分 |
| 净魂仙蛊 | 105 | 105 | 真蛊名（杀招「万我」核心蛊） |
| 命牌蛊 | 47 | 47 | 真蛊名（武家宗祠体系） |
| 魂灯蛊 | 39 | 39 | 真蛊名（武家宗祠体系） |
| 摄魂蛊 | 2 | 2 | 真蛊名（羊枯的魂道仙蛊） |
| 落魄蛊 | 1 | 1 | **不是蛊名**——语境是「落魄蛊仙」（落魄+蛊仙相邻） |
| 落魄谷 | — | — | **地名**，炼魂首选地 |
| 魄蛊 | 6 | 5 | **不是独立蛊名**——全在「气魄蛊/体魄蛊/云魄蛊…」内部 |
| 阴蛊 | 14 | 14 | **不是独立蛊名**——是「阴阳转身蛊」的阴/阳两半 |
| 灵蛊 | 2 | 2 | **不是独立蛊名**——来自「阵灵蛊」被切开 |
| 魂蛊 | 80 | 78 | **存疑**——多数在「神魂蛊/龙魂蛊…」内部，疑为泛称 |
| 灯蛊 | 40 | 0 | 派生名——真名是 `魂灯蛊`，方向疑为从真名剥字 |
| 魅蛊 | 26 | 0 | 裸数全是长名片段 |
| 挡尸蛊 / 撞魂 / 兽魂蛊 | 0 | 0 | 原文查无 |
| 僵尸蛊 / 尸蛊 | 8 / 32 | — | 待 Q4 判断是否对应「挡尸蛊」 |
| 炼魂 | 25 | — | 待 Q6 |
| **魂道蛊整体** | — | — | 40 只中仅 **4 只**可在原文站住（摄魂蛊/净魂仙蛊/命牌蛊/魂灯蛊） |

## GIT（执行前必读）

工作树已有**未提交改动**，均不属于本任务，禁止触碰：

```
 M AGENTS.md / PROJECT_MAP.md / ai-system/PRD.md / docs/debt.md
 M game/export_presets.cfg
 M game/scripts/domain/loot_resolver.gd
 M game/tests/unit/test_battle_save_load_semantics.gd
 M game/tests/unit/test_export_presets_exclude_filter.gd
 M lore/wiki/**                                  (wiki 蒸馏在途)
?? ai-system/**  (未跟踪的协作体系文件)
?? game/wenzhen-web-lab/                          (untracked 原型)
?? game/world-model/reports/numeric-status-audit.md        (L2 产出)
?? game/world-model/reports/difficulty-axis-probe.md       (L2 派单产出)
?? game/world-model/reports/soul-system-audit.md           (L2 派单产出)
?? game/world-model/tools/probe_difficulty_axes.py         (L2 派单产出)
?? game/world-model/rulings/RUL-2026-09-19-004.json        (L0 裁定)
?? game/world-model/rulings/RUL-2026-09-19-005.json        (L0 裁定)
```

执行前跑 `git status --porcelain` 自查；发现本任务写入路径与上述冲突则停止上报。

## Execution rules

- Worker class: `normal`。
- 纯只读检索；只新增 2 个文件。
- 不 commit / 不 push / 不 merge / 不 stash / 不 reset。
- 结束时按 `ai-system/WORKER_HANDOFF_TEMPLATE.md` 输出 Caveman Review Packet。

## 建议的检索脚手架（可自行改进）

```bash
PYTHONIOENCODING=utf-8 "C:/Users/90877/.workbuddy/binaries/python/versions/3.13.12/python.exe" - <<'PY'
import re
txt = open('蛊真人-clean.txt', encoding='utf-8', errors='replace').read()
for term in ['魂魄底蕴', '凝魂', '炼魂']:
    ms = list(re.finditer(re.escape(term), txt))
    print(f'=== {term}: {len(ms)} ===')
    for m in ms[:5]:
        ln = txt.count('\n', 0, m.start()) + 1          # 行号
        seg = txt[max(0, m.start()-60):m.start()+60].replace('\n', '⏎')
        print(f'  L{ln}: ...{seg}...')
PY
```

（行号定位已核实可用：原文共 437,060 行 / 8,587,697 字符，换行充分，
`txt.count('\n', 0, m.start()) + 1` 即可得到稳定行号。报告顶部请注明所用定位方式。）
