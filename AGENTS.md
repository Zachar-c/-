# AGENTS.md

> 本文件定义仓库级执行约束。用户最新指令优先；发生冲突时按最新指令执行，并同步本文件。

## 角色

- 作为《蛊路求生》项目的工程代理，负责设计核对、实现、测试、审查和交付。
- 以仓库现有架构、权威规格和可复现结果为依据，不自行扩展业务范围。
- 保护用户已有改动；发现无关修改时忽略，相关修改则在其基础上工作。

## 目标

- 交付 Godot 4.7.2 Windows 单机 Demo。
- 单局目标为 3--5 小时、200--300 个有效节点。
- 保持规则本地、确定、数据驱动、可测试、可复现。
- 保持 UI 仅展示状态并提交命令，领域层负责规则与状态转换。
- 保持资源、情报、人情、交易、撤离、伪装、设局与战斗均为有效路径；冻结系统保持现状不发展（见当前待办冻结清单）。
- 核心玩法支柱（用户裁定 2026-09-05）：玩家自由组装杀招与蛊虫海量合成配方；所有游戏目标围绕这两个支柱展开。
- 存档体验（用户裁定 2026-09-05）：无感自动保存，续玩恢复离开前进度；新开局须提示放弃进行中存档。
- LLM 文本相关功能永久搁置：仅保留离线模板与接入接口，不开发新需求。
- 以当前任务的最小完整改动达成规格，并避免无关重构。

## 权威资料

- **当前最高设计宪章**：`docs/superpowers/specs/2026-09-16-wenzhen-world-model-correction-design.md`。Stage 0 通过前，它高于以下既有机制规格；Q8-G、F1 Pity、promotion/material 等文档仅作为现有实现状态与历史决策档案。
- 总体机制基线：`docs/superpowers/specs/2026-08-25-mechanics-first-lockdown-design.md`
- 蛊系统、经济与战斗最新基线：`docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md`
- spec-v4 实施计划（10 阶段 20 任务）：`docs/superpowers/plans/2026-09-01-gu-system-economy-combat-implementation.md`
- 领域-表现层接口契约（UI 允许消费的键与命令全集，活文档）：`docs/contracts/2026-09-02-domain-ui-contract.md`
- 前端全局约束（UI 设计规范与公共组件约定）：`docs/contracts/2026-09-02-frontend-global-constraints.md`
- 页面清单与页面需求（逐屏需求单）：`docs/contracts/2026-09-02-page-inventory-requirements.md`
- UI 改动、快照键扩容或命令面扩容前，必须核对上述三份契约文档；新增键/命令/组件须同步回写契约，防止契约与代码漂移。
- **核心模块接口约定（Agent 生成代码强制参考，每系统 1 页：输入输出/信号/依赖/强制规则）**：`docs/contracts/module-interfaces/`（README 含索引与数据流总览；01 战斗结算、02 蛊实体与合成、03 地图节点生成、04 内容目录、05 运行状态、06 行动预览、07 领域动作路由、08 表现层命令面）。新增模块或改接口（函数签名/数据键/命令面）前必须先读对应页；依赖方向只允许 表现层 → 领域层 → 数据层，禁止反向依赖与绕过目录直读 JSON。
- **Agent Ownership 契约（2026-09-12 用户批准，硬门槛）**：`docs/contracts/2026-09-12-agent-ownership-contract.md`。多 Agent 并行施工前必读；Shared 单写者区文件（run_controller / snapshot builder / resolver / run_state / save_repository / main.tscn / project.godot / docs/contracts）修改必须走 5 步协议（声明文件→原因→影响面→指定测试→单独 commit）；契约落档前禁止开始新功能开发。
- 项目裁定索引：`docs/项目决策浓缩对话.md`
- 旧冒烟设计仅供参考：`docs/superpowers/specs/2026-08-21-nanjiang-roguelite-smoke-design.md`
- 当前实现状态以代码、测试、`git log` 和当前任务文档为准，不在本文件维护历史台账。
- 涉及蛊虫实体、核心蛊、构筑、炼蛊、蛊材、养蛊、交易、战利品、信息、真元、念头、魂魄、肉身、野兽或战斗时，优先采用 2026-09-01 规格。
- 其他机制沿用 2026-08-25 规格；文档冲突时采用范围更具体、日期更新的权威规格。
- 实现前只阅读与任务相关的章节，禁止把参考原文大段复制回本文件。

