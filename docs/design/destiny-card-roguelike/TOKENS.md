# 设计 Token 规格

> 映射到 Figma Variables：`Primitives`（单模式）→ `Semantic`（Dark 主模式；预留 Light）。  
> 颜色一律 0–1 写入 Figma Plugin API；下表给 HEX。

## 1. Primitives（单模式 Value）

### 色 · 暗夜阶（Neutral Night）

| Token | HEX | 用途 |
| --- | --- | --- |
| `night/0` | `#05070C` | 最深底 |
| `night/1` | `#0A0F18` | 页面底 |
| `night/2` | `#121A28` | 卡片面 |
| `night/3` | `#1A2436` | 浮起面 / 悬停 |
| `night/4` | `#243248` | 描边高亮 |
| `night/5` | `#3A4C68` | 强分隔 |

### 色 · 微光（Lumen）

| Token | HEX | 用途 |
| --- | --- | --- |
| `lumen/100` | `#F6F1E6` | 主文字（暖白） |
| `lumen/80` | `#D9D2C4` | 次文字 |
| `lumen/60` | `#A89F90` | 弱文字 |
| `lumen/40` | `#6E675C` | 禁用/极弱 |
| `lumen/gold` | `#D4B46A` | 命运金 · 主强调 |
| `lumen/gold-deep` | `#A8843C` | 金描边 |
| `lumen/glow` | `#F0E2B0` | 发光芯 |

### 色 · 道痕 / 流派

| Token | HEX | 流派/语义 |
| --- | --- | --- |
| `mark/force` | `#C47B5A` | 力道 · 赭 |
| `mark/soul` | `#7B8FD4` | 魂道 · 靛 |
| `mark/blood` | `#B54A4A` | 血道 · 绛 |
| `mark/wisdom` | `#6BA3A0` | 智道 · 青 |
| `mark/wood` | `#7A9E6A` | 木道 · 苍 |
| `mark/time` | `#9B7EC8` | 时道 · 紫 |

### 色 · 状态

| Token | HEX |
| --- | --- |
| `state/danger` | `#D45B5B` |
| `state/success` | `#6FAF8A` |
| `state/warn` | `#D4B46A` |
| `state/info` | `#6B8FBF` |

### 间距

`space/1=4` · `space/2=8` · `space/3=12` · `space/4=16` · `space/5=24` · `space/6=32` · `space/7=48` · `space/8=64`

### 圆角

`radius/0=0` · `radius/1=2` · `radius/2=4` · `radius/3=8` · `radius/4=12` · `radius/full=999`

### 线宽 / 描边

`stroke/hair=1`（命运丝线）· `stroke/em=2`（焦点）· `stroke/card=1`

### 字体

| 族 | 用途 | 备注 |
| --- | --- | --- |
| `font/display` | 大标题、结算 | Noto Serif SC / 思源宋体 |
| `font/ui` | 界面、按钮 | Noto Sans SC / 思源黑体 |
| `font/mono` | 数值、种子 | Roboto Mono / 等宽 |

### 字号（桌面 · 4K 基准 3840×2160）

| Token | px | 用途 |
| --- | --- | --- |
| `type/d1` | 72 | 主界面题 |
| `type/d2` | 48 | 屏题 |
| `type/h` | 32 | 区块题 |
| `type/b` | 24 | 正文 |
| `type/s` | 20 | 次要 |
| `type/cap` | 18 | 标签/角标 |
| `type/num-lg` | 56 | 资源大数 |
| `type/num-md` | 32 | 卡牌数值 |

> 1080p 回退：上述值 ×0.55–0.65 可得 1440 档；组件 min-height 按钮 ≥52（4K）/ ≥40（1080）。

### 效果（Effect Styles）

| 名称 | 配方 |
| --- | --- |
| `effect/glow-gold` | Drop 0 0 12 `#D4B46A` 35% |
| `effect/glow-soft` | Drop 0 0 24 `#F0E2B0` 18% |
| `effect/card-rest` | Drop 0 8 24 `#000` 45% |
| `effect/card-hover` | Drop 0 12 32 `#000` 55% + 内描边 gold 20% |
| `effect/frost` | Background blur 16（浮层） |

## 2. Semantic（别名 · Dark 主）

| Semantic | → Primitive |
| --- | --- |
| `bg/page` | `night/1` |
| `bg/surface` | `night/2` |
| `bg/raised` | `night/3` |
| `bg/scrim` | `night/0` @ 72% |
| `text/primary` | `lumen/100` |
| `text/secondary` | `lumen/80` |
| `text/muted` | `lumen/60` |
| `text/disabled` | `lumen/40` |
| `text/on-gold` | `night/0` |
| `accent/primary` | `lumen/gold` |
| `accent/border` | `lumen/gold-deep` |
| `accent/glow` | `lumen/glow` |
| `border/subtle` | `night/4` @ 40% |
| `border/strong` | `night/5` |
| `border/fate` | `lumen/gold-deep` @ 55%（丝线） |
| `action/primary-bg` | `lumen/gold` |
| `action/primary-fg` | `night/0` |
| `action/ghost-bg` | transparent |
| `action/ghost-fg` | `lumen/100` |
| `action/danger-fg` | `state/danger` |
| `feedback/danger` | `state/danger` |
| `feedback/success` | `state/success` |
| `feedback/warn` | `state/warn` |
| `card/gu-face` | `night/2` |
| `card/gu-edge` | 流派色 |
| `meter/hp` | `mark/blood` |
| `meter/qi` | `mark/wisdom` |
| `meter/life` | `mark/time` |

## 3. Figma 集合结构（Standard Pattern）

```text
Collection "Primitives"     mode: Value
Collection "Semantic"       mode: Dark | Light(预留)
Collection "Spacing"        mode: Value
Collection "Radius"         mode: Value
Collection "Type Scale"     mode: Value
```

Scope：颜色 → All；spacing/radius → All；type → TEXT_CONTENT。

Code syntax 建议：`var(--color-bg-page)`、`var(--space-4)` 等。

## 4. 对比度底线

- 正文 `text/primary` on `bg/surface` ≥ 4.5:1  
- 金色按钮 `night/0` on `lumen/gold` ≥ 4.5:1  
- `text/muted` 仅用于辅助，不承担关键规则文案  
