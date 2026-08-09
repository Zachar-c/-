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


def scan(lines):
    """对外扫描入口（规则见 scan_rules；本任务为空规则占位）。"""
    return scan_rules(lines)


def serialize_tsv(candidates, path):
    rows = [{k: (c.get(k) if c.get(k) is not None else '') for k in CANDIDATE_FIELDS} for c in candidates]
    if not rows:
        parent = os.path.dirname(path)
        if parent:
            os.makedirs(parent, exist_ok=True)
        with io.open(path, 'w', encoding='utf-8-sig', newline='') as fh:
            fh.write(u','.join(CANDIDATE_FIELDS) + u'\n')
        return
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
                  defaults={'Source': u'蛊真人-clean.txt', 'OutDir': 'working'})
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

    candidates = scan(edit_lines)
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