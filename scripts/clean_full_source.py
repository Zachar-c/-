# -*- coding: utf-8 -*-
"""全卷源文净化：清洗 蛊真人.txt 产出 蛊真人-clean.txt。
关键约束：只做行内替换与整行置空，绝不删除行——输出行数与原文完全一致，行号零漂移，
挂靠在原文上的 source_line、台账行号与 source-map 继续有效。
另产出 working/source-clean-candidates.tsv：上下文敏感/未裁决可疑项，仅供人工审阅，不改。
"""
import io
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gu_tools import PsArgs, repo_abs, print_console

RE_CTRLD_AD = re.compile(r'^\s*CTRL\s*\+\s*D\s*收藏.*$')
RE_PS_LEAD = re.compile(r'^\s*(?:\(\)\s*)?[\uFF08(]\s*[pP][sS]\s*[\uFF1A:]\s*')  # （ps：…、 (ps:…
RE_PS_LEAD2 = re.compile(r'^\s*[pP][sS]?\s*(?:[：:.\s]|[\u4e00-\u9fff]+)')
RE_WEIXIN_AD = re.compile(r'[（(]\s*想知道《蛊真人》更多精彩动态吗[^)）]*(?:[)）]|$)')
RE_PROMO_AD = re.compile(r'[（(]\s*天上掉馅饼的好活动.*?(?:[)）]|$)\s*r?\d*\s*$')
RE_WECHAT_PROMO = re.compile(r'[（(]\s*(?:我的小说《蛊真人》|小说《蛊真人》).*?(?:[)）]|$)\s*r?\d*\s*$')
RE_PS_THANKS = re.compile(r'^\s*[\uFF08(]\s*(?:感谢|谢谢).{0,120}(?:打赏|月票|推荐票|评价票|支持).{0,120}[。！]?[\uFF09)]?\s*$')
RE_BARE_THANKS = re.compile(
    r'^\s*最后[，,]?\s*要感谢[^。！]{0,80}。\s*$|'
    r'^\s*最后[，,]+\s*感谢[^。！]{0,60}(?:打赏|推荐票|评价票)[^。！]{0,40}[。！]{1,2}[\uFF09)】]*\s*$|'
    r'^\s*(?:最后[，,]要)?感谢[^。！]{0,60}(?:打赏|盟主|月票|投票|书友|正版|兄弟).{0,60}[。！\uFF09)】]*\s*$')
RE_BIRTHDAY = re.compile(r'^\s*今天是我的生日，.{0,60}(?:支持|祝福|盟主).{0,60}[。！]?\s*$')
RE_ANNOUNCE = re.compile(
    r'^\s*(?:另通知[:：]|还有一个通知|本书qq书友群|蛊真人qq[:：]|《蛊真人》vip群|'
    r'接下来vip[章节]*的更新|自公众号打赏开通以来|还有一个重要的事情|'
    r'还有一个vip群|另[：:]|备注[:：]).*$|'
    r'^\s*最后[，,]+\s*感谢[^。！]{0,60}(?:打赏|推荐票|评价票|收藏)[^。！]{0,40}[。！]{1,2}[\uFF09)】]*\s*$|'
    r'[^\n]*谢谢你们！[\uFF09)]\s*$|'
    r'^\s*吾读小说网全文字无弹窗地址[^\n]*\s*$')
