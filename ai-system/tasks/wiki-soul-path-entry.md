# Wiki 蒸馏批次：魂道（世界规则页）

```text
WORKFLOW ROLE
L3 Worker

UPSTREAM
L2 Orchestrator

DOWNSTREAM
L2 Review → L0（魂道内容取舍）

PROJECT GOAL
把「魂」从一个固定 1–4 的风险条，重新建立成**可成长的 Build Axis（魂道玩法）**。
要重建魂道，先要有可信的魂道原著口径——这正是本批次要补的缺口。

CURRENT PHASE
已生效裁定（`game/world-model/rulings/`）：
- `RUL-2026-09-19-004`：魂 = 可成长 Build Axis，对应魂道玩法
- `RUL-2026-09-19-005`：AP 档位参照原文 百人魂/千人魂/万人魂；魂与肉身/真元抢同一份资源
- `RUL-2026-09-19-006`：**魂魄底蕴 = 魂道的修为**；魂道最高造诣 = 幽魂的「三个头颅、千臂千手」

TASK PURPOSE
`lore/wiki/` 现有 44 个页面里，「魂道」**0 命中**，「魂魄」仅 3 次顺带提及——
**魂道在 Wiki 里是空白**。这导致 AI（含 L2）此前只能从 `game/data/` 的占位内容
去理解魂道，方向整体是错的（实测：游戏里 40 只魂道蛊有 36 只在原文无着落）。
本批次就是把这个空白补上，让 Wiki 成为魂道的可信入口。

TASK
按 `lore/wiki/AGENTS.md` 的编辑约定，完成**一个可聚焦批次**：
新建「魂道」世界规则页，并同步索引、互链、来源边界与日志。

**A. 新建 `lore/wiki/world/soul-path.md`**

- frontmatter 只用四个字段：
  ```yaml
  ---
  type: world
  name: 魂道
  aliases: []
  sources: ["source:source/蛊真人-clean.txt"]
  ---
  ```
  （`aliases` 按实际情况填；若本批只用到原文，sources 只列原文；
  不要引用 `game/world-model/reports/` 下的报告——Wiki 的来源命名空间只有
  `source:` / `notes:` / `memory:` / `canon-index:` 四类。）
- 正文区块用约定四段：`## 原著明确内容` / `## 资料整理` / `## 分析与解读` / `## 待核对`
- **`## 原著明确内容` 只放你亲自回读原文窗口、确认过的逐段事实**，
  每条写清「行号范围 + 章节名（原文有的话）+ ≤60 字短引或转述」。
  格式对齐现有页面（例：`（149584–149598 行，第一百七十二节《福地攻伐浅论道》）`）。
- **禁止写入游戏数值、卡牌效果、《问真》改编内容**（`lore/wiki/AGENTS.md` 明令）。
- **禁止复制大段原文**；短引单条 ≤60 字，全页引用合计 ≤1500 字。

**必须覆盖的原文要点**（下列行号已由 L2 复算，但**你仍须回读确认**，
行号不符或有出入以你回读结果为准，并在包内说明）：

| 要点 | 行号（待你确认） |
|---|---|
| 幽魂魔尊 = 魂道的开辟者，九转巅峰 | 78246 / 110686 |
| 二圣地与「魂道大成」：壮魂首选荡魂山，炼魂首选落魄谷 | 78254 / 93476 |
| 魂魄底蕴 = 可增长存量，单位「人魂」，阶梯 百→千→万（后有更高档） | 78254 / 78238 |
| 凝魂名录（神魂蛊、龙魂蛊、冰魂蛊等一族均可凝练魂魄） | 78254 |
| 壮魂：胆识蛊「直接增长底蕴，没有任何副作用，效率极高」；凡人到千人级约需二十年 | 93484 |
| 炼魂：落魄谷的雾 + 落魄风 | 78238 |
| 安魂：安魂汤 / 迷魂湖 | 332474 / 369026 |
| 狼魂蛊 → 狼人魂（人魂改兽魂）：三转市价七千七百枚元石；效用可叠加；需 9 只三转 | 81838 / 81920 / 81950 |
| 魂道最高造诣：幽魂魔尊「千臂千手，三个头颅」，魂魄「绝对超越了亿人魂」 | 81948 |
| 魂道极致：魂魄由虚返实，干涉物质，凝如肉身 | 185618 |
| 跨流派价值：奴道、炼道也需要魂魄底蕴；与升仙相关 | 130436 |
| 真实魂道蛊：净魂仙蛊（杀招「万我」核心蛊）、命牌蛊 / 魂灯蛊（武家宗祠）、摄魂蛊 | 123194 / 227566 / 250478 |
| 另有「梦境可直接提升底蕴」 | 153798 |
| 方源借助手段可达百万人魂级 | 182808 / 273656 |

