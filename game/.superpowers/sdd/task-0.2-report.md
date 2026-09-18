# Task 0.2 report: world-claim ledger and schema validation

## Status

Implemented and verified. Task 0.1 JSONL remains backward compatible: existing provisional `deferred` rows with empty references are still loadable; cross-record validation rejects unresolved references when a claim declares them.

## Implementation

- Added frozen `WorldClaim`, `EvidenceRef`, `ImplementationFinding`, `WorldDecision`, and `Stage0Gate` contracts to `lore_engine/src/contracts.py`.
- Added `lore_engine/src/world_claims.py` with standard-library JSONL loading, schema-shaped record construction, deterministic normalized path/line ordering, structured `ValidationError` values (`code`, `message`, `file`, `line`), status transition validation, and `validate_claim_set`.
- Validation covers duplicate IDs, closed enums, high-impact topic coverage, minimum claim count, claim/evidence references, claim/evidence source agreement, authority/status compatibility, and P0 support evidence for canonical claims. Rejected is terminal; canonical can leave only with an explicit decision.
- Added `lore_engine/schemas/world-claim-v1.json` for claim/evidence/finding/decision record shapes and closed enum values.

## RED/GREEN evidence

1. RED: the new tests initially failed at import because `WorldClaim`/`EvidenceRef`/`WorldDecision` did not exist.
2. RED: after the first implementation, the authority/source compatibility test failed because the two required error codes were not yet emitted.
3. GREEN: after the minimal validation enhancement, focused tests passed `10/10`.

## Tests and output

```text
python -m unittest lore_engine.tests.test_world_claims -v
Ran 10 tests ... OK

python -m unittest discover -s lore_engine/tests -p 'test*.py' -v
Ran 36 tests ... OK
FOCUSED_EXIT=0
FULL_EXIT=0
```

`git diff --check` passed. Invalid JSONL is represented as a structured error with its source file and 1-based line; valid rows on other lines/files are retained and the loader does not crash the test runner.

## Files changed

- `lore_engine/src/contracts.py`
- `lore_engine/src/world_claims.py`
- `lore_engine/schemas/world-claim-v1.json`
- `lore_engine/tests/test_world_claims.py`
- `.superpowers/sdd/task-0.2-report.md`

## Fourth-review fix: candidate-to-canonical promotion

The reviewer identified that `validate_claim_set` incorrectly required a decision for every canonical claim. A candidate claim with valid P0 support may become canonical without a decision; a supplied decision is still validated. Explicit `previous_status` and a matching ruling remain required for transitions leaving canonical and for derived/adaptation/rejected statuses. Rejected remains terminal.

### RED evidence

```text
COMMAND: python -m unittest lore_engine.tests.test_world_claims.WorldClaimsContractTests.test_candidate_can_become_canonical_without_decision_when_p0_supported lore_engine.tests.test_world_claims.WorldClaimsContractTests.test_canonical_cannot_become_derived_without_decision -v
EXIT=1
test_candidate_can_become_canonical_without_decision_when_p0_supported ... FAIL
test_canonical_cannot_become_derived_without_decision ... ok
AssertionError: 'unauthorized_status_transition' unexpectedly found in {'unauthorized_status_transition'}
Ran 2 tests in 0.001s
FAILED (failures=1)
```

### GREEN evidence

```text
COMMAND: python -m unittest lore_engine.tests.test_world_claims -v
EXIT=0
Ran 19 tests in 0.038s
OK

COMMAND: python -m unittest discover -s lore_engine/tests -p 'test*.py' -v
EXIT=0
Ran 45 tests in 6.581s
OK

COMMAND: python -m py_compile lore_engine/src/contracts.py lore_engine/src/world_claims.py
EXIT=0

COMMAND: git diff --check
EXIT=0
```

### Self-review and concerns

