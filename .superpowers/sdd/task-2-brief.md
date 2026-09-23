# Task 2 Brief

## Global Constraints

- 鏂拌剼鏈湪 `scripts/` 涓嬶紝澶翠袱琛?`# -*- coding: utf-8 -*-` + docstring锛屼笌鐜版湁鑴氭湰涓€鑷淬€?- 璇嶈〃鍞竴鏉ユ簮锛歚from clean_full_source import CONFIRMED_FIXES`锛岀姝㈠湪鎵弿鍣ㄥ唴澶嶅埗璇嶈〃銆?- TSV 鍐欑洏鐢?`gu_tools.write_csv_utf8_bom`锛圔OM+閫楀彿鍒嗛殧锛夛紱MD 鐢?`gu_tools.write_utf8_no_bom`銆?- 鎵弿鍣ㄥ彧璇绘簮鏂囦笌鍙拌处锛涘敮涓€鑷姩鍐欐鏂囪矾寰勬槸 `-Apply`锛堜粎璇嶈〃鏇挎崲锛夛紝涓€寰嬪啓 `working/apply-a-<鍗?-<鑼冨洿>.log` 鐣欑棔銆?- 骞傜瓑锛氬悓杈撳叆涓ゆ杩愯閫愬瓧鑺備竴鑷达紱`-Apply` 瀵瑰凡搴旂敤椤逛笉閲嶅璁℃暟銆?- 鍙傛暟涓€寰?PsArgs锛涙柊寮€鍏崇己鐪佷笉鍚敤锛屾棫璋冪敤琛屼负闆跺彉鍖栥€?- 璺緞鐢?`os.path.join`锛岀姝㈢‖缂栫爜 `\\`銆?- 绂佹淇敼 AGENTS.md銆佸彴璐︺€乧onfig/editorial-volumes.json銆?- 姣忎换鍔＄嫭绔?commit锛涗换鍔″畬鎴愯窇 `py -3 -m unittest tests.test_scan_candidates -v` + `git diff --check` 鍏ㄧ豢鍐嶆彁浜ゃ€?- 鎺у埗鍙颁贡鐮佷笉褰卞搷鏂囦欢鍐呭锛涙祴璇曟柇瑷€鍩轰簬鏂囦欢鍐呭銆?
---



### Task 2: A/B/C 涓夊眰瑙勫垯寮曟搸

**Files:**
- Modify: `scripts/scan_candidates.py`锛堟浛鎹?`scan_rules` 鍗犱綅锛屾柊澧炶鍒欏嚱鏁帮級
- Test: `tests/test_scan_candidates.py`锛堣拷鍔?RuleTests锛?
**Interfaces:**
- Consumes: Task 1 鐨?`build_candidate`銆乣find_section`銆乣CONFIRMED_FIXES`
- Produces锛堝潎鍙栨暣鎵硅 `lines`锛岃繑鍥?dict 鍒楄〃锛涘唴閮ㄥ惊鐜綋棣栬閲嶆柊璁＄畻 `section = find_section(lines, i - 1)`锛夛細
  - `mech_rules(lines) -> list[dict]`锛欰 绾?wordlist锛汢 绾?mojibake/redact
  - `semantic_rules(lines) -> list[dict]`锛欱 绾?repeat / 鍏冪煶-鏁板瓧娣风敤 num-mix
  - `literary_rules(lines) -> list[dict]`锛欳 绾?author-speak / network-word / scene-repetition
  - `scan_rules(lines) -> list[dict]`锛氱粍鍚堜笁灞傚叏閮ㄥ€欓€?
- [ ] **Step 1: 杩藉姞澶辫触娴嬭瘯**

杩藉姞鍒版祴璇曟枃浠讹細

```python
class RuleTests(unittest.TestCase):
    def test_mechWordlist(self):
        lines = [u'绗?1 鑺傦細娴嬭瘯', u'浠栬翰闂笉鍙婏紝鐪熸槸娣笉鍙婇槻銆?, u'']
        w = [c for c in mech_rules(lines) if c['rule'] == 'wordlist']
        self.assertEqual(len(w), 1)
        self.assertEqual(w[0]['severity'], 'A')
        self.assertIn(u'娣笉鍙婇槻', w[0]['sample'])

    def test_mechRedactAndMojibake(self):
        lines = [u'灏戝勾鑴歌壊澶у彉锛氣€淸***]锛佲€?, u'涔辩爜琛孿xfc銆?, u'']
        r = [c for c in mech_rules(lines) if c['rule'] == 'redact']
        m = [c for c in mech_rules(lines) if c['rule'] == 'mojibake']
        self.assertEqual(len(r), 1)
        self.assertEqual(len(m), 1)

    def test_semanticRepeat(self):
        lines = [u'浠栨繁娣辩殑鍚镐簡涓€鍙ｆ皵锛岀湅浜嗙湅韬竟鐨勬棌浜恒€?,
                 u'浠栨繁娣辩殑鍚镐簡涓€鍙ｆ皵锛岀湅浜嗙湅韬竟鐨勬棌浜恒€?, u'']
        rep = [c for c in semantic_rules(lines) if c['rule'] == 'repeat']
        self.assertGreaterEqual(len(rep), 1)
        self.assertEqual(rep[0]['severity'], 'B')

    def test_semanticNumMix(self):
        lines = [u'浠婃棩缁欎粬涓夊潡鍏冪煶锛屾槑鏃ュ張缁欎粬 3 鍧楀厓鐭炽€?, u'']
        n = [c for c in semantic_rules(lines) if c['rule'] == 'num-mix']
        self.assertGreaterEqual(len(n), 1)

    def test_literaryAuthorSpeak(self):
        lines = [u'鍐欏埌杩欓噷锛屾垜涔熶笉绂佽鍔濊鑰呬竴鍙ワ細榄旈亾鑷湁鍏朵唬浠枫€?, u'']
        a = [c for c in literary_rules(lines) if c['rule'] == 'author-speak']
        self.assertEqual(len(a), 1)
        self.assertEqual(a[0]['severity'], 'C')

    def test_literaryNetworkWord(self):
        lines = [u'杩欑瑪浜ゆ槗绠€鐩翠笉瑕佸お鐖斤紝濡ュΕ鐨勩€?, u'']
        n = [c for c in literary_rules(lines) if c['rule'] == 'network-word']
        self.assertGreaterEqual(len(n), 1)

    def test_literarySceneRep(self):
        lines = [u'绗?12 鑺傦細搴旇瘯',
                 u'娓呴鎷傝繃灞卞矖锛屾湀鍏夋磼钀芥灄闂达紝澶滆壊濡傛按銆?,
                 u'寰杞绘姎鍙ゆ湪锛岄浘姘旀挨姘插崐灞憋紝浜戝奖寰樺緤銆?,
                 u'瀵掗湶娌炬箍鐭抽樁锛岄澹版帬杩囧眿瑙掞紝鏈堝崕鏈﹁儳銆?,
                 u'鍏夊奖浜ら敊鐭崇紳锛屽北姘旀诞娌夎崏鏈紝鏄熸枟娓愭矇銆?,
                 u'', u'']
        s = [c for c in literary_rules(lines) if c['rule'] == 'scene-repetition']
        self.assertGreaterEqual(len(s), 1)
```

- [ ] **Step 2: 璺戞祴璇曠‘璁ゅけ璐?*

Run: `py -3 -m unittest tests.test_scan_candidates -v`
Expected: FAIL 鈥?`NameError: name 'mech_rules' is not defined`

- [ ] **Step 3: 瀹炵幇涓夊眰瑙勫垯**

鏇挎崲 `scan_rules`锛屽苟鍦ㄦ枃浠朵腑杩藉姞锛堟斁鍦?`serialize_md` 涔嬪悗锛夛細

```python
RE_UNKNOWN_CHAR = re.compile(u'[\ufffd\uf8ff\ue000-\uf8ff]')
RE_REDACT = re.compile(u'\[\*\*\*\]|\*\*')
```

杩藉姞鏈綋锛?
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


CHINESE_NUM = {u'闆?: '0', u'涓€': '1', u'浜?: '2', u'涓?: '3', u'鍥?: '4',
               u'浜?: '5', u'鍏?: '6', u'涓?: '7', u'鍏?: '8', u'涔?: '9'}
UNIT_WORDS = re.compile(u'[鍧楀厓鐭宠浆鎴愮骇骞存湀鏃ヤ袱宀乚')


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
                                           u'鐩镐技搴0:.2f}'.format(ratio)))
        compact = re.sub(r'\s+', '', line)
        han = set(re.findall(u'[涓€浜屼笁鍥涗簲鍏竷鍏節]+' + UNIT_WORDS.pattern + u'+', compact))
        arab = set(re.findall(u'[0-9]+' + UNIT_WORDS.pattern + u'+', compact))
        if han and arab:
            out.append(build_candidate('semantic', 'B', section, i, i,
                                       line.strip()[:120], 'num-mix',
                                       u'涓枃鏁板瓧涓庨樋鎷変集鏁板瓧娣风敤'))
    return out


NETWORK_WORDS = [u'濡ュΕ鐨?, u'鍒峰睆', u'鐑悳', u'娴侀噺', u'鐐硅禐', u'璇勮鍖?, u'666', u'鍚愭Ы', u'鎵撳崱']
RE_SCENE_SENT = re.compile(u'[銆傦紒锛焆')
SCENE_VOCAB = u'椋庢湀浜戦洩灞卞厜澶╅浘姘旈湶闇滄槦娼崏鏈ㄨ姳鐭虫按鏍戝奖'


def literary_rules(lines):
    out = []
    n = len(lines)
    for i, line in enumerate(lines, 1):
        section = find_section(lines, i - 1)
        stripped = line.strip()
        if re.match(u'^(?:鍐欏埌杩欓噷|璇村埌杩欓噷|绗旇€厊浣滆€厊鏈功|鍚勪綅璇昏€厊璇昏€?', stripped):
            out.append(build_candidate('literary', 'C', section, i, i,
                                       stripped[:90], 'author-speak', ''))
        for w in NETWORK_WORDS:
            if w in line:
                out.append(build_candidate('literary', 'C', section, i, i,
                                           stripped[:90], 'network-word', u'璇?{0}'.format(w)))
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
        if re.search(u'[鈥溾€濃€樷€欙細]', s):
            return False
        if sum(1 for ch in SCENE_VOCAB if ch in s) < 2:
            return False
    return True


def scan_rules(lines):
    return mech_rules(lines) + semantic_rules(lines) + literary_rules(lines)
```

- [ ] **Step 4: 璺戞祴璇?*

Run: `py -3 -m unittest tests.test_scan_candidates -v` 鈥?OK锛?2 鐢ㄤ緥锛?Run: `git diff --check`

- [ ] **Step 5: Commit**

```bash
git add scripts/scan_candidates.py tests/test_scan_candidates.py
git commit -m "feat: A/B/C 涓夊眰瑙勫垯寮曟搸锛堣瘝琛?涔辩爜閬斀/閲嶅/鏁板瓧娣风敤/浣滆€呰秺浣?缃戠粶璇?鍦烘櫙澶嶅啓锛?
```

---


