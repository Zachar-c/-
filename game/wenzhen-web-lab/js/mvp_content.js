// Focused 10-minute run content. Numeric combat data still comes from data.js.
globalThis.MVP_CONTENT = Object.freeze({
  run: Object.freeze({
    hp: 24,
    hpMax: 24,
    qi: 20,
    qiMax: 20,
    thoughts: 2,
    stones: 6,
    owned: Object.freeze({
      moonlight_gu: 1,
      small_light_gu: 1,
      stone_shell_gu: 1,
      vitality_grass_gu: 1,
      jade_skin_gu: 1,
    }),
  }),
  encounters: Object.freeze([
    Object.freeze({
      id: 'battle_1',
      type: 'battle',
      order: 1,
      title: '山道截杀',
      enemyId: 'ridge_hound',
      brief: '猎犬贴着湿泥压低肩背，等你先露破绽。',
    }),
    Object.freeze({ id: 'bazaar', type: 'bazaar', order: 2, title: '大巴扎' }),
    Object.freeze({
      id: 'battle_2',
      type: 'battle',
      order: 3,
      title: '雨沟追猎',
      enemyId: 'iron_hide_boar',
      brief: '铁皮山猪把泥甲拱得更厚，冲撞路线只有一条。',
    }),
    Object.freeze({ id: 'forge', type: 'forge', order: 4, title: '炼蛊台' }),
    Object.freeze({
      id: 'elite',
      type: 'elite',
      order: 5,
      title: '高坡截击',
      enemyId: 'ridge_elite_scout',
      brief: '悍客占住高坡，弩弦已经上紧。',
    }),
    Object.freeze({
      id: 'boss',
      type: 'boss',
      order: 6,
      title: '雷冠封路',
      enemyId: 'thunder_crown_sovereign',
      brief: '雷冠狼王走出雨幕，皮毛间全是爆响的火花。',
    }),
    Object.freeze({ id: 'ending', type: 'ending', order: 7, title: '本局结算' }),
  ]),
  tradeOptions: Object.freeze([
    Object.freeze({
      id: 'secure',
      label: '稳购',
      promise: '少走险路，先把手里的蛊配齐。',
      cost: Object.freeze({ stones: 3 }),
      gain: Object.freeze({ gu: Object.freeze({ small_light_gu: 2 }) }),
      consequence: '支付 3 元石，获得 2 只小光蛊。',
    }),
    Object.freeze({
      id: 'sacrifice',
      label: '割爱',
      promise: '用一层护身，换更硬的拳。',
      cost: Object.freeze({ gu: Object.freeze({ stone_shell_gu: 1 }) }),
      gain: Object.freeze({
        stones: 4,
        gu: Object.freeze({ white_boar_strength_gu: 1 }),
      }),
      consequence: '失去石皮蛊，获得白豕蛊与 4 元石。',
    }),
    Object.freeze({
      id: 'debt',
      label: '赊约',
      promise: '先拿月芒，下一战带伤应敌。',
      gain: Object.freeze({ gu: Object.freeze({ moon_glow_gu: 1 }) }),
      penalty: Object.freeze({ nextBattleHalf: true }),
      consequence: '获得月芒蛊；下一战开局气血与真元减半。',
    }),
  ]),
  forge: Object.freeze({
    recipeId: 'moonlight_glow',
    consume: Object.freeze({ moonlight_gu: 1, small_light_gu: 1 }),
    output: 'moon_glow_gu',
    preserveStones: 3,
    rule: '月芒蛊命中后压制目标反制 1 回合；这次攻击本身无视反制。',
  }),
  intel: Object.freeze({
    ridge_hound: Object.freeze({
      known: '低伏肩背，第一记近击可能被反口吞掉。',
      unknown: '还没看清它反口的确切时机。',
    }),
    iron_hide_boar: Object.freeze({
      known: '泥甲厚重，硬受一击后才会露出松散处。',
      unknown: '还不知道这次硬受会把它拖住多久。',
    }),
    ridge_elite_scout: Object.freeze({
      known: '占住高坡，直接出手可能落空。',
      unknown: '还没看清他的闪避路线。',
    }),
    thunder_crown_sovereign: Object.freeze({
      known: '雷毛带电，半血后它的行动会改变。',
      unknown: '尚未察明第二阶段会先出哪一手。',
    }),
  }),
});
