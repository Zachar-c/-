# 全书候选扫描 + 会话驱动分层自动化管线 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立「代码全书扫描 → 候选清单 → LLM 会话逐条决策 → 直接编辑正文 → 全量人工待检」的分层自动化管线，并用 vol3-151-180 试点验证。

**Architecture:** 纯规则（正则+词表+启发式，无模型）扫描器 `scripts/scan_candidates.py` 产出 A/B/C 三级候选（TSV+MD 双格式）；A 级词表 `-Apply` 模式自动应用并留痕；`scripts/audit_candidates.py` 生成人工待检表与误差统计；gen_brief/gen_report 注入候选小节。试点批次 vol3-151-180（当前为基线未精编，2828 行）。

**Tech Stack:** Python 3（py -3）、unittest、gu_tools（PsArgs/repo_abs/编码工具）、clean_full_source（CONFIRMED_FIXES 词表单一来源）、difflib 相似度。

## Global Constraints

- 新脚本在 `scripts/` 下，头两行 `# -*- coding: utf-8 -*-` + docstring，与现有脚本一致。
- 词表唯一来源：`from clean_full_source import CONFIRMED_FIXES`，禁止在扫描器内复制词表。
- TSV 写盘用 `gu_tools.write_csv_utf8_bom`（BOM+逗号分隔）；MD 用 `gu_tools.write_utf8_no_bom`。
- 扫描器只读源文与台账；唯一自动写正文路径是 `-Apply`（仅词表替换），一律写 `working/apply-a-<卷>-<范围>.log` 留痕。
- 幂等：同输入两次运行逐字节一致；`-Apply` 对已应用项不重复计数。
- 参数一律 PsArgs；新开关缺省不启用，旧调用行为零变化。
- 路径用 `os.path.join`，禁止硬编码 `\\`。
- 禁止修改 AGENTS.md、台账、config/editorial-volumes.json。
- 每任务独立 commit；任务完成跑 `py -3 -m unittest tests.test_scan_candidates -v` + `git diff --check` 全绿再提交。
- 控制台乱码不影响文件内容；测试断言基于文件内容。

---

### Task 1: scan_candidates.py 骨架（数据结构 / 节号定位 / TSV+MD 输出 / main 入口解析卷目录）

**Files:**
- Create: `scripts/scan_candidates.py`
- Test: `tests/test_scan_candidates.py`

**Interfaces:**
- Consumes: `gu_tools.PsArgs` / `repo_abs` / `write_csv_utf8_bom` / `write_utf8_no_bom`；`clean_full_source.CONFIRMED_FIXES`；`config/editorial-volumes.json`
- Produces:
  - `CANDIDATE_FIELDS = ['seq', 'type', 'severity', 'section', 'line_source', 'line_edit', 'sample', 'rule', 'verdict']`
  - `find_section(lines, line_index) -> int`
  - `build_candidate(type_, severity, section, line_source, line_edit, sample, rule, verdict='') -> dict`
  - `resolve_volume_dir(volume_id) -> str`（从 config 的 directoryPattern 匹配 volumes/ 下目录）
  - `resolve_batch_path(volume_dir, volume_id, batch) -> str`（拼接 `<vol>-sec<range>.edited.txt`）
  - `serialize_tsv(candidates, path)`、`serialize_md(candidates, edit_lines, path)`
  - `main()`：PsArgs 规格 `(Volume, Batch, Source, OutDir, Apply)`；读批次 .edited.txt 与净版源文对应区段，调用 `scan()`（本任务为空规则占位），输出 `working/candidates-<卷>-<范围>.tsv/.md`

- [ ] **Step 1: 写失败测试**

`tests/test_scan_candidates.py`：

```python
# -*- coding: utf-8 -*-
import io
import os
import shutil
import sys
import tempfile
import unittest

SCRIPTS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'scripts')
sys.path.insert(0, SCRIPTS_DIR)

from scan_candidates import (CANDIDATE_FIELDS, find_section, build_candidate,
                             serialize_tsv, serialize_md, scan)


class ScanBoneTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def test_buildCandidateFields(self):
        c = build_candidate('mech', 'A', 3, 10, 10, u'淬不及防', 'wordlist', '')
        self.assertEqual(list(c.keys()), CANDIDATE_FIELDS)

    def test_findSectionCountsFromHead(self):
        lines = [u'第 一 节 ： 纵 身 亡', u'正文一', u'第 二 节 ： 逆 光 阴', u'正文二', u'', u'正文三']
        self.assertEqual(find_section(lines, 0), 1)
        self.assertEqual(find_section(lines, 3), 2)
        self.assertEqual(find_section(lines, 5), 2)
        self.assertEqual(find_section([u'没有标题'], 0), 0)

    def test_serializeRoundTripCsv(self):
        cands = [build_candidate('semantic', 'B', 1, 4, 4, u'重复句', 'repeat', u'相似度0.8')]
        path = os.path.join(self.tmp, 'candidates.tsv')
        serialize_tsv(cands, path)
        with io.open(path, 'r', encoding='utf-8-sig') as fh:
            rows = list(csv.DictReader(fh))
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['rule'], 'repeat')
        self.assertEqual(rows[0]['severity'], 'B')

    def test_serializeMdContainsContext(self):
        lines = [u'第 1 节', u'你好', u'你坏']
        cands = [build_candidate('literary', 'C', 1, 2, 2, u'你好', 'author-speak', '')]
        path = os.path.join(self.tmp, 'candidates.md')
        serialize_md(cands, lines, path)
        txt = io.open(path, 'r', encoding='utf-8').read()
        self.assertIn(u'你好', txt)
        self.assertIn(u'author-speak', txt)

    def test_findSectionMatchesChineseNumeralHead(self):
        lines = [u'第一百五十一节：竟是蛊仙传承', u'砰！', u'黑楼兰一脚踢翻黑旗胜。']
        self.assertEqual(find_section(lines, 1), 1)
```

