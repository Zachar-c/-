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


if __name__ == '__main__':
    unittest.main()