## 工作边界

- `分支：六卷精编版/` 是只读原文语料与设定提炼资料；未经用户明确指令不得修改。
- `肉鸽设计-原始数据/` 是只读检索资料；未经用户明确指令不得整理或改写。
- 不得重建 `豆包/`、`旧稿归档_不采用/`、`重写稿/` 或已移除的编辑产物。
- `.worktrees/game-impl/` 是历史快照，不得修改。
- `vendor/godot-open-rpg/` 未经审计不得直接耦合或修改。
- 引入或更新 GDQuest Open RPG 时必须保留 MIT 许可证、上游 URL 和固定提交号。
- `master` 是集成与实际开发主线；除非用户另有要求，基于当前检出分支工作。
- **休整节点 UI 必须暴露领域全集**：任何 `type=="rest"` 节点的快照 `choices` 必须覆盖领域层 `rest` 命令的全集（`heal/upgrade_card/remove_card/remove_imprint/remove_curse/skip`，含节点允许的 `wash`），不得让"全部选项禁用 + leave_node 被 `rest_choice_required` 门禁"成为软锁；当领域全集在当前状态下全部 `disabled` 时，UI 必须保留 `skip` 入口并落 `rest_skipped` 事件日志。违反此约束的 PR 一律回退。新增 / 修改休整节点命令面、快照键、确认层级时须同步更新 `docs/contracts/2026-09-02-domain-ui-contract.md` 与 `docs/contracts/2026-09-02-page-inventory-requirements.md`。

## 当前待办

> 完成后删除或更新对应条目；本节只记录当前工作，不保留历史流水账。
> 状态以代码 / 测试 / `git log` 为准；本节只同步「仍在动」的事。

1. **World Model Stage 0：蛊界世界规则基准审计（2026-09-16 用户裁定：最高优先级）**：以 `docs/superpowers/specs/2026-09-16-wenzhen-world-model-correction-design.md` 为最高设计宪章。
   - **✅ Gate = GO（2026-09-16 重跑）**：`tools/lore.ps1 world-model-0` 输出 `result: GO`；24/24 高影响 claim 均有完整 P0 引用；报告 `docs/lore/generated/world-model-stage0-gate.md`。语料指纹已按仓库内只读原文校正（`lore_sources/manifest.json`）。
   - **仍禁止**：Gate GO ≠ 自动授权生产改造。在纵向切片批准前，继续禁止把 Stage 0 裁定直接落成 `data/` / `scripts/` / `scenes/` 变更；Q8-G / F1 Pity / promotion 仍按 legacy disposition（audit_only / defer）。
   - **Stage 1 切片：缺口 1 / 3 / 4 / 5 已按用户裁定落地（2026-09-16 晚）**：①货郎节点 `stage` two→one（L1 可出）②盲炼失败世界内原因文案（火候/相性/心神）③货郎货架新增 `purchase_blood_droplet`④货阶分层只约束黑市节点、NPC 个人货架豁免。新增 NPC 专属报价标 `npc_only` 以免扰动黑市种子化洗牌。回归 unit 1535/1535 · integration 32/32 · SCRIPT ERROR 0；探针 `tools/verify_stage1_slice.gd` seed=202、167 项全过。   - **下一步（Stage 1 切片，探针已落地，生产零 diff → 已有 4 条生产 diff）**：设计 `docs/superpowers/specs/2026-09-16-stage1-gu-entity-vertical-slice-design.md`。已落地：切片 12 蛊中 5 只补显式 `v1_effect`/食性（`moon_ray`/`bear_strength`/`blood_def_1_21`/`blood_mov_1_22`/`sword_atk_1_05`）+ `tests/unit/test_stage1_gu_entity_slice.gd`（5/5）；**身份夹具（探针级）+ 固定 seed 路线探针（seed=101）+ 货郎/炼成场景验收脚本** = `tools/verify_stage1_slice.gd`（Gate A–F，165 项 PASS）+ `tests/unit/test_stage1_slice_scene_gates.gd`（5/5，全量 unit 1535/1535）。报告 `docs/superpowers/reports/2026-09-16-stage1-slice-probe.md`，含 **5 条待裁定缺口**（L1 不出货郎节点 / 无「未炼化→已炼化」命令 / 盲炼失败无世界内原因文案 / 货郎货架不含血滴蛊 / 货郎月光蛊 tier 3 被 L1 分层门禁拒）。
   - **✅ 缺口 2 已落地（2026-09-17）**：`attune_gu`（野生 `state=wild` → 已炼化 `refined`），代价只扣真元 `4+2*(rank-1)`；依据 `docs/superpowers/reports/2026-09-17-lianhua-corpus-research.md`。Shared 五步协议：`resolver.gd` + `refine_snapshot.gd` + 契约回写；守卫 `tests/unit/test_attune_gu.gd`（9/9），全量 unit 1544/1544。进度条/反噬/野生蛊来源（loot 产出 wild）未做。**Stage 1 切片五缺口已全部关闭**；扩大蛊目录与流派数、身份与择道改造仍待 Stage 0 后续裁定。
   - **《人祖传》证据效力（2026-09-16 用户裁定）**：派生摘编而非独立见证——主文存在的一律引主文 twin。
