# Task 0.3 Report: source evidence、offsets 和 contradiction checks

## Status

Implemented. The change is read-only and scoped to evidence resolution, coverage/counter-evidence helpers, tests, and short fixtures. The real Stage 0 evidence JSONL remains unchanged: its two explicit `unknown` placeholders are not converted into verified evidence.

## Implementation

- Added `lore_engine/src/world_evidence.py`.
- `resolve_evidence(root, manifest, evidence_refs)` reuses `source_manifest.read_source`, verifies every manifest source before resolving references, preserves decoded source text exactly, and aligns using Python character offsets without newline/whitespace/Unicode normalization.
- Verified evidence must match the declared slice, occur exactly once in the decoded source, and use the manifest-declared source authority. Invalid alignment remains a visible `ResolvedEvidence(ok=False, error=...)`; source/hash/path/decode failures raise `EvidenceResolutionError`.
- Resolved evidence records short quote text, quote SHA-256, source SHA-256, source ID/reference, authority, kind, and character offsets only.
- `check_claim_coverage` keeps support, condition, counterexample, and unknown evidence in separate collections. Canonical/derived/adaptation claims require support; canonical support must be P0 (`primary_text` or `in_world_text`). Secondary notes cannot satisfy that requirement.
- `find_counter_evidence` reads indexed chunks/evidence and seed records without writing. Indexed primary counterexamples retain primary authority; seed-note candidates retain `secondary_note` authority and cannot promote a P0 claim.
- Added short, synthetic fixtures only; no novel passages were copied and no production game files were touched.

## RED/GREEN evidence

RED:

```text
COMMAND: python -m unittest lore_engine.tests.test_world_evidence -v
ERROR: ModuleNotFoundError: No module named 'lore_engine.src.world_evidence'
EXIT=1
```

GREEN focused run:

```text
COMMAND: python -m unittest lore_engine.tests.test_world_evidence lore_engine.tests.test_source_manifest -v
Ran 10 tests in 0.035s
OK
EXIT=0
```

GREEN full lore-engine run:

```text
COMMAND: python -m unittest discover -s lore_engine/tests -p 'test*.py' -v
Ran 62 tests in 4.925s
OK
EXIT=0
```

Additional verification:

```text
COMMAND: python -m py_compile lore_engine/src/world_evidence.py lore_engine/tests/test_world_evidence.py
EXIT=0
COMMAND: git diff --check
EXIT=0
COMMAND: strict real-manifest fingerprint check (case-insensitive SHA-256 comparison)
[('gu_zhenren_main', True), ('ren_zu_zhuan', True)]
EXIT=0
```

The manifest check intentionally compares digest case-insensitively, matching the existing strict implementation in `source_manifest.py`; source bytes and manifest hashes were not changed.

## Files changed

- `lore_engine/src/world_evidence.py`
- `lore_engine/tests/test_world_evidence.py`
- `lore_engine/tests/fixtures/world_model/short_primary.txt`
- `lore_engine/tests/fixtures/world_model/short_conflict.txt`
- `.superpowers/sdd/task-0.3-report.md`

Unrelated pre-existing untracked files, including the implementation plan and user backup/probe files, were preserved and excluded from the task commit.

## Self-review

- Exact alignment uses decoded character indices; the tests distinguish those indices from UTF-8 byte offsets and reject a quote that matches at multiple locations.
- Hash mismatch is checked even when no evidence references are supplied, so a resolver cannot silently skip source verification.
- Unknown evidence remains explicitly unresolved and is excluded from canonical/P0 support checks.
- Support, conditions, and counterexamples remain independently queryable; no boolean collapse occurs.
- Authority is checked both against the manifest and against the claim status. Secondary-note discovery is deliberately non-promotional.
- Resolver and search helpers do not mutate sources, benchmarks, SQLite data, or production paths.

## Concerns

- The current formal benchmark still has no verified source coordinates by design; Task 0.3 supplies the reusable machinery and synthetic coverage tests, not novel-derived evidence rows.
- `find_counter_evidence` is intentionally conservative and deterministic: it surfaces explicit counterexample markers and seed-note candidates, but it does not infer a contradiction from arbitrary prose.
- `ResolvedEvidence` is a task-local read model; later baseline/report tasks can join it to the existing frozen `EvidenceRef` records without changing the formal ledger contract.

## Commit

- Implementation: `061f5bb feat(lore): add exact world evidence resolution`
- Report commit is created separately after this report is written.

## Review-wave fixes

### RED/GREEN evidence

The review regressions were added before the implementation changes. The first RED run failed during import because the required explicit `CounterEvidenceCandidate` type did not exist:

