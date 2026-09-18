---
name: wenzhen-visual-style
description: "《问真》(gu-zhenren-editor, Godot 4) 游戏 UI 美术风格唯一权威规范：以 codex 基准图 assets/base_ref.png（1405×790）为基线逐像素采样。适用于为该项目设计任何屏幕（大厅/地图/战斗/流派/设置/杀招/炼蛊/商店/休息/结算/调试）、画线框稿、审计实机渲染与基线的差异、改 tscn 视觉、或新增公共组件（按钮/印章/面板/顶栏）。命中即读 SKILL.md；改色必须先重采样基准图再同步 tokens。"
---

# 问真视觉风格 · Wenzhen Visual Style

## 定位

**唯一权威基线 = `assets/base_ref.png`**（codex 生成的 1405×790 基准图，全界面基准设计）。
一切色值、字体、印章、按钮、网点、布局比例都从这张图采样；实机渲染与它不一致就是缺陷。
任何改色/加组件前，先回到基准图重新采样，再改 token，禁止凭空拍色值。

## 硬流程（视觉任务必经）

1. **线框稿先行**：新屏/改版先出独立 HTML 线框稿（1280×720，网点纸面 + 墨色 + 朱砂 + 透明按钮），
   Edge/Chrome 无头截图 `.preview/*_wireframe_v*.png`，等用户批准后再动 tscn。
2. **公共组件达成**：必须通过改公共组件（`gu_style.gd` / `wenzhen_master_theme.gd` / 公共 tscn）落地，
   各屏脚本不得私设硬编码色值。
3. **1:1 验收**：窗口 1280×720，实机渲染与线框稿/基线图对齐；真窗渲染图存 `.preview/*_render.png`。

## 资源（渐进披露，按需读取）

- `references/tokens.md` — 色板 token（纸底/网点、墨色、朱砂、按钮、印章规格）+ 基准采样方法。
- `references/godot-implementation.md` — Godot 4 实施要点（公共入口、网点节点模板、按钮/印章代码、验证、已知坑）。
- `assets/base_ref.png` — 权威基线图（改色/采样来源）。
- `assets/hall_dots.png` — 网点纹理图（5×7px 周期，Tile 铺满）。

## 核心规范速查

| 项 | 规范 |
|---|---|
| 背景 | 纸底 ColorRect + 网点 TextureRect（hall_dots Tile），任何屏幕都必须有 |
| 主文字 | INK_PRIMARY `#171814`（墨），次级 INK_SOFT `#686960`，禁止低对比浅灰正文 |
| 标题 | TITLE_FONT + 墨色 + 标题下 2px 红线 `#82463e`（REDLINE） |
| 印章 | 方角直角框、2px 深印泥 `#8c5850`、2×2 竖排字、**顺时针 +3°**、透明底 |
| 主按钮 | 透明底、TITLE_FONT 22、墨字芯、蓝描边 1px + 铁锈橙红左投影 1px、hover 转朱砂 |
| 导航/次要按钮 | 透明底 + NAV_TEXT，hover 转朱砂，圆角 2px |
| 语义色 | 契约蓝灰 / 异变橄榄黄 / 诅咒砖红 / 护盾青绿，只做文字徽标不作大面积底 |

## 纪律

- 不引入与基线无关的新配色；用户点名"高级感、清冷感"由基线的低饱和纸面 + 墨色 + 朱砂实现。
- 改色流程：裁剪基准图目标区 → 采样色簇（±16 容差比对）→ 更新 tokens.md → 同步 `gu_style.gd` → 全屏回归。
- 用户批准过的线框稿（`docs/superpowers/specs/2026-09-0*-*-wireframe*.html`）是实施合同，先对齐它再谈自由发挥。
