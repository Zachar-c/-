/* 问真 · 蛊战回合 · 开发顺序①
   数值源：docs/design/rank1-9-model/parameters.json（一转切片，见 params.js）
   规则固定、代价可读；不做任意拼接。
   月光/小光协同：一只即加倍、两只不叠加 [Canon] */

/* 全局 MODEL 来自 params.js */
const MODEL = window.MODEL;

const A = MODEL.aptitude.value; // 丙等
const S = MODEL.rank.base; // 一转基数 = 1
const HP_MAX = MODEL.combat.baseHp * S; // 100
const MP_MAX = Math.round(100 * A); // 44

const PLAYER = {
  hp: HP_MAX,
  hpMax: HP_MAX,
  mp: MP_MAX,
  mpMax: MP_MAX,
  guard: 0,
  burstCooldown: 0,
};

// 蛊 = 动作占位的「有名字的那一层」；数字全部来自模型 actions
const HAND = {
  fist: {
    id: 'fist',
    name: '拳脚（基础）',
    ap: MODEL.actions.basic.ap,
    cost: MODEL.actions.basic.mortalCost,
    desc: `衰减后基础手段：伤害 ${MODEL.actions.basic.damage}。真元打空后仍可行动。`,
    kind: 'atk',
    dmg: MODEL.actions.basic.damage,
  },
  moon: {
    id: 'moon',
    name: '月光蛊 · 月刃',
    ap: MODEL.actions.strike.ap,
    cost: MODEL.actions.strike.mortalCost,
    desc: `标准攻击占位：伤害 ${MODEL.actions.strike.damage}、真元 ${MODEL.actions.strike.mortalCost}（约空窍一成）[E05]。`,
    kind: 'atk',
    dmg: MODEL.actions.strike.damage,
  },
  small: {
    id: 'small',
    name: '小光蛊',
    ap: 0,
    cost: 0,
    desc: '本回合与月光同放：月刃×2（一只即倍，两只不叠）[Canon]。单独放出不占伤害预算。',
    kind: 'amp',
    dmg: 0,
  },
  jade: {
    id: 'jade',
    name: '玉皮蛊 · 防御',
    ap: MODEL.actions.guard.ap,
    cost: MODEL.actions.guard.mortalCost,
    desc: `护盾 ${MODEL.actions.guard.block}，只护到你下次行动前（blockExpires）。真元 ${MODEL.actions.guard.mortalCost}。`,
    kind: 'def',
    shield: MODEL.actions.guard.block,
  },
  boar: {
    id: 'boar',
    name: '白豕蛊 · 爆发',
    ap: MODEL.actions.burst.ap,
    cost: MODEL.actions.burst.mortalCost,
    desc: `爆发占位：伤害 ${MODEL.actions.burst.damage}、真元 ${MODEL.actions.burst.mortalCost}、冷却 ${MODEL.actions.burst.cooldown} 回合。吃掉你整回合 2AP。`,
    kind: 'atk',
    dmg: MODEL.actions.burst.damage,
    cooldown: MODEL.actions.burst.cooldown,
    burst: true,
  },
};

function makeEnemy(tplId, name, desc, patterns) {
  const t = MODEL.enemies[tplId];
  return {
    id: tplId,
    name,
    hp: t.hp,
    armor: t.armor,
    damage: t.damage,
    energyLoss: t.energyLoss || 0,
    carrier: t.carrier || null,
    packUnits: t.packUnits || 0,
    desc,
    patterns,
  };
}

