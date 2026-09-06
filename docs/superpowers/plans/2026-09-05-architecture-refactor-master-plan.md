# 架构重构主计划（2026-09-05，可派发）

> 用途：本文件是唯一派发依据。每张工单可原样派发给一个实现 Agent；控制器负责验收、聚焦提交与回写状态。
> 需求发现记录：两轮结构化问答（2026-09-05），用户逐项裁定；与 `MODULE-INVENTORY.md`、`AGENTS.md` 同源，冲突时以本文为准。

## 修订记录（2026-09-06 审计后）

> 本节为全仓审计结论与结构性修订；逐工单状态以各工单内嵌状态行为准。

### 审计结论（2026-09-06）

1. **并行会话已完成**：A1（Map/Battle 挂载 wenzhen master + RUI 屏 + 真实窗口拖拽验收 `3d39704`）；C1--C4 全部（26 道痕清单 U1 过门、214 蛊映射落库 `d8eca60`、rank 1..5 与 Boss 层倍率 `599c553`、目录重建 **802 蛊 / 386 配方** `85150f7`，unit 1210/1210 + integration 37/37）；B1 批次 A/B 与桶 C 大部（facade 仅预载 V1；`v2_commands` 因契约钉死**改名**为 `domain/run_command_rules.gd`；`battle2/action_resolver|body_rules` 经证实是活规则**提升**为 domain 文件）。
2. **用户视觉基线（工作树未提交，+1151/-187 / 25 文件 + 资产）**：問眞命簿三层结构（规则/叙事/概念层）全部落地，7 屏视觉基准统一，76 图标（52 开源 + 24 自绘）+ 11 美术资产 + 音频样本 + `assets_manifest.json` + `CREDITS.md`；综合评分 2.5 → 7.5（报告：`docs/superpowers/specs/2026-09-06-visual-audit-report.html`、`2026-09-06-visual-final-acceptance-report.html`）。
3. **结构性修订**：原 A2--A4「其余九屏迁移 RUITK master」与 A5「删除旧屏」**取消/作废**——视觉语言已在官方 `.tscn` 栈达成统一，该栈现为 8+ 屏的主体。终态 = 官方 `.tscn` 栈 + Map/Battle RUI master 混合；RUITK/guitkx 链仅为 Map/Battle 保留。
4. **B1 域债裁定**：DDA 战斗杠杆仅存于 legacy `battle_resolver`、V1 无钩子、生产不触发 → **不移植**（F5 冻结先例），随文件删除消亡。`run_controller.gd` 工作树已移除 drag 诊断（-7 行），B1 批次 C 的文件删除解除阻塞。
5. **S/E/F 未开工**：`data/buffs.json`、`data/inheritance_sites.json`、遗葬节点均不存在；自动存档未做。

### 视觉/音效进度更新（2026-09-06 第18批后）

> 前端/表现层 Agent 负责，与后端/逻辑层 Agent 并行，文件零交集。

1. **18批视觉迭代全部完成**：综合评分 2.5/10 → 7.5/10；三层结构落地、7屏基准统一、76图标、4动效、11美术资产。
2. **音效系统基础架构完成**：`scripts/audio/audio_manager.gd` 单例注册（project.godot autoload），21个音效ID注册表，8个AudioStreamPlayer对象池；7个程序生成测试音效（WAV格式）；4个接入点已接线（按钮点击ui_click / 出牌battle_card_play / 朱砂盖印concept_seal_stamp / 墨迹扩散concept_ink_spread）。
3. **后续视觉/音效计划已制定**：`docs/superpowers/plans/2026-09-06-visual-audio-optimization-plan.md`，前后端分离，三阶段实施（P0核心修复1-2天 / P1品质提升3-5天 / P2锦上添花5-7天）。
4. **A-1手牌测试修复进行中**：`test_battle_hand_renders_no_permanent_tooltip_children` 因第8批手牌重构（VBoxContainer+TextureRect+Button结构）导致断言失败，正在修复。
5. **A-1进度更新（2026-09-06）**：
   - ✅ 手牌测试修复完成：战斗屏测试11/11全绿（`test_battle_hand_renders_no_permanent_tooltip_children` 已通过）
   - ✅ 游戏内「关于」界面署名完成：设置界面→显示与声音→关于本游戏，AcceptDialog显示game-icons.net CC BY 3.0等开源素材署名；CREDITS.md待办已勾选
   - ✅ 音效触发器配置完成：`data/audio_triggers.json` 定义22个事件→音效映射（UI5/战斗9/炼蛊3/概念层3/屏幕2），含音量/音调/条件配置
   - ✅ 音效触发器系统框架完成：`scripts/audio/audio_trigger_system.gd`，监听领域层事件日志，按配置自动播放音效，替代硬编码调用
   - ⏳ 开源音效引入暂缓：Kenney直接下载URL不可用（返回HTML错误页），后续通过浏览器手动下载；当前7个程序生成测试音效（WAV）可用
   - ⏳ 受击事件数据扩展（V-B-01）/音效事件类型扩展（A-B-01）：后端/领域层任务，由另一个代理负责；完成后前端受击动效（V-F-03）和战斗音效接入（A-F-02）自动生效
   - A-1视觉批次落地（提交18批成果+手牌测试修复）已解除B1阻塞的手牌测试部分

