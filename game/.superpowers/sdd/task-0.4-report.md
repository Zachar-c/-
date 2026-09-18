# Task 0.4 Report: read-only current-implementation auditor

## Status

Implemented and verified. The auditor reads only the approved current-implementation surfaces and returns frozen-contract `ImplementationFinding` observations. Every finding remains `behavior_status="unknown"` and `migration_action="defer"`; code, data, and design text are never promoted into world truth.

No file under `data/`, `scripts/`, `scenes/`, the source corpus, or runtime configuration was modified. Pre-existing unrelated untracked worktree files were preserved and excluded from the task commit.

## Implementation

- Added `audit_current_implementation(repository_root)` in `lore_engine/src/implementation_audit.py`.
- Approved data reads are limited to `data/gu.json`, `data/schools.json`, `data/balance.json`, and optional `data/recipes.json`.
- Approved text reads are recursive under `scripts/domain/` and top-level Markdown registers under `docs/wiki/concepts/` and `docs/lore/`. `docs/lore/generated/` is intentionally excluded so derived reports cannot feed back into later audit output.
- JSON findings use deterministic JSON-pointer locators. GDScript and Markdown findings use one-based `line:N` locators.
- Finding IDs are deterministic SHA-256-derived IDs over claim ID, surface, normalized repository-relative path, and locator. Output is sorted by claim ID, path, locator, and finding ID.
- Path resolution occurs before every file read and rejects any resolved candidate outside the supplied repository root. The implementation contains no write operation.
- Detectors cover role fallback definitions/candidates, school starter pools, generic rank multipliers, rank/essence/aptitude/lifespan/soul/dao fields, dual essence/true-qi costs, explicit Gu effects, recipe definitions, refinement/feeding/transaction paths, combat/NPC/map/meta hooks, immutable event-log calls, and Q8-G/F1/promotion/material references.

## RED/GREEN evidence

Initial RED, before production code existed:

```text
COMMAND: python -m unittest lore_engine.tests.test_implementation_audit -v
ERROR: ModuleNotFoundError: No module named 'lore_engine.src.implementation_audit'
Ran 1 test
FAILED (errors=1)
EXIT=1
```

Review regression RED, after identifying generated-output feedback:

```text
COMMAND: python -m unittest lore_engine.tests.test_implementation_audit.ImplementationAuditTests.test_generated_lore_outputs_do_not_feed_back_into_register_scan -v
FAIL: generated docs/lore output was included
Ran 1 test
FAILED (failures=1)
EXIT=1
```

Focused GREEN:

```text
COMMAND: python -m unittest lore_engine.tests.test_implementation_audit -v
Ran 5 tests in 0.049s
OK
EXIT=0
```

The fixture's known count is exactly 33 findings. Two identical scans compare equal, the list is correctly sorted, the selected stable ID is `implementation-1da12cbc9eab3b54`, and source locators cover both JSON pointers and line numbers.

Full lore-engine GREEN:

```text
COMMAND: python -m unittest discover -s lore_engine/tests -p 'test*.py' -v
Ran 77 tests in 4.509s
OK
EXIT=0
```

Additional verification:

```text
COMMAND: python -m py_compile lore_engine/src/implementation_audit.py lore_engine/tests/test_implementation_audit.py
EXIT=0
COMMAND: git diff --check
EXIT=0
REAL TREE: finding_count=3375, unique_ids=3375, sorted=True,
           schema_errors=0, generated_paths=0, non_deferred=0
```

## Files changed

- `lore_engine/src/implementation_audit.py`
- `lore_engine/tests/test_implementation_audit.py`
- `lore_engine/tests/fixtures/world_model/game_snapshot/data/gu.json`
- `lore_engine/tests/fixtures/world_model/game_snapshot/data/schools.json`
- `lore_engine/tests/fixtures/world_model/game_snapshot/data/balance.json`
- `lore_engine/tests/fixtures/world_model/game_snapshot/data/recipes.json`
- `lore_engine/tests/fixtures/world_model/game_snapshot/scripts/domain/audit_fixture.gd`
- `lore_engine/tests/fixtures/world_model/game_snapshot/docs/wiki/concepts/audit.md`
- `lore_engine/tests/fixtures/world_model/game_snapshot/docs/lore/audit-register.md`
- `lore_engine/tests/fixtures/world_model/game_snapshot/docs/lore/generated/derived-output.md`
- `.superpowers/sdd/task-0.4-report.md`

## Self-review

