WORKFLOW ROLE:
L3 Worker
UPSTREAM:
Codex Orchestrator
DOWNSTREAM:
Codex Review
PROJECT GOAL:
Deliver Wenzhen as a playable Web strategy/build game, using existing approved mechanics.
CURRENT PHASE:
W1/W2 landed at 7f43b91. This task is a bounded W3 combat trustworthiness repair, NOT all W3 completion.
TASK PURPOSE:
Find and repair concrete differences between visible combat preview/cost/availability and actual action settlement. Highest priority is resource double charge, duplicate damage, wrong preview adapter, or hidden counter leakage.
TASK:
Read root navigation/protocol then game/wenzhen-web-lab/docs/lab-runtime-contract.md and W3 section of docs/superpowers/plans/2026-09-22-lab-playable-game.md. Inspect actual main.js -> CombatCore -> battle.js callers. Establish a short field mapping. Identify at most two related, unequivocal integration defects. Write meaningful failing regression tests against actual main action / UI adapters, then minimally fix and rerun. Do not change existing approved formulas. If rules are ambiguous, report exact inputs/outputs and leave semantics alone. If no defect found, return evidence without speculative refactors. State which W3 criteria remain unverified.
SCOPE:
Read game/wenzhen-web-lab/** and related approved docs. May modify only game/wenzhen-web-lab/js/main.js, js/battle.js, js/combat_core.js and create tests/lab_combat.test.mjs. Ask upstream before any other file. Orchestrator owns progress docs. Existing untracked files are unrelated and must remain untouched. Root C:/Users/90877/work_space/gu-zhenren. main tracked tree initially clean.
DO NOT:
No commit, merge, pull, push, checkout, reset, clean. No game/data edits, balance/price changes, new engine/framework, Godot work, content expansion, killing other sessions or touching secrets. No broad W4 work. No game state injection presented as normal player E2E. No second worker. Tests that need browser must use existing isolated lab_browser helper.
DECISION AUTHORITY:
Mechanical adapter and caller corrections proven by existing rule API and regression tests only.
ESCALATE WHEN:
Concurrent edits to your files, conflicting authority, ambiguous numerical rule, need wider files, architectural choice, inability to run tests.
DELIVERABLE:
A concise packet with STATUS CHANGED FOUND EVIDENCE TESTS RISKS QUESTIONS; include precise pre-fix failing assertions, post-fix counts and file locations. Identify synthetic fixtures vs normal play. Do not claim entire W3 done.
ACCEPTANCE:
Reproduce actual defect with failing regression then passing after fix; focused lab_combat + gu_rules + rules + mvp_logic tests pass; git diff --check; no out of scope change.
STATUS TARGET:
READY_FOR_REVIEW
