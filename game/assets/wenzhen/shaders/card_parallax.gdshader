// card_parallax.gdshader — 卡牌插画裸眼 3D 视差（2026-09-11 v2 收敛版）。
//
// 画法：宿主把指针相对卡心的 tilt（[-1..1]）注入 uniform，片元对插画
// UV 做反向偏移 + 轻微钳制，插画在画框内轻微游动，产生前后景深错觉。
// 静止（tilt=0）时逐像素等价原图，零开销感。
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D art_tex : source_color, filter_linear;
uniform vec2 tilt = vec2(0.0);
uniform float depth = 0.02;

void fragment() {
	vec2 uv = UV + tilt * depth;
	uv = clamp(uv, vec2(0.005), vec2(0.995));
	COLOR = texture(art_tex, uv);
}
