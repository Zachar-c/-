// 状态与主循环。普通脚本：全局 state / act；判定走 rules.js，面板来自 alchemy.js / killmove.js / battle.js。
const FORGE_ODDS = 0.7; // 原型设定：合炼成算七成。失败代价取自原文个案（合炼失败，小光蛊消亡）。

const READY = {
  stones: 3, thought: 3, blood: 24, bloodMax: 24, thoughtMax: 5,
  aptitude: 'bing', stage: 'one',
  owned: {
    moonlight_gu: 1, small_light_gu: 2, stone_shell_gu: 1, vitality_grass_gu: 1,
    jade_skin_gu: 1, white_boar_strength_gu: 1, blood_farewell_gu: 1, blood_droplet_gu: 1,
  },
};

let state = fresh();

function fresh() {
  const qiMax = DATA.battle.stageBase[READY.stage] * DATA.battle.aptitudeMult[READY.aptitude];
  return { ...READY, owned: { ...READY.owned }, equipped: [], battle: null, qiMax, qi: qiMax };
}

const $ = (s) => document.querySelector(s);

function toast(msg, kind = '') {
  const t = $('#toast');
  t.textContent = msg;
  t.className = 'on ' + kind;
  clearTimeout(toast._t);
  toast._t = setTimeout(() => (t.className = kind), 2400);
}

function hud() {
  $('#hud-qi').style.width = (state.qi / state.qiMax) * 100 + '%';
  $('#hud-qi-num').textContent = `${Math.round(state.qi)}/${state.qiMax}`;
  $('#hud-thought').textContent = state.thought;
  $('#hud-stone').textContent = state.stones;
  $('#hud-blood').textContent = state.blood;
  const apt = { jia: '甲等', yi: '乙等', bing: '丙等', ding: '丁等' }[state.aptitude];
  $('#hud-talent').textContent = `${apt} · 一转初阶`;
}

function draw() {
  hud();
  renderAlchemy($('#panel-alchemy'));
  renderKillmove($('#panel-killmove'));
  renderBattle($('#panel-battle'));
  renderCover($('#panel-cover'));
}

// 敌方回合 + 真元回复 + 回合推进。返回 true 表示战斗已结束。
// 意图选取与冷却门禁见 rules.js（语义来自数据自带的 _phases_note）。
function enemyTurn(b) {
  const it = b.enemyIntent;
  if (!it) {
    // 当前阶段所有意图都在冷却：本回合不攻击
    b.log.push('敌方蓄势不动（cooldown_wait）');
  } else {
    b.lastFired[it.id] = b.turn;
    if (it.damage) {
      const absorbed = Math.min(b.block, it.damage);   // 护体抵挡本次敌方出手
      b.block = 0;
      const taken = it.damage - absorbed;
      state.blood -= taken;
      b.log.push(absorbed
        ? `<b>${it.label}</b>，<span class="dmg">伤 ${taken}</span>（护体挡下 ${absorbed}）`
        : `<b>${it.label}</b>，<span class="dmg">伤 ${it.damage}</span>`);
      Sfx.hurt();
    } else {
      b.block = 0;
      b.log.push(`<b>${it.label}</b>`);
    }
    if (it.essence_burn) {
      state.qi = Math.max(0, state.qi - it.essence_burn);
      b.log.push(`<span class="dmg">真元被焚 ${it.essence_burn}</span>`);
    }
  }
  if (state.blood <= 0) {
    state.blood = 0;
    b.over = '败';
    b.log.push('气血耗尽');
    Sfx.lose();
    return true;
  }
  state.qi = Math.min(state.qiMax, state.qi + Math.floor((state.qiMax * DATA.battle.regenPct[state.aptitude]) / 100));
  state.thought = Math.min(state.thoughtMax, state.thought + 1);
  b.turn += 1;
  b.log.push(`— 第 ${b.turn} 回合 —`);
  act._pickIntent(b);
  return false;
}

