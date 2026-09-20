// 从 Godot 侧真实数据表抽取原型子集，产出 js/data.js。
// 运行：node tools/build_data.mjs   （在 game/wenzhen-web-lab/ 下）
// 为什么需要它：原型必须跑在真实数据上，否则"Web vs Godot"的质量对比不成立。
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const gameRoot = path.resolve(here, '..', '..');
const read = (p) => JSON.parse(fs.readFileSync(path.join(gameRoot, p), 'utf8'));

const guEntities = read('world-model/data/gu.json').entities;
const recipes = read('data/refinement_recipes.json').recipes;
const v1 = read('data/v1_battle.json');
const enemyFile = read('data/enemies.json');
const enemies = Array.isArray(enemyFile) ? enemyFile : (enemyFile.entities || enemyFile.enemies || []);

// 原型选用的蛊：M0 白名单 + 杀招表实际用到的几只。图标用 Godot 侧既有流派道徽。
const GU_ICON = {
  moonlight_gu: 'gu_moon', small_light_gu: 'gu_light', moon_glow_gu: 'gu_moon',
  white_boar_strength_gu: 'gu_force', jade_skin_gu: 'gu_water', stone_shell_gu: 'gu_earth',
  white_jade_gu: 'gu_water', blood_farewell_gu: 'gu_blood', blood_droplet_gu: 'gu_blood',
  vitality_grass_gu: 'gu_qi',
};
const guIds = Object.keys(GU_ICON);
const gu = guIds.map((id) => {
  const e = guEntities.find((x) => x.id === id);
  if (!e) throw new Error('gu not found: ' + id);
  return {
    id: e.id, name: e.name_zh, rank: e.rank, rarity: e.rarity, role: e.role,
    school: e.school, value: e.value, cost: e.activation_cost, effect: e.effect,
    icon: GU_ICON[id],
  };
});

// 配方：取同时涉及所选蛊、且是二转产出的固定配方，外加两条升炼。
// 必须过滤掉没有输入蛊的条目：那种配方在原型里会变成"无材料免费开炉"。
const fixed = recipes.filter((r) =>
  r.kind === 'fixed' && r.output_gu_id && guIds.includes(r.output_gu_id) &&
  (r.input_gu_ids || []).length > 0 &&
  r.input_gu_ids.every((i) => guIds.includes(i)));
const advances = recipes.filter((r) => r.kind === 'advance' && guIds.includes(r.output_gu_id)).slice(0, 2);
const picked = [...fixed, ...advances].map((r) => ({
  id: r.id, kind: r.kind, inputs: r.input_gu_ids || [], output: r.output_gu_id,
  stoneCost: r.stone_cost || 0, materials: r.materials || null, source: r.source || null,
}));

const killMoves = (v1.kill_moves || []).filter((k) => (k.recipe || []).every((i) => guIds.includes(i)));

// 敌人中文名来自 data/names.json（真实数据表），不自己起名。
// names.json 是嵌套结构：{ nodes, types, actions, gu, inheritances, enemies: {id: 名} }。
const names = read('data/names.json');
const enemyNames = names.enemies || names;
const ART = {
  neutral_stone_wanderer: 'enemy_stone_wanderer',
  ridge_hound: 'enemy_ridge_hound',
  iron_hide_boar: 'enemy_iron_hide_boar',
  thunder_crown_wolf: 'enemy_thunder_crown_wolf',
  // 带 phases 多阶段 AI 的 Boss（数据里共 5 个，另 3 个无对应立绘未纳入）
  thunder_crown_sovereign: 'enemy_thunder_crown_sovereign',
  // 该 Boss 无专属立绘，用同流派血道蝙蝠近似（原型借图，已在覆盖页声明）
  blood_vein_bishop: 'enemy_bat',
};
const pickedEnemies = Object.keys(ART)
  .map((id) => enemies.find((e) => e.id === id))
  .filter(Boolean)
  .map((e) => ({
    id: e.id, name: enemyNames[e.id] || e.id, rank: e.rank, hp: e.hp, theme: e.theme,
    intent: e.intent, portrait: ART[e.id],
    // 多阶段 AI：数据里 phases 为 [{until_hp_ratio, intents[{damage,speed,cooldown,essence_burn}], reactions}]，
    // 选取语义见数据自带的 _phases_note（冷却、阶段阈值严格递减、全部冷却则 cooldown_wait）。
    // 注意：Godot 运行时不读 phases（只在 enemy_catalog.gd 里做 schema 校验），本页是首个实现。
    phases: e.phases || null,
    phasesNote: e._phases_note || null,
    clues: e.clues || [],
    // 只取"有规则支撑"的反击：trigger=direct_strike、window=before_damage，
    // 且 counter_status 是 Godot 预警真正枚举的 bound/guarded
    // （见 action_preview_service.gd `_live_counter_labels`）。
    // 数据里还有 1 条 counter_status="sparked"，但 scripts/ 与 docs/ 里无任何实现语义，故不纳入。
    reactions: (e.reactions || []).filter((r) => r.trigger === 'direct_strike'
      && r.window === 'before_damage'
      && (r.counter_status === 'bound' || r.counter_status === 'guarded')),
  }));

