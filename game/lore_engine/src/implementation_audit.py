"""Read-only, non-authoritative observations of the current game implementation."""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from .contracts import ImplementationFinding


class ImplementationAuditError(ValueError):
    """Raised when an approved implementation surface cannot be audited safely."""


class UnsafeAuditPathError(ImplementationAuditError):
    """Raised before a scanner reads a path outside its repository root."""


_DATA_PATHS = (
    "data/gu.json",
    "data/schools.json",
    "data/balance.json",
    "data/recipes.json",
)
_TEXT_TREES = (
    ("scripts/domain", "*.gd", True),
    ("docs/wiki/concepts", "*.md", False),
    ("docs/lore", "*.md", False),
)
_TEXT_PATTERNS = (
    ("role_fallback_definition", "gu_activation", re.compile(r"\bdefault_v1_effect\b")),
    ("immutable_event_log", "world_scope_and_compression", re.compile(r"\bappend_event\s*\(")),
    ("generic_rank_multiplier", "rank_and_subrank", re.compile(r"\brank\w*[^\n]*(?:multiplier|ratio)|(?:multiplier|ratio)[^\n]*\brank\w*", re.IGNORECASE)),
    ("rank_field", "rank_and_subrank", re.compile(r"\brank\b", re.IGNORECASE)),
    ("essence_field", "primeval_essence", re.compile(r"\bessence\w*\b", re.IGNORECASE)),
    ("aptitude_field", "aptitude_capacity", re.compile(r"\baptitude\w*\b", re.IGNORECASE)),
    ("lifespan_field", "lifespan", re.compile(r"\blifespan\w*\b", re.IGNORECASE)),
    ("soul_field", "soul", re.compile(r"\bsoul\w*\b", re.IGNORECASE)),
    ("dao_field", "dao_marks", re.compile(r"\bdao(?:_marks?|\s+marks?)?\b", re.IGNORECASE)),
    ("refinement_path", "gu_refinement", re.compile(r"\brefin(?:e|ed|ing|ement)\w*\b", re.IGNORECASE)),
    ("feeding_path", "gu_feeding", re.compile(r"\bfeed(?:ing)?\w*\b", re.IGNORECASE)),
    ("transaction_path", "economy_and_primeval_stones", re.compile(r"\b(?:transaction|trade|market)\w*\b", re.IGNORECASE)),
    ("combat_hook", "kill_move", re.compile(r"\bcombat\w*\b", re.IGNORECASE)),
    ("npc_hook", "force_and_social_order", re.compile(r"\bnpc\w*\b", re.IGNORECASE)),
    ("map_hook", "world_scope_and_compression", re.compile(r"\bmap\w*\b", re.IGNORECASE)),
    ("meta_hook", "world_scope_and_compression", re.compile(r"\bmeta\w*\b", re.IGNORECASE)),
    ("legacy_q8g_reference", "world_scope_and_compression", re.compile(r"\bQ8[-_ ]?G\b", re.IGNORECASE)),
    ("legacy_f1_reference", "world_scope_and_compression", re.compile(r"\bF1\b", re.IGNORECASE)),
    ("promotion_reference", "rank_and_subrank", re.compile(r"\bpromotion\w*\b", re.IGNORECASE)),
    ("material_reference", "gu_refinement", re.compile(r"\bmaterial\w*\b", re.IGNORECASE)),
)
_CLASS_LIKE_SCHOOL_TERMS = {
    "archetype",
    "class",
    "playstyle",
    "profession",
    "role",
    "specialization",
    "vocation",
}


def _iter_approved_files(root: Path) -> tuple[Path, ...]:
    files: list[Path] = []
    for relative in _DATA_PATHS:
        candidate = root / relative
        if candidate.exists():
            files.append(candidate)
    for relative, pattern, recursive in _TEXT_TREES:
        base = root / relative
        if base.exists():
            files.extend(base.rglob(pattern) if recursive else base.glob(pattern))
    return tuple(sorted(files, key=lambda item: item.as_posix()))


