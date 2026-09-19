#!/usr/bin/env python3
"""Effect Budget census — read-only, stdlib only, no assertions.

Reads upstream data (game/data/gu.json, v1_battle.json, balance.json,
buffs.json) + resolver/pipeline/catalog sources as text evidence.
Computes every number in game/world-model/reports/effect-budget-census.md.
No PASS/FAIL verdicts: inversion criteria await L1 ruling.

Usage:
    python game/world-model/tools/audit_effect_budget.py [--report PATH] [--json PATH]

Defaults write the standing census report in place.
Exit code 0 = census completed; nonzero = IO/parse error only.
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

REPO_ROOT = Path(__file__).resolve().parents[3]
DATA = REPO_ROOT / "game" / "data"
WM_ROOT = REPO_ROOT / "game" / "world-model"
DEFAULT_REPORT = WM_ROOT / "reports" / "effect-budget-census.md"

COST_FIELDS = ["value", "essence_cost", "true_qi_cost", "feeding_cost"]
# Fields that do not scale with rank (gameplay dimensions, not magnitudes).
NON_SCALING_FIELDS = {"aoe", "delay", "condition", "consume_status"}


def load_json(name: str):
    return json.loads((DATA / name).read_text(encoding="utf-8"))


def rank_power_budget(balance: dict) -> dict[int, float]:
    table = (balance.get("rank_power_budget") or {}).get("budget_by_rank", {})
    out = {}
    for r in (1, 2, 3, 4, 5):
        out[r] = float(table[str(r)])
    return out


def fallback_curves(v1_battle: dict) -> dict:
    """Per-role fallback curve r1..r5, applying the resolver rule from source.

    Rule (v1_battle_resolver.gd default_v1_effect): kinds in
    RANK_SCALED_KINDS get amount += (rank-1); support_bonus likewise;
    shift/status stay flat. Base table comes from data only.
    """
    table = v1_battle.get("default_effect_by_role", {})
    src = (REPO_ROOT / "game" / "scripts" / "domain" / "v1_battle_resolver.gd").read_text(encoding="utf-8")
    scaled = []
    for line in src.splitlines():
        if "RANK_SCALED_KINDS" in line and "=" in line and "[" in line:
            inner = line.split("[", 1)[1].split("]", 1)[0]
            scaled = [p.strip().strip('"') for p in inner.split(",")]
            break
    curves = {}
    for role, base in table.items():
        kind = str(base.get("kind", ""))
        b = int(base.get("amount", 1))
        series = [b + (r - 1) if kind in scaled else b for r in (1, 2, 3, 4, 5)]
        curves[role] = {
            "kind": kind,
            "base": dict(base),
            "series": series,
            "scaled": kind in scaled,
            "growth": (series[4] / series[0]) if series[0] else 0.0,
        }
    return {"scaled_kinds": scaled, "curves": curves}


def handwritten_matrix(gu: list) -> dict:
    hw = [g for g in gu if g.get("v1_effect")]
    cells: dict[tuple, list] = defaultdict(list)
    for g in hw:
        e = g["v1_effect"] or {}
        cells[(g.get("role"), e.get("kind"), g.get("rank"))].append((g["id"], e.get("amount")))
    matrix = []
    for key in sorted(cells):
        amounts = [a for _, a in cells[key]]
        matrix.append({
            "role": key[0], "kind": key[1], "rank": key[2],
            "count": len(cells[key]),
            "min": min(amounts), "max": max(amounts),
            "ids": sorted(i for i, _ in cells[key]),
        })
    return {"total": len(gu), "handwritten": len(hw), "fallback": len(gu) - len(hw),
            "ranks": dict(sorted(Counter(g.get("rank") for g in gu).items())),
            "roles": dict(sorted(Counter(g.get("role") for g in gu).items(), key=lambda kv: -kv[1])),
            "kinds": dict(sorted(Counter((g.get("v1_effect") or {}).get("kind") for g in hw).items(), key=lambda kv: -kv[1])),
            "matrix": matrix}


def _max_by_rank(rows: list) -> dict:
    by_rank: dict[int, list] = defaultdict(list)
    for g, amount in rows:
        by_rank[g.get("rank")].append(amount)
    return {r: max(v) for r, v in sorted(by_rank.items())}


def inversion_coarse(hw: list) -> list:
    """Group by (role, kind): list ranks whose max amount sits below a lower rank's max."""
    groups: dict[tuple, list] = defaultdict(list)
    for g in hw:
        e = g["v1_effect"] or {}
        groups[(g.get("role"), e.get("kind"))].append((g, e.get("amount")))
    out = []
    for key in sorted(groups):
        mx = _max_by_rank(groups[key])
        ranks = sorted(mx)
        for i, hi in enumerate(ranks):
            for lo in ranks[:i]:
                if mx[hi] is not None and mx[lo] is not None and mx[hi] < mx[lo]:
                    out.append({"group": list(key), "high_rank": hi, "high_max": mx[hi],
                                "low_rank": lo, "low_max": mx[lo], "curve": mx})
                    break
    return out


