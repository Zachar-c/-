"""SQLite repository for Lore Compiler V1."""

from __future__ import annotations

import json
import sqlite3
from datetime import UTC, datetime
from pathlib import Path
from typing import Iterable

from .contracts import ChunkRecord, SectionRecord, SourceFingerprint, ValidatedExtraction


class LoreDatabase:
    def __init__(self, connection: sqlite3.Connection) -> None:
        self.connection = connection

    @classmethod
    def open(cls, path: Path) -> "LoreDatabase":
        path.parent.mkdir(parents=True, exist_ok=True)
        connection = sqlite3.connect(path)
        connection.execute("PRAGMA foreign_keys = ON")
        return cls(connection)

    def close(self) -> None:
        self.connection.close()

    def migrate(self) -> None:
        migration_path = Path(__file__).resolve().parents[1] / "migrations" / "001_initial.sql"
        self.connection.executescript(migration_path.read_text(encoding="utf-8"))
        self.connection.execute(
            "INSERT OR IGNORE INTO schema_migrations(version, applied_at) VALUES (?, ?)",
            ("001_initial", datetime.now(UTC).isoformat()),
        )
        self.connection.commit()

    def upsert_source(self, source: SourceFingerprint) -> None:
        self.connection.execute(
            """
            INSERT INTO sources(source_file_id, path, encoding, authority, default_claim_type, bytes, characters, sha256)
            VALUES (?, ?, ?, '', '', ?, ?, ?)
            ON CONFLICT(source_file_id) DO UPDATE SET
                path=excluded.path, encoding=excluded.encoding, bytes=excluded.bytes,
                characters=excluded.characters, sha256=excluded.sha256
            """,
            (source.source_file_id, source.path, source.encoding, source.bytes, source.characters, source.sha256),
        )
        self.connection.commit()

    def replace_sections_and_chunks(
        self,
        source_file_id: str,
        sections: Iterable[SectionRecord],
        chunks: Iterable[ChunkRecord],
    ) -> None:
        sections = tuple(sections)
        chunks = tuple(chunks)
        with self.connection:
            self.connection.execute("DELETE FROM chunks WHERE source_file_id = ?", (source_file_id,))
            self.connection.execute("DELETE FROM chapters WHERE source_file_id = ?", (source_file_id,))
            for section in sections:
                self.connection.execute(
                    "INSERT INTO chapters VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    (
                        section.source_id, section.source_file_id, section.volume, section.chapter,
                        section.title, section.sequence, section.start_offset, section.end_offset,
                        section.start_byte, section.end_byte, section.text, section.text_hash,
                        json.dumps(section.diagnostics, ensure_ascii=False),
                    ),
                )
            self.connection.executemany(
                """
                INSERT INTO chunks VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(chunk_id) DO UPDATE SET
                    text=excluded.text, chunk_hash=excluded.chunk_hash,
                    start_offset=excluded.start_offset, end_offset=excluded.end_offset,
                    start_byte=excluded.start_byte, end_byte=excluded.end_byte,
                    previous_id=excluded.previous_id, next_id=excluded.next_id
                """,
                [
                    (
                        chunk.chunk_id, chunk.source_id, chunk.source_file_id, chunk.volume,
                        chunk.chapter, chunk.title, chunk.sequence, chunk.chunk_sequence,
                        chunk.start_offset, chunk.end_offset, chunk.start_byte, chunk.end_byte,
                        chunk.text, chunk.chunk_hash, chunk.previous_id, chunk.next_id, chunk.status,
                    )
                    for chunk in chunks
                ],
            )
            self.connection.execute("DELETE FROM chunks_fts")
            self.connection.executemany(
                "INSERT INTO chunks_fts(chunk_id, text) VALUES (?, ?)",
                [(chunk.chunk_id, chunk.text) for chunk in chunks],
            )

    def search_chunks(self, query: str, limit: int = 20) -> list[ChunkRecord]:
        rows = self.connection.execute(
            "SELECT chunk_id, source_id, source_file_id, volume, chapter, title, sequence, chunk_sequence, start_offset, end_offset, start_byte, end_byte, text, chunk_hash, previous_id, next_id, status FROM chunks WHERE chunk_id IN (SELECT chunk_id FROM chunks_fts WHERE chunks_fts MATCH ?) LIMIT ?",
            (query, limit),
        ).fetchall()
        return [ChunkRecord(*row) for row in rows]

    def count(self, table: str) -> int:
        allowed = {"sources", "chapters", "chunks", "entities", "facts", "events", "relations", "rule_candidates", "conflicts"}
        if table not in allowed:
            raise ValueError(f"unsupported table: {table}")
        return int(self.connection.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0])

    def record_failed_run(self, run_id: str, chunk_id: str, backend: str, model: str, error_code: str) -> None:
        self.connection.execute(
            "INSERT OR REPLACE INTO extraction_runs(run_id, chunk_id, input_hash, backend, model, status, error_code, payload_json) VALUES (?, ?, '', ?, ?, 'FAILED', ?, '{}')",
            (run_id, chunk_id, backend, model, error_code),
        )
        self.connection.commit()

    def commit_extraction(self, chunk_id: str, run_id: str, extraction: ValidatedExtraction) -> None:
        if not extraction.ok or extraction.payload is None:
            raise ValueError("cannot commit invalid extraction")
        payload = extraction.payload
        with self.connection:
            for item in payload.get("entities", []):
                key = str(item.get("id", item.get("name", "")))
                self.connection.execute("INSERT OR IGNORE INTO entities(entity_key, entity_type, payload_json) VALUES (?, ?, ?)", (key, str(item.get("type", "concept")), json.dumps(item, ensure_ascii=False, sort_keys=True)))
            key_columns = {"facts": "fact_key", "events": "event_key", "relations": "relation_key", "rule_candidates": "rule_key"}
            for key_name, table in (("facts", "facts"), ("events", "events"), ("relations", "relations"), ("rule_candidates", "rule_candidates")):
                for item in payload.get(key_name, []):
                    key = str(item.get("id", item.get("fact_id", f"{table}:{chunk_id}")))
                    self.connection.execute(f"INSERT OR IGNORE INTO {table}({key_columns[table]}, source_id, chunk_id, payload_json) VALUES (?, ?, ?, ?)", (key, str(item.get("source_id", "")), chunk_id, json.dumps(item, ensure_ascii=False, sort_keys=True)))
            self.connection.execute("UPDATE chunks SET status='SUCCESS' WHERE chunk_id = ?", (chunk_id,))
            self.connection.execute("UPDATE extraction_runs SET status='SUCCESS' WHERE run_id = ?", (run_id,))
