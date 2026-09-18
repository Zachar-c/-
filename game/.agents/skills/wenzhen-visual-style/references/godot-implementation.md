# 问真视觉风格 · Godot 4 实施要点

> 项目：`gu-zhenren-editor`（Godot 4.x，`res://` 根）。
> 视觉硬流程：**独立 HTML 线框稿 → Edge 无头截图 `.preview/*.png` → 用户审阅批准 → 才改 tscn 实施**。
> 窗口 1280×720 与基准图/线框稿 1:1 验收。必须通过改公共组件达成效果，不得各屏私设硬编码色值。

## 1. 公共入口

- `scripts/presentation/gu_style.gd`：全部 token 常量（见 tokens.md）+ 公共组件函数
  `apply_seal(panel, tilt_deg=3.0)`（印章）、`label(text, size, color)`。
- 屏脚本（`scripts/presentation/screens/*_screen_view.gd`）只消费 token，不硬编码 `Color("xxxxxx")`。

## 2. 网点背景（tscn 节点模板）

在屏根下加两个全屏节点（ColorRect 在下、TextureRect 在上）：

```text
[node name="xxxPaper" type="ColorRect parent="xxx_root"]   # anchors full rect, color = 纸底 token
[node name="xxxDots" type="TextureRect" parent="xxx_root"] # anchors full rect
texture = <hall_dots.png>  # assets/wenzhen/hall/hall_dots.png
expand_mode = 1
stretch_mode = 6           # Tile
```

## 3. 标题

Label：`font = GuStyle.TITLE_FONT`、色 `GuStyle.INK_PRIMARY`、标题下加 2px 红线
ColorRect 色 `#82463e`（REDLINE）。

## 4. 印章

```gdscript
GuStyle.apply_seal($Path/SealPanelContainer)  # 方角 + 顺时针 +3° + 深印泥，自动完成
```

## 5. 按钮

- 导航/次要按钮：透明底 + `NAV_TEXT`，hover 转 CINNABAR，圆角 2px。
- 主按钮（确认/进入）：透明底 + TITLE_FONT 22px + INK_PRIMARY 黑字芯 +
  `font_outline_color=BTN_OUTLINE_BLUE` + `outline_size=1`；
  未激活态 = 透明底 + INK_SOFT 灰字（无描边）。
  （2026-09-11 用户裁定：全部文字阴影移除，`BTN_SHADOW_RUST` 左投影不再使用，勿回加。）

## 6. 语义状态文字

契约=STATUS_CONTRACT、异变/DDA=STATUS_MUTATE、诅咒=STATUS_CURSE、护盾=JADE。
不用这些色做大面积底色，只做文字/徽标。

## 7. 验证

- 渲染：`tools/verify_*.gd`（非 headless 真窗）→ `.preview/*.png`（1280×720），
  PowerShell 启动 `& .\tools\godot.ps1 -Console --path . -s tools/verify_xxx.gd`，跑完杀 Godot 进程。
- 像素核对：纯 Python PNG 解码采样目标区色簇，与 tokens.md 色值比对（±16 容差）。
- 守卫：`.preview/run_guard.ps1` → 7/7 全绿方可交付。

## 8. 已知坑

- 直接 Edit 大块 tscn 会 Native failure → 用 Python 字符串替换脚本，写回 `newline=''` 保 CRLF。
- RichTextLabel 左右锚点相同则宽度 0 文字不可见 → 显式 `offset_right`。
- 改纹理后删 `.godot/imported/<tex>.ctex/.md5` 再 `--headless --import`。
- PowerShell `curl` 是别名 → 用 `curl.exe`。
