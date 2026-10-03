"""Small regression checks for build_index.py without a novel fixture."""
import csv
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_index import noise_flags

SCRIPT = Path(__file__).with_name("build_index.py")


class BuildIndexTests(unittest.TestCase):
    def test_noise_flags(self):
        self.assertEqual(
            noise_flags("章节目录 第三节：作者PS：更新 http://example.test", ""),
            "directory;author_or_site;site_markup",
        )
        self.assertEqual(noise_flags("正文", "平静标题"), "")

    def run_builder(self, root, name, text):
        source = root / (name + ".txt")
        output = root / (name + "-out")
        source.write_bytes(text.encode("gbk"))
        subprocess.run(
            [sys.executable, str(SCRIPT), "-SourcePath", str(source), "-OutputDirectory", str(output)],
            check=True, capture_output=True, text=True,
        )
        return output

    def test_cli_last_chapter_duplicate_titles_and_empty_source(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            output = self.run_builder(
                root, "sample",
                "第一节：重复标题\n正文一\n（PS：说明）\n第二节：重复标题\n正文二\n第三节：末章\n末尾正文",
            )
            records = json.loads((output / "chapter-headings.json").read_text(encoding="utf-8-sig"))
            self.assertEqual([r["end_line"] for r in records], [3, 5, 7])
            self.assertEqual([r["content_characters"] for r in records], [18, 11, 10])
            self.assertEqual([r["contains_author_ps"] for r in records], [True, False, False])
            self.assertEqual([r["duplicate_title"] for r in records], [True, True, False])
            with (output / "chapter-number-summary.csv").open(encoding="utf-8-sig", newline="") as fh:
                summary = list(csv.DictReader(fh))
            self.assertEqual([r["number"] for r in summary], ["1", "2", "3"])

            empty_output = self.run_builder(root, "empty", "")
            self.assertEqual(
                json.loads((empty_output / "chapter-headings.json").read_text(encoding="utf-8-sig")),
                [],
            )
            self.assertEqual(
                json.loads((empty_output / "source-metadata.json").read_text(encoding="utf-8-sig"))["heading_hits"],
                0,
            )


if __name__ == "__main__":
    unittest.main()
