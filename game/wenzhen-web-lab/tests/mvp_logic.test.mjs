import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const context = vm.createContext({});
const load = (relativePath) => vm.runInContext(
  fs.readFileSync(new URL(relativePath, import.meta.url), 'utf8'),
  context,
  { filename: relativePath },
);

load('../js/balance.js');
load('../js/mvp_content.js');
load('../js/mvp_logic.js');
load('../js/data.js');
vm.runInContext('globalThis.__DATA = DATA;', context);

const content = context.MVP_CONTENT;
const logic = context.MvpLogic;
const data = context.__DATA;

test('run starts with persistent 24 hp and 12 essence', () => {
  const run = logic.createRun(content);
  assert.equal(run.hp, 24);
  assert.equal(run.qi, 12);
  assert.equal(run.qiMax, 12);
  assert.equal(run.stones, 3);
  assert.equal(run.owned.small_light_gu, 1);
});

test('stones can be smelted into essence outside battle', () => {
  const run = logic.createRun(content);
  run.qi = 8;
  const result = logic.smeltStone(run);
  assert.equal(result.ok, true);
  assert.equal(result.run.stones, 2);
  assert.equal(result.run.qi, 10);
});

test('secure trade spends future essence and adds two small light gu', () => {
  const result = logic.applyTrade(logic.createRun(content), 'secure', content);
  assert.equal(result.ok, true);
  assert.equal(result.run.stones, 0);
  assert.equal(result.run.owned.small_light_gu, 3);
});

test('sacrifice trade removes stone shell and grants boar plus stones', () => {
  const result = logic.applyTrade(logic.createRun(content), 'sacrifice', content);
  assert.equal(result.ok, true);
  assert.equal(result.run.owned.stone_shell_gu, undefined);
  assert.equal(result.run.owned.white_boar_strength_gu, 1);
  assert.equal(result.run.stones, 7);
});

test('debt trade permanently lowers essence cap to eight', () => {
  const result = logic.applyTrade(logic.createRun(content), 'debt', content);
  assert.equal(result.ok, true);
  assert.equal(result.run.owned.moon_glow_gu, 1);
  assert.equal(result.run.qiMax, 8);
  assert.equal(result.run.qi, 8);
  assert.equal(result.run.borrowedMoon, true);
});

test('forge consumes moon, small light and two essence to create moon glow', () => {
  // 月芒 rank2：须二转（或借月例外）方可炼成持有
  const base = logic.createRun(content);
  const blocked = logic.applyForge(base, 'forge', { ...content, forge: { ...content.forge, allowOverRank: false } });
  assert.equal(blocked.ok, false);
  assert.equal(blocked.reason, 'insufficient_rank');
  assert.equal(blocked.needRank, 2);

  const over = logic.applyForge(base, 'forge', { ...content, forge: { ...content.forge, allowOverRank: true, outputRank: 2 } });
  assert.equal(over.ok, true);
  assert.equal(over.run.owned.moonlight_gu, undefined);
  assert.equal(over.run.owned.small_light_gu, undefined);
  assert.equal(over.run.owned.moon_glow_gu, 1);
  assert.equal(over.run.qi, 10);
});

test('rank gate: one-turn cannot use rank-2 moon glow without borrow exception', () => {
  const run = logic.createRun(content);
  assert.equal(run.playerRank, 1);
  const gate = logic.canUseGu(run, 'moon_glow_gu', content);
  assert.equal(gate.ok, false);
  assert.equal(gate.reason, 'insufficient_qi_quality');
  const borrowed = { ...run, lowRankGu: { moon_glow_gu: true } };
  assert.equal(logic.canUseGu(borrowed, 'moon_glow_gu', content).ok, true);
});

