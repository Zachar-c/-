"""Local-first model adapters with content-addressed response caching."""

from __future__ import annotations

import hashlib
import json
import time
from pathlib import Path
from typing import Protocol

from .contracts import ChunkRecord, ModelResult, ModelTask


class ModelBackend(Protocol):
    backend_id: str

    def run(self, task: ModelTask) -> tuple[dict[str, object] | None, str | None]: ...


def _canonical(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


class DisabledBackend:
    backend_id = "disabled"

    def run(self, task: ModelTask) -> tuple[dict[str, object] | None, str | None]:
        del task
        return None, "backend_disabled"


class FixtureBackend:
    backend_id = "fixture"

    def __init__(self, fixture_path: Path | None = None) -> None:
        self.fixture_path = fixture_path

    def run(self, task: ModelTask) -> tuple[dict[str, object] | None, str | None]:
        if self.fixture_path is None:
            quote = str(task.payload.get("chunk_text", ""))[:12]
            source_id = str(task.payload.get("source_id", ""))
            chunk_id = str(task.payload.get("chunk_id", ""))
            sequence = int(task.payload.get("sequence", 0))
            return {
                "entities": [],
                "facts": [{
                    "fact_id": f"fixture-{chunk_id}", "subject": "fixture_subject",
                    "predicate": "contains_text", "object": "fixture_observation",
                    "fact_type": "CANON", "confidence": 1.0,
                    "source_id": source_id, "chunk_id": chunk_id,
                    "source_quote": quote, "sequence": sequence,
                    "conditions": [], "uncertainty": "",
                }],
                "events": [], "relations": [], "rule_candidates": [], "uncertain_items": [],
            }, None
        try:
            payload = json.loads(self.fixture_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return None, "fixture_invalid"
        return payload, None


class ModelRouter:
    def __init__(self, backend: ModelBackend, model: str = "gpt-5.6-luna", cache_dir: Path | None = None) -> None:
        self.backend = backend
        self.model = model
        self.cache_dir = cache_dir
        if cache_dir is not None:
            cache_dir.mkdir(parents=True, exist_ok=True)

    def _cache_key(self, task: ModelTask) -> str:
        payload = {"task": task.__dict__, "backend": self.backend.backend_id, "model": self.model}
        return hashlib.sha256(_canonical(payload).encode("utf-8")).hexdigest()

    def run(self, task: ModelTask) -> ModelResult:
        key = self._cache_key(task)
        cache_path = self.cache_dir / f"{key}.json" if self.cache_dir else None
        if cache_path and cache_path.exists():
            output = json.loads(cache_path.read_text(encoding="utf-8"))
            return ModelResult("SUCCESS", self.backend.backend_id, self.model, output, key, 0, 0, None)
        started = time.perf_counter()
        output, error = self.backend.run(task)
        elapsed = int((time.perf_counter() - started) * 1000)
        status = "SUCCESS" if output is not None and error is None else "ISOLATED"
        raw_hash = hashlib.sha256(_canonical(output).encode("utf-8")).hexdigest() if output is not None else None
        if cache_path and status == "SUCCESS":
            cache_path.write_text(_canonical(output), encoding="utf-8")
        return ModelResult(status, self.backend.backend_id, self.model, output, raw_hash, elapsed, 0, error)


def build_model_task(chunk: ChunkRecord, context: dict[str, object]) -> ModelTask:
    payload = {
        "source_id": chunk.source_id,
        "chunk_id": chunk.chunk_id,
        "sequence": chunk.sequence,
        "title": chunk.title,
        "chunk_text": chunk.text,
        "context": context,
    }
    digest = hashlib.sha256(_canonical(payload).encode("utf-8")).hexdigest()
    return ModelTask("extract", digest, "extraction-v1", "extraction-v1", payload)
