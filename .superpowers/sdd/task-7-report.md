# Task 7 报告：脚本收敛

- 日期：2026-08-24
- 基线 HEAD：0ab4c65 → 本次提交：**da6474d** `refactor: 脚本收敛至极简线核心链，一次性工具归档scripts/_archive`
- 结果：10 个一次性工具移入 `scripts/_archive/`（全部 100% rename，SHA256 逐一核对不变），新增 `_archive/README.md`，scripts/ 顶层保留极简线核心链。

## 1. Step 1 核实结论（移动前完成）

### 1.1 确定归档名单（brief 指定，共 10 个文件）

| 文件 | 性质核实 |
| --- | --- |
| add_batch_summary.py | 一次性批摘要补写工具；仅被 validate_editorial_assets.py 的**错误提示文案**提及（非 import/subprocess，见 2.2） |
| create_edited_baseline.py/.ps1 | 初版底稿生成；.py 与 .ps1 为平行实现（ps1 非转发壳） |
| create_volume_baselines.py/.ps1 | 分卷基线生成；.py 内 `import create_edited_baseline`（与被依赖方同批归档，依赖闭合）；ps1 内调用 create_edited_baseline.ps1（同批归档） |
| normalize_source_index.py/.ps1 | 索引归一化（建库期一次性）；平行实现 |
| split_volume_boundary.py/.ps1 | 卷一/卷二边界拆分（一次性，硬编码卷一路径与边界标记）；平行实现 |
| build_index.ps1 | 建库索引重建（keep 的 build_index.py 的 ps1 平行版） |

### 1.2 待核实 .ps1 判定（关键发现）

对 scripts 下全部 10 个 .ps1 读取全文并扫描 python 调用：**0 个文件含任何 python 引用，无一为"纯转发壳"，全部是独立 PowerShell 实现。**

| .ps1 | 行数 | 判定 | 依据 |
| --- | --- | --- | --- |
| gen_brief.ps1 | 311 | **保留** | 完整独立实现简报生成逻辑，未调用 gen_brief.py |
| gen_report.ps1 | 231 | **保留** | 完整独立实现审阅报告逻辑；且内部直接调用 validate_editorial_assets.ps1（L182-186），归档会破坏其验证环节 |
| validate_editorial_assets.ps1 | 253 | **保留** | 完整独立校验实现（UTF-8/结构/边界检查），未调用同名 .py |
| build_epub.ps1 | 437 | **保留** | 完整独立 EPUB 打包实现（中文数字转换、OPF/NCX 生成等） |
| extract_batch.ps1 | 26 | **保留** | 独立 CP936 行区间抽取实现 |

按 brief 判定标准"确认是转发壳才归档；若含独立逻辑则保留并报告"——5 个待核实 .ps1 全部保留。Task 6 review 备注预期它们是转发壳，实测不符（git log 显示 0ab4c65 只改了台账接线内容，未改为转发壳形态）。

### 1.2b 归档 README 文案偏差说明

brief 给定的 README 全文含"ps1 为 py 脚本的转发壳"。按 brief 要求逐字写入，但该表述对本次归档的 5 个 .ps1 不成立（它们是平行实现而非转发壳）。已在上方 1.2 以实测证据纠正，README 未擅改，留待用户裁决是否修订该句。

## 2. 依赖扫描结果（brief Step 1 规定模式）

`Select-String -Path scripts\*.py -Pattern "add_batch_summary|create_edited_baseline|create_volume_baselines|normalize_source_index|split_volume_boundary"` 命中分类：

- **import/subprocess 级依赖：仅 1 处** — `create_volume_baselines.py:13 import create_edited_baseline as baseline`。两者同在确定归档名单，随批一起归档，依赖闭合并整体迁移，无需暂缓。
- **docstring 注释级引用（无运行时影响）**：gu_tools.py L132/L156/L169 提及 create_volume_baselines、build_index、normalize_source_index（行为一致性说明）；create_edited_baseline.py / normalize_source_index.py / split_volume_boundary.py 自述对齐各自 ps1。
- **错误提示文案级引用**：validate_editorial_assets.py L188/L201 缺摘要块时报错文案建议"run scripts/add_batch_summary.py"。非 import/subprocess，按 brief 判据不阻塞归档；归档后该提示路径过时（脚本仍在 _archive 内可恢复）。列为遗留问题 Q2。

tests/ 全目录检索上述名字 + build_index：**零命中** → 无测试用例需移入 `scripts/_archive/tests/`，也无用例需删除（全局约束 tests 条款不触发）。

## 3. Step 2 移动记录

- 新建 `scripts/_archive/README.md`（brief 给定全文逐字写入）。
- `git mv` 10 个文件 → git status 显示 10 条 `R`（100% 相似度）+ `A scripts/_archive/README.md`。
- SHA256 前后比对：**10/10 一致**（如 add_batch_summary.py `8F42B1ED…B6573`、build_index.ps1 `0AB32651…32178` 等，满足"一字不改"约束）。
- 移动后 scripts/ 顶层 = Keep 清单全量在位：12 个核心 .py（clean_full_source / extract_batch / gen_brief / gen_report / water_scan / scan_candidates / audit_candidates / validate_editorial_assets / check_remote_base / build_epub / build_index / gu_tools）+ 5 个保留 .ps1 + `_archive/` + `__pycache__/`。

