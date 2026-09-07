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
  - [x] 全库扫描 scripts 中残留的实体数值硬编码（蛊/敌人/道具/事件）→ 见下方「扫描结果」
  - [ ] ~~写数据驱动审计脚本/校验（防回归）~~ → 扫描已证明域层基本干净，**该项降优先级**：先补一个 CI 级 grep 守门（见扫描结果 §守门）比写校验脚本便宜得多
  - [x] 已知候选：`scripts/domain/school_rules.gd` overchannel_benefit（damage 4/6/2、draws、bound）→ ~~抽 `data/schools.json`~~ **改判：主树零调用，属死代码**（2026-09-07 晚核实；唯一引用在 `.claude/worktrees/battle-visual-implementation/scripts/domain/battle_resolver.gd:747`，那份是 B1 待删的 legacy）。**不必抽数据，随 `battle_resolver.gd` 一并删除即可** —— 别为死代码做数据驱动迁移。
  - [ ] 测试断言一律不硬编码数值基线，改从 catalog 取（2026-09-07 已立此约定，首个范式见 `test_slice_buffs.gd`）

### 扫描结果（2026-09-07 晚，工单 2 交付）

方法：对 `scripts/domain/*.gd` 全量 grep 语义键数值
`(damage|heal|cost|bonus|value|amount|threshold|cap|multiplier|ratio|weight|pct|stacks)\s*[:=]\s*-?[0-9]+`。

**结论：域层已基本数据驱动，命中 9 处 → 5 处误报 / 2 处死代码 / 2 处真候选。没有发现「蛊/敌人/道具/事件」四类实体的硬编码残留**（蛊=gu.json 802、敌=enemies.json、道具/事件同理均已落 data）。

| 位置 | 数值 | 判定 | 处置 |
|---|---|---|---|
| `school_rules.gd:34-40` `overchannel_benefit` | damage 4/6/2、draws 1 | **死代码**（主树零调用） | 随 B1 删，不迁 |
| `school_rules.gd:46-52` `apply_overchannel_soul` | soul 钳到 1、mercy | **死代码**（零调用） | 随 B1 删，不迁 |
| `school_rules.gd:9-21` `blood_stacks` 三函数 | — | **仅被自己的测试引用**（`test_school_framework.gd:81-92`），生产零调用 | 死代码，删函数同时删对应用例 |
| `school_rules.gd:23-27` `material_fuel` / `is_soul` | — | `material_fuel` 同左；`is_soul` 有 1 处外部引用待确认 | 待确认后再定 |
| `v1_battle_resolver.gd:23-28` 基础动作表 | attack 2 / defense 3 / heal 2 / shift 1 / marked 1 / bound 1 | **活代码 + 核心** | 唯一值得迁的候选，但 V1 是高风险核心，需配套测试，**优先级交用户定** |
| `blood_qi_rules.gd:41` | time_cost 1、blood_trail 1 | **活代码**（被 `run_command_rules` / `run_snapshot_builder` preload） | 单处、成本低，可迁 `data/` |
| `battle_command_facade.gd:75` | `{"hp":1.0,"damage":1.0}` | **误报**：中性倍率 1.0，非实体数值 | 不动 |
| `economy_rules.gd:86` / `death_report_builder.gd:16` / `synthesis_rules.gd:44` / `action_resolver.gd:50` | 100.0 换算、0 默认值 | **误报**：纯数学或兜底默认 | 不动 |

**重要改判**：原计划「`overchannel_benefit` → 抽 `data/schools.json`」取消。整个 `school_rules.gd` 大部是死代码，**不要为死代码做数据驱动迁移**。

**§守门**：与其写校验脚本，不如在 `tools/check.ps1` 里加一行 grep —— 对 `scripts/domain/` 扫上述语义键正则，命中即报警（白名单里放已判定的误报 4 处）。成本一行，效果等价。

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
- **失配已闭环（2026-09-07 晚）**：`test_slice_buffs` 的 boss hp 断言已改为**数据驱动**——先从 `controller.catalog["enemies"]` 取 `miasma_vein_lord.hp` 作基线，再断言战斗中 hp == 基线且 `> 1`。契约锁定为「减血 buff 不削 Boss」而非具体数字，以后调敌人数值不会再红。**unit 恢复 1130/1130**。
- **数据侧定性**：`a257bd5` 的敌人改动**不是误改**，是一次成体系的 Boss 强化（hp 8/8/9/10/11 → 14/15/16/18/20，essence +2，意图伤害 +1）。故断言对齐数据是正确的方向，不要去回滚数据。
- **环境提示**：`assets/audio/music/` 资产（9 BGM）入库后首次跑测试需先执行 `godot --headless --path <根> --import` 生成导入缓存，否则 `test_audio_director` 5 用例因 load 失败误报；`tools/check.ps1` 仍受 Dialogue Manager invalid UID 警告 + PowerShell stderr 误判限制，需绕过直调。

## 验收命令

- `tools/test.ps1 -Suite unit`（**当前基线 unit 1130/1130 全绿**，2026-09-07 晚复测；`test_slice_buffs` 失配已修；旧记的 `test_wenzhen_card_fsm` 顺序依赖已不复现，隔离与全量均 10/10）
- `tools/test.ps1 -Suite integration`
- `tools/check.ps1`