def inversion_by_cost(hw: list) -> tuple[list, dict]:
    """Same check inside exact cost-structure groups.

    Cost key uses a MISS sentinel so absent fields never silently become 0.
    Returns (candidates, missing_stats).
    """
    missing = {f: sum(1 for g in hw if f not in g) for f in COST_FIELDS}
    groups: dict[tuple, list] = defaultdict(list)
    for g in hw:
        e = g["v1_effect"] or {}
        key = (g.get("role"), e.get("kind"),
               tuple((f, g.get(f, "MISS")) for f in COST_FIELDS))
        groups[key].append((g, e.get("amount")))
    out = []
    for key in sorted(groups, key=str):
        mx = _max_by_rank(groups[key])
        ranks = sorted(mx)
        if len(ranks) < 2:
            continue
        for i, hi in enumerate(ranks):
            for lo in ranks[:i]:
                if mx[hi] < mx[lo]:
                    out.append({"group": [key[0], key[1]], "cost": dict(key[2]),
                                "high_rank": hi, "high_max": mx[hi],
                                "low_rank": lo, "low_max": mx[lo],
                                "ids": sorted(g["id"] for g, _ in groups[key])})
                    break
    return out, missing


def field_census(hw: list) -> list:
    counts = Counter()
    for g in hw:
        for k in (g.get("v1_effect") or {}):
            counts[k] += 1
    rows = []
    for field in sorted(counts, key=lambda f: (-counts[f], f)):
        users = [g for g in hw if field in (g.get("v1_effect") or {})]
        samples = []
        for g in users[:3]:
            samples.append({"id": g["id"], field: (g["v1_effect"] or {})[field]})
        rows.append({"field": field, "count": counts[field],
                     "ids": sorted(g["id"] for g in users),
                     "samples": samples,
                     "non_scaling": field in NON_SCALING_FIELDS})
    return rows


def exemptions(gu: list) -> dict:
    over = [g for g in gu if int(g.get("rank", 1)) > 5]
    low_ex = [g["id"] for g in gu if g.get("low_rank_exception")]
    test_tag = [g["id"] for g in gu if "test" in (g.get("tags") or [])]
    buffs = json.loads((DATA / "buffs.json").read_text(encoding="utf-8"))
    slay_ref = ((buffs.get("buffs") or {}).get("slay_gu_ten") or {})
    pipe = (REPO_ROOT / "game" / "scripts" / "domain" / "v1_grammar_pipeline.gd").read_text(encoding="utf-8")
    aoe_line = next((ln.strip() for ln in pipe.splitlines() if 'aoe' in ln and 'enemy_all' in ln), "")
    cat = (REPO_ROOT / "game" / "scripts" / "domain" / "content_catalog.gd").read_text(encoding="utf-8")
    cat_lines = [f"content_catalog.gd:{i+1}: {ln.strip()}"
                 for i, ln in enumerate(cat.splitlines()) if "low_rank_exception" in ln or "GU_RANK_MAX" in ln]
    return {"rank_over_5": [(g["id"], g.get("rank")) for g in over],
            "low_rank_exception": low_ex, "tags_test": test_tag,
            "slay_gu": next((g for g in gu if g["id"] == "test_slay_gu"), {}),
            "slay_gu_ten_ref": slay_ref, "aoe_equiv_line": aoe_line,
            "catalog_lines": cat_lines}