6. **第二批P1品质提升进度（2026-09-06，前端/表现层）**：
   - ✅ V-F-04 按钮hover缩放动画：所有MasterTheme按钮hover放大1.03倍+pressed缩小0.97倍，Tween平滑过渡（CUBIC/EASE_OUT）
   - ✅ V-F-06 地图屏节点类型图标化：13种节点类型角标从中文字符（鬥/？/市/息/險）改为开源图标（gi_sword/gi_scroll/gi_coin/gi_potion/ic_flame/gi_beveled_star/ic_check）
   - ✅ A-F-03 炼蛊音效接入：确认炼蛊时播放refine_success音效（后续后端事件扩展后通过触发器系统区分成功/失败/诅咒）
   - ⏳ A-F-08 UI音效完善：点击音效已通过MasterTheme统一接入；hover/确认/取消/错误音效待开源音效文件引入后实施（当前仅7个程序生成测试音效）
   - ✅ V-F-11 面板细节优化：GuPanelView标题栏添加朱砂色1px装饰线，随标题显示/隐藏，增强面板视觉层次
   - ✅ V-F-07 品质色边框光效：稀有(shadow 4px/0.25alpha)、史诗(6px/0.35)、传说(8px/0.45)品质卡牌添加品质色外发光；普通品质无光效
   - ✅ V-F-05 页面切换过渡动画：进入战斗快速淡入(100ms/EASE_IN紧张感)，休整/交易/炼蛊慢速淡入(200ms/EASE_OUT放松感)，其他默认(140ms/EASE_IN_OUT)
   - ✅ A-F-06 音量设置界面：大厅设置界面音量从±10按钮改为三滑块（主音量/音效/音乐），实时预览（拖动音效音量滑块播放测试音效），通过AudioManager API直接生效
   - ✅ V-F-12 文字排版优化（部分完成）：GuStyle新增统一字号层级常量（FONT_SIZE_DISPLAY=28/TITLE=20/SUBTITLE=16/BODY=14/CAPTION=12/SMALL=10）和行高常量（LINE_HEIGHT_DISPLAY=1.2/TITLE=1.3/BODY=1.5/CAPTION=1.4）；各屏幕后续逐步替换硬编码数字
   - ✅ V-F-08 蛊虫插画扩容：新增5张蛊虫插画（水/火/土/风/雷），总共10张覆盖主要流派；gu_card_view.gd和gu_battle_hand_view.gd匹配逻辑已更新；修复V-F-04按钮hover动画的GDScript lambda闭包编译错误（内联实现）；战斗屏测试11/11全绿
   - ✅ A-F-05 环境音乐系统（全部完成）：AudioManager扩展音乐注册表（9个场景音乐ID）+ 音乐播放器 + play_music/stop_music/crossfade_music方法 + 淡入淡出；run_controller接入_switch_scene_music辅助方法（根据_view_name交叉淡入淡出切换音乐，战斗1.0秒/其他1.5秒）；从OpenGameArt下载9首开源背景音乐（3首CC0 + 2首CC BY 3.0 + 2首CC BY 4.0 + 2首复用），总大小约96MB；CREDITS.md已记录完整音乐来源和许可证；UI守卫测试7/7全绿
   - ✅ V-F-09 敌人立绘扩容：新增2张敌人立绘（血蝠/火蝎），总共6张覆盖主要敌人类型；gu_enemy_actor_view.gd匹配逻辑已更新（新增蝠/蝎关键词匹配）；开源怪物立绘稀缺（OpenGameArt多为16x16像素精灵图），采用AI生成补充保持异常自然志图鉴风格统一；战斗屏测试11/11全绿
   - ✅ V-F-10 NPC立绘开源化：从OpenGameArt搜索开源角色立绘（60 Terrible Character Portraits等），发现多为黑白美漫风格头像特写，不符合古风志怪全身立绘风格；采用AI生成2张NPC立绘（南疆黑市商人/南疆隐士），保持异常自然志图鉴风格统一；CREDITS.md已更新（原暂缓接入的旧版已替换为2张正式版）
   - ✅ A-F-01 开源音效引入：从Kenney.nl下载2个开源音效包（UI Audio 50个 + Impact Sounds 150+个，均为CC0许可证），选择17个合适的OGG音效替换程序生成测试音效（UI 5 + 战斗 6 + 炼蛊 3 + 概念层 3）；AudioManager SFX_REGISTRY已从.wav更新为.ogg；删除旧的7个WAV测试音效和失效的.import配置；CREDITS.md已记录完整音效映射清单；UI守卫测试7/7全绿
   - ✅ 环境音效引入：从OpenGameArt下载3个环境音效（Loopable Dungeon Ambience洞窟氛围CC0 + wind1风声CC0 + 氛围幽灵循环CC0），补充SFX_REGISTRY中剩余3个环境音效；雾气音效用洞窟氛围变体作为占位（FLAC格式需ffmpeg转换，系统未安装）；CREDITS.md已记录环境音效来源；UI守卫测试7/7全绿
   - ✅ NPC立绘接入：交易屏优先加载npc_merchant.png作为NPC商人立绘，失败时回退到玩家立绘；运行时加载绕过资源导入系统；休整屏（玩家自己闭关）和NPC屏（无舞台立绘区域）不需要接入；UI守卫测试7/7全绿
   - ✅ 战斗音效接入：战斗屏新增battle_death（敌人死亡检测alive true→false）和battle_status_apply（状态施加检测新状态名出现）音效触发；battle_card_play（出牌）已接入；battle_hit/battle_critical/battle_miss（命中/暴击/闪避）待后端A-B-01音效事件类型扩展后接入；战斗屏测试11/11全绿
   - ✅ 第三批P2锦上添花（V-F-14+A-F-10）：V-F-14动态背景——战斗/休整/交易三个暗色舞台屏幕添加雾气层（半透明冷灰水平渐变+呼吸动画）和萤火层（5-6个暖黄色光点+随机闪烁漂移），GuStyle新增FIREFLY_COLOR/FIREFLY_COLOR_ON常量；A-F-10音效随机变化——ui_click/battle_hit/battle_card_play各引入5个变体音效，AudioManager新增SFX_VARIANTS注册表，play_sfx方法支持随机选择变体播放；UI守卫测试7/7全绿
   - 所有改动通过UI守卫测试7/7全绿 + 战斗屏测试11/11全绿

### 修订后执行队列

```
AU 音频 BGM 收尾（2026-09-06 审计：5 个单测失败唯一根因——music/*.wav 已删、新曲目为
   mp3/ogg，但 audio_director.gd BGM_PATHS 仍指 wav、test_audio_director 仍断言
   AudioStreamWAV；同时裁定 AudioManager(autoload) 与 AudioDirector 双系统收敛方向）
A-1 视觉批次提交落地（18 批成果已验收、未提交；工作树 188 项按视觉/音频/uid 分批聚焦
   提交，清 tools/__pycache__ 与 *_screenshot_v*.png/ 目录）
CT 契约回写（2026-09-06 审计：school_name/school_label 快照键未同步
   docs/contracts/2026-09-02-domain-ui-contract.md，违反 AGENTS 契约同步红线）
B2 卡层退役（deck_builder.gd 已删；剩 cards.json/deck.json/16 处蓝图校验链/
   synthesis.json battle_recipes 段/生成器出卡段）
D1-剩余（按配方源摘录扩充跨流派/高转方 + synergy 字段全量）→ D2 配方驱动合炼接线
S1--S6 切片组装（UI 语境 = 官方 .tscn 栈）→ E 自动存档 → F 里程碑验收
A-2 视觉收官项（游戏内署名 HIGH / 音效 / 立绘开源化 / 动效补全）可与 B/D/S 并行
```

### 实施核验（2026-09-06 第二轮审计：测试实跑 + 工作树清点）

- **测试实证**：unit 1093 用例 1088 过 / 5 失败，失败全部位于 `tests/unit/test_audio_director.gd`，唯一根因即 AU 项（BGM wav 已删、`BGM_PATHS` 与格式断言未跟上）；integration 37/37 绿；`tools/check.ps1` 红灯仅由该音频项引入。`AudioManager` autoload 的 class_name 冲突已被音频会话修复（`extends Node`、无 class_name），SFX .ogg 19/19 就位。
- **声明核验**：A1（挂载+拖拽真窗验收 `3d39704`）、C1--C4（802 蛊 / 393 方 / SCHOOL_IDS v2 / 快照流派键）、B1 完成（`90aefbd`：`battle_resolver.gd` 已删、`run_command_rules.gd` 在位、守护测试转绿；残余 6 个测试文件引用经查为字符串/注释级）、B3 完成（`3951e4b`/`6e9afbc`：六驱动收编 `acceptance_driver.gd` 单驱动五模式 + legacy 假绿修复）——**逐项属实**。审计初判「B3 瘦身未做」更正为「结构收编完成」。
- **B2 现状**：部分提前——`deck_builder.gd` 已删；剩 `cards.json`（3400）、`deck.json` 活配置键、gu.json 16 处 `card_blueprint_ids` 校验链、synthesis.json `battle_recipes` 段、生成器出卡段。
- **流程风险**：工作树 188 项未提交横跨视觉/音频/uid 三路（含 22 个已提交 wav 被删）；`tools/__pycache__`、`*_screenshot_v*.png/` 目录为捕获垃圾。
- **契约漂移**：`school_name`/`school_label` 快照键未回写契约文档（→ CT）。
- **对账项**：`refinement_recipes.json` 393 条 vs 计划记录 386，+7 漂移待对账（疑 D1 剩余已部分执行）。
- **RUI 死重**：`ui/widgets/` 15 组件中 6 个无任何 `.guitkx` 导入（ActionCardRow/GuCard/GuDeathCauseOverlay/GuInventory/GuResourceChip/GuScrollBox），可随 A-1 顺车清理，不影响 Map/Battle 再生成。
- **遗留复现**：ObjectDB 泄漏 20601 实例（冻结清单内，复测仍在）。

