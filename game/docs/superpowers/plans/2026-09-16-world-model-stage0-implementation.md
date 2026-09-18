# World Model Stage 0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立《問眞》世界模型基准审计的可重复 Stage 0 流程，产出至少 20、目标 24 条高影响 `world_claim` 的证据链、当前实现映射、冲突裁决和硬 Gate 结果；在 Gate 通过前不修改任何生产规则、`data/`、Godot 场景或领域脚本。

**Architecture:** 复用现有本地优先 `lore_engine`。原文通过已核验的只读 manifest 和稳定章节/文本偏移进入证据层；人工或离线抽取的候选进入独立的 world-claim ledger；实现审计器只读取当前 `data/`、`scripts/domain/`、关键设计登记册并生成实现快照；裁决器根据证据等级、反证和适配边界输出 Baseline v1。最终报告和 JSON 快照都是可重建派生物，不进入 Godot 运行时。

**Tech Stack:** Python 3.12 标准库、SQLite/FTS5（复用现有 Lore Compiler）、JSON Schema/JSONL、PowerShell 统一入口、Python `unittest`；离线默认，测试不依赖网络或 LLM。

## Global Constraints

- 本计划只覆盖 World Model Stage 0；Stage 0 通过以前，阶段 1--6 只能调查、记录和设计，不能改生产规则。
- 当前最高设计宪章是 `docs/superpowers/specs/2026-09-16-wenzhen-world-model-correction-design.md`。`docs/superpowers/plans/2026-08-27-novel-to-game-phase-0-1-implementation.md`、Q8-G、F1 Pity、19 流派晋升链、80 材料和 promotion economy 仅作为历史/待审计材料；Stage 0 不实现或恢复其中任何生产行为。
- `gu-zu/` 下原文只读。读取必须沿用 manifest 的严格编码、SHA-256 和路径边界检查；不得复制整段原文进仓库，测试只使用短引文或本地小型 fixture。
- 证据优先级固定为：`蛊真人-clean.txt` / 《人祖传》原文 P0，已核验检索记忆库 P1，现有代码与数据 P2，旧设计文档 P3。P2/P3 不能反向证明 P0。
- 第 4 节审计表只是初步假设/偏差候选；任何候选进入 `Baseline v1` 前必须有原文证据位置、推导链、反证检索结果、置信度和适配裁决。未知项必须显式保留，不能以“代码已有”自动确认为事实。
- 只允许修改 `lore_engine/`、`lore_sources/` 下 Stage 0 配置/fixture、`docs/lore/generated/` 报告、`docs/lore/` 的审计说明、Stage 0 专用测试和 `tools/lore.ps1`/CLI 接线。禁止修改 `data/`、`scripts/`、`scenes/`、运行时存档格式和用户当前未提交的地图改动。
- 审计结果不得绕过领域层直接成为游戏规则；不得引入非确定 RNG；不得用 LLM 作为裁决器；任何未来迁移/废止建议必须先写入 Baseline 的 disposition，不得偷偷兼容旧行为。
- 所有输出必须确定性排序、带源指纹和生成器版本；同一工作树、同一输入、同一命令重复运行应产生相同 JSON 内容和相同 Markdown 内容。
- 每个任务先写失败测试，再写最小实现，再运行定向测试和全套 lore 回归；每个阶段必须执行 Non-regression Gate。

## File Responsibility Map

```text
lore_engine/
  cli.py                              # world-model-0 命令、退出码和路径接线
  config/world-model-stage0.json     # 24 条目标 claim、阈值、允许扫描路径和版本
  schemas/world-claim-v1.json        # claim/evidence/decision/baseline JSON 契约
  src/contracts.py                   # 稳定 dataclass 与枚举
  src/world_claims.py                # claim ledger、状态机、完整性校验
  src/world_evidence.py              # 原文定位、短引文对齐、反证/覆盖计算
  src/implementation_audit.py        # 只读扫描当前游戏数据/代码/登记册
  src/world_baseline.py              # 裁决矩阵、Q8-G disposition、Gate 结果
  src/reports.py                     # 复用报告出口并增加 Baseline Markdown/JSON
  tests/test_world_claims.py
  tests/test_world_evidence.py
  tests/test_implementation_audit.py
  tests/test_world_baseline.py
  tests/test_stage0_cli.py
  tests/fixtures/world_model/         # 短文本、候选、冲突和实现扫描 fixture

lore_sources/
  benchmarks/world_model_stage0/
    claims.jsonl                      # 24 个有明确主题的人工基准 claim
    evidence.jsonl                    # 可回查的短引文/偏移/来源等级
    decisions.jsonl                   # 初步裁决与未知项，不能直接写入游戏数据

docs/lore/generated/
  world-model-baseline-v1.json       # 可重建的机器快照
  world-model-baseline-v1.md         # 面向设计/施工的审计报告
  world-model-stage0-gate.md         # GO/NO-GO 与 Non-regression 证据
```

