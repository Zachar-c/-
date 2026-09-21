// Focused Web MVP UI. Rule transitions live in mvp_logic.js; this file renders and dispatches.
const Mvp = (() => {
  const content = globalThis.MVP_CONTENT;
  const rules = globalThis.MvpLogic;
  const guById = (id) => DATA.gu.find((gu) => gu.id === id) || null;
  const enemyById = (id) => DATA.enemies.find((enemy) => enemy.id === id) || null;

  /* 允许 ?seed=N 覆盖，这样自动走盘可以对同一套规则换种子重复验证。 */
  const requestedSeed = Number(new URLSearchParams(globalThis.location?.search || '').get('seed'));
  const baseSeed = Number.isFinite(requestedSeed) && requestedSeed > 0 ? requestedSeed : content.run.seed;

  let runSerial = 0;
  let run = rules.createRun(content, baseSeed);
  let battle = null;
  let toastTimer = null;

  const esc = (value) => String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

  const currentStep = () => content.encounters[run.stepIndex] || content.encounters.at(-1);
  const isBattleStep = (step = currentStep()) => ['battle', 'elite', 'boss'].includes(step.type);
  const portraitPath = (id) => `../assets/wenzhen/enemies/${enemyById(id).portrait}.png`;
  const guPath = (id) => `../assets/wenzhen/gu/${guById(id).icon}.png`;
  const cooldownKey = (id, index) => `${id}:${index}`;

  function pushLog(kind, label, detail) {
    run.runLog.push({ kind, label, detail });
  }

  function toast(text, tone = '') {
    const node = document.querySelector('#mvp-toast');
    node.textContent = text;
    node.className = `show ${tone}`;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { node.className = tone; }, 2200);
  }

  function rewardText(definition) {
    return rules.battleReward(DATA, definition.id);
  }

  function beginStep() {
    const step = currentStep();
    if (isBattleStep(step)) startBattle(step);
    else battle = null;
    render();
  }

  function startBattle(step) {
    const definition = enemyById(step.enemyId);
    const enemy = rules.startTurn(
      content,
      rules.createEnemy(content, definition.id),
      1,
      run.seed,
    ).enemy;
    run.thoughts = run.thoughtMax;
    battle = {
      step,
      definition,
      enemy,
      turn: 1,
      block: 0,
      damageReduction: 0,
      lightSupport: 0,
      used: {},
      cooldowns: {},
      actionOrder: [],
      currentGuIds: [],
      previousGuIds: [],
      sealedToday: {},
      sealedNext: {},
      usedLight: false,
      stoneShellUsed: false,
      attackedThisTurn: false,
      guUsedCount: 0,
      lastEnemyDamage: 0,
      observeCount: 0,
      damageTaken: 0,
      guUsage: {},
      log: [`${definition.name} 出现。`],
    };
  }

  function startEnemyTurnState() {
    const started = rules.startTurn(content, battle.enemy, battle.turn, run.seed);
    battle.enemy = started.enemy;
    if (started.phaseChanged) {
      battle.log.push(`<b>${battle.definition.name}</b> 转入第 ${started.phaseIndex + 1} 阶段。`);
    }
  }

  function smelt() {
    const result = rules.smeltStone(run);
    if (!result.ok) {
      return toast(result.reason === 'essence_full' ? '真元已满' : '没有可碎的元石', 'bad');
    }
    run = result.run;
    toast('元石 -1 · 真元 +2', 'good');
    render();
  }

  function actionBlockedReason(id, index) {
    const action = content.actions[id];
    const gu = guById(id);
    if (!action || !gu || !battle || battle.won || battle.enemy.hp <= 0) return '不可用';
    if (battle.sealedToday[id]) return '本回合被封印';
    if (battle.used[cooldownKey(id, index)]) return '本回合已用';
    const nextTurn = Number(battle.cooldowns[cooldownKey(id, index)] || 0);
    if (nextTurn > battle.turn) return `冷却至第 ${nextTurn} 回合`;
    if (run.thoughts < action.thought) return '念头不足';
    if (run.qi < effectiveQiCost(action)) return '真元不足';
    if (action.hp && run.hp <= action.hp) return '气血不足';
    return '';
  }

  function effectiveQiCost(action) {
    return rules.actionValues(action, battle?.lightSupport).qi;
  }

  function effectiveDamage(action) {
    return rules.actionValues(action, battle?.lightSupport).damage;
  }

  function markActionUsed(id, index) {
    battle.used[cooldownKey(id, index)] = true;
    battle.actionOrder.push(id);
    battle.currentGuIds.push(id);
    battle.guUsedCount += 1;
    battle.guUsage[id] = (battle.guUsage[id] || 0) + 1;
    const action = content.actions[id];
    if (action.cooldown > 0) {
      battle.cooldowns[cooldownKey(id, index)] = battle.turn + action.cooldown + 1;
    }
  }

  function useAction(id, index) {
    const blocked = actionBlockedReason(id, index);
    if (blocked) return toast(blocked, 'bad');
    const action = content.actions[id];
    const gu = guById(id);
    const supportActive = action.light && battle.lightSupport > 0;
    const values = rules.actionValues(action, battle.lightSupport);
    const qiCost = values.qi;
    run.thoughts -= action.thought;
    run.qi -= qiCost;
    if (action.hp) run.hp -= action.hp;

    if (supportActive && action.damage) {
      battle.log.push(`小光蛊支援生效：${gu.name} 真元 -${action.qi - qiCost}，伤害 +1。`);
    }
    if (supportActive && !action.inspect) battle.lightSupport = 0;
    if (action.light) battle.usedLight = true;
    markActionUsed(id, index);

    if (action.inspect) {
      const alreadyKnown = battle.enemy.revealed;
      battle.enemy = rules.revealCounter(battle.enemy);
      battle.lightSupport += 1;
      /* 只有真正揭示了新信息才计入观察成本：小光蛊平时是当光道支援用的，
         把它每次都算成「观察」会让信息税看起来比实际高。 */
      if (!alreadyKnown) battle.observeCount += 1;
      battle.log.push(`<b>${gu.name}</b> 照见当前反制。`);
    }
    if (action.block) {
      battle.block += action.block;
      if (action.chargeGuard) battle.stoneShellUsed = true;
      battle.log.push(`<b>${gu.name}</b> 护体 +${action.block}。`);
    }
    if (action.heal) {
      run.hp = Math.min(run.hpMax, run.hp + action.heal);
      battle.log.push(`<b>${gu.name}</b> 回气 +${action.heal}。`);
    }
    if (action.damage) {
      battle.attackedThisTurn = true;
      const wounded = battle.lastEnemyDamage > 0;
      const damage = id === 'white_boar_strength_gu' && wounded
        ? action.woundedDamage
        : values.damage;
      const suppress = id === 'moon_glow_gu' && battle.enemy.revealed;
      const bypassCounter = suppress || (id === 'white_boar_strength_gu' && wounded);
      const hit = rules.resolveDirectStrike(battle.enemy, {
        damage,
        bypassCounter,
        suppressCounter: suppress,
      });
      battle.enemy = hit.enemy;
      if (hit.swallowed) {
        const counter = rules.counterRule(content, hit.counterId);
        battle.log.push(`<b>${gu.name}</b> 被「${counter?.label || '反制'}」吞掉，未造成伤害。`);
        if (hit.selfDamage) {
          run.hp = Math.max(0, run.hp - hit.selfDamage);
          battle.damageTaken += hit.selfDamage;
          battle.log.push(`迎击反伤 ${hit.selfDamage} 气血。`);
        }
        if (hit.ironRage) {
          battle.log.push(`铁皮未破；下一次冲撞 +${hit.ironRage}。`);
        }
      } else {
        battle.log.push(`<b>${gu.name}</b> 命中，伤 ${hit.damage}${suppress ? '，并压制当前反制与特殊效果' : ''}。`);
      }
    }

    if (run.hp <= 0) return loseRun('月芒耗尽了最后一点气血。');
    settleBattleIfDead();
    render();
  }

  function observe() {
    if (!battle || battle.won || run.thoughts < 1 || battle.enemy.revealed) return;
    run.thoughts -= 1;
    battle.enemy = rules.revealCounter(battle.enemy);
    battle.observeCount += 1;
    battle.log.push(`观察成功：当前反制为「${rules.counterRule(content, battle.enemy.currentCounter)?.label || '无'}」。`);
    render();
  }

  function defend() {
    if (!battle || battle.won || run.thoughts < 1) return;
    run.thoughts -= 1;
    battle.damageReduction += 2;
    battle.log.push('收势：本回合受到的敌方伤害 -2。');
    render();
  }

  function settleBattleIfDead() {
    if (!battle || battle.enemy.hp > 0) return false;
    battle.won = true;
    const reward = rewardText(battle.definition);
    run.stones += reward;
    /* V4：普通战胜利恢复 2 气血 / 2 真元（唯一生存校准阀门，不做节点/UI/选择）。 */
    run = rules.applyVictoryRecovery(run, content);
    pushLog('battle', battle.step.title, `${battle.definition.name} 伏诛；元石 +${reward}，气血 +2，真元 +2。`);
    battle.log.push(`<b>${battle.definition.name}</b> 伏诛。元石 +${reward}，战后恢复 2 气血 / 2 真元。`);
    toast(`伏诛 · 元石 +${reward} · 气血 +2 · 真元 +2`, 'good');
    return true;
  }

  function endTurn() {
    if (!battle || battle.won || battle.enemy.hp <= 0) return;
    const intent = battle.enemy.currentIntent;
    const counterId = battle.enemy.currentCounter;
    const resolved = rules.resolveEnemyAction(
      battle.enemy,
      {
        hp: run.hp,
        qi: run.qi,
        block: battle.block,
      },
      {
        intent,
        usedLight: battle.usedLight,
        damageReduction: battle.damageReduction,
        stoneShellUsed: battle.stoneShellUsed,
        attacked: battle.attackedThisTurn,
        guUsedCount: battle.guUsedCount,
      },
    );
    run.hp = resolved.player.hp;
    run.qi = resolved.player.qi;
    battle.block = resolved.player.block;
    battle.lastEnemyDamage = resolved.damage;
    battle.damageTaken += resolved.damage;
    battle.enemy = resolved.enemy;

    const counter = rules.counterRule(content, counterId);
    if (resolved.handled) {
      battle.log.push(`已正确处理反制「${counter?.label || counterId}」：本次敌方伤害 -3。`);
    }

    if (!intent || intent.tag === 'wait') {
      battle.log.push(`<b>${battle.definition.name}</b> 蓄势不动。`);
    } else {
      let extra = '';
      if (counterId === 'draw_light' && !battle.usedLight) extra = '（逐光未破）';
      if (intent.tag === 'charge' && battle.enemy.ironRage > 0) extra = `（铁皮积威 +${battle.enemy.ironRage}）`;
      battle.log.push(`<b>${intent.label}</b>${extra}：伤 ${resolved.damage}${resolved.blocked ? `（护体挡下 ${resolved.blocked}）` : ''}。`);
      if (counter && counterId === 'draw_light') {
        battle.log.push(battle.usedLight ? '逐光条件已满足。' : '逐光条件未满足，扑击伤害提高。');
      }
      if (resolved.qiLoss) battle.log.push(`真元被夺 ${resolved.qiLoss}。`);
      if (resolved.specialSuppressed) battle.log.push('月芒压制生效，特殊效果没有发生。');
      else if (resolved.handled && intent.kind) battle.log.push('反制已被正确处理，特殊效果没有发生。');
      if (intent.kind === 'seal' && !resolved.specialCancelled) {
        const target = rules.sealTarget(counterId, battle.actionOrder);
        if (target) {
          battle.sealedNext[target] = true;
          battle.log.push(`${counter?.label || '封脉'}：${guById(target)?.name || target} 下回合被封印。`);
        }
      }
      if (battle.stoneShellUsed && intent.tag === 'charge') {
        battle.log.push('石皮承受冲撞，铁皮在下一回合失效。');
      }
    }

    if (run.hp <= 0) return loseRun(`${battle.definition.name} 造成了致命伤害。`);

    if (battle.definition.id === 'thunder_crown_sovereign' && rules.phaseIndexFor(content, battle.enemy) === 1) {
      const repeated = rules.repeatingGuIds(battle.previousGuIds, battle.currentGuIds);
      for (const id of repeated) {
        battle.sealedNext[id] = true;
        battle.log.push(`雷冠记招：重复使用的 ${guById(id)?.name || id} 下回合被封印。`);
      }
    }
    battle.previousGuIds = [...battle.currentGuIds];
    battle.currentGuIds = [];
    battle.enemy = rules.finishEnemyAction(battle.enemy);
    battle.turn += 1;
    battle.used = {};
    battle.cooldowns = { ...battle.cooldowns };
    battle.actionOrder = [];
    battle.sealedToday = { ...battle.sealedNext };
    battle.sealedNext = {};
    battle.lightSupport = 0;
    battle.damageReduction = 0;
    battle.usedLight = false;
    battle.stoneShellUsed = false;
    battle.attackedThisTurn = false;
    battle.guUsedCount = 0;
    battle.block = 0;
    run.thoughts = run.thoughtMax;
    startEnemyTurnState();
    battle.log.push(`— 第 ${battle.turn} 回合 —`);
    render();
  }

  function chooseTrade(id) {
    const result = rules.applyTrade(run, id, content);
    if (!result.ok) return toast('这条路现在走不通', 'bad');
    run = result.run;
    toast(`已选择 · ${content.tradeOptions.find((option) => option.id === id).label}`, 'good');
    run.stepIndex += 1;
    beginStep();
  }

  function chooseForge(choice) {
    const result = rules.applyForge(run, choice, content);
    if (!result.ok) {
      const reason = result.reason === 'insufficient_essence' ? '真元不足，无法正炼' : '原料不足，无法正炼';
      return toast(choice === 'forge' ? reason : '选择无效', 'bad');
    }
    run = result.run;
    toast(choice === 'forge' ? '正炼完成' : '保炉 · 元石 +3', 'good');
    run.stepIndex += 1;
    beginStep();
  }

  function restart() {
    runSerial += 1;
    run = rules.createRun(content, baseSeed + runSerial);
    battle = null;
    beginStep();
  }

  function loseRun(detail) {
    run.hp = 0;
    run.result = { won: false, title: '气血耗尽', detail };
    run.stepIndex = content.encounters.length - 1;
    battle = null;
    renderEnding();
  }

  function smeltButton() {
    return `<button class="plain smelt" data-smelt ${run.stones > 0 && run.qi < run.qiMax ? '' : 'disabled'}>
      碎石还元 · 元石 1 → 真元 2
    </button>`;
  }

  function renderHud() {
    const borrowed = run.borrowedMoon ? '<span class="wound">道伤 · 真元上限 8</span>' : '';
    document.querySelector('#mvp-hud').innerHTML = `
      <div class="brand">
        <span class="brand-name">问真</span>
        <span class="phase-count">第 ${Math.min(currentStep().order, 6)} / 6 段</span>
      </div>
      <div class="resources">
        <span><b>气血</b>${run.hp}/${run.hpMax}</span>
        <span><b>真元</b>${run.qi}/${run.qiMax}</span>
        <span><b>念头</b>${run.thoughts}/${run.thoughtMax}</span>
        <span><b>元石</b>${run.stones}</span>
        ${borrowed}
      </div>
      <button class="plain" data-restart>重开</button>`;
    document.querySelector('[data-restart]').addEventListener('click', restart);
  }

  function actionLabel(id, index) {
    const action = content.actions[id];
    const qi = effectiveQiCost(action);
    const hp = action.hp ? ` · 气血 ${action.hp}` : '';
    const cd = action.cooldown ? ` · 冷却 ${action.cooldown}` : '';
    const support = action.light && battle.lightSupport > 0 ? ' · 小光支援' : '';
    return `真元 ${qi} · 念头 ${action.thought}${hp}${cd}${support}`;
  }

  function renderActions() {
    return Object.entries(run.owned).flatMap(([id, count]) => {
      const action = content.actions[id];
      const gu = guById(id);
      if (!action || !gu) return [];
      return Array.from({ length: count }, (_, index) => {
        const reason = actionBlockedReason(id, index);
        const damage = action.damage
          ? `伤 ${id === 'white_boar_strength_gu' && battle.lastEnemyDamage > 0 ? action.woundedDamage : effectiveDamage(action)}`
          : '';
        const detail = [
          damage,
          action.block ? `护体 ${action.block}` : '',
          action.heal ? `回气 ${action.heal}` : '',
          action.inspect ? '照见反制' : '',
          action.support ? '下一只光道 +1 伤 / -1 真元' : '',
        ].filter(Boolean).join(' · ');
        return `
          <button class="gu-action" ${reason ? 'disabled' : ''} data-use-gu="${id}" data-instance="${index}">
            <img src="${guPath(id)}" alt="">
            <span><b>${esc(action.label)}</b><em>${esc(detail)}</em></span>
            <small>${esc(reason || actionLabel(id, index))}</small>
          </button>`;
      });
    }).join('');
  }

  function renderBattle() {
    const enemy = battle.enemy;
    const definition = battle.definition;
    const intel = content.intel[definition.id];
    const counter = rules.counterRule(content, enemy.currentCounter);
    const phase = rules.phaseIndexFor(content, enemy) + 1;
    const hpPct = Math.max(0, enemy.hp / enemy.hpMax * 100);
    const suppress = enemy.suppressed ? '月芒压制中' : '';
    const intentText = enemy.currentIntent?.label || '无';
    const revealedCounter = enemy.revealed && counter
      ? `${counter.label}：${counter.detail}`
      : enemy.revealed ? '无反制' : '未知';

    if (battle.won) {
      document.querySelector('#mvp-app').innerHTML = `
        <section class="outcome">
          <div class="outcome-mark">伏诛</div>
          <img src="${portraitPath(definition.id)}" alt="">
          <h1>${esc(definition.name)}</h1>
          <p>战利已入袋。气血没有恢复，真元只回了 2。</p>
          <div class="outcome-stats">
            <span>元石 +${rewardText(definition)}</span>
            <span>气血 ${run.hp}/${run.hpMax}</span>
            <span>真元 ${run.qi}/${run.qiMax}</span>
          </div>
          ${smeltButton()}
          <button class="primary" data-next-step>继续</button>
        </section>`;
      document.querySelector('[data-smelt]')?.addEventListener('click', smelt);
      document.querySelector('[data-next-step]').addEventListener('click', () => {
        run.stepIndex += 1;
        beginStep();
      });
      return;
    }

    document.querySelector('#mvp-app').innerHTML = `
      <section class="battle-layout">
        <div class="enemy-sheet">
          <div class="section-label">${esc(battle.step.title)} · ${phase}/2 阶段</div>
          <div class="enemy-art"><img src="${portraitPath(definition.id)}" alt=""><span class="enemy-rank">${definition.rank} 转</span></div>
          <h1>${esc(definition.name)}</h1>
          <div class="hp-line"><i style="width:${hpPct}%"></i></div>
          <div class="enemy-hp">气血 ${enemy.hp} / ${enemy.hpMax}</div>
          <dl class="intel">
            <div><dt>下一行动</dt><dd>${esc(intentText)}${enemy.currentIntent?.damage ? ` · 预计 ${enemy.currentIntent.damage + (enemy.currentIntent.tag === 'charge' ? enemy.ironRage : 0)} 伤` : ''}</dd></div>
            <div><dt>已知弱点</dt><dd>${esc(intel.known)}</dd></div>
            <div><dt>未察信息</dt><dd>${esc(intel.unknown)}</dd></div>
            <div><dt>反制</dt><dd>${esc(revealedCounter)}</dd></div>
            ${suppress ? `<div><dt>状态</dt><dd>${suppress}</dd></div>` : ''}
            ${enemy.ironRage ? `<div><dt>铁皮积威</dt><dd>下一次冲撞 +${enemy.ironRage}</dd></div>` : ''}
          </dl>
        </div>
        <div class="battle-controls">
          <div class="turn-line"><span>第 ${battle.turn} 回合</span><span>护体 ${battle.block} · 减伤 ${battle.damageReduction}</span></div>
          <div class="support-line">${battle.lightSupport ? `小光支援待用 · ${battle.lightSupport}` : '小光支援：无'}</div>
          <div class="action-grid">${renderActions()}</div>
          <div class="basic-actions">
            <button ${run.thoughts >= 1 && !enemy.revealed ? '' : 'disabled'} data-observe>观察 <small>念头 1 · 揭示本回合反制</small></button>
            <button ${run.thoughts >= 1 ? '' : 'disabled'} data-defend>收势 <small>念头 1 · 本回合伤害 -2</small></button>
            <button data-end-turn>结束回合</button>
          </div>
        </div>
        <aside class="combat-log">
          <div class="section-label">战报</div>
          ${battle.log.slice(-11).map((line) => `<p>${line}</p>`).join('')}
        </aside>
      </section>`;

    document.querySelectorAll('[data-use-gu]').forEach((button) => {
      button.addEventListener('click', () => useAction(button.dataset.useGu, Number(button.dataset.instance)));
    });
    document.querySelector('[data-observe]')?.addEventListener('click', observe);
    document.querySelector('[data-defend]')?.addEventListener('click', defend);
    document.querySelector('[data-end-turn]')?.addEventListener('click', endTurn);
  }

  function renderBazaar() {
    const options = content.tradeOptions.map((option) => {
      const blocked = Number(option.cost?.stones || 0) > run.stones
        || !rules.canPay(run.owned, option.cost?.gu || {});
      return `
        <button class="choice-card ${blocked ? 'blocked' : ''}" ${blocked ? 'disabled' : ''} data-trade="${option.id}">
          <span class="choice-index">${option.id === 'secure' ? '甲' : option.id === 'sacrifice' ? '乙' : '丙'}</span>
          <b>${esc(option.label)}</b>
          <em>${esc(option.promise)}</em>
          <strong>${esc(option.consequence)}</strong>
          <small>${blocked ? '当前条件不足' : '选择后不可反悔'}</small>
        </button>`;
    }).join('');
    document.querySelector('#mvp-app').innerHTML = `
      <section class="choice-screen">
        <div class="section-label">交换 · 你准备让未来的自己缺什么</div>
        <h1>大巴扎</h1>
        <p class="screen-lead">元石不是钱，是尚未兑现的真元。</p>
        ${smeltButton()}
        <div class="choice-grid">${options}</div>
      </section>`;
    document.querySelector('[data-smelt]')?.addEventListener('click', smelt);
    document.querySelectorAll('[data-trade]').forEach((button) => {
      button.addEventListener('click', () => chooseTrade(button.dataset.trade));
    });
  }

  function renderForge() {
    const hasIngredients = rules.canPay(run.owned, content.forge.consume);
    const canForge = hasIngredients && run.qi >= content.forge.qiCost;
    const borrowLine = run.borrowedMoon
      ? '正炼不获得第二只月芒；改为解除道伤，真元上限恢复至 12。'
      : '月光 + 小光 + 2 真元 → 稳定月芒蛊。';
    document.querySelector('#mvp-app').innerHTML = `
      <section class="choice-screen">
        <div class="section-label">合炼 · 改变规则，或保存未来</div>
        <h1>炼蛊台</h1>
        <p class="screen-lead">${esc(borrowLine)}</p>
        ${smeltButton()}
        <div class="forge-grid">
          <button class="forge-card" ${canForge ? '' : 'disabled'} data-forge>
            <div class="recipe-line">
              <img src="${guPath('moonlight_gu')}" alt=""><span>月光蛊</span><b>+</b>
              <img src="${guPath('small_light_gu')}" alt=""><span>小光蛊</span><b>+</b>
              <b>2 真元</b><b>→</b>
              <img src="${guPath('moon_glow_gu')}" alt=""><span>${run.borrowedMoon ? '解除道伤' : '月芒蛊'}</span>
            </div>
            <strong>${esc(content.forge.rule)}</strong>
            <small>${canForge ? '原料与真元齐备' : hasIngredients ? '真元不足' : '原料不足'}</small>
          </button>
          <button class="forge-card preserve" data-preserve>
            <div class="preserve-mark">留</div>
            <b>保炉</b>
            <strong>不消耗蛊虫，获得 ${content.forge.preserveStones} 元石。</strong>
            <small>保留工具箱与未来真元储备。</small>
          </button>
        </div>
      </section>`;
    document.querySelector('[data-smelt]')?.addEventListener('click', smelt);
    document.querySelector('[data-forge]')?.addEventListener('click', () => chooseForge('forge'));
    document.querySelector('[data-preserve]').addEventListener('click', () => chooseForge('preserve'));
  }

  function renderEnding() {
    const result = run.result || { won: true, title: '走完一局', detail: '你从山道走到了雷冠封路。' };
    const owned = Object.entries(run.owned)
      .filter(([, count]) => count > 0)
      .map(([id, count]) => `${guById(id)?.name || id}×${count}`)
      .join('、');
    document.querySelector('#mvp-hud').innerHTML = `
      <div class="brand"><span class="brand-name">问真</span><span class="phase-count">本局结算</span></div>
      <div class="resources"><span><b>气血</b>${run.hp}/${run.hpMax}</span><span><b>真元</b>${run.qi}/${run.qiMax}</span><span><b>元石</b>${run.stones}</span></div>
      <button class="plain" data-restart>重开</button>`;
    document.querySelector('[data-restart]').addEventListener('click', restart);
    document.querySelector('#mvp-app').innerHTML = `
      <section class="ending-screen">
        <div class="section-label">终局 · 所见即所得</div>
        <h1>${esc(result.title)}</h1>
        <p class="screen-lead">${esc(result.detail)}</p>
        <div class="ending-summary">
          <div><span>最终构筑</span><b>${esc(owned)}</b></div>
          <div><span>剩余资源</span><b>气血 ${run.hp} · 真元 ${run.qi}/${run.qiMax} · 元石 ${run.stones}</b></div>
        </div>
        <div class="run-trail">
          ${run.runLog.map((entry) => `<div><span>${esc(entry.kind)}</span><b>${esc(entry.label)}</b><em>${esc(entry.detail)}</em></div>`).join('')}
        </div>
        <button class="primary" data-restart-bottom>再试另一条路</button>
      </section>`;
    document.querySelector('[data-restart-bottom]').addEventListener('click', restart);
  }

  function render() {
    renderHud();
    const step = currentStep();
    if (step.type === 'ending') return renderEnding();
    if (isBattleStep(step)) return renderBattle();
    if (step.type === 'bazaar') return renderBazaar();
    if (step.type === 'forge') return renderForge();
    return renderEnding();
  }

  /* 只读快照，供自动走盘记录逐场指标（HP/Qi/Stone/turnCount/observeCount/
     damageTaken/guUsage）。页面渲染不依赖它。 */
  function stats() {
    return {
      seed: run.seed,
      stepId: currentStep().id,
      stepIndex: run.stepIndex,
      hp: run.hp,
      hpMax: run.hpMax,
      qi: run.qi,
      qiMax: run.qiMax,
      stones: run.stones,
      tradeChoice: run.tradeChoice,
      forgeChoice: run.forgeChoice,
      borrowedMoon: run.borrowedMoon,
      owned: { ...run.owned },
      ended: !!run.result,
      result: run.result ? { ...run.result } : null,
      runLog: run.runLog.map((entry) => ({ ...entry })),
      battle: battle ? {
        enemyId: battle.definition.id,
        enemyHp: battle.enemy.hp,
        enemyHpMax: battle.enemy.hpMax,
        turn: battle.turn,
        won: !!battle.won,
        revealed: !!battle.enemy.revealed,
        currentCounter: battle.enemy.currentCounter || '',
        knownCounters: [...(battle.enemy.knownCounters || [])],
        intent: battle.enemy.currentIntent ? { ...battle.enemy.currentIntent } : null,
        lightSupport: battle.lightSupport,
        block: battle.block,
        observeCount: battle.observeCount,
        damageTaken: battle.damageTaken,
        guUsage: { ...battle.guUsage },
      } : null,
    };
  }

  return { start: beginStep, stats };
})();

Mvp.start();
