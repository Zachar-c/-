# Lore Compiler V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local, resumable Lore Compiler V1 that indexes and extracts evidence-backed structured knowledge from the first 10 canonical sections of Volume 1 without modifying Godot runtime data or source material.

**Architecture:** Use a standalone `lore_engine` Python CLI beside the Godot project. Strictly read the primary UTF-8 corpus, identify the first 10 unindented section headings, create contiguous non-overlapping chunks, validate controlled extraction JSON, and persist accepted records plus checkpoint state in SQLite. Use a fixture backend for the deterministic offline dry-run and keep the Luna HTTP adapter isolated behind the same `ModelTask -> ModelResult` contract.

**Tech Stack:** Python 3.12 standard library (`argparse`, `dataclasses`, `hashlib`, `json`, `pathlib`, `sqlite3`, `unittest`, `urllib`), SQLite with FTS5, PowerShell 7, JSON Schema files, and Markdown reports. The repository-provided Python runtime must be locatable through `tools/lore.ps1`; no third-party Python package is required.

## Global Constraints

- The authoritative implementation specification is `docs/superpowers/specs/2026-09-11-lore-compiler-v1-design.md`.
- The primary text `分支：六卷精编版/蛊真人-clean.txt` is read-only, strict UTF-8, and must match SHA-256 `BF78D41427E28BB8B64F1AD6D93B971D1A77458ABF273E554AABE7F27A155D34`.
- `分支：六卷精编版/《人祖传》.txt` is read-only, strict GB18030, and is registered separately as `in_world_lore`; it is not part of the 10-section dry-run.
- Only the first 10 unindented section headings after `第一卷：魔性不改` are canonical for this run; indented duplicate headings are diagnostics, not chapters.
- `sequence` is the global appearance order; the local novel section number is not sufficient as a stable identity.
- Canonical chunks are contiguous and non-overlapping. Context is represented by links and selected context metadata, never by duplicating canonical text.
- Lore levels are `CANON`, `INFERRED`, `ADAPTATION`, and `GAME_ORIGINAL`; lower levels never overwrite higher levels.
- Every accepted fact requires a valid source/chunk reference and a quote that matches the source text verbatim.
- Model output is never trusted directly. Parse, schema, reference, enum, confidence, quote, and duplicate validation happens before formal writes.
- Failed or invalid extraction is isolated in `extraction_runs`; it never partially writes formal facts, entities, events, relations, or rule candidates.
- Each chunk is checkpointed with `PENDING`, `RUNNING`, `SUCCESS`, `FAILED`, or `NEEDS_REVIEW`; resume and retry must be idempotent.
- Existing `docs/lore` material is imported as seed data without deleting or rewriting it. Seed content remains distinguishable from model extraction.
- V1 never writes `data/*.json`, `scripts/`, `scenes/`, `ui/`, the source corpus, or existing Godot tests.
- Generated SQLite, cache, checkpoint, and report files live under `generated/lore/` and are ignored by Git.
- Never stage or commit unrelated existing changes in the working tree.

## File Responsibility Map

The implementation should use focused modules with these responsibilities:

```text
lore_engine/
  __init__.py                 package marker and version
  cli.py                      command parser and exit-code mapping
  config/default.json         paths, chunk settings, backend defaults
  migrations/001_initial.sql  SQLite schema and FTS5 table
  schemas/extraction-v1.json  model output contract
  prompts/extraction-v1.txt   short cacheable extraction prefix
  src/contracts.py            dataclasses, enums, canonical JSON helpers
  src/source_manifest.py      strict source loading and fingerprints
  src/chunker.py              heading parsing and contiguous chunks
  src/database.py             migration and transactional repository
  src/validator.py            extraction and source-reference validation
  src/model_router.py         disabled, fixture, and HTTP Luna adapters
  src/seeds.py                seed_canon/inferred/note/game_design import
  src/pipeline.py             checkpointed extraction orchestration
  src/reports.py              deterministic dry-run and validation reports
  tests/                      unittest suite and fixtures

lore_sources/
  manifest.json               source declarations and immutable fingerprints
  seeds/                      normalized seed import inputs

generated/lore/                ignored runtime output
tools/lore.ps1                 PowerShell entry point and Python discovery
```

