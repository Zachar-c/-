"""Deterministic Stage 0 hypothesis adjudication without production authority."""

from __future__ import annotations

from dataclasses import dataclass
import re
from typing import Iterable, Iterator

from .contracts import EvidenceRef, ImplementationFinding, WorldClaim, WorldDecision
from .world_claims import validate_status_transition


P0_AUTHORITIES = frozenset({"primary_text", "in_world_text"})


@dataclass(frozen=True)
class LegacyDisposition:
    mechanic_id: str
    disposition: str
    rationale: str


LEGACY_DISPOSITIONS = (
    LegacyDisposition(
        "f1_pity",
        "audit_only",
        "F1 Pity is historical implementation context and cannot authorize Stage 0 production behavior.",
    ),
    LegacyDisposition(
        "promotion_economy",
        "defer",
        "Promotion economy remains deferred until source evidence and the later economy slice are adjudicated.",
    ),
    LegacyDisposition(
        "promotion_materials",
        "defer",
        "Promotion materials remain deferred until source evidence and the later refinement slice are adjudicated.",
    ),
    LegacyDisposition(
        "q8g_promotion_chain",
        "audit_only",
        "Q8-G is retained only as an audit trail and is not a production-ready world rule.",
    ),
    LegacyDisposition(
        "school_promotion",
        "defer",
        "School promotion remains deferred while school-as-class semantics are under review.",
    ),
)


@dataclass(frozen=True)
class EvidenceDetail:
    evidence_id: str
    source_file_id: str
    source_ref: str
    char_start: int
    char_end: int
    quote: str
    authority: str
    evidence_kind: str


@dataclass(frozen=True)
class FindingDetail:
    finding_id: str
    path: str
    locator: str
    observed: str
    source_layer: str
    behavior_status: str
    migration_action: str


@dataclass(frozen=True)
class BaselineRow:
    claim_id: str
    topic: str
    impact: str
    support_evidence: tuple[EvidenceDetail, ...]
    source_fact: tuple[str, ...]
    derivation: str
    world_model_ruling: str
    current_findings: tuple[FindingDetail, ...]
    current_implementation: tuple[str, ...]
    decision_kind: str | None
    preliminary_ruling: str | None
    final_ruling: str | None
    effective_ruling: str
    player_consequence: str
    migration_deprecation_action: str
    confidence: str
    condition_evidence: tuple[EvidenceDetail, ...]
    resolved_condition_evidence: tuple[EvidenceDetail, ...]
    resolution_status: str
    counter_evidence_details: tuple[EvidenceDetail, ...]
    counter_evidence: tuple[str, ...]
    unknowns: tuple[str, ...]

    @property
    def proposed_ruling(self) -> str:
        """Compatibility alias; prefer preliminary_ruling/final_ruling."""
        return self.preliminary_ruling or self.final_ruling or "needs_evidence"

    @property
    def ruling(self) -> str:
        """Compatibility alias; the effective ruling is never the raw hypothesis."""
        return self.effective_ruling

    @property
    def migration_action(self) -> str:
        """Compatibility alias for report consumers using the shorter name."""
        return self.migration_deprecation_action


@dataclass(frozen=True)
class BaselineAdjudication:
    rows: tuple[BaselineRow, ...]
    legacy_dispositions: tuple[LegacyDisposition, ...]
    gate_result: str
    gate_blockers: tuple[str, ...]

    def __iter__(self) -> Iterator[BaselineRow]:
        return iter(self.rows)

    def __len__(self) -> int:
        return len(self.rows)

    def __getitem__(self, index: int) -> BaselineRow:
        return self.rows[index]


def _index_unique(records: Iterable[object], attribute: str, label: str) -> dict[str, object]:
    indexed: dict[str, object] = {}
    for record in records:
        key = getattr(record, attribute)
        if key in indexed:
            raise ValueError(f"duplicate {label}: {key}")
        indexed[key] = record
    return indexed


def _verified(item: EvidenceRef) -> bool:
    return (
        item.authority in P0_AUTHORITIES
        and item.evidence_kind != "unknown"
        and item.char_start >= 0
        and item.char_end > item.char_start
        and bool(item.quote.strip())
    )


def _evidence_text(item: EvidenceRef) -> str:
    return item.quote.strip() or f"{item.source_file_id}:{item.source_ref}"


def _evidence_detail(item: EvidenceRef) -> EvidenceDetail:
    return EvidenceDetail(
        item.evidence_id,
        item.source_file_id,
        item.source_ref,
        item.char_start,
        item.char_end,
        item.quote,
        item.authority,
        item.evidence_kind,
    )


def _finding_text(item: ImplementationFinding) -> str:
    return (
        f"{item.path}#{item.locator} [{item.behavior_status}/{item.migration_action}]: "
        f"{item.observed}"
    )


def _finding_detail(item: ImplementationFinding) -> FindingDetail:
    return FindingDetail(
        item.finding_id,
        item.path,
        item.locator,
        item.observed,
        item.source_layer,
        item.behavior_status,
        item.migration_action,
    )


