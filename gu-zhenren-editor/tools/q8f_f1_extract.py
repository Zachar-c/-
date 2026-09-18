"""Q8-F F1 economy audit extractor.

Read-only. Dumps every economic fact needed by ECONOMY_CURRENT_AUDIT.md.
Usage: python tools/q8f_f1_extract.py
"""

import json
import os
from collections import Counter, defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")


def load(name):
    with open(os.path.join(DATA, name + ".json"), encoding="utf-8") as fh:
        return json.load(fh)


balance = load("balance")
shops = load("shops")
loot = load("loot_tables")
recipes = load("refinement_recipes")
pacing = load("pacing")
gu = load("gu")
enemies = load("enemies")
nodes = load("nodes")

OUT = []
def p(*args):
    line = " ".join(str(a) for a in args)
    OUT.append(line)
    print(line)


p("#" * 70)
p("# F1 EXTRACT — economy raw facts")
p("#" * 70)

# ---------------------------------------------------------------- balance
p("\n\n=== [A] BALANCE CONSTANTS ===")
p(json.dumps(balance, ensure_ascii=False, indent=1))

# ---------------------------------------------------------------- materials
p("\n\n=== [B] MATERIALS (loot_tables.materials) ===")
materials = loot["materials"]
p("count =", len(materials))
for mid, m in materials.items():
    p("\n-- %s (%s)" % (mid, m.get("name_zh", "?")))
    p("   value=%s value_tier=%s rank=%s reference_value=%s" % (
        m.get("value"), m.get("value_tier"), m.get("rank"), m.get("reference_value")))
    p("   dao_tags=%s diet_tags=%s" % (m.get("dao_tags"), m.get("diet_tags")))
    p("   is_common=%s is_exclusive=%s divisible=%s public_liquidity=%s" % (
        m.get("is_common"), m.get("is_exclusive"), m.get("divisible"), m.get("public_liquidity")))
    p("   use=%s" % json.dumps(m.get("use", {}), ensure_ascii=False))

# ---------------------------------------------------------------- loot tables
p("\n\n=== [C] LOOT TABLES ===")
p("pity =", json.dumps(loot.get("pity"), ensure_ascii=False))
for tier, t in loot["loot"].items():
    p("\n-- tier=%s" % tier)
    p("   material_count=%s material_pool=%s" % (t.get("material_count"), t.get("material_pool")))
    p("   gu_chance_pct=%s forced_rarity=%s" % (t.get("gu_chance_pct"), t.get("forced_rarity")))
    for k, v in t.items():
        if k not in ("material_count", "material_pool", "gu_chance_pct", "forced_rarity", "gu_pool"):
            p("   %s=%s" % (k, json.dumps(v, ensure_ascii=False)[:400]))

# ---------------------------------------------------------------- recipes
p("\n\n=== [D] REFINEMENT RECIPES ===")
rec = recipes["recipes"]
p("recipe count =", len(rec))
kind_counter = Counter()
rank_counter = Counter()
missing_output_rank = []
mat_use = defaultdict(int)          # material -> number of recipes using it
mat_total_consumed = defaultdict(int)  # material -> sum of quantities across recipes
recipes_with_materials = 0
recipes_with_stone_cost = 0
stone_costs = Counter()
gu_as_input = Counter()
for r in rec:
    rid = r.get("id", "?")
    kind_counter[r.get("kind", "?")] += 1
    rk = r.get("output_rank")
    if rk is None:
        missing_output_rank.append(rid)
    rank_counter[rk] += 1
    mats = r.get("materials", {})
    if mats:
        recipes_with_materials += 1
        for mid, qty in mats.items():
            mat_use[mid] += 1
            mat_total_consumed[mid] += int(qty)
    if "stone_cost" in r:
        recipes_with_stone_cost += 1
        stone_costs[int(r["stone_cost"])] += 1
    for gid in r.get("input_gu_ids", []):
        gu_as_input[gid] += 1

p("kind histogram =", dict(kind_counter))
p("output_rank distribution =", dict(sorted(
    ((str(k), v) for k, v in rank_counter.items()), key=lambda kv: str(kv[0]))))
p("recipes missing output_rank =", len(missing_output_rank))
p("recipes with materials field =", recipes_with_materials, "/", len(rec))
p("recipes with stone_cost =", recipes_with_stone_cost, "/", len(rec))
p("stone_cost values =", dict(sorted(stone_costs.items())))
p("distinct gu used as input =", len(gu_as_input))