/* 八场：模型 5 类普通敌 + 3 类特殊载体。数字全部来自 parameters.json */
const ENEMIES = [
  makeEnemy(
    'skirmisher',
    '1 · 快攻兽（skirmisher）',
    '短命快攻。耐受不高，但会连续施压。',
    [
      { type: 'atk', value: 13, label: '急咬', detail: '造成 13 点伤害' },
      { type: 'atk', value: 17, label: '连咬', detail: '造成 17 点伤害' },
    ]
  ),
  makeEnemy(
    'armored',
    '2 · 甲壳兽（armored）',
    '减伤护甲 35%。平砍吃亏，爆发与协同更值。',
    [
      { type: 'atk', value: 17, label: '甲撞', detail: '造成 17 点伤害（自身带 35% 减伤）' },
      { type: 'atk', value: 17, label: '缩甲反击', detail: '造成 17 点伤害' },
    ]
  ),
  makeEnemy(
    'pressure',
    '3 · 重压兽（pressure）',
    '持续压力。单击很重——这回合该防还是硬换？',
    [
      { type: 'atk', value: 22, label: '重击', detail: '造成 22 点伤害' },
      { type: 'atk', value: 25, label: '蓄力重击', detail: '造成 25 点伤害' },
    ]
  ),
  makeEnemy(
    'disruptor',
    '4 · 扰元兽（disruptor）',
    '会摸走你的真元。省元太狠会被抽干。',
    [
      { type: 'atk', value: 16, label: '撕咬', detail: '造成 16 点伤害' },
      { type: 'steal', value: 4, label: '扰元', detail: '偷取 4 点真元（energyLoss）' },
    ]
  ),
  makeEnemy(
    'soulBody',
    '5 · 虚魂体（soulBody）',
    '载体：魂体。常规伤害减免 65%，爆发类全额承伤。',
    [
      { type: 'atk', value: 24, label: '魂冲', detail: '造成 24 点伤害' },
      { type: 'atk', value: 24, label: '阴袭', detail: '造成 24 点伤害' },
    ]
  ),
  makeEnemy(
    'brute',
    '6 · 雷冠头狼（brute）',
    '每两回合蓄势。不会无限让你稳扎。',
    [
      { type: 'atk', value: 20, label: '电弧', detail: '造成 20 点伤害' },
      { type: 'charge', value: 0, label: '蓄势', detail: '下一击提高（windup）' },
      { type: 'atk', value: 26, label: '雷扑', detail: '造成 26 点伤害' },
    ]
  ),
  makeEnemy(
    'guHouse',
    '7 · 蛊屋（guHouse）',
    '载体：蛊屋。护甲 40%、耐受极高、单击很轻——像在拆固定杀招。',
    [
      { type: 'atk', value: 4, label: '屋脊弹', detail: '造成 4 点伤害（自身 40% 减伤）' },
      { type: 'atk', value: 4, label: '阵纹反击', detail: '造成 4 点伤害' },
    ]
  ),
  makeEnemy(
    'beastPack',
    '8 · 兽群（beastPack）',
    '载体：兽潮 6 单位。伤害随剩余单位衰减，但总量很大。',
    [
      { type: 'pack', value: 24, label: '群袭', detail: '按剩余单位线性出伤（下限 25%）' },
      { type: 'pack', value: 24, label: '再扑', detail: '按剩余单位线性出伤' },
    ]
  ),
];

const state = {
  wave: 0,
  turn: 1,
  enemy: null,
  enemyHp: 0,
  enemyMax: 0,
  patternIdx: 0,
  chargeBonus: 0,
  packUnits: 0,
  picked: [],
  log: [],
  over: false,
  won: false,
};

function addLog(kind, text, cls = '') {
  state.log.unshift({ kind, text, cls });
  if (state.log.length > 60) state.log.pop();
}

function currentIntent() {
  return state.enemy.patterns[state.patternIdx % state.enemy.patterns.length];
}

function startWave(index) {
  state.wave = index;
  const e = ENEMIES[index];
  state.enemy = e;
  state.enemyHp = e.hp;
  state.enemyMax = e.hp;
  state.packUnits = e.packUnits || 0;
  state.patternIdx = 0;
  state.chargeBonus = 0;
  state.picked = [];
  state.over = false;
  state.won = false;
  addLog('遭遇', `对上 ${e.name}（模板 hp ${e.hp} / dmg 见意图）。`);
  render();
}

function resetAll() {
  PLAYER.hp = PLAYER.hpMax;
  PLAYER.mp = PLAYER.mpMax;
  PLAYER.guard = 0;
  PLAYER.burstCooldown = 0;
  state.turn = 1;
  state.picked = [];
  state.log = [];
  addLog('开始', `一转标尺：耐受 ${HP_MAX}、丙等真元 ${MP_MAX}、每回合 ${MODEL.combat.actionsPerTurn} AP。`);
  addLog('来源', `数值源 ${MODEL.source}；协同规则为固定组合，不做任意拼接。`);
  startWave(0);
}

function availableCards() {
  return ['fist', 'moon', 'small', 'jade', 'boar'];
}

function pickedAp() {
  return state.picked.reduce((s, id) => s + HAND[id].ap, 0);
}

function pickedCost() {
  return state.picked.reduce((s, id) => s + HAND[id].cost, 0);
}

function comboActive() {
  return state.picked.includes('moon') && state.picked.includes('small');
}