（需 `import csv`。序列化基于 `seq` 升序以保持 TSV 幂等可复现。）

- [ ] **Step 2: 跑测试确认失败**

Run: `py -3 -m unittest tests.test_scan_candidates -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'scan_candidates'`

- [ ] **Step 3: 写骨架实现**

`scripts/scan_candidates.py`：

```python
# -*- coding: utf-8 -*-
"""全书候选扫描：A/B/C 三级规则+清单输出（骨架版先跑通结构与输出，规则见 Task 2）."""
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gu_tools import PsArgs, repo_abs, write_csv_utf8_bom, write_utf8_no_bom
from clean_full_source import CONFIRMED_FIXES

CANDIDATE_FIELDS = ['seq', 'type', 'severity', 'section', 'line_source', 'line_edit', 'sample', 'rule', 'verdict']
RE_SECTION_HEAD = re.compile(r'^\s*第\s*[一二三四五六七八九十百千0-9]+\s*节\s*[:：]?\s*\S')


def find_section(lines, line_index):
    """该行所属节序号：从文件头数到该行为止的节标题数（1-based；无标题返回 0）。"""
    count = 0
    for i in range(0, line_index + 1):
        if RE_SECTION_HEAD.match(lines[i]):
            count += 1
    return count


def build_candidate(type_, severity, section, line_source, line_edit, sample, rule, verdict=''):
    return {'seq': 0, 'type': type_, 'severity': severity, 'section': section,
            'line_source': line_source, 'line_edit': line_edit, 'sample': sample,
            'rule': rule, 'verdict': verdict}


def scan_rules(lines):
    """规则入口。Task 1 返回空；Task 2 实现三层规则后替换本体。"""
    return []


def serialize_tsv(candidates, path):
    rows = [{k: (c.get(k) if c.get(k) is not None else '') for k in CANDIDATE_FIELDS} for c in candidates]
    write_csv_utf8_bom(path, rows)


def serialize_md(candidates, edit_lines, path):
    out = [u'# 候选清单（机器生成；verdict 由会话填写）', '']
    for c in candidates:
        out.append(u'### [seq {0}] {1} 级 · {2} · 节{3} · 行 {4}'.format(
            c['seq'], c['severity'], c['type'], c['section'], c['line_source']))
        out.append(u'原文：{0}'.format((c['sample'] or '').replace('\n', ' ')))
        out.append(u'规则：{0}（verdict={1}）'.format(c['rule'], c['verdict']))
        out.append('')
    write_utf8_no_bom(path, u'\n'.join(out))


def resolve_volume_dir(volume_id):
    with io.open(repo_abs('config/editorial-volumes.json'), 'r', encoding='utf-8-sig') as fh:
        cfg = json.load(fh)
    vol = next((v for v in cfg['volumes'] if v['id'] == volume_id), None)
    if not vol:
        raise SystemExit('Unknown volume: {0}'.format(volume_id))
    pattern = re.compile(vol['directoryPattern'].replace('.', r'\.').replace('*', '.*'))
    for name in sorted(os.listdir(repo_abs('volumes'))):
        if pattern.match(name):
            return os.path.join(repo_abs('volumes'), name)
    raise SystemExit('Volume directory not found for: {0}'.format(volume_id))


def main():
    args = PsArgs(specs=[('Volume', 'string'), ('Batch', 'string'),
                         ('Source', 'string'), ('OutDir', 'string'), ('Apply', 'bool')],
                  defaults={'Source': '蛊真人-clean.txt', 'OutDir': 'working'})
    volume_id = args.get('Volume')
    batch = args.get('Batch')
    if not volume_id or not batch:
        raise SystemExit('Usage: -Volume vol1 -Batch 001-030 [-Source ...] [-OutDir ...] [-Apply]')
    out_dir = repo_abs(args.get('OutDir'))

    volume_dir = resolve_volume_dir(volume_id)
    edited_path = os.path.join(volume_dir, u'{0}-sec{1}.edited.txt'.format(volume_id, batch))
    if not os.path.isfile(edited_path):
        raise SystemExit('Edited text not found: {0}'.format(edited_path))
    with io.open(edited_path, 'r', encoding='utf-8-sig', newline='') as fh:
        edit_lines = fh.read().splitlines()

    candidates = scan_rules(edit_lines)
    for idx, c in enumerate(candidates, 1):
        c['seq'] = idx
    tsv_path = os.path.join(out_dir, u'candidates-{0}-{1}.tsv'.format(volume_id, batch))
    md_path = os.path.join(out_dir, u'candidates-{0}-{1}.md'.format(volume_id, batch))
    serialize_tsv(candidates, tsv_path)
    serialize_md(candidates, edit_lines, md_path)
    print(u'output: {0}'.format(tsv_path))
    print(u'output: {0}'.format(md_path))


if __name__ == '__main__':
    main()
```

