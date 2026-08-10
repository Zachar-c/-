# -*- coding: utf-8 -*-
"""Task 5：audit_candidates 审计表生成与误差统计测试。"""
import io
import os
import shutil
import sys
import tempfile
import unittest

SCRIPTS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'scripts')
sys.path.insert(0, SCRIPTS_DIR)

from audit_candidates import summarize_audit, write_audit, load_candidates


class AuditStatTests(unittest.TestCase):
    def test_summarize(self):
        rows = [
            {'verdict': u'已自动应用', '人工结论': ''},
            {'verdict': u'', '人工结论': u'错'},
            {'verdict': u'', '人工结论': u'漏检'},
            {'verdict': '', '人工结论': ''},
        ]
        s = summarize_audit(rows)
        self.assertEqual(s['total'], 4)
        self.assertEqual(s['applied'], 1)
        self.assertEqual(s['wrong'], 1)
        self.assertEqual(s['miss'], 1)
        self.assertEqual(s['pending'], 2)

    def test_summarize_missing_fields(self):
        s = summarize_audit([{}, {'verdict': u'已自动应用'}])
        self.assertEqual(s['total'], 2)
        self.assertEqual(s['applied'], 1)
        self.assertEqual(s['wrong'], 0)
        self.assertEqual(s['miss'], 0)
        self.assertEqual(s['pending'], 2)


class AuditFileTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.path = os.path.join(self.temp_dir, 'audit.tsv')

    def tearDown(self):
        shutil.rmtree(self.temp_dir)

    def test_write_audit_roundtrip(self):
        rows = [
            {'seq': '1', 'type': 'mech', 'severity': 'A', 'section': '152',
             'before': '错字', 'after': '正字', 'verdict': '', '人工结论': ''},
        ]
        write_audit(self.path, rows)
        loaded = load_candidates(self.path)
        self.assertEqual(len(loaded), 1)
        self.assertEqual(loaded[0]['seq'], '1')
        self.assertEqual(loaded[0]['after'], u'正字')
        self.assertEqual(loaded[0][u'人工结论'], '')

    def test_write_audit_empty_rows(self):
        write_audit(self.path, [])
        with io.open(self.path, 'r', encoding='utf-8-sig') as fh:
            head = fh.readline()
        self.assertIn('seq', head)
        self.assertIn(u'人工结论', head)


if __name__ == '__main__':
    unittest.main()