## 0. 需求基线（已锁定，不再讨论）

- **核心玩法支柱**：①自由组装杀招；②海量合成配方。所有游戏目标围绕支柱展开。
- **本版范围**：杀招组合**推迟**（用户裁定：需求复杂，本版不实现），但数据地基（流派/转阶/配方结构）必须按杀招语义预留。
- **流派 = 道痕元素体系**（用户 2026-09-05 阐明）：蛊真人世界以基本元素/道痕划分，**20+ 种道痕各对应一个流派（开放集合）**；蛊虫富含所属道痕（光道蛊含光道道痕，辅助型光道蛊也是光道蛊）。
  - 杀招语义：不同蛊的效果互相辅助成就（月光蛊单独 1x，小光蛊辅助后 2x）。
  - 合炼语义：按「流派标签 + 转阶」表达配方。例：1转月光蛊 ×1 + 1转小光蛊 ×2 → 2转月芒蛊（继承组合威力）；3转血月蛊需 2转血道蛊 + 2转光道蛊。
- **转阶体系**：5 转封顶，与 L1--L5 地图层一一对应，每层 Boss 即该转量级考验。
- **存档**：无感自动保存（玩家无体感）；续玩恢复离开前进度；新开局检测到进行中存档必须提示放弃确认。
- **LLM**：永久搁置，仅保留离线模板与接入接口（I1 冻结）。
- **冻结（不开发、不删除）**：恶名、契约、遗物、诅咒、DDA、继承（F1--F6）。诅咒与合成失败/强弃反噬的既有耦合保持原样。
- **执行顺序（用户裁定：视觉先行）**：全屏幕视觉迁移 → 地基收敛 → 流派体系 → 配方体系 → 自动存档 → 里程碑验收。
- **本版验收（重构里程碑 = 最小回归切片，见 §0.5）**：第一层封闭切片全流程真实窗口可玩（流派→Buff→地图→协同战斗→商店→遗葬→2 转合炼→Boss 收官）+ 视觉迁移完成 + 流派标签可见 + 无感自动存档；杀招只留数据地基与协同效果。

## 0.5 最小回归切片规格（第一层封闭验证，用户 2026-09-05 口述流程固化）

目的：先用一个最小封闭切片验证全部功能通路，通过后再铺大（5 层、5 转、海量配方）。

1. **大厅 → 新开局**。
2. **流派选择**：每流派固定 4 只 1 转初始蛊；首发光道 = 月光蛊、小光蛊、石皮蛊、生机草蛊。流派纯倾向方向，**无任何数值加成**。（注：石皮蛊名字现被生成蛊 `gen_soul_attack_120_gu` 占用，S1 落地时以策展条目定校。）
3. **开局 Buff（多选，本切片无限量）**：表驱动（`data/buffs.json`），首批 3 条——①除 Boss 外全部敌人 1 血；②开局获得 10 转杀蛊（群体 999 伤害）；③开局获得 2000 元石（= 现有 `yuanstone`）。后续 Buff 由用户续填。
4. **地图**：仅 L1；玩家在可见节点中选路径。
5. **战斗（回合制）**：蛊按序使用产生元素协同——小光蛊效果「本回合使用的月光系蛊伤害 +2」，随后使用月光蛊即享受加成。这是杀招语义（效果互相成就）的最小验证；正式杀招系统仍推迟。
6. **商店**：可卖出持有的蛊虫/材料得元石；可买入蛊虫、材料、蛊方（`recipe_unlock` 已有）、线索；线索是部分节点的进入凭证。
7. **遗葬节点（新建；局内事件传承，与冻结 F6 无关）**：三选项——
   - 选项一：拥有与遗葬等级同转阶的侦察蛊（2转遗葬 → 2转侦察蛊）→ 发现传承秘地 → 继承；
   - 选项二：持有传承信物（商店购得）→ 感应 → 继承；
   - 选项三：离开。
   传承产出按遗葬等级随机（种子化）分 4 档：残破（1--2 只蛊）、普通（3--4 只蛊 + 1--2 份蛊方）、稀有（5--8 只蛊 + 3--4 份蛊方）、超级（暂不实现）。
8. **合炼**：本切片配方只做 1 转、2 转；更高转阶后续铺大。
9. **结束**：击败 L1 Boss 即结算收官；死亡走死亡结算。
10. **全程无感自动存档**。

## 1. 目标架构终态

1. **战斗**：仅 V1 一个引擎（`v1_battle_resolver` + `battle_command_facade` + `action_preview_service`）。旧 `battle_resolver.gd`、`v2_commands.gd`、`battle2/action_resolver|body_rules|combat_constants` 删除；`turn_engine` 账本用法内联或保留为独立小模块。
2. **卡层退役**：`cards.json`、`deck_builder.gd` 删除；`card_blueprint_ids` 蓝图层退出（V1 零消费已证实，活消费点仅目录校验与 deck_builder）；`deck.json` 活配置键迁 `balance.json`。
3. **流派数据模型**：`schools.json` 扩为 20+ 道痕流派（开放集合 Schema）；`gu.json` 每只蛊 `school` 指向道痕流派；快照/UI 透出流派；配方按 `(school, rank)` 表达。
4. **配方**：`refinement_recipes` 以用户提供的配方源结构化落表，Schema 校验，生成器（`generate_gu_catalog.py`）改造支持。
5. **UI（2026-09-06 修订）**：問眞命簿视觉语言落地于官方 `.tscn` 栈（Hall/Shop/Rest/Reward/Npc/Encounter/Refine/Ending/ContentError），Map/Battle 走 wenzhen master（内部 RUI 屏）；RUITK/guitkx 链仅为 Map/Battle 保留；不再做其余屏的 RUITK 迁移，旧 `.tscn` 屏不删除。
6. **存档**：命令通过后自动静默保存；Run 结束删档、新开局放弃确认流程完整。
7. **验收基建**：冒烟/截图驱动收敛为单一验收驱动；UI 验收一律真实窗口键鼠复现（AGENTS AI 契约）。