function togglePick(id) {
  if (state.over) return;
  const i = state.picked.indexOf(id);
  if (i >= 0) {
    state.picked.splice(i, 1);
    render();
    return;
  }
  if (state.picked.includes(id)) return;
  const card = HAND[id];
  if (pickedAp() + card.ap > MODEL.combat.actionsPerTurn) {
    addLog('行动', `放不出 ${card.name}：超过每回合 ${MODEL.combat.actionsPerTurn} AP。`);
    render();
    return;
  }
  if (pickedCost() + card.cost > PLAYER.mp) {
    addLog('真元', `放不出 ${card.name}：还差 ${pickedCost() + card.cost - PLAYER.mp} 点青铜真元。`);
    render();
    return;
  }
  if (card.burst && PLAYER.burstCooldown > 0) {
    addLog('冷却', `${card.name} 冷却中（剩 ${PLAYER.burstCooldown} 回合）。`);
    render();
    return;
  }
  state.picked.push(id);
  render();
}

function resolveTurn() {
  if (state.over) return;
  if (!state.picked.length) {
    addLog('回合', '空过一回合。');
  }

  let dmgToEnemy = 0;
  let notes = [];
  const combo = comboActive();
  let usedBurst = false;

  state.picked.forEach((id) => {
    const c = HAND[id];
    if (c.kind === 'atk') {
      let d = c.dmg;
      if (id === 'moon' && combo) {
        d = d * 2;
        notes.push('月光借小光加倍（×2，不再叠第二只）');
      }
      if (id === 'small') {
        d = 0;
        if (!combo) notes.push('小光单独不产生标准输出');
      }
      const cls = c.burst ? 'burst' : id === 'fist' ? 'basic' : 'strike';
      if (c.burst) usedBurst = true;

      // 载体：魂体减常规伤
      if (state.enemy.carrier === 'soulBody' && d > 0) {
        const resist = MODEL.carriers.soulBodyResist[cls] || 0;
        if (resist > 0) {
          d = Math.round(d * (1 - resist));
          notes.push(`虚魂体减免常规伤（${cls} −${Math.round(resist * 100)}%）`);
        } else {
          notes.push(`虚魂体不减 ${cls} 类伤害`);
        }
      }
      // 载体：兽群按单位出伤有别，玩家侧按 packAoeYield 简单加权
      if (state.enemy.carrier === 'beastPack' && d > 0) {
        const y = MODEL.carriers.packAoeYield[cls] || 1;
        d = Math.round(d * y);
      }
      // 护甲
      const armor = state.enemy.armor || 0;
      if (armor > 0 && d > 0) d = Math.round(d * (1 - armor));
      dmgToEnemy += d;
    } else if (c.kind === 'def') {
      PLAYER.guard = c.shield;
      notes.push(`玉皮护盾 ${c.shield}（至下次行动前）`);
    }
  });

  PLAYER.mp -= pickedCost();
  if (PLAYER.mp < 0) PLAYER.mp = 0;

  if (usedBurst) PLAYER.burstCooldown = MODEL.actions.burst.cooldown;
  else if (PLAYER.burstCooldown > 0) PLAYER.burstCooldown -= 1;

  if (dmgToEnemy > 0) {
    state.enemyHp -= dmgToEnemy;
    if (state.enemy.carrier === 'beastPack' && state.packUnits > 0) {
      const maxU = state.enemy.packUnits || 1;
      const nextUnits = Math.max(0, Math.ceil((state.enemyHp / state.enemyMax) * maxU));
      if (nextUnits < state.packUnits) {
        addLog('兽群', `打散 ${state.packUnits - nextUnits} 个单位（剩 ${nextUnits}）`, 'good');
        state.packUnits = nextUnits;
      }
    }
    addLog('你', `打出 ${dmgToEnemy} 伤${combo ? '（月刃协同）' : ''}`, 'good');
    notes.forEach((n) => addLog('联动', n, 'good'));
  } else if (notes.length) {
    notes.forEach((n) => addLog('联动', n));
  }

  if (state.enemyHp <= 0) {
    state.enemyHp = 0;
    addLog('胜', `${state.enemy.name} 倒下。`, 'good');
    PLAYER.mp = Math.min(PLAYER.mpMax, PLAYER.mp + 6);
    if (state.wave < ENEMIES.length - 1) {
      state.over = true;
      state.won = true;
      render();
      showResult(true, true);
    } else {
      state.over = true;
      state.won = true;
      render();
      showResult(true, false);
    }
    return;
  }

  const intent = currentIntent();
  if (intent.type === 'atk') {
    let d = intent.value + state.chargeBonus;
    state.chargeBonus = 0;
    if (PLAYER.guard > 0) {
      const blocked = Math.min(PLAYER.guard, d);
      d -= blocked;
      PLAYER.guard = 0;
      addLog('玉皮', `挡下 ${blocked} 点`, 'good');
    }
    PLAYER.hp -= d;
    addLog('敌', `${intent.label}：${d} 点伤害`, 'hit');
  } else if (intent.type === 'pack') {
    // 兽群：按剩余单位线性衰减，下限 packDamageFloor
    const units = Math.max(1, state.packUnits || 1);
    const maxU = state.enemy.packUnits || 1;
    const scale = Math.max(MODEL.carriers.packDamageFloor, units / maxU);
    let d = Math.round(intent.value * scale + state.chargeBonus);
    state.chargeBonus = 0;
    if (PLAYER.guard > 0) {
      const blocked = Math.min(PLAYER.guard, d);
      d -= blocked;
      PLAYER.guard = 0;
      addLog('玉皮', `挡下 ${blocked} 点`, 'good');
    }
    PLAYER.hp -= d;
    addLog('敌', `${intent.label}：${d} 点（${units}/${maxU} 单位）`, 'hit');
  } else if (intent.type === 'steal') {
    const s = Math.min(intent.value, PLAYER.mp);
    PLAYER.mp -= s;
    addLog('敌', `摸走 ${s} 点真元`, 'hit');
  } else if (intent.type === 'charge') {
    state.chargeBonus += 6;
    addLog('敌', '蓄势：下一击 +6');
  }

  if (PLAYER.hp <= 0) {
    PLAYER.hp = 0;
    state.over = true;
    state.won = false;
    render();
    showResult(false, false);
    return;
  }

  state.turn += 1;
  if (state.turn > MODEL.combat.maxTurns) {
    state.over = true;
    state.won = false;
    render();
    showResult(false, false, '超过 30 回合上限，按未胜处理——禁止无限防御刷收益。');
    return;
  }
  state.patternIdx += 1;
  state.picked = [];
  PLAYER.guard = 0;
  render();
}

