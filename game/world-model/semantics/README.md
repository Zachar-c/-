# Game Semantics（Canon → Gameplay 唯一翻译层的可执行语义落点）

> 依 RUL-2026-09-25-001（L0 换基裁定）与 R0 审计（docs/design/canon-runtime/2026-09-25-r0-ownership-audit.md）设立。
> `game/world-model/` 是 Canon 事实到游戏可运行语义的**唯一翻译层**（L1 计划原则）；本目录承载其中可执行、可校验的语义工件。

## 职责与依赖方向

```text
lore/wiki → lore/runtime →（Canon 事实）
game/data（balance/effect_budget 等语义真源）
        ↓ 本层：binding / contract / projection policy
game/data → build_data.mjs → 生成物 → Web Runtime（生产执行器）
```

- 只允许向下投影，禁止反向写入：Game Projection 数值不得回写 lore/wiki 或 lore/runtime（compile_runtime BANNED_KEYS + canon 形状白名单双向锁）。
- Godot domain（`game/scripts/domain/`）为成熟参考规则资产，不是本层的运行时上游。

## 文件清单

| 文件 | 内容 |
|---|---|
| `effect-execution-contract.md` | Effect Execution Contract V1：执行管线、事务纪律、V1 verb 集、新增 verb 路径、No Silent Fallback、Rank 边界 |

## 现行语义真源映射（2026-09-25，P2 批）

| 语义 | SOURCE_OF_TRUTH | 投影/消费 |
|---|---|---|
| role 曲线（30 值） | `game/data/balance.json` `effect_budget.default_amount_by_role` | `wenzhen-web-lab/data/projections.json` `PROJ-LAB-ROLE-CURVE-001` → build_data → 生成物 `DATA.projections.role_curve_lab` |
| role→semantic kind | `game/data/v1_battle.json` `default_effect_by_role.kind` | build_data 映射（amount 已改读投影表；v1_battle 遗留 amount 标注 legacy_godot_fallback_only，待 Godot 迁移批删除） |
| MVP 实验蛊 lab 覆写 | `js/mvp_content.js`（guRef+overrideReason） | `projections.json` `PROJ-LAB-MVP-GU-EXCEPTION-001` 显式登记（父引用+forbidWriteBack） |
| 效果执行 | `js/gu_rules.js` `applyPart`（Effect Semantic Executor） | 未知 verb fail-fast；契约见 `effect-execution-contract.md` |

## 验收锚点

- `game/wenzhen-web-lab/tests/semantics.test.mjs`：批B 五条（真源 30 值 / kind 真源 / 投影全量断言 / 例外登记 / fail-fast）。
- `game/wenzhen-web-lab/tools/check_projection.mjs`：PROJ-LAB-ROLE-CURVE-001 与 PROJ-LAB-MVP-GU-EXCEPTION-001 真实消费者断言。
