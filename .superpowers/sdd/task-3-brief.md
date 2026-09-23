# Task 3 Brief

## Global Constraints

- 鏂拌剼鏈湪 `scripts/` 涓嬶紝澶翠袱琛?`# -*- coding: utf-8 -*-` + docstring锛屼笌鐜版湁鑴氭湰涓€鑷淬€?- 璇嶈〃鍞竴鏉ユ簮锛歚from clean_full_source import CONFIRMED_FIXES`锛岀姝㈠湪鎵弿鍣ㄥ唴澶嶅埗璇嶈〃銆?- TSV 鍐欑洏鐢?`gu_tools.write_csv_utf8_bom`锛圔OM+閫楀彿鍒嗛殧锛夛紱MD 鐢?`gu_tools.write_utf8_no_bom`銆?- 鎵弿鍣ㄥ彧璇绘簮鏂囦笌鍙拌处锛涘敮涓€鑷姩鍐欐鏂囪矾寰勬槸 `-Apply`锛堜粎璇嶈〃鏇挎崲锛夛紝涓€寰嬪啓 `working/apply-a-<鍗?-<鑼冨洿>.log` 鐣欑棔銆?- 骞傜瓑锛氬悓杈撳叆涓ゆ杩愯閫愬瓧鑺備竴鑷达紱`-Apply` 瀵瑰凡搴旂敤椤逛笉閲嶅璁℃暟銆?- 鍙傛暟涓€寰?PsArgs锛涙柊寮€鍏崇己鐪佷笉鍚敤锛屾棫璋冪敤琛屼负闆跺彉鍖栥€?- 璺緞鐢?`os.path.join`锛岀姝㈢‖缂栫爜 `\\`銆?- 绂佹淇敼 AGENTS.md銆佸彴璐︺€乧onfig/editorial-volumes.json銆?- 姣忎换鍔＄嫭绔?commit锛涗换鍔″畬鎴愯窇 `py -3 -m unittest tests.test_scan_candidates -v` + `git diff --check` 鍏ㄧ豢鍐嶆彁浜ゃ€?- 鎺у埗鍙颁贡鐮佷笉褰卞搷鏂囦欢鍐呭锛涙祴璇曟柇瑷€鍩轰簬鏂囦欢鍐呭銆?
---



### Task 3: `-Apply`锛欰 绾ц瘝琛ㄨ嚜鍔ㄥ簲鐢?+ 鐣欑棔 + 骞傜瓑

**Files:**
- Modify: `scripts/scan_candidates.py`锛堣拷鍔?`apply_wordlist` 涓?main 鍒嗘敮锛?- Test: `tests/test_scan_candidates.py`锛堣拷鍔?ApplyTests锛?
**Interfaces:**
- Produces: `apply_wordlist(text, pairs) -> (new_text, applied, skipped)`锛屽叾涓?applied/skipped 涓?`(old, new)` 鍏冪粍鍒楄〃锛涘紩鍙峰唴璇 `_in_quote` 璺宠繃
- main 鐨?`-Apply` 鍒嗘敮锛氳鍙栨湰鎵?.edited.txt 鈫?搴旂敤璇嶈〃 鈫?鍐欏洖鍘熸枃浠?鈫?鐢熸垚 `working/apply-<鍗?-<鑼冨洿>.log`锛堟瘡琛?`old|new|娆℃暟`锛夛紱閲嶈窇涓嶉噸澶嶈鏁帮紙`old` 宸蹭笉瀛樺湪锛宎pplied 涓虹┖锛岀 2 娆℃棤鍓綔鐢級

- [ ] **Step 1: 杩藉姞澶辫触娴嬭瘯**

```python
class ApplyTests(unittest.TestCase):
    def test_applyReplacesAndLogs(self):
        txt = u'浠栫湡鏄番涓嶅強闃层€備笅涓€琛岃繕鏄番涓嶅強闃层€俓n'
        new_txt, applied, skipped = apply_wordlist(txt, [(u'娣笉鍙婇槻', u'鐚濅笉鍙婇槻')])
        self.assertEqual(applied, [(u'娣笉鍙婇槻', u'鐚濅笉鍙婇槻')])
        self.assertEqual(skipped, [])
        self.assertIn(u'鐚濅笉鍙婇槻', new_txt)
        self.assertNotIn(u'娣笉鍙婇槻', new_txt)

    def test_applySkipsQuoteContext(self):
        txt = u'浠栬锛氣€滄垜鍋忚娣笉鍙婇槻銆傗€漒n'
        new_txt, applied, skipped = apply_wordlist(txt, [(u'娣笉鍙婇槻', u'鐚濅笉鍙婇槻')])
        self.assertEqual(applied, [])
        self.assertEqual(skipped, [u'娣笉鍙婇槻'])

    def test_applyPowerIdempotent(self):
        txt = u'浠栫湡鏄番涓嶅強闃层€俓n'
        new_txt, applied1, _ = apply_wordlist(txt, [(u'娣笉鍙婇槻', u'鐚濅笉鍙婇槻')])
        _, applied2, _ = apply_wordlist(new_txt, [(u'娣笉鍙婇槻', u'鐚濅笉鍙婇槻')])
        self.assertEqual(len(applied1), 1)
        self.assertEqual(applied2, [])

    def test_applySecondRunNoSideEffect(self):
        txt = u'鐪熸槸娣笉鍙婇槻鍟娿€俓n'
        new1, _, _ = apply_wordlist(txt, [(u'娣笉鍙婇槻', u'鐚濅笉鍙婇槻')])
        new2, applied, _ = apply_wordlist(new1 + u'娣笉鍙婇槻娈嬬暀', [(u'娣笉鍙婇槻', u'鐚濅笉鍙婇槻')])
        self.assertNotEqual(new2, new1)  # 鏂板嚭鐜版棫璇嶄細鍐嶆鏇挎崲