def _safe_relative(root: Path, candidate: Path) -> tuple[Path, str]:
    resolved = candidate.resolve(strict=True)
    try:
        relative = resolved.relative_to(root)
    except ValueError as exc:
        raise UnsafeAuditPathError(f"audit path escapes repository root: {candidate}") from exc
    return resolved, relative.as_posix()


def _json_pointer(*segments: object) -> str:
    encoded = (str(segment).replace("~", "~0").replace("/", "~1") for segment in segments)
    return "/" + "/".join(encoded)


def _is_class_like_school_field(key: str) -> bool:
    terms = {term for term in re.split(r"[^a-z0-9]+", key.lower()) if term}
    return bool(terms & _CLASS_LIKE_SCHOOL_TERMS)


def _finding(surface: str, claim_id: str, path: str, locator: str, detail: str, source_layer: str) -> ImplementationFinding:
    identity = "\0".join((claim_id, surface, path, locator))
    finding_id = f"implementation-{hashlib.sha256(identity.encode('utf-8')).hexdigest()[:16]}"
    return ImplementationFinding(
        finding_id=finding_id,
        claim_id=claim_id,
        path=path,
        locator=locator,
        observed=f"[{surface}] {detail}",
        source_layer=source_layer,
        behavior_status="unknown",
        migration_action="defer",
    )


def _field_finding(surface: str, claim_id: str, path: str, locator: str, key: str, value: object) -> ImplementationFinding:
    rendered = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    if len(rendered) > 160:
        rendered = rendered[:157] + "..."
    return _finding(surface, claim_id, path, locator, f"field {key}={rendered}", "data")


def _scan_gu(payload: object, path: str) -> list[ImplementationFinding]:
    if not isinstance(payload, list):
        raise ImplementationAuditError(f"{path} must contain a JSON array")
    findings: list[ImplementationFinding] = []
    for index, item in enumerate(payload):
        if not isinstance(item, dict):
            continue
        prefix = _json_pointer(index)
        if "rank" in item:
            findings.append(_field_finding("rank_field", "rank_and_subrank", path, _json_pointer(index, "rank"), "rank", item["rank"]))
        for key in sorted(item):
            if "essence" in key.lower():
                findings.append(_field_finding("essence_field", "primeval_essence", path, _json_pointer(index, key), key, item[key]))
            if key.lower().startswith("feeding"):
                findings.append(_field_finding("feeding_path", "gu_feeding", path, _json_pointer(index, key), key, item[key]))
        if "essence_cost" in item and "true_qi_cost" in item:
            findings.append(_finding("dual_resource_cost", "primeval_essence", path, prefix, "Gu definition carries essence_cost and true_qi_cost", "data"))
        if "v1_effect" in item:
            findings.append(_field_finding("explicit_gu_effect", "gu_activation", path, _json_pointer(index, "v1_effect"), "v1_effect", item["v1_effect"]))
        elif "role" in item:
            findings.append(_field_finding("role_fallback_candidate", "gu_activation", path, _json_pointer(index, "role"), "role", item["role"]))
    return findings


def _scan_schools(payload: object, path: str) -> list[ImplementationFinding]:
    if not isinstance(payload, dict):
        raise ImplementationAuditError(f"{path} must contain a JSON object")
    findings: list[ImplementationFinding] = []
    for school_id in sorted(payload):
        school = payload[school_id]
        if not isinstance(school, dict):
            continue
        if "starter_gu_ids" in school:
            locator = _json_pointer(school_id, "starter_gu_ids")
            findings.append(_field_finding("school_starter_pool", "world_scope_and_compression", path, locator, "starter_gu_ids", school["starter_gu_ids"]))
        for key in sorted(school):
            if _is_class_like_school_field(key):
                findings.append(_field_finding("school_class_semantics", "world_scope_and_compression", path, _json_pointer(school_id, key), key, school[key]))
    return findings