function showResult(won, hasNext, extra) {
  const panel = document.getElementById('result-panel');
  panel.hidden = false;
  document.getElementById('result-title').textContent = won
    ? hasNext
      ? `击破 ${state.enemy.name}`
      : '整场打完'
    : '你倒下了';
  document.getElementById('result-body').textContent = won
    ? hasNext
      ? `这一场你的选择来自：意图、真元、2AP、协同。下一场是 ${ENEMIES[state.wave + 1] ? ENEMIES[state.wave + 1].name : '终场'}——短板会被加压。`
      : '八场都过了。若连点两下同一套还能过，说明预算还太松；若你在「省元 / 协同 / 该防 / 爆发冷却 / 载体克制」之间来回换——方向对了。'
    : (extra || '败因通常不是数值，是这回合把真元或防御用在了错处。再看意图。');

  const next = document.getElementById('btn-next');
  next.hidden = !(won && hasNext);
  if (won && hasNext) {
    next.onclick = () => {
      panel.hidden = true;
      PLAYER.hp = Math.min(PLAYER.hpMax, PLAYER.hp + 25);
      PLAYER.mp = Math.min(PLAYER.mpMax, PLAYER.mp + 12);
      PLAYER.burstCooldown = 0;
      state.turn = 1;
      startWave(state.wave + 1);
    };
  }
}

