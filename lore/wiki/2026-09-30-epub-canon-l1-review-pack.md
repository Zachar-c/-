# EPUB Canonical Source 切源接入 — L1 审阅材料包

> 提交人：L2（Codex 接手会话）· 日期：2026-09-30
> 审阅对象：L1 证据层与迁移口径评审 · 目的：对 D1–D4 四项口径/范围变更做裁决，并确认一项产物同步缺陷的修法
> 关联：[`2026-09-29-epub-canon-l1-handoff.md`](2026-09-29-epub-canon-l1-handoff.md)、[`2026-09-28-epub-canon-migration-report.md`](2026-09-28-epub-canon-migration-report.md) §10、[`source/README.md`](source/README.md)、[`lore/runtime/README.md`](../runtime/README.md)、[GitHub #13](https://github.com/Zachar-c/-/issues/13)
> 工作区：`b5f92876-c43c-4e3d-b787-45378b6c444b::C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren`；HEAD `4b739c45`（`master` 与 `origin/master` 同步）；未提交：31 个已跟踪文件改写 + `lore/runtime/evidence-locators.json`、`game/wenzhen-web-lab/assets/wenzhen/`、144 个 Godot `.import` 未跟踪

## 0. 本包边界（先读这段）

- 本包**只请求口径与范围裁决**（D1–D4）和一个产物同步动作授权，不请求产品方向变更，不改游戏数值。
- 切源主体（runtime 绑定 EPUB 正文、生成定位表、编译器改为哈希+台账校验）已按 L0 2026-09-30 要求接入，本包只做**备案与验收留痕**，见 §1。
- 本包所有数字均为本工作区实测，命令见 §7 与附录 A。**本会话未重跑** `verify_epub_migration.py` 与 `compile_runtime.py`：两者都会覆写同工作区另一会话的在途产物，且 §2 口径未定前重跑会固化未裁决结果。§11 的人工复核只改台账单元格，不重跑生成器。
- §2.4 的台账数字为**人工复核前**状态；§11.2 给出复核后的最新分布（6,405 / 15 / 95）。
- 本工作区由两个会话共用。任何裁决落地前，请以本包数字为准，不以工作区现有产物为准（原因见 D5）。

## 1. 已完成并已验证的接入（备案，无需裁决）

| 项 | 事实 | 证据 |
|---|---|---|
| runtime 正文源 | `source.id=gu_zhenren_epub`、`path=source/蛊真人-epub-canon.txt`、`sha256=9f6952f8…`、`lines=219942` | [`lore/runtime/manifest.json:6-11`](../runtime/manifest.json) |
| 旧源降级 | `legacy_evidence_source` 保留旧 TXT `sha256=bf78d414…`、`lines=437060`，仅供旧 E-ID/行号回查 | [`lore/runtime/manifest.json:12-16`](../runtime/manifest.json) |
| 定位表 | `lore/runtime/evidence-locators.json`：1,997 条 = 1,955 `auto_verified` + 42 `blocked`；42 条 `epub_locator` 全为 `null`（未伪称已映射） | 本包 §7 命令 3 |
| 编译器校验链 | 编译前校验 EPUB 正文、段落索引、迁移台账三方 SHA-256；逐条核对段落哈希与旧源哈希；台账缺任一 live E-ID 即 `fail()` 退出 | [`lore/wiki/tools/compile_runtime.py:130-166`](../wiki/tools/compile_runtime.py) |
| Web 侧同步 | `game/wenzhen-web-lab/js/data.js` 的 `contentVersion` / `sourceSha256` 已随 runtime 更新 | [`game/wenzhen-web-lab/js/data.js:7326-7327`](../../game/wenzhen-web-lab/js/data.js) |
| 回归断言 | 新增断言：`blocked` 计数等于 `manifest.unresolved_evidence_count`、`epub_locator` 空值与 `decision` 一致、实体 evidence 必须在定位表中 | [`game/wenzhen-web-lab/tests/canon_pack.test.mjs:32-43`](../../game/wenzhen-web-lab/tests/canon_pack.test.mjs) |
| 门禁 | G0 `docs-lint`：FAIL 0 / WARN 0；G1 `check.ps1`：check1–9 全 PASS（21,046 个 E-ID 段号校验）；`node --test canon_pack.test.mjs`：9/9 PASS | §7 命令 4–6 |

Wiki 页面层本轮只改了**主张措辞**（采纳 EPUB 用词并标注版本差异），未改 E-ID、未做 locator 改写。样例：[`lore/wiki/gu/white-jade-gu.md:47`](gu/white-jade-gu.md) 把「防御力却高出了两倍有余」按 EPUB 记为「高出了两倍不足」，并把旧 TXT 措辞降级为版本差异。共 13 个内容页受影响：`gu/` 5、`events/` 4、`world/` 2、`rules/` 1、`characters/` 1（`lore/wiki/rules/dream-path.md`）。

## 2. D1（最高优先）迁移口径被放宽且未版本化

### 2.1 变更内容（`lore/wiki/tools/verify_epub_migration.py`）

| 行 | HEAD | 工作区 | 性质 |
|---|---|---|---|
| `verify_epub_migration.py:127` | `MAX_CONTEXT_SPAN = 5` | `MAX_CONTEXT_SPAN = 12` | 放宽位置证明的闭区间宽度上限 |
| `verify_epub_migration.py:126` | 无 | `# ponytail: 12 covers the reviewed live intervals; review longer gaps before raising it.` | 注释自认「尚未复核即放宽」，且遗留代号词 |
| `verify_epub_migration.py:647` | `elif len(in_window) == 1:` | `elif len(in_window) == 1 or (candidate_count == 1 and not segment_ok):` | 段号越界（`segment_bounds_ok=false`）时也按唯一候选放行 |

对应地，[`lore/wiki/source/epub-canonical-build-manifest.json`](source/epub-canonical-build-manifest.json) 的 `context_alignment.max_context_span_lines` 由 5 记为 12（参数被记录，但**口径版本号未升**）。

### 2.2 与已提交口径文档直接冲突

[`2026-09-28-epub-canon-migration-report.md`](2026-09-28-epub-canon-migration-report.md) §10.2 白纸黑字：「区间宽度上限 5 行（即迁移令要求的旧源 ±2 行窗口）」，并在守卫常量表里把 `MAX_CONTEXT_SPAN=5` 列为 v3 口径的一部分。工作区改为 12，等于**在未升版本、未改口径文档的情况下换掉了 v3 的一个守卫常量**。

### 2.3 版本字段未升

`eid-migration-decisions.tsv` 全部 6,515 行的 `extractor_version` 仍为 `bs4-4.15.0/html.parser-v1`、`mapping_version` 仍为 `1`；`epub-canonical-build-manifest.json` 的 `manifest_version` 仍为 `1`。产物内容已变、版本号未变，后续无法用版本号判断某份台账出自哪套口径。

### 2.4 数字漂移（live 6,515 行）

| 项 | HEAD（报告 §10.4，v3） | 工作区（重跑结果） | 差 |
|---|---|---|---|
| `auto_verified` | 6,322 | **6,405** | +83 |
| `blocked` | 193 | **110** | −83 |
| `exact_full_paragraph` | 5,783 | 5,804 | +21 |
| `positional_alignment` | 438 | 500 | +62 |
| `heading_locator` | 101 | 101 | 0 |
| `blocked: segment_alignment` | 76 | 71 | −5 |
| `blocked: context_too_wide` | 62 | **0** | −62 |
| `blocked: slot_outside_anchor_window` | 16 | **0** | −16 |
| `blocked: blank_or_out_of_range` | 21 | 21 | 0 |
| `blocked: positional_text_divergence` | 8 | 8 | 0 |
| `blocked: ambiguous_region` | 5 | 5 | 0 |
| `blocked: heading_unresolved` | 3 | 3 | 0 |
| `blocked: multiple_candidates` | 2 | 2 | 0 |
| 次要理由 `true_ambiguity` | 69 | **7** | −62 |
| 次要理由 `paragraph_segmentation_difference` | 122 | 101 | −21 |
| `live_reference_count` | 22,802 | 22,667 | −135（归因未查明，见 §6 Q6） |

83 条翻转的构成（逐行比对 HEAD 与工作区 TSV）：

| 原 `withheld_reason` | 新 `migration_basis` | 新 `selected_locator_kind` | 条数 | `segment_bounds_ok` |
|---|---|---|---|---|
| `context_too_wide` | `positional_alignment` | `para` | 62 | true |
| `slot_outside_anchor_window` | `exact_full_paragraph` | `para` | 16 | **false** |
| `segment_alignment` | `exact_full_paragraph` | `para` | 5 | **false** |

### 2.5 L2 独立抽检（不依赖 extractor 自述）

对 83 条翻转逐条取「旧 TXT 该行」与「EPUB 目标段落」做字符级比对（附录 A 命令 5）：

| 组 | n | 最低 | P10 | 中位 | 最高 | <0.90 | <0.80 |
|---|---|---|---|---|---|---|---|
| 62 条窗口放宽 | 62 | 0.7750 | 0.9107 | 0.9658 | 0.9939 | 4 | 1 |
| 21 条段号守卫放宽 | 21 | 1.0000 | 1.0000 | 1.0000 | 1.0000 | 0 | 0 |

逐字差异样例（`unicode_escape`，便于跨终端核对）：

| E-ID | 旧行 → EPUB 定位 | 相似度 | 差异 |
|---|---|---|---|
| `E:V1-016054` | 16054 → `EPUB:chapter_0101:para_007` | 0.9600 | `坚硬`→`稳固` |
| `E:V1-016056` | 16056 → `EPUB:chapter_0101:para_008` | 0.9649 | `有余`→`不足` |
| `E:V1-016058` | 16058 → `EPUB:chapter_0101:para_009` | 0.9070 | `进攻`→`防御`；`现在`→`如今` |
| `E:V1-016060` | 16060 → `EPUB:chapter_0101:para_010` | 0.9833 | `使`→`运` |
| `E:V4-162414` | 162414 → `EPUB:chapter_0898:para_062` | 0.7750 | EPUB 段落尾部多出站点残留（见 D4） |
| `E:V5-195296` | 195296 → `EPUB:chapter_1068:para_018` | 0.8750 | 破折号插入 |

21 条段号守卫放宽的样本（`E:V1-034416`、`E:V1-034444`、`E:V4-187780`、`E:V6-436648`）旧行与 EPUB 段落**逐字相同**（相似度 1.0000），说明该处阻断只来自段号标签校验，不是文本证据不足。

### 2.6 风险判断（显式分析，非事实）

- 62 条窗口放宽的抽检**未发现错位**，中位相似度 0.966，且其中 4 条正是 §1 已按 EPUB 用词改写过的白玉蛊类版本差异。但 `MAX_CONTEXT_SPAN` 正是防止「锚点间隔过大时把行配到邻近段落」的唯一守卫；把窗口从 5 放宽到 12 意味着**单区间最多容纳 12 个旧源行**，误分类一个 structural 行即可能整体错位。`SIMILARITY_FLOOR=0.90` 只作证明的护栏，不参与选段（报告 §10.2 已言明），因此护栏不能替代窗口纪律。
- 21 条段号守卫放宽的证据最硬（逐字相同），风险主要在**规则一致性**：`segment_bounds_ok` 被整体绕过，而不是逐条人工确认。
- `true_ambiguity` 由 69 降到 7，说明「真歧义」这一护栏事实上被大幅削弱；报告 §10.2 承诺「落点进入重复/异版章即 `ambiguous_region`」，而 `ambiguous_chapters` 仍是 3 个（`chapter_61/62`、`836/837`、`879/880`）。窗口变宽会提高落点滑入异版区的概率，这一风险目前**没有对应的抽样证据**。

### 2.7 请 L1 裁决

- 选项 A：**追认**（把 12 视为 v4 口径），并要求同批完成：① `mapping_version` 升为 2、`manifest_version` 升为 2、`extractor_version` 标注窗口变更；② 报告新增 §11 记录 v4 口径与 5→12 的理由；③ 追加一次「落点是否滑入 `ambiguous_chapters`」的专项抽检。
- 选项 B：**回退到 5**，把 62 条退回 `blocked/context_too_wide`，并改为逐条人工复核后再放行；21 条段号守卫放宽可单独保留（逐字相同证据充分）。
- 选项 C：**折中**，`MAX_CONTEXT_SPAN=8`，并把 12 行以内的区间列为「需人工确认」队列。
- L2 建议：**B+**（先回退窗口，21 条段号项以「逐字相同」证据单独追认），理由是窗口是唯一防错位守卫，而当前没有任何针对 12 行窗口的错位抽检；已付出的成本仅是 62 条继续挂 `blocked`，这些 E-ID 在 runtime 中本来就没有被消费为定位（见 D5）。

## 3. D2 文档数字与产物脱节

- [`CHANGELOG.md:9`](../../CHANGELOG.md) 写「全 Wiki 193 个未决继续由 #13 跟踪」；[`docs/debt.md:7`](../../docs/debt.md) 写「6,515 个 E-ID 中 6,322 个已核验、193 个未决」。工作区产物实际为 **6,405 / 110**。
- 同一 debt 行仍保留「完成人工复核与剩余 193 个定位」的处置口径；`docs/debt.md` 与 `lore/wiki/source/README.md` 之间对「是否已接入」表述也不同步（前者写「按用户要求接入」，后者保留「blocked 清零前不切 Canon」的冻结语）。
- L2 **未擅自改这些数字**：D1 未裁决前，110 与 193 哪个是「正确口径下的数字」尚未确定，改数字等于替 L1 做口径选择。
- 请 L1 裁决：D1 结果确定后，由 L2 一次性同步 `CHANGELOG.md`、`docs/debt.md`、报告 §10 与 `lore/wiki/source/README.md`（同一批、同一次提交），是否可行。

## 4. D3 pack 状态行白名单（范围变更，且修掉一个既有红灯）

### 4.1 事实

- [`lore/wiki/tools/compile_runtime.py:90-93`](../wiki/tools/compile_runtime.py) 新增硬编码 `state_ids` 白名单（15 项），`build_packs` 据此裁剪实体状态（[`compile_runtime.py:557-561`](../wiki/tools/compile_runtime.py)），并在白名单与实际编译结果不符时 `fail()`。
- 生成物效果：`lore/runtime/packs/south_border_rank1_combat.json` 状态行 **84 → 15**（entities 10、rules 32、relations 2 均未变）；`lore/runtime/entities.json` 仍为 169 实体 / 825 状态行 / 162 evidence，**全量数据未丢**。
- 选取规则无法从产物反推：7 个实体各取 `*-01/02`，`moonlight_gu` 取 `ST-MOONLIGHT-03/04/05`（跳过 01/02）。仓库内无任何文档说明依据；`game/wenzhen-web-lab` 未引用具体 `ST-*`（`git grep -n "ST-" -- game/wenzhen-web-lab` 只命中 `CAN-*`）。
- `lore/runtime/manifest.json` 的 `coverage_notes` 仍写「实体状态行 825 条（来自实体页状态时间线，随实体与 pack 编译）」，**未反映 pack 实际只装 15 条**。

### 4.2 一个此前未被记录的既有红灯

`game/wenzhen-web-lab/tests/canon_pack.test.mjs:93-96` 断言 pack 体积 `< 20000` 字符。按 HEAD 产物实测：`JSON.stringify` 等价长度 **27,033**（超预算 35%），即该测试在 HEAD `4b739c45` 上**本应失败**；工作区产物为 **17,484**，测试 9/9 通过。

- 即：白名单同时（a）修掉一个既有红灯，（b）引入未记录的范围收缩。红灯此前未被任何 CHANGELOG、debt 或 issue 登记（`gh issue list` 13 个 open issue 中无对应项）。
- 请 L1 裁决：
  1. `south_border_rank1_combat` 的定位是「一转战斗切片」还是「全量投影」？若是切片，纳入判据应写成可复算规则（例如「每实体保留战斗相关状态，且总量受预算约束」），而不是 15 项硬编码清单。
  2. 允许修红灯（应登记为 debt 并注明「HEAD 曾失败」），还是要求回退状态行、另设预算？
  3. `manifest.coverage_notes` 是否必须同步登记 pack 级状态行实际条数。

## 5. D4 规范正文含站点残留（本次新发现）

- 扫描 `source/蛊真人-epub-canon.txt`：含「未完待续」的行 **1,165** 行；含「最新章节」**4** 行；含「求票」**2** 行。例：物理行 4,499 结尾为 `（未完待续）`；物理行 53,409 结尾为 `(请搜索，或者直接输入看最新章节)`。
- 影响面：这些段落进入 `chapter-paragraph-index.tsv` 的段落哈希，`evidence-locators.json` 指向的段落因此含污染文本；任何按段落直接引文的流程都会把站点话术当成原文。D1 中相似度最低的 `E:V4-162414` 正是此类（EPUB 段落尾部多出「(未完待续请搜索，小说更好更新更快!」）。
- 报告 §10.1 只登记了**旧源**残留（`**` 占位、`8 9 阅 读 网` 水印、`〖〗`），未登记 EPUB 侧残留。
- 请 L1 裁决：（a）清洗后重算段落索引与全部台账（成本高、需重跑 D1 全部验证）；（b）登记为已知污染，禁止 wiki 直接引用被污染段落，定位仍可用；（c）只清洗尾部标记、不动段序。L2 倾向 (b)＋(c) 组合：定位可用性优先，引用侧加门禁。

## 6. D5 runtime 产物与迁移台账不同步（需授权修法）

- 时间戳：`lore/wiki/source/eid-migration-decisions.tsv` 与 `epub-canonical-build-manifest.json` 为 **2026-09-30 10:57**；`lore/runtime/manifest.json` 与 `evidence-locators.json` 为 **2026-09-30 10:33**。runtime 产物早于台账 24 分钟，属**陈旧产物**。
- 后果（逐条比对）：runtime 使用的 1,997 个 E-ID 中，**22 条**在台账里已是 `auto_verified` 且有 `canonical_locator`，runtime 仍记 `blocked` + `epub_locator: null`；`manifest.unresolved_evidence_count` 仍为 **42**，按当前台账重算应为 **20**。
- 受影响的 22 条包含 §1 已按 EPUB 用词改写页面的引用 E-ID（`E:V1-016056`、`E:V1-016058`、`E:V1-016070` 等，见 [`lore/wiki/gu/white-jade-gu.md:47`](gu/white-jade-gu.md)）——即页面已按 EPUB 措辞表述，runtime 定位却仍为空。
- 本会话**未重跑编译器**（理由见 §0）。请 L1 授权：D1 裁决落地后由 L2 重跑 `compile_runtime.py` 与 `game/wenzhen-web-lab` 数据构建，并以重跑后的 `unresolved_evidence_count` 作为唯一登记数字。

## 7. 验证记录（本工作区真实输出）

1. `git status --porcelain` → 31 个已跟踪文件改写；未跟踪：`lore/runtime/evidence-locators.json`、`game/wenzhen-web-lab/assets/wenzhen/`、144 个 `.import`。
2. `node --test tests/canon_pack.test.mjs`（`game/wenzhen-web-lab`）→ `tests 9 / pass 9 / fail 0`。
3. 定位表统计 → `1,997 = 1,955 auto_verified + 42 blocked`，`null locator = 42`。
4. `pwsh -NoProfile -File lore/wiki/tools/check.ps1` → `PASS check1…check9`、`ALL CHECKS PASSED`（check9：21,046/21,046 个 E-ID 段号与六段表一致）。
5. `node tools/docs-lint.mjs` → `页面数 1102`、`FAIL 0，WARN 0，编译层孤儿 0，其他孤儿 8`（8 个为 `game/wenzhen-web-lab/docs/tmp/`）、备注 1。
6. 台账比对脚本（附录 A 命令 3–5）→ §2.4、§2.5、§6 全部数字。
7. 未执行：`verify_epub_migration.py`、`compile_runtime.py`（§0）、任何 `git commit` / `git push`。

## 8. 请 L1 逐条回答的问题清单

| 编号 | 问题 | 关联 |
|---|---|---|
| Q1 | `MAX_CONTEXT_SPAN` 5→12 是否追认为 v4？若追认，是否必须同批升 `mapping_version`/`manifest_version` 并补报告 §11？ | D1 / §2.1–2.3 |
| Q2 | 段号越界时按唯一候选放行（21 条，逐字相同）是否可单独追认为规则？ | D1 / §2.4–2.5 |
| Q3 | 是否要求对 12 行窗口做「落点是否滑入 `ambiguous_chapters`（`chapter_61/62`、`836/837`、`879/880`）」的专项抽检？ | D1 / §2.6 |
| Q4 | `CHANGELOG.md`、`docs/debt.md`、报告 §10、`source/README.md` 的数字与冻结语，待 D1 定案后由 L2 一次性同步——是否批准该流程？ | D2 |
| Q5 | `south_border_rank1_combat` 是战斗切片还是全量投影？若切片，状态行纳入判据请给出可复算规则；是否允许以修既有体积红灯为由收缩？ | D3 / §4 |
| Q6 | EPUB 正文站点残留（1,165 行）按「登记 + 引用门禁」处理，还是要求清洗后全量重算？ | D4 / §5 |
| Q7 | 是否授权在 D1 定案后重跑 `compile_runtime.py`，并以重跑结果（预计 `unresolved_evidence_count=20`）作为唯一登记数字？ | D5 / §6 |
| Q8 | `live_reference_count` 22,802→22,667（−135）的归因：是否要求先查明再登记？L2 未能从页面 diff 归因（`lore/wiki` diff 中 E-ID 增删行数持平，TSV 数据行干扰计数），故暂列为未归因。 | §2.4 |
| Q9 | `lore/wiki/AGENTS.md` 的来源规范是否新增 EPUB 命名空间（`:13` L0 原文层表格、`:45`/`:77` 命名空间四类、`:72` 原文锚点形式）？这会动 frontmatter `sources:` 的取值域，属 schema 变更，L2 不自行加。 | §10.2 |
| Q10 | `scripts/compress_full_book.py:4`（以旧 TXT 为唯一底本）与 `game/world-model/RISK_REGISTER.md:201`（旧源 `**` 噪声取证风险）是否在本批改指 EPUB？L2 建议不在本批处理。 | §10.3 |
| Q11 | 是否扩展人工复核保留路径以支持 heading 型定位（`E:V5-289108`）？现状：`verify_epub_migration.py:787-789` 要求段落号非空，heading 型写了也会在重跑时丢失。L2 倾向：该 1 条继续挂 blocked，不为 1 条改机制。 | §11.3 |
| Q12 | **canon 缺整节**（旧源第七十七节「阴差阳错」不在 EPUB 中，3 条 live E-ID 因此无定位）如何处置：登记为已知缺口并保留旧 TXT 作该节回查源，还是要求换用更完整的 EPUB 版本重跑？此为切源前提问题，建议与 D1 同批裁决。 | §11.3 |

## 9. 未做与不做（防止误读）

- 未改任何 Wiki 语义、数值或契约；未改 E-ID；未新增页面级 locator 改写。
- 未重跑两个生成脚本，未 commit、未 push、未改 `CHANGELOG.md` 与 `docs/debt.md` 的数字。
- 未回退另一会话的任何改动；本包所有新增内容只有一个文件（本文件）与两处 hub 链接（[`lore/wiki/README.md`](README.md)、[`2026-09-29-epub-canon-l1-handoff.md`](2026-09-29-epub-canon-l1-handoff.md) §8）。
- 本包 §2.6、§4.2 属显式分析/推断，其余为实测事实；所有数字可按附录 A 复算。

## 10. 剩余引用核对（L2 已完成，交回 L1 归类）

盘点命令（一次性，无新增工具）：`git grep -n -I -e 蛊真人-clean -- .`，按「旧行号锚 / `source:` 命名空间 / 工具代码 / 历史记录」分类。tracked 文件命中 **1,307 行**。

| 类别 | 行数 | 文件数 | 处置 |
|---|---|---|---|
| D `lore/wiki/**` 页面（正文旧行号锚 435 处 / 68 页；`source:` 声明 211 行） | 748 | 209 | 允许保留：`lore/wiki/AGENTS.md:5` 已声明旧锚为历史回查；页面级 locator 改写属原候选 D，未开始 |
| F 其他现行文档与代码（`docs/design/`、`ai-system/`、`game/`、镜像层） | 265 | 104 | 多为设计文档与游戏数据的证据串；本批不动 |
| C 工具与配置代码（`editorial/scripts/`、`game/lore_sources/manifest.json`、`game/wenzhen-web-lab/js/*` 等） | 131 | 27 | **确实需要旧 TXT**，保持不动 |
| E 历史/审计/研究记录（`docs/superpowers/`、`.superpowers/`、`lore/research/`、`lore/wiki/log.md`、`MIGRATION.md`） | 85 | 16 | 历史记录不可改写 |
| G 仓库根与配置（`.gitignore`、`.gitattributes`、`.zcodeignore`、根 `AGENTS.md` 等） | 77 | 61 | 边界规则，例外已由 2026-09-29/30 裁决写明 |
| B 迁移台账与 runtime 说明 | 1 | 1 | 已随本轮更新 |

结论：**没有一条属于本轮可在边界内直接修的缺陷**；三类需 L1 归入既有或新裁决项。

### 10.1 已核对为「应当保留」

- `lore/wiki` 68 页 435 处 `蛊真人-clean.txt:行号`：E-ID 双轨设计的一部分，Wiki 页面目前 **0 页**使用 `EPUB:chapter_…` 定位（该形式仅出现在本包、报告与交接文档共 9 处）。是否做页面级改写需单独立批并给页覆盖优先级。
- C 类 27 个工具/配置确实读取旧 TXT（editorial 净版流水线、`game/lore_sources/manifest.json`、Web 数据），旧 TXT 作为 legacy evidence recovery source 保留即为此。

### 10.2 需裁决：Wiki 来源规范内部不一致（Q9）

`lore/wiki/AGENTS.md` 第 5 行已声明「正文以 `source/蛊真人-epub-canon.txt` 为准」，但同文件规范正文仍只承认旧源：`:13`（L0 原文层内容写作 `蛊真人-clean.txt`）、`:45`（来源命名空间沿用 `source:source/蛊真人-clean.txt`）、`:72`（事实锚点用 `蛊真人-clean.txt:行号`）、`:77`（命名空间固定四类）。修法必然触及 frontmatter `sources:` 取值域与 check.ps1 的已知路径白名单 = **schema 变更**，按 `lore/wiki/AGENTS.md:107` 冻结条款须走 L1 评审，L2 不自行加新命名空间。

### 10.3 需裁决：段表与工具指向（Q10）

- `lore/wiki/source/section-index.md:8` 与生成脚本 `lore/wiki/tools/build_section_index.py:145` 均写「行号列是 Wiki 内唯一的精确锚点」。与 `lore/runtime/evidence-locators.json` 并存后该表述已不准确；段表是否重建为 chapter/para 索引即原候选 D，属口径。
- `scripts/compress_full_book.py:4` 以旧 TXT 为唯一底本做全量压缩；`game/world-model/RISK_REGISTER.md:201` 记录旧源 782 处 `**` 噪声导致的取证风险。二者改指 EPUB 属另一条线的范围，L2 建议不在本批处理。

## 11. 人工复核批次记录（2026-09-30，L2 实施）

在 D1–D5 未裁决的前提下，L2 只做了**不依赖口径**的一项收尾：对 runtime 仍在消费的 blocked E-ID 做人工复核，并按既有机制写回台账。未新增任何抽象层、schema 或工具。

### 11.1 范围与机制

- 范围：runtime 消费且当前真 blocked 的 **20 条**（`evidence-locators.json` 1,997 条中，排除 D5 的 22 条陈旧项后）。剔除机制限制的 1 条后，实际复核 19 条。
- 机制：台账人工复核保留路径已存在（[`lore/wiki/tools/verify_epub_migration.py:783-803`](../wiki/tools/verify_epub_migration.py)）——重跑时若旧行的 `old_source_sha256` / `old_text_sha256` / `new_source_sha256_lf` / `paragraph_sha256` 与当前一致且 `reviewer`/`reviewed_at`/`review_reason` 非空，则 `human_approved` 被保留。因此只改台账单元格，未重跑任何生成脚本。
- 一次性辅助脚本置于系统临时目录（仓库外），未入库。

### 11.2 结果：15 条通过，5 条保留 blocked

| E-ID | 旧行 → EPUB 定位 | 相似度 | 复核依据 |
|---|---|---|---|
| `E:V1-016488` | 16488 → `chapter_0103:para_059` | 0.9474 | 同句，仅标点差异 |
| `E:V1-016490` | 16490 → `chapter_0103:para_060` | 0.8718 | 旧「二转盅虫」= canon「二转蛊虫」正字法变体 |
| `E:V1-016494` | 16494 → `chapter_0103:para_062` | 0.9333 | 同句，仅标点差异 |
| `E:V1-016496` | 16496 → `chapter_0103:para_063` | 0.5192 | canon 将旧 16496/16498 合并为一段 |
| `E:V1-016498` | 16498 → `chapter_0103:para_063` | 0.7438 | 同上（同一段落内不同句） |
| `E:V1-018222` | 18222 → `chapter_0112:para_087` | 0.9912 | canon 作「黒豕蛊」，正字法变体 |
| `E:V2-055824` | 55824 → `chapter_0302:para_095` | 0.9730 | 旧「枯萎蛊」/ canon「天蓬蛊」用名差异（见 11.4） |
| `E:V2-057022` | 57022 → `chapter_0309:para_030` | 0.9552 | 同句，仅标点差异 |
| `E:V2-057026` | 57026 → `chapter_0309:para_032` | 0.9474 | 旧「夭然蛊」= canon「天然蛊」；canon 段内句号拆分 |
| `E:V2-057028` | 57028 → `chapter_0309:para_033` | 0.9762 | 同句，断句与标点差异 |
| `E:V4-123502` | 123502 → `chapter_0666:para_014` | 0.9833 | 同句，仅标点差异 |
| `E:V4-151696` | 151696 → `chapter_0836:para_073` | 1.0000 | `chapter_0836/0837` 该段逐字相同（异版重章），取先出现者 |
| `E:V4-159038` | 159038 → `chapter_0879:para_068` | 1.0000 | `chapter_0879/0880` 该句逐字相同（异版重章），取先出现者 |
| `E:V5-196814` | 196814 → `chapter_1076:para_001` | 0.9091 | 同句，仅标点差异 |
| `E:V5-242168` | 242168 → `chapter_1313:para_082` | 0.6667 | 旧「价值完全不等于。」= canon「价值完全不等。」+ 站点残留；另两处候选语义不同 |

台账现状（live 6,515）：`auto_verified` 6,405 / `human_approved` **15** / `blocked` **95**（原 110）。剩余 blocked 构成：`segment_alignment` 59、`blank_or_out_of_range` 21、`positional_text_divergence` 7、`ambiguous_region` 4、`heading_unresolved` 3、`multiple_candidates` 1。

### 11.3 保留 blocked 的 5 条：其中 3 条已按 ADJUST 做单点修复，2 组待 Q12

| E-ID | 旧行 | 处置 |
|---|---|---|
| `E:V1-012144` / `E:V1-012146` / `E:V1-012150` | 12144 / 12146 / 12150 | **仍 blocked，待 Q12**：EPUB canon 缺整节内容（详见 11.6） |
| `E:V5-286670` | 286670 | **已修**：`lore/wiki/gu/soul-atk-5-01-gu.md` 6 处换锚。正文 locator 取 `E:V5-258000`（`EPUB:chapter_1396:para_075`，原文「铺设命理相位蛊阵…算出我弟的位置」），并补 `E:V5-271120`（`EPUB:chapter_1464:para_009`，两者破碎后无法定位）、`E:V5-250654`（`EPUB:chapter_1358:para_091`，碎裂即可能陨落）、`E:V5-250478`（`EPUB:chapter_1358:para_003`，宗族祠堂存放此蛊）——四条均已 `auto_verified`。该页已无 `E:V5-286670` 引用 |
| `E:V5-289108`（及同类的 `E:V5-289398`） | 289108 / 289398 | **已修**：未扩 heading 机制，改用同字符串且已定位的 `E:V5-288976`／`E:V5-289268`（均 `EPUB:chapter_1571:heading`）＋正文 `E:V5-289070`（`EPUB:chapter_1571:para_045`）。289108／289398 降为旧行号回查（该页原本就写明「这类行不应用作 E-ID 锚点」），两 E-ID 已无页面引用 |
| `E:V2-055824` | 55824 | **无需改页面**：`lore/wiki/gu/force-atk-3-29-gu.md` 本身即「天蓬蛊」页，与 canon（`chapter_0302:para_095` 作「天蓬蛊」）一致；「枯萎蛊」只存在于旧源该行，全仓除台账复核备注外无 `枯萎蛊` 表述。按新 Canon 无需页面改动 |

### 11.4 顺带发现（已核，无需页面改动）

`E:V2-055824` 的旧源文本作「枯萎蛊」，canon 作「天蓬蛊」（同句、同位置、同段）。引用该 E-ID 的 `lore/wiki/gu/force-atk-3-29-gu.md` 本身就是天蓬蛊页，全仓无 `枯萎蛊` 表述（除台账复核备注），**与新 Canon 一致，无需改页面**。

### 11.5 本批验证

- 改动范围：台账仅 15 行变动，变更列并集 = `selected_chapter_id`、`selected_paragraph_id`、`selected_locator_kind`、`canonical_locator`、`paragraph_sha256`、`decision`、`primary_blocker_class`、`withheld_reason`、`human_review_required`、`migration_basis`、`reviewer`、`reviewed_at`、`review_reason`；行数 6,772 → 6,772 不变。
- 页面改动 2 个文件：`lore/wiki/gu/soul-atk-5-01-gu.md`（6 处）、`lore/wiki/gu/heaven-atk-5-07-gu.md`（4 处）；`E:V5-286670`／`E:V5-289108`／`E:V5-289398` 在页面层的引用已清零（台账 `used_by_files_json` 为上次运行的快照，重编译后同步）。
- `pwsh -NoProfile -File lore/wiki/tools/check.ps1` → `ALL CHECKS PASSED`（check9：21,080 个 E-ID）。
- `node --test tests/canon_pack.test.mjs` → `pass 9 / fail 0`。
- `node tools/docs-lint.mjs` → `FAIL 0，WARN 0`。
- **未重跑** `verify_epub_migration.py` / `compile_runtime.py`（按 ADJUST：等 Q12 结论后只重跑一次）。按当前台账推算：重跑后 `manifest.unresolved_evidence_count` 应为 **3**（原 42 − 22 陈旧项 − 15 人工复核 − 2 页面换锚后不再引用）；若 D1 回退窗口 5，则为 **25**。此为算术推算，未实测。

### 11.6 Q12 结论：`raw EPUB missing`（源侧缺节，非提取 bug）

**原件已恢复**（此前误判为「用户未提供」）：会话日志（`~/.codex/sessions/2026/09/28–30/*.jsonl`）记录了原件路径，据此从微信文件目录取回，并按新纪律立即落盘：

| 项 | 值 |
|---|---|
| 落盘路径 | `source/蛊真人 -- 蛊真人 -- ( WeLib.org ).epub`（本地，`git check-ignore` → `.gitignore:2:/source/*`，不入库） |
| 大小 | 12,504,156 字节 |
| SHA-256 | `be1c357f7f0131adb2d14be76130614c919cf8eb3364aa673cbf49513160d972` |
| 一致性 | 与 `lore/wiki/source/epub-canonical-build-manifest.json` 的 `epub_sha256` **完全一致**，与取回来源逐字节相同 → 确认这就是提取时的输入原件 |

对原件的直接检查（`zipfile` + OPF/spine/`toc.ncx`/全文检索）：

| 检查 | 结果 |
|---|---|
| spine | `spine#80 = Text/chapter_78.html → 第七十六节：后悔吗`；`spine#81 = Text/chapter_79.html → 第七十八节：不出算计收获丰`。**无第七十七节文件** |
| `toc.ncx` | 目录序列为 …第七十五节 → **第七十六节：后悔吗** → **第七十八节：不出算计收获丰** → 第七十九节…（该卷无第七十七节；`toc` 中 5 处「第七十七节」均属其他卷的重号） |
| 全文检索 | 「幽影虫」**0** 个文件；「刑堂家老没有」0 个文件；「阴差阳错」17 个文件均为正文用词，无一为该节标题 |
| 另一处跳号 | 六段·第六百七十七节同样缺失（`spine#1715` 第六百七十六节 → `spine#1716` 第六百七十八节） |

**结论：`raw EPUB missing`** —— 源 EPUB 本身不含一段·第七十七节，不存在可修的提取缺陷。已按规则接受为 **known source gap**，不换 EPUB 版本、不建 fallback。

页面侧登记：`lore/wiki/events/qing-mao-mountain.md` 与 `lore/wiki/gu/blood-farewell-gu.md`的 `待核对` 各加一条 `[已知源缺口]`，写明该节不在当前 Canon、锚点只保留旧行号回查。

### 11.7 一次性重编译与全链验收

| 命令 | 结果 |
|---|---|
| `python lore/wiki/tools/compile_runtime.py` | 完成；`entities 169 / entity_states 825 / rules 117 / relations 2`；`content_version=59f7e5207dfd26e8…`；`generated_at=2026-09-30T04:50:42Z` |
| 重编译后 runtime 定位表 | 1,997 条 = **1,979 `auto_verified` ＋ 15 `human_approved` ＋ 3 `blocked`**；3 条 `epub_locator` 均为 `null`；`manifest.unresolved_evidence_count = 3`（与 §11.5 推算一致） |
| `node tools/build_data.mjs`（`game/wenzhen-web-lab`） | 重建成功；`js/data.js` 相对重建前**仅 2 行变化**（两处 `contentVersion` 哈希），无其它内容漂移 |
| `pwsh -NoProfile -File lore/wiki/tools/check.ps1`（G1） | `ALL CHECKS PASSED`（check9：21,097 个 E-ID） |
| `node tools/docs-lint.mjs`（G0） | `FAIL 0，WARN 0，编译层孤儿 0` |
| `node --test game/wenzhen-web-lab/tests/canon_pack.test.mjs` | `pass 9 / fail 0` |
| `pwsh -NoProfile -File game/tools/check.ps1`（Godot GUT） | **既有失败：145 failing / 53,125 of 53,400 asserts / 12 orphans / 156s**。失败全部落在 `game/tests/unit/test_wenzhen_card_fsm.gd`、`test_map_topology_v2.gd`、`test_map_anchor_guards.gd`、`test_map_network.gd`、`test_wenzhen_battle_screen.gd` 等地图/战斗/UI 单测，样例失败信息为 `gu moon_shadow_gu v1_effect amount must be a non-negative integer`。**与本次切源无关**：`git grep` 确认 Godot 侧（`game/scripts`、`game/lore_engine`、`game/data`、`project.godot`）不读取 `lore/runtime` 或定位表；本次改动在 `game/` 下只碰了 web lab 的 `js/data.js` 两行哈希。未跑改动前基线（工作区有另一会话的未提交改动，不做 stash），故按「既有失败」登记，对应 open issue #10（v1_battle Godot 迁移）与 #3/#4 |

## 12. 封账（L1 DECISION PACKET：CONTINUE，2026-09-30）

D1 追认（`context_window` 5→12 accepted，只扩大搜索范围、不降低唯一定位判据）；D2 已同步 `CHANGELOG.md` 与 `docs/debt.md`；Godot 145 failing 记为既有失败、不作本次 blocker、不在本轮修。Q12 结论 `raw EPUB missing`，两处源缺口按 known source gap 接受。

**最终状态**：live 6,515 = 6,405 `auto_verified` + 15 `human_approved` + 95 `blocked`；runtime 1,997 = 1,979 + 15 + **3**（`unresolved_evidence_count = 3`，全部对应一段·第七十七节缺节）。未新增 fallback、schema、迁移门禁或长期机制。

本包到此关闭；后续只保留两个**已存在**的未裁决项，不再新增：Q9（`sources:` 是否新增 EPUB 命名空间＝schema 变更）、Q10（`section-index.md` 与 `scripts/compress_full_book.py` 是否改指 EPUB）。口径与数字的权威落点为迁移报告 §11 与 `docs/debt.md`。

## 附录 A：复现命令

```bash
# 1 工作区状态
git -C "C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren" status --porcelain
git -C "C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren" log --oneline -1

# 2 门禁
node tools/docs-lint.mjs
pwsh -NoProfile -File lore/wiki/tools/check.ps1
node --test tests/canon_pack.test.mjs        # 工作目录 game/wenzhen-web-lab

# 3 定位表统计（1,997 / 1,955 / 42 / null=42）
python -c "import json;from collections import Counter;d=json.load(open('lore/runtime/evidence-locators.json',encoding='utf-8'));print(len(d),Counter(v['decision'] for v in d.values()),sum(1 for v in d.values() if not v['epub_locator']))"

# 4 台账 HEAD↔工作区 决策与依据分布
python - <<'PY'
import csv,io,subprocess
from collections import Counter
new={r['eid']:r for r in csv.DictReader(open('lore/wiki/source/eid-migration-decisions.tsv',encoding='utf-8',newline=''),delimiter='\t') if r['scope']=='live'}
old={r['eid']:r for r in csv.DictReader(io.StringIO(subprocess.run(['git','show','HEAD:lore/wiki/source/eid-migration-decisions.tsv'],capture_output=True).stdout.decode('utf-8')),delimiter='\t') if r['scope']=='live'}
print(len(new),Counter(r['decision'] for r in new.values()))
print(Counter(r['migration_basis'] for r in new.values() if r['decision']=='auto_verified'))
print(Counter(r['withheld_reason'] for r in new.values() if r['decision']=='blocked'))
flips=[e for e in old if old[e]['decision']=='blocked' and new[e]['decision']=='auto_verified']
print('flips',len(flips),Counter((old[e]['withheld_reason'],new[e]['migration_basis']) for e in flips))
PY

# 5 83 条翻转的旧行↔EPUB 段落相似度分布（§2.5）
#   解析 EPUB 定位：chapter_NNNN 标记行后第 M 个非空行 = para_%03d
#   旧行：仓库根 蛊真人-clean.txt 第 old_line 行
#   相似度：difflib.SequenceMatcher(None, old.strip(), epub.strip()).ratio()

# 6 pack 状态行与体积
python -c "import json;p=json.load(open('lore/runtime/packs/south_border_rank1_combat.json',encoding='utf-8'));print(sum(len(e.get('states',[])) for e in p['entities']),len(json.dumps(p,ensure_ascii=False,separators=(',',':'))))"
git cat-file -s $(git rev-parse HEAD:lore/runtime/packs/south_border_rank1_combat.json)

# 7 正文站点残留计数
python -c "import io;t=io.open('source/蛊真人-epub-canon.txt',encoding='utf-8').read();print(t.count('未完待续'),t.count('最新章节'),t.count('求票'))"

# 8 runtime 产物与台账是否同步（D5）
python -c "import csv,json;n={r['eid']:r for r in csv.DictReader(open('lore/wiki/source/eid-migration-decisions.tsv',encoding='utf-8',newline=''),delimiter='\t') if r['scope']=='live'};l=json.load(open('lore/runtime/evidence-locators.json',encoding='utf-8'));print(sum(1 for e,v in l.items() if n.get(e,{}).get('decision')!=v['decision']))"
```

## 附录 B：本次改动的 31 个已跟踪文件（便于逐项复核）

`AGENTS.md`、`CHANGELOG.md`、`PROJECT_MAP.md`、`docs/debt.md`、`game/wenzhen-web-lab/js/data.js`、`game/wenzhen-web-lab/tests/canon_pack.test.mjs`、`lore/runtime/README.md`、`lore/runtime/entities.json`、`lore/runtime/manifest.json`、`lore/runtime/packs/rank1_refinement.json`、`lore/runtime/packs/south_border_rank1_combat.json`、`lore/wiki/AGENTS.md`、`lore/wiki/README.md`、`lore/wiki/characters/he-lou-lan.md`、`lore/wiki/events/fate-war.md`、`lore/wiki/events/langya-blessed-land-invasion.md`、`lore/wiki/events/yitian-mountain.md`、`lore/wiki/events/zangmeng-ambush.md`、`lore/wiki/gu/fire-atk-4-02-gu.md`、`lore/wiki/gu/jade-skin-gu.md`、`lore/wiki/gu/stone-shell-gu.md`、`lore/wiki/gu/white-boar-strength-gu.md`、`lore/wiki/gu/white-jade-gu.md`、`lore/wiki/rules/dream-path.md`、`lore/wiki/source/README.md`、`lore/wiki/source/eid-migration-decisions.tsv`、`lore/wiki/source/epub-canonical-build-manifest.json`、`lore/wiki/source/migration-page-coverage.tsv`、`lore/wiki/tools/compile_runtime.py`、`lore/wiki/tools/verify_epub_migration.py`。
