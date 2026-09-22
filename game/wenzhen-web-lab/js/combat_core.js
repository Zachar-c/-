/* 唯一 Web 战斗核（合并：逻辑=MVP，壳=Lab）
 * 身份：MvpLogic 的正式别名 + Lab 适配；禁止第二套结算。
 * 反制/意图/逆息/越阶门禁一律走这里。
 */
globalThis.CombatCore = (() => {
  const engine = globalThis.MvpLogic;
  if (!engine) {
    console.error('[CombatCore] MvpLogic 未加载，禁止回退第二套战斗');
  }

  /** 敌人字段 → 战斗核敌人（counterSequence 等） */
  function toCoreEnemy(labEnemy, contentProfiles = null) {
    const profile = contentProfiles?.[labEnemy.id] || contentProfiles?.[labEnemy.enemyId] || null;
    const intents = profile?.intents
      || profile?.phaseOne
      || (labEnemy.intent ? [{ ...labEnemy.intent, counterSequence: labEnemy.counterSequence }] : []);
    return {
      id: labEnemy.id,
      name: labEnemy.name,
      rank: labEnemy.rank || 1,
      hp: labEnemy.hp,
      hpMax: labEnemy.hpMax || labEnemy.hp,
      phaseAt: labEnemy.phaseAt ?? profile?.phaseAt ?? null,
      intents,
      phaseOne: profile?.phaseOne,
      phaseTwo: profile?.phaseTwo,
      currentCounter: labEnemy.currentCounter || '',
      currentIntent: labEnemy.currentIntent || null,
      counterRevealed: !!labEnemy.counterRevealed || !!labEnemy.revealed,
      counterBroke: !!labEnemy.counterBroke,
      ironRage: labEnemy.enemyIntent?.id?.includes('charge') || labEnemy.ironRage,
    };
  }

  function counterView(enemy) {
    const active = engine.counterActive ? engine.counterActive(enemy) : false;
    const id = active ? enemy.currentCounter : '';
    const revealed = !!enemy.counterRevealed;
    return {
      id: revealed ? id : id ? 'unknown' : '',
      known: revealed && id ? id : '',
      unknown: id && !revealed,
      rule: id && revealed ? null : null,
    };
  }

  return Object.freeze({
    engine,
    ...engine,
    toCoreEnemy,
    counterView,
  });
})();