RE_MOBILE_TAIL = re.compile(r'手机用户请浏览阅读，更优质的阅读体验。\s*$')
RE_FAVORITE_RECO = re.compile(r'[\uFF08(]\s*喜欢本小说的网友[，,]?\s*可能喜欢[:：]?\s*[^\uFF09)]*[\uFF09)]?[。！]?')
RE_HREF_RECO = re.compile(r'[\uFF08(]\s*<a\s+href="[^"]*"[^>]*>[^<\uFF09)]{1,30}</a>[\uFF09)]')
RE_THANKS_LIST = re.compile(r'^\s*感谢(?:以下)?读者朋友们?[^。\n]{0,40}打赏[:：]?\s*$')
RE_LIST_LINE = re.compile(r'^[^，\u201C\u201D\uFF08\uFF09()：:\n]*[、][^！\u201C\u201D\uFF08\uFF09()\n]*$')
RE_PLEA = re.compile(r'^\s*(?:求|恳请|拜托)[^。]{0,30}(?:月票|推荐票|订阅|收藏)[^。]{0,20}。[。]?\s*$')
RE_CHAPTER_HEAD = re.compile(r'^(?:第[零一二三四五六七八九十百千]+节|序)[：:]')
RE_UNFINISHED_TAIL = re.compile(
    r'[\uFF08(]\s*未完待续(?:。)?\s*[\uFF09)]?(?:[^\uFF09)]*[\uFF09)]?)*\s*(?:</?dd>)?\s*$|'
    r'未完待续[。\s^]*(?:~[^\n]*)?$')
RE_TAIL_SQUIGGLE = re.compile(r'\s*(?:\(~\^~\)[^)\n]*\)|\([~^]+\.[a-zA-Z0-9.]+\))\s*$')
RE_BRACKET_AD = re.compile(r'^\s*【(?:感谢大家一直以来的支持|马上就要515了|最新播报|播报)[^】]*】.*$')
RE_TAIL_DD = re.compile(r'\s*</?dd>\s*$')
RE_TAIL_PAGEMARK = re.compile(r'\s*r\d{2,5}\s*$')
RE_BODY_PREFIX = re.compile(r'^\s*正文\s+')
RE_NET_MARK = re.compile(r'^\s*网络小说独家首发\s*')
RE_SITE_TAIL = re.compile(
    r'(?:更多精彩阅读请收藏\s*)?(?:吾爱文学网|吾爱小说网|笔趣阁|快乐文学网)\s*'
    r'(?:www\.)?[a-z0-9.\-]+\.(?:com|net|cn|top|cc|xyz)\s*$', re.I)
RE_SITE_UI = re.compile(
    r'^\s*(?:搜\s*小\s*说|报错[:：]|(?:&gt;?|>)\s*(?:女生小说|男生小说)\s*>\s*|'
    r'吾读小说网[^,，\n]*|上一页\s+返回目录\s+下一页|'
    r'如果你不记的本地域名没关系[^\n]*|'
    r'如果任何单位或个人对本站的文学作品版权有质疑[^\n]*|'
    r'copyright\s*&copy;?\s*\d{4}\s+all rights reserved\.|'
    r'\d+QQ书友群[^\n]*|'
    r'5\s*2\s*0\s*小说[^\n]*).*$', re.I)
