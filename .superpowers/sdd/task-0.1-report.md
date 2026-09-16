# Task 0.1 Report: 固定 Stage 0 输入、输出和生产边界

## Implementation

- Added `lore_engine/config/world-model-stage0.json` with the exact 24 high-impact topic IDs, `minimum_claims: 20`, both P0 source IDs, a Stage 0 read allowlist, and explicit `data/`, `scripts/`, and `scenes/` production-write denylist.
- Added 24 provisional benchmark claim rows. All are `deferred` with neutral audit-target statements; no unverified review example is encoded as settled fact.
- Added two unresolved evidence placeholders keyed to the existing manifest source IDs and 24 `needs_evidence` decision rows whose implementation actions forbid production changes.
- Added an invalid-record fixture and focused contract/claim-validation tests. The test-local validator covers missing references, invented status, missing P0 citation, and direct production-path edits.
- `lore_sources/manifest.json` was not modified; existing source hashes remain untouched.

## Tests and RED/GREEN evidence

- RED: `python -m unittest lore_engine.tests.test_world_claims -v` initially failed with missing Stage 0 config, fixture, and benchmark artifacts (3 errors).
- GREEN: the same focused command passed: 3 tests, 0 failures.
- Full regression: `python -m unittest discover -s lore_engine/tests -v` passed: 29 tests, 0 failures.
- JSONL sanity check passed: claims 24 rows, evidence 2 rows, decisions 24 rows. `git diff --check` passed.

## Files changed

- `lore_engine/config/world-model-stage0.json`
- `lore_sources/benchmarks/world_model_stage0/claims.jsonl`
- `lore_sources/benchmarks/world_model_stage0/evidence.jsonl`
- `lore_sources/benchmarks/world_model_stage0/decisions.jsonl`
- `lore_engine/tests/fixtures/world_model/invalid_claim.json`
- `lore_engine/tests/test_world_claims.py`

## Self-review

- The 24 config IDs are unique and match the benchmark claim IDs exactly.
- Every benchmark row is provisional (`deferred`), and all 24 rows satisfy the explicit-deferred allowance for incomplete source verification.
- Decision text is audit-only and does not prescribe runtime behavior or edit any production path.
- Existing untracked user files, including the map-related backup/probe, were preserved and are excluded from the commit.

## Concerns

- Evidence offsets and quotes are intentionally unresolved placeholders; exact source alignment belongs to Task 0.3.
- The record rejection helper is test-local because the reusable ledger validator is explicitly scoped to Task 0.2.
- No real source verification or Stage 0 Gate execution is claimed by this task.

## Reviewer P1 fix

- Root cause: `read_allowlist` listed Stage 0 metadata and fixture paths but omitted the two source `path` values declared in `lore_sources/manifest.json`; literal allowlist enforcement would therefore block both P0 sources.
- Fix: added the exact manifest-declared paths `分支：六卷精编版/蛊真人-clean.txt` and `分支：六卷精编版/《人祖传》.txt` to `lore_engine/config/world-model-stage0.json` without changing the production denylist or manifest hashes.
- Regression RED: `python -m unittest lore_engine.tests.test_world_claims.WorldClaimsContractTests.test_read_allowlist_covers_every_manifest_source_path -v` failed with `manifest source is outside Stage 0 read allowlist: 分支：六卷精编版/蛊真人-clean.txt`.
- Regression GREEN: the same command is covered in `python -m unittest lore_engine.tests.test_world_claims -v`: 4 tests, 0 failures, `OK`.
- Full regression: `python -m unittest discover -s lore_engine/tests -v`: 30 tests, 0 failures, `OK`.

### Fix self-review

- Allowlist enforcement can now match each manifest source by exact normalized path; the source files remain read-only inputs.
- `data/`, `scripts/`, and `scenes/` remain excluded from the allowlist and unchanged in the production-write denylist.
- Only the config, its covering test, and this report are included in the fix commit; unrelated user worktree files remain unstaged.
