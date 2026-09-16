"""Stable data contracts shared by Lore Compiler stages."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class SourceSpec:
    source_file_id: str
    path: str
    encoding: str
    authority: str
    default_claim_type: str
    expected_sha256: str


@dataclass(frozen=True)
class SourceFingerprint:
    source_file_id: str
    path: str
    encoding: str
    bytes: int
    characters: int
    sha256: str


@dataclass(frozen=True)
class SectionRecord:
    source_id: str
    source_file_id: str
    volume: int
    chapter: int
    title: str
    sequence: int
    start_offset: int
    end_offset: int
    start_byte: int
    end_byte: int
    text: str
    text_hash: str
    diagnostics: tuple[str, ...] = field(default_factory=tuple)


@dataclass(frozen=True)
class ChunkConfig:
    target_chars: int
    max_chars: int
    min_chars: int


@dataclass(frozen=True)
class ChunkRecord:
    chunk_id: str
    source_id: str
    source_file_id: str
    volume: int
    chapter: int
    title: str
    sequence: int
    chunk_sequence: int
    start_offset: int
    end_offset: int
    start_byte: int
    end_byte: int
    text: str
    chunk_hash: str
    previous_id: str | None = None
    next_id: str | None = None
    status: str = "PENDING"


@dataclass(frozen=True)
class ModelTask:
    task_type: str
    input_sha256: str
    prompt_version: str
    schema_version: str
    payload: dict[str, object]


@dataclass(frozen=True)
class ModelResult:
    status: str
    backend: str
    model: str
    output: dict[str, object] | None
    raw_sha256: str | None
    elapsed_ms: int
    estimated_cost_micros: int
    error_code: str | None


@dataclass(frozen=True)
class QuoteAlignment:
    ok: bool
    start_offset: int | None = None
    end_offset: int | None = None
    error: str | None = None


@dataclass(frozen=True)
class ValidatedExtraction:
    ok: bool
    payload: dict[str, object] | None
    errors: tuple[str, ...] = field(default_factory=tuple)


@dataclass(frozen=True)
class SeedRecord:
    seed_id: str
    seed_kind: str
    label: str
    summary: str
    source_doc: str
    source_ref: str
    content_hash: str
    review_status: str


@dataclass(frozen=True)
class SeedImportSummary:
    inserted: int
    skipped: int


@dataclass(frozen=True)
class WorldClaim:
    claim_id: str
    topic: str
    statement: str
    status: str
    impact: str
    source_ids: tuple[str, ...]
    evidence_ids: tuple[str, ...]
    counter_evidence_ids: tuple[str, ...]
    confidence: str
    previous_status: str | None = None


@dataclass(frozen=True)
class EvidenceRef:
    evidence_id: str
    source_file_id: str
    source_ref: str
    char_start: int
    char_end: int
    quote: str
    authority: str
    evidence_kind: str


@dataclass(frozen=True)
class ImplementationFinding:
    finding_id: str
    claim_id: str
    path: str
    locator: str
    observed: str
    source_layer: str
    behavior_status: str
    migration_action: str


@dataclass(frozen=True)
class WorldDecision:
    claim_id: str
    ruling: str
    rationale: str
    player_consequence: str
    implementation_action: str
    non_regression_notes: tuple[str, ...]
    previous_status: str | None = None
    decision_kind: str = "final"


@dataclass(frozen=True)
class Stage0Gate:
    result: str
    claim_count: int
    high_impact_covered: int
    unresolved_high_impact: tuple[str, ...]
    production_paths_changed: tuple[str, ...]
    deterministic: bool