**B. 同步 `lore/wiki/world/index.md`**
- 在「## 修炼」之后新增一节 `## 流派`，把 `[魂道](soul-path.md)` 作为首条。
  （理由：流派会有后继条目——血道、力道、气道等——单独成节比塞进「修炼」更稳。
  若你回读后认为 `## 修炼` 更合适，可自行决定，但须在交付包里说明理由。）
- 不要改动本页其他既有内容。

**C. 互链与反向链接**
- 只在**目标文件确实存在**时加链接（`lore/wiki/AGENTS.md` 明令）。
- 判断是否需要从 `world/cultivation-system.md`（道痕与流派那几行）或
  `events/story-arc-overview.md` 指向本页；需要就加一行，不需要就不加，并在包内说明。
- `lore/wiki/index.md` 的「当前阅读顺序」**不动**（本批不改阅读顺序）。

**D. `lore/wiki/log.md` 追加一条本批记录**
- 对齐既有条目的写法：本批范围、新增/修改文件、原文窗口清单、已知边界、
  验收结果（含 `source:` 路径检查的既有 FAIL 说明）。

SCOPE
只读：`lore/wiki/**`、`蛊真人-clean.txt`（**仓库根目录**，23,609,617 字节 / 8,587,697 字符 /
      437,060 行，md5 `8fc65b410a47ef34d99deafbaeac33d6`）、
      `game/world-model/reports/soul-canon-verification.md`、`game/world-model/reports/soul-system-audit.md`、
      `game/world-model/rulings/RUL-2026-09-19-00{4,5,6}.json`
只写（仅此四处，均在 `lore/wiki/` 内）：
- `lore/wiki/world/soul-path.md`（新建）
- `lore/wiki/world/index.md`（加索引）
- `lore/wiki/log.md`（加日志）
- 至多一个既有页面的互链行（见 C）

DO NOT
- 禁止修改 `lore/wiki/` 以外的任何文件。特别禁止：`game/**`、`ai-system/**`、`docs/**`、
  `lore/research/**`、`lore/wiki/AGENTS.md`、`lore/wiki/index.md`、`lore/wiki/README.md`
- **禁止把游戏内容写进 Wiki**：40 只魂道蛊、AP 档位、`soul`/`soul_max`、RUL 裁定编号
  都不属于 Wiki 的原著事实区
- **禁止把 L2/L3 的判断写成原著事实**：核验报告是检索辅助，不是来源；
  每条事实都必须来自你亲自回读的原文窗口
- **禁止大段抄录原文**（单条短引 ≤60 字，全页 ≤1500 字）
- **禁止为凑内容做联想**：原文查无的（如「挡尸蛊」「撞魂」）一律进 `## 待核对`，
  不得写成事实，也不得强行对应到别的概念
- **禁止新建幽魂魔尊人物页**：他的传记属 `characters/` 分类的另一批次，本批不建，
  也**不得留下指向不存在页面的断链**（正文中可正常提及，只是不加链接）
- 禁止 commit / push / merge / stash / reset
- 禁止新增依赖（仅标准库 / `rg` / 现有工具）
- 禁止把 `蛊真人-clean.txt` 复制、移动、改名或提交（`.gitignore:13` 已忽略，须保持未被追踪）

DECISION AUTHORITY
可自行决定：页面内部的条目组织与取舍、哪些要点合并成一条、`## 流派` 节放哪里（须说明理由）、
是否加互链、引用哪些原文窗口。
不可自行决定：魂道的事实边界（拿不准就进 `## 待核对`）、是否新建其他页面、是否改索引结构。

