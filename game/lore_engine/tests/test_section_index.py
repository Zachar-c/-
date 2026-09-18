from __future__ import annotations

import unittest

from lore_engine.src.chunker import parse_sections


class SectionIndexTests(unittest.TestCase):
    def test_selects_first_ten_unindented_sections_after_volume(self) -> None:
        text = "\n".join(
            [
                "前言",
                "第一卷：魔性不改",
                *[f"第{number}节：标题{number}\n正文{number}" for number in range(1, 11)],
                "第二卷：后续",
                "第一节：不应选择",
            ]
        )
        sections = parse_sections(text, section_limit=10)

        self.assertEqual(len(sections), 10)
        self.assertEqual([section.volume for section in sections], [1] * 10)
        self.assertEqual([section.chapter for section in sections], list(range(1, 11)))
        self.assertEqual([section.sequence for section in sections], list(range(1, 11)))
        self.assertEqual(sections[0].source_id, "V01-C001")
        self.assertEqual(sections[-1].source_id, "V01-C010")
        self.assertEqual(sections[0].text, "正文1")

    def test_indented_duplicate_heading_is_diagnostic_only(self) -> None:
        text = "\n".join(
            [
                "第一卷：魔性不改",
                "第一节：正式标题",
                "正文",
                "    第一节：重复标题",
                "重复正文",
            ]
        )
        sections = parse_sections(text, section_limit=10)

        self.assertEqual(len(sections), 1)
        self.assertEqual(sections[0].title, "第一节：正式标题")
        self.assertIn("indented_heading", sections[0].diagnostics)

    def test_repeated_local_number_does_not_overwrite_selected_records(self) -> None:
        text = "\n".join(
            [
                "第一卷：第一卷",
                "第一节：第一",
                "A",
                "第二卷：第二卷",
                "第一节：第二卷第一节",
                "B",
            ]
        )
        sections = parse_sections(text, section_limit=10)

        self.assertEqual(len(sections), 1)
        self.assertEqual(sections[0].source_id, "V01-C001")
        self.assertEqual(sections[0].text, "A")


if __name__ == "__main__":
    unittest.main()
