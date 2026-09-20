// 从 Godot 侧真实数据表抽取原型子集，产出 js/data.js。
// 运行：node tools/build_data.mjs   （在 game/wenzhen-web-lab/ 下）
// 为什么需要它：原型必须跑在真实数据上，否则"Web vs Godot"的质量对比不成立。
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const gameRoot = path.resolve(here, '..', '..');
const read = (p) => JSON.parse(fs.readFileSync(path.join(gameRoot, p), 'utf8'));

const battleGuFile = read('data/gu.json');
const guEntities = Array.isArray(battleGuFile) ? battleGuFile : (battleGuFile.entities || battleGuFile.gu || []);
const battleGuById = Object.fromEntries(
  (Array.isArray(battleGuFile) ? battleGuFile : (battleGuFile.entities || battleGuFile.gu || []))
    .map((entry) => [entry.id, entry]),
);
const names = read('data/names.json');
const recipes = read('data/refinement_recipes.json').recipes;
const v1 = read('data/v1_battle.json');
const balance = read('data/balance.json');
const aptitude = read('data/aptitude.json');
const lootTables = read('data/loot_tables.json');
const pacing = read('data/pacing.json');
const schoolPools = read('data/school_pools.json');
const enemyFile = read('data/enemies.json');
const enemies = Array.isArray(enemyFile) ? enemyFile : (enemyFile.entities || enemyFile.enemies || []);
const firstRun = read('data/first_run.json');

// 原型选用的蛊：M0 白名单 + 杀招表 + 商店货架实际引用的几只。图标用 Godot 侧既有流派道徽。
const ICON_BY_SCHOOL = {
  moon: 'gu_moon', light: 'gu_light', force: 'gu_force', water: 'gu_water',
  earth: 'gu_earth', blood: 'gu_blood', qi: 'gu_qi', refine: 'gu_refine',
  sword: 'gu_sword', fire: 'gu_fire', poison: 'gu_poison', wind: 'gu_wind',
  thunder: 'gu_thunder', wisdom: 'gu_qi',
};
const LAB_EFFECT_GU_IDS = [
  'blood_atk_5_02_gu',
  'fire_atk_2_01_gu',
  'water_atk_3_05_gu',
  'wisdom_rec_1_20_gu',
  'wisdom_atk_3_13_gu',
];
const COMBAT_GU_ICON = {
  moonlight_gu: 'gu_moon', small_light_gu: 'gu_light', moon_glow_gu: 'gu_moon',
  white_boar_strength_gu: 'gu_force', jade_skin_gu: 'gu_water', stone_shell_gu: 'gu_earth',
  white_jade_gu: 'gu_water', blood_farewell_gu: 'gu_blood', blood_droplet_gu: 'gu_blood',
  vitality_grass_gu: 'gu_qi', sword_atk_1_06_gu: 'gu_sword', sword_atk_1_05_gu: 'gu_sword',
  sword_rec_1_10_gu: 'gu_sword', qi_atk_1_01_gu: 'gu_qi', qi_rec_2_14_gu: 'gu_qi',
  wood_atk_1_05_gu: 'gu_qi', water_atk_1_08_gu: 'gu_water', moon_shadow_gu: 'gu_moon',
  blood_heal_2_23_gu: 'gu_blood',
};
// 舍利蛊与资质蛊不参与战斗，只进入蛊仓。舍利蛊沿用 Godot 现有实体；
// 资质蛊是本轮 L0 明确要求的 lab-only 普通蛊实体。
const SUPPORT_GU_IDS = new Set([
  'aptitude_gu',
  'gold_atk_2_11_gu',
  'gold_atk_2_12_gu',
  'gold_atk_3_13_gu',
  'gold_atk_4_14_gu',
  'gold_atk_5_15_gu',
  'gold_atk_2_16_gu',
]);
const SUPPORT_GU_ICON = {
  aptitude_gu: 'gu_qi',
  gold_atk_2_11_gu: 'gu_qi',
  gold_atk_2_12_gu: 'gu_qi',
  gold_atk_3_13_gu: 'gu_qi',
  gold_atk_4_14_gu: 'gu_qi',
  gold_atk_5_15_gu: 'gu_qi',
  gold_atk_2_16_gu: 'gu_qi',
};
const GU_ICON = { ...COMBAT_GU_ICON, ...SUPPORT_GU_ICON };
const shopFile = read('data/shops.json');
const shopOffersRaw = shopFile.offers || [];
const shopGuIds = shopOffersRaw
  .filter((o) => o.kind === 'purchase' && o.gu_id)
  .map((o) => o.gu_id);
