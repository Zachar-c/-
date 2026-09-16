from __future__ import annotations

import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from lore_engine.src.reports import (
    build_world_baseline_report,
    render_world_baseline_markdown,
    write_world_baseline_outputs,
)
from lore_engine.src.world_baseline import LEGACY_DISPOSITIONS


ROOT = Path(__file__).resolve().parents[2]
GENERATED_AT = "2026-09-16T00:00:00Z"


def _write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False) + "\n", encoding="utf-8")


def _write_report_fixture(root: Path, *, support_quote: str = "Support fact.") -> Path:
    source_text = "Support fact.\nCondition fact.\nCounter fact.\n"
    source_path = root / "lore_sources" / "fixture.txt"
    source_path.parent.mkdir(parents=True, exist_ok=True)
    source_path.write_bytes(source_text.encode("utf-8"))

    config_path = root / "lore_engine" / "config" / "world-model-stage0.json"
    _write_json(
        config_path,
        {
            "version": "world-model-stage0-v1",
            "minimum_claims": 1,
            "high_impact_claim_ids": ["fixture_claim"],
            "p0_source_ids": ["fixture"],
        },
    )
    benchmark_dir = root / "lore_sources" / "benchmarks" / "world_model_stage0"
    _write_json(
        benchmark_dir / "claims.jsonl",
        {
            "claim_id": "fixture_claim",
            "topic": "fixture_claim",
            "statement": "A scoped fixture ruling.",
            "status": "derived",
            "previous_status": "candidate",
            "impact": "high",
            "source_ids": ["fixture"],
            "evidence_ids": ["support", "condition"],
            "counter_evidence_ids": ["counter"],
            "confidence": "high",
        },
    )
    _write_json(
        benchmark_dir / "decisions.jsonl",
        {
            "claim_id": "fixture_claim",
            "decision_kind": "final",
            "ruling": "revise",
            "rationale": "Condition: support applies only in the stated scope.",
            "player_consequence": "Players see the scoped rule.",
            "implementation_action": "Retain the scoped rule.",
            "non_regression_notes": [],
            "previous_status": "candidate",
        },
    )
    evidence = []
    for evidence_id, quote, kind in (
        ("support", support_quote, "support"),
        ("condition", "Condition fact.", "condition"),
        ("counter", "Counter fact.", "counterexample"),
    ):
        start = source_text.index("Support fact.") if evidence_id == "support" else source_text.index(quote)
        evidence.append(
            {
                "evidence_id": evidence_id,
                "source_file_id": "fixture",
                "source_ref": f"fixture:{evidence_id}",
                "char_start": start,
                "char_end": start + len(quote),
                "quote": quote,
                "authority": "primary_text",
                "evidence_kind": kind,
            }
        )
    evidence_path = benchmark_dir / "evidence.jsonl"
    evidence_path.parent.mkdir(parents=True, exist_ok=True)
    evidence_path.write_text(
        "".join(json.dumps(item, ensure_ascii=False) + "\n" for item in evidence),
        encoding="utf-8",
    )
    _write_json(
        root / "lore_sources" / "manifest.json",
        [
            {
                "source_file_id": "fixture",
                "path": "lore_sources/fixture.txt",
                "encoding": "utf-8",
                "authority": "primary_text",
                "default_claim_type": "CANON",
                "expected_sha256": hashlib.sha256(source_path.read_bytes()).hexdigest(),
            }
        ],
    )
    return source_path


class WorldBaselineReportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.report = build_world_baseline_report(ROOT, generated_at_utc=GENERATED_AT)

    def test_report_freezes_metadata_provenance_counts_and_legacy_dispositions(self) -> None:
        report = self.report

        self.assertEqual(report["baseline_version"], "world-model-baseline-v1")
        self.assertEqual(report["generator"], {"name": "lore_engine.reports", "version": "1"})
        self.assertEqual(report["generated_at_utc"], GENERATED_AT)
        self.assertEqual(report["timestamp_policy"], "explicit_reproducible_utc")

        manifest = report["provenance"]["source_manifest"]
        self.assertEqual(manifest["path"], "lore_sources/manifest.json")
        self.assertRegex(manifest["sha256"], r"^[0-9a-f]{64}$")
        self.assertEqual(
            [source["source_file_id"] for source in manifest["sources"]],
            ["gu_zhenren_main", "ren_zu_zhuan"],
        )
        self.assertTrue(all(source["declared_sha256"] == source["actual_sha256"] for source in manifest["sources"]))

        input_hashes = report["provenance"]["input_files"]
        self.assertEqual([item["path"] for item in input_hashes], sorted(item["path"] for item in input_hashes))
        self.assertEqual(len(input_hashes), 5)
        self.assertTrue(all(len(item["sha256"]) == 64 for item in input_hashes))
        self.assertEqual(report["claim_counts"]["total"], 24)
        self.assertEqual(report["claim_counts"]["high_impact"], 24)
        self.assertEqual(report["claim_counts"]["effective_rulings"], {"needs_evidence": 24})
        self.assertEqual(len(report["unresolved_high_impact"]), 24)
        self.assertEqual(report["stage0_gate"]["result"], "NO_GO")

        expected_legacy = [
            {"mechanic_id": item.mechanic_id, "disposition": item.disposition, "rationale": item.rationale}
            for item in LEGACY_DISPOSITIONS
        ]
        self.assertEqual(report["legacy_dispositions"], expected_legacy)
        self.assertEqual(
            report["legacy_disposition_summary"],
            {
                "f1_pity": "audit_only",
                "promotion_economy": "defer",
                "promotion_materials": "defer",
                "q8g_promotion_chain": "audit_only",
                "school_promotion": "defer",
            },
        )

    def test_claim_rows_keep_evidence_coordinates_without_copying_quotes(self) -> None:
        for row in self.report["claims"]:
            self.assertIn("source_fact", row)
            self.assertIn("evidence", row)
            self.assertIn("counter_evidence", row)
            self.assertIn("implementation", row)
            for evidence in row["evidence"] + row["counter_evidence"]:
                self.assertEqual(
                    set(evidence),
                    {"evidence_id", "source_file_id", "source_ref", "char_start", "char_end", "authority", "evidence_kind"},
                )
                self.assertNotIn("quote", evidence)
            self.assertLessEqual(len(row["implementation"]["locations"]), 12)

    def test_markdown_has_required_review_sections_and_columns(self) -> None:
        markdown = render_world_baseline_markdown(self.report)

        for heading in (
            "## 已核验事实",
            "## 偏差候选",
            "## 冲突与未知",
            "## 当前实现映射",
            "## 玩家后果",
            "## 迁移/废止说明",
            "## Stage 0 Gate",
        ):
            self.assertIn(heading, markdown)
        self.assertIn(
            "| Claim | 已核验事实 | Evidence IDs | Source locations | 偏差候选 | 冲突与未知 | 当前实现映射 | 玩家后果 | 迁移/废止说明 |",
            markdown,
        )
        self.assertIn("**NO_GO**", markdown)
        self.assertIn("[适配登记](../adaptation-register.md)", markdown)
        self.assertNotIn("stage0_pending_main_text\n", markdown)
        representative = next(row for row in self.report["claims"] if row["claim_id"] == "aptitude_capacity")
        self.assertTrue(representative["world_model_ruling"])
        self.assertTrue(representative["derivation"])
        self.assertTrue(representative["player_consequence"])
        self.assertGreater(representative["implementation"]["finding_count"], 0)
        self.assertTrue(representative["implementation"]["locations"])
        self.assertIn("`aptitude_capacity`", markdown)
        self.assertIn("data/balance.json#/aptitude_recovery_multiplier", markdown)

    def test_verified_rows_preserve_source_facts_and_counter_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _write_report_fixture(root)

            report = build_world_baseline_report(root, generated_at_utc=GENERATED_AT)
            row = report["claims"][0]
            markdown = render_world_baseline_markdown(report)

            self.assertEqual(row["source_fact"], ["Support fact."])
            self.assertEqual([item["evidence_id"] for item in row["counter_evidence"]], ["counter"])
            self.assertIn("Support fact.", markdown)
            conflicts = markdown.split("## 冲突与未知", 1)[1].split("## 当前实现映射", 1)[0]
            self.assertIn("counter", conflicts)
            self.assertIn("fixture:counter@30:43", conflicts)

    def test_structurally_valid_but_misaligned_evidence_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _write_report_fixture(root, support_quote="Tampered fact.")

            with self.assertRaisesRegex(
                ValueError,
                "invalid baseline evidence support: quote does not match declared decoded-character range",
            ):
                build_world_baseline_report(root, generated_at_utc=GENERATED_AT)

    def test_tampered_source_is_rejected_by_manifest_hash(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source_path = _write_report_fixture(root)
            source_path.write_text("Tampered source.\n", encoding="utf-8")

            with self.assertRaisesRegex(ValueError, "source hash mismatch for fixture"):
                build_world_baseline_report(root, generated_at_utc=GENERATED_AT)

    def test_repeated_outputs_are_byte_identical(self) -> None:
        first = build_world_baseline_report(ROOT, generated_at_utc=GENERATED_AT)
        second = build_world_baseline_report(ROOT, generated_at_utc=GENERATED_AT)

        with tempfile.TemporaryDirectory() as tmp:
            first_json, first_md = write_world_baseline_outputs(first, Path(tmp) / "first")
            second_json, second_md = write_world_baseline_outputs(second, Path(tmp) / "second")
            self.assertEqual(first_json.read_bytes(), second_json.read_bytes())
            self.assertEqual(first_md.read_bytes(), second_md.read_bytes())
            self.assertEqual(json.loads(first_json.read_text(encoding="utf-8")), first)

    def test_timestamp_must_be_explicit_canonical_utc(self) -> None:
        for timestamp in ("", "2026-09-16", "2026-09-16T00:00:00+00:00", "2026-09-16T00:00:00.000Z"):
            with self.subTest(timestamp=timestamp):
                with self.assertRaisesRegex(ValueError, "YYYY-MM-DDTHH:MM:SSZ"):
                    build_world_baseline_report(ROOT, generated_at_utc=timestamp)


if __name__ == "__main__":
    unittest.main()
