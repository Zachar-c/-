# Task 0.5 Report: explicit Stage 0 adjudication input

## Status

Implemented and verified on branch `codex/task-0.5-adjudication-input`.

The preliminary 24-topic hypothesis table is now explicit adjudication input rather than an accidental production specification. The adjudicator preserves the proposed disposition while separately computing an evidence-gated effective ruling. Because the current benchmark contains no verified P0 source coordinates, every real benchmark row remains effectively `needs_evidence`; none authorizes a production rule.

Implementation commit: `2663d19 feat(lore): add stage0 baseline adjudication`

No file under `data/`, `scripts/`, `scenes/`, the source corpus, or runtime code/configuration was modified. Pre-existing untracked plan, backup, and probe files were preserved and excluded from the commit.

## Implementation

- Replaced the generic 24-row placeholder decision file with deterministic, topic-specific preliminary hypotheses spanning `retain`, `revise`, `remove`, `defer`, and `needs_evidence`.
- Added `adjudicate_baseline(claims, evidence, findings, decisions)` as a pure, deterministic four-layer join.
- Added immutable `BaselineRow`, `BaselineAdjudication`, and `LegacyDisposition` records.
- Each row exposes: claim/topic identity, source fact, derivation, world-model ruling, current implementation observations, preliminary and effective rulings, player consequence, migration/deprecation action, confidence, counter-evidence, and unknowns.
- Findings remain non-authoritative observations. A `partial` finding or its migration suggestion cannot retain a hypothesis automatically.
- Unsupported preliminary `retain`/`revise`/`remove` decisions are downgraded to effective `needs_evidence` until verified P0 support exists.
- P0 support plus P0 counter-evidence forces `needs_evidence` and `NO_GO` unless a verified condition record or explicit human-readable `Scope:`/`Condition:` rationale resolves applicability.
- Removed rules require a non-empty migration/deprecation action or note.
- Decisions require an explicit player-facing consequence, including game adaptations.
- Added explicit dispositions for `q8g_promotion_chain`, `f1_pity`, `school_promotion`, `promotion_materials`, and `promotion_economy`; each is only `audit_only` or `defer`, never `production_ready`.
- Inputs and findings are normalized into deterministic topic/path/evidence ordering. Reversed input collections produce equal results.

## RED

The focused tests were written before the implementation module. The first run failed for the expected missing feature:

```text
COMMAND: python -m unittest lore_engine.tests.test_world_baseline -v
ERROR: ModuleNotFoundError: No module named 'lore_engine.src.world_baseline'
Ran 1 test
FAILED (errors=1)
EXIT=1
```

The test file already contained coverage for all five required review constraints, complete row joins, contradiction handling/resolution, input-order determinism, and the 24-row benchmark.

## GREEN

The required focused command was run twice consecutively:

```text
COMMAND: python -m unittest lore_engine.tests.test_world_baseline -v
Ran 9 tests in 0.007s
OK
EXIT=0

COMMAND: python -m unittest lore_engine.tests.test_world_baseline -v
Ran 9 tests in 0.008s
OK
EXIT=0
```

The complete lore-engine regression passed:

```text
COMMAND: python -m unittest discover -s lore_engine/tests -t . -v
Ran 88 tests in 4.457s
OK
EXIT=0
```

Additional checks:

```text
COMMAND: python -m py_compile lore_engine/src/world_baseline.py lore_engine/tests/test_world_baseline.py
EXIT=0

COMMAND: git diff --check
EXIT=0
```

The real-tree read-only adjudication check produced:

```text
claims=24
evidence_errors=0
decision_errors=0
findings=3375
rows=24
preliminary_rulings=defer,needs_evidence,remove,retain,revise
effective_rulings=needs_evidence
gate=CONDITIONAL_GO
stable=True
row_sha256=66436343ee522cef01458710243fc010a56baba9a09363d772f669564ad6300d
legacy=f1_pity:audit_only,promotion_economy:defer,promotion_materials:defer,q8g_promotion_chain:audit_only,school_promotion:defer
```

`CONDITIONAL_GO` here is the Task 0.5 adjudication-model status, not the final Stage 0 hard Gate. The later Task 0.7 gate remains responsible for rejecting incomplete high-impact source coverage.

## Files

- `lore_sources/benchmarks/world_model_stage0/decisions.jsonl`
- `lore_engine/src/world_baseline.py`
- `lore_engine/tests/test_world_baseline.py`
- `.superpowers/sdd/task-0.5-report.md`

## Self-review

