from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from lore_engine.src.contracts import ChunkRecord
from lore_engine.src.database import LoreDatabase
from lore_engine.src.model_router import FixtureBackend, ModelRouter
from lore_engine.src.pipeline import Pipeline


def make_chunks() -> list[ChunkRecord]:
    return [
        ChunkRecord(
            f"V01-C001-S{index:02d}", "V01-C001", "fixture", 1, 1, "测试", index, index,
            index - 1, index, index - 1, index, f"证据{index}", f"hash-{index}"
        )
        for index in range(1, 6)
    ]


class FailingFixture(FixtureBackend):
    def __init__(self, failed_ids: set[str] | None = None) -> None:
        super().__init__()
        self.failed_ids = failed_ids or set()

    def run(self, task):
        if str(task.payload.get("chunk_id")) in self.failed_ids:
            return None, "fixture_failure"
        return super().run(task)


class PipelineResumeTests(unittest.TestCase):
    def test_stop_failure_resume_and_idempotency(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            db = LoreDatabase.open(Path(tmp) / "lore.sqlite")
            try:
                db.migrate()
                db.connection.execute("INSERT INTO sources VALUES (?, ?, ?, ?, ?, ?, ?, ?)", ("fixture", "fixture.txt", "utf-8", "test", "CANON", 1, 1, "hash"))
                db.connection.execute("INSERT INTO chapters VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", ("V01-C001", "fixture", 1, 1, "测试", 1, 0, 5, 0, 5, "证据1证据2证据3证据4证据5", "hash", "[]"))
                db.connection.executemany("INSERT INTO chunks VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [tuple(chunk.__dict__.values()) for chunk in make_chunks()])
                db.connection.commit()
                backend = FailingFixture({"V01-C001-S03"})
                pipeline = Pipeline(db, ModelRouter(backend, cache_dir=Path(tmp) / "cache"))

                first = pipeline.run(make_chunks(), dry_run=False, stop_after=2)
                self.assertEqual(first.processed, 2)
                self.assertEqual([row[0] for row in db.connection.execute("SELECT status FROM chunks ORDER BY chunk_sequence")], ["SUCCESS", "SUCCESS", "PENDING", "PENDING", "PENDING"])

                failed = pipeline.run(make_chunks(), dry_run=False, resume=True)
                self.assertEqual(failed.failed, 1)
                self.assertEqual(db.connection.execute("SELECT COUNT(*) FROM facts").fetchone()[0], 4)

                backend.failed_ids.clear()
                resumed = pipeline.run(make_chunks(), dry_run=False, resume=True)
                self.assertEqual(resumed.failed, 0)
                self.assertEqual(db.connection.execute("SELECT COUNT(*) FROM facts").fetchone()[0], 5)
                before = db.connection.execute("SELECT COUNT(*) FROM facts").fetchone()[0]
                pipeline.run(make_chunks(), dry_run=False, resume=True)
                self.assertEqual(db.connection.execute("SELECT COUNT(*) FROM facts").fetchone()[0], before)
            finally:
                db.close()


if __name__ == "__main__":
    unittest.main()
