# M0 Core Loop Closure Implementation Plan

> For agentic workers: REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将用户提供的 M0 核心玩法契约落成可执行的阶段基线，并修正 UI 集成测试，使普通战斗默认通过真实战斗结算进入奖励，而不是用投降结束。

**Architecture:** 不改生产战斗规则、数据格式或世界模型。复用现有 `RunController`、战斗命令入口和现有测试驱动逻辑，在 UI 集成测试中增加真实战斗路径；把 M0 的内容上限、闭环和放行条件单独记录为规格文档，避免把现有大体量系统误当成 M0 已验收。

**Global constraints:**

- M0 只验证“观察敌意 → 使用蛊虫 → 管理真元 → 承担结果 → 获得奖励 → 改变 Build → 再战”。
- M0 内容上限为 1 个玩家、6 种蛊虫、3 种普通敌人、1 个 Boss、真元、HP、3 选 1 奖励、4 场战斗。
- 普通战斗 UI 测试优先真实击败；只有专门的终局测试才允许覆盖投降。
- 不修改 `data/`、`scripts/`、领域规则和 Godot 生产场景；不扩展到 M1 的永久成长、复杂地图、炼蛊、喂养或剧情系统。
- 使用 ASCII 命令和文件名，避免在测试命令中引入 shell 转义问题。

## Task 1: Add a failing assertion for real battle victory

**Files:** `tests/integration/test_wenzhen_ui_flow.gd`

1. Add a focused test near the existing generated-run UI tests.
2. Drive a fresh run to an ordinary battle using the existing controller setup.
3. Assert that the path reaches a reward/next-node state through `battle_victory`, and that it does not emit `battle_retreat`.
4. Initially make the assertion against the current battle view before adding the battle helper, so the focused test fails for the missing real-victory behavior rather than silently passing through surrender.
5. Run only this Godot test and record the expected red result.

## Task 2: Implement the test-only real battle driver

**Files:** `tests/integration/test_wenzhen_ui_flow.gd`

1. Add a bounded helper that reads the current battle snapshot, selects an executable attack/damage Gu, submits `use_gu` with the current state version, and ends the turn when no attack is currently usable.
2. Stop only when the controller leaves Battle; never call `retreat` or `surrender` from this helper.
3. Assert the event log contains `battle_victory`, no `battle_retreat`, and the view is the reward or next-node state.
4. Keep the existing surrender coverage as a separately named explicit terminal-path test, not as the normal victory proof.
5. Run the focused UI test until green.

## Task 3: Record the M0 contract and current gate status

**Files:** `docs/superpowers/specs/2026-09-17-m0-core-loop-contract.md`

1. Transcribe the user-provided M0 objective in concise, testable language.
2. Define the five contracts: player decisions, predictable enemy intent, victory/reward/loss conditions, bounded randomness, and loop/time target.
3. Define the exact content cap and explicit non-goals.
4. Define the single M0 pass condition: four consecutive fights, meaningful reward/build differences, and willingness to restart after failure.
5. Map current evidence to the contract and mark unproven items as open instead of inferring them from the larger existing project.
6. Include exact commands for focused UI verification and the integration suite.

## Task 4: Verify and report the stage gate

1. Run the focused UI test.
2. Run `tools/test.ps1 -Suite integration`.
3. Run `git diff --check` and inspect `git status --short`.
4. Report separately: what is now proven, what remains unproven for M0, and whether entering the next implementation stage is allowed.