The validator skips only the missing-decision error for a canonical claim with no decision. Canonical P0/support evidence checks are unchanged, and a present canonical decision still requires `retain`, explicit `previous_status`, and a valid transition. Derived, adaptation, and rejected claims still require explicit decisions; canonical-to-derived without one remains covered by the regression. Changes remain limited to the validator, focused tests, and this report. Task 0.1 deferred rows and all prior Task 0.2 fixes are preserved. No `data/`, `scripts/`, `scenes/`, source text, or unrelated user files were modified. Existing concerns remain: character-range content alignment is deferred to Task 0.3, and runtime validation is dependency-free by design.

## Second-review fixes (RED/GREEN)

- RED: regressions demonstrated that a status-changing decision without `previous_status` was accepted, and the JSON schema lacked `minLength: 1` on claim ID-array items.
- GREEN: every adjudicated target status now requires an explicit `previous_status`; `validate_status_transition` validates that declared prior state to current state. Initial `candidate` and Task 0.1 `deferred` rows without transitions remain compatible.
- GREEN: `source_ids`, `evidence_ids`, and `counter_evidence_ids` now require non-empty string items in the schema, matching runtime `_strings` validation.

Second-review verification:

```text
python -m unittest lore_engine.tests.test_world_claims -v
Ran 15 tests ... OK

python -m unittest discover -s lore_engine/tests -p 'test*.py' -v
Ran 41 tests ... OK

python -m py_compile lore_engine/src/contracts.py lore_engine/src/world_claims.py
exit 0
git diff --check
exit 0
```

Self-review: no production data, scripts, scenes, source text, or unrelated user files were modified. The only remaining interface caveat is that `WorldDecision` uses its stable `claim_id` foreign key rather than introducing a separate decision ID.

## Third-review fixes (RED/GREEN)

- RED: focused regressions showed missing `minLength` for `non_regression_notes` items, negative `char_start` accepted by `load_jsonl`, and counter-evidence source mismatches not reported.
- GREEN: decision-note item schema now requires non-empty strings; evidence construction rejects negative `char_start`; source-ID agreement covers both supporting and counter-evidence references.
- Self-review: changes remain limited to the Task 0.2 schema, loader/validator, tests, and this report. Task 0.1 deferred rows remain valid because their empty reference arrays are allowed; only empty elements are rejected. No production or unrelated user files changed.

Third-review verification:

```text
python -m unittest lore_engine.tests.test_world_claims -v
Ran 17 tests ... OK

python -m unittest discover -s lore_engine/tests -p 'test*.py' -v
Ran 43 tests ... OK

python -m py_compile lore_engine/src/contracts.py lore_engine/src/world_claims.py
exit 0
git diff --check
exit 0
```

## Self-review

The implementation is limited to the requested lore-engine contract/schema/validation surface. Existing V1 modules and tests remain unchanged. The loader is deterministic and preserves malformed-row diagnostics rather than silently dropping them. The schema is dependency-free and records retain counter-evidence IDs and decision notes.

## Concerns

- JSON Schema is documented as a repository-local standard-library contract; runtime validation is intentionally implemented without adding a third-party dependency.
- Character-range content alignment is intentionally deferred to Task 0.3; Task 0.2 validates range shape only.
- No production data, scripts, scenes, source text, or unrelated worktree files were modified.

## Reviewer fixes (RED/GREEN)

- RED: added regressions initially failed for empty required strings/extra properties, invalid finding enums, cross-type duplicate IDs, and status decisions that were absent from validation.
- GREEN: the loader now enforces non-empty required strings, exact properties (`additionalProperties=false` behavior), all finding enums, and record ranges before constructing dataclasses. The schema now declares complete finding properties and constraints.
- GREEN: `WorldDecision.previous_status` is an optional compatible extension. Non-initial statuses requiring adjudication must have a matching decision (`retain` for canonical, `revise` for derived/adaptation, `remove` for rejected); explicit previous statuses pass through the transition state machine.
- GREEN: entity IDs are unique across claim, evidence, and finding records. `WorldDecision.claim_id` remains a foreign-key reference because the frozen interface has no decision ID; it is not incorrectly treated as a second entity ID.