- Confirmed all 3,375 real-tree findings have unique IDs, pass the existing finding schema, and use only `data`, `domain`, or `spec` source layers.
- Confirmed no finding makes an alignment or migration ruling; every result is explicitly unknown/deferred.
- Confirmed sorting does not depend on filesystem enumeration order and IDs use normalized forward-slash paths.
- Confirmed an injected out-of-root candidate is rejected before `Path.open`, every normal open uses mode `r`, and fixture bytes are unchanged after the scan.
- Confirmed only the four approved data filenames are considered. The existing `data/refinement_recipes.json` is not scanned because Task 0.4 approves only optional `data/recipes.json`; recipe/refinement behavior can still be observed in approved domain and register text.
- Confirmed generated lore outputs are excluded to avoid self-referential and run-order-dependent findings.
- Confirmed user-owned untracked plan, backup, and probe files remain untouched.

## Concerns

- Text detection is deliberately lexical and conservative. It records candidate hooks/references, not semantic proof, so later baseline adjudication must tolerate repeated or context-only observations.
- JSON findings are occurrence-level. The current `gu.json` therefore contributes many rank and fallback candidates; this is useful provenance but produces a large real snapshot (3,375 rows).
- Line locators and IDs for text findings change when source lines move. They are stable for identical repository content, which is the determinism guarantee for this stage, but are not intended as permanent semantic identifiers across edits.
- `data/recipes.json` is currently absent in the real tree. Expanding the allowlist to similarly named production files requires an explicit later task/spec change.

## Important review fixes: school class semantics and RFC 6901 locators

### Changes

- `_scan_schools` now emits one `school_class_semantics` finding for each explicit class-like assignment. Recognized terms include `class`, `role`, `archetype`, `specialization`, `playstyle`, `profession`, and `vocation`, including compound keys such as `combat_role` through token matching.
- Class-like findings remain implementation observations only: `behavior_status="unknown"`, `migration_action="defer"`, and `source_layer="data"`.
- Added one shared JSON Pointer builder that applies RFC 6901 escaping in the required order (`~` to `~0`, then `/` to `~1`). Every JSON locator emitted by Gu, school, balance, and recipe scanners now uses it.
- Extended the school fixture with `class`, `role`, `archetype`, and `specialization`, and changed its dynamic school ID to `light~/path` so both RFC 6901 escape cases are exercised. The fixture now has exactly 37 findings.
- Added a regression that resolves every emitted data locator back into its fixture JSON value, preventing unescaped or malformed pointers in any JSON scanner.

### RED/GREEN evidence

The two regressions were written before the implementation changes. They failed for the expected missing behavior and invalid locator:

```text
COMMAND: python -m unittest \
  lore_engine.tests.test_implementation_audit.ImplementationAuditTests.test_school_class_like_assignments_are_reported_individually \
  lore_engine.tests.test_implementation_audit.ImplementationAuditTests.test_every_json_locator_is_an_rfc6901_pointer_to_fixture_data -v
FAIL: four school_class_semantics locators were absent
FAIL: data/schools.json#/light~/path/starter_gu_ids contained an invalid `~` escape
Ran 2 tests in 0.026s
FAILED (failures=2)
EXIT=1
```

Focused GREEN after the fixes:

```text
COMMAND: python -m unittest lore_engine.tests.test_implementation_audit -v
Ran 7 tests in 0.069s
OK
EXIT=0
```

Full lore-engine GREEN:

```text
COMMAND: python -m unittest discover -s lore_engine/tests -p 'test*.py' -v
Ran 79 tests in 4.580s
OK
EXIT=0
```

Additional verification:

```text
COMMAND: python -m py_compile lore_engine/src/implementation_audit.py lore_engine/tests/test_implementation_audit.py
EXIT=0
COMMAND: git diff --check
EXIT=0
REAL TREE: finding_count=3375, unique_ids=3375, sorted=True,
           schema_errors=0, pointer_errors=0, non_deferred=0
```

### Self-review

- The approved read allowlist is unchanged; no additional data, script, scene, generated report, or source-text path is scanned.
- Existing finding IDs remain stable whenever their claim, surface, path, and already-valid locator are unchanged. Escaping only changes IDs for keys whose previous locators were not valid RFC 6901 pointers.
- All dynamic JSON object keys pass through the shared encoder, including school IDs and Gu/balance/recipe field names; array indices use the same builder.
- The pointer regression validates syntax and dereferenceability across every fixture data finding rather than testing only one hard-coded school locator.
- Class-like school assignments are recorded independently so mixed semantics stay visible, and no assignment is interpreted as world truth or an automatic migration decision.
- Real `data/schools.json` currently has starter pools but no explicit class-like fields, so the real finding count remains 3,375; future approved fields are detected without widening the scan surface.
- Path-containment, read-only open-mode, non-mutation, deterministic ordering, named detectors, and generated-output exclusion tests remain green.

### Remaining concerns

- Class-like detection is intentionally field-name based. Novel aliases without one of the recognized semantic terms require an explicit detector update rather than inference from arbitrary prose values.
- JSON Pointer locators are stable for identical data. Renaming a dynamic key correctly changes both its locator and finding ID.
