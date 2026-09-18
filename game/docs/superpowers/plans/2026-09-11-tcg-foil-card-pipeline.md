# 卡牌全息闪箔 + 裸眼 3D 效果 方案（2026-09-11 v2，收敛版）

> 状态：实现中。v1 的 Python 生成流水线 / cards.json / 卡牌工厂 / 万智风排版**全部砍掉**。
> 用户裁定（2026-09-11）：不要万智风格，不与水墨风冲突；只要裸眼 3D + 卡牌全息闪箔两项效果，收敛实现。

## 1. 范围

只加两个 CanvasItem Shader 与对应接线，落在本局现有卡牌上，不新增目录、不新增数据文件、不动领域层：

| 效果 | 载体 | 实现 |
|---|---|---|
| 全息闪箔 | `gu_card.tscn` 的 `ShimmerOverlay` 覆盖层（换新 shader） | 彩虹干涉 + 镜面高光，TIME + tilt 驱动，稀有度控强度 |
| 裸眼 3D | 画框内插画 `GuImage`（挂视差 shader） | 指针相对卡心的 tilt 驱动 UV 视差偏移，插画在画框内轻微游动 |

水墨兼容：彩虹用低饱和金色系（GuStyle.ANOMALY_YELLOW 调制），强度低（≤0.35），高光扫掠代替高饱和镭射；普通/稀有卡几乎不可见，epic+ 才明显。

## 2. Shader

### 2.1 `assets/wenzhen/shaders/card_holo_foil.gdshader`（全息闪箔覆盖层）

```glsl
shader_type canvas_item;
render_mode unshaded;

uniform vec4 foil_color : source_color = vec4(0.95, 0.85, 0.55, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;   // 稀有度控（epic 0.18 / legendary 0.35，普通 0）
uniform vec2 rect_half = vec2(60.0, 90.0);
uniform float corner_radius = 8.0;
uniform vec2 tilt = vec2(0.0);       // 指针相对卡心 [-1..1]，宿主注入
uniform float anim_time = 0.0;       // 脚本推进（TIME 暂停会停）
uniform float band_speed = 0.25;

float rounded_box_sdf(vec2 p, vec2 half_size, float r) {
    vec2 q = abs(p) - half_size + vec2(r);
    return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

vec3 rainbow(float t) {
    return 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + t));
}

void fragment() {
    if (intensity <= 0.001) { discard; }
    vec2 p = UV * rect_half * 2.0 - rect_half;
    float sdf = rounded_box_sdf(p, rect_half, corner_radius);
    float inside = 1.0 - smoothstep(-1.0, 0.0, sdf);
    if (inside <= 0.001) { discard; }
    // 1) 彩虹干涉：相位随 tilt 流动（姿态改变反光）。
    float phase = (UV.x + UV.y) * 2.5 - (tilt.x + tilt.y) * 1.5 + anim_time * band_speed;
    vec3 irid = rainbow(phase);
    // 2) 镜面高光：固定光源方向，tilt 反向移动（裸眼 3D 的立体线索）。
    vec2 light_dir = vec2(-0.6, -0.8);
    float spec = clamp(dot(normalize(tilt + vec2(0.0001)), light_dir) * 0.5 + 0.5, 0.0, 1.0);
    spec = pow(spec, 6.0) * (0.6 + 0.4 * length(tilt));
    // 3) 弱化到水墨能接受的饱和度。
    vec3 tint = mix(foil_color.rgb, irid, 0.45) * intensity;
    float glow = (0.35 + 0.65 * spec) * intensity;
    COLOR = vec4(tint + foil_color.rgb * spec * intensity, glow * inside);
}
```

### 2.2 `assets/wenzhen/shaders/card_parallax.gdshader`（裸眼 3D 视差）

```glsl
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D art_tex : source_color, filter_linear;
uniform vec2 tilt = vec2(0.0);        // 与闪箔同一 tilt，宿主同源注入
uniform float depth = 0.012;          // 视差幅度（UV 比例）

void fragment() {
    // tilt 反向偏移 + 轻微缩放，避免边缘露底。
    vec2 uv = UV + tilt * depth;
    uv = clamp(uv, vec2(0.005), vec2(0.995));
    COLOR = texture(art_tex, uv);
}
```

## 3. 宿主接线（`gu_card_view.gd`，约 30 行）

- `_gui_input` 捕获鼠标移动 → `tilt = (local_pos - size/2) / (size/2)`，写入两个材质；`mouse_exited` 归零（pointer 离开回到静止）。
- `ShimmerOverlay` 材质换成 `card_holo_foil.gdshader`（原 `card_rarity_shimmer.gdshader` 删除，无其他引用）；强度沿用稀有度映射。
- `GuImage` 挂 `card_parallax.gdshader` 材质（代码内创建），`art_tex` 绑定原纹理。
- `_process` 仅 epic+ 推进 `anim_time`；截图/测试可冻结。

## 4. 验收

- `tools/check.ps1` + `tools/test.ps1 -Suite unit` 全绿（现有卡牌测试不回归）。
- headless 断言：两材质存在、tilt 写入生效、普通卡 intensity=0。
- 真窗效果（彩虹观感、视差幅度）由用户主动验收后调参；数值先落代码常量，收敛后再按需挪 JSON。
