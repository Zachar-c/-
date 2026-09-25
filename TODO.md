# 开发计划与当前进度

> 文件名使用字母 O：`TODO.md`。阶段计划保留原路径，本文件维护入口与本次状态，不复刻所有任务清单。

## CURRENT PHASE

- GOAL：打磨浏览器 Web 版《问真》为完整、可长期游玩的单机产品。
- ACTIVE：继续扩充五段路线的有效选择、长期成长与结局内容，并复核整局难度、奖励节奏和胜利路线。
- COMPLETED：异闻事件已进入种子化路线（只开放可完整结算的即时气血/元石事件）；新增五段场景图与四个专属层主肖像；稳定进行中存档兼容口径；大厅加入最近 24 局旧录与种子复走。
- CONTENT GATE：已建立 `saveCompatibilityVersion`（当前 `lab-run-v2`，材料循环移除后迁移旧字段）；`contentVersion` 仍标记完整内容快照。新增文案、美术与兼容内容不阻断进行中存档；状态结构或规则发生破坏性变化时须提升兼容版本并处理迁移。
- REVALIDATE：2026-09-22 Web 整局验收曾记录缺少获胜轨迹；当前本轮未做浏览器整局复核，胜利路线、重载续玩与旧种子复走仍待实际验收。
- DECISIONS：Web 主入口为 `game/wenzhen-web-lab/lab.html`；Godot 作为规则和数据来源；美术可原创；不以短流程切片作为最终交付。
- NEXT：在可用浏览器环境中复核整局胜利、重载续玩、异闻代价和旧种子复走；玩法主线按构筑分叉计划推进 Phase 8 批B（等 L1）及其后阶段。批B 解锁时的就绪任务底稿：[ai-system/tasks/p3b1-role-curves.md](ai-system/tasks/p3b1-role-curves.md)（数值前提 RUL-008/011 与 P2 预算曲线仍现行；落点按 Web 载体换基，见 [docs/dormant-registry.md](docs/dormant-registry.md)）。
- DO NOT：不把 `mvp.html` 短剧本当作完整产品；不因平台选择重写已有规则；数值调整遵循现有 L1/L0 边界。

## 项目进度入口

- Monorepo 迁移已完成，记录见 [MIGRATION.md](MIGRATION.md)，不重新开启迁移计划。
- **当前玩法主线**：[构筑分叉重建计划](docs/superpowers/plans/2026-09-25-build-fork-rebuild.md)（Phase 0–7 DONE；Phase 8 批A DONE，批B BLOCKED 等 L1）。
- Web 阶段记录：[W0–W7 计划](docs/superpowers/plans/2026-09-22-lab-playable-game.md)。其中开发里程碑保留作历史证据，不能替代当前长线产品验收。
- 本轮会话还原点：[会话收敛归档](docs/superpowers/reports/2026-09-24-session-consolidation.md)（含 gpt6sol 检索关闭结论）。
- 待复核事项与历史发布边界：[docs/debt.md](docs/debt.md)。