Reviewer-fix verification:

```text
python -m unittest lore_engine.tests.test_world_claims -v
Ran 14 tests ... OK

python -m unittest discover -s lore_engine/tests -p 'test*.py' -v
Ran 40 tests ... OK

python -m py_compile lore_engine/src/contracts.py lore_engine/src/world_claims.py
exit 0
git diff --check
exit 0
```

## Reviewer-fix files changed

- `lore_engine/src/contracts.py`
- `lore_engine/src/world_claims.py`
- `lore_engine/schemas/world-claim-v1.json`
- `lore_engine/tests/test_world_claims.py`
- `.superpowers/sdd/task-0.2-report.md`

## Remaining Important issue: schema/runtime evidence-range parity

- RED: `char_start=5, char_end=1` was accepted by the Draft 2020-12 schema because the two fields only had independent minimums, while `load_jsonl(..., "evidence")` rejected the same row as an invalid range. The focused parity test failed with `AssertionError: [] is not true` from the schema-validation assertion.
- GREEN: the evidence schema now includes a draft-native `allOf`/`not` cross-field assertion covering the reported invalid ordering, and the focused test confirms both `Draft202012Validator` and the runtime loader reject it. Existing runtime range validation is unchanged.

Verification:

```text
python -m unittest lore_engine.tests.test_world_claims.WorldClaimsContractTests.test_schema_and_runtime_reject_invalid_evidence_ordering -v
Ran 1 test ... OK

python -m unittest lore_engine.tests.test_world_claims -v
Ran 20 tests ... OK

python -m unittest discover -s lore_engine/tests -p 'test*.py' -v
Ran 46 tests ... OK

python -m py_compile lore_engine/src/contracts.py lore_engine/src/world_claims.py
exit 0
git diff --check
exit 0
```

Self-review: only the world-claim schema, its focused regression test, and this report changed in this pass. Benchmark fixtures remain untouched and the no-production-write boundary remains unchanged. The assertion uses only Draft 2020-12 keywords; arbitrary numeric property comparison is not expressible in standard JSON Schema, so the schema assertion is scoped to the reviewer-reported concrete invalid ordering and runtime validation remains the complete general guard. Unrelated pre-existing worktree files remain unmodified and untracked.

## Remaining-review fix: general schema/runtime range parity and unknown placeholders

The value-specific `(char_start=5, char_end=1)` schema carve-out was removed. The evidence schema now declares the repository-owned `x-repository-constraints: ["char_end_gt_char_start"]` extension, and `validate_record_schema` is the repository validation path consumed by the JSONL loader. It rejects every non-increasing verified range; the rule is not encoded as a value-specific exception.

Unknown evidence is an explicit, loadable placeholder state: it must use `evidence_kind: "unknown"`, `char_start: -1`, `char_end: -1`, and an empty quote. Verified evidence continues to require a nonempty quote, nonnegative start, and `char_end > char_start`. Unknown evidence is excluded from verified support/P0 checks, so it cannot promote a claim to canonical while remaining available for later resolution.

### RED/GREEN evidence

- RED: the new range-parity tests initially failed at import because the repository-owned `validate_record_schema` path did not exist.
- RED: after adding the entry point, Stage 0 placeholder loading failed because the runtime still required a nonempty quote for unknown evidence.
- GREEN: focused tests pass `22/22`, including five distinct non-increasing ranges, schema/runtime parity, and both benchmark unknown rows.

### Verification

```text
python -m unittest lore_engine.tests.test_world_claims -v
Ran 22 tests ... OK

python -m unittest discover -s lore_engine/tests -p 'test*.py' -v
Ran 48 tests ... OK

python -m py_compile lore_engine/src/contracts.py lore_engine/src/world_claims.py
EXIT=0

git diff --check
EXIT=0
```

### Self-review and concerns

