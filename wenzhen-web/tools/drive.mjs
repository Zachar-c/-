/* 用真实时间驱动无头 Edge 的验证工具。不依赖虚拟时间。

   node tools/drive.mjs <url> "<计划>" [W,H]

   计划是一串用逗号分隔的步骤：
     wait:MS          等真实毫秒
     shot:PATH        截图
     move:X:Y         移动鼠标（触发视差 / 悬停）
     click:X:Y        点击
     eval:EXPR        在页面里求值并打印
     log              打印收集到的 console 与页面错误

   例：
     node tools/drive.mjs "http://127.0.0.1:4177/?gate=0" \
       "wait:6000,shot:a.png,move:900:500,wait:2000,shot:b.png,click:900:500,wait:3000,shot:c.png,log"

   用真实时间而不是 --virtual-time-budget：虚拟时间下 CSS 过渡只有被别的
   重算带动时才推进，会拍到假的中间态。 */

import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync, rmSync } from 'node:fs';
import path from 'node:path';

const EDGE = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const PORT = 9333;

const [, , url, plan = '', size = '1600,900'] = process.argv;

if (!url) {
  console.error('usage: node tools/drive.mjs <url> "<plan>" [W,H]');
  process.exit(2);
}

const [W, H] = size.split(',').map(Number);
const profile = path.join(process.env.TEMP || '.', 'wenzhen-drive-profile');
rmSync(profile, { recursive: true, force: true });

