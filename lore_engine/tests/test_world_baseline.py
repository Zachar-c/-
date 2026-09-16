from __future__ import annotations

import unittest
from pathlib import Path

from lore_engine.src.contracts import EvidenceRef, ImplementationFinding, WorldClaim, WorldDecision
from lore_engine.src.implementation_audit import audit_current_implementation
from lore_engine.src.world_baseline import LEGACY_DISPOSITIONS, adjudicate_baseline
from lore_engine.src.world_claims import load_jsonl, validate_claim_set


ROOT = Path(__file__).resolve().parents[2]
DECISIONS_PATH = ROOT / "lore_sources" / "benchmarks" / "world_model_stage0" / "decisions.jsonl"
CLAIMS_PATH = ROOT / "lore_sources" / "benchmarks" / "world_model_stage0" / "claims.jsonl"
EVIDENCE_PATH = ROOT / "lore_sources" / "benchmarks" / "world_model_stage0" / "evidence.jsonl"
CONFIG_PATH = ROOT / "lore_engine" / "config" / "world-model-stage0.json"


def claim(
    *,
    status: str = "deferred",
    evidence_ids: tuple[str, ...] = (),
    counter_ids: tuple[str, ...] = (),
    previous_status: str | None = None,
) -> WorldClaim:
    return WorldClaim(
        "c1",
        "topic",
        "A scoped world claim.",
        status,
        "high",
        ("gu_zhenren_main",),
        evidence_ids,
        counter_ids,
        "high" if evidence_ids else "unknown",
        previous_status,
    )


def decision(
    ruling: str,
    *,
    consequence: str = "Players can predict the visible cost before acting.",
    action: str = "Keep the old rule audit-only until migration is approved.",
    notes: tuple[str, ...] = (),
    rationale: str = "A preliminary human ruling.",
    decision_kind: str = "preliminary",
    previous_status: str | None = None,
) -> WorldDecision:
    return WorldDecision(
        "c1", ruling, rationale, consequence, action, notes,
        previous_status, decision_kind,
    )


def evidence(
    evidence_id: str,
    kind: str,
    quote: str,
    source_file_id: str = "gu_zhenren_main",
) -> EvidenceRef:
    return EvidenceRef(
        evidence_id,
        source_file_id,
        f"chapter:{evidence_id}",
        0,
        len(quote),
        quote,
        "primary_text",
        kind,
    )


