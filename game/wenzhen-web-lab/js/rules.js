// 规则层：从 Godot 数据与规则文件直译的判定，表现层只读这里的结果，不自己算。
//
// 两类来源：
//   1) 反击预警：scripts/domain/action_preview_service.gd `_live_counter_labels`（§16.5）
//   2) 多阶段 AI：data/enemies.json 的 phases + 数据自带 _phases_note
//      —— Godot 运行时尚未实现（只在 enemy_catalog.gd 里做 schema 校验），本页是首个实现，
//         语义严格照抄 _phases_note，未写明的部分（选招顺序）在下面标注为原型设定。

// ---------- 反击 ----------

// 直接攻击口径（原型设定）：效果类型为 strike 的杀招。
// Godot 侧只对"基本拳脚 / 荆棘鞭击"这类路径做反击检查；本页以 strike 近似。
function isDirectStrike(move) {
  return (move.effect || {}).kind === 'strike';
}

const statusZh = (s) => ({ bound: '受制', guarded: '戒备' }[s] || s || '—');

// 一条反击当前是否生效（会吞掉直接攻击）。
// 与 Godot 一致：trigger=direct_strike、window=before_damage；
// 敌方已处于该状态时该反击不再生效（bound → enemy_bound，guarded → guarded）。
function reactionLive(battle, r) {
  if (!battle.revealed) return false;
  if (r.trigger !== 'direct_strike' || r.window !== 'before_damage') return false;
  if (r.counter_status === 'bound' && battle.flags.enemy_bound) return false;
  if (r.counter_status === 'guarded' && battle.flags.guarded) return false;
  return true;
}

function reactionSettled(battle, r) {
  return (r.counter_status === 'bound' && !!battle.flags.enemy_bound)
    || (r.counter_status === 'guarded' && !!battle.flags.guarded);
}

const hpRatio = (enemy) => (enemy.hpMax ? Math.max(0, enemy.hp) / enemy.hpMax : 1);

// 当前生效中的反击：取当前阶段的反击表（有 phases 的敌人在各阶段可给不同反击）
function liveReactions(battle) {
  return phaseView(battle.enemy).reactions.filter((r) => reactionLive(battle, r));
}

// ---------- 多阶段 AI ----------

// 当前阶段 = 数据顺序中"最后一个 until_hp_ratio ≥ 当前血量比"的阶段
// （_phases_note：阈值按数据顺序严格递减）。
function activePhase(enemy) {
  const phases = enemy.phases;
  if (!phases || !phases.length) return null;
  const ratio = hpRatio(enemy);
  let index = 0;
  for (let i = 0; i < phases.length; i++) if (phases[i].until_hp_ratio >= ratio) index = i;
  return { index, total: phases.length, until: phases[index].until_hp_ratio, data: phases[index] };
}

// 本回合可用的意图集合与反击集合：有 phases 走阶段表，否则回落到顶层单条 intent/reactions。
function phaseView(enemy) {
  const ap = activePhase(enemy);
  if (ap) return { phase: ap, intents: ap.data.intents || [], reactions: ap.data.reactions || [] };
  return { phase: null, intents: enemy.intent ? [enemy.intent] : [], reactions: enemy.reactions || [] };
}

// 意图是否已冷却完毕：第 T 回合发出，下一次最早 T + cooldown + 1（_phases_note 原文）。
function intentReady(lastFiredTurn, cooldown, turn) {
  if (lastFiredTurn === null || lastFiredTurn === undefined) return true;
  return turn >= lastFiredTurn + (cooldown || 0) + 1;
}

// 选取本回合意图：阶段内按数据顺序取第一条已冷却的；
// 全部在冷却 → null，即 cooldown_wait（该回合不攻击）。
// 【原型设定】数据未写明多意图之间的优先级，本页取数据顺序；Godot 无实现可对照。
function selectIntent(intents, lastFired, turn) {
  for (const it of intents) if (intentReady(lastFired[it.id], it.cooldown, turn)) return it;
  return null;
}

// 意图文案：伤害 / 焚元 / 攻击
function intentText(it) {
  if (!it) return '冷却中 · 本回合不攻击';
  const parts = [];
  if (it.damage) parts.push(`伤 ${it.damage}`);
  if (it.essence_burn) parts.push(`焚元 ${it.essence_burn}`);
  return `${it.label}（${parts.join(' · ') || '无直接伤害'}）`;
}
