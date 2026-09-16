# Task 0.7 Report: Hard Stage 0 Gate and CLI boundary guard

## Status

Implemented and verified on branch `codex/task-0.5-adjudication-input`, then hardened in a
post-implementation review round (three boundary defects fixed; see "Review fixes").

The real repository result remains the required `NO_GO` with exit code `3`: all 24 target topics are represented, but 0 of the required minimum 20 high-impact claims currently have complete P0 references. No file under `data/`, `scripts/`, `scenes/`, either source text, or the user's unrelated untracked paths was modified.

## Implementation

- Added `world-model-0 --config ... --out ...` to the Python CLI and preserved PowerShell argument/exit-code forwarding through `tools/lore.ps1`.
- The command verifies the config and manifest-backed sources, loads claims/evidence/decisions, runs the read-only implementation auditor, builds the baseline twice, compares deterministic JSON/Markdown content, and writes only the three generated artifacts under the configured output directory.
- Added hard blockers for fewer than 20 complete high-impact P0 references, a target-topic count other than 24, missing topics, unresolved high-impact/P0 claims, failed provenance, non-deterministic output, any changed production path, removals without migration/deprecation treatment, unsafe Q8-G/F1 dispositions, and detected Q8-G/F1 production diffs.
- Added `CONDITIONAL_GO` only when all hard conditions pass and deferred work is non-high-impact; `NO_GO` returns `3`, input/config/source errors return `2`, and unexpected internal failures return `5`.
- Extended baseline generation with a caller-selected config path while retaining the existing default API.
- Generated `world-model-stage0-gate.md` with the exact command, source/output hashes, coverage, unresolved items, legacy dispositions, production-boundary evidence, and forbidden follow-up actions.

## Review fixes

A review round on commit `2eaeece` found three boundary defects in the Gate. All three
are fixed in the same task, and the fixes are reverified below.

1. **The production-path check was blind to committed changes.** `_git_changed_paths`
   diffed against `HEAD`, so it only ever saw uncommitted edits: any production path
   already committed while Stage 0 was in progress would have passed the Gate silently.
   The Gate now takes a **fixed** `pre_stage0_baseline_commit` - the last commit that
   touched production code before Stage 0 work started - and diffs the worktree against
   it. It currently points at `b2aeb2e5cb854cb2ee2cea12647cd6fadd46aa7d` (the D7 commit);
   the original `a7e6596a8b8a84541940c922fbd8b7c720565a2c` was lost when the sandbox
   destroyed the local `.git`, so the pin was re-pointed at the rebuilt D7 commit.
   The value is
   validated as a full 40-character hash, must resolve to a commit, and must be an
   ancestor of `HEAD`; anything else is an input error (`2`).
2. **A weakened config could allow production changes.** `production_write_denylist` was
   read from the config alone, so an emptied list disabled the guard.
   `_production_denylist` now unions the config with a mandatory
   `("data/", "scripts/", "scenes/")` denylist.
3. **Duplicate configured topics inflated coverage.** `_evaluate_stage0_gate` iterated
   the raw `targets` list, so a config with 23 unique topics and one repeat reported
   `24/24` covered. It now iterates `sorted(target_set)` and adds the blocker
   `configured unique target topic count <n> != 24`.

Six new tests cover them: a committed forbidden path is detected; an emptied config
denylist still yields `NO_GO` with `data/gu.json` reported; duplicated topics report
`target_topic_count=23` with the unique-count blocker; an unresolvable baseline returns
`2`; a baseline moved forward to `HEAD` returns `2` with the "fixed pre-Stage-0 baseline"
message; a non-ancestor baseline raises `not an ancestor of HEAD`.

## RED

The CLI tests were added before implementation. The first run failed because the command and orchestration API did not exist:

```text
COMMAND: python -m unittest lore_engine.tests.test_stage0_cli -v
Ran 4 tests in 0.777s
FAILED (errors=4)
Representative failures: invalid choice 'world-model-0'; lore_engine.cli had no build_world_baseline_report attribute.
EXIT=1
```

## GREEN

Required focused suite:

```text
COMMAND: python -m unittest lore_engine.tests.test_stage0_cli lore_engine.tests.test_cli -v
Ran 14 tests in 63.370s
OK
EXIT=0
```

Full lore regression:

```text
COMMAND: python -m unittest discover -s lore_engine/tests
Ran 118 tests in 71.138s
OK
EXIT=0
```

Compilation and whitespace checks:

```text
COMMAND: python -m py_compile lore_engine/cli.py lore_engine/src/reports.py lore_engine/tests/test_stage0_cli.py lore_engine/tests/test_world_claims.py
EXIT=0

COMMAND: git diff --check
EXIT=0
```

## Real Gate and non-regression evidence

```text
COMMAND: tools/lore.ps1 world-model-0 --config lore_engine/config/world-model-stage0.json --out docs/lore/generated
RESULT=NO_GO
EXIT=3
TARGET_TOPICS=24/24
COMPLETE_HIGH_IMPACT_P0=0
PRODUCTION_PATH_CHANGES=0
```

The wrapper was also run twice against the same output directory - once as
`python -m lore_engine.cli world-model-0 ...` and once through `tools/lore.ps1
world-model-0 ...`. Both returned `result=NO_GO` with exit code `3`, and all three
artifacts were byte-identical to the checked-in copies after both runs.

```text
RUN_A (python -m lore_engine.cli, EXIT=3): result=NO_GO
RUN_B (tools/lore.ps1,          EXIT=3): result=NO_GO  -> wrapper forwards result and exit code
REPEATED_IDENTICAL=True
world-model-baseline-v1.json=a173c926ce531deef0b14e6b74cf6466fb59d9413a25af37c8f1519922ad4605
world-model-baseline-v1.md=7f2639f7cbfdbce195413f2f25936f969c61265cc436b81578693b80227a110a
world-model-stage0-gate.md=1c90aa8b3278fdda6f465445c09950b45d96b941d99f12b3d3e16197c1df90ca
PRODUCTION_PATH_CHANGES=0
INGEST_EXIT=0
selected_sections=10
```

`git status --short` was unchanged by both runs, so the command is reproducible against
its own checked-in output. A separate confirmatory two-run comparison into two fresh
temporary directories remains Task 0.8.

The production/source path status check printed no entries for `data/`, `scripts/`, `scenes/`, `蛊真人-clean.txt`, or `《人祖传》.txt`.

## Files

- `lore_engine/cli.py`
- `lore_engine/config/world-model-stage0.json` (adds the fixed `pre_stage0_baseline_commit`)
- `lore_engine/src/reports.py`
- `lore_engine/tests/test_cli.py`
- `lore_engine/tests/test_stage0_cli.py`
- `lore_engine/tests/test_world_claims.py`
- `docs/lore/generated/world-model-baseline-v1.json`
- `docs/lore/generated/world-model-baseline-v1.md`
- `docs/lore/generated/world-model-stage0-gate.md`
- `.superpowers/sdd/task-0.7-report.md`

## Expected blocker

The Gate is intentionally `NO_GO`, not operationally blocked: the benchmark still contains 24 deferred high-impact claims without complete verified P0 coordinates. The command correctly prevents that evidence debt from being reported as success or from authorizing production work.
