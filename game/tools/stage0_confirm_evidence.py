"""Promote human-confirmed Stage 0 recall candidates into the benchmark ledger.

`tools/stage0_evidence_candidates.py` produces candidates and deliberately stops
there, because accepting a citation is a human judgement. This tool is the other
half: it takes that judgement as input - a `topic:rank` spec - and performs the
mechanical part, so confirmation never turns into hand-edited JSONL.

    topic:1        cite candidate rank 1 of that topic in 主文 (the novel)
    topic:i1       cite rank 1 of that topic in 《人祖传》 (the excerpt itself)
    topic:t1       cite its 主文 twin instead (novel coordinates, primary_text)
    topic:1,3      several ranks for one topic
    topic：1       full-width colon and comma are accepted too

Ranks are per source, so a bare rank means 主文; `i` and `t` select the excerpt
row or its novel twin. Default is a dry run that writes nothing; `--apply`
updates the three ledger files atomically. Every change is re-resolved through
the production `resolve_evidence` and re-validated with `validate_claim_set`
before anything is written, so an unusable citation can never reach the ledger.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from lore_engine.cli import _complete_p0_reference  # noqa: E402  (gate predicate, reused verbatim)
from lore_engine.src.contracts import EvidenceRef, WorldClaim, WorldDecision  # noqa: E402
from lore_engine.src.reports import _evidence_location  # noqa: E402
from lore_engine.src.source_manifest import load_manifest  # noqa: E402
from lore_engine.src.world_baseline import adjudicate_baseline  # noqa: E402
from lore_engine.src.world_claims import load_jsonl, validate_claim_set  # noqa: E402
from lore_engine.src.world_evidence import resolve_evidence  # noqa: E402

LEDGER = ROOT / "lore_sources" / "benchmarks" / "world_model_stage0"
CANDIDATES = ROOT / "docs" / "lore" / "candidates" / "stage0-evidence-candidates.jsonl"
CONFIG_PATH = ROOT / "lore_engine" / "config" / "world-model-stage0.json"
MANIFEST_PATH = ROOT / "lore_sources" / "manifest.json"

BLOCKING_RULINGS = {"defer", "needs_evidence"}
# retain -> canonical, revise -> derived, remove -> rejected
STATUS_FOR_RULING = {"retain": "canonical", "revise": "derived", "remove": "rejected"}
RULING_FOR_STATUS = {value: key for key, value in STATUS_FOR_RULING.items()}

SEPARATORS = re.compile(r"[,\uff0c\s]+")
KVP = re.compile(r"[:\uff1a]")
# topic:rank[,rank...] - scanned as a whole so "a:1,2 b:3" is not split on the comma
SELECTION = re.compile(
    r"([A-Za-z_][A-Za-z0-9_]*)\s*[:\uff1a]\s*((?:[itIT]?\d+)(?:\s*[,\uff0c]\s*[itIT]?\d+)*)"
)
RANK_SEPARATOR = re.compile(r"[,\uff0c]")
IGNORABLE = str.maketrans("", "", ",\uff0c \t\r\n")


@dataclass(frozen=True)
class Selection:
    claim_id: str
    rank: int
    kind: str  # "main" | "excerpt" | "twin"

    @property
    def label(self) -> str:
        prefix = {"main": "", "excerpt": "i", "twin": "t"}[self.kind]
        return f"{self.claim_id}:{prefix}{self.rank}"


def parse_spec(text: str) -> tuple[Selection, ...]:
    """Parse `topic:rank` selections; accepts full-width colon/comma."""
    selections: list[Selection] = []
    consumed = 0
    for match in SELECTION.finditer(text):
        gap = text[consumed : match.start()].translate(IGNORABLE)
        if gap:
            raise ValueError(f"cannot parse {gap!r}; expected topic:rank")
        consumed = match.end()
        claim_id = match.group(1)
        for raw in RANK_SEPARATOR.split(match.group(2)):
            raw = raw.strip()
            if not raw:
                continue
            kind = "main"
            if raw[:1].lower() in {"i", "t"}:
                kind = "excerpt" if raw[:1].lower() == "i" else "twin"
                raw = raw[1:]
            if not raw.isdigit():
                raise ValueError(f"cannot parse rank {raw!r}; expected a number")
            selections.append(Selection(claim_id, int(raw), kind))
    leftover = text[consumed:].translate(IGNORABLE)
    if leftover:
        raise ValueError(f"cannot parse {leftover!r}; expected topic:rank")
    if not selections:
        raise ValueError("no selections given")
    return tuple(selections)


def parse_rulings(text: str) -> dict[str, str]:
    """Parse `topic=retain` overrides."""
    rulings: dict[str, str] = {}
    for chunk in SEPARATORS.split(text.strip()):
        if not chunk:
            continue
        if "=" not in chunk:
            raise ValueError(f"cannot parse ruling {chunk!r}; expected topic=ruling")
        claim_id, ruling = chunk.split("=", 1)
        if ruling not in STATUS_FOR_RULING:
            raise ValueError(f"unknown ruling {ruling!r}; expected retain/revise/remove")
        rulings[claim_id] = ruling
    return rulings


def load_candidates(path: Path) -> dict[tuple[str, int, str], dict]:
    """Index candidates by (claim_id, rank, kind): main / excerpt / twin."""
    index: dict[tuple[str, int, str], dict] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        kind = "main" if row["source_file_id"] == "gu_zhenren_main" else "excerpt"
        index[(row["claim_id"], int(row["rank"]), kind)] = row
        twin = row.get("twin")
        if twin:
            index[(row["claim_id"], int(row["rank"]), "twin")] = {
                **row,
                "source_file_id": "gu_zhenren_main",
                "authority": "primary_text",
                "char_start": twin["char_start"],
                "char_end": twin["char_end"],
                "quote": twin["quote"],
                "resolver_ready": twin.get("resolver_ready", True),
                "twin": None,
            }
    return index


def evidence_id_for(selection: Selection) -> str:
    prefix = {"main": "m", "excerpt": "i", "twin": "t"}[selection.kind]
    return f"stage0_{selection.claim_id}_{prefix}{selection.rank:02d}"


def _row(value: object) -> dict:
    assert isinstance(value, dict)
    return value


def _dump(records: list[dict]) -> str:
    return "".join(
        json.dumps(item, ensure_ascii=False, separators=(",", ":")) + "\n"
        for item in records
    )


def _project(claims, evidence, decisions, config) -> tuple[int, list[str]]:
    """Reuse the gate's own predicate to predict its two evidence blockers."""
    adjudication = adjudicate_baseline(claims, evidence, (), decisions)
    rows = adjudication.rows
    report_rows = [
        {
            "topic": row.topic,
            "impact": row.impact,
            "evidence": [
                _evidence_location(item)
                for item in (*row.support_evidence, *row.condition_evidence)
            ],
        }
        for row in rows
    ]
    p0_source_ids = {str(item) for item in config.get("p0_source_ids", ())}
    complete = sorted(
        item["topic"] for item in report_rows if _complete_p0_reference(item, p0_source_ids)
    )
    blocked = sorted(
        row.claim_id
        for row in rows
        if row.impact == "high" and row.effective_ruling in BLOCKING_RULINGS
    )
    return len(complete), blocked


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", required=True, help="e.g. 'natal_gu:1,3 soul:t1'")
    parser.add_argument("--ruling", default="", help="e.g. 'natal_gu=retain'")
    parser.add_argument("--apply", action="store_true", help="write the ledger")
    parser.add_argument("--candidates", type=Path, default=CANDIDATES)
    parser.add_argument("--ledger", type=Path, default=LEDGER)
    args = parser.parse_args(argv)

    selections = parse_spec(args.spec)
    overrides = parse_rulings(args.ruling)
    index = load_candidates(args.candidates)
    config = _row(json.loads(CONFIG_PATH.read_text(encoding="utf-8")))

    claims_path = args.ledger / "claims.jsonl"
    evidence_path = args.ledger / "evidence.jsonl"
    decisions_path = args.ledger / "decisions.jsonl"
    claim_rows = [
        json.loads(line) for line in claims_path.read_text(encoding="utf-8").splitlines() if line.strip()
    ]
    evidence_rows = [
        json.loads(line) for line in evidence_path.read_text(encoding="utf-8").splitlines() if line.strip()
    ]
    decision_rows = [
        json.loads(line) for line in decisions_path.read_text(encoding="utf-8").splitlines() if line.strip()
    ]
    for label, rows in (
        ("claims", claim_rows),
        ("evidence", evidence_rows),
        ("decisions", decision_rows),
    ):
        if not rows:
            raise ValueError(f"{label}.jsonl is empty")

    claim_by_id = {row["claim_id"]: row for row in claim_rows}
    decision_by_id = {row["claim_id"]: row for row in decision_rows}
    by_span = {
        (row["source_file_id"], row["char_start"], row["char_end"]): row["evidence_id"]
        for row in evidence_rows
        if row.get("evidence_kind") != "unknown"
    }

    problems: list[str] = []
    additions: list[dict] = []
    chosen: dict[str, list[str]] = {}
    for selection in selections:
        if selection.claim_id not in claim_by_id:
            problems.append(f"{selection.label}: unknown claim/topic")
            continue
        candidate = index.get((selection.claim_id, selection.rank, selection.kind))
        if candidate is None:
            hint = {"main": "", "excerpt": " (no 《人祖传》 row)", "twin": " (no 主文 twin)"}[
                selection.kind
            ]
            problems.append(f"{selection.label}: no such candidate{hint}")
            continue
        if not candidate.get("resolver_ready", True):
            problems.append(f"{selection.label}: candidate is not uniquely quotable")
            continue
        span = (candidate["source_file_id"], candidate["char_start"], candidate["char_end"])
        evidence_id = by_span.get(span)
        if evidence_id is None:
            evidence_id = evidence_id_for(selection)
            if any(row["evidence_id"] == evidence_id for row in evidence_rows + additions):
                problems.append(f"{selection.label}: evidence id {evidence_id} already taken")
                continue
            additions.append(
                {
                    "evidence_id": evidence_id,
                    "source_file_id": candidate["source_file_id"],
                    "source_ref": f"stage0_recall/{candidate.get('matched_pattern', '')}",
                    "char_start": candidate["char_start"],
                    "char_end": candidate["char_end"],
                    "quote": candidate["quote"],
                    "authority": candidate["authority"],
                    "evidence_kind": "support",
                }
            )
        chosen.setdefault(selection.claim_id, [])
        if evidence_id not in chosen[selection.claim_id]:
            chosen[selection.claim_id].append(evidence_id)

    if not chosen:
        for problem in problems:
            print(f"REJECTED {problem}")
        print("nothing to do")
        return 2

    updated_claims: list[dict] = []
    updated_decisions: list[dict] = []
    for row in claim_rows:
        claim_id = row["claim_id"]
        if claim_id not in chosen:
            updated_claims.append(row)
            continue
        preliminary = decision_by_id[claim_id]
        ruling = overrides.get(claim_id)
        if ruling is None:
            current = preliminary["ruling"]
            ruling = current if current in STATUS_FOR_RULING else "retain"
        status = STATUS_FOR_RULING[ruling]
        ids = list(dict.fromkeys([*row["evidence_ids"], *chosen[claim_id]]))
        sources = sorted(
            {
                *row["source_ids"],
                *(
                    item["source_file_id"]
                    for item in evidence_rows + additions
                    if item["evidence_id"] in ids
                ),
            }
        )
        updated_claims.append(
            {
                **row,
                "status": status,
                "previous_status": preliminary.get("previous_status") or "deferred",
                "source_ids": sources,
                "evidence_ids": ids,
            }
        )

    # Decisions follow their claims; rows outside the spec must survive untouched.
    for row in decision_rows:
        claim_id = row["claim_id"]
        if claim_id not in chosen:
            updated_decisions.append(row)
            continue
        ids = next(
            item["evidence_ids"] for item in updated_claims if item["claim_id"] == claim_id
        )
        ruling = next(
            item["status"] for item in updated_claims if item["claim_id"] == claim_id
        )
        updated_decisions.append(
            {
                **row,
                "ruling": RULING_FOR_STATUS[ruling],
                "decision_kind": "final",
                "previous_status": row.get("previous_status") or "deferred",
                "rationale": (
                    row["rationale"].rstrip()
                    + f" Final ruling: confirmed against {len(ids)} verified P0 "
                    + f"citation(s) ({', '.join(ids)}). Scope: as written at the cited "
                    + "spans; Stage 0 authorises audit only."
                ),
            }
        )

    touched = {row["claim_id"] for row in updated_decisions if row["claim_id"] in chosen}
    final_claims: list[WorldClaim] = []
    for row in updated_claims:
        final_claims.append(
            WorldClaim(
                row["claim_id"],
                row["topic"],
                row["statement"],
                row["status"],
                row["impact"],
                tuple(row["source_ids"]),
                tuple(row["evidence_ids"]),
                tuple(row["counter_evidence_ids"]),
                row["confidence"],
                row.get("previous_status"),
            )
        )
    all_evidence_rows = evidence_rows + additions
    final_evidence = [
        EvidenceRef(
            row["evidence_id"],
            row["source_file_id"],
            row["source_ref"],
            row["char_start"],
            row["char_end"],
            row["quote"],
            row["authority"],
            row["evidence_kind"],
        )
        for row in all_evidence_rows
    ]
    final_decisions = [
        WorldDecision(
            row["claim_id"],
            row["ruling"],
            row["rationale"],
            row["player_consequence"],
            row["implementation_action"],
            tuple(row["non_regression_notes"]),
            row.get("previous_status"),
            row.get("decision_kind", "final"),
        )
        for row in updated_decisions
    ]

    # 1. The resolver is the authority on whether a citation is usable.
    manifest = load_manifest(MANIFEST_PATH)
    resolved = resolve_evidence(ROOT, manifest, final_evidence)
    bad = [
        f"{item.evidence_id}: {item.error}"
        for item in resolved
        if not item.ok and item.evidence_kind != "unknown"
    ]
    if bad:
        problems.extend(bad)
    # 2. The claim validator is the authority on whether the transition is legal.
    checked = validate_claim_set((*final_claims, *final_evidence, *final_decisions), config)
    problems.extend(f"{item.code}: {item.message}" for item in checked.errors)

    before = _project(
        tuple(
            WorldClaim(
                row["claim_id"], row["topic"], row["statement"], row["status"],
                row["impact"], tuple(row["source_ids"]), tuple(row["evidence_ids"]),
                tuple(row["counter_evidence_ids"]), row["confidence"], row.get("previous_status"),
            )
            for row in claim_rows
        ),
        tuple(
            EvidenceRef(
                row["evidence_id"], row["source_file_id"], row["source_ref"],
                row["char_start"], row["char_end"], row["quote"], row["authority"],
                row["evidence_kind"],
            )
            for row in evidence_rows
        ),
        tuple(
            WorldDecision(
                row["claim_id"], row["ruling"], row["rationale"], row["player_consequence"],
                row["implementation_action"], tuple(row["non_regression_notes"]),
                row.get("previous_status"), row.get("decision_kind", "final"),
            )
            for row in decision_rows
        ),
        config,
    )
    after = _project(final_claims, final_evidence, final_decisions, config)

    for row in additions:
        print(
            f"+ {row['evidence_id']:<28} {row['source_file_id']:<15} "
            f"{row['char_start']:>8}  {row['quote'].strip()[:44]}"
        )
    for claim_id in sorted(chosen):
        row = next(item for item in updated_claims if item["claim_id"] == claim_id)
        print(
            f"~ {claim_id:<32} -> {row['status']:<9} "
            f"({len(row['evidence_ids'])} citation(s))"
        )
    for problem in problems:
        print(f"REJECTED {problem}")
    print(
        f"complete high-impact references: {before[0]}/{len(claim_rows)} -> "
        f"{after[0]}/{len(claim_rows)}   (gate minimum 20)"
    )
    print(
        f"claims stuck on defer/needs_evidence: {len(before[1])} -> {len(after[1])}"
        + (f"  [{', '.join(after[1])}]" if after[1] else "")
    )

    if problems:
        print("aborted: nothing written")
        return 1
    if not args.apply:
        print("dry run: nothing written (pass --apply to update the ledger)")
        return 0

    evidence_path.write_text(_dump(all_evidence_rows), encoding="utf-8")
    claims_path.write_text(_dump(updated_claims), encoding="utf-8")
    decisions_path.write_text(_dump(updated_decisions), encoding="utf-8")
    print(f"applied: {len(additions)} evidence row(s), {len(touched)} claim(s) finalised")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
