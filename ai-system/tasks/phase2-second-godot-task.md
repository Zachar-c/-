# Phase 2 / Godot Worker #002

## Task

修复多敌战斗的胜利掉落 tier 判定。

## Evidence

当前 `LootResolver.settle_victory()` 只从 `battle["enemy_kind"]` 判定 tier；多敌战斗使用 `battle["enemy_kinds"]`，因此包含精英敌人的战斗会回退为 common。`acceptance_driver.gd` 的现有审计注释也记录了这一口径。地图威胁判定已经按多敌中的最高威胁处理，结算应与之保持一致。

## Scope

- 真实行为修复：多敌结算至少包含一个 elite 时使用 elite loot；包含 boss 时使用 boss loot；全为 common 时保持 common。
- 保持单敌 `enemy_kind` 的现有行为。
- 增加或修改最小回归测试，覆盖 common-only、common+elite、boss precedence 与 deterministic behavior（按现有测试结构取必要子集）。
- 预期修改不超过 3 个文件，优先限制在 `game/scripts/domain/loot_resolver.gd` 与 `game/tests/unit/test_loot_tables.gd`。

## Acceptance

1. 多敌 `[common, elite]` 的结算结果使用 elite tier，并产生 elite tier 的绑定行为。
2. 多敌全 common 仍使用 common tier。
3. boss 级敌人存在时不被 elite/common 覆盖。
4. 单敌与同 seed 结果的既有测试保持通过。
5. 不改存档格式、核心数据结构、节点数据或场景；不提交、不 push。

## Worker Protocol

先读根目录 `AGENTS.md`、`PROJECT_MAP.md`、`game/README.md`、`game/AGENTS.md` 与本任务文件。只在当前独立 worktree 内施工。完成后必须返回：理解的边界、修改文件、测试命令与结果、是否需要人工接管、剩余风险。若发现任务需要扩大范围，停止并报告。
