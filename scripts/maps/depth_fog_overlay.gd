class_name DepthFogOverlay
extends ColorRect

## MILESTONE_11.md Module 1 (2026-06-28 redesign, Snir): a radial darkness
## gradient over the outside water that CLOSES IN on the sub with depth --
## clear near the sub, fading to pitch-dark at the edges, the clear radius
## itself shrinking as depth approaches the deepest zone cap (so the deepest
## areas are practically black everywhere). Covers the full world rect via
## `shaders/depth_fog.gdshader`, computed in world space so it lines up with
## the floodlight beam / ambient glow (also world-space). Sits at a z_index
## ABOVE plain gameplay (fish, wrecks, background — all default z=0) so it
## visually obscures them in the dark, but BELOW the sub (Sub.z_index is
## raised past Z_INDEX in sub.gd) so the hull, crew, room interiors, the
## floodlight beam, and the sub's own ambient glow all draw on top of it and
## punch through via ordinary alpha blending — no masking needed. Purely
## cosmetic: the only gameplay value it reads is Sub.depth_m(), the same one
## the hull-pressure gate already uses; nothing here feeds back into AI or
## detection.
##
## 2026-06-28 follow-up (Snir): the far field is fog-free in the Shallows,
## then ramps (gradually, not a snap -- 2026-06-29 follow-up #3) toward fully
## OPAQUE at the deepest zone cap -- depth mostly changes how big the clear
## area around the sub is, not just how dark the outer edges get. The active
## floodlight beam also carves its own directional wedge into the darkness
## (see shaders/depth_fog.gdshader), genuinely repelling it rather than just
## being painted on top. 2026-06-29 follow-up #3: the clear area hugs the
## sub's real hull silhouette (Sub.hull_rects(), fed to the shader each frame)
## instead of a circle from a single center point, so a long sub reads as a
## long glow.

## Above normal gameplay (z=0) and a resting salvage drop (z=6), below a
## carried/tip salvage item (z=50, see salvage_item.gd) and the sub itself.
const Z_INDEX := 40
const SHADER_PATH := "res://shaders/depth_fog.gdshader"
## Must match the fixed-size `hull_rects` array declared in the shader.
## The grid's bounds guard (SubGrid.MAX_CELLS = 9x5) caps the sub's room count
## well under this, even with every slot bought out over a long run.
const MAX_HULL_RECTS := 16

var sub: Sub = null
var _shader: ShaderMaterial

static func build(world_size: Vector2) -> DepthFogOverlay:
	var overlay := DepthFogOverlay.new()
	overlay.name = "DepthFogOverlay"
	overlay.position = Vector2.ZERO
	overlay.size = world_size
	overlay.z_index = Z_INDEX
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color(1, 1, 1, 1)  # irrelevant: the shader fully overrides COLOR

	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PATH)
	mat.set_shader_parameter("rect_origin", overlay.position)
	mat.set_shader_parameter("rect_size", overlay.size)
	overlay.material = mat
	overlay._shader = mat
	return overlay

func _process(_delta: float) -> void:
	if sub == null or not is_instance_valid(sub):
		return
	var feel := GameFeel.fog
	var depth := sub.depth_m()
	var ppm := GameFeel.PIXELS_PER_METER
	_shader.set_shader_parameter("fog_color", feel.fog_color)
	_shader.set_shader_parameter("darkness_alpha", feel.outer_alpha(depth))
	_shader.set_shader_parameter("clear_radius_px", feel.clear_radius_m_at(depth) * ppm)
	_shader.set_shader_parameter("falloff_width_px", feel.falloff_width_m * ppm)

	# 2026-06-29 follow-up #3: the clear area hugs the sub's actual hull
	# silhouette instead of a single center point -- pad to MAX_HULL_RECTS so
	# the array size always matches the shader's fixed declaration.
	var hull_rects: Array = []
	for r in sub.hull_rects():
		if hull_rects.size() >= MAX_HULL_RECTS:
			break  # an implausibly room-stuffed sub -- silently drop the rest
		var origin: Vector2 = sub.global_position + r.position
		hull_rects.append(Vector4(origin.x, origin.y, origin.x + r.size.x, origin.y + r.size.y))
	var rect_count := hull_rects.size()
	while hull_rects.size() < MAX_HULL_RECTS:
		hull_rects.append(Vector4.ZERO)
	_shader.set_shader_parameter("hull_rects", hull_rects)
	_shader.set_shader_parameter("hull_rect_count", rect_count)

	# 2026-06-28 follow-up #3: the active floodlight beam carves its own
	# wedge into the darkness, on top of the ambient clear circle above.
	var fl := sub.active_floodlight()
	if fl != null:
		_shader.set_shader_parameter("floodlight_on", 1.0)
		_shader.set_shader_parameter("floodlight_tip", sub.to_global(fl.tip_local))
		_shader.set_shader_parameter("floodlight_dir", fl.beam_dir())
		_shader.set_shader_parameter("floodlight_range_px", fl.height_m * ppm)
		var half_width_m := GameFeel.floodlight.base_half_width_m(fl.height_m)
		_shader.set_shader_parameter("floodlight_half_width_px", half_width_m * ppm)
		_shader.set_shader_parameter("floodlight_softness_px", feel.floodlight_cutout_softness_m * ppm)
	else:
		_shader.set_shader_parameter("floodlight_on", 0.0)