（Step 3 中使用 `out_dir` 为上文定义的输出目录变量；`import json` 已含在头部。）

- [ ] **Step 4: 跑测试**

Run: `py -3 -m unittest tests.test_scan_candidates -v` — Expected: OK（5 个用例）
Run: `py -3 -m unittest discover -s tests -v` — Expected: OK（原 3 个 check_remote_base 不回退）

- [ ] **Step 5: 冒烟运行**

Run: `py -3 scripts/scan_candidates.py -Volume vol3 -Batch 151-180`
Expected: 输出两行 `output: working/candidates-vol3-151-180.tsv` 与 `.md`；TSV 仅表头；MD 仅首行标题。

- [ ] **Step 6: Commit**

```bash
git add scripts/scan_candidates.py tests/test_scan_candidates.py
git commit -m "feat: 候选扫描管线骨架（数据结构/节号定位/TSV+MD输出/卷目录解析）"
```

---

### Task 2: A/B/C 三层规则引擎

**Files:**
- Modify: `scripts/scan_candidates.py`（替换 `scan_rules` 占位，新增规则函数）
- Test: `tests/test_scan_candidates.py`（追加 RuleTests）

**Interfaces:**
- Consumes: Task 1 的 `build_candidate`、`find_section`、`CONFIRMED_FIXES`
- Produces（均取整批行 `lines`，返回 dict 列表；内部循环体首行重新计算 `section = find_section(lines, i - 1)`）：
  - `mech_rules(lines) -> list[dict]`：A 级 wordlist；B 级 mojibake/redact
  - `semantic_rules(lines) -> list[dict]`：B 级 repeat / 元石-数字混用 num-mix
  - `literary_rules(lines) -> list[dict]`：C 级 author-speak / network-word / scene-repetition
  - `scan_rules(lines) -> list[dict]`：组合三层全部候选

- [ ] **Step 1: 追加失败测试**

追加到测试文件：

