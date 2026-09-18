/* 舞台。整个「引擎」就是这些东西，没有更多。
   场景是 async 函数，按顺序 await 下去，读起来就是它发生的时间顺序。 */

import {
  initAudio, resumeAudio, fadeMaster, soundVault, soundRain, fadeRoom,
  heartbeat, chime, startAmbientDrops, soundRoom, swallow, stoneTick, murmur,
} from './audio.js';
import { vaultScene } from './scenes/01_vault.js';
import { rainScene } from './scenes/02_rain.js';
import { feedScene } from './scenes/03_feed.js';
import { visitScene } from './scenes/04_visit.js';

const stageEl = document.getElementById('stage');
const flashEl = document.getElementById('flash');
const params = new URLSearchParams(location.search);
const EASE = 'cubic-bezier(.4, 0, .2, 1)';

// 出错时不要只给一块黑屏。黑屏是最贵的调试成本。
const debugEl = document.createElement('pre');
debugEl.id = 'debug';
debugEl.style.cssText = 'position:fixed;left:10px;bottom:10px;z-index:999;max-width:72vw;margin:0;' +
  'padding:10px 12px;display:none;white-space:pre-wrap;word-break:break-all;' +
  'font:12px/1.6 ui-monospace,monospace;color:#ff9a9a;background:rgba(0,0,0,.82)';
document.body.appendChild(debugEl);

const report = (msg) => {
  debugEl.style.display = 'block';
  debugEl.textContent += msg + '\n';
};
window.addEventListener('error', (e) => report(`[error] ${e.message} @ ${e.filename}:${e.lineno}`));
window.addEventListener('unhandledrejection', (e) => report(`[reject] ${e.reason?.stack || e.reason}`));

const stage = {
  params,
  state: {},                 // 幕与幕之间要留下的东西。一个普通对象，够用。
  audio: {
    initAudio, resumeAudio, fadeMaster, soundVault, soundRain, fadeRoom,
    heartbeat, chime, startAmbientDrops, soundRoom, swallow, stoneTick, murmur,
  },

  wait(ms) {
    return new Promise((r) => setTimeout(r, ms));
  },

  /** 新建一层。depth 是视差深度：0 不动，数字越大跟鼠标越近。 */
  layer(depth = 0) {
    const el = document.createElement('div');
    el.className = 'layer';
    el.style.setProperty('--depth', depth);
    stageEl.appendChild(el);
    return el;
  },

  /** 新建一个元素挂在某层下面 */
  put(parent, tag, className, html) {
    const el = document.createElement(tag);
    if (className) el.className = className;
    if (html != null) el.innerHTML = html;
    parent.appendChild(el);
    return el;
  },

  fade(node, to, ms = 1000, delay = 0) {
    return new Promise((res) => {
      node.style.transition = `opacity ${ms}ms ${EASE} ${delay}ms`;
      // 强制一次样式刷新，把「当前值」坐实，再改成目标值，过渡才会真的跑起来。
      // 不用 requestAnimationFrame：那要求浏览器正在出帧，无头渲染时不一定。
      void node.offsetWidth;
      node.style.opacity = String(to);
      setTimeout(res, ms + delay + 30);
    });
  },

  /** 让画面随鼠标缓慢位移。相机跟着人动，人才在画面里。 */
  parallax() {
    window.addEventListener('pointermove', (e) => {
      stageEl.style.setProperty('--px', (e.clientX / window.innerWidth - 0.5).toFixed(3));
      stageEl.style.setProperty('--py', (e.clientY / window.innerHeight - 0.5).toFixed(3));
    });
  },

  /** 悬停一次就回调（只触发一次） */
  onFirstHover(layer, fn) {
    layer.classList.add('lookable');
    layer.addEventListener('pointerenter', fn, { once: true });
  },

  /** 等玩家点在某层上 */
  waitForLook(layer) {
    layer.classList.add('lookable');
    return new Promise((res) => layer.addEventListener('pointerdown', res, { once: true }));
  },

  /** 等玩家点任意处 */
  waitForClick() {
    return new Promise((res) => window.addEventListener('pointerdown', res, { once: true }));
  },

  /** 白场。切场不用淡入淡出，用一次曝光过渡。 */
  async whiteout(peak = 0.92, up = 620, down = 2100) {
    await this.fade(flashEl, peak, up);
    this.fade(flashEl, 0, down);
  },

  /** 把当前所有层一起淡掉再删掉。用来做「叠化」，不是硬切。 */
  async fadeOutAll(ms = 1800) {
    const layers = [...stageEl.querySelectorAll('.layer')];
    await Promise.all(layers.map((l) => this.fade(l, 0, ms)));
    layers.forEach((l) => l.remove());
  },

  clear() {
    stageEl.querySelectorAll('.layer').forEach((n) => n.remove());
  },
};

async function boot() {
  const gate = document.getElementById('gate');
  const startAt = params.get('scene');

  if (params.get('gate') !== '0') {
    await stage.wait(700);
    await stage.fade(gate.querySelector('.gate-hint'), 1, 1700);
    await stage.waitForClick();
  } else {
    gate.remove();
  }

  if (params.get('silent') !== '1') {
    initAudio();
    resumeAudio();
    fadeMaster(0.9, 3000);
    soundVault();
    soundRain();
  }

  if (gate.parentNode) {
    await stage.fade(gate, 0, 1000);
    gate.remove();
  }

  if (startAt === 'rain') {
    fadeRoom('rain', 1, 3000);
    await rainScene(stage);
    return;
  }
  if (startAt === 'feed') {
    fadeRoom('rain', 1, 1500);
    await feedScene(stage);
    return;
  }
  if (startAt === 'visit') {
    await visitScene(stage);
    return;
  }

  await vaultScene(stage);
  await rainScene(stage);
  await feedScene(stage);
  await visitScene(stage);

  // 原型到此。第五幕还没写。
  const marker = stage.layer(0);
  stage.put(marker, 'div', 'marker', '原型到此 · 第四幕完 · 选择：' + (stage.state.act4 ?? '—'));
  await stage.fade(marker, 1, 2200, 1400);
}

// ?probe=1 时把各层「实际算出来的」opacity 打在屏幕上。
// 截图是黑屏、DOM 却一切正常的时候，只有这个东西能分辨。
if (params.get('probe') === '1') {
  debugEl.style.display = 'block';
  debugEl.style.color = '#7fff7f';
  setInterval(() => {
    const ops = [...stageEl.querySelectorAll('.layer')]
      .map((l) => (l.firstElementChild ? l.firstElementChild.className : '?') + '=' + getComputedStyle(l).opacity);
    debugEl.textContent = `t=${Math.round(performance.now())}\n${ops.join('\n') || '(无层)'}`;
  }, 300);
}

boot();