test('forging after borrowing moon repays the cap debt instead of duplicating it', () => {
  const borrowed = logic.applyTrade(logic.createRun(content), 'debt', content).run;
  const result = logic.applyForge(borrowed, 'forge', content);
  assert.equal(result.ok, true);
  assert.equal(result.run.owned.moon_glow_gu, 1);
  assert.equal(result.run.qiMax, 12);
  assert.equal(result.run.borrowedMoon, false);
  assert.equal(result.run.forgeChoice, 'repay');
});

test('preserve keeps ingredients and grants three stones', () => {
  const result = logic.applyForge(logic.createRun(content), 'preserve', content);
  assert.equal(result.ok, true);
  assert.equal(result.run.owned.moonlight_gu, 1);
  assert.equal(result.run.stones, 6);
});

test('hound exposes a hidden counter and observation reveals it', () => {
  const enemy = logic.createEnemy(content, 'ridge_hound');
  const started = logic.startTurn(content, enemy, 1, 101).enemy;
  assert.ok(['intercept', 'draw_light'].includes(started.currentCounter));
  assert.equal(started.revealed, false);
  const revealed = logic.revealCounter(started);
  assert.equal(revealed.revealed, true);
  assert.ok(logic.counterRule(content, revealed.currentCounter).detail);
});

test('intercept keeps swallowing every direct attack in the round', () => {
  const enemy = logic.createEnemy(content, 'ridge_hound');
  enemy.currentCounter = 'intercept';
  const first = logic.resolveDirectStrike(enemy, { damage: 4 });
  const second = logic.resolveDirectStrike(first.enemy, { damage: 4 });
  assert.equal(first.swallowed, true);
  assert.equal(second.swallowed, true);
  assert.equal(second.selfDamage, 2);
  assert.equal(second.enemy.hp, logic.profileFor(content, 'ridge_hound').hp, '吞刀不掉血');
});

test('iron keeps swallowing attacks and increases the next charge', () => {
  const enemy = logic.createEnemy(content, 'iron_hide_boar');
  enemy.currentCounter = 'iron';
  const first = logic.resolveDirectStrike(enemy, { damage: 5 });
  const second = logic.resolveDirectStrike(first.enemy, { damage: 5 });
  assert.equal(second.swallowed, true);
  assert.equal(second.enemy.ironRage, 2);
  assert.equal(second.enemy.hp, logic.profileFor(content, 'iron_hide_boar').hp);
});

test('draw light adds three damage when no light gu was used', () => {
  const enemy = logic.createEnemy(content, 'ridge_hound');
  enemy.currentCounter = 'draw_light';
  const failed = logic.resolveEnemyAction(enemy, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 4 },
    usedLight: false,
  });
  const passed = logic.resolveEnemyAction(enemy, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 4 },
    usedLight: true,
  });
  assert.equal(failed.damage, 7);
  assert.equal(passed.damage, 4);
});

test('stone shell breaks the next charge counter', () => {
  const enemy = logic.createEnemy(content, 'iron_hide_boar');
  enemy.currentCounter = 'iron';
  const result = logic.resolveEnemyAction(enemy, { hp: 24, qi: 12, block: 5 }, {
    intent: { damage: 5, tag: 'charge' },
    stoneShellUsed: true,
  });
  assert.equal(result.enemy.counterBroken, true);
});

test('moon glow suppression bypasses the counter and lowers enemy damage by three', () => {
  const enemy = logic.createEnemy(content, 'ridge_hound');
  const maxHp = logic.profileFor(content, 'ridge_hound').hp;
  enemy.currentCounter = 'intercept';
  enemy.revealed = true;
  const hit = logic.resolveDirectStrike(enemy, {
    damage: 4,
    bypassCounter: true,
    suppressCounter: true,
  });
  assert.equal(hit.swallowed, false);
  assert.equal(hit.enemy.hp, maxHp - 4);
  const resolved = logic.resolveEnemyAction(hit.enemy, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 4 },
  });
  assert.equal(resolved.damage, 1);
});

