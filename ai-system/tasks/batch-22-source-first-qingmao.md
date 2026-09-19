# Batch 22：Source-first 蒸馏恢复（青茅山早期核心循环）

## 目标

暂停 Semantic Boundary Normalization，恢复 Source-first 蒸馏。

本批的真实目标是：从原文中提炼一个与《问真》未来生产直接相关、但规模可控的连续剧情窗口，让 AI 不必重读这段原文就能理解方源早期状态、资源限制、蛊虫关系和关键选择。

Wiki 是原文蒸馏层和上下文缓存，不是产品本身，也不为了知识治理继续增加规则。

## 原文窗口

主证据只使用根目录本地原文：

- 文件：蛊真人-clean.txt
- 行号：906–3454
- 章节：第 4 节至第 20 节
- 起点：古月方源与开窍大典
- 终点：方源炼化月光蛊、取得学堂首名

选择理由：

这一段是连续且闭合的早期循环，包含：

- 方源重生后的当前身份与处境；
- 开窍、资质、真元海和一转起点；
- 资源不足与修炼速度；
- 月光蛊、酒虫、春秋蝉的实际作用；
- 花酒行者遗藏与早期选择；
- 炼化失败风险、资源消耗和春秋蝉现身；
- 以信息优势、隐藏能力和争取首名为核心的行动逻辑。

不要把整个青茅山卷当成本批范围，不要读取或整理窗口外剧情，除非为了理解窗口内一句话而做最小上下文确认，并在 Handoff 标明。

## 先读规则

先读：

- AGENTS.md
- PROJECT_MAP.md
- lore/wiki/README.md
- lore/wiki/AGENTS.md
- ai-system/WORKER_PROTOCOL.md
- ai-system/WORKER_HANDOFF_TEMPLATE.md

再直接读取蛊真人-clean.txt 的 906–3454 行。notes/memory 只能帮助定位，不能作为本批 Source-first 蒸馏的主证据。

## 允许修改的文件

只允许修改以下文件：

- lore/wiki/AGENTS.md
- lore/wiki/README.md
- lore/wiki/characters/fang-yuan.md
- lore/wiki/events/qing-mao-mountain.md
- lore/wiki/world/aptitude-and-aperture.md
- lore/wiki/world/primeval-essence.md
- lore/wiki/world/gu-care-and-refinement.md
- lore/wiki/gu/moonlight-gu.md
- lore/wiki/gu/small-light-gu.md
- lore/wiki/gu/spring-autumn-cicada.md
- lore/wiki/log.md

禁止修改其他文件；禁止新增页面、数据库、RAG、知识图谱、脚本、检查项、frontmatter 字段或新的 Review/导航协议。

如果现有页面无法承载某个重要事实，先在 Handoff 记录，不要为了覆盖率新增页面。

## 规则文件最小修改

检查现有规则是否已经表达项目目标。

只在必要位置做最小修改，明确：

- Wiki 的目标是压缩 AI 理解原文的上下文成本；
- AI 平时优先读 Wiki，遇到缺口、冲突或高风险细节再回查原文；
- Wiki 的价值是减少 AI 重读原文并加速《问真》的剧情、系统、美术和关卡生产；
- 不为了知识治理本身继续增加规则。

不要新建治理文档，不要扩展 Schema，不要把本批内容写成游戏设计。

## Source-first 蒸馏要求

1. 先读原文，再修改 Wiki。
2. 优先更新已有页面。
3. 对直接由 906–3454 行支持的事实，可以写入 原著明确内容，并附原文行号区间。
4. 对只由 notes/memory 支持、或本批原文没有核验的内容，保持在 资料整理 或 待核对。
5. 不把人物分析、主题归纳、游戏设计写成原著事实。
6. 不复制长段原文，只写精确、短的中文转述和行号。
7. 不为满足区块完整而制造事实。
8. 不改游戏代码、游戏数值或设计文档。
9. 如果使用根目录原文路径，不新增或修改 source namespace；不要移动、复制或提交原文文件。

