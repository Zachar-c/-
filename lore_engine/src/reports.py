"""Deterministic database reports."""

from __future__ import annotations

import json
from pathlib import Path

from .database import LoreDatabase


def build_report(db: LoreDatabase) -> dict[str, object]:
    counts = {table: db.count(table) for table in ("sources", "chapters", "chunks", "entities", "facts", "events", "relations", "rule_candidates", "conflicts")}
    statuses = {
        str(status): int(amount)
        for status, amount in db.connection.execute("SELECT status, COUNT(*) FROM chunks GROUP BY status ORDER BY status")
    }
    runs = {
        str(status): int(amount)
        for status, amount in db.connection.execute("SELECT status, COUNT(*) FROM extraction_runs GROUP BY status ORDER BY status")
    }
    return {"version": "lore-v1", "counts": counts, "chunk_statuses": statuses, "extraction_runs": runs}


def write_report(report: dict[str, object], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")
