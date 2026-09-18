/* 环境音与音乐。第一幕所有声音都是现场合成的，没有音频文件。
   等真的需要音乐时再引入 <audio>，不要提前建音频管理系统。 */

let ctx = null;
let master = null;
let noiseBuf = null;
const rooms = new Map();

function makeNoise(seconds = 4) {
  const len = Math.floor(ctx.sampleRate * seconds);
  const buf = ctx.createBuffer(1, len, ctx.sampleRate);
  const d = buf.getChannelData(0);
  for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
  return buf;
}

export function initAudio() {
  if (ctx) return ctx;
  const AC = window.AudioContext || window.webkitAudioContext;
  if (!AC) return null;
  ctx = new AC();
  master = ctx.createGain();
  master.gain.value = 0;
  master.connect(ctx.destination);
  noiseBuf = makeNoise(4);
  return ctx;
}

export function resumeAudio() {
  if (ctx && ctx.state === 'suspended') ctx.resume();
}

export function fadeMaster(to, ms = 1500) {
  if (!ctx) return;
  const t = ctx.currentTime;
  master.gain.cancelScheduledValues(t);
  master.gain.setValueAtTime(master.gain.value, t);
  master.gain.linearRampToValueAtTime(to, t + ms / 1000);
}

/* 一个「空间」= 一组会持续发声的源 + 一个可淡入淡出的总增益 */
function room(name, build) {
  if (!ctx) return null;
  if (rooms.has(name)) return rooms.get(name);
  const g = ctx.createGain();
  g.gain.value = 0;
  g.connect(master);
  build(g);
  rooms.set(name, g);
  return g;
}

export function fadeRoom(name, to, ms = 2000) {
  const g = rooms.get(name);
  if (!g) return;
  const t = ctx.currentTime;
  g.gain.cancelScheduledValues(t);
  g.gain.setValueAtTime(g.gain.value, t);
  g.gain.linearRampToValueAtTime(to, t + ms / 1000);
}

/* 空窍：极低频的嗡鸣 + 一点高频微光 */
export function soundVault() {
  room('vault', (g) => {
    const sub = ctx.createOscillator();
    sub.type = 'sine';
    sub.frequency.value = 46;

    const fifth = ctx.createOscillator();
    fifth.type = 'sine';
    fifth.frequency.value = 69.5;

    const shimmer = ctx.createOscillator();
    shimmer.type = 'sine';
    shimmer.frequency.value = 1188;
    const shimmerGain = ctx.createGain();
    shimmerGain.gain.value = 0.012;

    const mix = ctx.createGain();
    mix.gain.value = 0.42;

    // 极慢的呼吸，让它不像电子音，像有没有东西在
    const lfo = ctx.createOscillator();
    lfo.frequency.value = 0.055;
    const lfoGain = ctx.createGain();
    lfoGain.gain.value = 0.2;

    sub.connect(mix);
    fifth.connect(mix);
    shimmer.connect(shimmerGain);
    shimmerGain.connect(mix);
    lfo.connect(lfoGain);
    lfoGain.connect(mix.gain);
    mix.connect(g);

    sub.start(); fifth.start(); shimmer.start(); lfo.start();
  });
}

/* 青茅山的雨：宽带噪声做雨幕，另一路低频噪声做山谷的底噪 */
export function soundRain() {
  room('rain', (g) => {
    const sheet = ctx.createBufferSource();
    sheet.buffer = noiseBuf;
    sheet.loop = true;

    const hp = ctx.createBiquadFilter();
    hp.type = 'highpass';
    hp.frequency.value = 340;
    const lp = ctx.createBiquadFilter();
    lp.type = 'lowpass';
    lp.frequency.value = 4300;

    const sheetGain = ctx.createGain();
    sheetGain.gain.value = 0.26;

    sheet.connect(hp); hp.connect(lp); lp.connect(sheetGain); sheetGain.connect(g);

    const rumble = ctx.createBufferSource();
    rumble.buffer = noiseBuf;
    rumble.loop = true;
    const lp2 = ctx.createBiquadFilter();
    lp2.type = 'lowpass';
    lp2.frequency.value = 190;
    const rumbleGain = ctx.createGain();
    rumbleGain.gain.value = 0.5;
    rumble.connect(lp2); lp2.connect(rumbleGain); rumbleGain.connect(g);

    // 雨势自然的起伏
    const lfo = ctx.createOscillator();
    lfo.frequency.value = 0.07;
    const lfoGain = ctx.createGain();
    lfoGain.gain.value = 0.055;
    lfo.connect(lfoGain); lfoGain.connect(sheetGain.gain);

    sheet.start(); rumble.start(); lfo.start();
  });
}

