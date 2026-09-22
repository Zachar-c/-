// 从 Godot 侧真实数据表抽取原型子集，产出 js/data.js。
// 运行：node tools/build_data.mjs   （在 game/wenzhen-web-lab/ 下）
// 为什么需要它：原型必须跑在真实数据上，否则"Web vs Godot"的质量对比不成立。
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
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
// 舍利系列的转数按**原著定位**建，不读 gu 自己的 rank 字段。
// 主依据 `蛊真人-clean.txt:86506` 一句话列全系列：「从一转到五转，分别有青铜、
// 赤铁、白银、黄金、紫晶舍利蛊」；同一点另由 18066（青铜/赤铁/白银）与
// 18068（黄金到四转）复述。
//
// 为什么不能读 rank：金色进阶链（`refinement_recipes.json` 的 promote_gold_*）
// 是 1→5 的严格阶梯，第 2 级正是 `gold_atk_2_12_gu`（青铜舍利蛊），
// `tests/unit/test_promotion_1b1a.gd` 断言每一级 rank 恰好 +1。把它的 rank
// 改成 1 会打断那条链与测试；所以 lab 按名字定转数，Godot 数据不动。
const SARI_BY_RANK = {
  1: 'gold_atk_2_12_gu',
  2: 'gold_atk_2_11_gu',
  3: 'gold_atk_3_13_gu',
  4: 'gold_atk_4_14_gu',
  5: 'gold_atk_5_15_gu',
};
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

// 配方：取同时涉及所选蛊、且是二转产出的固定配方。
// L0 2026-09-25 Phase 0：升炼自环（投入=产出）与无真实语义的 advance 不进 live 可见路径。
// 必须过滤掉没有输入蛊的条目：那种配方在原型里会变成"无材料免费开炉"。
const fixed = recipes.filter((r) =>
  r.kind === 'fixed' && r.output_gu_id && baseGuIds.includes(r.output_gu_id) &&
  (r.input_gu_ids || []).length > 0 &&
  r.input_gu_ids.every((i) => baseGuIds.includes(i)));