## Stable Interfaces

在 Task 0.2 锁定以下接口；后续任务不得改名，只能扩展兼容字段：

```python
@dataclass(frozen=True)
class WorldClaim:
    claim_id: str
    topic: str
    statement: str
    status: str                    # candidate/canonical/derived/adaptation/rejected/deferred
    impact: str                    # high/medium/low
    source_ids: tuple[str, ...]
    evidence_ids: tuple[str, ...]
    counter_evidence_ids: tuple[str, ...]
    confidence: str                # high/medium/low/unknown

@dataclass(frozen=True)
class EvidenceRef:
    evidence_id: str
    source_file_id: str
    source_ref: str
    char_start: int
    char_end: int
    quote: str
    authority: str                 # primary_text/in_world_text/secondary_note/code/design
    evidence_kind: str             # support/condition/counterexample/unknown

@dataclass(frozen=True)
class ImplementationFinding:
    finding_id: str
    claim_id: str
    path: str
    locator: str
    observed: str
    source_layer: str              # data/domain/presentation/spec
    behavior_status: str           # aligned/partial/conflict/unknown/not_implemented
    migration_action: str          # retain/revise/remove/defer

@dataclass(frozen=True)
class WorldDecision:
    claim_id: str
    ruling: str                    # retain/revise/remove/defer/needs_evidence
    rationale: str
    player_consequence: str
    implementation_action: str
    non_regression_notes: tuple[str, ...]

@dataclass(frozen=True)
class Stage0Gate:
    result: str                    # GO/NO_GO/CONDITIONAL_GO
    claim_count: int
    high_impact_covered: int
    unresolved_high_impact: tuple[str, ...]
    production_paths_changed: tuple[str, ...]
    deterministic: bool
```

稳定 CLI 入口为：

```powershell
tools/lore.ps1 world-model-0 --config lore_engine/config/world-model-stage0.json --out generated/lore/world-model-stage0
```

退出码沿用项目约定：`0=Gate 通过或有条件通过`、`2=输入/配置错误`、`3=质量 Gate 失败`、`5=内部错误`。`NO_GO` 必须返回 `3`；不能用成功退出码掩盖未覆盖的高影响 claim 或生产路径改动。

---

## Task 0.1: 固定 Stage 0 输入、输出和生产边界

**Files:**
- Modify: `lore_engine/config/world-model-stage0.json`
- Modify: `lore_sources/manifest.json` only if the existing source declaration needs the Stage 0 benchmark metadata; do not change existing source hashes
- Add: `lore_sources/benchmarks/world_model_stage0/claims.jsonl`
- Add: `lore_sources/benchmarks/world_model_stage0/evidence.jsonl`
- Add: `lore_sources/benchmarks/world_model_stage0/decisions.jsonl`
- Add: `lore_engine/tests/fixtures/world_model/invalid_claim.json`
- Test: `lore_engine/tests/test_world_claims.py`

- [ ] Write a failing test that loads the Stage 0 config and asserts exactly 24 unique high-impact claim IDs, `minimum_claims=20`, the two P0 source IDs, and an allowlist that excludes `data/`, `scripts/`, and `scenes/`.
- [ ] Write a failing test that rejects a benchmark record with a missing source/evidence reference, an invented status, a P0 claim without a source citation, or an `implementation_action` that directly edits a production path.
- [ ] Add the config with the fixed audit topics: `gu_is_life`, `gu_is_independent_entity`, `cultivator_aperture`, `aptitude_capacity`, `primeval_essence`, `rank_and_subrank`, `gu_refinement`, `gu_ownership`, `gu_feeding`, `gu_activation`, `natal_gu`, `gu_recipe`, `kill_move`, `information_leak`, `dao_marks`, `mortal_immortal_boundary`, `lifespan`, `soul`, `body_and_blood`, `force_and_social_order`, `inheritance`, `economy_and_primeval_stones`, `tribulation_or_ascension`, and `world_scope_and_compression`.
- [ ] Give every benchmark row a provisional status and require `candidate`/`deferred` when source verification is incomplete; do not encode the five review examples as settled facts merely because their subjects are listed.
- [ ] Run `python -m unittest lore_engine.tests.test_world_claims -v` and verify the new tests pass while the pre-existing lore tests remain unchanged.