/* 一次心跳。两声，第二声轻一些——是心音，不是鼓点。 */
export function heartbeat() {
  if (!ctx) return;
  const t = ctx.currentTime + 0.05;
  const thump = (at, level) => {
    const o = ctx.createOscillator();
    o.type = 'sine';
    o.frequency.setValueAtTime(76, at);
    o.frequency.exponentialRampToValueAtTime(37, at + 0.17);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, at);
    g.gain.linearRampToValueAtTime(level, at + 0.014);
    g.gain.exponentialRampToValueAtTime(0.0001, at + 0.36);
    o.connect(g); g.connect(master);
    o.start(at); o.stop(at + 0.42);
  };
  thump(t, 0.5);
  thump(t + 0.28, 0.3);
}

/* 一声很轻的钟。用在蝉显形的瞬间。 */
export function chime(freq = 1244, level = 0.055, dur = 4) {
  if (!ctx) return;
  const t = ctx.currentTime + 0.02;
  const o = ctx.createOscillator();
  o.type = 'sine';
  o.frequency.value = freq;
  const g = ctx.createGain();
  g.gain.setValueAtTime(0.0001, t);
  g.gain.linearRampToValueAtTime(level, t + 0.05);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  o.connect(g); g.connect(master);
  o.start(t); o.stop(t + dur + 0.1);
}

/* 屋檐滴水。 */
export function waterDrop() {
  if (!ctx) return;
  const t = ctx.currentTime + 0.02;
  const src = ctx.createBufferSource();
  src.buffer = noiseBuf;
  src.playbackRate.value = 1.6;
  const bp = ctx.createBiquadFilter();
  bp.type = 'bandpass';
  bp.frequency.setValueAtTime(2400, t);
  bp.frequency.exponentialRampToValueAtTime(700, t + 0.09);
  bp.Q.value = 6;
  const g = ctx.createGain();
  g.gain.setValueAtTime(0.0001, t);
  g.gain.linearRampToValueAtTime(0.16, t + 0.004);
  g.gain.exponentialRampToValueAtTime(0.0001, t + 0.13);
  src.connect(bp); bp.connect(g); g.connect(master);
  src.start(t); src.stop(t + 0.2);
}

/* 每隔一会儿来一次滴水，让静止的画面不是死的。
   只许有一条循环——第二幕和第四幕都会要它，起两条水滴会翻倍。 */
let dropsStarted = false;

export function startAmbientDrops() {
  if (dropsStarted) return;
  dropsStarted = true;
  const tick = () => {
    if (!ctx) return;
    waterDrop();
    setTimeout(tick, 2600 + Math.random() * 5200);
  };
  setTimeout(tick, 1800);
}

/* 听不清的低语。不是词，是两个人隔着雨说话的节奏和口气。
   用带通噪声做气音，一段 2~4 个音节的模糊句子。
   pan：-1 全在左，1 全在右。用来把人放在画面之外——玩家只能转头去找。 */