- Confirmed all 24 decision rows load through the frozen `WorldDecision` JSONL schema with zero malformed records and exactly match the target count.
- Confirmed all five requested preliminary ruling values are represented, while the real unverified source claims are downgraded to effective `needs_evidence`.
- Confirmed support and counter-evidence are considered only when explicitly referenced by the claim and when they have P0 authority, non-placeholder ranges, and non-empty exact quotes.
- Confirmed implementation findings cannot supply P0 authority and are rendered in stable path/locator/finding-ID order.
- Confirmed unresolved P0 contradiction produces both `needs_evidence` and `NO_GO`; a verified condition makes the scope explicit and permits the proposed ruling.
- Confirmed removal and player-consequence invariants fail closed with readable `ValueError` messages.
- Confirmed the returned result supports both explicit `.rows` access and deterministic tuple-like iteration for later report consumers.
- Confirmed the five legacy mechanics have no `production_ready` value or code path.
- Confirmed no random, LLM, filesystem write, source-text mutation, or runtime integration was introduced.
- Confirmed only the scoped implementation files were staged in commit `2663d19`; unrelated untracked files remain untouched.

## Concerns

- The 24 decision records intentionally encode preliminary hypotheses, not claim-status transition authorizations. Some proposed rulings therefore differ from the current deferred claim status; consumers must use `adjudicate_baseline` and its effective `ruling`, not apply raw decisions directly to production or pass them off as finalized claim transitions.
- The current benchmark still has only placeholder evidence. Consequently, all real rows remain `needs_evidence`, confidence is `unknown`, and no Stage 0 production work is authorized.
- Human-readable rationale resolution is deliberately explicit: only verified condition evidence or a rationale marked `Scope:`/`Condition:` resolves a P0 support/counter-evidence conflict. Free-form prose is not guessed as a resolution.
- Final `GO`/`NO_GO` policy for overall high-impact coverage, protected-path diffs, and CLI exit codes belongs to Task 0.7; this task enforces the narrower contradiction rule and exposes deterministic gate inputs.

## Critical/Important review fix wave

This section supersedes the earlier statements that the real benchmark produced `CONDITIONAL_GO` and that high-impact hard-gate enforcement could wait for Task 0.7. Task 0.5 now returns `NO_GO` for every unresolved high-impact topic.

### Contract and authorization boundary

- Added backward-compatible `WorldDecision.decision_kind`, with the closed values `preliminary` and `final`; omitted values default to `final` so prior finalized callers retain their behavior.
- Added the same optional field to `world-claim-v1.json` and the JSONL loader.
- Marked every real `decisions.jsonl` row explicitly as `decision_kind="preliminary"`.
- `validate_claim_set` accepts deferred preliminary hypotheses with any of the five preliminary rulings but excludes them from claim-status transition authorization.
- A preliminary decision cannot make `effective_ruling` production-authoritative, even when verified P0 support is supplied.
- A `final` label alone is also insufficient. Effective authorization requires a valid evidence-backed claim-status transition: matching ruling/status, explicit `previous_status`, compatible claim/decision history, and a valid frozen transition.
- `BaselineRow` now exposes `decision_kind`, `preliminary_ruling`, `final_ruling`, and `effective_ruling` separately. Compatibility properties `proposed_ruling` and `ruling` map to the explicit fields without making hypotheses authoritative.

### Hard Gate and contradiction resolution

- Any high-impact row whose effective ruling remains `defer` or `needs_evidence` is a hard blocker and produces `NO_GO`.
- `CONDITIONAL_GO` is limited to unresolved non-high-impact rows after every high-impact row has a verified, finalized effective ruling.
- A P0 support/counterexample contradiction is resolved only when both requirements hold:
  1. the claim explicitly references verified P0 condition evidence whose source participates in both the support and counterexample context; and
  2. the decision rationale contains a non-empty human marker of the form `Scope: ...` or `Condition: ...`.
- Empty markers, rationale-only markers, condition-only evidence, and conditions from unrelated source context remain unresolved and force `needs_evidence`/`NO_GO` for high-impact claims.
- Accepted resolution evidence is retained as structured `condition_evidence` in the output row.

### Independently auditable rows

Each row now keeps structured provenance instead of relying only on flattened display text:

- `support_evidence`: evidence ID, source ID/ref, decoded offsets, quote, authority, and kind;
- `derivation` and `world_model_ruling` as separate text fields;
- `current_findings`: finding ID, path, locator, observation, layer, behavior status, and migration action;
- `player_consequence` and `migration_deprecation_action` as independent fields;
- `condition_evidence` and `counter_evidence_details` with complete evidence provenance;
- `unknowns` as an independent deterministic list.

The existing `source_fact`, `current_implementation`, and `counter_evidence` display tuples remain available for report consumers.

