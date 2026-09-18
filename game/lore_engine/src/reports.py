"""Deterministic database and World Model Baseline reports."""

from __future__ import annotations

import json
import hashlib
import re
from collections import Counter
from dataclasses import asdict
from pathlib import Path
from typing import Iterable

from .database import LoreDatabase
from .implementation_audit import audit_current_implementation
from .source_manifest import fingerprint_source, load_manifest
from .world_baseline import BaselineAdjudication, BaselineRow, adjudicate_baseline
from .world_claims import load_jsonl, validate_claim_set
from .world_evidence import EvidenceResolutionError, resolve_evidence


BASELINE_VERSION = "world-model-baseline-v1"
BASELINE_GENERATOR = {"name": "lore_engine.reports", "version": "1"}
_UTC_TIMESTAMP = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
_BASELINE_INPUT_PATHS = (
    "lore_sources/benchmarks/world_model_stage0/claims.jsonl",
    "lore_sources/benchmarks/world_model_stage0/decisions.jsonl",
    "lore_sources/benchmarks/world_model_stage0/evidence.jsonl",
    "lore_sources/manifest.json",
)
_MAX_IMPLEMENTATION_LOCATIONS = 12


def build_report(db: LoreDatabase) -> dict[str, object]:
    counts = {table: db.count(table) for table in ("sources", "chapters", "chunks", "entities", "facts", "events", "relations", "rule_candidates", "conflicts")}
    statuses = {
        str(status): int(amount)
        for status, amount in db.connection.execute("SELECT status, COUNT(*) FROM chunks GROUP BY status ORDER BY status")
    }
    runs = {
        str(status): int(amount)
        for status, amount in db.connection.execute("SELECT status, COUNT(*) FROM extraction_runs GROUP BY status ORDER BY status")
    }
    return {"version": "lore-v1", "counts": counts, "chunk_statuses": statuses, "extraction_runs": runs}