const advances = recipes.filter((r) => {
  if (r.kind !== 'advance' || r.retired || !baseGuIds.includes(r.output_gu_id)) return false;
  const inputs = r.input_gu_ids || [];
  if (!inputs.length) return false;
  if (inputs.length === 1 && inputs[0] === r.output_gu_id) return false;
  if ([...new Set(inputs)].length === 1 && inputs[0] === r.output_gu_id) return false;
  return true;
}).slice(0, 2);
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
    // L0 Phase 1：三个敌人问题轴（信息反制 / 重甲 / 闪避）
    problemAxis: e.problemAxis || null,
    problemLabel: e.problemLabel || null,
    armorValue: e.armorValue ?? null,
    evasionBreakpoint: e.evasionBreakpoint ?? null,
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
// L0 2026-09-25 Phase 0：古方（gu_fang_unlock）只记账无机械收益，未接通前不得作为正式可购成长项。
const SHOP_OFFER_KINDS = new Set(['purchase', 'material_purchase']);
const supportShopOffers = [
  { id: 'lab_shop_aptitude_gu', kind: 'purchase', gu_id: 'aptitude_gu', tier: 1, stone_cost: 20 },
  ...Object.entries(SARI_BY_RANK)
    .map(([rank, guId]) => {
      const entity = battleGuById[guId] || {};
      return {
        id: `lab_shop_${guId}`,
        kind: 'purchase',
        gu_id: guId,
        // 档位取原著转数：青铜舍利蛊是一转蛊，必须在一转区域就买得到
        // （shop_rules 按 offer.tier <= 该层 shop_max_tier 上架）。
        tier: Number(rank),
        stone_cost: Math.max(5, Number(entity.value || 5) * 2),
      };
    }),
];
const shopOffers = [...shopOffersRaw, ...supportShopOffers]
  .filter((o) => SHOP_OFFER_KINDS.has(String(o.kind || '')))
  .filter((o) => !o.retired && o.mechanical !== false)
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
    { name: '突破链', detail: '每转四阶；小突破消耗元石或当前转数同阶舍利蛊，舍利不可越阶；巅峰冲下一转要求资质与元石同时达标。舍利系列按原著定位建转数：一转青铜 / 二转赤铁 / 三转白银 / 四转黄金 / 五转紫晶', source: '本轮 L0 裁决；舍利转数依据 `蛊真人-clean.txt:86506`「从一转到五转，分别有青铜、赤铁、白银、黄金、紫晶舍利蛊」（另见 `:18066` `:18068`）；大突破元石成本沿用 balance；essence_capacity.gd' },
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
    { name: '坊市货架', detail: '按层显示 4–6 件蛊/材料；同店确定性洗牌、最高档保底、流派蛊保底；购买按层价加价。古方（gu_fang_unlock）因无机械收益已移出 live 货架（L0 2026-09-25 Phase 0）', source: 'data/shops.json → purchase/material_purchase；data/pacing.json → layers；shop_command_rules.gd::shop_stock/shop_slot_count/shop_layer_price' },
    { name: '险地节点（探查 / 穿越 / 退回）', detail: '固定图每层 3 个候选中确定性地换入 1 个险地节点（毒瘴山道 / 积水石窟 / 黑泥沼地；槽位与模板都由 seed 决定，同 seed 同难度同图）；探查与退回只记事实（route_scouted / withdrawn_safely），穿越消耗 1 点真元、真元不足则拒绝且不结算；解析后回统一整备，不做 on_skip 后果', source: 'data/nodes.json → toxic_mountain_path / flooded_cave / black_mud_marsh（choices 均为 scout/cross/withdraw）；social_command_rules.gd:768-771,801-803（标准行动转移）；action_preview_service.gd:1022-1028,1076-1077,1085-1087（预览门禁与文案）；display_text.gd:69,86,90（显示名）、228,238,242（行动结果文案）' },
    { name: '非战斗节点的标准动作结算（险地 / 市集 / 野蛊）', detail: '固定图每层 3 个候选中确定性地换入 1 个非战斗节点，模板池 = 险地 3 + 市集 2 + 野蛊 1 + 休整 2 + 静修 1 共 9 个模板（槽位与模板都由 seed 决定，同 seed 同难度同图）；节点动作页按模板 choices 出标准动作卡（choices 里未搬的动作不出卡），并按 Godot 口径总是补一张 leave 卡（离开遭遇）。已接入：work（元石 +3）/ harvest（元石 +2）/ buy_information 与 trade（门禁元石 ≥ 2，不足则拒绝且不结算；成功扣 2 并记事实 bought_information / bought_service）/ leave（记 route_left_behind）/ scout / cross（门禁真元 ≥ 1，成功扣 1）/ withdraw（静修节点的 meditate 见下条）；被拒不结算，解析后进入统一整备', source: 'data/nodes.json → village_short_work / ridge_market / blood_moss_grove / rest_hollow / rest_shrine / body_imprint_ritual 与三个险地模板；social_command_rules.gd:747-803（转移；_resource_transition:814-821 的 before/after 语义、_spend_stone_for_fact:823-831、_fact_transition:881-887）；action_preview_service.gd:44-45,992-995,1022-1035,1043-1044,1114-1115,1119,1198-1208,1306-1309（卡片、门禁、文案与 remedy）；display_text.gd:226,230,232,238,241-243（行动结果）、503-505（被拒兜底）；data/names.json → types / actions 分区（节点与动作中文名）' },
    { name: '恢复类节点（休整 / 静修）', detail: '非战斗模板池加入休整（山壁石穴 / 古祠残龛）与静修（体印仪式）后，地图上第一次出现恢复气血与真元的途径。休整节点（type=rest）是一次收益门禁、两步交互：先取「歇脚恢复」（气血恢复 max(1, floor(上限×0.30))、真元 +2，均按各自上限截断；卡片显示按当前数值算出的真实恢复量），「离开休整」卡此时才解禁——未取收益时该卡禁用并显示门禁原文「休整抉择未定：须先选择恢复、强化或移除其一，才能离开。」；探访已消费后收益卡禁用（「本次休整已处置完毕。」），重复取收益被拒（rest_already_used）且状态不变，未取收益就想离开被拒（rest_choice_required）且状态不变。静修节点（type=seclusion）走标准动作：「静修」真元 +1（按真元上限截断），离开没有休整门禁（seclusion 不在 rest-class 名单内）', source: 'data/nodes.json → rest_hollow / rest_shrine / body_imprint_ritual；rest_rules.gd:22（REST_NODE_TYPE）、:27（REST_CLASS_TYPES，seclusion 不在其中）、:121-141（_rest_heal：气血/真元公式与 rest_recovered、<节点id>_used 标记）、:165-179（_consume_rest_visit 的旗标语义，本片未搬）；social_command_rules.gd:586-589 与 encounter_session_resolver.gd:121-126（未消费不许离开 → rest_choice_required）；action_preview_service.gd:746-808（node.rest_heal / node.leave 两张卡与文案）、:811-831（已消费卡禁用的 block_reason）；social_command_rules.gd:772-773（meditate 真元 +1）与 display_text.gd:76,234（静修显示名与结果文案）' },
  ],
  notCovered: [
    { name: '追击压力类动作（deceive / retreat）', why: '效果落在 state.pursuit（social_command_rules.gd:774-777）；本原型没有追击压力槽，搬进来就是「声明了但没人读」的字段，按登记不实现' },
    { name: '升仙条件类动作（open / prepare / scheme）', why: '效果落在 state.ascension 的升仙五项（social_command_rules.gd:778-783）；本原型没有升仙窗口与终局资格判定，登记不实现' },
    { name: '体印动作（take_imprint）', why: '效果写入 body_imprints（social_command_rules.gd:784-794 的铁骨体印）；本原型没有体印系统，登记不实现。静修节点（体印仪式）的 choices 里有这条，但节点动作页不出这张卡——搬进来只会是禁用空按钮' },
    { name: '只有单张蛊卡的强化、免费移除、印记与反噬（休整节点的另四种收益）', why: '休整节点在 Godot 还有强化一张蛊卡（action_preview_service.gd:759-768）、移除一只蛊（:769-778）、抹除一枚印记（:779-788）、拔除一层反噬（:789-798）四个选项；本原型没有蛊卡强化、没有免费移除（蛊仓只有卖蛊返 50%）、没有印记/遗物、没有诅咒系统，搬进来就是空按钮，按登记不实现' },
    { name: '休整跳过模式（rest mode=skip）', why: 'rest_rules.gd:89-103 的 _rest_skip 只在领域层可达（消费探访并落 rest_skipped），Godot 侧的休整卡集合（action_preview_service.gd:746-808）没有它的入口，故本片不搬；休整节点因此必须至少取一次收益才能离开' },
    { name: '文案与实现漂移：休整收益卡的「恢复 2 点」', why: '数据/表现漂移（登记，不修 Godot）：action_preview_service.gd:756 的 node.rest_heal 卡写死 expected_gain「恢复气血 2 点。/恢复真元 2 点。」，而 rest_rules.gd:129-131 的实际效果是「气血 +max(1, floor(上限×0.30))、真元 +2」。本页按真实数值显示（例：上限 24 点时恢复 7 点）' },
    { name: '数据缺口：data/names.json → types 缺 rest 键', why: 'data/names.json 的 types 分区有 seclusion（静修）但没有 rest，而 Godot 侧的 scripts/presentation/display_text.gd:54 的 const TYPES 里 rest 是「休整」。本页类型名取 DATA.nodeTypes 优先、缺失时回退「休整」（来源 display_text.gd:54），回退表在 js/node_action_rules.js' },
    { name: '只记事实、无消费点的动作（accept / ally / claim / inspect / lure 与 contact / caravan 专属动作）', why: '这些动作只写 known_facts（social_command_rules.gd:795-800），而本原型对已知事实没有任何分支消费（见下面 knownFacts 一条）；contact 的 negotiate/deceive/retreat/fight 与 caravan 的 probe/buy/sell/exchange 还各自需要专属结算模块，一并登记不实现' },
    { name: '炼蛊 / 修行节点的休息类门禁（rest-class 剩余部分）', why: 'rest_rules.gd:27 的 REST_CLASS_TYPES = [rest, refinement, cultivation]：rest 的那一份门禁已在本片搬入（见 covered 的恢复类节点），refinement / cultivation 两类节点本原型仍未接入（连节点带动作），其一次性门禁与 refine / cultivate 专属动作一并不搬' },
    { name: '其余节点类型的专属结算', why: 'contact / caravan / event / refinement / cultivation / ledger / inheritance / commission / pursuit / earth_vein 等类型各有专属选项与命令面（商队、炼蛊、修行、总账、遗葬传承等），本原型固定图只放战斗与五类非战斗模板（险地 / 市集 / 野蛊 / 休整 / 静修），其余类型未接入' },
    { name: '非战斗槽位的类型分布进一步稀释', why: '非战斗槽位仍是每层 1 个（槽位 seed 未变），但模板池由 6 个扩到 9 个后，各类型出现频率被进一步稀释（本片首局 seed 101 / normal 实测：险地 12 / 市集 11 / 野蛊 8 / 休整 12 / 静修 7，slice-10 时是险地 31 / 市集 12 / 野蛊 7）。这是 slice-10 已登记、待 L1 裁的同一件事的延续，不是本片新增裁决项' },
    { name: 'knownFacts 只写不读', why: '本片与 slice-09 引入的 state.knownFacts 至今只被写入（scout / withdraw / leave / buy_information / trade），没有任何分支消费它；读取点只有 node_action_rules 的透传与 main.js 的事件日志。照实登记：这是「声明了但没人读」的状态槽，不要以为它已经在驱动玩法' },
    { name: '精英代价绑定', why: 'elite 战利品表声明 backlash/notoriety cost_pool；本原型不继承恶名系统，也不伪造精英代价结算' },
    { name: 'Godot 服务型系统与动态难度', why: 'L0 裁决：除蛊方服务外，资源交换、寿元交易、以物易物、洗恶名、补魂丹、配方解锁与动态难度均不作为本原型目标；相关 Godot 实现仅保留为历史参照' },
    { name: '意图选取顺序', why: '数据未写明多意图之间的优先级（_phases_note 只定义了冷却门禁）。本页取"数据顺序中第一条可用的"，属原型设定，Godot 无实现可对照' },
    { name: '另 3 个带阶段数据的 Boss', why: 'blood_vein_bishop 之外的 clan_patriarch / blue_fur_jiangshi / miasma_vein_lord 缺少对应立绘，未纳入；其中 clan_patriarch 的「家族征召」是 damage 0 且无 essence_burn，语义未知' },
    { name: 'Boss 立绘', why: '血络主教无专属立绘，借用同流派血道蝙蝠图（enemy_bat.png），仅影响观感' },
    { name: '魂魄成长与失控', why: '本页已接魂魄行动分档、抽魂与魂魄归零死亡；魂魄收集、成长、狂暴和失控仍未实现' },
    { name: '完整事件日志与存档', why: '已接最小 run event_log 并用于炼蛊与战利品 tick；完整领域事件形状、存档与回放尚未接入' },
    { name: 'counter_status="sparked"（雷冠头狼）', why: '数据漂移：data/enemies.json 声明了该反击状态，但 scripts/ 与 docs/ 里零命中，规则层无实现语义。本页不臆造，已从反击列表剔除' },
    { name: '险地节点的 on_skip', why: '数据漂移：data/nodes.json 的险地模板声明了 on_skip（lose_route / lose_clue / gain_pursuit），但 scripts/ 里零命中，Godot 域层没有实现该字段。本页不臆造跳过后果，险地只结算 choices 里的三条 standard action。休整/静修模板也带 on_skip（rest 为 none；体印仪式为 lose_foundation），本页同样不结算——休整节点没有跳过入口（见上一条），静修节点也没有' },
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
  sariByRank: SARI_BY_RANK,
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
  /* Rank 主链：WORLD 真源快照（Integration 刀1）。Lab 投影只准读这里。 */
  worldBalance: {
    rank_step_ratio: balance.rank_step_ratio,
    standard_hit_ratio: balance.standard_hit_ratio,
    human_base_health: balance.human_base_health,
    standard_human_hp: balance.standard_human_hp,
    player_start_hp: balance.player_start_hp,
    thought_base_capacity: balance.thought_base_capacity,
    stone_to_essence_per_stone: balance.stone_to_essence_per_stone,
    rank_power_budget: balance.rank_power_budget,
  },
  actions: names.actions || {}, nodeTypes: names.types || {}, battle, mechanisms,
};
// contentVersion = sha256(JSON.stringify(out)) 在写入 contentVersion 字段之前。
// 存档信封用它做内容兼容门禁；改状态结构时必须提升 LabSave.schemaVersion。
const contentVersion = createHash('sha256').update(JSON.stringify(out)).digest('hex');
out.contentVersion = contentVersion;
const banner = '// 本文件由 tools/build_data.mjs 从 Godot 侧数据表生成，不要手改。\n'
  + '// 用普通脚本（非 ES module）产出，这样 file:// 双击打开也能跑，不必起本地服务。\n';
fs.writeFileSync(path.join(here, '..', 'js', 'data.js'),
  banner + 'const DATA = ' + JSON.stringify(out, null, 2) + ';\n');
console.log('gu', gu.length, '| recipes', picked.length, '| killMoves', killMoves.length,
  '| enemies', pickedEnemies.length, '| nodes', nodes.length, '| route', route.length,
  '| shopOffers', shopOffers.length, '| contentVersion', contentVersion);
if (drift.length) console.log('数据/规则漂移（' + drift.length + '）：\n  - ' + drift.join('\n  - '));
