# EPUB Canonical Source 迁移 — L1 交接与审阅请求

> 交接人：MainAgent（EPUB 迁移验证工作线）· 日期：2026-09-29
> 审阅对象：L1 证据层评审 · 目的：请 L1 判断下一步执行计划
> 关联：`lore/wiki/2026-09-28-epub-canon-migration-report.md`（v2 报告）、`lore/wiki/source/eid-migration-map-final.tsv`、`lore/wiki/source/old-line-to-epub-map.tsv`、`source/蛊真人-epub-canon.txt`

---

## 1. 交接背景

用户上传 EPUB《蛊真人》（WeLib 版，12.5MB），要求将 EPUB 迁移为 LLMWiki 新 **Canonical Novel Source**，最终替代现有 `source/蛊真人-clean.txt`。全程原则：不改写正文、不删旧源、不批量改 E-ID、不确定项不强配。

## 2. 已完成工作（验证阶段，全部完成）

| 项 | 结果 |
|---|---|
| EPUB 解析 | spine 2,367 项 = cover+intro+chapter_0~2364；正文章节 **2,365**，正文段落 **215,213**，约 735 万字 |
| 新规范源生成 | `source/蛊真人-epub-canon.txt`（219,942 行），每章 `=== chapter_NNNN｜标题 ===` 标记；一 `<p>`=一段；正文零改写 |
| 新地址方案 | `EPUB:chapter_N:para_M`，随机重建验证 200/200 成功 |
| 全量行号映射 | 旧源 215,231 非空行 → 唯一命中 **195,362（90.8%）**，多处 8,217，未命中 11,652 |
| E-ID 分类（唯一 4,880） | 精确 **4,594（94.1%）** / 模糊 115 / 重复 110 / 差异 20 / 未找到 13 / 行号越界·空行 21 / 引文过短 7；可定位 4,709（96.5%） |
| Golden Pages | 月光蛊 98% · 酒虫 97% · 小光蛊 90% · 春秋蝉 99% · 智慧蛊 96% · gu 41 页 95% |
| 段号↔行号校验 | 30 个 E-ID 段号落在段边界外（登记待核） |

## 3. 提交状态（2026-09-29）

| commit | 内容 | 状态 |
|---|---|---|
| `c841d522` | 报告 v2 + 双映射表入库（3 files, +200,386） | ✅ 已推送 |
| `4a4861b9` | 用户裁决：`.gitignore`/`AGENTS.md` 原则放宽，`source/蛊真人-epub-canon.txt` 入库（219,942 行） | ✅ 已推送 |
| 待安排 | E-ID 页面批量迁移（第一批 4,594 精确项） | ⏸ 未执行，待 L1 计划 |

**原则变更（用户 2026-09-29 裁决）**：`source/蛊真人-epub-canon.txt` 作为 EPUB 派生规范全文，**允许**入库推送（新 Canonical Novel Source 候选）；其余原文底稿（`蛊真人-clean.txt`、`《人祖传》.txt` 等）仍保持不入库。`.gitignore` 与根 `AGENTS.md` 已同步写入例外说明。

## 4. 已识别差异（记录，未裁决）

1. **EPUB 内部缺陷**：chapter_61=62 整章一字不差重复（73 段）；chapter_836/837、879/880 同题两版（相似度 0.76/0.80）——需 L0/L1 裁决去重/保留。
2. **结尾多 54 章**：卷六·节 315–368（ch2310~2364）为旧源所无（旧源六段止于节 314，含天庭大战结局）——EPUB 更完整，待对照确认。
3. **EPUB 缺节**：一段·节 77「阴差阳错」（节号 76→78 跳号）；四段·节 331 等——旧源独有。
4. **节号回退 5 处**：ch534/1048/1358/1560/1778 卷内节号标注异常。
5. **非正文**：ch0 序、47 求票、2269 全渠道感言、2358 完本感言类，建议与正文分区管理。

## 5. 请 L1 判断的下一步计划（候选方向）

**候选 A（推荐起点）：第一批 E-ID 自动迁移**
- 范围：4,594 个精确可迁移 E-ID → 页面 `E:Vx-xxxxxx` 改写为 `EPUB:chapter_N:para_M`，**保留旧行号双轨**作历史锚
- 依据：`eid-migration-map-final.tsv` class=exact 行；Golden Page 精确率 90–99%
- 产出：每页 diff 补丁 + 迁移登记表；跑 `check.ps1` check1–8 门禁

