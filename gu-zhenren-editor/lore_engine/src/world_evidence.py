"""Read-only source evidence alignment and claim coverage helpers."""

from __future__ import annotations

import hashlib
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

from .contracts import ChunkRecord, EvidenceRef, SeedRecord, SourceSpec, WorldClaim
from .source_manifest import SourceFingerprintError, SourcePathError, load_manifest, read_source


class EvidenceResolutionError(ValueError):
    """Raised when a source cannot be verified against the manifest."""


@dataclass(frozen=True)
class ResolvedEvidence:
    evidence_id: str
    source_file_id: str
    source_ref: str
    char_start: int
    char_end: int
    quote: str
    authority: str
    evidence_kind: str
    ok: bool
    quote_sha256: str
    source_sha256: str | None = None
    error: str | None = None


@dataclass(frozen=True)
class ClaimCoverage:
    claim_id: str
    support: tuple[EvidenceRef | ResolvedEvidence | CounterEvidenceCandidate, ...] = ()
    conditions: tuple[EvidenceRef | ResolvedEvidence | CounterEvidenceCandidate, ...] = ()
    counter_evidence: tuple[EvidenceRef | ResolvedEvidence | CounterEvidenceCandidate, ...] = ()
    unknown: tuple[EvidenceRef | ResolvedEvidence | CounterEvidenceCandidate, ...] = ()
    errors: tuple[str, ...] = ()
    unresolved: tuple[CounterEvidenceCandidate, ...] = ()

    @property
    def ok(self) -> bool:
        return not self.errors


@dataclass(frozen=True)
class CounterEvidenceCandidate:
    """A discovered counterexample that is not safe to enter the formal ledger."""

    evidence_id: str
    source_file_id: str | None
    source_ref: str | None
    char_start: int | None
    char_end: int | None
    quote: str
    authority: str | None
    evidence_kind: str
    verified: bool
    reason: str


_P0_AUTHORITIES = {"primary_text", "in_world_text"}
_AUTHORITY_RANK = {"primary_text": 0, "in_world_text": 0, "secondary_note": 1, "code": 2, "design": 3}
_COUNTER_MARKERS = ("反例", "但是", "然而", "并非", "不能", "无法", "不总", "冲突")


def _specs(manifest: Iterable[SourceSpec] | Path) -> dict[str, SourceSpec]:
    items = load_manifest(manifest) if isinstance(manifest, Path) else tuple(manifest)
    return {spec.source_file_id: spec for spec in items}


def _matches(text: str, quote: str) -> list[int]:
    if not quote:
        return []
    starts: list[int] = []
    cursor = 0
    while True:
        found = text.find(quote, cursor)
        if found < 0:
            return starts
        starts.append(found)
        cursor = found + 1


def resolve_evidence(
    root: Path, manifest: Iterable[SourceSpec] | Path, evidence_refs: Iterable[EvidenceRef]
) -> tuple[ResolvedEvidence, ...]:
    """Resolve evidence against exact decoded text and declared character offsets.

    The source is read through ``read_source``.  No whitespace, newline, or Unicode
    normalization is performed before slicing or counting occurrences.
    """
    specs = _specs(manifest)
    texts: dict[str, tuple[str, str]] = {}
    for spec in specs.values():
        try:
            payload = read_source(root, spec)
            source_bytes = (root / spec.path).read_bytes()
            texts[spec.source_file_id] = (payload, hashlib.sha256(source_bytes).hexdigest())
        except (OSError, UnicodeError, SourceFingerprintError, SourcePathError) as exc:
            raise EvidenceResolutionError(str(exc)) from exc
    resolved: list[ResolvedEvidence] = []
    for evidence in evidence_refs:
        spec = specs.get(evidence.source_file_id)
        if spec is None:
            raise EvidenceResolutionError(f"unknown source file: {evidence.source_file_id}")
        if evidence.authority != spec.authority:
            resolved.append(_invalid(evidence, "evidence authority does not match manifest authority"))
            continue
        try:
            text, source_hash = texts[evidence.source_file_id]
        except (OSError, UnicodeError, SourceFingerprintError, SourcePathError) as exc:
            raise EvidenceResolutionError(str(exc)) from exc
        if evidence.evidence_kind == "unknown":
            resolved.append(ResolvedEvidence(**evidence.__dict__, ok=False, quote_sha256="", source_sha256=source_hash, error="unknown evidence placeholder"))
            continue
        if evidence.char_start < 0 or evidence.char_end <= evidence.char_start or evidence.char_end > len(text):
            resolved.append(_invalid(evidence, "invalid decoded-character range", source_hash))
            continue
        if text[evidence.char_start:evidence.char_end] != evidence.quote:
            resolved.append(_invalid(evidence, "quote does not match declared decoded-character range", source_hash))
            continue
        occurrences = _matches(text, evidence.quote)
        if len(occurrences) != 1 or occurrences[0] != evidence.char_start:
            resolved.append(_invalid(evidence, "quote must occur exactly once at the declared offset", source_hash))
            continue
        resolved.append(ResolvedEvidence(**evidence.__dict__, ok=True, quote_sha256=hashlib.sha256(evidence.quote.encode("utf-8")).hexdigest(), source_sha256=source_hash))
    return tuple(resolved)