```python
class RuleTests(unittest.TestCase):
    def test_mechWordlist(self):
        lines = [u'第 1 节：测试', u'他躲闪不及，真是淬不及防。', u'']
        w = [c for c in mech_rules(lines) if c['rule'] == 'wordlist']
        self.assertEqual(len(w), 1)
        self.assertEqual(w[0]['severity'], 'A')
        self.assertIn(u'淬不及防', w[0]['sample'])

    def test_mechRedactAndMojibake(self):
        lines = [u'少年脸色大变：“[***]！”', u'乱码行\xfc。', u'']
        r = [c for c in mech_rules(lines) if c['rule'] == 'redact']
        m = [c for c in mech_rules(lines) if c['rule'] == 'mojibake']
        self.assertEqual(len(r), 1)
        self.assertEqual(len(m), 1)

    def test_semanticRepeat(self):
        lines = [u'他深深的吸了一口气，看了看身边的族人。',
                 u'他深深的吸了一口气，看了看身边的族人。', u'']
        rep = [c for c in semantic_rules(lines) if c['rule'] == 'repeat']
        self.assertGreaterEqual(len(rep), 1)
        self.assertEqual(rep[0]['severity'], 'B')

    def test_semanticNumMix(self):
        lines = [u'今日给他三块元石，明日又给他 3 块元石。', u'']
        n = [c for c in semantic_rules(lines) if c['rule'] == 'num-mix']
        self.assertGreaterEqual(len(n), 1)

    def test_literaryAuthorSpeak(self):
        lines = [u'写到这里，我也不禁要劝读者一句：魔道自有其代价。', u'']
        a = [c for c in literary_rules(lines) if c['rule'] == 'author-speak']
        self.assertEqual(len(a), 1)
        self.assertEqual(a[0]['severity'], 'C')

    def test_literaryNetworkWord(self):
        lines = [u'这笔交易简直不要太爽，妥妥的。', u'']
        n = [c for c in literary_rules(lines) if c['rule'] == 'network-word']
        self.assertGreaterEqual(len(n), 1)

    def test_literarySceneRep(self):
        lines = [u'第 12 节：应试',
                 u'清风拂过山岗，月光洒落林间，夜色如水。',
                 u'微风轻抚古木，雾气氤氲半山，云影徘徊。',
                 u'寒露沾湿石阶，风声掠过屋角，月华朦胧。',
                 u'光影交错石缝，山气浮沉草木，星斗渐沉。',
                 u'', u'']
        s = [c for c in literary_rules(lines) if c['rule'] == 'scene-repetition']
        self.assertGreaterEqual(len(s), 1)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `py -3 -m unittest tests.test_scan_candidates -v`
Expected: FAIL — `NameError: name 'mech_rules' is not defined`

- [ ] **Step 3: 实现三层规则**

替换 `scan_rules`，并在文件中追加（放在 `serialize_md` 之后）：

```python
RE_UNKNOWN_CHAR = re.compile(u'[\ufffd\uf8ff\ue000-\uf8ff]')
RE_REDACT = re.compile(u'\[\*\*\*\]|\*\*')
```

追加本体：

```python
def mech_rules(lines):
    out = []
    for i, line in enumerate(lines, 1):
        section = find_section(lines, i - 1)
        for old, new in CONFIRMED_FIXES:
            if old in line:
                out.append(build_candidate('mech', 'A', section, i, i,
                                           line.strip()[:120], 'wordlist', ''))
        if RE_UNKNOWN_CHAR.search(line):
            out.append(build_candidate('mech', 'B', section, i, i,
                                       line.strip()[:120], 'mojibake', ''))
        if RE_REDACT.search(line):
            out.append(build_candidate('mech', 'B', section, i, i,
                                       line.strip()[:120], 'redact', ''))
    return out


CHINESE_NUM = {u'零': '0', u'一': '1', u'二': '2', u'三': '3', u'四': '4',
               u'五': '5', u'六': '6', u'七': '7', u'八': '8', u'九': '9'}
UNIT_WORDS = re.compile(u'[块元石转成级年月日两岁]')


def semantic_rules(lines):
    out = []
    n = len(lines)
    for i, line in enumerate(lines, 1):
        section = find_section(lines, i - 1)
        prev = lines[i - 2] if i > 1 else u''
        if len(line) >= 12 and len(prev) >= 12:
            ratio = SequenceMatcher(None, prev, line).ratio()
            if ratio >= 0.8:
                out.append(build_candidate('semantic', 'B', section, i - 1, i - 1,
                                           prev.strip()[:120], 'repeat',
                                           u'相似度{0:.2f}'.format(ratio)))
        compact = re.sub(r'\s+', '', line)
        han = set(re.findall(u'[一二三四五六七八九]+' + UNIT_WORDS.pattern + u'+', compact))
        arab = set(re.findall(u'[0-9]+' + UNIT_WORDS.pattern + u'+', compact))
        if han and arab:
            out.append(build_candidate('semantic', 'B', section, i, i,
                                       line.strip()[:120], 'num-mix',
                                       u'中文数字与阿拉伯数字混用'))
    return out


NETWORK_WORDS = [u'妥妥的', u'刷屏', u'热搜', u'流量', u'点赞', u'评论区', u'666', u'吐槽', u'打卡']
RE_SCENE_SENT = re.compile(u'[。！？]')
SCENE_VOCAB = u'风月云雪山光天雾气露霜星潮草木花石水树影'


def literary_rules(lines):
    out = []
    n = len(lines)
    for i, line in enumerate(lines, 1):
        section = find_section(lines, i - 1)
        stripped = line.strip()
        if re.match(u'^(?:写到这里|说到这里|笔者|作者|本书|各位读者|读者)', stripped):
            out.append(build_candidate('literary', 'C', section, i, i,
                                       stripped[:90], 'author-speak', ''))
        for w in NETWORK_WORDS:
            if w in line:
                out.append(build_candidate('literary', 'C', section, i, i,
                                           stripped[:90], 'network-word', u'词={0}'.format(w)))
    for start in range(0, n - 2):
        chunk = lines[start:start + 4]
        if _all_scene(chunk):
            out.append(build_candidate('literary', 'C', find_section(lines, start),
                                       start + 1, start + 1,
                                       u' '.join(x.strip() for x in chunk)[:200],
                                       'scene-repetition', ''))
            break
    return out


def _all_scene(chunk):
    for line in chunk:
        s = line.strip()
        if not s or not RE_SCENE_SENT.search(s):
            return False
        if re.search(u'[“”‘’：]', s):
            return False
        if sum(1 for ch in SCENE_VOCAB if ch in s) < 2:
            return False
    return True