RE_PINYIN_NOTE = re.compile(r'[\uFF08(]([a-zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜü]{1,6})[\uFF09)]')
RE_X2552 = re.compile(r'www\.x\d+\.com', re.I)
RE_DD = re.compile(r'</?dd>')
RE_HTML_TAG = re.compile(r'<[^>]{0,200}>')
RE_NBSP = re.compile(r'&nbsp;|&nbs;|&lt;|&gt;|&amp;|&(?:spades|hearts|clubs|diams|sect|middot);|&#\d{1,6};')
RE_PINYIN_TAIL = re.compile(r'([\u4e00-\u9fff])([a-zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜü]+)[\u4e00-\u9fff]')
RE_WATERMARK = re.compile(
    r'手\s*机\s*用\s*户\s*请\s*访\s*问[^\n]*|'
    r'请\s*搜\s*索[^\n]*小说更好更新[^\n]*|'
    r'http://[^\s，。！？、；：“”\u4e00-\u9fff]{0,80}|'
    r'\b[pP]iaotian[a-z0-9./]{0,20}|'
    r'5\s*2\s*0\s*[xX]\s*[sS][^\n\u4e00-\u9fff]{0,20}|'
    r'(?:[`＝─=]{2,}\s*)?2\s*[＋+]?\s*3\s*[wW][xX][\s`＝─=-]*|'
    r'︽頂點小說[，,]?[^\n\u4e00-\u9fff]{0,8}|'
    r'[wW]{2}[^\n\u4e00-\u9fff]{0,16}|'
    r'∽≧长∽≧风∽≧文∽≧学[，、]?|'
    r'∟■[^\n]{0,30}|'
    r'(?:▲|▼|◆|◇)[^\n]{0,30}|'
    r'レ[^\n]{0,80}レ|'
    r'\\长\\风\(cf\)(?:\(wx\))?\.?|'
    r'`{1,2}长`{1,2}风`{1,2}文学`{1,2}cfwx`{0,2}|'
    r'reads;[^\n。！？]{0,16}|'
    r'≌→style_txt;|'
    r'壹看书[^\n]{0,12}|'
    r'[（(]欢迎您来[^）)]{0,30}[）)]?[RV]{0,2}|'
    r'\bRQ\s*$|'
    r'^\s*BR\b|'
    r'pbtt|'
    r'[╪┝┞┠┡┢┥┦┧┨]{2,}[^\n]{0,20}?[wW][〈《﹝＜<][wW][〈《﹝＜<][wW][^\n\u4e00-\u9fff]{0,12}|'
    r'[╪┝┞┠┡┢┥┦┧┨]{2,}[^\n\u4e00-\u9fff]{0,12}|'
    r'壹[ΚK]à[^\n\u4e00-\u9fff]{0,6}|'
    r'◎[^\n]{0,30}◎|文學館[^\n\u4e00-\u9fff]{0,10}|百度搜文學馆[^\n\u4e00-\u9fff]{0,10}|'
    r'∴■长∴■风∴■文∴■学[，、]?[^\n\u4e00-\u9fff]{0,6}|'
    r'^\s*readx;?\s*$|'
    r'\brs\s*$|'
    r'[0-9]♂[0-9a-z]*|▽♂t|♂et|'
    r'^\s*♂\s*$|'
    r'天才壹秒記住[^\n]*|'
    r'【?笔♂趣→阁[^\n]*|'
    r'\bpbtt\b|'
    r'^\s*i\d{4,}[-+]*\d{4,}[-+]*\w{2,}[-+]*\d{6,}[-+]*\s*$|'
    r'ads_[a-z0-9_]+\(\);', re.I)
RE_WWW_INLINE = re.compile(r'\s*www\.')

CONFIRMED_FIXES = [
    (u'淬不及防', u'猝不及防'),
    (u'幸-运', u'幸运'),
    (u'爱生离', u'爱别离'),
    (u'青矛山', u'青茅山'),
    (u'黒豕', u'黑豕'),
    (u'兴-奋', u'兴奋'),
    (u'**oss', u'Boss'),
]
PINYIN_MAP = [
    (u'sè', u'色'), (u'jīng', u'精'), (u'xìng', u'性'), (u'rì', u'日'),
    (u'yīn', u'阴'), (u'yín', u'淫'), (u'shè', u'射'), (u'yù', u'欲'),
    (u'cāo', u'操'), (u'chūn', u'春'), (u'cháo', u'潮'), (u'nǎi', u'奶'),
    (u'jǐng', u'警'), (u'huā', u'花'), (u'sāo', u'骚'), (u'bó', u'薄'),
    (u'hòu', u'厚'), (u'rǔ', u'乳'), (u'jī', u'激'), (u'piáo', u'嫖'),
    (u'nǎinǎi', u'奶奶'),
]
PINYIN_SPECIAL = [
    (u'激ān', u'奸'), (u'o阿', u'啊'), (u'露n理', u'伦理'),
    (u'太rì阳', u'太阳'), (u'h酒行者', u'花酒行者'), (u'h心', u'花心'),
    (u'zhong yāng', u'中央'), (u'zi you', u'自由'), (u'chéng rén', u'成人'),
    (u'hou望', u'厚望'), (u'houhou', u'厚厚'),
    (u'仈激ǔ', u'八九'), (u'仈jiu', u'八九'),
    (u'赤露o上身', u'赤裸上身'), (u'我x夜', u'我日夜'), (u'我x后', u'我日后'),
    (u'zhōng yāng', u'中央'), (u'zhōngyāng', u'中央'), (u'zhongyāng', u'中央'), (u'dita', u'地带'),
    (u'仍1ri', u'仍旧'), (u'èng九歌', u'凤九歌'), (u'云huáng', u'云凰'),
    (u'25o9o6315', u'250906315'), (u'（ qiè）', u'窃'),
]
RE_PINYIN_CTX = re.compile(
    r'(^\s*|[\u4e00-\u9fff])(xing|jing|chun|ri|yu|yin|hou|ji|fen)'
    r'([\u4e00-\u9fff]|$|[，。！？、；：,.!?;:])', re.I)