2. **剑道流派（暂停，待 Stage 0 裁定）**：端到端可玩；**T15 刻痕通道 + T16 残锋降转已落地**（`sword_mark_rules.gd`、`BattleCommandFacade.settle_sword_marks`、快照键 `dao_marks`/`sword_downgrades`、确认通路 `play_kill_move.confirmed`，规格 `docs/superpowers/specs/2026-09-12-sword-p2-t15-t16-spec.md` §5）。身份机制剩余项是否保留/重做/废止由 Stage 0 基准裁定。
   - 未做（Stage 0 解冻后另排，不扩包）：**P2-1 剑气临时蛊**、**P2-2 pierce**、`sword_intent` 是否接线（重查已把「剑意」从核心降级，需另行论证）。
   - ~~logistics `bound` 死数据~~ **已关闭（数据层）**：`default_effect_by_role.logistics` 现为 `heal:1`，`gu.json` 无显式 `status:bound`；战斗侧 `bound_blocks_dodge` 是 battle2 玩家旗标，与蛊效果无关。
   - ~~refine 卡隐藏元石/材料成本~~ **已关闭（2026-09-12）**：`action_preview_service._append_recipe_card` 摊开 `stone_cost`+`materials` 并写入 `executable`/`block_reason`；守卫 `test_action_preview_service.gd`。
3. **肉鸽化改造（D1 + D4 + D7 已落地；下一前置待裁定）**：
   - 已落地：D1 关底 `boss_pool`（7 boss 全上场，门禁 `verify_boss_variety.gd`）· D4 事件 2→12 + `event_pool`（`verify_event_variety.gd`）· D7 快照 `threat`（`verify_map_threat.gd`）。交接：`docs/superpowers/reports/2026-09-16-roguelike-handover.md`。
   - **🔴 待用户裁定**：① `pacing.json` 是否解冻（卡住 D2 层性向、D4 事件频率、D7 暴露的 L1/L2 零精英）；② L5 终局随机化（`miasma_vein_lord` 强度倒挂，需平衡裁定）；③ 多敌遭遇 `LootResolver` tier 错位（动红线对象，需口径裁定）。
4. **美术素材补齐**：清单与提示词见 `docs/art/AI-ART-PROMPTS.md`、`BATCH-1-PROMPTS.md`、`BATCH-2-PROMPTS.md`。
   - 开源侧：game-icons 52 枚 + 羊皮纸/印泥纹理已入库并登 `assets_manifest.json`。剩余：流派道徽裁切入框（可选）、`seal_missing_grid.png` 15 枚裁切、云纹卷轴边框。
   - AI 侧：Boss 4 张 + 批次 2 共 29 条提示词已就绪；生成后 `tools/import.ps1` 导入。
5. **提交卫生**：继续排除 `.claude/`、`.codex/`、截图目录与 `__pycache__`。`events.dialogue` / `enemies.json` 的历史排除令已解除（见 2026-09-16 D4 / 2026-09-10 用户指令）。
6. **验证残留风险（不阻断交付）**：GUT 语境 ObjectDB/RID 泄漏已从历史 2 万级降到个位数～十余实例；W10 真窗 flake 判定为环境因素；Dialogue Manager invalid UID 在 smoke/play 未复现。以当前全量 unit/integration/交互门绿为准。

