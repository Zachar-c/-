# Task 1 Brief（从实施计划提取）

# Global Constraints（本次实施全程适用）
- 鏂拌剼鏈湪 `scripts/` 涓嬶紝澶翠袱琛?`# -*- coding: utf-8 -*-` + docstring锛屼笌鐜版湁鑴氭湰涓€鑷淬€?- 璇嶈〃鍞竴鏉ユ簮锛歚from clean_full_source import CONFIRMED_FIXES`锛岀姝㈠湪鎵弿鍣ㄥ唴澶嶅埗璇嶈〃銆?- TSV 鍐欑洏鐢?`gu_tools.write_csv_utf8_bom`锛圔OM+閫楀彿鍒嗛殧锛夛紱MD 鐢?`gu_tools.write_utf8_no_bom`銆?- 鎵弿鍣ㄥ彧璇绘簮鏂囦笌鍙拌处锛涘敮涓€鑷姩鍐欐鏂囪矾寰勬槸 `-Apply`锛堜粎璇嶈〃鏇挎崲锛夛紝涓€寰嬪啓 `working/apply-a-<鍗?-<鑼冨洿>.log` 鐣欑棔銆?- 骞傜瓑锛氬悓杈撳叆涓ゆ杩愯閫愬瓧鑺備竴鑷达紱`-Apply` 瀵瑰凡搴旂敤椤逛笉閲嶅璁℃暟銆?- 鍙傛暟涓€寰?PsArgs锛涙柊寮€鍏崇己鐪佷笉鍚敤锛屾棫璋冪敤琛屼负闆跺彉鍖栥€?- 璺緞鐢?`os.path.join`锛岀姝㈢‖缂栫爜 `\\`銆?- 绂佹淇敼 AGENTS.md銆佸彴璐︺€乧onfig/editorial-volumes.json銆?- 姣忎换鍔＄嫭绔?commit锛涗换鍔″畬鎴愯窇 `py -3 -m unittest tests.test_scan_candidates -v` + `git diff --check` 鍏ㄧ豢鍐嶆彁浜ゃ€?- 鎺у埗鍙颁贡鐮佷笉褰卞搷鏂囦欢鍐呭锛涙祴璇曟柇瑷€鍩轰簬鏂囦欢鍐呭銆?
---



### Task 1: scan_candidates.py 楠ㄦ灦锛堟暟鎹粨鏋?/ 鑺傚彿瀹氫綅 / TSV+MD 杈撳嚭 / main 鍏ュ彛瑙ｆ瀽鍗风洰褰曪級

**Files:**
- Create: `scripts/scan_candidates.py`
- Test: `tests/test_scan_candidates.py`

**Interfaces:**
- Consumes: `gu_tools.PsArgs` / `repo_abs` / `write_csv_utf8_bom` / `write_utf8_no_bom`锛沗clean_full_source.CONFIRMED_FIXES`锛沗config/editorial-volumes.json`
- Produces:
  - `CANDIDATE_FIELDS = ['seq', 'type', 'severity', 'section', 'line_source', 'line_edit', 'sample', 'rule', 'verdict']`
  - `find_section(lines, line_index) -> int`
  - `build_candidate(type_, severity, section, line_source, line_edit, sample, rule, verdict='') -> dict`
  - `resolve_volume_dir(volume_id) -> str`锛堜粠 config 鐨?directoryPattern 鍖归厤 volumes/ 涓嬬洰褰曪級
  - `resolve_batch_path(volume_dir, volume_id, batch) -> str`锛堟嫾鎺?`<vol>-sec<range>.edited.txt`锛?  - `serialize_tsv(candidates, path)`銆乣serialize_md(candidates, edit_lines, path)`
  - `main()`锛歅sArgs 瑙勬牸 `(Volume, Batch, Source, OutDir, Apply)`锛涜鎵规 .edited.txt 涓庡噣鐗堟簮鏂囧搴斿尯娈碉紝璋冪敤 `scan()`锛堟湰浠诲姟涓虹┖瑙勫垯鍗犱綅锛夛紝杈撳嚭 `working/candidates-<鍗?-<鑼冨洿>.tsv/.md`

- [ ] **Step 1: 鍐欏け璐ユ祴璇?*

