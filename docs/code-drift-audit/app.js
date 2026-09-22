/* 文件级方向偏移审计 · 本地仓库证据 */

const FILES = [
  {
    path: 'game/data/balance.json',
    tag: 'keep',
    role: 'Rank/HP/念头/石 → 真源',
    action: 'KEEP · 真源。所有投影必须父子挂靠这里',
  },
  {
    path: 'game/scripts/domain/gu_balance.gd',
    tag: 'keep',
    role: 'rank_power_budget / rank_multiplier 唯一访问点',
    action: 'KEEP · GOOD 复用上游表；勿旁路再算',
  },
  {
    path: 'game/scripts/domain/market_rules.gd',
    tag: 'keep',
    role: '市价/回收/估值',
    action: 'KEEP · 定价 Owner；须接进收入↔购买力环',
  },
  {
    path: 'game/scripts/domain/economy_rules.gd',
    tag: 'keep',
    role: '通用买价/服务价',
    action: 'KEEP',
  },
  {
    path: 'game/data/gu.json',
    tag: 'keep',
    role: '蛊身份 + v1_effect',
    action: 'KEEP · 身份 Owner',
  },
  {
    path: 'game/data/v1_battle.json → kill_moves',
    tag: 'drift',
    role: '杀招',
    action: 'DRIFT·预制技能：自带 damage/thought_cost/qi_cost，recipe 只当解锁条件（例 km_force_avalanche.damage=8）',
  },
  {
    path: 'game/data/refinement_recipes.json',
    tag: 'keep',
    role: '炼方图',
    action: 'KEEP · 468 条；须与杀招组件替换/成本传播接上',
  },
  {
    path: 'game/data/shops.json + loot_tables.json + enemies.json',
    tag: 'drift',
    role: '商店/掉落/敌',
    action: 'DRIFT·与 battle_stone_rewards / market_rules 未合成同一购买力环',
  },
  {
    path: 'game/data/balance.json → battle_stone_rewards',
    tag: 'drift',
    role: '战斗收入',
    action: 'DRIFT·收入表与 shops.stone_cost 分写，未锚定「几场买一只」',
  },
  {
    path: 'game/scripts/domain/v1_battle_resolver.gd',
    tag: 'drift',
    role: '战斗结算',
    action: 'DRIFT·Counter/Intent 占比高；缺真元压制/距离/杀招结构等并列 primitive 的运行时',
  },
  {
    path: 'game/scripts/domain/battle2/*',
    tag: 'orphan',
    role: 'battle2 距离/擒拿等',
    action: 'ORPHAN/并行·与 v1 双战斗语义，Integration 暂不合并，登记勿扩',
  },
  {
    path: 'game/scripts/domain/cultivator_rules.gd + essence_capacity.gd',
    tag: 'keep',
    role: '念头/真元容量',
    action: 'GOOD · 已挂 balance.json',
  },
  {
    path: 'game/scripts/domain/feeding_rules.gd / material_rules.gd',
    tag: 'keep',
    role: '供养/材料转数',
    action: 'GOOD · 复用 rank_multiplier，非再写倍率',
  },
  {
    path: 'game/wenzhen-web-lab/js/balance.js',
    tag: 'keep',
    role: 'Lab 校验器',
    action: 'KEEP·已降级为报警器 + 消费 WORLD_BALANCE；禁止升格世界裁判',
  },
  {
    path: 'game/wenzhen-web-lab/js/mvp_content.js',
    tag: 'keep',
    role: 'Lab 场景 override',
    action: 'KEEP·已 guRef/overrideReason；勿回退成第二蛊库',
  },
  {
    path: 'game/wenzhen-web-lab/js/mvp_logic.js',
    tag: 'drift',
    role: 'Lab 战斗',
    action: 'DRIFT·Counter 拳套成功，但是局部语法；勿推广为全游戏唯一战斗骨架',
  },
  {
    path: 'game/wenzhen-web-lab/tools/autoplay.mjs',
    tag: 'good',
    role: '动态验收',
    action: 'GOOD · 长期保留，升级为世界规则实验装置',
  },
  {
    path: 'game/wenzhen-web-lab/tools/check_balance.mjs',
    tag: 'good',
    role: '静态门禁',
    action: 'GOOD · 已挂 Rank/override/Effect 形状',
  },
  {
    path: 'game/wenzhen-web-lab/balance/**',
    tag: 'orphan',
    role: '模型脊柱实验',
    action: 'FROZEN · 禁止长成第四套引擎',
  },
  {
    path: 'game/wenzhen-web-lab/vertical/**',
    tag: 'orphan',
    role: 'Golden 校准 + vbattle',
    action: 'GOLDEN 只读 · vbattle 冻结',
  },
  {
    path: 'game/world-model/rulings/RUL-2026-09-19-008/009',
    tag: 'keep',
    role: '转数≠万能倍率 / 双轴',
    action: 'KEEP · 产品宪法层',
  },
];

