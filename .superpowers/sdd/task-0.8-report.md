# Task 0.8 Report: Full regression and Non-regression Gate

## Status

Executed on `master` at `e1dc69c`, which is pushed to `origin/master`. Every hard
condition was evaluated. The Gate result is **NO_GO**, unchanged from Task 0.7,
because the evidence debt has not moved. No command in this task touched a
production path.

## Environment note (history rebuild)

The sandbox destroyed the local `.git` during Task 0.7, so the original per-task
commits and their objects are gone. Stage 0 was reconstituted from the working
tree as `137bfde` (charter + plan), `b2aeb2e` (D7, which is also the pre-Stage-0
production baseline) and `e1dc69c` (pipeline + gate + the seven task reports). The
baseline pin now points at `b2aeb2e5cb854cb2ee2cea12647cd6fadd46aa7d`. Tasks 0.1
to 0.7 are complete and each is documented in its own report.

## 0.8-1 Full regression

```text
COMMAND: python -m unittest discover -s lore_engine/tests
Ran 118 tests in 67.770s
OK
EXIT=0
```

No network module is imported by the pipeline: grepping `lore_engine` (excluding
tests) for `socket|urllib|http|requests|httpx|aiohttp` imports returns nothing.

## 0.8-2 Source verification

```text
COMMAND: python -m lore_engine.cli ingest --manifest lore_sources/manifest.json --verify-only
EXIT=0
gu_zhenren_main  sha256=bf78d41427e28bb8b64f1ad6d93b971d1a77458abf273e554aabe7f27a155d34
                 bytes=23609617  characters=9024757  encoding=utf-8
ren_zu_zhuan     sha256=e6a6a6187ec69d36957defac0aa644cec494fe2c1b2d2e6c13969fe460b9cab8
                 bytes=155759  characters=82247  encoding=gb18030
selected_sections=10
```

Both fingerprints match the ones recorded in
`docs/lore/generated/world-model-stage0-gate.md`, so no source hash changed.

The Windows wrapper was exercised too:

```text
COMMAND: tools/lore.ps1 ingest --manifest lore_sources/manifest.json --verify-only
EXIT=0, identical fingerprints, selected_sections=10

COMMAND: tools/lore.ps1 world-model-0 --config lore_engine/config/world-model-stage0.json --out docs/lore/generated
EXIT=3 (NO_GO), identical blockers to the direct invocation
```

Capture note: when the wrapper output is captured through PowerShell's
`| Out-String`, the non-ASCII source paths come back mojibake. That is an artifact
of the console encoding in the capture, not of the command - the direct
invocation prints the paths correctly as UTF-8, and hashes and counts are exact
in both.

## 0.8-3 Two-run artifact comparison

```text
COMMAND (run 1): python -m lore_engine.cli world-model-0 --config ... --out .workbuddy/tmp/t08/run1
COMMAND (run 2): python -m lore_engine.cli world-model-0 --config ... --out .workbuddy/tmp/t08/run2

world-model-baseline-v1.json  IDENTICAL  a173-style hash 033aa5246fddcd8882c7ad2c1865d0994473fa1d4cc9715b7b3371fdb71530a7
world-model-baseline-v1.md    IDENTICAL  7f2639f7cbfdbce195413f2f25936f969c61265cc436b81578693b80227a110a
world-model-stage0-gate.md    DIFFERS    line 4 only
```

The gate report records the exact invocation command by design, so running the
gate into two *different* output directories yields two reports whose only
difference is that `--out` value:

```diff
- Exact command: `tools/lore.ps1 world-model-0 --config ... --out .workbuddy/tmp/t08/run1`
+ Exact command: `tools/lore.ps1 world-model-0 --config ... --out .workbuddy/tmp/t08/run2`
```

