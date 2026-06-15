shader_type canvas_item;

// M6 Module 4: gentle ambient water motion. A low-amplitude horizontal
// sine-wave UV displacement applied to whatever has already been drawn
// (background landscape + sub + crew/fish), giving a slow, undulating
// "underwater shimmer" without any real fluid simulation.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float speed : hint_range(0.0, 4.0) = 0.6;
uniform float amplitude : hint_range(0.0, 0.02) = 0.004;
uniform float frequency : hint_range(0.0, 40.0) = 8.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	uv.x += sin(uv.y * frequency + TIME * speed) * amplitude;
	COLOR = texture(screen_texture, uv);
}
