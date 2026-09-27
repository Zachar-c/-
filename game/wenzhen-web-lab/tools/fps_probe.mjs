/* 稳定 60 帧 + 1% low 验收探针（不入产品链）：
 * 在真实 Chromium 里用 lab_browser.sampleFps 采样 rAF 间隔。
 * 验收口径：
 *   - 平均 FPS ≥ 55
 *   - P95 帧间隔 ≤ 16.7ms（≈ 不掉到 60 以下的主流量）
 *   - **1% low FPS > 60**（最差 1% 帧平均帧时间 < 16.7ms）
 * 覆盖：大厅空闲、开局换页、连续交互中的 draw 热路径。
 * 用法：node tools/fps_probe.mjs
 */
import { openLab } from '../tests/helpers/lab_browser.mjs';

const SAMPLE_MS = 1600;

const lab = await openLab({ viewport: [1280, 720] });
const fail = [];
const check = (name, ok, detail = '') => {
  console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${detail ? ` — ${detail}` : ''}`);
  if (!ok) fail.push(name);
};

async function sample(label) {
  const stats = await lab.sampleFps(SAMPLE_MS);
  console.log(
    `  [${label}] frames=${stats.frames} avgFps=${stats.avgFps.toFixed(1)}`
    + ` low1=${stats.low1.toFixed(1)} low1Gap=${stats.low1Gap.toFixed(2)}ms`
    + ` p95=${stats.p95.toFixed(2)}ms max=${stats.max.toFixed(2)}ms`,
  );
  return stats;
}

function checkBudget(label, stats) {
  check(`${label} avgFps ≥ 55`, stats.avgFps >= 55, `avgFps=${stats.avgFps.toFixed(1)}`);
  check(`${label} 1% low > 60`, stats.low1 > 60, `low1=${stats.low1.toFixed(1)} low1Gap=${stats.low1Gap.toFixed(2)}ms`);
  check(`${label} p95 ≤ 16.7ms`, stats.p95 <= 16.7, `p95=${stats.p95.toFixed(2)}`);
}

// 边点边采：让 draw/持久化落在采样窗口内，专打 1% low。
async function sampleDuringClicks(label, selectors) {
  const sampling = lab.sampleFps(SAMPLE_MS);
  for (const sel of selectors) {
    await lab.click(sel).catch(() => {});
    await new Promise((r) => setTimeout(r, 120));
  }
  const stats = await sampling;
  console.log(
    `  [${label}] frames=${stats.frames} avgFps=${stats.avgFps.toFixed(1)}`
    + ` low1=${stats.low1.toFixed(1)} low1Gap=${stats.low1Gap.toFixed(2)}ms`
    + ` p95=${stats.p95.toFixed(2)}ms max=${stats.max.toFixed(2)}ms`,
  );
  return stats;
}

try {
  const idle = await sample('hall-idle');
  checkBudget('大厅空闲', idle);

  await lab.click('[data-start-run]');
  const map = await sample('map-after-start');
  checkBudget('开局后行程', map);

  const interactive = await sampleDuringClicks('click-during-sample', [
    '[data-choose-node]',
    '[data-return-node]',
    '[data-prep-continue]',
    '[data-start-encounter]',
    '[data-basic-attack]',
    '[data-end-turn]',
    '[data-use-gu]',
    '[data-use]',
  ]);
  checkBudget('交互热路径', interactive);

  const errors = lab.logs().filter((l) => /\[exception\]|\[console\.error\]/.test(l));
  check('console / exception 干净', errors.length === 0, errors.slice(0, 3).join(' | ') || 'clean');
} finally {
  await lab.close();
}

if (fail.length) {
  console.error(`fps_probe: ${fail.length} 项未过`);
  process.exit(1);
}
console.log('fps_probe: 全部通过');