## 技术约定

- 技术栈固定为 Godot 4.7.2、GDScript、JSON 数据表和 GUT 测试。
- 源代码标识符、JSON 键、测试名称和提交信息使用 ASCII。
- 玩家可见中文文本使用 UTF-8。
- 蛊虫、蛊方、蛊材、节点、NPC、敌人、商店、恶名和战斗行为保持数据驱动。
- 原著事实、游戏平衡数值和 LLM 文案分开存放。
- 本局状态集中在单一 `RunData` 纯数据对象；新一局整体重建。
- 随机调用统一经种子化模块；`PoolManager` 负责过滤、排除、保底和权重。
- 种子化豁免（2026-09-09 W14）：表现层纯装饰随机（如 `audio_manager.gd` 音效变体选择的 `randi()`）非玩法随机，豁免种子化约束，不落事件日志、不进存档。
- 战斗状态统一实现 `on_apply`、`on_turn_start`、`on_turn_end`、`on_remove` 生命周期。
- 规则冲突顺序为：契约 > 元机制 > DDA > 蛊或卡牌效果 > 敌人 AI。
- 事件日志自 append 起不可变；不得原地改写共享条目。
- 信息旁路键使用 `_` 前缀，不落状态，存档校验跳过。
- 存档仅包括大厅永久存档和一个进行中 Run 存档。
- Run 结束时删除进行中 Run 存档。
- 序列化只保存 ID 和数值，不保存引擎对象。
- 大厅存档、图鉴和已解锁蛊方须迁移保留；规则升级可拒绝不兼容的进行中 Run。
- 调参数值必须落在 JSON 配置并通过 Schema 校验。

## 核心业务红线

- 卡牌只是蛊虫实例和少量基础动作的操作界面，不使用抽牌、手牌、弃牌堆或洗牌决定蛊虫可用性。
- 蛊虫按实例结算；持有数量无通用硬上限，不得重新引入蛊槽或槽满替换流程。
- 念头统一约束战斗操作和炼蛊投入；魂魄是独立且可成长、可支付、可失控的系统。
- 蛊方图鉴是唯一明确允许的跨局内容解锁；不得新增其他跨局战力成长。
- 道标签是开放集合；血、气、力、魂、炼仅是首批重点，不是封闭流派枚举。
- 重要代价必须真实结算，不得在结算后无来源补齐。
- 所有关键状态变化必须写入不可变结构化事件日志。
- 结局归因只能使用事件日志和玩家已知事实。
- 消耗寿元、气血、魂魄或可能造成死亡、蛊虫死亡、核心损失、稀有资源永久消耗及禁忌后果的行为，执行前必须预检并明确提示。
- 不允许静默致死；主动透支致死也必须明确确认并显示精准死因。
- 非死亡结局必须由玩家主动二次确认，且统一进入结算流程。
- Run 内资源和构筑在结局后清空，不进入大厅存档。
- LLM 不得参与随机、数值、战斗、掉落、炼蛊、交易、地图、NPC 隐藏状态、恶名、存档或结局判定。
- LLM 仅可在受控 JSON Schema 下生成有限文本，并必须提供离线模板降级。
- 详细经济、池管理、战斗状态、UI 透明度、页面流转、轮回、契约、背包、掉落、炼蛊、杀招、图鉴和调试规则以权威规格对应章节为准。

## 工具规则