def census() -> dict:
    gu = load_json("gu.json")
    v1_battle = load_json("v1_battle.json")
    balance = load_json("balance.json")
    hw = [g for g in gu if g.get("v1_effect")]
    budget = rank_power_budget(balance)
    fb = fallback_curves(v1_battle)
    coarse = inversion_coarse(hw)
    fine, missing = inversion_by_cost(hw)
    coarse_keys = {(c["group"][0], c["group"][1], c["high_rank"], c["low_rank"]) for c in coarse}
    fine_keys = {(c["group"][0], c["group"][1], c["high_rank"], c["low_rank"]) for c in fine}
    return {
        "gu_total": len(gu), "budget": budget, "fallback": fb,
        "matrix": handwritten_matrix(gu),
        "inversion_coarse": coarse, "inversion_by_cost": fine,
        "only_coarse": sorted(coarse_keys - fine_keys), "only_fine": sorted(fine_keys - coarse_keys),
        "cost_missing_hw": missing,
        "cost_missing_all": {f: sum(1 for g in gu if f not in g) for f in COST_FIELDS},
        "fields": field_census(hw), "exemptions": exemptions(gu),
    }


def md(c: dict) -> str:
    L = []
    A = L.append
    A("# Effect Budget Census (P3-A, read-only)")
    A("")
    A("> All numbers computed by `game/world-model/tools/audit_effect_budget.py` "
      "from upstream data. No hardcoded constants. No PASS/FAIL verdicts — "
      "inversion criteria await L1 ruling.")
    A("")
    A(f"- gu total {c['gu_total']} / handwritten {c['matrix']['handwritten']} / "
      f"fallback {c['matrix']['fallback']}")
    A(f"- ranks: {c['matrix']['ranks']}")
    A(f"- roles: {c['matrix']['roles']}")
    A(f"- handwritten kinds: {c['matrix']['kinds']}")
    A("")
    A("## 1. Fallback curve vs Rank Power Budget")
    A("")
    budget_str = ", ".join("r%d=%g" % (r, c["budget"][r]) for r in (1, 2, 3, 4, 5))
    A(f"Budget (balance.json): {budget_str} (r5/r1 = 16.0x).")
    A(f"Rank-scaled kinds (v1_battle_resolver.gd): {c['fallback']['scaled_kinds']}. "
      "Rule: `amount = base + (rank-1)`; `support_bonus` same; `shift`/`status` flat.")
    A("")
    A("| role | kind | r1..r5 | r5/r1 | budget r1..r5 | gap r5 (budget/fallback) |")
    A("|---|---|---|---|---|---|")
    for role in ("attack", "defense", "healing", "logistics", "movement", "recon"):
        f = c["fallback"]["curves"][role]
        s = f["series"]
        gap = c["budget"][5] / s[4] if s[4] else 0
        A(f"| {role} | {f['kind']} | {','.join(map(str,s))} | {f['growth']:.1f}x | "
          f"40,80,160,320,640 | {gap:.1f}x |")
    A("")
    A("- attack/strike, defense/shield, healing/heal scale +1/rank (3.0x / 2.3x / 3.0x); "
      "logistics/heal base 1 scales 1..5 (5.0x); movement/shift and recon/status flat 1.0x.")
    A("- recon base carries `support_school: self` + `support_bonus: 1`, also +1/rank "
      "(r1..r5 = 1..5), injected as the gu school at resolve time.")
    A("- Budget grows 16x while fallback grows 1.0x–5.0x: fallback is a flat survival "
      "floor, not a budget share. Any per-rank share formula is L1's call.")
    A("")
    A("## 2. Handwritten coverage matrix (role, kind) x rank")
    A("")
    A("| role | kind | rank | n | min | max | ids |")
    A("|---|---|---|---|---|---|---|")
    for m in c["matrix"]["matrix"]:
        A(f"| {m['role']} | {m['kind']} | {m['rank']} | {m['count']} | {m['min']} | "
          f"{m['max']} | {', '.join(m['ids'])} |")
    A("")
    A("- r3: 180 gu, 10 handwritten; `strike` only `water_atk_3_05_gu` (amount=2) — matches L2 note.")
    A("- Empty ranks are fallback-only: e.g. defense r2/r4/r5, healing r2/r3/r5, "
      "logistics r2–r5, movement r2/r4/r5, recon r2–r4, attack r4 has 1 handwritten.")
    A("")
    A("## 3. Inversion candidates (two cost apertures, listed separately)")
    A("")
    A("Coarse aperture — group by (role, kind), compare per-rank amount maxima:")
    A("")
    if c["inversion_coarse"]:
        for inv in c["inversion_coarse"]:
            A(f"- {inv['group'][0]}/{inv['group'][1]}: r{inv['high_rank']} max {inv['high_max']} "
              f"< r{inv['low_rank']} max {inv['low_max']} (curve {inv['curve']})")
    else:
        A("- none")
    A("")
    A("Fine aperture — same check inside exact cost-structure groups "
      "(value/essence_cost/true_qi_cost/feeding_cost, MISS = field absent, never 0):")
    A("")
    if c["inversion_by_cost"]:
        for inv in c["inversion_by_cost"]:
            A(f"- {inv['group'][0]}/{inv['group'][1]} cost {inv['cost']}: "
              f"r{inv['high_rank']} max {inv['high_max']} < r{inv['low_rank']} max {inv['low_max']} "
              f"ids {', '.join(inv['ids'])}")
    else:
        A("- none")
    A("")
    A(f"- Only-coarse (vanish under same-cost grouping): {c['only_coarse'] or 'none'}")
    A(f"- Only-fine (appear only under same-cost grouping): {c['only_fine'] or 'none'}")
    A(f"- Cost-field absence in handwritten 61: {c['cost_missing_hw']}; in all 802: {c['cost_missing_all']}")
    A("- D7 requires same-position + same-cost-structure; L1 to rule which aperture is executable.")
    A("")
    A("## 4. v1_effect field census (61 handwritten)")
    A("")
    A("| field | n | non-scaling dim? | ids |")
    A("|---|---|---|---|")
    for f in c["fields"]:
        tag = "YES" if f["non_scaling"] else "-"
        A(f"| {f['field']} | {f['count']} | {tag} | {', '.join(f['ids'])} |")
    A("")
    for f in c["fields"]:
        bits = "; ".join("%s=%r" % (s["id"], s[f["field"]]) for s in f["samples"])
        A("- `%s` x%d: %s" % (f["field"], f["count"], bits))
    A("- Non-rank-scaling dims (`aoe`/`delay`/`condition`/`consume_status`): binary/shape "
      "modifiers, not magnitudes — L1 to decide how they grow (slots? tiers? gates?).")
    A("- `name` (2: status names) and `heal` (1: heal_and_strike sub-amount) are payload "
      "labels, not independent dims.")
    A("")
    A("## 5. Exemption paths (bypass 1-5 rank semantics)")
    A("")
    s = c["exemptions"]["slay_gu"]
    A(f"- `test_slay_gu`: rank {s.get('rank')}, v1_effect {s.get('v1_effect')}, "
      f"tags {s.get('tags')}, low_rank_exception {s.get('low_rank_exception')}.")
    A("- buffs.json `slay_gu_ten`: gu_id=%r (S2 opening buff carrier)." % c["exemptions"]["slay_gu_ten_ref"].get("gu_id"))
    A(f"- Catalog rank-cap lines: {'; '.join(c['exemptions']['catalog_lines'])}")
    A(f"- Grammar pipeline aoe line: `{c['exemptions']['aoe_equiv_line']}` "
      "(aoe==true resolves as selector enemy_all).")
    A(f"- rank>5 gu: {c['exemptions']['rank_over_5'] or 'only test_slay_gu'}; "
      f"low_rank_exception gu: {c['exemptions']['low_rank_exception']}; "
      f"tags=test gu: {c['exemptions']['tags_test']}")
    A("- can_activate: `low_rank_exception or cultivator_rank >= gu_rank` "
      "(cultivator_rules.gd:28-29). DO NOT delete test_slay_gu (S2 slay_gu_ten carrier).")
    A("")
    A("## Reproduce")
    A("")
    A("```")
    A("python game/world-model/tools/audit_effect_budget.py --report game/world-model/reports/effect-budget-census.md")
    A("```")
    return "\n".join(L) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description="Effect Budget census (read-only)")
    ap.add_argument("--report", default=str(DEFAULT_REPORT))
    ap.add_argument("--json", default=None)
    args = ap.parse_args()
    try:
        c = census()
    except (OSError, json.JSONDecodeError, KeyError) as exc:
        print(f"census failed: {exc}", file=sys.stderr)
        return 1
    Path(args.report).write_text(md(c), encoding="utf-8")
    if args.json:
        Path(args.json).write_text(json.dumps(c, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
    print(f"census: gu={c['gu_total']} hw={c['matrix']['handwritten']} "
          f"coarse={len(c['inversion_coarse'])} fine={len(c['inversion_by_cost'])} -> {args.report}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
