// 人类属性来源与蛊虫生命周期。敌我共用；具体蛊效果由数据与 GuRules 提供。
globalThis.HumanRules = (() => {
  const ATTRIBUTES = Object.freeze(['hpMax', 'soulMax', 'thoughtMax', 'defense', 'attack', 'attackDelay', 'essenceMax', 'essenceRegen', 'essenceQuality']);
  const BASELINE = Object.freeze({ hpMax: 10, soulMax: 1, thoughtMax: 3, defense: 0, attack: 3, attackDelay: 0 });
  const ESSENCE_BY_RANK = Object.freeze({
    1: Object.freeze({ max: 6, regen: 2, quality: 1 }),
    2: Object.freeze({ max: 8, regen: 2, quality: 2 }),
    3: Object.freeze({ max: 10, regen: 3, quality: 3 }),
    4: Object.freeze({ max: 12, regen: 3, quality: 4 }),
    5: Object.freeze({ max: 14, regen: 4, quality: 5 }),
  });

  function base(rank = 1) {
    const qi = ESSENCE_BY_RANK[Number(rank)];
    if (!qi) throw new RangeError(`unsupported human rank: ${rank}`);
    return { ...BASELINE, essenceMax: qi.max, essenceRegen: qi.regen, essenceQuality: qi.quality };
  }

  function guInstance(definitionId, ordinal, state = 'held') {
    if (!definitionId || !Number.isInteger(ordinal) || ordinal < 1) throw new TypeError('invalid Gu instance');
    return { instanceId: `${definitionId}::${ordinal}`, definitionId, state, sealed: false };
  }

  function actor({ id, rank = 1, guInstances = [], baseline = base(rank) }) {
    const byId = new Set();
    for (const gu of guInstances) {
      if (!gu?.instanceId || byId.has(gu.instanceId)) throw new TypeError('duplicate or missing Gu instance ID');
      byId.add(gu.instanceId);
    }
    return {
      id, rank: Number(rank), baseline: { ...baseline },
      guInstances: guInstances.map((gu) => ({ ...gu })), modifierLedger: [], maintainedGu: [],
      hp: Number(baseline.hpMax), soul: Number(baseline.soulMax),
      thought: Number(baseline.thoughtMax), essence: Number(baseline.essenceMax),
    };
  }

  function effective(record, human) {
    if (!record?.active) return false;
    if (record.persistence === 'session_permanent') return true;
    if (record.persistence !== 'maintained' && record.persistence !== 'timed') return false;
    if (record.persistence === 'timed') return true;
    const gu = human.guInstances.find((item) => item.instanceId === record.sourceGuInstanceId);
    return !!gu && gu.state === 'held' && !gu.sealed
      && human.maintainedGu.some((item) => item.instanceId === gu.instanceId && item.active);
  }

  function attribute(human, name) {
    if (!ATTRIBUTES.includes(name)) throw new RangeError(`unknown human attribute: ${name}`);
    return Number(human.baseline[name] || 0)
      + human.modifierLedger.reduce((sum, record) =>
        sum + (record.attribute === name && effective(record, human) ? Number(record.amount) : 0), 0);
  }

  function attributes(human) {
    return Object.fromEntries(ATTRIBUTES.map((name) => [name, attribute(human, name)]));
  }

  function controlCapacity(human) {
    const held = human.maintainedGu.reduce((sum, item) => {
      const gu = human.guInstances.find((entry) => entry.instanceId === item.instanceId);
      return sum + (item.active && gu?.state === 'held' && !gu.sealed ? Number(item.focusCost || 0) : 0);
    }, 0);
    return Math.max(0, attribute(human, 'thoughtMax') - held);
  }

  function refreshControl(human) {
    human.thought = controlCapacity(human);
    return human.thought;
  }

  function basicStrikePlan(human) {
    return { damage: attribute(human, 'attack'), delayTurns: Math.max(0, Math.ceil(attribute(human, 'attackDelay'))) };
  }

  function addModifier(human, entry) {
    if (!ATTRIBUTES.includes(entry?.attribute) || !Number.isFinite(Number(entry?.amount))) {
      throw new TypeError('invalid human modifier');
    }
    if (!['session_permanent', 'maintained', 'timed'].includes(entry.persistence)) {
      throw new TypeError('invalid human modifier persistence');
    }
    if (!entry.sourceGuDefinitionId || !entry.sourceGuInstanceId || !entry.sourceEffectId) {
      throw new TypeError('human modifier requires Gu source');
    }
    human.modifierLedger.push({
      attribute: entry.attribute, amount: Number(entry.amount),
      sourceGuDefinitionId: entry.sourceGuDefinitionId,
      sourceGuInstanceId: entry.sourceGuInstanceId,
      sourceEffectId: entry.sourceEffectId,
      persistence: entry.persistence,
      dependency: entry.persistence === 'session_permanent' ? 'none' : 'source_gu',
      createdAt: entry.createdAt ?? null, active: true, removalReason: null,
    });
    return human.modifierLedger.at(-1);
  }

  function stopMaintained(human, instanceId, reason) {
    for (const item of human.maintainedGu) {
      if (item.instanceId === instanceId && item.active) {
        item.active = false;
        item.removalReason = reason;
      }
    }
    for (const record of human.modifierLedger) {
      if (record.sourceGuInstanceId === instanceId && record.persistence === 'maintained' && record.active) {
        record.active = false;
        record.removalReason = reason;
      }
    }
  }

  function startMaintained(human, instanceId, { startCost, upkeepCost, hitCost = 0, focusCost = 0, defenseGroup, modifiers, turn = 0 }) {
    const gu = human.guInstances.find((item) => item.instanceId === instanceId);
    if (!gu || gu.state !== 'held' || gu.sealed) return { ok: false, reason: 'gu_unavailable' };
    if (human.maintainedGu.some((item) => item.instanceId === instanceId && item.active)) {
      return { ok: false, reason: 'already_active' };
    }
    if (defenseGroup && human.maintainedGu.some((item) => item.active && item.defenseGroup === defenseGroup)) {
      return { ok: false, reason: 'defense_group_active' };
    }
    const cost = Number(startCost);
    const upkeep = Number(upkeepCost);
    const perHit = Number(hitCost);
    const focus = Number(focusCost);
    if (!Number.isInteger(cost) || cost < 0 || !Number.isInteger(upkeep) || upkeep < 0
      || !Number.isInteger(perHit) || perHit < 0 || !Number.isInteger(focus) || focus < 0) {
      throw new TypeError('invalid maintenance cost');
    }
    if (human.essence < cost) return { ok: false, reason: 'insufficient_essence' };
    human.essence -= cost;
    human.maintainedGu.push({ instanceId, upkeepCost: upkeep, hitCost: perHit, focusCost: focus,
      defenseGroup: defenseGroup ?? null, active: true, startedAt: turn, removalReason: null });
    for (const modifier of modifiers || []) {
      addModifier(human, {
        ...modifier, sourceGuDefinitionId: gu.definitionId,
        sourceGuInstanceId: instanceId, persistence: 'maintained', createdAt: turn,
      });
    }
    return { ok: true, cost };
  }

  function trainBody(human, instanceId, { attribute: name = 'attack', step, cap, cost, visitId } = {}) {
    if (!ATTRIBUTES.includes(name) || !Number.isFinite(step) || step <= 0
      || !Number.isFinite(cap) || cap <= 0 || !Number.isFinite(cost) || cost < 0
      || typeof visitId !== 'string' || !visitId) throw new TypeError('invalid body training parameters');
    const gu = human.guInstances.find((item) => item.instanceId === instanceId);
    const records = human.modifierLedger.filter((record) => record.sourceGuDefinitionId === gu?.definitionId
      && record.attribute === name && record.persistence === 'session_permanent'
      && record.sourceEffectId === 'body_training');
    const repeatedVisit = human.modifierLedger.some((record) => record.sourceGuDefinitionId === gu?.definitionId
      && record.persistence === 'session_permanent' && record.sourceEffectId === 'body_training'
      && record.createdAt === visitId);
    const total = records.reduce((sum, record) => sum + Number(record.amount), 0);
    const result = (ok, reason = null, gained = 0) => ({ ok, reason, cost, gained, total: total + gained });
    if (!gu || gu.state !== 'held' || gu.sealed) return result(false, 'gu_unavailable');
    if (repeatedVisit) return result(false, 'repeated_visit');
    if (total >= cap) return result(false, 'cap_reached');
    if (human.essence < cost) return result(false, 'insufficient_essence');
    const gained = Math.min(step, cap - total);
    human.essence -= cost;
    addModifier(human, {
      attribute: name, amount: gained, sourceGuDefinitionId: gu.definitionId,
      sourceGuInstanceId: instanceId, sourceEffectId: 'body_training',
      persistence: 'session_permanent', createdAt: visitId,
    });
    return result(true, null, gained);
  }

  function upkeep(human) {
    const events = [];
    for (const item of human.maintainedGu) {
      if (!item.active) continue;
      const gu = human.guInstances.find((entry) => entry.instanceId === item.instanceId);
      if (!gu || gu.state !== 'held' || gu.sealed) {
        stopMaintained(human, item.instanceId, 'gu_unavailable');
        events.push({ instanceId: item.instanceId, ok: false, reason: 'gu_unavailable' });
      } else if (human.essence < item.upkeepCost) {
        stopMaintained(human, item.instanceId, 'insufficient_essence');
        events.push({ instanceId: item.instanceId, ok: false, reason: 'insufficient_essence' });
      } else {
        human.essence -= item.upkeepCost;
        events.push({ instanceId: item.instanceId, ok: true, cost: item.upkeepCost });
      }
    }
    return events;
  }

  function receiveHit(human, damage) {
    const incoming = Math.max(0, Number(damage) || 0);
    const events = [];
    for (const item of human.maintainedGu) {
      if (!item.active) continue;
      const gu = human.guInstances.find((entry) => entry.instanceId === item.instanceId);
      if (!gu || gu.state !== 'held' || gu.sealed) {
        stopMaintained(human, item.instanceId, 'gu_unavailable');
        events.push({ instanceId: item.instanceId, ok: false, reason: 'gu_unavailable' });
      } else if (incoming > 0 && item.hitCost > 0 && human.essence < item.hitCost) {
        stopMaintained(human, item.instanceId, 'insufficient_essence');
        events.push({ instanceId: item.instanceId, ok: false, reason: 'insufficient_essence' });
      } else if (incoming > 0 && item.hitCost > 0) {
        human.essence -= item.hitCost;
        events.push({ instanceId: item.instanceId, ok: true, cost: item.hitCost });
      }
    }
    const defense = attribute(human, 'defense');
    const remaining = Math.max(0, incoming - defense);
    return { damage: remaining, absorbed: incoming - remaining, events };
  }

  function seal(human, instanceId) {
    const gu = human.guInstances.find((item) => item.instanceId === instanceId);
    if (!gu || gu.state !== 'held') return false;
    gu.sealed = true;
    stopMaintained(human, instanceId, 'sealed');
    return true;
  }

  function dispose(human, instanceId, disposition) {
    if (!['consumed', 'sold', 'refined'].includes(disposition)) throw new RangeError('invalid Gu disposition');
    const gu = human.guInstances.find((item) => item.instanceId === instanceId);
    if (!gu || gu.state !== 'held') return false;
    gu.state = disposition;
    stopMaintained(human, instanceId, disposition);
    return true;
  }

  function endBattle(human) {
    for (const item of human.maintainedGu) if (item.active) stopMaintained(human, item.instanceId, 'battle_end');
    for (const record of human.modifierLedger) {
      if (record.persistence === 'timed' && record.active) {
        record.active = false;
        record.removalReason = 'battle_end';
      }
    }
  }

  function adjustedHp(current, oldMax, newMax) {
    return Math.max(0, Math.min(newMax, newMax - (oldMax - current)));
  }

  return Object.freeze({ BASELINE, ESSENCE_BY_RANK, base, guInstance, actor,
    attribute, attributes, controlCapacity, refreshControl, basicStrikePlan, addModifier, startMaintained, trainBody, upkeep, receiveHit,
    stopMaintained, seal, dispose, endBattle, adjustedHp });
})();
