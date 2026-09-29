# 原始资料入口

这里不复制整部小说，只记录蒸馏时应回查的现有资料。

## 主要原文

- 仓库根 `蛊真人-clean.txt`：当前 Canonical Novel Source；runtime manifest 绑定其 SHA-256。`source/蛊真人-clean.txt` 是同一旧源的 LF 副本，行号相同但文件哈希不同。
- `source/蛊真人-epub-canon.txt`：用户批准入库的 EPUB 派生候选源；尚未完成 E-ID 迁移与 runtime/Web/Game 回归，因此目前不是唯一 Canonical Novel Source。
- `source/《人祖传》.txt`：世界内典籍，GB18030 编码。

## EPUB 迁移验证产物

- [EPUB Canonical 迁移报告](../2026-09-28-epub-canon-migration-report.md)：原始 v2 记录；2026-09-29 verifier 复核补记见报告末尾，原“基本安全”结论已被新证据取代。
- [L1 迁移交接记录](../2026-09-29-epub-canon-l1-handoff.md)：候选计划及当前执行状态。
- `epub-canonical-build-manifest.json`：EPUB、派生文本、提取器、规范化和重建规模指纹。
- `chapter-paragraph-index.tsv`：每章每段的稳定地址与段落 SHA-256。
- `eid-migration-decisions.tsv`：当前 Live E-ID 的迁移决策、旧地址、候选地址及回滚字段；人工批准状态由审核人填写并经 verifier 保留。
- `migration-page-coverage.tsv`：runtime 80 个实体页、最近新增 40 页及其他活动 Wiki 页的逐页覆盖状态。
- verifier：[`tools/verify_epub_migration.py`](../tools/verify_epub_migration.py)；需 Python 3.12、beautifulsoup4 4.15.0，并传入原 EPUB 路径。

## 现有整理资料

- `game/docs/lore/canon-index.md`：已登记的原著事实与原文行号。
- `game/分支：六卷精编版/记忆库/05-设定集-核心锚点.md`：核心设定锚点。
- `game/分支：六卷精编版/记忆库/04-人祖传-隐喻索引.md`：三十八节隐喻索引。
- `lore/research/分支：六卷精编版/记忆库/02-人物弧光.md`：人物整理资料，属于二手整理。
- `lore/research/分支：六卷精编版/记忆库/06-角色台账.md`：角色行为约束，属于创作辅助资料。
- [`chapter-index.md`](chapter-index.md)：读书笔记区间索引。
- [`section-index.md`](section-index.md)：原文卷节标记索引（生成物，`tools/build_section_index.py` 重建；行号↔节题对照，含重复与编号异常登记）。

## 回查原则

先查 Wiki，再用 `rg` 查原文；Wiki 与原文冲突时，以原文为准，并在页面“待核对”区块记录冲突。
