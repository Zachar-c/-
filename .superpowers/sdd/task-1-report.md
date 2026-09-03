# Task 1: Route Closure Regression

## Status

Complete. First-run route edges are now closed to the declared route while preserving valid template-defined branches.

## TDD

### RED

Added `test_first_run_filters_template_edges_outside_declared_route` to mutate a template with an out-of-route edge and assert that the generated route filters it and restores the next declared route node as a fallback. The test failed before the production change because `_route_from_ids()` copied template edges unchanged and preserved terminal template edges.

### GREEN

Updated `_route_from_ids()` to:

- Build a set of declared `route_ids`.
- Keep only unique `next_ids` that belong to that set.
- Add the next declared route item when a non-terminal node has no valid remaining successor.
- Force the terminal node to have an empty `next_ids` array.

The existing first-run test now asserts route closure and non-terminal reachability without requiring a linear route, so branch selection semantics remain intact.

## Files

- `scripts/domain/map_generator.gd`
- `tests/unit/test_first_run_route.gd`
- `.superpowers/sdd/task-1-report.md`

## Verification

- `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_first_run_route.gd` — passed, 2/2 tests, 71 asserts.
- `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_map_network.gd` — passed, 6/6 tests, 6376 asserts.
- `git diff --check` — passed with no output.

## Self-review

- No new random calls or state mutation were introduced.
- Template branch edges that point to another declared route node remain available.
- Duplicate successors are removed deterministically while preserving source order.
- Non-terminal route nodes cannot be left without an in-route successor.
- The final route node is always terminal, preventing leaked template edges after the declared route.
- No unrelated worktree changes were modified.

## Concerns

The route builder still assumes every configured `route_id` exists in `node_by_id`; catalog validation is responsible for rejecting unknown IDs before generation.