def _invalid(evidence: EvidenceRef, error: str, source_hash: str | None = None) -> ResolvedEvidence:
    return ResolvedEvidence(**evidence.__dict__, ok=False, quote_sha256=hashlib.sha256(evidence.quote.encode("utf-8")).hexdigest() if evidence.quote else "", source_sha256=source_hash, error=error)


def check_claim_coverage(
    claim: WorldClaim, evidence: Iterable[EvidenceRef | ResolvedEvidence | CounterEvidenceCandidate], manifest: Iterable[SourceSpec] | Path | None = None
) -> ClaimCoverage:
    """Check claim references while retaining support, conditions, and counters separately."""
    items = tuple(evidence)
    by_id = {item.evidence_id: item for item in items}
    errors: list[str] = []
    selected: list[EvidenceRef | ResolvedEvidence | CounterEvidenceCandidate] = []
    for evidence_id in claim.evidence_ids + claim.counter_evidence_ids:
        if evidence_id not in by_id:
            errors.append(f"missing evidence reference: {evidence_id}")
        else:
            selected.append(by_id[evidence_id])
    support = tuple(item for item in selected if item.evidence_kind == "support")
    conditions = tuple(item for item in selected if item.evidence_kind == "condition")
    counters = tuple(item for item in selected if item.evidence_kind == "counterexample")
    unknown = tuple(item for item in selected if item.evidence_kind == "unknown")
    candidates = tuple(item for item in selected if isinstance(item, CounterEvidenceCandidate))
    if candidates:
        errors.append("claim references unresolved counter-evidence candidates")
    if any(getattr(item, "ok", True) is False for item in selected if item.evidence_kind != "unknown"):
        errors.append("claim references unresolved evidence")
    if manifest is not None:
        specs = _specs(manifest)
        for item in selected:
            spec = specs.get(item.source_file_id)
            if spec is None or spec.authority != item.authority:
                errors.append(f"evidence authority mismatch: {item.evidence_id}")
    required_status = claim.status in {"canonical", "derived", "adaptation"}
    if required_status and not support:
        errors.append(f"{claim.status} claim requires support evidence")
    if required_status and any(_AUTHORITY_RANK.get(item.authority, 99) > 0 for item in support):
        errors.append(f"{claim.status} claim support authority is too low")
    if claim.status == "canonical" and not any(item.authority in _P0_AUTHORITIES for item in support):
        errors.append("canonical claim requires P0 support evidence")
    return ClaimCoverage(claim.claim_id, support, conditions, counters, unknown, tuple(dict.fromkeys(errors)), candidates)