**Expected result:** Stage 0 has a versioned, auditable input contract and an explicit no-production-write boundary; the benchmark contains 24 target slots and at least 20 rows with complete references or explicit deferred status.

## Task 0.2: Implement the world-claim ledger and schema validation

**Files:**
- Modify: `lore_engine/src/contracts.py`
- Add: `lore_engine/src/world_claims.py`
- Add: `lore_engine/schemas/world-claim-v1.json`
- Test: `lore_engine/tests/test_world_claims.py`

- [ ] Add tests for valid claim/evidence/decision records, duplicate IDs, invalid enums, missing high-impact topics, status transitions, and the minimum-20 threshold.
- [ ] Implement frozen dataclasses matching the Stable Interfaces and a loader that reads JSONL in deterministic path/line order.
- [ ] Implement `validate_claim_set(records, config)` so it checks topic coverage, evidence references, authority/status compatibility, unique IDs, and that `canonical` cannot be created without P0 evidence.
- [ ] Implement the status transition rule: `candidate -> canonical|derived|adaptation|rejected|deferred`; `canonical -> derived|adaptation|deferred` only through an explicit new decision; `rejected` is terminal for the current baseline.
- [ ] Validate JSON records using the repository’s standard-library approach and return structured errors with file and line context; do not silently drop malformed rows.
- [ ] Run `python -m unittest lore_engine.tests.test_world_claims -v` and verify invalid fixtures fail with exit status captured by the test rather than crashing the test runner.

**Expected result:** A claim cannot silently become canon, disappear due to malformed JSONL, or bypass the evidence/status state machine.

## Task 0.3: Add source evidence, offsets, and contradiction checks

**Files:**
- Add: `lore_engine/src/world_evidence.py`
- Add: `lore_engine/tests/fixtures/world_model/short_primary.txt`
- Add: `lore_engine/tests/fixtures/world_model/short_conflict.txt`
- Test: `lore_engine/tests/test_world_evidence.py`

- [ ] Write failing tests that require a quote to occur exactly once at the declared character offsets, reject byte/character offset confusion, reject source hash mismatch, and reject evidence whose source authority is lower than the claim’s asserted status.
- [ ] Write a failing test for a supported claim with a condition and a counterexample, ensuring both are retained in the baseline instead of being collapsed into a single boolean.
- [ ] Implement `resolve_evidence(root, manifest, evidence_refs)` by reusing `source_manifest.read_source` and exact decoded character offsets; do not normalize text before alignment.
- [ ] Implement `check_claim_coverage` and `find_counter_evidence` over the indexed source/chunk data and existing seed records; a secondary note can discover a candidate but cannot upgrade it to P0.
- [ ] Store only short quote text, source IDs, offsets, hashes and references in benchmark files; never copy long passages from the novel.
- [ ] Run `python -m unittest lore_engine.tests.test_world_evidence lore_engine.tests.test_source_manifest -v` and verify the real manifest still passes strict source verification.

**Expected result:** Every accepted or deferred world claim is traceable to exact source coordinates, and contradictory/conditional evidence remains visible to reviewers.

## Task 0.4: Build a read-only current-implementation auditor

**Files:**
- Add: `lore_engine/src/implementation_audit.py`
- Add: `lore_engine/tests/fixtures/world_model/game_snapshot/`
- Test: `lore_engine/tests/test_implementation_audit.py`

