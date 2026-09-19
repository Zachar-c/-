# Batch 21：Semantic Boundary Normalization（人物页导航闭环）

## 目标

在已完成 Batch 20 的三个样板人物页上，完成“阶段索引 / 关键关系”的语义闭环。

本批只解决一个问题：导航结构应当指向知识，但不能把尚未逐段核验的 notes/memory 摘要伪装成事实结论。

不要扩展到其他人物页，不要新增正文层级。

## 允许修改的文件（仅限以下四个）

- lore/wiki/characters/fang-yuan.md
- lore/wiki/characters/star-constellation.md
- lore/wiki/characters/dragon-duke.md
- lore/wiki/log.md

禁止修改其他文件；禁止新增页面、来源文件、索引系统、脚本、数据库或游戏代码。

## 先决条件

1. 先读 AGENTS.md → PROJECT_MAP.md → lore/wiki/README.md → lore/wiki/AGENTS.md，再读 ai-system/WORKER_PROTOCOL.md 与 ai-system/WORKER_HANDOFF_TEMPLATE.md。
2. Batch 20 已提交为 4debe29 docs(wiki): normalize character evidence layers。
3. 修改前执行 git status --porcelain，保护所有其他项目改动，不回滚、不格式化、不覆盖。
4. 只处理这三个人物页，不复制未验证的方法到其他页面。

## 核心规则

1. 不新增第五种或第六种正文知识层级。现有四层保持不变：
   - 原著明确内容
   - 资料整理
   - 分析与解读
   - 待核对
2. 阶段索引、关键关系、关系网络是导航结构，不是新的事实层级。
3. 逐条检查三页中这些导航/摘要区块：
   - 如果只是链接或章节名，可以保留。
   - 如果包含 notes/memory 支撑但未逐段原文核验的事实性断言，优先改成简短导航语句，指向对应的 资料整理、分析与解读 或 待核对 区块。
   - 如果是跨事实归纳或价值判断，明确指向 分析与解读，不要保留成无来源事实。
   - 如果存在证据不足、轮次未确认或冲突，指向 待核对。
4. 不机械地删除全部导航内容，不把人物页变成只有链接的空壳；保留对新人有用的入口和章节名称。
5. 不补写人物经历、原文事实、章节号、source 行号或 canon-index ID。除非已有页面中的锚点已经明确且只是做最小指针调整，否则不要新增证据。
6. 不改 Batch 20 已完成的 资料整理 条目内容、锚点、Run 1 / Run 2 标记。
7. 只在必要时修改正文内指针；如果没有明确误导，不要重写。
8. 更新 lore/wiki/log.md，记录：
   - 每页哪些导航句保留；
   - 哪些摘要被改成导航指针或明确标为分析/待核对；
   - 哪些内容刻意未动；
   - 未解决的语义缺口。
9. 运行检查，不提交、不推送。提交由协调方在评审通过后执行。

## 重点审查方向

- 方源：阶段索引中的前世、重生初期、青茅山、南疆外出摘要；关系网络中是否混入因果结论。
- 星宿：阶段索引和关键关系中关于合道、天庭、宿命蛊、星宿意志的句子。
- 龙公：阶段索引和关键关系中关于洪亭师徒、龙人、宿命大战和秩序立场的句子。
- 不要把“导航层”写成新的“辅助事实”分类。

## 验收命令

从仓库根目录运行：

- pwsh -NoProfile -File lore/wiki/tools/check.ps1
- git diff --check
- git status --short -- lore/wiki

必须逐项记录结果。预期仍为 check2 的 18 条已知 local-only WARN、0 FAIL。

## 交付

严格按 ai-system/WORKER_HANDOFF_TEMPLATE.md 输出完整 Review Handoff。

最终状态只能为 READY_FOR_REVIEW 或 BLOCKED。

