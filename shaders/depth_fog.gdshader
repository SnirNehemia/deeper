shader_type canvas_item;

// MILESTONE_11.md Module 1 (2026-06-28 redesign, then two same-day/next-day
// follow-ups): a darkness gradient that closes in on the sub. The clear area
// hugs the sub's actual hull silhouette (a small list of world-space hull
// rects, not a single center point) -- clear within `clear_radius_px` of the
// nearest hull surface, ramping to `darkness_alpha` (the far-field cap) over
// `falloff_width_px`, so a long sub reads as a long glow rather than a circle
// poking past its bow/stern evenly. The floodlight beam ADDITIONALLY carves
// a directional wedge into the same darkness -- the union of the hull glow
// and the beam wedge stays clear. GDScript (depth_fog_overlay.gd) drives all
// uniforms every frame from GameFeel.fog + Sub.hull_rects() + Sub.depth_m() +
// the active FloodlightStation (if any).

uniform vec4 fog_color : source_color = vec4(0.02, 0.06, 0.14, 1.0);
uniform float darkness_alpha : hint_range(0.0, 1.0) = 0.0;
uniform vec2 rect_origin = vec2(0.0, 0.0);
uniform vec2 rect_size = vec2(1.0, 1.0);
uniform float clear_radius_px = 0.0;
uniform float falloff_width_px = 1.0;

// The sub's hull, as up to 16 world-space rects (min.x, min.y, max.x, max.y
// per rect) -- 2026-06-29 follow-up #3: the glow hugs this silhouette
// instead of a single center point. Only the first `hull_rect_count` entries
// are read; the rest are padding.
uniform vec4 hull_rects[16];
uniform int hull_rect_count = 0;

// The floodlight's repelled-darkness cone: a triangular wedge from
// `floodlight_tip` along `floodlight_dir`, widening linearly from 0 at the
// tip to `floodlight_half_width_px` at `floodlight_range_px` out -- the same
// chord-of-circle shape FloodlightFeel draws the beam itself with. Off
// (floodlight_on = 0) collapses the wedge to a no-op.
uniform float floodlight_on : hint_range(0.0, 1.0) = 0.0;
uniform vec2 floodlight_tip = vec2(0.0, 0.0);
uniform vec2 floodlight_dir = vec2(1.0, 0.0);
uniform float floodlight_range_px = 0.0;
uniform float floodlight_half_width_px = 0.0;
uniform float floodlight_softness_px = 1.0;

void fragment() {
	vec2 world_pos = rect_origin + UV * rect_size;

	float d = 1e9;
	for (int i = 0; i < hull_rect_count; i++) {
		vec4 r = hull_rects[i];
		vec2 clamped = vec2(clamp(world_pos.x, r.x, r.z), clamp(world_pos.y, r.y, r.w));
		d = min(d, distance(world_pos, clamped));
	}
	float t_ambient = clamp((d - clear_radius_px) / max(falloff_width_px, 1.0), 0.0, 1.0);

	vec2 rel = world_pos - floodlight_tip;
	float fwd = dot(rel, floodlight_dir);
	vec2 perp_axis = vec2(-floodlight_dir.y, floodlight_dir.x);
	float perp = abs(dot(rel, perp_axis));
	float width_at_fwd = floodlight_half_width_px
		* clamp(fwd / max(floodlight_range_px, 1.0), 0.0, 1.0);
	float soft = max(floodlight_softness_px, 1.0);
	float t_side = clamp((perp - width_at_fwd) / soft, 0.0, 1.0);
	float t_near = clamp(-fwd / soft, 0.0, 1.0);
	float t_far = clamp((fwd - floodlight_range_px) / soft, 0.0, 1.0);
	float t_beam = max(t_side, max(t_near, t_far));
	t_beam = mix(1.0, t_beam, floodlight_on);

	float t = min(t_ambient, t_beam);
	COLOR = vec4(fog_color.rgb, darkness_alpha * t);
}