No Godot module is added in this plan. `ContentCatalog` remains the only runtime JSON loader and is not modified.

---

### Task 1: CLI and Runtime Scaffold

**Files:**
- Create: `lore_engine/__init__.py`
- Create: `lore_engine/cli.py`
- Create: `lore_engine/tests/__init__.py`
- Create: `lore_engine/tests/test_cli.py`
- Create: `tools/lore.ps1`
- Modify: `.gitignore`

**Interfaces:**
- `lore_engine.cli.main(argv: list[str] | None = None) -> int`
- `tools/lore.ps1` forwards all arguments to `python -m lore_engine.cli`.
- Supported top-level commands are `ingest`, `index`, `run`, `retry`, `validate`, and `report`.
- Exit codes are `0` success, `2` configuration/input error, `3` validation/quality failure, `4` quarantined task, and `5` unexpected error.

- [ ] **Step 1: Write the failing CLI tests.**

Add tests that run the module through `subprocess` with the workspace Python executable and assert:

```python
result = run_cli(["--help"])
assert result.returncode == 0
for name in ("ingest", "index", "run", "retry", "validate", "report"):
    assert name in result.stdout
```

Add a test that an unknown command returns exit code `2`, and a test that `--version` returns the package version without touching the source corpus.

- [ ] **Step 2: Run the tests and confirm failure.**

Run:

```powershell
$py = 'C:\Users\Zachary\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $py -m unittest lore_engine.tests.test_cli -v
```

Expected: FAIL because `lore_engine` and the CLI do not yet exist.

- [ ] **Step 3: Implement the minimal parser and runtime locator.**

`tools/lore.ps1` must resolve the Python executable in this order: `-PythonPath` parameter, `LORE_PYTHON` environment variable, the workspace dependency path from the current machine, then `python` on `PATH`. If none exists, print an actionable error and exit `2`. Do not install packages or download anything.

The parser must register all six commands, even if later commands initially return a controlled “not implemented” exit `2`.

- [ ] **Step 4: Add generated-output ignores and pass the tests.**

Add only these ignore rules if absent:

```gitignore
generated/lore/
lore_engine/__pycache__/
**/__pycache__/
```

Run the focused unittest and `git diff --check`. Verify `git status --short` shows no changes outside the new scaffold and unrelated pre-existing work remains untouched.

- [ ] **Step 5: Commit the scaffold.**

```powershell
git add .gitignore lore_engine tools/lore.ps1
git commit -m "build(lore): scaffold compiler cli"
```

---

### Task 2: Immutable Source Manifest and 10-Section Index

**Files:**
- Create: `lore_sources/manifest.json`
- Create: `lore_engine/config/default.json`
- Create: `lore_engine/src/contracts.py`
- Create: `lore_engine/src/source_manifest.py`
- Create: `lore_engine/src/chunker.py`
- Create: `lore_engine/tests/test_source_manifest.py`
- Create: `lore_engine/tests/test_section_index.py`
- Modify: `lore_engine/cli.py`

**Interfaces:**
- `load_manifest(path: Path) -> tuple[SourceSpec, ...]`
- `read_source(root: Path, spec: SourceSpec) -> str`
- `fingerprint_source(root: Path, spec: SourceSpec) -> SourceFingerprint`
- `parse_sections(text: str, volume_limit: int = 1, section_limit: int = 10) -> tuple[SectionRecord, ...]`
- `byte_offset_map(text: str) -> list[int]`

- [ ] **Step 1: Write source and section tests.**

Tests must cover:

```python
assert read_source(root, utf8_spec) == expected_text
with self.assertRaises(UnicodeDecodeError):
    read_source(root, wrong_encoding_spec)
with self.assertRaises(SourceFingerprintError):
    fingerprint_source(root, tampered_spec)
sections = parse_sections(real_text, section_limit=10)
assert len(sections) == 10
assert [s.sequence for s in sections] == list(range(1, 11))
assert sections[0].volume == 1
assert sections[0].chapter == 1
assert sections[0].title == "第一节：纵身亡魔心仍不悔"
```

