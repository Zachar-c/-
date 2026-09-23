# Task 4 Brief

## Global Constraints

- 鏂拌剼鏈湪 `scripts/` 涓嬶紝澶翠袱琛?`# -*- coding: utf-8 -*-` + docstring锛屼笌鐜版湁鑴氭湰涓€鑷淬€?- 璇嶈〃鍞竴鏉ユ簮锛歚from clean_full_source import CONFIRMED_FIXES`锛岀姝㈠湪鎵弿鍣ㄥ唴澶嶅埗璇嶈〃銆?- TSV 鍐欑洏鐢?`gu_tools.write_csv_utf8_bom`锛圔OM+閫楀彿鍒嗛殧锛夛紱MD 鐢?`gu_tools.write_utf8_no_bom`銆?- 鎵弿鍣ㄥ彧璇绘簮鏂囦笌鍙拌处锛涘敮涓€鑷姩鍐欐鏂囪矾寰勬槸 `-Apply`锛堜粎璇嶈〃鏇挎崲锛夛紝涓€寰嬪啓 `working/apply-a-<鍗?-<鑼冨洿>.log` 鐣欑棔銆?- 骞傜瓑锛氬悓杈撳叆涓ゆ杩愯閫愬瓧鑺備竴鑷达紱`-Apply` 瀵瑰凡搴旂敤椤逛笉閲嶅璁℃暟銆?- 鍙傛暟涓€寰?PsArgs锛涙柊寮€鍏崇己鐪佷笉鍚敤锛屾棫璋冪敤琛屼负闆跺彉鍖栥€?- 璺緞鐢?`os.path.join`锛岀姝㈢‖缂栫爜 `\\`銆?- 绂佹淇敼 AGENTS.md銆佸彴璐︺€乧onfig/editorial-volumes.json銆?- 姣忎换鍔＄嫭绔?commit锛涗换鍔″畬鎴愯窇 `py -3 -m unittest tests.test_scan_candidates -v` + `git diff --check` 鍏ㄧ豢鍐嶆彁浜ゃ€?- 鎺у埗鍙颁贡鐮佷笉褰卞搷鏂囦欢鍐呭锛涙祴璇曟柇瑷€鍩轰簬鏂囦欢鍐呭銆?
---



### Task 4: gen_brief / gen_report 鍊欓€夋憳瑕佽妭

**Files:**
- Modify: `scripts/gen_brief.py`锛堟柊澧?`Candidates` bool 鍙傛暟锛涘湪鏈?batch 鐨勫熬閮ㄨ緭鍑哄墠鎻掑叆鍊欓€夎妭锛?- Modify: `scripts/gen_report.py`锛堟柊澧?`Candidates` bool 鍙傛暟锛涘湪"鍙拌处钀藉湴娓呭崟"灏忚妭鍚庢彃鍏ュ€欓€?瀹¤鑺傦級
- Test: `tests/test_brief_report_candidates.py`锛堟柊寤猴級

**Interfaces:**
- 杈撳嚭鏍煎紡锛氱畝鎶ヨ拷鍔?`## N. 鏈壒鍊欓€塦 鑺傦紙N 涓哄師鑺傚彿+1锛夛紝鍐呭锛?  - `- 鍊欓€夋€绘暟锛歂锛圓: a / B: b / C: c锛塦
  - `- 娓呭崟锛歸orking/candidates-<鍗?-<range>.tsv / .md`
  - `- 寰呮琛細working/audit-<鍗?-<range>.tsv锛圱ask 5 鍚庡嚭鐜帮級`
- 鏃犲€欓€夋枃浠舵椂涓嶈緭鍑鸿鑺傦紱`-Candidates` 缂虹渷 false锛岃涓轰笉鍙樸€?
- [ ] **Step 1: 鍐欏け璐ユ祴璇?*

`tests/test_brief_report_candidates.py`锛?
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
        # 绛夊緟 gen_brief/gen_report 瀵煎嚭鍊欓€夎妭鍑芥暟锛堟湰娴嬭瘯浠呭湪鍘熷嚱鏁板瓨鍦ㄦ椂鎵ц锛?```

