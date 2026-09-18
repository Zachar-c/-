"""Append-only V0 seed record import."""

from __future__ import annotations

import json
from collections.abc import Iterable
from pathlib import Path

from .contracts import SeedImportSummary, SeedRecord
from .database import LoreDatabase

SEED_KINDS = {"seed_canon", "seed_inferred", "seed_note", "seed_game_design"}


def load_seed_records(seed_dir: Path) -> list[SeedRecord]:
    records: list[SeedRecord] = []
    for path in sorted(seed_dir.glob("seed_*.jsonl")):
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            if not line.strip():
                continue
            try:
                payload = json.loads(line)
                record = SeedRecord(**payload)
            except (TypeError, json.JSONDecodeError) as exc:
                raise ValueError(f"invalid seed record {path}:{line_number}") from exc
            if record.seed_kind not in SEED_KINDS:
                raise ValueError(f"unknown seed kind: {record.seed_kind}")
            records.append(record)
    return records


def import_seeds(db: LoreDatabase, records: Iterable[SeedRecord]) -> SeedImportSummary:
    inserted = 0
    skipped = 0
    with db.connection:
        for record in records:
            existing = db.connection.execute("SELECT 1 FROM facts WHERE fact_key = ?", (f"seed:{record.seed_id}",)).fetchone()
            if existing:
                skipped += 1
                continue
            db.connection.execute(
                "INSERT INTO facts(fact_key, source_id, chunk_id, payload_json) VALUES (?, ?, ?, ?)",
                (f"seed:{record.seed_id}", record.source_doc, record.source_ref, json.dumps(record.__dict__, ensure_ascii=False, sort_keys=True)),
            )
            inserted += 1
    return SeedImportSummary(inserted, skipped)