Use a small synthetic fixture to prove an indented duplicate heading is ignored and a repeated local section number in a later volume cannot overwrite an earlier record. Assert that the source file mtime and SHA remain unchanged after reading.

- [ ] **Step 2: Run the tests and confirm failure.**

```powershell
& $py -m unittest lore_engine.tests.test_source_manifest lore_engine.tests.test_section_index -v
```

Expected: FAIL because the contracts and parsers do not exist.

- [ ] **Step 3: Add the manifest and strict reader.**

Declare both source files:

```json
[
  {
    "source_file_id": "gu_zhenren_main",
    "path": "分支：六卷精编版/蛊真人-clean.txt",
    "encoding": "utf-8",
    "authority": "primary_text",
    "default_claim_type": "CANON",
    "expected_sha256": "BF78D41427E28BB8B64F1AD6D93B971D1A77458ABF273E554AABE7F27A155D34"
  },
  {
    "source_file_id": "ren_zu_zhuan",
    "path": "分支：六卷精编版/《人祖传》.txt",
    "encoding": "gb18030",
    "authority": "in_world_text",
    "default_claim_type": "IN_WORLD_LORE",
    "expected_sha256": "E6A6A6187EC69D36957DEFAC0AA644CEC494FE2C1B2D2E6C13969FE460B9CAB8"
  }
]
```

The reader must resolve paths under the repository root, reject traversal, read bytes, decode with `errors="strict"`, and compare the expected digest before returning text. Do not normalize line endings or whitespace.

- [ ] **Step 4: Implement heading parsing and section identities.**

Recognize only headings matching an unindented line of `第...卷：...` or `第...节：...`. After the first Volume 1 heading, take the first 10 unindented section headings. Preserve the original heading text after outer line trimming. Store both local `chapter` and global `sequence`; use `V01-C001` through `V01-C010` for this batch.

Build a character-to-byte offset map from the original decoded text. Do not use re-encoded substring lengths as a substitute for a map.

- [ ] **Step 5: Wire `ingest --verify-only` and verify.**

The command must print source file ID, encoding, bytes, decoded characters, SHA-256, and the selected section count. It must not create SQLite or modify source files in verify-only mode.

Run:

```powershell
& .\tools\lore.ps1 ingest --manifest lore_sources/manifest.json --verify-only
& $py -m unittest lore_engine.tests.test_source_manifest lore_engine.tests.test_section_index -v
git diff --exit-code -- '分支：六卷精编版'
```

Expected: both source fingerprints pass; the primary source is strict UTF-8, the in-world text is strict GB18030, 10 sections are selected, and the corpus diff is empty.

- [ ] **Step 6: Commit the source index.**

```powershell
git add lore_sources lore_engine tools/lore.ps1
git commit -m "feat(lore): add immutable source index"
```

---

### Task 3: Contiguous Chunking and SQLite Schema

**Files:**
- Create: `lore_engine/migrations/001_initial.sql`
- Create: `lore_engine/src/database.py`
- Create: `lore_engine/tests/test_chunker.py`
- Create: `lore_engine/tests/test_database.py`
- Modify: `lore_engine/src/chunker.py`
- Modify: `lore_engine/cli.py`

**Interfaces:**
- `iter_chunks(section: SectionRecord, text: str, config: ChunkConfig) -> Iterator[ChunkRecord]`
- `LoreDatabase.open(path: Path) -> LoreDatabase`
- `LoreDatabase.migrate() -> None`
- `LoreDatabase.upsert_source(source: SourceFingerprint) -> None`
- `LoreDatabase.replace_sections_and_chunks(source_file_id: str, sections: Iterable[SectionRecord], chunks: Iterable[ChunkRecord]) -> None`
- `LoreDatabase.search_chunks(query: str, limit: int = 20) -> list[ChunkRecord]`

- [ ] **Step 1: Write chunk and migration tests.**

Use synthetic sections containing short paragraphs, a paragraph longer than the target, and a section shorter than 3000 characters. Assert:

