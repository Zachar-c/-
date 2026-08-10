# -*- coding: utf-8 -*-
"""候选审计表生成与误差统计：读取候选 TSV 与 .edited.txt，逐条生成 before/after 审计行。
用法：
  py -3 scripts/audit_candidates.py -Volume vol3 -Batch 151-180
  py -3 scripts/audit_candidates.py -Volume vol3 -Batch 151-180 -Candidates working/candidates-x.tsv -Edited volumes/03-xx/vol3-sec151-180.edited.txt -Out working
输出：working/audit-<卷>-<范围>.tsv，并打印统计（total/applied/wrong/miss/pending）。
人工逐条在 '人工结论' 列填：对 / 错 / 漏检，用于统计管线误差。"""
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


def write_audit(path, rows):
    out_rows = []
    for r in rows:
        out_rows.append({k: (r.get(k) if r.get(k) is not None else '') for k in CSV_FIELDS})
    if not out_rows:
        parent = os.path.dirname(path)
        if parent:
            os.makedirs(parent, exist_ok=True)
        with io.open(path, 'w', encoding='utf-8-sig', newline='') as fh:
            fh.write(u','.join(CSV_FIELDS) + u'\n')
        return
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
    if not vol or not batch:
        raise SystemExit('必须提供 -Volume 与 -Batch，例如 -Volume vol3 -Batch 151-180。')
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
    out_path = os.path.join(repo_abs(args.get('Out')), u'audit-{0}-{1}.tsv'.format(vol, batch))
    write_audit(out_path, out_rows)
    stats = summarize_audit(out_rows)
    print_console(u'audit: total={total} applied={applied} wrong={wrong} miss={miss} pending={pending}'.format(**stats))


if __name__ == '__main__':
    main()
