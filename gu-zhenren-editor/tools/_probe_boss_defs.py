# -*- coding: utf-8 -*-
"""Read-only probe: dump every tier==boss enemy definition + all fields present."""
import io, json, os, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tools", "_probe_boss_defs.md")

with io.open(os.path.join(ROOT, "data", "enemies.json"), encoding="utf-8") as f:
    en = json.load(f)
elist = en if isinstance(en, list) else en.get("enemies", [])
with io.open(os.path.join(ROOT, "data", "nodes.json"), encoding="utf-8") as f:
    nd = json.load(f)

bosses = [e for e in elist if str(e.get("tier", "")) == "boss"]
allkeys = collections.Counter()
for e in elist:
    for k in e.keys():
        allkeys[k] += 1

lines = []
lines.append("# Boss 定义探针（只读）\n")
lines.append("- 敌人总数 %d，其中 tier==boss 共 **%d**" % (len(elist), len(bosses)))
lines.append("- 全部敌人字段出现频次: %s" % dict(allkeys.most_common()))
lines.append("")

lines.append("## 每个 boss 的完整定义\n")
for b in sorted(bosses, key=lambda x: str(x.get("id", ""))):
    lines.append("### `%s`" % b.get("id"))
    for k in sorted(b.keys()):
        v = b[k]
        if isinstance(v, (list, dict)):
            v = json.dumps(v, ensure_ascii=False)
            if len(v) > 300:
                v = v[:300] + " ...(截断)"
        lines.append("  - %s = %s" % (k, v))
    lines.append("")

lines.append("## 关底台节点（nodes.json）\n")
for n in nd.get("nodes", []):
    if int(n.get("layer_boss", 0) or 0) > 0:
        lines.append("### `%s` (layer_boss=%s)" % (n.get("id"), n.get("layer_boss")))
        for k in sorted(n.keys()):
            if k == "id":
                continue
            v = n[k]
            if isinstance(v, (list, dict)):
                v = json.dumps(v, ensure_ascii=False)
            lines.append("  - %s = %s" % (k, v))
        lines.append("")

io.open(OUT, "w", encoding="utf-8").write("\n".join(lines))
print("WROTE", OUT)
