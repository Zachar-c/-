from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from lore_engine.src.database import LoreDatabase
from lore_engine.src.reports import build_report, write_report


class ReportTests(unittest.TestCase):
    def test_report_is_json_and_counts_statuses(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            db = LoreDatabase.open(Path(tmp) / "lore.sqlite")
            try:
                db.migrate()
                report = build_report(db)
                self.assertEqual(report["counts"]["chunks"], 0)
                output = Path(tmp) / "report.json"
                write_report(report, output)
                self.assertEqual(report, __import__("json").loads(output.read_text(encoding="utf-8")))
            finally:
                db.close()


if __name__ == "__main__":
    unittest.main()
