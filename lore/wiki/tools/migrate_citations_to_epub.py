#!/usr/bin/env python3
"""把 Wiki 页面对旧源 `蛊真人-clean.txt` 的引用改写为 EPUB 章节/段落定位。

背景：2026-09-30 起正文真源为 `source/蛊真人-epub-canon.txt`。页面里仍残留
`蛊真人-clean.txt:NNNN` 形态的定位，读者无法据此回查，且旧源已不在库。

定位表来源与优先级（越靠前越可信）：
  1. lore/runtime/evidence-locators.json —— 针对本仓 EPUB 生成的已核/人工核准锚
  2. lore/wiki/source/eid-migration-map-final.tsv —— 针对本仓 EPUB 的迁移终表
  3. 旧行号→EPUB 全量映射表 —— 仅用于补齐前两者未覆盖的行号

只改写「真正的引用」：行内 `蛊真人-clean.txt:NNNN` 与 frontmatter 的 sources 声明。
按字节改写，逐文件保持原有 BOM 与行尾（260 个 CRLF / 15 个 LF / 2 个 BOM，
整文件重写会导致行尾被整体改写的全量 diff）。

刻意不改写：
  - E:V… 证据 ID —— 它是 check9 段号校验与 compile_runtime 的追溯骨干，不是旧源引用
  - 历史报告/交接文档里对旧源文件名的叙述 —— 那是史实，改掉等于改历史
  - 裸行号（如「219,943 行」是文件行数而非引用）—— 语义有歧义，需逐条判断
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
WIKI = ROOT / "lore" / "wiki"
LOCATORS = ROOT / "lore" / "runtime" / "evidence-locators.json"
FINAL_TSV = WIKI / "source" / "eid-migration-map-final.tsv"
# 旧行号→EPUB 全量映射（不在本仓，由 C 盘工作副本提供；已对本仓基准交叉校验零冲突）
FULL_MAP = Path("/mnt/c/Users/90877/work_space/gu-zhenren/lore/wiki/source/old-line-to-epub-map.tsv")

# 只信任本仓这两类结论
TRUSTED_CLASSES = {"精确"}
# `蛊真人-clean.txt:123` —— 单点
INLINE_CITATION = re.compile(r"`蛊真人-clean\.txt:([0-9]+)`")
# `蛊真人-clean.txt:123-456` —— 区间（同一反引号内）
INLINE_RANGE = re.compile(r"`蛊真人-clean\.txt:([0-9]+)-([0-9]+)`")
FRONTMATTER_SOURCE = re.compile(r'(sources:\s*\[)"source:source/蛊真人-clean\.txt"')
# 多行 YAML 列表形态：
#   sources:
#     - "source:source/蛊真人-clean.txt"
# 带引号，因此在正文里不会出现，替换是安全的。
FRONTMATTER_SOURCE_ITEM = re.compile(r'"source:source/蛊真人-clean\.txt"')
# 引用链里的裸旧行号：紧跟在一个旧源引用之后。旧页面常连写多个旧行号而只写一次文件名：
#   `蛊真人-clean.txt:159948`、`168082`      （顿号/逗号分隔，第二个数字裸写）
#   `蛊真人-clean.txt:151598`–`151654`      （每个行号各自加反引号）
TRAILING_BARE = re.compile(
    r"(蛊真人-clean\.txt:[0-9]+)"
    r"((?:`?\s*(?:[、,]|–|-)\s*`?)[0-9]{3,6}`?)+")
BARE_NUMBER = re.compile(r"[0-9]{3,6}")
# 已转换的 EPUB 定位后仍跟着裸旧行号（早期批次漏改的残留）
TRAILING_AFTER_EPUB = re.compile(
    r"(`EPUB chapter_\d{4} para_\d{3}`)((?:`?\s*(?:[、,]|\u2013|-)\s*`?)[0-9]{3,6}`?)+")


def load_map() -> dict[int, tuple[str, str]]:
    merged: dict[int, tuple[str, str]] = {}
    provenance: Counter[str] = Counter()

    if LOCATORS.is_file():
        data = json.loads(LOCATORS.read_text(encoding="utf-8"))
        for eid, rec in data.items():
            if rec.get("decision") == "blocked":
                continue
            hit = re.match(r"EPUB:chapter_(\d+):para_(\d+)", rec.get("epub_locator") or "")
            if hit and "-" in eid:
                merged[int(eid.split("-")[1])] = (hit.group(1), hit.group(2))
                provenance["locators_" + rec["decision"]] += 1

    if FINAL_TSV.is_file():
        with FINAL_TSV.open(encoding="utf-8-sig", newline="") as stream:
            for row in csv.DictReader(stream, delimiter="\t"):
                if not (row.get("chapter") and row.get("para") and row.get("old_line")):
                    continue
                cls = row.get("class", "")
                provenance["tsv_" + cls] += 1
                if cls not in TRUSTED_CLASSES:
                    continue
                merged.setdefault(int(row["old_line"]), (row["chapter"], row["para"]))

    if FULL_MAP.is_file():
        with FULL_MAP.open(encoding="utf-8-sig") as stream:
            for line in stream:
                parts = line.rstrip("\n").split("\t")
                if len(parts) < 3:
                    continue
                try:
                    key = int(parts[0])
                except ValueError:
                    continue
                if key not in merged:
                    merged[key] = (parts[1], parts[2])
                    provenance["full_map_fill"] += 1
    return merged, provenance


def render(chapter: str, para: str) -> str:
    return f"`EPUB chapter_{int(chapter):04d} para_{int(para):03d}`"


def render_line(line: int, mapping: dict[int, tuple[str, str]], stats: Counter[str]) -> str:
    """单个旧行号 -> EPUB 定位；无对应段落时保留旧行号但显式标注为未迁移。"""
    stats["line_seen"] += 1
    target = mapping.get(line)
    if target is not None:
        stats["line_converted"] += 1
        return render(*target)
    stats["line_unmapped"] += 1
    return f"`旧源行 {line}·未映射`"


def swap_range(mapping, stats):
    """区间引用：两端都能定位就整体替换，否则保留未映射端并显式标注。"""
    def handle(hit):
        start, end = int(hit.group(1)), int(hit.group(2))
        a, b = mapping.get(start), mapping.get(end)
        if a and b:
            stats["range_converted"] += 1
            return f"{render(*a)}\u2013{render(*b)}"
        if a or b:
            stats["range_partial"] += 1
            lo = render(*a) if a else f"`\u65e7\u6e90\u884c {start}\u00b7\u672a\u6620\u5c04`"
            hi = render(*b) if b else f"`\u65e7\u6e90\u884c {end}\u00b7\u672a\u6620\u5c04`"
            return f"{lo}\u2013{hi}"
        stats["range_unmapped"] += 1
        return f"`\u65e7\u6e90\u884c {start}\u2013{end}\u00b7\u672a\u6620\u5c04`"
    return handle


def rewrite_citations(text, mapping, stats):
    """把一段文本里的旧源引用整体改写为 EPUB 定位。

    处理三种形态：单点 `\u869c\u771f\u4eba-clean.txt:123`、区间 `...:123-456`，以及旧页面
    只写一次文件名的连写串（`...:59612`\u2013`59616`\u3001`95124`\u2013`95128`）。
    连写串里分隔符与反引号混用且方向不定，正则切分不可靠，改用显式扫描。
    """
    text = INLINE_RANGE.sub(swap_range(mapping, stats), text)

    out = []
    cursor = 0
    while True:
        hit = INLINE_CITATION.search(text, cursor)
        if hit is None:
            out.append(text[cursor:])
            break
        out.append(text[cursor:hit.start()])
        out.append(render_line(int(hit.group(1)), mapping, stats))
        cursor = hit.end()
        # \u5411\u540e\u8fde\u7eed\u541e\u6389\u94fe\u5f0f\u88f8\u884c\u53f7\uff0c\u76f4\u5230\u9047\u5230\u4e0d\u662f\u300c\u5206\u9694\u7b26 + \u884c\u53f7\u300d\u7684\u4e0b\u4e00\u4e2a\u8bb0\u53f7
        while True:
            probe = cursor
            while probe < len(text) and text[probe] in " \t":
                probe += 1
            if probe < len(text) and text[probe] in "\u3001,\u2013-":
                probe += 1
            else:
                break
            while probe < len(text) and text[probe] in " \t":
                probe += 1
            if probe < len(text) and text[probe] == "`":
                probe += 1
            number = re.match(r"[0-9]{3,6}", text[probe:])
            if number is None:
                break
            out.append(text[cursor:probe])
            out.append(render_line(int(number.group(0)), mapping, stats))
            cursor = probe + number.end()
    # 收尾：修掉早期批次遗留的「已转换 EPUB 定位 + 裸旧行号」串。
    # 例如 `EPUB chapter_0443 para_039`–`81812`，后半段是漏改的旧源行号。
    text = "".join(out)

    def rewrite_bare_chain(fragment):
        """把只有裸行号的片段逐个换成 EPUB 定位或未映射标注。"""
        # 先去掉片段自带的反引号：render_line 会输出成对反引号，否则会出现四连反引号
        fragment = fragment.replace("`", "")
        return re.sub(r"[0-9]{3,6}",
                      lambda num: render_line(int(num.group(0)), mapping, stats),
                      fragment)

    return TRAILING_AFTER_EPUB.sub(
        lambda hit: hit.group(1) + rewrite_bare_chain(hit.group(2)), text)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--apply", action="store_true", help="真正写盘；缺省只做干跑统计")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    if not FULL_MAP.is_file():
        print(f"WARN 缺少全量映射表：{FULL_MAP}", file=sys.stderr)
        print("      覆盖率会显著下降；请确认该文件仍可访问。", file=sys.stderr)

    mapping, provenance = load_map()
    if not args.quiet:
        print("定位表来源：")
        for key, count in provenance.most_common():
            print(f"  {key}: {count}")

    stats = Counter()
    changed: list[tuple[Path, int]] = []
    for path in sorted(WIKI.rglob("*.md")):
        raw = path.read_bytes()
        text = raw.decode("utf-8-sig")

        new_text = rewrite_citations(text, mapping, stats)
        new_text, fm = FRONTMATTER_SOURCE.subn(
            lambda hit: hit.group(1) + '"source:source/蛊真人-epub-canon.txt"', new_text)
        # 多行 YAML 列表形态
        new_text, fm2 = FRONTMATTER_SOURCE_ITEM.subn(
            '"source:source/蛊真人-epub-canon.txt"', new_text)
        fm += fm2
        if fm:
            stats["frontmatter_converted"] += fm

        if new_text != text:
            changed.append((path, stats["line_converted"] + fm))
            if args.apply:
                # 按字节写回：BOM 与行尾逐文件保持原样
                has_bom = raw.startswith(b"\xef\xbb\xbf")
                payload = new_text.encode("utf-8")
                if has_bom:
                    payload = b"\xef\xbb\xbf" + payload
                path.write_bytes(payload)

    print(f"\n干跑={'否' if args.apply else '是（加 --apply 才写盘）'}")
    print(f"改动文件: {len(changed)}")
    print(f"  旧行号 转换 {stats['line_converted']} / 命中 {stats['line_seen']}"
          f"（未映射 {stats['line_unmapped']}，已标注为「旧源行 N·未映射」）")
    print(f"  区间 转换 {stats['range_converted']}，部分转换 {stats['range_partial']}，"
          f"整段未映射 {stats['range_unmapped']}")
    print(f"  frontmatter sources 转换 {stats['frontmatter_converted']}")
    unmapped_total = stats["line_unmapped"] + stats["range_unmapped"] + stats["range_partial"]
    if unmapped_total:
        print(f"\n注意：{unmapped_total} 处旧行号在 EPUB 中没有唯一对应段落"
              f"（旧源在正文行之间插入空行、节标题与目录行），已显式标注为未映射，"
              f"不再以 clean.txt 行号冒充当前可回查定位。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())