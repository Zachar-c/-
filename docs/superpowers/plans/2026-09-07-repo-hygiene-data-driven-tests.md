# 2026-09-07 仓库治理三工单：根目录收敛 / 数据驱动强化 / 核心模块测试

> 用户裁定（2026-09-07）：后续系统越多人越乱 → 根目录收敛；Agent 改数值不触碰业务代码 → 数据驱动；Agent 提交代码前自动跑测 → 核心模块测试质量底线。
> 与 `2026-09-05-architecture-refactor-master-plan.md` 并行，互不干扰；本计划文件用于并行会话同步。

## 工单 1：根目录收敛

- **目标**：`.agents`、`.superpowers` 从根目录移到 `scripts/core/` 统一管理；根目录只保留配置、文档、工具和一级目录。
- **状态**：✅ 已完成（2026-09-07）。
- **改动**：
  - `scripts/core/.agents/`（4 个 SKILL.md，git mv 保留历史）
  - `scripts/core/.superpowers/`（sdd 35 / brainstorm 20 / ui_captures 157 / ui_walkthrough 57 / 根层日志 55）
  - `.gitignore`：`.superpowers/` → `scripts/core/.superpowers/`
  - 引用同步：
    - `scripts/acceptance_driver.gd:45` OUT_DIR → `res://scripts/core/.superpowers/ui_captures/wenzhen`
    - `tests/unit/test_catalog_expansion.gd:105` harvest → `..\..\scripts\core\.superpowers\sdd\gu-name-harvest.txt`
    - `tools/generate_gu_catalog.py:23` DEFAULT_HARVEST → `scripts/core/.superpowers/sdd/gu-name-harvest.txt`
  - 验证：`test_catalog_expansion` 9/9 绿（852 断言）；`test_v1_battle_resolver` 23/23 绿。
- **后续约定**：新 Agent 技能、会话产物统一落 `scripts/core/` 下；根目录不再新增隐藏工作目录。

## 工单 2：数据驱动强化

- **目标**：蛊、敌人、道具、事件数值配置全部抽到 `data/`（JSON/TSV），`scripts` 只写纯逻辑。
- **现状**：`data/` 已有 29 个 JSON（gu 802 蛊 / enemies 12 敌 / nodes / events / shops / loot_tables / v1_battle 等），`content_catalog`、`enemy_catalog`、`gu_instance`、`map_generator`、`recipe_rules` 均已从 data 加载。
- **待办**：
  - [ ] 全库扫描 scripts 中残留的实体数值硬编码（蛊/敌人/道具/事件）
  - [ ] 已知候选：`scripts/domain/school_rules.gd` overchannel_benefit（damage 4/6/2、draws、bound）→ 抽 `data/schools.json`
  - [ ] 写数据驱动审计脚本/校验（防回归）

## 工单 3：核心模块测试

- **目标**：战斗结算、蛊效果生效、地图节点生成三个核心系统补单元测试；Agent 提交前自动跑测。
- **现状**：已有 `test_v1_battle_resolver`（23）、`test_battle2_*`、`test_map_generator`、`test_map_layout_rows`、`test_gu_instance_model` 等。
- **待办**：
  - [x] 审计三系统现有覆盖缺口
  - [x] 补缺：战斗结算边界、蛊效果生命周期、地图节点生成规则
  - [x] 全量回归（unit + integration + check）

### 第三批交付（2026-09-07，已完成）

- **新增 3 个守卫测试文件**（共 21 用例，全部通过）：
  1. `tests/unit/test_v1_battle_settlement_guards.gd`（8 用例）：玩家 hp/life_cost/soul 归零三路 defeat 归因、敌人护盾吸收→穿透→击杀、victory 后禁止行动、撤退经 facade 结算/Boss 战禁止。
  2. `tests/unit/test_v1_gu_effect_guards.gd`（8 用例）：heal 封顶 max_hp / 负治疗 no-op、buff 跨施放叠加、status 叠加与 last_effect_target、shift 位置、shield 累加、aoe 群伤、S4 同流派支援加成。
  3. `tests/unit/test_map_anchor_guards.gd`（5 用例）：L1 锚点（遗葬山脊 pre_boss / 炼蛊谷地 mid）多种子保底、行位置语义、每层黑市/休整锚点保底。
- **顺带修复真实缺陷**：`v1_battle_resolver.gd::player_action` 无 phase 门禁，victory/defeat 后仍可出牌——已在统一入口加 `_is_over` 拦截（返回 `battle_over`），`test_v1_battle_resolver` 23/23 无回归。
- **回归结果**：unit **1130 测试 1129 通过**（唯一失败 `test_slice_buffs.gd::test_lesser_one_hp_spares_bosses_only` 为既有数据/测试失配：`data/enemies.json` 的 miasma_vein_lord hp 已由 8 调至 14，测试仍断言 8；还原本次改动后仍失败，与本批无关，需另行对齐数据或断言）；integration **31/31**；核心脚本 check 无错误。
- **环境提示**：`assets/audio/music/` 资产（9 BGM）入库后首次跑测试需先执行 `godot --headless --path <根> --import` 生成导入缓存，否则 `test_audio_director` 5 用例因 load 失败误报；`tools/check.ps1` 仍受 Dialogue Manager invalid UID 警告 + PowerShell stderr 误判限制，需绕过直调。

## 验收命令

- `tools/test.ps1 -Suite unit`（当前基线 unit 1096/1098，2 个失败为已知 `test_wenzhen_card_fsm` 顺序依赖；本批后实测 1130/1129，唯一失败为上方 slice_buffs 数据失配）
- `tools/test.ps1 -Suite integration`
- `tools/check.ps1`