```python
chunks = list(iter_chunks(section, text, config))
assert "".join(c.text for c in chunks) == section_text
assert all(a.end_offset == b.start_offset for a, b in zip(chunks, chunks[1:]))
assert all(c.text == section_text[c.start_offset:c.end_offset] for c in chunks)
assert all(c.start_offset < c.end_offset for c in chunks)
assert [c.chunk_sequence for c in chunks] == list(range(1, len(chunks) + 1))
```

Test that the same input produces the same chunk IDs, that paragraph boundaries are preferred, and that no cross-section chunk is created. Database tests must verify migration, foreign keys, unique constraints, FTS5 search, and repeated import without row growth.

- [ ] **Step 2: Run the tests and confirm failure.**

```powershell
& $py -m unittest lore_engine.tests.test_chunker lore_engine.tests.test_database -v
```

Expected: FAIL because the migration, repository, and chunker are absent.

- [ ] **Step 3: Create the normalized schema.**

Create these tables with text stable IDs and JSON payload columns where appropriate:

```text
schema_migrations
sources
chapters
chunks
entities
entity_aliases
facts
events
relations
rule_candidates
conflicts
extraction_runs
```

Add foreign keys from chapters/chunks to sources, and from evidence-bearing records to source/chunk IDs. Add unique keys for `source_file_id`, chapter `source_id`, chunk `chunk_id`, fact `fact_key`, relation `relation_key`, event `event_key`, rule `rule_key`, and conflict `conflict_key`. Add `chunks_fts` as an FTS5 external-content or maintained virtual table over chunk text.

- [ ] **Step 4: Implement contiguous paragraph-first chunking.**

Read target and maximum lengths from `config/default.json`; do not hardcode the 3000–8000 soft range into behavior. Split at blank-line paragraph boundaries first. If a paragraph exceeds the maximum, split at deterministic character boundaries. Never overlap, trim, or concatenate across sections. Set `previous_id` and `next_id` after all chunk IDs are known.

Use chunk IDs `V01-C001-S01` for the selected batch. Store character and UTF-8 byte offsets, raw text, and SHA-256. The chunk hash is computed from exact text, not normalized text.

- [ ] **Step 5: Implement transactional import and `index`.**

`index` must upsert the source, replace only the selected source’s index records inside one transaction, and report 10 sections, chunk count, total indexed characters, and any parse diagnostics. A second identical invocation must not duplicate records or change IDs.

Run:

```powershell
& .\tools\lore.ps1 index --source-file-id gu_zhenren_main --section-limit 10 --database generated/lore/lore-v1.sqlite
& .\tools\lore.ps1 index --source-file-id gu_zhenren_main --section-limit 10 --database generated/lore/lore-v1.sqlite
& $py -m unittest lore_engine.tests.test_chunker lore_engine.tests.test_database -v
```

Expected: the second run reports no logical additions; all chunk text reconstructs each section exactly.

- [ ] **Step 6: Commit the schema and chunker.**

```powershell
git add lore_engine
git commit -m "feat(lore): add contiguous chunks and sqlite schema"
```

---

### Task 4: Extraction Schema, Evidence Validation, and Fixture Backend

**Files:**
- Create: `lore_engine/schemas/extraction-v1.json`
- Create: `lore_engine/prompts/extraction-v1.txt`
- Create: `lore_engine/src/validator.py`
- Create: `lore_engine/src/model_router.py`
- Create: `lore_engine/tests/test_validator.py`
- Create: `lore_engine/tests/test_model_router.py`
- Create: `lore_engine/tests/fixtures/model/valid_extraction.json`
- Create: `lore_engine/tests/fixtures/model/invalid_json.txt`
- Create: `lore_engine/tests/fixtures/model/invalid_extraction.json`
- Modify: `lore_engine/src/contracts.py`
- Modify: `lore_engine/config/default.json`

**Interfaces:**
- `validate_extraction(payload: object, chunk: ChunkRecord, source_text: str) -> ValidatedExtraction`
- `align_quote(quote: str, chunk_text: str) -> QuoteAlignment`
- `build_model_task(chunk: ChunkRecord, context: dict[str, object]) -> ModelTask`
- `ModelRouter.run(task: ModelTask) -> ModelResult`
- `canonical_json(value: object) -> str`

