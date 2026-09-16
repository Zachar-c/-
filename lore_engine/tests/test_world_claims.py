from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from jsonschema import Draft202012Validator

from lore_engine.src.contracts import EvidenceRef, ImplementationFinding, WorldClaim, WorldDecision
from lore_engine.src.world_claims import (
    load_jsonl,
    validate_record_schema,
    validate_claim_set,
    validate_status_transition,
)


ROOT = Path(__file__).parents[2]
CONFIG_PATH = ROOT / "lore_engine" / "config" / "world-model-stage0.json"
BENCHMARK_PATH = (
    ROOT / "lore_sources" / "benchmarks" / "world_model_stage0" / "claims.jsonl"
)
MANIFEST_PATH = ROOT / "lore_sources" / "manifest.json"
INVALID_FIXTURE_PATH = Path(__file__).parent / "fixtures" / "world_model" / "invalid_claim.json"


ALLOWED_STATUSES = {"candidate", "canonical", "derived", "adaptation", "rejected", "deferred"}
PROVISIONAL_STATUSES = {"candidate", "deferred"}
P0_SOURCE_IDS = {"gu_zhenren_main", "ren_zu_zhuan"}
FORBIDDEN_PRODUCTION_PREFIXES = ("data/", "scripts/", "scenes/")


def validate_benchmark_record(record: dict[str, object], *, p0_claim: bool = False) -> None:
    status = record.get("status")
    if status not in ALLOWED_STATUSES:
        raise ValueError("invented status")
    source_ids = record.get("source_ids")
    evidence_ids = record.get("evidence_ids")
    if not isinstance(source_ids, list) or not isinstance(evidence_ids, list):
        raise ValueError("missing source/evidence reference")
    if not source_ids or not evidence_ids:
        raise ValueError("missing source/evidence reference")
    if p0_claim and not P0_SOURCE_IDS.intersection(source_ids):
        raise ValueError("P0 claim requires a source citation")
    action = record.get("implementation_action", "")
    if any(str(action).replace("\\", "/").startswith(prefix) for prefix in FORBIDDEN_PRODUCTION_PREFIXES):
        raise ValueError("implementation action edits production path")


