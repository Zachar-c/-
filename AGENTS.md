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

1. **World Model Stage 0：蛊界世界规则基准审计（2026-09-16 用户裁定：最高优先级）**：以 `docs/superpowers/specs/2026-09-16-wenzhen-world-model-correction-design.md` 为最高设计宪章。Stage 0 通过前只允许证据索引、审计报告、只读探针和测试夹具；禁止继续施工 F1 Pity、Q8-G promotion/material、流派晋升链及其他生产规则变更。Q8-G 文档降级为现有系统状态与历史决策档案。
   - 出口：至少冻结 20 条、目标 24 条高影响 `world_claim`，形成 `World Model Baseline v1`，并逐项裁定现有机制保留、冻结、重做或废止。
   - **证据债现状（2026-09-16）**：管道与门禁已就绪（`tools/lore.ps1 world-model-0`，exit 3 = `NO_GO`），24 条 claim 仍全部 `deferred`、零引用。候选已批量召回（`tools/stage0_evidence_candidates.py` → `docs/lore/candidates/`，208 条 / 207 条可入库），复核走 `tools/verify_stage0_candidates.py`（用真 `resolve_evidence` 反查，含 twin）。**唯一阻塞是人工确认**：把确认项写入 `evidence.jsonl` 并挂到 claim。据此报告 `.superpowers/sdd/evidence-recall-report.md`。
   - **《人祖传》证据效力（2026-09-16 用户裁定）**：它是书中书，全文散在蛊真人中（实测 92.6% 段落可在主文定位）。故为**派生摘编而非独立见证**——同一句话不得当两条互证；两源同为 P0（`_AUTHORITY_RANK` 均为 0），主文存在的段落一律引主文（候选带 `twin` 坐标），仅摘编独有的段落才以 `in_world_text` 引用。
   - Stage 0 通过后，后续阶段必须先做 10–20 只蛊的纵向切片，再允许扩大内容池。
2. **剑道流派收口（暂停，待 Stage 0）**：端到端可玩已通（契约 + 至终局驱动 + `CORE_LOOP_FAITHFUL=1 sword`）；身份机制未做完。其规则是否保留、重做或废止由 Stage 0 基准裁定。
   - **T16 残锋降转**（第一阻塞）：杀招永久耗剑蛊道痕、阈值降转；规格 `docs/superpowers/specs/2026-09-12-sword-p2-t15-t16-spec.md` §2。前置：`battle_command_facade` → `RunState.gu_instances` 实例回写通路；不可逆代价须确认 UI + 预检，禁止静默惩罚。
   - 随 T16：`sword_mark_cost` 4 只预留字段接入；logistics `bound` 死数据读取点（或裁定删除）。
   - **P2-1 剑气临时蛊 / P2-2 pierce**：T16 落地后再排，不扩包。
   - 参考：`reports/2026-09-12-sword-school-completion-audit.md` §7；验收：剑道契约 + `test_drive_to_ending` + unit/integration + 交互门。
2. **当前批次（2026-09-11 用户裁定：卡牌 UI 重构 + 真窗验收）**：
   - **卡牌重构**：手牌单卡信息层级/画框/稀有度流光重构（现役 `GuTallFanHandView`，战斗线框 v3 卡 110×154 基线）——单测 + 交互门三键回归**已完成**（2026-09-11），真窗手感验收 ✅（2026-09-14，五态截图全通过，连带修复卡牌插画空白）。
   - **战斗水墨去框重构（2026-09-11 已落地）**：敌人/玩家去框融入山水、意图篆刻印、按钮减重、debug 弱化；headless 全绿，真窗验收 ✅（2026-09-14）。
   - **休息屏软锁修复（2026-09-11 已落地）**：主决策面滚动化 + LeaveRow 常驻跳过入口；回归门 `tools/verify_rest_headless.gd`（1280x720 SubViewport 可视预算 + 引擎拾取）。
   - **V 线（已批准，2026-09-10）**：Encounter v1（C4）、Npc/Ending/ContentError v1（B1）线框稿均获批；B2 首批 tscn 已落地（`ddef08a` + `4de08bf`：四屏布局与线框对齐 + 结局回顾格 + NPC 对话卡）。B2 真窗/截图验收 ✅（2026-09-14，四屏全部成功截图）。
   - **E1-E7 按层伪随机：全链闭环**（E1 pacing 分类概率表 / E2 生成器分类抽取 / E3 休息三选一 mode_groups / E4 表现层路由 / E5 `verify_pacing_density` + `verify_route_diversity` 双门 / E6 `enemy_roll` / E7 `shop_stock`）。
   - **交互闭环契约**（已落工具规则 §）：全屏 `verify_interaction_loop.gd` 为交付回归门（`dead=[]`、`no_ui_click=[]`、`occluded=[]` 三键全 0，滚动裁剪以 `scrolled=N` 计数留痕）；Settings 手记/图鉴导航已接入路由启用（`nav_journal`/`nav_codex`，2026-09-11），设置=当前页标识 disabled。
