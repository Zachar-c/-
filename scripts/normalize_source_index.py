# -*- coding: utf-8 -*-
"""源索引归一化审计：从 CP936 源文解析标题候选，与原始索引 CSV 对比，输出归一化 CSV/摘要/审计报告。
对齐 normalize_source_index.ps1。"""
import csv
import io
import json
import os
import re
import sys
from collections import OrderedDict
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gu_tools import PsArgs, repo_abs, repo_path, read_source_lines, chinese_number, write_json, write_csv_utf8_bom, write_utf8_bom, print_console

HEADING_CANDIDATE = re.compile(
    r'^\s*(?:(\u6B63\u6587)\s*)?\u7B2C([\u96F6\u3007\u4E00\u4E8C\u4E24\u4E09\u56DB\u4E94\u516D\u4E03\u516B\u4E5D\u5341\u767E\u5343\u4E07\d]+)\u8282\s*[\uFF1A:]\s*(.*?)\s*$')


def noise_flags(line, title):
    text = u'{0} {1}'.format(line, title)
    flags = []
    if re.search(u'\u76EE\u5F55|\u7AE0\u8282\u76EE\u5F55|\u5F3A\u5F31\\(\u7B2C\\d+/\u7B2C\\d+\u9875\\)', text):
        flags.append('directory_or_page')
    if re.search(u'\u4F5C\u8005|\u4F5C\u5BB6|\u5377\u672B\u611F\u8A00|\u5B8C\u672C\u611F\u8A00|\u65B0\u4E66|\u66F4\u65B0|\u8BA2\u9605|\u6708\u7968|\u63A8\u8350\u7968|\u672A\u5B8C\u5F85\u7EED|\\(?\\s*(?:ps|PS)\\s*[:\uFF1A]', text):
        flags.append('author_or_site')
    if re.search(u'www\\.|https?://|\u624B\u673A\u7528\u6237|\u8BF7\u6536\u85CF|\u7CBE\u5F69\u9605\u8BFB|</?\\w+[^>]*>', text):
        flags.append('site_markup')
    return ';'.join(flags)


def heading_candidate(line, source_line):
    m = HEADING_CANDIDATE.match(line)
    if not m:
        return None
    title = m.group(3).strip()
    if not title:
        return None
    return {
        'source_line': source_line,
        'section_text': m.group(2),
        'section_number': chinese_number(m.group(2)),
        'title': title,
        'noise_flags': noise_flags(line, title),
    }


def sequence_status(current, previous):
    if previous is None:
        return 'run_start'
    if current['section_number'] == previous['section_number'] + 1:
        return 'monotonic_next'
    if current['section_number'] == previous['section_number']:
        return 'duplicate_number'
    if current['section_number'] < previous['section_number']:
        return 'decrease_review_required'
    return 'gap_review_required'


