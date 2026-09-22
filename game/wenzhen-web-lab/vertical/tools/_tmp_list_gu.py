import json
from pathlib import Path
gu = json.loads(Path("game/data/gu.json").read_text(encoding="utf-8"))
keys = (
    "moon", "light", "jade", "stone", "whirl", "orchid",
    "frost", "phantom", "blood", "taiyin", "golden",
    "rainbow", "mark", "spin", "veil", "soul", "shadow",
    "wheel", "condense", "treasure", "glow",
)
rows = [g for g in gu if any(k in g["id"] for k in keys)]
rows.sort(key=lambda g: (g.get("rank", 1), g["id"]))
for g in rows:
    print(f"{g.get('rank')} {g['id']} value={g.get('value')}")
print("total", len(rows), "of", len(gu))
