# -*- coding: utf-8 -*-
import csv
import io
import os
import shutil
import sys
import tempfile
import unittest

SCRIPTS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'scripts')
sys.path.insert(0, SCRIPTS_DIR)

from scan_candidates import (CANDIDATE_FIELDS, find_section, build_candidate,
                             serialize_tsv, serialize_md, scan,
                             scan_rules, mech_rules, semantic_rules, literary_rules,
                             apply_wordlist)


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


class RuleTests(unittest.TestCase):
    def test_mechWordlist(self):
        lines = [u'第 1 节：测试', u'他躲闪不及，真是淬不及防。', u'']
        w = [c for c in mech_rules(lines) if c['rule'] == 'wordlist']
        self.assertEqual(len(w), 1)
        self.assertEqual(w[0]['severity'], 'A')
        self.assertIn(u'淬不及防', w[0]['sample'])

    def test_mechRedactAndMojibake(self):
        lines = [u'少年脸色大变：“[***]！”', u'乱码行\ufffd。', u'']
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


class ApplyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmp)

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

    def test_applyMixedQuoteAndBareOccurrence(self):
        txt = u'他说：“淬不及防。”事后众人皆淬不及防。'
        new_txt, applied, skipped = apply_wordlist(txt, [(u'淬不及防', u'猝不及防')])
        self.assertEqual(len(applied), 1)
        self.assertIn(u'“淬不及防。”', new_txt)   # 引号内保持原词
        self.assertIn(u'众人皆猝不及防', new_txt)  # 引号外被替换
        self.assertGreaterEqual(len(skipped), 1)

    def test_applyToFilePreservesCrlfAndBom(self):
        import scan_candidates as sc
        path = os.path.join(self.tmp, 'edit.txt')
        raw = u'\ufeff真是淬不及防。\r\n下一行不动。\r\n'
        with io.open(path, 'w', encoding='utf-8-sig', newline='') as fh:
            fh.write(raw)
        applied, skipped = sc.apply_to_file(path, [(u'淬不及防', u'猝不及防')])
        self.assertEqual(len(applied), 1)
        with io.open(path, 'rb') as fh:
            blob = fh.read()
        self.assertTrue(blob.startswith(u'\ufeff'.encode('utf-8')))  # BOM 保持
        self.assertEqual(blob.count(b'\r\n'), 2)                      # CRLF 保持
        self.assertIn(u'猝不及防'.encode('utf-8'), blob)


if __name__ == '__main__':
    unittest.main()