def scan_rules(lines):
    return mech_rules(lines) + semantic_rules(lines) + literary_rules(lines)
```

- [ ] **Step 4: 跑测试**

Run: `py -3 -m unittest tests.test_scan_candidates -v` — OK（12 用例）
Run: `git diff --check`

- [ ] **Step 5: Commit**

```bash
git add scripts/scan_candidates.py tests/test_scan_candidates.py
git commit -m "feat: A/B/C 三层规则引擎（词表/乱码遮蔽/重复/数字混用/作者越位/网络词/场景复写）"
```

---

### Task 3: `-Apply`：A 级词表自动应用 + 留痕 + 幂等

**Files:**
- Modify: `scripts/scan_candidates.py`（追加 `apply_wordlist` 与 main 分支）
- Test: `tests/test_scan_candidates.py`（追加 ApplyTests）

**Interfaces:**
- Produces: `apply_wordlist(text, pairs) -> (new_text, applied, skipped)`，其中 applied/skipped 为 `(old, new)` 元组列表；引号内语境 `_in_quote` 跳过
- main 的 `-Apply` 分支：读取本批 .edited.txt → 应用词表 → 写回原文件 → 生成 `working/apply-<卷>-<范围>.log`（每行 `old|new|次数`）；重跑不重复计数（`old` 已不存在，applied 为空，第 2 次无副作用）

- [ ] **Step 1: 追加失败测试**

```python
class ApplyTests(unittest.TestCase):
    def test_applyReplacesAndLogs(self):
        txt = u'他真是淬不及防。下一行还是淬不及防。\n'
        new_txt, applied, skipped = apply_wordlist(txt, [(u'淬不及防', u'猝不及防')])
        self.assertEqual(applied, [(u'淬不及防', u'猝不及防')])
        self.assertEqual(skipped, [])
        self.assertIn(u'猝不及防', new_txt)
        self.assertNotIn(u'淬不及防', new_txt)

    def test_applySkipsQuoteContext(self):
        txt = u'他说：“我偏要淬不及防。”\n'
        new_txt, applied, skipped = apply_wordlist(txt, [(u'淬不及防', u'猝不及防')])
        self.assertEqual(applied, [])
        self.assertEqual(skipped, [u'淬不及防'])

    def test_applyPowerIdempotent(self):
        txt = u'他真是淬不及防。\n'
        new_txt, applied1, _ = apply_wordlist(txt, [(u'淬不及防', u'猝不及防')])
        _, applied2, _ = apply_wordlist(new_txt, [(u'淬不及防', u'猝不及防')])
        self.assertEqual(len(applied1), 1)
        self.assertEqual(applied2, [])

    def test_applySecondRunNoSideEffect(self):
        txt = u'真是淬不及防啊。\n'
        new1, _, _ = apply_wordlist(txt, [(u'淬不及防', u'猝不及防')])
        new2, applied, _ = apply_wordlist(new1 + u'淬不及防残留', [(u'淬不及防', u'猝不及防')])
        self.assertNotEqual(new2, new1)  # 新出现旧词会再次替换
```

- [ ] **Step 2: 跑测试确认失败（`NameError: apply_wordlist`）**
- [ ] **Step 3: 实现**

```python
def _in_quote(text, token):
    idx = text.find(token)
    if idx < 0:
        return False
    before = text[idx - 1:idx]
    after = text[idx + len(token):idx + len(token) + 1]
    return (before == u'“' and after == u'”') or (before == u'‘' and after == u'’')


def apply_wordlist(text, pairs):
    applied = []
    skipped = []
    for old, new in pairs:
        if old not in text:
            continue
        if _in_quote(text, old):
            skipped.append(old)
            continue
        text = text.replace(old, new)
        applied.append((old, new))
    return text, applied, skipped
```

main 中 `-Apply` 分支（在输出 tsv/md 前）：

```python
    if args.get('Apply'):
        with io.open(edited_path, 'r', encoding='utf-8-sig') as fh:
            raw = fh.read()
        new_raw, applied, skipped = apply_wordlist(raw, CONFIRMED_FIXES)
        if applied:
            with io.open(edited_path, 'w', encoding='utf-8-sig', newline='') as fh:
                fh.write(new_raw)
        log_path = os.path.join(out_dir, u'apply-{0}-{1}.log'.format(volume_id, batch))
        log_lines = []
        for old, new in applied:
            log_lines.append(u'{0}|{1}|{2}'.format(old, new, new_raw.count(new)))
        for old in skipped:
            log_lines.append(u'{0}|SKIP|引号语境保人工'.format(old))
        write_utf8_no_bom(log_path, u'\n'.join(log_lines))
        print(u'applied: {0} skipped: {1}'.format(len(applied), len(skipped)))