const DRIFT = [
  {
    cls: 'p1',
    t: '① Effect Budget / PP / priceGu 权限过大',
    p: '从「检测离谱」滑向「它值多少 / 敌人多少 HP」。代码本身是检测器；危险是升格为世界裁判。',
    pre: `证据：
  balance.js priceGu/kitDpr/deriveEnemyHp — 已注释降级 + 消费 WORLD_BALANCE
  风险残留：任何人拿 priceGu 当商店价 → 回到 Rank→Budget→Price 标准 Roguelike

应然：
  原作机制 + 品质 + 条件 + 构筑位 + 资源/经济环境 → 实际价值
  PP/kitDpr/deriveEnemyHp = 报警器 / 估算器`,
  },
  {
    cls: 'p1',
    t: '② 同一世界多真相：差异缺父子关系',
    p: 'thought 3 vs 2 合法；不合法的是不能回答「为什么是 2」。要强制 parent=world → child=lab projection。',
    pre: `证据：
  balance.json thought_base_capacity=3
  balance.js LAB.thoughtsPerTurn=2
  刀1 已建 WORLD_BALANCE + PROJECTION 注释 + check_balance 断言
  仍缺：其余分叉（伤害 2 vs gu.json amount=3 等）未全部挂 parent 字段`,
  },
  {
    cls: 'p2',
    t: '③ Counter 正在变成唯一战斗语法',
    p: 'Intent/Observe/Counter/read+act 在 10 分钟 Lab 非常成功。若全游戏战斗都长这样，会变成读题解题战术游戏，不是蛊师战斗。',
    pre: `证据：
  v1_battle_resolver + mvp_logic 以 counter/intent 为高密度骨架
  真元压制 / 距离 / 杀招结构 / 蛊克制 / 伤势 等未并列运行时

裁决：Counter = primitive 之一，禁止升格唯一骨架`,
  },
  {
    cls: 'p1',
    t: '④ 杀招仍是预制技能（最重的产品偏移）',
    p: 'recipe 只当解锁条件，damage 写在杀招上 → 组件不共同产生效果，还是传统 RPG 技能。',
    pre: `证据：
  game/data/v1_battle.json
  km_force_avalanche { recipe:[force_gu,bear_strength_gu], damage:8, true_qi_cost:4 }
  = 两只蛊解锁一个自带数值的技能

应然：
  月光提供 projectile/moon damage
  小光提供 light amp / qi modify
  杀招提供 sequence/coordination/conditions
  结果由组合推导；换核重推 variant`,
  },
  {
    cls: 'p1',
    t: '⑤ 经济未闭合：收入/物价/炼耗三处各写数字',
    p: 'battle_reward、shops.stone_cost、recipe cost 若互不锚定，只是三个有数字的功能，不是力量循环。',
    pre: `证据：
  balance.json battle_stone_rewards / cultivate_rank_*_stone_cost
  shops.json 各 offer.stone_cost
  market_rules.gd gu_public_price = rank_standard_price×4
  refinement_recipes stone_cost/materials

缺口：缺少「一场均收 × 场次 = 一只同转蛊 / 一次炼制」的强制购买力门禁`,
  },
  {
    cls: 'p2',
    t: '⑥ 修为只进了数学，没进运行时纵轴',
    p: 'rank_multiplier 用于喂养/材料/血气等，但「能承载什么」（真元质量、杀招复杂度、经济层、敌人手段密度）未作为同一根轴贯通。',
    pre: `证据：
  gu_balance.rank_multiplier 调用点多在倍率场景
  运行时缺少「低转蛊高转保值 / 高转复杂杀招门禁」的组合验证
  autoplay 仅 3 路 10 分钟剧本，未 1→5 纵向`,
  },
];

