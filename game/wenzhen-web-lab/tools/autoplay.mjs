/* 《问真》10 分钟循环的第一道产品验收门：真实 DOM 自动走盘。
 *
 * 为什么需要它：88/88 只能证明「按钮能按、状态能变」，证明不了
 * 「这个游戏数学上还能不能玩」。本工具用无头 Edge + CDP 把 index.html
 * 从第一战真实操作到结算，并逐场记录资源轨迹。
 *
 * 用法：
 *   node tools/autoplay.mjs --route sacrifice
 *   node tools/autoplay.mjs --route all --seed 101 --trace
 *   node tools/autoplay.mjs --route all --json
 *
 * 选项：
 *   --route <secure|sacrifice|debt|all>  交易分支，all = 三条依次跑（默认 all）
 *   --seed <N>                           覆盖局面种子（页面 ?seed=N）
 *   --seeds <list|range>                 多种子达标率，如 101,102 或 101-110
 *   --min-clear-rate <0..1>              每路线通关率门槛（多种子时生效，默认 0.7）
 *   --trace                              打印每场战报与逐回合决策
 *   --json                               末尾输出机器可读结果
 *   --shots <dir>                        逐步截图目录
 *   --max-steps <N>                      单局步数上限（防死循环，默认 900）
 *   --headed                             不用 headless
 *
 * 判定区间来自 2026-09-21 L1 冻结规则 V4。区间原文、当前阻塞与待裁决杠杆见
 * docs/2026-09-21-v4-calibration-handoff.md；本文件只测量与判定，不改数值。
 */

import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const ROUTES = ['secure', 'sacrifice', 'debt'];

const EDGE_CANDIDATES = [
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
];

/* L1 V4.1 验收区间。battleKey 用遭遇 id 对齐。
   回合窗口是「10 分钟」的代理指标，不是产品目标本身。 */
const ACCEPTANCE = {
  postBattleHp: { battle_1: 18, battle_2: 12, elite: 8 },
  turnTarget: {
    battle_1: [3, 5],
    battle_2: [4, 6],
    elite: [4, 6],
    boss: [6, 9],
  },
  totalTurns: [17, 24],
  /* 逆息是保险丝，不能成为构筑主循环 */
  maxExhaustionPerRun: 2,
};

/* ---------------- 参数 ---------------- */

function parseSeedList(spec) {
  const text = String(spec || '').trim();
  if (!text) return [];
  if (/^\d+-\d+$/.test(text)) {
    const [a, b] = text.split('-').map(Number);
    if (b < a) throw new Error(`种子区间无效: ${text}`);
    const out = [];
    for (let s = a; s <= b; s++) out.push(s);
    return out;
  }
  return text.split(',').map((x) => Number(x.trim())).filter((n) => Number.isFinite(n));
}

function parseArgs(argv) {
  const opts = {
    routes: null,
    seed: null,
    seeds: null,
    minClearRate: 0.7,
    trace: false,
    json: false,
    shots: '',
    maxSteps: 900,
    headed: false,
    edge: '',
    url: '',
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const next = () => argv[++i];
    if (a === '--route') { opts.routes = String(next()).split(','); }
    else if (a === '--seed') { opts.seed = Number(next()); }
    else if (a === '--seeds') { opts.seeds = parseSeedList(next()); }
    else if (a === '--min-clear-rate') { opts.minClearRate = Number(next()); }
    else if (a === '--trace') { opts.trace = true; }
    else if (a === '--json') { opts.json = true; }
    else if (a === '--shots') { opts.shots = next(); }
    else if (a === '--max-steps') { opts.maxSteps = Number(next()); }
    else if (a === '--headed') { opts.headed = true; }
    else if (a === '--edge') { opts.edge = next(); }
    else if (a === '--url') { opts.url = next(); }
    else { console.error(`未知参数: ${a}`); process.exit(2); }
  }
  if (!opts.routes) opts.routes = ['all'];
  if (opts.routes.includes('all')) opts.routes = [...ROUTES];
  for (const r of opts.routes) {
    if (!ROUTES.includes(r)) { console.error(`未知路线: ${r}`); process.exit(2); }
  }
  if (opts.seeds && opts.seeds.length) {
    /* 多种子模式：--seeds 覆盖 --seed */
  } else if (opts.seed !== null && Number.isFinite(opts.seed)) {
    opts.seeds = [opts.seed];
  } else {
    opts.seeds = [null];
  }
  if (!(opts.minClearRate >= 0 && opts.minClearRate <= 1)) {
    console.error('--min-clear-rate 必须在 0~1');
    process.exit(2);
  }
  if (!opts.url) opts.url = pathToFileURL(path.resolve(import.meta.dirname, '../index.html')).href;
  return opts;
}

