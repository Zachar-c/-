# -*- coding: utf-8 -*-
"""《蛊真人》编辑资产校验：阶段 baseline/outline/detail/final，检查跟踪边界、UTF-8、CSV、编辑文本、细纲标题与批次。
对齐 validate_editorial_assets.ps1，退出码 0=通过。"""
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gu_tools import PsArgs, REPO_ROOT, git_ls_files, chinese_number

PHASES = ('baseline', 'outline', 'detail', 'final')
RE_BATCH_RANGE = re.compile(r'^(\d{3})-(\d{3})$')
NOISE_MARKERS = [
    chr(0x7AD9) + chr(0x70B9),          # 站点
    chr(0x4F5C) + chr(0x8005) + chr(0x6309) + chr(0x8BED),  # 作者按语
    chr(0x6253) + chr(0x8D4F),          # 打赏
    chr(0x63A8) + chr(0x8350) + chr(0x7968),  # 推荐票
    chr(0x6708) + chr(0x7968),          # 月票
    chr(0x8BF7) + chr(0x6536) + chr(0x85CF),  # 请收藏
    chr(0x624B) + chr(0x673A) + chr(0x7528) + chr(0x6237),  # 手机用户
    'CTRL+D',
    '<dd>',
    '</dd>',
    chr(0x672A) + chr(0x5B8C) + chr(0x5F85) + chr(0x7EED),  # 未完待续
]
MAX_PARAGRAPH_LENGTH = 500
RE_DETAIL_HEADING = re.compile(r'(?m)^#{2,3}\s+\u7B2C\s*(\d+)\s*\u8282[\uFF1A:]')
RE_EDITED_HEADING = re.compile(r'(?m)^\u7B2C([\u96F6\u4E00\u4E8C\u4E09\u56DB\u4E94\u516D\u4E03\u516B\u4E5D\u5341\u767E]+)\u8282(?:[\uFF1A:]|\s+(?!\u8BFE))')
RE_OUTLINE_REF = re.compile(r'\]\(([^)#]+)\)')


def parse_batch_range(spec, errors):
    """解析 '001-030' 为 (1, 30)；非法时记入 errors 并返回 None。"""
    m = RE_BATCH_RANGE.match(spec)
    if not m:
        errors.append('Invalid batch range spec "{0}"; expected DDD-DDD'.format(spec))
        return None
    return int(m.group(1)), int(m.group(2))


def strict_utf8(path, errors):
    try:
        with io.open(path, 'r', encoding='utf-8', newline='') as fh:
            fh.read()
        return True
    except UnicodeDecodeError:
        errors.append('Invalid UTF-8: {0}'.format(path))
        return False


