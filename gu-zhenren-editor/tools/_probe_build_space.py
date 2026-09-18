# -*- coding: utf-8 -*-
"""Read-only probe: how large is the *effective* in-run build space?"""
import io, json, os, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tools", "_probe_build_space.md")


def load(name):
    with io.open(os.path.join(ROOT, "data", name), encoding="utf-8") as f:
        return json.load(f)


gu = load("gu.json")
rec = load("refinement_recipes.json")
sch = load("schools.json")
vb = load("v1_battle.json")
syn = load("synthesis.json")

def as_list(d, *keys):
    if isinstance(d, list):
        return d
    for k in keys:
        if isinstance(d, dict) and isinstance(d.get(k), list):
            return d[k]
    return []


glist = as_list(gu, "gu", "items", "entries")
rlist = as_list(rec, "recipes", "entries")

with_effect = [g for g in glist if g.get("v1_effect")]
effect_kinds = collections.Counter()
for g in with_effect:
    e = g.get("v1_effect")
    if isinstance(e, dict):
        for k in e.keys():
            effect_kinds[k] += 1

schools = collections.Counter(str(g.get("school", "?")) for g in glist)
ranks = collections.Counter(int(g.get("rank", 0)) for g in glist)
r_out = collections.Counter()
for r in rlist:
    r_out[str(r.get("output_gu_id", r.get("output", "?")))] += 1

lines = []
lines.append("# 局内构筑空间探针（只读）\n")
lines.append("- 蛊定义总数: **%d**" % len(glist))
lines.append("- 带 `v1_effect`（能进战斗）的蛊: **%d** (%.1f%%)"
             % (len(with_effect), 100.0 * len(with_effect) / max(1, len(glist))))
lines.append("- v1_effect 键分布: %s" % dict(effect_kinds))
lines.append("")
lines.append("- 流派分布 (前 12): %s" % schools.most_common(12))
lines.append("- rank 分布: %s" % sorted(ranks.items()))
lines.append("")
lines.append("- 合成配方总数: **%d**" % len(rlist))
lines.append("- 配方产出去重后蛊数: %d" % len(r_out))
top = r_out.most_common(8)
lines.append("- 产出最多的蛊 (前 8): %s" % top)
lines.append("")
if isinstance(sch, dict):
    lines.append("- schools.json 顶层键: %s" % list(sch.keys()))
    slist = as_list(sch, "schools", "entries")
    if slist:
        lines.append("- 流派数: %d" % len(slist))
if isinstance(vb, dict):
    lines.append("- v1_battle.json 顶层键: %s" % list(vb.keys()))
if isinstance(syn, dict):
    lines.append("- synthesis.json 顶层键: %s" % list(syn.keys()))
lines.append("")

io.open(OUT, "w", encoding="utf-8").write("\n".join(lines))
print("WROTE", OUT)