const act = {
  forge(recipeId) {
    const r = DATA.recipes.find((x) => x.id === recipeId);
    if (!r) return;
    const need = r.inputs.reduce((m, id) => ((m[id] = (m[id] || 0) + 1), m), {});
    for (const [id, n] of Object.entries(need)) if ((state.owned[id] || 0) < n) return toast('材料不足', 'bad');
    if ((r.stoneCost || 0) > state.stones) return toast('元石不足', 'bad');

    for (const [id, n] of Object.entries(need)) state.owned[id] -= n;
    state.stones = Math.max(0, state.stones - (r.stoneCost || 0));
    Sfx.forge();

    const outName = (DATA.gu.find((g) => g.id === r.output) || {}).name || r.output;
    if (Math.random() < FORGE_ODDS) {
      state.owned[r.output] = (state.owned[r.output] || 0) + 1;
      Sfx.success();
      toast(`开炉成功 · ${outName}`, 'good');
    } else {
      // 失败代价：按原文个案，本次投入中最低转的那只消亡（小光蛊）
      const victim = Object.keys(need)
        .map((id) => DATA.gu.find((g) => g.id === id))
        .sort((a, b) => a.rank - b.rank)[0];
      state.owned[victim.id] = Math.max(0, (state.owned[victim.id] || 0) - 1);
      Sfx.fail();
      toast(`开炉失败 · ${victim.name}消亡`, 'bad');
    }
    draw();
  },

  toggleMove(id) {
    const i = state.equipped.indexOf(id);
    if (i >= 0) { state.equipped.splice(i, 1); Sfx.click(); }
    else if (state.equipped.length >= 3) return toast('杀招槽已满（三）', 'bad');
    else { state.equipped.push(id); Sfx.click(); }
    draw();
  },

  startBattle(enemyId) {
    const e = DATA.enemies.find((x) => x.id === enemyId);
    state.battle = {
      enemy: { ...e, hpMax: e.hp, hp: e.hp },
      revealed: false,   // 反击与线索初始隐藏；观察后揭示（Godot 侧为 counter_revealed）
      flags: {},         // enemy_bound / guarded
      lastFired: {},     // 意图上次发出的回合 → 冷却门禁
      phaseIndex: undefined, phaseTotal: 0, enemyIntent: null,
      block: 0, turn: 1, over: null,
      log: [`<b>${e.name}</b> 逼近。`],
    };
    act._pickIntent(state.battle);
    Sfx.click();
    draw();
  },

  // 选本回合敌方意图：阶段 + 冷却门禁（全部在冷却则为 null = cooldown_wait）
  _pickIntent(b) {
    const view = phaseView(b.enemy);
    const idx = view.phase ? view.phase.index : null;
    if (b.phaseIndex !== undefined && idx !== b.phaseIndex && idx !== null) {
      b.log.push(`<b>敌方转入第 ${idx + 1} 阶段</b>`);
    }
    b.phaseIndex = idx;
    b.phaseTotal = view.phase ? view.phase.total : 0;
    const prevId = b.enemyIntent ? b.enemyIntent.id : null;
    b.enemyIntent = selectIntent(view.intents, b.lastFired, b.turn);
    const nextId = b.enemyIntent ? b.enemyIntent.id : null;
    if (nextId !== prevId) b.log.push(`意图：${intentText(b.enemyIntent)}`);
  },

  observe() {
    const b = state.battle;
    if (!b || b.over || b.revealed) return;
    if (state.thought < 1) return toast('念头不足', 'bad');
    state.thought -= 1;
    b.revealed = true;
    Sfx.click();
    b.log.push('你凝神细察，看清了对方的线索与反击。');
    if (enemyTurn(b)) { draw(); return; }
    draw();
  },

  useMove(id) {
    const b = state.battle;
    if (!b || b.over) return;
    const m = DATA.killMoves.find((x) => x.id === id);
    if (state.qi < m.true_qi_cost || state.thought < m.thought_cost) return toast('真元或念头不足', 'bad');

    state.qi -= m.true_qi_cost;
    state.thought -= m.thought_cost;

    // 真实规则：直接攻击会被生效中的反击吞掉，且敌方随即转入对应状态、该反击此后不再预警。
    // 见 scripts/domain/action_preview_service.gd `_live_counter_labels`。
    if (isDirectStrike(m)) {
      const hit = liveReactions(b)[0];
      if (hit) {
        if (hit.counter_status === 'bound') b.flags.enemy_bound = true;
        if (hit.counter_status === 'guarded') b.flags.guarded = true;
        b.log.push(`<b>${m.label}</b> 被「${hit.label}」吞掉，<span class="dmg">未造成伤害</span>`);
        b.log.push(`敌方转入「${statusZh(hit.counter_status)}」，该反击此后不再预警`);
        Sfx.fail();
        if (enemyTurn(b)) { draw(); return; }
        draw();
        return;
      }
    }

    const e = m.effect;
    const hits = [];
    if (e.kind === 'strike') hits.push({ dmg: e.amount });
    if (e.kind === 'heal_and_strike') hits.push({ dmg: e.amount, heal: e.heal });
    if (e.kind === 'shield' || e.kind === 'grant_block') b.block += e.amount;
    if (e.kind === 'heal') hits.push({ heal: e.amount });
    if (e.kind === 'composite') e.parts.forEach((p) => {
      if (p.kind === 'grant_block' || p.kind === 'shield') b.block += p.amount;
      if (p.kind === 'strike') hits.push({ dmg: p.amount });
    });

    let dmg = 0;
    for (const h of hits) {
      if (h.heal) { state.blood = Math.min(state.bloodMax, state.blood + h.heal); b.log.push(`<span class="heal">回气 +${h.heal}</span>`); }
      if (h.dmg) dmg += h.dmg;
    }
    if (dmg) {
      b.enemy.hp -= dmg;
      b.log.push(`<b>${m.label}</b> 命中，<span class="dmg">伤 ${dmg}</span>`);
      Sfx.hit();
      const box = $('#foe-box');
      if (box) { box.classList.add('hit'); setTimeout(() => box.classList.remove('hit'), 300); }
    }
    if (b.block) b.log.push(`护体 ${b.block}`);
    if (b.enemy.hp > 0) act._pickIntent(b);   // 血量变化可能触发阶段切换

    if (b.enemy.hp <= 0) {
      b.over = '胜';
      b.log.push(`<b>${b.enemy.name}</b> 伏诛`);
      Sfx.win();
      state.stones += 2;
      b.log.push('战利品：元石 +2（原型设定）');
      draw();
      return;
    }

    if (enemyTurn(b)) { draw(); return; }
    draw();
  },

  endBattle() {
    state.battle = null;
    Sfx.click();
    draw();
  },
};

