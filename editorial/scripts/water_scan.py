# -*- coding: utf-8 -*-
"""文学层水分扫描（示范）：段落级压缩候选，输出 working/water-candidates-<卷>-<批次>.tsv/.md。
规则（均限定纯叙述句，跳过对话/标题/空行）：
  repetitive-claim 同节内非相邻近义句对（相似度>=0.75，句长>=12，间隔>=2行）
  expo-block       连续>=5个非空叙述行（每行>=10字，整块无引号）：议论/环境/过程堆叠
  scene-pile       连续>=3行场景词密集且无引号：环境复写（不 break，报告全部）
用法：py -3 scripts/water_scan.py -Volume vol3 -Batch 121-150
"""
import io
import os
import re
import sys
from difflib import SequenceMatcher

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gu_tools import PsArgs, repo_abs
from scan_candidates import resolve_volume_dir, RE_SECTION_HEAD, find_section

FIELDS = ['seq', 'type', 'severity', 'section', 'line_start', 'line_end', 'sample', 'rule']
RE_SENT = re.compile(u'[^。！？…]+[。！？…]')
SCENE_VOCAB = u'风月云雪山光天雾气露霜星潮草木花石水树影'
RE_SPECTATE = re.compile(u'(吸引|引起|牵动|汇聚).{0,6}(关注|注目|围观|目光|视线)|无数.{0,8}(围观|目光|注目)|(众人|所有人|全场|在场).{0,6}(目光|视线|目光齐)|密切关注')


def spectate_lines(lines, out):
    """机械围观反应：不改变状态、只复述场面的围观句。"""
    for i, line in enumerate(lines, 1):
        s = line.strip()
        if not s or RE_SECTION_HEAD.match(s):
            continue
        if RE_SPECTATE.search(s):
            out.append({
                'type': 'literary', 'severity': 'C',
                'section': find_section(lines, i - 1),
                'line_start': i, 'line_end': i,
                'sample': s[:200],
                'rule': 'spectate 机械围观'})

def sentences_of(line):
    s = line.strip()
    if not s or RE_SECTION_HEAD.match(s):
        return []
    if u'“' in s or u'”' in s or u'‘' in s or u'’' in s or u'：' in s:
        return []
    return [x.strip() for x in RE_SENT.findall(s) if len(x.strip()) >= 12]


def repetitive_claims(lines, out):
    by_section = {}
    for i, line in enumerate(lines, 1):
        sec = find_section(lines, i - 1)
        if sec == 0:
            continue
        for s in sentences_of(line):
            by_section.setdefault(sec, []).append((i, s))
    for sec, items in by_section.items():
        for a in range(len(items)):
            for b in range(a + 1, len(items)):
                la, sa = items[a]
                lb, sb = items[b]
                if lb - la < 2:
                    continue
                if SequenceMatcher(None, sa, sb).ratio() >= 0.75:
                    out.append({
                        'type': 'literary', 'severity': 'C', 'section': sec,
                        'line_start': lb, 'line_end': lb,
                        'sample': (sa[:40] + u' // ' + sb[:100])[:200],
                        'rule': u'repetitive-claim 相似度{0:.2f}'.format(
                            SequenceMatcher(None, sa, sb).ratio())})


def expo_blocks(lines, out):
    """连续 >=5 个非空叙述行（空行不中断）为议论/过程堆叠候选。"""
    n = len(lines)
    start = None
    block_rows = 0
    for i in range(n):
        s = lines[i].strip()
        if not s:
            continue
        valid = (len(s) >= 10 and not RE_SECTION_HEAD.match(s)
                 and not (u'“' in s or u'”' in s or u'‘' in s or u'’' in s))
        if valid:
            if start is None:
                start = i
            block_rows += 1
        else:
            if start is not None and block_rows >= 5:
                out.append({
                    'type': 'literary', 'severity': 'C',
                    'section': find_section(lines, start),
                    'line_start': start + 1, 'line_end': i,
                    'sample': u' '.join(x.strip() for x in lines[start:i + 1])[:200],
                    'rule': u'expo-block {0}行'.format(block_rows)})
            start = None
            block_rows = 0
    if start is not None and block_rows >= 5:
        out.append({
            'type': 'literary', 'severity': 'C',
            'section': find_section(lines, start),
            'line_start': start + 1, 'line_end': n,
            'sample': u' '.join(x.strip() for x in lines[start:n])[:200],
            'rule': u'expo-block {0}行'.format(block_rows)})


def scene_piles(lines, out):
    """连续 >=3 个非空行场景词密集（空行不中断）：环境复写。"""
    n = len(lines)
    start = None
    block_rows = 0
    for i in range(n):
        s = lines[i].strip()
        if not s:
            continue
        dense = (len(s) >= 8 and not RE_SECTION_HEAD.match(s)
                 and not (u'“' in s or u'”' in s or u'‘' in s or u'’' in s)
                 and sum(1 for ch in SCENE_VOCAB if ch in s) >= 2)
        if dense:
            if start is None:
                start = i
            block_rows += 1
        else:
            if start is not None and block_rows >= 3:
                out.append({
                    'type': 'literary', 'severity': 'C',
                    'section': find_section(lines, start),
                    'line_start': start + 1, 'line_end': i,
                    'sample': u' '.join(x.strip() for x in lines[start:i + 1])[:200],
                    'rule': u'scene-pile {0}行'.format(block_rows)})
            start = None
            block_rows = 0
    if start is not None and block_rows >= 3:
        out.append({
            'type': 'literary', 'severity': 'C',
            'section': find_section(lines, start),
            'line_start': start + 1, 'line_end': n,
            'sample': u' '.join(x.strip() for x in lines[start:n])[:200],
            'rule': u'scene-pile {0}行'.format(block_rows)})


def main():
    args = PsArgs(specs=[('Volume', 'string'), ('Batch', 'string')])
    vol = args.get('Volume')
    batch = args.get('Batch')
    if not vol or not batch:
        raise SystemExit('Usage: -Volume vol3 -Batch 121-150')
    vdir = resolve_volume_dir(vol)
    path = os.path.join(vdir, u'{0}-sec{1}.edited.txt'.format(vol, batch))
    with io.open(path, 'r', encoding='utf-8-sig') as fh:
        lines = fh.read().splitlines()
    out = []
    repetitive_claims(lines, out)
    expo_blocks(lines, out)
    scene_piles(lines, out)
    spectate_lines(lines, out)
    out.sort(key=lambda c: (c['section'], c['line_start']))
    for idx, c in enumerate(out, 1):
        c['seq'] = idx
    base = repo_abs(u'working/water-candidates-{0}-{1}'.format(vol, batch))
    with io.open(base + '.tsv', 'w', encoding='utf-8-sig', newline='') as fh:
        fh.write(u','.join(FIELDS) + u'\n')
        for c in out:
            fh.write(u','.join(str(c.get(k) or '') for k in FIELDS) + u'\n')
    with io.open(base + '.md', 'w', encoding='utf-8', newline='') as fh:
        fh.write(u'# 文学层水分候选（示范；人工判断后才可动正文）\n\n')
        for c in out:
            fh.write(u'### [seq {0}] 节{1} 行 {2}-{3} · {4}\n'.format(
                c['seq'], c['section'], c['line_start'], c['line_end'], c['rule']))
            fh.write(u'原文：{0}\n\n'.format(c['sample']))
    print(u'water candidates: {0} -> {1}.tsv'.format(len(out), base))


if __name__ == '__main__':
    main()
