# 问真·《蛊真人》LLM Wiki

这是《蛊真人》蒸馏的第一版知识层：让 AI 在创作过程中优先获得稳定、结构化的世界知识，并在需要时回查原文。

目标是压缩 AI 理解原文的上下文成本：平时优先读 Wiki，遇到缺口、冲突或高风险细节再回查原文；Wiki 的价值是减少 AI 重读原文，加速《问真》的剧情、系统、美术和关卡生产，不为知识治理本身增加规则。

## 使用方式

1. 先读 [`index.md`](index.md)。
2. 按分类索引进入人物、蛊虫、事件、世界规则或主题页。
3. 页面没有回答问题时，用 `rg` 回查现有原文和读书笔记。
4. 确认后的结论写回对应 Wiki 页面，并保留章节或行号来源。

原文来源状态与 EPUB 迁移验收材料见 [`source/README.md`](source/README.md)。现以 `source/蛊真人-epub-canon.txt` 为正文真源；旧 E-ID 和行号保留作历史回查。全量 E-ID 定位及未决状态见 `lore/wiki/source/eid-migration-decisions.tsv`，运行时使用的子集见 `lore/runtime/evidence-locators.json`；旧裸行号可查 `lore/wiki/source/old-line-to-epub-map.tsv`。当前接入状态、待 L1 裁决的口径项（迁移窗口放宽、pack 状态行白名单、正文站点残留）与产物同步缺陷见 [`2026-09-30-epub-canon-l1-review-pack.md`](2026-09-30-epub-canon-l1-review-pack.md)。

```powershell
rg -n "关键词" "source\蛊真人-epub-canon.txt"
rg -n "关键词" "game\分支：六卷精编版\读书笔记"
```

## 来源优先级

1. `source/蛊真人-epub-canon.txt`
2. `source/《人祖传》.txt`
3. `game/docs/lore/canon-index.md`
4. 现有读书笔记和记忆库
5. 游戏设计、重写方案和分析文字

Wiki 页面中的“原著明确内容”必须能回到前四类来源；游戏改编和重写决定不得伪装成原著事实。

## v1 不做什么

- 不复制整部原文到新目录。
- 不新增 SQLite、向量数据库、知识图谱、任务队列或自研 RAG。
- 不修改游戏运行时代码和现有 `lore_engine`。
- 不在内容尚未稳定前接入 Quartz；展示层以后再加。

“暂时没有整理”不等于“原著不存在”。不确定的内容写入“待核对”，不要凭印象补全。