// 遭遇：战斗节点模板原样抽取（10 个 type=combat；唯一多敌 beast_swarm_pass）。
// 规模口径见 map_generator.gd（maxi(1, fallback.size())），运行时敌名单口径见
// battle_command_facade.gd `_v1_enemies`（enemy_roll > enemy_kinds > enemy_kind）。
const nodesFile = read('data/nodes.json');
const nodeList = Array.isArray(nodesFile) ? nodesFile : (nodesFile.nodes || []);
const nodeNames = names.nodes || {};
const encounters = nodeList
  .filter((t) => t.type === 'combat')
  .map((t) => ({
    id: t.id,
    name: nodeNames[t.id] || t.id,
    type: t.type,
    enemy_kind: t.enemy_kind || null,
    enemy_kinds: t.enemy_kinds ? [...t.enemy_kinds] : null,
    enemy_theme: t.enemy_theme || null,
    boss_pool: t.boss_pool ? [...t.boss_pool] : null,
    summary: t.summary || '',
  }));
// 机制覆盖清单：给开发者看的"这个页面验了什么、没验什么"。
// 只列已实现且能指到源头的机制；未覆盖项要写清为什么没做，避免页面看起来比实际完整。
const mechanisms = {
  covered: [
    { name: '真实蛊实体', detail: '10 只蛊的名称/转数/稀有度/流派/价值/效果', source: 'world-model/data/gu.json（802 实体）' },
    { name: '合炼与升炼配方', detail: '6 条配方的材料、元石成本、原文出处行号；失败代价按原文个案（小光蛊消亡）', source: 'data/refinement_recipes.json（468 条）' },
    { name: '杀招组装与消耗', detail: '3 个杀招的配方、真元/念头消耗、效果', source: 'data/v1_battle.json → kill_moves（26 条）' },
    { name: '真元上限与回复', detail: '真元上限 = stage_base × aptitude_mult；每回合按 regen_pct 回复（丙等 25%）', source: 'data/v1_battle.json → stage_base / aptitude_mult / regen_pct' },
    { name: '敌人意图', detail: '意图标签与伤害，每回合公开', source: 'data/enemies.json → intent' },
    { name: '线索与反击（隐藏→揭示）', detail: '敌人自带 clues 与 reactions；揭示前不预警，揭示后可预警', source: 'v1_battle_resolver.gd:136,724-731（counter_revealed）' },
    { name: '直接攻击被反击吞掉', detail: '触发条件 trigger=direct_strike / window=before_damage；吞掉后敌方进入 bound/guarded，该反击随即不再预警', source: 'action_preview_service.gd:325-347（_live_counter_labels）' },
    { name: '多阶段 AI（阶段 + 冷却门禁）', detail: '按 until_hp_ratio 切阶段；每阶段可有多条意图，第 T 回合发出后 T+cooldown+1 起才可再选；当前阶段所有意图都在冷却时显示 cooldown_wait、该回合不攻击', source: 'data/enemies.json 的 phases 与自带 _phases_note；enemy_catalog.gd:174-208 只做 schema 校验，运行时未实现——本页是首个实现' },
    { name: '焚元意图', detail: '意图带 essence_burn 时烧掉玩家真元（蚀脉扰元 / 麻痹长嗥）', source: 'data/enemies.json phases[].intents[].essence_burn（按字段名直译，Godot 运行时不读该字段）' },
    { name: '多敌遭遇', detail: '10 个 type=combat 模板中唯一多敌 beast_swarm_pass（enemy_kinds 2 只）；规模 = enemy_kinds 长度；玩家点选目标、未选回退第一个存活；敌方按数组序逐个结算、每次立即判胜负；全灭才胜利；反击/阶段/冷却每敌一份；护体是池语义', source: 'data/nodes.json → beast_swarm_pass；battle_command_facade.gd:58-68,152-160（_v1_enemies）；v1_grammar_pipeline.gd:103-124（resolve_targets）、132-137（alive_count）；v1_battle_resolver.gd:110-135（_build_enemies）、644（_enemy_is_alive）、820-826（end_turn）、1063-1072（焚元）、1083-1088（护体池）' },
  ],
  notCovered: [
    { name: 'marked 刻痕', why: 'v1_battle.json 的 kill_moves 里没有任何带 marked 的招，来源在剑道刻痕通道，本批无数据支撑，不臆造' },
    { name: 'sealed 封印', why: '同上，26 个 kill_moves 无 sealed 效果' },
    { name: 'support_bonus 辅助加成', why: '只在 content_catalog.gd 里做 schema 校验，未找到结算应用点，故不实现' },
    { name: '意图选取顺序', why: '数据未写明多意图之间的优先级（_phases_note 只定义了冷却门禁）。本页取"数据顺序中第一条可用的"，属原型设定，Godot 无实现可对照' },
    { name: '另 3 个带阶段数据的 Boss', why: 'blood_vein_bishop 之外的 clan_patriarch / blue_fur_jiangshi / miasma_vein_lord 缺少对应立绘，未纳入；其中 clan_patriarch 的「家族征召」是 damage 0 且无 essence_burn，语义未知' },
    { name: 'Boss 立绘', why: '血络主教无专属立绘，借用同流派血道蝙蝠图（enemy_bat.png），仅影响观感' },
    { name: '念头/魂魄完整系统', why: '本页只用了念头作为行动成本，魂魄与失控未实现' },
    { name: '确定性、存档、事件日志', why: '本原型完全没有：随机、不落盘、不改写状态机，仅供视觉确认' },
    { name: 'counter_status="sparked"（雷冠头狼）', why: '数据漂移：data/enemies.json 声明了该反击状态，但 scripts/ 与 docs/ 里零命中，规则层无实现语义。本页不臆造，已从反击列表剔除' },
    { name: '线索的中文名', why: '数据缺口：data/names.json 没有 clues 分区，敌人线索只有 id（stone_dust、steady_stance 等）；本页照原样显示 id，不自行译名' },
  ],
};

