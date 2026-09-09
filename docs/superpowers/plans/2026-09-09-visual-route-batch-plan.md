# 2026-09-09 批次实施计划 · 美术风格补全 + 按层伪随机

> 用户 2026-09-09 裁定 4 需求（美术风格 / 事件分类 / 敌人 / 商店按层伪随机）。
> 权威规格：`docs/superpowers/specs/2026-09-09-event-classification-design.md`。
> 视觉硬流程（线框稿 → 批准 → tscn）：`wenzhen-visual-style` skill 的 godot-implementation.md。
> 交互闭环契约（AGENTS.md 工具规则）：`tools/verify_interaction_loop.gd` 全屏零死按钮零缺音效。

## 1. 批次总览与依赖

| 批次 | 内容 | 依赖 | 验证门 |
|---|---|---|---|
| **V1** | Encounter 屏线框稿（HTML + 无头截图） | — | 用户批准 |
| **V2** | Npc 屏线框稿 | V1 风格基线 | 用户批准 |
| **V3** | Ending 屏线框稿 | V2 | 用户批准 |
| **V4** | ContentError 屏线框稿 | V3 | 用户批准 |
| **V5-V8** | 4 屏 tscn 实施（逐屏） | 对应线框稿批准 | 交互审计 + 1280×720 截图对齐 |
| **E1** | 数据层：pacing.json 分类概率表；nodes.json stage 修正 | — | schema 校验 + 解析 |
| **E2** | 生成器：map_generator 分类抽取（层过滤 + 权重伪随机 + 未知迷雾标记） | E1 | 确定性单测（种子族分布） |
| **E3** | 领域：rest 三选一（mode_groups 快照 + refinement/cultivation 并入 rest 会话）；契约回写 | E2 | rest 单测 + contract 校验 |
| **E4** | 表现层：休息屏三选一 UI；地图「?」迷雾；refinement→Rest 路由 | E3 | 交互审计 + 截图 |
| **E5** | 回归：verify_pacing_density 扩展 + route_diversity + 全量测试 | E4 | unit + integration 全绿 |
| **E6** | 敌人按层品质随机：enemies.json weight + enemy_roll 抽取 + pacing enemy_weights | E1（并行 E5 后） | 确定性单测 + 层门禁 |
| **E7** | 商店按层随机：shops.json weight + travel 生成 shop_roll + 快照/购买一致 | E5 后 | 确定性单测 + 保底断言 |

**并行策略**：V 系列（表现层线框稿→tscn）与 E1-E3（数据/领域）互不重叠，可并行推进；
E4（表现层）须等 V 系列 tscn 基础 + E3 完成（休息屏三选一 UI 与美术统一）；E6/E7 独立于 E4。

## 2. 验收口径（4 需求）

- **V0 美术风格**：4 屏线框稿逐屏批准；tscn 严格消费 GuStyle tokens / 公共组件，不私设色值；1280×720 渲染与线框稿 1:1；交互闭环审计通过；未开放入口 disabled。
- **E1-E5 事件分类**：37 模板映射 4 分类；战斗占比 73%→55-60%；5 层每层 4 分类均出现；36 随机模板全可达；同种子同路线；休息三选一执行一次后 leave 放行。
- **E6 敌人**：elite 概率 20%→60% 随层；boss 仅 Boss 位；同种子同敌；旧模板回落 enemy_kind。
- **E7 商店**：同层不同店货架不同；保底品质货必现；购买越权拒绝；同种子同货架。

## 3. 已落库

| 提交 | 内容 |
|---|---|
| `802a66b` | 交互闭环修复（Settings nav disabled + top bar 音效）+ verify_interaction_loop.gd + AGENTS.md 契约 |
| `445b285` | 事件分类规格（映射 / 层概率 / 休息三选一 / 地图迷雾 / E1-E5） |
| `3d3803f` | 敌人 E6 + 商店 E7 设计追加 |
| `—`（本批） | AGENTS.md 当前待办统一登记 + 本计划文档 |

## 4. 风险与回退

- 休息三选一若 cultivate 语义冲突 → 先接 meditate/refine/rest 三族，cultivate 保留 action_card 通道。
- 未知类揭示后屏内缺内容（如 Npc 无商人数据）→「先可达、内容后补」，列入待办回写契约。
- 战斗占比目标靠实测校准（E5 工具），不达标优先调分类概率表而非硬编码。
- E6/E7 改动 `enemies.json`/`shops.json` 后必须过 content_catalog 校验（节点/货架引用完整性）。
