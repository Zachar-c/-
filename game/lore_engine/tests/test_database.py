from __future__ import annotations

import tempfile
import unittest
import json
from pathlib import Path

from lore_engine.src.chunker import iter_chunks, parse_sections
from lore_engine.src.contracts import ChunkConfig, SourceFingerprint, SourceSpec
from lore_engine.src.database import LoreDatabase
from lore_engine.src.source_manifest import read_source


class DatabaseTests(unittest.TestCase):
    def test_migration_fts_and_idempotent_source_import(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            db = LoreDatabase.open(Path(tmp) / "lore.sqlite")
            db.migrate()
            source = SourceFingerprint("fixture", "fixture.txt", "utf-8", 4, 4, "a" * 64)
            db.upsert_source(source)
            db.upsert_source(source)

            self.assertEqual(db.count("sources"), 1)
            self.assertEqual(db.search_chunks("月光蛊"), [])
            db.close()

    def test_ten_sections_import_is_contiguous_and_idempotent(self) -> None:
        root = Path(__file__).resolve().parents[2]
        manifest = root / "lore_sources" / "manifest.json"
        spec_data = next(
            item
            for item in json.loads(manifest.read_text(encoding="utf-8"))
            if item["source_file_id"] == "gu_zhenren_main"
        )
        spec = SourceSpec(**spec_data)
        text = read_source(root, spec)
        sections = parse_sections(text, section_limit=10)
        chunks = tuple(
            chunk
            for item in sections
            for chunk in iter_chunks(item, item.text, ChunkConfig(6000, 8000, 3000))
        )

        with tempfile.TemporaryDirectory() as tmp:
            db = LoreDatabase.open(Path(tmp) / "lore.sqlite")
            try:
                db.migrate()
                db.upsert_source(
                    SourceFingerprint(
                        spec.source_file_id,
                        spec.path,
                        spec.encoding,
                        len(text.encode("utf-8")),
                        len(text),
                        spec.expected_sha256,
                    )
                )
                db.replace_sections_and_chunks(spec.source_file_id, sections, chunks)
                first_counts = (db.count("chapters"), db.count("chunks"))
                db.replace_sections_and_chunks(spec.source_file_id, sections, chunks)
                second_counts = (db.count("chapters"), db.count("chunks"))

                self.assertEqual(first_counts, (10, len(chunks)))
                self.assertEqual(second_counts, first_counts)
                self.assertTrue(db.search_chunks("月光蛊"))
                for item in sections:
                    stored = db.connection.execute(
                        "SELECT text FROM chapters WHERE source_id = ?", (item.source_id,)
                    ).fetchone()[0]
                    self.assertEqual(stored, item.text)
            finally:
                db.close()


if __name__ == "__main__":
    unittest.main()