function findEdge(explicit) {
  if (explicit) return explicit;
  const found = EDGE_CANDIDATES.find((p) => existsSync(p));
  if (!found) throw new Error('找不到 Edge/Chrome，可用 --edge 指定');
  return found;
}

/* ---------------- CDP ---------------- */

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

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
        if (this.pending.has(id)) { this.pending.delete(id); reject(new Error(`timeout: ${method}`)); }
      }, 60000);
    });
  }
}

async function attach(edgePath, port, headed, size) {
  const profile = path.join(process.env.TEMP || '.', `wenzhen-autoplay-${port}`);
  rmSync(profile, { recursive: true, force: true });
  const args = [
    headed ? '--new-window' : '--headless=new',
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
    } catch { /* 还没起来 */ }
    if (!wsUrl) await sleep(250);
  }
  if (!wsUrl) { proc.kill(); throw new Error('devtools 端口没起来'); }

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
    width: size[0], height: size[1], deviceScaleFactor: 1, mobile: false,
  });
  return { cdp, proc, ws, S };
}

/* 页面探针：DOM（能点什么是页面说了算）+ Mvp.stats()（纯逻辑指标）。
   注意 mvp.js 里 Mvp 是顶层 const，顶层 const 不会挂到 globalThis 上，
   只能按词法名直接访问——写成 globalThis.Mvp 会永远是 undefined。 */
const PROBE = `(() => {
  const q = (s) => document.querySelector(s);
  const stats = (typeof Mvp !== 'undefined' && Mvp.stats) ? Mvp.stats() : null;
  let screen = 'unknown';
  if (q('[data-restart-bottom]')) screen = 'ending';
  else if (q('[data-end-turn]')) screen = 'battle';
  else if (q('[data-next-step]')) screen = 'won';
  else if (q('[data-trade]')) screen = 'bazaar';
  else if (q('[data-preserve]') || q('[data-forge]')) screen = 'forge';
  const actions = [...document.querySelectorAll('[data-use-gu]')].map((b) => ({
    id: b.dataset.useGu,
    instance: Number(b.dataset.instance),
    disabled: b.disabled,
    text: b.innerText.replace(/\\s+/g, ' '),
  }));
  return JSON.stringify({
    screen,
    heading: q('h1')?.innerText?.trim() || '',
    actions,
    trades: [...document.querySelectorAll('[data-trade]')].map((b) => ({ id: b.dataset.trade, disabled: b.disabled })),
    observe: !!q('[data-observe]') && !q('[data-observe]').disabled,
    defend: !!q('[data-defend]') && !q('[data-defend]').disabled,
    exhaust: !!q('[data-exhaust]') && !q('[data-exhaust]').disabled,
    forge: !!q('[data-forge]') && !q('[data-forge]').disabled,
    preserve: !!q('[data-preserve]'),
    nextStep: !!q('[data-next-step]'),
    overflow: { sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth },
    stats,
  });
})()`;

/* ---------------- 策略 ----------------
   按 V4.1 规则决策：先「读对」（识破反制），再「做对」（执行反制要求）。
   正确处理 → -3，所以不做对就等于白读。
   迎击只吞直接攻击，不禁止其他行动——不得把 intercept 执行成整回合放弃。 */

