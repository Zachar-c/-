# -*- coding: utf-8 -*-
"""从 CP936 源文构建章节索引（metadata/headings/摘要 CSV+JSON）。对齐 build_index.ps1。"""
import io
import json
import os
import re
import sys
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gu_tools import PsArgs, repo_abs, chinese_number, write_json, write_csv_utf8_bom

HEADING_PATTERN = re.compile(
    r'^\s*(?:\u6B63\u6587\s*)?\u7B2C([\u96F6\u3007\u4E00\u4E8C\u4E24\u4E09\u56DB\u4E94\u516D\u4E03\u516B\u4E5D\u5341\u767E\u5343\u4E07\d]+)\u8282[\uFF1A:]\s*(.+?)\s*$')

RE_AUTHOR_PS = re.compile(r'[\uFF08(]\s*(?:ps|PS)\s*[:\uFF1A]|\u4F5C\u8005|\u672A\u5B8C\u5F85\u7EED')


def noise_flags(line, title):
    text = u'{0} {1}'.format(line, title)
    flags = []
    if re.search(u'\u76EE\u5F55|\u7AE0\u8282\u76EE\u5F55', text):
        flags.append('directory')
    if re.search(u'\u4F5C\u8005|\u4F5C\u5BB6|\u5377\u672B\u611F\u8A00|\u5B8C\u672C\u611F\u8A00|\u65B0\u4E66|\u66F4\u65B0|\u8BA2\u9605|\u6708\u7968|\u63A8\u8350\u7968|\u672A\u5B8C\u5F85\u7EED|\uFF08?\\s*(?:ps|PS)\\s*[:\uFF1A]', text):
        flags.append('author_or_site')
    if re.search(u'www\\.|http://|https://|\u624B\u673A\u7528\u6237|\u8BF7\u6536\u85CF|\u7CBE\u5F69\u9605\u8BFB|</?\\w+[^>]*>', text):
        flags.append('site_markup')
    return ';'.join(flags)


def main():
    args = PsArgs(specs=[
        ('SourcePath', 'string'),
        ('OutputDirectory', 'string'),
    ])
    source = repo_abs(args.require('SourcePath'))
    output_dir = repo_abs(args.require('OutputDirectory'))
    os.makedirs(output_dir, exist_ok=True)

    with io.open(source, 'r', encoding='gbk', newline='') as fh:
        lines = fh.read().splitlines()

    all_text_characters = 0
    han_characters = 0
    non_empty_lines = 0
    heading_records = []
    for index, line in enumerate(lines):
        all_text_characters += len(line)
        han_characters += len(re.findall(u'[\u3400-\u4DBF\u4E00-\u9FFF]', line))
        if line.strip():
            non_empty_lines += 1
        m = HEADING_PATTERN.match(line)
        if m:
            heading_records.append({
                'heading_id': len(heading_records) + 1,
                'line': index + 1,
                'number_text': m.group(1),
                'number': chinese_number(m.group(1)),
                'title': m.group(2).strip(),
                'flags': noise_flags(line, m.group(2)),
            })

    for index, record in enumerate(heading_records):
        next_line = heading_records[index + 1]['line'] if index + 1 < len(heading_records) else len(lines) + 1
        start, end = record['line'], next_line - 1
        content_characters = 0
        contains_author_ps = False
        for line_index in range(start, next_line):
            if line_index > len(lines):
                break
            content_characters += len(lines[line_index - 1])
            if RE_AUTHOR_PS.search(lines[line_index - 1]):
                contains_author_ps = True
        record['end_line'] = end
        record['content_characters'] = content_characters
        record['contains_author_ps'] = contains_author_ps

    title_groups = {}
    for record in heading_records:
        title_groups.setdefault(record['title'], []).append(record)
    for group in title_groups.values():
        is_duplicate = len(group) > 1
        for record in group:
            record['duplicate_title'] = is_duplicate

    metadata = {
        'source_path': os.path.abspath(source),
        'source_bytes': os.path.getsize(source),
        'encoding': 'CP936 / GBK',
        'line_count': len(lines),
        'non_empty_lines': non_empty_lines,
        'decoded_characters_without_newlines': all_text_characters,
        'han_characters': han_characters,
        'user_stated_characters': 14577005,
        'heading_hits': len(heading_records),
        'generated_at': datetime.now().strftime('%Y-%m-%dT%H:%M:%S'),
    }

    write_json(os.path.join(output_dir, 'source-metadata.json'), metadata)
    write_csv_utf8_bom(os.path.join(output_dir, 'chapter-headings.csv'), heading_records)
    write_json(os.path.join(output_dir, 'chapter-headings.json'), heading_records)

    by_number = {}
    for record in heading_records:
        by_number.setdefault(record['number'], []).append(record)
    summary = []
    for number in sorted(by_number):
        group = sorted(by_number[number], key=lambda r: r['line'])
        summary.append({
            'number': number,
            'occurrences': len(group),
            'first_line': group[0]['line'],
            'first_title': group[0]['title'],
            'last_line': group[-1]['line'],
        })
    write_csv_utf8_bom(os.path.join(output_dir, 'chapter-number-summary.csv'), summary)

    print(json.dumps(metadata, ensure_ascii=False))


if __name__ == '__main__':
    main()