def main():
    args = PsArgs(specs=[
        ('Phase', 'string'),
        ('RepoRoot', 'string'),
        ('Volume', 'string[]'),
        ('Batch', 'string'),
    ], defaults={
        'Phase': 'baseline',
        'RepoRoot': REPO_ROOT,
        'Volume': ['vol1'],
    })
    phase = args.get('Phase')
    if phase not in PHASES:
        raise SystemExit('Invalid phase: {0}. Valid: {1}'.format(phase, ', '.join(PHASES)))
    repo_root = os.path.abspath(args.get('RepoRoot'))
    volumes = args.get('Volume')
    batch_spec = args.get('Batch')
    batch_range = parse_batch_range(batch_spec, []) if batch_spec else None
    if batch_spec and batch_range is None:
        raise SystemExit('Invalid -Batch value: {0}; expected DDD-DDD (e.g. 091-120)'.format(batch_spec))

    errors = []
    config_path = os.path.join(repo_root, 'config', 'editorial-volumes.json')
    if not os.path.isfile(config_path):
        raise SystemExit('Missing editorial volume configuration: {0}'.format(config_path))
    with io.open(config_path, 'r', encoding='utf-8-sig') as fh:
        volume_config = json.load(fh)
    known_volume_ids = [v['id'] for v in volume_config['volumes']]
    if 'all' in volumes:
        volumes = list(known_volume_ids)
    unknown = [v for v in volumes if v not in known_volume_ids]
    if unknown:
        raise SystemExit('Unknown volume id(s): {0}. Known ids: {1}'.format(
            ', '.join(unknown), ', '.join(known_volume_ids)))
    selected_volumes = [v for v in volume_config['volumes'] if v['id'] in volumes]

    def repo_path(relative):
        return os.path.join(repo_root, relative)

    def test_required_file(relative):
        if not os.path.isfile(repo_path(relative)):
            errors.append('Missing required file: {0}'.format(relative))
            return False
        return True

    # Test-TrackedSourceBoundary
    allowlist = set(volume_config.get('trackedSourceAllowlist', []))
    for path in git_ls_files(repo_root):
        if path in allowlist:
            continue
        leaf = path.split('/')[-1]
        if re.match(r'^(source|complete|full).*(txt|docx?|pdf)$', leaf):
            errors.append('Complete-source copy appears tracked: {0}'.format(path))

    # Test-TrackedUtf8Assets
    for relative in git_ls_files(repo_root):
        if re.search(r'\.(md|csv|edited\.txt)$', relative):
            path = repo_path(relative)
            if os.path.isfile(path):
                strict_utf8(path, errors)

    # Test-CsvAssets
    import csv
    for relative in git_ls_files(repo_root, '*.csv'):
        path = repo_path(relative)
        try:
            with io.open(path, 'r', encoding='utf-8-sig', newline='') as fh:
                reader = csv.reader(fh)
                header = next(reader, None)
                for _ in reader:
                    pass
            if header is None or ',' not in ','.join(header or []):
                errors.append('CSV has no comma-delimited header: {0}'.format(relative))
        except Exception as exc:
            errors.append('CSV cannot be imported: {0}; {1}'.format(relative, exc))

    # Test-EditedText
    volume_root = repo_path('volumes')
    edited_files = []
    if os.path.isdir(volume_root):
        for dirpath, _, filenames in os.walk(volume_root):
            for name in filenames:
                if name.endswith('.edited.txt'):
                    edited_files.append(os.path.join(dirpath, name))
    for file_path in edited_files:
        with io.open(file_path, 'r', encoding='utf-8', newline='') as fh:
            content = fh.read()
        for marker in NOISE_MARKERS:
            if marker in content:
                errors.append('Edited text contains forbidden noise marker "{0}": {1}'.format(marker, file_path))
        lines = content.splitlines()
        for index, line in enumerate(lines):
            if len(line) > MAX_PARAGRAPH_LENGTH:
                errors.append('Edited text has an overlong paragraph ({0} chars) at {1}:{2}'.format(
                    len(line), file_path, index + 1))

    # outline/detail/final shared requirements
    if phase in ('outline', 'detail', 'final'):
        test_required_file('outlines/README.md')
        test_required_file('notes/fact-disputes.csv')
        test_required_file('scripts/validate_editorial_assets.ps1')
    if phase in ('outline', 'detail', 'final'):
        test_required_file('outlines/00-full-book-outline.md')

    if phase in ('detail', 'final'):
        batch_lo, batch_hi = (parse_batch_range(batch_spec, []) if batch_spec else (None, None))
        for volume in selected_volumes:
            batches = volume['batches']
            if batch_lo is not None:
                batches = [b for b in batches if parse_batch_range(b['range'], []) == (batch_lo, batch_hi)]
                if not batches:
                    errors.append('{0} has no batch matching -Batch {1}'.format(volume['id'], batch_spec))
            for batch in batches:
                test_required_file('outlines/detail/{0}-sec{1}.md'.format(volume['id'], batch['range']))
            # Test-DetailHeadings（-Batch 时只核对指定批次的细纲内节号区间）
            detail_dir = repo_path('outlines/detail')
            detail_files = []
            if os.path.isdir(detail_dir):
                for name in os.listdir(detail_dir):
                    if re.fullmatch(volume['detailPattern'].replace('.', r'\.').replace('*', '.*'), name) and os.path.isfile(os.path.join(detail_dir, name)):
                        detail_files.append(name)
            if not detail_files:
                errors.append('No detail outline files found for {0}.'.format(volume['id']))
            else:
                if batch_lo is not None:
                    for batch in batches:
                        if not parse_batch_range(batch['range'], []) == (batch_lo, batch_hi):
                            continue
                        path = os.path.join(detail_dir, '{0}-sec{1}.md'.format(volume['id'], batch['range']))
                        if not os.path.isfile(path):
                            continue
                        with io.open(path, 'r', encoding='utf-8', newline='') as fh:
                            content = fh.read()
                        numbers = [int(m.group(1)) for m in RE_DETAIL_HEADING.finditer(content)]
                        if numbers != list(range(batch_lo, batch_hi + 1)):
                            errors.append('{0} detail batch {1} must cover exactly {2}-{3}; found: {4}'.format(
                                volume['id'], batch['range'], batch_lo, batch_hi, ','.join(map(str, numbers))))
                else:
                    section_numbers = []
                    for name in detail_files:
                        with io.open(os.path.join(detail_dir, name), 'r', encoding='utf-8', newline='') as fh:
                            content = fh.read()
                        section_numbers.extend(int(m.group(1)) for m in RE_DETAIL_HEADING.finditer(content))
                    seen = {}
                    for number in section_numbers:
                        seen[number] = seen.get(number, 0) + 1
                    for number, count in seen.items():
                        if count > 1:
                            errors.append('Duplicate detail section: {0}'.format(number))
                    expected = list(range(1, int(volume['sectionCount']) + 1))
                    if sorted(section_numbers) != expected:
                        errors.append('{0} detail sections must cover exactly 1-{1}; found: {2}'.format(
                            volume['id'], volume['sectionCount'], ','.join(map(str, sorted(section_numbers)))))
            # Test-VolumeSectionBatches
            directories = [d for d in os.listdir(volume_root)
                           if os.path.isdir(os.path.join(volume_root, d)) and re.fullmatch(
                               volume['directoryPattern'].replace('.', r'\.').replace('*', '.*'), d)]
            if len(directories) != 1:
                errors.append('Expected exactly one directory for {0}; found: {1}'.format(volume['id'], len(directories)))
            else:
                directory = os.path.join(volume_root, directories[0])
                total = 0
                checked_any = False
                for batch in batches:
                    if batch_lo is not None and not parse_batch_range(batch['range'], []) == (batch_lo, batch_hi):
                        continue
                    file_name = '{0}-sec{1}.edited.txt'.format(volume['id'], batch['range'])
                    path = os.path.join(directory, file_name)
                    if not os.path.isfile(path):
                        errors.append('Missing {0} text batch: {1}'.format(volume['id'], file_name))
                        continue
                    with io.open(path, 'r', encoding='utf-8', newline='') as fh:
                        content = fh.read()
                    headings = list(RE_EDITED_HEADING.finditer(content))
                    count = len(headings)
                    if count != batch['count']:
                        errors.append('Unexpected section count in {0}: expected {1}, found {2}'.format(
                            file_name, batch['count'], count))
                    if batch_lo is not None:
                        lo, hi = parse_batch_range(batch['range'], [])
                        numbers = [chinese_number(m.group(1)) for m in headings]
                        if numbers != list(range(lo, hi + 1)):
                            errors.append('Section numbers in {0} must be strictly {1}-{2} in order; found: {3}'.format(
                                file_name, lo, hi, ','.join(map(str, numbers))))
                        checked_any = True
                    total += count
                if batch_lo is not None and not checked_any:
                    errors.append('-Batch {0} matches no {1} text batch'.format(batch_spec, volume['id']))
                elif batch_lo is None and total != int(volume['sectionCount']):
                    errors.append('{0} text must contain exactly {1} section headings; found: {2}'.format(
                        volume['id'], volume['sectionCount'], total))

    if phase in ('outline', 'detail', 'final'):
        # Test-OutlineReferences
        outlines_root = repo_path('outlines')
        if os.path.isdir(outlines_root):
            for dirpath, _, filenames in os.walk(outlines_root):
                for name in filenames:
                    if not name.endswith('.md'):
                        continue
                    full = os.path.join(dirpath, name)
                    with io.open(full, 'r', encoding='utf-8', newline='') as fh:
                        content = fh.read()
                    for m in RE_OUTLINE_REF.finditer(content):
                        target = m.group(1)
                        if re.match(r'^(https?|mailto):', target):
                            continue
                        if not os.path.exists(os.path.join(dirpath, target)):
                            errors.append('Broken outline reference in {0}: {1}'.format(full, target))

    # source audit JSON parses
    source_audit_path = repo_path('index/source-audit.json')
    if os.path.isfile(source_audit_path):
        try:
            with io.open(source_audit_path, 'r', encoding='utf-8-sig') as fh:
                json.load(fh)
        except Exception as exc:
            errors.append('Source audit JSON cannot be parsed: {0}'.format(exc))

    if errors:
        print('', file=sys.stderr)
        for message in errors:
            print('- ' + message, file=sys.stderr)
        sys.exit(1)

    print('Editorial asset validation passed: phase={0}; volume={1}'.format(phase, ','.join(volumes)))
    sys.exit(0)


if __name__ == '__main__':
    main()
