from __future__ import annotations

import hashlib
import tempfile
import unittest
from pathlib import Path

from lore_engine.src.contracts import ChunkRecord, EvidenceRef, SeedRecord, SourceSpec, WorldClaim
from lore_engine.src.world_evidence import CounterEvidenceCandidate, EvidenceResolutionError, check_claim_coverage, find_counter_evidence, resolve_evidence


class WorldEvidenceTests(unittest.TestCase):
    def _spec(self, root: Path, name: str = "short_primary.txt", authority: str = "primary_text") -> SourceSpec:
        path = root / name
        return SourceSpec("fixture", name, "utf-8", authority, "CANON", hashlib.sha256(path.read_bytes()).hexdigest())

    def test_resolves_quote_at_exact_decoded_character_offset_once(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "short_primary.txt"
            source.write_bytes(Path(__file__).parent.joinpath("fixtures/world_model/short_primary.txt").read_bytes())
            quote = "蛊是天地真精"
            text = source.read_text(encoding="utf-8")
            start = text.index(quote)
            evidence = EvidenceRef("e1", "fixture", "fixture#1", start, start + len(quote), quote, "primary_text", "support")

            resolved = resolve_evidence(root, (self._spec(root),), (evidence,))

            self.assertTrue(resolved[0].ok)
            self.assertEqual(resolved[0].quote, quote)
            self.assertEqual(resolved[0].char_start, start)
            self.assertEqual(resolved[0].quote_sha256, hashlib.sha256(quote.encode("utf-8")).hexdigest())

    def test_rejects_duplicate_or_byte_based_alignment(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "short_primary.txt"
            source.write_bytes(Path(__file__).parent.joinpath("fixtures/world_model/short_primary.txt").read_bytes())
            quote = "蛊是天地真精"
            text = source.read_text(encoding="utf-8")
            start = text.index(quote)
            valid = EvidenceRef("e1", "fixture", "fixture#1", start, start + len(quote), quote, "primary_text", "support")
            byte_offset = EvidenceRef("e2", "fixture", "fixture#1", len(text[:start].encode("utf-8")), len(text[:start].encode("utf-8")) + len(quote), quote, "primary_text", "support")

            self.assertTrue(resolve_evidence(root, (self._spec(root),), (valid,))[0].ok)
            self.assertFalse(resolve_evidence(root, (self._spec(root),), (byte_offset,))[0].ok)
            duplicate_start = text.index("蛊")
            duplicate = EvidenceRef("e3", "fixture", "fixture#1", duplicate_start, duplicate_start + 1, "蛊", "primary_text", "support")
            self.assertFalse(resolve_evidence(root, (self._spec(root),), (duplicate,))[0].ok)

    def test_rejects_source_hash_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "short_primary.txt"
            source.write_text("changed", encoding="utf-8")
            bad = SourceSpec("fixture", source.name, "utf-8", "primary_text", "CANON", "0" * 64)
            with self.assertRaises(EvidenceResolutionError):
                resolve_evidence(root, (bad,), ())

    def test_coverage_retains_support_condition_and_counterexample(self) -> None:
        claim = WorldClaim("c1", "gu", "蛊有条件且存在反例", "canonical", "high", ("fixture",), ("support", "condition"), ("counter",), "high")
        evidence = (
            EvidenceRef("support", "fixture", "fixture#1", 0, 1, "蛊", "primary_text", "support"),
            EvidenceRef("condition", "fixture", "fixture#2", 1, 2, "天", "primary_text", "condition"),
            EvidenceRef("counter", "fixture", "fixture#3", 2, 3, "地", "primary_text", "counterexample"),
        )
        result = check_claim_coverage(claim, evidence)
        self.assertTrue(result.ok)
        self.assertEqual([item.evidence_id for item in result.conditions], ["condition"])
        self.assertEqual([item.evidence_id for item in result.counter_evidence], ["counter"])

    def test_secondary_note_can_find_candidate_but_not_p0(self) -> None:
        claim = WorldClaim("c1", "gu", "蛊可炼化", "canonical", "high", ("fixture",), (), (), "high")
        seed = SeedRecord("s1", "seed_note", "反例", "反例：蛊可炼化并非总是成立", "note.md", "p1", "hash", "approved")
        found = find_counter_evidence(claim, (), (seed,))
        self.assertTrue(found)
        self.assertEqual(found[0].authority, "secondary_note")
        self.assertFalse(check_claim_coverage(claim, found).ok)

    def test_indexed_counterexample_is_kept_as_primary_evidence(self) -> None:
        chunk = ChunkRecord("V01-C001-S01", "V01-C001", "fixture", 1, 1, "短冲突", 1, 1, 0, 18, 0, 18, "反例：蛊并非总能激活。", "hash")
        claim = WorldClaim("c1", "gu", "蛊总能激活", "deferred", "high", ("fixture",), (), (), "unknown")

        found = find_counter_evidence(claim, (chunk,))

        self.assertEqual(len(found), 1)
        self.assertIsInstance(found[0], CounterEvidenceCandidate)
        self.assertIsNone(found[0].authority)
        self.assertFalse(found[0].verified)
        self.assertEqual(found[0].evidence_kind, "counterexample")

    def test_chunk_authority_comes_from_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "short_conflict.txt"
            source.write_bytes(Path(__file__).parent.joinpath("fixtures/world_model/short_conflict.txt").read_bytes())
            spec = self._spec(root, "short_conflict.txt", "secondary_note")
            text = source.read_text(encoding="utf-8")
            chunk = ChunkRecord("chunk", "source", "fixture", 1, 1, "短冲突", 1, 1, 0, len(text), 0, len(text.encode("utf-8")), text, hashlib.sha256(text.encode("utf-8")).hexdigest())

            found = find_counter_evidence(WorldClaim("c", "x", "x", "deferred", "high", ("fixture",), (), (), "unknown"), (chunk,), (), (spec,), root)

            self.assertEqual(found[0].authority, "secondary_note")

    def test_chunk_counterexample_requires_exact_source_alignment_and_hash(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "short_conflict.txt"
            source.write_bytes(Path(__file__).parent.joinpath("fixtures/world_model/short_conflict.txt").read_bytes())
            spec = self._spec(root, "short_conflict.txt")
            text = source.read_text(encoding="utf-8")
            chunk = ChunkRecord("chunk", "source", "fixture", 1, 1, "短冲突", 1, 1, 0, len(text), 0, len(text.encode("utf-8")), text, "wrong-hash")

            found = find_counter_evidence(WorldClaim("c", "x", "x", "deferred", "high", ("fixture",), (), (), "unknown"), (chunk,), (), (spec,), root)

            self.assertTrue(found)
            self.assertIsInstance(found[0], CounterEvidenceCandidate)
            self.assertFalse(found[0].verified)
            self.assertIn("hash", found[0].reason)

    def test_seed_statement_match_without_marker_is_not_counter_evidence(self) -> None:
        claim = WorldClaim("c1", "gu", "蛊可炼化", "canonical", "high", ("fixture",), (), (), "high")
        seed = SeedRecord("s1", "seed_note", "observation", "蛊可炼化", "note.md", "p1", "hash", "approved")

        self.assertEqual(find_counter_evidence(claim, (), (seed,)), ())

    def test_raw_string_is_skipped_as_unverified_candidate_with_diagnostic(self) -> None:
        found = find_counter_evidence(WorldClaim("c", "x", "x", "deferred", "high", (), (), (), "unknown"), ("反例：没有坐标",))

        self.assertEqual(len(found), 1)
        self.assertIsInstance(found[0], CounterEvidenceCandidate)
        self.assertIsNone(found[0].source_file_id)
        self.assertIsNone(found[0].char_start)
        self.assertFalse(found[0].verified)
        self.assertIn("coordinates", found[0].reason)

    def test_source_path_error_is_wrapped(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            bad = SourceSpec("fixture", "../outside.txt", "utf-8", "primary_text", "CANON", "0" * 64)
            with self.assertRaises(EvidenceResolutionError):
                resolve_evidence(root, (bad,), ())

    def test_malformed_chunk_bounds_remain_candidate(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "short_conflict.txt"
            source.write_bytes(Path(__file__).parent.joinpath("fixtures/world_model/short_conflict.txt").read_bytes())
            spec = self._spec(root, "short_conflict.txt")
            text = source.read_text(encoding="utf-8")
            chunk = ChunkRecord("chunk", "source", "fixture", 1, 1, "短冲突", 1, 1, 0, len(text) + 1, 0, len(text.encode("utf-8")) + 1, text, hashlib.sha256(text.encode("utf-8")).hexdigest())

            found = find_counter_evidence(WorldClaim("c", "x", "x", "deferred", "high", ("fixture",), (), (), "unknown"), (chunk,), (), (spec,), root)

            self.assertIsInstance(found[0], CounterEvidenceCandidate)
            self.assertFalse(found[0].verified)
            self.assertIn("bounds", found[0].reason)

    def test_candidate_is_unresolved_in_claim_coverage(self) -> None:
        claim = WorldClaim("c", "x", "x", "deferred", "high", ("fixture",), (), ("candidate",), "unknown")
        candidate = CounterEvidenceCandidate("candidate", "fixture", "note", None, None, "反例", "secondary_note", "counterexample", False, "needs verification")

        result = check_claim_coverage(claim, (candidate,))

        self.assertFalse(result.ok)
        self.assertEqual(result.counter_evidence, (candidate,))
        self.assertTrue(any("unresolved" in error for error in result.errors))

    def test_mismatched_chunk_byte_bounds_remain_candidate(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "short_conflict.txt"
            source.write_bytes(Path(__file__).parent.joinpath("fixtures/world_model/short_conflict.txt").read_bytes())
            spec = self._spec(root, "short_conflict.txt")
            text = source.read_text(encoding="utf-8")
            chunk = ChunkRecord("chunk", "source", "fixture", 1, 1, "短冲突", 1, 1, 0, len(text), 1, len(text.encode("utf-8")), text, hashlib.sha256(text.encode("utf-8")).hexdigest())

            found = find_counter_evidence(WorldClaim("c", "x", "x", "deferred", "high", ("fixture",), (), (), "unknown"), (chunk,), (), (spec,), root)

            self.assertIsInstance(found[0], CounterEvidenceCandidate)
            self.assertFalse(found[0].verified)
            self.assertIn("byte", found[0].reason)

    def test_long_marker_line_is_unresolved_instead_of_truncated_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            text = "反例：" + "长" * 240 + "。\n"
            source = root / "long.txt"
            source.write_bytes(text.encode("utf-8"))
            spec = SourceSpec("fixture", source.name, "utf-8", "primary_text", "CANON", hashlib.sha256(source.read_bytes()).hexdigest())
            chunk = ChunkRecord("chunk", "source", "fixture", 1, 1, "长线", 1, 1, 0, len(text), 0, len(text.encode("utf-8")), text, hashlib.sha256(text.encode("utf-8")).hexdigest())

            found = find_counter_evidence(WorldClaim("c", "x", "x", "deferred", "high", ("fixture",), (), (), "unknown"), (chunk,), (), (spec,), root)

            self.assertIsInstance(found[0], CounterEvidenceCandidate)
            self.assertFalse(found[0].verified)
            self.assertIn("200", found[0].reason)

    def test_gb18030_chunk_byte_bounds_use_manifest_encoding(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            text = "反例：人祖传并非总能直接证明规则。\n"
            source = root / "renzu.txt"
            source.write_bytes(text.encode("gb18030"))
            spec = SourceSpec("renzu", source.name, "gb18030", "in_world_text", "IN_WORLD_LORE", hashlib.sha256(source.read_bytes()).hexdigest())
            base = ("chunk", "source", "renzu", 1, 1, "人祖传", 1, 1, 0, len(text), 0, len(source.read_bytes()), text, hashlib.sha256(text.encode("utf-8")).hexdigest())
            valid = ChunkRecord(*base)
            mismatched = ChunkRecord(*base[:10], 1, base[11], *base[12:])
            claim = WorldClaim("c", "x", "x", "deferred", "high", ("renzu",), (), (), "unknown")

            resolved = find_counter_evidence(claim, (valid,), (), (spec,), root)
            candidate = find_counter_evidence(claim, (mismatched,), (), (spec,), root)

            self.assertTrue(resolved[0].ok)
            self.assertEqual(resolved[0].authority, "in_world_text")
            self.assertIsInstance(candidate[0], CounterEvidenceCandidate)
            self.assertIn("byte", candidate[0].reason)


if __name__ == "__main__":
    unittest.main()