3. ~~队列后续：真窗键鼠验收（B2 四屏 + W10 `continue_run` + S 阶段全流程 + 手牌动态手感）~~ ✅ **已闭环（2026-09-14）**：四项真窗验收全部通过，详见 `docs/superpowers/reports/2026-09-14-true-window-acceptance.md`；连带修复卡牌插画空白（`_card_art_texture` 改用 `load()` 替代 `Image.load()`，消除导出 WARNING）。D1b 古方知识模型已落地（`2026-09-06-gu-synthesis-design.md` + `test_synthesis_knowledge.gd`）；`run_controller` A7 减行已达标 888 行。
4. 验证遗留（2026-09-15 复核）：smoke 门断言已跟进 rest/NPC/ending/battle 屏重构全绿；W10 首跑 `has_save=false` flake 经 headless 5 轮全新态探针（`tools/probe_w10_flake.gd`）不可复现，判定为真窗环境因素（并发引擎实例或 GUI 包装层），`verify_w10_continue_run.gd` 已加固为 `save_run` 失败显式报错；Dialogue Manager invalid UID 在 smoke/play 模式未复现；ObjectDB/RID 泄漏仍存但 GUT 退出时降至 18 实例 / 6 资源（历史 20601，属 GUT 语境既有遗留）；最终 `tools/test.ps1 -Suite unit`（1467/1467）、`-Suite integration`（32/32）、交互门全绿。
5. 提交时继续排除 `.claude/`、`.codex/`、截图目录与 `__pycache__`。~~无关的 `data/dialogues/events.dialogue` 本地修改~~ **排除令已解除（2026-09-16）**：D4 已使 `events.dialogue` 成为事件机制的必要组成（每条事件必须有 `~ <event_id>` 菜单块，否则对话气球点了悬空），并由 `tools/verify_event_variety.gd` 的反空转 canary 守卫，不再属"无关本地修改"。~~`data/enemies.json` 在 E6 补 weight 验证前仍按未经验证排除，E6 落地后解除。~~ **排除令已解除（2026-09-10 用户指令）**：原排除理由（E6 补 `weight` 验证）已失效——E7 改用"种子化洗牌取前 N"而非权重法，E6 也不再需要 `weight`；`data/enemies.json` 现有 30 条均由 `content_catalog.validate` 全量校验 + `test_b5_content_expansion.gd` 三条池契约守卫（clue ≥2 / 每主题有非 boss / 每条能起战）覆盖。
6. **美术素材补齐（2026-09-15 新建待办，两途径）**：缺失清单与提示词见 `docs/art/AI-ART-PROMPTS.md`（§9 开源 vs AI 分类）、`docs/art/BATCH-1-PROMPTS.md`（首轮入库状态速查）。
   - **公开美术（开源）**：game-icons 52 枚已入库、`gu_icon_view.gd` ICON_PATHS 注册 + modulate 染色、大厅「关于」CC BY 3.0 署名、`apply_seal` 印章组件已实现。**2026-09-15 已落地**：① E1 羊皮纸纹理 `paper_texture.png`（texturize.app royalty-free，2048²）与 E2 印泥肌理 `seal_ink_texture.png`（grunge 源本地调朱砂红，`tools/gen_seal_ink_texture.py` 复现）已入库 `assets/wenzhen/textures/` 并导入；③ 52 枚 game-icons + 2 纹理已补登 `assets_manifest.json`（57 条，`tools/update_assets_manifest.py` 幂等追加，manifest 单测 4/4）。**剩余**：② 流派道徽纹样 13/20 game-icons 裁切入框（流派卡当前纯文字，可选增强）；E3 云纹卷轴边框公开源无匹配水墨素材，留待 AI 生成或程序化。
   - **GPT/AI 生图**：提示词已就绪——Boss 4 张见 `BATCH-1-PROMPTS.md` 批次 1，其余 29 条（敌人 7 / NPC 3 / 蛊形 9 / 背景 7 / 品牌 3）见 `BATCH-2-PROMPTS.md`（2026-09-15，高内聚低耦合：§0 画风锚点单一来源 + 每条提示词内联展开、可直接复制）。生成后落对应目录跑 `tools/import.ps1` 即导入；`seal_missing_grid.png` 15 枚待裁切（节点 3 + 道徽 7 + 徽记 5）。