```

（注意此分支不更新候选 verdict；会话主流程在应用后自行核对。）

- [ ] **Step 4: 跑全部测试 + 冒烟**

Run: `py -3 -m unittest tests.test_scan_candidates -v`（OK，4 新用例）
Run: `git diff --check`
Run: 复制一份 vol3-151-180.edited.txt 到 temp，对 temp 副本：`py -3 scripts/scan_candidates.py -Volume vol3 -Batch 151-180 -Source <temp> -Apply` 前确认该批无"淬不及防"字样（该词表项在历批已清）→ 用 `-OutDir working/tmp` 观察 log 文件存在且计数为 0；再对临时造词文件验证一次替换生效。

- [ ] **Step 5: Commit**

```bash
git add scripts/scan_candidates.py tests/test_scan_candidates.py
git commit -m "feat: -Apply 词表自动应用+引号安全网+留痕+幂等"
```

---

### Task 4: gen_brief / gen_report 候选摘要节

**Files:**
- Modify: `scripts/gen_brief.py`（新增 `Candidates` bool 参数；在有 batch 的尾部输出前插入候选节）
- Modify: `scripts/gen_report.py`（新增 `Candidates` bool 参数；在"台账落地清单"小节后插入候选+审计节）
- Test: `tests/test_brief_report_candidates.py`（新建）

**Interfaces:**
- 输出格式：简报追加 `## N. 本批候选` 节（N 为原节号+1），内容：
  - `- 候选总数：N（A: a / B: b / C: c）`
  - `- 清单：working/candidates-<卷>-<range>.tsv / .md`
  - `- 待检表：working/audit-<卷>-<range>.tsv（Task 5 后出现）`
- 无候选文件时不输出该节；`-Candidates` 缺省 false，行为不变。

- [ ] **Step 1: 写失败测试**

`tests/test_brief_report_candidates.py`：

```python
# -*- coding: utf-8 -*-
import io
import os
import sys
import tempfile
import unittest

SCRIPTS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'scripts')
sys.path.insert(0, SCRIPTS_DIR)

from gu_tools import write_csv_utf8_bom

CANDIDATE_FIELDS = ['seq', 'type', 'severity', 'section', 'line_source', 'line_edit', 'sample', 'rule', 'verdict']


class CandidateSnippetTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def tearDown(self):
        os.rmdir(self.tmp)

    def build_candidate_tsv(self, name, rows):
        path = os.path.join(self.tmp, name)
        write_csv_utf8_bom(path, rows)
        return path

    def test_format_counts(self):
        from scan_candidates import CANDIDATE_FIELDS as F
        rows = [
            {k: '' for k in F}, {k: '' for k in F}
        ]
        rows[0]['severity'] = 'A'
        rows[1]['severity'] = 'C'
        path = self.build_candidate_tsv('candidates-x.tsv', rows)
        # 等待 gen_brief/gen_report 导出候选节函数（本测试仅在原函数存在时执行）
```

（说明：本测试只保证数据契约；节文本断言交给 Step 3 后对真实 gen_brief 输出做 `assertIn(u'候选总数')` 集成检查——脚本导出函数难以注入临时路径，采用命令行级集成测试：以临时 RepoRoot 实跑。测试执行时做法：**复制 `scripts/gen_brief.py` 到 tmp、改动 RepoRoot 指向 tmp 夹具目录，实跑断言输出含 `候选总数：2（A: 1 / B: 0 / C: 1）`**。）

- [ ] **Step 2: 实现 gen_brief**（在 `main()` 输出块前——即 `brief_text = os.linesep.join(lines)` 出现前——插入；修改点含顶部 `import csv`）

```python
    if args.get('Candidates') and batch:
        cand_path = os.path.join(repo_path('working'), u'candidates-{0}-{1}.tsv'.format(vol_cfg['id'], batch))
        if os.path.isfile(cand_path):
            with io.open(cand_path, 'r', encoding='utf-8-sig') as fh:
                cand_rows = list(csv.DictReader(fh))
            n_a = sum(1 for r in cand_rows if r.get('severity') == 'A')
            n_b = sum(1 for r in cand_rows if r.get('severity') == 'B')
            n_c = sum(1 for r in cand_rows if r.get('severity') == 'C')
            brief('')
            brief(u'## 7. 候选统计（scan_candidates 输出）')
            brief('')
            brief(u'- 候选总数：{0}（A: {1} / B: {2} / C: {3}）'.format(len(cand_rows), n_a, n_b, n_c))
            brief(u'- 清单：working/candidates-{0}-{1}.tsv、.md'.format(vol_cfg['id'], batch))
        else:
            brief(u'## 7. 候选统计（未生成清单：先运行 scan_candidates.py -Volume {0} -Batch {1}）'.format(
                vol_cfg['id'], batch))
```

