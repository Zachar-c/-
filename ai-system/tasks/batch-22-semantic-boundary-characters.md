# Batch 22：Semantic Boundary Normalization（第二组人物页）

## 目标

对剩余四个人物页做第二组语义清账：

- 红莲魔尊
- 元莲仙尊
- 白凝冰
- 黑楼兰

继续执行已验证的判断规则：

- 有逐段 source 原文或已核验 canon-index，且陈述范围不超过证据：原著明确内容。
- 只有 notes/memory 支撑：资料整理。
- 跨事实归纳、人物弧光、价值判断：分析与解读。
- 证据不足、冲突或轮次未确认：待核对。
- 阶段索引、身份与关系、关键关系、关系网络只做导航，不是新事实层级。

目标是搬层级、降低确定性，不改故事，不补知识。

## 允许修改的文件（仅限以下五个）

- lore/wiki/characters/red-lotus.md
- lore/wiki/characters/yuan-lian-xian-zun.md
- lore/wiki/characters/bai-ning-bing.md
- lore/wiki/characters/he-lou-lan.md
- lore/wiki/log.md

禁止修改其他文件；禁止新增人物页、来源文件、索引系统、脚本、数据库或游戏代码。

## 先决条件

1. 先读 AGENTS.md → PROJECT_MAP.md → lore/wiki/README.md → lore/wiki/AGENTS.md，再读 ai-system/WORKER_PROTOCOL.md 与 ai-system/WORKER_HANDOFF_TEMPLATE.md。
2. Batch 21 已提交为 c08cba5 docs(wiki): close character navigation boundaries。
3. 修改前执行 git status --porcelain，保护所有其他项目改动，不回滚、不格式化、不覆盖。
4. 先逐页检查现有区块和锚点，再决定每条的去向；不要机械整段搬家。

## 页面级重点

### red-lotus.md

- 检查 阶段索引、原著明确内容、关键关系、关系网络。
- 阶段索引中的 notes/memory-only 摘要必须改成导航或明确指向资料整理/分析/待核对。
- 原著明确内容中只有 notes/memory 的条目移入资料整理，保留原文、锚点、轮次和限制语。
- 已明确为分析的核心定义不要改成事实。

### yuan-lian-xian-zun.md

- 原著明确内容当前主要使用 notes 锚点，逐条判断并按证据层级处理。
- 身份与关系、关键关系等顶部摘要若包含事实性断言，改为导航指针或明确标注分析/待核对。
- 不要把坚持仙蛊、逆流河、天元宝皇莲、豆神宫等关系扩写成未经核验的因果链。

### bai-ning-bing.md

- 原著明确内容的三条均需检查是否只有整理资料支撑。
- 只有 notes/memory 的内容移到资料整理；人物弧光归纳留在分析与解读；不补十绝体或身份变化细节。

### he-lou-lan.md

- 原著明确内容的三条均需检查证据层级。
- 没有逐段原文或 canon-index 就降为资料整理。
- 保留现有分析和待核对内容，不扩展北原、黑家或十绝体设定。

## 核心边界

1. 不新增第五种或第六种正文层级。
2. 不为了让原著明确内容不为空而补原文事实。
3. 不创建永久 UUID、段落 ID 或新的索引系统。
4. 不改 frontmatter，除非发现现有来源字段本身失效；若失效，停止并报告。
5. 不改其他人物页，即使发现跨页指针可以优化，也只在日志记录。
6. 资料整理统一使用现有降级说明，保留 notes/memory 锚点、轮次和限制语。
7. 需要改导航时，优先使用“相关导航入口”“见本页《资料整理》/《分析与解读》/《待核对》”等现有模式，不使用“辅助事实”等新分类。
8. 更新 lore/wiki/log.md，逐页记录保留、降级、导航改写、未解决缺口和未触碰范围。

## 验收

从仓库根目录运行：

- pwsh -NoProfile -File lore/wiki/tools/check.ps1
- git diff --check
- git status --short -- lore/wiki

预期保持：

- check1 30/30
- check2 86/104，18 条已知 local-only WARN，0 FAIL
- check3 24/24
- check4 378/378
- check5 41 个 Markdown 文件
- check6 30/30
- check7 30/30

不要提交或推送。提交由协调方在评审通过后执行。

## 交付

严格按 ai-system/WORKER_HANDOFF_TEMPLATE.md 输出完整 Review Handoff。

最终状态只能为 READY_FOR_REVIEW 或 BLOCKED。