`tests/test_scan_candidates.py`锛?
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
        c = build_candidate('mech', 'A', 3, 10, 10, u'娣笉鍙婇槻', 'wordlist', '')
        self.assertEqual(list(c.keys()), CANDIDATE_FIELDS)

    def test_findSectionCountsFromHead(self):
        lines = [u'绗?涓€ 鑺?锛?绾?韬?浜?, u'姝ｆ枃涓€', u'绗?浜?鑺?锛?閫?鍏?闃?, u'姝ｆ枃浜?, u'', u'姝ｆ枃涓?]
        self.assertEqual(find_section(lines, 0), 1)
        self.assertEqual(find_section(lines, 3), 2)
        self.assertEqual(find_section(lines, 5), 2)
        self.assertEqual(find_section([u'娌℃湁鏍囬'], 0), 0)

    def test_serializeRoundTripCsv(self):
        cands = [build_candidate('semantic', 'B', 1, 4, 4, u'閲嶅鍙?, 'repeat', u'鐩镐技搴?.8')]
        path = os.path.join(self.tmp, 'candidates.tsv')
        serialize_tsv(cands, path)
        with io.open(path, 'r', encoding='utf-8-sig') as fh:
            rows = list(csv.DictReader(fh))
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['rule'], 'repeat')
        self.assertEqual(rows[0]['severity'], 'B')

    def test_serializeMdContainsContext(self):
        lines = [u'绗?1 鑺?, u'浣犲ソ', u'浣犲潖']
        cands = [build_candidate('literary', 'C', 1, 2, 2, u'浣犲ソ', 'author-speak', '')]
        path = os.path.join(self.tmp, 'candidates.md')
        serialize_md(cands, lines, path)
        txt = io.open(path, 'r', encoding='utf-8').read()
        self.assertIn(u'浣犲ソ', txt)
        self.assertIn(u'author-speak', txt)

    def test_findSectionMatchesChineseNumeralHead(self):
        lines = [u'绗竴鐧句簲鍗佷竴鑺傦細绔熸槸铔婁粰浼犳壙', u'鐮帮紒', u'榛戞ゼ鍏颁竴鑴氳涪缈婚粦鏃楄儨銆?]
        self.assertEqual(find_section(lines, 1), 1)
```

锛堥渶 `import csv`銆傚簭鍒楀寲鍩轰簬 `seq` 鍗囧簭浠ヤ繚鎸?TSV 骞傜瓑鍙鐜般€傦級

- [ ] **Step 2: 璺戞祴璇曠‘璁ゅけ璐?*

Run: `py -3 -m unittest tests.test_scan_candidates -v`
Expected: FAIL 鈥?`ModuleNotFoundError: No module named 'scan_candidates'`

- [ ] **Step 3: 鍐欓鏋跺疄鐜?*

`scripts/scan_candidates.py`锛?
```python
# -*- coding: utf-8 -*-
"""鍏ㄤ功鍊欓€夋壂鎻忥細A/B/C 涓夌骇瑙勫垯+娓呭崟杈撳嚭锛堥鏋剁増鍏堣窇閫氱粨鏋勪笌杈撳嚭锛岃鍒欒 Task 2锛?"""
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gu_tools import PsArgs, repo_abs, write_csv_utf8_bom, write_utf8_no_bom
from clean_full_source import CONFIRMED_FIXES

CANDIDATE_FIELDS = ['seq', 'type', 'severity', 'section', 'line_source', 'line_edit', 'sample', 'rule', 'verdict']
RE_SECTION_HEAD = re.compile(r'^\s*绗琝s*[涓€浜屼笁鍥涗簲鍏竷鍏節鍗佺櫨鍗?-9]+\s*鑺俓s*[:锛歖?\s*\S')


def find_section(lines, line_index):
    """璇ヨ鎵€灞炶妭搴忓彿锛氫粠鏂囦欢澶存暟鍒拌琛屼负姝㈢殑鑺傛爣棰樻暟锛?-based锛涙棤鏍囬杩斿洖 0锛夈€?""
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
    """瑙勫垯鍏ュ彛銆俆ask 1 杩斿洖绌猴紱Task 2 瀹炵幇涓夊眰瑙勫垯鍚庢浛鎹㈡湰浣撱€?""
    return []


def serialize_tsv(candidates, path):
    rows = [{k: (c.get(k) if c.get(k) is not None else '') for k in CANDIDATE_FIELDS} for c in candidates]
    write_csv_utf8_bom(path, rows)


def serialize_md(candidates, edit_lines, path):
    out = [u'# 鍊欓€夋竻鍗曪紙鏈哄櫒鐢熸垚锛泇erdict 鐢变細璇濆～鍐欙級', '']
    for c in candidates:
        out.append(u'### [seq {0}] {1} 绾?路 {2} 路 鑺倇3} 路 琛?{4}'.format(
            c['seq'], c['severity'], c['type'], c['section'], c['line_source']))
        out.append(u'鍘熸枃锛歿0}'.format((c['sample'] or '').replace('\n', ' ')))
        out.append(u'瑙勫垯锛歿0}锛坴erdict={1}锛?.format(c['rule'], c['verdict']))
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
                  defaults={'Source': '铔婄湡浜?clean.txt', 'OutDir': 'working'})
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

锛圫tep 3 涓娇鐢?`out_dir` 涓轰笂鏂囧畾涔夌殑杈撳嚭鐩綍鍙橀噺锛沗import json` 宸插惈鍦ㄥご閮ㄣ€傦級

- [ ] **Step 4: 璺戞祴璇?*

Run: `py -3 -m unittest tests.test_scan_candidates -v` 鈥?Expected: OK锛? 涓敤渚嬶級
Run: `py -3 -m unittest discover -s tests -v` 鈥?Expected: OK锛堝師 3 涓?check_remote_base 涓嶅洖閫€锛?
- [ ] **Step 5: 鍐掔儫杩愯**

Run: `py -3 scripts/scan_candidates.py -Volume vol3 -Batch 151-180`
Expected: 杈撳嚭涓よ `output: working/candidates-vol3-151-180.tsv` 涓?`.md`锛汿SV 浠呰〃澶达紱MD 浠呴琛屾爣棰樸€?
- [ ] **Step 6: Commit**

```bash
git add scripts/scan_candidates.py tests/test_scan_candidates.py
git commit -m "feat: 鍊欓€夋壂鎻忕绾块鏋讹紙鏁版嵁缁撴瀯/鑺傚彿瀹氫綅/TSV+MD杈撳嚭/鍗风洰褰曡В鏋愶級"
```

---