```

- [ ] **Step 2: 璺戞祴璇曠‘璁ゅけ璐ワ紙`NameError: apply_wordlist`锛?*
- [ ] **Step 3: 瀹炵幇**

```python
def _in_quote(text, token):
    idx = text.find(token)
    if idx < 0:
        return False
    before = text[idx - 1:idx]
    after = text[idx + len(token):idx + len(token) + 1]
    return (before == u'鈥? and after == u'鈥?) or (before == u'鈥? and after == u'鈥?)


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

main 涓?`-Apply` 鍒嗘敮锛堝湪杈撳嚭 tsv/md 鍓嶏級锛?
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
            log_lines.append(u'{0}|SKIP|寮曞彿璇淇濅汉宸?.format(old))
        write_utf8_no_bom(log_path, u'\n'.join(log_lines))
        print(u'applied: {0} skipped: {1}'.format(len(applied), len(skipped)))
```

锛堟敞鎰忔鍒嗘敮涓嶆洿鏂板€欓€?verdict锛涗細璇濅富娴佺▼鍦ㄥ簲鐢ㄥ悗鑷鏍稿銆傦級

- [ ] **Step 4: 璺戝叏閮ㄦ祴璇?+ 鍐掔儫**

Run: `py -3 -m unittest tests.test_scan_candidates -v`锛圤K锛? 鏂扮敤渚嬶級
Run: `git diff --check`
Run: 澶嶅埗涓€浠?vol3-151-180.edited.txt 鍒?temp锛屽 temp 鍓湰锛歚py -3 scripts/scan_candidates.py -Volume vol3 -Batch 151-180 -Source <temp> -Apply` 鍓嶇‘璁よ鎵规棤"娣笉鍙婇槻"瀛楁牱锛堣璇嶈〃椤瑰湪鍘嗘壒宸叉竻锛夆啋 鐢?`-OutDir working/tmp` 瑙傚療 log 鏂囦欢瀛樺湪涓旇鏁颁负 0锛涘啀瀵逛复鏃堕€犺瘝鏂囦欢楠岃瘉涓€娆℃浛鎹㈢敓鏁堛€?
- [ ] **Step 5: Commit**

```bash
git add scripts/scan_candidates.py tests/test_scan_candidates.py
git commit -m "feat: -Apply 璇嶈〃鑷姩搴旂敤+寮曞彿瀹夊叏缃?鐣欑棔+骞傜瓑"
```

---


