# 问真视觉风格 · 色板与公共组件规格

> 全部色值来自 Codex 基准图（`assets/base_ref.png`，1405×790）逐像素采样校准，
> 与 `scripts/presentation/gu_style.gd` 中的 GuStyle token 同源。改色前先改基准采样，再同步 token。

## 1. 纸底与网点（全屏基底）

| token | 色值 | 用途 |
|---|---|---|
| PAPER_BG | `#ece9df` | 主表面、宣纸白 |
| PAPER_HALL | `#e5e2d7` | 大厅/流派主纸面 |
| PAPER_MAP | `#e7e4da` | 地图主纸面 |
| PAPER_RAISED | `#e6e2d7` | 次级纸面 |
| PAPER_DEEP | `#ddd8cc` | 禁用层 |

**网点纹理** `assets/hall_dots.png`：5×7px 周期（列距 5px × 行距 7px）、1px 圆点、不透明
RGB(200,201,190)、以 Tile 模式铺满全屏。任何屏幕背景 = 纸底 ColorRect + 网点 TextureRect。

## 2. 墨色与文字 token

| token | 色值 | 用途 |
|---|---|---|
| INK_PRIMARY | `#171814` | 大标题、主文字 |
| INK_SOFT | `#686960` | 次级文字、灰值 |
| INK_MUTED | `#68675f` | 介于主文字与纸底 |
| SUBTITLE_TEXT | `#707060` | 副题 |
| NAV_TEXT | `#505040` | 右栏导航按钮 |
| NOTE_TEXT | `#607060` | 说明/注释 |
| STAT_NAME_TEXT | `#606860` | 属性名/区块标题 |
| VER_TEXT | `#888880` | 版本号 |
| CORNER_TEXT | `#707870` | 左上角角标 |
| HILITE_PLACE | `#c89860` | 上一世地点（橙棕） |
| HILITE_REALM | `#6898c0` | 境界（蓝灰） |
| HILITE_NOTE | `#98c8d8` | 札记名（青蓝） |

## 3. 朱砂与语义色

| token | 色值 | 用途 |
|---|---|---|
| CINNABAR | `#9c332d` | 强调/hover 文字 |
| SEAL_CINNABAR | `#8c5850` | 印章印泥（框+字） |
| REDLINE | `#82463e` | 标题下红线 |
| STATUS_CONTRACT | `#506880` | 契约（蓝灰） |
| STATUS_MUTATE | `#887830` | 异变/DDA（橄榄黄） |
| STATUS_CURSE | `#904038` | 诅咒（砖红） |
| JADE | `#3f7063` | 护盾/正向（青绿） |

## 4. 主按钮（双色描边，基准实测）

| token | 色值 | 用途 |
|---|---|---|
| BTN_OUTLINE_BLUE | `#3880b8` | 蓝色描边（outline） |
| ~~BTN_SHADOW_RUST~~ | `#803810` | **已废弃（2026-09-11 用户裁定：全部文字阴影移除）** |

**规格**：透明底（网点透出）、TITLE_FONT、font_size 22、黑字芯 INK_PRIMARY、
蓝 outline 1px、hover 文字转 CINNABAR、圆角 2px。**无文字阴影。**

## 5. 印章（apply_seal 公共组件）

- 方角直角框（corner_radius 0），边框 2px，印泥 SEAL_CINNABAR
- 2×2 竖排字（TITLE_FONT，12px），字与框同色
- **顺时针微斜 +3°**（Godot `rotation = deg_to_rad(3.0)`）
- 透明底（网点透出）
