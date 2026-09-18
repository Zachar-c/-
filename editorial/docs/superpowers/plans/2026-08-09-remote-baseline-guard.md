# Remote Baseline Guard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent commits and pushes when local `HEAD` is not based on the freshly fetched `origin/main` baseline.

**Architecture:** A small standard-library Python checker fetches the configured remote branch, then verifies `origin/main` is an ancestor of `HEAD`. Versioned Git hooks invoke that checker, while `AGENTS.md` defines the mandatory workflow and README contains only setup commands.

**Tech Stack:** Python 3 standard library, Git, POSIX shell hooks, `unittest`.

## Global Constraints

- `AGENTS.md` remains the sole complete normative source.
- Do not force-push to bypass the guard.
- Hooks must work from a normal Git for Windows checkout.
- The checker must fail closed when fetch or reference resolution fails.
- Use `apply_patch` for repository edits and test behavior before implementation.

---

### Task 1: Checker Contract and Tests

**Files:**
- Create: `tests/test_check_remote_base.py`
- Create: `scripts/check_remote_base.py`

**Interfaces:**
- Produces: `check_remote_base(repo_root, remote='origin', branch='main', fetch=True, run=None) -> CheckResult`
- `CheckResult` exposes `ok` and `message`.

- [ ] Write temporary-repository tests for an aligned baseline, a remote commit missing locally, and a missing remote-tracking reference.
- [ ] Run `py -3 -m unittest tests.test_check_remote_base -v` and verify it fails because the checker module does not exist.
- [ ] Implement the smallest checker that fetches, resolves `HEAD` and `refs/remotes/<remote>/<branch>`, then runs `merge-base --is-ancestor`.
- [ ] Re-run the test module and verify all tests pass.

### Task 2: Hook Integration

**Files:**
- Create: `.githooks/pre-commit`
- Create: `.githooks/pre-push`

**Interfaces:**
- Both hooks execute `py -3 scripts/check_remote_base.py` from the repository root and forward its exit code.

- [ ] Add portable POSIX shell hooks with the same command path resolution.
- [ ] Configure `core.hooksPath` to `.githooks` in this checkout.
- [ ] Invoke both hook files directly and verify they permit the current synchronized branch.

### Task 3: Workflow Documentation

**Files:**
- Modify: `AGENTS.md` section 12
- Modify: `README.md` after the normative-source section

**Interfaces:**
- `AGENTS.md` specifies fetch/check/rebase behavior and prohibits bypassing the guard.
- README lists only the hook installation and manual checker commands.

- [ ] Add concise mandatory synchronization rules to `AGENTS.md`.
- [ ] Add concise setup commands to README without duplicating editorial rules.

### Task 4: Regression Verification

**Files:**
- Verify only.

- [ ] Run `py -3 -m unittest discover -s tests -v`.
- [ ] Run `py -3 scripts/check_remote_base.py`.
- [ ] Run `py -3 scripts/validate_editorial_assets.py -Phase detail -Volume vol2 -Batch 091-120`.
- [ ] Run `git diff --check` and inspect `git status --short`.
