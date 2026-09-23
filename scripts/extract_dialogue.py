# -*- coding: utf-8 -*-
"""《蛊真人》底本对话提取器。

从蛊真人-clean.txt 中按节切分，提取所有含全角引号（“…”）或半角引号（"…"）
的行作为“对话行”，逐节写入输出文件（保留节标题），并输出统计。

用法：
  py -3 scripts/extract_dialogue.py -Source 蛊真人-clean.txt -Out working/dialogue-extract.txt
  -MinQ  仅统计/提取引号对完整的行（默认 True）。
  -StatsOnly 只打印统计，不写正文。
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gu_tools import PsArgs, repo_abs, read_utf8, write_utf8_no_bom

RE_SECTION_HEAD = re.compile(r'^\s*第\s*[一二三四五六七八九十百千0-9]+\s*节\s*[:：]?\s*\S')
# 全角引号：左“ U+201C 右” U+201D；另含 ASCII 双引号
OPEN_Q = u'\u201c'
CLOSE_Q = u'\u201d'


def is_dialogue_line(line, minq=True):
    if CLOSE_Q in line or OPEN_Q in line:
        return True
    if '"' in line:
        return True
    return False


def has_pair(line):
    return (OPEN_Q in line and CLOSE_Q in line) or (line.count('"') >= 2)


def main():
    ps = PsArgs(specs=[
        ('Source', 'string'), ('Out', 'string'), ('MinQ', 'bool'), ('StatsOnly', 'bool')])
    source = ps.get('Source') or u'蛊真人-clean.txt'
    out = ps.get('Out') or repo_abs(u'working/dialogue-extract.txt')
    minq = ps.get('MinQ', True)
    stats_only = ps.get('StatsOnly', False)

    lines = read_utf8(repo_abs(source)).split(u'\n')
    n = len(lines)

    bounds = []
    starts = [i for i, l in enumerate(lines) if RE_SECTION_HEAD.match(l)]
    for k, s in enumerate(starts):
        e = starts[k + 1] if k + 1 < len(starts) else n
        bounds.append((s, e))

    out_lines = []
    n_sec = 0
    n_dialogue = 0
    n_dialogue_chars = 0
    n_dialogue_full = 0  # 含完整引号对的行
    total_visible = 0
    per_sec = []
    for (s, e) in bounds:
        sec_text = u'\n'.join(lines[s:e])
        sec_vis = sum(len(l) for l in lines[s:e] if l.strip())
        total_visible += sec_vis
        dlg_lines = []
        for l in lines[s:e]:
            if not l.strip():
                continue
            if not is_dialogue_line(l, minq):
                continue
            dlg_lines.append(l)
            n_dialogue += 1
            n_dialogue_chars += len(l)
            if has_pair(l):
                n_dialogue_full += 1
        per_sec.append({
            'sec': lines[s].strip(),
            'visible': sec_vis,
            'n': len(dlg_lines),
            'chars': sum(len(l) for l in dlg_lines)})
        if not stats_only:
            out_lines.append(lines[s].rstrip())
            out_lines.append(u'')
            out_lines.append(u'## 对话行 %d 条 / %d 字' % (len(dlg_lines), sum(len(l) for l in dlg_lines)))
            out_lines.append(u'')
            out_lines.extend(dlg_lines)
            out_lines.append(u'')
        n_sec += 1

    if not stats_only:
        write_utf8_no_bom(out, u'\n'.join(out_lines))
        print(u'written=%s' % out)

    print(u'sections=%d' % n_sec)
    print(u'dialogue_lines=%d' % n_dialogue)
    print(u'dialogue_chars=%d' % n_dialogue_chars)
    print(u'dialogue_full_pair_lines=%d' % n_dialogue_full)
    print(u'total_visible_chars=%d' % total_visible)
    ratio = n_dialogue_chars * 100.0 / total_visible if total_visible else 0.0
    print(u'dialogue_ratio_pct=%.2f' % ratio)


if __name__ == '__main__':
    main()