const BREAKS = [
  {
    cls: 'p1',
    t: '断点 1 · 杀招组件化（产品方向）',
    p: 'kill_move 伤害/消耗由组件与协调推导；recipe 升格为 composition；支持换核重推。禁止再手填预制 damage。',
  },
  {
    cls: 'p1',
    t: '断点 2 · 经济购买力闭环',
    p: 'battle_stone_rewards → market_rules 价 → 炼耗期望 → 「几场一次明显成长」写进 check_balance 门禁。',
  },
  {
    cls: 'p1',
    t: '断点 3 · 父子投影强制化',
    p: '每个 lab 分叉字段必须带 parentWorldKey + ratio；check_balance 全量核对，杜绝「刚好不同数字」。',
  },
  {
    cls: 'p2',
    t: '断点 4 · Rank 纵轴进运行时',
    p: '真元质量/可催动层/杀招复杂度/经济层同一 Rank 读数；低转保值与高转门槛用 autoplay 断言。',
  },
  {
    cls: 'p2',
    t: '断点 5 · Counter 降为并列 primitive',
    p: '战斗语法清单显式化；新机制必须进 primitive 表而不是长在 counter 上。不重写引擎，只限制扩展方向。',
  },
];

const GOOD = [
  { cls: 'p0', t: '信息改变行为', p: 'Observe/Counter/read+act 已落地，符合设计。' },
  { cls: 'p0', t: '强力手段真实代价', p: 'Qi/HP/Thought/CD/逆息，符合。' },
  { cls: 'p0', t: '不同构筑解决同敌人', p: 'secure/sacrifice/debt 轨迹分化，规模小但机制真。' },
  { cls: 'p0', t: 'autoplay + check_balance + seed', p: '世界规则实验装置雏形，长期保留。' },
  { cls: 'p0', t: 'RUL-008/009', p: '转数≠万能倍率、双轴分离，宪法层正确。' },
  { cls: 'p0', t: 'gu_balance 复用 balance.json', p: 'GOOD：正确复用，不是再写公式。' },
];

const tagLabel = { keep: 'KEEP', drift: 'DRIFT', conflict: 'CONFLICT', orphan: 'ORPHAN', good: 'GOOD' };

document.getElementById('fileTable').innerHTML = `
<table class="files">
  <thead><tr><th>裁决</th><th>文件</th><th>角色</th><th>动作 / 证据</th></tr></thead>
  <tbody>
    ${FILES.map(
      (f) => `<tr>
        <td><span class="tag ${f.tag}">${tagLabel[f.tag]}</span></td>
        <td class="path">${f.path}</td>
        <td>${f.role}</td>
        <td>${f.action}</td>
      </tr>`
    ).join('')}
  </tbody>
</table>`;

const renderCards = (id, arr) => {
  document.getElementById(id).innerHTML = arr
    .map(
      (x) => `<article class="card ${x.cls}">
      <h3>${x.t}</h3>
      <p>${x.p}</p>
      ${x.pre ? `<pre>${x.pre}</pre>` : ''}
    </article>`
    )
    .join('');
};
renderCards('driftList', DRIFT);
renderCards('breakList', BREAKS);
renderCards('goodList', GOOD);

document.getElementById('tabs').addEventListener('click', (e) => {
  const b = e.target.closest('button[data-tab]');
  if (!b) return;
  document.querySelectorAll('.tabs button').forEach((x) => x.classList.remove('on'));
  document.querySelectorAll('.panel').forEach((x) => x.classList.remove('on'));
  b.classList.add('on');
  document.getElementById(b.dataset.tab).classList.add('on');
});