test('seal target follows first or last action order', () => {
  assert.equal(logic.sealTarget('seal_first', ['moonlight_gu', 'stone_shell_gu']), 'moonlight_gu');
  assert.equal(logic.sealTarget('seal_last', ['moonlight_gu', 'stone_shell_gu']), 'stone_shell_gu');
});

test('boss phase changes at phaseAt hp and burns three essence', () => {
  const phaseAt = logic.profileFor(content, 'thunder_crown_sovereign').phaseAt;
  const enemy = logic.createEnemy(content, 'thunder_crown_sovereign');
  enemy.hp = phaseAt;
  const started = logic.startTurn(content, enemy, 2, 101).enemy;
  assert.equal(logic.phaseIndexFor(content, started), 1);
  const result = logic.resolveEnemyAction(started, { hp: 24, qi: 9, block: 0 }, {
    intent: { kind: 'burn_qi', burnQi: 3, damage: 0 },
  });
  assert.equal(result.player.qi, 6);
});

test('battle reward uses the real tier table', () => {
  assert.equal(logic.battleReward(data, 'ridge_hound'), 3);
  assert.equal(logic.battleReward(data, 'ridge_elite_scout'), 8);
  assert.equal(logic.battleReward(data, 'thunder_crown_sovereign'), 15);
});

test('light support is applied before the support charge is spent', () => {
  const values = logic.actionValues(content.actions.moonlight_gu, 1);
  assert.equal(values.qi, 0);
  assert.equal(values.damage, 3);
});

test('battle screen exposes both known and unknown intelligence', () => {
  const source = fs.readFileSync(new URL('../js/mvp.js', import.meta.url), 'utf8');
  assert.match(source, /<dt>已知弱点<\/dt>\s*<dd>\$\{esc\(intel\.known\)\}<\/dd>/);
  assert.match(source, /<dt>未察信息<\/dt>\s*<dd>\$\{esc\(intel\.unknown\)\}<\/dd>/);
});

/* ------------------------------------------------------------------
   V4（2026-09-21 L1 裁决）
   1. 反制第一次观察后，本场永久识别（不再每回合重新隐藏）
   2. 正确处理当前反制 → 本次敌方伤害 -3 并取消意图附带的特殊效果，下限 0
   3. 普通战胜利 → +2 气血 / +2 真元
   ------------------------------------------------------------------ */

test('a counter type stays identified for the rest of the battle after one observation', () => {
  // 山猪 V4.1 起 iron_gate 按回合取槽：T1/T4 有 iron，不是每回合都有。
  // 「永久识别」在真正再次出现该反制时生效（learned 也算读对）。
  let enemy = logic.createEnemy(content, 'iron_hide_boar');
  enemy = logic.startTurn(content, enemy, 1, 101).enemy;
  assert.equal(enemy.currentCounter, 'iron');
  assert.equal(enemy.revealed, false, '第一次遇到仍未识破');

  enemy = logic.revealCounter(enemy);
  // vm 里的数组来自另一个 realm，deepStrictEqual 会因原型不同而失败，先转成本 realm 的数组
  assert.deepEqual(Array.from(enemy.knownCounters), ['iron']);

  enemy = logic.finishEnemyAction(enemy);
  enemy = logic.startTurn(content, enemy, 4, 101).enemy;   // 第 4 回合再次 iron
  assert.equal(enemy.currentCounter, 'iron');
  assert.equal(enemy.revealed, true, '同一反制类型本场永久识别，不再收第二次念头税');
});

test('an unidentified counter grants no mitigation even when the action happens to match', () => {
  const enemy = logic.createEnemy(content, 'ridge_hound');
  enemy.currentCounter = 'intercept';
  enemy.revealed = false;
  const resolved = logic.resolveEnemyAction(enemy, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 4, tag: 'charge' },
    attacked: false,
  });
  assert.equal(resolved.handled, false);
  assert.equal(resolved.damage, 4, '没读信息就不该白拿减伤');
});

