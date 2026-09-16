"""World-claim ledger contracts, JSONL loading, and cross-record validation."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from .contracts import EvidenceRef, ImplementationFinding, WorldClaim, WorldDecision

STATUSES = {"candidate", "canonical", "derived", "adaptation", "rejected", "deferred"}
IMPACTS = {"high", "medium", "low"}
CONFIDENCE = {"high", "medium", "low", "unknown"}
AUTHORITIES = {"primary_text", "in_world_text", "secondary_note", "code", "design"}
EVIDENCE_KINDS = {"support", "condition", "counterexample", "unknown"}
RULINGS = {"retain", "revise", "remove", "defer", "needs_evidence"}
SOURCE_LAYERS = {"data", "domain", "presentation", "spec"}
BEHAVIOR_STATUSES = {"aligned", "partial", "conflict", "unknown", "not_implemented"}
MIGRATION_ACTIONS = {"retain", "revise", "remove", "defer"}
SCHEMA_PATH = Path(__file__).parents[1] / "schemas" / "world-claim-v1.json"


@dataclass(frozen=True)
class ValidationError:
    code: str
    message: str
    file: str = ""
    line: int = 0


@dataclass(frozen=True)
class ValidationResult:
    errors: tuple[ValidationError, ...] = ()

    @property
    def ok(self) -> bool:
        return not self.errors


@dataclass(frozen=True)
class LoadedRecords:
    records: tuple[object, ...]
    errors: tuple[ValidationError, ...] = ()


def _error(code: str, message: str, path: Path | str = "", line: int = 0) -> ValidationError:
    return ValidationError(code, message, str(path), line)


def _strings(value: object) -> bool:
    return isinstance(value, list) and all(isinstance(item, str) and item for item in value)


def validate_record_schema(payload: object, kind: str) -> tuple[str, ...]:
    """Validate a complete repository record without a third-party runtime."""
    if kind not in {"claim", "evidence", "finding", "decision"}:
        return (f"unknown record kind: {kind}",)
    if not isinstance(payload, dict):
        return ("record must be an object",)
    definition = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))["$defs"][kind]
    required = tuple(definition.get("required", ()))
    properties = definition.get("properties", {})
    errors: list[str] = []
    missing = [key for key in required if key not in payload]
    extra = sorted(set(payload) - set(properties))
    errors.extend(f"missing required property: {key}" for key in missing)
    errors.extend(f"additional property is not allowed: {key}" for key in extra)
    for key, value in payload.items():
        if key not in properties:
            continue
        spec = properties[key]
        if spec.get("type") == "string":
            if not isinstance(value, str):
                errors.append(f"{key} must be a string")
            elif len(value) < spec.get("minLength", 0):
                errors.append(f"{key} must not be empty")
        elif spec.get("type") == "integer":
            if not isinstance(value, int) or isinstance(value, bool):
                errors.append(f"{key} must be an integer")
            elif "minimum" in spec and value < spec["minimum"]:
                errors.append(f"{key} is below the minimum")
        elif spec.get("type") == "array":
            if not isinstance(value, list):
                errors.append(f"{key} must be an array")
            else:
                item_spec = spec.get("items", {})
                for item in value:
                    if item_spec.get("type") == "string" and (not isinstance(item, str) or len(item) < item_spec.get("minLength", 0)):
                        errors.append(f"{key} items must be non-empty strings")
        if "enum" in spec and value not in spec["enum"]:
            errors.append(f"{key} contains an invalid enum")
        if "const" in spec and value != spec["const"]:
            errors.append(f"{key} does not match its required constant")
    if kind == "evidence" and payload.get("evidence_kind") == "unknown":
        if (payload.get("char_start"), payload.get("char_end"), payload.get("quote")) != (-1, -1, ""):
            errors.append("unknown evidence must use the explicit placeholder range and quote")
    if kind == "evidence" and payload.get("evidence_kind") in {"support", "condition", "counterexample"}:
        start, end = payload.get("char_start"), payload.get("char_end")
        if isinstance(start, int) and not isinstance(start, bool) and start < 0:
            errors.append("char_start is below the minimum")
        if isinstance(end, int) and not isinstance(end, bool) and end < 1:
            errors.append("char_end is below the minimum")
        if isinstance(payload.get("quote"), str) and not payload["quote"]:
            errors.append("quote must not be empty")
        if isinstance(start, int) and not isinstance(start, bool) and isinstance(end, int) and not isinstance(end, bool) and end <= start:
            errors.append("char_end must be greater than char_start")
    constraints = definition.get("x-repository-constraints", ())
    if "char_end_gt_char_start" in constraints and kind == "evidence" and payload.get("evidence_kind") not in EVIDENCE_KINDS:
        errors.append("evidence_kind is required")
    return tuple(errors)


def _claim(payload: dict[str, object]) -> WorldClaim:
    return WorldClaim(payload["claim_id"], payload["topic"], payload["statement"], payload["status"], payload["impact"], tuple(payload["source_ids"]), tuple(payload["evidence_ids"]), tuple(payload["counter_evidence_ids"]), payload["confidence"], payload.get("previous_status"))


def _record(payload: object, kind: str) -> object:
    schema_errors = validate_record_schema(payload, kind)
    if schema_errors:
        raise ValueError(schema_errors[0])
    assert isinstance(payload, dict)
    if kind == "claim":
        return _claim(payload)
    if kind == "evidence":
        required = ("evidence_id", "source_file_id", "source_ref", "char_start", "char_end", "quote", "authority", "evidence_kind")
        return EvidenceRef(*(payload[key] for key in required))
    if kind == "decision":
        required = ("claim_id", "ruling", "rationale", "player_consequence", "implementation_action", "non_regression_notes")
        return WorldDecision(payload["claim_id"], payload["ruling"], payload["rationale"], payload["player_consequence"], payload["implementation_action"], tuple(payload["non_regression_notes"]), payload.get("previous_status"), payload.get("decision_kind", "final"))
    if kind == "finding":
        required = ("finding_id", "claim_id", "path", "locator", "observed", "source_layer", "behavior_status", "migration_action")
        return ImplementationFinding(*(payload[key] for key in required))
    raise ValueError(f"unknown record kind: {kind}")


def load_jsonl(paths: Iterable[Path], kind: str) -> LoadedRecords:
    """Load JSONL in normalized path/line order, retaining row errors."""
    records: list[object] = []
    errors: list[ValidationError] = []
    for path in sorted((Path(item) for item in paths), key=lambda item: item.as_posix()):
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if not line.strip():
                continue
            try:
                records.append(_record(json.loads(line), kind))
            except (json.JSONDecodeError, ValueError, TypeError) as exc:
                errors.append(_error("malformed_record", str(exc), path, line_number))
    return LoadedRecords(tuple(records), tuple(errors))


def validate_status_transition(previous: str, current: str, *, explicit_decision: bool = False) -> ValidationResult:
    allowed = {
        "candidate": {"canonical", "derived", "adaptation", "rejected", "deferred"},
        "canonical": {"canonical", "derived", "adaptation", "deferred"} if explicit_decision else set(),
        "derived": set(), "adaptation": set(), "deferred": set(), "rejected": set(),
    }
    if previous not in STATUSES or current not in STATUSES:
        return ValidationResult((_error("invalid_enum", "unknown claim status"),))
    if current not in allowed[previous]:
        return ValidationResult((_error("invalid_status_transition", f"cannot transition {previous} -> {current}"),))
    return ValidationResult()


def validate_claim_set(records: Iterable[object], config: dict[str, object]) -> ValidationResult:
    records = tuple(records)
    claims = tuple(record for record in records if isinstance(record, WorldClaim))
    evidence = {record.evidence_id: record for record in records if isinstance(record, EvidenceRef)}
    decisions_by_claim: dict[str, list[WorldDecision]] = {}
    for record in records:
        if isinstance(record, WorldDecision):
            decisions_by_claim.setdefault(record.claim_id, []).append(record)
    errors: list[ValidationError] = []
    seen: set[str] = set()
    for record in records:
        identifier = getattr(record, "claim_id", None) if isinstance(record, WorldClaim) else getattr(record, "evidence_id", getattr(record, "finding_id", None))
        if identifier is None:
            continue
        if identifier in seen:
            errors.append(_error("duplicate_id", f"duplicate ID: {identifier}"))
        seen.add(identifier)
    for claim in claims:
        if claim.status not in STATUSES or claim.impact not in IMPACTS or claim.confidence not in CONFIDENCE:
            errors.append(_error("invalid_enum", f"invalid enum in claim {claim.claim_id}"))
        for evidence_id in claim.evidence_ids + claim.counter_evidence_ids:
            if evidence_id not in evidence:
                errors.append(_error("missing_evidence_reference", f"claim {claim.claim_id} references unknown evidence {evidence_id}"))
        referenced = [evidence[eid] for eid in claim.evidence_ids if eid in evidence]
        verified_referenced = [item for item in referenced if item.evidence_kind != "unknown"]
        all_referenced = [evidence[eid] for eid in claim.evidence_ids + claim.counter_evidence_ids if eid in evidence]
        source_ids = set(claim.source_ids)
        for item in all_referenced:
            if item.source_file_id not in source_ids:
                errors.append(_error("evidence_source_mismatch", f"evidence {item.evidence_id} is not from a claim source"))
        if claim.status == "canonical" and referenced and (len(verified_referenced) != len(referenced) or any(item.evidence_kind != "support" for item in verified_referenced)):
            errors.append(_error("authority_status_mismatch", f"canonical claim {claim.claim_id} requires support evidence"))
        if claim.status == "canonical" and not any(item.source_file_id in set(config.get("p0_source_ids", ())) and item.authority in {"primary_text", "in_world_text"} for item in verified_referenced):
            errors.append(_error("canonical_requires_p0_evidence", f"canonical claim {claim.claim_id} lacks P0 evidence"))
        decisions = decisions_by_claim.get(claim.claim_id, [])
        if len(decisions) > 1:
            errors.extend(_error("duplicate_decision", f"duplicate decision for claim {claim.claim_id}") for _ in decisions[1:])
        final_decisions = [item for item in decisions if item.decision_kind == "final"]
        decision = final_decisions[0] if final_decisions else None
        if decision is not None and claim.previous_status is not None and decision.previous_status is not None and claim.previous_status != decision.previous_status:
            errors.append(_error("previous_status_mismatch", f"claim {claim.claim_id} previous_status {claim.previous_status} does not match decision {decision.previous_status}"))
        if claim.status in {"canonical", "derived", "adaptation", "rejected"} and (claim.status != "canonical" or decision is not None or claim.previous_status not in {None, "candidate"}):
            if decision is None:
                errors.append(_error("unauthorized_status_transition", f"claim {claim.claim_id} has no explicit decision"))
            else:
                expected_ruling = {"canonical": "retain", "derived": "revise", "adaptation": "revise", "rejected": "remove"}[claim.status]
                if decision.ruling != expected_ruling:
                    errors.append(_error("decision_status_mismatch", f"decision {decision.ruling} does not authorize {claim.status}"))
                if decision.previous_status is None:
                    errors.append(_error("missing_previous_status", f"decision for {claim.claim_id} must declare previous_status"))
                else:
                    transition = validate_status_transition(decision.previous_status, claim.status, explicit_decision=True)
                    errors.extend(transition.errors)
        if claim.previous_status is not None and not (claim.status in {"canonical", "derived", "adaptation", "rejected"} and decision is not None):
            errors.extend(validate_status_transition(claim.previous_status, claim.status).errors)
        if claim.status in {"candidate", "deferred"}:
            allowed_rulings = {"candidate": {"defer", "needs_evidence"}, "deferred": {"defer", "needs_evidence"}}[claim.status]
            for attached_decision in final_decisions:
                if attached_decision.ruling not in allowed_rulings:
                    errors.append(_error("decision_status_mismatch", f"decision {attached_decision.ruling} does not authorize {claim.status}"))
                if attached_decision.previous_status is not None:
                    transition = validate_status_transition(attached_decision.previous_status, claim.status, explicit_decision=True)
                    errors.extend(transition.errors)
    for item in evidence.values():
        if item.authority not in AUTHORITIES or item.evidence_kind not in EVIDENCE_KINDS:
            errors.append(_error("invalid_enum", f"invalid enum in evidence {item.evidence_id}"))
        if item.evidence_kind != "unknown" and (item.char_start < 0 or item.char_end <= item.char_start):
            errors.append(_error("invalid_range", f"invalid character range in evidence {item.evidence_id}"))
    for decision in (record for record in records if isinstance(record, WorldDecision)):
        if decision.ruling not in RULINGS or decision.decision_kind not in {"preliminary", "final"}:
            errors.append(_error("invalid_enum", f"invalid ruling in decision for {decision.claim_id}"))
        if decision.claim_id not in {claim.claim_id for claim in claims}:
            errors.append(_error("missing_claim_reference", f"decision references unknown claim {decision.claim_id}"))
    claim_ids = {claim.claim_id for claim in claims}
    for finding in (record for record in records if isinstance(record, ImplementationFinding)):
        if finding.claim_id not in claim_ids:
            errors.append(_error(
                "missing_claim_reference",
                f"finding {finding.finding_id} references unknown claim {finding.claim_id}",
            ))
    topics = set(config.get("high_impact_claim_ids", ()))
    covered = {claim.topic for claim in claims}
    errors.extend(_error("missing_high_impact_topic", f"missing high-impact topic: {topic}") for topic in sorted(topics - covered))
    minimum = config.get("minimum_claims", 0)
    if isinstance(minimum, int) and len(claims) < minimum:
        errors.append(_error("minimum_claims", f"need at least {minimum} claims, got {len(claims)}"))
    return ValidationResult(tuple(errors))