锛堣鏄庯細鏈祴璇曞彧淇濊瘉鏁版嵁濂戠害锛涜妭鏂囨湰鏂█浜ょ粰 Step 3 鍚庡鐪熷疄 gen_brief 杈撳嚭鍋?`assertIn(u'鍊欓€夋€绘暟')` 闆嗘垚妫€鏌モ€斺€旇剼鏈鍑哄嚱鏁伴毦浠ユ敞鍏ヤ复鏃惰矾寰勶紝閲囩敤鍛戒护琛岀骇闆嗘垚娴嬭瘯锛氫互涓存椂 RepoRoot 瀹炶窇銆傛祴璇曟墽琛屾椂鍋氭硶锛?*澶嶅埗 `scripts/gen_brief.py` 鍒?tmp銆佹敼鍔?RepoRoot 鎸囧悜 tmp 澶瑰叿鐩綍锛屽疄璺戞柇瑷€杈撳嚭鍚?`鍊欓€夋€绘暟锛?锛圓: 1 / B: 0 / C: 1锛塦**銆傦級

- [ ] **Step 2: 瀹炵幇 gen_brief**锛堝湪 `main()` 杈撳嚭鍧楀墠鈥斺€斿嵆 `brief_text = os.linesep.join(lines)` 鍑虹幇鍓嶁€斺€旀彃鍏ワ紱淇敼鐐瑰惈椤堕儴 `import csv`锛?
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
            brief(u'## 7. 鍊欓€夌粺璁★紙scan_candidates 杈撳嚭锛?)
            brief('')
            brief(u'- 鍊欓€夋€绘暟锛歿0}锛圓: {1} / B: {2} / C: {3}锛?.format(len(cand_rows), n_a, n_b, n_c))
            brief(u'- 娓呭崟锛歸orking/candidates-{0}-{1}.tsv銆?md'.format(vol_cfg['id'], batch))
        else:
            brief(u'## 7. 鍊欓€夌粺璁★紙鏈敓鎴愭竻鍗曪細鍏堣繍琛?scan_candidates.py -Volume {0} -Batch {1}锛?.format(
                vol_cfg['id'], batch))
```

- [ ] **Step 3: 瀹炵幇 gen_report**锛堟彃鍏ュ埌"鍙拌处钀藉湴娓呭崟"鑺傚悗锛?
```python
    # 鍊欓€変笌瀹¤灏忚妭
    if args.get('Candidates'):
        cand_path = os.path.join(repo_path('working'), u'candidates-{0}-{1}.tsv'.format(vol_cfg['id'], batch))
        if os.path.isfile(cand_path):
            with io.open(cand_path, 'r', encoding='utf-8-sig') as fh:
                cand_rows = list(csv.DictReader(fh))
            n_a = sum(1 for r in cand_rows if r.get('severity') == 'A')
            n_b = sum(1 for r in cand_rows if r.get('severity') == 'B')
            n_c = sum(1 for r in cand_rows if r.get('severity') == 'C')
            report('')
            report(u'## 5. 鍊欓€変笌瀹¤锛堥檮锛?)
            report('')
            report(u'- 鍊欓€夋€绘暟锛歿0}锛圓: {1} / B: {2} / C: {3}锛?.format(len(cand_rows), n_a, n_b, n_c))
        audit_path = repo_path(u'working\\audit-{0}-{1}.tsv'.format(vol_cfg['id'], batch))
        if os.path.isfile(audit_path):
            with io.open(audit_path, 'r', encoding='utf-8-sig') as fh:
                audit_rows = list(csv.DictReader(fh))
            wrong = sum(1 for r in audit_rows if r.get('浜哄伐缁撹') == '閿?)
            miss = sum(1 for r in audit_rows if r.get('浜哄伐缁撹') == '婕忔')
            report(u'- 瀹¤琛ㄥ凡鐢熸垚锛歿0} 鏉★紝閿欒/婕忔 {1}/{2}'.format(
                len(audit_rows), wrong, miss))
```

- [ ] **Step 4: 闆嗘垚娴嬭瘯**

鏋勯€犳渶灏忓す鍏蜂粨搴擄紙澶嶅埗 config/editorial-volumes.json銆佸缓 volumes/01-x/vol4-sec001-030.edited.txt 绌烘枃浠躲€亀orking/candidates-vol4-001-030.tsv锛夛細
Run: `py -3 scripts/gen_report.py -Volume vol4 -Batch 001-030 -Candidates -RepoRoot <tmp>` Expected: 杈撳嚭鍚?`鍊欓€夋€绘暟锛?锛圓: 1 / B: 0 / C: 1锛塦
Run: `py -3 scripts/gen_brief.py -Volume vol4 -Batch 001-030 -Candidates -RepoRoot <tmp>` Expected: 杈撳嚭鍚?`### 7. 鍊欓€夌粺璁
Run: 鏃?`-Candidates` 鏃惰緭鍑轰笉鍚?`鍊欓€夋€绘暟`锛堜繚鎸佹棫琛屼负锛?Run: `py -3 -m unittest tests.test_brief_report_candidates -v` 鈥?OK

- [ ] **Step 5: Commit**

```bash
git add scripts/gen_brief.py scripts/gen_report.py tests/test_brief_report_candidates.py
git commit -m "feat: 鍊欓€夌粺璁℃敞鍏?gen_brief/gen_report锛?Candidates 寮€鍏筹紝缂虹渷琛屼负涓嶅彉锛?
```

---


