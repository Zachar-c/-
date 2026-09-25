#!/usr/bin/env python3
"""Runtime Benchmark 机械校验：pack 引用完整性 + pack 无死重。

用法：py -3 lore/wiki/tools/check_runtime_benchmark.py \
        [--benchmark lore/wiki/tools/benchmark-runtime-stage1.md] \
        [--pack lore/runtime/packs/south_border_rank1_combat.json]

校验（只看 pack JSON 与基准 md，不读 wiki 正文）：
1. 每道题「判分依据」引用的正向 ID 必须存在于 pack（实体/规则/关系）；
2. 负查询（!id）必须**不**存在于 pack（负查询题的正确性依赖缺席）；
3. pack 每个条目至少被一道计分题引用，或登记在「未覆盖项登记」表中——死重即失败；
4. 缺口题（「缺口题」节下）不计分，其 !GAP-* 令牌仅作缺席断言。

退出码：0 通过；1 有违规（打印明细）。
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]

TOKEN_SPLIT = re.compile(r"[、，,;；\s]+")


def split_rows(line: str) -> list[str]:
    return [c.strip() for c in line.strip().strip("|").split("|")]


def parse_benchmark(path: Path) -> tuple[list[dict], list[str]]:
    """返回 (题目行, 未覆盖登记条目)。题目行: {no, section, tokens}。"""
    scored: list[dict] = []
    uncovered: list[str] = []
    section = ""
    table_mode: str | None = None  # None | 'questions' | 'uncovered'
    header: list[str] | None = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line.startswith("#"):
            section = line.lstrip("#").strip()
            table_mode = None
            header = None
            continue
        if not line.startswith("|"):
            table_mode = None if not line else table_mode
            continue
        cells = split_rows(line)
        if all(re.fullmatch(r":?-{2,}:?", c) for c in cells):
            continue
        if header is None:
            header = cells
            if any("判分依据" in h for h in header):
                table_mode = "questions"
            elif header and header[0].startswith("pack 条目"):
                table_mode = "uncovered"
            else:
                table_mode = None
            continue
        if table_mode == "questions":
            idx = next((i for i, h in enumerate(header) if "判分依据" in h), None)
            if idx is None or len(cells) <= idx or not cells[0] or cells[0] == "#":
                continue
            tokens = [t for t in TOKEN_SPLIT.split(cells[idx]) if t]
            scored.append({"no": cells[0], "section": section, "tokens": tokens})
        elif table_mode == "uncovered":
            uncovered.append(cells[0])
    return scored, uncovered


def load_pack_ids(pack_path: Path) -> tuple[set[str], dict]:
    pack = json.loads(pack_path.read_text(encoding="utf-8"))
    ids = {e["id"] for e in pack.get("entities", [])}
    # IR v0.2：实体状态行（states[].id）也是可引用的 pack 条目
    ids |= {s["id"] for e in pack.get("entities", []) for s in e.get("states", [])}
    ids |= {r["id"] for r in pack.get("rules", [])}
    ids |= {r["id"] for r in pack.get("relations", [])}
    return ids, pack


def dead_weight_exempt(pack: dict) -> set[str]:
    """实体状态行（states[].id）随实体承载，不计入死重统计（其宿主实体已被题目覆盖）。"""
    return {s["id"] for e in pack.get("entities", []) for s in e.get("states", [])}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--benchmark", default="lore/wiki/tools/benchmark-runtime-stage1.md")
    ap.add_argument("--pack", default="lore/runtime/packs/south_border_rank1_combat.json")
    args = ap.parse_args()

    bench_path = REPO / args.benchmark
    pack_path = REPO / args.pack
    scored, uncovered = parse_benchmark(bench_path)
    pack_ids, pack = load_pack_ids(pack_path)
    if not scored:
        print("[check_runtime_benchmark] 错误：基准文件未解析到题目表", file=sys.stderr)
        sys.exit(1)

    errors: list[str] = []
    gap_questions = 0
    cited: set[str] = set()
    for q in scored:
        is_gap = "缺口" in q["section"]
        for tok in q["tokens"]:
            negative = tok.startswith("!")
            target = tok[1:] if negative else tok
            if negative:
                if target in pack_ids and not target.startswith("GAP-"):
                    errors.append(f"题{q['no']}：负查询 {target} 竟存在于 pack")
                continue
            if target not in pack_ids:
                errors.append(f"题{q['no']}：判分依据 {target} 不在 pack（拼错或未编译）")
            else:
                cited.add(target)
        if is_gap:
            gap_questions += 1
            continue
        positives = [t for t in q["tokens"] if not t.startswith("!")]
        if not positives:
            continue  # 纯负查询题（正确行为 = 识别 canon 缺席），无正向依据属预期
        if not (set(positives) & pack_ids):
            errors.append(f"题{q['no']}：计分题无任何有效 pack 依据")

    dead = sorted(pack_ids - cited - dead_weight_exempt(pack))
    uncovered_registered = {u for u in uncovered if u and u != "（当前无）"}
    for item in dead:
        if item not in uncovered_registered:
            errors.append(f"pack 死重：{item} 未被任何计分题引用，也未登记未覆盖项")

    total = len(scored) - gap_questions
    print(f"[check_runtime_benchmark] pack 条目 {len(pack_ids)}（含实体状态行，死重豁免）；"
          f"计分题 {total}（缺口题 {gap_questions}）；被引用 {len(cited)}")
    if errors:
        print("[check_runtime_benchmark] 校验失败：", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        sys.exit(1)
    print("[check_runtime_benchmark] 通过：引用完整，无死重")


if __name__ == "__main__":
    main()
