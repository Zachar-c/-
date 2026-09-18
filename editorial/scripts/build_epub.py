# -*- coding: utf-8 -*-
"""由精编文本批量生成 EPUB。对齐 build_epub.ps1 的输出结构；
mimetype 直接用 zipfile 的 STORED 模式写入，取代 PS 版 Add-ZipEntry + Repair-MimetypeEntry 的二进制修补。"""
import io
import os
import re
import sys
import zipfile
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gu_tools import PsArgs, repo_abs, chinese_number, print_console

HEADING_PATTERN = re.compile(r'^第(?P<number>[零〇一二两三四五六七八九十百千万\d]+)节[：:\s　]*(?P<title>.+?)\s*$')
RANGE_PATTERN = re.compile(r'(?P<volume>vol\d)-sec(?P<start>\d+)-(?P<end>\d+)\.edited\.txt$', re.IGNORECASE)


def default_book_id(source_paths):
    """从第一个精编源文件名推导 BookId（vol1-sec001-199.edited.txt -> gu-zhenren-vol1-sec001-199）；
    推导失败返回 None，由调用方强制要求显式提供。"""
    for source in source_paths or []:
        m = RANGE_PATTERN.search(os.path.basename(source))
        if m:
            return 'gu-zhenren-{0}-sec{1}-{2}'.format(
                m.group('volume'), m.group('start'), m.group('end'))
    return None


def escape_xml(value):
    if value is None:
        return ''
    return (value.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
            .replace('"', '&quot;').replace("'", '&apos;'))


def safe_file_name(value):
    invalid = set('<>:"/\\|?*')
    return ''.join('_' if ch in invalid else ch for ch in value)


CONTAINER_XML = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
'''

STYLESHEET = '''@charset "UTF-8";
body {
  margin: 0 1em;
  padding: 0;
  font-family: serif;
  line-height: 1.85;
  text-align: justify;
  word-wrap: break-word;
}
h1 {
  margin: 2.5em 0 1.5em;
  font-size: 1.35em;
  text-align: center;
  font-weight: bold;
  line-height: 1.5;
}
.title-page {
  margin-top: 30vh;
  text-align: center;
}
.title-page h1 {
  margin: 0 0 1em;
  font-size: 1.8em;
}
.title-page p {
  text-align: center;
  text-indent: 0;
}
p {
  margin: 0 0 0.9em;
  text-indent: 2em;
}
.toc {
  margin: 2em 0;
  padding: 0;
  list-style: none;
}
.toc li {
  margin: 0.65em 0;
  text-indent: 0;
}
a {
  color: inherit;
  text-decoration: none;
}
'''


def read_chapters(source_paths):
    chapters = []
    for source in source_paths:
        path = repo_abs(source)
        if not os.path.isfile(path):
            raise SystemExit('Source file not found: {0}'.format(path))
        with io.open(path, 'r', encoding='utf-8-sig', newline='') as fh:
            lines = fh.read().splitlines()
        source_name = os.path.basename(path)
        range_match = RANGE_PATTERN.search(source_name)
        range_start = int(range_match.group('start')) if range_match else None
        range_end = int(range_match.group('end')) if range_match else None
        current = None
        content = []
        for line in lines:
            m = HEADING_PATTERN.match(line)
            if m:
                chapter_number = chinese_number(m.group('number'))
                if range_end is not None and (chapter_number < range_start or chapter_number > range_end):
                    if current is not None:
                        current['content'] = content
                        chapters.append(current)
                    current = None
                    break
                if current is not None:
                    current['content'] = content
                    chapters.append(current)
                current = {'number': m.group('number'), 'title': m.group('title').strip(), 'content': []}
                content = []
                continue
            if current is not None:
                content.append(line)
        if current is not None:
            current['content'] = content
            chapters.append(current)
    return chapters


def add_text_entry(zf, entry_name, content):
    content = content.replace('\r\n', '\n').rstrip('\n').replace('\n', '\r\n')
    zf.writestr(entry_name, content.encode('utf-8'))


def main():
    args = PsArgs(specs=[
        ('SourcePath', 'string[]'),
        ('OutputPath', 'string'),
        ('BookTitle', 'string'),
        ('PartTitle', 'string'),
        ('BookId', 'string'),
    ], defaults={
        'BookTitle': '《蛊真人》精编版',
        'PartTitle': '第一部　魔性不改',
    })
    source_paths = args.require('SourcePath')
    output = repo_abs(args.require('OutputPath'))
    book_title = args.get('BookTitle')
    part_title = args.get('PartTitle')
    book_id = args.get('BookId')
    if not book_id:
        book_id = default_book_id(source_paths)
    if not book_id:
        raise SystemExit(
            'Missing -BookId；无法从源文件名（如 vol1-sec001-199.edited.txt）自动推导，'
            '请显式提供，例如 -BookId gu-zhenren-vol2-sec001-206')

    chapters = read_chapters(source_paths)
    if not chapters:
        raise SystemExit('No chapter headings were found in the source files.')

    os.makedirs(os.path.dirname(output), exist_ok=True)
    with zipfile.ZipFile(output, 'w') as zf:
        zf.writestr('mimetype', b'application/epub+zip', compress_type=zipfile.ZIP_STORED)
        add_text_entry(zf, 'META-INF/container.xml', CONTAINER_XML)
        add_text_entry(zf, 'OEBPS/style.css', STYLESHEET)

        title_xhtml = u'''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="zh-CN" lang="zh-CN">
  <head>
    <title>{0}</title>
    <link rel="stylesheet" type="text/css" href="style.css"/>
  </head>
  <body class="title-page">
    <h1>{0}</h1>
    <p>{1}</p>
    <p><a href="nav.xhtml">进入目录</a></p>
  </body>