**候选 B：坏锚修正批（并行可做）**
- 21 个空行坏锚 + 30 个段号越界 E-ID + 7 个引文过短 → 人工核对正确锚点后迁移

**候选 C：重章裁决**
- ch61/62、836/837、879/880 → L0/L1 裁决保留策略（去重 or 保留双版标注），裁决后落 canon 标记

**候选 D：索引切换**
- `section-index.md`/`chapter-index.md` 重建为 chapter/para 索引，旧行号列降级为辅助

**候选 E：回归与退役**
- Golden Page 回归（基线 90–99%）→ 全部通过后旧源移 `archive/`（不删除）

> L1 可从中选择、排序或裁剪；迁移节奏建议按 AGENTS.md「批次与评审」五步走（抽取→归一→时序因果→巩固→页面重构）执行，单批聚焦、批内闭环。

## 6. 移交物清单

- `lore/wiki/2026-09-28-epub-canon-migration-report.md` — 验证报告 v2（差异清单 §3、切换步骤 §7）
- `lore/wiki/source/eid-migration-map-final.tsv` — 4,880 E-ID 分类迁移映射
- `lore/wiki/source/old-line-to-epub-map.tsv` — 195,362 行旧行号→EPUB 地址全量映射
- `source/蛊真人-epub-canon.txt` — 新规范源全文（已入库推送）
- 中间产物（本地工作目录，不入库）：`eid_line_match_v2.json`、`epub_parsed.json`、`parse_epub.py` 等

## 7. 遗留依赖

- EPUB 原件与旧源 `蛊真人-clean.txt` 均在附件目录（本地）；切换执行批需要时可直接读取。
- 30 个段号越界 E-ID 的修正需 L1 提供正确锚点口径（沿用行号 or 改用段内节号）。

## 8. 2026-09-29 L2 执行补记：候选计划已按新证据重排

旧 §2/§5 是 `c841d522` 迁移快照及当时提出的候选，不代表当前完整 Live E-ID 集；“4,594 精确即可批量迁移”的前提已被独立 verifier 证伪。现执行顺序改为：固定并复现派生文本 → 从当前活动 Wiki/runtime/Web 重提取 Live E-ID → 重建逐项决策及页覆盖账本 → 处理人工阻断 → shadow compile → regression 与 rollback drill → 最后才考虑 Canon/index pointer 切换。E-ID 保留为历史 Evidence ID；不能因 locator 更新而删除旧 ID。

复核事实与机器产物见关联迁移报告 §9 及 §10 及 [`source/README.md`](source/README.md)。口径 **v3（C2 消歧，2026-09-29）** 结果（6,515 个 Live E-ID）：**6,322 `auto_verified`（较 v1 基线 +609）、0 `human_approved`、193 `blocked`**；`blocked` 全部标记 `human_review_required`。runtime 恢复 80 页中 40 页仍含阻断项（v2 计 58、v1 计 75），最近 40 页中 20 页（v2 计 36、v1 计 40）。旧口径「801 = 真正 blocker」已作废；801/802 的差异原因是互斥残差与非互斥谓词计数混加（详见报告 §10.3）。正式切源尚未执行；**blocked 清零前不切 Canon、不做正式 locator migration**。进入 shadow compile 的条件仍为 `auto_verified + human_approved = 6,515` 且 `blocked = 0`，当前均未满足。

## 9. 2026-09-30 接手会话补记：切源已接入，四项口径待 L1 裁决

L0 于 2026-09-30 要求把 EPUB 正文接入 Wiki runtime，接入改动在工作区未提交状态（HEAD 仍为 `4b739c45`）。复核发现接入同时带来四项未裁决变更：迁移窗口 `MAX_CONTEXT_SPAN` 5→12、段号越界按唯一候选放行、pack 状态行硬编码白名单（84→15）、EPUB 正文站点残留；另有 runtime 产物早于迁移台账 24 分钟导致 22 条 E-ID 状态不一致。全部证据、复现命令与逐条问题见 [`2026-09-30-epub-canon-l1-review-pack.md`](2026-09-30-epub-canon-l1-review-pack.md)。本节不改写 §8 的 v3 结论——§8 描述的是已归档口径，工作区台账已非该口径，须待 L1 裁决后统一升版与同步。