// 数据/规则漂移：跑 build_data 时顺手报出来，避免"数据里写了但没人实现"悄悄溜过去。
const drift = [];
enemies.forEach((e) => (e.reactions || []).forEach((r) => {
  if (!['bound', 'guarded'].includes(r.counter_status)) {
    drift.push(`${e.id} 的 counter_status="${r.counter_status}" 无规则实现`);
  }
}));

const battle = {
  aptitudeMult: v1.aptitude_mult, regenPct: v1.regen_pct, stageBase: v1.stage_base,
  thoughtCostDefault: v1.thought_cost_default, trueQiCostDefault: v1.true_qi_cost_default,
  fightDamageBase: v1.fight_damage_base,
};

const out = { gu, recipes: picked, killMoves, enemies: pickedEnemies, encounters, battle, mechanisms };
const banner = '// 本文件由 tools/build_data.mjs 从 Godot 侧数据表生成，不要手改。\n'
  + '// 用普通脚本（非 ES module）产出，这样 file:// 双击打开也能跑，不必起本地服务。\n';
fs.writeFileSync(path.join(here, '..', 'js', 'data.js'),
  banner + 'const DATA = ' + JSON.stringify(out, null, 2) + ';\n');
console.log('gu', gu.length, '| recipes', picked.length, '| killMoves', killMoves.length, '| enemies', pickedEnemies.length, '| encounters', encounters.length);
if (drift.length) console.log('数据/规则漂移（' + drift.length + '）：\n  - ' + drift.join('\n  - '));