const guIds = [...new Set([...Object.keys(GU_ICON), ...shopGuIds, ...LAB_EFFECT_GU_IDS])]
  .filter((id) => guEntities.some((e) => e.id === id));
const RANK_SCALED_EFFECT_KINDS = new Set(['strike', 'shield', 'heal']);
const defaultBattleEffect = (definition, role, rank) => {
  const raw = v1.default_effect_by_role?.[role];
  if (!raw) return {};
  const effect = JSON.parse(JSON.stringify(raw));
  if (RANK_SCALED_EFFECT_KINDS.has(String(effect.kind || ''))) {
    effect.amount = Number(effect.amount || 1) + Math.max(0, Number(rank || 1) - 1);
  }
  if (effect.support_school === 'self') {
    effect.support_school = String(definition.school || '');
  }
  return effect;
};
const guView = (e) => {
  const battle = battleGuById[e.id] || {};
  const role = battle.role || e.role;
  const rank = battle.rank ?? e.rank ?? 1;
  const effect = battle.v1_effect || e.v1_effect;
  const support = SUPPORT_GU_IDS.has(e.id);
  const battleEffect = support
    ? null
    : effect
      ? JSON.parse(JSON.stringify(effect))
      : defaultBattleEffect(e, role, rank);
  return {
    id: e.id, name: names.gu?.[e.id] || e.id, rank: e.rank, rarity: e.rarity,
    role: support ? 'support' : role,
    school: e.school, value: e.value, cost: Number(e.true_qi_cost ?? e.essence_cost ?? 0),
    effect: support
      ? { kind: e.id === 'aptitude_gu' ? 'aptitude_up' : 'breakthrough_material' }
      : effect
        ? JSON.parse(JSON.stringify(effect))
        : defaultBattleEffect(e, role, rank),
    icon: GU_ICON[e.id] || ICON_BY_SCHOOL[e.school] || 'gu_qi',
    combat: support ? '' : (battle.combat || ''),
    battleEffect,
    trueQiCost: Number(battle.true_qi_cost ?? battle.essence_cost ?? e.true_qi_cost ?? e.essence_cost ?? 0),
    thoughtCost: Number(battle.thought_cost ?? v1.thought_cost_default ?? 1),
    lowRankException: Boolean(battle.low_rank_exception || false),
    lifeCost: Number(battle.life_cost ?? 0),
    labOnly: e.id === 'aptitude_gu',
  };
};
const gu = guIds.map((id) => {
  const e = guEntities.find((x) => x.id === id);
  if (!e) throw new Error('gu not found: ' + id);
  return guView(e);
});
const lootGuIds = new Set([
  ...Object.values(lootTables.loot || {}).flatMap((table) =>
    Object.values(table.gu_pool?.by_rarity || {}).flat()),
  ...(schoolPools.light || []),
]);
for (const id of lootGuIds) {
  if (gu.some((entry) => entry.id === id)) continue;
  const e = guEntities.find((x) => x.id === id);
  if (!e) continue;
  gu.push(guView(e));
}
if (!gu.some((entry) => entry.id === 'aptitude_gu')) {
  gu.push({
    id: 'aptitude_gu',
    name: '资质蛊',
    rank: 1,
    rarity: 'rare',
    role: 'support',
    school: 'human',
    value: 20,
    cost: 0,
    effect: { kind: 'aptitude_up' },
    icon: 'gu_qi',
    combat: '',
    battleEffect: null,
    trueQiCost: 0,
    thoughtCost: 0,
    lowRankException: false,
    lifeCost: 0,
    labOnly: true,
  });
}
const baseGuIds = Object.keys(COMBAT_GU_ICON);

