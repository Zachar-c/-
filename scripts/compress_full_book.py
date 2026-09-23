# -*- coding: utf-8 -*-
"""《蛊真人》全书快速压缩（过场压缩·保护高潮/设定/弧光/人祖传）。

作用：以蛊真人-clean.txt 为唯一底本，机械、确定性地压缩全书的过渡/水分内容，
按剧情节点合并为若干章（默认 450 章），产出压缩全本与统计报告。

压缩边界（只压过场，不碰核心）：
  必删（安全过场/残留）：网页残留、章节目录、更新求票、机械围观、场景复写、
      同节内重复宣判、纯过渡时间/赶路句、爬虫重复章节。
  必保：节标题、所有含引号的对话、每节首尾段落、《人祖传》及世界观设定词行、
      含数字（元石/数量/境界）的叙述行。

用法：py -3 scripts/compress_full_book.py
      [-Source 蛊真人-clean.txt] [-Chapters 450] [-OutDir working/full-compress]
      [-MinReduction 0.30] [-DryRun]

输出：压缩全本 txt、压缩报告 md。
"""
import os
import re
import sys
from difflib import SequenceMatcher

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gu_tools import PsArgs, repo_abs, write_utf8_no_bom, write_utf8_bom, read_utf8

RE_SECTION_HEAD = re.compile(r'^\s*第\s*[一二三四五六七八九十百千0-9]+\s*节\s*[:：]?\s*\S')

QUOTE_CHARS = u'“”‘’「」『』"' + u'\u2018\u2019\u201c\u201d'

RE_SPECTATE = re.compile(
    u'(吸引|引起|牵动|汇聚).{0,6}(关注|注目|围观|目光|视线)|无数.{0,8}(围观|目光|注目)'
    u'|(众人|所有人|全场|在场).{0,6}(目光|视线)|密切关注')

SCENE_VOCAB = u'风月云雪山光天雾气露霜星潮草木花石水树影'

RE_SETTINGS = re.compile(
    u'尊者|仙尊|魔尊|传人|传承|真传|秘辛|秘闻|流派|境界|福地|洞天|仙窍|天庭|长生天|'
    u'宿命|天意|命运|春秋蝉|光阴长河|生死门|平凡深渊|秘禁|太古|远古|上古|中古|'
    u'人祖传|人祖|盗天|巨阳|元莲|星宿|元始|红莲|无极|狂蛮|长毛|荡魂山|至尊|蛊道|'
    u'仙蛊|蛊方|蛊虫|杀招|大阵|阵图|道痕|寿蛊|异兽|荒兽|五域|中洲|北原|南疆|西漠|'
    u'东海|逆流河|大势|大世|乱世|一转|二转|三转|四转|五转|六转|七转|八转|九转')

RE_RESIDUE_LINE = re.compile(
    u'^(章节目录|新章节目录|小提示|第一卷|第二卷|第三卷|第四卷|第五卷|第六卷|本章完|'
    u'大结局|求订阅|求月票|求推荐|推荐票|加更|爆更|三更|二更|万更|双更|书友Q|'
    u'欢迎来到|如果喜欢|各位书友|请订阅|请收藏|点击收藏|推荐给|书评|评论区|打赏|'
    u'正版|笔趣阁|网址|https|www|QQ群|加群|群号|微信公众号|微博|连载中|已完本|'
    u'往期|回顾|目录|返回|上一章|下一章|加入书架|点击下一页)')

RE_RESIDUE_INLINE = re.compile(r'第\s*\d+\s*/\s*\d+\s*页|第\s*[一二三四五六七八九十]+\s*页|\(全本\)|（全本）|未完待续|待续')

RE_TRANSIT = re.compile(
    u'^(过了|数日|数天|数十日|几日|几天|数月|数年后|时日|不久|片刻|很快|随即|'
    u'随后|接着|而后|于是|转瞬|眨眼|不知不觉|时间流逝|日子|光阴|岁月|一路|前行|'
    u'赶路|启程|出发|离开|返回|回家|入城|出城|到达|抵达|来到|前往|走向|'
    u'路过|途中|沿路|沿途|快马|日夜兼程|披星戴月|风餐露宿|马不停蹄|'
    u'第二日|第二天|次日|翌日|当天夜里|这天|这日|这一日|这一夜)')


def _has_quote(line):
    return any(c in line for c in QUOTE_CHARS)