test('handling an identified counter cuts the enemy action by three', () => {
  const hound = logic.createEnemy(content, 'ridge_hound');
  hound.currentCounter = 'intercept';
  hound.revealed = true;

  const withheld = logic.resolveEnemyAction(hound, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 4, tag: 'charge' },
    attacked: false,
  });
  assert.equal(withheld.handled, true);
  assert.equal(withheld.damage, 1, '读对 + 做对：4 → 1');

  const greedy = logic.resolveEnemyAction(hound, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 4, tag: 'charge' },
    attacked: true,
  });
  assert.equal(greedy.handled, false);
  assert.equal(greedy.damage, 4, '读对但硬打：照样吃满');
});

test('handling an identified draw-light counter removes the bonus and then cuts three', () => {
  const enemy = logic.createEnemy(content, 'ridge_hound');
  enemy.currentCounter = 'draw_light';
  enemy.revealed = true;

  const ok = logic.resolveEnemyAction(enemy, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 4, tag: 'charge' },
    usedLight: true,
  });
  assert.equal(ok.damage, 1);

  const bad = logic.resolveEnemyAction(enemy, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 4, tag: 'charge' },
    usedLight: false,
  });
  assert.equal(bad.damage, 7, '未处理：4 + 3');
});

test('mitigation never drives the enemy action below zero', () => {
  const enemy = logic.createEnemy(content, 'ridge_hound');
  enemy.currentCounter = 'intercept';
  enemy.revealed = true;
  const resolved = logic.resolveEnemyAction(enemy, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 2, tag: 'charge' },
    attacked: false,
  });
  assert.equal(resolved.damage, 0);
});

test('handling a seal counter cancels the seal special effect', () => {
  const enemy = logic.createEnemy(content, 'ridge_elite_scout');
  enemy.currentCounter = 'seal_first';
  enemy.revealed = true;

  const handled = logic.resolveEnemyAction(enemy, { hp: 24, qi: 12, block: 0 }, {
    intent: { kind: 'seal', damage: 0 },
    guUsedCount: 0,
  });
  assert.equal(handled.handled, true);
  assert.equal(handled.specialCancelled, true);

  const played = logic.resolveEnemyAction(enemy, { hp: 24, qi: 12, block: 0 }, {
    intent: { kind: 'seal', damage: 0 },
    guUsedCount: 2,
  });
  assert.equal(played.handled, false);
  assert.equal(played.specialCancelled, false);
});

/* V4.1-Q3 已补反制序列：主要伤害意图都能进入统一减伤逻辑。
   本用例只保留「当前回合确实没有反制时不可减免」的语义。 */
test('V4 accepted gap: intents without a counter cannot be mitigated', () => {
  const elite = logic.createEnemy(content, 'ridge_elite_scout');
  elite.currentCounter = '';
  const resolved = logic.resolveEnemyAction(elite, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 4, tag: 'charge' },
    attacked: false,
  });
  assert.equal(resolved.handled, false);
  assert.equal(resolved.damage, 4);

  const drained = logic.resolveEnemyAction(elite, { hp: 24, qi: 12, block: 0 }, {
    intent: { kind: 'drain_qi', drainQi: 3, damage: 0 },
    guUsedCount: 0,
  });
  assert.equal(drained.handled, false);
  assert.equal(drained.player.qi, 9, '无反制的意图无法取消，噬元照扣');
});

/* ---------------- V4.1 ---------------- */