p("\n-- MATERIAL usage in recipes (recipe_count, total_qty) --")
p("   materials referenced =", len(mat_use))
for mid in sorted(mat_use, key=lambda k: -mat_use[k]):
    p("   %-28s recipes=%-4d total_qty=%d" % (mid, mat_use[mid], mat_total_consumed[mid]))
p("   (unused materials) =", [m for m in loot["materials"] if m not in mat_use])

p("\n-- top 15 gu used as recipe input --")
for gid, cnt in gu_as_input.most_common(15):
    p("   %-30s %d" % (gid, cnt))

p("\n-- caravan_offers --")
caravan = recipes.get("caravan_offers", [])
p("count =", len(caravan))
p(json.dumps(caravan, ensure_ascii=False, indent=1)[:2500])

# ---------------------------------------------------------------- gu values
p("\n\n=== [E] GU VALUE TABLE (gu.json) ===")
p("gu count =", len(gu))
rank_hist = Counter()
rarity_hist = Counter()
school_rank = defaultdict(Counter)
explicit_effect = 0
for g in gu:
    rank_hist[g.get("rank")] += 1
    rarity_hist[g.get("rarity")] += 1
    school_rank[g.get("school")][g.get("rank")] += 1
    if g.get("v1_effect"):
        explicit_effect += 1
p("rank histogram =", dict(sorted(rank_hist.items(), key=lambda kv: kv[0])))
p("rarity histogram =", dict(rarity_hist))
p("explicit v1_effect =", explicit_effect, "/", len(gu))
p("value formula: gu_value_by_rank =", balance["gu_value_by_rank"])
p("gu_estimate_ratio =", balance.get("gu_estimate_ratio"))

# rarity x rank cross check (is rarity == rank?)
cross = defaultdict(Counter)
for g in gu:
    cross[g.get("rarity")][g.get("rank")] += 1
p("\n-- rarity x rank crosstab --")
for rarity in sorted(cross):
    p("   %-10s %s" % (rarity, dict(sorted(cross[rarity].items()))))

# ---------------------------------------------------------------- shops
p("\n\n=== [F] SHOPS ===")
offers = shops["offers"]
p("offer count =", len(offers))
kind_counter = Counter()
for o in offers:
    kind_counter[o.get("kind", "?")] += 1
p("kind histogram =", dict(kind_counter))
p("\n-- all offers --")
for i, o in enumerate(offers):
    p("[%02d] %s" % (i, json.dumps(o, ensure_ascii=False)))

# ---------------------------------------------------------------- pacing layers
p("\n\n=== [G] PACING (layers / stone budget) ===")
p("layers =", json.dumps(pacing.get("layers"), ensure_ascii=False))
p("advance_bonus_by_rank =", json.dumps(pacing.get("advance_bonus_by_rank"), ensure_ascii=False))
p("lifespan_milestones =", json.dumps(pacing.get("lifespan_milestones"), ensure_ascii=False))
p("turn_scaling =", json.dumps(pacing.get("turn_scaling"), ensure_ascii=False)[:600])

# ---------------------------------------------------------------- enemies
p("\n\n=== [H] ENEMIES ===")
p("enemy count =", len(enemies))
p("first enemy sample =", json.dumps(enemies[0], ensure_ascii=False)[:600])
ek = Counter()
for e in enemies:
    ek[e.get("tier", e.get("role", "?"))] += 1
p("tier/role histogram =", dict(ek))

# ---------------------------------------------------------------- nodes (economics)
p("\n\n=== [I] NODES — economy-relevant types ===")
p("nodes type =", type(nodes).__name__)
if isinstance(nodes, dict):
    p("keys =", list(nodes.keys())[:20])
    for k in list(nodes.keys())[:3]:
        p("  %s -> %s" % (k, json.dumps(nodes[k], ensure_ascii=False)[:400]))
    nt = Counter()
    for k, v in nodes.items():
        if isinstance(v, dict):
            nt[v.get("type", "?")] += 1
    p("node type histogram =", dict(nt))
elif isinstance(nodes, list):
    nt = Counter()
    for n in nodes:
        nt[n.get("type", "?") if isinstance(n, dict) else "str"] += 1
    p("node type histogram =", dict(nt))

# ---------------------------------------------------------------- write
with open(os.path.join(ROOT, "docs", "q8f", "_f1_extract.txt"), "w", encoding="utf-8") as fh:
    fh.write("\n".join(OUT))
p("\n\n[written] docs/q8f/_f1_extract.txt  (%d lines)" % len(OUT))
