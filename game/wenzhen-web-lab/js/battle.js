// 战斗。普通脚本：全局 renderBattle。判定一律走 rules.js，本文件只负责显示与派发。
const portrait = (p) => `../assets/wenzhen/enemies/${p}.png`;

function renderBattle(root) {
  const b = state.battle;

  if (!b) {
    const list = DATA.enemies.map((e) => `
      <div class="gu ${e.phases ? 'r2' : ''}">
        <img class="thumb" src="${portrait(e.portrait)}" alt="">
        <div class="gn">${e.name}</div>
        <div class="gm">${e.theme} · rank ${e.rank} · 气血 ${e.hp}</div>
        <div class="ge">${e.phases ? `${e.phases.length} 阶段 · 每阶段意图 ${e.phases.map((p) => p.intents.length).join('/')}` : `单意图：${e.intent.label}（${e.intent.damage}）`}</div>
        <div class="gm">线索 ${e.clues.length} · 反击 ${e.reactions.length}</div>
        <button style="margin-top:11px" data-foe="${e.id}">迎战</button>
      </div>`).join('');
    root.innerHTML = `
      <h2>选择对手 · 金框为多阶段 Boss</h2>
      <div class="grid">${list}</div>
      <h2 style="margin-top:28px">出战杀招</h2>
      <div class="moves">${state.equipped.length
        ? state.equipped.map((id) => {
            const m = DATA.killMoves.find((x) => x.id === id);
            return `<div class="move ready"><div class="ml">${m.label}</div><div class="me">${effectText(m.effect)}</div><div class="mc">${isDirectStrike(m) ? '直接攻击' : '非直接'} · 真元 ${m.true_qi_cost} · 念头 ${m.thought_cost}</div></div>`;
          }).join('')
        : '<div class="move"><div class="mr" style="font-size:13px">尚未记入杀招。先到「杀招」页组装。</div></div>'}</div>`;
    root.querySelectorAll('[data-foe]').forEach((el) =>
      el.addEventListener('click', () => act.startBattle(el.dataset.foe)));
    return;
  }

  const view = phaseView(b.enemy);
  const hpPct = Math.max(0, (b.enemy.hp / b.enemy.hpMax) * 100);
  const live = liveReactions(b);

  const phaseChips = view.phase
    ? `<span class="chip live">阶段 ${view.phase.index + 1}/${view.phase.total} · 血线 ≤${Math.round(view.phase.until * 100)}%</span>`
    : '<span class="chip none">无阶段</span>';

  const intentChip = b.enemyIntent
    ? `<span class="chip live">${intentText(b.enemyIntent)}</span>`
    : '<span class="chip spent">冷却中 · 本回合不攻击</span>';

  const cdChips = view.intents.map((it) => {
    const ready = intentReady(b.lastFired[it.id], it.cooldown, b.turn);
    const next = (b.lastFired[it.id] || 0) + (it.cooldown || 0) + 1;
    return `<span class="chip ${ready ? 'none' : 'spent'}">${it.label} · ${ready ? '可用' : `冷却至第 ${next} 回合`}</span>`;
  }).join('') || '<span class="chip none">—</span>';

  const clueChips = b.revealed
    ? (b.enemy.clues.length ? b.enemy.clues.map((c) => `<span class="chip">${c}</span>`).join('') : '<span class="chip none">无线索</span>')
    : '<span class="chip hidden">未察</span>';
  const rxChips = (view.reactions || []).map((r) => {
    if (!b.revealed) return '<span class="chip hidden">未知反击</span>';
    if (reactionLive(b, r)) return `<span class="chip live">${r.label} · 会吞掉直接攻击</span>`;
    if (reactionSettled(b, r)) return `<span class="chip spent">${r.label} · 已失效</span>`;
    return `<span class="chip none">${r.label}</span>`;
  }).join('') || '<span class="chip none">无反击</span>';

  const flagged = Object.keys(b.flags).map((k) => `<span class="chip flag">${statusZh(k === 'enemy_bound' ? 'bound' : 'guarded')}</span>`).join('');

  const buttons = state.equipped.map((id) => {
    const m = DATA.killMoves.find((x) => x.id === id);
    const ok = state.qi >= m.true_qi_cost && state.thought >= m.thought_cost && !b.over;
    const risky = isDirectStrike(m) && live.length;
    return `<button ${ok ? '' : 'disabled'} data-use="${m.id}" class="${risky ? 'risky' : ''}">${m.label} <span class="cost">真元${m.true_qi_cost}</span>${risky ? ' <span class="warnmark">⚠</span>' : ''}</button>`;
  }).join('');

  root.innerHTML = `
    <div class="field">
      <div class="foe" id="foe-box">
        <div class="colhead">敌方</div>
        <img src="${portrait(b.enemy.portrait)}" alt="">
        <div class="fn">${b.enemy.name}</div>
        <div class="hpline"><i style="width:${hpPct}%"></i></div>
        <div class="gm" style="margin-top:7px">气血 ${Math.max(0, b.enemy.hp)} / ${b.enemy.hpMax}</div>
        <div class="chips" style="margin-top:12px">${phaseChips}</div>
        <div class="colhead" style="margin-top:16px">本回合意图</div>
        <div class="chips">${intentChip}</div>
        <div class="colhead" style="margin-top:14px">意图冷却</div>
        <div class="chips">${cdChips}</div>
        <div class="colhead" style="margin-top:14px">线索</div>
        <div class="chips">${clueChips}</div>
        <div class="colhead" style="margin-top:14px">反击</div>
        <div class="chips">${rxChips}</div>
        ${flagged ? `<div class="colhead" style="margin-top:14px">状态</div><div class="chips">${flagged}</div>` : ''}
      </div>
      <div class="pick">
        <div class="colhead">出招</div>
        ${live.length ? `<div class="forewarn">⚠ 直接攻击会被「${live.map((r) => r.label).join('、')}」吞掉（反击预警）</div>` : ''}
        ${!b.revealed && !b.over ? '<button data-observe="1">观察（耗 1 念头 · 1 回合）</button>' : ''}
        ${buttons || '<div class="mr" style="font-size:12px;color:var(--ink-soft)">无可用杀招</div>'}
        <div class="mc" style="margin-top:14px;font-size:12px;color:var(--ink-soft)">
          护体 ${b.block} · 回合 ${b.turn}${b.revealed ? '' : ' · 未察'}${b.over ? ` · <span style="color:var(--cinnabar)">${b.over}</span>` : ''}
        </div>
        <button class="ghost" style="margin-top:16px" data-escape="1">${b.over ? '再战一场' : '脱离'}</button>
      </div>
      <div>
        <div class="colhead">战报</div>
        <div class="log" id="log">${b.log.map((l) => `<div>${l}</div>`).join('')}</div>
      </div>
    </div>`;

  root.querySelectorAll('[data-use]').forEach((el) =>
    el.addEventListener('click', () => act.useMove(el.dataset.use)));
  const ob = root.querySelector('[data-observe]');
  if (ob) ob.addEventListener('click', () => act.observe());
  root.querySelector('[data-escape]').addEventListener('click', () => act.endBattle());
}