- [ ] **Step 3: 实现 gen_report**（插入到"台账落地清单"节后）

```python
    # 候选与审计小节
    if args.get('Candidates'):
        cand_path = os.path.join(repo_path('working'), u'candidates-{0}-{1}.tsv'.format(vol_cfg['id'], batch))
        if os.path.isfile(cand_path):
            with io.open(cand_path, 'r', encoding='utf-8-sig') as fh:
                cand_rows = list(csv.DictReader(fh))
            n_a = sum(1 for r in cand_rows if r.get('severity') == 'A')
            n_b = sum(1 for r in cand_rows if r.get('severity') == 'B')
            n_c = sum(1 for r in cand_rows if r.get('severity') == 'C')
            report('')
            report(u'## 5. 候选与审计（附）')
            report('')
            report(u'- 候选总数：{0}（A: {1} / B: {2} / C: {3}）'.format(len(cand_rows), n_a, n_b, n_c))
        audit_path = repo_path(u'working\\audit-{0}-{1}.tsv'.format(vol_cfg['id'], batch))
        if os.path.isfile(audit_path):
            with io.open(audit_path, 'r', encoding='utf-8-sig') as fh:
                audit_rows = list(csv.DictReader(fh))
            wrong = sum(1 for r in audit_rows if r.get('人工结论') == '错')
            miss = sum(1 for r in audit_rows if r.get('人工结论') == '漏检')
            report(u'- 审计表已生成：{0} 条，错误/漏检 {1}/{2}'.format(
                len(audit_rows), wrong, miss))
```

- [ ] **Step 4: 集成测试**

构造最小夹具仓库（复制 config/editorial-volumes.json、建 volumes/01-x/vol4-sec001-030.edited.txt 空文件、working/candidates-vol4-001-030.tsv）：
Run: `py -3 scripts/gen_report.py -Volume vol4 -Batch 001-030 -Candidates -RepoRoot <tmp>` Expected: 输出含 `候选总数：2（A: 1 / B: 0 / C: 1）`
Run: `py -3 scripts/gen_brief.py -Volume vol4 -Batch 001-030 -Candidates -RepoRoot <tmp>` Expected: 输出含 `### 7. 候选统计`
Run: 无 `-Candidates` 时输出不含 `候选总数`（保持旧行为）
Run: `py -3 -m unittest tests.test_brief_report_candidates -v` — OK

- [ ] **Step 5: Commit**

```bash
git add scripts/gen_brief.py scripts/gen_report.py tests/test_brief_report_candidates.py
git commit -m "feat: 候选统计注入 gen_brief/gen_report（-Candidates 开关，缺省行为不变）"
```

---

### Task 5: audit_candidates.py（审计表生成 + 误差统计）

**Files:**
- Create: `scripts/audit_candidates.py`
- Test: `tests/test_audit_candidates.py`（新建）

**Interfaces:**
- Consumes: 候选 TSV、.edited.txt（取 before/after 文本）
- Produces:
  - `load_audit_rows(path) -> list[dict]`
  - `summarize_audit(rows) -> dict(total, applied, skipped, wrong, miss, pending)`
  - `write_audit(rows, path)`（BOM CSV，列：`seq,type,severity,section,before,after,verdict,人工结论`）
  - `main()`：`-Volume -Batch -Candidates -Edited -Out`；读候选 TSV + 编辑文本，before 从候选 sample，after 从编辑文本行（行号候选字段），逐个生成审计表；输出 `working/audit-<卷>-<范围>.tsv`，并打印 summarize 统计

- [ ] **Step 1: 写失败测试**

```python
# -*- coding: utf-8 -*-
import io
import os
import shutil
import sys
import tempfile
import unittest

SCRIPTS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'scripts')
sys.path.insert(0, SCRIPTS_DIR)

from audit_candidates import summarize_audit


class AuditStatTests(unittest.TestCase):
    def test_summarize(self):
        rows = [
            {'verdict': u'已自动应用', '人工结论': ''},
            {'verdict': u'', '人工结论': u'错'},
            {'verdict': u'', '人工结论': u'漏检'},
            {'verdict': '', '人工结论': ''},
        ]
        s = summarize_audit(rows)
        self.assertEqual(s['applied'], 1)
        self.assertEqual(s['wrong'], 1)
        self.assertEqual(s['miss'], 1)
        self.assertEqual(s['pending'], 4)
```

- [ ] **Step 2: 跑测试确认失败（ModuleNotFoundError）**
- [ ] **Step 3: 实现**

