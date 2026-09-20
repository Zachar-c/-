# L3 任务包 · 网页端决定性实验 S1：多敌遭遇

```text
WORKFLOW ROLE:
L3 Web Lab Worker（读写限定 game/wenzhen-web-lab/**；Godot 线只读）

UPSTREAM:
Codex Orchestrator（L2）

DOWNSTREAM:
Codex Review（L2）→ 实验计量表（docs/2026-09-20-deepening-experiment.md §3）

PROJECT GOAL:
《问真》（《蛊真人》改编游戏）的**载体裁决**需要证据：规则复杂度上升后，
Web 侧的改写速度是否还保持。game/wenzhen-web-lab/ 就是为回答这个问题建的功能验收台。

CURRENT PHASE:
V2 需求重构期。L0 禁止开发、只允许研究；**已单独裁决**允许网页端做这一件「决定性实验」。
本包是该实验的第 1 步。前 3 天的成果（炼蛊/杀招/战斗/反击/多阶段 AI）已在页面上跑通，
本包是第一次让**规则密度真正上升**。

TASK PURPOSE:
把战斗从「单敌」扩到「多敌」，并逐条照搬 Godot 侧**既有**语义。
它给上游解决的是：这是「Web 是否只在玩具规模下快」的第一个台阶。

TASK:
1) 读完现状：js/main.js（单敌结构与 act.*）、js/rules.js（全部判定）、js/battle.js（渲染）、
   tools/build_data.mjs（数据生成）。
2) 按下文「规格来源」逐条实现多敌遭遇；**所有判定必须能指回 Godot 行号**。
3) 更正覆盖页里一条**已被证伪**的声明（见下「必须更正」）。
4) 出报告。

--------------------------------------------------------------------
规格来源（Godot，只读；这是唯一权威，不许自行发明规则）
--------------------------------------------------------------------

A. 遭遇怎么组
   - 数据里**唯一**的多敌遭遇：game/data/nodes.json → 模板 beast_swarm_pass，
     字段 enemy_kinds: ["ridge_hound", "neutral_stone_wanderer"]。
     其余 9 个 type=combat 模板都是单敌 enemy_kind。
   - 遭遇规模 = 模板 enemy_kinds 的长度：
     scripts/domain/map_generator.gd:345-346
     `roll_enemy_ids(..., maxi(1, fallback.size()), ...)`
   - 运行时读取优先级 enemy_roll > enemy_kinds > enemy_kind：
     scripts/domain/battle_command_facade.gd:152-160（`_v1_enemies`）
   - **多敌遭遇只落 enemy_kinds**，单敌才同时落 enemy_kind：
     scripts/domain/battle_command_facade.gd:58-68

B. 每个敌人一张独立状态表
   - 逐只构造字段见 scripts/domain/battle_command_facade.gd:160-188：
     {id, label, hp, phases, intent{id,kind,damage,label,speed,cooldown,
      essence_burn,seal_turns,soul_drain,life_cost,counter_tag}}
   - last_fired / phases+phase_index / statuses（bound、guarded）都是**每敌一份**：
     scripts/domain/v1_battle_resolver.gd:110-135（`_build_enemies`，phase_index: -1, last_fired: {}）

C. 玩家出招的目标选择（顺序不可调）
   scripts/domain/v1_grammar_pipeline.gd:103-124（`resolve_targets`）：
     1. effect.aoe == true 或 selector == "enemy_all" → 全部存活敌人（数组序）
     2. selector == "self" → self
     3. selector == "enemy_first" → 数组序第一个存活
     4. target_key 非空 → 该 id
     5. 兜底 → 数组序第一个存活
   本页现状：data/v1_battle.json 的 kill_moves 没有 aoe/selector 字段，所以默认口径 =
   **玩家点选目标，未选则回退第一个存活**（第 5 条）。若某杀招数据带 aoe，按第 1 条打全部。
   不许自创「随机目标」「打最弱的」这类规则。

D. 敌方回合顺序
   scripts/domain/v1_battle_resolver.gd:820-826（`end_turn`）：
   按 enemies **数组序**，逐个存活敌人结算自己的意图；每结算完一个**立即判胜负**，已分胜负就停。
   不是同时结算，不是按速度排序。

E. 存活与胜利
   - 存活判定 = hp > 0：scripts/domain/v1_battle_resolver.gd:644（`_enemy_is_alive`）
   - 计数：scripts/domain/v1_grammar_pipeline.gd:132-137（`alive_count`）
   - **全灭才胜利**。

F. 反击吞掉是「每敌各管各的」
   现状 js/main.js:181-193 用全局 b.flags。多敌后：
   - bound/guarded 挂到**被打的那一只**身上；
   - 预警只显示**当前选中目标**的反击（口径 source：scripts/domain/action_preview_service.gd
     `_live_counter_labels`，判定条件 trigger=direct_strike、window=before_damage，
     且 counter_status=bound 遇 enemy_bound、guarded 遇 guarded 时该反击失效）。

G. 护体是「池」，不是「一次性免伤」
   scripts/domain/v1_battle_resolver.gd:1083-1088（`_damage_player`）：
   `after_shield = max(0, shield - amount)`；`leftover = max(0, amount - shield)`；
   只扣 leftover 的气血，**shield 不清零**。多敌时逐个敌人依次消耗同一个池子。
   ⚠ 现状 js/main.js:58-60 是 `absorbed = min(block, dmg); block = 0` ——
     单敌下与 Godot 等价，多敌下**不等价**。S1 必须改成池语义（block -= absorbed）。
   已知且**不在本包范围**的差异：Godot 的护体跨回合保留，本页是回合结束清零
   （既有原型设定）——照旧在覆盖页标注，不要偷偷改也不要偷偷抹掉这条标注。

H. 焚元
   scripts/domain/v1_battle_resolver.gd:1063-1072：意图实际发出即扣玩家真元，下限 0，
   与伤害**独立**（护体不吞焚元）。多敌下每只都可能焚。

--------------------------------------------------------------------
必须更正（覆盖页有一条已被证伪）
--------------------------------------------------------------------

tools/build_data.mjs 的 mechanisms.notCovered 里写着：

  { name: '多敌遭遇', why: 'data/nodes.json 的节点是 enemy_kind 单敌结构，未见多敌编组数据' }

**这条是错的**：数据里有 enemy_kinds，只是当时只查了 enemy_kind。
处理：删掉该条，把「多敌遭遇」加进 covered，source 写清本条 A/B/C/D 的出处
（nodes.json → beast_swarm_pass / battle_command_facade.gd / v1_grammar_pipeline.gd / v1_battle_resolver.gd）。

--------------------------------------------------------------------
产出要求
--------------------------------------------------------------------

1. tools/build_data.mjs：新增 encounters 抽取（从 game/data/nodes.json）：
   至少含 beast_swarm_pass（多敌 2 只）与其余 combat 模板；字段照数据原样
   （id / type / enemy_kind / enemy_kinds / enemy_theme / boss_pool）。
   生成到 js/data.js（唯一来源，不手改生成物）。
2. js/rules.js：把吃 battle.enemy 的函数改成吃「单个敌人对象 + 回合数」。
   phaseView / activePhase / intentReady / selectIntent 已是纯函数；重点改
   reactionLive / reactionSettled / liveReactions 的目标口径（按目标取，不读全局 flags）。
3. js/main.js：startBattle(encounterId) 建 b.enemies[]（每只带 hpMax/hp/phaseIndex/
   lastFired/flags/statuses）；useMove(id, targetId) 只打选中目标（aoe 时打全部存活）；
   enemyTurn 按数组序遍历存活敌人；胜利 = 全灭；护体改池语义。
4. js/battle.js：敌方区改成列表，每只一盒：
   立绘 / 名 / 血条 / 阶段 / 本回合意图 / 意图冷却 / 线索 / 反击 / 状态；
   可点选目标（选中高亮），默认第一个存活。

SCOPE:
读：game/wenzhen-web-lab/**、game/data/nodes.json、game/data/enemies.json、
    game/scripts/domain/{battle_command_facade,v1_battle_resolver,v1_grammar_pipeline,map_generator,enemy_catalog}.gd、
    game/wenzhen-web/tools/drive.mjs（驱动工具，只读）。
写：game/wenzhen-web-lab/js/**、game/wenzhen-web-lab/tools/build_data.mjs、
    game/wenzhen-web-lab/docs/2026-09-20-s1-report.md（新建）。

DO NOT:
- 不改 Godot 线任何文件（game/scripts/**、game/data/**、game/world-model/** 只读）。
- 不动 js/data.js（生成物）、不动 docs/2026-09-19-handoff.md（上一轮记录）、
  不动 docs/2026-09-20-deepening-experiment.md（计量表由 L2 填）。
- 不引入 ES module / 构建步骤 / 新依赖；必须保持双击 file:// 能开（普通脚本按序加载，
  相对路径，无 fetch）。
- 不 commit、不 push、不 merge。
- 不自创规则：写不出 Godot 出处的东西不要做。

ACCEPTANCE:
1. `node tools/build_data.mjs` 跑通，输出含 encounters 计数。
2. 用真实时间驱动无头 Edge 端到端真点：
   `node ../wenzhen-web/tools/drive.mjs "<file://…/index.html>?silent=1" "<计划>" "1280,720"`
   计划至少覆盖（每步后可 eval 断言 + shot 截图）：
   a. 进战斗页 → 选多敌遭遇（兽潮隘口）→ 两只都在 → 截图
   b. 点选目标 A 出招 → 断言 **只有 A 掉血、B 不掉** → 截图
   c. 打死 A → 断言 B 仍在，B 的意图/反击照常显示 → 截图
   d. 打死 B → 断言胜利、元石 +2 → 截图
   e. 单独一场：直接攻击被反击吞掉时，状态只挂到**被打的那只**身上 → 截图
3. **必须真看图**（不能只凭 document.documentElement.dataset.ready === '1' 就算完成）。
4. 页面上覆盖页可见已更正（多敌从「未覆盖」移到「已覆盖」）。
5. 报告 game/wenzhen-web-lab/docs/2026-09-20-s1-report.md：
   改了哪些文件 + 每个文件的净增改行数（`git diff --stat` 口径，排除 js/data.js）+
   每张截图路径 + 每条断言的**实际输出文本**。

ESCALATE WHEN:
- 发现某条 Godot 语义我上面写错了（停下、指出行号、别顺着做）；
- 多敌遭遇在数据里其实不止 beast_swarm_pass 一处；
- 需要给杀招编造 aoe/selector 数据才能继续（那是数据问题，不是实现问题）。

STATUS TARGET:
READY_FOR_REVIEW
```

## 返回格式

```text
STATUS: DONE / PARTIAL / BLOCKED
CHANGED:
FOUND:
EVIDENCE:
TESTS:
RISKS:
QUESTIONS:
```
