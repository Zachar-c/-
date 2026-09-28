# 开发计划与当前进度

> 文件名使用字母 O：`TODO.md`。阶段计划保留原路径，本文件维护入口与本次状态，不复刻所有任务清单。

## CURRENT PHASE

- GOAL：打磨浏览器 Web 版《问真》为完整、可长期游玩的单机产品。
- ACTIVE：执行 2026-09-25 L0 优先级链（RUL-2026-09-25-001）：P0 补 RULES 簇独立 benchmark 缺口 → P1 打通月光体系 Canon Runtime → P2 Game Semantics + Effect Contract → P3 Conformance（C1–C5）→ P4 无核心 fallback 的 Rank1 垂直切片 → P5 批量扩展蛊虫；「先证明知识能够变成规则，再扩大知识数量」。lab 整局打磨随切片推进。 GitHub 执行跟踪：[GitHub #8](https://github.com/Zachar-c/-/issues/8)；Runtime scale-out：[GitHub #7](https://github.com/Zachar-c/-/issues/7)。
- COMPLETED：异闻事件已进入种子化路线（只开放可完整结算的即时气血/元石事件）；新增五段场景图与四个专属层主肖像；稳定进行中存档兼容口径；大厅加入最近 24 局旧录与种子复走。
- CONTENT GATE：已建立 `saveCompatibilityVersion`（当前 `lab-run-v2`，材料循环移除后迁移旧字段）；`contentVersion` 仍标记完整内容快照。新增文案、美术与兼容内容不阻断进行中存档；状态结构或规则发生破坏性变化时须提升兼容版本并处理迁移。
- REVALIDATE：2026-09-26 浏览器整局复核完成，四项全绿（seed 103 normal 胜利、两次重载 0 diff、7 例异闻精确结算、旧种子复走一致；laya 辅助判定一致；胜利种子广度仍为 1，扩面属后续批次）：[验收记录](game/wenzhen-web-lab/docs/2026-09-26-lab-full-run-acceptance.md)。
- DECISIONS：Web 主入口为 `game/wenzhen-web-lab/lab.html`；Godot 作为规则和数据来源；美术可原创；不以短流程切片作为最终交付；Knowledge Ready ≠ Game Ready——GAME_GENERATION_READY 需 benchmark≥45 + Runtime 编译 + 无占位 + Semantics binding + conformance + 无核心 fallback（RUL-2026-09-25-001）。
- NEXT：浏览器整局复核已完成（2026-09-26，四项全绿，见 REVALIDATE）；**批B 已执行完毕待复核收口**——RUL-2026-09-26-001 落地：lab 曲线换基（sqrt_budget_scalar_projection_v1，attack [1,2,2,3,4] 等六条）、敌方压缩表重基（改伤随表 25 处）、MVP 例外五字段重基（refDpr 2.5→1.5）、参考层敌 HP 自动重推导（8/9/14/15→5/5/8/9 四窗全落）；check_projection 60/60、check_balance 49/49、测试 264 中 263 过（唯一失败=B 线预存）、换基后真实整局 seed 103 victory；结果包 [p3b1-role-curves-result.md](ai-system/tasks/p3b1-role-curves-result.md)；真实层 hp 零手调（envelope 比率 1.0）；真实局变易属 V5 校准议题；魂轴 lab-run-v2 事实刷新已落盘（2026-09-26，[刷新件](ai-system/RESEARCH-REQUEST-2026-09-26-soul-axis-fact-refresh.md)，八项取证全带行号），待按「刷新件 + 旧件 §3/§6」重派 L1（Q3：矛盾仍在按 S1–S5，不得用旧 200 局调难度）。
- DO NOT：不把 `mvp.html` 短剧本当作完整产品；不因平台选择重写已有规则；数值调整遵循现有 L1/L0 边界；不得在 Effect Executor 内加隐藏 Rank 倍率；不得为肉鸽需要直接新增 effect verb（必须走 Canon→Semantics→verb）。

## 项目进度入口

- Monorepo 迁移已完成，记录见 [MIGRATION.md](MIGRATION.md)，不重新开启迁移计划。
- **当前玩法主线**：[构筑分叉重建计划](docs/superpowers/plans/2026-09-25-build-fork-rebuild.md)（Phase 0–7 DONE；Phase 8 批A DONE，批B ×3 真元曲线 BLOCKED 等 L1，请求件 [RESEARCH-REQUEST-2026-09-23-phase8-rank-essence-curve.md](ai-system/RESEARCH-REQUEST-2026-09-23-phase8-rank-essence-curve.md) 仍 PENDING_L1；Phase 8 跟踪：[GitHub #5](https://github.com/Zachar-c/-/issues/5)；注意与 NEXT 行的批B（role curves）是两个批，勿混）。
- 2026-09-25 L0 换基裁定：[RUL-2026-09-25-001](game/world-model/rulings/RUL-2026-09-25-001.json)、[评审件 ANSWER](ai-system/RESEARCH-REQUEST-2026-09-25-dormant-asset-rebase.md)（Effect Execution Contract、曲线真源、魂轴刷新、conformance 恢复、GAME_GENERATION_READY 门禁、P0–P5 链）。
- Web 阶段记录：[W0–W7 计划](docs/superpowers/plans/2026-09-22-lab-playable-game.md)。其中开发里程碑保留作历史证据，不能替代当前长线产品验收。
- 2026-09-24 阶段任务记录：[Web 优化任务拆分](docs/superpowers/plans/2026-09-24-wenzhen-web-optimization-tasks.md)。以 CURRENT PHASE 的后续裁定与验收状态为准。 未完成项分别见：WOPT-06 [GitHub #2](https://github.com/Zachar-c/-/issues/2)、WOPT-07 [GitHub #3](https://github.com/Zachar-c/-/issues/3)、WOPT-08 [GitHub #4](https://github.com/Zachar-c/-/issues/4)。
- 本轮会话还原点：[会话收敛归档](docs/superpowers/reports/2026-09-24-session-consolidation.md)（含 gpt6sol 检索关闭结论）。
- 待复核事项与历史发布边界：[docs/debt.md](docs/debt.md)。 当前开放债务索引：[GitHub #1](https://github.com/Zachar-c/-/issues/1)、[GitHub #6](https://github.com/Zachar-c/-/issues/6)、[GitHub #7](https://github.com/Zachar-c/-/issues/7)、[GitHub #9](https://github.com/Zachar-c/-/issues/9)、[GitHub #10](https://github.com/Zachar-c/-/issues/10)、[GitHub #11](https://github.com/Zachar-c/-/issues/11)、[GitHub #12](https://github.com/Zachar-c/-/issues/12)。
