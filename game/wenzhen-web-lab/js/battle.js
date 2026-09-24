// 战斗。普通脚本：全局 renderBattle。壳=lab.css；结算/反制=MVP CombatCore。
const WEB_BOSS_PORTRAITS = new Set([
  'web_boss_miasma_vein_lord',
  'web_boss_blood_vein_bishop',
  'web_boss_clan_patriarch',
  'web_boss_blue_fur_jiangshi',
]);
const portrait = (p) => `../assets/wenzhen/enemies/${p}.${WEB_BOSS_PORTRAITS.has(p) ? 'jpg' : 'png'}`;

function battleReasonLabel(reason) {
  return ({
    battle_over: '战斗已经结束',
    condition_miss: '效果条件未满足',
    consume_status_missing: '目标没有可消耗的状态',
    delay_shape_rejected: '此延迟效果暂不可用',
    trigger_unsupported: '此触发方式暂不可用',
  })[reason] || guReasonLabel(reason) || reason || '';
}

function counterBadge(enemy) {
  const core = globalThis.CombatCore;
  if (!core || !enemy) return '';
  const active = core.counterActive ? core.counterActive(enemy) : !!enemy.currentCounter;
  if (!active) return '<span class="chip">反制 —</span>';
  if (enemy.counterRevealed || enemy.revealed) {
    const label = (MVP_CONTENT?.counterRules?.[enemy.currentCounter]?.label) || enemy.currentCounter;
    return `<span class="chip live">反制 ${label}</span>`;
  }
  return '<span class="chip">反制 未知</span>';
}

/** MVP 情报：公开意图 / 已知弱点 / 未察信息 */
function intelBlock(enemy) {
  const id = enemy?.id || '';
  const intel = (typeof MVP_CONTENT !== 'undefined' && MVP_CONTENT.intel && MVP_CONTENT.intel[id]) || null;
  const revealed = !!(enemy?.revealed || enemy?.counterRevealed);
  const counterId = enemy?.currentCounter || '';
  const counterLabel = revealed && counterId
    ? ((MVP_CONTENT?.counterRules?.[counterId]?.label) || counterId)
    : null;
  const intent = enemy?.enemyIntent || enemy?.currentIntent;
  const preview = (globalThis.CombatCore?.previewEnemyDamage && intent)
    ? globalThis.CombatCore.previewEnemyDamage(enemy, intent, { usedLight: false })
    : null;
  const dmgLine = preview
    ? `预计 ${preview.base}${preview.projected !== preview.base ? ` → ${preview.projected} 伤` : ''}`
    : (intent ? `预计 ${intent.damage || 0} 伤` : '冷却中');
  return `
    <div class="intel-lines">
      <div><span class="il">下一行动</span><span>${intent ? (intent.label || intent.id) : '蓄势'} · ${dmgLine}</span></div>
      <div><span class="il">已知弱点</span><span>${(intel && intel.known) || '—'}</span></div>
      <div><span class="il">未察信息</span><span>${(intel && intel.unknown) || (revealed ? '已全部识破' : '反制未识破')}</span></div>
      <div><span class="il">反制</span><span>${counterLabel || (counterId ? '未知' : '—')}</span></div>
    </div>`;
}

function battleEncounterCard(node) {
  if (!node || !['battle', 'elite', 'boss'].includes(node.type)) return '';
  const ids = nodeEnemyIds(node);
  const names = ids.map((id) => (enemyById(id) || {}).name || id);
  return `<section class="combat-intro">
    <div>
      <div class="kicker">当前遭遇 · ${node.segment ? `第 ${node.segment} 段` : stageLabel(node.stage)}</div>
      <h2>${node.name}</h2>
      <p>${node.summary || ''}</p>
      <div class="tag-row">${names.map((name) => `<span class="tagline">${name}</span>`).join('')}</div>
    </div>
    <button class="primary" data-start-encounter>迎战</button>
  </section>`;
}