export function murmur(syllables = 3, at = 0, pan = 0, level = 0.07) {
  if (!ctx) return;
  const bus = ctx.createGain();
  bus.gain.value = level;

  const lp = ctx.createBiquadFilter();
  lp.type = 'lowpass';
  lp.frequency.value = 820;              // 隔着雨，高频先没了
  lp.connect(bus);

  if (ctx.createStereoPanner) {
    const p = ctx.createStereoPanner();
    p.pan.value = Math.max(-1, Math.min(1, pan));
    bus.connect(p);
    p.connect(master);
  } else {
    bus.connect(master);
  }

  let t = ctx.currentTime + 0.04 + at;
  for (let i = 0; i < syllables; i++) {
    const dur = 0.15 + Math.random() * 0.13;
    const src = ctx.createBufferSource();
    src.buffer = noiseBuf;
    src.loop = true;

    const bp = ctx.createBiquadFilter();
    bp.type = 'bandpass';
    bp.frequency.setValueAtTime(430 + Math.random() * 240, t);
    bp.frequency.exponentialRampToValueAtTime(300 + Math.random() * 190, t + dur);
    bp.Q.value = 1.7;

    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.linearRampToValueAtTime(0.9, t + 0.035);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);

    src.connect(bp); bp.connect(g); g.connect(lp);
    src.start(t); src.stop(t + dur + 0.06);
    t += dur + 0.05 + Math.random() * 0.1;
  }
}

/* 屋里。同一场雨，隔着墙——低通压掉高频，只剩闷闷的一片。
   这一层存在的意义是：让玩家听出「在屋里」而不是「在雨里」。 */
export function soundRoom() {
  room('room', (g) => {
    const muffled = ctx.createBufferSource();
    muffled.buffer = noiseBuf;
    muffled.loop = true;
    const lp = ctx.createBiquadFilter();
    lp.type = 'lowpass';
    lp.frequency.value = 400;
    const mg = ctx.createGain();
    mg.gain.value = 0.16;
    muffled.connect(lp); lp.connect(mg); mg.connect(g);

    // 极轻的木头/空腔共鸣，很窄的一条
    const body = ctx.createBufferSource();
    body.buffer = noiseBuf;
    body.loop = true;
    const bp = ctx.createBiquadFilter();
    bp.type = 'bandpass';
    bp.frequency.value = 178;
    bp.Q.value = 4.5;
    const bg = ctx.createGain();
    bg.gain.value = 0.05;
    body.connect(bp); bp.connect(bg); bg.connect(g);

    muffled.start(); body.start();
  });
}

/* 蝉吞下元石。两声：一声闷响往下掉，一点亮音往上化开。
   step 是第几颗——音高逐颗变化，否则三次听起来像一次。 */
export function swallow(step = 0) {
  if (!ctx) return;
  const t = ctx.currentTime + 0.02;

  const o = ctx.createOscillator();
  o.type = 'sine';
  o.frequency.setValueAtTime(196 - step * 13, t);
  o.frequency.exponentialRampToValueAtTime(62 - step * 6, t + 0.3);
  const g = ctx.createGain();
  g.gain.setValueAtTime(0.0001, t);
  g.gain.linearRampToValueAtTime(0.30, t + 0.022);
  g.gain.exponentialRampToValueAtTime(0.0001, t + 0.46);
  o.connect(g); g.connect(master);
  o.start(t); o.stop(t + 0.5);

  const s = ctx.createOscillator();
  s.type = 'sine';
  s.frequency.setValueAtTime(742 + step * 96, t + 0.05);
  s.frequency.exponentialRampToValueAtTime(1360 + step * 150, t + 0.52);
  const sg = ctx.createGain();
  sg.gain.setValueAtTime(0.0001, t);
  sg.gain.linearRampToValueAtTime(0.042, t + 0.08);
  sg.gain.exponentialRampToValueAtTime(0.0001, t + 1.5);
  s.connect(sg); sg.connect(master);
  s.start(t + 0.05); s.stop(t + 1.6);
}

/* 拿起一颗石头。一声几乎听不见的轻响——有反馈，但不打断安静。 */
export function stoneTick() {
  if (!ctx) return;
  const t = ctx.currentTime + 0.01;
  const o = ctx.createOscillator();
  o.type = 'triangle';
  o.frequency.setValueAtTime(1720, t);
  o.frequency.exponentialRampToValueAtTime(980, t + 0.09);
  const g = ctx.createGain();
  g.gain.setValueAtTime(0.0001, t);
  g.gain.linearRampToValueAtTime(0.022, t + 0.006);
  g.gain.exponentialRampToValueAtTime(0.0001, t + 0.12);
  o.connect(g); g.connect(master);
  o.start(t); o.stop(t + 0.15);
}
