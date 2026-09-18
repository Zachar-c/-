# -*- coding: utf-8 -*-
"""Parse verify_pacing_density.gd output -> per-layer / per-seed battle-share variance.

Usage:
    python tools/measure_category_variance.py [input_txt] [output_md]
Defaults: tools/_baseline_e5a_40seeds.txt -> tools/_measure_out.md

This is the M1/M2 measurement half of the layer-temperament gate
(see docs/superpowers/specs/2026-09-16-rogue-layer-temperament-spec.md §7).
It is measurement-only: it never touches data/ or scripts/.
"""
import io, os, re, statistics, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "_baseline_e5a_40seeds.txt")
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "_measure_out.md")

if not os.path.exists(SRC):
    raise SystemExit("missing input: " + SRC)

txt = io.open(SRC, encoding="utf-8", errors="replace").read()
lines = txt.splitlines()

cur_seed = None
rows = []
agg = {}
full = []
for ln in lines:
    m = re.search(r"===== seed (\d+) =====", ln)
    if m:
        cur_seed = int(m.group(1))
        continue
    m = re.search(r"L(\d) battle=(\d+) rest=(\d+) unknown=(\d+) trade=(\d+) total=(\d+)", ln)
    if m and cur_seed is not None:
        L = int(m.group(1))
        b, r, u, t, tot = (int(m.group(i)) for i in (2, 3, 4, 5, 6))
        rows.append((cur_seed, L, b, r, u, t, tot))
        agg.setdefault(L, []).append(float(b) / tot if tot else 0.0)
        continue
    m = re.search(r"FULL battle share=([\d.]+)", ln)
    if m and cur_seed is not None:
        full.append(float(m.group(1)))

# Anti-noop canary: a parse that found nothing must fail loudly, not print a report.
seeds_seen = len({r[0] for r in rows})
if not rows or seeds_seen < 2:
    raise SystemExit("CANARY FAIL: parsed %d rows / %d seeds from %s" % (len(rows), seeds_seen, SRC))

out = []
out.append("# 类别占比方差测量（%d 种子）\n" % seeds_seen)
out.append("- 输入 `%s` · 解析 %d 个 (seed, layer) 行" % (os.path.basename(SRC), len(rows)))
out.append("")
out.append("## 每层随机槽 battle 占比\n")
out.append("| 层 | 均值 | 标准差 | 最小 | 最大 | 极差 |")
out.append("|---|---|---|---|---|---|")
for L in sorted(agg):
    v = agg[L]
    out.append("| L%d | %.3f | %.3f | %.3f | %.3f | %.3f |"
               % (L, statistics.fmean(v), statistics.pstdev(v), min(v), max(v), max(v) - min(v)))
allv = [x for L in agg for x in agg[L]]
out.append("")
out.append("- 全层合并: 均值 %.3f, 标准差 %.3f, 极差 %.3f"
           % (statistics.fmean(allv), statistics.pstdev(allv), max(allv) - min(allv)))
out.append("")
out.append("## 整局 battle 占比\n")
if full:
    sigma = statistics.pstdev(full)
    out.append("- n=%d, 均值 %.3f, **标准差 %.3f**, 最小 %.3f, 最大 %.3f"
               % (len(full), statistics.fmean(full), sigma, min(full), max(full)))
    out.append("- 门禁带 [0.50, 0.60]；越界种子数 = %d"
               % sum(1 for x in full if x < 0.50 or x > 0.60))
    out.append("- **M2 判定（σ >= 0.050）: %s**" % ("PASS" if sigma >= 0.050 else "FAIL"))
out.append("")
out.append("## 门禁原文\n")
out.append("```")
out.extend([l for l in lines if l.startswith("  AGG ") or l.startswith("E5a ") or l.startswith("EXIT=")])
out.append("```")

io.open(OUT, "w", encoding="utf-8").write("\n".join(out))
print("WROTE", OUT)
