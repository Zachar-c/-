/* 动效层一次性探针（验收用，不入产品链）：
 * 只用 tests/helpers/lab_browser.mjs 的公开 API（bootInfo / click / shoot / logs），
 * 不另造浏览器启动器、不碰内部 evalJs。
 *   1) file:// 启动 lab.html（helper 内部等待 dataset.ready）；
 *   2) __labBootInfo().motion 断言：vendor GSAP 3.13.0 已载入、Motion.active、html.motion-on 已挂；
 *   3) 点「开始新局」触发真实换页，抓两张即时截图留档（0.36s 进场窗口内能否截到中间帧看时机）；
 *   4) CDP console / exception 必须全干净。
 * 用法：node tools/motion_probe.mjs
 */
import assert from 'node:assert/strict';
import { openLab } from '../tests/helpers/lab_browser.mjs';

const lab = await openLab({ viewport: [1280, 720] });
const fail = [];
const check = (name, ok, detail = '') => {
  console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${detail ? ` — ${detail}` : ''}`);
  if (!ok) fail.push(name);
};
try {
  const info = await lab.bootInfo();
  assert.ok(info && info.motion, 'bootInfo 缺少 motion 诊断块');
  check('vendor gsap.min.js loaded', info.motion.gsap === '3.13.0', `version=${info.motion.gsap}`);
  check('Motion.active (motion-on 已挂)', info.motion.active === true && info.motion.motionOn === true,
    JSON.stringify(info.motion));

  // 触发一次真实换页：大厅「开始新局」→ 行程页。进场 tween 全程 ~0.56s，连抓两张截图。
  await lab.click('[data-start-run]');
  await lab.shoot('screenshots/motion-probe-map-early.png');
  await lab.click('[data-return-node]').catch(() => {}); // 若已在 map，无伤；否则回 map 再截一帧
  await lab.shoot('screenshots/motion-probe-map-late.png');

  const snap = await lab.snapshot();
  check('换页后落在行程页', snap?.page === 'map', `page=${snap?.page}`);

  const errors = lab.logs().filter((l) => /\[exception\]|\[console\.error\]/.test(l));
  check('console / exception 干净', errors.length === 0, errors.slice(0, 3).join(' | ') || 'clean');
} finally {
  await lab.close();
}
if (fail.length) {
  console.error(`motion_probe: ${fail.length} 项未过`);
  process.exit(1);
}
console.log('motion_probe: 全部通过');