## 页面重点

### fang-yuan.md

补充本窗口直接支持的早期状态：

- 当前身份、重生后起点和开窍阶段；
- 27 步、丙等、真元海约四成四（仅在原文确实支持时写入事实区）；
- 早期目标和资源限制；
- 花酒遗藏、酒虫、春秋蝉、月光蛊之间的窗口内关系；
- 炼化月光蛊取得首名的事件结果。

不要扩展到窗口外的后期身份、宿命大战或永生。

### qing-mao-mountain.md

补充窗口内直接出现的青茅山三族、山寨、开窍大典和早期资源/社会结构事实。不要扩写狼潮或窗口外事件。

### aptitude-and-aperture.md / primeval-essence.md

用原文窗口核验开窍、资质步数、真元海比例、真元作为修炼资源的表述。区分：

- 步数分级；
- 真元海比例；
- 当前剩余真元；
- 资质与实际战力。

不要制造完整数值表。

### moonlight-gu.md / small-light-gu.md

只补窗口内直接支持的：

- 月光蛊的取得、炼化、印记和月光刃；
- 小光蛊若在窗口内确实出现的作用；
- 食物、真元消耗和协同边界。

精确消耗若原文窗口没有明确，不要补。

### spring-autumn-cicada.md

只补窗口内直接出现的：

- 春秋蝉现身；
- 当前品阶/状态；
- 与方源本命、重生和信息优势的窗口内关系；
- 对空窍或修炼的已明确影响。

不得把窗口外的完整重生机制、红莲关系或后期天意机制写入本批事实区。

### gu-care-and-refinement.md

只补窗口内直接支持的炼化过程、资源消耗、蛊虫意志/反噬和修炼限制。不要把单个案例泛化成所有蛊虫的通用规则。

## Lore 与游戏边界

Lore 中允许记录：

- 事件为什么重要；
- 人物做了什么选择；
- 资源与代价如何限制行动；
- 这些信息体现了什么人物逻辑。

Lore 中禁止记录：

- 技能数值；
- 玩家属性；
- UI；
- 关卡实现；
- 战斗数值；
- 游戏机制方案。

Handoff 必须回答这些知识未来能帮助《问真》AI 设计者理解什么，但不要把答案写入 Lore 正文。

## Wiki-only usability check

完成后，不重新读取本批原文，只使用 Wiki 检查以下问题：

- 此阶段方源是什么状态？
- 他有哪些前世知识，但当前实际拥有什么？
- 当前主要资源限制是什么？
- 有哪些重要人物和关系？
- 当前有哪些关键蛊虫及用途？
- 主要事件为什么发生？
- 哪些选择体现了人物的行动逻辑？
- 这一阶段哪些知识未来可能支撑《问真》生产？

Handoff 必须按以下格式报告：

- 能直接回答：
- 部分可回答：
- 必须回原文：
- 暴露出的知识缺口：

不要创建自动评测系统。

## 更新日志

在 lore/wiki/log.md 追加本批记录，说明：

- 原文窗口和选择理由；
- 直接来自原文的主要蒸馏成果；
- 使用了哪些已有页面；
- 哪些内容仍待回查；
- 没有新增基础设施、Schema 或游戏设计。

## 验收

从仓库根目录运行：

- pwsh -NoProfile -File lore/wiki/tools/check.ps1
- git diff --check
- git status --short -- lore/wiki

如实记录结果。允许保留既有 check2 local-only WARN，但不得新增未知 FAIL。

不要提交或推送。提交由协调方在评审通过后执行。

## 交付

严格按 ai-system/WORKER_HANDOFF_TEMPLATE.md 输出完整 Review Handoff，并额外包含：

- 本批读了什么原文；
- Wiki 实际获得了什么；
- Wiki-only usability check；
- 对《问真》未来 AI 设计的帮助；
- 范围检查；
- 自动检查。

最终 STATUS 必须为 READY_FOR_REVIEW。