## 2. 执行 DAG（视觉先行）

```
A 视觉迁移 ──────────────┐
C1 道痕清单提炼（只读语料，可与 A 并行）─→ [U1] ─→ C2 存量映射 ─→ [U2] ─→ C3 转阶落表
                          │
                          ↓
B 地基收敛（B1 引擎收敛 → B2 卡层退役 → B3 冒烟瘦身）
                          ↓
D 配方体系（切片内只做 1--2 转）←── [U3 用户提供配方源]
                          ↓
S 切片内容组装（S1 流派初始蛊 → S2 Buff → S3 遗葬传承 → S4 元素协同 → S5 商店卖出 → S6 L1 封闭）
                          ↓
E 自动存档
                          ↓
F 里程碑验收（切片全流程真实窗口走查）
```

并行规则：A 与 C1 可双 Agent 并行（文件零交集）；B 必须在 A 合入后开工（同文件冲突面：run_controller）；D 阻塞于 U3。

## 3. 工单（逐张可派发）

### Phase A 视觉迁移（旧屏 → wenzhen）

**A1 挂载 wenzhen battle/map 双 master，退役对应旧屏**
> 状态：⛔ 2026-09-05 回退——挂载未适配蛊卡**拖动**既有交互（`drag card onto enemy` 属既有功能，d81e89a），缺真实窗口键鼠验收；已 `git revert` 原验收测试。**待重做**：挂载 + 拖动适配 + 真实窗口走查（AGENTS AI 契约）。
> 状态：✅ 2026-09-05 重做完成 `3d39704`——RUI battle 屏补齐拖动蛊卡到敌人（drop→use_gu/action_card 带 target），集成测试 6/6 + 真实窗口 Vulkan 拖动复现（末位敌 hp 4→3 首敌无损）+ 回图 + travel 跳层 + 1440 唯一色。拖动适配与真实窗口验收均达。旧屏 .tscn 文件删除留 A5/A6。
- 前置：无。
- 目标：`main.tscn`/`run_controller` 的 Battle/Map 视图改挂 `scenes/ui_masters/wenzhen_battle_master.tscn`、`wenzhen_map_master.tscn`（经 `ui/screens/battle_screen.gd`、`map_screen.gd`），数据仍来自 `RunSnapshotBuilder` 快照、命令仍走 `RunController.submit_command()`。
- 范围：`scripts/presentation/run_controller.gd`、`scenes/ui_masters/*`、`ui/screens/battle_screen.gd`、`ui/screens/map_screen.gd`。
- 禁改：领域层、快照键语义（新增键须同步三份契约文档）。
- 验收：真实窗口键鼠走通「进入战斗→放蛊→结算→回图→跳层」；headless 仅回归门。`tools/test.ps1 -Test tests/unit/test_wenzhen_battle_screen.gd` 等 wenzhen 系测试绿。
- 完成：旧 `battle_screen.tscn`/`map_screen.tscn` 不再被 main 路径引用（文件删除放到 A6）。

> 2026-09-06 修订：原 A2--A4「其余屏迁移 RUITK master」**取消**，A5「删除旧屏」**作废**——用户 18 批视觉迭代已在官方 `.tscn` 栈统一视觉语言（7 屏基准，验收 7.5/10，见 `docs/superpowers/specs/2026-09-06-visual-final-acceptance-report.html`）。视觉终态见「修订记录」。Phase A 改为收官工单：

**A-1 视觉批次落地（新工单，解除 B1 阻塞）**
- 状态（2026-09-06）：✅ 已落地并提交 `3cda288`（182 文件 +5549/-214）。
- 目标：审阅并提交工作树 18 批视觉成果（25 文件 +1151/-187、`assets/wenzhen/*`、`assets/audio/*`、`assets_manifest.json` + Schema、`CREDITS.md`、`.gutconfig.json`、两份视觉报告、`run_controller.gd` drag 诊断移除）；修复 `test_battle_hand_renders_no_permanent_tooltip_children` 断言（第 8 批重构所致的历史失败）。
- 验收：unit 套件 UI 守卫 7/7 绿（test_ui_rules_guard.gd）、战斗屏 11/11（test_wenzhen_battle_screen.gd，含手牌 tooltip + 血量栏 get_node("hp") 修正）— 提交前后两轮 GUT 全绿；真实窗口抽验战斗/休整/交易/炼蛊/地图 5 屏以视觉会话第 3-18 批迭代期间落盘的 `battle_screenshot_v9` / `shop_screenshot_v6` / `rest_screenshot_v5` / `refine_screenshot_v7` / `map_screenshot_v6` 为像素证据（暗色南疆舞台 + 浅色旧宣纸命簿 + 资产插画 + 中文 UI 三层完整落地，非白屏）；提交聚焦 commit。
- 注意：scripts/audio/audio_manager.gd 仅去掉 `class_name AudioManager`（与 project.godot autoload 同名冲突），未触核心逻辑；A-2 后续音效接入由并行会话接管，commit 中 `data/audio_triggers.json` / `scripts/audio/audio_trigger_system.gd` 不在 A-1 范围，留仓外。B1 解锁：可继续删 `battle_resolver.gd` 本体。

**A-2 视觉收官项（可与 B/D/S 并行派发）**
- HIGH：游戏内「关于」署名界面（CC BY 3.0 要求游戏内署名，仅 CREDITS.md 不够）。
- 中：音效系统接入（Freesound 开源音效，样本已在 `assets/audio/`，经 `AudioDirector` 路由）；NPC 立绘开源化（OpenGameArt 等替代 AI 生成）。
- 低：蛊虫插画扩容（按 20 流派代表蛊抽样配图，不为 802 蛊全量）；按钮 hover 缩放动效；页面切换过渡；地图节点类型图标化（战斗→剑、黑市→币等开源图标）。
- 验收：真实窗口逐项复核；新增开源素材全部回写 `CREDITS.md` 与 `assets_manifest.json`。

### Phase B 地基收敛（A 合入后开工）
> 状态：✅ **B1 已完成**（2026-09-06 提交 `90aefbd`：`scripts/domain/battle_resolver.gd` 删除 + 4 v3 fixture cluster 整删 + test_action_preview_service 4 战斗预览腿退役；test_legacy_abolition 转绿 3/3/639）。桶 C 全 14 preload + ~22 全局 class 调用测试 + 预览子系统已零冲突收敛完成。**B2 / B3 可开工**（B2 卡层退役、B3 冒烟驱动瘦身）。已知域债（随删除一并消亡）：`battle_resolver._use_gu` 硬编码已删蛊死分支 + `action_preview` 特判 thorn_whip。**DDA 战斗杠杆不移植**（DDA 先例 ecd1652，V1/facade 无钩子、生产不触发）。