def write_report(report: dict[str, object], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _canonical_json(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def _validate_timestamp(value: str) -> None:
    if not _UTC_TIMESTAMP.fullmatch(value):
        raise ValueError("generated_at_utc must use YYYY-MM-DDTHH:MM:SSZ")
    try:
        from datetime import datetime

        datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ")
    except ValueError as exc:
        raise ValueError("generated_at_utc must use YYYY-MM-DDTHH:MM:SSZ") from exc


def _evidence_location(item: object) -> dict[str, object]:
    detail = asdict(item)
    detail.pop("quote", None)
    return detail


def _implementation_summary(row: BaselineRow) -> dict[str, object]:
    locations = [
        {
            "finding_id": item.finding_id,
            "path": item.path,
            "locator": item.locator,
            "behavior_status": item.behavior_status,
            "migration_action": item.migration_action,
        }
        for item in row.current_findings[:_MAX_IMPLEMENTATION_LOCATIONS]
    ]
    return {
        "finding_count": len(row.current_findings),
        "locations": locations,
        "omitted_location_count": max(0, len(row.current_findings) - len(locations)),
    }


def _claim_row(row: BaselineRow) -> dict[str, object]:
    evidence = sorted(
        (*row.support_evidence, *row.condition_evidence),
        key=lambda item: (item.evidence_id, item.source_file_id, item.char_start),
    )
    return {
        "claim_id": row.claim_id,
        "topic": row.topic,
        "impact": row.impact,
        "world_model_ruling": row.world_model_ruling,
        "derivation": row.derivation,
        "decision_kind": row.decision_kind,
        "preliminary_ruling": row.preliminary_ruling,
        "final_ruling": row.final_ruling,
        "effective_ruling": row.effective_ruling,
        "confidence": row.confidence,
        "source_fact": list(row.source_fact),
        "evidence": [_evidence_location(item) for item in evidence],
        "counter_evidence": [_evidence_location(item) for item in row.counter_evidence_details],
        "resolution_status": row.resolution_status,
        "unknowns": list(row.unknowns),
        "implementation": _implementation_summary(row),
        "player_consequence": row.player_consequence,
        "migration_deprecation_action": row.migration_deprecation_action,
    }


def _audit_digest(adjudication: BaselineAdjudication) -> str:
    findings = [
        asdict(finding)
        for row in adjudication.rows
        for finding in row.current_findings
    ]
    return hashlib.sha256(_canonical_json(findings)).hexdigest()


def build_world_baseline_report(
    repository_root: Path | str,
    *,
    generated_at_utc: str,
    config_path: Path | str = Path("lore_engine/config/world-model-stage0.json"),
) -> dict[str, object]:
    """Build the reproducible Stage 0 baseline from repository-owned inputs.

    The timestamp is mandatory caller input so a rebuild never consults the wall
    clock. Source quotes are intentionally omitted; evidence IDs and decoded
    character coordinates are sufficient to return to the read-only corpus.
    """
    _validate_timestamp(generated_at_utc)
    root = Path(repository_root).resolve(strict=True)
    configured = Path(config_path)
    configured = configured if configured.is_absolute() else root / configured
    configured = configured.resolve(strict=True)
    input_paths = (configured,) + tuple(root / relative for relative in _BASELINE_INPUT_PATHS)
    config = json.loads(input_paths[0].read_text(encoding="utf-8"))
    claims = load_jsonl((input_paths[1],), "claim")
    decisions = load_jsonl((input_paths[2],), "decision")
    evidence = load_jsonl((input_paths[3],), "evidence")
    load_errors = claims.errors + decisions.errors + evidence.errors
    if load_errors:
        first = load_errors[0]
        raise ValueError(f"invalid baseline input {first.file}:{first.line}: {first.message}")

    manifest_path = root / "lore_sources" / "manifest.json"
    specs = load_manifest(manifest_path)
    verifiable_evidence = tuple(
        item for item in evidence.records if item.evidence_kind != "unknown"
    )
    try:
        resolved_evidence = (
            resolve_evidence(root, specs, verifiable_evidence)
            if verifiable_evidence
            else ()
        )
    except EvidenceResolutionError as exc:
        raise ValueError(f"invalid baseline evidence source: {exc}") from exc
    invalid_evidence = sorted(
        (item for item in resolved_evidence if not item.ok),
        key=lambda item: item.evidence_id,
    )
    if invalid_evidence:
        first = invalid_evidence[0]
        raise ValueError(f"invalid baseline evidence {first.evidence_id}: {first.error}")

    findings = tuple(audit_current_implementation(root))
    validation = validate_claim_set(
        claims.records + evidence.records + findings + decisions.records,
        config,
    )
    if not validation.ok:
        first = validation.errors[0]
        raise ValueError(f"invalid baseline claim set: {first.code}: {first.message}")
    adjudication = adjudicate_baseline(
        claims.records, evidence.records, findings, decisions.records
    )

    source_fingerprints = []
    for spec in sorted(specs, key=lambda item: item.source_file_id):
        fingerprint = fingerprint_source(root, spec)
        source_fingerprints.append(
            {
                "source_file_id": spec.source_file_id,
                "path": spec.path,
                "encoding": spec.encoding,
                "authority": spec.authority,
                "declared_sha256": spec.expected_sha256.lower(),
                "actual_sha256": fingerprint.sha256.lower(),
                "bytes": fingerprint.bytes,
                "characters": fingerprint.characters,
            }
        )

    claim_records = tuple(claims.records)
    effective_counts = Counter(row.effective_ruling for row in adjudication.rows)
    status_counts = Counter(getattr(claim, "status") for claim in claim_records)
    unresolved = sorted(
        row.claim_id
        for row in adjudication.rows
        if row.impact == "high" and row.effective_ruling in {"defer", "needs_evidence"}
    )
    legacy = [asdict(item) for item in adjudication.legacy_dispositions]
    return {
        "baseline_version": BASELINE_VERSION,
        "generator": dict(BASELINE_GENERATOR),
        "generated_at_utc": generated_at_utc,
        "timestamp_policy": "explicit_reproducible_utc",
        "provenance": {
            "source_manifest": {
                "path": "lore_sources/manifest.json",
                "sha256": _sha256(manifest_path),
                "sources": source_fingerprints,
            },
            "input_files": [
                {"path": path.relative_to(root).as_posix(), "sha256": _sha256(path)}
                for path in sorted(input_paths, key=lambda item: item.relative_to(root).as_posix())
            ],
            "implementation_audit": {
                "finding_count": len(findings),
                "normalized_sha256": _audit_digest(adjudication),
            },
        },
        "claim_counts": {
            "total": len(adjudication.rows),
            "high_impact": sum(row.impact == "high" for row in adjudication.rows),
            "statuses": dict(sorted(status_counts.items())),
            "effective_rulings": dict(sorted(effective_counts.items())),
        },
        "unresolved_high_impact": unresolved,
        "legacy_dispositions": legacy,
        "legacy_disposition_summary": {
            item["mechanic_id"]: item["disposition"] for item in legacy
        },
        "claims": [_claim_row(row) for row in adjudication.rows],
        "stage0_gate": {
            "result": adjudication.gate_result,
            "blockers": list(adjudication.gate_blockers),
            "deterministic": True,
            "production_changes_authorized": False,
        },
        "detailed_registers": [
            "docs/lore/adaptation-register.md",
            "docs/lore/canon-index.md",
            "docs/lore/game-rule-register.md",
        ],
    }


def _md(value: object) -> str:
    text = str(value).replace("\r", " ").replace("\n", " ").replace("|", "\\|")
    return " ".join(text.split())


def _joined(values: Iterable[object], empty: str = "—") -> str:
    rendered = [_md(value) for value in values if str(value).strip()]
    return "<br>".join(rendered) if rendered else empty


def _evidence_labels(
    row: dict[str, object], field: str = "evidence"
) -> tuple[list[str], list[str]]:
    records = row[field]
    assert isinstance(records, list)
    identifiers = [str(item["evidence_id"]) for item in records]
    locations = [
        f'{item["source_file_id"]}:{item["source_ref"]}@{item["char_start"]}:{item["char_end"]}'
        for item in records
    ]
    return identifiers, locations


def render_world_baseline_markdown(report: dict[str, object]) -> str:
    """Render a concise review view without embedding copyrighted passages."""
    claims = report["claims"]
    assert isinstance(claims, list)
    provenance = report["provenance"]
    assert isinstance(provenance, dict)
    audit = provenance["implementation_audit"]
    assert isinstance(audit, dict)
    lines = [
        "# World Model Baseline v1",
        "",
        f'- 生成时间（显式 UTC）：`{_md(report["generated_at_utc"])}`',
        f'- 生成器：`{_md(report["generator"]["name"])}@{_md(report["generator"]["version"])}`',
        f'- 实现审计：`{audit["finding_count"]}` 条，规范化 SHA-256 `{audit["normalized_sha256"]}`',
        "- 本报告只保存证据 ID 与定位，不复制原文段落；详细登记见 [适配登记](../adaptation-register.md)、[正典索引](../canon-index.md) 与 [规则登记](../game-rule-register.md)。",
        "",
        "| Claim | 已核验事实 | Evidence IDs | Source locations | 偏差候选 | 冲突与未知 | 当前实现映射 | 玩家后果 | 迁移/废止说明 |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for row in claims:
        evidence_ids, locations = _evidence_labels(row)
        counter_ids, _counter_locations = _evidence_labels(row, "counter_evidence")
        implementation = row["implementation"]
        assert isinstance(implementation, dict)
        implementation_text = f'{implementation["finding_count"]} findings'
        conflicts = [*(f"反证 {item}" for item in counter_ids), *row["unknowns"]]
        lines.append(
            "| " + " | ".join(
                (
                    _md(row["claim_id"]),
                    _joined(row["source_fact"], "未核验"),
                    _joined(evidence_ids),
                    _joined(locations),
                    _md(row["preliminary_ruling"] or "—"),
                    _joined(conflicts),
                    implementation_text,
                    _md(row["player_consequence"]),
                    _md(row["migration_deprecation_action"]),
                )
            ) + " |"
        )

    lines.extend(("", "## 已核验事实", ""))
    verified = [row for row in claims if row["evidence"]]
    if not verified:
        lines.append("当前 24 条高影响 claim 均无已核验 P0 坐标；不得将候选陈述视为事实。")
    else:
        for row in verified:
            evidence_ids, locations = _evidence_labels(row)
            lines.append(
                f'- `{row["claim_id"]}`：事实：{_joined(row["source_fact"])}；'
                f'证据：{_joined(evidence_ids)}；定位：{_joined(locations)}'
            )

    lines.extend(("", "## 偏差候选", "", "| Claim | Preliminary | Effective | Confidence |", "|---|---|---|---|"))
    for row in claims:
        lines.append(f'| `{row["claim_id"]}` | {_md(row["preliminary_ruling"] or "—")} | {_md(row["effective_ruling"])} | {_md(row["confidence"])} |')

    lines.extend(("", "## 冲突与未知", ""))
    for row in claims:
        counter_ids, counter_locations = _evidence_labels(row, "counter_evidence")
        details = []
        if counter_ids:
            details.extend(
                (
                    f"反证 IDs：{_joined(counter_ids)}",
                    f"反证定位：{_joined(counter_locations)}",
                )
            )
        if row["unknowns"]:
            details.append(f'未知：{_joined(row["unknowns"])}')
        if details:
            lines.append(f'- `{row["claim_id"]}`：{"；".join(details)}')

    lines.extend(("", "## 当前实现映射", "", "以下仅为只读实现观察，不构成世界事实。每条 claim 最多展示 12 个定位；完整审计由上方规范化哈希冻结。", ""))
    for row in claims:
        implementation = row["implementation"]
        locations = implementation["locations"]
        samples = [f'{item["path"]}#{item["locator"]}' for item in locations]
        suffix = f'（另省略 {implementation["omitted_location_count"]} 条）' if implementation["omitted_location_count"] else ""
        lines.append(f'- `{row["claim_id"]}`：{implementation["finding_count"]} 条；{_joined(samples)}{suffix}')

    lines.extend(("", "## 玩家后果", ""))
    lines.extend(f'- `{row["claim_id"]}`：{_md(row["player_consequence"])}' for row in claims)

    lines.extend(("", "## 迁移/废止说明", ""))
    lines.extend(f'- `{row["claim_id"]}`：{_md(row["migration_deprecation_action"])}' for row in claims)
    lines.extend(("", "Legacy dispositions:", ""))
    for item in report["legacy_dispositions"]:
        lines.append(f'- `{item["mechanic_id"]}` → `{item["disposition"]}`：{_md(item["rationale"])}')

    gate = report["stage0_gate"]
    counts = report["claim_counts"]
    lines.extend(
        (
            "",
            "## Stage 0 Gate",
            "",
            f'- 结果：**{gate["result"]}**',
            f'- Claims：{counts["total"]}（high impact: {counts["high_impact"]}）',
            f'- 未解决高影响项：{len(report["unresolved_high_impact"])}',
            f'- Blockers：{_joined(gate["blockers"])}',
            "- 生产改动授权：否。Stage 0 未通过前不得将候选裁定写入运行时代码或数据。",
            "",
        )
    )
    return "\n".join(lines)


def write_world_baseline_outputs(report: dict[str, object], output_dir: Path | str) -> tuple[Path, Path]:
    """Write canonical LF-terminated JSON and Markdown baseline artifacts."""
    directory = Path(output_dir)
    directory.mkdir(parents=True, exist_ok=True)
    json_path = directory / f"{BASELINE_VERSION}.json"
    markdown_path = directory / f"{BASELINE_VERSION}.md"
    json_path.write_bytes(json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2).encode("utf-8") + b"\n")
    markdown_path.write_bytes(render_world_baseline_markdown(report).encode("utf-8"))
    return json_path, markdown_path
