"""Command-line entry point for Lore Compiler V1."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
import subprocess
import sys
from pathlib import Path

from . import __version__
from .src.chunker import iter_chunks, parse_sections
from .src.contracts import ChunkConfig, ChunkRecord
from .src.database import LoreDatabase
from .src.model_router import DisabledBackend, FixtureBackend, ModelRouter
from .src.pipeline import Pipeline
from .src.reports import (
    build_report,
    build_world_baseline_report,
    render_world_baseline_markdown,
    write_report,
    write_world_baseline_outputs,
)
from .src.seeds import import_seeds, load_seed_records
from .src.source_manifest import fingerprint_source, load_manifest, read_source


COMMANDS = ("ingest", "index", "run", "retry", "validate", "report", "world-model-0")
DEFAULT_STAGE0_TIMESTAMP = "2026-09-16T08:20:35Z"
GATE_REPORT_NAME = "world-model-stage0-gate.md"
PRE_STAGE0_BASELINE_COMMIT = "b2aeb2e5cb854cb2ee2cea12647cd6fadd46aa7d"
MANDATORY_PRODUCTION_DENYLIST = ("data/", "scripts/", "scenes/")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="lore-compiler",
        description="Evidence-first local Lore Compiler V1.",
    )
    parser.add_argument("--version", action="version", version=__version__)
    subparsers = parser.add_subparsers(dest="command")
    for command in COMMANDS:
        subparsers.add_parser(command, help=f"Run the {command} pipeline step.")
    ingest = subparsers.choices["ingest"]
    ingest.add_argument("--manifest", type=Path, default=Path("lore_sources/manifest.json"))
    ingest.add_argument("--verify-only", action="store_true")
    index = subparsers.choices["index"]
    index.add_argument("--source-file-id", default="gu_zhenren_main")
    index.add_argument("--section-limit", type=int, default=10)
    index.add_argument("--database", type=Path, default=Path("generated/lore/lore-v1.sqlite"))
    seed_import = subparsers.add_parser("seed-import", help="Import append-only V0 seed records.")
    seed_import.add_argument("--database", type=Path, default=Path("generated/lore/lore-v1.sqlite"))
    seed_import.add_argument("--seed-dir", type=Path, default=Path("lore_sources/seeds"))
    run = subparsers.choices["run"]
    run.add_argument("--backend", choices=("fixture", "disabled"), default="fixture")
    run.add_argument("--database", type=Path, default=Path("generated/lore/lore-v1.sqlite"))
    run.add_argument("--dry-run", action="store_true")
    run.add_argument("--stop-after", type=int)
    run.add_argument("--resume", action="store_true")
    retry = subparsers.choices["retry"]
    retry.add_argument("--database", type=Path, default=Path("generated/lore/lore-v1.sqlite"))
    validate = subparsers.choices["validate"]
    validate.add_argument("--database", type=Path, default=Path("generated/lore/lore-v1.sqlite"))
    report = subparsers.choices["report"]
    report.add_argument("--database", type=Path, default=Path("generated/lore/lore-v1.sqlite"))
    report.add_argument("--out", type=Path, default=Path("generated/lore/reports/lore-v1.json"))
    stage0 = subparsers.choices["world-model-0"]
    stage0.add_argument("--config", type=Path, default=Path("lore_engine/config/world-model-stage0.json"))
    stage0.add_argument("--out", type=Path, default=Path("generated/lore/world-model-stage0"))
    stage0.add_argument("--generated-at-utc", default=DEFAULT_STAGE0_TIMESTAMP)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.command is None:
        parser.print_help()
        return 0
    if args.command == "ingest" and args.verify_only:
        return _verify_sources(args.manifest)
    if args.command == "index":
        return _index_source(args)
    if args.command == "seed-import":
        return _import_seeds(args)
    if args.command == "run":
        return _extract(args)
    if args.command == "retry":
        return _retry(args)
    if args.command == "validate":
        return _validate(args)
    if args.command == "report":
        return _report(args)
    if args.command == "world-model-0":
        return _world_model_stage0(args)
    print(f"{args.command}: not implemented")
    return 2


def _verify_sources(manifest_path: Path) -> int:
    root = Path(__file__).resolve().parents[1]
    try:
        specs = load_manifest(root / manifest_path)
        for spec in specs:
            fingerprint = fingerprint_source(root, spec)
            print(json.dumps(fingerprint.__dict__, ensure_ascii=False, sort_keys=True))
        primary = next((spec for spec in specs if spec.source_file_id == "gu_zhenren_main"), None)
        if primary is not None:
            sections = parse_sections(read_source(root, primary))
            print(f"selected_sections={len(sections)}")
        return 0
    except (OSError, UnicodeError, ValueError, TypeError) as exc:
        print(f"ingest: {exc}", file=sys.stderr)
        return 2


def _index_source(args: argparse.Namespace) -> int:
    root = Path(__file__).resolve().parents[1]
    try:
        specs = load_manifest(root / "lore_sources/manifest.json")
        spec = next(item for item in specs if item.source_file_id == args.source_file_id)
        text = read_source(root, spec)
        source = fingerprint_source(root, spec)
        sections = parse_sections(text, section_limit=args.section_limit)
        config = ChunkConfig(target_chars=6000, max_chars=8000, min_chars=3000)
        chunks = tuple(
            chunk
            for section in sections
            for chunk in iter_chunks(section, section.text, config)
        )
        db = LoreDatabase.open(root / args.database)
        try:
            db.migrate()
            db.upsert_source(source)
            db.replace_sections_and_chunks(spec.source_file_id, sections, chunks)
            print(
                json.dumps(
                    {
                        "sections": len(sections),
                        "chunks": len(chunks),
                        "characters": sum(len(section.text) for section in sections),
                    },
                    ensure_ascii=False,
                    sort_keys=True,
                )
            )
        finally:
            db.close()
        return 0
    except (OSError, UnicodeError, ValueError, StopIteration, sqlite3.Error) as exc:
        print(f"index: {exc}", file=sys.stderr)
        return 2


def _import_seeds(args: argparse.Namespace) -> int:
    root = Path(__file__).resolve().parents[1]
    try:
        db = LoreDatabase.open(root / args.database)
        try:
            db.migrate()
            summary = import_seeds(db, load_seed_records(root / args.seed_dir))
            print(json.dumps(summary.__dict__, ensure_ascii=False, sort_keys=True))
        finally:
            db.close()
        return 0
    except (OSError, ValueError, sqlite3.Error) as exc:
        print(f"seed-import: {exc}", file=sys.stderr)
        return 2


def _indexed_chunks(db: LoreDatabase) -> list[ChunkRecord]:
    rows = db.connection.execute(
        "SELECT chunk_id, source_id, source_file_id, volume, chapter, title, sequence, chunk_sequence, start_offset, end_offset, start_byte, end_byte, text, chunk_hash, previous_id, next_id, status FROM chunks ORDER BY sequence, chunk_sequence"
    ).fetchall()
    return [ChunkRecord(*row) for row in rows]


def _extract(args: argparse.Namespace) -> int:
    root = Path(__file__).resolve().parents[1]
    try:
        db = LoreDatabase.open(root / args.database)
        try:
            db.migrate()
            backend = FixtureBackend() if args.backend == "fixture" else DisabledBackend()
            router = ModelRouter(backend, cache_dir=root / "generated/lore/cache")
            summary = Pipeline(db, router).run(
                _indexed_chunks(db),
                dry_run=args.dry_run,
                stop_after=args.stop_after,
                resume=args.resume,
            )
            print(json.dumps(summary.__dict__, ensure_ascii=False, sort_keys=True))
            return 4 if summary.failed else 0
        finally:
            db.close()
    except (OSError, ValueError, sqlite3.Error) as exc:
        print(f"extract: {exc}", file=sys.stderr)
        return 2


def _retry(args: argparse.Namespace) -> int:
    root = Path(__file__).resolve().parents[1]
    try:
        db = LoreDatabase.open(root / args.database)
        try:
            db.migrate()
            summary = Pipeline(db, ModelRouter(FixtureBackend(), cache_dir=root / "generated/lore/cache")).retry(_indexed_chunks(db))
            print(json.dumps(summary.__dict__, ensure_ascii=False, sort_keys=True))
            return 4 if summary.failed else 0
        finally:
            db.close()
    except (OSError, ValueError, sqlite3.Error) as exc:
        print(f"retry: {exc}", file=sys.stderr)
        return 2


def _validate(args: argparse.Namespace) -> int:
    root = Path(__file__).resolve().parents[1]
    try:
        db = LoreDatabase.open(root / args.database)
        try:
            db.migrate()
            invalid = db.connection.execute(
                "SELECT chunk_id, status FROM chunks WHERE status NOT IN ('PENDING', 'RUNNING', 'SUCCESS', 'FAILED', 'NEEDS_REVIEW')"
            ).fetchall()
            if invalid:
                print(json.dumps({"invalid_chunks": invalid}, ensure_ascii=False), file=sys.stderr)
                return 3
            print(json.dumps(build_report(db), ensure_ascii=False, sort_keys=True))
            return 0
        finally:
            db.close()
    except (OSError, sqlite3.Error) as exc:
        print(f"validate: {exc}", file=sys.stderr)
        return 2


def _report(args: argparse.Namespace) -> int:
    root = Path(__file__).resolve().parents[1]
    try:
        db = LoreDatabase.open(root / args.database)
        try:
            db.migrate()
            write_report(build_report(db), root / args.out)
        finally:
            db.close()
        return 0
    except (OSError, sqlite3.Error) as exc:
        print(f"report: {exc}", file=sys.stderr)
        return 2


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _resolve_pre_stage0_baseline(root: Path, baseline: object) -> str:
    if not isinstance(baseline, str) or re.fullmatch(r"[0-9a-fA-F]{40}", baseline) is None:
        raise ValueError("pre-Stage-0 baseline must be a full 40-character commit hash")
    resolved = subprocess.run(
        ("git", "rev-parse", "--verify", f"{baseline}^{{commit}}"),
        cwd=root,
        capture_output=True,
        text=True,
    )
    if resolved.returncode != 0:
        raise ValueError(f"pre-Stage-0 baseline does not resolve to a commit: {baseline}")
    commit = resolved.stdout.strip()
    ancestor = subprocess.run(
        ("git", "merge-base", "--is-ancestor", commit, "HEAD"),
        cwd=root,
        capture_output=True,
        text=True,
    )
    if ancestor.returncode == 1:
        raise ValueError(f"pre-Stage-0 baseline is not an ancestor of HEAD: {commit}")
    if ancestor.returncode != 0:
        detail = ancestor.stderr.strip() or "git merge-base failed"
        raise ValueError(f"could not validate pre-Stage-0 baseline: {detail}")
    return commit


def _git_changed_paths(root: Path, baseline: object) -> tuple[str, ...]:
    commit = _resolve_pre_stage0_baseline(root, baseline)
    commands = (
        ("git", "diff", "--name-only", "--no-renames", commit, "--"),
        ("git", "ls-files", "--others", "--exclude-standard"),
    )
    changed: set[str] = set()
    for command in commands:
        completed = subprocess.run(
            command,
            cwd=root,
            capture_output=True,
            text=True,
            check=True,
        )
        changed.update(
            line.strip().replace("\\", "/")
            for line in completed.stdout.splitlines()
            if line.strip()
        )
    return tuple(sorted(changed))


def _configured_pre_stage0_baseline(root: Path, config: dict[str, object]) -> str:
    configured = config.get("pre_stage0_baseline_commit")
    if configured != PRE_STAGE0_BASELINE_COMMIT:
        raise ValueError(
            "fixed pre-Stage-0 baseline must be "
            f"{PRE_STAGE0_BASELINE_COMMIT}, got {configured!r}"
        )
    return _resolve_pre_stage0_baseline(root, configured)


def _is_under_prefix(path: str, prefix: str) -> bool:
    normalized = path.replace("\\", "/").lstrip("./")
    normalized_prefix = prefix.replace("\\", "/").strip("/")
    return normalized == normalized_prefix or normalized.startswith(normalized_prefix + "/")


def _production_denylist(config: dict[str, object]) -> tuple[str, ...]:
    configured = tuple(str(item) for item in config.get("production_write_denylist", ()))
    return tuple(dict.fromkeys((*MANDATORY_PRODUCTION_DENYLIST, *configured)))


def _production_diff_mentions_legacy(
    root: Path,
    baseline: str,
    paths: tuple[str, ...],
) -> bool:
    if not paths:
        return False
    completed = subprocess.run(
        ("git", "diff", "--no-ext-diff", baseline, "--", *paths),
        cwd=root,
        capture_output=True,
        text=True,
        check=True,
    )
    text = completed.stdout
    for relative in paths:
        candidate = root / relative
        if candidate.is_file() and relative not in completed.stdout:
            try:
                text += "\n" + candidate.read_text(encoding="utf-8")
            except (OSError, UnicodeError):
                continue
    return re.search(r"\b(?:Q8[-_ ]?G|F1)\b", text, re.IGNORECASE) is not None


def _provenance_ok(report: dict[str, object]) -> bool:
    try:
        provenance = report["provenance"]
        manifest = provenance["source_manifest"]
        sources = manifest["sources"]
        input_files = provenance["input_files"]
        return (
            len(str(manifest["sha256"])) == 64
            and all(item["declared_sha256"] == item["actual_sha256"] for item in sources)
            and all(len(str(item["sha256"])) == 64 for item in input_files)
        )
    except (KeyError, TypeError):
        return False


def _complete_p0_reference(row: dict[str, object], p0_source_ids: set[str]) -> bool:
    evidence = (*row.get("evidence", ()), *row.get("counter_evidence", ()))

    def complete(item: object) -> bool:
        return (
            isinstance(item, dict)
            and bool(item.get("evidence_id"))
            and bool(item.get("source_file_id"))
            and bool(item.get("source_ref"))
            and isinstance(item.get("char_start"), int)
            and isinstance(item.get("char_end"), int)
            and item["char_end"] > item["char_start"] >= 0
            and item.get("authority") in {"primary_text", "in_world_text"}
            and item.get("evidence_kind") in {"support", "condition", "counterexample"}
        )

    return row.get("impact") == "high" and bool(evidence) and all(
        complete(item) for item in evidence
    ) and any(
        isinstance(item, dict)
        and item.get("source_file_id") in p0_source_ids
        and item.get("authority") in {"primary_text", "in_world_text"}
        and item.get("evidence_kind") in {"support", "condition"}
        for item in evidence
    )


def _evaluate_stage0_gate(
    report: dict[str, object],
    config: dict[str, object],
    changed_paths: tuple[str, ...],
    *,
    deterministic: bool,
    q8g_f1_production_change: bool,
) -> dict[str, object]:
    claims = report.get("claims", ())
    assert isinstance(claims, list)
    targets = tuple(str(item) for item in config.get("high_impact_claim_ids", ()))
    target_set = set(targets)
    rows_by_topic = {str(row.get("topic")): row for row in claims if isinstance(row, dict)}
    missing_topics = sorted(target_set - set(rows_by_topic))
    p0_source_ids = {str(item) for item in config.get("p0_source_ids", ())}
    complete = sorted(
        topic
        for topic in sorted(target_set)
        if topic in rows_by_topic and _complete_p0_reference(rows_by_topic[topic], p0_source_ids)
    )
    incomplete_high = sorted(target_set - set(complete))
    minimum = int(config.get("minimum_claims", 20))
    unresolved_p0 = sorted(
        str(row.get("claim_id"))
        for row in claims
        if isinstance(row, dict)
        and row.get("impact") == "high"
        and row.get("resolution_status") == "unresolved"
        and any(
            item.get("authority") in {"primary_text", "in_world_text"}
            for item in (*row.get("evidence", ()), *row.get("counter_evidence", ()))
            if isinstance(item, dict)
        )
    )
    removal_without_migration = sorted(
        str(row.get("claim_id"))
        for row in claims
        if isinstance(row, dict)
        and row.get("effective_ruling") == "remove"
        and (
            not re.search(
                r"migrat|deprecat",
                str(row.get("migration_deprecation_action", "")),
                re.IGNORECASE,
            )
        )
    )
    denylist = _production_denylist(config)
    production_changes = tuple(
        path for path in changed_paths if any(_is_under_prefix(path, prefix) for prefix in denylist)
    )
    high_deferred = sorted(
        str(row.get("claim_id"))
        for row in claims
        if isinstance(row, dict)
        and row.get("impact") == "high"
        and row.get("effective_ruling") in {"defer", "needs_evidence"}
    )
    non_blocking_deferred = sorted(
        str(row.get("claim_id"))
        for row in claims
        if isinstance(row, dict)
        and row.get("impact") != "high"
        and row.get("effective_ruling") in {"defer", "needs_evidence"}
    )
    legacy = report.get("legacy_disposition_summary", {})
    legacy_safe = isinstance(legacy, dict) and all(
        legacy.get(mechanic) in {"audit_only", "defer"}
        for mechanic in ("q8g_promotion_chain", "f1_pity")
    )

    blockers: list[str] = []
    if len(complete) < minimum:
        blockers.append(f"high-impact complete references {len(complete)} < {minimum}")
    if len(targets) != 24:
        blockers.append(f"configured target topic count {len(targets)} != 24")
    if len(target_set) != 24:
        blockers.append(f"configured unique target topic count {len(target_set)} != 24")
    if missing_topics:
        blockers.append("missing target topics: " + ", ".join(missing_topics))
    if incomplete_high:
        blockers.append("high-impact claims missing complete P0 references: " + ", ".join(incomplete_high))
    if high_deferred:
        blockers.append("unresolved high-impact claims: " + ", ".join(high_deferred))
    if unresolved_p0:
        blockers.append("unresolved P0 conflicts: " + ", ".join(unresolved_p0))
    if not _provenance_ok(report):
        blockers.append("provenance verification failed")
    if not deterministic:
        blockers.append("repeated output is not deterministic")
    if production_changes:
        blockers.append("forbidden production paths changed: " + ", ".join(production_changes))
    if removal_without_migration:
        blockers.append("removals missing migration/deprecation: " + ", ".join(removal_without_migration))
    if not legacy_safe:
        blockers.append("Q8-G/F1 legacy disposition is production-ready or missing")
    if q8g_f1_production_change:
        blockers.append("Q8-G/F1 production change detected")

    result = "NO_GO" if blockers else "CONDITIONAL_GO" if non_blocking_deferred else "GO"
    return {
        "result": result,
        "blockers": blockers,
        "claim_count": len(claims),
        "target_topic_count": len(target_set),
        "high_impact_covered": len(complete),
        "missing_topics": missing_topics,
        "incomplete_high_impact": incomplete_high,
        "unresolved_high_impact": high_deferred,
        "unresolved_p0_conflicts": unresolved_p0,
        "non_blocking_deferred": non_blocking_deferred,
        "production_paths_changed": list(production_changes),
        "q8g_f1_production_change": q8g_f1_production_change,
        "removals_without_migration": removal_without_migration,
        "deterministic": deterministic,
        "provenance_verified": _provenance_ok(report),
    }


def _render_stage0_gate(
    report: dict[str, object],
    gate: dict[str, object],
    command: str,
    output_hashes: dict[str, str],
) -> str:
    provenance = report["provenance"]
    sources = provenance["source_manifest"]["sources"]
    lines = [
        "# World Model Stage 0 Gate",
        "",
        f'- Result: **{gate["result"]}**',
        f"- Exact command: `{command}`",
        f'- Deterministic repeated output: `{str(gate["deterministic"]).lower()}`',
        f'- Provenance verified: `{str(gate["provenance_verified"]).lower()}`',
        "",
        "## Source hashes",
        "",
    ]
    lines.extend(
        f'- `{item["source_file_id"]}`: `{item["actual_sha256"]}`'
        for item in sources
    )
    lines.extend(("", "## Output hashes", ""))
    lines.extend(f'- `{name}`: `{digest}`' for name, digest in sorted(output_hashes.items()))
    lines.extend(
        (
            "",
            "## Claim coverage",
            "",
            f'- Target topics represented: `{gate["target_topic_count"] - len(gate["missing_topics"])}/{gate["target_topic_count"]}`',
            f'- High-impact claims with complete P0 references: `{gate["high_impact_covered"]}`',
            f'- Total baseline rows: `{gate["claim_count"]}`',
            "",
            "## Unresolved items",
            "",
        )
    )
    unresolved = gate["unresolved_high_impact"]
    lines.extend((f"- `{item}`" for item in unresolved),)
    if not unresolved:
        lines.append("- None.")
    conflicts = gate["unresolved_p0_conflicts"]
    lines.append(
        "- Unresolved P0 conflicts: "
        + (", ".join(f"`{item}`" for item in conflicts) if conflicts else "None.")
    )
    deferred = gate["non_blocking_deferred"]
    lines.append(
        "- Non-blocking deferred claims: "
        + (", ".join(f"`{item}`" for item in deferred) if deferred else "None.")
    )
    lines.extend(("", "## Legacy dispositions", ""))
    lines.extend(
        f'- `{item["mechanic_id"]}` -> `{item["disposition"]}`: {item["rationale"]}'
        for item in report["legacy_dispositions"]
    )
    lines.extend(("", "## Production boundary", ""))
    changed = gate["production_paths_changed"]
    lines.append("- Changed forbidden paths: " + (", ".join(f"`{item}`" for item in changed) if changed else "None."))
    blockers = gate["blockers"]
    lines.append("- Gate blockers: " + ("; ".join(str(item) for item in blockers) if blockers else "None."))
    lines.extend(
        (
            "",
            "## Forbidden follow-up actions before Gate approval",
            "",
            "- Do not modify `data/`, `scripts/`, or `scenes/` from Stage 0 findings.",
            "- Do not implement or restore Q8-G promotion or F1 Pity behavior.",
            "- Do not migrate saves, remove legacy fields, or silently preserve deprecated behavior.",
            "- Do not start the vertical-slice production implementation until this Gate is reviewed and approved.",
            "",
        )
    )
    return "\n".join(lines)


def _display_path(root: Path, path: Path) -> str:
    try:
        return path.resolve().relative_to(root).as_posix()
    except ValueError:
        return path.resolve().as_posix()


def _world_model_stage0(args: argparse.Namespace) -> int:
    root = Path(__file__).resolve().parents[1]
    try:
        config_path = args.config if args.config.is_absolute() else root / args.config
        config_path = config_path.resolve(strict=True)
        config = json.loads(config_path.read_text(encoding="utf-8"))
        baseline = _configured_pre_stage0_baseline(root, config)
        output_dir = args.out if args.out.is_absolute() else root / args.out
        output_dir = output_dir.resolve()
        try:
            output_relative = output_dir.relative_to(root).as_posix()
        except ValueError:
            output_relative = ""
        denylist = _production_denylist(config)
        if output_relative and any(_is_under_prefix(output_relative, prefix) for prefix in denylist):
            raise ValueError(f"output directory is a forbidden production path: {output_relative}")

        first = build_world_baseline_report(
            root,
            generated_at_utc=args.generated_at_utc,
            config_path=config_path,
        )
        second = build_world_baseline_report(
            root,
            generated_at_utc=args.generated_at_utc,
            config_path=config_path,
        )
        deterministic = (
            json.dumps(first, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
            == json.dumps(second, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
            and render_world_baseline_markdown(first) == render_world_baseline_markdown(second)
        )
        changed_paths = _git_changed_paths(root, baseline)
        production_paths = tuple(
            path for path in changed_paths if any(_is_under_prefix(path, prefix) for prefix in denylist)
        )
        legacy_change = _production_diff_mentions_legacy(root, baseline, production_paths)
        gate = _evaluate_stage0_gate(
            first,
            config,
            changed_paths,
            deterministic=deterministic,
            q8g_f1_production_change=legacy_change,
        )
        first["stage0_gate"] = {
            "result": gate["result"],
            "blockers": gate["blockers"],
            "deterministic": gate["deterministic"],
            "production_changes_authorized": False,
            "production_paths_changed": gate["production_paths_changed"],
        }
        json_path, markdown_path = write_world_baseline_outputs(first, output_dir)
        output_hashes = {
            json_path.name: _sha256(json_path),
            markdown_path.name: _sha256(markdown_path),
        }
        command = (
            "tools/lore.ps1 world-model-0 "
            f"--config {_display_path(root, config_path)} "
            f"--out {_display_path(root, output_dir)}"
        )
        gate_path = output_dir / GATE_REPORT_NAME
        gate_path.write_text(
            _render_stage0_gate(first, gate, command, output_hashes),
            encoding="utf-8",
            newline="\n",
        )
        print(
            json.dumps(
                {
                    "result": gate["result"],
                    "gate_report": _display_path(root, gate_path),
                    "blockers": gate["blockers"],
                },
                ensure_ascii=False,
                sort_keys=True,
            )
        )
        return 3 if gate["result"] == "NO_GO" else 0
    except (OSError, UnicodeError, ValueError, TypeError, json.JSONDecodeError, subprocess.SubprocessError) as exc:
        print(f"world-model-0: {exc}", file=sys.stderr)
        return 2
    except Exception as exc:  # pragma: no cover - defensive CLI boundary
        print(f"world-model-0: internal error: {exc}", file=sys.stderr)
        return 5


if __name__ == "__main__":
    sys.exit(main())
