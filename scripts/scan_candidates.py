# -*- coding: utf-8 -*-
"""全书候选扫描：A/B/C 三级规则+清单输出（词表/乱码遮蔽/重复/数字混用/作者越位/网络词/场景复写）。"""
import io
import json
import os
import re
import sys
from difflib import SequenceMatcher

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


def scan(lines):
    """对外扫描入口：组合三层规则全部候选。"""
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


RE_UNKNOWN_CHAR = re.compile(u'[\ufffd\uf8ff\ue000-\uf8ff]')
RE_REDACT = re.compile(r'\[\*\*\*\]|\*\*')


def mech_rules(lines):
    out = []
    for i, line in enumerate(lines, 1):
        section = find_section(lines, i - 1)
        for old, new in CONFIRMED_FIXES:
            if old in line:
                out.append(build_candidate('mech', 'A', section, i, i,
                                           line.strip()[:120], 'wordlist', ''))
        if RE_UNKNOWN_CHAR.search(line):
            out.append(build_candidate('mech', 'B', section, i, i,
                                       line.strip()[:120], 'mojibake', ''))
        if RE_REDACT.search(line):
            out.append(build_candidate('mech', 'B', section, i, i,
                                       line.strip()[:120], 'redact', ''))
    return out


CHINESE_NUM = {u'零': '0', u'一': '1', u'二': '2', u'三': '3', u'四': '4',
               u'五': '5', u'六': '6', u'七': '7', u'八': '8', u'九': '9'}
UNIT_WORDS = re.compile(u'[块元石转成级年月日两岁]')


def semantic_rules(lines):
    out = []
    for i, line in enumerate(lines, 1):
        section = find_section(lines, i - 1)
        prev = lines[i - 2] if i > 1 else u''
        if len(line) >= 12 and len(prev) >= 12:
            ratio = SequenceMatcher(None, prev, line).ratio()
            if ratio >= 0.8:
                out.append(build_candidate('semantic', 'B', section, i - 1, i - 1,
                                           prev.strip()[:120], 'repeat',
                                           u'相似度{0:.2f}'.format(ratio)))
        compact = re.sub(r'\s+', '', line)
        han = set(re.findall(u'[一二三四五六七八九]+' + UNIT_WORDS.pattern + u'+', compact))
        arab = set(re.findall(u'[0-9]+' + UNIT_WORDS.pattern + u'+', compact))
        if han and arab:
            out.append(build_candidate('semantic', 'B', section, i, i,
                                       line.strip()[:120], 'num-mix',
                                       u'中文数字与阿拉伯数字混用'))
    return out


NETWORK_WORDS = [u'妥妥的', u'刷屏', u'热搜', u'流量', u'点赞', u'评论区', u'666', u'吐槽', u'打卡']
RE_SCENE_SENT = re.compile(u'[。！？]')
SCENE_VOCAB = u'风月云雪山光天雾气露霜星潮草木花石水树影'


def literary_rules(lines):
    out = []
    n = len(lines)
    for i, line in enumerate(lines, 1):
        section = find_section(lines, i - 1)
        stripped = line.strip()
        if re.match(u'^(?:写到这里|说到这里|笔者|作者|本书|各位读者|读者)', stripped):
            out.append(build_candidate('literary', 'C', section, i, i,
                                       stripped[:90], 'author-speak', ''))
        for w in NETWORK_WORDS:
            if w in line:
                out.append(build_candidate('literary', 'C', section, i, i,
                                           stripped[:90], 'network-word', u'词={0}'.format(w)))
    for start in range(0, n - 2):
        chunk = lines[start:start + 4]
        if _all_scene(chunk):
            out.append(build_candidate('literary', 'C', find_section(lines, start),
                                       start + 1, start + 1,
                                       u' '.join(x.strip() for x in chunk)[:200],
                                       'scene-repetition', ''))
            break
    return out


def _all_scene(chunk):
    for line in chunk:
        s = line.strip()
        if not s or not RE_SCENE_SENT.search(s):
            return False
        if re.search(u'[“”‘’：]', s):
            return False
        if sum(1 for ch in SCENE_VOCAB if ch in s) < 2:
            return False
    return True


def scan_rules(lines):
    return mech_rules(lines) + semantic_rules(lines) + literary_rules(lines)


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