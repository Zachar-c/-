/* 模型脊柱浏览器 · 只读展示 + 传播实验 */
const S = window.SPINE || { acceptance: [], sample: { gu: [], edges: [], killerMoves: [], enemies: [], impact: {} }, layers: {} };

const $ = (s) => document.querySelector(s);

function renderLayers() {
  const layers = [
    { t: 'L1 Canonical', d: '原著事实 / Dao Profile。禁止伤害价格。', files: S.layers.canonical || [] },
    { t: 'L2 Rulings', d: 'Fact → 游戏身份与禁令。扩写必须过此层。', files: S.layers.rulings || [] },
    { t: 'L3 Model', d: 'Rank / Quality / Effect / Enemy / Economy / 炼图 / 杀招骨架 / Primitives', files: S.layers.models || [] },
    { t: 'L4 Projection', d: '推导 damage/qi/price/drop → generated/', files: S.layers.projections || [] },
    { t: 'Simulation', d: '战斗 / 经济 / 成长 / 五条复利验收', files: (S.layers.generated || []).concat(['acceptance_spine.mjs']) },
    { t: 'Golden Set', d: '30 蛊 / 24 杀招 / 50 敌人 = 校准集，不是真源', files: S.layers.golden || [] },
  ];
  $('#layerCards').innerHTML = layers
    .map(
      (l) => `<article class="layer-card">
        <h3>${l.t}</h3>
        <p>${l.d}</p>
        <ul>${(l.files || []).map((f) => `<li>${f}</li>`).join('')}</ul>
      </article>`
    )
    .join('');
}

function renderAccept() {
  const list = S.acceptance || [];
  $('#acceptList').innerHTML = list
    .map(
      (a) => `<div class="accept-item ${a.pass ? '' : 'fail'}">
        <div class="mark">${a.pass ? '✓' : '×'}</div>
        <div><strong>${a.name}</strong><span>${a.detail || ''}</span></div>
      </div>`
    )
    .join('');
}

function renderVectors() {
  const gu = S.sample.gu || [];
  $('#vectorList').innerHTML = gu
    .map((g) => {
      const v = g.value_vector || {};
      const bars = Object.entries(v)
        .map(([k, n]) => `<span class="bar">${k} <b>${n}</b></span>`)
        .join('');
      return `<div class="vec-row"><div class="name">${g.name}<br><span style="color:var(--muted)">${g.id} · R${g.rank}</span></div><div class="bars">${bars}</div></div>`;
    })
    .join('');
}

function renderGraph() {
  const imp = S.sample.impact || {};
  $('#graphOut').textContent =
    `Q: 月芒市场价为什么是这个数？\n` +
    `↑ market = intrinsic × tier × scarcity × supply × demand × markup\n` +
    `↑ 二转经济购买力（EconomyProfile）\n` +
    `↑ 炼制期望成本 = once/success\n` +
    `↑ 月光 + 小光×2（canonical recipe）\n` +
    `↑ 小光供应 / 稀缺 / 掉落 / 商店\n\n` +
    `impact(scarcity.small_light_gu) →\n` +
    JSON.stringify(imp, null, 2);
}

function renderEdges() {
  const edges = S.sample.edges || [];
  $('#edgeOut').textContent = edges
    .map((e) => `${e.id}  ${e.from.join('+')} → ${e.to}\n    success=${(e.success * 100).toFixed(0)}%  once=${e.onceCost}  expected=${e.expectedCost}  market=${e.marketPrice}`)
    .join('\n\n');
}

$('#tabs').addEventListener('click', (e) => {
  const b = e.target.closest('button[data-tab]');
  if (!b) return;
  document.querySelectorAll('.tabs button').forEach((x) => x.classList.remove('on'));
  document.querySelectorAll('.panel').forEach((x) => x.classList.remove('on'));
  b.classList.add('on');
  $('#' + b.dataset.tab).classList.add('on');
});

$('#runCascade').addEventListener('click', () => {
  const mode = $('#scarcity').value;
  const imp = { ...(S.sample.impact || {}) };
  if (mode) {
    imp.notes = [...(imp.notes || []), `实验：小光 scarcity=${mode}（详见 acceptance_spine 第 3 条）`];
    imp.gu = [...new Set([...(imp.gu || []), 'small_light_gu', 'moon_glow_gu'])];
    imp.killer_moves = [...new Set([...(imp.killer_moves || []), 'double_moon_blades', 'moonglow_break'])];
    imp.refine_edges = [...new Set([...(imp.refine_edges || []), 'R01→moon_glow'])];
  }
  $('#impactOut').textContent = JSON.stringify(imp, null, 2);
  const edges = S.sample.edges || [];
  const glow = edges.find((e) => e.to === 'moon_glow_gu') || edges[0];
  const mult = mode === 'extreme' ? 1.35 : mode === 'high' ? 1.15 : 1;
  if (glow) {
    const exp = Math.round(glow.expectedCost * mult);
    $('#edgeOut').textContent =
      `moonlight + small_light×2 → moon_glow\n` +
      `  once ≈ ${Math.round(glow.onceCost * mult)}\n` +
      `  expected = once/success(${(glow.success * 100).toFixed(0)}%) ≈ ${exp}\n` +
      `  （完整重算请跑 simulation/acceptance_spine.mjs）`;
  }
});

renderLayers();
renderAccept();
renderVectors();
renderGraph();
renderEdges();
$('#impactOut').textContent = JSON.stringify(S.sample.impact || {}, null, 2);