const edge = spawn(EDGE, [
  '--headless=new',
  '--hide-scrollbars',
  '--no-first-run',
  '--no-default-browser-check',
  '--disable-extensions',
  '--autoplay-policy=no-user-gesture-required',
  `--remote-debugging-port=${PORT}`,
  `--user-data-dir=${profile}`,
  `--window-size=${W},${H}`,
  'about:blank',
], { stdio: 'ignore' });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function debuggerUrl() {
  for (let i = 0; i < 120; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${PORT}/json/version`);
      const j = await r.json();
      if (j.webSocketDebuggerUrl) return j.webSocketDebuggerUrl;
    } catch { /* 还没起来 */ }
    await sleep(250);
  }
  throw new Error('devtools 端口没起来');
}

class Cdp {
  constructor(ws) {
    this.ws = ws;
    this.id = 0;
    this.pending = new Map();
    this.logs = [];
    ws.onmessage = (ev) => {
      const m = JSON.parse(ev.data);
      if (m.id && this.pending.has(m.id)) {
        const { resolve, reject } = this.pending.get(m.id);
        this.pending.delete(m.id);
        m.error ? reject(new Error(JSON.stringify(m.error))) : resolve(m.result);
      } else if (m.method === 'Runtime.consoleAPICalled') {
        this.logs.push(`[console.${m.params.type}] ` + m.params.args.map((a) => a.value ?? a.description).join(' '));
      } else if (m.method === 'Runtime.exceptionThrown') {
        const d = m.params.exceptionDetails;
        this.logs.push(`[exception] ${d.text} ${d.exception?.description || ''}`);
      } else if (m.method === 'Log.entryAdded') {
        const e = m.params.entry;
        if (e.level === 'error' || e.level === 'warning') this.logs.push(`[${e.level}] ${e.text} ${e.url || ''}`);
      }
    };
  }

  send(method, params = {}, sessionId) {
    const id = ++this.id;
    const msg = { id, method, params };
    if (sessionId) msg.sessionId = sessionId;
    this.ws.send(JSON.stringify(msg));
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      setTimeout(() => {
        if (this.pending.has(id)) {
          this.pending.delete(id);
          reject(new Error(`timeout: ${method}`));
        }
      }, 60000);
    });
  }
}

async function main() {
  const wsUrl = await debuggerUrl();
  const ws = new WebSocket(wsUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });

  const cdp = new Cdp(ws);

  const { targetInfos } = await cdp.send('Target.getTargets');
  const page = targetInfos.find((t) => t.type === 'page');
  const { sessionId } = await cdp.send('Target.attachToTarget', { targetId: page.targetId, flatten: true });

  const S = (m, p) => cdp.send(m, p, sessionId);

  await S('Page.enable');
  await S('Runtime.enable');
  await S('Log.enable');
  await S('Emulation.setDeviceMetricsOverride', {
    width: W, height: H, deviceScaleFactor: 1, mobile: false,
  });
  await S('Page.navigate', { url });

  const results = [];

  for (const raw of plan.split(',').map((s) => s.trim()).filter(Boolean)) {
    const [step, a, b] = raw.split(':');

    if (step === 'wait') {
      await sleep(Number(a));
    } else if (step === 'shot') {
      const abs = path.resolve(raw.slice(5));   // 用整段切，Windows 路径里有冒号
      mkdirSync(path.dirname(abs), { recursive: true });
      const { data } = await S('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
      writeFileSync(abs, Buffer.from(data, 'base64'));
      results.push(`shot ${abs}`);
    } else if (step === 'move') {
      await S('Input.dispatchMouseEvent', { type: 'mouseMoved', x: Number(a), y: Number(b), buttons: 0 });
    } else if (step === 'click') {
      const x = Number(a); const y = Number(b);
      await S('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y, buttons: 0 });
      await S('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', buttons: 1, clickCount: 1 });
      await sleep(40);
      await S('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', buttons: 0, clickCount: 1 });
    } else if (step === 'down') {
      await S('Input.dispatchMouseEvent', { type: 'mouseMoved', x: Number(a), y: Number(b), buttons: 0 });
      await S('Input.dispatchMouseEvent', { type: 'mousePressed', x: Number(a), y: Number(b), button: 'left', buttons: 1, clickCount: 1 });
    } else if (step === 'drag') {
      await S('Input.dispatchMouseEvent', { type: 'mouseMoved', x: Number(a), y: Number(b), button: 'left', buttons: 1 });
    } else if (step === 'up') {
      await S('Input.dispatchMouseEvent', { type: 'mouseReleased', x: Number(a), y: Number(b), button: 'left', buttons: 0, clickCount: 1 });
    } else if (step === 'drags') {
      // 一次完整的拖拽：drags:X1:Y1>X2:Y2
      // 中间必须真的发多次 mouseMoved，否则 pointermove 只触发一次，拖拽逻辑测不出来。
      const [from, to] = raw.slice(6).split('>');
      const [x1, y1] = from.split(':').map(Number);
      const [x2, y2] = to.split(':').map(Number);
      await S('Input.dispatchMouseEvent', { type: 'mouseMoved', x: x1, y: y1, buttons: 0 });
      await S('Input.dispatchMouseEvent', { type: 'mousePressed', x: x1, y: y1, button: 'left', buttons: 1, clickCount: 1 });
      const N = 16;
      for (let i = 1; i <= N; i++) {
        const t = i / N;
        await S('Input.dispatchMouseEvent', {
          type: 'mouseMoved',
          x: Math.round(x1 + (x2 - x1) * t),
          y: Math.round(y1 + (y2 - y1) * t),
          button: 'left',
          buttons: 1,
        });
        await sleep(30);
      }
      await S('Input.dispatchMouseEvent', { type: 'mouseReleased', x: x2, y: y2, button: 'left', buttons: 0, clickCount: 1 });
    } else if (step === 'eval') {
      const r = await S('Runtime.evaluate', { expression: raw.slice(5), returnByValue: true });
      results.push(`eval → ${JSON.stringify(r.result?.value ?? r.result?.description)}`);
    } else if (step === 'log') {
      results.push(cdp.logs.length ? cdp.logs.join('\n') : '(无 console 输出、无错误)');
      cdp.logs = [];
    } else {
      results.push(`!! 未知步骤 ${raw}`);
    }
  }

  console.log(results.join('\n'));
  if (cdp.logs.length) console.log('--- 未读日志 ---\n' + cdp.logs.join('\n'));

  try { await cdp.send('Browser.close'); } catch { /* ignore */ }
  ws.close();
  await sleep(400);
  edge.kill();
}

main().catch((e) => {
  console.error('drive 失败:', e.message);
  edge.kill();
  process.exit(1);
});