```python
import csv
import io
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gu_tools import PsArgs, repo_abs, print_console, write_csv_utf8_bom
from scan_candidates import resolve_volume_dir

CSV_FIELDS = ['seq', 'type', 'severity', 'section', 'before', 'after', 'verdict', '人工结论']


def summarize_audit(rows):
    return {
        'total': len(rows),
        'applied': sum(1 for r in rows if r.get('verdict') == u'已自动应用'),
        'wrong': sum(1 for r in rows if r.get('人工结论') == u'错'),
        'miss': sum(1 for r in rows if r.get('人工结论') == u'漏检'),
        'pending': sum(1 for r in rows if not (r.get('人工结论') or '').strip()),
    }
```

```python
def write_audit(path, rows):
    out_rows = []
    for r in rows:
        out_rows.append({k: (r.get(k) if r.get(k) is not None else '') for k in CSV_FIELDS})
    write_csv_utf8_bom(path, out_rows)


def load_candidates(cands_path):
    with io.open(cands_path, 'r', encoding='utf-8-sig') as fh:
        return list(csv.DictReader(fh))


def main():
    args = PsArgs(specs=[('Volume', 'string'), ('Batch', 'string'),
                         ('Candidates', 'string'), ('Edited', 'string'),
                         ('Out', 'string')], defaults={'Out': 'working'})
    vol = args.get('Volume')
    batch = args.get('Batch')
    cands_path = args.get('Candidates') or repo_abs(u'working/candidates-{0}-{1}.tsv'.format(vol, batch))
    edited_path = args.get('Edited') or os.path.join(resolve_volume_dir(vol),
                                                     u'{0}-sec{1}.edited.txt'.format(vol, batch))
    cands = load_candidates(cands_path)
    with io.open(edited_path, 'r', encoding='utf-8-sig') as fh:
        edit_lines = fh.read().splitlines()
    out_rows = []
    for c in cands:
        ln = int(c.get('line_edit') or 0)
        before = (c.get('sample') or '').strip()[:120]
        after = edit_lines[ln - 1].strip()[:120] if 0 < ln <= len(edit_lines) else ''
        out_rows.append({'seq': c.get('seq', ''), 'type': c.get('type', ''),
                         'severity': c.get('severity', ''), 'section': c.get('section', ''),
                         'before': before, 'after': after,
                         'verdict': c.get('verdict', ''), '人工结论': ''})
    write_audit(os.path.join(repo_abs(args.get('Out')), u'audit-{0}-{1}.tsv'.format(vol, batch)), out_rows)
    stats = summarize_audit(out_rows)
    print_console(u'audit: total={total} applied={applied} wrong={wrong} miss={miss} pending={pending}'.format(**stats))
```

- [ ] **Step 4: 测试 + 冒烟**

Run: `py -3 -m unittest tests.test_audit_candidates -v`
Run: 对 vol3-151-180 跑一次审计（生成 `working/audit-vol3-151-180.tsv`，统计数值打印）
Run: `git diff --check`

- [ ] **Step 5: Commit**

```bash
git add scripts/audit_candidates.py tests/test_audit_candidates.py
git commit -m "feat: 审计表生成与误差统计（audit_candidates.py）"
```

---

### Task 6: 试点运行 vol3-151-180

**Files:** 运行验证（无新代码）

- [ ] **Step 1**: `py -3 scripts/scan_candidates.py -Volume vol3 -Batch 151-180` → 输出 tsv/md；记录候选总数与 A/B/C 分布
- [ ] **Step 2**: `py -3 scripts/scan_candidates.py -Volume vol3 -Batch 151-180 -Apply` → 核对 `.edited.txt` 词表命中行被替换、`working/apply-vol3-151-180.log` 留痕、重跑不重复
- [ ] **Step 3**: 打开 `gen_brief -Candidates` 简报，按候选逐条决策（A 已应用核对、B/C 改删留）直接编辑 `volumes/03-*/vol3-sec151-180.edited.txt`（本步骤由会话执行）
- [ ] **Step 4**: 回归：`py -3 scripts/validate_editorial_assets.py -Phase detail` + `git diff --check` + 本批标题数量/顺序、错名/重字/乱码扫描
- [ ] **Step 5**: `py -3 scripts/gen_report.py -Volume vol3 -Batch 151-180 -Candidates` → 用户全量待检 `audit-vol3-151-180.tsv`（逐条 tick 人工结论）→ 复跑 summarize 出《质量下降报告》
- [ ] **Step 6**: 按报告执行铺开/降级/回退决策；结论写入 vol3 决策注册表；按 AGENTS.md §12 提交（消息含裁决要点 + 审阅状态）

---

## 验收门槛（全局）

- 全部测试：`py -3 -m unittest tests.test_scan_candidates tests.test_audit_candidates tests.test_brief_report_candidates -v` 绿
- `py -3 -m unittest discover -s tests -v` 无既有回归
- 试点 30 节产出：candidates tsv/md、apply log、audit 表、gen_report 批报齐备
- 按任务间 commit 约定逐个提交（每个任务独立 commit）