#!/usr/bin/env python3
"""Stage 0 evidence candidate retrieval (offline, deterministic, stdlib only).

Purpose: recall *candidate* passages for the 24 high-impact world-model claims so a
human can inspect and confirm them.  It does not decide anything and it never writes
into the benchmark ledger - confirmed candidates are promoted into
``lore_sources/benchmarks/world_model_stage0/{claims,evidence}.jsonl`` by hand.

Why it is built this way
------------------------
``world_evidence.resolve_evidence`` accepts a citation only when

  * the source is read through ``source_manifest.read_source`` (strict decode), so the
    offsets are **decoded character** indices, not bytes;
  * ``text[char_start:char_end] == quote``; and
  * the quote occurs **exactly once** in the whole source, at exactly ``char_start``.

So a candidate is only usable when its quote is globally unique.  This tool grows each
candidate window until the slice is unique and reports candidates where uniqueness
cannot be reached, instead of emitting quotes that would be rejected later.

Usage
-----
    python tools/stage0_evidence_candidates.py [--top N] [--per-topic N]

Outputs (review artefacts, never pipeline input)
    docs/lore/candidates/stage0-evidence-candidates.jsonl
    docs/lore/candidates/stage0-evidence-candidates.md
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from lore_engine.src import source_manifest  # noqa: E402  (path bootstrap above)

MANIFEST = ROOT / "lore_sources" / "manifest.json"
OUT_DIR = ROOT / "docs" / "lore" / "candidates"
CLAIMS = ROOT / "lore_sources" / "benchmarks" / "world_model_stage0" / "claims.jsonl"

MAX_QUOTE = 120         # characters; keeps quotes short, as the plan requires
MIN_QUOTE = 30          # a 2-character hit is unique but useless as a citation
STRIDE = 4              # characters added per growth step when hunting a unique window
CONTEXT = 70            # characters of padding used when scoring a hit's neighbourhood
UNIQUE_TRIES = 40       # growth steps when hunting for a globally unique window

# ---------------------------------------------------------------------------
# Query table: topic -> list of (regex, weight).
# Weight 3 = the topic's canonical term, 2 = a close synonym, 1 = weakly related.
# The tool prints per-pattern hit counts so an over-broad term is visible and can
# be tightened without touching any other topic.
# ---------------------------------------------------------------------------
QUERIES: dict[str, list[tuple[str, int]]] = {
    "gu_is_life": [
        ("活蛊", 3), ("死蛊", 3), ("蛊虫[^。！？]{0,6}死", 3), ("蛊[^。！？]{0,4}活", 2),
        ("养蛊如", 2), ("蛊的命", 2), ("有灵性", 1),
    ],
    "gu_is_independent_entity": [
        ("独立[^。！？]{0,6}蛊", 3), ("蛊[^。！？]{0,4}认主", 3), ("认主", 2),
        ("无主之蛊", 2), ("有自己的意志", 2), ("蛊的意志", 2), ("听命于", 1),
    ],
    "cultivator_aperture": [
        ("空窍", 3), ("窍壁", 3), ("开窍", 3), ("气海", 2), ("窍穴", 2),
        ("蛊师[^。！？]{0,4}窍", 2), ("窍[^。！？]{0,3}破碎", 2),
    ],
    "aptitude_capacity": [
        ("资质", 3), ("甲等", 3), ("乙等", 2), ("丙等", 2), ("丁等", 2),
        ("天资", 2), ("容量", 2), ("容纳", 1),
    ],
    "primeval_essence": [
        ("真元", 3), ("元力", 3), ("真元[^。！？]{0,4}(不足|耗尽|消耗)", 3),
        ("元气", 2), ("催动真元", 2),
    ],
    "rank_and_subrank": [
        ("一转", 3), ("二转", 3), ("三转", 3), ("四转", 3), ("五转", 3),
        ("初阶", 2), ("中阶", 2), ("高阶", 2), ("巅峰", 2), ("转阶", 2),
    ],
    "gu_refinement": [
        ("炼蛊", 3), ("炼化", 3), ("炼制", 3), ("蛊材", 3), ("蛊方", 2), ("秘方", 2),
    ],
    "gu_ownership": [
        ("蛊[^。！？]{0,4}(归属|属于)", 3), ("夺蛊", 3), ("抢蛊", 3), ("占有", 2),
        ("转赠", 2), ("认主", 2), ("归属", 2),
    ],
    "gu_feeding": [
        ("喂养", 3), ("喂食", 3), ("养蛊", 3), ("蛊食", 3), ("饲料", 2),
        ("饥饿", 2), ("进食", 2),
    ],
    "gu_activation": [
        ("催动", 3), ("激发", 3), ("激活", 3), ("施展蛊", 3), ("催动蛊虫", 3),
        ("耗尽", 2),
    ],
    "natal_gu": [
        ("本命蛊", 3), ("本命", 3), ("命蛊", 2),
    ],
    "gu_recipe": [
        ("蛊方", 3), ("配方", 3), ("秘方", 3), ("炼制之法", 3), ("丹方", 1),
    ],
    "kill_move": [
        ("杀招", 3), ("绝招", 3), ("合击", 3), ("连招", 2), ("招式", 2),
    ],
    "information_leak": [
        ("情报", 3), ("泄露", 3), ("走漏", 3), ("打探", 2), ("探听", 2),
        ("耳目", 2), ("消息灵通", 2),
    ],
    "dao_marks": [
        ("道痕", 3), ("道纹", 3), ("道韵", 3), ("烙印", 2), ("痕迹", 1),
    ],
    "mortal_immortal_boundary": [
        ("凡人", 3), ("蛊仙", 3), ("仙凡", 3), ("成仙", 2), ("飞升", 2), ("长生", 2),
    ],
    "lifespan": [
        ("寿元", 3), ("寿数", 3), ("阳寿", 3), ("寿命", 3), ("延寿", 3),
        ("寿尽", 2), ("短寿", 2),
    ],
    "soul": [
        ("魂魄", 3), ("神魂", 3), ("魂力", 3), ("夺魂", 2), ("伤魂", 2),
        ("灵魂", 2), ("魂飞魄散", 2),
    ],
    "body_and_blood": [
        ("肉身", 3), ("血脉", 3), ("气血", 3), ("精血", 3), ("躯体", 2),
        ("血统", 2),
    ],
    "force_and_social_order": [
        ("势力", 3), ("家族", 3), ("辈分", 3), ("规矩", 2), ("地位", 2),
        ("身份", 2), ("秩序", 2),
    ],
    "inheritance": [
        ("传承", 3), ("遗藏", 3), ("家传", 3), ("秘传", 3), ("继承", 2),
    ],
    "economy_and_primeval_stones": [
        ("元石", 3), ("灵石", 3), ("价格", 2), ("交易", 2), ("财富", 2),
        ("货币", 2),
    ],
    "tribulation_or_ascension": [
        ("天劫", 3), ("渡劫", 3), ("劫数", 3), ("升仙", 3), ("劫难", 2),
    ],
    "world_scope_and_compression": [
        ("天地", 2), ("疆域", 3), ("五域", 3), ("镇压", 2), ("广袤", 2),
        ("格局", 2),
    ],
}


def load_claim_topics() -> list[str]:
    topics: list[str] = []
    for line in CLAIMS.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        record = json.loads(line)
        topics.append(str(record["claim_id"]))
    return topics


def unique_quote(text: str, match_start: int, match_end: int) -> tuple[int, int, str, bool]:
    """Grow the window around a hit until the slice occurs exactly once.

    Returns (char_start, char_end, quote, unique).  ``quote`` is always an exact slice
    of ``text``, so it satisfies the resolver's slice-equality rule; the flag says
    whether it also satisfies the global-uniqueness rule.

    A bare hit is grown to at least ``MIN_QUOTE`` characters first - a two-character
    phrase can be globally unique and still be worthless as a citation - and only then
    extended until it is unique.  Sides alternate so the window stays centred on the
    hit, which makes the first unique window the tightest one the stride can reach.
    """
    left, right = match_start, match_end
    while right - left < MIN_QUOTE and (left > 0 or right < len(text)):
        if (right - left) % (STRIDE * 2) < STRIDE and left > 0:
            left = max(0, left - STRIDE)
        else:
            right = min(len(text), right + STRIDE)
    if text.count(text[left:right]) == 1:
        return left, right, text[left:right], True
    for step in range(1, UNIQUE_TRIES + 1):
        if step % 2 == 1:
            left = max(0, left - STRIDE)
        else:
            right = min(len(text), right + STRIDE)
        if right - left > MAX_QUOTE:
            break
        quote = text[left:right]
        if text.count(quote) == 1:
            return left, right, quote, True
    fallback = text[match_start:match_end]
    return match_start, match_end, fallback, text.count(fallback) == 1


def recall_for_topic(text: str, topic: str, per_topic: int) -> tuple[list[dict], dict[str, int]]:
    patterns = QUERIES.get(topic, [])
    compiled = [(re.compile(pattern), weight, pattern) for pattern, weight in patterns]
    counts: dict[str, int] = {}
    hits: list[tuple[int, int, str, int]] = []
    for regex, weight, pattern in compiled:
        found = list(regex.finditer(text))
        counts[pattern] = len(found)
        for match in found:
            hits.append((match.start(), match.end(), pattern, weight))

    # Score every hit by how many *distinct* topic patterns sit in its neighbourhood,
    # tie-broken by pattern weight and then by rarity (fewer source occurrences first).
    scored: list[tuple[float, int, tuple[int, int, str, int]]] = []
    for hit_start, hit_end, _pattern, _weight in hits:
        window_start = max(0, hit_start - CONTEXT)
        window_end = min(len(text), hit_end + CONTEXT)
        window = text[window_start:window_end]
        matched = set()
        total_weight = 0
        for regex, weight, pattern in compiled:
            if regex.search(window):
                matched.add(pattern)
                total_weight += weight
        rarity = sum(1.0 / max(1, counts[pattern]) for pattern in matched)
        scored.append((len(matched) + total_weight / 100.0 + rarity, hit_start,
                       (hit_start, hit_end, pattern, weight)))
    scored.sort(key=lambda item: (-item[0], item[1]))

    candidates: list[dict] = []
    used_regions: list[tuple[int, int]] = []
    for score, _start, (hit_start, hit_end, pattern, weight) in scored:
        if len(candidates) >= per_topic:
            break
        if any(abs(hit_start - taken) < 120 for taken in used_regions):
            continue
        char_start, char_end, quote, is_unique = unique_quote(text, hit_start, hit_end)
        if len(quote) > MAX_QUOTE:
            continue
        used_regions.append(hit_start)
        candidates.append({
            "rank": len(candidates) + 1,
            "score": round(score, 4),
            "matched_pattern": pattern,
            "matched_weight": weight,
            "char_start": char_start,
            "char_end": char_end,
            "quote": quote,
            "quote_chars": len(quote),
            "unique": is_unique,
            "occurrences": text.count(quote),
        })
    return candidates, counts


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--per-topic", type=int, default=6)
    args = parser.parse_args()

    specs = source_manifest.load_manifest(MANIFEST)
    topics = load_claim_topics()
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    payloads: dict[str, tuple[str, str, str]] = {}
    for spec in specs:
        text = source_manifest.read_source(ROOT, spec)
        raw = (ROOT / spec.path).read_bytes()
        payloads[spec.source_file_id] = (text, spec.authority, hashlib.sha256(raw).hexdigest())
        print(f"source {spec.source_file_id}: {len(text)} decoded characters, sha256={hashlib.sha256(raw).hexdigest()[:12]}")

    records: list[dict] = []
    verified = 0
    not_unique = 0
    coverage: dict[str, int] = {}
    for topic in topics:
        coverage[topic] = 0
        for source_file_id, (text, authority, source_hash) in payloads.items():
            candidates, counts = recall_for_topic(text, topic, args.per_topic)
            for candidate in candidates:
                record = {
                    "claim_id": topic,
                    "source_file_id": source_file_id,
                    "authority": authority,
                    "source_sha256": source_hash,
                    "source_ref": candidate["matched_pattern"],
                    "char_start": candidate["char_start"],
                    "char_end": candidate["char_end"],
                    "quote": candidate["quote"],
                    "rank": candidate["rank"],
                    "score": candidate["score"],
                    "unique": candidate["unique"],
                    "occurrences": candidate["occurrences"],
                    "matched_pattern": candidate["matched_pattern"],
                    "confirmed": False,
                }
                # Self-check against the resolver's own acceptance rule.
                slice_ok = text[record["char_start"]:record["char_end"]] == record["quote"]
                record["resolver_ready"] = bool(slice_ok and record["occurrences"] == 1)
                if record["resolver_ready"]:
                    verified += 1
                if not record["unique"]:
                    not_unique += 1
                records.append(record)
                coverage[topic] += 1

    jsonl = OUT_DIR / "stage0-evidence-candidates.jsonl"
    jsonl.write_text(
        "".join(json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n" for record in records),
        encoding="utf-8",
    )

    lines: list[str] = [
        "# Stage 0 evidence candidates (for human review)",
        "",
        "Generated by `tools/stage0_evidence_candidates.py` - offline, deterministic, and "
        "read-only with respect to the benchmark ledger. Nothing here is confirmed: every "
        "row has `confirmed: false` and must be inspected before it is promoted into "
        "`lore_sources/benchmarks/world_model_stage0/{claims,evidence}.jsonl`.",
        "",
        "A candidate is only usable if its `quote` occurs exactly once in the source at "
        "exactly `char_start` - that is what `world_evidence.resolve_evidence` enforces. "
        "The `ready` column shows the tool's own self-check of that rule.",
        "",
        "The table below collapses whitespace runs for readability; the JSONL keeps the "
        "exact source slice, which is what must be copied into the ledger.",
        "",
        f"- topics: {len(topics)}   candidates: {len(records)}   "
        f"resolver-ready: {verified}   needing disambiguation: {not_unique}",
        "",
        "| topic | source | rank | ready | start | quote |",
        "|---|---|---|---|---|---|",
    ]
    for topic in topics:
        for record in [item for item in records if item["claim_id"] == topic]:
            quote = re.sub(r"\s+", " ", record["quote"]).strip().replace("|", "\\|")
            mark = "yes" if record["resolver_ready"] else "NO"
            source = "主文" if record["source_file_id"] == "gu_zhenren_main" else "人祖传"
            lines.append(
                f"| {topic} | {source} | {record['rank']} | {mark} | {record['char_start']} | {quote} |"
            )
    lines.append("")
    (OUT_DIR / "stage0-evidence-candidates.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"topics={len(topics)} candidates={len(records)} resolver_ready={verified} not_unique={not_unique}")
    print(f"wrote {jsonl.relative_to(ROOT)}")
    print(f"wrote {(OUT_DIR / 'stage0-evidence-candidates.md').relative_to(ROOT)}")
    empty = [topic for topic, count in coverage.items() if count == 0]
    if empty:
        print("topics with no candidate: " + ", ".join(empty))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
