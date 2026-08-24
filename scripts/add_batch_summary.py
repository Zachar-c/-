# -*- coding: utf-8 -*-
"""为 outlines/detail/*.md 生成「本批主线 + 关联冻结裁决」摘要块。

幂等：已包含「## 本批主线」或「## 关联冻结裁决」的文件跳过。内容自动提取：
- 主线：由各节标题串成节链（节标题即主线骨架）
- 冻结裁决：从 notes/ledger.md 条目行（`[来源:` 前缀）中提取与本批范围相关的记录

用法：
  py -3 scripts/add_batch_summary.py            # 全部卷
  py -3 scripts/add_batch_summary.py -Volume vol1
"""
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gu_tools import PsArgs, REPO_ROOT, print_console

SUMMARY_HEADING = u'## 本批主线'
DECISION_HEADING = u'## 关联冻结裁决'


def load_volume_config(repo_root):
    with io.open(os.path.join(repo_root, 'config', 'editorial-volumes.json'), 'r', encoding='utf-8-sig') as fh:
        return json.load(fh)


def read_utf8_preserve(path):
    with io.open(path, 'r', encoding='utf-8-sig', newline='') as fh:
        return fh.read()


def write_utf8_preserve(path, text, had_bom):
    with io.open(path, 'w', encoding='utf-8-sig' if had_bom else 'utf-8', newline='') as fh:
        fh.write(text)


def collect_headings(detail_path):
    text = read_utf8_preserve(detail_path)
    headings = re.findall(r'(?m)^#{2,3}\s+第\s*(\d+)\s*节[：:]\s*(.+?)\s*$', text)
    return text, headings


def collect_ledger_entries(repo_root):
    ledger_path = os.path.join(repo_root, 'notes', 'ledger.md')
    if not os.path.isfile(ledger_path):
        return []
    text = read_utf8_preserve(ledger_path)
    entries = []
    for line in text.splitlines():
        stripped = line.strip()
        if re.match(r'^-\s*\[来源[:：]', stripped):
            entries.append(re.sub(r'^-\s*', '', stripped))
    return entries


def entry_matches_batch(entry, rng):
    if u'全卷' in entry or u'全书' in entry:
        return True
    return bool(re.search(re.sub(r'-', r'\\s*[-—–]\\s*', rng), entry))


def render_block(vol_id, rng, headings, entries, eol):
    lines = []
    lines.append(SUMMARY_HEADING)
    lines.append('')
    if headings:
        first_no = headings[0][0]
        last_no = headings[-1][0]
        chain = u' → '.join(u'{0}节《{1}》'.format(no, title) for no, title in headings)
        if len(chain) > 400:
            chain = u' → '.join(u'{0}节《{1}》'.format(no, title) for no, title in headings[:8])
            chain += u' → ……（共 {0} 节）'.format(len(headings))
        lines.append(u'- 第{0}—{1}节（共 {2} 节）主线：{3}'.format(first_no, last_no, len(headings), chain))
    else:
        lines.append(u'- 细纲节标题未解析（占位细纲），本批主线待批内维护。')
    lines.append('')
    lines.append(DECISION_HEADING)
    lines.append('')
    if entries:
        for entry in entries:
            cut = entry[:60] + (u'…' if len(entry) > 60 else u'')
            lines.append(u'- ' + cut)
    else:
        lines.append(u'- 本批暂无直接命中的冻结裁决；活约束统一见 notes/ledger.md。')
    lines.append(u'- 裁决全文与溯源 ID 以 notes/ledger.md 为准（历史原文在 notes/archive/）。')
    return eol.join(lines)


def main():
    args = PsArgs(specs=[
        ('Volume', 'string'),
        ('RepoRoot', 'string'),
    ], defaults={
        'Volume': 'all',
        'RepoRoot': REPO_ROOT,
    })
    repo_root = os.path.abspath(args.get('RepoRoot'))
    volume_config = load_volume_config(repo_root)
    wanted = args.get('Volume')
    outline_root = os.path.join(repo_root, 'outlines', 'detail')
    changed = 0
    for vol_cfg in volume_config['volumes']:
        if wanted != 'all' and wanted != vol_cfg['id']:
            continue
        for batch_item in vol_cfg['batches']:
            rng = batch_item['range']
            outline_path = os.path.join(outline_root, u'{0}-sec{1}.md'.format(vol_cfg['id'], rng))
            if not os.path.isfile(outline_path):
                continue
            text, headings = collect_headings(outline_path)
            if SUMMARY_HEADING in text or DECISION_HEADING in text:
                continue
            eol = u'\r\n' if u'\r\n' in text else u'\n'
            entries = [e for e in collect_ledger_entries(repo_root) if entry_matches_batch(e, rng)]
            block = render_block(vol_cfg['id'], rng, headings, entries, eol)
            had_bom = text.startswith(u'\ufeff')
            body = text[1:] if had_bom else text
            marker = re.search(r'\n#{2,3}\s+第\s*(\d+)\s*节', body)
            insert_at = marker.start(0) if marker else len(body)
            head = body[:insert_at]
            if head.endswith(u'\r'):
                head = head[:-1]
            body = head + eol + block + body[insert_at:]
            write_utf8_preserve(outline_path, body, had_bom)
            print_console(u'- 已写入摘要块：{0}-sec{1}'.format(vol_cfg['id'], rng))
            changed += 1
    print_console(u'完成：{0} 个细纲新增摘要块（已存在的跳过）。'.format(changed))


if __name__ == '__main__':
    main()