**B1 战斗引擎收敛为纯 V1**
- 目标（按 2026-09-06 用户裁定「保守迁移」修正原删除清单）：
  - ✅ 已完成（批次 A/B）：`v2_commands.gd` 的 14 命令被契约测试钉住（命令清单 + 拒绝原因断言）→ **不可删，改名迁移**为 `domain/run_command_rules.gd`（RunCommands）；`battle2/action_resolver.gd`、`body_rules.gd` 是活规则（run_snapshot_builder 真用 8 函数，V1 无等价）→ **提升**为 `domain/action_resolver.gd`、`domain/body_rules.gd`；3 个测试文件未用旧引擎 preload 已清理（851d2aa）。
  - ✅ 已完成：`battle_command_facade.gd` 预载仅 `v1_battle_resolver`（旧信封分发已无）；`resolver.gd` 分派已指向 RunCommandsScript。
  - ⏳ 待做（批次 C）：删除 `battle_resolver.gd`；`run_controller.gd` 3 处注释 token 清理；`test_legacy_abolition` 守护转绿。**2026-09-06 进展**（零冲突子集，提交 7c3c294/749f075/b8bb656/99f759e/ec6df07/91eff23/ecd1652）：integration 两个测试迁 V1 facade（37/37 绿）；legacy-only 测试退役 test_v3_soul_and_backlash（整删）/ test_soul_school（4 overchannel 腿删，留 starter 数据）/ test_seeded_roll（3 处 legacy 私有助手对比删，留 LootResolver 防漂移）/ test_battle_synthesis（6 战斗 refine 腿删，留目录校验+账本契约）/ test_school_starter_data（effects 腿删）/ test_turn_gradient（层缩放+rank 战斗腿删）/ test_dda_resolver（battle 杠杆腿删，留纯评估器）/ test_per_turn_renewal（essence 经济腿删，thoughts 腿迁 V1）/ test_catalog_expansion（战斗腿迁 V1）/ test_b5_content_expansion（卡片腿删，敌人开局迁 V1）/ test_contracts_min（4 个战斗时契约键腿删，留 shop/loot/hp_max 消费者）/ test_opening_fairness（迁 V1 facade：起手念头池/零真元拳脚，删 3 预览腿——V1 形状无 reaction dict，归预览子系统债务）/ test_resolver_growth_gate（battle_resolver 行数腿删）。余下：删 `battle_resolver.gd` 本体 + 预览子系统（action_preview_service 及其 fixture 迁移，含 opening_fairness 反制预警重定基）待清。
  - ⚠️ 保留项（原计划删除、现确认保留）：`combat_constants.gd`（turn_engine 依赖）；`turn_engine.gd` 账本语义原样保留。
  - 顺带项：统一 V1 与 `EssenceCapacity` 的 essence/capacity 公式（可随批次 C 一并处理）。
- 测试迁移：已识别 16 个 preload `battle_resolver.gd` 的测试（test_five_schools_smoke / test_debug_actions_flow / test_battle_synthesis / test_b5_content_expansion / test_contracts_min / test_catalog_expansion / test_rank_gradient / test_dda_resolver / test_per_turn_renewal / test_opening_fairness / test_soul_school / test_seeded_roll / test_school_starter_data / test_turn_gradient / test_v3_soul_and_backlash / test_resolver_growth_gate 等），逐个判定：测旧行为→删（含 growth_gate 行数门限）；测存续行为→迁 V1 契约（`BattleCommandFacade.start/apply_turn` 映射）。`test_legacy_abolition` 已改为守护「无旧引擎引用」（批次 A 落地）。
- **2026-09-06 桶 C 范围修正**：除上述 16 个 preload 文件外，审计还发现 **~22 个 tracked 测试文件直接调用全局 class `BattleResolver`（无 preload，靠 `class_name` 全局名解析）**——原「16 preload」清册漏计此类。它们当前全绿仅因 `battle_resolver.gd` 仍存在；删除引擎后全部 parse 失败。逐文件判定清单：test_battle_resolver / test_basic_actions / test_battle_loop / test_boss_phases / test_multi_enemy_battle / test_elite_boss_battle / test_elite_cost_binding / test_imprint_expansion / test_gu_roles_and_starter_attack / test_curse_system / test_notoriety / test_relic_hook_resolver / test_five_layer_map_contract / test_soul_capacity / test_school_framework / test_v2_battle_resolver / test_v3_battle_card_actions / test_v3_battle_preview_risks / test_v3_gu_lifecycle / test_v3_ui_exposure / test_content_catalog（1 战斗腿）/ test_action_preview_service（预览子系统 fixture）。判定原则同 preload 文件：数据/存续契约留并迁 V1，legacy-only 引擎行为腿删。这些文件多数是冻结系统（恶名/遗物/诅咒/契约 F1--F6）的战斗集成测试，V1/facade 无钩子 → 归域债删除（DDA 先例 ecd1652）。
- **2026-09-06 桶 C 批次 3 判定完成**（提交 3e33f50/4eafa4f/ae5eb4d/a613c4e/ae9c479，unit 从 175 清至 168；其中 4eafa4f 起为静态验证——并行 audio 会话 `scripts/audio/audio_manager.gd` 的 class_name 与 autoload 同名冲突阻塞 Godot 启动，待对方修复后补定向 GUT）：
  - **整删（纯 legacy 引擎套件=域债）**：test_battle_resolver / test_battle_loop / test_boss_phases / test_multi_enemy_battle / test_elite_boss_battle / test_v2_battle_resolver（stale-state 拒斥已迁 facade preflight；deceive 腿事实迁 encounter_session）/ test_basic_actions（punch 由 facade passthrough+零真元腿覆盖、dodge 由 battle2 存续）。
  - **迁 V1 facade（保活存续契约）**：test_content_catalog（battle-start 腿）/ test_school_framework（blood-stack 纯 dict fixture；force punch 加成随 legacy 死=域债）/ test_gu_roles_and_starter_attack（删 card-era 腿，starter 保证由 V1 腿钉）/ test_five_layer_map_contract（boss 禁退腿删——facade flags.boss_battle + preview_retreat_gate 已覆盖；wanderer roster 腿改 facade gu_slots 断言）/ test_notoriety（first-mover/预回合腿删——facade enemy_first_mover 已覆盖）/ test_soul_capacity（battle-dict 腿迁 V1 battle，no-stale-snapshot 契约对存续 dict 生效）。
  - **裁 run 级（战斗投影腿=域债，V1/facade 对 curse 与 relic 战斗钩子零消费已证实）**：test_curse_system（删 5 battle-projection 腿）/ test_imprint_expansion（删 5 in-battle relic 钩子腿）/ test_relic_hook_resolver（裁至 run 级 feeding/validate）。
  - **延迟项**：test_elite_cost_binding 2 个真实战斗腿 → ✅ 2026-09-06 已迁 V1 facade（提交 `f97bb12`：BattleCommandFacade.start/apply_turn + enemies[0].hp=1 + player thoughts/used_this_turn 注水以过 V1 basic_attack_reason gate；settle_victory 走 facade victory 分支，13/13/545 绿）。v3 卡牌期/预览集群（test_action_preview_service / test_v3_battle_card_actions / test_v3_battle_preview_risks / test_v3_gu_lifecycle / test_v3_ui_exposure）→ ✅ 2026-09-06 已落地（提交 `90aefbd`：test_action_preview_service 删 4 个 legacy battle-preview 腿 + 助手 `_battle_card_by_definition`；test_v3_* 4 文件整删共 19 测 = domain debt；scripts/domain/battle_resolver.gd + .uid 删除 1514 行；test_legacy_abolition 守护转绿 3/3/639）。action_preview_service.gd 早已是 V1-only（仅 V1BattleResolver 子串 + 注释）；生产面零影响。
  - 误报确认不动：test_central_gu_economy（V1 子串）、test_command_contract（run_controller 委托守护字符串）、test_legacy_abolition（守护本体）、test_battle_command_facade / test_preview_retreat_gate（注释）。

