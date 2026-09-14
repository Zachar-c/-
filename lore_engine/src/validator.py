"""Strict validation for model extraction payloads."""

from __future__ import annotations

from collections.abc import Iterable

from .contracts import ChunkRecord, QuoteAlignment, ValidatedExtraction

FACT_TYPES = {"CANON", "INFERRED", "ADAPTATION", "GAME_ORIGINAL"}
ENTITY_TYPES = {
    "character", "faction", "location", "resource", "item",
    "creature", "cultivation", "concept", "organization",
}
RELATION_TYPES = {
    "belongs_to", "controls", "located_at", "allied_with", "enemy_of",
    "uses", "produces", "consumes", "knows", "kills", "trades_with",
    "causes", "affected_by",
}
TOP_LEVEL_KEYS = {"entities", "facts", "events", "relations", "rule_candidates", "uncertain_items"}
FACT_KEYS = {
    "fact_id", "subject", "predicate", "object", "fact_type", "confidence",
    "source_id", "chunk_id", "source_quote", "sequence", "conditions", "uncertainty",
}


def align_quote(quote: str, chunk_text: str) -> QuoteAlignment:
    if not isinstance(quote, str) or not quote:
        return QuoteAlignment(False, error="source_quote must be a non-empty string")
    starts: list[int] = []
    cursor = 0
    while True:
        position = chunk_text.find(quote, cursor)
        if position < 0:
            break
        starts.append(position)
        cursor = position + 1
    if len(starts) != 1:
        return QuoteAlignment(False, error="source_quote must occur exactly once in the referenced chunk")
    start = starts[0]
    return QuoteAlignment(True, start, start + len(quote))


def _is_string_array(value: object) -> bool:
    return isinstance(value, list) and all(isinstance(item, str) for item in value)


def _validate_fact(value: object, chunk: ChunkRecord) -> list[str]:
    if not isinstance(value, dict):
        return ["fact must be an object"]
    errors: list[str] = []
    missing = FACT_KEYS - value.keys()
    errors.extend(f"fact missing {key}" for key in sorted(missing))
    if errors:
        return errors
    for key in ("fact_id", "subject", "predicate", "object", "source_id", "chunk_id", "source_quote", "uncertainty"):
        if not isinstance(value[key], str):
            errors.append(f"fact {key} must be a string")
    if value["fact_type"] not in FACT_TYPES:
        errors.append("fact fact_type has unknown enum")
    confidence = value["confidence"]
    if not isinstance(confidence, (int, float)) or isinstance(confidence, bool) or not 0 <= confidence <= 1:
        errors.append("fact confidence must be a number in [0, 1]")
    if value["source_id"] != chunk.source_id:
        errors.append("fact source_id does not match chunk")
    if value["chunk_id"] != chunk.chunk_id:
        errors.append("fact chunk_id does not match chunk")
    if value["sequence"] != chunk.sequence:
        errors.append("fact sequence does not match chunk")
    if not _is_string_array(value["conditions"]):
        errors.append("fact conditions must be a string array")
    alignment = align_quote(value["source_quote"], chunk.text)
    if not alignment.ok:
        errors.append(alignment.error or "invalid source_quote")
    return errors


def validate_extraction(payload: object, chunk: ChunkRecord, source_text: str) -> ValidatedExtraction:
    del source_text  # Full-source presence must not make an out-of-chunk quote valid.
    if not isinstance(payload, dict):
        return ValidatedExtraction(False, None, ("extraction must be an object",))
    errors: list[str] = []
    if set(payload) != TOP_LEVEL_KEYS:
        errors.append("extraction must contain exactly the V1 top-level keys")
    for key in TOP_LEVEL_KEYS:
        if key in payload and not isinstance(payload[key], list):
            errors.append(f"{key} must be an array")
    for fact in payload.get("facts", []):
        errors.extend(_validate_fact(fact, chunk))
    for entity in payload.get("entities", []):
        if not isinstance(entity, dict) or entity.get("type") not in ENTITY_TYPES:
            errors.append("entity type has unknown enum")
    for relation in payload.get("relations", []):
        if not isinstance(relation, dict) or relation.get("predicate") not in RELATION_TYPES:
            errors.append("relation predicate has unknown enum")
    if errors:
        return ValidatedExtraction(False, None, tuple(errors))
    return ValidatedExtraction(True, payload, ())