ESCALATE WHEN
- 回读发现 L2 给的行号与原文内容对不上（超过 2 处）
- 回读发现原文存在与 `RUL-2026-09-19-006`（魂魄底蕴 = 魂道修为）相冲突的表述
- 发现魂道在原文中有远多于预期且自相矛盾的体系（例：多个互斥的成长路径）
- 需要改 `lore/wiki/AGENTS.md` 才能完成本批

DELIVERABLE
1. `lore/wiki/world/soul-path.md`
2. `lore/wiki/world/index.md`（加 `## 流派` 节）
3. `lore/wiki/log.md`（追加本批记录）
4. Caveman Review Packet（`ai-system/WORKER_HANDOFF_TEMPLATE.md`）

ACCEPTANCE
- 页面通过 `lore/wiki/AGENTS.md` 的格式检查：四字段 frontmatter（`type` = `world`）、
  四段正文区块、ASCII slug 文件名、相对链接且目标存在
- `## 原著明确内容` 每一条都有行号范围，且**逐条经你回读确认**
- 全页无游戏数值、无裁定编号、无 L2/L3 判断混入事实区
- 短引预算达标（单条 ≤60 字，合计 ≤1500 字）
- `git status --short -- lore/wiki` 只显示本批允许的文件
- `git diff --check` 无新增空白错误
- 断链检查通过（新增链接的目标文件均存在）
- `source:` 路径检查的既有 FAIL（`source/` 目录本地缺失）**如实记录为既有债务**，
  不得声称全量验收通过
- `git status --porcelain` 中**不出现 `蛊真人-clean.txt`**

STATUS TARGET
READY_FOR_WIKI_REVIEW
```

## 追加补丁（L2 于本批执行期间追加 · `RUL-2026-09-19-007`）

**若你尚未写完 `## 待核对`，请按本节处理；若已写完，请在交付前回头改这一处。**

L0 已校正一条原话：**「挡尸蛊」实为「胆识蛊」，「撞魂」实为「壮魂」**（同音误记）。
因此：

- **不要把「挡尸蛊」「撞魂」记为「原文查无」**——那是校正前的误记形式。
- 正确写法（在 `## 待核对` 或 `## 原著明确内容`，视你取证结果定）：
  L0 原话系同音误记，校正后为「胆识蛊可以壮魂」，原文予以证实。
- **胆识蛊与壮魂本就是本批必收要点**（见上文表格），补上这两条即可：
  - 原文原句：「而一些胆石中，藏有胆识蛊，**可以壮人魂魄**」（L76064）；
    胆识蛊产自荡魂山的胆石，命中 **514** 次；壮魂 **42** 次、荡魂山 **709** 次。
  - **一条此前审计未记录的限制机制**，请务必回读确认后收入：
    「魂魄也不可能一味地得到胆识蛊的增强。一旦魂魄不够凝练，使用大量胆识蛊导致过度的膨胀，
    必是一场万劫不复的灾难。」（L76090）
    → 即「凝练」（凝魂）是「壮魂」的安全前提。这为魂道内部提供了一条风险与平衡关系。
  - 另有胆识蛊 → 魂魄底蕴的直接增长链（L76078），可与「底蕴可增长」互证。
  - 狼人魂术语再次确认（L81944：「成半人半狼的形态，俗称狼人魂」），
    且原文明确「万人魂也绝不是终点，上面还有亿人魂等等」。

另外一处相关校正（供你写 `## 待核对` 时参考）：
「落魄蛊」与地名「落魄谷」是同一处同音误记（谷/蛊 同音），L0 的机制主张
（落魄谷可炼魂）与原文一致——被证伪的只是「落魄蛊是一个蛊名」这一层。

## 技术事实（已由 L2 核实，Worker 不必重新考古）

