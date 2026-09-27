/* 从 docs/design/rank1-9-model/parameters.json 抽出的一转战斗切片
   数值以源文件为准；playtest/model_link.mjs 对照防漂移。
   非模块脚本：暴露全局 MODEL，便于 file:// 直接打开。 */

window.MODEL = {
  version: '0.2.0-draft',
  source: 'docs/design/rank1-9-model/parameters.json',
  combat: {
    baseHp: 100,
    actionsPerTurn: 2,
    maxTurns: 30,
    blockExpires: true,
  },
  aptitude: { id: '丙', value: 0.44 },
  rank: {
    rank: 1,
    name: '一转',
    essence: '青铜真元',
    base: 1,
    essenceQuality: 1,
    priceUnit: 1,
  },
  actions: {
    basic: { ap: 1, damage: 10, block: 0, mortalCost: 0, immortalCost: 0, cooldown: 0 },
    strike: { ap: 1, damage: 24, block: 0, mortalCost: 10, immortalCost: 1, cooldown: 0 },
    burst: { ap: 2, damage: 66, block: 0, mortalCost: 25, immortalCost: 3, cooldown: 3 },
    guard: { ap: 1, damage: 0, block: 20, mortalCost: 8, immortalCost: 1, cooldown: 0 },
  },
  enemies: {
    skirmisher: { hp: 75, damage: 13, armor: 0, windupEvery: 0 },
    pressure: { hp: 95, damage: 22, armor: 0, windupEvery: 0 },
    brute: { hp: 125, damage: 26, armor: 0, windupEvery: 2 },
    armored: { hp: 105, damage: 17, armor: 0.35, windupEvery: 0 },
    disruptor: { hp: 90, damage: 16, armor: 0, windupEvery: 0, energyLoss: 4 },
    soulBody: { hp: 70, damage: 24, armor: 0, windupEvery: 0, carrier: 'soulBody' },
    guHouse: { hp: 200, damage: 4, armor: 0.4, windupEvery: 0, carrier: 'guHouse' },
    beastPack: { hp: 300, damage: 24, armor: 0, windupEvery: 0, carrier: 'beastPack', packUnits: 6 },
  },
  carriers: {
    damageClasses: { basic: 'regular', strike: 'regular', drain: 'regular', burst: 'burst', guard: 'none' },
    soulBodyResist: { regular: 0.65, burst: 0 },
    packDamageFloor: 0.25,
    packAoeYield: { basic: 1, strike: 1.2, burst: 1.5, drain: 1 },
  },
  refinement: {
    baseSuccess: [0.95, 0.9, 0.85, 0.8, 0.75, 0.65, 0.55, 0.45, 0.35],
    failureInjuryFraction: 0.1,
    refundInputGu: false,
  },
  economy: {
    grossPerPeriod: 24,
    foodPerGu: 1,
    guCount: 5,
    recoverFullHp: 12,
    mortalRefillPerPoint: 0.12,
    fieldCost: 3,
    refinementFee: 12,
    startingWallet: 48,
  },
};
