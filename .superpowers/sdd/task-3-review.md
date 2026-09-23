# Task 3 Review：`-Apply` 词表自动应用 + 留痕 + 幂等（提交 2483df6）

> 依据：`docs/superpowers/plans/2026-08-09-fulltext-candidate-pipeline.md` Task 3 小节（brief 与 diff 均为 GBK 解读乱码，以 plan 为准）。报告文件 task-3-report.md 不存在，冒烟执行情况无法核实。

## A. Spec 合规判定：✅（附 2 项违反全局约束的行为，见 Important）

- `apply_wordlist(text, pairs) -> (new_text, applied, skipped)`：签名、返回三元组 ✓
- applied = `(old, new)` 元组列表；skipped = old 字符串列表（与测试断言、`old|SKIP|…` log 行一致）✓
- 引号内跳过：`_in_quote` 成对引号计数版已实现（对 plan 原始相邻判定版的修正）✓
- main `-Apply` 分支：读 .edited.txt（utf-8-sig）→ 应用词表（CONFIRMED_FIXES 单一来源，import 自 clean_full_source，未复制）→ **有替换才写回**（utf-8-sig, newline=''）✓ → log 用 write_utf8_no_bom、行格式 `old|new|次数` 与 `old|SKIP|引号语境保人工` ✓；位置在 tsv/md 输出前 ✓；不更新候选 verdict ✓（与 plan 附注一致）
- 幂等：第二次运行 old 已不存在 → applied 为空 → 不写回、不改内容 ✓（测试 3/4 覆盖）
- 新开关缺省不启用、旧调用零变化：置于 `if args.get('Apply')` ✓

## B. 代码质量

### Critical

无。

### Important

- **I1｜`_in_quote` 按「首次出现」定夺全词，`replace` 却全局替换**（scan_candidates.py:153-166, 174, 176）：token 同时出现在引号外与引号内时——首次出现在引号外 → 引号内的该词也被替换（安全网失效）；首次出现在引号内 → 整词跳过，引号外的同词漏改。词表为全书记录级，测试 2 只覆盖「唯一出现即在引号内」的简单情形。建议改为逐 occurrence 判断，或至少补混合语境用例并把语义写进 docstring。

- **I2｜`-Apply` 读侧未用 `newline=''`，写侧固定 utf-8-sig → 破坏「仅词表替换」约束**（scan_candidates.py:213, 217）：读入时通用换行翻译会把 `\r\n→\n`，一旦有替换写回，整批正文 CRLF→LF；写侧 utf-8-sig 恒加 BOM，原无 BOM 文件（试点 vol3-151-180 即无 BOM）被追加 BOM。现驻 12 个抽样批次全部 CRLF、部分有 BOM——真实批次只要命中一个词即触发整文件行尾/BOM 变更，与全局约束 16「唯一自动写正文路径…仅词表替换」及「同输入两次运行逐字节一致」不符。该缺陷源自 plan 片段本身（plan 原样如此），实现忠实照做，但仍须修正：读侧加 `newline=''`，并按源文件 BOM 有无选择编码（或先读 BOM 再定 write encoding）。

- **I3｜写回路径零测试兜底**：测试仅覆盖 `apply_wordlist` 纯函数；`main` 的 -Apply 写回、log 格式、BOM/newline 行为均无 CLI/集成断言。冒烟步骤（plan Step 4）只验证 0 计数分支——试点批实测 7 条词表旧词数量均为 0，不触发写回，I2 的副作用在冒烟中被绕过；「临时造词文件验证替换生效」也只会断言内容，不会断言文件字节级其它差异。建议补一个 `-Apply` 集成用例（temp 副本 + 断言逐字节/行尾/BOM 不变）。

### Minor

- **M1｜skipped 契约表述不一致**：plan Task 3 Interfaces：skipped 为 `(old, new)` 元组；测试与实现为 old 字符串列表。实现与测试、log 相容，只需修正 Interfaces 行文字。
- **M2｜log 文件名歧义**：全局约束 16 写 `apply-a-<卷>-<范围>.log`，Task 3 内文与实现为 `apply-<卷>-<范围>.log`（scan_candidates.py:219），同 plan 内部冲突；需用户定夺既定文件名为准。
- **M3｜计数语义**：`new_raw.count(new)` 统计的是新词在全文的频次，不是本次替换次数；若文中原本就有 `猝不及防` 等新词会多计。与 plan 片段一致，仍建议改按替换发生次数统计（或文档注明口径）。
- **M4｜级联替换无防护**：若某对 new 包含另一对 old（词表扩展时），后序 pair 会把前序产物二次替换。现 7 个 CONFIRMED_FIXES 相互无包含关系，当前不触发；属未来风险，建议在注释或在 apply 前做重叠断言。
- **M5｜未配对引号漏判**：仅存前引号（如残半引号文本）时 `closes=0`→判为引号外→被替换。与修版「成对引号」语义一致，但本语料残半引号场景现实存在，需确认这是接受的 tradeoff（仅在 docstring 已声明「成对」，未在接口层说明）。