| 事实 | 证据 |
|---|---|
| Wiki 编辑约定 | `lore/wiki/AGENTS.md`（frontmatter 四字段、四段区块、来源命名空间、批次与评审、更新方式） |
| 现有世界规则页 | `world/cultivation-system.md`（53 行）、`world/primeval-essence.md`（36 行）、`world/aptitude-and-aperture.md`、`world/gu-care-and-refinement.md`、`world/south-jiang.md`、`world/heavenly-court.md`、`world/world-operating-system.md` |
| 引用格式范例 | `world/cultivation-system.md:27`「（138684–138712 行，北原拍卖会第一百零九节《吃力》）」 |
| `source:` 命名空间现状 | `lore/wiki/source/README.md:7` 声明主原文为 `source/蛊真人-clean.txt`；**该目录本地不存在**，属既有 local-only 债务（历史批次 check 一直记为已知 FAIL） |
| 实际可读原文 | 仓库根目录 `蛊真人-clean.txt`，md5 `8fc65b410a47ef34d99deafbaeac33d6`，437,060 行 |
| 行号口径 | 与 Wiki 现有引用一致（均为该文件的 1 起始行号） |
| `**` 是清洗残留 | 原文中 `**` 为占位符（例：`**魂首选荡魂山胆识蛊`）。上一批 L3 已三处互证解码为「迷惘雾」「迷魂湖」，本批回读时注意勿当原文用字 |
| 魂道在 Wiki 的现状 | `lore/wiki/` 全库：`魂道` 0 命中；`魂魄` 3 命中（`events/story-arc-overview.md:79,104`、`gu/fate-gu.md:46`），均非魂道机制 |
| Python | `C:\Users\90877\.workbuddy\binaries\python\versions\3.13.12\python.exe`；`python` 不在 PATH |
| 终端编码坑 | 控制台是 gb2312，**必须** `PYTHONIOENCODING=utf-8`，否则中文输出乱码 |
| 本仓 `.ps1` 必须纯 ASCII | PS 5.1 对无 BOM 文件按 ANSI 解析，中文注释直接造成语法错误 |

## GIT（执行前必读）

`lore/wiki/` 已有**开工前就存在的未提交改动**（wiki 蒸馏在途），不属于本批，禁止回滚或覆盖：

```
 M lore/wiki/characters/bai-ning-bing.md
 M lore/wiki/characters/fang-yuan.md
 M lore/wiki/events/index.md
 M lore/wiki/events/qing-mao-mountain.md
 M lore/wiki/gu/index.md
 M lore/wiki/gu/moonlight-gu.md
 M lore/wiki/gu/small-light-gu.md
 M lore/wiki/index.md
 M lore/wiki/log.md
 M lore/wiki/world/aptitude-and-aperture.md
 M lore/wiki/world/cultivation-system.md
 M lore/wiki/world/index.md
 M lore/wiki/world/primeval-essence.md
 M lore/wiki/world/south-jiang.md
?? lore/wiki/events/story-arc-overview.md
?? lore/wiki/gu/m0-six-gu.md
?? lore/wiki/world/world-operating-system.md
```

注意：`world/index.md` **在本批允许修改范围内**（加 `## 流派` 节）；
`lore/wiki/index.md` 不在范围内，**不要动**。
执行前跑 `git status --porcelain -- lore/wiki` 自查，与上述不符则停止上报。

## Execution rules

- Worker class: `normal`。
- 只读原文 + 只写 `lore/wiki/` 内的 3 个文件（+ 至多 1 处互链）。
- 不 commit / 不 push / 不 merge / 不 stash / 不 reset。
- 结束时按 `ai-system/WORKER_HANDOFF_TEMPLATE.md` 输出 Caveman Review Packet。

## 建议的检索脚手架（可自行改进）

```bash
PYTHONIOENCODING=utf-8 "C:/Users/90877/.workbuddy/binaries/python/versions/3.13.12/python.exe" - <<'PY'
txt = open('蛊真人-clean.txt', encoding='utf-8', errors='replace').read().split('\n')
def show(a, b):                      # 行号区间（1 起始，含两端）
    for i in range(a-1, min(b, len(txt))):
        print(f'L{i+1}: {txt[i]}')
show(78236, 78258)                   # 幽魂魔尊 + 二圣地 + 凝魂名录
PY
```