// 配方：取同时涉及所选蛊、且是二转产出的固定配方，外加两条升炼。
// 必须过滤掉没有输入蛊的条目：那种配方在原型里会变成"无材料免费开炉"。
const fixed = recipes.filter((r) =>
  r.kind === 'fixed' && r.output_gu_id && baseGuIds.includes(r.output_gu_id) &&
  (r.input_gu_ids || []).length > 0 &&
  r.input_gu_ids.every((i) => baseGuIds.includes(i)));
const advances = recipes.filter((r) => r.kind === 'advance' && baseGuIds.includes(r.output_gu_id)).slice(0, 2);
const picked = [...fixed, ...advances].map((r) => ({
  id: r.id, kind: r.kind, inputs: r.input_gu_ids || [], output: r.output_gu_id,
  stoneCost: r.stone_cost || 0, materials: r.materials || null, source: r.source || null,
  successRollMax: r.success_roll_max ?? 100,
}));

const killMoves = (v1.kill_moves || []).filter((k) => (k.recipe || []).every((i) => baseGuIds.includes(i)));

// 敌人中文名来自 data/names.json（真实数据表），不自己起名。
// names.json 是嵌套结构：{ nodes, types, actions, gu, inheritances, enemies: {id: 名} }。
const enemyNames = names.enemies || names;
const PORTRAIT_BY_THEME = {
  beast: 'enemy_beast_swarm',
  cultivator: 'enemy_sanxiu',
  faction: 'enemy_sanxiu',
  anomaly: 'enemy_toad',
  neutral: 'enemy_stone_wanderer',
};
const ART = {
  neutral_stone_wanderer: 'enemy_stone_wanderer',
  ridge_hound: 'enemy_ridge_hound',
  iron_hide_boar: 'enemy_iron_hide_boar',
  thunder_crown_wolf: 'enemy_thunder_crown_wolf',
  crag_serpent_matriarch: 'enemy_crag_serpent_matriarch',
  marrow_gu_adept: 'enemy_sanxiu',
  ridge_elite_scout: 'enemy_sanxiu',
  miasma_vein_lord: 'enemy_toad',
  clan_patriarch: 'enemy_sanxiu',
  blue_fur_jiangshi: 'enemy_centipede',
  demon_path_adept: 'enemy_sanxiu',
  // 带 phases 多阶段 AI 的 Boss（数据里共 5 个，另 3 个无对应立绘未纳入）
  thunder_crown_sovereign: 'enemy_thunder_crown_sovereign',
  // 该 Boss 无专属立绘，用同流派血道蝙蝠近似（原型借图，已在覆盖页声明）
  blood_vein_bishop: 'enemy_bat',
};
const nodesFile = read('data/nodes.json');
const nodeList = Array.isArray(nodesFile) ? nodesFile : (nodesFile.nodes || []);
const routeIds = firstRun.route_ids || [];
const routeEnemyIds = routeIds.flatMap((id) => {
  const node = nodeList.find((n) => n.id === id);
  return node ? [node.enemy_kind, ...(node.enemy_kinds || [])].filter(Boolean) : [];
});
const pickedEnemyIds = [...new Set([...Object.keys(ART), ...routeEnemyIds])]
  .filter((id) => enemies.some((e) => e.id === id));
