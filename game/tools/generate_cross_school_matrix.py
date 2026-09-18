#!/usr/bin/env python3
"""D1b first-batch cross-school matrix generator (rank-3 layer).

For every rank-3 gu that no recipe produces yet, emits one fixed recipe:
  main     = same-school rank-2 gu   (round-robin over the school pool)
  partner  = partner-school rank-2 gu (round-robin over the partner pool)
Partner directions come from SCHOOL_PARTNER (the D1b first-batch direction
matrix: R4 moon_shadow light-qi and R5 blood_moon light-blood are the
hard corpus anchors; the rest are derived by wuxing/semantic pairing).

v1 `input_gu_ids` are concrete ids (execution requirement: fixed recipes
consume by definition_id); v2 `inputs` mirrors {school, rank, count} per
the D1 v2 schema. Every entry carries a `derived:` source anchor.

Usage (from repo root):
  py -3 tools/generate_cross_school_matrix.py            # write + report
  py -3 tools/generate_cross_school_matrix.py --dry-run  # report only

Idempotent: existing `mx_*` recipes are replaced; curated recipes untouched.
Re-pairing a school = edit SCHOOL_PARTNER and re-run.
"""
import argparse
import collections
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GU = os.path.join(ROOT, "data", "gu.json")
RECIPES = os.path.join(ROOT, "data", "refinement_recipes.json")
NAMES = os.path.join(ROOT, "data", "gu_names.json")

# D1b first-batch direction matrix: school -> (partner school, anchor note).
SCHOOL_PARTNER = {
    "light": ("qi", "R04 月影蛊 光×气 原文锚 clean 17152-17155"),
    "blood": ("light", "R05 血月蛊 光×血 同构（读书笔记 A2b 蛊虫盘）"),
    "qi": ("light", "R04 镜像：气承光耀"),
    "water": ("fire", "水火既济；鬼火蛊水火炼法 clean 150990-151208"),
    "fire": ("water", "水火既济镜像"),
    "wood": ("earth", "木植于土"),
    "earth": ("wood", "土养草木"),
    "gold": ("sword", "锐金成剑"),
    "sword": ("gold", "剑承金气"),
    "force": ("bone", "力发筋骨"),
    "bone": ("force", "骨承其力"),
    "soul": ("dream", "魂梦交感"),
    "dream": ("soul", "梦载魂影"),
    "wind": ("qi", "风行气随"),
    "refine": ("fire", "炉火炼材"),
    "heaven": ("luck", "天命气运"),
    "luck": ("heaven", "运承天时"),
    "human": ("wisdom", "人心生智"),
    "wisdom": ("human", "智出人心"),
    "slave": ("human", "奴道驭人"),
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true", help="report only")
    args = parser.parse_args()

    with open(GU, encoding="utf-8") as fh:
        gu = json.load(fh)
    with open(RECIPES, encoding="utf-8") as fh:
        data = json.load(fh)
    try:
        with open(NAMES, encoding="utf-8") as fh:
            names = json.load(fh)
    except FileNotFoundError:
        names = {}

    recipes = data.get("recipes", [])
    produced = {r.get("output_gu_id") for r in recipes}
    schools = {g["school"] for g in gu}
    missing = set(SCHOOL_PARTNER) - schools
    if missing:
        print("matrix references undeclared dao marks: %s" % sorted(missing))
        return 1

    rank2_by_school = collections.defaultdict(list)
    for g in gu:
        if g.get("rank") == 2:
            rank2_by_school[g["school"]].append(g["id"])
    for s in rank2_by_school:
        rank2_by_school[s].sort()
    empty = [s for s in SCHOOL_PARTNER
             if not rank2_by_school.get(s) or not rank2_by_school.get(SCHOOL_PARTNER[s][0])]
    if empty:
        print("schools lacking rank-2 pools: %s" % sorted(empty))
        return 1

    mains = collections.Counter()
    partners = collections.Counter()
    fresh = []
    targets = sorted(
        (g for g in gu if g.get("rank") == 3 and g["id"] not in produced),
        key=lambda g: g["id"],
    )
    for g in targets:
        s = g["school"]
        p_school, anchor = SCHOOL_PARTNER[s]
        main_id = rank2_by_school[s][mains[s] % len(rank2_by_school[s])]
        mains[s] += 1
        partner_id = rank2_by_school[p_school][
            partners[p_school] % len(rank2_by_school[p_school])]
        partners[p_school] += 1
        fresh.append({
            "id": "mx_" + g["id"][: -len("_gu")],
            "kind": "fixed",
            "input_gu_ids": [main_id, partner_id],
            "input_min_rank": 2,
            "output_gu_id": g["id"],
            "output_rank": 3,
            "source": (
                "derived:D1b 首批方向 %s；3转=2转+2转跨流派（同构月影 光×气 / 血月 光×血）；"
                "主蛊%s×伴蛊%s" % (
                    anchor,
                    names.get(main_id, main_id),
                    names.get(partner_id, partner_id),
                )
            ),
            "inputs": [
                {"school": s, "rank": 2, "count": 1},
                {"school": p_school, "rank": 2, "count": 1},
            ],
        })

    kept = [r for r in recipes if not str(r.get("id", "")).startswith("mx_")]
    print("rank3 targets: %d, generating %d mx_ recipes (replacing %d old mx_)"
          % (len(targets), len(fresh), len(recipes) - len(kept)))
    if not args.dry_run and fresh:
        data["recipes"] = kept + fresh
        with open(RECIPES, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(data, fh, ensure_ascii=False, indent=1)
            fh.write("\n")
        print("written: %s (total recipes %d)" % (RECIPES, len(data["recipes"])))

    covered = produced | {r["output_gu_id"] for r in fresh}
    high = [g for g in gu if g.get("rank") in (3, 4, 5)]
    gaps = [g for g in high if g["id"] not in covered]
    by_rank = collections.Counter(g["rank"] for g in gaps)
    print("rank3-5 coverage now: %d/%d, remaining gaps %s"
          % (len(high) - len(gaps), len(high), dict(sorted(by_rank.items()))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
