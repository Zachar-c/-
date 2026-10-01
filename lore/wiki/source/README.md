# 原始资料入口

这里不复制整部小说，只记录蒸馏时应回查的现有资料。

## 主要原文

- 仓库根 `蛊真人-clean.txt`：**legacy evidence recovery source**（旧版 TXT），只用于旧 E-ID、行号回查与版本差异对照。`source/蛊真人-clean.txt` 是同一旧源的 LF 副本，行号相同但文件哈希不同。
- `source/蛊真人-epub-canon.txt`：EPUB 派生 **Canonical Source**。2026-09-30 按用户要求接入 Wiki runtime；旧 E-ID 不改号，已核验定位接入生成的 `lore/runtime/evidence-locators.json`，未决定位保持空值，不伪称对应新段落。全量待审项仍由 #13 跟踪。
- `source/蛊真人 -- 蛊真人 -- ( WeLib.org ).epub`：**Canon 源原件**（WeLib 版，12,504,156 字节，SHA-256 `be1c357f7f0131adb2d14be76130614c919cf8eb3364aa673cbf49513160d972`），与 `epub-canonical-build-manifest.json` 的 `epub_sha256` 一致；本地留存、不入库（`source/` 整目录被 `.gitignore` 排除，仅派生 canon 例外）。2026-09-30 已对原件直接确认：一段·第七十七节「阴差阳错」在 spine 与 `toc.ncx` 中均不存在（第七十六节 → 第七十八节），「幽影虫」全书 0 次——属**源侧已知缺节**，非提取失败。
- `source/《人祖传》.txt`：世界内典籍，GB18030 编码。

## EPUB 迁移验证产物

- [EPUB Canonical 迁移报告](../2026-09-28-epub-canon-migration-report.md)：原始 v2 记录；2026-09-29 verifier 复核见 §9，判定口径 **v3（C2 消歧）** 见 §10——§10 取代 §9 的「801 = 真正 blocker」拆分，并给出 801/802 的差异原因。
- [L1 迁移交接记录](../2026-09-29-epub-canon-l1-handoff.md)：候选计划及当前执行状态。
- `epub-canonical-build-manifest.json`：EPUB、派生文本、提取器、规范化和重建规模指纹；含口径 v3 的 `decision_policy`、`baseline_blocker_partition`、`migration_basis_counts`、`blocked_by_withheld_reason`、`legacy_variance_by_kind`、`secondary_reason_counts`、`context_alignment`。
- `chapter-paragraph-index.tsv`：每章每段的稳定地址与段落 SHA-256（纯段落，未改动）。章标题定位符 `EPUB:chapter_N:heading` 只记在 decisions 里，不塞进段落索引。
- `eid-migration-decisions.tsv`：当前 Live E-ID 的迁移决策、旧地址、规范定位符及回滚字段（37 列）；`decision` 取值 `auto_verified`（定位符被唯一确定且顺序一致）/ `blocked`（无法钉住位置或落点进入重复/异版章，附 `primary_blocker_class`、`withheld_reason`）/ `out_of_scope`（非 live）。`migration_basis` 记录解析依据（`exact_full_paragraph` / `positional_alignment` / `heading_locator` / `human_approved`）；`legacy_variance` 记录与旧源的差异（**差异本身不再阻断**）；`secondary_reason_json` 记录附加原因（`legacy_typo` / `legacy_redaction` / `paragraph_segmentation_difference` / `legacy_content_missing` / `true_ambiguity` / `punctuation_variant` / `content_divergence`）；人工批准状态由审核人填写并经 verifier 保留。
- `migration-page-coverage.tsv`：runtime 80 个实体页、最近新增 40 页及其他活动 Wiki 页的逐页覆盖状态（按口径 v3 汇总）。
- `unreferenced-chapters.tsv`：2,365 章中**未被任何 Live E-ID 引用的 699 章**登记（`chapter_id` / 标题 / `EPUB:chapter_N` 地址 / `has_eid` / `wiki_referenced`，当前全为 `false`）。只是章节登记，不新建 Wiki 页面；内容由 `chapter-paragraph-index.tsv` 与 `eid-migration-decisions.tsv` 投影得到，不新增事实来源。
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

## 知识缺口调查

[知识完整性调查](completeness-audit.md)记录缺实体、缺条件、检索困难、规则漂移与证据边界；[实体落点候选清单](entity-coverage-inventory.tsv)用于排查既有名录漏项，不是全书实体全集或事实验收证明。