- [ ] **Step 1: Write schema and isolation tests.**

Create tests for:

```python
valid = json.loads(valid_fixture.read_text(encoding="utf-8"))
assert validate_extraction(valid, chunk, source_text).ok

for bad in (invalid_json, invalid_shape, bad_enum, bad_confidence,
            bad_chunk_id, bad_quote, bad_entity_ref):
    result = validate_extraction(bad, chunk, source_text)
    assert not result.ok
```

Assert that an invalid quote occurring elsewhere in the full source is still rejected when it is absent from the referenced chunk. Assert that `possible_match` aliases are accepted but never converted to a merge. Assert that fixture results are offline and that the second identical model task hits the cache.

- [ ] **Step 2: Run the tests and confirm failure.**

```powershell
& $py -m unittest lore_engine.tests.test_validator lore_engine.tests.test_model_router -v
```

Expected: FAIL because the schema, validator, router, and fixtures do not exist.

- [ ] **Step 3: Define the strict extraction JSON Schema.**

The top-level object must require exactly these arrays:

```json
{
  "entities": [],
  "facts": [],
  "events": [],
  "relations": [],
  "rule_candidates": [],
  "uncertain_items": []
}
```

Require fact fields `fact_id`, `subject`, `predicate`, `object`, `fact_type`, `confidence`, `source_id`, `chunk_id`, `source_quote`, `sequence`, `conditions`, and `uncertainty`. Enumerate entity types and relation types from the V1 specification. Set confidence to a numeric range `[0, 1]`. Require `fact_type` to be one of the four Lore levels.

Use a local standard-library validator for the supported schema subset; do not add a dependency solely for JSON Schema.

- [ ] **Step 4: Implement evidence and reference validation.**

Validate JSON parse, required keys, arrays, enums, confidence, source/chunk identity, sequence, entity references, relation participants, event source references, and exact quote occurrence inside the referenced chunk. Reject ambiguous or missing quote matches. Compute stable record keys from canonical JSON excluding volatile timestamps and use them for deduplication.

- [ ] **Step 5: Implement fixture, disabled, and isolated HTTP adapter contracts.**

`FixtureBackend` reads only a checked-in fixture and maps it to the current chunk. `DisabledBackend` returns a controlled no-call result. `JsonHttpBackend` uses `urllib.request`, reads URL/model/key names from config/environment, and refuses to run unless `allow_network=True`. Store only a hash and sanitized error metadata for failed responses; never persist API keys.

The default config must select `fixture` for the dry-run test profile and `disabled` for a no-model profile. The configured model name is `gpt-5.6-luna`, default effort `low`; escalation metadata may be attached but must not activate Terra.

- [ ] **Step 6: Verify and commit.**

```powershell
& $py -m unittest lore_engine.tests.test_validator lore_engine.tests.test_model_router -v
& .\tools\lore.ps1 run --backend disabled --dry-run --database generated/lore/lore-v1.sqlite
```

Expected: all focused tests pass; disabled mode makes no network call; invalid responses are represented as isolated results and cannot be persisted as formal facts.

```powershell
git add lore_engine
git commit -m "feat(lore): validate evidence-backed extraction"
```

---

### Task 5: Seed Import and Transactional Extraction Writes

**Files:**
- Create: `lore_sources/seeds/seed_canon.jsonl`
- Create: `lore_sources/seeds/seed_inferred.jsonl`
- Create: `lore_sources/seeds/seed_note.jsonl`
- Create: `lore_sources/seeds/seed_game_design.jsonl`
- Create: `lore_engine/src/seeds.py`
- Create: `lore_engine/tests/test_seeds.py`
- Create: `lore_engine/tests/test_database_writes.py`
- Modify: `lore_engine/src/database.py`
- Modify: `lore_engine/src/validator.py`

**Interfaces:**
- `load_seed_records(seed_dir: Path) -> list[SeedRecord]`
- `import_seeds(db: LoreDatabase, records: Iterable[SeedRecord]) -> SeedImportSummary`
- `LoreDatabase.commit_extraction(chunk_id: str, run_id: str, extraction: ValidatedExtraction) -> None`
- `LoreDatabase.record_failed_run(run: ExtractionRun) -> None`

