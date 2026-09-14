// card_hover_glow.gdshader — 卡牌悬停辉光（2026-09-11 卡牌重构）。
//
// 画法：全幅覆盖 Control，片元只画「圆角矩形外扩若干像素的柔光边」，
// 内部完全透明（不打卡面内容）。on=0 时 discard，宿主在 mouse_entered/exited
// 翻转 uniform，不重建材质。
//
// 颜色一律走 uniform（宿主从 GuStyle token 注入），shader 内不写死项目色值。
shader_type canvas_item;
render_mode unshaded;

uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float on : hint_range(0.0, 1.0) = 0.0;
uniform vec2 rect_half = vec2(60.0, 90.0);
uniform float corner_radius = 8.0;
// 辉光外扩厚度（像素）。
uniform float glow_width = 5.0;

float rounded_box_sdf(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	if (on <= 0.001) {
		discard;
	}
	vec2 p = UV * rect_half * 2.0 - rect_half;
	float sdf = rounded_box_sdf(p, rect_half, corner_radius);
	// 只画卡边外侧 [0, glow_width] 的环带，向内不覆盖卡面。
	float outer = 1.0 - smoothstep(0.0, glow_width, sdf);
	float inside_cut = step(0.0, sdf);
	float ring = outer * inside_cut;
	if (ring <= 0.001) {
		discard;
	}
	// 越贴卡边越亮，往外衰减。
	float falloff = 1.0 - clamp(sdf / glow_width, 0.0, 1.0);
	COLOR = vec4(glow_color.rgb, glow_color.a * ring * falloff * on);
}