### ⚠️ 无法从 diff 验证

1. 单元测试实际全绿（本 diff 只含 4 新用例代码；预计兼容既有测试）；`git diff --check` 结果。
2. 冒烟步骤实执行（report 不存在）：temp 副本 -Apply log 为 0、造词文件替换生效；试点文件全词通查为 0 词条命中（已核实）。
3. 试点批 vol3-151-180 本身 LF+无 BOM，可逃生 I2 的隐患，全库其余批为 CRLF——真实一触即发。
4. commit message 中文为 GBK 乱码，提交信息无法核对内容。

### 修版项归纳

- _in_quote 修正版对「成对引号」计数本身正确：left 净开 >0 且 right 净闭 >0 才判在内，每对引号分别判定；嵌套（“『…』”）边界情形处理合理；find 查不到时 False。
- 二次替换链（pair A 产物生成 pair B 的 old）：现词表不存在；代码无防护（M4）。

## 总体判定：**Approved（附建议）** —— 不阻塞合入，但 I2（newline/BOM）与 I3（零 CLI 覆盖）建议在 Task 4 前置补丁处理；I1 混合引语境建议补测试并明确语义。

---

## REREVIEW（提交 fab95ce，相对 2483df6）

> 复核依据：直接以 git 检出的 fab95ce 实际源码与测试（r-package diff 系 GBK 解读乱码，未采用其文字内容）。未重跑测试（已全绿 21 用例）。

### I1 状态：**已关闭** ✅

`_in_quote_at(text, idx, token_len)` + `apply_wordlist` 逐处 buf/pos 拼接（scan_candidates.py:153-192）经边界推演成立：

- **token 在引号内**：left 净开 >0 且 right 净闭 >0 → 跳过。混引测试首处（`“淬不及防。”`内）走此分支 ✓
- **token 在引号外、句中有成对引号**：如 `“A。”B淬` → left 净开 =0 → finds False → 替换 ✓（test_applyMixed 的裸词处即此分支）
- **token 在引号外、句中有未配对引号**：left 净开>0 但 right 净闭 count=0 → 判引号外 → 替换。沿用「成对引号」语义（原 M5 tradeoff，docstring:154 已声明）
- 混引/裸词测试为真断言：`len(applied)==1`、引号内原词保留字面断言、引号外替换断言、`len(skipped)>=1`，全部针对文件内容而非空转。
- **buf/pos 循环正确性**：`text.find(old, pos)` 全程在**未变的原始 text** 上扫描（text 仅在 join 后重赋），pos 前进量用 `len(old)`（而非 len(new)），输出累积到 buf——替换长短不均（new 含 old 或变长）时索引不错位，且**同 pair 内无二次替换**（产物不重扫），与 `str.replace` 的费重叠语义一致（`'aaa'→new+'a'`）。
- 遗留细微点（Minor）：①单引号对 `‘ ’` 代码覆盖但无测试用例；②逐处 append 使 skipped 可含同一旧词多条目（log 逐出现处输出 SKIP 行），与原「每词一条」语义不同，docstring 未说明；③`goto` 前 old 不在 text 时 early-continue、循环内再 find，逻辑冗余但无害。

### I2 状态：**部分关闭** —— CRLF 已修，BOM 半未修（升格为遗留 Important）

- **CRLF 半** ✅：读/写两侧 `newline=''`（scan_candidates.py:197,201），raw 原样往返；测试断言 `blob.count(b'\r\n')==2` 为真断言。驱动诊断。
- **BOM 半 ✗**：`utf-8-sig` 写侧对**原本无 BOM 的文件会追加 BOM**，I2 原诊断「原无 BOM 文件被追加 BOM」未消除——修复只保证「有 BOM → 有 BOM」。实测全库 24 份 .edited.txt：仅 **3 份有 BOM，21 份无 BOM**（vol1-sec001-120 等），首次 -Apply 命中任一词即给无 BOM 批次整体添加 BOM，仍违反「仅词表替换」字节级约束。测试 `test_applyToFilePreservesCrlfAndBom` 恰好只覆盖有 BOM→有 BOM 的方向，把该半边缺陷掩盖了。修正：先按字节探测 BOM（或 `read(raw bytes).startswith(BOM)`），写侧据此选择 `utf-8-sig`/`utf-8`；补一个无 BOM 文件的往返断言。

### I3 状态：**已关闭**（写回路径获得真集成测试）✅

