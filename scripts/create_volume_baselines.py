# -*- coding: utf-8 -*-
"""从完整源文中按批次拆分并清洗生成卷级基线，同时输出节-源行映射 CSV。
对齐 create_volume_baselines.ps1；清洗复用 create_edited_baseline.clean_lines（原 ps1 子进程调用改为进程内调用）。"""
import io
import json
import os
import re
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gu_tools import PsArgs, repo_abs, repo_path, read_source_lines, chinese_section_number, write_utf8_no_bom, write_csv_utf8_bom
import create_edited_baseline as baseline


def load_volume_config(volume_id):
    config_path = repo_path('config\\editorial-volumes.json')
    with io.open(config_path, 'r', encoding='utf-8-sig') as fh:
        volume_config = json.load(fh)
    vol_cfg = next((v for v in volume_config['volumes'] if v['id'] == volume_id), None)
    if not vol_cfg:
        raise SystemExit('Unknown volume id: {0}'.format(volume_id))
    return int(vol_cfg['sectionCount'])

BODY = chr(0x6B63) + chr(0x6587)       # 正文
ORDINAL = chr(0x7B2C)                  # 第
SECTION = chr(0x8282)                  # 节
FULL_COLON = chr(0xFF1A)               # ：
HEADING_PATTERN = re.compile(r'^' + BODY + ' ' + ORDINAL + r'(.{1,12})' + SECTION + r'(?:[' + FULL_COLON + r':]|\s{2,})')
HEADING_CORE = re.compile(r'^' + BODY + ' ' + ORDINAL + r'(.{1,12})' + SECTION)
BATCH_PATTERN = re.compile(r'^(\d{3})-(\d{3})$')


def main():
    args = PsArgs(specs=[
        ('SourcePath', 'string'),
        ('StartLine', 'int'),
        ('EndLine', 'int'),
        ('OutputDirectory', 'string'),
        ('VolumeId', 'string'),
        ('VolumeTitle', 'string'),
        ('Batches', 'string[]'),
        ('ExcludeRanges', 'string[]'),
    ], defaults={'ExcludeRanges': []})
    source = repo_abs(args.require('SourcePath'))
    start_line = args.require('StartLine')
    end_line = args.require('EndLine')
    output_dir = repo_abs(args.require('OutputDirectory'))
    volume_id = args.require('VolumeId')
    volume_title = args.require('VolumeTitle')
    batches = args.require('Batches')
    exclude_ranges = args.get('ExcludeRanges')

    all_lines = read_source_lines(source)
    excluded = set()
    for range_text in exclude_ranges:
        m = re.match(r'^(\d+)-(\d+)$', range_text)
        if not m:
            raise SystemExit('Invalid exclusion range: {0}'.format(range_text))
        excluded.update(range(int(m.group(1)), int(m.group(2)) + 1))

    canonical = [{'SourceLine': ln, 'Text': all_lines[ln - 1]}
                 for ln in range(start_line, end_line + 1) if ln not in excluded]

    headings = [row for row in canonical if HEADING_PATTERN.match(row['Text'])]
    section_count = load_volume_config(volume_id)
    if len(headings) != section_count:
        raise SystemExit('Expected {0} canonical headings; found {1}'.format(section_count, len(headings)))

    heading_rows = []
    for row in headings:
        m = HEADING_CORE.match(row['Text'])
        heading_rows.append({
            'Number': chinese_section_number(m.group(1)),
            'SourceLine': row['SourceLine'],
            'Text': row['Text'],
        })
    expected = list(range(1, section_count + 1))
    if [r['Number'] for r in heading_rows] != expected:
        raise SystemExit('Canonical section numbers are not continuous 1-{0}.'.format(section_count))

    os.makedirs(output_dir, exist_ok=True)
    by_number = {r['Number']: r for r in heading_rows}
    with tempfile.TemporaryDirectory(prefix='editorial-') as temp_root:
        for batch in batches:
            m = BATCH_PATTERN.match(batch)
            if not m:
                raise SystemExit('Invalid batch: {0}'.format(batch))
            first, last = int(m.group(1)), int(m.group(2))
            start_source = by_number[first]['SourceLine']
            next_row = by_number.get(last + 1)
            end_source = next_row['SourceLine'] - 1 if next_row else end_line
            batch_lines = [row['Text'] for row in canonical
                           if start_source <= row['SourceLine'] <= end_source]
            temp = os.path.join(temp_root, '{0}-sec{1}.cp936.txt'.format(volume_id, batch))
            with open(temp, 'w', encoding='gbk', newline='') as fh:
                fh.write('\n'.join(batch_lines))
            output = os.path.join(output_dir, '{0}-sec{1}.edited.txt'.format(volume_id, batch))
            result = baseline.clean_lines(batch_lines)
            result[2] = volume_title
            write_utf8_no_bom(output, '\n'.join(result))

    write_csv_utf8_bom(os.path.join(output_dir, '{0}-section-source-map.csv'.format(volume_id)),
                       [{'Number': r['Number'], 'SourceLine': r['SourceLine'], 'Text': r['Text']} for r in heading_rows])


if __name__ == '__main__':
    main()
