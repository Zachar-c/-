#!/usr/bin/env python3
"""蒸馏率正式指标：source tokens → retrieved wiki tokens → QA accuracy。

词表：tiktoken cl100k_base（GPT-4 系）。注意：这不是 GLM 官方词表，
绝对 token 数是该词表口径；簇间对比与比值有效，不要跨词表混用数字。

簇定义与三个基准文件（benchmark-qms/fate/xq.md）的口径一致：
- QMS：原文窗口 = 906–17148 行（连续窗口）；wiki = 6 页。
- FATE：原文窗口 = 323070–323780 行（逐段核验窗口）；wiki = 4 页。
- XQ：原文窗口 = 各页引用的原文窗口并集（跨窗口规则簇）；wiki = 4 页。

QA accuracy 取各基准文件当前回归记录的首测得分。
用法：py -3 lore/wiki/tools/measure_distillation.py
"""
from __future__ import annotations

from pathlib import Path

import tiktoken

REPO = Path(__file__).resolve().parents[3]
NOVEL = REPO / "蛊真人-clean.txt"

# (名称, 原文窗口 [(起, 止)...]，wiki 页, QA 得分, 题数)
CLUSTERS = [
    (
        "QMS（青茅山·剧情型）",
        [(906, 17148)],
        [
            "lore/wiki/characters/fang-yuan.md",
            "lore/wiki/events/qing-mao-mountain.md",
            "lore/wiki/gu/moonlight-gu.md",
            "lore/wiki/gu/small-light-gu.md",
            "lore/wiki/world/primeval-essence.md",
            "lore/wiki/world/gu-care-and-refinement.md",
        ],
        (49.5, 50),
    ),
    (
        "FATE（宿命大战·叙事难点型）",
        [(323070, 323780)],
        [
            "lore/wiki/gu/spring-autumn-cicada.md",
            "lore/wiki/characters/red-lotus.md",
            "lore/wiki/gu/fate-gu.md",
            "lore/wiki/events/fate-war.md",
        ],
        (50, 50),
    ),
    (
        "XQ（仙窍飞轮·规则型）",
        [
            (1154, 1160), (1004, 1010), (1156, 1218), (1354, 1362),
            (1872, 1892), (3612, 3614), (4258, 4260), (4656, 4678),
            (4673, 4676), (4952, 4960), (5222, 5230), (8536, 8536),
            (14744, 14748), (16276, 16276), (20672, 20672), (21664, 21664),
            (50192, 50192), (60582, 60582), (69304, 69304), (69622, 69622),
            (70034, 70034), (70356, 70362), (75764, 75788), (76284, 76284),
            (85306, 85310), (86506, 86510), (87532, 87532),
            (112670, 112726), (112720, 112726), (121474, 121474),
            (121986, 122000), (122006, 122030), (123708, 123722),
            (134168, 134178), (136548, 136564), (138684, 138712),
            (149584, 149598), (150406, 150468), (150438, 150442),
            (171108, 171168), (171278, 171288),
        ],
        [
            "lore/wiki/world/cultivation-system.md",
            "lore/wiki/world/aptitude-and-aperture.md",
            "lore/wiki/world/primeval-essence.md",
            "lore/wiki/world/world-operating-system.md",
        ],
        (50, 50),
    ),
]


def main() -> None:
    enc = tiktoken.get_encoding("cl100k_base")
    lines = NOVEL.read_text(encoding="utf-8").splitlines()

    rows = []
    for name, windows, pages, (score, total) in CLUSTERS:
        idx: set[int] = set()
        for a, b in windows:
            idx.update(range(a - 1, min(b, len(lines))))
        source_text = "\n".join(lines[i] for i in sorted(idx))
        source_tokens = len(enc.encode(source_text))
        source_chars = sum(len(lines[i]) + 1 for i in sorted(idx))

        wiki_tokens = 0
        wiki_chars = 0
        for p in pages:
            t = (REPO / p).read_text(encoding="utf-8")
            wiki_tokens += len(enc.encode(t))
            wiki_chars += len(t)

        rows.append({
            "name": name, "src_tok": source_tokens, "src_chr": source_chars,
            "wiki_tok": wiki_tokens, "wiki_chr": wiki_chars,
            "ratio_tok": source_tokens / wiki_tokens,
            "per_q": wiki_tokens / total, "score": score, "total": total,
            "acc": score / total * 100,
        })

    out = []
    w = out.append
    w("# 蒸馏率正式指标（distillation metrics）")
    w("")
    w(f"> 词表：tiktoken cl100k_base 0.14.0（GPT-4 系）。非 GLM 官方词表——绝对值为该词表口径，簇间对比与比值有效。生成工具：`tools/measure_distillation.py`。")
    w("> QA accuracy 取各基准文件当前回归记录的首测得分（独立盲测）。")
    w("")
    w("| 簇 | 原文 tokens | Wiki tokens | 压缩倍数（token 口径） | 每题摊销 Wiki tokens | QA accuracy |")
    w("|---|---|---|---|---|---|")
    for r in rows:
        w(f"| {r['name']} | {r['src_tok']:,} | {r['wiki_tok']:,} | {r['ratio_tok']:.1f}× | "
          f"{r['per_q']:,.0f} | {r['acc']:.0f}%（{r['score']}/{r['total']}） |")
    w("")
    w("口径说明：")
    w("")
    w("- 「原文 tokens」= 该簇基准文件声明的核验窗口内的原文 token 数（QMS 为连续窗口；XQ 为各页引用窗口的并集）。")
    w("- 「Wiki tokens」= 盲测白名单内簇页面的全量 token（盲测协议为一次全簇读取服务 50 题，故每题摊销 = 全簇 / 50）。")
    w("- 字符口径参考：QMS 13.9×、FATE 0.8×（跨窗口综合页大于单窗口属预期）、XQ 跨窗口不适用——详见各基准文件基线节。")
    w("")

    metrics_path = REPO / "lore" / "wiki" / "tools" / "distillation-metrics.md"
    metrics_path.write_text("\n".join(out) + "\n", encoding="utf-8", newline="\n")
    print("\n".join(out))


if __name__ == "__main__":
    main()