function render() {
  document.getElementById('turn').textContent = String(state.turn);
  document.getElementById('hp').textContent = String(PLAYER.hp);
  document.getElementById('mp').textContent = String(PLAYER.mp);
  document.getElementById('ap').textContent = `${Math.max(0, MODEL.combat.actionsPerTurn - pickedAp())}`;
  document.getElementById('enemy-name').textContent = state.enemy ? state.enemy.name : '—';
  document.getElementById('enemy-hp').textContent = state.enemy ? `${state.enemyHp}/${state.enemyMax}` : '0';

  const intent = state.enemy ? currentIntent() : null;
  const intentEl = document.getElementById('intent');
  if (intent) {
    const extra = state.chargeBonus ? `（含蓄势加成 ${state.chargeBonus}）` : '';
    intentEl.innerHTML = `<strong>下一手意图</strong>　${intent.label} · ${intent.detail}${extra}`;
  }

  const box = document.getElementById('enemy-box');
  if (state.enemy) {
    const pct = Math.round((state.enemyHp / state.enemyMax) * 100);
    const packLine = state.enemy.carrier === 'beastPack'
      ? `<p>剩余单位：${state.packUnits} / ${state.enemy.packUnits}（伤害随单位衰减，下限 25%）</p>`
      : '';
    const soulLine = state.enemy.carrier === 'soulBody'
      ? `<p>载体规则：常规伤 −65%，爆发类全额。</p>`
      : '';
    box.innerHTML = `
      <h4>${state.enemy.name}</h4>
      <div class="hp-bar"><i style="width:${pct}%"></i></div>
      ${packLine}
      ${soulLine}
      <p>${state.enemy.desc}</p>
    `;
  }

  const hand = document.getElementById('hand');
  hand.innerHTML = availableCards()
    .map((id) => {
      const c = HAND[id];
      const picked = state.picked.includes(id);
      const apLeft = MODEL.combat.actionsPerTurn - (pickedAp() - (picked ? c.ap : 0));
      const mpLeft = PLAYER.mp - (pickedCost() - (picked ? c.cost : 0));
      const cd = c.burst && PLAYER.burstCooldown > 0;
      const disabled =
        state.over ||
        (!picked && (apLeft < c.ap || mpLeft < c.cost || cd));
      return `
        <button type="button" class="gu-btn ${picked ? 'is-picked' : ''}" data-pick="${id}" ${disabled ? 'disabled' : ''}>
          <span class="name">${c.name}</span>
          <span class="cost">AP ${c.ap} · 真元 ${c.cost}${cd ? ' · 冷却' + PLAYER.burstCooldown : ''}</span>
          <span class="desc">${c.desc}</span>
        </button>
      `;
    })
    .join('');

  hand.querySelectorAll('[data-pick]').forEach((b) => {
    b.addEventListener('click', () => togglePick(b.getAttribute('data-pick')));
  });

  const tip = document.getElementById('combo-tip');
  if (comboActive()) {
    tip.textContent = '协同成立：本回合月刃威力×2。小光不再另计伤害。';
  } else if (state.picked.includes('moon')) {
    tip.textContent = '月光单放：标准攻击 24。若还带小光，可考虑同回合并出。';
  } else if (state.picked.includes('small')) {
    tip.textContent = '小光单独不产生标准输出——它适合并进月刃。';
  } else if (state.picked.includes('boar')) {
    tip.textContent = '爆发占满 2AP 与 25 真元——确认意图后再丢。';
  } else {
    tip.textContent = `先看意图。每回合 ${MODEL.combat.actionsPerTurn} AP，护盾过期，最多 ${MODEL.combat.maxTurns} 回合。`;
  }

  document.getElementById('rules').innerHTML = `
    <div class="rule"><strong>标尺 · ${MODEL.rank.name} ${MODEL.rank.essence}</strong>耐受 ${HP_MAX} · 丙等真元 ${MP_MAX} · 基数 B=${S}。源：${MODEL.source}</div>
    <div class="rule"><strong>回合制，意图先亮</strong>每回合 ${MODEL.combat.actionsPerTurn} AP；最多 ${MODEL.combat.maxTurns} 回合判未胜。</div>
    <div class="rule"><strong>动作预算（模型 actions）</strong>基础 10伤/0元 · 标准 24伤/10元 · 爆发 66伤/25元/冷却3 · 防御 20盾/8元。</div>
    <div class="rule"><strong>协同（固定规则）</strong>月光+小光同回合并出 → 月刃×2；一只即倍，两只不叠 [Canon]。</div>
    <div class="rule"><strong>同一只蛊一个当下</strong>本回合放过的不能重复堆叠；爆发吃满 2AP。</div>
    <div class="rule"><strong>护盾过期</strong>玉皮只护到下次行动前（blockExpires=true）。</div>
    <div class="rule"><strong>不做任意拼接</strong>效果来自指定蛊与固定组合，方便读懂、验收、对齐模型。</div>
  `;

  const log = document.getElementById('log');
  log.innerHTML = state.log
    .slice(0, 20)
    .map((l) => `<div class="log-item ${l.cls}"><strong>${l.kind}</strong>${l.text}</div>`)
    .join('');

  document.getElementById('btn-resolve').disabled = state.over;
  document.getElementById('btn-clear').disabled = state.over || !state.picked.length;
}

document.getElementById('btn-resolve').addEventListener('click', resolveTurn);
document.getElementById('btn-clear').addEventListener('click', () => {
  state.picked = [];
  render();
});
document.getElementById('btn-restart').addEventListener('click', () => {
  document.getElementById('result-panel').hidden = true;
  document.getElementById('btn-next').hidden = true;
  resetAll();
});

resetAll();