The artifacts this step names (the baseline JSON and Markdown) are byte-identical,
and the Gate's own determinism condition - build twice inside a run and compare
content - holds. The gate report itself is therefore only comparable for a fixed
`--out`; that is a traceability-versus-comparability trade-off, not a defect.
Re-running into the *same* directory is byte-stable:
`docs/lore/generated/world-model-stage0-gate.md` stayed at
`752eca070668cb41ef72096f811fbbf17c38e80c0e214be48463249ae070c277` across runs and
`git status` showed no change afterwards.

## 0.8-4 Production path manifest (pre/post)

```text
COMMAND: find data scripts scenes -type f -print0 | sort -z | xargs -0 sha256sum
672 files hashed before the task and again after every command above.
PRE/POST DIFF: no differences.
```

This is the strongest non-regression evidence in this task: nothing under `data/`,
`scripts/` or `scenes/` changed, and the working tree still carries only the two
pre-existing untracked leftovers (`tests/unit/test_enemy_roll.gd.local-bak` and
`tools/_tmp_contact_probe.gd`).

## 0.8-5 Boundary and phrasing checks

- **No non-deterministic source reaches the artifacts.** The only hit for
  `random|uuid|time.time|datetime.now|utcnow|secrets` in `lore_engine/src` is
  `database.py`'s migration-ledger timestamp (`("001_initial", datetime.now(UTC)...)`).
  `database.py` is imported by the shared `reports.py`, but the timestamp never
  reaches the baseline - proven by the byte-identical repeated output above.
- **No LLM dependency.** No `openai|anthropic|claude|api_key` usage anywhere in
  `lore_engine` outside tests (the two grep hits are the word `fullmatch`).
- **Generated rows are prospective, not already-applied rules.** The baseline
  table has 24 data rows; every row carries a non-empty 迁移/废止说明, and the
  玩家后果 / 迁移 columns are prohibitions and next steps, for example:
  - `gu_recipe`: "No recipe unlock or execution rule change is authorized." /
    "Defer and verify source-backed knowledge and execution boundaries."
  - `tribulation_or_ascension`: "No tribulation, ascension, or boss-gate
    production rule is authorized." / "Defer until exact P0 evidence and a
    later-stage design are approved."
- **Zero completion-state claims** about production rules
  (`已实施|已落地|已生效|已改为`) appear in the baseline report.
- All seven required sections are present: 已核验事实, 偏差候选, 冲突与未知,
  当前实现映射, 玩家后果, 迁移/废止说明, Stage 0 Gate.
- All 24 rows still carry no evidence IDs, which is precisely the Gate blocker.
- No silent save conversion and no direct data mutation: the pipeline only reads
  the approved paths and writes the three generated artifacts into the configured
  output directory, and 0.8-4 shows production files untouched.

## 0.8-6 Gate result

```text
RESULT=NO_GO   EXIT=3
TARGET_TOPICS=24/24
COMPLETE_HIGH_IMPACT_P0=0
PRODUCTION_PATH_CHANGES=0
```

Blockers, unchanged from Task 0.7:

- `high-impact complete references 0 < 20`
- `high-impact claims missing complete P0 references`: all 24 target topics
- `unresolved high-impact claims`: all 24 target topics

No unresolved P0 conflicts, no non-blocking deferred claims, no changed forbidden
paths. The blocker is evidence, not code: `claims.jsonl` still holds 24 `deferred`
rows with empty `source_ids`/`evidence_ids`, and `evidence.jsonl` still holds only
the two placeholder records.

## 0.8-7 Next step (not started - requires explicit approval)

Per the plan, the first vertical slice (10-20 gu, one identity background, one
route, 2-3 enemies, one refinement scene, one NPC) must not start until this Gate
report is reviewed and approved. Before that approval can be meaningful the 24
high-impact claims need real P0 evidence: quote, exact decoded character offsets
and source hash for at least 20 of them. That is content work on
`lore_sources/benchmarks/world_model_stage0/`, not pipeline code - the pipeline
already rejects unsourced claims, which is why the Gate is honest about the debt
instead of reporting progress it does not have.
