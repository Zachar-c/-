# -*- coding: utf-8 -*-
"""Task 4：gen_brief/gen_report -Candidates 开关与候选/审计统计节测试。

用临时夹具仓库（-RepoRoot）实测真实脚本：候选清单统计、缺失提示、
无开关不输出、审计表统计。
"""
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS_DIR = os.path.join(REPO, 'scripts')

VOLUME_CONFIG = {
    'trackedSourceAllowlist': [],
    'userStatedCharacters': 0,
    'bookIdPattern': 'tvol-{volume}-sec{first}-{last}',
    'volumes': [
        {
            'id': 'tvol',
            'directoryPattern': '99-*',
            'detailPattern': 'tvol-sec*.md',
            'sectionCount': 199,
            'batches': [
                {'range': '151-180', 'count': 30},
            ],
        },
    ],
}

CANDIDATE_HEADER = ['seq', 'type', 'severity', 'section', 'line_source', 'line_edit', 'sample', 'rule', 'verdict']
CANDIDATE_ROWS = [
    ['1', 'mech', 'A', '152', '12', '12', '错字A', 'wordlist', ''],
    ['2', 'mech', 'A', '153', '20', '20', '错字B', 'wordlist', ''],
    ['3', 'sema', 'B', '154', '30', '30', '重复句', 'repeat', ''],
    ['4', 'sema', 'B', '155', '40', '40', '矛盾', 'conflict', ''],
    ['5', 'sema', 'B', '156', '50', '50', '重复词', 'repeat', ''],
    ['6', 'lite', 'C', '157', '60', '60', '冗余尾', 'trail', ''],
]

AUDIT_HEADER = ['seq', 'type', 'severity', 'section', 'line_source', 'line_edit', 'sample', 'rule', 'verdict', '人工结论']
AUDIT_ROWS = [
    ['1', 'mech', 'A', '152', '12', '12', '错字A', 'wordlist', '改', '对'],
    ['2', 'sema', 'B', '154', '30', '30', '重复句', 'repeat', '改', '错'],
    ['3', 'lite', 'C', '157', '60', '60', '冗余尾', 'trail', '改', '漏检'],
]


class BriefReportCandidatesTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.repo_root = os.path.join(self.temp_dir, 'fixture')
        os.makedirs(os.path.join(self.repo_root, 'config'), exist_ok=True)
        os.makedirs(os.path.join(self.repo_root, 'working'), exist_ok=True)
        with io.open(os.path.join(self.repo_root, 'config', 'editorial-volumes.json'),
                     'w', encoding='utf-8-sig', newline='') as fh:
            json.dump(VOLUME_CONFIG, fh, ensure_ascii=False, indent=2)
        self.cand_path = os.path.join(self.repo_root, 'working', 'candidates-tvol-151-180.tsv')
        self.audit_path = os.path.join(self.repo_root, 'working', 'audit-tvol-151-180.tsv')

    def tearDown(self):
        shutil.rmtree(self.temp_dir)

    def write_tsv(self, path, header, rows):
        with io.open(path, 'w', encoding='utf-8-sig', newline='') as fh:
            fh.write(u','.join(header) + u'\n')
            for row in rows:
                fh.write(u','.join(row) + u'\n')

    def run_script(self, name, *extra_args):
        out = os.path.join(self.temp_dir, 'out.md')
        out_arg = '-BriefOut' if name == 'gen_brief.py' else '-OutFile'
        args = [sys.executable, os.path.join(SCRIPTS_DIR, name),
                '-RepoRoot', self.repo_root,
                out_arg, out] + list(extra_args)
        proc = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if proc.returncode != 0:
            self.fail(u'{0} 退出码 {1}: {2}'.format(
                name, proc.returncode, proc.stderr.decode('utf-8', errors='replace')))
        with io.open(out, 'r', encoding='utf-8-sig') as fh:
            return fh.read()

    # ---------------- gen_brief ----------------

    def test_brief_reports_candidate_stats_with_flag(self):
        self.write_tsv(self.cand_path, CANDIDATE_HEADER, CANDIDATE_ROWS)
        text = self.run_script('gen_brief.py', '-Volume', 'tvol', '-Batch', '151-180', '-Candidates')
        self.assertIn(u'候选清单：6 条（A: 2 / B: 3 / C: 1）', text)

    def test_brief_hints_generation_when_candidates_missing(self):
        text = self.run_script('gen_brief.py', '-Volume', 'tvol', '-Batch', '151-180', '-Candidates')
        self.assertIn(u'候选清单尚未生成', text)

    def test_brief_silent_without_flag(self):
        self.write_tsv(self.cand_path, CANDIDATE_HEADER, CANDIDATE_ROWS)
        text = self.run_script('gen_brief.py', '-Volume', 'tvol', '-Batch', '151-180')
        self.assertNotIn(u'候选清单', text)

    def test_brief_tolerates_empty_candidates_file(self):
        with io.open(self.cand_path, 'w', encoding='utf-8-sig', newline='') as fh:
            fh.write(u','.join(CANDIDATE_HEADER) + u'\n')
        text = self.run_script('gen_brief.py', '-Volume', 'tvol', '-Batch', '151-180', '-Candidates')
        self.assertIn(u'候选清单：0 条（A: 0 / B: 0 / C: 0）', text)

    # ---------------- gen_report ----------------

    def test_report_reports_candidate_and_audit_stats(self):
        self.write_tsv(self.cand_path, CANDIDATE_HEADER, CANDIDATE_ROWS)
        self.write_tsv(self.audit_path, AUDIT_HEADER, AUDIT_ROWS)
        text = self.run_script('gen_report.py', '-Volume', 'tvol', '-Batch', '151-180',
                               '-Candidates', '-SkipValidate')
        self.assertIn(u'候选总数：6（A: 2 / B: 3 / C: 1）', text)
        self.assertIn(u'审计表已生成：3 条，错误/漏检 1/1', text)

    def test_report_silent_without_flag(self):
        self.write_tsv(self.cand_path, CANDIDATE_HEADER, CANDIDATE_ROWS)
        text = self.run_script('gen_report.py', '-Volume', 'tvol', '-Batch', '151-180', '-SkipValidate')
        self.assertNotIn(u'候选总数', text)

    def test_report_missing_candidates_file(self):
        text = self.run_script('gen_report.py', '-Volume', 'tvol', '-Batch', '151-180',
                               '-Candidates', '-SkipValidate')
        self.assertNotIn(u'候选总数', text)
        self.assertIn(u'## 6. 候选与审计（附）', text)


if __name__ == '__main__':
    unittest.main()