7. **肉鸽化改造（2026-09-16：D1 + D4 + D7 已落地，D2/D4 频率待裁定）**：
   - **D1 关底 Boss 随机化** ✅：4 个关底台加 `boss_pool`（按 `hp × boss_layer_mult` 的**有效强度**做滑动窗口，层内差 ≤2 / 层间单调，原关底 Boss 恒在池内），`map_generator._roll_boss_for` 用独立派生流抽取 + 相邻层不重复；**L5 `final_boss_stand` 保持固定**。门禁 `tools/verify_boss_variety.gd` 40 种子 PASS（`topology_mismatch=0`），**7 个 boss 全部上场**（改前 5 个）。回滚＝删 4 个节点上的 `boss_pool` 键。
   - **D4 事件池扩容** ✅：`data/events.json` 2 → 12 条（母题落在原文高频词：遗藏/兽潮/赌斗/斗蛊/秘境/血脉/元石/本命蛊），四杠杆＝`health_cost` / `delayed_soul_cost` / `curse_id`（3 条诅咒全用上）/ **新增 `stone_gain`**；事件节点加 `event_pool` 按种子抽宿主事件。**顺带修复扩容硬前置**：`_append_event_cards` 原不接收 node、遍历全表出卡（池=2 时看不出，扩到 12 会铺满 12 张），已改 node-aware。门禁 `tools/verify_event_variety.gd` 40 种子 PASS（12/12 覆盖、93 事件槽）。回滚＝删 `event_pool` / `stone_gain`。
   - **D7 精英节点显性化** ✅（2026-09-16）：地图节点新增只读键 `threat`（`"" | "elite"`，判据真源 `MapGenerator.node_threat` 读 catalog 的 `tier`）。修复两个叠加缺陷：① `map_screen_view` 的精英分支判 `node.enemy_kind.contains("elite")`，而地图快照**从不写 `enemy_kind`** ⇒ 死代码；② 12 个精英里只有 `ridge_elite_scout` 的 id 含 "elite" ⇒ 即使键到位也漏判 11/12。门禁 `tools/verify_map_threat.gd` 40 种子 PASS（6500 节点 / 1105 精英 / 旧判据仅 418）；全量 unit 1525/1525 + 交互门三键全 0。回滚＝删快照 `threat` 键。
   - **🔴 待用户裁定（第一前置）**：`pacing.json` 是否解冻。现在**卡住三件事**——① D2 层性向（改 `category_weights`，违反 Reachability「不改 pacing」红线 + 作废 f1 的 32 局语料）；② D4 的**频率提升**（事件仍 ≈2.3 个/局，本轮只买到"种类"多样性）；③ **D7 暴露的 L1/L2 零精英**（前两大层战斗池只剩 beast 主题，而 beast 精英最低 rank 3 > 两层 `enemy_rank_max` ⇒ 一局前 40% 没有精英威胁方差）。不裁定就只能继续在数据层做加法。
   - **已知缺陷（未修，需口径裁定）**：多敌遭遇结算 tier 错位——`LootResolver` 只读 `battle.enemy_kind`，而 `BattleCommandFacade` 仅在 `enemy_roll.size()==1` 时写该键 ⇒ `beast_swarm_pass`（唯一多敌模板）即使两只都是精英也按 **common** 结算（少给奖励、不触发精英绑定代价）。修它要动 `LootResolver`（红线）。
   - **未做**：L5 终局随机化（阻塞于 `miasma_vein_lord` **强度倒挂**——rank 3 / hp 14 却是全场最弱 boss，有效 HP 21 < L4 候选 27，需平衡裁定）；`pursuit` 型固定精英（`greedy_wanderer`）未纳入 D7；精英角标视觉权重可再加强（现仅角标 `險` + 类别 `精英`）。
   - 文档：交接 `docs/superpowers/reports/2026-09-16-roguelike-handover.md` · 调研与方向对比 `...roguelike-audit-and-directions.md` · D4 实施 `...d4-event-pool-expansion.md` · **D7 实施 `...d7-elite-node-visibility.md`（含 Shared 区五步声明）** · D2 预审 `docs/superpowers/specs/2026-09-16-rogue-layer-temperament-spec.md`。

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