def _scan_balance(payload: object, path: str) -> list[ImplementationFinding]:
    if not isinstance(payload, dict):
        raise ImplementationAuditError(f"{path} must contain a JSON object")
    findings: list[ImplementationFinding] = []
    field_surfaces = (
        ("aptitude", "aptitude_field", "aptitude_capacity"),
        ("lifespan", "lifespan_field", "lifespan"),
        ("soul", "soul_field", "soul"),
        ("dao", "dao_field", "dao_marks"),
        ("essence", "essence_field", "primeval_essence"),
        ("material", "material_reference", "gu_refinement"),
    )
    for key in sorted(payload):
        lowered = key.lower()
        locator = _json_pointer(key)
        if "rank" in lowered and ("multiplier" in lowered or "ratio" in lowered):
            findings.append(_field_finding("generic_rank_multiplier", "rank_and_subrank", path, locator, key, payload[key]))
            continue
        for needle, surface, claim_id in field_surfaces:
            if needle in lowered:
                findings.append(_field_finding(surface, claim_id, path, locator, key, payload[key]))
                break
    return findings


def _scan_recipes(payload: object, path: str) -> list[ImplementationFinding]:
    if not isinstance(payload, list):
        raise ImplementationAuditError(f"{path} must contain a JSON array")
    findings: list[ImplementationFinding] = []
    for index, item in enumerate(payload):
        if not isinstance(item, dict):
            continue
        recipe_id = str(item.get("id", index))
        findings.append(_finding("recipe_definition", "gu_recipe", path, _json_pointer(index), f"recipe id={recipe_id}", "data"))
        for key in sorted(item):
            if "material" in key.lower():
                findings.append(_field_finding("material_reference", "gu_refinement", path, _json_pointer(index, key), key, item[key]))
    return findings


def _scan_json(text: str, path: str) -> list[ImplementationFinding]:
    try:
        payload = json.loads(text)
    except json.JSONDecodeError as exc:
        raise ImplementationAuditError(f"invalid JSON in {path}: {exc}") from exc
    scanner = {
        "data/gu.json": _scan_gu,
        "data/schools.json": _scan_schools,
        "data/balance.json": _scan_balance,
        "data/recipes.json": _scan_recipes,
    }[path]
    return scanner(payload, path)


def _scan_text(text: str, path: str) -> list[ImplementationFinding]:
    source_layer = "domain" if path.startswith("scripts/domain/") else "spec"
    findings: list[ImplementationFinding] = []
    for line_number, line in enumerate(text.splitlines(), 1):
        compact = " ".join(line.strip().split())
        if not compact:
            continue
        excerpt = compact if len(compact) <= 200 else compact[:197] + "..."
        for surface, claim_id, pattern in _TEXT_PATTERNS:
            if pattern.search(line):
                findings.append(_finding(surface, claim_id, path, f"line:{line_number}", excerpt, source_layer))
    return findings


def audit_current_implementation(repository_root: Path | str) -> list[ImplementationFinding]:
    """Scan only approved game surfaces and return deterministic observations.

    Findings deliberately remain ``unknown``/``defer``: implementation is an audit
    subject and never evidence for world truth.
    """
    root = Path(repository_root).resolve(strict=True)
    if not root.is_dir():
        raise UnsafeAuditPathError(f"repository root is not a directory: {root}")
    findings: list[ImplementationFinding] = []
    for candidate in _iter_approved_files(root):
        resolved, relative = _safe_relative(root, candidate)
        text = resolved.read_text(encoding="utf-8")
        if relative in _DATA_PATHS:
            findings.extend(_scan_json(text, relative))
        else:
            findings.extend(_scan_text(text, relative))
    return sorted(findings, key=lambda item: (item.claim_id, item.path, item.locator, item.finding_id))


__all__ = [
    "ImplementationAuditError",
    "UnsafeAuditPathError",
    "audit_current_implementation",
]