// 覆盖页：让开发者一眼看清"这页验了什么、没验什么"。
function renderCover(root) {
  const c = DATA.mechanisms;
  root.innerHTML = `
    <h2>已覆盖 · 可在页面上当场验证</h2>
    <div class="cover-list">${c.covered.map((x) => `
      <div class="cover ok">
        <div class="cv">${x.name}</div>
        <div class="cd">${x.detail}</div>
        <div class="cs">来源：${x.source}</div>
      </div>`).join('')}</div>
    <h2 style="margin-top:32px">未覆盖 · 不要以为这页已经完整</h2>
    <div class="cover-list">${c.notCovered.map((x) => `
      <div class="cover no">
        <div class="cv">${x.name}</div>
        <div class="cd">${x.why}</div>
      </div>`).join('')}</div>`;
}

// 面板切换
const tabs = [...document.querySelectorAll('#tabs button')];
tabs.forEach((b) => b.addEventListener('click', () => {
  tabs.forEach((x) => x.classList.toggle('on', x === b));
  document.querySelectorAll('.panel').forEach((p) => p.classList.toggle('on', p.id === 'panel-' + b.dataset.tab));
  Sfx.click();
}));
$('#reset').addEventListener('click', () => { state = fresh(); Sfx.click(); draw(); toast('已重开'); });
document.addEventListener('pointerdown', () => Sfx.click(), { once: true });

draw();
document.documentElement.dataset.ready = '1';