def main():
    args = PsArgs(specs=[
        ('SourcePath', 'string'),
        ('RawIndexPath', 'string'),
        ('OutputDirectory', 'string'),
    ])
    source = repo_abs(args.require('SourcePath'))
    raw_index = repo_abs(args.require('RawIndexPath'))
    output_dir = repo_abs(args.require('OutputDirectory'))
    os.makedirs(output_dir, exist_ok=True)

    source_lines = read_source_lines(source)
    user_stated_characters = 0
    config_path = repo_path('config\\editorial-volumes.json')
    if os.path.isfile(config_path):
        with io.open(config_path, 'r', encoding='utf-8-sig') as fh:
            volume_config = json.load(fh)
        user_stated_characters = int(volume_config.get('userStatedCharacters', 0))
    with io.open(raw_index, 'r', encoding='utf-8-sig', newline='') as fh:
        raw_rows = list(csv.DictReader(fh))

    candidates = [c for i, line in enumerate(source_lines)
                  if (c := heading_candidate(line, i + 1)) is not None]

    raw_line_set = {int(row['line']) for row in raw_rows}

    sequence_run = 0
    previous = None
    normalized = []
    for candidate in candidates:
        status = sequence_status(candidate, previous)
        if previous is None or status in ('decrease_review_required', 'gap_review_required'):
            sequence_run += 1
        flags = candidate['noise_flags'].split(';') if candidate['noise_flags'].strip() else []
        review_required = ('review_required' in status) or (status == 'duplicate_number') or (len(flags) > 0)
        normalized.append({
            'source_line': candidate['source_line'],
            'section_number': candidate['section_number'],
            'section_text': candidate['section_text'],
            'title': candidate['title'],
            'noise_flags': candidate['noise_flags'],
            'sequence_run': sequence_run,
            'sequence_status': status,
            'duplicate_group': '',
            'canonical_candidate': False,
            'review_required': review_required,
        })
        previous = candidate

    duplicate_groups = {}
    for row in normalized:
        key = row['section_number']
        if key in duplicate_groups:
            duplicate_groups[key] += 1
        else:
            duplicate_groups[key] = 1
    for row in normalized:
        if duplicate_groups[row['section_number']] > 1:
            row['duplicate_group'] = 'section-{0}'.format(row['section_number'])

    for run_number in {row['sequence_run'] for row in normalized}:
        run_rows = sorted((r for r in normalized if r['sequence_run'] == run_number),
                          key=lambda r: r['source_line'])
        clean_rows = []
        last_clean_number = None
        for row in run_rows:
            if row['sequence_status'] == 'duplicate_number':
                continue
            if row['review_required'] or row['sequence_status'] not in ('run_start', 'monotonic_next'):
                if len(clean_rows) >= 3:
                    for clean_row in clean_rows:
                        clean_row['canonical_candidate'] = True
                clean_rows = []
                last_clean_number = None
                continue
            if last_clean_number is None or row['section_number'] == last_clean_number + 1:
                clean_rows.append(row)
                last_clean_number = row['section_number']
                continue
            if len(clean_rows) >= 3:
                for clean_row in clean_rows:
                    clean_row['canonical_candidate'] = True
            clean_rows = [row]
            last_clean_number = row['section_number']
        if len(clean_rows) >= 3:
            for clean_row in clean_rows:
                clean_row['canonical_candidate'] = True

    normalized_path = os.path.join(output_dir, 'chapter-headings-normalized.csv')
    summary_path = os.path.join(output_dir, 'chapter-number-summary-normalized.csv')
    audit_json_path = os.path.join(output_dir, 'source-audit.json')
    audit_markdown_path = os.path.join(output_dir, 'source-audit.md')

    write_csv_utf8_bom(normalized_path, normalized)

    summary = []
    for number in sorted({row['section_number'] for row in normalized}):
        rows = sorted((r for r in normalized if r['section_number'] == number),
                      key=lambda r: r['source_line'])
        titles = []
        for row in rows:
            if row['title'] not in titles:
                titles.append(row['title'])
        summary.append({
            'section_number': number,
            'occurrences': len(rows),
            'first_source_line': rows[0]['source_line'],
            'last_source_line': rows[-1]['source_line'],
            'titles': ' | '.join(titles),
            'canonical_candidates': sum(1 for r in rows if r['canonical_candidate']),
            'review_required': sum(1 for r in rows if r['review_required']),
        })
    write_csv_utf8_bom(summary_path, summary)

    run_summary = []
    for run_number in sorted({row['sequence_run'] for row in normalized}):
        rows = sorted((r for r in normalized if r['sequence_run'] == run_number),
                      key=lambda r: r['source_line'])
        run_summary.append({
            'sequence_run': run_number,
            'count': len(rows),
            'first_source_line': rows[0]['source_line'],
            'last_source_line': rows[-1]['source_line'],
            'first_section': rows[0]['section_number'],
            'last_section': rows[-1]['section_number'],
            'canonical_candidates': sum(1 for r in rows if r['canonical_candidate']),
            'review_required': sum(1 for r in rows if r['review_required']),
        })

    raw_line_numbers = [int(row['line']) for row in raw_rows]
    candidate_line_numbers = [row['source_line'] for row in normalized]
    missing_from_raw = [n for n in candidate_line_numbers if n not in raw_line_set]
    raw_only = [n for n in raw_line_numbers if n not in set(candidate_line_numbers)]
    non_monotonic = [r for r in normalized if 'review_required' in r['sequence_status']]

    source_bytes = os.path.getsize(source)
    source_audit = OrderedDict([
        ('source_path', os.path.abspath(source)),
        ('source_bytes', source_bytes),
        ('encoding', 'CP936 / GBK'),
        ('source_line_count', len(source_lines)),
        ('decoded_characters_without_newlines', sum(len(l) for l in source_lines)),
        ('user_stated_characters', user_stated_characters),
        ('raw_index_rows', len(raw_rows)),
        ('parsed_heading_candidates', len(normalized)),
        ('duplicate_section_numbers', sum(1 for v in duplicate_groups.values() if v > 1)),
        ('sequence_runs', len(run_summary)),
        ('review_required_rows', sum(1 for r in normalized if r['review_required'])),
        ('non_monotonic_or_gap_rows', len(non_monotonic)),
        ('raw_index_lines_not_reparsed', len(raw_only)),
        ('reparsed_lines_missing_from_raw_index', len(missing_from_raw)),
        ('generated_at', datetime.now().strftime('%Y-%m-%dT%H:%M:%S')),
    ])
    write_json(audit_json_path, source_audit)

    md = [
        '# Complete Source Index Audit',
        '',
        'This report audits and normalizes the index only. It does not modify or copy the complete source.',
        '',
        '## Source statistics',
        '',
        u'- Source path: `{0}`'.format(source_audit['source_path']),
        u'- Encoding: {0}'.format(source_audit['encoding']),
        u'- Bytes: {0}'.format(source_audit['source_bytes']),
        u'- Lines: {0}'.format(source_audit['source_line_count']),
        u'- Decoded characters excluding newlines: {0}'.format(source_audit['decoded_characters_without_newlines']),
        u'- User-stated character count: {0}'.format(source_audit['user_stated_characters']),
        u'- Existing raw index rows: {0}'.format(source_audit['raw_index_rows']),
        u'- Reparsed heading candidates: {0}'.format(source_audit['parsed_heading_candidates']),
        u'- Duplicate section numbers: {0}'.format(source_audit['duplicate_section_numbers']),
        u'- Sequence runs: {0}'.format(source_audit['sequence_runs']),
        u'- Rows requiring review: {0}'.format(source_audit['review_required_rows']),
        '',
        '## Rules',
        '',
        '- Keep every recognizable section-heading candidate; never delete a duplicate silently.',
        '- Mark site, author, page, and directory candidates in noise_flags instead of treating them as clean story facts.',
        '- Mark only a clean, strictly increasing run of at least three candidates as canonical_candidate=true.',
        '- Keep duplicates, gaps, decreases, and noisy rows as review_required=true until an editor approves a source range.',
        '',
        '## Sequence runs',
        '',
        '| Run | Count | First line | Last line | First section | Last section | Canonical candidates | Review rows |',
        '| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |',
    ]
    for run in run_summary:
        md.append('| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} |'.format(
            run['sequence_run'], run['count'], run['first_source_line'], run['last_source_line'],
            run['first_section'], run['last_section'], run['canonical_candidates'], run['review_required']))
    md += [
        '',
        '## Raw index comparison',
        '',
        u'- Reparsed lines absent from the existing raw index: {0}'.format(len(missing_from_raw)),
        u'- Existing raw-index lines not reparsed by this script: {0}'.format(len(raw_only)),
        '',
        '## Manual review boundary',
        '',
        '- canonical_candidate=true is a candidate only, not a final volume or arc boundary.',
        '- Later outlines may cite only source ranges that have been manually approved from source context.',
        '- Computed source statistics and the user-stated character count are kept as separate values.',
        '',
    ]
    write_utf8_bom(audit_markdown_path, os.linesep.join(md))

    print_console(json.dumps(source_audit, ensure_ascii=False))


if __name__ == '__main__':
    main()