test('V4.1 counter sequences are deterministic by turn', () => {
  // 必须像真实对局一样串 enemy，否则 intentHits 永远停在 1
  let hound = logic.createEnemy(content, 'ridge_hound');
  const seen = [];
  for (let turn = 1; turn <= 4; turn++) {
    hound = logic.startTurn(content, hound, turn, 101).enemy;
    seen.push(hound.currentCounter || 'none');
    hound = logic.finishEnemyAction(hound);
  }
  assert.deepEqual(seen, ['draw_light', 'none', 'intercept', 'none']);

  // 山猪 iron_gate 用 turn 模式：T1/T4 铁皮，全回合约 1/3
  let boar = logic.createEnemy(content, 'iron_hide_boar');
  const boarSeen = [];
  for (let turn = 1; turn <= 6; turn++) {
    boar = logic.startTurn(content, boar, turn, 101).enemy;
    boarSeen.push(boar.currentCounter || 'none');
    boar = logic.finishEnemyAction(boar);
  }
  assert.equal(boarSeen[0], 'iron');
  assert.equal(boarSeen[2], 'none');
  assert.equal(boarSeen[3], 'iron');
  assert.equal(boarSeen.filter((c) => c === 'iron').length, 2);

  let boss = logic.createEnemy(content, 'thunder_crown_sovereign');
  const bossSeen = [];
  for (let turn = 1; turn <= 4; turn++) {
    boss = logic.startTurn(content, boss, turn, 101).enemy;
    bossSeen.push(boss.currentCounter || 'none');
    boss = logic.finishEnemyAction(boss);
  }
  assert.deepEqual(bossSeen, ['intercept', 'none', 'draw_light', 'none']);
});

test('V4.1 crossbow and thunder_pounce_2 carry mitigable counters', () => {
  // 悍客 crossbow 按意图出现次数取序列：第 1 次 seal_first
  const elite = logic.createEnemy(content, 'ridge_elite_scout');
  const at3 = logic.startTurn(content, elite, 3, 101).enemy;
  assert.equal(at3.currentIntent.id, 'crossbow_shot');
  assert.equal(at3.currentCounter, 'seal_first');
  const handled = logic.resolveEnemyAction(at3, { hp: 24, qi: 12, block: 0 }, {
    intent: at3.currentIntent,
    guUsedCount: 0,
  });
  // 未识破 → 不给减伤（Q4：读对 + 做对）
  assert.equal(handled.handled, false);
  const revealed = { ...at3, revealed: true };
  const handled2 = logic.resolveEnemyAction(revealed, { hp: 24, qi: 12, block: 0 }, {
    intent: at3.currentIntent,
    guUsedCount: 0,
  });
  assert.equal(handled2.handled, true);
  assert.equal(handled2.damage, 1, '弩箭 4 → 1');

  // 狼王二阶段 pounce2 按出现次数：draw_light / none / intercept / none
  const bossProfile = logic.profileFor(content, 'thunder_crown_sovereign');
  let boss = logic.createEnemy(content, 'thunder_crown_sovereign');
  const p2 = [];
  for (let turn = 1; turn <= 12; turn++) {
    boss = logic.startTurn(content, boss, turn, 101).enemy;
    if (boss.currentIntent?.id === 'thunder_pounce_2') {
      p2.push({ turn, counter: boss.currentCounter || 'none' });
    }
    boss = logic.finishEnemyAction(boss);
    boss.hp = bossProfile.phaseAt; // 保持二阶段
    boss.lastPhaseIndex = 1;
  }
  assert.equal(p2.length, 6, '二阶段 burn/pounce 交替，12 回合 6 次 pounce2');
  assert.deepEqual(
    p2.map((x) => x.counter),
    ['draw_light', 'none', 'intercept', 'none', 'draw_light', 'none'],
  );
});