- [ ] Write failing tests against a fixture tree containing a role fallback, class-like school data, a generic rank multiplier, a dual resource field, an explicit Gu effect, a recipe, and an immutable event-log call; assert stable finding IDs and source locators.
- [ ] Implement read-only scanners for the approved current paths: `data/gu.json`, `data/schools.json`, `data/balance.json`, `data/recipes.json` when present, `scripts/domain/`, and the existing `docs/wiki/concepts/`/`docs/lore/` registers.
- [ ] Detect and report, without deciding world truth, the known audit surfaces: `default_v1_effect` role fallback; schools with starter pools/class semantics; `rank`/`essence`/`aptitude`/`lifespan`/`soul`/`dao` fields; explicit vs fallback Gu effects; refinement/feeding/transaction paths; combat, NPC, map and meta hooks; Q8-G/F1/promotion/material references.
- [ ] Make scan output a pure `ImplementationFinding` list sorted by claim ID, path, locator, and finding ID. Read files only; never rewrite or format production files.
- [ ] Add a path-safety test that fails if the auditor opens a path outside the repository or writes under any production path.
- [ ] Run `python -m unittest lore_engine.tests.test_implementation_audit -v` and inspect the generated finding count against the fixture’s known count.

**Expected result:** Baseline rows can show “原著事实 → 当前实现” without treating current implementation as evidence, and the audit itself cannot mutate the game.

## Task 0.5: Encode the preliminary hypothesis table as explicit adjudication input

**Files:**
- Modify: `lore_sources/benchmarks/world_model_stage0/decisions.jsonl`
- Add: `lore_engine/src/world_baseline.py`
- Test: `lore_engine/tests/test_world_baseline.py`

- [ ] Write failing tests for all five review constraints: Q8-G/F1 is audit-only; unresolved source claims remain `needs_evidence`; a partial implementation is not automatically retained; a removed rule has a migration/deprecation note; a game adaptation has an explicit player-facing consequence.
- [ ] Add deterministic decision rows for the 24 topics. The rows must distinguish `retain`, `revise`, `remove`, `defer`, and `needs_evidence`; use `defer`/`needs_evidence` wherever the clean text and 《人祖传》 have not yet been verified.
- [ ] Implement `adjudicate_baseline(claims, evidence, findings, decisions)` to join the four layers and emit one complete row per target topic: source fact, derivation, world-model ruling, current implementation, ruling, player consequence, migration/deprecation action, confidence, counter-evidence, and unknowns.
- [ ] Implement explicit disposition records for legacy mechanics: `q8g_promotion_chain`, `f1_pity`, `school_promotion`, `promotion_materials`, and `promotion_economy`. Their Stage 0 disposition may be `audit_only` or `defer`, but never `production_ready`.
- [ ] Implement a contradiction rule: if P0 support and P0 counter-evidence both exist without a human-readable scope/condition resolution, the claim is `needs_evidence` and the Gate cannot be `GO`.
- [ ] Run `python -m unittest lore_engine.tests.test_world_baseline -v` and verify the report rows are stable across two runs.

**Expected result:** The old audit table becomes a controlled hypothesis-to-ruling pipeline rather than an accidental code specification.

## Task 0.6: Generate Baseline v1 JSON/Markdown and freeze provenance

**Files:**
- Modify: `lore_engine/src/reports.py`
- Add: `lore_engine/tests/test_world_baseline_report.py`
- Generate: `docs/lore/generated/world-model-baseline-v1.json`
- Generate: `docs/lore/generated/world-model-baseline-v1.md`

- [ ] Write failing tests that require report metadata: baseline version, generator version, UTC generation timestamp policy, source manifest hashes, input file hashes, claim counts, unresolved high-impact claims, and exact legacy disposition summary.
- [ ] Write a golden-output test that checks the Markdown contains the required table columns and the sections “已核验事实”, “偏差候选”, “冲突与未知”, “当前实现映射”, “玩家后果”, “迁移/废止说明”, and “Stage 0 Gate”.
- [ ] Implement deterministic JSON serialization and Markdown rendering with fixed ordering; timestamps must be either omitted from content hashes or supplied through an explicit reproducible mode so repeated runs compare equal.
- [ ] Include per-claim evidence IDs and source locations, but keep the generated report concise enough to review; link to existing detailed registers instead of copying long source text.
- [ ] Generate the first report from the real manifest plus benchmark records and record unresolved claims honestly. Do not edit `data/`, `scripts/`, `scenes/`, or any current user-owned map files to make the report pass.
- [ ] Run `python -m unittest lore_engine.tests.test_reports lore_engine.tests.test_world_baseline_report -v` and compare two generated JSON files byte-for-byte.

