class_name DepthFogOverlay
extends ColorRect

## MILESTONE_11.md Module 1: a flat darkness layer over the outside water,
## covering the full world rect. Sits at a z_index ABOVE plain gameplay (fish,
## wrecks, background — all default z=0) so it visually obscures them in the
## dark, but BELOW the sub (Sub.z_index is raised past Z_INDEX in sub.gd) so
## the hull, crew, room interiors, the floodlight beam, and the sub's own
## ambient glow all draw on top of it and punch through via ordinary alpha
## blending — no shader/masking needed for a first pass. Purely cosmetic: the
## only gameplay value it reads is Sub.depth_m(), the same one the hull-
## pressure gate already uses; nothing here feeds back into AI or detection.

## Above normal gameplay (z=0) and a resting salvage drop (z=6), below a
## carried/tip salvage item (z=50, see salvage_item.gd) and the sub itself.
const Z_INDEX := 40

var sub: Sub = null

static func build(world_size: Vector2) -> DepthFogOverlay:
	var overlay := DepthFogOverlay.new()
	overlay.name = "DepthFogOverlay"
	overlay.position = Vector2.ZERO
	overlay.size = world_size
	overlay.z_index = Z_INDEX
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := GameFeel.fog.fog_color
	overlay.color = Color(c.r, c.g, c.b, 0.0)
	return overlay

func _process(_delta: float) -> void:
	if sub == null or not is_instance_valid(sub):
		return
	var feel := GameFeel.fog
	var alpha := feel.darkness_alpha(sub.depth_m())
	color = Color(feel.fog_color.r, feel.fog_color.g, feel.fog_color.b, alpha)