test('V4.1 exhaustion converts hp to qi only when damage gu are qi-locked', () => {
  const run = logic.createRun(content);
  // 炼蛊后只剩月芒：3 Qi 门槛
  run.owned = { moon_glow_gu: 1 };
  run.qi = 0;
  run.thoughts = 2;
  run.hp = 20;
  const battle = { turn: 1, used: {}, cooldowns: {}, sealedToday: {}, lightSupport: 0 };

  const gate = logic.exhaustionGate(run, content, battle);
  assert.equal(gate.eligible, true);
  assert.equal(gate.qiBlocked, true);

  const result = logic.applyExhaustion(run, battle, content);
  assert.equal(result.ok, true);
  assert.equal(result.run.qi, 3);
  assert.equal(result.run.hp, 18);
  assert.equal(result.run.thoughts, 1);
  assert.equal(result.battle.exhaustionCount, 1);
  assert.equal(result.battle.exhaustionUsedThisTurn, true);
  assert.equal(result.battle.exhaustionReadyAt, 3);

  // 同回合禁止再触发，且禁收势/生机草
  assert.equal(logic.exhaustionGate(result.run, content, result.battle).eligible, false);
  assert.equal(logic.isActionBannedThisTurn('defend', result.battle, content), true);
  assert.equal(logic.isActionBannedThisTurn('vitality_grass_gu', result.battle, content), true);

  // CD 2：第 3 回合才能再逆息
  const later = { ...result.battle, turn: 3, exhaustionUsedThisTurn: false };
  const run2 = { ...result.run, qi: 0, thoughts: 2, hp: 16 };
  assert.equal(logic.exhaustionGate(run2, content, later).eligible, true);
});

test('V4.1 exhaustion does not fire when a damage gu is already usable', () => {
  const run = logic.createRun(content);
  run.owned = { white_boar_strength_gu: 1, moonlight_gu: 1 };
  run.qi = 0; // 月光被真元卡住
  run.thoughts = 2;
  run.hp = 20;
  const battle = { turn: 1, used: {}, cooldowns: {}, sealedToday: {}, lightSupport: 0 };
  // 白豕 0 真元可用 → 不该逆息
  assert.equal(logic.exhaustionGate(run, content, battle).eligible, false);
  assert.equal(logic.exhaustionGate(run, content, battle).anyUsable, true);
});

test('V4.1 exhaustion requires qi as the blocking reason', () => {
  const run = logic.createRun(content);
  run.owned = { moonlight_gu: 1 };
  run.qi = 0;
  run.thoughts = 0; // 念头不足，不是真元
  run.hp = 20;
  const battle = { turn: 1, used: {}, cooldowns: {}, sealedToday: {}, lightSupport: 0 };
  const gate = logic.exhaustionGate(run, content, battle);
  assert.equal(gate.eligible, false);
  // 有伤害蛊但被念头卡住 → 不算「原因包含真元不足」的唯一原因时
  // 若 also qi blocked：moonlight needs thought 1 and qi 1 → both block
  // reason order: thought first. Still qi-blocked is true because qi < cost too.
  // L1: 原因包含真元不足 — qiBlocked 为 true 即可，但必须没有任何可用伤害蛊。
  // thoughts=0 使它不可用且 qiBlocked=true → 按 L1 字面仍可触发？
  // 「原因包含真元不足」= 存在因 qi 不足而不可用的伤害蛊。这里是 true。
  // 但 canPay 要求 thoughts>=1，所以 gate.canPay=false → eligible=false。正确。
  assert.equal(gate.canPay, false);
});

test('V4 expected damage after correct handling matches the ruling table', () => {
  // 猎犬 4 → 1
  const hound = logic.createEnemy(content, 'ridge_hound');
  hound.currentCounter = 'intercept';
  hound.revealed = true;
  assert.equal(logic.resolveEnemyAction(hound, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 4, tag: 'charge' }, attacked: false,
  }).damage, 1);

  // 山猪 5 → 2（石皮破铁皮）
  const boar = logic.createEnemy(content, 'iron_hide_boar');
  boar.currentCounter = 'iron';
  boar.revealed = true;
  assert.equal(logic.resolveEnemyAction(boar, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 5, tag: 'charge' }, stoneShellUsed: true,
  }).damage, 2);

  // 狼王 5 → 2
  const boss = logic.createEnemy(content, 'thunder_crown_sovereign');
  boss.currentCounter = 'intercept';
  boss.revealed = true;
  assert.equal(logic.resolveEnemyAction(boss, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 5, tag: 'charge' }, attacked: false,
  }).damage, 2);
});

