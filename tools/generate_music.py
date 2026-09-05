#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""确定性合成《蛊路求生》循环 BGM（无第三方版权，全部自合成）。

输出：24kHz / 16-bit / mono / 30 秒无缝循环 WAV，写入 assets/audio/music/。
可复现：固定种子，重跑本脚本产生逐字节一致的输出。

曲目与用途（与 run_controller 视图 → BGM 映射一致）：
  hall   大厅 / 标题    空灵苍凉，D 羽调式慢速琶音 + 长低音 drone
  map    地图与各类探索屏 静谧悬疑，drone + 稀疏五声短句 + 低噪铺底
  battle 战斗          紧张，鼓点脉冲 + 五声快速动机
  ending 结局          低沉悲凉，慢速和弦长音

循环策略：
  - pad/drone 为恒定包络持续层；事件层（琶音/旋律/鼓）保证在循环内衰减完毕；
  - 输出前对整条 30s 波形做 50ms 边界交叉淡化，消除相位不连续产生的咔哒。
"""

import math
import os
import random
import wave

import numpy as np

SR = 24000          # 采样率（Hz）
DUR = 30.0          # 循环时长（秒）
N = int(SR * DUR)   # 样本总数
FADE = int(SR * 0.05)  # 边界淡化样本数

# D 羽调式音级频率（D2..D6），用于暗色东方氛围
_NOTES = {
    "D2": 73.42, "F2": 87.31, "G2": 98.00, "A2": 110.00, "C3": 130.81,
    "D3": 146.83, "F3": 174.61, "G3": 196.00, "A3": 220.00, "C4": 261.63,
    "D4": 293.66, "F4": 349.23, "G4": 392.00, "A4": 440.00, "C5": 523.25,
    "D5": 587.33, "F5": 698.46, "G5": 783.99, "A5": 880.00, "C6": 1046.50,
}

SEED = 20260906


def _time(start: float, dur: float) -> np.ndarray:
    """返回 [start, start+dur) 区间的采样时间轴。"""
    i0 = max(0, int(start * SR))
    i1 = min(N, int((start + dur) * SR))
    return np.arange(i0, i1) / SR


def _place(buf: np.ndarray, seg: np.ndarray, start: float) -> None:
    """把 seg（已带包络）写入 buf 的对应区间并混叠。"""
    i0 = max(0, int(start * SR))
    i1 = min(N, i0 + len(seg))
    buf[i0:i1] += seg[: i1 - i0]


def _env_adsr(n: int, attack: float, sustain: float, release: float, sr: int = SR) -> np.ndarray:
    """简版包络：线性 attack → 恒定 sustain → 指数 release（release 末尾归零）。"""
    env = np.ones(n)
    a = max(1, int(attack * sr))
    if a < n:
        env[:a] = np.linspace(0.0, 1.0, a)
    r = max(1, int(release * sr))
    if r < n:
        tail = np.exp(-4.0 * np.linspace(0.0, 1.0, r))
        env[n - r:] = np.minimum(env[n - r:], tail)
    env *= sustain
    return env


def _tone(freq: float, dur: float, amp: float, attack: float = 0.005,
          release: float = 0.6, sustain: float = 1.0, harm: float = 0.0) -> np.ndarray:
    """单一正弦（可带 2/3 次谐波）带包络，返回时长 dur 的片段。"""
    t = np.arange(int(dur * SR)) / SR
    w = np.sin(2 * np.pi * freq * t)
    if harm > 0.0:
        w += harm * 0.5 * np.sin(2 * np.pi * 2.0 * freq * t)
        w += harm * 0.25 * np.sin(2 * np.pi * 3.0 * freq * t)
    return amp * w * _env_adsr(len(w), attack, sustain, release)


def _drone(freq: float, amp: float, lfo_hz: float = 0.08, lfo_depth: float = 0.25) -> np.ndarray:
    """恒定幅度长低音（带慢速 LFO 呼吸 + 轻微失谐合唱感），用于无缝循环铺底。
    早期版本为纯正弦，持续听感机械如电流"嗡"声；现叠加 ±0.5Hz 失谐分量
    形成自然拍频，泛音 0.4/0.15 保持温暖度。音量由调用方控制在氛围级。"""
    t = np.arange(N) / SR
    lfo = 1.0 - lfo_depth * (0.5 + 0.5 * np.sin(2 * np.pi * lfo_hz * t))
    det = 0.5
    sig = np.sin(2 * np.pi * freq * t) + 0.6 * np.sin(2 * np.pi * (freq + det) * t) \
        + 0.4 * np.sin(2 * np.pi * 2.0 * freq * t) \
        + 0.15 * np.sin(2 * np.pi * 3.0 * freq * t)
    # 首尾各留 1.5s 淡入淡出，保证循环边界无突变（持续层音量低，几乎无感）
    ramp = np.ones(N)
    r = int(1.5 * SR)
    ramp[:r] = np.linspace(0.0, 1.0, r)
    ramp[-r:] = np.linspace(1.0, 0.0, r)
    return amp * lfo * sig * ramp


def _bell(freq: float, amp: float, dur: float = 4.0, attack: float = 0.002) -> np.ndarray:
    """钟磬感：基频 + 和谐泛音（2/3 次），长指数衰减。
    早期版本用 2.76x/5.40x 非谐泛音，在 2.2-4.8kHz 产生尖锐"电蚊"声（人耳
    等响度最敏感区），已改为和谐泛音并整体压低音区（G4/A4/D4 起，泛音 <1.4kHz）。"""
    t = np.arange(int(dur * SR)) / SR
    env = np.exp(-1.6 * t)
    env[: max(1, int(attack * SR))] *= np.linspace(0.0, 1.0, max(1, int(attack * SR)))
    sig = np.sin(2 * np.pi * freq * t) \
        + 0.30 * np.sin(2 * np.pi * 2.0 * freq * t) \
        + 0.12 * np.sin(2 * np.pi * 3.0 * freq * t)
    return amp * env * sig


def _breath_noise(amp: float, cutoff: float = 0.02, seed: int = SEED) -> np.ndarray:
    """低通噪声铺底（风声/环境感），恒定包络 + 边界淡化。"""
    rng = np.random.default_rng(seed)
    raw = rng.normal(0.0, 1.0, N)
    # 向量化低通（因果近似）：用指数核卷积做简单平滑
    k = max(2, int(cutoff * SR))
    kernel = np.exp(-np.linspace(0.0, 6.0, k))
    kernel /= kernel.sum()
    y = np.convolve(raw, kernel, mode="same")
    y /= (np.abs(y).max() + 1e-9)
    y *= amp
    y *= 0.6 + 0.4 * np.sin(2 * np.pi * 0.05 * np.arange(N) / SR + 1.0)
    r = int(2.0 * SR)
    y[:r] *= np.linspace(0.0, 1.0, r)
    y[-r:] *= np.linspace(1.0, 0.0, r)
    return y


def _crossfade_loop(buf: np.ndarray, fade: int = FADE) -> np.ndarray:
    """首尾 50ms 交叉淡化：尾段线性淡出、头段线性淡入，消除边界相位跳变。"""
    out = buf.copy()
    f = min(fade, len(out) // 2)
    if f <= 0:
        return out
    out[:f] *= np.linspace(0.0, 1.0, f)
    out[-f:] *= np.linspace(1.0, 0.0, f)
    return out


def _lowpass(x: np.ndarray, cutoff: float = 6000.0, slope: float = 900.0) -> np.ndarray:
    """FFT 平滑滚降低通：cutoff 以上余弦过渡到 slope 处全零，无 ringing。
    音乐内容最高音 C6=1046.5Hz，其 3 次谐波 3139Hz 远低于 cutoff，音色无损；
    主要用于兜底削减合成中残留的高频（如鼓点白噪瞬态）避免尖锐听感。"""
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X = np.fft.rfft(x)
    edge = cutoff + slope
    g = np.ones_like(f)
    m = (f > cutoff) & (f < edge)
    g[m] = 0.5 + 0.5 * np.cos(np.pi * (f[m] - cutoff) / slope)
    g[f >= edge] = 0.0
    return np.fft.irfft(X * g, n=len(x))


def build_hall() -> np.ndarray:
    """大厅：空灵苍凉——慢速琶音为主角，drone 退为极轻的氛围层。"""
    rng = random.Random(SEED + 1)
    buf = np.zeros(N)
    buf += _drone(_NOTES["D2"], 0.05, lfo_hz=0.07, lfo_depth=0.3)
    buf += _drone(_NOTES["A2"], 0.02, lfo_hz=0.05, lfo_depth=0.3)
    # 琶音动机：D-F-G-A-C（D 羽），每 2s 一个音，跨 8 度
    arp = ["D3", "F3", "G3", "A3", "C4", "A3", "G3", "F3",
           "D4", "F4", "G4", "A4", "C5", "A4", "G4", "F4"]
    t = 0.0
    idx = 0
    while t < DUR - 6.0:
        name = arp[idx % len(arp)]
        seg = _tone(_NOTES[name], 4.0, 0.075, attack=0.05, release=3.8, sustain=1.0, harm=0.15)
        _place(buf, seg, t)
        idx += 1
        t += 2.0
    # 钟磬：每个 8 拍点缀一次（低音区和谐泛音，避免高频电蚊感）
    t = 1.0
    while t < DUR - 5.0:
        name = rng.choice(["G4", "A4", "D4"])
        _place(buf, _bell(_NOTES[name], 0.028, dur=5.0), t)
        t += 6.0
    return _crossfade_loop(buf)


def build_map() -> np.ndarray:
    """地图：静谧悬疑——D2 drone + 噪声铺底 + 稀疏五声短句 + 缓慢长音。"""
    rng = random.Random(SEED + 2)
    buf = np.zeros(N)
    buf += _drone(_NOTES["D2"], 0.05, lfo_hz=0.06, lfo_depth=0.35)
    buf += _drone(_NOTES["C3"], 0.02, lfo_hz=0.04, lfo_depth=0.4)
    buf += _breath_noise(0.025, cutoff=0.012, seed=SEED + 7)
    # 稀疏旋律短句（0.5-1.5s，间隔 3.5-7s），音量低
    motif = ["G4", "A4", "C5", "A4", "G4", "F4", "D4"]
    t = 2.0
    while t < DUR - 3.0:
        n = rng.randint(3, 6)
        for k in range(n):
            name = motif[(rng.randrange(len(motif)))]
            seg = _tone(_NOTES[name], 1.2, 0.03, attack=0.03, release=1.0, sustain=0.8, harm=0.1)
            _place(buf, seg, t + k * 0.28)
        t += rng.uniform(3.5, 7.0)
    # 缓慢交替长音（G4/C4），持续层
    t = 0.0
    names = ["G4", "C4"]
    k = 0
    while t < DUR - 4.0:
        seg = _tone(_NOTES[names[k % 2]], 4.5, 0.022, attack=1.0, release=1.0, sustain=1.0, harm=0.05)
        _place(buf, seg, t)
        k += 1
        t += 4.5
    return _crossfade_loop(buf)


def build_battle() -> np.ndarray:
    """战斗：紧张——鼓点脉冲（120BPM）+ 低音脉冲 + 五声快速动机。"""
    rng = random.Random(SEED + 3)
    buf = np.zeros(N)
    beat = 0.5  # 120 BPM
    # 鼓：低频冲击 + 噪声瞬态
    t = 0.0
    acc = 0.0
    while t < DUR:
        seg = _tone(70.0, 0.3, 0.30, attack=0.001, release=0.28, sustain=1.0, harm=0.5)
        _place(buf, seg, t)
        # 噪声瞬态（军鼓感）：幅度压低 + 后续全局低通削减白噪高频
        rng2 = np.random.default_rng(SEED + int(t * 10))
        nz = rng2.normal(0.0, 1.0, int(0.06 * SR))
        nz *= np.exp(-np.linspace(0.0, 8.0, len(nz)))
        _place(buf, nz * 0.05, t)
        t += beat
        acc += 1
    # 低音脉冲：每拍 D2/A2 交替（节奏性低音，微降避免压过动机）
    t = 0.0
    names = ["D2", "A2"]
    k = 0
    while t < DUR:
        seg = _tone(_NOTES[names[k % 2]], 0.45, 0.10, attack=0.002, release=0.4, sustain=1.0, harm=0.3)
        _place(buf, seg, t)
        k += 1
        t += beat
    # 五声快速动机：每 4 拍一组十六分跑动，组间留白
    run = ["G4", "A4", "C5", "D5", "C5", "A4", "G4", "A4"]
    t = 0.0
    while t < DUR - 2.0:
        off = 0.0
        for name in run:
            seg = _tone(_NOTES[name], 0.22, 0.05, attack=0.002, release=0.18, sustain=1.0, harm=0.12)
            _place(buf, seg, t + off)
            off += 0.25
        t += 2.0
    return _crossfade_loop(buf)


def build_ending() -> np.ndarray:
    """结局：低沉悲凉——D2 长音（极轻）+ 极慢和弦（Dm/C）+ 低琶音。"""
    buf = np.zeros(N)
    buf += _drone(_NOTES["D2"], 0.06, lfo_hz=0.05, lfo_depth=0.3)
    buf += _drone(_NOTES["F2"], 0.02, lfo_hz=0.04, lfo_depth=0.35)
    # 极慢和弦琶音：Dm (D-F-A) / C (C-E-G) 交替，每 5s 一音
    chords = [["D3", "F3", "A3"], ["C3", "G3", "C4"], ["F3", "A3", "D4"], ["A2", "C4", "F4"]]
    t = 0.0
    idx = 0
    while t < DUR - 6.0:
        ch = chords[idx % len(chords)]
        for name in ch:
            seg = _tone(_NOTES[name], 6.0, 0.030, attack=1.2, release=4.0, sustain=1.0, harm=0.1)
            _place(buf, seg, t)
        idx += 1
        t += 5.0
    return _crossfade_loop(buf)


TRACKS = {
    "hall": build_hall,
    "map": build_map,
    "battle": build_battle,
    "ending": build_ending,
}


def write_wav(path: str, samples: np.ndarray) -> None:
    data = np.clip(samples, -1.0, 1.0)
    pcm = (data * 32767.0).astype("<i2")
    with wave.open(path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(pcm.tobytes())


def main() -> None:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(root, "assets", "audio", "music")
    os.makedirs(out_dir, exist_ok=True)
    for name, builder in TRACKS.items():
        samples = _lowpass(builder())
        path = os.path.join(out_dir, name + ".wav")
        write_wav(path, samples)
        peak = float(np.abs(samples).max())
        print(f"{name}.wav  n={len(samples)}  peak={peak:.3f}")


if __name__ == "__main__":
    main()