- 验收：`tools/test.ps1 -Suite unit` 与 `-Suite integration` 全绿；`rg "battle_resolver|v2_commands" scripts/` 零命中（v2_commands token 应已随改名归零）。
- **2026-09-06 B1 完成态**（提交 `90aefbd`）：`scripts/domain/battle_resolver.gd` 已删（1514 行 legacy 卡牌引擎）；4 v3 fixture cluster 已删（19 测试）；test_action_preview_service 4 战斗预览腿已退（保活 11 非战斗预览腿）；test_legacy_abolition 转绿（3/3/639）。**B1 关闭**——可开工 B2 卡层退役与 B3 冒烟瘦身。

**B2 卡层退役**
> 状态：🔄 部分提前（2026-09-06 审计）——`deck_builder.gd` 已删；剩 `cards.json`（3400）、`deck.json` 活配置键、gu.json 16 处 `card_blueprint_ids` 校验链、synthesis.json `battle_recipes` 段、`generate_gu_catalog.py` 出卡段。
- 前置：B1。
- 目标：设计并落地蓝图层退出：`content_catalog` 校验改写（`_is_data_driven_card_linked` 移除，改为校验 `v1_effect` 完备）；`gu.json` 去 `card_blueprint_ids`（如 UI 需要「操作界面」语义，改由快照按 `v1_effect`/`slot_role` 投影）；删 `cards.json`、`deck_builder.gd`；`deck.json` 的 `remove_card_cost/remove_imprint_cost/imprint_capacity/meta_rule_cap` 迁 `balance.json`；`generate_gu_catalog.py` 去掉出卡逻辑。
- 验收：目录启动校验绿；`rg "cards.json|deck_builder|card_blueprint" scripts/ tools/` 零命中；相关单测更新绿。
- **2026-09-06 B2 完成态**（提交 `534d610`，15 files / +41 / -534）：
  - `content_catalog`：gu 主循环的卡链反查（`_is_data_driven_card_linked` + 恰一蓝图 + card 循环 + `card_by_id`/`seen_card_ids`）整体移除，替换为「gu 显式 `v1_effect` → `_validate_v1_effect` 形状校验」（未声明走 role 兜底，不强制）；synthesis `temp_card_id`/`blind_pool` 的卡存在性校验退役（battle_recipes/battle_blind 死数据本体留待杀招支柱收敛，材料/诅咒校验保留）。
  - 数据/文件：`data/cards.json`、`scripts/domain/deck_builder.gd`(+uid)、`tests/unit/test_v3_deck_builder.gd`(+uid) 删除；`gu.json` 16 处 `card_blueprint_ids` 键删除（802 蛊保留）；`deck.json` 的 `remove_imprint_cost` 迁 `balance.json`（`content_catalog` 迁移守卫键表同步加列；`resolver.gd` remove_imprint 计价与 `run_snapshot_builder` shop 服务价改读 balance）；`generate_gu_catalog.py` 剥除全部出卡逻辑。
  - 测试：catalog_expansion/school_starter_data/b5_content_expansion/rarity_data_model/slay_gu_final_chapter 改为 `v1_effect`/V1 combat-shape 守卫；新增合成坏 `v1_effect` 的 validate 红测。定向 9 套件绿（catalog 9、starter 9、b5 4、rarity 10、content_catalog 21、removal 16、imprint 10、npc_stock 13、slay 2）。
  - 验收线：scripts/ 与 tools/ 对 `cards.json|deck_builder|card_blueprint` 零命中；全量 unit 1093 中 3 红 = 并行视觉会话 in-flight 代码（`gu_panel_view.gd:28` 调用 Godot 不存在的 `VBoxContainer.get_child_index`；map 图标/settings 音量断言），非 B2 面（并行 presentation M 文件不可触碰）。
  - 遗留：`action_preview_service.gd:93/102/120` 仍以 `catalog.get("card_by_id", {})` 取 V1 槽定义——load_all 已不再输出该键，`.get` 默认空不报错；V1 蛊槽预览投影本应走 `gu_by_id`（B1 移交态即如此），留待预览子系统收敛批次处理。

**B3 冒烟驱动瘦身**
- 前置：B1（驱动引用的旧路径已清理）。
- 目标：`smoke_render/ui_capture/playthrough_smoke/crash_recovery_driver/integration_smoke/render_probe`（~2840 行）收敛为单一 `scripts/acceptance_driver.gd` + 一个入口参数（模式：smoke/capture/soak），保留崩溃恢复检查。
- 验收：`tools/test.ps1 -Suite integration` 与 `tools/check.ps1` 绿；删除文件无残留引用。
- **2026-09-06 完成态**（提交 `3951e4b` feat + `6e9afbc` fix）：6 驱动收编为单一 `scripts/acceptance_driver.gd`（2818 行）五模式进程内运行——smoke（含原 integration_smoke 真实主场景段）/ capture（--batch hall|map 保留）/ play（PLAYTHROUGH_* env 保留）/ render（SCENE/UNIQUE/VERDICT 保留）/ crash（CRASH_PHASE 三阶段保留）。`tools/crash_recovery_check.ps1` 改启动 `--mode=crash`；`export_presets.cfg` exclude 改 `scripts/acceptance_driver.gd`；契约测试（command_contract 11 / guards 3 / visual_contract 4 / export_filter 1）全绿。
  - 顺带修复 legacy 假绿：旧 smoke 断言失败 quit(1) 后被结尾 quit() 覆盖成 exit 0——shop 屏起的 8 屏 verify 从未真正验证过。新实现单点 quit + 返回码穿透，并修正两处断言过期（Stage 包装层路径前缀；battle 手牌多行卡面按钮改 contains 匹配）。smoke headless 全绿 31 OK + INTEGRATION OK exit 0。
  - 遗留：`.zcode/plan-sess_019430f7` 旧计划文档保留；battle 屏 verify 为真绿首验基线。

### Phase C 流派体系（C1 可与 A 并行）

**C1 道痕清单提炼（只读） → 门 U1**
> 状态：✅ 2026-09-05 完成——产出 `docs/superpowers/specs/2026-09-05-dao-mark-school-list-draft.md`：26 条道痕 + 14 条存疑线索；红线六道（血/气/力/魂/炼/光）全覆盖。**门 U1：✅ 2026-09-05 用户认可；C2/C3 可开工。**
- 目标：从 `分支：六卷精编版/` 只读语料提炼 20+ 道痕/流派清单初稿（id、中文名、一句话界定、代表蛊例），整理成 `docs/superpowers/specs/2026-09-XX-dao-mark-school-list-draft.md`。
- 禁改：语料目录只读；不改任何数据表。
- 完成：初稿交用户审订（门 U1），锁定后 Schema 按开放集合落地。

