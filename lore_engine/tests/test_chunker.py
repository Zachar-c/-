from __future__ import annotations

import unittest

from lore_engine.src.chunker import iter_chunks
from lore_engine.src.contracts import ChunkConfig, SectionRecord


def section(source_id: str, text: str) -> SectionRecord:
    return SectionRecord(
        source_id=source_id,
        source_file_id="fixture",
        volume=1,
        chapter=1,
        title="测试节",
        sequence=1,
        start_offset=0,
        end_offset=len(text),
        start_byte=0,
        end_byte=len(text.encode("utf-8")),
        text=text,
        text_hash="section-hash",
    )


class ChunkerTests(unittest.TestCase):
    def test_chunks_reconstruct_section_without_overlap(self) -> None:
        text = "段落一\n\n段落二很长\n\n段落三"
        chunks = list(iter_chunks(section("V01-C001", text), text, ChunkConfig(6, 8, 3)))

        self.assertGreater(len(chunks), 1)
        self.assertEqual("".join(chunk.text for chunk in chunks), text)
        self.assertEqual([c.chunk_sequence for c in chunks], list(range(1, len(chunks) + 1)))
        self.assertTrue(all(c.text == text[c.start_offset:c.end_offset] for c in chunks))
        self.assertTrue(all(a.end_offset == b.start_offset for a, b in zip(chunks, chunks[1:])))
        self.assertIsNone(chunks[0].previous_id)
        self.assertIsNone(chunks[-1].next_id)
        self.assertEqual(chunks[0].next_id, chunks[1].chunk_id)

    def test_long_paragraph_splits_deterministically(self) -> None:
        text = "甲" * 21
        config = ChunkConfig(8, 8, 3)
        first = list(iter_chunks(section("V01-C002", text), text, config))
        second = list(iter_chunks(section("V01-C002", text), text, config))

        self.assertEqual([c.chunk_id for c in first], [c.chunk_id for c in second])
        self.assertEqual("".join(c.text for c in first), text)
        self.assertTrue(all(len(c.text) <= 8 for c in first))


if __name__ == "__main__":
    unittest.main()
