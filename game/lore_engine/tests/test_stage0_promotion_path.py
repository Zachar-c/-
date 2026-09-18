"""Stage 0 must have a reachable promotion path out of `deferred`.

The Gate blocks while any high-impact claim carries a `defer` / `needs_evidence`
effective ruling, and an effective ruling can only become `retain` / `revise` /
`remove` once `_final_transition_authorized` accepts the claim-status transition.
All 24 Stage 0 claims start life as `deferred`, so if `deferred` has no outgoing
edge the Gate is unsatisfiable no matter how complete the evidence is.

These tests pin the reachability of that path on the real ledger, not on a mock.
"""

from __future__ import annotations

import json
import unittest
from pathlib import Path

from lore_engine.src.contracts import EvidenceRef, WorldClaim, WorldDecision
from lore_engine.src.world_baseline import adjudicate_baseline
from lore_engine.src.world_claims import (
    STATUSES,
    load_jsonl,
    validate_claim_set,
    validate_status_transition,
)

ROOT = Path(__file__).resolve().parents[2]
LEDGER = ROOT / "lore_sources" / "benchmarks" / "world_model_stage0"
CLAIMS_PATH = LEDGER / "claims.jsonl"
DECISIONS_PATH = LEDGER / "decisions.jsonl"
CONFIG_PATH = ROOT / "lore_engine" / "config" / "world-model-stage0.json"

# claim status -> the preliminary ruling that authorises it
PROMOTION_RULING = {
    "canonical": "retain",
    "derived": "revise",
    "adaptation": "revise",
    "rejected": "remove",
}
BLOCKING_RULINGS = {"defer", "needs_evidence"}


def _config() -> dict:
    payload = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    assert isinstance(payload, dict)
    return payload


def _evidence(claim_id: str) -> EvidenceRef:
    return EvidenceRef(
        f"ev_{claim_id}",
        "gu_zhenren_main",
        f"stage0/{claim_id}",
        1,
        5,
        "引文",
        "primary_text",
        "support",
    )


class StatusTransitionTests(unittest.TestCase):
    def test_deferred_can_be_promoted_only_with_an_explicit_decision(self) -> None:
        for target in PROMOTION_RULING:
            with self.subTest(target=target):
                self.assertTrue(
                    validate_status_transition(
                        "deferred", target, explicit_decision=True
                    ).ok
                )

    def test_deferred_is_still_terminal_without_an_explicit_decision(self) -> None:
        for target in STATUSES - {"deferred"}:
            with self.subTest(target=target):
                self.assertFalse(
                    validate_status_transition("deferred", target).ok,
                    f"deferred -> {target} must require an explicit decision",
                )

    def test_deferred_can_stay_deferred_with_an_explicit_decision(self) -> None:
        self.assertTrue(
            validate_status_transition("deferred", "deferred", explicit_decision=True).ok
        )

    def test_promotion_never_reopens_back_into_candidate(self) -> None:
        self.assertFalse(
            validate_status_transition("deferred", "candidate", explicit_decision=True).ok
        )


class RealLedgerPromotionPathTests(unittest.TestCase):
    """The Gate's `unresolved high-impact claims` blocker must be removable."""

    def setUp(self) -> None:
        self.config = _config()
        loaded_claims = load_jsonl((CLAIMS_PATH,), "claim")
        self.assertEqual([], [item.message for item in loaded_claims.errors])
        self.claims = tuple(
            item for item in loaded_claims.records if isinstance(item, WorldClaim)
        )
        loaded_decisions = load_jsonl((DECISIONS_PATH,), "decision")
        self.assertEqual([], [item.message for item in loaded_decisions.errors])
        self.preliminary = {
            item.claim_id: item
            for item in loaded_decisions.records
            if isinstance(item, WorldDecision)
        }

    def test_the_ledger_has_no_remaining_blockers(self) -> None:
        # After the Stage 0 evidence audit, every high-impact claim carries a
        # final ruling backed by verified P0 citations, so none may remain in a
        # blocking (defer / needs_evidence) ruling and none may stay deferred.
        blocked = sorted(
            claim.claim_id
            for claim in self.claims
            if claim.impact == "high"
            and self.preliminary[claim.claim_id].ruling in BLOCKING_RULINGS
        )
        self.assertEqual(0, len(blocked))
        self.assertTrue(
            all(
                self.preliminary[claim.claim_id].decision_kind == "final"
                for claim in self.claims
            )
        )

    def test_every_high_impact_claim_can_leave_the_blocking_ruling(self) -> None:
        promoted_claims: list[WorldClaim] = []
        evidence: list[EvidenceRef] = []
        final_decisions: list[WorldDecision] = []
        for claim in self.claims:
            preliminary = self.preliminary[claim.claim_id]
            status = "rejected" if preliminary.ruling == "remove" else "canonical"
            promoted_claims.append(
                WorldClaim(
                    claim.claim_id,
                    claim.topic,
                    claim.statement,
                    status,
                    claim.impact,
                    ("gu_zhenren_main",),
                    (f"ev_{claim.claim_id}",),
                    (),
                    "high",
                    "deferred",
                )
            )
            evidence.append(_evidence(claim.claim_id))
            final_decisions.append(
                WorldDecision(
                    claim.claim_id,
                    PROMOTION_RULING[status],
                    "Final ruling: the passage states the rule at the quoted span.",
                    preliminary.player_consequence,
                    "Deprecate the superseded hypothesis; migrate nothing in Stage 0.",
                    preliminary.non_regression_notes,
                    "deferred",
                    "final",
                )
            )

        result = validate_claim_set(
            (*promoted_claims, *evidence, *final_decisions), self.config
        )
        self.assertEqual([], [item.message for item in result.errors])

        adjudication = adjudicate_baseline(
            promoted_claims, evidence, (), final_decisions
        )
        still_blocking = sorted(
            row.claim_id
            for row in adjudication.rows
            if row.impact == "high" and row.effective_ruling in BLOCKING_RULINGS
        )
        self.assertEqual([], still_blocking)

    def test_a_final_decision_must_replace_the_preliminary_row(self) -> None:
        """Keeping both rows is rejected, so finalisation is a replacement."""
        claim = WorldClaim(
            "c1", "t", "s", "canonical", "high",
            ("gu_zhenren_main",), ("ev_c1",), (), "high", "deferred",
        )
        preliminary = WorldDecision(
            "c1", "needs_evidence", "Preliminary.", "No change.", "Collect evidence.", (), None, "preliminary"
        )
        final = WorldDecision(
            "c1", "retain", "Final.", "No change.", "Audit only.", (), "deferred", "final"
        )
        result = validate_claim_set(
            (claim, _evidence("c1"), preliminary, final), self.config
        )
        codes = {item.code for item in result.errors}
        self.assertIn("duplicate_decision", codes)
        self.assertFalse(result.ok)


if __name__ == "__main__":
    unittest.main()