def find_counter_evidence(
    claim: WorldClaim,
    indexed_sources: Iterable[ChunkRecord | str | EvidenceRef],
    seed_records: Iterable[SeedRecord] = (),
    manifest: Iterable[SourceSpec] | Path | None = None,
    root: Path | None = None,
) -> tuple[EvidenceRef | ResolvedEvidence | CounterEvidenceCandidate, ...]:
    """Find visible counterexamples from indexed chunks and notes without upgrading authority."""
    found: list[EvidenceRef | ResolvedEvidence | CounterEvidenceCandidate] = []
    specs = _specs(manifest) if manifest is not None else {}
    for item in indexed_sources:
        if isinstance(item, EvidenceRef):
            if item.evidence_kind == "counterexample":
                found.append(item)
            continue
        text = item.text if isinstance(item, ChunkRecord) else str(item)
        if not any(marker in text for marker in _COUNTER_MARKERS):
            continue
        line = next((line.strip() for line in text.splitlines() if any(marker in line for marker in _COUNTER_MARKERS)), text.strip())
        if not isinstance(item, ChunkRecord):
            found.append(CounterEvidenceCandidate(f"candidate:{len(found) + 1}", None, None, None, None, line[:200], None, "counterexample", False, "raw indexed text lacks source coordinates"))
            continue
        spec = specs.get(item.source_file_id)
        if spec is None or root is None:
            found.append(CounterEvidenceCandidate(f"candidate:{len(found) + 1}", item.source_file_id, item.chunk_id, item.start_offset, item.end_offset, line[:200], spec.authority if spec else None, "counterexample", False, "chunk lacks manifest/root provenance for source alignment"))
            continue
        try:
            source_text = read_source(root, spec)
            source_bytes = (root / spec.path).read_bytes()
        except (OSError, UnicodeError, SourceFingerprintError, SourcePathError) as exc:
            found.append(CounterEvidenceCandidate(f"candidate:{len(found) + 1}", item.source_file_id, item.chunk_id, item.start_offset, item.end_offset, line[:200], spec.authority, "counterexample", False, f"source verification failed: {exc}"))
            continue
        source_hash = hashlib.sha256(source_bytes).hexdigest()
        if not (0 <= item.start_offset < item.end_offset <= len(source_text)):
            found.append(CounterEvidenceCandidate(f"candidate:{len(found) + 1}", item.source_file_id, item.chunk_id, item.start_offset, item.end_offset, line[:200], spec.authority, "counterexample", False, "chunk bounds are outside decoded source bounds"))
            continue
        expected_start_byte = len(source_text[:item.start_offset].encode(spec.encoding))
        expected_end_byte = len(source_text[:item.end_offset].encode(spec.encoding))
        source_byte_length = len(source_bytes)
        if not (0 <= item.start_byte < item.end_byte <= source_byte_length) or (item.start_byte, item.end_byte) != (expected_start_byte, expected_end_byte):
            found.append(CounterEvidenceCandidate(f"candidate:{len(found) + 1}", item.source_file_id, item.chunk_id, item.start_offset, item.end_offset, line[:200], spec.authority, "counterexample", False, "chunk byte bounds do not match exact UTF-8 source offsets"))
            continue
        if hashlib.sha256(item.text.encode("utf-8")).hexdigest() != item.chunk_hash or source_text[item.start_offset:item.end_offset] != item.text:
            found.append(CounterEvidenceCandidate(f"candidate:{len(found) + 1}", item.source_file_id, item.chunk_id, item.start_offset, item.end_offset, line[:200], spec.authority, "counterexample", False, "chunk text or hash does not match source"))
            continue
        local_start = item.text.find(line)
        if len(line) > 200:
            found.append(CounterEvidenceCandidate(f"candidate:{len(found) + 1}", item.source_file_id, item.chunk_id, item.start_offset + local_start, item.start_offset + local_start + len(line), line[:200], spec.authority, "counterexample", False, "marker line exceeds 200-character evidence limit; exact quote remains unresolved"))
            continue
        start = item.start_offset + local_start
        occurrences = _matches(source_text, line)
        if local_start < 0 or len(occurrences) != 1 or occurrences[0] != start:
            found.append(CounterEvidenceCandidate(f"candidate:{len(found) + 1}", item.source_file_id, item.chunk_id, start, start + len(line), line[:200], spec.authority, "counterexample", False, "counterexample quote is not uniquely aligned in source"))
            continue
        found.append(ResolvedEvidence(f"counter:{len(found) + 1}", item.source_file_id, item.chunk_id, start, start + len(line), line[:200], spec.authority, "counterexample", True, hashlib.sha256(line[:200].encode("utf-8")).hexdigest(), source_hash))
    for seed in seed_records:
        haystack = f"{seed.label} {seed.summary}"
        if any(marker in haystack for marker in _COUNTER_MARKERS):
            found.append(CounterEvidenceCandidate(f"seed-counter:{seed.seed_id}", seed.source_doc, seed.source_ref, None, None, seed.summary[:200], "secondary_note", "counterexample", False, "secondary note candidate requires primary-source verification"))
    return tuple(found)
