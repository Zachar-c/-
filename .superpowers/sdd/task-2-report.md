# Task 2 报告：A/B/C 三层规则引擎

## 状态：DONE_WITH_CONCERNS（详见"自审发现"第 1 条）

## 实现摘要

在 `scripts/scan_candidates.py` 中实现三层规则引擎，替换 Task 1 的 `scan_rules` 空占位：

| 层 | 函数 | 规则 | 级别 |
|---|---|---|---|
| A 机械层 | `mech_rules(lines)` | `wordlist`（遍历 `clean_full_source.CONFIRMED_FIXES`，禁止复制词表） | A |
| | | `mojibake`（U+FFFD / U+F8FF / PUA E000–F8FF） | B |
| | | `redact`（`[***]` / `**`） | B |
| B 语义层 | `semantic_rules(lines)` | `repeat`（相邻两行 ≥12 字、difflib 相似度 ≥0.8） | B |
| | | `num-mix`（中文数字与阿拉伯数字+单位词混用） | B |
| C 文学层 | `literary_rules(lines)` | `author-speak`（`re.match` 检查 stripped 文本前的作者越位词） | C |
| | | `network-word`（网络词表 9 词） | C |
| | | `scene-repetition`（`_all_scene` 启发式，首段命中即 break） | C |
| 组合 | `scan_rules(lines)` | `mech_rules + semantic_rules + literary_rules` | — |

实现要点（对应需求）：
- 词表唯一来源 `from clean_full_source import CONFIRMED_FIXES`，未复制。
- 所有规则函数循环体首行重算 `section = find_section(lines, i - 1)`，无循环外共享 section 变量。
- `_all_scene(chunk)`：≤4 行块中每行含 `RE_SCENE_SENT` 句末标点、无引号/冒号、场景词（SCENE_VOCAB）≥2 个，全部满足才候选；`literary_rules` 中 `for start in range(0, n - 2)` 遍历并在第一段命中后 `break`。
- 新增 `from difflib import SequenceMatcher` 导入（plan Tech Stack 已声明 difflib）。
- `RE_REDACT` 用 raw string 写法（语义与 plan 字面等价，消除 Python 3.12 SyntaxWarning）。

## TDD 过程

1. **红**：追加 `RuleTests`（7 用例，仅引用 `mech_rules/semantic_rules/literary_rules`，暂不导入）→ `py -3 -m unittest tests.test_scan_candidates -v` 输出 7 个 `NameError: name 'xxx_rules' is not defined`（ERROR），既有 5 用例 OK —— 符合 brief 预期失败形态。
2. **绿**：实现三层规则 + 补充测试文件导入（`scan_rules, mech_rules, semantic_rules, literary_rules`）→ 12/12 OK。
3. **回归**：`py -3 -m unittest discover -s tests -v` → 15/15 OK（含既有 3 个 check_remote_base 用例，无回归）。
4. **冒烟**：`py -3 scripts/scan_candidates.py -Volume vol3 -Batch 151-180` → 输出 `working/candidates-vol3-151-180.tsv`（30 条候选，redact 为主）与 `.md`；该目录已被用户 .gitignore 覆盖，未入库。
5. `git diff --check` → 无输出（通过）。
6. `py -3 scripts/check_remote_base.py` → 通过（origin/main 已包含于 HEAD），按 AGENTS.md 12.2 在提交前执行。

## 测试输出（最终）

```
Ran 12 tests in 0.015s  —  OK   （tests.test_scan_candidates：5 ScanBone + 7 RuleTests）
Ran 15 tests in 4.884s  —  OK   （discover -s tests：新增 7 + 既有 8，无回归）
```

## 提交

- `223c683` feat: A/B/C 三层规则引擎（词表/乱码遮蔽/重复/数字混用/作者越位/网络词/场景复写）
- `2 files changed, 146 insertions(+), 8 deletions(-)`，仅 `scripts/scan_candidates.py` 与 `tests/test_scan_candidates.py`；用户未提交的 `.gitignore`、`progress.md`、`vol3-sec091-120.edited.txt` 及其余文件均未 add/改动。

## 自审发现

1. **plan/brief 内部矛盾（已裁决）**：mojibake 用例样本为 `u'乱码行\xfc。'`（U+00FC ü），而 demand 正则 `[\ufffd\uf8ff\ue000-\uf8ff]` 不含 U+00FC，按文档直抄必 FAIL（实测 `0 != 1`）。依据：正则作为接口代码在两份文档 Step 3 一致重复出现，测试样本仅出现一次，且正文乱码实测形态为 PUA 字符（vol3 全量 .edited.txt 已清洗，无 ü/FFFD 残留；`task-1-review-package.txt` 含 18 个 PUA，印证 E000–F8FF 是真实目标）。处置：保留 plan 正则字面，将测试样本改为 `\ufffd`（U+FFFD 替换符，解码失败乱码的标准形态）。已验：`test_mechRedactAndMojibake` 绿。
2. **SyntaxWarning 消除**：plan 字面 `u'\[\*\*\*\]|\*\*'` 在 Python 3.12 触发 invalid-escape 警告；改 raw string 语义完全等价。
3. **`new` 变量未用**：`mech_rules` 中 `for old, new in CONFIRMED_FIXES` 的 `new` 未使用——plan 原文即如此（候选只记 old 命中），保留字面，不做多余发挥。
4. **既有 ResourceWarning**：`test_serializeMdContainsContext` 中 `io.open(...).read()` 未关闭，为 Task 1 既有代码，非本任务范围，未改动。
5. **`_all_scene` 全绿验证**：scene 用例 4 句场景句 + 空行，`range(0, n-2)` 在 `start=1` 命中并 break，与需求"找到第一段后 break"一致；`第 12 节：应试` 因无句末标点被正确排除。