function chooseActions(s, memory = { padTurn: -1, defendTurn: -1 }) {
  const st = s.stats;
  const b = st?.battle;
  const avail = s.actions.filter((a) => !a.disabled);
  const hasGu = (id) => avail.some((a) => a.id === id);
  const gu = (id) => avail.find((a) => a.id === id);
  const intent = b?.intent || null;
  const intentDamage = Number(intent?.damage || 0);
  const willHit = intentDamage > 0;
  const bigHit = intentDamage >= 5;
  const counter = b?.currentCounter || '';
  const identified = !!b?.revealed;
  const hp = st?.hp ?? 0;
  const hpMax = st?.hpMax ?? 24;
  const qi = st?.qi ?? 0;
  const lowHp = hp <= 12;
  const support = Number(b?.lightSupport || 0);

  // 1) 读对：还没识破就先花 1 念头看。小光蛊照见 + 光道支援，比「观察」更划算。
  if (counter && !identified) {
    if (hasGu('small_light_gu')) return { kind: 'gu', id: 'small_light_gu', why: '识破反制(小光)' };
    if (s.observe) return { kind: 'observe', why: '识破反制(观察)' };
  }

  /* 输出优先级：小光蛊（0 真元，光道）→ 月光蛊（吃支援后 0 真元 +1 伤）。
     这条组合是唯一「不烧真元」的输出线，烧真元去补护体只会把自己逼进
     「真元 0 且打不动」的死局。 */
  const strike = () => {
    const boar = gu('white_boar_strength_gu');
    const boarReady = !!boar && /伤 5/.test(boar.text);
    if (counter === 'draw_light') {
      // 逐光必须用光道蛊才算做对
      if (hasGu('small_light_gu') && hasGu('moonlight_gu')) return { kind: 'gu', id: 'small_light_gu', why: '铺光道支援(逐光)' };
      if (hasGu('moonlight_gu')) return { kind: 'gu', id: 'moonlight_gu', why: '光道输出(逐光)' };
      if (hasGu('vitality_grass_gu') && hp < hpMax) return { kind: 'gu', id: 'vitality_grass_gu', why: '光道(逐光)' };
      if (hasGu('moon_glow_gu')) return { kind: 'gu', id: 'moon_glow_gu', why: '月芒(逐光)' };
      return null;
    }
    if (boarReady) return { kind: 'gu', id: 'white_boar_strength_gu', why: '白豕0真元5伤' };
    /* 斩杀窗：支援+月光 3 伤可收头时，优先铺支援 */
    const enemyHp = Number(b?.enemyHp ?? 99);
    if (support === 0 && hasGu('small_light_gu') && hasGu('moonlight_gu') && enemyHp <= 3) {
      return { kind: 'gu', id: 'small_light_gu', why: '斩杀窗铺支援' };
    }
    if (support === 0 && hasGu('small_light_gu') && hasGu('moonlight_gu')) {
      return { kind: 'gu', id: 'small_light_gu', why: '铺光道支援(省真元)' };
    }
    /* 月光 CD0 是持续输出引擎；月芒 CD2 只在需要压制/爆发或月光不可用时用。 */
    if (hasGu('moonlight_gu')) return { kind: 'gu', id: 'moonlight_gu', why: '月光输出' };
    if (qi >= 3 && hasGu('moon_glow_gu')) return { kind: 'gu', id: 'moon_glow_gu', why: '月芒输出' };
    return null;
  };

  const blockId = hasGu('stone_shell_gu') ? 'stone_shell_gu' : hasGu('jade_skin_gu') ? 'jade_skin_gu' : '';
  /* 真伤害 = 文案里伤 ≥1。小光是支援/照见，不能当输出填空。 */
  const realDamageAvailable = () => avail.some((a) => /伤\s*[1-9]/.test(a.text));
  const qiLockedRealDamage = () => s.actions.some((a) => a.disabled && /真元不足/.test(a.text) && /伤\s*[1-9]/.test(a.text));

  /* 逆息：真元卡住真输出时的保险丝。
     只挡一种自杀：逆息后会被下击带走，且本回合斩不了。
     （实测：Boss 剩 3 血时 3→1 强杀未遂被反杀。） */
  const exhaustIfWorthIt = () => {
    if (!s.exhaust) return null;
    if (Number(st?.thoughts ?? 2) < 2) return null;
    if (!qiLockedRealDamage()) return null;
    const enemyHp = Number(b?.enemyHp ?? 99);
    const afterHp = hp - 2;
    const expectedHit = Number(intentDamage || 0);
    const withSupport = support > 0 || hasGu('small_light_gu');
    const canKill = (hasGu('moonlight_gu') && (withSupport ? enemyHp <= 3 : enemyHp <= 2))
      || (hasGu('white_boar_strength_gu') && enemyHp <= 2)
      || (qi + 3 >= 3 && hasGu('moon_glow_gu') && enemyHp <= 4);
    if (canKill) return { kind: 'exhaust', why: '逆息(斩杀窗)' };
    if (afterHp <= 2 && expectedHit >= 3) return null;
    return { kind: 'exhaust', why: '逆息(真元卡住真输出，换一刀)' };
  };

  /* 没有真伤害窗口、但真伤害被真元卡住时，必须先逆息——
     否则小光/收势会耗光念头，保险丝永远按不出来，进入打不死也死不了。 */
  if (!realDamageAvailable() && counter !== 'intercept') {
    const fuse = exhaustIfWorthIt();
    if (fuse) return fuse;
  }

  /* 封脉：L1 要求「改变技能顺序」，不是整回合放弃。
     seal_first → 本回合只垫 1 只非伤害蛊（memory 防连垫）；seal_last → 先伤害。 */
  const sealOrderPlay = () => {
    const throwaway = hasGu('small_light_gu') ? 'small_light_gu'
      : hasGu('vitality_grass_gu') ? 'vitality_grass_gu'
        : hasGu('jade_skin_gu') ? 'jade_skin_gu' : '';
    const damageId = hasGu('white_boar_strength_gu') ? 'white_boar_strength_gu'
      : hasGu('moonlight_gu') ? 'moonlight_gu'
        : (qi >= 3 && hasGu('moon_glow_gu')) ? 'moon_glow_gu' : '';
    const turn = Number(b?.turn || 0);
    if (counter === 'seal_first') {
      if (throwaway && damageId && memory.padTurn !== turn) {
        memory.padTurn = turn;
        return { kind: 'gu', id: throwaway, why: '封首：先垫非核心蛊' };
      }
      if (damageId) return { kind: 'gu', id: damageId, why: '封首：打伤害' };
    }
    if (counter === 'seal_last') {
      if (damageId) return { kind: 'gu', id: damageId, why: '封尾：先出伤害' };
      if (throwaway) return { kind: 'gu', id: throwaway, why: '封尾：垫尾' };
    }
    return null;
  };

  /* 非直接攻击行动：迎击回合也合法。 */
  const supportActions = () => {
    if (counter === 'intercept') {
      // 迎击下优先真正有用的事：照见/支援/护体/回气/逆息，而不是空过
      if (hasGu('small_light_gu') && support === 0) return { kind: 'gu', id: 'small_light_gu', why: '小光支援(迎击下非直攻)' };
      if (blockId && willHit) return { kind: 'gu', id: blockId, why: '护体(迎击下非直攻)' };
      if (hasGu('vitality_grass_gu') && hp < hpMax) return { kind: 'gu', id: 'vitality_grass_gu', why: '回气(迎击下非直攻)' };
      if (s.defend && willHit) return { kind: 'defend', why: '收势(迎击下非直攻)' };
      return exhaustIfWorthIt();
    }
    return null;
  };

  /* 兜底：打不了才护体；收势一回合一次；逆息只当保险丝。 */
  const fallback = () => {
    if (blockId && willHit && (bigHit || lowHp) && qi >= 2) return { kind: 'gu', id: blockId, why: '护体(大伤害/残血)' };
    if (s.defend && willHit && (bigHit || lowHp) && qi < 2 && memory.defendTurn !== Number(b?.turn || 0)) {
      memory.defendTurn = Number(b?.turn || 0);
      return { kind: 'defend', why: '收势(缺真元)' };
    }
    if (hasGu('vitality_grass_gu') && hp < hpMax) return { kind: 'gu', id: 'vitality_grass_gu', why: '回气' };
    const exhaust = exhaustIfWorthIt();
    if (exhaust) return exhaust;
    return { kind: 'end', why: '保资源' };
  };

  // 2) 做对：迎击只吞直接攻击，不禁止其他行动（V4.1-Q2-A）。
  if (counter === 'intercept') {
    const boar = gu('white_boar_strength_gu');
    if (boar && /伤 5/.test(boar.text)) return { kind: 'gu', id: 'white_boar_strength_gu', why: '白豕带伤破反制（拿血换节奏）' };
    if (qi >= 3 && hasGu('moon_glow_gu') && identified) return { kind: 'gu', id: 'moon_glow_gu', why: '月芒压制反制' };
    const supportPick = supportActions();
    if (supportPick) return supportPick;
    return { kind: 'end', why: '迎击下无直攻窗口，保留资源' };
  }

  // 3) 铁皮：优先月芒压制（能打伤害），其次石皮破铁皮（0 伤但拿减伤）。
  if (counter === 'iron') {
    const boar = gu('white_boar_strength_gu');
    if (boar && /伤 5/.test(boar.text)) return { kind: 'gu', id: 'white_boar_strength_gu', why: '白豕带伤破铁皮' };
    if (identified && qi >= 3 && hasGu('moon_glow_gu')) return { kind: 'gu', id: 'moon_glow_gu', why: '月芒压制铁皮并输出' };
    if (hasGu('stone_shell_gu')) return { kind: 'gu', id: 'stone_shell_gu', why: '石皮破铁皮' };
    return fallback();
  }

  // 3b) 封脉：改行动顺序，而不是放弃整个回合。
  if (counter === 'seal_first' || counter === 'seal_last') {
    const sealPick = sealOrderPlay();
    if (sealPick) return sealPick;
    return fallback();
  }

  // 4) 其余（无反制）：正常输出。
  const pick = strike();
  if (pick) return pick;
  return fallback();
}