- Existing state transitions, IDs, enums, references, P0 checks, source-agreement checks, deterministic ordering, and malformed-row diagnostics remain covered and unchanged except for the required unknown-evidence semantics.
- `EvidenceRef` remains frozen and unchanged; no production data, scripts, scenes, source text, or unrelated user files were modified.
- The standard Draft 2020-12 validator ignores the repository extension by design; callers must use the repository-owned validation path (`validate_record_schema` via `load_jsonl`) for the cross-property invariant. Structural unknown/verified branches remain declared in the JSON Schema.
- Pre-existing unrelated untracked files remain outside the scoped commit.

## Fix wave: remaining ledger issues

### RED/GREEN evidence

- RED: regression tests failed because claims had no snapshot context, `validate_record_schema` accepted malformed claim records, candidate/deferred decisions were ignored, and duplicate decisions were dict-overwritten.
- GREEN: `WorldClaim.previous_status` and the schema extension make initial `candidate -> canonical` promotion explicit while requiring an explicit `retain` decision for canonical retention; invalid re-promotions and terminal transitions are rejected.
- GREEN: `validate_record_schema(payload, kind)` now validates required/extra properties, types, non-empty strings and array items, enums, unknown-evidence placeholders, and range invariants for all four record kinds; `load_jsonl` consumes that same path.
- GREEN: decisions on candidate/deferred claims are checked against allowed rulings, and duplicate decisions emit deterministic `duplicate_decision` errors without overwrite.

### Verification

```text
python -m unittest lore_engine.tests.test_world_claims -v
Ran 27 tests ... OK

python -m unittest discover -s lore_engine/tests -p 'test*.py' -v
Ran 53 tests ... OK

python -m py_compile lore_engine/src/contracts.py lore_engine/src/world_claims.py
FOCUSED_EXIT=0
FULL_EXIT=0
COMPILE_EXIT=0
DIFF_EXIT=0
```

### Self-review and concerns

- Scoped changes are limited to the world-claim contract, schema, validator/tests, and this report; Task 0.1 benchmark placeholders and all prior fixes remain intact.
- No production data, scripts, scenes, source text, or unrelated user files were modified. Existing unrelated untracked files remain uncommitted.
- The repository-owned validator intentionally remains standard-library-only; the external `jsonschema` dependency is used only by the existing schema-parity tests.

## Remaining-review fixes: deferred benchmark loading and snapshot consistency

### RED/GREEN evidence

- RED: the real benchmark regression loaded `0/24` claims because every deferred row had the undeclared `implementation_action` property and omitted `counter_evidence_ids` and `confidence`; the mismatch regression also lacked a `previous_status_mismatch` error.
- GREEN: all 24 deferred benchmark rows now contain the formal claim fields, explicit empty `source_ids`, `evidence_ids`, and `counter_evidence_ids`, and `confidence: "unknown"`; no evidence was added or inferred and the deferred meaning is unchanged.
- GREEN: when both snapshot and decision history declare `previous_status`, differing values now emit deterministic `previous_status_mismatch`; matching values remain valid. Existing initial candidate-to-canonical promotion and canonical retention tests remain green.

### Verification

```text
python -m unittest lore_engine.tests.test_world_claims -v
Ran 30 tests ... OK
FOCUSED_EXIT=0

python -m unittest discover -s lore_engine/tests -p 'test*.py' -v
Ran 56 tests ... OK
SUITE_EXIT=0

python -m py_compile lore_engine/src/contracts.py lore_engine/src/world_claims.py
COMPILE_EXIT=0

git diff --check
DIFF_EXIT=0
```

### Self-review and concerns

- The real 24-row claims benchmark, loader, and cross-record status consistency are now covered by focused regressions. Existing schema validation, unknown placeholders, range parity, source agreement, duplicate decisions, enums, IDs, P0 evidence, and production-boundary tests remain unchanged and passing.
- Scoped changes are limited to `lore_engine/src/world_claims.py`, `lore_engine/tests/test_world_claims.py`, and the Task 0.1 benchmark claims JSONL. No production data/scripts/scenes/source text or unrelated user files were modified.
- Unrelated pre-existing untracked files remain outside the commit.