```text
COMMAND: python -m unittest lore_engine.tests.test_world_evidence -v
ERROR: ImportError: cannot import name 'CounterEvidenceCandidate'
EXIT=1
```

The final focused run covers all five review findings plus the original source-manifest tests:

```text
COMMAND: python -m unittest lore_engine.tests.test_world_evidence lore_engine.tests.test_source_manifest -v
Ran 15 tests in 0.039s
OK
EXIT=0
```

The full lore-engine regression remains green:

```text
COMMAND: python -m unittest discover -s lore_engine/tests -p 'test*.py'
Ran 67 tests in 4.406s
OK
EXIT=0
```

Additional checks:

```text
COMMAND: python -m py_compile lore_engine/src/world_evidence.py lore_engine/tests/test_world_evidence.py
EXIT=0
COMMAND: git diff --check
EXIT=0
```

### Review fixes implemented

- Chunk authority now comes from the matching `SourceSpec`; without manifest/root provenance, a chunk is an explicit unverified candidate rather than primary evidence.
- Chunk-derived evidence is emitted as hash-bearing `ResolvedEvidence` only after the chunk hash, exact source slice, unique quote occurrence, decoded offsets, and source hash all verify. Failed checks remain `CounterEvidenceCandidate` diagnostics.
- Seed notes are considered only when explicit counterexample/contradiction markers are present. A claim-statement match alone is ignored; marker matches retain `secondary_note` and remain unverified candidates.
- Raw string inputs are retained only as diagnostics with `None` source IDs/references/coordinates; no empty IDs or `-1` offsets are fabricated.
- `SourcePathError` is wrapped as `EvidenceResolutionError` in both resolver and indexed-source verification paths.

### Review-wave self-review and concerns

- The original `find_counter_evidence(claim, indexed_sources, seed_records)` call shape remains valid; manifest and root are optional positional extensions.
- Verified chunk results now carry source and quote hashes through `ResolvedEvidence`, while candidates cannot be mistaken for formal `EvidenceRef` rows.
- P0 constraints remain unchanged: only manifest-declared P0 authorities can satisfy canonical support, and secondary notes never promote a claim.
- The helper remains deterministic and read-only; no benchmark, novel, SQLite, `data/`, `scripts/`, or `scenes/` files changed.
- Concern: callers that previously assumed every returned counterexample was an `EvidenceRef` must now handle the documented union of `ResolvedEvidence` and `CounterEvidenceCandidate`; this is required to keep provenance failures visible rather than silently asserting evidence.

## Review-wave commit

- `2861180 fix(lore): preserve counter-evidence provenance`

## Final Important fixes

### RED/GREEN evidence

Two focused regressions were added before the implementation changes. They initially failed because an out-of-range chunk could still become `ResolvedEvidence`, and `ClaimCoverage` treated a candidate without `.ok` as resolved:

```text
COMMAND: python -m unittest lore_engine.tests.test_world_evidence.WorldEvidenceTests.test_malformed_chunk_bounds_remain_candidate lore_engine.tests.test_world_evidence.WorldEvidenceTests.test_candidate_is_unresolved_in_claim_coverage -v
FAILED (failures=2)
EXIT=1
```

After the fixes:

```text
COMMAND: python -m unittest lore_engine.tests.test_world_evidence lore_engine.tests.test_source_manifest -v
Ran 17 tests in 0.067s
OK
EXIT=0

COMMAND: python -m unittest discover -s lore_engine/tests -p 'test*.py'
Ran 69 tests in 4.329s
OK
EXIT=0

COMMAND: python -m py_compile lore_engine/src/world_evidence.py lore_engine/tests/test_world_evidence.py
EXIT=0
COMMAND: git diff --check
EXIT=0
```

### Final fixes and self-review

- `find_counter_evidence` validates `0 <= start_offset < end_offset <= len(source_text)` before any source slice. Malformed bounds become explicit candidates with a diagnostic and cannot reach `ResolvedEvidence`.
- `ClaimCoverage` and `check_claim_coverage` now include `CounterEvidenceCandidate` in their public unions. Candidates are retained in their evidence-kind bucket and `unresolved`, always add an unresolved-candidate error, and therefore cannot make coverage `ok=True`.
- Candidate coordinates are optional (`str | None`, `int | None`), matching raw/seed candidates without inventing empty IDs or `-1` offsets.
- Prior manifest-derived authority, exact decoded offsets, unique alignment, source/chunk hashes, marker-only seed discovery, path wrapping, read-only behavior, deterministic ordering, and P0 restrictions remain intact.
- No benchmark, source novel, SQLite, `data/`, `scripts/`, or `scenes/` files changed. Existing unrelated untracked files remain preserved.