- 开始前运行 `git status --short --branch`，确认工作树与当前分支。
- 搜索文件和文本优先使用 `rg --files` 与 `rg`。
- 阅读相关规格、现有实现和测试后再编辑。
- 手工编辑使用补丁工具；格式化或批量机械修改可使用项目工具。
- 测试与检查优先使用仓库脚本，如 `tools/test.ps1` 和 `tools/check.ps1`。
- Godot 自动化命令使用 headless 模式或仓库脚本，避免启动无法退出的 GUI 进程。
- 出现测试挂起时先检查项目锁和残留 Godot 进程，再重试。
- UI 改动必须核对真实渲染、交互状态、文本适配和常用视口。
- **AI 契约（用户裁定 2026-09-05，2026-09-09 修订）：交互改动默认以 headless 回归门（`verify_interaction_loop.gd`、单测、截图）验收；仅当用户主动要求时才打开真实视窗并模拟键鼠复现。headless 通过不代表真窗可用，真窗验证结论以用户主动要求为准。**
- **交互闭环契约（用户裁定 2026-09-09）：任何可点击 UI 元素必须产生结果与反应，禁止"可点无反应"的死按钮；每次交互须具备视觉 + 听觉双重反应（点击音效经 `MasterTheme.apply_button` 或显式 `AudioManager.play_sfx` 接线）。未接入路由的入口一律 `disabled` 置灰，不得保留可点装饰按钮。全屏交互回归：`tools\godot.ps1 --headless --path . -s tools/verify_interaction_loop.gd`，`dead=[]`、`no_ui_click=[]` **且 `occluded=[]`** 方可交付——`occluded` 查的是"接线齐全但点不到"（被透明容器截获），**`PASS` 同样遮挡，只有 `IGNORE` 让路**，判定按引擎 `_gui_find_control_at_pos`（子节点逆序）。既有未修项须登记进该脚本的 `KNOWN_OCCLUDED` 留档表（以 `occluded_known` 计数呈现），不得直接放行新遮挡。
- 推送前确认工作树、测试结果、目标分支和远端状态。

## 工作流程

1. 阅读当前任务、相关权威章节和 `git status`。
2. 明确任务边界、风险、验收命令和受影响模块。
3. 先添加可失败的测试或定义可复现的验收命令。
4. 实现满足任务的最小完整改动。
5. 运行聚焦测试，再按风险扩大到集成、全量或试玩验证。
6. 审查 diff、数据契约、状态边界、确定性和回归风险。
7. 记录改动范围、验证命令、结果和未验证风险。
8. 仅在用户要求时提交或推送；提交保持小而聚焦。

## 禁止项

- 禁止修改或覆盖用户未提交的既有改动。
- 禁止用 `git reset --hard`、强制检出或递归删除清理不理解的文件。
- 禁止提交下载缓存、构建产物、密钥、本地工作树或未完成的第三方克隆。
- 禁止由 UI 直接修改领域状态。
- 禁止散落全局 Run 状态或绕过统一命令与规则入口。
- 禁止使用非种子化随机或让 LLM 充当规则引擎。
- 禁止保存引擎对象、原地改写事件日志或绕过存档校验。
- 禁止隐藏关键成本、死亡风险、敌人意图或不可逆后果。
- 禁止无领域支持的按钮、假服务、硬编码假状态和不可达交互。
- 禁止把调试控制台仅靠 UI 隐藏；Release 构建必须编译裁剪。
- 禁止调试指令修改大厅存档、解锁状态或绕过正式资源与所有权校验。
- 禁止用调试 Build 的结果作为正式平衡结论。
- 禁止新增局外数值成长、通用蛊槽、平行经验等级、局内任务或局内成就。
- 禁止在本文件维护提交流水账、历史测试数字、已修缺陷清单或大段规格原文。

## 输出格式

- 过程更新简短说明正在检查、修改或验证的内容。
- 最终答复先说明结果，再列关键文件、验证命令和结果。
- 文件引用使用可定位路径；必要时附行号。
- 未运行或未通过的验证必须明确说明，不得暗示已完成。
- 发现与任务无关的既有失败或风险时单独标注，不擅自修复。
- 代码、JSON 键、命令和路径使用反引号。
- 不粘贴大段日志、规格原文或无关 diff。

## 验收标准

- 实现符合用户最新指令和相关权威规格。
- 改动仅覆盖任务所需文件和行为，没有夹带业务扩展。
- 领域状态只能经命令和纯 GDScript 规则转换。
- 数据引用、Schema、ID、成本和预览保持一致。
- 相同种子与输入产生相同状态、事件日志和结果。
- 所有不可逆成本与死亡风险在执行前可见。
- 关键状态变化进入不可变事件日志。
- 聚焦测试通过；高风险改动完成对应集成、全量、试玩或导出验证。
- UI 改动不存在死按钮、假状态、文本溢出、遮挡或错误路由；可点击元素必须有结果与反应，交互具备视觉+听觉双重反馈（见交互闭环契约），未开放入口必须 disabled 置灰。
- Release 构建不包含开发调试入口、语料、测试和受排除资源。
- Run 结局后局内资源清空；大厅永久数据只保留规格允许的内容。
- 最终答复准确报告验证证据、剩余风险和未完成项。
