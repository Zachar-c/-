"""Resumable, transactional extraction pipeline."""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from datetime import UTC, datetime

from .contracts import ChunkRecord
from .database import LoreDatabase
from .model_router import ModelRouter, build_model_task
from .validator import validate_extraction


@dataclass(frozen=True)
class PipelineSummary:
    processed: int = 0
    succeeded: int = 0
    failed: int = 0
    skipped: int = 0
    retried: int = 0


class Pipeline:
    def __init__(self, db: LoreDatabase, router: ModelRouter) -> None:
        self.db = db
        self.router = router

    def run(
        self,
        chunks: list[ChunkRecord],
        *,
        dry_run: bool = False,
        stop_after: int | None = None,
        resume: bool = False,
    ) -> PipelineSummary:
        processed = succeeded = failed = skipped = 0
        for chunk in chunks:
            if stop_after is not None and processed >= stop_after:
                break
            status = self.db.connection.execute(
                "SELECT status FROM chunks WHERE chunk_id = ?", (chunk.chunk_id,)
            ).fetchone()
            if status is None:
                skipped += 1
                continue
            if resume and status[0] == "SUCCESS":
                skipped += 1
                continue
            processed += 1
            run_id = hashlib.sha256(f"run:{chunk.chunk_id}:{chunk.chunk_hash}".encode()).hexdigest()[:24]
            self.db.connection.execute(
                "INSERT OR REPLACE INTO extraction_runs(run_id, chunk_id, input_hash, backend, model, status, error_code, payload_json) VALUES (?, ?, ?, ?, ?, 'RUNNING', NULL, '{}')",
                (run_id, chunk.chunk_id, chunk.chunk_hash, self.router.backend.backend_id, self.router.model),
            )
            self.db.connection.execute("UPDATE chunks SET status='RUNNING' WHERE chunk_id = ?", (chunk.chunk_id,))
            self.db.connection.commit()

            result = self.router.run(build_model_task(chunk, {}))
            if result.status != "SUCCESS" or result.output is None:
                self.db.record_failed_run(run_id, chunk.chunk_id, result.backend, result.model, result.error_code or "model_failed")
                self.db.connection.execute("UPDATE chunks SET status='FAILED' WHERE chunk_id = ?", (chunk.chunk_id,))
                self.db.connection.commit()
                failed += 1
                continue
            validated = validate_extraction(result.output, chunk, chunk.text)
            if not validated.ok:
                self.db.record_failed_run(run_id, chunk.chunk_id, result.backend, result.model, "schema_invalid")
                self.db.connection.execute("UPDATE chunks SET status='NEEDS_REVIEW' WHERE chunk_id = ?", (chunk.chunk_id,))
                self.db.connection.commit()
                failed += 1
                continue
            if dry_run:
                self.db.connection.execute("UPDATE chunks SET status='PENDING' WHERE chunk_id = ?", (chunk.chunk_id,))
                self.db.connection.execute("DELETE FROM extraction_runs WHERE run_id = ?", (run_id,))
                self.db.connection.commit()
            else:
                self.db.commit_extraction(chunk.chunk_id, run_id, validated)
            succeeded += 1
        return PipelineSummary(processed, succeeded, failed, skipped)

    def retry(self, chunks: list[ChunkRecord]) -> PipelineSummary:
        eligible = []
        for chunk in chunks:
            status = self.db.connection.execute("SELECT status FROM chunks WHERE chunk_id = ?", (chunk.chunk_id,)).fetchone()
            if status and status[0] in ("FAILED", "NEEDS_REVIEW"):
                eligible.append(chunk)
        return self.run(eligible, resume=False)