PINYIN_CTX_MAP = {
    'xing': u'性', 'jing': u'精', 'chun': u'春', 'ri': u'日',
    'yu': u'欲', 'yin': u'阴', 'hou': u'厚', 'ji': u'激', 'fen': u'粉',
}
RE_PINYIN_NOTE = re.compile(r'[\uFF08(]([a-zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜü]{1,6})[\uFF09)]')


def pinyin_fix(line):
    for pair in PINYIN_SPECIAL:
        if pair[0] in line:
            line = line.replace(pair[0], pair[1])
    for syl, zh in PINYIN_MAP:
        if syl in line:
            line = line.replace(syl, zh)
    if RE_PINYIN_CTX.search(line):
        def _sub(m):
            return (m.group(1) or u'') + PINYIN_CTX_MAP[m.group(2)] + (m.group(3) or u'')
        line = RE_PINYIN_CTX.sub(_sub, line)
    return line
SENSITIVE_WORDS = [u'漠尘', u'漠北', u'王大', u'王二', u'白獒']
CANDIDATE_PATTERNS = [
    (re.compile(r'[A-Za-z]{2,}\b'), '英文残留'),
    (re.compile(r'[\uFFFD\uFFFC\uFFFE\uFFFF]'), '替换字符'),
    (RE_PINYIN_TAIL, '拼音残留'),
]
AUTHOR_SPEAK_MARKERS = re.compile(
    r'(?:新书|码字|更新速度|加更|月票|推荐票|书友|读者朋友|订阅|收藏|上架|章节)',
    re.UNICODE)


def is_para_start(line):
    if not line.strip():
        return False
    if RE_CTRLD_AD.match(line):
        return True
    if RE_BRACKET_AD.match(line):
        return True
    if RE_PS_LEAD.match(line) or RE_PS_LEAD2.match(line):
        return True
    return False


def mark_author_paras(lines):
    spans = []
    i = 0
    n = len(lines)
    while i < n:
        if is_para_start(lines[i]):
            end = i
            while end + 1 < n and lines[end + 1].strip():
                end += 1
            spans.append((i, end))
            i = end + 1
        else:
            i += 1
    return spans


def clean_line(line):
    if not line.strip():
        return line
    if RE_CTRLD_AD.match(line) or RE_BRACKET_AD.match(line):
        return ''
    if RE_PS_LEAD.match(line) or RE_PS_LEAD2.match(line):
        return ''
    if RE_PS_THANKS.match(line) or RE_THANKS_LIST.match(line):
        return ''
    if RE_SITE_UI.match(line):
        return ''
    if RE_BARE_THANKS.match(line) or RE_BIRTHDAY.match(line) or RE_ANNOUNCE.match(line):
        return ''
    if RE_PLEA.match(line) and not RE_CHAPTER_HEAD.match(line):
        return ''
    line = RE_MOBILE_TAIL.sub('', line)
    line = RE_FAVORITE_RECO.sub('', line)
    line = RE_HREF_RECO.sub('', line)
    line = RE_WEIXIN_AD.sub('', line)
    line = RE_PROMO_AD.sub('', line)
    line = RE_WECHAT_PROMO.sub('', line)
    line = RE_SITE_TAIL.sub('', line)
    line = RE_X2552.sub('', line)
    line = RE_DD.sub('', line)
    line = RE_HTML_TAG.sub('', line)
    line = RE_NBSP.sub('', line)
    line = RE_WATERMARK.sub('', line)
    line = RE_PINYIN_NOTE.sub('', line)
    line = RE_WWW_INLINE.sub('', line)
    line = RE_TAIL_PAGEMARK.sub('', line)
    line = RE_TAIL_SQUIGGLE.sub('', line)
    line = RE_UNFINISHED_TAIL.sub('', line)
    line = RE_NET_MARK.sub('', line)
    line = RE_BODY_PREFIX.sub('', line)
    if line.strip() and RE_SITE_UI.match(line):
        return ''
    if not line.strip():
        return ''
    return line