/* ---------------- 单局走盘 ---------------- */

async function playRoute(env, opts, route, seed) {
  const { S, cdp } = env;
  const url = seed ? `${opts.url}?seed=${seed}` : opts.url;
  cdp.logs = [];
  await S('Page.navigate', { url });
  await sleep(1500);

  const evalJs = async (expr) => {
    const r = await S('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true });
    if (r.exceptionDetails) {
      throw new Error('页面求值异常: ' + (r.exceptionDetails.exception?.description || r.exceptionDetails.text));
    }
    return r.result?.value;
  };

  /* 硬门：拿不到 stats 就直接失败。否则策略会退化成「读不到反制 = 无脑打」，
     最终报出一个看起来能跑、实际什么都没测到的空结果。 */
  const hasStats = await evalJs(`(typeof Mvp !== 'undefined') && typeof Mvp.stats === 'function'`);
  if (!hasStats) throw new Error('页面没有暴露 Mvp.stats()，无法采集逐场指标（不要让走盘静默失去测量能力）');

  const shoot = async (name) => {
    if (!opts.shots) return;
    mkdirSync(opts.shots, { recursive: true });
    const { data } = await S('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
    writeFileSync(path.join(opts.shots, name), Buffer.from(data, 'base64'));
  };
  /* 同 id 多实例时 querySelector 可能命中被禁用的那个，必须挑第一个可用的。 */
  const click = async (sel) => {
    const r = await evalJs(`(() => {
      const els = [...document.querySelectorAll(${JSON.stringify(sel)})];
      const b = els.find((e) => !e.disabled);
      if (!b) return 'NONE';
      b.click();
      return 'ok';
    })()`);
    if (r === 'NONE') throw new Error(`click 目标全被禁用: ${sel}`);
    await sleep(60);
  };

  const battles = [];
  const timeline = [];
  let steps = 0;
  let outcome = 'incomplete';
  let lastKey = '';
  const memory = { padTurn: -1, defendTurn: -1 };

  for (; steps < opts.maxSteps; steps++) {
    const s = JSON.parse(await evalJs(PROBE));
    const b = s.stats?.battle;

    const key = [s.screen, s.heading, b?.enemyHp, b?.turn].join('|');
    if (key !== lastKey) {
      lastKey = key;
      timeline.push({ step: steps, screen: s.screen, heading: s.heading, hp: s.stats?.hp, qi: s.stats?.qi, stones: s.stats?.stones, enemyHp: b?.enemyHp, turn: b?.turn, counter: b?.currentCounter, identified: !!b?.revealed });
      if (s.screen === 'battle') await shoot(`auto-${route}-battle${battles.length + 1}-t${b?.turn}.png`);
    }

    if (s.screen === 'ending') {
      const res = s.stats?.result;
      outcome = res ? (res.won ? 'cleared' : 'lost') : 'unknown';
      timeline.push({ step: steps, screen: 'ending', heading: s.heading, hp: s.stats?.hp, qi: s.stats?.qi, stones: s.stats?.stones });
      await shoot(`auto-${route}-ending.png`);
      break;
    }

    if (s.screen === 'won') {
      // 记这一场的指标（此时 battle 对象还在，计数器完好）
      battles.push({
        stepId: s.stats.stepId,
        enemyId: b.enemyId,
        enemyHpMax: b.enemyHpMax,
        turnCount: b.turn,
        observeCount: b.observeCount,
        damageTaken: b.damageTaken,
        knownCounters: b.knownCounters,
        guUsage: b.guUsage,
        exhaustionCount: b.exhaustionCount || 0,
        counterTurns: b.counterTurns || 0,
        noCounterTurns: b.noCounterTurns || 0,
        zeroDamageTurns: b.zeroDamageTurns || 0,
        hpAfter: s.stats.hp,
        qiAfter: s.stats.qi,
        stonesAfter: s.stats.stones,
        hpMax: s.stats.hpMax,
        qiMax: s.stats.qiMax,
      });
      if (opts.trace) timeline.push({ step: steps, screen: 'battle-clear', detail: JSON.stringify(battles.at(-1)) });
      await click('[data-next-step]');
      continue;
    }

    if (s.screen === 'battle') {
      const pick = chooseActions(s, memory);
      if (opts.trace) {
        timeline.push({ step: steps, screen: 'battle-action', turn: b.turn, counter: b.currentCounter, identified: !!b.revealed, chose: `${pick.kind}:${pick.id || ''}`, why: pick.why });
      }
      if (pick.kind === 'gu') await click(`[data-use-gu="${pick.id}"]`);
      else if (pick.kind === 'observe') await click('[data-observe]');
      else if (pick.kind === 'defend') await click('[data-defend]');
      else if (pick.kind === 'exhaust') await click('[data-exhaust]');
      else await click('[data-end-turn]');
      continue;
    }

    if (s.screen === 'bazaar') {
      const wanted = s.trades.find((t) => t.id === route && !t.disabled);
      const pick = wanted || s.trades.find((t) => !t.disabled);
      if (!pick) throw new Error('大巴扎三个选项全部不可选');
      timeline.push({ step: steps, screen: 'bazaar', chose: pick.id, options: s.trades.map((t) => `${t.id}${t.disabled ? ':blocked' : ':ok'}`).join(',') });
      await click(`[data-trade="${pick.id}"]`);
      continue;
    }

    if (s.screen === 'forge') {
      /* 炼蛊会吃掉月光（CD0 主输出）。若之后只剩月芒（CD2，每 3 回合 1 刀），
         悍客 18 血在 4~6 回合内打不完——这是策略选择保炉，不是改规则。
         有白豕（CD1）垫着时才正炼，保留一条持续输出线。 */
      const owned = s.stats?.owned || {};
      const hasBoar = Number(owned.white_boar_strength_gu || 0) > 0;
      const hasMoonlight = Number(owned.moonlight_gu || 0) > 0;
      const wouldOrphanMoonGlow = hasMoonlight && !hasBoar;
      if (s.forge && !wouldOrphanMoonGlow) {
        timeline.push({ step: steps, screen: 'forge', chose: 'forge' });
        await click('[data-forge]');
        continue;
      }
      timeline.push({ step: steps, screen: 'forge', chose: wouldOrphanMoonGlow ? 'preserve(keep_moonlight)' : 'preserve' });
      await click('[data-preserve]');
      continue;
    }

    throw new Error(`停在未知屏 ${s.screen}`);
  }

  const overflow = JSON.parse(await evalJs(PROBE)).overflow;
  const bossEntry = timeline.find((t) => t.screen === 'battle' && t.heading?.includes('雷冠'));
  /* 步数打满不是「还没跑完」，是这一局已经打不死了：真元归零后没有输出手段，
     收势(-2)+回气(+1) 又能压过被处理过的敌方伤害，于是永远收不了场。
     单独命名，别让它伪装成一个中性的 incomplete。 */
  if (outcome === 'incomplete' && steps >= opts.maxSteps) outcome = 'stalemate';
  return {
    route,
    seed: seed || 'default',
    outcome,
    steps,
    battles,
    bossEntryHp: bossEntry?.hp ?? null,
    bossEntryQi: bossEntry?.qi ?? null,
    hpMax: battles[0]?.hpMax ?? 24,
    qiMax: battles.at(-1)?.qiMax ?? 12,
    finalHp: timeline.at(-1)?.hp ?? null,
    finalQi: timeline.at(-1)?.qi ?? null,
    finalStones: timeline.at(-1)?.stones ?? null,
    totalTurns: battles.reduce((n, x) => n + x.turnCount, 0),
    totalObserves: battles.reduce((n, x) => n + x.observeCount, 0),
    totalDamage: battles.reduce((n, x) => n + x.damageTaken, 0),
    exhaustionCount: battles.reduce((n, x) => n + (x.exhaustionCount || 0), 0),
    counterTurns: battles.reduce((n, x) => n + (x.counterTurns || 0), 0),
    noCounterTurns: battles.reduce((n, x) => n + (x.noCounterTurns || 0), 0),
    zeroDamageTurns: battles.reduce((n, x) => n + (x.zeroDamageTurns || 0), 0),
    overflow,
    consoleErrors: cdp.logs.slice(),
    timeline,
  };
}

/* ---------------- 判定与输出 ---------------- */

function judge(runs, opts) {
  const rows = [];
  const add = (name, ok, detail) => rows.push({ name, ok, detail });
  const multi = runs.length > ROUTES.length;

  for (const r of runs) {
    const after = {};
    for (const b of r.battles) after[b.stepId] = b.hpAfter;
    const tag = multi ? `${r.route}@${r.seed}` : r.route;

    for (const [stepId, minHp] of Object.entries(ACCEPTANCE.postBattleHp)) {
      const hp = after[stepId];
      add(`${tag} · ${stepId} 后 HP≥${minHp}`, hp !== undefined && hp >= minHp, `实际 ${hp ?? '未到达'}`);
    }
    for (const b of r.battles) {
      const t = ACCEPTANCE.turnTarget[b.stepId];
      if (!t) continue;
      add(`${tag} · ${b.stepId} 回合数 ${t[0]}~${t[1]}`, b.turnCount >= t[0] && b.turnCount <= t[1], `实际 ${b.turnCount}`);
    }
    add(`${tag} · 总回合 ${ACCEPTANCE.totalTurns[0]}~${ACCEPTANCE.totalTurns[1]}`, r.totalTurns >= ACCEPTANCE.totalTurns[0] && r.totalTurns <= ACCEPTANCE.totalTurns[1], `实际 ${r.totalTurns}`);
    const fullBoth = r.bossEntryHp === r.hpMax && r.bossEntryQi === r.qiMax;
    add(`${tag} · Boss 开战不满血满真元`, r.bossEntryHp !== null && r.bossEntryQi !== null && !fullBoth, `HP ${r.bossEntryHp}/${r.hpMax} · Qi ${r.bossEntryQi}/${r.qiMax}`);
    add(`${tag} · 完整通关`, r.outcome === 'cleared', r.outcome === 'stalemate' ? '僵局（打不死也死不了）' : r.outcome);
    add(
      `${tag} · 逆息 ≤${ACCEPTANCE.maxExhaustionPerRun}`,
      (r.exhaustionCount || 0) <= ACCEPTANCE.maxExhaustionPerRun,
      `实际 ${r.exhaustionCount || 0}（保险丝，不能当主循环）`,
    );
    add(`${tag} · 无 console 错误`, r.consoleErrors.length === 0, `${r.consoleErrors.length} 条`);
    add(`${tag} · 无横向溢出`, r.overflow.sw === r.overflow.cw, `${r.overflow.sw}/${r.overflow.cw}`);
  }

  const cleared = runs.filter((r) => r.outcome === 'cleared').length;
  add('全部局次通关', cleared === runs.length, `${cleared}/${runs.length}`);
  const stalemates = runs.filter((r) => r.outcome === 'stalemate').length;
  add('stalemate = 0', stalemates === 0, `${stalemates}/${runs.length}`);
  const stressed = runs.some((r) => (r.finalHp !== null && r.finalHp <= 8) || (r.finalQi !== null && r.finalQi <= 3));
  add('Boss 结束至少一路 HP≤8 或 Qi≤3', stressed, runs.map((r) => `${r.route}@${r.seed}:HP${r.finalHp}/Qi${r.finalQi}`).join(' '));
  const sig = new Set(runs.map((r) => `${r.totalTurns}|${r.totalObserves}|${r.totalDamage}|${r.finalStones}|${r.finalQi}`));
  if (!multi) {
    add('三条路线资源轨迹明显不同', sig.size === runs.length, `${sig.size} 种签名 / ${runs.length} 条`);
  }

  /* L1 多局口径：每路线独立 ≥70% 通关，且 0 stalemate。 */
  if (multi) {
    const minRate = opts.minClearRate;
    for (const route of ROUTES) {
      const subset = runs.filter((r) => r.route === route);
      if (!subset.length) continue;
      const wins = subset.filter((r) => r.outcome === 'cleared').length;
      const rate = wins / subset.length;
      add(
        `${route} 通关率 ≥${(minRate * 100).toFixed(0)}%`,
        rate + 1e-9 >= minRate,
        `${wins}/${subset.length} = ${(rate * 100).toFixed(0)}%`,
      );
    }
  }
  return rows;
}

function report(runs, rows, opts) {
  console.log('\n================ 逐场指标 ================');
  for (const r of runs) {
    console.log(`\n[${r.route}] seed=${r.seed} → ${r.outcome}  (步数 ${r.steps} 总回合 ${r.totalTurns} 观察 ${r.totalObserves} 受伤 ${r.totalDamage})`);
    console.log('  阶段      回合  观察  受伤  战后HP  Qi   元石  已识破反制');
    for (const b of r.battles) {
      console.log(
        `  ${b.stepId.padEnd(9)} ${String(b.turnCount).padStart(3)}  ${String(b.observeCount).padStart(4)}  ${String(b.damageTaken).padStart(4)}  `
        + `${String(b.hpAfter).padStart(5)}  ${String(b.qiAfter).padStart(4)}  ${String(b.stonesAfter).padStart(4)}  ${(b.knownCounters || []).join('/') || '-'}`,
      );
    }
    console.log(`  终局 HP ${r.finalHp} · Qi ${r.finalQi} · 元石 ${r.finalStones} · Boss 开战 HP ${r.bossEntryHp}/${r.hpMax} Qi ${r.bossEntryQi}/${r.qiMax}`);
    console.log(`  节奏 逆息 ${r.exhaustionCount || 0} · 反制回合 ${r.counterTurns || 0} / 无反制 ${r.noCounterTurns || 0} · 零输出回合 ${r.zeroDamageTurns || 0}`);
    if (r.consoleErrors.length) console.log(`  console 错误: ${r.consoleErrors.join(' | ')}`);
  }

  console.log('\n================ L1 V4 验收 ================');
  let pass = 0;
  for (const row of rows) {
    console.log(`  ${row.ok ? 'PASS' : 'FAIL'}  ${row.name}  (${row.detail})`);
    if (row.ok) pass += 1;
  }
  console.log(`\n  ${pass}/${rows.length} 项达标`);

  if (opts.trace) {
    console.log('\n================ 轨迹 ================');
    for (const r of runs) {
      console.log(`\n[${r.route}]`);
      for (const t of r.timeline) console.log('  ' + JSON.stringify(t));
    }
  }
  if (opts.json) console.log('\n===JSON===\n' + JSON.stringify({ runs, rows }, null, 2));
}

/* ---------------- 主流程 ---------------- */

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const edgePath = findEdge(opts.edge);
  const env = await attach(edgePath, 9345, opts.headed, [1280, 720]);
  const runs = [];
  try {
    for (const seed of opts.seeds) {
      for (const route of opts.routes) {
        runs.push(await playRoute(env, opts, route, seed));
      }
    }
  } finally {
    try { await env.cdp.send('Browser.close'); } catch { /* ignore */ }
    env.ws.close();
    await sleep(300);
    env.proc.kill();
  }
  const rows = judge(runs, opts);
  report(runs, rows, opts);
  process.exit(rows.every((r) => r.ok) ? 0 : 3);
}

main().catch((e) => { console.error('autoplay 失败:', e.message); process.exit(1); });
