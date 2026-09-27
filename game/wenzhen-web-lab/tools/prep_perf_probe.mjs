/* prep 热路径计时探针（不入产品链）：页内同步点击耗时（含 draw）。
 * 用法：node tools/prep_perf_probe.mjs
 */
import { openLab } from '../tests/helpers/lab_browser.mjs';

const lab = await openLab({ viewport: [1280, 720] });

async function timeMeasure(label, selector, times = 5) {
  const samples = [];
  for (let i = 0; i < times; i++) {
    const r = await lab.measureClick(selector);
    if (!r?.ok) {
      console.log(`  [${label}] skip (${r?.reason || 'fail'})`);
      return null;
    }
    samples.push(r.ms);
    await new Promise((r2) => setTimeout(r2, 16));
  }
  const avg = samples.reduce((s, x) => s + x, 0) / samples.length;
  const max = Math.max(...samples);
  console.log(`  [${label}] n=${times} avg=${avg.toFixed(1)}ms max=${max.toFixed(1)}ms samples=${samples.map((x) => x.toFixed(1)).join(',')}`);
  return { avg, max };
}

try {
  await lab.click('[data-start-run]');
  for (let i = 0; i < 16; i++) {
    const s = await lab.snapshot();
    if (s?.page === 'prep') break;
    if (s?.page === 'map' && s?.journey?.availableNodeIds?.length) {
      await lab.click('[data-choose-node]').catch(() => {});
    } else if (s?.page === 'node-action') {
      await lab.click('[data-node-action]').catch(() => {});
    } else if (s?.page === 'battle') {
      await lab.click('[data-start-encounter]').catch(() => {});
      await lab.click('[data-basic-attack]').catch(() => {});
      await lab.click('[data-end-turn]').catch(() => {});
    } else if (s?.page === 'reward') {
      await lab.click('[data-reward-gu]').catch(() => {});
      await lab.click('[data-reward-continue]').catch(() => {});
    } else {
      await lab.click('button.primary, [data-choose-node], [data-prep-continue]').catch(() => {});
    }
    await new Promise((r) => setTimeout(r, 60));
  }
  console.log('landed page=', (await lab.snapshot())?.page);

  console.log('--- prep tabs (page-local sync ms) ---');
  await timeMeasure('tab-shop', '[data-prep-tab="shop"]');
  await timeMeasure('tab-gu', '[data-prep-tab="gu"]');
  await timeMeasure('tab-alchemy', '[data-prep-tab="alchemy"]');
  await timeMeasure('tab-killmove', '[data-prep-tab="killmove"]');
  await timeMeasure('tab-alchemy-again', '[data-prep-tab="alchemy"]');

  console.log('--- actions ---');
  await timeMeasure('buy-or-break', '[data-buy-offer]:not([disabled]), [data-break]:not([disabled])');
  await timeMeasure('forge', '[data-forge]:not([disabled])');
  await timeMeasure('km', '[data-km]:not([disabled])');

  const errors = lab.logs().filter((l) => /\[exception\]|\[console\.error\]/.test(l));
  console.log('errors:', errors.slice(0, 5).join(' | ') || 'clean');
} finally {
  await lab.close();
}