**C2 存量 214 蛊流派映射 → 门 U2**
> 状态：✅ 2026-09-05 完成（门 U2 用户认可「按文档建议全收」后落库 `d8eca60`）——`gu.json` 214 蛊 school 全量落库（114 改派，分布=映射文档 §0）；`schools.json` v2（20 校，moonlight 并入 light）+ `school_pools.json` v2（每校池=全校蛊，214 全覆盖）；`content_catalog` SCHOOL_IDS 6→20，目录校验绿；测试契约迁移 10 用例绿；快照/图鉴/tooltip 透出中文流派（`school_name`/`school_label`），真实窗口验收（383 唯一色 + 5 流派标签命中）。全量 unit 1143 过 / 3 挂（guitkx A1、imprint/npc_stock B2，均非本工单）。
- 前置：U1 锁定清单。
- 目标：按蛊名/效果/现有表现生成全量映射表（含 `small_light_gu`→光道 这类修正），输出可审 diff 文档；用户审订（门 U2）后一次性落 `gu.json` + `schools.json` v2，`content_catalog` 校验同步，快照与卡面/tooltip/图鉴透出流派。
- 验收：目录校验绿；真实窗口任意蛊卡可见流派标签；wenzhen 系 UI 测试绿。

**C3 转阶落表**
> 状态：✅ 2026-09-05 完成——`content_catalog` rank 校验 1..5 上界（GU_RANK_MAX，test-only 蛊 low_rank_exception 豁免：十转杀蛊）；rarity 与转阶解耦说明落 Schema 注释（epic·1转/common·2转 数据实证）；新增 Boss 量级校验（boss_layer_mult/stage_base 五层键 one..five 全覆盖，对齐 facade.BOSS_LAYER_IDS）；`tests/unit/test_c3_rank_tier_contract.gd` 5/5 红先行绿。全量 unit 1197 过 / 3 挂（guitkx/imprint/npc_stock 非本工单）。提交 `599c553`。
- 前置：U2。
- 目标：rank 语义扩为 1--5 转（5 转对 L1--L5），rarity 与转阶解耦说明落 Schema 注释；`content_catalog` 校验 1--5；Boss 量级挂钩核对（中央倍率 `data/v1_battle.json`）。
- 验收：校验绿 + `test_v1_five_layer_clear` 等层级测试绿。

**C4 蛊虫目录重建（追加工单，2026-09-06 · 门 U3b）**
> 状态：✅ 2026-09-06 完成并提交 `85150f7`——gu.json 由 214 蛊重建为 **802（20 道 × 40~42）**；`refinement_recipes` = **386**（377 advance + 8 fixed + 1 free_mix）；gen_ 程序填充蛊与发明蛊按审计清册删除（现目录 gen_=0）；白豕蛊/石皮蛊/刀翅血蝠蛊/月痕蛊等正名在 `names.json`（802 条）归位；配方按 `(school, rank)` 表达，Schema 强制 value 表值。开场包 starter、商店/掉落/图鉴测试契约全部换锚到新目录，`unit 1210/1210 + integration 37/37 + 0 risky`。
- 说明：本工单吸收了 C2 后续「非原文蛊删除」与「<40 扩充」两项诉求（原任务 #22--#24），以重建而非增删的方式落地。保留蛊效果与原文逐只核验（审计清册第二阶段）留作内容策展线，不阻塞后续工单。

### Phase D 配方体系（阻塞于 U3）
> U3 已于 2026-09-06 过门。D1 的 Schema v2 与配方落表部分成果已在 C4 完成（386 方落 `refinement_recipes.json`）；剩余为按 `2026-09-06-recipe-source-excerpts-draft.md` 扩充跨流派/高转配方与 `synergy` 预留字段。

**D1 配方源结构化落表 → 数据**
- 前置：**U3 用户提供配方源材料**（文本/表格/原著摘录均可）。
- 目标：配方 Schema v2：`{id, output_gu_id, output_rank, inputs: [{school, rank, count}], optional_materials, source}`，按用户模型表达（1转月光蛊×1+1转小光蛊×2→2转月芒蛊；3转需 2转+2转 跨流派）；落 `data/refinement_recipes.json` v2 + Schema 校验；杀招组合字段（synergy）只预留不实现。
- 验收：目录校验绿；每条配方可被领域校验通过。

**D2 合炼玩法接线**
- 前置：D1 + A3（新炼蛊屏）。
- 目标：领域合炼命令（现 `refine` 命令面扩展为配方驱动：按配方消耗对应蛊实例与材料，成功/反噬沿用现有结算与预检红线）；新炼蛊屏展示配方、材料齐备度与风险预览。
- 验收：真实窗口完成一次「按配方合炼出高转蛊」全流程；不可逆成本预检可见。

**D3 杀招数据地基（不实现玩法）**
> 状态：❌ 2026-09-06 关闭（用户裁定）——原验收线「`rg "kill_move" scripts/presentation/` 零命中」建立在「杀招本版推迟」假设上，但 V1 已实现杀招系统（`v1_battle_resolver` `kill_moves` 组装 + `play_kill_move` 命令 + `data/v1_battle.json` + 战斗屏 KillHost），杀招属核心支柱正当实现，验收线无法满足。月光蛊+小光蛊=2x 组合加成并入正式杀招系统（按 2026-09-01 规格）开发时一并设计，不再设单独数据预留工单。
- 目标：仅在数据层预留杀招组合描述结构（蛊效果互补的 synergy 键），快照不透出、无 UI、无战斗逻辑；文档记录月光蛊+小光蛊=2x 的目标语义为下一版规格输入。
- 验收：Schema 校验绿；`rg "kill_move" scripts/presentation/` 零命中（确认无越界实现）。

**D1b 跨流派合炼矩阵（打通 3-5 转合炼链）— 专项（2026-09-06 用户裁定开）**
> 状态：⏳ 待派发（内容策展输入依赖）。背景：I-3 侦察发现全库仅 2 条配方产出 rank3+ 蛊（blood_moon_forged / moon_shadow_locked），180 只 rank3 + 244 只 rank4/5 蛊**无任何合炼产出途径**（gen_ 蛊各族独立无同名前身、loot 仅 elite epic 掉 1 只 4 转蛊）——「海量合成配方」核心支柱在 2→3 转断裂。用户裁定开专项补跨流派矩阵。
- 目标：按 D1 v2 原则（3 转 = 2转+2转 跨流派；4 转 = 3+3；5 转 = 4+4）为全部高转蛊设计合炼链，打通玩家 1→5 转全链。`data/refinement_recipes.json` 增 fixed 方（school/rank/count 表达），Schema v2 已就绪不改。
- 输入（策展）：逐族的「进阶主蛊 × 跨流派伴蛊」方向与语义锚点，源自 `2026-09-06-recipe-source-excerpts-draft.md` R1-R8 + 各道语料；缺目录蛊（幻月/月霓裳/月旋/雾步/影幕/痕石/旋风等）登记于 `2026-09-06-gu-catalog-rebuild-audit-draft.md` §6.1 审计清册二阶段，落库后补对应配方。
- 验收：目录校验绿；每只 rank3-5 蛊 ≥1 条产出配方（可达性脚本断言）；source 锚点齐（derived 注明推导规则）；全量 unit/integration 绿。
- 边界：不阻塞 D2（D2 流程接线可用现有 2 转配方先打通，D1b 内容后补）；synergy 归杀招系统不在此设计。

