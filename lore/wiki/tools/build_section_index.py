#!/usr/bin/env python3
"""生成 lore/wiki/source/section-index.md（原文卷节标记索引）。

源：仓库根本地 蛊真人-clean.txt（UTF-8，不入 Git）。
用法：py -3 lore/wiki/tools/build_section_index.py
输出为生成物：原文重新清洗或替换后必须重跑本脚本并复核受影响引用。

诚实边界（与输出文件一致）：
- 行号是唯一精确锚点；节号按段重置且非全局唯一，仅作人文定位辅助。
- 标记行存在「章节目录 [全局章号.]」站点前缀与少量行内嵌标记，均收录并备注。
- 「段」按节号重置推断（落到 1 或差距>100），不代表原文卷结构；
  全文仅一处卷标记（第一卷：魔性不改）。
- 重复标记、段内跳号与相邻标记大间隔在输出中显式登记。
"""
from __future__ import annotations

import re
from datetime import date
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SRC = REPO / "蛊真人-clean.txt"
OUT = REPO / "lore" / "wiki" / "source" / "section-index.md"

CN = {"零": 0, "一": 1, "二": 2, "三": 3, "四": 4, "五": 5,
      "六": 6, "七": 7, "八": 8, "九": 9, "两": 2}
# 标记行：可选「章节目录 [全局章号.]」前缀 + 第X节
MARK = re.compile(
    r"^\s*(?:章节目录\s*((?:\d+[.．])?)\s*)?第([零一二三四五六七八九十百千两0-9]+)节[：:]?\s*(.*)$")
# 行内嵌标记（与正文粘在同一行，如 「”蛊真人 第四十八节：白羽飞象”“连…」）
EMBED = re.compile(r"第([零一二三四五六七八九十百千两0-9]+)节[：:]")
LOOSE_PREFIX = re.compile(r"^[^第]*蛊真人\s*$")


def c2n(s: str) -> int | None:
    s = s.replace("两", "二")
    if s.isdigit():
        return int(s)
    total = num = 0
    for ch in s:
        if ch in CN:
            num = CN[ch]
        elif ch == "十":
            total += (num or 1) * 10
            num = 0
        elif ch == "百":
            total += (num or 1) * 100
            num = 0
        else:
            return None
    return total + num


def clean_title(t: str) -> str:
    t = re.sub(r"\(第\d+/\d+页\)\s*$", "", t).strip()
    return t.rstrip("：: ").strip()