const pickedEnemies = pickedEnemyIds
  .map((id) => enemies.find((e) => e.id === id))
  .filter(Boolean)
  .map((e) => ({
    id: e.id, name: enemyNames[e.id] || e.id, rank: e.rank, hp: e.hp, theme: e.theme,
    tier: e.tier || 'common',
    intent: e.intent, portrait: ART[e.id] || PORTRAIT_BY_THEME[e.theme] || 'enemy_beast_swarm',
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
const nodeNames = names.nodes || {};
const nodeView = (n) => ({
  id: n.id,
  name: nodeNames[n.id]
    || (n.enemy_kind && enemyNames[n.enemy_kind])
    || (n.summary ? String(n.summary).split(/[，。；]/)[0] : n.id),
  stage: n.stage || null,
  type: n.type,
  summary: n.summary || '',
  choices: n.choices || [],
  nextIds: n.next_ids || [],
  enemyKind: n.enemy_kind || null,
  enemyKinds: n.enemy_kinds ? [...n.enemy_kinds] : null,
  enemyTheme: n.enemy_theme || null,
  bossPool: n.boss_pool ? [...n.boss_pool] : null,
  npcId: n.npc_id || null,
  eventId: n.event_id || null,
  layerBoss: n.layer_boss || null,
  layer: n.layer ?? n.layer_boss ?? null,
});
const nodes = nodeList.map(nodeView);
const nodeById = Object.fromEntries(nodes.map((n) => [n.id, n]));
let routeLayer = 1;
const route = routeIds.map((id) => {
  const node = nodeById[id];
  if (!node) return null;
  node.layer = node.layerBoss || routeLayer;
  if (node.layerBoss) routeLayer = Math.min(5, node.layerBoss + 1);
  return node;
}).filter(Boolean);
const encounters = nodeList
  .filter((t) => t.type === 'combat')
  .map(nodeView);

// L0 裁决（2026-09-20）：原型只保留蛊/材料货架与蛊方服务。
// 不继承 Godot 的恶名、资源交换、寿元交易、以物易物、补魂丹与配方解锁服务。
const SHOP_OFFER_KINDS = new Set(['purchase', 'material_purchase', 'gu_fang_unlock']);
const supportShopOffers = [
  { id: 'lab_shop_aptitude_gu', kind: 'purchase', gu_id: 'aptitude_gu', tier: 1, stone_cost: 20 },
  ...['gold_atk_2_11_gu', 'gold_atk_2_12_gu', 'gold_atk_3_13_gu', 'gold_atk_4_14_gu', 'gold_atk_5_15_gu']
    .map((guId, index) => {
      const entity = battleGuById[guId] || {};
      return {
        id: `lab_shop_${guId}`,
        kind: 'purchase',
        gu_id: guId,
        tier: Math.max(1, Number(entity.rank || index + 2)),
        stone_cost: Math.max(5, Number(entity.value || 5) * 2),
      };
    }),
];
const shopOffers = [...shopOffersRaw, ...supportShopOffers]
  .filter((o) => SHOP_OFFER_KINDS.has(String(o.kind || '')))
  .map((o) => ({ ...o, gu_name: o.gu_id ? (names.gu?.[o.gu_id] || '') : '' }));
const shopOfferIds = new Set(shopOffers.map((o) => String(o.id)));
const materialById = lootTables.materials || {};
const materials = Object.entries(materialById).map(([id, value]) => ({
  id,
  name: value.name_zh || id,
  qualityBand: value.quality_band || '',
  daoTags: value.dao_tags || [],
}));
const labSchool = 'light';
const schoolPromotionMaterials = new Set();
for (const recipe of recipes) {
  if (recipe.kind !== 'promotion' || !String(recipe.id || '').startsWith(`promote_${labSchool}_`)) continue;
  for (const materialId of Object.keys(recipe.materials || {})) schoolPromotionMaterials.add(materialId);
}
const materialPityTargetsByTier = {};
for (const [tier, bands] of Object.entries(lootTables.pity?.material_pity?.target_bands_by_tier || {})) {
  const ids = (lootTables.loot?.[tier]?.material_pool || []).map((entry) =>
    typeof entry === 'string' ? entry : entry.id);
  materialPityTargetsByTier[tier] = [...new Set(ids)].filter((id) =>
    schoolPromotionMaterials.has(id) && (bands || []).includes(materialById[id]?.quality_band));
}
const npcs = read('data/npcs.json').map((n) => ({
  ...n,
  stock: (n.stock || []).filter((id) => shopOfferIds.has(String(id))),
}));
const events = read('data/events.json').events || [];
// 机制覆盖清单：给开发者看的"这个页面验了什么、没验什么"。
// 只列已实现且能指到源头的机制；未覆盖项要写清为什么没做，避免页面看起来比实际完整。
const mechanisms = {
  covered: [
    { name: '真实蛊实体', detail: '77 只可在当前原型出现的蛊定义（基础白名单 + 战利品池 + V1 特殊效果样本 + 舍利/资质蛊）；舍利与资质蛊不进入战斗列表', source: 'data/gu.json（802 实体）+ 本轮 L0 要求的 lab-only 资质蛊' },
    { name: '固定节点图与统一整备', detail: '开局按难度生成固定五段分支图；每段准备深度为简单 15 / 普通 10 / 困难 5，只展示当前可走的 2–3 个后继；每场战斗胜利后进入同一整备页', source: '本轮设计：docs/superpowers/specs/2026-09-20-wenzhen-web-run-flow-convergence-design.md' },
    { name: '合炼与升炼配方', detail: '6 条配方的材料、元石成本、原文出处行号；判定用 run seed 与事件序号，失败销毁全部投入', source: 'data/refinement_recipes.json（468 条）；refine_command_rules.gd::_refinement_roll/_apply_fixed_recipe' },
    { name: '蛊虫行动', detail: '所有已炼化战斗蛊直接进入战斗可用列表，无固定槽位上限；每回合念头/行动数按魂魄分档，转数质量门禁、真元/念头成本、条件门禁、每回合一次限制与同流派支援按 Godot 解析器执行', source: 'data/gu.json → combat/true_qi_cost/thought_cost/v1_effect；action_points.gd::per_turn；cultivator_rules.gd::can_activate；v1_battle_resolver.gd::can_play_gu/play_gu；v1_grammar_pipeline.gd::gate_miss_reason' },
    { name: '寿元、延迟、状态消费与意图弱化', detail: 'gu life_cost 在支付后结算，归零立即败北且本次效果不执行；delay 先付费后登记，到期回合重放；consume_status 要求至少一层并在命中后全额清除；weaken_intent 只降低目标下一次伤害意图并在消费或回合末归零', source: 'data/gu.json → life_cost/v1_effect.delay/v1_effect.consume_status/kind=weaken_intent；v1_battle_resolver.gd::_spend_costs/_apply_effect/_fire_delayed_effects/_resolve_enemy_intent/end_turn；v1_grammar_pipeline.gd::gate_miss_reason' },
    { name: '野生蛊炼化', detail: '开局带 2 只野生小光蛊；野生蛊不可催动；炼化按 rank 支付 4+2×(rank-1) 真元，成功后转为已炼化实例并可出战', source: 'run_opening_flow.gd::_inject_wild_starters；refine_command_rules.gd::_attune_gu；refine_snapshot.gd::attune_candidates' },
    { name: '杀招组装与消耗', detail: '5 个杀招的配方、真元/念头消耗、效果', source: 'data/v1_battle.json → kill_moves（26 条）' },
    { name: '杀招配方与支援', detail: '配方蛊封印门禁、配方实例本回合锁定，杀招效果吃同流派支援与剑意；额外 damage 独立结算', source: 'v1_battle_resolver.gd::play_kill_move/_apply_effect' },
    { name: '真元上限与回复', detail: '真元上限 = essence_base × aptitude_factor × cultivation_factor；战斗每回合按 v1 regen_pct 向上取整回复（丙等 25%）', source: 'data/aptitude.json；v1_battle_resolver.gd::_ceil_pct' },
    { name: '战后恢复', detail: '战斗胜利后真元回满，气血恢复最大气血的 30%；不设休整节点或调息按钮', source: '本轮 L0 裁决' },
    { name: '战利品池与保底', detail: '按 tier+layer 读取材料数/权重、蛊概率/稀有度权重；common/elite/boss 材料保底与 common 蛊保底按事件序号推进', source: 'data/loot_tables.json；data/pacing.json；loot_resolver.gd::settle_victory' },
    { name: '突破链', detail: '每转四阶；小突破消耗元石或当前转数同阶舍利蛊，舍利不可越阶；巅峰冲下一转要求资质与元石同时达标', source: '本轮 L0 裁决；大突破元石成本沿用 balance；essence_capacity.gd' },
    { name: '敌人意图', detail: '意图标签与伤害，每回合公开', source: 'data/enemies.json → intent' },
    { name: '线索与反击（隐藏→揭示）', detail: '敌人自带 clues 与 reactions；揭示前不预警，揭示后可预警', source: 'v1_battle_resolver.gd:136,724-731（counter_revealed）' },
    { name: '直接攻击被反击吞掉', detail: '触发条件 trigger=direct_strike / window=before_damage；吞掉后敌方进入 bound/guarded，该反击随即不再预警', source: 'action_preview_service.gd:325-347（_live_counter_labels）' },
    { name: '刻痕回合末结算', detail: '敌方行动后，按存活敌人身上的 marked 层数结算独立伤害；不吃护盾、不衰减，层数按 mark_scratch_cap 截断', source: 'data/v1_battle.json mark_scratch_per_layer/mark_scratch_cap；v1_battle_resolver.gd::_settle_marks' },
    { name: '剑意加成与衰减', detail: '剑意上限 5，只加成剑道 strike，不吃自己的出招；回合末按 50% 向下取整衰减并跨回合保留', source: 'school_rules.gd::add_sword_intent/decay_sword_intent；v1_battle_resolver.gd::_apply_effect/end_turn' },
    { name: '基础搏斗', detail: '拳脚消耗 1 念头和 1 次行动，不耗真元；伤害 = fight_damage_base + force + yi_zhang', source: 'v1_battle_resolver.gd::basic_attack' },
    { name: '敌方封印意图', detail: 'seal 意图按 turn % 候选蛊数量确定目标，封印状态按回合倒计时解除', source: 'data/enemies.json seal_turns；v1_battle_resolver.gd::_seal_random_gu/_start_player_turn' },
    { name: '抽魂意图', detail: 'soul_drain 扣除玩家魂魄；魂魄归零立即败北，翌回合念头上限按剩余魂魄重新分档', source: 'v1_battle_resolver.gd::_resolve_enemy_intent/_check_player_death；action_points.gd::per_turn' },
    { name: '多阶段 AI（阶段 + 冷却门禁）', detail: '按 until_hp_ratio 切阶段；每阶段可有多条意图，第 T 回合发出后 T+cooldown+1 起才可再选；当前阶段所有意图都在冷却时显示 cooldown_wait、该回合不攻击', source: 'data/enemies.json 的 phases 与自带 _phases_note；本页按该语义独立实现检索台' },
    { name: '焚元意图', detail: '意图带 essence_burn 时烧掉玩家真元（蚀脉扰元 / 麻痹长嗥）', source: 'data/enemies.json phases[].intents[].essence_burn（按字段名直译，Godot 运行时不读该字段）' },
    { name: '多敌遭遇', detail: '10 个 type=combat 模板中唯一多敌 beast_swarm_pass（enemy_kinds 2 只）；规模 = enemy_kinds 长度；玩家点选目标、未选回退第一个存活；敌方按数组序逐个结算、每次立即判胜负；全灭才胜利；反击/阶段/冷却每敌一份；护体是池语义', source: 'data/nodes.json → beast_swarm_pass；battle_command_facade.gd:58-68,152-160（_v1_enemies）；v1_grammar_pipeline.gd:103-124（resolve_targets）、132-137（alive_count）；v1_battle_resolver.gd:110-135（_build_enemies）、644（_enemy_is_alive）、820-826（end_turn）、1063-1072（焚元）、1083-1088（护体池）' },
    { name: '坊市货架与蛊方服务', detail: '按层显示 4–6 件蛊/材料；同店确定性洗牌、最高档保底、流派蛊保底；购买按层价加价；仅保留蛊方解锁服务', source: 'data/shops.json → purchase/material_purchase/gu_fang_unlock；data/pacing.json → layers；shop_command_rules.gd::shop_stock/shop_slot_count/shop_layer_price/_shop_gu_fang_unlock' },
  ],
  notCovered: [
    { name: '路线选择的领域结算', why: '本原型只按节点类型分流，并在选择后推进路线；交涉、侦察、穿越等完整结算仍以 Godot 领域层为准' },
    { name: '精英代价绑定', why: 'elite 战利品表声明 backlash/notoriety cost_pool；本原型不继承恶名系统，也不伪造精英代价结算' },
    { name: 'Godot 服务型系统与动态难度', why: 'L0 裁决：除蛊方服务外，资源交换、寿元交易、以物易物、洗恶名、补魂丹、配方解锁与动态难度均不作为本原型目标；相关 Godot 实现仅保留为历史参照' },
    { name: '意图选取顺序', why: '数据未写明多意图之间的优先级（_phases_note 只定义了冷却门禁）。本页取"数据顺序中第一条可用的"，属原型设定，Godot 无实现可对照' },
    { name: '另 3 个带阶段数据的 Boss', why: 'blood_vein_bishop 之外的 clan_patriarch / blue_fur_jiangshi / miasma_vein_lord 缺少对应立绘，未纳入；其中 clan_patriarch 的「家族征召」是 damage 0 且无 essence_burn，语义未知' },
    { name: 'Boss 立绘', why: '血络主教无专属立绘，借用同流派血道蝙蝠图（enemy_bat.png），仅影响观感' },
    { name: '魂魄成长与失控', why: '本页已接魂魄行动分档、抽魂与魂魄归零死亡；魂魄收集、成长、狂暴和失控仍未实现' },
    { name: '完整事件日志与存档', why: '已接最小 run event_log 并用于炼蛊与战利品 tick；完整领域事件形状、存档与回放尚未接入' },
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
  fightDamageBase: v1.fight_damage_base, stoneRewards: balance.battle_stone_rewards,
  markScratchPerLayer: v1.mark_scratch_per_layer ?? 1,
  markScratchCap: v1.mark_scratch_cap ?? 10,
};

const cultivationCosts = {
  2: balance.cultivate_rank_two_stone_cost || 0,
  3: balance.cultivate_rank_three_stone_cost || 0,
  4: balance.cultivate_rank_four_stone_cost || 0,
  5: balance.cultivate_rank_five_stone_cost || 0,
};

const byTier = (tier) => pickedEnemies
  .filter((enemy) => enemy.tier === tier)
  .sort((a, b) => Number(a.rank || 0) - Number(b.rank || 0) || String(a.id).localeCompare(String(b.id)));
const allCommonEnemies = byTier('common');
const allEliteEnemies = byTier('elite');
const allBossEnemies = byTier('boss');
const FIXED_BOSS_BY_SEGMENT = {
  1: 'crag_serpent_matriarch',
  2: 'marrow_gu_adept',
  3: 'thunder_crown_sovereign',
  4: 'blood_vein_bishop',
  5: 'miasma_vein_lord',
};
const flowPoolsBySegment = {};
for (let segment = 1; segment <= 5; segment += 1) {
  const rankCap = Math.min(5, segment + 1);
  const withinRank = (enemy) => Number(enemy.rank || 1) <= rankCap;
  const fixedBoss = FIXED_BOSS_BY_SEGMENT[segment];
  flowPoolsBySegment[String(segment)] = {
    battle: (allCommonEnemies.filter(withinRank).length ? allCommonEnemies.filter(withinRank) : allCommonEnemies)
      .map((enemy) => enemy.id),
    elite: (allEliteEnemies.filter(withinRank).length ? allEliteEnemies.filter(withinRank) : allEliteEnemies)
      .map((enemy) => enemy.id),
    boss: allBossEnemies.some((enemy) => enemy.id === fixedBoss)
      ? [fixedBoss]
      : (allBossEnemies.filter(withinRank).length ? allBossEnemies.filter(withinRank) : allBossEnemies)
        .map((enemy) => enemy.id),
  };
}
const supportGuBySegment = {};
for (let segment = 1; segment <= 5; segment += 1) {
  const rankCap = Math.min(5, segment + 1);
  supportGuBySegment[String(segment)] = gu
    .filter((entry) => entry.role === 'support' && Number(entry.rank || 1) <= rankCap && entry.id !== 'aptitude_gu')
    .map((entry) => entry.id);
  if (segment >= 2) supportGuBySegment[String(segment)].push('aptitude_gu');
}

const flow = {
  difficulties: {
    easy: { label: '简单', prepPerSegment: 15 },
    normal: { label: '普通', prepPerSegment: 10 },
    hard: { label: '困难', prepPerSegment: 5 },
  },
  stageLabels: ['初阶', '中阶', '高阶', '巅峰'],
  segmentTitles: {
    1: '青茅山外围',
    2: '落瘴岭',
    3: '血蟒涧',
    4: '万蛊窟',
    5: '瘴脉深处',
  },
  poolsBySegment: flowPoolsBySegment,
  supportGuBySegment,
  supportGuIds: [...SUPPORT_GU_IDS],
  aptitudeGuId: 'aptitude_gu',
  smallBreakthroughCosts: {
    1: [2, 3, 4],
    2: [4, 6, 8],
    3: [8, 12, 16],
    4: [12, 18, 24],
    5: [20, 30, 40],
  },
  bigStoneCosts: cultivationCosts,
  aptitudeOrder: ['ding', 'bing', 'yi', 'jia'],
  aptitudeGateByTargetRank: { 2: 'bing', 3: 'yi', 4: 'yi', 5: 'jia' },
  sariByRank: {
    2: 'gold_atk_2_11_gu',
    3: 'gold_atk_3_13_gu',
    4: 'gold_atk_4_14_gu',
    5: 'gold_atk_5_15_gu',
  },
  rewardGuChoiceCount: 3,
  postBattleHealPct: 30,
};

const out = {
  runSeed: firstRun.seed || 1,
  aptitude,
  cultivationCosts,
  flow,
  loot: {
    tables: Object.fromEntries(
      Object.entries(lootTables.loot || {}).map(([tier, table]) => {
        const clean = { ...table };
        delete clean.cost_pool;
        if (tier === 'elite') clean.gu_chance_pct = Math.max(Number(clean.gu_chance_pct || 0), 35);
        if (tier === 'boss') clean.gu_chance_pct = Math.max(Number(clean.gu_chance_pct || 0), 55);
        return [tier, clean];
      }),
    ),
    pity: lootTables.pity || {},
    pacingLayers: pacing.layers || {},
    schoolMaterialResonance: lootTables.school_material_resonance || 1,
    schoolPools: { [labSchool]: schoolPools[labSchool] || [] },
    materialPityTargetsByTier,
    school: labSchool,
  },
  gu, recipes: picked, killMoves, enemies: pickedEnemies, encounters,
  nodes, route, shopOffers, materials, npcs, events,
  actions: names.actions || {}, nodeTypes: names.types || {}, battle, mechanisms,
};
const banner = '// 本文件由 tools/build_data.mjs 从 Godot 侧数据表生成，不要手改。\n'
  + '// 用普通脚本（非 ES module）产出，这样 file:// 双击打开也能跑，不必起本地服务。\n';
fs.writeFileSync(path.join(here, '..', 'js', 'data.js'),
  banner + 'const DATA = ' + JSON.stringify(out, null, 2) + ';\n');
console.log('gu', gu.length, '| recipes', picked.length, '| killMoves', killMoves.length,
  '| enemies', pickedEnemies.length, '| nodes', nodes.length, '| route', route.length,
  '| shopOffers', shopOffers.length);
if (drift.length) console.log('数据/规则漂移（' + drift.length + '）：\n  - ' + drift.join('\n  - '));
