#!/usr/bin/env python3
"""Re-resolve every Stage 0 recall candidate through the real evidence resolver.

The recall tool self-checks its output, but a self-check is not evidence: this script
builds the actual `EvidenceRef` objects the ledger would carry and hands them to
``world_evidence.resolve_evidence`` - the same function the Stage 0 gate uses to police
``evidence.jsonl``.  It exits non-zero when the recall tool's own verdict disagrees with
the resolver, so a candidate can never be promoted on a stale promise.

Two things are checked, not one:

* every candidate resolves in its own source, and
* every ``twin`` resolves in ``gu_zhenren_main``, which is what validates the
  excerpt -> novel offset mapping.

A candidate the recall tool already flagged ``resolver_ready: false`` is an *expected*
rejection and is reported as such; it does not fail the run.  Any other rejection does.

Usage
-----
    python tools/verify_stage0_candidates.py
"""

from __future__ import annotations

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lore_engine.src import world_evidence  # noqa: E402  (path bootstrap above)
from lore_engine.src.contracts import EvidenceRef  # noqa: E402

CANDIDATES = ROOT / "docs" / "lore" / "candidates" / "stage0-evidence-candidates.jsonl"
MANIFEST = ROOT / "lore_sources" / "manifest.json"
MAIN_SOURCE_ID = "gu_zhenren_main"


def build_refs(records: list[dict]) -> tuple[list[EvidenceRef], list[tuple[str, int, bool]]]:
    """Return the refs to resolve plus (kind, record index, expected_ok) for each."""
    refs: list[EvidenceRef] = []
    expectations: list[tuple[str, int, bool]] = []
    for index, record in enumerate(records):
        expectations.append(("self", index, bool(record["resolver_ready"])))
        refs.append(
            EvidenceRef(
                f"c{index}",
                record["source_file_id"],
                record["source_ref"],
                record["char_start"],
                record["char_end"],
                record["quote"],
                record["authority"],
                "support",
            )
        )
        twin = record.get("twin")
        if twin:
            expectations.append(("twin", index, bool(twin["resolver_ready"])))
            refs.append(
                EvidenceRef(
                    f"t{index}",
                    MAIN_SOURCE_ID,
                    record["source_ref"],
                    twin["char_start"],
                    twin["char_end"],
                    twin["quote"],
                    "primary_text",
                    "support",
                )
            )
    return refs, expectations


def describe(
    records: list[dict], kind: str, index: int, expected_ok: bool, resolved: object
) -> str:
    row = records[index]
    return (
        f"{kind} {row['claim_id']}#{row['rank']} "
        f"({row['source_file_id']}@{row.get('char_start')}): "
        f"expected_ok={expected_ok} actual={resolved.ok} error={resolved.error}"
    )


def main() -> int:
    records = [
        json.loads(line)
        for line in CANDIDATES.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    refs, expectations = build_refs(records)
    resolved = world_evidence.resolve_evidence(ROOT, MANIFEST, refs)

    unexpected: list[str] = []
    expected_rejections: list[str] = []
    for position, (kind, index, expected_ok) in enumerate(expectations):
        actual_ok = resolved[position].ok
        if actual_ok == expected_ok:
            if not expected_ok:
                # Both sides agree this candidate is unusable - report it, do not fail on it.
                expected_rejections.append(describe(records, kind, index, expected_ok, resolved[position]))
            continue
        unexpected.append(describe(records, kind, index, expected_ok, resolved[position]))

    self_count = sum(1 for kind, _, _ in expectations if kind == "self")
    twin_count = sum(1 for kind, _, _ in expectations if kind == "twin")
    ready = sum(1 for _, _, expected in expectations if expected)
    print(
        f"candidates={len(records)} refs={len(refs)} "
        f"(self={self_count}, twin={twin_count}) resolver_confirmed={ready}"
    )
    print(f"known_rejections={len(expected_rejections)} disagreements={len(unexpected)}")
    for detail in expected_rejections:
        print(f"  KNOWN  {detail}")
    for detail in unexpected:
        print(f"  BROKEN {detail}")

    excerpt_only = [
        record
        for record in records
        if record["source_file_id"] != MAIN_SOURCE_ID and not record.get("twin")
    ]
    print(f"excerpt-only rows={len(excerpt_only)}")
    for record in excerpt_only:
        print(f"  {record['claim_id']} #{record['rank']} {record['quote'][:56]!r}")

    if unexpected:
        print("FAIL: the recall tool's verdict disagrees with the resolver")
        return 1
    print("PASS: every candidate's readiness matches the resolver")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
