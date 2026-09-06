#!/usr/bin/env python3
"""D1b cross-school matrix acceptance: every rank-3..5 gu must be reachable.

Reads data/refinement_recipes.json + data/gu.json and reports coverage:
for each rank-3..5 gu, is there >=1 recipe producing it? Ranked coverage
by school/rank, and the full unreachable list (sorted by school/rank).

Usage (from repo root):
  python tools/verify_recipe_coverage.py            # report + exit 1 if gaps
  python tools/verify_recipe_coverage.py --report   # report only, exit 0

This is the D1b acceptance line: recipes may only be merged once this
script reports zero unreachable rank-3..5 gu.
"""
import argparse
import collections
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GU = os.path.join(ROOT, "data", "gu.json")
RECIPES = os.path.join(ROOT, "data", "refinement_recipes.json")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", action="store_true",
                        help="report only; exit 0 even with gaps")
    args = parser.parse_args()

    with open(GU, encoding="utf-8") as fh:
        gu = json.load(fh)
    by_id = {g["id"]: g for g in gu}
    with open(RECIPES, encoding="utf-8") as fh:
        recipes = json.load(fh).get("recipes", [])

    produced = collections.Counter(x.get("output_gu_id") for x in recipes)
    high = [g for g in gu if g.get("rank") in (3, 4, 5)]
    unreachable = sorted(
        (g for g in high if produced.get(g["id"], 0) == 0),
        key=lambda g: (g.get("rank"), g.get("school", ""), g["id"]),
    )

    by_rank = collections.Counter(g.get("rank") for g in high)
    reached_by_rank = collections.Counter(
        g.get("rank") for g in high if produced.get(g["id"], 0) > 0)
    by_school = collections.Counter(
        (g.get("rank"), g.get("school", "")) for g in unreachable)

    print("recipe-producing recipes: %d" % len(recipes))
    print("rank3-5 gu: %d, reachable: %d, unreachable: %d" % (
        len(high), len(high) - len(unreachable), len(unreachable)))
    for rank in (3, 4, 5):
        print("  rank %d: %d/%d reachable" % (
            rank, reached_by_rank.get(rank, 0), by_rank.get(rank, 0)))
    if unreachable:
        print("unreachable by school/rank:")
        for (rank, school), count in sorted(by_school.items()):
            print("  rank %d %s: %d" % (rank, school, count))
        print("first 20 unreachable ids:")
        for g in unreachable[:20]:
            print("  %s (rank %s %s)" % (g["id"], g.get("rank"), g.get("school")))
    else:
        print("ALL rank-3..5 gu reachable - D1b coverage complete.")

    return 1 if (not args.report and unreachable) else 0


if __name__ == "__main__":
    sys.exit(main())