class WorldClaimsContractTests(unittest.TestCase):
    def test_stage0_config_freezes_24_unique_high_impact_claims_and_boundary(self) -> None:
        config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        claim_ids = config["high_impact_claim_ids"]

        self.assertEqual(len(claim_ids), 24)
        self.assertEqual(len(set(claim_ids)), 24)
        self.assertEqual(config["minimum_claims"], 20)
        self.assertEqual(
            config["pre_stage0_baseline_commit"],
            "b2aeb2e5cb854cb2ee2cea12647cd6fadd46aa7d",
        )
        self.assertEqual(set(config["p0_source_ids"]), P0_SOURCE_IDS)
        self.assertNotIn("data/", config["read_allowlist"])
        self.assertNotIn("scripts/", config["read_allowlist"])
        self.assertNotIn("scenes/", config["read_allowlist"])
        self.assertEqual(
            set(config["production_write_denylist"]),
            set(FORBIDDEN_PRODUCTION_PREFIXES),
        )

    def test_read_allowlist_covers_every_manifest_source_path(self) -> None:
        config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        allowlist = tuple(path.replace("\\", "/") for path in config["read_allowlist"])

        for source in manifest:
            source_path = source["path"].replace("\\", "/")
            self.assertTrue(
                any(source_path == allowed or source_path.startswith(allowed) for allowed in allowlist),
                f"manifest source is outside Stage 0 read allowlist: {source_path}",
            )

    def test_benchmark_rows_are_provisional_and_have_target_topics(self) -> None:
        config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        rows = [json.loads(line) for line in BENCHMARK_PATH.read_text(encoding="utf-8").splitlines()]
        self.assertEqual({row["claim_id"] for row in rows}, set(config["high_impact_claim_ids"]))
        self.assertTrue(all(row["status"] in PROVISIONAL_STATUSES for row in rows))
        self.assertGreaterEqual(sum(bool(row["source_ids"] and row["evidence_ids"]) or row["status"] == "deferred" for row in rows), 20)

    def test_real_benchmark_claims_load_without_malformed_records(self) -> None:
        loaded = load_jsonl((BENCHMARK_PATH,), "claim")

        self.assertEqual(len(loaded.records), 24)
        self.assertEqual(loaded.errors, ())
        self.assertTrue(all(claim.status == "deferred" for claim in loaded.records))
        self.assertTrue(all(claim.source_ids == () for claim in loaded.records))
        self.assertTrue(all(claim.evidence_ids == () for claim in loaded.records))
        self.assertTrue(all(claim.counter_evidence_ids == () for claim in loaded.records))
        self.assertTrue(all(claim.confidence == "unknown" for claim in loaded.records))

    def test_invalid_benchmark_records_are_rejected(self) -> None:
        cases = json.loads(INVALID_FIXTURE_PATH.read_text(encoding="utf-8"))["cases"]
        for case in cases:
            with self.subTest(case=case["name"]):
                with self.assertRaises(ValueError):
                    validate_benchmark_record(case["record"], p0_claim=case.get("p0_claim", False))

    def test_valid_claim_evidence_and_decision_records_are_frozen_contracts(self) -> None:
        claim = WorldClaim(
            "c1", "gu_is_life", "A gu is living.", "candidate", "high",
            ("gu_zhenren_main",), ("e1",), (), "unknown",
        )
        evidence = EvidenceRef("e1", "gu_zhenren_main", "v1:c1", 0, 5, "quote", "primary_text", "support")
        decision = WorldDecision("c1", "defer", "needs verification", "no change", "defer", ())
        self.assertEqual(validate_claim_set((claim, evidence, decision), {
            "minimum_claims": 1, "high_impact_claim_ids": ["gu_is_life"],
            "p0_source_ids": ["gu_zhenren_main"],
        }).errors, ())
        with self.assertRaises(AttributeError):
            claim.status = "canonical"

    def test_duplicate_ids_invalid_enums_and_missing_topics_are_structured_errors(self) -> None:
        claim = WorldClaim("c1", "gu_is_life", "x", "settled", "high", (), ("missing",), (), "unknown")
        result = validate_claim_set((claim, claim), {
            "minimum_claims": 20, "high_impact_claim_ids": ["gu_is_life", "aptitude_capacity"],
            "p0_source_ids": ["gu_zhenren_main"],
        })
        codes = {error.code for error in result.errors}
        self.assertIn("duplicate_id", codes)
        self.assertIn("invalid_enum", codes)
        self.assertIn("missing_high_impact_topic", codes)
        self.assertIn("minimum_claims", codes)

    def test_canonical_requires_p0_evidence_and_references_must_exist(self) -> None:
        claim = WorldClaim("c1", "gu_is_life", "x", "canonical", "high", ("secondary",), ("e1",), (), "high")
        evidence = EvidenceRef("e1", "secondary", "ref", 0, 1, "x", "secondary_note", "support")
        result = validate_claim_set((claim, evidence), {
            "minimum_claims": 1, "high_impact_claim_ids": ["gu_is_life"],
            "p0_source_ids": ["gu_zhenren_main"],
        })
        self.assertIn("canonical_requires_p0_evidence", {error.code for error in result.errors})
        missing = validate_claim_set((WorldClaim("c2", "gu_is_life", "x", "candidate", "high", (), ("nope",), (), "unknown"),), {
            "minimum_claims": 1, "high_impact_claim_ids": ["gu_is_life"], "p0_source_ids": [],
        })
        self.assertIn("missing_evidence_reference", {error.code for error in missing.errors})

    def test_claim_sources_and_evidence_authority_must_match_asserted_status(self) -> None:
        claim = WorldClaim("c1", "gu_is_life", "x", "canonical", "high", ("gu_zhenren_main",), ("e1",), (), "high")
        evidence = EvidenceRef("e1", "secondary", "ref", 0, 1, "x", "secondary_note", "unknown")
        result = validate_claim_set((claim, evidence), {
            "minimum_claims": 1, "high_impact_claim_ids": ["gu_is_life"],
            "p0_source_ids": ["gu_zhenren_main"],
        })
        codes = {error.code for error in result.errors}
        self.assertIn("evidence_source_mismatch", codes)
        self.assertIn("authority_status_mismatch", codes)

    def test_status_transition_requires_explicit_decision_to_leave_canonical(self) -> None:
        self.assertTrue(validate_status_transition("candidate", "canonical").ok)
        self.assertFalse(validate_status_transition("canonical", "derived").ok)
        self.assertTrue(validate_status_transition("canonical", "derived", explicit_decision=True).ok)
        self.assertFalse(validate_status_transition("rejected", "candidate", explicit_decision=True).ok)

    def test_jsonl_loader_orders_paths_and_lines_and_keeps_malformed_rows(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "b.jsonl").write_text('{"claim_id":"b","topic":"b","statement":"b","status":"deferred","impact":"low","source_ids":[],"evidence_ids":[],"counter_evidence_ids":[],"confidence":"unknown"}\n{bad}\n', encoding="utf-8")
            (root / "a.jsonl").write_text('{"claim_id":"a","topic":"a","statement":"a","status":"deferred","impact":"low","source_ids":[],"evidence_ids":[],"counter_evidence_ids":[],"confidence":"unknown"}\n', encoding="utf-8")
            loaded = load_jsonl((root / "b.jsonl", root / "a.jsonl"), "claim")
        self.assertEqual([record.claim_id for record in loaded.records], ["a", "b"])
        self.assertEqual([(error.file, error.line) for error in loaded.errors], [(str(root / "b.jsonl"), 2)])

    def test_jsonl_loader_rejects_empty_required_fields_and_extra_properties(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "claims.jsonl"
            base = {"claim_id":"c1","topic":"topic","statement":"statement","status":"deferred","impact":"low","source_ids":[],"evidence_ids":[],"counter_evidence_ids":[],"confidence":"unknown"}
            empty = dict(base, statement="")
            extra = dict(base, unexpected="no")
            path.write_text("\n".join(json.dumps(row) for row in (empty, extra)), encoding="utf-8")
            loaded = load_jsonl((path,), "claim")
        self.assertEqual(loaded.records, ())
        self.assertEqual([error.line for error in loaded.errors], [1, 2])

    def test_jsonl_loader_rejects_invalid_finding_enums(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "findings.jsonl"
            path.write_text(json.dumps({
                "finding_id":"f1", "claim_id":"c1", "path":"x", "locator":"l", "observed":"o",
                "source_layer":"unknown", "behavior_status":"aligned", "migration_action":"retain",
            }), encoding="utf-8")
            loaded = load_jsonl((path,), "finding")
        self.assertEqual(loaded.records, ())
        self.assertEqual(loaded.errors[0].code, "malformed_record")

    def test_cross_type_duplicate_ids_are_rejected(self) -> None:
        claim = WorldClaim("same", "topic", "x", "deferred", "low", (), (), (), "unknown")
        evidence = EvidenceRef("same", "source", "ref", 0, 1, "x", "primary_text", "support")
        finding = ImplementationFinding("same", "same", "path", "loc", "observed", "data", "aligned", "retain")
        result = validate_claim_set((claim, evidence, finding), {"minimum_claims": 1, "high_impact_claim_ids": [], "p0_source_ids": []})
        self.assertEqual(sum(error.code == "duplicate_id" for error in result.errors), 2)

    def test_status_transition_requires_and_accepts_linked_decision(self) -> None:
        claim = WorldClaim("c1", "topic", "x", "derived", "low", (), (), (), "unknown")
        unauthorized = validate_claim_set((claim,), {"minimum_claims": 1, "high_impact_claim_ids": [], "p0_source_ids": []})
        self.assertIn("unauthorized_status_transition", {error.code for error in unauthorized.errors})
        decision = WorldDecision("c1", "revise", "r", "p", "a", (), "canonical")
        authorized = validate_claim_set((claim, decision), {"minimum_claims": 1, "high_impact_claim_ids": [], "p0_source_ids": []})
        self.assertNotIn("unauthorized_status_transition", {error.code for error in authorized.errors})
        wrong_ruling = validate_claim_set((claim, WorldDecision("c1", "retain", "r", "p", "a", (), "canonical")), {"minimum_claims": 1, "high_impact_claim_ids": [], "p0_source_ids": []})
        self.assertIn("decision_status_mismatch", {error.code for error in wrong_ruling.errors})
        missing_previous = validate_claim_set((claim, WorldDecision("c1", "revise", "r", "p", "a", ())), {"minimum_claims": 1, "high_impact_claim_ids": [], "p0_source_ids": []})
        self.assertIn("missing_previous_status", {error.code for error in missing_previous.errors})

    def test_candidate_can_become_canonical_without_decision_when_p0_supported(self) -> None:
        claim = WorldClaim("c1", "topic", "x", "canonical", "high", ("p0",), ("e1",), (), "high")
        evidence = EvidenceRef("e1", "p0", "ref", 0, 1, "x", "primary_text", "support")
        result = validate_claim_set((claim, evidence), {
            "minimum_claims": 1, "high_impact_claim_ids": [], "p0_source_ids": ["p0"],
        })
        self.assertNotIn("unauthorized_status_transition", {error.code for error in result.errors})

    def test_canonical_cannot_become_derived_without_decision(self) -> None:
        claim = WorldClaim("c1", "topic", "x", "derived", "low", (), (), (), "unknown")
        result = validate_claim_set((claim,), {
            "minimum_claims": 1, "high_impact_claim_ids": [], "p0_source_ids": [],
        })
        self.assertIn("unauthorized_status_transition", {error.code for error in result.errors})

    def test_schema_requires_non_empty_id_array_items(self) -> None:
        schema = json.loads((ROOT / "lore_engine" / "schemas" / "world-claim-v1.json").read_text(encoding="utf-8"))
        claim = schema["$defs"]["claim"]["properties"]
        for field in ("source_ids", "evidence_ids", "counter_evidence_ids"):
            self.assertEqual(claim[field]["items"]["minLength"], 1)
        notes = schema["$defs"]["decision"]["properties"]["non_regression_notes"]
        self.assertEqual(notes["items"]["minLength"], 1)

    def test_loader_rejects_negative_char_start(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "evidence.jsonl"
            path.write_text(json.dumps({
                "evidence_id":"e1", "source_file_id":"source", "source_ref":"ref", "char_start":-1,
                "char_end":1, "quote":"x", "authority":"primary_text", "evidence_kind":"support",
            }), encoding="utf-8")
            loaded = load_jsonl((path,), "evidence")
        self.assertEqual(loaded.records, ())
        self.assertEqual(loaded.errors[0].code, "malformed_record")

    def test_schema_and_runtime_reject_invalid_evidence_ordering(self) -> None:
        schema = json.loads((ROOT / "lore_engine" / "schemas" / "world-claim-v1.json").read_text(encoding="utf-8"))
        evidence = {
            "evidence_id": "e1", "source_file_id": "source", "source_ref": "ref",
            "char_start": 5, "char_end": 1, "quote": "x",
            "authority": "primary_text", "evidence_kind": "support",
        }

        self.assertTrue(validate_record_schema(evidence, "evidence"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "evidence.jsonl"
            path.write_text(json.dumps(evidence), encoding="utf-8")
            loaded = load_jsonl((path,), "evidence")
        self.assertEqual(loaded.records, ())
        self.assertEqual(loaded.errors[0].code, "malformed_record")

    def test_schema_and_runtime_reject_every_non_increasing_evidence_range(self) -> None:
        schema = json.loads((ROOT / "lore_engine" / "schemas" / "world-claim-v1.json").read_text(encoding="utf-8"))
        self.assertEqual(
            schema["$defs"]["evidence"]["x-repository-constraints"],
            ["char_end_gt_char_start"],
        )
        for start, end in ((0, 0), (1, 0), (5, 1), (10, 9), (99, 99)):
            with self.subTest(start=start, end=end):
                evidence = {
                    "evidence_id": "e1", "source_file_id": "source", "source_ref": "ref",
                    "char_start": start, "char_end": end, "quote": "x",
                    "authority": "primary_text", "evidence_kind": "support",
                }
                self.assertTrue(validate_record_schema(evidence, "evidence"))
                with tempfile.TemporaryDirectory() as directory:
                    path = Path(directory) / "evidence.jsonl"
                    path.write_text(json.dumps(evidence), encoding="utf-8")
                    loaded = load_jsonl((path,), "evidence")
                self.assertEqual(loaded.records, ())
                self.assertEqual(loaded.errors[0].code, "malformed_record")

    def test_unknown_stage0_evidence_placeholders_load_without_being_verified(self) -> None:
        evidence_path = ROOT / "lore_sources" / "benchmarks" / "world_model_stage0" / "evidence.jsonl"
        loaded = load_jsonl((evidence_path,), "evidence")
        self.assertEqual(loaded.errors, ())
        self.assertEqual([item.evidence_kind for item in loaded.records], ["unknown", "unknown"])
        self.assertEqual([(item.char_start, item.char_end, item.quote) for item in loaded.records], [(-1, -1, ""), (-1, -1, "")])
        claim = WorldClaim("c1", "topic", "x", "canonical", "high", ("gu_zhenren_main",), ("stage0_pending_main_text",), (), "high")
        result = validate_claim_set(tuple(loaded.records) + (claim,), {"minimum_claims": 1, "high_impact_claim_ids": [], "p0_source_ids": ["gu_zhenren_main"]})
        codes = {error.code for error in result.errors}
        self.assertIn("authority_status_mismatch", codes)
        self.assertIn("canonical_requires_p0_evidence", codes)

    def test_counter_evidence_must_match_claim_source_ids(self) -> None:
        claim = WorldClaim("c1", "topic", "x", "candidate", "low", ("primary",), (), ("e1",), "unknown")
        evidence = EvidenceRef("e1", "secondary", "ref", 0, 1, "x", "secondary_note", "counterexample")
        result = validate_claim_set((claim, evidence), {"minimum_claims": 1, "high_impact_claim_ids": [], "p0_source_ids": []})
        self.assertIn("evidence_source_mismatch", {error.code for error in result.errors})

    def test_canonical_snapshot_context_distinguishes_initial_promotion_and_retention(self) -> None:
        evidence = EvidenceRef("e1", "p0", "ref", 0, 1, "x", "primary_text", "support")
        initial = WorldClaim("c1", "topic", "x", "canonical", "high", ("p0",), ("e1",), (), "high", "candidate")
        self.assertNotIn("unauthorized_status_transition", {e.code for e in validate_claim_set((initial, evidence), {"minimum_claims": 1, "high_impact_claim_ids": [], "p0_source_ids": ["p0"]}).errors})
        retained = WorldClaim("c2", "topic", "x", "canonical", "high", ("p0",), ("e1",), (), "high", "canonical")
        retained_result = validate_claim_set((retained, evidence), {"minimum_claims": 1, "high_impact_claim_ids": [], "p0_source_ids": ["p0"]})
        self.assertIn("unauthorized_status_transition", {e.code for e in retained_result.errors})
        retention = WorldDecision("c2", "retain", "r", "p", "a", (), "canonical")
        self.assertNotIn("invalid_status_transition", {e.code for e in validate_claim_set((retained, evidence, retention), {"minimum_claims": 1, "high_impact_claim_ids": [], "p0_source_ids": ["p0"]}).errors})
        repromoted = WorldClaim("c3", "topic", "x", "canonical", "high", ("p0",), ("e1",), (), "high", "rejected")
        self.assertIn("invalid_status_transition", {e.code for e in validate_claim_set((repromoted, evidence), {"minimum_claims": 1, "high_impact_claim_ids": [], "p0_source_ids": ["p0"]}).errors})

    def test_terminal_and_incompatible_snapshot_transitions_are_rejected(self) -> None:
        claim = WorldClaim("c1", "topic", "x", "deferred", "low", (), (), (), "unknown", "rejected")
        result = validate_claim_set((claim,), {"minimum_claims": 1, "high_impact_claim_ids": [], "p0_source_ids": []})
        self.assertIn("invalid_status_transition", {e.code for e in result.errors})

    def test_validate_record_schema_covers_all_record_kinds(self) -> None:
        valid = {
            "claim": {"claim_id":"c1","topic":"t","statement":"s","status":"candidate","impact":"low","source_ids":[],"evidence_ids":[],"counter_evidence_ids":[],"confidence":"unknown"},
            "evidence": {"evidence_id":"e1","source_file_id":"s","source_ref":"r","char_start":0,"char_end":1,"quote":"q","authority":"primary_text","evidence_kind":"support"},
            "finding": {"finding_id":"f1","claim_id":"c1","path":"p","locator":"l","observed":"o","source_layer":"data","behavior_status":"aligned","migration_action":"retain"},
            "decision": {"claim_id":"c1","ruling":"defer","rationale":"r","player_consequence":"p","implementation_action":"a","non_regression_notes":[]},
        }
        for kind, payload in valid.items():
            self.assertEqual(validate_record_schema(payload, kind), (), kind)
            bad = dict(payload)
            bad[next(iter(payload))] = ""
            self.assertTrue(validate_record_schema(bad, kind), kind)
            extra = dict(payload, unexpected=True)
            self.assertTrue(validate_record_schema(extra, kind), kind)

    def test_candidate_and_deferred_decisions_must_match_status(self) -> None:
        candidate = WorldClaim("c1", "topic", "x", "candidate", "low", (), (), (), "unknown")
        deferred = WorldClaim("c2", "topic", "x", "deferred", "low", (), (), (), "unknown")
        wrong_candidate = WorldDecision("c1", "remove", "r", "p", "a", ())
        valid_deferred = WorldDecision("c2", "defer", "r", "p", "a", (), "candidate")
        result = validate_claim_set((candidate, deferred, wrong_candidate, valid_deferred), {"minimum_claims": 2, "high_impact_claim_ids": [], "p0_source_ids": []})
        codes = {e.code for e in result.errors}
        self.assertIn("decision_status_mismatch", codes)
        self.assertNotIn("missing_previous_status", codes)

    def test_duplicate_decisions_are_rejected_without_overwriting(self) -> None:
        claim = WorldClaim("c1", "topic", "x", "deferred", "low", (), (), (), "unknown")
        first = WorldDecision("c1", "defer", "r", "p", "a", ())
        second = WorldDecision("c1", "remove", "r", "p", "a", ())
        result = validate_claim_set((claim, first, second), {"minimum_claims": 1, "high_impact_claim_ids": [], "p0_source_ids": []})
        self.assertIn("duplicate_decision", {e.code for e in result.errors})
        self.assertIn("decision_status_mismatch", {e.code for e in result.errors})

    def test_claim_and_decision_previous_status_must_match(self) -> None:
        claim = WorldClaim("c1", "topic", "x", "derived", "low", (), (), (), "unknown", "canonical")
        decision = WorldDecision("c1", "revise", "r", "p", "a", (), "candidate")

        result = validate_claim_set((claim, decision), {"minimum_claims": 1, "high_impact_claim_ids": [], "p0_source_ids": []})

        self.assertEqual(
            [(error.code, error.message) for error in result.errors if error.code == "previous_status_mismatch"],
            [("previous_status_mismatch", "claim c1 previous_status canonical does not match decision candidate")],
        )

    def test_matching_claim_and_decision_previous_status_is_valid(self) -> None:
        claim = WorldClaim("c1", "topic", "x", "derived", "low", (), (), (), "unknown", "canonical")
        decision = WorldDecision("c1", "revise", "r", "p", "a", (), "canonical")

        result = validate_claim_set((claim, decision), {"minimum_claims": 1, "high_impact_claim_ids": [], "p0_source_ids": []})

        self.assertNotIn("previous_status_mismatch", {error.code for error in result.errors})

    def test_preliminary_decision_is_valid_input_but_not_transition_authority(self) -> None:
        deferred = WorldClaim("c1", "topic", "x", "deferred", "high", (), (), (), "unknown")
        hypothesis = WorldDecision("c1", "remove", "r", "p", "a", (), None, "preliminary")

        deferred_result = validate_claim_set(
            (deferred, hypothesis),
            {"minimum_claims": 1, "high_impact_claim_ids": [], "p0_source_ids": []},
        )

        self.assertEqual(deferred_result.errors, ())
        canonical = WorldClaim("c1", "topic", "x", "canonical", "high", (), (), (), "unknown", "canonical")
        canonical_result = validate_claim_set(
            (canonical, hypothesis),
            {"minimum_claims": 1, "high_impact_claim_ids": [], "p0_source_ids": []},
        )
        self.assertIn("unauthorized_status_transition", {error.code for error in canonical_result.errors})

    def test_orphan_implementation_finding_is_rejected(self) -> None:
        claim = WorldClaim("c1", "topic", "x", "deferred", "high", (), (), (), "unknown")
        orphan = ImplementationFinding(
            "f1", "missing", "data/gu.json", "/x", "observation",
            "data", "unknown", "defer",
        )

        result = validate_claim_set(
            (claim, orphan),
            {"minimum_claims": 1, "high_impact_claim_ids": [], "p0_source_ids": []},
        )

        self.assertEqual(
            [(error.code, error.message) for error in result.errors],
            [("missing_claim_reference", "finding f1 references unknown claim missing")],
        )

    def test_decision_kind_is_optional_final_and_closed_when_present(self) -> None:
        base = {
            "claim_id":"c1", "ruling":"defer", "rationale":"r", "player_consequence":"p",
            "implementation_action":"a", "non_regression_notes":[],
        }
        self.assertEqual(validate_record_schema(base, "decision"), ())
        self.assertEqual(validate_record_schema(dict(base, decision_kind="preliminary"), "decision"), ())
        self.assertTrue(validate_record_schema(dict(base, decision_kind="draft"), "decision"))


if __name__ == "__main__":
    unittest.main()