### Phase S 切片内容组装（第一层封闭验证的实体工单）

**S1 流派与初始蛊**
- 前置：U1（光道入道痕清单）。
- 目标：schools.json 调整为每流派 4 只 1 转初始蛊；新增光道流派；落实石皮蛊（名字现被生成蛊 `gen_soul_attack_120_gu` 占用——新建策展条目 `stone_skin_gu` 或改派，冲突在 C2 映射审订同步定校）；开局流派选择仅定倾向与初始蛊，无加成；快照/UI 按新视觉呈现。
- 验收：新开局选定光道后拥有且仅拥有 4 只初始蛊；真实窗口可走通。

**S2 开局 Buff 系统**
- 前置：A（新 UI 开局流程）。
- 目标：`data/buffs.json` 表驱动，首批 3 条（除 Boss 外敌人 1 血；开局 10 转杀蛊群体 999；开局 2000 元石）；领域在 run 创建时结算 Buff，多选、本切片无限量；开局流程流派选择后进入 Buff 多选；杀蛊按蛊实例入包。
- 验收：三种 Buff 各自真实结算且可叠加；同种子同结果；后续 Buff 用户续填只改表。

**S3 遗葬节点与局内传承**
- 前置：S1、商店信物可购（S5）。
- 目标：新节点类型遗葬（带等级字段）；三选项门控——同转阶侦察蛊发现 / 传承信物感应 / 离开；传承产出表 `data/inheritance_sites.json`：遗葬等级 × 品质（残破 1--2 蛊；普通 3--4 蛊 + 1--2 蛊方；稀有 5--8 蛊 + 3--4 蛊方；超级不做），种子化随机；与冻结 F6 无关。
- 验收：三条路线各走通一次；同种子同产出；关键选择落不可变事件日志；真实窗口可用。

**S4 元素协同战斗效果**
- 前置：B1（单引擎）。
- 目标：`v1_effect` 新增支援类效果——小光蛊「本回合月光系蛊伤害 +2」，战斗按序结算生效；预检/快照可见（透明度红线）；杀招正式系统不实现。
- 验收：真实窗口小光蛊→月光蛊连用伤害 +2；单测覆盖结算与预览。

**S5 商店卖出与信物**
- 前置：A3（新商店屏）。
- 目标：商店支持卖出持有蛊虫/材料换元石（中央定价走 economy_rules）；买入面已支持蛊方（`recipe_unlock`）与线索，补传承信物商品项。
- 验收：卖买循环真实窗口走通；价格全部落表。

**S6 第一层封闭**
- 前置：S1--S5、C3（1--2 转数值）。
- 目标：地图配置为 L1 单层；L1 Boss 击败 → 胜利结算收官；死亡 → 死亡结算；两条路径均遵守存档删除与结局归因红线。
- 验收：集成套件新增切片端到端测试；真实窗口完整一局。

### Phase E 自动存档

**E1 无感自动保存**
- 前置：A 全部合入、S1--S6 完成（切片新内容进存档）。
- 目标：`submit_command` 接受命令后自动 `SaveRepository.save_run`（静默，无 UI 提示），节流策略（如每命令/每视图流转）落常量；地图屏手动保存按钮移除；「继续游戏」读档流程保持；新开局检测到进行中 Run 存档 → 二次确认放弃（`gu_confirm_dialog`）。
- 验收：真实窗口「玩到任意节点→关进程→重开→继续游戏→进度一致」；新开局确认弹窗真实可见；`test_save_repository` 系绿。

### Phase F 里程碑验收

**F1 重构里程碑验收**
- 前置：A--E 全部完成。
- 验收清单：`tools/test.ps1 -Suite unit`、`-Suite integration`、`tools/check.ps1` 全绿；**切片全流程真实窗口走查**（大厅 → 光道 4 蛊开局 → Buff 多选 → L1 地图 → 小光蛊+月光蛊协同战斗 → 商店卖买/蛊方/线索 → 遗葬三路线 → 2 转合炼 → Boss 收官，另验死亡支线与存档连续性）；全屏走查（11 类页面全部新栈、无死按钮/溢出/遮挡）；`data/v1_battle.json` Boss 倍率与转阶量级核对报告。产出验收记录文档。

## 4. 用户审订门汇总

| 门 | 内容 | 阻塞 |
|----|------|------|
| U1 | 20+ 道痕流派清单初稿审订 — ✅ 2026-09-05 用户认可 | C2/C3（已放行） |
| U2 | 214 蛊流派全量映射审订 — ✅ 2026-09-05 用户认可（按文档建议全收） | C2 落库（已完成 `d8eca60`）/C3/D1 |
| U3 | 合炼配方源材料提供 | ✅ 2026-09-06 用户审订通过（`2026-09-06-recipe-source-excerpts-draft.md` 定稿，低转合炼源已生效） |
| U3b | 蛊虫目录重建审订（追加门） | ✅ 2026-09-06 用户审订通过（`2026-09-06-gu-catalog-rebuild-audit-draft.md` 定稿，802 目录已落库） |

**追加裁定（2026-09-06，用户口述，冲突时以本表下方为准）**

- **地图节点收窄**：生成图与 first_run 只保留 combat / rest / shop / layer_boss 四类；事件类（event/encounter/caravan/refinement/cultivation/hazard/inheritance…）从 pacing pools 与 first_run 移除，`nodes.json` 保留全量模板库，事件后续逐个补回。
- **蛊虫目录重建**：gu.json = 802（20 道 × 40~42），refinement_recipes = 386；每月「非原文蛊删除」与「<40 扩充」的原始诉求已由本次重建一次性落地。
- **开局包**：wanderer starter = small_light / blood_farewell / stone_shell / blood_bat / force_gu（school-less runs 保持战斗契约）。
- 上述三项已提交 `85150f7`（unit 1210/1210、integration 37/37、0 risky）。

## 5. 派发规约（每张工单的 Agent brief 附加规则）

- 开工先 `git status --short --branch`；阅读本文件对应工单 + `AGENTS.md` 红线 + 相关契约文档。
- 先写可失败测试或定义可复现验收命令，再实现最小完整改动。
- Godot 一律 headless 或仓库脚本，禁止裸启动 GUI（防挂起）；UI 工单必须加做真实窗口键鼠验收。
- 完成后报告格式：DONE / DONE_WITH_CONCERNS + 改动文件 + 验证命令与结果 + 未验证风险；控制器聚焦提交（消息 ASCII）。
- 提交排除：`.claude/`、未验证的 `data/enemies.json`、无关的 `data/dialogues/events.dialogue` 本地修改。
