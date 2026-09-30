# 查设定/证据

> 给研究者：从规则索引到 canon 命题，再到原文锚点，三步拿到可追溯的设定依据。

## 给谁

需要核实「这条设定有没有原文依据」的人——考据、争议裁决、写引用、出研究请求。

## 你会得到什么

- 成文规则簇的索引入口
- canon 命题（CAN-*）的登记表
- 原文回查的路径与定位工具
- 「已核 / 推断 / 未决」的判读规则

读完后你能沿 Wiki → Claim → Evidence → Raw 一路追溯，并分清哪些结论可以直接引用。

## 怎么用本页

默认顺序：**规则索引 → canon → 证据回查**。Wiki 是压缩层，不是证据终点；凡是要写进正式材料的断言，最终都要回到原文锚点。

## 逐步阅读清单

### 一、规则索引

1. [规则页索引](../rules/index.md) —— 成文规则簇的总目录；每条 claim 带证据列与禁止误读，是查机制的第一站。
2. [世界规则索引](../world/index.md) —— 体系、流派、地域、组织的入口；跨人物复用的设定优先看这里。
3. [蛊虫、蛊方、炼蛊与杀招](../world/gu-refine-killer-chain.md) —— 关系链总纲；查「X 和 Y 什么关系」的高频答案。

### 二、canon 命题

4. [canon-index](../../../game/docs/lore/canon-index.md) —— CAN-* 命题登记表；引用已固化结论前先查状态与证据列。
5. [Wiki 编辑约定](../AGENTS.md) 一等公民 ID 节 —— E-ID / ST-ID / EVT-ID / CAN-* 的链路约定；看懂 ID 才能沿链追溯。

### 三、证据回查

6. [原始资料入口](../source/README.md) —— 原文、笔记、记忆库的位置与来源优先级；回查从这里开始。
7. [原文卷节标记索引](../source/section-index.md) —— 行号→节题对照；人文定位用节#N 辅助。
8. `lore/wiki/source/eid-migration-decisions.tsv`、`lore/runtime/evidence-locators.json` —— E-ID 迁移决策与运行时定位子集；`blocked` 项不得当作已映射。
9. [chapter-index](../source/chapter-index.md)、`old-line-to-epub-map.tsv` —— 读书笔记区间与旧裸行号映射；处理历史锚时用。

（争议与冲突）页面「待核对」区块 + `docs/debt.md` —— 已登记的缺口、冲突与待裁定项；别把它们当已解决。

## 常见坑

- **把 Wiki 当证据终点**：Wiki 是综合层（L5）；精确原话、争议裁决必须回 L0/L1。
- **新旧源混用**：正文真源是 `source/蛊真人-epub-canon.txt`；旧 `E:V…` 与 `蛊真人-clean.txt:行号` 是历史锚，不代表当前正文位置。
- **把 `blocked` 定位当已映射**：evidence-locators 里 `blocked` 项未钉住，不得引用为精确出处。
- **把笔记/研究资料当原著事实**：`notes:`、`memory:`、`lore/research/` 都不是原文；来源命名空间见 [Wiki 编辑约定](../AGENTS.md)。
- **把角色观点当世界规则**：`[对话]`/`[信念]`/`[传闻]` 不能升格；判读规则在 AGENTS.md 认知标记节。

## 相关阅读路径

- [五分钟看懂世界](five-minute-world.md) —— 先建骨架再考据。
- [同人写作](fanfic-writer.md) —— 研究要落到创作。
- [做《问真》](wenzhen-dev.md) —— 设定要落到游戏数据分界。