def _migration_text(decision: WorldDecision | None) -> str:
    if decision is None:
        return "No migration is authorized until an adjudication decision exists."
    parts = [decision.implementation_action.strip()]
    parts.extend(note.strip() for note in decision.non_regression_notes if note.strip())
    return " ".join(part for part in parts if part)


def _resolution_conditions(
    support: tuple[EvidenceRef, ...],
    conditions: tuple[EvidenceRef, ...],
    counters: tuple[EvidenceRef, ...],
    decision: WorldDecision | None,
) -> tuple[EvidenceRef, ...]:
    if decision is None or not re.search(
        r"(?i)\b(?:scope|condition)\s*:\s*\S", decision.rationale
    ):
        return ()
    context_sources = (
        {item.source_file_id for item in support}
        & {item.source_file_id for item in counters}
    )
    return tuple(
        item for item in conditions if item.source_file_id in context_sources
    )


def _final_transition_authorized(
    claim: WorldClaim, decision: WorldDecision | None
) -> bool:
    if decision is None or decision.decision_kind != "final":
        return False
    expected = {
        "canonical": "retain",
        "derived": "revise",
        "adaptation": "revise",
        "rejected": "remove",
    }
    if expected.get(claim.status) != decision.ruling:
        return False
    if decision.previous_status is None:
        return False
    if claim.previous_status is not None and claim.previous_status != decision.previous_status:
        return False
    return validate_status_transition(
        decision.previous_status, claim.status, explicit_decision=True
    ).ok


