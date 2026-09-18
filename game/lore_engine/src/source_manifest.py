"""Strict, read-only source manifest operations."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from .contracts import SourceFingerprint, SourceSpec


class SourcePathError(ValueError):
    """Raised when a manifest path escapes the repository root."""


class SourceFingerprintError(ValueError):
    """Raised when a source does not match its declared digest."""


def load_manifest(path: Path) -> tuple[SourceSpec, ...]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, list):
        raise ValueError("source manifest must be a JSON array")
    specs: list[SourceSpec] = []
    for item in payload:
        if not isinstance(item, dict):
            raise ValueError("source manifest entries must be objects")
        specs.append(SourceSpec(**item))
    return tuple(specs)


def _resolve(root: Path, spec: SourceSpec) -> Path:
    root = root.resolve()
    candidate = (root / spec.path).resolve()
    try:
        candidate.relative_to(root)
    except ValueError as exc:
        raise SourcePathError(f"source path escapes repository root: {spec.path}") from exc
    return candidate


def _read_bytes(root: Path, spec: SourceSpec) -> bytes:
    path = _resolve(root, spec)
    before = path.stat()
    payload = path.read_bytes()
    after = path.stat()
    if before.st_mtime_ns != after.st_mtime_ns or before.st_size != after.st_size:
        raise SourceFingerprintError(f"source changed while reading: {spec.source_file_id}")
    digest = hashlib.sha256(payload).hexdigest()
    if digest.lower() != spec.expected_sha256.lower():
        raise SourceFingerprintError(
            f"source hash mismatch for {spec.source_file_id}: expected {spec.expected_sha256}, got {digest}"
        )
    return payload


def read_source(root: Path, spec: SourceSpec) -> str:
    return _read_bytes(root, spec).decode(spec.encoding, errors="strict")


def fingerprint_source(root: Path, spec: SourceSpec) -> SourceFingerprint:
    payload = _read_bytes(root, spec)
    text = payload.decode(spec.encoding, errors="strict")
    return SourceFingerprint(
        source_file_id=spec.source_file_id,
        path=spec.path,
        encoding=spec.encoding,
        bytes=len(payload),
        characters=len(text),
        sha256=hashlib.sha256(payload).hexdigest(),
    )
