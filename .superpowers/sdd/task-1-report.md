# Task 1 Report

## Fix

Corrected `tests/unit/test_content_catalog.gd` to use the required
`slice_bright_thread` mapping, require a non-empty `kill_move_id`, require a
matching kill move, and require that its recipe includes the output GU. Fixed
the malformed GDScript declarations and retained explicit `v1_effect` checks.
The negative tests now mutate the `slice_bright_thread` slice as required.

## Verification

Command:

`powershell.exe -File tools/test.ps1 -Test tests/unit/test_content_catalog.gd`

Output summary: `17/21 passed`, `4 failing`, `23/27 asserts`; exit code `1`.
Failures are the missing shipped `slice_bright_thread` recipe, missing
`kill_moves` table, and the not-yet-implemented invalid `v1_effect` validation.

Command:

`powershell.exe -File tools/test.ps1 -Test tests/unit/test_battle_synthesis.gd`

Output summary: `8/9 passed`, `1 failing`, `21/23 asserts`; exit code `1`.
The remaining failure is the pre-existing unknown transaction output contract:
`GuInstance.transaction_ledger()` returns no `error` entry for
`missing_output_gu`.

## Concerns

The requested test-only hardening was applied to `tests/unit/test_content_catalog.gd`: missing `slice_bright_thread`, `v1_battle.kill_moves`, output GU, and `v1_effect` values now use `get` plus type guards, while shipped mapping assertions remain strict.

## Fix Verification

Command:

`powershell.exe -File tools/test.ps1 -Test tests/unit/test_content_catalog.gd`

Output summary: `17/21 passed`, `4 failing`, `24/28 asserts`; exit code `1`.
The four failures are clean assertion failures for absent slice data/validation, with no key-access crashes.

The ledger test already contains `assert_true(result.has("error"))` immediately before reading `result["error"]`; no production files were changed.
