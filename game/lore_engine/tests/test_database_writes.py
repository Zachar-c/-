from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from lore_engine.src.contracts import ChunkRecord, ValidatedExtraction
from lore_engine.src.database import LoreDatabase


class DatabaseWriteTests(unittest.TestCase):
    def test_failed_run_does_not_write_formal_rows(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            db = LoreDatabase.open(Path(tmp) / "lore.sqlite")
            try:
                db.migrate()
                db.record_failed_run("run-1", "V01-C001-S01", "fixture", "gpt-5.6-luna", "bad_json")
                self.assertEqual(db.count("facts"), 0)
                self.assertEqual(db.count("entities"), 0)
                self.assertEqual(db.connection.execute("SELECT status FROM extraction_runs").fetchone()[0], "FAILED")
            finally:
                db.close()


if __name__ == "__main__":
    unittest.main()