function renderBattle(root) {
  const b = state.battle;
  const encounter = currentNode();
  const guRoster = currentCombatRoster(
    b ? b.guUsedThisTurn : {},
    b ? b.guSealed : {},
  );

  const debugSparring = /(?:\?|&)debug=1(?:&|$)/.test(String(location.search || ''));
  if (!b) {
    const roster = debugSparring ? DATA.enemies.map((e) => `
      <article class="gu ${e.phases ? 'r2' : ''}">
        <img class="thumb" src="${portrait(e.portrait)}" alt="">
        <div class="gn">${e.name}</div>
        <div class="gm">${e.theme} · rank ${e.rank} · 气血 ${e.hp}</div>
        <div class="ge">${e.phases ? `${e.phases.length} 阶段 · 每阶段意图 ${e.phases.map((p) => p.intents.length).join('/')}` : `单意图：${intentText(e.intent)}`}</div>
        <div class="gm">线索 ${e.clues.length} · 反击 ${e.reactions.length}</div>
        <button style="margin-top:11px" data-foe="${e.id}">演武</button>
      </article>`).join('') : '';
    root.innerHTML = `
      ${battleEncounterCard(encounter)}
      ${debugSparring ? `
      <h2 style="margin-top:28px">自由演武 · 单一敌人</h2>
      <div class="grid">${roster}</div>` : ''}
      <h2 style="margin-top:28px">可用蛊虫 · 无固定槽位上限</h2>
      <div class="moves">${guRoster.length
        ? guRoster.map((g) => `<div class="move ready">
            <div class="ml">${g.name}</div>
            <div class="me">${effectText(g.battleEffect)}</div>
            <div class="mc">${g.rank} 转 · ${schoolLabel(g.school)} · 真元 ${g.trueQiCost} · 念头 ${g.thoughtCost}</div>
          </div>`).join('')
        : '<div class="move"><div class="mr" style="font-size:13px">暂无已炼化战斗蛊。</div></div>'}</div>
      <h2 style="margin-top:28px">出战杀招</h2>
      <div class="moves">${state.equipped.length
        ? state.equipped.map((id) => {
            const m = DATA.killMoves.find((x) => x.id === id);
            const kmDirect = GuRules.killMoveIsDirectStrike(m, GU_BY_ID, {});
            return `<div class="move ready"><div class="ml">${m.label}</div><div class="me">${killMoveEffectText(m, GU_BY_ID)}</div><div class="mc">${kmDirect ? '直接攻击' : '非直接'} · 真元 ${m.true_qi_cost} · 念头 ${m.thought_cost}</div></div>`;
          }).join('')
        : '<div class="move"><div class="mr" style="font-size:13px">尚未记入杀招。先到「杀招」页组装。</div></div>'}</div>`;
    root.querySelector('[data-start-encounter]')?.addEventListener('click', () => {
      const ids = nodeEnemyIds(encounter);
      if (ids.length) act.startBattle(ids, encounter.id);
    });
    root.querySelectorAll('[data-foe]').forEach((el) =>
      el.addEventListener('click', () => act.startBattle(el.dataset.foe)));
    return;
  }

  const target = targetOf(b);
  const view = phaseView(target);
  const hpPct = Math.max(0, (target.hp / target.hpMax) * 100);
  const live = liveReactions(target);

  const actors = b.enemies.map((enemy) => {
    const ev = phaseView(enemy);
    const pct = Math.max(0, (enemy.hp / enemy.hpMax) * 100);
    const dead = enemy.hp <= 0;
    const chosen = enemy.id === b.targetId;
    return `<button class="enemy-actor ${chosen ? 'target' : ''} ${dead ? 'dead' : ''}" data-target="${enemy.id}" aria-pressed="${chosen}" aria-label="${enemy.name}，${dead ? '已伏诛' : `气血 ${Math.max(0, enemy.hp)} / ${enemy.hpMax}，意图 ${intentText(enemy.enemyIntent)}`}" ${dead ? 'disabled' : ''}>
      <img src="${portrait(enemy.portrait)}" alt="">
      <span class="ea-name">${enemy.name}</span>
      <span class="ea-hp" role="meter" aria-label="${enemy.name}气血" aria-valuemin="0" aria-valuemax="${enemy.hpMax}" aria-valuenow="${Math.max(0, enemy.hp)}"><i style="width:${pct}%"></i></span>
      <span class="ea-intent">${dead ? '伏诛' : intentText(enemy.enemyIntent)}</span>
      <span class="ea-phase">${ev.phase ? `阶段 ${ev.phase.index + 1}/${ev.phase.total}` : '无阶段'}</span>
    </button>`;
  }).join('');

  const phaseChips = view.phase
    ? `<span class="chip live">阶段 ${view.phase.index + 1}/${view.phase.total} · 血线 ≤${Math.round(view.phase.until * 100)}%</span>`
    : '<span class="chip none">无阶段</span>';

  const intentChip = target.enemyIntent
    ? `<span class="chip live">${intentText(target.enemyIntent)}</span>`
    : '<span class="chip spent">冷却中 · 本回合不攻击</span>';
  const counterChip = counterBadge(target);
  const intelHtml = intelBlock(target);

  const cdChips = view.intents.map((it) => {
    const ready = intentReady(target.lastFired[it.id], it.cooldown, b.turn);
    const next = (target.lastFired[it.id] || 0) + (it.cooldown || 0) + 1;
    return `<span class="chip ${ready ? 'none' : 'spent'}">${it.label} · ${ready ? '可用' : `冷却至第 ${next} 回合`}</span>`;
  }).join('') || '<span class="chip none">—</span>';

  const clueChips = target.revealed
    ? (target.clues.length ? target.clues.map((c) => `<span class="chip">${c}</span>`).join('') : '<span class="chip none">无线索</span>')
    : '<span class="chip hidden">未察</span>';
  const rxChips = (view.reactions || []).map((r) => {
    if (!target.revealed) return '<span class="chip hidden">未知反击</span>';
    if (reactionLive(target, r)) return `<span class="chip live">${r.label} · 会吞掉直接攻击</span>`;
    if (reactionSettled(target, r)) return `<span class="chip spent">${r.label} · 已失效</span>`;
    return `<span class="chip none">${r.label}</span>`;
  }).join('') || '<span class="chip none">无反击</span>';

  const flagChips = Object.keys(target.flags)
    .map((k) => `<span class="chip flag">${statusZh(k === 'enemy_bound' ? 'bound' : 'guarded')}</span>`)
    .join('');
  const marked = Number(target.statuses?.marked || 0);
  const intentWeaken = Number(target.intentWeaken || 0);
  const statusChips = `${flagChips}${marked ? `<span class="chip">刻痕 ${marked}</span>` : ''}${intentWeaken ? `<span class="chip">意弱 ${intentWeaken}</span>` : ''}`;
  const delayedChips = (b.delayedEffects || []).map((entry) =>
    `<span class="chip spent">${entry.label} · 第 ${entry.dueTurn} 回合</span>`).join('');
  const basicOk = state.thought >= 1 && b.actionsUsed < b.actionLimit && !b.over;
  const observeOk = state.thought >= 1 && b.actionsUsed < b.actionLimit && !b.over;
  const basicWhy = b.over ? '本场战斗已结束'
    : b.actionsUsed >= b.actionLimit ? '本回合行动数已尽'
      : state.thought < 1 ? '念头不足' : '';
  const observeWhy = b.over ? '本场战斗已结束'
    : b.actionsUsed >= b.actionLimit ? '本回合行动数已尽'
      : state.thought < 1 ? '念头不足' : '';

  const buttons = state.equipped.map((id) => {
    const m = DATA.killMoves.find((x) => x.id === id);
    const recipeInstances = GuRules.killMoveRecipeInstances(
      m,
      state.owned,
      b.guUsedThisTurn,
      b.guSealed,
    );
    const recipeBlocked = !!b.killMoveUsedThisTurn?.[m.id]
      || recipeInstances.some((instanceId) => !instanceId);
    const thoughtCost = Number(m.thought_cost || 0);
    const qiCost = Number(m.true_qi_cost || 0);
    const moveGate = GuRules.killMoveGateMissReason(m, GU_BY_ID, {
      hp: state.blood,
      hpMax: state.bloodMax,
      enemiesAlive: aliveEnemies(b).length,
      turn: b.turn,
      statusStacks: target.statuses || {},
    });
    const blockedReason = b.over ? '战斗已经结束'
      : recipeBlocked ? '杀招已用，或配方蛊本回合不可用'
        : state.qi < qiCost ? '真元不足'
          : state.thought < thoughtCost ? '念头不足'
            : b.actionsUsed >= b.actionLimit ? '本回合行动数已尽'
              : moveGate ? battleReasonLabel(moveGate) : '';
    const ok = !blockedReason
      && b.actionsUsed < b.actionLimit
      && !b.over;
    const risky = (GuRules.killMoveIsDirectStrike(m, GU_BY_ID, {}) && live.length) || Number(m.life_cost || 0) > 0;
    const title = blockedReason;
    const life = Number(m.life_cost || 0) > 0 ? `寿元${m.life_cost}` : '';
    return `<button ${ok ? '' : 'disabled'} data-use="${m.id}" class="${risky ? 'risky' : ''}" title="${title || (life ? '寿元代价：归零将当场陨落' : '')}">${m.label} <span class="cost">真元 ${qiCost} · 念头 ${thoughtCost}${life ? ` · ${life}` : ''}</span>${risky ? ' <span class="warnmark">⚠</span>' : ''}${!ok ? `<small class="action-blocked">${title || '当前不可用'}</small>` : ''}</button>`;
  }).join('');
  const guButtons = guRoster.map((g) => {
    const used = !!b.guUsedThisTurn[g.instanceId];
    const reason = GuRules.activationReason(g, {
      playerRank: state.cultivation,
      trueQi: state.qi,
      thought: state.thought,
      usedThisTurn: used,
      actionLimitReached: b.actionsUsed >= b.actionLimit,
    });
    const gate = GuRules.gateMissReason(g.battleEffect, {
      hp: state.blood,
      hpMax: state.bloodMax,
      enemiesAlive: aliveEnemies(b).length,
      turn: b.turn,
      statusStacks: target.statuses || {},
    });
    const blocked = reason || gate || (b.over ? 'battle_over' : '');
    const risky = (isDirectStrike({ effect: g.battleEffect }) && live.length) || Number(g.lifeCost || 0) > 0;
    const label = g.count > 1 ? `${g.name} ${g.instanceIndex}/${g.count}` : g.name;
    const life = Number(g.lifeCost || 0) > 0 ? `寿元${g.lifeCost}` : '';
    const blockedLabel = battleReasonLabel(blocked);
    return `<button ${blocked ? 'disabled' : ''} data-use-gu="${g.instanceId}" class="${risky ? 'risky' : ''}" title="${blockedLabel || (life ? '寿元代价：归零将当场陨落' : '')}">${label} <span class="cost">真元 ${g.trueQiCost} · 念头 ${g.thoughtCost}${life ? ` · ${life}` : ''}</span>${risky ? ' <span class="warnmark">⚠</span>' : ''}${blocked ? `<small class="action-blocked">${blockedLabel || '当前不可用'}</small>` : ''}</button>`;
  }).join('');

  root.innerHTML = `
    <div class="battle-head">
      <div><div class="kicker">${encounter ? `第 ${encounter.segment} 段 · ${segmentTitle(encounter.segment)} · ${encounter.name}` : '当前遭遇'} · 第 ${b.turn} 回合</div><h2>战斗 · 场上 ${aliveEnemies(b).length}/${b.enemies.length}</h2></div>
      <div class="wallet">行动 ${b.actionsUsed}/${b.actionLimit} · 护体 ${b.block} · 剑意 ${b.swordIntent}</div>
    </div>
    <div class="enemy-stack">${actors}</div>
    <div class="field">
      <div class="foe" id="foe-box">
        <div class="turn-pill">回合 <b>${b.turn}</b> · 行动 <b>${b.actionsUsed}/${b.actionLimit}</b></div>
        <div class="colhead">当前目标</div>
        <img src="${portrait(target.portrait)}" alt="">
        <div class="fn">${target.name}</div>
        <div class="hpline" role="meter" aria-label="${target.name}气血" aria-valuemin="0" aria-valuemax="${target.hpMax}" aria-valuenow="${Math.max(0, target.hp)}"><i style="width:${hpPct}%"></i></div>
        <div class="gm" style="margin-top:7px">气血 ${Math.max(0, target.hp)} / ${target.hpMax}</div>
        <div class="chips" style="margin-top:12px">${phaseChips}</div>
        <div class="colhead" style="margin-top:16px">本回合意图</div>
        <div class="chips">${intentChip} ${counterChip}</div>
        ${intelHtml}
        <div class="colhead" style="margin-top:14px">意图冷却</div>
        <div class="chips">${cdChips}</div>
        ${delayedChips ? `<div class="colhead" style="margin-top:14px">延迟结算</div><div class="chips">${delayedChips}</div>` : ''}
        <div class="colhead" style="margin-top:14px">线索</div>
        <div class="chips">${clueChips}</div>
        <div class="colhead" style="margin-top:14px">反击</div>
        <div class="chips">${rxChips}</div>
        ${statusChips ? `<div class="colhead" style="margin-top:14px">状态</div><div class="chips">${statusChips}</div>` : ''}
      </div>
      <div class="pick">
        <div class="colhead">催动蛊虫 · ${guRoster.length}</div>
        ${live.length ? `<div class="forewarn">⚠ 对当前目标直接攻击会被「${live.map((r) => r.label).join('、')}」吞掉（反击预警）</div>` : ''}
        <button ${basicOk ? '' : 'disabled'} data-basic-attack="1" class="${live.length ? 'risky' : basicOk ? 'primary' : ''}" title="${basicWhy}">拳脚攻击 <span class="cost">念头 1</span>${live.length ? ' <span class="warnmark">⚠</span>' : ''}${basicWhy ? `<small class="action-blocked">${basicWhy}</small>` : ''}</button>
        ${!target.revealed && !b.over ? `<button ${observeOk ? '' : 'disabled'} data-observe="1" title="${observeWhy}">观察敌手 <span class="cost">念头 1 · 消耗本回合行动</span>${observeWhy ? `<small class="action-blocked">${observeWhy}</small>` : ''}</button>` : ''}
        ${(() => {
          const roster = currentCombatRoster(b.guUsedThisTurn, b.guSealed);
          const damageGu = roster.filter((g) => g.battleEffect?.kind === 'strike' || Number(g.battleEffect?.amount || 0) > 0);
          const qiLocked = damageGu.length > 0 && !damageGu.some((g) => state.qi >= Number(g.trueQiCost || 0));
          const exhaustOk = !b.over && state.thought >= 1 && !b.exhaustUsedThisTurn && !(b.exhaustCooldown > 0) && qiLocked;
          const exhaustWhy = b.exhaustUsedThisTurn ? '本回合已逆息'
            : b.exhaustCooldown > 0 ? `逆息冷却 ${b.exhaustCooldown} 回合`
            : !qiLocked ? '未陷入真元枯竭'
            : state.thought < 1 ? '念头不足' : '';
          return `<button ${exhaustOk ? '' : 'disabled'} data-exhaust="1" title="${exhaustWhy}">逆息（念头1 · 气血-2 · 真元+3）</button>`;
        })()}
        ${guButtons || '<div class="mr" style="font-size:12px;color:var(--ink-soft)">无可用蛊虫</div>'}
        <div class="colhead" style="margin-top:8px">杀招</div>
        ${buttons || '<div class="mr" style="font-size:12px;color:var(--ink-soft)">无可用杀招</div>'}
        <button class="ghost" data-end-turn="1" ${b.over ? 'disabled' : ''}>结束回合</button>
        <div class="mc" style="margin-top:14px;font-size:12px;color:var(--ink-soft)">
          护体 ${b.block} · 寿元 ${state.lifeTime} · 回合 ${b.turn}${target.revealed ? '' : ' · 未察'}${b.over ? ` · <span style="color:var(--cinnabar)">${b.over}</span>` : ''}
        </div>
        ${b.over === '胜' ? '' : `<button class="ghost" style="margin-top:16px" data-escape="1">脱离</button>`}
      </div>
      <div>
        <div class="colhead">战报</div>
        <div class="log" id="log">${b.log.map((l) => `<div>${l}</div>`).join('')}</div>
      </div>
    </div>`;

  root.querySelectorAll('[data-target]').forEach((el) =>
    el.addEventListener('click', () => act.setTarget(el.dataset.target)));
  root.querySelectorAll('[data-use]').forEach((el) =>
    el.addEventListener('click', () => act.useMove(el.dataset.use)));
  root.querySelectorAll('[data-use-gu]').forEach((el) =>
    el.addEventListener('click', () => act.useGu(el.dataset.useGu)));
  root.querySelector('[data-basic-attack]')?.addEventListener('click', () => act.basicAttack());
  root.querySelector('[data-observe]')?.addEventListener('click', () => act.observe());
  root.querySelector('[data-exhaust]')?.addEventListener('click', () => act.exhaust());
  root.querySelector('[data-end-turn]')?.addEventListener('click', () => act.endTurn());
  root.querySelector('[data-escape]')?.addEventListener('click', () => act.endBattle());
}