class WorldBaselineTests(unittest.TestCase):
    def test_q8g_f1_and_promotion_mechanics_are_never_production_ready(self) -> None:
        expected = {
            "q8g_promotion_chain",
            "f1_pity",
            "school_promotion",
            "promotion_materials",
            "promotion_economy",
        }

        self.assertEqual({item.mechanic_id for item in LEGACY_DISPOSITIONS}, expected)
        self.assertTrue(all(item.disposition in {"audit_only", "defer"} for item in LEGACY_DISPOSITIONS))
        self.assertNotIn("production_ready", {item.disposition for item in LEGACY_DISPOSITIONS})

    def test_unresolved_source_claim_remains_needs_evidence(self) -> None:
        result = adjudicate_baseline((claim(),), (), (), (decision("retain"),))

        self.assertEqual(result.rows[0].preliminary_ruling, "retain")
        self.assertEqual(result.rows[0].effective_ruling, "needs_evidence")
        self.assertIn("verified P0 support", " ".join(result.rows[0].unknowns))
        self.assertEqual(result.gate_result, "NO_GO")

    def test_preliminary_decision_never_authorizes_even_verified_support(self) -> None:
        support = evidence("support", "support", "A verified source statement.")

        result = adjudicate_baseline(
            (claim(evidence_ids=("support",)),),
            (support,),
            (),
            (decision("retain", decision_kind="preliminary"),),
        )

        self.assertEqual(result.rows[0].preliminary_ruling, "retain")
        self.assertEqual(result.rows[0].effective_ruling, "needs_evidence")
        self.assertEqual(result.gate_result, "NO_GO")

    def test_final_label_without_valid_status_transition_does_not_authorize(self) -> None:
        support = evidence("support", "support", "A verified source statement.")

        result = adjudicate_baseline(
            (claim(evidence_ids=("support",)),),
            (support,),
            (),
            (decision("retain", decision_kind="final"),),
        )

        self.assertEqual(result.rows[0].final_ruling, "retain")
        self.assertEqual(result.rows[0].effective_ruling, "needs_evidence")
        self.assertIn("finalized claim-status transition", " ".join(result.rows[0].unknowns))

    def test_partial_implementation_is_not_automatically_retained(self) -> None:
        finding = ImplementationFinding(
            "f1", "c1", "data/gu.json", "/gu", "Only part of the behavior exists.",
            "data", "partial", "retain",
        )

        result = adjudicate_baseline((claim(),), (), (finding,), (decision("needs_evidence"),))

        self.assertEqual(result.rows[0].effective_ruling, "needs_evidence")
        self.assertNotEqual(result.rows[0].effective_ruling, finding.migration_action)
        self.assertIn("partial", result.rows[0].current_implementation[0])

    def test_removed_rule_requires_a_migration_or_deprecation_note(self) -> None:
        support = evidence("support", "support", "A verified source statement.")
        removed = decision("remove", action="", notes=())

        with self.assertRaisesRegex(ValueError, "migration/deprecation"):
            adjudicate_baseline((claim(evidence_ids=("support",)),), (support,), (), (removed,))

    def test_game_adaptation_requires_an_explicit_player_consequence(self) -> None:
        support = evidence("support", "support", "A verified source statement.")
        adaptation = decision("revise", consequence="")

        with self.assertRaisesRegex(ValueError, "player-facing consequence"):
            adjudicate_baseline(
                (claim(status="adaptation", evidence_ids=("support",)),),
                (support,),
                (),
                (adaptation,),
            )

    def test_complete_rows_join_all_four_layers_and_are_stable(self) -> None:
        support = evidence("support", "support", "A verified source statement.")
        finding = ImplementationFinding(
            "f1", "c1", "scripts/domain/rule.gd", "line:7", "Current rule observation.",
            "domain", "aligned", "retain",
        )
        args = (
            (claim(status="canonical", evidence_ids=("support",), previous_status="candidate"),),
            (support,),
            (finding,),
            (decision("retain", decision_kind="final", previous_status="candidate"),),
        )

        first = adjudicate_baseline(*args)
        second = adjudicate_baseline(*(tuple(reversed(part)) for part in args))

        self.assertEqual(first, second)
        row = first.rows[0]
        self.assertEqual(row.source_fact, ("A verified source statement.",))
        self.assertEqual(row.derivation, "A preliminary human ruling.")
        self.assertEqual(row.world_model_ruling, "A scoped world claim.")
        self.assertIsNone(row.preliminary_ruling)
        self.assertEqual(row.final_ruling, "retain")
        self.assertEqual(row.effective_ruling, "retain")
        self.assertEqual(row.support_evidence[0].evidence_id, "support")
        self.assertEqual(row.current_findings[0].finding_id, "f1")
        self.assertTrue(row.current_implementation)
        self.assertTrue(row.player_consequence)
        self.assertTrue(row.migration_deprecation_action)
        self.assertEqual(row.confidence, "high")
        self.assertEqual(row.counter_evidence, ())
        self.assertEqual(row.unknowns, ())

    def test_unresolved_p0_contradiction_forces_needs_evidence_and_no_go(self) -> None:
        support = evidence("support", "support", "The rule applies.")
        counter = evidence("counter", "counterexample", "The rule does not apply here.")

        result = adjudicate_baseline(
            (claim(evidence_ids=("support",), counter_ids=("counter",)),),
            (support, counter),
            (),
            (decision("retain"),),
        )

        self.assertEqual(result.rows[0].effective_ruling, "needs_evidence")
        self.assertEqual(result.gate_result, "NO_GO")
        self.assertIn("c1", result.gate_blockers)

    def test_finalized_support_with_unresolved_counterexample_forces_no_go(self) -> None:
        support = evidence("support", "support", "The rule applies.")
        unresolved_counter = EvidenceRef(
            "counter", "gu_zhenren_main", "pending-counter", -1, -1, "",
            "primary_text", "unknown",
        )

        result = adjudicate_baseline(
            (claim(status="canonical", evidence_ids=("support",), counter_ids=("counter",), previous_status="candidate"),),
            (support, unresolved_counter),
            (),
            (decision("retain", decision_kind="final", previous_status="candidate"),),
        )

        row = result.rows[0]
        self.assertEqual(row.final_ruling, "retain")
        self.assertEqual(row.effective_ruling, "needs_evidence")
        self.assertIn("unresolved evidence: counter", row.unknowns)
        self.assertEqual(result.gate_result, "NO_GO")

    def test_condition_without_explicit_scope_rationale_does_not_resolve_conflict(self) -> None:
        support = evidence("support", "support", "The rule applies.")
        condition = evidence("condition", "condition", "The rule applies only under this condition.")
        counter = evidence("counter", "counterexample", "Outside that condition it does not apply.")

        result = adjudicate_baseline(
            (claim(status="canonical", evidence_ids=("support", "condition"), counter_ids=("counter",), previous_status="candidate"),),
            (support, condition, counter),
            (),
            (decision("retain", decision_kind="final", previous_status="candidate"),),
        )

        self.assertEqual(result.rows[0].effective_ruling, "needs_evidence")
        self.assertEqual(result.gate_result, "NO_GO")
        self.assertEqual(result.rows[0].condition_evidence[0].evidence_id, "condition")
        self.assertEqual(result.rows[0].resolved_condition_evidence, ())
        self.assertEqual(result.rows[0].resolution_status, "unresolved")

    def test_scope_rationale_without_condition_evidence_does_not_resolve_conflict(self) -> None:
        support = evidence("support", "support", "The rule applies.")
        counter = evidence("counter", "counterexample", "The rule does not apply here.")

        result = adjudicate_baseline(
            (claim(status="canonical", evidence_ids=("support",), counter_ids=("counter",), previous_status="candidate"),),
            (support, counter),
            (),
            (decision("retain", rationale="Scope: only the stated case.", decision_kind="final", previous_status="candidate"),),
        )

        self.assertEqual(result.rows[0].effective_ruling, "needs_evidence")
        self.assertEqual(result.gate_result, "NO_GO")

    def test_empty_scope_marker_and_unrelated_condition_do_not_resolve_conflict(self) -> None:
        support = evidence("support", "support", "The rule applies.")
        condition = evidence("condition", "condition", "An unrelated condition.", "ren_zu_zhuan")
        counter = evidence("counter", "counterexample", "The rule does not apply here.")

        for rationale in ("Scope:", "Condition:   ", "Scope: unrelated condition"):
            with self.subTest(rationale=rationale):
                result = adjudicate_baseline(
                    (claim(status="canonical", evidence_ids=("support", "condition"), counter_ids=("counter",), previous_status="candidate"),),
                    (support, condition, counter),
                    (),
                    (decision("retain", rationale=rationale, decision_kind="final", previous_status="candidate"),),
                )
                self.assertEqual(result.rows[0].effective_ruling, "needs_evidence")
                self.assertEqual(result.rows[0].condition_evidence[0].evidence_id, "condition")
                self.assertEqual(result.rows[0].resolved_condition_evidence, ())
                self.assertEqual(result.rows[0].resolution_status, "unresolved")

    def test_verified_context_condition_and_scope_rationale_resolve_conflict(self) -> None:
        support = evidence("support", "support", "The rule applies.")
        condition = evidence("condition", "condition", "The rule applies only under this condition.")
        counter = evidence("counter", "counterexample", "Outside that condition it does not apply.")

        result = adjudicate_baseline(
            (claim(status="canonical", evidence_ids=("support", "condition"), counter_ids=("counter",), previous_status="candidate"),),
            (support, condition, counter),
            (),
            (decision("retain", rationale="Condition: applies only to the stated case.", decision_kind="final", previous_status="candidate"),),
        )

        self.assertEqual(result.rows[0].effective_ruling, "retain")
        self.assertEqual(result.rows[0].condition_evidence[0].evidence_id, "condition")
        self.assertEqual(result.rows[0].resolved_condition_evidence[0].evidence_id, "condition")
        self.assertEqual(result.rows[0].resolution_status, "resolved")
        self.assertEqual(result.gate_result, "GO")

    def test_orphan_implementation_finding_is_a_linkage_error(self) -> None:
        orphan = ImplementationFinding(
            "orphan", "missing", "data/gu.json", "/x", "orphan observation",
            "data", "unknown", "defer",
        )

        with self.assertRaisesRegex(ValueError, "finding references unknown claim: missing"):
            adjudicate_baseline((claim(),), (), (orphan,), (decision("defer"),))

    def test_conditional_go_requires_complete_high_impact_coverage(self) -> None:
        support = evidence("support", "support", "A verified source statement.")
        high = claim(status="canonical", evidence_ids=("support",), previous_status="candidate")
        low = WorldClaim("c2", "topic-2", "A low-impact deferred item.", "deferred", "low", (), (), (), "unknown")
        final = decision("retain", decision_kind="final", previous_status="candidate")
        deferred = WorldDecision("c2", "defer", "Deferred follow-up.", "No current effect.", "Defer it.", (), None, "final")

        result = adjudicate_baseline((high, low), (support,), (), (final, deferred))

        self.assertEqual(result.gate_result, "CONDITIONAL_GO")

    def test_benchmark_finalized_with_complete_p0_coverage(self) -> None:
        import json

        config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        claims = load_jsonl((CLAIMS_PATH,), "claim")
        evidence_records = load_jsonl((EVIDENCE_PATH,), "evidence")
        first = load_jsonl((DECISIONS_PATH,), "decision")
        second = load_jsonl((DECISIONS_PATH,), "decision")

        self.assertEqual(claims.errors + evidence_records.errors + first.errors, ())
        self.assertEqual(first.records, second.records)
        self.assertEqual(len(first.records), 24)
        self.assertTrue(all(item.decision_kind == "final" for item in first.records))
        self.assertEqual(
            {item.ruling for item in first.records},
            {"retain", "revise", "remove"},
        )
        findings = audit_current_implementation(ROOT)
        validation = validate_claim_set(
            claims.records + evidence_records.records + tuple(findings) + first.records,
            config,
        )
        self.assertEqual(validation.errors, ())

        adjudication = adjudicate_baseline(
            claims.records, evidence_records.records, findings, first.records
        )
        self.assertEqual(len(adjudication.rows), 24)
        self.assertEqual(
            {row.effective_ruling for row in adjudication.rows},
            {"retain", "revise", "remove"},
        )
        self.assertTrue(all(row.resolution_status == "not_required" for row in adjudication.rows))
        self.assertEqual(adjudication.gate_result, "GO")
        retained_finding_ids = {
            finding.finding_id
            for row in adjudication.rows
            for finding in row.current_findings
        }
        self.assertEqual(retained_finding_ids, {finding.finding_id for finding in findings})
        self.assertGreater(len(retained_finding_ids), 0)


if __name__ == "__main__":
    unittest.main()