- [ ] **Step 1: Write seed and transaction tests.**

Use small fixtures representing one `CANON`, one `INFERRED`, one `NOTE`, and one `GAME_DESIGN` record. Assert all records remain queryable, seed type and source file are preserved, repeated import does not grow tables, and seed canonical priority is metadata rather than deletion of model candidates.

Inject a failure between entity and fact preparation and assert the transaction leaves neither formal row. Assert `record_failed_run` writes only `extraction_runs` and chunk failure state.

- [ ] **Step 2: Run tests and confirm failure.**

```powershell
& $py -m unittest lore_engine.tests.test_seeds lore_engine.tests.test_database_writes -v
```

Expected: FAIL because seed loaders and transactional write methods do not exist.

- [ ] **Step 3: Normalize existing manual registers into seed inputs without altering them.**

Read `docs/lore/canon-index.md`, `docs/lore/adaptation-register.md`, and `docs/lore/game-rule-register.md`. Convert only reliably parseable rows into JSONL seed records containing `seed_id`, `seed_kind`, `label`, `summary`, `source_doc`, `source_ref`, `content_hash`, and `review_status`. Preserve the original markdown files byte-for-byte. Unparseable rows become `seed_note` records with `review_status="NEEDS_REVIEW"` rather than guessed facts.

- [ ] **Step 4: Implement seed priority and formal writes.**

Use a precedence field for `seed_canon`, but retain every extracted record under its own stable key. Insert all accepted extraction records and set chunk `SUCCESS` in one transaction. Failed extraction writes only the run record, retry count, error code, and `FAILED`/`NEEDS_REVIEW` status.

- [ ] **Step 5: Verify source and Godot boundaries.**

```powershell
& .\tools\lore.ps1 seed-import --database generated/lore/lore-v1.sqlite --seed-dir lore_sources/seeds
& $py -m unittest lore_engine.tests.test_seeds lore_engine.tests.test_database_writes -v
git diff --exit-code -- 'docs/lore' 'data' 'scripts' 'scenes' 'ui' '分支：六卷精编版'
```

Expected: seed import is idempotent and all protected directories remain unchanged.

- [ ] **Step 6: Commit the seed importer.**

```powershell
git add lore_sources/seeds lore_engine
git commit -m "feat(lore): import protected seed records"
```

---

### Task 6: Checkpointed Pipeline, Resume, Retry, and Reports

**Files:**
- Create: `lore_engine/src/pipeline.py`
- Create: `lore_engine/src/reports.py`
- Create: `lore_engine/tests/test_pipeline_resume.py`
- Create: `lore_engine/tests/test_reports.py`
- Modify: `lore_engine/migrations/001_initial.sql`
- Modify: `lore_engine/src/database.py`
- Modify: `lore_engine/src/model_router.py`
- Modify: `lore_engine/cli.py`

**Interfaces:**
- `Pipeline.run(selection: Selection, backend: str, dry_run: bool, stop_after: int | None, resume: bool) -> PipelineSummary`
- `Pipeline.retry(statuses: tuple[str, ...]) -> PipelineSummary`
- `build_report(db: LoreDatabase) -> dict[str, object]`
- `write_report(report: dict[str, object], path: Path) -> None`

- [ ] **Step 1: Write crash and resume tests.**

Create five synthetic chunks and a fixture backend that raises on chunk 3. Assert:

```python
summary = pipeline.run(selection, backend="fixture", dry_run=False)
assert states() == ["SUCCESS", "SUCCESS", "FAILED", "PENDING", "PENDING"]

pipeline.run(selection, backend="fixture", dry_run=False, resume=True)
assert states() == ["SUCCESS", "SUCCESS", "SUCCESS", "SUCCESS", "SUCCESS"]
```

Also test `stop_after=2`, lease expiration of `RUNNING`, retry restricted to failed/review states, and a changed chunk hash marking prior work stale instead of silently reusing it. Run the same successful pipeline twice and assert logical record counts and stable-content hashes are identical.

