"""Command-line entry point for Lore Compiler V1."""

from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from pathlib import Path

from . import __version__
from .src.chunker import iter_chunks, parse_sections
from .src.contracts import ChunkConfig, ChunkRecord
from .src.database import LoreDatabase
from .src.model_router import DisabledBackend, FixtureBackend, ModelRouter
from .src.pipeline import Pipeline
from .src.reports import build_report, write_report
from .src.seeds import import_seeds, load_seed_records
from .src.source_manifest import fingerprint_source, load_manifest, read_source


COMMANDS = ("ingest", "index", "run", "retry", "validate", "report")


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


if __name__ == "__main__":
    sys.exit(main())