def adjudicate_baseline(
    claims: Iterable[WorldClaim],
    evidence: Iterable[EvidenceRef],
    findings: Iterable[ImplementationFinding],
    decisions: Iterable[WorldDecision],
) -> BaselineAdjudication:
    """Join Stage 0 inputs and apply evidence gates to preliminary rulings.

    Decision rows are hypotheses. A verified P0 source layer is required before
    ``retain``, ``revise``, or ``remove`` can become an effective ruling.
    Implementation findings never supply that authority.
    """
    claim_by_id = _index_unique(tuple(claims), "claim_id", "claim")
    evidence_by_id = _index_unique(tuple(evidence), "evidence_id", "evidence")
    decision_by_id = _index_unique(tuple(decisions), "claim_id", "decision")
    findings_by_claim: dict[str, list[ImplementationFinding]] = {}
    for finding in findings:
        findings_by_claim.setdefault(finding.claim_id, []).append(finding)

    unknown_decisions = sorted(set(decision_by_id) - set(claim_by_id))
    if unknown_decisions:
        raise ValueError(f"decision references unknown claim: {unknown_decisions[0]}")
    unknown_findings = sorted(set(findings_by_claim) - set(claim_by_id))
    if unknown_findings:
        raise ValueError(f"finding references unknown claim: {unknown_findings[0]}")

    rows: list[BaselineRow] = []
    conflict_blockers: list[str] = []
    for claim_id, untyped_claim in sorted(
        claim_by_id.items(), key=lambda item: (item[1].topic, item[0])
    ):
        claim = untyped_claim
        assert isinstance(claim, WorldClaim)
        decision_record = decision_by_id.get(claim_id)
        decision = decision_record if isinstance(decision_record, WorldDecision) else None

        referenced_ids = claim.evidence_ids + claim.counter_evidence_ids
        missing_ids = sorted(evidence_id for evidence_id in referenced_ids if evidence_id not in evidence_by_id)
        referenced = tuple(
            evidence_by_id[evidence_id]
            for evidence_id in referenced_ids
            if evidence_id in evidence_by_id
        )
        typed_evidence = tuple(item for item in referenced if isinstance(item, EvidenceRef))
        source_ids = set(claim.source_ids)
        support = tuple(
            item for item in typed_evidence
            if item.evidence_kind == "support"
            and item.source_file_id in source_ids
            and _verified(item)
        )
        conditions = tuple(
            item for item in typed_evidence
            if item.evidence_kind == "condition"
            and _verified(item)
        )
        counters = tuple(
            item for item in typed_evidence
            if item.evidence_kind == "counterexample"
            and item.source_file_id in source_ids
            and _verified(item)
        )
        unresolved_evidence = sorted(
            item.evidence_id for item in typed_evidence if not _verified(item)
        )
        referenced_counters = tuple(
            evidence_by_id[evidence_id]
            for evidence_id in claim.counter_evidence_ids
            if evidence_id in evidence_by_id
            and isinstance(evidence_by_id[evidence_id], EvidenceRef)
        )
        unresolved_counter_ids = sorted(
            evidence_id
            for evidence_id in claim.counter_evidence_ids
            if evidence_id not in evidence_by_id
            or not isinstance(evidence_by_id[evidence_id], EvidenceRef)
            or not _verified(evidence_by_id[evidence_id])
            or evidence_by_id[evidence_id].evidence_kind != "counterexample"
            or evidence_by_id[evidence_id].source_file_id not in source_ids
        )

        if decision is not None and decision.ruling == "remove" and not _migration_text(decision):
            raise ValueError(f"removed rule {claim_id} requires a migration/deprecation note")
        if decision is not None and not decision.player_consequence.strip():
            raise ValueError(f"game adaptation {claim_id} requires an explicit player-facing consequence")

        resolution_conditions = _resolution_conditions(
            support, conditions, counters, decision
        )
        has_unresolved_p0_conflict = bool(
            support and counters and not resolution_conditions
        )
        if has_unresolved_p0_conflict:
            conflict_blockers.append(claim_id)

        unknowns: list[str] = []
        unknowns.extend(f"missing evidence reference: {item}" for item in missing_ids)
        unknowns.extend(f"unresolved evidence: {item}" for item in unresolved_evidence)
        if not support:
            unknowns.append("verified P0 support is not yet available")
        if has_unresolved_p0_conflict:
            unknowns.append("P0 support and counter-evidence lack a human-readable scope/condition resolution")
        if unresolved_counter_ids:
            unknowns.append(
                "referenced counter-evidence is unresolved: "
                + ", ".join(unresolved_counter_ids)
            )
        if decision is None:
            unknowns.append("adjudication decision is not yet available")

        preliminary_ruling = (
            decision.ruling
            if decision is not None and decision.decision_kind == "preliminary"
            else None
        )
        final_ruling = (
            decision.ruling
            if decision is not None and decision.decision_kind == "final"
            else None
        )
        transition_authorized = _final_transition_authorized(claim, decision)
        if final_ruling is not None and not transition_authorized:
            unknowns.append("a finalized claim-status transition is not authorized")
        if (
            has_unresolved_p0_conflict
            or unresolved_counter_ids
            or not support
            or not transition_authorized
        ):
            effective_ruling = "needs_evidence"
        else:
            effective_ruling = final_ruling

        sorted_findings = tuple(
            sorted(
                findings_by_claim.get(claim_id, ()),
                key=lambda item: (item.path, item.locator, item.finding_id),
            )
        )
        implementation = tuple(_finding_text(item) for item in sorted_findings)
        migration = _migration_text(decision)
        if effective_ruling == "remove" and not migration:
            raise ValueError(f"removed rule {claim_id} requires a migration/deprecation note")

        rows.append(
            BaselineRow(
                claim_id=claim_id,
                topic=claim.topic,
                impact=claim.impact,
                support_evidence=tuple(
                    _evidence_detail(item)
                    for item in sorted(support, key=lambda item: item.evidence_id)
                ),
                source_fact=tuple(_evidence_text(item) for item in sorted(support, key=lambda item: item.evidence_id)),
                derivation=decision.rationale.strip() if decision is not None else "No adjudication rationale is available.",
                world_model_ruling=claim.statement,
                current_findings=tuple(_finding_detail(item) for item in sorted_findings),
                current_implementation=implementation,
                decision_kind=decision.decision_kind if decision is not None else None,
                preliminary_ruling=preliminary_ruling,
                final_ruling=final_ruling,
                effective_ruling=effective_ruling,
                player_consequence=decision.player_consequence.strip() if decision is not None else "No player-facing change is authorized.",
                migration_deprecation_action=migration,
                confidence=claim.confidence if support and not has_unresolved_p0_conflict else "unknown",
                condition_evidence=tuple(
                    _evidence_detail(item)
                    for item in sorted(conditions, key=lambda item: item.evidence_id)
                ),
                resolved_condition_evidence=tuple(
                    _evidence_detail(item)
                    for item in sorted(resolution_conditions, key=lambda item: item.evidence_id)
                ),
                resolution_status=(
                    "resolved"
                    if support and counters and resolution_conditions
                    else "unresolved"
                    if claim.counter_evidence_ids
                    else "not_required"
                ),
                counter_evidence_details=tuple(
                    _evidence_detail(item)
                    for item in sorted(referenced_counters, key=lambda item: item.evidence_id)
                ),
                counter_evidence=tuple(
                    _evidence_text(item)
                    for item in sorted(referenced_counters, key=lambda item: item.evidence_id)
                ),
                unknowns=tuple(unknowns),
            )
        )

    hard_blockers = sorted(
        set(conflict_blockers)
        | {
            row.claim_id
            for row in rows
            if row.impact == "high"
            and row.effective_ruling in {"defer", "needs_evidence"}
        }
    )
    if hard_blockers:
        gate_result = "NO_GO"
    elif any(row.effective_ruling in {"defer", "needs_evidence"} for row in rows):
        gate_result = "CONDITIONAL_GO"
    else:
        gate_result = "GO"
    return BaselineAdjudication(
        tuple(rows),
        LEGACY_DISPOSITIONS,
        gate_result,
        tuple(hard_blockers),
    )