- [ ] **Step 2: Run tests and confirm failure.**

```powershell
& $py -m unittest lore_engine.tests.test_pipeline_resume lore_engine.tests.test_reports -v
```

Expected: FAIL because the pipeline and report functions do not exist.

- [ ] **Step 3: Add checkpoint columns and lease semantics.**

Extend `chunks` with status, input hash, prompt version, schema version, run ID, retry count, started time, finished time, lease expiry, and error code. Add extraction run fields for backend/model, request hash, response hash, validation status, and sanitized error. Use UTC ISO timestamps only for diagnostics; exclude them from logical content hashes.

- [ ] **Step 4: Implement the pipeline transaction boundaries.**

For each selected chunk: claim it atomically, build the task, call the router, validate the result, then either commit all formal rows plus `SUCCESS` or commit only the isolated run plus failure status. Resume claims only pending/stale/expired-running records; retry claims only `FAILED` and `NEEDS_REVIEW`. `dry_run` performs the same reads, task construction, backend call, and validation but does not commit formal extraction records; it still writes a deterministic preview report.

- [ ] **Step 5: Implement deterministic reports and CLI commands.**

Reports must include selected sections/chunks, statuses, success/failure/retry/review counts, entity/fact/event/relation/rule counts, quote-validation failures, cache hits, backend/model metadata, and protected-path mutation check results. Sort arrays and keys deterministically.

Wire `run`, `retry`, `validate`, and `report` in the CLI. `run --stop-after N` must stop after N processed chunks with exit `0` if no validation failure occurred; resume must continue from the database state.

- [ ] **Step 6: Verify and commit.**

```powershell
& $py -m unittest lore_engine.tests.test_pipeline_resume lore_engine.tests.test_reports -v
& .\tools\lore.ps1 run --backend fixture --dry-run --database generated/lore/lore-v1.sqlite
& .\tools\lore.ps1 run --backend fixture --stop-after 3 --database generated/lore/lore-v1.sqlite
& .\tools\lore.ps1 run --backend fixture --resume --database generated/lore/lore-v1.sqlite
& .\tools\lore.ps1 report --database generated/lore/lore-v1.sqlite --out generated/lore/reports/v1.json
```

Expected: the stopped run preserves its checkpoint; resume processes only unfinished work; repeated runs do not duplicate formal records; report JSON is valid and deterministic apart from diagnostic timestamps.

```powershell
git add lore_engine
git commit -m "feat(lore): add resumable extraction pipeline"
```

---

### Task 7: Real 10-Section Offline Dry-Run and Delivery Gate

**Files:**
- Create: `lore_engine/tests/test_real_ten_section_acceptance.py`
- Create: `docs/lore/generated/README.md`
- Modify: `docs/lore/README.md`
- Modify: `tools/lore.ps1` only if command wiring needs correction

**Interfaces:**
- Acceptance uses the public CLI and the database/report APIs from Tasks 1–6.
- No new domain API is introduced in this task.

- [ ] **Step 1: Write the end-to-end acceptance test before running the real corpus.**

The test must invoke the CLI against a temporary database and assert:

```python
assert selected_section_count == 10
assert section_ids == [f"V01-C{i:03d}" for i in range(1, 11)]
assert every_successful_fact_has_valid_quote
assert no_chunk_overlap
assert concatenated_chunks_equal_each_section
```

It must also run a stop/resume sequence, rerun the completed pipeline, compare logical row counts, inject one invalid fixture response, and assert no formal record is created for that chunk.

- [ ] **Step 2: Run the acceptance test and inspect failures.**

```powershell
& $py -m unittest lore_engine.tests.test_real_ten_section_acceptance -v
```

Expected: any failure is treated as an implementation defect or explicit environment issue; do not weaken the test to make the run green.

- [ ] **Step 3: Run the real 10-section dry-run.**