def main() -> None:
    lines = SRC.read_text(encoding="utf-8").splitlines()
    marks: list[dict] = []  # line, value, title, global_no, embedded
    for i, l in enumerate(lines):
        m = MARK.match(l)
        if m:
            marks.append({
                "line": i + 1, "value": c2n(m.group(2)),
                "title": clean_title(m.group(3)), "global_no": m.group(1) or "",
                "embedded": False,
            })
            continue
        e = EMBED.search(l)
        if e and LOOSE_PREFIX.match(l[: e.start()]):
            tail = l[e.end():]
            title = re.split(r"[“”]", tail)[0]
            marks.append({
                "line": i + 1, "value": c2n(e.group(1)),
                "title": clean_title(title), "global_no": "",
                "embedded": True,
            })

    # 分段：仅在节号真重置（落到 1 且前值非 1）处切段；
    # 其余段内下降（如 517→193→518 的孤立突降）标记为编号异常，不分段
    zones: list[list[int]] = []
    prev: int | None = None
    for seq, mk in enumerate(marks):
        v = mk["value"]
        if seq == 0:
            zones.append([seq])
        elif v is not None and prev is not None and v == 1 and prev != 1:
            zones.append([seq])
        else:
            zones[-1].append(seq)
        if v is not None:
            prev = v
    zone_starts = {zs[0] for zs in zones}

    anomaly: dict[int, str] = {}
    for seq, mk in enumerate(marks):
        if seq in zone_starts or seq == 0:
            continue  # 段边界的真重置不算异常
        v = mk["value"]
        prev = marks[seq - 1]["value"]
        if v is not None and prev is not None and v < prev:
            nxt = marks[seq + 1]["value"] if seq + 1 < len(marks) else None
            if nxt is not None and nxt > v:
                anomaly[seq] = f"段内编号突降（{prev}→{v}→{nxt}，疑似源文本编号错误）"
            else:
                anomaly[seq] = f"段内编号下降（{prev}→{v}，后续未回升）"

    zn = len(zones)
    zname = ["一二三四五六七八九十"[i] if i < 10 else str(i + 1) for i in range(zn)]
    seq_zone: dict[int, int] = {}
    for zi, zs in enumerate(zones):
        for s in zs:
            seq_zone[s] = zi

    # 段内重复检测 + 相邻标记大间隔
    seen_in_zone: dict[tuple[int, str], int] = {}
    dup_rows: dict[int, tuple[int, int]] = {}
    gap_note: dict[int, int] = {}
    BIG_GAP = 5000
    for zi, zs in enumerate(zones):
        for s in zs:
            mk = marks[s]
            key = (mk["value"] if mk["value"] is not None else -1, mk["title"])
            if key in seen_in_zone:
                dup_rows[s] = (seen_in_zone[key], marks[seen_in_zone[key]]["line"])
            else:
                seen_in_zone[key] = s
            if s + 1 < len(marks):
                gap = marks[s + 1]["line"] - mk["line"]
                if gap > BIG_GAP:
                    gap_note[s] = gap

    out: list[str] = []
    w = out.append
    w("# 原文卷节索引（蛊真人-clean.txt）")
    w("")
    w(f"> 本文件由 `tools/build_section_index.py` 生成（{date.today().isoformat()}），"
      f"源为仓库根本地 `蛊真人-clean.txt`（UTF-8，{len(lines):,} 行，不入 Git）。")
    w("> 原文重新清洗或替换后必须重新生成本表并复核受影响引用。")
    w("")
    w("## 用法与边界（诚实登记）")
    w("")
    w("- 行号是唯一精确锚点：引用一律写 `蛊真人-clean.txt:行号`。节号按段重置且非全局唯一，只作人文定位辅助。")
    w(f"- 「全局序」是本表给全部 {len(marks)} 个节标记的稳定顺序号（1–{len(marks)}），可作引用助记（写作 节#N）。")
    w("- 标记行含站点杂质：多数带「章节目录」前缀、少量带全局章号（如 4477.）、4 行与正文同行（行内嵌），均如实收录并备注。")
    w("- 原文仅一处卷标记（第 247 行「第一卷：魔性不改」）；「段」按节号重置推断，不代表原文卷结构。")
    w("- 重复标记与相邻标记大间隔见下方专节；这些区间的引用以行号为准。")
    w("")
    w("## 段级摘要")
    w("")
    w("| 段 | 行范围 | 原节号范围 | 标记数 |")
    w("|---|---|---|---|")
    for zi, zs in enumerate(zones):
        vals = [marks[s]["value"] for s in zs if marks[s]["value"] is not None]
        w(f"| {zname[zi]} | {marks[zs[0]]['line']:,}–{marks[zs[-1]]['line']:,} | "
          f"{min(vals)}–{max(vals)} | {len(zs)} |")
    w(f"（共 {zn} 段、{len(marks)} 个节标记；段内含重复与跳号，见总表备注与专节。）")
    w("")
    w("## 节标记总表")
    w("")
    w("| 全局序 | 段 | 原节号 | 节题 | 起始行 | 备注 |")
    w("|---|---|---|---|---|---|")
    for s, mk in enumerate(marks):
        note = ""
        if mk["global_no"]:
            note += f"全局章号 {mk['global_no'].rstrip('.．')}；"
        if mk["embedded"]:
            note += "行内嵌标记（与正文同行）；"
        if s in anomaly:
            note += anomaly[s] + "；"
        if s in dup_rows:
            note += f"重复（首现 节#{dup_rows[s][0] + 1}@{dup_rows[s][1]:,}）；"
        if s in gap_note:
            note += f"至下节间隔 {gap_note[s]:,} 行；"
        w(f"| {s + 1} | {zname[seq_zone[s]]} | {mk['value']} | {mk['title']} | "
          f"{mk['line']:,} | {note.rstrip('；')} |")
    w("")
    w("## 重复标记专节")
    w("")
    w("同段内同号同题的后续出现（引用优先首现；重复块是否逐字一致需回原文比对）：")
    w("")
    if dup_rows:
        for s in sorted(dup_rows):
            mk = marks[s]
            w(f"- 节#{s + 1}（第{mk['value']}节「{mk['title']}」@{mk['line']:,}）"
              f"——首现 节#{dup_rows[s][0] + 1}@{dup_rows[s][1]:,}")
    else:
        w("（无）")
    w("")
    w("## 相邻标记大间隔（>5,000 行）")
    w("")
    if gap_note:
        w("引用这些区间时行号之外没有节标记可依托：")
        w("")
        for s, g in sorted(gap_note.items()):
            w(f"- {marks[s]['line']:,} → {marks[s + 1]['line']:,}（约 {g / 10000:.1f} 万行）")
    else:
        w("（无）")
    w("")

    OUT.write_text("\n".join(out) + "\n", encoding="utf-8", newline="\n")

    # ---- 校验输出（人工复核用，不做硬断言）----
    print(f"markers: {len(marks)}  zones: {zn}  ->  {OUT}")
    embedded = [mk for mk in marks if mk["embedded"]]
    print(f"embedded markers: {len(embedded)}: " +
          ", ".join(f"L{mk['line']}(第{mk['value']}节)" for mk in embedded))
    print("known-anchor spot checks:")
    print(f"  #1 = L{marks[0]['line']} 第{marks[0]['value']}节 {marks[0]['title']}")
    for want in (9736, 10930, 313034, 323400, 431716):
        lo = max(s for s, mk in enumerate(marks) if mk["line"] <= want)
        nxt = marks[lo + 1] if lo + 1 < len(marks) else None
        tail = f" → 下一节 #{lo + 2} @ {nxt['line']:,}" if nxt else "（末标记）"
        print(f"  line {want}: 节#{lo + 1} 第{marks[lo]['value']}节「{marks[lo]['title']}」"
              f"@{marks[lo]['line']:,}{tail}")


if __name__ == "__main__":
    main()