**Expected result:** Reviewers receive one reproducible `World Model Baseline v1`, with provenance and unknowns visible rather than hidden behind confident prose.

## Task 0.7: Add the hard Stage 0 Gate and CLI boundary guard

**Files:**
- Modify: `lore_engine/cli.py`
- Modify: `tools/lore.ps1` only if argument forwarding needs an explicit `world-model-0` example or validation
- Add: `lore_engine/tests/test_stage0_cli.py`
- Add: `docs/lore/generated/world-model-stage0-gate.md`

- [ ] Write failing CLI tests for: successful `CONDITIONAL_GO`, `NO_GO` with exit code `3`, missing source/config with exit code `2`, and a simulated production-path diff that always fails the Gate.
- [ ] Implement `world-model-0` as a read-only command that verifies sources, loads claims/evidence/decisions, runs the implementation auditor, generates the baseline, and writes only to the configured output directory.
- [ ] Implement the hard Gate exit conditions: at least 20 high-impact claims with complete references; all 24 target topics represented; all unresolved P0 conflicts listed; deterministic repeated output; no production paths changed; every proposed removal has migration/deprecation treatment; no Q8-G/F1 production change detected.
- [ ] Return `CONDITIONAL_GO` when the minimum evidence/report requirements pass but any non-blocking claim remains deferred; return `NO_GO` when a high-impact claim is missing, a P0 conflict is unresolved, a provenance check fails, or any forbidden production path changes.
- [ ] Add the Stage 0 Gate report with the exact command, source hashes, output hashes, claim coverage, unresolved items, legacy dispositions, and a list of explicitly forbidden follow-up actions before Gate approval.
- [ ] Run `python -m unittest lore_engine.tests.test_stage0_cli lore_engine.tests.test_cli -v` and verify `tools/lore.ps1 world-model-0 ...` forwards the same result on Windows.

**Expected result:** Stage 0 is a real hard boundary. A passing report authorizes planning the next vertical slice; it does not authorize production implementation by itself.

## Task 0.8: Execute the full regression and Non-regression Gate

**Files:**
- Test only: all existing `lore_engine/tests/`
- Verify only: `data/`, `scripts/`, `scenes/`, current working-tree user files
- Generate: final `docs/lore/generated/world-model-stage0-gate.md`

- [ ] Run `python -m unittest discover -s lore_engine/tests -v`; expected result is zero failures and no network access.
- [ ] Run `tools/lore.ps1 ingest --manifest lore_sources/manifest.json --verify-only`; expected result is both source fingerprints plus the selected-section diagnostic, with no hash changes.
- [ ] Run the Stage 0 command twice into separate temporary output directories and compare JSON/Markdown hashes; expected result is identical content.
- [ ] Capture a pre/post path manifest for `data/`, `scripts/`, and `scenes/`; expected result is no changes. Treat all existing user modifications listed by `git status --short` as pre-existing and preserve them.
- [ ] Verify every generated row has domain-layer implications phrased as a future implementation instruction, not an already-applied rule; verify no non-deterministic RNG, LLM rule decision, direct data mutation, or silent old-save conversion was introduced.
- [ ] If any hard condition fails, publish `NO_GO` with the exact blocking claim/path and stop; do not proceed to vertical-slice production work.
- [ ] Only after the Gate report is reviewed and explicitly approved should a separate plan be written for the first vertical slice: 10--20 Gu, one identity background, one route, 2--3 enemies, one refinement scene, and one NPC.

**Expected result:** A complete, auditable Stage 0 handoff exists, while the game’s current production implementation and the user’s unrelated worktree changes remain untouched.

## Execution Notes

- Do not implement F1 Pity, Q8-G promotion, school expansion, material economy, or any replacement world rule while executing this plan.
- Do not expand the existing 802-Gu/20-school content pool. The first content slice is a later Gate-controlled plan, not part of Stage 0.
- If existing `lore_engine` interfaces conflict with this plan, preserve existing V1 commands and add compatible modules; do not break the existing lore compiler regression suite to simplify Stage 0.
- The existing 2026-08-27 lore-engine plan remains historical implementation context. This plan is the narrower, higher-priority World Model Stage 0 gate required by the 2026-09-16 design charter.