### Review-wave RED

The new regressions were added before contract or adjudicator changes. The first focused run failed for the missing decision kind/schema and row behavior:

```text
COMMAND: python -m unittest lore_engine.tests.test_world_baseline lore_engine.tests.test_world_claims -v
Ran 46 tests in 0.047s
FAILED (failures=1, errors=16)
```

Representative failures were:

```text
TypeError: WorldDecision.__init__() takes from 7 to 8 positional arguments but 9 were given
AttributeError: 'WorldDecision' object has no attribute 'decision_kind'
additional property is not allowed: decision_kind
```

These failures directly demonstrated that the old contract could not distinguish preliminary hypotheses from final transition authority.

### Review-wave GREEN

Contract isolation passed first:

```text
COMMAND: python -m unittest lore_engine.tests.test_world_claims -v
Ran 32 tests in 0.057s
OK
EXIT=0
```

The adjudication and hard-gate suite then passed:

```text
COMMAND: python -m unittest lore_engine.tests.test_world_baseline -v
Ran 15 tests in 0.013s
OK
EXIT=0
```

Combined focused verification:

```text
COMMAND: python -m unittest lore_engine.tests.test_world_baseline lore_engine.tests.test_world_claims -v
Ran 47 tests in 0.066s
OK
EXIT=0
```

Full lore regression:

```text
COMMAND: python -m unittest discover -s lore_engine/tests -t . -v
Ran 96 tests in 6.149s
OK
EXIT=0
```

Additional verification:

```text
COMMAND: python -m py_compile lore_engine/src/contracts.py lore_engine/src/world_claims.py lore_engine/src/world_baseline.py lore_engine/tests/test_world_claims.py lore_engine/tests/test_world_baseline.py
EXIT=0

COMMAND: git diff --check
EXIT=0
```

The real 24-row benchmark was loaded and validated as one complete claim set before adjudication:

```text
load_errors=0
validation_errors=0
findings=3375
rows=24
preliminary=defer,needs_evidence,remove,retain,revise
effective=needs_evidence
gate=NO_GO
blockers=24
stable=True
sha256=ddf44d85f029b461478c17d97f2905b0e771253483c2c4e160b0ad631c20f525
```

### Review-wave files

- `lore_engine/src/contracts.py`
- `lore_engine/schemas/world-claim-v1.json`
- `lore_engine/src/world_claims.py`
- `lore_engine/src/world_baseline.py`
- `lore_engine/tests/test_world_claims.py`
- `lore_engine/tests/test_world_baseline.py`
- `lore_sources/benchmarks/world_model_stage0/decisions.jsonl`
- `.superpowers/sdd/task-0.5-report.md`

### Review-wave self-review

- Confirmed all 24 real decisions explicitly declare `preliminary`, load without schema errors, and validate together with real claims and evidence placeholders.
- Confirmed the validator ignores preliminary rows only for transition authority; duplicate decisions, missing claim references, malformed records, invalid enums, and all existing final-decision checks remain active.
- Confirmed a valid final decision is necessary but not sufficient: verified referenced P0 support and a legal frozen status transition are also required.
- Confirmed all 24 current high-impact benchmark topics are listed as blockers and the result is deterministically `NO_GO`.
- Confirmed `CONDITIONAL_GO` only occurs in the tested case where high-impact coverage is complete and the remaining unresolved item is low impact.
- Confirmed contradiction resolution requires both independently verifiable condition evidence and explicit non-empty scope prose; neither side can resolve a conflict alone.
- Confirmed accepted support, condition, counter-evidence, and implementation findings preserve IDs and source locators in immutable structured detail records.
- Confirmed reversed input order yields the same result and real-tree output hash.
- Confirmed Q8-G, F1 Pity, school promotion, promotion materials, and promotion economy remain only `audit_only`/`defer`.
- Confirmed no `data/`, `scripts/`, `scenes/`, source text, runtime code, or unrelated user file changed.

### Review-wave concerns

- The real benchmark intentionally remains `NO_GO`: it has no verified P0 coordinates and no finalized claim transitions. This is the correct hard-gate result, not a remaining implementation defect.
- Context linkage for contradiction conditions is deliberately conservative under the frozen evidence contract: an accepted condition must be claim-referenced and share a P0 source with both support and counterexample evidence. Cross-source resolutions need an explicit future relation field rather than heuristic inference.
- Omitted `decision_kind` defaults to `final` for compatibility. New hypothesis ledgers must set `preliminary` explicitly, as the real Stage 0 ledger now does.

## Remaining Important review fix wave

### Changes