def _has_digit(line):
    return any(c.isdigit() for c in line)


def count_visible(lines):
    return sum(len(x) for x in lines)


def find_sections(lines):
    starts = [i for i, l in enumerate(lines) if RE_SECTION_HEAD.match(l)]
    bounds = []
    for k, s in enumerate(starts):
        e = starts[k + 1] if k + 1 < len(starts) else len(lines)
        bounds.append((s, e))
    return bounds


def section_title(lines, start):
    return lines[start].strip().strip(u'\u3000 ')[:40]


def rubber(body):
    return u''.join(b.strip() for b in body if b.strip())


def compress_section(lines, s, e, prot, prof):
    """压缩单节，返回 (kept_lines, stats_delta)。prot: 保护决定（处理残留外全保）。"""
    body_idx = [k for k in range(s, e) if not RE_SECTION_HEAD.match(lines[k])]
    first_body = body_idx[0] if body_idx else s
    last_body = body_idx[-1] if body_idx else s

    kept = []
    stats = {}
    seen = []
    scene_run = 0

    for k in range(s, e):
        line = lines[k]
        st = line.strip()
        if RE_SECTION_HEAD.match(line):
            kept.append(line)
            continue
        if not st:
            kept.append(line)
            continue
        # 首尾段落必保
        if k == first_body or k == last_body:
            kept.append(line)
            continue
        # 对话必保
        if _has_quote(line):
            kept.append(line)
            continue
        # 残留必删（无论是否保护节）
        if RE_RESIDUE_LINE.match(st) or RE_RESIDUE_INLINE.search(line):
            stats['residue'] = stats.get('residue', 0) + len(line)
            continue
        # 保护节：除残留外全保留
        if prot:
            kept.append(line)
            continue
        # 设定/数字必保
        if RE_SETTINGS.search(line) or _has_digit(line):
            kept.append(line)
            continue
        # 机械围观
        if RE_SPECTATE.search(line):
            stats['spectate'] = stats.get('spectate', 0) + len(line)
            continue
        # 场景复写收缩
        thr = prof['scenepile']
        dense = len(st) >= 8 and sum(1 for c in SCENE_VOCAB if c in st) >= 2
        if dense:
            scene_run += 1
            if scene_run > thr:
                stats['scenepile'] = stats.get('scenepile', 0) + len(line)
                continue
        else:
            scene_run = 0
        # 过渡句
        if prof['transit'] and RE_TRANSIT.match(st) and len(st) <= prof['transit_max']:
            stats['transit'] = stats.get('transit', 0) + len(line)
            continue
        # 重复宣判（限窗，避免大节 O(n^2)）
        if prof['repeat'] and len(st) >= 12:
            dup = False
            for pk, p in seen[-prof.get('window', 40):]:
                if abs(len(p) - len(st)) > max(4, len(st) // 2):
                    continue
                if SequenceMatcher(None, p, st).ratio() >= prof['repeat_thr']:
                    dup = True
                    break
            if dup:
                stats['repeat'] = stats.get('repeat', 0) + len(line)
                continue
            seen.append((k, st))
        kept.append(line)

    return kept, stats


def collapse_blanks(kept):
    out = []
    blank = 0
    for line in kept:
        if not line.strip():
            blank += 1
            if blank == 1:
                out.append(line)
        else:
            blank = 0
            out.append(line)
    return out


def main():
    ps = PsArgs(specs=[
        ('Source', 'string'), ('Chapters', 'int'), ('MinReduction', 'string'),
        ('OutDir', 'string'), ('DryRun', 'bool')])
    src = ps.get('Source') or u'蛊真人-clean.txt'
    chapters = ps.get('Chapters', 450)
    try:
        min_red = float(ps.get('MinReduction') or '0.30')
    except (TypeError, ValueError):
        min_red = 0.30
    outdir = ps.get('OutDir') or repo_abs(u'working/full-compress')
    dry = ps.get('DryRun', False)

    lines = read_utf8(repo_abs(src)).split(u'\n')
    bounds = find_sections(lines)
    n = len(bounds)

    # 保护节
    protect = set()
    for i, (s, e) in enumerate(bounds):
        t = section_title(lines, s)
        if u'人祖传' in t or u'祖传' in t:
            protect.add(i)
    if n:
        protect.add(0)
        protect.add(n - 1)

    # 爬虫重复章节
    dupsec_idx = set()
    prev_t = None
    prev_rub = None
    for i, (s, e) in enumerate(bounds):
        t = section_title(lines, s)
        body = [l for l in lines[s:e] if not RE_SECTION_HEAD.match(l)]
        rub = rubber(body)
        if prev_t == t and prev_rub is not None and len(rub) > 0:
            if SequenceMatcher(None, rub, prev_rub).ratio() >= 0.9:
                dupsec_idx.add(i)
        prev_t = t
        prev_rub = rub

    profiles = [
        {'protect': True, 'scenepile': 3, 'transit': True, 'transit_max': 48,
         'repeat': True, 'repeat_thr': 0.85, 'window': 40},
        {'protect': True, 'scenepile': 2, 'transit': True, 'transit_max': 60,
         'repeat': True, 'repeat_thr': 0.82, 'window': 40},
        {'protect': True, 'scenepile': 3, 'transit': True, 'transit_max': 72,
         'repeat': True, 'repeat_thr': 0.80, 'window': 40},
    ]

    in_visible = count_visible(lines)
    chosen = None
    for prof in profiles:
        # 按节压缩，得到每节的保留行（保持顺序）
        sec_kept = []
        stats = {}
        for i, (s, e) in enumerate(bounds):
            if i in dupsec_idx:
                _d = sum(len(l) for l in lines[s:e] if l.strip())
                stats['dupsec'] = stats.get('dupsec', 0) + _d
                sec_kept.append([])
                continue
            seg, sec_stats = compress_section(lines, s, e, i in protect, prof)
            sec_kept.append(seg)
            for kk, vv in sec_stats.items():
                stats[kk] = stats.get(kk, 0) + vv

        flat = [l for seg in sec_kept for l in seg]
        out_visible = count_visible(collapse_blanks(flat))
        red = 1.0 - out_visible / in_visible if in_visible else 0.0
        if red >= min_red or prof is profiles[-1]:
            chosen = (sec_kept, out_visible, red, stats, prof)
            break

    sec_kept, out_visible, red, stats, prof = chosen
    print(u'input  visible : {0}'.format(in_visible))
    print(u'output visible : {0}'.format(out_visible))
    print(u'reduction      : {0:.1%}'.format(red))
    print(u'sections       : {0}   protected: {1}   dupsec: {2}'.format(n, len(protect), len(dupsec_idx)))
    print(u'per-rule drop  : {0}'.format(stats))

    if dry:
        return

    # 合并章节（按节），目标每章字数
    target = out_visible / max(1, chapters)
    chapters_out = []
    cur = []
    cur_chars = 0
    for seg in sec_kept:
        seg_chars = count_visible(seg)
        if cur and cur_chars > 0 and cur_chars + seg_chars > target * 1.5:
            chapters_out.append(cur)
            cur = []
            cur_chars = 0
        cur.extend(seg)
        cur_chars += seg_chars
    if cur:
        chapters_out.append(cur)

    parts = []
    for ci, ch in enumerate(chapters_out, 1):
        fh = next((l for l in ch if RE_SECTION_HEAD.match(l)), u'')
        title = section_title(ch, 0) if ch else u''
        parts.append(u'\n\n{0}\n{1}'.format(
            u'=' * 16 + u' 第 {0:03d} 章 {1} '.format(ci, title) + u'=' * 16,
            u'\n'.join(ch)))
    full = u'\n'.join(parts)
    final_path = os.path.join(outdir, u'蛊真人-压缩全本-{0}章.txt'.format(len(chapters_out)))
    write_utf8_bom(final_path, full)

    report = [
        u'# 全书压缩报告',
        u'',
        u'- 源文件：' + src,
        u'- 原文可见字数：' + str(in_visible),
        u'- 压缩后可见字数：' + str(out_visible),
        u'- 压缩率（减少）：{0:.1%}'.format(red),
        u'- 章节数：' + str(len(chapters_out)),
        u'- 节数：{0}  保护节：{1}  去重节：{2}'.format(n, len(protect), len(dupsec_idx)),
        u'- 使用档位：' + str(prof),
        u'- 分规则删减字符：' + str(stats),
        u'- 输出文件：' + final_path,
    ]
    write_utf8_no_bom(os.path.join(outdir, u'压缩报告.md'), u'\n'.join(report))
    print(u'wrote {0}'.format(final_path))
    print(u'wrote {0}'.format(os.path.join(outdir, u'压缩报告.md')))


if __name__ == '__main__':
    main()