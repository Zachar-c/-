const Q = [
  {
    t: 'Q1 杀招是否必须立刻组件化？（产品方向）',
    p: '证据：v1_battle.json km_force_avalanche.recipe=[force_gu,bear_strength_gu] 但 damage=8、true_qi_cost=4 写在杀招本体（26 条同构）。',
    opts: 'A 立刻：伤害/消耗由组件 v1_effect+协调推导 · B 渐进：强制「组件和×协调=声明 damage」校验 · C 暂缓',
    want: '另请给协调系数/多组件聚合/换核 variant 的最小 JSON schema',
  },
  {
    t: 'Q2 经济购买力门禁取哪组？',
    p: 'battle_stone_rewards / shops.stone_cost / market_rules.gu_public_price(=材料价×4) / refinement stone_cost 分写；Lab 投影 20×、念头 2、HP 24、石1:2。',
    want: '1→5 转 × 收入/物价/炼耗/突破 的可进 check_balance 的门禁表；分轴 vs 共乘数如何对齐 RUL-008',
  },
  {
    t: 'Q3 父子投影最小 schema？',
    p: '例：WORLD thought=3 → LAB 2。要能答「为什么是 2」。',
    want: '字段级 schema + 禁止投影清单（哪些必须同值）',
  },
  {
    t: 'Q4 Counter 权限上限',
    p: 'Intent/Observe/intercept/draw_light/seal_first/seal_last/iron + read+act 已验证信息改变打法。',
    want: '相对真元压制/距离/杀招结构/伤势/隐匿 的职责边界；新 combat 机制扩展准入清单',
  },
  {
    t: 'Q5 Rank 纵轴最小运行时字段（≤8）',
    p: 'rank_multiplier 已用于喂养/材料/血气；杀招复杂度门禁、低转保值、高转可催动层未强制。',
    want: '字段集 + 低转保值是否再加价值折算 + 复杂度可否被品质/代价突破',
  },
  {
    t: 'Q6 五断点顺序 + 重大变更标注',
    p: '①杀招组件化 ②经济闭环 ③父子投影 ④Rank 纵轴 ⑤Counter 降 primitive',
    want: '是否调序；哪些必须呈 L0 批准',
  },
];

document.getElementById('q').innerHTML = Q.map(
  (x) => `<article class="qcard"><h3>${x.t}</h3><p>${x.p}</p><p><b>请裁决/给出：</b> ${x.want}${x.opts ? `<br><b>选项：</b> ${x.opts}` : ''}</p></article>`
).join('');

document.getElementById('factsOut').textContent = `1. Rank 真源 balance.json 40/80/160/320/640 · rank_step_ratio=2 · gu_balance 访问点
2. HP 双轴 RUL-009：human_base_health=100 · 禁止丙等→HP×0.8
3. 念头 WORLD 3 → LAB 2（pacing projection）
4. 石→真元 WORLD 1:5 → LAB 1:2
5. gu.json 802 条；moonlight v1_effect strike amount=3 · value=4
6. 炼方 468；moon_glow_fixed=月光+小光×2（canon 引文 17024-17155）
7. kill_moves 26 条预制 damage
8. market_rules：gu_public_price=rank_standard_price×4
9. v1_battle_resolver=结算 Owner；battle2 并行 ORPHAN
10. 本机验收：check_balance 38/38 · tests 116/116 · autoplay 30/41
11. 禁止第四套 Rank/定价/战斗；30/24/50=Golden`;

document.getElementById('confOut').textContent = `C1 杀招结构 vs 手填 damage（产品方向）
C2 收入/店价/炼耗无购买力锚
C3 月芒 2 小光 canon vs 1 小光 lab
C4 Counter 高密度 vs 多语法战斗
C5 battle2 与 v1 双战斗
C6 单局 1→5 vs Roguelike 死亡环（知识可跨局/力量不可——请给倾向）`;

document.getElementById('wantOut').textContent = `1. Q1–Q6 逐项裁决（A/B/C 或修正案 + 不可做项）
2. 杀招组件化最小 schema 或书面否决
3. 购买力门禁表（可进 check_balance）
4. 投影 schema + 禁投影清单
5. Combat primitive 扩展准入清单
6. Rank 运行时最小字段集（≤8）
7. 五断点顺序确认 + 重大变更标注（呈 L0 清单）
8. （可选）C3 双炼方、C6 单局长度倾向`;

document.getElementById('tabs').addEventListener('click', (e) => {
  const b = e.target.closest('button[data-tab]');
  if (!b) return;
  document.querySelectorAll('.tabs button').forEach((x) => x.classList.remove('on'));
  document.querySelectorAll('.panel').forEach((x) => x.classList.remove('on'));
  b.classList.add('on');
  document.getElementById(b.dataset.tab).classList.add('on');
});
