# Task 1 Report：scan_candidates.py 骨架

- 实现日期：2026-08-09
- 提交：`6fb2d6f` 「feat: 候选扫描管线骨架（数据结构/节号定位/TSV+MD输出/卷目录解析）」
- 涉及文件（仅提交这两个）：`scripts/scan_candidates.py`（新增，107 行）、`tests/test_scan_candidates.py`（新增，60 行）

## 1. 实现摘要

按 Task 1 brief（及同源 plan 文档）落地骨架：

- 数据结构：`CANDIDATE_FIELDS = ['seq','type','severity','section','line_source','line_edit','sample','rule','verdict']`；`build_candidate(...)` 返回字段顺序一致、`seq` 占位 0 的 dict。
- 节号定位：`find_section(lines, line_index)` 自文件头数到该行，匹配 `RE_SECTION_HEAD`（`^\s*第\s*[一二三四五六七八九十百千0-9]+\s*节\s*[:：]?\s*\S`，兼容"第 一 节"带空格与"第一百五十一节："中文数字标题）。
- 输出：`serialize_tsv`（空候选时也写出表头，见自审发现 1）、`serialize_md`（`verdict` 字段透出，人工会话填写）。
- 卷目录解析：`resolve_volume_dir` 读 `config/editorial-volumes.json`，将 `directoryPattern`（如 `03-*`）转正则匹配 `volumes/` 下真实目录。
- `main()`：`PsArgs` 规格 `(Volume, Batch, Source, OutDir, Apply)`，缺省 `Source=蛊真人-clean.txt`、`OutDir=working`；为空规则占位阶段产 `candidates-<卷>-<范围>.tsv/.md`。
- 词表唯一来源 `from clean_full_source import CONFIRMED_FIXES`，本任务未复制进扫描器（Task 2 使用）。

与 brief 代码的差异（均为需求内部不一致的调和）：

1. brief 的 main 代码调用 `scan_rules(edit_lines)`，而测试文件 `from scan_candidates import ... scan`。为同时满足测试导入与 brief 的 main 语义，实现为：`scan(lines)` 为对外入口（委托 `scan_rules`），`scan_rules` 保留为 Task 2 的规则占位。二者皆可用，Task 2 替换 `scan_rules` 本体即可。
2. brief 的 `test_serializeMdContainsContext`/`test_serializeRoundTripCsv` 需 `import csv`（brief 第 86 行注明"需 import csv"），已加入。
3. Task 1 空候选时 `write_csv_utf8_bom` 对空行表（rows=[]）只会写出 BOM、无任何内容；为满足冒烟"TSV 仅表头"（仅表头、无数据行），`serialize_tsv` 空候选时直接写 BOM+表头行。Task 2 有候选时仍走 `write_csv_utf8_bom`。

编码：控制台使用 GBK 显示乱码不影响；文件均为 UTF-8，测试/实现用 `io.open(..., encoding='utf-8-sig')` 读写（源文件无 BOM 也能正确读）。brief 文件本身含 PUA/乱码字符，不可直接拷贝；字符串以 plan 文档（`docs/superpowers/plans/2026-08-09-fulltext-candidate-pipeline.md`）中的干净文本为准复原。

## 2. 测试输出（全部通过后）

首次失败（TDD 红）：

```
ImportError: Failed to import test module: test_scan_candidates
ModuleNotFoundError: No module named 'scan_candidates'
```

实现后单批：

```
test_buildCandidateFields ... ok
test_findSectionCountsFromHead ... ok
test_findSectionMatchesChineseNumeralHead ... ok
test_serializeMdContainsContext ... ok（unittest 列出 ResourceWarning，非失败）
test_serializeRoundTripCsv ... ok
Ran 5 tests in 0.045s  OK
```

全量回归（含既有 check_remote_base 3 用例）：

```
Ran 8 tests in 4.976s  OK
```