</html>
'''.format(escape_xml(book_title), escape_xml(part_title))
        add_text_entry(zf, 'OEBPS/title.xhtml', title_xhtml)

        chapter_manifest = []
        chapter_spine = []
        nav_items = []
        ncx_items = []
        chapter_index = 0
        for chapter in chapters:
            chapter_index += 1
            cid = 'chapter-{0:03d}'.format(chapter_index)
            file_name = cid + '.xhtml'
            chapter_title = u'第{0}节　{1}'.format(chapter['number'], chapter['title'])
            paragraphs = []
            for line in chapter['content']:
                if line.strip():
                    paragraphs.append(u'<p>{0}</p>'.format(escape_xml(line.strip())))
            paragraph_text = '\r\n'.join(paragraphs) + '\r\n'
            chapter_xhtml = u'''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="zh-CN" lang="zh-CN">
  <head>
    <title>{0}</title>
    <link rel="stylesheet" type="text/css" href="style.css"/>
  </head>
  <body>
    <h1 id="{1}">{0}</h1>
    {2}
  </body>
</html>
'''.format(escape_xml(chapter_title), cid, paragraph_text)
            add_text_entry(zf, 'OEBPS/' + file_name, chapter_xhtml)
            chapter_manifest.append(u"    <item id='{0}' href='{1}' media-type='application/xhtml+xml'/>".format(cid, file_name))
            chapter_spine.append(u"    <itemref idref='{0}'/>".format(cid))
            nav_items.append(u"      <li><a href='{0}'>{1}</a></li>".format(file_name, escape_xml(chapter_title)))
            play_order = chapter_index + 1
            ncx_items.append(u"    <navPoint id='navPoint-{0}' playOrder='{1}'><navLabel><text>{2}</text></navLabel><content src='{3}'/></navPoint>".format(
                chapter_index, play_order, escape_xml(chapter_title), file_name))

        nav_xhtml = u'''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="zh-CN" lang="zh-CN">
  <head>
    <title>目录</title>
    <link rel="stylesheet" type="text/css" href="style.css"/>
  </head>
  <body>
    <h1>{0}</h1>
    <p>{1}</p>
    <nav epub:type="toc" id="toc">
      <ol class="toc">
        <li><a href="title.xhtml">封面</a></li>
{2}      </ol>
    </nav>
  </body>
</html>
'''.format(escape_xml(book_title), escape_xml(part_title), os.linesep.join(nav_items) + os.linesep)
        add_text_entry(zf, 'OEBPS/nav.xhtml', nav_xhtml)

        ncx = u'''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="{0}"/>
  </head>
  <docTitle><text>{1}</text></docTitle>
  <navMap>
    <navPoint id="navPoint-title" playOrder="1"><navLabel><text>封面</text></navLabel><content src="title.xhtml"/></navPoint>
{2}  </navMap>
</ncx>
'''.format(escape_xml(book_id), escape_xml(book_title), os.linesep.join(ncx_items) + os.linesep)
        add_text_entry(zf, 'OEBPS/toc.ncx', ncx)

        modified = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        manifest = u'''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="book-id" xml:lang="zh-CN">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="book-id">{0}</dc:identifier>
    <dc:title>{1}</dc:title>
    <dc:language>zh-CN</dc:language>
    <dc:creator>古月</dc:creator>
    <meta property="dcterms:modified">{2}</meta>
  </metadata>
  <manifest>
    <item id="title" href="title.xhtml" media-type="application/xhtml+xml"/>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="css" href="style.css" media-type="text/css"/>
{3}  </manifest>
  <spine toc="ncx">
    <itemref idref="title"/>
{4}  </spine>
</package>
'''.format(escape_xml(book_id), escape_xml(book_title), modified,
           os.linesep.join(chapter_manifest) + os.linesep, os.linesep.join(chapter_spine) + os.linesep)
        add_text_entry(zf, 'OEBPS/content.opf', manifest)

    print_console('Created: {0}'.format(output))
    print_console('Chapters: {0}'.format(len(chapters)))


if __name__ == '__main__':
    main()
