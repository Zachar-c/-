/* lab 浏览器测试 helper：复用 tools/autoplay.mjs 的 CDP 连接思路。
 * W2–W4 的 Node 集成测试和 W6 driver 复用此 helper，不各造浏览器启动器。
 * 公开 API 仅：url / logs / click / snapshot / reload / shoot / close / bootInfo（只读）。
 * 不提供 state-write / act-call 捷径；内部 evalJs 只服务 click / snapshot / bootInfo / readiness。
 */
import { spawn } from 'node:child_process';
import net from 'node:net';
import { existsSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const EDGE_CANDIDATES = [
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
];

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function findBrowser(explicit) {
  if (explicit) return explicit;
  const found = EDGE_CANDIDATES.find((p) => existsSync(p));
  if (!found) {
    throw new Error('lab_browser: 找不到 Edge/Chrome（测试浏览器依赖不可用），可用 edge 选项指定');
  }
  return found;
}

function freePort() {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.once('error', reject);
    srv.listen(0, '127.0.0.1', () => {
      const { port } = srv.address();
      srv.close(() => resolve(port));
    });
  });
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
        this.logs.push(`[console.${m.params.type}] ` + m.params.args.map((x) => x.value ?? x.description).join(' '));
      } else if (m.method === 'Runtime.exceptionThrown') {
        const d = m.params.exceptionDetails;
        this.logs.push(`[exception] ${d.text} ${d.exception?.description || ''}`);
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

async function attach(edgePath, port, size) {
  const profile = path.join(process.env.TEMP || '.', `wenzhen-lab-browser-${port}`);
  rmSync(profile, { recursive: true, force: true });
  const args = [
    '--headless=new',
    '--hide-scrollbars', '--no-first-run', '--no-default-browser-check',
    '--disable-extensions', '--autoplay-policy=no-user-gesture-required',
    `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`,
    `--window-size=${size[0]},${size[1]}`, 'about:blank',
  ];
  const proc = spawn(edgePath, args, { stdio: 'ignore' });

  let wsUrl = '';
  for (let i = 0; i < 120 && !wsUrl; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${port}/json/version`);
      wsUrl = (await r.json()).webSocketDebuggerUrl || '';
    } catch { /* not up yet */ }
    if (!wsUrl) await sleep(250);
  }
  if (!wsUrl) {
    proc.kill();
    throw new Error('lab_browser: devtools 端口没起来（测试浏览器依赖不可用）');
  }

  const ws = new WebSocket(wsUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
  const cdp = new Cdp(ws);
  const { targetInfos } = await cdp.send('Target.getTargets');
  const page = targetInfos.find((t) => t.type === 'page');
  const { sessionId } = await cdp.send('Target.attachToTarget', { targetId: page.targetId, flatten: true });
  const S = (m, p) => cdp.send(m, p, sessionId);
  await S('Page.enable');
  await S('Runtime.enable');
  await S('Emulation.setDeviceMetricsOverride', {
    width: size[0], height: size[1], deviceScaleFactor: 1, mobile: false,
  });
  return { cdp, proc, ws, S, profile };
}

/**
 * openLab({ entry, seed, viewport, edge })
 * entry: lab.html 绝对路径或 file URL
 * seed: 仅用于明确新局的 ?seed=
 * viewport: [w, h]，默认 1280x720
 * returns { click, snapshot, reload, close, shoot, logs }
 */
export async function openLab(options = {}) {
  const viewport = options.viewport || [1280, 720];
  const edgePath = findBrowser(options.edge);
  const port = await freePort();
  let entryUrl;
  if (String(options.entry || '').startsWith('file:') || String(options.entry || '').startsWith('http')) {
    entryUrl = String(options.entry);
  } else if (options.entry) {
    entryUrl = pathToFileURL(path.resolve(options.entry)).href;
  } else {
    entryUrl = pathToFileURL(path.resolve(import.meta.dirname, '../../lab.html')).href;
  }
  if (options.seed != null) {
    const join = entryUrl.includes('?') ? '&' : '?';
    entryUrl = `${entryUrl}${join}seed=${encodeURIComponent(options.seed)}`;
  }

  const env = await attach(edgePath, port, viewport);
  const { cdp, proc, ws, S, profile } = env;
  let currentUrl = entryUrl;

  const evalJs = async (expression) => {
    const r = await S('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    if (r.exceptionDetails) {
      throw new Error('页面求值异常: ' + (r.exceptionDetails.exception?.description || r.exceptionDetails.text));
    }
    return r.result?.value;
  };

  const waitForReady = async () => {
    for (let i = 0; i < 40; i++) {
      const ready = await evalJs(`document.documentElement.dataset.ready === '1'`);
      if (ready) return;
      await sleep(50);
    }
    throw new Error('lab_browser: 等待 dataset.ready 超时');
  };

  await S('Page.navigate', { url: currentUrl });
  await waitForReady();

  const api = {
    url: () => currentUrl,
    logs: () => cdp.logs.slice(),
    async click(selector) {
      const result = await evalJs(`(() => {
        const els = [...document.querySelectorAll(${JSON.stringify(selector)})];
        const b = els.find((e) => !e.disabled);
        if (!b) return 'NONE';
        b.click();
        return 'ok';
      })()`);
      if (result === 'NONE') throw new Error(`click 目标全被禁用: ${selector}`);
      await sleep(80);
      return true;
    },
    async snapshot() {
      // 只读完整可序列化 state（main.js __labSnapshot）。
      const value = await evalJs(`(typeof __labSnapshot === 'function') ? __labSnapshot() : null`);
      return value;
    },
    async bootInfo() {
      const value = await evalJs(`(typeof __labBootInfo === 'function') ? __labBootInfo() : null`);
      return value;
    },
    async reload() {
      await S('Page.navigate', { url: currentUrl });
      await waitForReady();
    },
    async shoot(filePath) {
      mkdirSync(path.dirname(filePath), { recursive: true });
      const { data } = await S('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
      writeFileSync(filePath, Buffer.from(data, 'base64'));
      return filePath;
    },
    async close() {
      try { await cdp.send('Browser.close'); } catch { /* ignore */ }
      try { ws.close(); } catch { /* ignore */ }
      await sleep(200);
      try { proc.kill(); } catch { /* ignore */ }
      try { rmSync(profile, { recursive: true, force: true }); } catch { /* ignore */ }
    },
  };
  return api;
}
