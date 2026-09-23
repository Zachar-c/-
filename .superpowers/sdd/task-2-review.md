# Task 2 评审（提交 223c683）

评审对象：`.superpowers\sdd\task-2-brief.md`（乱码，以 `docs\superpowers\plans\2026-08-09-fulltext-candidate-pipeline.md` Task 2 与 Global Constraints 为准）、`.superpowers\sdd\task-2-report.md`、`.superpowers\sdd\task-2-review-package.txt`。
核对方式：diff 包为 GBK 误渲染，已直读工作区 `scripts/scan_candidates.py`、`tests/test_scan_candidates.py` 实际字节确认内容；`git show 223c683 --stat` 与 `git status --short` 确认提交边界。

## Spec 合规：✅（1 处已裁决的样本偏离，见 Issue M1）

| 需求项 | 结果 |
|---|---|
| `mech_rules`：wordlist（A 级）、mojibake/redact（B 级） | ✅ 与 plan Step 3 逐行一致（scan_candidates.py:65-79） |
| `semantic_rules`：repeat（B 级、≥12 字、相邻行、SequenceMatcher 相似度≥0.8）、num-mix（B 级） | ✅ (scan_candidates.py:87-105) |
| `literary_rules`：author-speak / network-word / scene-repetition（均 C 级） | ✅ (scan_candidates.py:113-146) |
| `scan_rules` 组合三层全部候选 | ✅ (scan_candidates.py:149-150) |
| 循环体首行重算 `section = find_section(lines, i - 1)` | ✅ 三个规则函数均为循环第一条语句 |
| 词表 `from clean_full_source import CONFIRMED_FIXES`，不复制 | ✅ 扫描器内无任何词表字面量（scan_candidates.py:12） |
| 严重度 A/B/C 正确（wordlist=A；mojibake/redact/repeat/num-mix=B；author-speak/network-word/scene-repetition=C） | ✅ |
| 追加 7 个 RuleTests，真断言（assertEqual/assertIn/severity），基于文件内容 | ✅ 全部真断言，无架空断言 |
| Global Constraints：仅改动 2 个沙文件；未碰 AGENTS.md/台账/config/editorial-volumes.json | ✅ `git show 223c683 --stat`：仅 scan_candidates.py + test 文件 |
| 幂等/确定性 | ✅ 无全局可变状态，遍历顺序固定；repeat 用相邻行，scene 用 range(0, n−2) 有限遍历 |
| 用户未提交改动（.gitignore / progress.md / vol3-sec091-120.edited.txt）未混入提交 | ✅ 仍在工作区未 add |
| TDD 红形态与 plan 一致（NameError） | ✅ report 记载暂不导入、7 个 NameError，与 plan Step 2 预期一致 |

**超范围检查**：无。未改写 scan() 行为、未动 serialize_tsv/md、未实现 Task 3 的 `-Apply`（main 仍为 Task 1 解析）。`RE_REDACT` raw 写法与导入 `SequenceMatcher` 均在 plan Tech Stack/Step 3 声明内。

## Issues

### Critical
无。

### Important
无。

### Minor

- **M1（偏离已有裁决，建议 plan 勘误）**：plan Step 2 测试样本 `u'乱码行\xfc。'`（U+00FC）与 plan Step 3 正则 `[\ufffd\uf8ff\ue000-\uf8ff]` 互斥——按 plan 原样必 FAIL（实测断言 0 != 1）。implementer 保留正则（两份文档 Step 3 一致出现，属接口），把测试样本改为 U+FFFD（解码失败标准形态），并以 task-1-review-package 中 18 个 PUA 字符实证正文乱码真实形态。判定：调整合理——正则匹配不了 `\xfc`，若保留 `\xfc` 该测试将永远失败、失去验证意义；U+FFFD 与 PUA 均为实际解码失败形态。建议：在 plan 文档追加一行勘误说明，防止后续任务再照抄原样本。
- **M2（死代码，plan 遗留）**：`CHINESE_NUM` 定义后未使用（semantic 层的 han 正则是内联字符类，不引用该 dict）。plan 原文如此，非实现方引入；无副作用。
- **M3（冗余，plan 遗留）**：字符类 `[\ufffd\uf8ff\ue000-\uf8ff]` 中 `\uf8ff` 已被 `\ue000-\uf8ff` 区间覆盖，冗余但无害。
- **M4（测试脆弱性，非缺陷）**：`test_mechWordlist` 的 `assertEqual(len(w), 1)` 依赖测试行「他躲闪不及，真是淬不及防。」不含词表中其他 6 条（已实测核验），且词表扩容（如新增「躲闪」类条目）会碎。当前绿，属 plan 断言强度本身。
- **M5（覆盖率盲区）**：`test_semanticRepeat` 仅断言 `≥1` 且 severity=B，未断言候选的 `line_source`/`section` 定位正确性（缓释：plan 测试亦如此，非实现偏离）。

## ⚠️ 无法从 diff 验证项

1. 测试全绿声明（12/12、discover 15/15）与 `git diff --check` 通过——仅见 report 自述，按指示未重跑。
2. vol3-151-180 冒烟输出 30 条候选及 `working/candidates-*.tsv/.md` 内容——输出位于 gitignore 目录，diff 不可见。
3. `check_remote_base.py` 通过（origin/main 包含于 HEAD）——agent 流程声明，非本评审范围。
4. `git config core.hooksPath` 是否已配置——环境事项，非本 task 判定依据。

## 总体判定：**Approved**

实现与权威 plan 的 Task 2 逐字一致（含 `range(0, n-2)`、`break`、`_all_scene` 四条件、scene 候选用 `find_section(lines, start)` 等全部细节），severity 分级、词表单一来源、循环内重算 section 均合规；唯一偏离（mojibake 测试样本）证据充分、理由成立，以 Minor 记录并建议 plan 勘误。无超范围改动，无 Critical/重要问题。