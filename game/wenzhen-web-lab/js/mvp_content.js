// Focused 10-minute run content · LAB SCENARIO OVERRIDE（不是第二套蛊库）
//
// Integration 刀2（EXISTING_CAPABILITY_MAP）：
//   身份/转数/role/effect  OWNER = game/data/gu.json
//   炼方 OWNER = game/data/refinement_recipes.json
//   杀招 OWNER = game/data/v1_battle.json
//   敌人 OWNER = game/data/enemies.json
//   Rank/HP/念头/石     OWNER = game/data/balance.json（经 MvpBalance 投影）
//
// 本文件只允许：
//   1) 10 分钟 Lab 剧本（路线、节点、forge 选择、Boss 相位）
//   2) 相对 gu.json 的 lab 量纲 OVERRIDE（须写 guRef + overrideReason）
// 禁止：把这里的 damage/qi/block 当全库定价或正式战斗数值反推。
//
// Enemy HP is DERIVED from MvpBalance (kit throughput × target turns × counter tax).
// Do not hand-edit enemy HP — edit kit / sequences / target turns and let balance.js derive.
globalThis.MVP_CONTENT = (() => {
  const B = globalThis.MvpBalance;

  const run = Object.freeze({
    seed: 101,
    /* RUL-010 q5 gu_rank_cap：一转只能正常催动一转蛊 */
    playerRank: 1,
    /* PROJECTION of balance.json player_start_hp=100 → lab 24（见 balance.js） */
    hp: 24,
    hpMax: 24,
    qi: 12,
    qiMax: 12,
    baseQiMax: 12,
    thoughts: 2,
    stones: 3,
    owned: Object.freeze({
      moonlight_gu: 1,
      small_light_gu: 1,
      stone_shell_gu: 1,
      vitality_grass_gu: 1,
      jade_skin_gu: 1,
    }),
  });

  /* 动作 = lab 量纲 OVERRIDE。guRef → game/data/gu.json 身份 Owner。 */
  const actions = Object.freeze({
    moonlight_gu: Object.freeze({
      guRef: 'moonlight_gu',
      overrideReason: 'LAB_PROJECTION 10min 咽吐；全库 v1_effect 以 gu.json 为准',
      label: '月光蛊',
      thought: 1,
      qi: 1,
      cooldown: 0,
      light: true,
      damage: 2,
      supportedDamage: 3,
      supportedQi: 0,
    }),
    small_light_gu: Object.freeze({
      guRef: 'small_light_gu',
      overrideReason: 'LAB_PROJECTION；支援/识破语义对齐 gu.json，数值按 lab',
      label: '小光蛊',
      thought: 1,
      qi: 0,
      cooldown: 2,
      light: true,
      inspect: true,
      support: true,
    }),
    stone_shell_gu: Object.freeze({
      guRef: 'stone_shell_gu',
      overrideReason: 'LAB_OVERRIDE 盾量；身份以 gu.json 为准',
      label: '石皮蛊',
      thought: 1,
      qi: 1,
      cooldown: 1,
      block: 5,
      chargeGuard: true,
    }),
    vitality_grass_gu: Object.freeze({
      guRef: 'vitality_grass_gu',
      overrideReason: 'LAB_PROJECTION 治疗量',
      label: '生机草蛊',
      thought: 1,
      qi: 0,
      cooldown: 0,
      heal: 1,
      light: true,
    }),
    jade_skin_gu: Object.freeze({
      guRef: 'jade_skin_gu',
      overrideReason: 'LAB_PROJECTION 玉皮盾量；全库以 gu.json 为准',
      label: '玉皮蛊',
      thought: 1,
      qi: 1,
      cooldown: 1,
      block: 3,
    }),
    white_boar_strength_gu: Object.freeze({
      guRef: 'white_boar_strength_gu',
      overrideReason: 'LAB 剧本路线蛊（sacrifice）；非月光库',
      label: '白豕蛊',
      thought: 1,
      qi: 0,
      cooldown: 1,
      damage: 2,
      woundedDamage: 5,
      breaksCounterWhenWounded: true,
    }),
    moon_glow_gu: Object.freeze({
      guRef: 'moon_glow_gu',
      rank: 2,
      overrideReason: 'LAB_PROJECTION 月芒；炼方 canonical=moonlight+small×2（refinement_recipes moon_glow_fixed）；二转蛊，一转不可正常催动',
      label: '月芒蛊',
      thought: 1,
      qi: 3,
      hp: 1,
      cooldown: 2,
      damage: 4,
      light: true,
      suppressWhenRevealed: true,
    }),
  });

  /* V4.1-Q2：counterSequence 按出现次数/回合循环；'none' = 本回合无反制。
     敌人剧本 OVERRIDE — 身份/意图池 OWNER=enemies.json；此处仅 lab 确定性序列。 */
  const seqHound = Object.freeze(['draw_light', 'none', 'intercept', 'none']);
  const seqBoar = Object.freeze(['iron', 'none', 'none']);
  const seqBoss1 = Object.freeze(['intercept', 'none', 'draw_light', 'none']);
  const seqSeal = Object.freeze(['seal_first', 'none', 'seal_last', 'none']);
  const seqBoss2 = Object.freeze(['draw_light', 'none', 'intercept', 'none']);

  /* 参考吞吐：开局 kit（所有路线共同的月光输出线）。 */
  const refKit = B.kitDpr(run.owned, actions, { thoughts: run.thoughts });
  const refDpr = refKit.dpr;

  /* 目标回合 = L1 V4.1 窗口中值。HP 由吞吐 × 回合 × 反制税推出。 */
  const targetTurns = Object.freeze({
    battle_1: 4,
    battle_2: 5,
    elite: 5,
    boss: 7.5,
  });

  const hpFor = (key, seq, extra = 0) => B.deriveEnemyHp({
    dpr: refDpr + extra,
    targetTurns: targetTurns[key],
    zeroRate: B.counterZeroRate(seq),
    margin: 1.08,
    minHp: 4,
  });

  const enemyProfiles = Object.freeze({
    ridge_hound: Object.freeze({
      hp: hpFor('battle_1', seqHound),
      phaseAt: null,
      intents: Object.freeze([
        Object.freeze({
          id: 'stalk_pounce',
          label: '蓄扑',
          damage: 4,
          tag: 'charge',
          counterSequence: seqHound,
        }),
      ]),
    }),
    iron_hide_boar: Object.freeze({
      hp: hpFor('battle_2', seqBoar),
      phaseAt: null,
      intents: Object.freeze([
        Object.freeze({
          id: 'boar_charge_5',
          label: '獠牙冲撞',
          damage: 5,
          tag: 'charge',
          counterSequence: seqBoar,
          counterSequenceKey: 'iron_gate',
          counterSeqMode: 'turn',
        }),
        Object.freeze({ id: 'boar_wait', label: '蓄势', damage: 0, tag: 'wait' }),
        Object.freeze({
          id: 'boar_charge_6',
          label: '獠牙冲撞',
          damage: 6,
          tag: 'charge',
          counterSequence: seqBoar,
          counterSequenceKey: 'iron_gate',
          counterSeqMode: 'turn',
        }),
      ]),
    }),
    ridge_elite_scout: Object.freeze({
      hp: hpFor('elite', seqSeal),
      phaseAt: null,
      intents: Object.freeze([
        Object.freeze({
          id: 'seal_order',
          label: '封脉',
          damage: 0,
          kind: 'seal',
          counterSequence: seqSeal,
        }),
        Object.freeze({
          id: 'drain_qi',
          label: '噬元',
          damage: 0,
          kind: 'drain_qi',
          drainQi: 3,
        }),
        Object.freeze({
          id: 'crossbow_shot',
          label: '弩箭贯击',
          damage: 4,
          tag: 'charge',
          counterSequence: seqSeal,
        }),
      ]),
    }),
    thunder_crown_sovereign: Object.freeze({
      /* Boss 两阶段，取两序列平均反制税 */
      hp: hpFor('boss', [...seqBoss1, ...seqBoss2]),
      phaseAt: 14,
      phaseOne: Object.freeze([
        Object.freeze({
          id: 'thunder_pounce',
          label: '雷冠贯落',
          damage: 5,
          tag: 'charge',
          counterSequence: seqBoss1,
        }),
      ]),
      phaseTwo: Object.freeze([
        Object.freeze({ id: 'burn_qi_3', label: '焚元', damage: 0, kind: 'burn_qi', burnQi: 3 }),
        Object.freeze({
          id: 'thunder_pounce_2',
          label: '雷冠贯落',
          damage: 6,
          tag: 'charge',
          counterSequence: seqBoss2,
        }),
      ]),
    }),
  });

  /* Boss 二阶段阈值也从 HP 推（约 50%），不再手写 14 */
  const bossHp = enemyProfiles.thunder_crown_sovereign.hp;
  const thunder = {
    ...enemyProfiles.thunder_crown_sovereign,
    phaseAt: Math.max(1, Math.round(bossHp * 0.5)),
  };

  const balanceReport = Object.freeze({
    identity: 'P3 experimental reference · LAB_BUDGET_PROJECTION=20 · LAB_PRICING_V1',
    refDpr,
    refPlan: refKit.plan,
    targetTurns,
    sequences: Object.freeze({ seqHound, seqBoar, seqBoss1, seqSeal, seqBoss2 }),
    enemyHp: Object.freeze({
      ridge_hound: enemyProfiles.ridge_hound.hp,
      iron_hide_boar: enemyProfiles.iron_hide_boar.hp,
      ridge_elite_scout: enemyProfiles.ridge_elite_scout.hp,
      thunder_crown_sovereign: thunder.hp,
    }),
    /* H1：偏离推导 >20% 时在此写 reason。当前 0 偏差，reasons 为空。 */
    overrideReasons: Object.freeze({}),
    /* 历史 calibration snapshot（L1 P2-H4），不再是执行表 */
    legacyV4HpSnapshot: Object.freeze({ ridge_hound: 10, iron_hide_boar: 15, ridge_elite_scout: 18, thunder_crown_sovereign: 28 }),
  });

  return Object.freeze({
    run,
    encounters: Object.freeze([
      Object.freeze({
        id: 'battle_1',
        type: 'battle',
        order: 1,
        title: '山道截杀',
        enemyId: 'ridge_hound',
        brief: '猎犬藏着一种反制式，先看清代价。',
      }),
      Object.freeze({ id: 'bazaar', type: 'bazaar', order: 2, title: '大巴扎' }),
      Object.freeze({
        id: 'battle_2',
        type: 'battle',
        order: 3,
        title: '雨沟追猎',
        enemyId: 'iron_hide_boar',
        brief: '铁皮山猪不接受无脑攻击，它会把鲁莽变成下一次冲撞。',
      }),
      Object.freeze({ id: 'forge', type: 'forge', order: 4, title: '炼蛊台' }),
      Object.freeze({
        id: 'elite',
        type: 'elite',
        order: 5,
        title: '高坡截击',
        enemyId: 'ridge_elite_scout',
        brief: '悍客先封你的出招顺序，再抽走剩余真元。',
      }),
      Object.freeze({
        id: 'boss',
        type: 'boss',
        order: 6,
        title: '雷冠封路',
        enemyId: 'thunder_crown_sovereign',
        brief: '雷冠狼王会记住你重复使用的蛊。',
      }),
      Object.freeze({ id: 'ending', type: 'ending', order: 7, title: '本局结算' }),
    ]),
    tradeOptions: Object.freeze([
      Object.freeze({
        id: 'secure',
        label: '光道积累',
        promise: '放弃未来的真元储备，换取稳定的信息与光道行动。',
        cost: Object.freeze({ stones: 3 }),
        gain: Object.freeze({ gu: Object.freeze({ small_light_gu: 2 }) }),
        consequence: '支付 3 元石，获得 2 只小光蛊。',
      }),
      Object.freeze({
        id: 'sacrifice',
        label: '力道换命',
        promise: '不要安全防御，用自己的身体制造破绽。',
        cost: Object.freeze({ gu: Object.freeze({ stone_shell_gu: 1 }) }),
        gain: Object.freeze({
          stones: 4,
          gu: Object.freeze({ white_boar_strength_gu: 1 }),
        }),
        consequence: '永久失去石皮蛊，获得白豕蛊与 4 元石。',
      }),
      Object.freeze({
        id: 'debt',
        label: '借月',
        promise: '提前得到修改敌人规则的能力，但留下道伤。',
        gain: Object.freeze({ gu: Object.freeze({ moon_glow_gu: 1 }) }),
        penalty: Object.freeze({ qiMax: 8, borrowedMoon: true }),
        consequence: '获得借来的月芒蛊；本局真元上限永久降至 8。',
      }),
    ]),
    forge: Object.freeze({
      /* C3 · RUL-010：canonical 炼方=月光+小光×2（moon_glow_fixed）。
         本条仅 lab 场景捷径，禁止当 WORLD 炼方 / Projection / 纵向正式炼方。 */
      kind: 'experimental_scenario_recipe',
      /* lab 场景允许越阶炼成，但必须落入 lowRankGu 例外（借役催动），不可静默当二转常态 */
      allowOverRank: true,
      outputRank: 2,
      recipeId: 'moonlight_glow',
      recipeOwner: 'game/data/refinement_recipes.json',
      recipeCanonicalId: 'moon_glow_fixed',
      consumeOverrideReason: 'LAB 简化 1 小光；canonical 为 2 小光，见 moon_glow_fixed.source',
      consume: Object.freeze({ moonlight_gu: 1, small_light_gu: 1 }),
      qiCost: 2,
      output: 'moon_glow_gu',
      preserveStones: 3,
      // 当前 MVP recipe rule（三问已录 lab-mechanics-three-questions.md）
      rule: '月芒蛊消耗 3 真元、1 气血、1 念头，冷却 2 回合；对已洞悉目标可压制反制与特殊效果，并降低本次敌方伤害 3。',
    }),
    /* LAB pacing valve / MVP recipe rule / anti-softlock —— 三问见
       docs/lab-mechanics-three-questions.md。禁止升格为 world 规则。 */
    victoryRecovery: Object.freeze({ hp: 2, qi: 2 }),
    exhaustion: Object.freeze({
      id: 'exhaustion',
      label: '逆息',
      thought: 1,
      qiGain: 3,
      hpCost: 2,
      cooldownTurns: 2,
      banActions: Object.freeze(['defend', 'vitality_grass_gu']),
    }),
    actions,
    enemyProfiles: Object.freeze({
      ridge_hound: enemyProfiles.ridge_hound,
      iron_hide_boar: enemyProfiles.iron_hide_boar,
      ridge_elite_scout: enemyProfiles.ridge_elite_scout,
      thunder_crown_sovereign: Object.freeze(thunder),
    }),
    counterRules: Object.freeze({
      intercept: Object.freeze({
        label: '迎击',
        detail: '直接攻击无效；每次出手额外损失 2 气血。',
      }),
      draw_light: Object.freeze({
        label: '逐光',
        detail: '若本回合未使用光道蛊，蓄扑伤害 +3。',
      }),
      iron: Object.freeze({
        label: '铁皮',
        detail: '直接攻击无效且不会击破铁皮；每次鲁莽攻击使下次冲撞 +1。',
      }),
      seal_first: Object.freeze({
        label: '封首',
        detail: '封住你本回合使用的第一只蛊，持续 1 回合。',
      }),
      seal_last: Object.freeze({
        label: '封尾',
        detail: '封住你本回合使用的最后一只蛊，持续 1 回合。',
      }),
    }),
    intel: Object.freeze({
      ridge_hound: Object.freeze({
        known: '公开：蓄扑，预计 4 伤。',
        unknown: '未知：迎击还是逐光。',
      }),
      iron_hide_boar: Object.freeze({
        known: '公开：冲撞与蓄势循环；冲撞伴有铁皮。',
        unknown: '未知：铁皮需要哪条路线击破。',
      }),
      ridge_elite_scout: Object.freeze({
        known: '公开：先封脉，再噬元，后直击。',
        unknown: '未知：封首还是封尾。',
      }),
      thunder_crown_sovereign: Object.freeze({
        known: '公开：一阶段试探，二阶段焚元并记住重复用蛊。',
        unknown: '未知：一阶段采用哪种反制式。',
      }),
    }),
    balanceReport,
  });
})();

if (typeof module !== 'undefined' && module.exports) module.exports = globalThis.MVP_CONTENT;