def main():
    args = PsArgs(specs=[
        ('SourcePath', 'string'),
        ('OutputPath', 'string'),
        ('ReportPath', 'string'),
    ])
    source = repo_abs(args.require('SourcePath'))
    output = repo_abs(args.get('OutputPath') or u'蛊真人-clean.txt')
    report = repo_abs(args.get('ReportPath') or u'working/source-clean-candidates.tsv')

    with io.open(source, 'r', encoding='utf-8', newline='') as fh:
        raw = fh.read()
    newline = u'\r\n' if u'\r\n' in raw else u'\n'
    lines = raw.splitlines()

    out_lines = []
    candidates = []
    stats = {'blanked': 0, 'fixes': 0, 'candidates': 0}
    in_thanks = False
    for line_no, line in enumerate(lines, 1):
        cleaned = clean_line(line)
        if RE_THANKS_LIST.match(line):
            in_thanks = True
        elif in_thanks and cleaned.strip() and not RE_LIST_LINE.match(cleaned):
            in_thanks = False
        if in_thanks and cleaned.strip() and RE_LIST_LINE.match(cleaned):
            cleaned = ''
            stats['blanked'] += 1
        if cleaned != line and cleaned.strip() == '':
            stats['blanked'] += 1
        for fix_from, fix_to in CONFIRMED_FIXES:
            if fix_from in cleaned:
                cleaned = cleaned.replace(fix_from, fix_to)
                stats['fixes'] += 1
        pinyin_fixed = pinyin_fix(cleaned)
        if pinyin_fixed != cleaned:
            stats['fixes'] += 1
            cleaned = pinyin_fixed
        for word in SENSITIVE_WORDS:
            if word in cleaned:
                candidates.append((line_no, '敏感词:' + word, cleaned.strip()[:120]))
                stats['candidates'] += 1
        if cleaned.strip() and AUTHOR_SPEAK_MARKERS.search(cleaned.strip()[:60]) and (
                cleaned.strip().startswith(('（', '(', '【')) or len(cleaned.strip()) > 60):
            if not RE_CHAPTER_HEAD.match(cleaned.strip()):
                candidates.append((line_no, '作者话候选', cleaned.strip()[:120]))
                stats['candidates'] += 1
        for cpat, label in CANDIDATE_PATTERNS:
            for m in cpat.finditer(cleaned):
                candidates.append((line_no, label, cleaned.strip()[:120]))
                stats['candidates'] += 1
                break
        out_lines.append(cleaned)

    newline = u'\r\n' if u'\r\n' in raw else u'\n'
    with io.open(output, 'w', encoding='utf-8', newline='') as fh:
        fh.write(newline.join(out_lines) + newline)
    with io.open(report, 'w', encoding='utf-8', newline='') as fh:
        fh.write(u'line_no\ttype\tsample\n')
        fh.write(u''.join(u'{0}\t{1}\t{2}\n'.format(no, t, s) for no, t, s in candidates[:2000]))

    print_console(u'净化完成：{0} 行 -> {1} 行（行数守恒 {2}）'.format(
        len(lines), len(out_lines), 'PASS' if len(lines) == len(out_lines) else 'FAIL'))
    print_console(u'整行置空 {0} 处；已裁决替换 {1} 处；候选 {2} 条 -> {3}'.format(
        stats['blanked'], stats['fixes'], stats['candidates'], report))


if __name__ == '__main__':
    main()