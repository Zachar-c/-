from __future__ import annotations

import json
import os
import sqlite3
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def run_cli(database: Path, *args: str) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["PYTHONPATH"] = str(ROOT)
    return subprocess.run(
        [
            os.fspath(Path(os.environ.get("LORE_PYTHON", "C:/Users/Zachary/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe"))),
            "-m", "lore_engine.cli", *args, "--database", os.fspath(database),
        ],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


class RealTenSectionAcceptanceTests(unittest.TestCase):
    def test_index_extract_resume_and_repeat_are_idempotent(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            database = Path(tmp) / "lore.sqlite"
            indexed = run_cli(database, "index", "--source-file-id", "gu_zhenren_main", "--section-limit", "10")
            self.assertEqual(indexed.returncode, 0, indexed.stderr)
            self.assertEqual(json.loads(indexed.stdout), {"characters": 31084, "chunks": 10, "sections": 10})

            first = run_cli(database, "run", "--backend", "fixture", "--stop-after", "3")
            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertEqual(json.loads(first.stdout)["processed"], 3)
            resumed = run_cli(database, "run", "--backend", "fixture", "--resume")
            self.assertEqual(resumed.returncode, 0, resumed.stderr)
            self.assertEqual(json.loads(resumed.stdout)["processed"], 7)

            db = sqlite3.connect(database)
            try:
                self.assertEqual(db.execute("SELECT COUNT(*) FROM chapters").fetchone()[0], 10)
                self.assertEqual(db.execute("SELECT COUNT(*) FROM chunks WHERE status='SUCCESS'").fetchone()[0], 10)
                self.assertEqual(db.execute("SELECT COUNT(*) FROM facts").fetchone()[0], 10)
                rows = db.execute("SELECT source_id, start_offset, end_offset, text FROM chunks ORDER BY sequence, chunk_sequence").fetchall()
                self.assertEqual(len(rows), 10)
                self.assertTrue(all(row[1] < row[2] for row in rows))
            finally:
                db.close()

            repeat = run_cli(database, "run", "--backend", "fixture", "--resume")
            self.assertEqual(repeat.returncode, 0, repeat.stderr)
            self.assertEqual(json.loads(repeat.stdout)["processed"], 0)


if __name__ == "__main__":
    unittest.main()
