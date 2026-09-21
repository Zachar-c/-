// Focused Web MVP. All rule transitions live in mvp_logic.js; this file renders and dispatches.
const Mvp = (() => {
  const content = globalThis.MVP_CONTENT;
  const rules = globalThis.MvpLogic;
  const guById = (id) => DATA.gu.find((gu) => gu.id === id) || null;
  const enemyById = (id) => DATA.enemies.find((enemy) => enemy.id === id) || null;

  let run = rules.createRun(content);
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

  function rewardText(enemy) {
    return rules.battleReward(enemy, DATA.battle.stoneRewards);
  }

  function beginStep() {
    const step = currentStep();
    if (isBattleStep(step)) {
      startBattle(step);
    } else {
      battle = null;
    }
    render();
  }

  function startBattle(step) {
    run = rules.applyNextBattlePenalty(run);
    run.thoughts = run.thoughtMax;
    const definition = enemyById(step.enemyId);
    let enemy = rules.createEnemy(definition);
    enemy = rules.syncIntent(definition, enemy, 1).enemy;
    battle = {
      step,
      definition,
      enemy,
      turn: 1,
      block: 0,
      support: {},
      used: {},
      killMoveUsed: false,
      log: [`${definition.name} 出现。`],
    };
  }

  function syncEnemyPhase() {
    if (!battle?.enemy) return;
    const synced = rules.syncIntent(battle.definition, battle.enemy, battle.turn);
    if (synced.phaseChanged) {
      battle.log.push(`<b>${battle.definition.name}</b> 转入第 ${synced.phase.index + 1} 阶段。`);
    }
    battle.enemy = synced.enemy;
  }

  function spendGu(id, instanceIndex) {
    battle.used[`${id}:${instanceIndex}`] = true;
  }

  function guUsed(id, instanceIndex) {
    return !!battle.used[`${id}:${instanceIndex}`];
  }

  function firstUnusedInstance(id) {
    const count = Number(run.owned[id] || 0);
    for (let i = 0; i < count; i += 1) if (!guUsed(id, i)) return i;
    return -1;
  }

  function directAttack(damage, options = {}) {
    const result = rules.resolveDirectStrike(battle.definition, battle.enemy, {
      damage,
      bypassReaction: !!options.bypassReaction,
      suppressReaction: !!options.suppressReaction,
      turn: battle.turn,
    });
    battle.enemy = result.enemy;
    if (result.swallowed) {
      battle.log.push(`直接攻击被 <b>${esc(result.reactionLabel)}</b> 吞掉，没有造成伤害。`);
      return result;
    }
    if (result.damage > 0) {
      battle.log.push(`命中 <b>${esc(battle.definition.name)}</b>，伤 ${result.damage}。`);
    }
    if (result.suppressed) battle.log.push(`月芒压制了 <b>${esc(result.reactionLabel)}</b>。`);
    syncEnemyPhase();
    return result;
  }

  function settleBattleIfDead() {
    if (battle.enemy.hp > 0) return false;
    battle.won = true;
    const reward = rewardText(battle.definition);
    run.stones += reward;
    run.hp = Math.min(run.hpMax, run.hp + Math.ceil(run.hpMax * 0.3));
    run.qi = run.qiMax;
    pushLog('battle', battle.step.title, `${battle.definition.name} 伏诛；元石 +${reward}。`);
    battle.log.push(`<b>${battle.definition.name}</b> 伏诛。元石 +${reward}，真元回满，气血恢复。`);
    toast(`伏诛 · 元石 +${reward}`, 'good');
    return true;
  }

  function applyPlan(plan, label) {
    if (plan.heal) {
      run.hp = Math.min(run.hpMax, run.hp + plan.heal);
      battle.log.push(`<b>${label}</b> 回气 +${plan.heal}。`);
    }
    if (plan.block) {
      battle.block += plan.block;
      battle.log.push(`<b>${label}</b> 护体 +${plan.block}。`);
    }
    if (plan.intentWeaken) {
      battle.intentWeaken = Number(battle.intentWeaken || 0) + plan.intentWeaken;
      battle.log.push(`<b>${label}</b> 弱化敌方意图 ${plan.intentWeaken}。`);
    }
    if (plan.support) {
      battle.support[plan.support.school] = Number(battle.support[plan.support.school] || 0)
        + plan.support.bonus;
    }
  }

  function pay(actionCost) {
    if (run.thoughts < actionCost.thought) return false;
    if (run.qi < actionCost.qi) return false;
    run.thoughts -= actionCost.thought;
    run.qi -= actionCost.qi;
    return true;
  }

  function canUseGu(id, instanceIndex) {
    const gu = guById(id);
    if (!gu || !battle || battle.won || battle.enemy.hp <= 0) return false;
    if (guUsed(id, instanceIndex)) return false;
    if (run.thoughts < Number(gu.thoughtCost || 0)) return false;
    if (run.qi < Number(gu.trueQiCost || 0)) return false;
    return true;
  }

  function useGu(id, instanceIndex) {
    const gu = guById(id);
    if (!canUseGu(id, instanceIndex)) return;
    pay({ qi: Number(gu.trueQiCost || 0), thought: Number(gu.thoughtCost || 0) });
    spendGu(id, instanceIndex);
    const plan = GuRules.effectPlan(gu.battleEffect, {
      school: gu.school,
      supports: battle.support,
      statusStacks: {},
    });
    battle.log.push(`催动 <b>${gu.name}</b>：真元 -${gu.trueQiCost}，念头 -${gu.thoughtCost}。`);
    if (plan.damage > 0) {
      directAttack(plan.damage, {
        bypassReaction: id === 'moon_glow_gu',
        suppressReaction: id === 'moon_glow_gu',
      });
    }
    applyPlan({ ...plan, damage: 0 }, gu.name);
    settleBattleIfDead();
    render();
  }

  function basicAttack() {
    if (!battle || battle.won || run.thoughts < 1) return;
    run.thoughts -= 1;
    battle.log.push('拳脚直取。');
    directAttack(Number(DATA.battle.fightDamageBase || 1));
    settleBattleIfDead();
    render();
  }

  function useKillMove() {
    if (!battle || battle.won || battle.killMoveUsed) return;
    const move = DATA.killMoves.find((entry) => entry.id === 'km_light_converge');
    if (!move) return;
    const moon = firstUnusedInstance('moonlight_gu');
    const light = firstUnusedInstance('small_light_gu');
    if (moon < 0 || light < 0) return toast('配方蛊本回合已用', 'bad');
    if (!pay({ qi: Number(move.true_qi_cost), thought: Number(move.thought_cost) })) {
      return toast('真元或念头不足', 'bad');
    }
    spendGu('moonlight_gu', moon);
    spendGu('small_light_gu', light);
    battle.killMoveUsed = true;
    battle.log.push(`凝光：真元 -${move.true_qi_cost}，念头 -${move.thought_cost}，配方蛊本回合锁定。`);
    directAttack(Number(move.effect.amount || 0));
    settleBattleIfDead();
    render();
  }

  function observe() {
    if (!battle || battle.won || battle.enemy.revealed || run.thoughts < 1) return;
    run.thoughts -= 1;
    battle.enemy.revealed = true;
    battle.log.push(`凝神观察 <b>${battle.definition.name}</b>，看穿了它的反制。`);
    render();
  }

  function endTurn() {
    if (!battle || battle.won || battle.enemy.hp <= 0) return;
    const intent = battle.enemy.currentIntent;
    if (!intent) {
      battle.log.push(`<b>${battle.definition.name}</b> 蓄势不动。`);
    } else {
      const weaken = Math.max(0, Number(battle.intentWeaken || 0));
      const resolvedIntent = weaken
        ? { ...intent, damage: Math.max(0, Number(intent.damage || 0) - weaken) }
        : intent;
      if (weaken) {
        battle.log.push(`意图弱化生效，伤害 -${weaken}。`);
        battle.intentWeaken = 0;
      }
      const result = rules.resolveEnemyIntent(battle.enemy, resolvedIntent, {
        hp: run.hp,
        qi: run.qi,
        block: battle.block,
      });
      run.hp = result.player.hp;
      run.qi = result.player.qi;
      battle.block = result.player.block;
      battle.enemy = rules.markIntentUsed(
        battle.enemy,
        intent,
        battle.turn,
      );
      const damageText = result.blocked
        ? `伤 ${result.damage}（护体挡下 ${result.blocked}）`
        : `伤 ${result.damage}`;
      battle.log.push(`<b>${esc(intent.label)}</b>：${damageText}。`);
      if (result.essenceBurn > 0) battle.log.push(`真元被焚 ${result.essenceBurn}。`);
    }

    if (run.hp <= 0) {
      run.hp = 0;
      run.result = {
        won: false,
        title: '气血耗尽',
        detail: `${battle.definition.name} 还在场上，你的道路止于这一战。`,
      };
      renderEnding();
      return;
    }

    battle.enemy = rules.tickReactionSuppression(battle.enemy);
    battle.turn += 1;
    battle.used = {};
    battle.killMoveUsed = false;
    battle.support = {};
    run.thoughts = run.thoughtMax;
    run.qi = Math.min(run.qiMax, run.qi + Math.ceil(run.qiMax * 0.25));
    syncEnemyPhase();
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
    if (!result.ok) return toast(choice === 'forge' ? '原料不足，无法开炉' : '选择无效', 'bad');
    run = result.run;
    toast(choice === 'forge' ? '月芒已成' : '保炉 · 元石 +3', 'good');
    run.stepIndex += 1;
    beginStep();
  }

  function restart() {
    run = rules.createRun(content);
    battle = null;
    beginStep();
  }

  function renderHud() {
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
      </div>
      <button class="plain" data-restart>重开</button>`;
    document.querySelector('[data-restart]').addEventListener('click', restart);
  }

  function renderBattle() {
    const enemy = battle.enemy;
    const definition = battle.definition;
    const intel = content.intel[definition.id] || { known: '线索未明。', unknown: '尚未看清。' };
    const reaction = rules.reactionState(battle.definition, enemy).reaction;
    const phase = rules.phaseDataFor(definition, enemy.hp / enemy.hpMax);
    const hpPct = Math.max(0, enemy.hp / enemy.hpMax * 100);

    if (battle.won) {
      document.querySelector('#mvp-app').innerHTML = `
        <section class="outcome">
          <div class="outcome-mark">伏诛</div>
          <img src="${portraitPath(definition.id)}" alt="">
          <h1>${esc(definition.name)}</h1>
          <p>战利已入袋。下一段路已经显出来。</p>
          <div class="outcome-stats">
            <span>元石 +${rewardText(definition)}</span>
            <span>气血 ${run.hp}/${run.hpMax}</span>
            <span>真元 ${run.qi}/${run.qiMax}</span>
          </div>
          <button class="primary" data-next-step>继续</button>
        </section>`;
      document.querySelector('[data-next-step]').addEventListener('click', () => {
        run.stepIndex += 1;
        beginStep();
      });
      return;
    }

    const guInstances = Object.entries(run.owned).flatMap(([id, count]) => {
      const gu = guById(id);
      if (!gu?.combat || gu.combat === 'none') return [];
      return Array.from({ length: count }, (_, index) => ({ gu, index }))
        .map(({ gu: item, index }) => {
          const used = guUsed(item.id, index);
          const available = canUseGu(item.id, index);
          const reason = used ? '本回合已用' : run.qi < item.trueQiCost ? '真元不足' : run.thoughts < item.thoughtCost ? '念头不足' : '';
          return `
            <button class="gu-action" ${available ? '' : 'disabled'} data-use-gu="${item.id}" data-instance="${index}">
              <img src="${guPath(item.id)}" alt="">
              <span><b>${esc(item.name)}</b><em>${esc(effectText(item.battleEffect))}</em></span>
              <small>真元 ${item.trueQiCost} · 念头 ${item.thoughtCost}${reason ? ` · ${reason}` : ''}</small>
            </button>`;
        });
    }).join('');

    const move = DATA.killMoves.find((entry) => entry.id === 'km_light_converge');
    const moonAvailable = firstUnusedInstance('moonlight_gu') >= 0;
    const lightAvailable = firstUnusedInstance('small_light_gu') >= 0;
    const moveReady = moonAvailable && lightAvailable
      && run.qi >= Number(move.true_qi_cost)
      && run.thoughts >= Number(move.thought_cost)
      && !battle.killMoveUsed;
    const intentLabel = enemy.currentIntent ? intentText(enemy.currentIntent) : '冷却中 · 暂不出手';
    const reactionText = !reaction
      ? '无明确反制。'
      : !enemy.revealed
        ? '未知反制。'
        : enemy.reactionSettled
          ? `${reaction.label} · 已失效`
          : Number(enemy.reactionSuppressed) > 0
            ? `${reaction.label} · 已被月芒压制`
            : `${reaction.label} · 会吞掉直接攻击`;

    document.querySelector('#mvp-app').innerHTML = `
      <section class="battle-layout">
        <div class="enemy-sheet">
          <div class="section-label">${esc(battle.step.title)} · ${phase.index + 1}/${phase.total} 阶段</div>
          <div class="enemy-art">
            <img src="${portraitPath(definition.id)}" alt="">
            <span class="enemy-rank">${definition.rank} 转</span>
          </div>
          <h1>${esc(definition.name)}</h1>
          <div class="hp-line"><i style="width:${hpPct}%"></i></div>
          <div class="enemy-hp">气血 ${enemy.hp} / ${enemy.hpMax}</div>
          <dl class="intel">
            <div><dt>下一行动</dt><dd>${esc(intentLabel)}</dd></div>
            <div><dt>已知弱点</dt><dd>${esc(intel.known)}</dd></div>
            <div><dt>未知信息</dt><dd>${esc(enemy.revealed ? reactionText : intel.unknown)}</dd></div>
            ${enemy.revealed ? `<div><dt>反制</dt><dd>${esc(reactionText)}</dd></div>` : ''}
          </dl>
        </div>

        <div class="battle-controls">
          <div class="turn-line">
            <span>第 ${battle.turn} 回合</span>
            <span>护体 ${battle.block}</span>
          </div>
          <div class="action-grid">${guInstances}</div>
          <button class="kill-move ${moveReady ? '' : 'muted'}" ${moveReady ? '' : 'disabled'} data-kill-move>
            <span><b>${esc(move.label)}</b><em>${esc(effectText(move.effect))} · 配方蛊本回合锁定</em></span>
            <small>真元 ${move.true_qi_cost} · 念头 ${move.thought_cost}</small>
          </button>
          <div class="basic-actions">
            <button ${run.thoughts >= 1 ? '' : 'disabled'} data-basic>拳脚 <small>伤 ${DATA.battle.fightDamageBase || 1} · 念头 1</small></button>
            <button ${!enemy.revealed && run.thoughts >= 1 ? '' : 'disabled'} data-observe>观察 <small>念头 1</small></button>
            <button data-end-turn>结束回合</button>
          </div>
        </div>

        <aside class="combat-log">
          <div class="section-label">战报</div>
          ${battle.log.slice(-10).map((line) => `<p>${line}</p>`).join('')}
        </aside>
      </section>`;

    document.querySelectorAll('[data-use-gu]').forEach((button) => {
      button.addEventListener('click', () => useGu(button.dataset.useGu, Number(button.dataset.instance)));
    });
    document.querySelector('[data-kill-move]')?.addEventListener('click', useKillMove);
    document.querySelector('[data-basic]')?.addEventListener('click', basicAttack);
    document.querySelector('[data-observe]')?.addEventListener('click', observe);
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
        <div class="section-label">交换 · 你愿意失去什么</div>
        <h1>大巴扎</h1>
        <p class="screen-lead">摊主不问来历，只看你手里还有什么。</p>
        <div class="choice-grid">${options}</div>
      </section>`;
    document.querySelectorAll('[data-trade]').forEach((button) => {
      button.addEventListener('click', () => chooseTrade(button.dataset.trade));
    });
  }

  function renderForge() {
    const hasIngredients = rules.canPay(run.owned, content.forge.consume);
    document.querySelector('#mvp-app').innerHTML = `
      <section class="choice-screen">
        <div class="section-label">合炼 · 改变一条规则</div>
        <h1>炼蛊台</h1>
        <p class="screen-lead">火候只够一次。原料入炉，或者留下等下一局。</p>
        <div class="forge-grid">
          <button class="forge-card" ${hasIngredients ? '' : 'disabled'} data-forge>
            <div class="recipe-line">
              <img src="${guPath('moonlight_gu')}" alt="">
              <span>月光蛊</span>
              <b>+</b>
              <img src="${guPath('small_light_gu')}" alt="">
              <span>小光蛊</span>
              <b>→</b>
              <img src="${guPath('moon_glow_gu')}" alt="">
              <span>月芒蛊</span>
            </div>
            <strong>${esc(content.forge.rule)}</strong>
            <small>${hasIngredients ? '原料齐备' : '原料不足'}</small>
          </button>
          <button class="forge-card preserve" data-preserve>
            <div class="preserve-mark">留</div>
            <b>保炉</b>
            <strong>不消耗蛊虫，获得 ${content.forge.preserveStones} 元石。</strong>
            <small>保留当前构筑，用钱补下一场。</small>
          </button>
        </div>
      </section>`;
    document.querySelector('[data-forge]')?.addEventListener('click', () => chooseForge('forge'));
    document.querySelector('[data-preserve]')?.addEventListener('click', () => chooseForge('preserve'));
  }

  function renderEnding() {
    const result = run.result || { won: true, title: '走完一局', detail: '你从大巴扎走到了雷冠封路。' };
    const owned = Object.entries(run.owned)
      .filter(([, count]) => count > 0)
      .map(([id, count]) => `${guById(id)?.name || id}×${count}`)
      .join('、');
    document.querySelector('#mvp-hud').innerHTML = `
      <div class="brand"><span class="brand-name">问真</span><span class="phase-count">本局结算</span></div>
      <div class="resources"><span><b>气血</b>${run.hp}/${run.hpMax}</span><span><b>元石</b>${run.stones}</span></div>
      <button class="plain" data-restart>重开</button>`;
    document.querySelector('[data-restart]').addEventListener('click', restart);
    document.querySelector('#mvp-app').innerHTML = `
      <section class="ending-screen">
        <div class="section-label">终局 · 所见即所得</div>
        <h1>${esc(result.title)}</h1>
        <p class="screen-lead">${esc(result.detail)}</p>
        <div class="ending-summary">
          <div><span>最终构筑</span><b>${esc(owned)}</b></div>
          <div><span>剩余资源</span><b>气血 ${run.hp} · 元石 ${run.stones}</b></div>
        </div>
        <div class="run-trail">
          ${run.runLog.map((entry) => `<div><span>${esc(entry.kind)}</span><b>${esc(entry.label)}</b><em>${esc(entry.detail)}</em></div>`).join('')}
        </div>
        <button class="primary" data-restart-bottom>再试另一条路</button>
      </section>`;
    document.querySelector('[data-restart-bottom]').addEventListener('click', restart);
  }

  function showLoss() {
    run.result = run.result || {
      won: false,
      title: '气血耗尽',
      detail: '这一局止步于雷雨和铁腥味里。',
    };
    run.stepIndex = content.encounters.length - 1;
    battle = null;
    renderEnding();
  }

  function render() {
    if (!run.result && run.hp <= 0) return showLoss();
    renderHud();
    const step = currentStep();
    if (step.type === 'ending') return renderEnding();
    if (isBattleStep(step)) return renderBattle();
    if (step.type === 'bazaar') return renderBazaar();
    if (step.type === 'forge') return renderForge();
    return renderEnding();
  }

  return { start: beginStep };
})();

Mvp.start();
