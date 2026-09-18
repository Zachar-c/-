// card_holo_foil.gdshader — 卡牌全息闪箔覆盖层（2026-09-11 v2 收敛版）。
//
// 画法：全幅透明覆盖 Control（材质挂这里），片元内做「圆角矩形内遮罩 +
// 彩虹干涉 + 镜面高光」。彩虹与高光相位随 tilt（指针相对卡心）流动，
// 形成随姿态变化的闪箔反光；anim_time 由宿主脚本推进（TIME 暂停会停）。
// 水墨兼容：金色系低饱和、强度低（普通 0 / epic 0.18 / legendary 0.35）。
//
// 颜色一律走 uniform（宿主从 GuStyle token 注入），shader 内不写死项目色值。
shader_type canvas_item;
render_mode unshaded;

uniform vec4 foil_color : source_color = vec4(0.95, 0.85, 0.55, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 rect_half = vec2(60.0, 90.0);
uniform float corner_radius = 8.0;
uniform vec2 tilt = vec2(0.0);
uniform float anim_time = 0.0;
uniform float band_speed = 0.25;

float rounded_box_sdf(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

vec3 rainbow(float t) {
	return 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + t));
}

void fragment() {
	if (intensity <= 0.001) {
		discard;
	}
	vec2 p = UV * rect_half * 2.0 - rect_half;
	float sdf = rounded_box_sdf(p, rect_half, corner_radius);
	float inside = 1.0 - smoothstep(-1.0, 0.0, sdf);
	if (inside <= 0.001) {
		discard;
	}
	// 彩虹干涉：相位随 tilt 流动（姿态改变反光走向）。
	float phase = (UV.x + UV.y) * 2.5 - (tilt.x + tilt.y) * 1.5 + anim_time * band_speed;
	vec3 irid = rainbow(phase);
	// 镜面高光：固定光源方向，高光点随 tilt 移动（裸眼 3D 的立体线索）。
	vec2 light_dir = vec2(-0.6, -0.8);
	float spec = clamp(dot(normalize(tilt + vec2(0.0001)), light_dir) * 0.5 + 0.5, 0.0, 1.0);
	spec = pow(spec, 8.0);
	// 闪箔带：正弦波峰取幂 → 2~3 条随时间/姿态扫过的斜向亮带，其余区域只留弱金洗底。
	float band = pow(max(sin(phase * 3.14159), 0.0), 3.0);
	float a = (0.10 + 0.60 * band * (0.35 + 0.65 * spec) + 0.30 * spec) * intensity;
	// 亮带处更白亮，非带区偏金，贴水墨气质。
	vec3 col = mix(foil_color.rgb, vec3(1.0), band * 0.45) * mix(vec3(1.0), irid, 0.5);
	COLOR = vec4(col, a * inside);
}
