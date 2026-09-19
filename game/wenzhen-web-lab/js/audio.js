// WebAudio 程序合成：零音频资产起步。每个交互都必须有听觉反馈（既有约定）。
// 普通脚本：全局 Sfx，供 main.js 调用。?silent=1 关闭（无头验证用）。
let ctx = null;
const on = !new URLSearchParams(location.search).has('silent');

function ac() {
  if (!on) return null;
  if (!ctx) ctx = new (window.AudioContext || window.webkitAudioContext)();
  if (ctx.state === 'suspended') ctx.resume();
  return ctx;
}

function tone({ freq = 440, dur = 0.16, type = 'sine', gain = 0.09, slide = 0 }) {
  const a = ac(); if (!a) return;
  const o = a.createOscillator(), g = a.createGain();
  o.type = type; o.frequency.setValueAtTime(freq, a.currentTime);
  if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(40, freq + slide), a.currentTime + dur);
  g.gain.setValueAtTime(gain, a.currentTime);
  g.gain.exponentialRampToValueAtTime(0.0001, a.currentTime + dur);
  o.connect(g).connect(a.destination);
  o.start(); o.stop(a.currentTime + dur);
}

function noise({ dur = 0.3, gain = 0.07, hp = 400 }) {
  const a = ac(); if (!a) return;
  const n = Math.floor(a.sampleRate * dur);
  const buf = a.createBuffer(1, n, a.sampleRate);
  const d = buf.getChannelData(0);
  for (let i = 0; i < n; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / n);
  const src = a.createBufferSource(); src.buffer = buf;
  const f = a.createBiquadFilter(); f.type = 'highpass'; f.frequency.value = hp;
  const g = a.createGain(); g.gain.value = gain;
  src.connect(f).connect(g).connect(a.destination);
  src.start();
}

const Sfx = {
  click: () => tone({ freq: 320, dur: 0.07, type: 'triangle', gain: 0.05 }),
  forge: () => { noise({ dur: 0.7, gain: 0.06, hp: 120 }); tone({ freq: 96, dur: 0.7, type: 'sawtooth', gain: 0.05, slide: -30 }); },
  success: () => { tone({ freq: 784, dur: 0.5, type: 'sine', gain: 0.08 }); setTimeout(() => tone({ freq: 1175, dur: 0.6, type: 'sine', gain: 0.06 }), 110); },
  fail: () => { tone({ freq: 150, dur: 0.42, type: 'square', gain: 0.06, slide: -60 }); noise({ dur: 0.22, gain: 0.05, hp: 260 }); },
  hit: () => { noise({ dur: 0.16, gain: 0.1, hp: 900 }); tone({ freq: 180, dur: 0.14, type: 'square', gain: 0.05, slide: -70 }); },
  hurt: () => tone({ freq: 110, dur: 0.3, type: 'sawtooth', gain: 0.07, slide: -40 }),
  win: () => [0, 150, 300].forEach((d, i) => setTimeout(() => tone({ freq: [523, 659, 880][i], dur: 0.55, type: 'sine', gain: 0.07 }), d)),
  lose: () => [0, 200].forEach((d, i) => setTimeout(() => tone({ freq: [220, 138][i], dur: 0.8, type: 'sine', gain: 0.07 }), d)),
};