`apply_to_file` 成为写回唯一入口（main:237 改调用它），`test_applyToFilePreservesCrlfAndBom` 实测 读-替换-写回 全程，断言 applied、BOM 前缀、CRLF 计数、替换字节——非虚断言。log 生成与 main CLI 分支仍无断言（原为 I3 的 Minor 部分），且 `new_raw` 重复读档计数可接受。log 计数沿用旧 M3 语义（`count(new)` 为全文频次非本次次数），维持 Minor 待处理。

### 遗留/新发现问题

| 级别 | 项 | 说明 |
|---|---|---|
| **Important** | **I2-BOM 遗留** | 21/24 真实批次无 BOM，-Apply 首次命中词即追加 BOM；BOM-less 往返无测试覆盖（现有测试只覆盖有 BOM 方向） |
| Minor | M5 单引号对无测试 | `‘ ’` 分支无用例（代码已覆盖两对） |
| Minor | skipped 词条复现 | 逐处追加使同一 token 可出现多条；log 逐词输出 SKIP 行，语义与旧版「每词一条」不同，docstring 未说明 |
| Minor | M2/M3/M4 未变 | log 文件名 apply-*/apply-a-* 不一致、计数口径、跨 pair 级联（同 pair 内级联已被 buf 扫描消除，优于原实现） |

### 复核判定：**Needs Fixes**

I1、I3 及 I2 的 CRLF 半边已扎实关闭，代码质量较优；但 I2 的 BOM 半边是该 Important 的原组成之一，且对真实仓（21/24 无 BOM）一触即发，现有测试恰好只覆盖了不触发的方向——必须补「无 BOM 文件往返不加 BOM」的探测/编码选择 + 反向测试后重新审阅。修完即复批。

---

## REREVIEW-2（提交 eb81cae，修订 I2-BOM 遗留）

> 复核依据：rereview2-package 的 diff（内容含 GBK 解读乱码，仅结构可用）。未重跑测试（已全绿 22 用例）。

### I2 状态：**已关闭** ✅（BOM 半边）

- **探测**：`rb` 读入 `codecs.BOM_UTF8`（b'\xef\xbb\xbf'）前缀检测，`has_bom` 判定成立。
- **编解码配对**：有 BOM → `decode('utf-8-sig')` 脱 BOM，写侧 `encode('utf-8')` 后手动再前置 BOM——往返逐字节等价；无 BOM → `decode('utf-8')∖encode('utf-8')`，不加回 BOM——I2 原缺陷（21/24 无 BOM 批次被追加 BOM）消除。无 BOM 文件含非法序列时 `decode('utf-8')` 直接抛错、不写回，与原 utf-8-sig 读侧失败模式一致，无回归。
- **换行**：读/写均二进制模式，CRLF/LF 原样往返，上批 CRLF 修复不被破坏。
- **仅 applied 非空才写**：无替换时零写击，逐字节一致性保持。

### 测试 `test_applyToFileKeepsNoBomFileBomless` 评估

- 输入：`encoding='utf-8'` + `newline=''` 写入 → 无 BOM、LF 行尾 ✓
- `len(applied)==1` + `assertIn(替换词.encode, blob)`：替换真实生效 ✓
- `assertFalse(blob.startswith(b'\xef\xbb\xbf'))`：无 BOM 保持为真断言 ✓
- **Minor（断言强度）**：`blob.count(b'\n')==2` 无法区分 LF 与 CRLF（CRLF 中每个 '\n' 也计入），若写侧混入文本模式转换 `\n→\r\n` 该断言仍会通过；本实现为二进制往返不会触发，仅建议改为 `assertNotIn(b'\r\n', blob)` 以求判别力（可选，不阻塞）。

### 回归检查

- diff 仅触及 `apply_to_file` 主体与新增 `import codecs`，函数签名/返回值不变，`main` 调用方与既有 CRLF+BOM 测试路径不受影响；`write_utf8_no_bom`/`write_csv_utf8_bom` 的 log/tsv 写侧未动，无双模式混用。
- 既有 `test_applyToFilePreservesCrlfAndBom`（有 BOM 方向）逻辑与新实现依然相容：utf-8-sig 写入 → 检测到 BOM → decode 剥离 → encode 加回。✓

### 新问题

| 级别 | 项 | 说明 |
|---|---|---|
| Minor | LF 断言弱 | `count(b'\n')==2` 不能区分 `\n` 与 `\r\n`；建议 `assertNotIn(b'\r\n', blob)`（本次代换不触发，非阻塞） |

### 复核判定：**Closed**

I2 两项组成（CRLF、BOM 双向保持）均已落实，转折点满足上一轮复批要求（无 BOM 文件往返不加 BOM + 反向测试）；实现为干净字节级往返，无模式混用回归。仅剩 Minor 断言强度备注。无需再次复批。