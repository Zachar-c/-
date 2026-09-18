from __future__ import annotations

import unittest

from lore_engine.src.contracts import ChunkRecord
from lore_engine.src.validator import align_quote, validate_extraction


def chunk(text: str = "原文证据") -> ChunkRecord:
    return ChunkRecord(
        "V01-C001-S01", "V01-C001", "fixture", 1, 1, "测试节", 1, 1,
        0, len(text), 0, len(text.encode("utf-8")), text, "hash",
    )


def payload(item: dict | None = None) -> dict:
    fact = {
        "fact_id": "fact-1", "subject": "主体", "predicate": "属性",
        "object": "对象", "fact_type": "CANON", "confidence": 0.8,
        "source_id": "V01-C001", "chunk_id": "V01-C001-S01",
        "source_quote": "原文证据", "sequence": 1, "conditions": [], "uncertainty": "",
    }
    if item:
        fact.update(item)
    return {"entities": [], "facts": [fact], "events": [], "relations": [], "rule_candidates": [], "uncertain_items": []}


class ValidatorTests(unittest.TestCase):
    def test_valid_fact_with_exact_quote_passes(self) -> None:
        result = validate_extraction(payload(), chunk(), "完整原文证据")
        self.assertTrue(result.ok, result.errors)

    def test_bad_quote_is_rejected_even_if_full_source_contains_it(self) -> None:
        result = validate_extraction(payload({"source_quote": "完整原文证据"}), chunk(), "完整原文证据")
        self.assertFalse(result.ok)

    def test_bad_enum_confidence_and_reference_are_rejected(self) -> None:
        result = validate_extraction(payload({"fact_type": "WRONG", "confidence": 2, "chunk_id": "other"}), chunk(), "完整原文")
        self.assertFalse(result.ok)
        self.assertTrue(any("unknown enum" in error or "confidence" in error or "chunk_id" in error for error in result.errors))

    def test_quote_alignment_rejects_ambiguous_matches(self) -> None:
        self.assertFalse(align_quote("证据", "证据与证据").ok)
        self.assertTrue(align_quote("唯一", "原文唯一").ok)

    def test_top_level_and_nested_enums_are_closed(self) -> None:
        bad = payload()
        bad["unexpected"] = []
        self.assertFalse(validate_extraction(bad, chunk(), "完整原文").ok)
        bad = {"entities": [{"type": "unknown"}], "facts": [], "events": [], "relations": [], "rule_candidates": [], "uncertain_items": []}
        self.assertFalse(validate_extraction(bad, chunk(), "完整原文").ok)


if __name__ == "__main__":
    unittest.main()