### Remaining concern

Callers must handle the documented result union and inspect `ResolvedEvidence.ok` or `CounterEvidenceCandidate.verified`; candidates are intentionally visible but are never formal verified evidence.

## Final review-fix commit

- `4644ad0 fix(lore): reject malformed evidence chunks`

## Final provenance fixes

### RED/GREEN evidence

Two regressions were written first. They failed because indexed chunks validated only character bounds (not byte bounds), and long marker lines were truncated after deriving coordinates, allowing an internally inconsistent resolved record:

```text
COMMAND: python -m unittest lore_engine.tests.test_world_evidence.WorldEvidenceTests.test_mismatched_chunk_byte_bounds_remain_candidate lore_engine.tests.test_world_evidence.WorldEvidenceTests.test_long_marker_line_is_unresolved_instead_of_truncated_evidence -v
FAILED (failures=2)
EXIT=1
```

After implementation:

```text
COMMAND: python -m unittest lore_engine.tests.test_world_evidence lore_engine.tests.test_source_manifest -v
Ran 19 tests in 0.052s
OK
EXIT=0

COMMAND: python -m unittest discover -s lore_engine/tests -p 'test*.py'
Ran 71 tests in 4.615s
OK
EXIT=0

COMMAND: python -m py_compile lore_engine/src/world_evidence.py lore_engine/tests/test_world_evidence.py
EXIT=0
COMMAND: git diff --check
EXIT=0
```

### Fixes and self-review

- Indexed chunks now require valid character bounds and byte bounds that exactly equal UTF-8 byte lengths of `source_text[:start_offset]` and `source_text[:end_offset]`; mismatches remain explicit candidates.
- Marker lines of at most 200 characters are returned with the full exact quote, matching coordinates and quote hash. Lines over 200 characters remain unresolved candidates with the original full range metadata and a diagnostic, never truncated `ResolvedEvidence`.
- Existing manifest-derived authority, source/chunk hash checks, unique decoded alignment, candidate coverage handling, marker-only seed discovery, path wrapping, deterministic/read-only behavior, and P0 rules remain unchanged.
- Added focused tests cover mismatched byte bounds and long marker-line handling; all prior Task 0.3 regressions remain green.

### Remaining concern

Long counterexample lines are intentionally deferred as candidates until a future caller can provide a short, exact, uniquely aligned quote/range; no lossy truncation is accepted as verified evidence.

## Final provenance-fix commit

- `13e0b0f fix(lore): validate counter-evidence byte provenance`

## Encoding-specific provenance fix

### RED/GREEN evidence

A GB18030 regression was added first. It failed because indexed byte-bound validation encoded decoded prefixes as UTF-8 even when the manifest declared GB18030:

```text
COMMAND: python -m unittest lore_engine.tests.test_world_evidence.WorldEvidenceTests.test_gb18030_chunk_byte_bounds_use_manifest_encoding -v
FAIL: valid GB18030 chunk was not verified
EXIT=1
```

After using the matched `SourceSpec.encoding` for decoded-prefix byte calculations:

```text
COMMAND: python -m unittest lore_engine.tests.test_world_evidence lore_engine.tests.test_source_manifest -v
Ran 20 tests in 0.057s
OK
EXIT=0

COMMAND: python -m unittest discover -s lore_engine/tests -p 'test*.py'
Ran 72 tests in 4.537s
OK
EXIT=0

COMMAND: python -m py_compile lore_engine/src/world_evidence.py lore_engine/tests/test_world_evidence.py
EXIT=0
COMMAND: git diff --check
EXIT=0
```

### Fix and self-review

- Indexed chunk byte bounds now use `spec.encoding` for exact decoded source prefixes, supporting both UTF-8 and GB18030.
- The existing raw-byte source hash remains computed from source bytes, and strict decoding/path/hash checks remain delegated to `read_source`/the manifest.
- The regression proves valid GB18030 bounds resolve as `ResolvedEvidence` and mismatched bounds remain `CounterEvidenceCandidate`.
- All previous authority, exact quote, candidate, coverage, marker, long-line, P0, deterministic, and read-only protections remain covered by the same suite.
- No benchmark, novel, SQLite, `data/`, `scripts/`, or `scenes/` files changed; unrelated untracked files remain preserved.

### Remaining concern

Chunk hashes continue to follow the pre-existing UTF-8 text-hash contract, while byte bounds follow the manifest encoding; both checks are intentionally independent.

## Encoding-fix commit

- `aeb04d9 fix(lore): honor manifest encoding for evidence offsets`