test('V4.1 derived enemy hp matches balance report (not hand-written)', () => {
  const hp = content.balanceReport.enemyHp;
  assert.equal(logic.profileFor(content, 'ridge_hound').hp, hp.ridge_hound);
  assert.equal(logic.profileFor(content, 'iron_hide_boar').hp, hp.iron_hide_boar);
  assert.equal(logic.profileFor(content, 'ridge_elite_scout').hp, hp.ridge_elite_scout);
  assert.equal(logic.profileFor(content, 'thunder_crown_sovereign').hp, hp.thunder_crown_sovereign);
  // 伤害意图仍为 V4 冻结表
  assert.equal(logic.profileFor(content, 'ridge_hound').intents[0].damage, 4);
  assert.equal(logic.profileFor(content, 'iron_hide_boar').intents[0].damage, 5);
  assert.equal(logic.profileFor(content, 'iron_hide_boar').intents[2].damage, 6);
  assert.equal(logic.profileFor(content, 'ridge_elite_scout').intents[2].damage, 4);
  const boss = logic.profileFor(content, 'thunder_crown_sovereign');
  assert.equal(boss.phaseOne[0].damage, 5);
  assert.equal(boss.phaseTwo[1].damage, 6);
});

test('a won battle restores two health and two essence without exceeding caps', () => {
  const run = logic.createRun(content);
  run.hp = 8;
  run.qi = 7;
  const after = logic.applyVictoryRecovery(run);
  assert.equal(after.hp, 10);
  assert.equal(after.qi, 9);

  run.hp = 23;
  run.qi = 12;
  const capped = logic.applyVictoryRecovery(run);
  assert.equal(capped.hp, 24);
  assert.equal(capped.qi, 12);
});

/* 预览必须与结算同一条公式：V4 减伤回显，不再只报原始意图伤害。 */
test('intent preview reflects V4 mitigation instead of raw damage', () => {
  const hound = logic.createEnemy(content, 'ridge_hound');
  hound.currentIntent = { damage: 4, tag: 'charge' };
  hound.currentCounter = 'intercept';
  hound.revealed = true;

  const open = logic.previewEnemyDamage(hound, hound.currentIntent, {
    attacked: false, usedLight: false, damageReduction: 0,
    canStillAvoidAttack: true,
  });
  assert.equal(open.base, 4);
  assert.equal(open.min, 1, '正确处理（不硬打）→ 4-3=1');
  assert.equal(open.max, 4, '做错则吃满');

  const committed = logic.previewEnemyDamage(hound, hound.currentIntent, {
    attacked: true, usedLight: false, damageReduction: 0,
    canStillAvoidAttack: false,
  });
  assert.equal(committed.projected, 4, '已硬打，-3 拿不到');
  assert.equal(committed.max, 4);

  const defended = logic.previewEnemyDamage(hound, hound.currentIntent, {
    attacked: false, usedLight: false, damageReduction: 2,
    canStillAvoidAttack: true,
  });
  assert.equal(defended.projected, 0, '处理正确 + 收势 2 → 4-3-2 下限 0');
});

test('intent preview includes draw-light penalty and iron rage', () => {
  const boss = logic.createEnemy(content, 'thunder_crown_sovereign');
  boss.ironRage = 1;
  boss.currentIntent = { damage: 5, tag: 'charge' };
  boss.currentCounter = 'draw_light';
  boss.revealed = false;

  const open = logic.previewEnemyDamage(boss, boss.currentIntent, {
    usedLight: false, canStillUseLight: true, damageReduction: 0,
  });
  assert.equal(open.base, 6, '基础 5 + 铁皮积威 1');
  assert.equal(open.max, 9, '未用光道 → 逐光 +3');
  assert.equal(open.min, 3, '用光道并处理正确 → 6-3');

  const noLightLeft = logic.previewEnemyDamage(boss, boss.currentIntent, {
    usedLight: false, canStillUseLight: false, damageReduction: 0,
  });
  assert.equal(noLightLeft.projected, 9, '无法再用光道，逐光加伤锁定');
});
