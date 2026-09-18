# -*- coding: utf-8 -*-
"""清洗爬虫文本生成精编基线（过滤站点标记/水印/HTML残留/重复章节标题），UTF-8 无 BOM 写出。
对齐 create_edited_baseline.ps1。"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gu_tools import PsArgs, repo_abs, read_source_lines, write_utf8_no_bom


def from_codepoints(*cps):
    return ''.join(chr(cp) for cp in cps)


BOOK_TITLE = from_codepoints(0x300A, 0x86CA, 0x771F, 0x4EBA, 0x300B, 0x7CBE, 0x7F16, 0x7248)   # 《蛊真人》精编版
VOLUME_TITLE = from_codepoints(0x7B2C, 0x4E00, 0x90E8, 0x0020, 0x9B54, 0x6027, 0x4E0D, 0x6539)  # 第一部 魔性不改
SITE_MARKER = from_codepoints(0x66F4, 0x591A, 0x7CBE, 0x5F69, 0x9605, 0x8BFB, 0x8BF7, 0x6536, 0x85CF)  # 更多精彩阅读请收藏
BODY_PREFIX = from_codepoints(0x6B63, 0x6587)  # 正文
UNFINISHED = from_codepoints(0x672A, 0x5B8C, 0x5F85, 0x7EED)  # 未完待续
OPEN_QUOTE = from_codepoints(0x300C)  # 「
CLOSE_QUOTE = from_codepoints(0x300D)  # 」
FORUM_MARKER = from_codepoints(0x86CA, 0x771F, 0x4EBA, 0x5427)  # 蛊真人吧
BAIDU_MARKER = from_codepoints(0x767E, 0x5EA6)  # 百度

RE_CTRL_D = re.compile(r'^\s*CTRL\+D\s+')
RE_PS_LINE = re.compile(r'^\s*[\uFF08(]?\s*[pP][sS]\s*[\uFF1A:]?\s*')
RE_PS_THANKS = re.compile(r'^\s*[\uFF08(]\s*(?:感谢|统计|打赏|月票|推荐票|谢谢)')
RE_PS_UNFINISHED_LINE = re.compile(r'^\s*[\uFF08(]?\s*' + re.escape(UNFINISHED) + r'\s*[\uFF09)]?\s*$')
RE_AD_TAIL = re.compile(r'(?:投推荐票、月票，|订阅，打赏，)您的支持，就是我最大的动力。?手机用户请到(?:\.qda)?\.阅读。?[)）]?|订阅，打赏，您的支持，就是我最大的动力。[)）]?')
RE_BODY_PREFIX = re.compile(r'\([^)]*\)\s*$')
RE_BOLD = re.compile(r'^<b>.*</b>$')
RE_LEAD_4SP = re.compile(r'^\s{4}')
RE_UNFINISHED = re.compile(r'[\uFF08(]\s*' + re.escape(UNFINISHED) + r'[^)）]*(?:[)）]|$)')
RE_DD = re.compile(r'</?dd>')
RE_RQ = re.compile(r'RQ\s*$')
RE_WATERMARK = re.compile(re.escape(OPEN_QUOTE) + r'[^' + re.escape(OPEN_QUOTE + CLOSE_QUOTE) + r']*(?:' +
                          re.escape(FORUM_MARKER) + '|' + re.escape(BAIDU_MARKER) + ')[^' +
                          re.escape(OPEN_QUOTE + CLOSE_QUOTE) + r']*' + re.escape(CLOSE_QUOTE))
RE_CHAPTER_HEAD = re.compile(r'^' + chr(0x7B2C) + r'.{1,12}' + chr(0x8282))


def clean_lines(lines):
    result = [BOOK_TITLE, '', VOLUME_TITLE, '']
    for raw_line in lines:
        line = raw_line.rstrip()
        if RE_CTRL_D.match(line):
            continue
        if line.lstrip().startswith(SITE_MARKER):
            continue
        if RE_PS_LINE.match(line):
            continue
        if RE_PS_THANKS.match(line):
            continue
        if RE_PS_UNFINISHED_LINE.match(line):
            continue
        if line.startswith(BODY_PREFIX + ' '):
            line = line[len(BODY_PREFIX):].lstrip()
            line = RE_BODY_PREFIX.sub('', line)
        if RE_BOLD.match(line):
            continue
        line = RE_LEAD_4SP.sub('', line)
        line = RE_UNFINISHED.sub('', line)
        line = RE_AD_TAIL.sub('', line)
        line = RE_DD.sub('', line)
        line = RE_RQ.sub('', line)
        line = RE_WATERMARK.sub('', line)
        if line == '' and result and result[-1] == '':
            continue
        result.append(line)

    while result and result[-1] == '':
        result.pop()

    # Some scraped pages repeat the chapter heading once inside the body wrapper.
    for index in range(len(result) - 1, 1, -1):
        if result[index - 1] == '' and result[index] == result[index - 2] and RE_CHAPTER_HEAD.match(result[index]):
            del result[index]
            del result[index - 1]
    result.append('')
    return result


def main():
    args = PsArgs(specs=[
        ('SourcePath', 'string'),
        ('OutputPath', 'string'),
        ('BookTitle', 'string'),
        ('VolumeTitle', 'string'),
    ])
    source = args.require('SourcePath')
    output = args.require('OutputPath')
    book_title = args.get('BookTitle') or BOOK_TITLE
    volume_title = args.get('VolumeTitle') or VOLUME_TITLE

    lines = read_source_lines(repo_abs(source))
    result = clean_lines(lines)
    if book_title != BOOK_TITLE:
        result[0] = book_title
    if volume_title != VOLUME_TITLE:
        result[2] = volume_title
    write_utf8_no_bom(repo_abs(output), '\r\n'.join(result) + '\r\n')


if __name__ == '__main__':
    main()