```powershell
& .\tools\lore.ps1 ingest --manifest lore_sources/manifest.json --verify-only
& .\tools\lore.ps1 index --source-file-id gu_zhenren_main --section-limit 10 --database generated/lore/lore-v1.sqlite
& .\tools\lore.ps1 seed-import --database generated/lore/lore-v1.sqlite --seed-dir lore_sources/seeds
& .\tools\lore.ps1 run --backend fixture --dry-run --database generated/lore/lore-v1.sqlite
& .\tools\lore.ps1 run --backend fixture --stop-after 3 --database generated/lore/lore-v1.sqlite
& .\tools\lore.ps1 run --backend fixture --resume --database generated/lore/lore-v1.sqlite
& .\tools\lore.ps1 validate --database generated/lore/lore-v1.sqlite
& .\tools\lore.ps1 report --database generated/lore/lore-v1.sqlite --out generated/lore/reports/lore-v1-10-sections.json
```

The fixture must use real quotes from the first 10 sections, including evidence such as the Volume 1 headings, the opening Spring Autumn Cicada claims, aperture/primeval sea descriptions, Gu Master rank statements, Gu Room selection, and primeval stone/Gu refinement pressure. It must not invent facts absent from those chunks.

- [ ] **Step 4: Add the migration note to the Lore README.**

Document that `docs/lore/*.md` remains a human-readable review surface during migration, while SQLite is the structured intermediate truth for compiler output. State that V1 does not export into Godot `data/` and that `generated/lore/` is disposable.

- [ ] **Step 5: Run the complete offline gate.**

```powershell
& $py -m unittest discover -s lore_engine/tests -p 'test_*.py' -v
& .\tools\lore.ps1 ingest --manifest lore_sources/manifest.json --verify-only
& .\tools\lore.ps1 validate --database generated/lore/lore-v1.sqlite
git diff --exit-code -- 'data' 'scripts' 'scenes' 'ui' '分支：六卷精编版' 'docs/lore/canon-index.md' 'docs/lore/adaptation-register.md' 'docs/lore/game-rule-register.md'
git diff --check
```

Expected: all Lore tests pass; strict source verification passes; formal output is schema-valid and idempotent; protected paths are unchanged. Any existing unrelated Godot test failures must be reported separately and not repaired as part of this task.

- [ ] **Step 6: Commit the V1 delivery gate.**

```powershell
git add lore_engine docs/lore/README.md docs/lore/generated
git commit -m "test(lore): accept ten-section compiler dry-run"
git status --short --branch
```

---

## Execution Checkpoints

After Task 2, stop and inspect source IDs, offsets, and the first 10 titles. After Task 3, stop and verify exact text reconstruction and no overlap. After Task 4, stop and verify invalid model output cannot enter formal tables. After Task 6, stop and inspect crash/resume and idempotency behavior. Only after all checkpoints pass should the real 10-section dry-run run.

## Explicitly Deferred

- Full-corpus indexing and 700万字 processing.
- Three-route discovery, blind audit, later-counter-evidence adjudication, strict/research query modes, and benchmark gold sets.
- Release snapshots and Godot adaptation export.
- Any modification to `ContentCatalog`, `data/*.json`, Godot scenes, runtime scripts, or UI.
- Production network calls or cost calibration for Luna. The adapter contract is implemented and tested, but fixture mode is the V1 acceptance baseline.

## Plan Self-Review

- Spec coverage: source immutability and encoding are Task 2; section/chunk identity and offsets are Tasks 2–3; SQLite tables and FTS5 are Task 3; schema, evidence, model routing, and retry isolation are Task 4; seed precedence is Task 5; checkpoint/resume/retry/idempotency are Task 6; 10-section dry-run and protected-path gate are Task 7.
- Scope: the plan stops at the requested V1 skeleton and offline 10-section dry-run; no later query, benchmark, release, or Godot export work is included.
- Type consistency: `SourceSpec`, `SectionRecord`, `ChunkRecord`, `ModelTask`, `ModelResult`, `ValidatedExtraction`, and `ExtractionRun` are defined in `contracts.py` before consumers are introduced.
- Placeholder scan: no unfinished steps, unowned interfaces, or unspecified edge-case tasks remain. Ellipses appear only in Python type signatures such as `tuple[SourceSpec, ...]`; all prose requirements and sample hashes are concrete.
- Existing worktree safety: every commit stages only the files named by its task; no command resets, checks out, deletes, or formats unrelated files.
