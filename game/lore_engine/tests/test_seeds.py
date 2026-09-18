from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from lore_engine.src.seeds import import_seeds, load_seed_records
from lore_engine.src.database import LoreDatabase


class SeedTests(unittest.TestCase):
    def test_loads_four_seed_kinds_and_import_is_idempotent(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for kind in ("canon", "inferred", "note", "game_design"):
                (root / f"seed_{kind}.jsonl").write_text(
                    json.dumps({"seed_id": f"seed-{kind}", "seed_kind": f"seed_{kind}", "label": kind, "summary": kind, "source_doc": "fixture", "source_ref": "1", "content_hash": "hash", "review_status": "approved"}, ensure_ascii=False) + "\n",
                    encoding="utf-8",
                )
            records = load_seed_records(root)
            self.assertEqual({record.seed_kind for record in records}, {"seed_canon", "seed_inferred", "seed_note", "seed_game_design"})
            db = LoreDatabase.open(root / "lore.sqlite")
            try:
                db.migrate()
                first = import_seeds(db, records)
                second = import_seeds(db, records)
                self.assertEqual(first.inserted, 4)
                self.assertEqual(second.inserted, 0)
                self.assertEqual(db.count("facts"), 4)
            finally:
                db.close()


if __name__ == "__main__":
    unittest.main()