- Any referenced counter-evidence that is missing, malformed for counterexample use, placeholder/unknown, non-P0, or sourced outside the claim now forces `effective_ruling="needs_evidence"`.
- A high-impact row with such unresolved counter-evidence is therefore a hard blocker and produces `NO_GO`, even when support is verified and the final claim transition is otherwise valid.
- `counter_evidence_details` now retains every present referenced counter record, including placeholders, so unresolved provenance remains auditable rather than disappearing behind an unknown message.
- `condition_evidence` now retains every verified, claim-referenced condition record independently of whether it resolves a contradiction.
- Added `resolved_condition_evidence` for only the conditions that satisfy the strict source-context plus `Scope:`/`Condition:` rationale rule.
- Added deterministic `resolution_status` values: `resolved`, `unresolved`, or `not_required`.
- `validate_claim_set` now emits `missing_claim_reference` for every `ImplementationFinding` whose `claim_id` is absent.
- `adjudicate_baseline` fails closed with a linkage error when an orphan finding is supplied; matched findings remain preserved as structured `current_findings` rows.
- The real 24-topic regression now runs `audit_current_implementation(ROOT)`, validates claims, evidence, all real findings, and decisions as one claim set, adjudicates them, and verifies that every finding ID is retained in exactly its linked row set.

### RED

The regressions were written first. The initial focused run demonstrated all three defects:

```text
COMMAND: python -m unittest lore_engine.tests.test_world_baseline lore_engine.tests.test_world_claims -v
Ran 50 tests in 0.493s
FAILED (failures=3, errors=6)
```

Representative failures:

```text
AssertionError: 'retain' != 'needs_evidence'
AttributeError: 'BaselineRow' object has no attribute 'resolved_condition_evidence'
IndexError: tuple index out of range  # verified condition was discarded
AssertionError: ValueError not raised  # orphan finding was silently dropped
AssertionError: [] != [('missing_claim_reference', ...)]
```

The same run exposed one test-fixture tuple/list concatenation error in the new real-auditor integration. That setup expression was corrected before implementing behavior.

### GREEN

Focused adjudication and claim-contract tests:

```text
COMMAND: python -m unittest lore_engine.tests.test_world_baseline lore_engine.tests.test_world_claims -v
Ran 50 tests in 0.438s
OK
EXIT=0
```

Full lore regression:

```text
COMMAND: python -m unittest discover -s lore_engine/tests -t . -v
Ran 99 tests in 8.202s
OK
EXIT=0
```

Additional checks:

```text
COMMAND: python -m py_compile lore_engine/src/world_claims.py lore_engine/src/world_baseline.py lore_engine/tests/test_world_claims.py lore_engine/tests/test_world_baseline.py
EXIT=0

COMMAND: git diff --check
EXIT=0
```

### Files

- `lore_engine/src/world_baseline.py`
- `lore_engine/src/world_claims.py`
- `lore_engine/tests/test_world_baseline.py`
- `lore_engine/tests/test_world_claims.py`
- `.superpowers/sdd/task-0.5-report.md`

### Self-review

- Confirmed finalized support plus a referenced placeholder counterexample cannot retain a rule and produces high-impact `NO_GO`.
- Confirmed missing counter IDs and present-but-unverified counter records follow the same fail-closed path.
- Confirmed all present referenced counter records remain visible through structured details, while missing IDs remain explicit in `unknowns`.
- Confirmed verified condition records survive in `condition_evidence` when rationale is absent, the marker is empty, or source context is unrelated.
- Confirmed only conditions satisfying both strict context linkage and non-empty human-readable scope prose appear in `resolved_condition_evidence` with `resolution_status="resolved"`.
- Confirmed real auditor findings participate in the same `validate_claim_set` call as the 24 claims, evidence placeholders, and preliminary decisions.
- Confirmed all real finding IDs are retained by the 24 adjudication rows; no unmatched finding is silently discarded.
- Confirmed both validator and adjudicator fail explicitly on synthetic orphan finding references.
- Confirmed prior preliminary/final isolation, status-transition checks, hard high-impact Gate, legacy dispositions, deterministic ordering, and read-only auditing remain covered.
- Confirmed no production path or unrelated user file changed.

### Concerns

- The real benchmark remains intentionally `NO_GO` because all source evidence is still placeholder-only. The added real findings improve implementation traceability but cannot supply P0 authority.
- Missing counter-evidence has no record to serialize; its ID and missing-reference diagnostic are retained in `unknowns`, while present placeholders retain full structured details.
- Orphan findings now fail the whole claim-set/adjudication input rather than being emitted as separate rows. This is deliberate: implementation observations cannot be adjudicated safely without a declared target topic.