`git diff --check`：通过（exit 0）。

## 3. 冒烟输出（Step 5）

```
py -3 scripts/scan_candidates.py -Volume vol3 -Batch 151-180
output: C:\Users\90877\work_space\gu-zhenren\working\candidates-vol3-151-180.tsv
output: C:\Users\90877\work_space\gu-zhenren\working\candidates-vol3-151-180.md
```

- TSV 内容：仅表头 `seq,type,severity,section,line_source,line_edit,sample,rule,verdict`（无数据行）✓
- MD 内容：仅首行 `# 候选清单（机器生成；verdict 由会话填写）` ✓
- 两文件均未 `git add`（保持 untracked）。

## 4. 提交前的流程异常与处理（现场实录）

1. `check_remote_base.py` 首次失败：`HEAD does not include origin/main`。`origin/main` 在审阅期间推进了 3 个提交（R2 001-030 第三卷、181-206 与 151-180 第二卷）。
2. 按 AGENTS.md §12.2：先保护未提交改动 → `git stash push` 用户对 `vol3-sec091-120.edited.txt` 的改动 → `git rebase origin/main`。
3. Rebase 在 `notes/batch-report.md` 冲突（本地被重放提交 63c1a0a 的 vol3-061-090 批报 vs 新基线上 vol2-151-180 批报）。判定：batch-report 是"每批覆盖式"生成物，重放提交应保留其自身批次内容 → 取 `--theirs`（63c1a0a 版本），`rebase --continue` 完成（用 `GIT_EDITOR=true` 免交互）。
4. `git stash pop` 恢复用户改动（diff 无变化），重跑 `check_remote_base.py`：通过（origin/main 已含于新 HEAD）。
5. 重跑 5+8 测试，全绿后提交。提交仅含本任务两文件；用户改动与 working/ 输出未混入。

## 5. 提交哈希

- `6fb2d6f  feat: 候选扫描管线骨架（数据结构/节号定位/TSV+MD输出/卷目录解析）`（2 files changed, 167 insertions）

## 6. 自审发现（self-review）

- brief 文件加载为乱码（写盘时被 GBK/PUA 破坏），动手前无法原样执行；已按 plan 文档清洗为 UTF-8 正文，实现与测试字符串均以 plan 为准。报告此差异以便用户核对。
- `serialize_tsv` 的空候选分支会写 BOM+表头行；注意 SDK 的 `write_csv_utf8_bom` 在有数据时行为不变，Task 2 之后常态走原路径。
- `scan` / `scan_rules` 双名并存：Task 2 若按计划"替换 `scan_rules` 占位"，无需动测试导入；若后续在 main 中改用 `scan_rules` 亦无碍。
- `notes/batch-report.md` 在 rebase 中被重放提交改写为 vol3-061-090 批次内容（与本地 commit 一致）；对远端已提交的 batch-report 内容没有覆盖判据，若用户期望"报告只到最新批次"需下次批次提交覆盖。

## 7. Concerns

1. .gitignore 尚不含 `working/candidates-*.tsv/.md` 和 `working/apply-*.log`（`.log` 已全局忽略，TSV/MD 未忽略）。本任务未将其加入（AGENTS.md 禁止修改 .gitignore 以外的清单，且未获授权）；后续 Task 每次冒烟都会把这两个文件留在 untracked，建议某任务顺带收敛（需用户授权改 .gitignore）。
2. rebase 处理 batch-report.md 冲突时取了本地批次的版本；`notes/` 内容良多 had HE structural-surgery 等随旧提交一起移动，未逐条比对远端台账内容（rebase 自动合并成功、无其他冲突）。若下游会话需要核对台账合并结果，可用 `git diff origin/main..HEAD -- notes/`。
3. 一条 ResourceWarning（测试中 `io.open().read()` 未 close）来自既有 brief 给定的测试代码，非实现问题；如需零警告可后续统一改为 `with` 块。