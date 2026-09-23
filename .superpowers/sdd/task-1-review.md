# Task 1 Review：scan_candidates.py 骨架（提交 6fb2d6f）

> 审阅基准：plan 文档 `docs/superpowers/plans/2026-08-09-fulltext-candidate-pipeline.md` Task 1 小节 + Global Constraints（brief 文件乱码，按指示以 plan 为准）。diff 文件本身也被控制台 GBK 乱码污染，已直接读仓库内实际文件（`scripts/scan_candidates.py`、`tests/test_scan_candidates.py`）核对。

## Spec 合规：✅（全部达成，无缺失/超范围）

| 核对项 | 结果 |
|---|---|
| 头部两行 `# -*- coding: utf-8 -*-` + docstring | ✅ scan_candidates.py:1-2 |
| `CANDIDATE_FIELDS` 9 字段且顺序一致 | ✅ :13，逐字匹配 |
| `find_section`：从文件头数到该行（含），按标题出现次序计数，1-based，无标题返回 0 | ✅ :17-23，与 plan 代码逐字一致 |
| `build_candidate` 字段顺序 + `seq` 占位 0 + `verdict=''` 缺省 | ✅ :26-29 |
| `serialize_tsv` 非空走 `write_csv_utf8_bom` | ✅ :51（空候选分支为已文档化偏差，见 M-1） |
| `serialize_md` 用 `write_utf8_no_bom` | ✅ :62 |
| `resolve_volume_dir` 读 config/editorial-volumes.json，directoryPattern→正则匹配 volumes/ 目录 | ✅ :65-75；config 实为 `"directoryPattern": "03-*"`，volumes/ 下存在匹配目录 |
| main：PsArgs 规格 `(Volume, Batch, Source, OutDir, Apply)`、缺省 `Source=蛊真人-clean.txt`、`OutDir=working` | ✅ :79-81；PsArgs 对 bool 按开关解析（gu_tools.py:201-204），`-Apply` 语义正确 |
| 词表 `from clean_full_source import CONFIRMED_FIXES`，未复制 | ✅ :11；clean_full_source.py:105 为唯一词表源 |
| 输出 `candidates-<卷>-<范围>.tsv/.md` 到 working | ✅ :98-101 |
| 测试 5 个用例与 plan 一致 + 补 `import csv`（plan 注明"需 import csv"） | ✅ 测试真断言（回读文件内容断言，非只跑不验） |
| 无硬编码 `\\`、路径全 `os.path.join` | ✅ |
| 提交范围：仅本任务两文件（107+60 行 = 167 增） | ✅ |
| 禁改 AGENTS.md/台账/config | ✅ 未触碰 |

### 缺失/超范围
- 无缺失项、无超范围项。两处与 plan 的差异均为 plan 内部矛盾的正确调和，已由 implementer 文档化：
  1. plan 测试 import `scan` 而 plan main 调 `scan_rules` → 实现为 `scan()` 委托 `scan_rules()` 双名并存（Task 2 替换 scan_rules 本体即可，contract 不变）。
  2. plan 注释要求"序列化基于 seq 升序"但 plan 代码未排序 / plan Interfaces 列 `resolve_batch_path` 而 plan 代码在 main 内联（见 M-2）。

## Issues

**Critical：无。**

**Important：无。**

**Minor：**
- **M-1**（scripts/scan_candidates.py:44-50）`serialize_tsv` 空候选分支绕过 `write_csv_utf8_bom`，手写 BOM+表头，与 Global Constraint "TSV 写盘用 write_csv_utf8_bom" 字面不符。理由成立：gu_tools.py:70-74 对 `rows=[]` 只写 BOM 无表头，无法满足 plan Step 5 "TSV 仅表头" 的冒烟预期——plan 自身的前瞻矛盾，此分支输出与 helper 有数据时逐字节等价（utf-8-sig、逗号分隔、newline=''、makedirs），并直接引用 CANDIDATE_FIELDS 无漂移风险。保留建议：Task 2 常态数据走回统一 helper，此分支继续兜底空清单即可。
- **M-2**（scan_candidates.py:89）Interfaces 清单中的 `resolve_batch_path()` 未实现为函数，main 内联 `os.path.join(volume_dir, '{0}-sec{1}.edited.txt'...)`。plan Step 3 的代码本体同样内联（Interfaces 与代码自相矛盾），按"以 plan 代码为准"判为可接受；写下游 Task 5 计划代码也自拼接，无调用方依赖该函数。
- **M-3**（tests/test_scan_candidates.py:50）`io.open(...).read()` 未用 with 关闭，unittest 报 ResourceWarning（来自 plan 给定测试代码，非实现问题）。可后续统一零警告。
- **M-4** `serialize_tsv` 未显式按 `seq` 排序；幂等依赖 scan_rules 输出次序稳定（Task 1 空列表无影响；Task 2 三层规则输出次序确定）。不影响本任务。
- **M-5** 占位性未用项均按 plan 骨架预期：`Source` 参数未消费（Task 2/3 用）、`CONFIRMED_FIXES` import 未使用、`serialize_md` 的 `edit_lines` 参数未用——与 plan 代码一致，非缺陷。
- **M-6** 两文件末尾均无换行符（`\ No newline at end of file`）——无害，报告称 `git diff --check` 通过。

## ⚠️ 无法从 diff 验证
- 测试实际运行结果（报告称 5+8 全绿，含既有 check_remote_base 3 例）——按指示未重跑。
- 冒烟输出内容（报告称 TSV 仅表头、MD 仅首行）；已确认 volumes/ 下存在 vol3 匹配目录（`03-*`），resolve 路径成立。
- rebase 与台账合并结果（控制器职责，报告 §7.2 已附 `git diff origin/main..HEAD -- notes/` 自查手段）。
- working/ 两个冒烟输出未入库（符合"两文件 just commit"约定；`.gitignore` 未含 candidates-*.tsv/.md 为 implementer 已报告的 Concern，需用户授权后另行处理，非本任务职责）。

## 总体判定：Approved

- Spec 合规完整，无缺失/超范围；两处 plan 内部矛盾（scan/scan_rules 双名、空表头）被合理调和并文档化。
- 无 Critical/Important 问题；Minor 均为占位性、无害或计划 ORIGINAL 中的矛盾，可在 Task 2/3 顺带收敛（M-1 保留语义、M-3 补 with）。
- 建议 Task 2 开工时顺手确认 M-4（排序）与 M-6（如要规范化）——均非本任务阻塞项。