## 4. Step 3 回归结果

| 命令 | 结果 |
| --- | --- |
| `python -m pytest tests -q` | **35 passed in 8.56s**（与基线持平，pytest 收集不受影响） |
| `py -3 scripts/validate_editorial_assets.py -Phase detail` | `Editorial asset validation passed: phase=detail; volume=vol1`，EXIT=0 |
| `py -3 scripts/gen_brief.py -Volume vol3 -Batch 211-244` | 正常输出 97 行（进度总览/批次定位/细纲表等各节齐全），EXIT=0 |

备注：首次捕获 gen_brief 输出时因管道截断显示 EXIT=-1，去除截断重跑确认为 EXIT=0，属采集侧假象，非脚本故障。（控制台显示的乱码为终端代码页显示问题，文件本身 UTF-8 正常。）

## 5. Step 4 提交

- `py -3 scripts/check_remote_base.py` → "Remote baseline origin/main is included in HEAD." EXIT=0。
- 提交前 `git status --short` 核对：暂存区仅含本任务 11 项改动；`.superpowers/sdd/*` 未跟踪文件与 `progress.md` 改动均**未**混入。
- 提交 da6474d：11 files changed, 5 insertions(+)（即 README 5 行 + 10 条 rename）。

## 6. 偏差与遗留问题

1. **Q1（判定偏差，已按 brief 处理）**：Task 6 review 预期 gen_brief.ps1/gen_report.ps1 是转发壳，实测为独立实现。按 brief"含独立逻辑→保留并报告"保留全部 5 个候选 .ps1。因此本任务实际归档 10 个文件（而非计划文档中列出的 13 个候选）。
2. **Q2（文案过时）**：validate_editorial_assets.py 两处报错文案仍指向 `scripts/add_batch_summary.py`（现已位于 _archive/）。建议后续任务把提示改为 `_archive/add_batch_summary.py` 或删除建议。
3. **Q3（文档过时）**：docs/knowledge-base/01-project-overview.md L37-40 仍以可路径调用的口吻列出 4 个已归档 .ps1；历史 plans 文档中的引用属存档记录不需改。知识库表格建议后续同步。
4. **Q4（README 表述）**：见 1.2b——README"转发壳"一句与本批归档事实不符，未擅改 brief 固定文案。
5. tests/ 条款未触发：无针对被归档脚本的测试用例，无收集错误。

## 7. 自检清单

- [x] Keep 清单 12 个 .py 全部仍在 scripts/ 顶层
- [x] 10 个归档文件 SHA256 移动前后一致（一字不改）
- [x] pytest 收集与结果不受影响（35 passed）
- [x] check_remote_base 通过后才提交；前向提交，无 amend/reset
- [x] 提交暂存只含本任务改动

## Pre-review fix

日期：2026-08-24。code review 前修正本报告遗留问题 Q2 与 Q4，仅改文案，不动任何校验逻辑、退出码或检查项。

### 变更明细

1. **Q4 → `scripts/_archive/README.md:4`**：删除与归档事实不符的句子「ps1 为 py 脚本的转发壳，随 py 版一并归档。」（1.2 节已核实 0 个 .ps1 是转发壳，且本次归档不含任何 .ps1）。README 其余四行保持不变。
2. **Q2 → `scripts/validate_editorial_assets.py:188`**：缺摘要块报错文案删去过时提示「; run scripts/add_batch_summary.py」，保留「missing summary block (## 本批主线 / ## 关联冻结裁决)」主体。
3. **Q2 → `scripts/validate_editorial_assets.py:201`**：同上，删去「; run scripts/add_batch_summary.py」，保留「missing summary block」主体。两处均为纯字符串修改（add_batch_summary.py 已在 `_archive/`，不再作可运行建议）。

### 验证

| 命令 | 结果 |
| --- | --- |
| `python -m pytest tests -q -k "validate or editorial"` | 0 selected（35 deselected in 0.05s）——tests/ 中无文件名/用例名含 validate 或 editorial 的用例，实际覆盖由全量套件承担 |
| `python -m pytest tests -q` | **35 passed in 8.81s** |
| `python -m py_compile scripts/validate_editorial_assets.py` | 编译通过 |

### 提交

- `py -3 scripts/check_remote_base.py` → 通过后才提交；前向提交，无 amend。
- 暂存区仅含：`scripts/_archive/README.md`、`scripts/validate_editorial_assets.py`、`.superpowers/sdd/task-7-report.md`；其余未跟踪的 `.superpowers/sdd/*` 与 `progress.md` 改动不混入。

Q2、Q4 就此关闭；Q1、Q3 维持原状待后续任务处理。
