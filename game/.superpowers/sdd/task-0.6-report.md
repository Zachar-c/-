# Task 0.6 Report: Baseline v1 JSON/Markdown and frozen provenance

## Status

Implemented and verified on branch `codex/task-0.5-adjudication-input`.

Implementation commit: `b8f488b feat(lore): generate baseline v1 reports`

The generated baseline contains 24 high-impact claims, 24 unresolved high-impact blockers, 3,375 read-only implementation findings, and an honest `NO_GO`. No file under `data/`, `scripts/`, `scenes/`, either source text, runtime code, or any unrelated user-owned path was modified.

Review follow-up completed: report generation now validates every non-placeholder evidence record against the manifest and exact decoded source coordinates before adjudication, and both JSON and Markdown preserve the required source-fact/counter-evidence fields.

## Implementation

- Added `build_world_baseline_report(root, generated_at_utc=...)`, which loads the real Stage 0 config and benchmark ledgers, runs the existing implementation auditor and adjudicator, validates the joined claim set, and verifies both manifest-declared corpus hashes against the real source files.
- Added an explicit reproducible timestamp policy. The builder never reads the wall clock; callers must supply a canonical `YYYY-MM-DDTHH:MM:SSZ` value.
- Frozen SHA-256 provenance for the config, manifest, three benchmark JSONL files, both source files, and a canonical serialization of all implementation findings.
- Added deterministic claim/status/ruling counts, the 24 unresolved high-impact IDs, exact five-item legacy disposition detail and summary, and the existing `NO_GO` result/blockers.
- Preserved per-claim source facts, evidence IDs, source IDs/references, decoded character offsets, authority, and evidence kind. Markdown keeps counter-evidence concise by rendering IDs and locations rather than repeating counterexample text.
- Bounded current-implementation details to 12 deterministic locations per claim, retained total/omitted counts, and froze the complete auditor result with a normalized hash.
- Added Markdown sections `已核验事实`, `偏差候选`, `冲突与未知`, `当前实现映射`, `玩家后果`, `迁移/废止说明`, and `Stage 0 Gate`, plus the required review-table columns and links to existing detailed registers.
- Added canonical LF-terminated writers for `world-model-baseline-v1.json` and `.md`.

## RED

The report tests were written before the implementation. The first focused run failed for the expected missing report API:

```text
COMMAND: python -m unittest lore_engine.tests.test_world_baseline_report -v
ImportError: cannot import name 'build_world_baseline_report' from 'lore_engine.src.reports'
Ran 1 test in 0.001s
FAILED (errors=1)
EXIT=1
```

This proved the new suite exercised behavior absent from the pre-Task-0.6 code.

## GREEN

New report suite:

```text
COMMAND: python -m unittest lore_engine.tests.test_world_baseline_report -v
Ran 5 tests in 1.509s
OK
EXIT=0
```

Required focused suite:

```text
COMMAND: python -m unittest lore_engine.tests.test_reports lore_engine.tests.test_world_baseline_report -v
Ran 6 tests in 1.497s
OK
EXIT=0
```

Full lore regression:

```text
COMMAND: python -m unittest discover -s lore_engine/tests -t . -v
Ran 104 tests in 9.965s
OK
EXIT=0
```

Compilation and whitespace checks:

```text
COMMAND: python -m py_compile lore_engine/src/reports.py lore_engine/tests/test_world_baseline_report.py
EXIT=0

COMMAND: git diff --check
EXIT=0
```

## Generated output and determinism

The real-tree generation used the explicit timestamp `2026-09-16T08:20:35Z` and reported:

```text
gate=NO_GO
claims=24
unresolved=24
findings=3375
world-model-baseline-v1.json=72167 bytes
world-model-baseline-v1.md=27046 bytes
```

A fresh build with the timestamp read back from the checked-in JSON was written twice to temporary directories and compared byte-for-byte with itself and the checked-in artifacts:

```text
json_repeat_equal=True
md_repeat_equal=True
json_checked_in_equal=True
md_checked_in_equal=True
```

## Files

- `lore_engine/src/reports.py`
- `lore_engine/tests/test_world_baseline_report.py`
- `docs/lore/generated/world-model-baseline-v1.json`
- `docs/lore/generated/world-model-baseline-v1.md`
- `.superpowers/sdd/task-0.6-report.md`

## Self-review

- Checked every Task 0.6 brief item against the implementation and tests.
- Confirmed the legacy disposition summary exactly matches `LEGACY_DISPOSITIONS` and contains no `production_ready` value.
- Confirmed all current real claims remain `needs_evidence`, all 24 high-impact IDs remain blockers, and the report displays `NO_GO` rather than softening unresolved evidence.
- Confirmed manifest declarations and actual source fingerprints match and are both serialized, with lowercase SHA-256 values for stable comparison.
- Confirmed report input paths are sorted and hashes are computed from bytes without text normalization.
- Confirmed claim rows are sorted by the existing adjudicator and all nested evidence and implementation locations have deterministic ordering.
- Confirmed source facts are retained in JSON and the Markdown verified-facts section, while counter-evidence remains concise as IDs and source coordinates.
- Confirmed implementation observations are not promoted into evidence or production authority.
- Confirmed the Markdown has all seven required sections, the required columns, links to the existing registers, and a visible `NO_GO` gate.
- Confirmed only the four implementation/artifact files were staged in `b8f488b`; pre-existing untracked plan, backup, and probe files remained untouched.

## Concerns

- The baseline is intentionally `NO_GO`: all 24 benchmark claims still lack verified P0 coordinates and finalized evidence-backed transitions. This is the expected truthful output, not a report-generation defect.
- The Markdown and each JSON claim show at most 12 implementation locations to remain reviewable. The complete 3,375-finding set is frozen by count and normalized SHA-256, while source paths/locators for the displayed sample remain deterministic.
- Reproduction requires reusing the explicit `generated_at_utc` value. Supplying a different valid UTC timestamp intentionally changes both artifacts; no implicit clock value is used.

## Review follow-up verification

- Added real-file fixture coverage proving an exact-offset quote mismatch is rejected before adjudication and a manifest/source hash mismatch remains a deterministic error.
- Added non-vacuous fixture assertions for JSON `source_fact`, Markdown verified facts, and Markdown counter-evidence IDs/locations.
- Strengthened the real-output test with representative non-empty ruling, derivation, consequence, implementation count/location, headings, columns, gate, and register-link assertions.
- `python -m unittest lore_engine.tests.test_reports lore_engine.tests.test_world_baseline_report -v`: 9 tests passed.
- `python -m unittest discover -s lore_engine/tests -t . -v`: 107 tests passed.
- `python -m py_compile lore_engine/src/reports.py lore_engine/tests/test_world_baseline_report.py`: passed.
- Rebuilt twice with the checked-in timestamp: JSON and Markdown were byte-identical to each other and to the checked-in artifacts (`72767` and `27262` bytes respectively).
