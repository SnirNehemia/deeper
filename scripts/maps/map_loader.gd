class_name MapLoader
extends Node2D

## M6 wiring: assembles everything a map needs from a MapConfig —
## physical terrain, gen-layer entity spawn data, and visual layers — into
## one Node2D added to the world scene. The world pulls spawn coordinates
## and dock parameters from here instead of hardcoding them.

## World position where the player sub should spawn (from gen-layer white pixel).
var sub_spawn: Vector2 = Vector2.ZERO
## The water surface y in world coordinates, derived from the bottommost sky
## row in the physical layer. Fed to Sub.water_surface_y for buoyancy.
var water_surface_y: float = 0.0
## Center and radius of the docking area (derived from gen-layer dock pixels),
## fed to Sub.try_bank() and the _is_docked() proximity check.
var dock_center: Vector2 = Vector2.ZERO
var dock_radius: float = 0.0
## Entity spawn lists read by the world to create Fish and Wreck nodes.
var territorial_fish_spawns: Array[Vector2] = []
var hunter_fish_spawns: Array[Vector2] = []
var wreck_spawns: Array[Vector2] = []
## The dock-zone Area2D (collision_mask = SUB_HULL) added as a child, so the
## world can call dock_zone.overlaps_body(sub) for the dry-dock prompt.
var dock_zone: Area2D = null

## Builds and returns a MapLoader for `config`. Adds terrain + visual layers
## as children immediately; entity spawn coordinates are available on the
## returned node for the caller to spawn Fish/Wreck at.
static func build(config: MapConfig) -> MapLoader:
	var loader := MapLoader.new()
	loader.name = "MapLoader"

	# --- Physical terrain ---
	loader.water_surface_y = PhysicalLayerParser.find_water_surface_y(config)
	var terrain := PhysicalLayerBuilder.build(config)
	loader.add_child(terrain)

	# --- Visual layers ---
	var visuals := MapVisualLayers.build(config)
	loader.add_child(visuals)

	# --- Generation layer ---
	var spawns := GenerationLayerParser.parse(config)
	loader.sub_spawn = spawns[GenerationLayerParser.KEY_PLAYER_SPAWN]
	loader.territorial_fish_spawns = spawns[GenerationLayerParser.KEY_TERRITORIAL_FISH]
	loader.hunter_fish_spawns = spawns[GenerationLayerParser.KEY_HUNTER_FISH]
	loader.wreck_spawns = spawns[GenerationLayerParser.KEY_WRECKAGE]

	var dock_positions: Array[Vector2] = spawns[GenerationLayerParser.KEY_DOCK_ZONES]
	if not dock_positions.is_empty():
		loader.dock_center = _bbox_center(dock_positions)
		loader.dock_radius = _bbox_half_diagonal(dock_positions)
		loader.dock_zone = _build_dock_area(dock_positions, config.pixel_scale())
		loader.add_child(loader.dock_zone)

	return loader

# --- Helpers ---

static func _bbox_center(points: Array[Vector2]) -> Vector2:
	var min_p := points[0]
	var max_p := points[0]
	for p in points:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	return (min_p + max_p) * 0.5

static func _bbox_half_diagonal(points: Array[Vector2]) -> float:
	var min_p := points[0]
	var max_p := points[0]
	for p in points:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	return (max_p - min_p).length() * 0.5

static func _build_dock_area(positions: Array[Vector2], scale: float) -> Area2D:
	var area := Area2D.new()
	area.name = "DockZone"
	area.add_to_group("dock_zone")
	area.collision_layer = 0
	area.collision_mask = Layers.SUB_HULL
	area.monitoring = true
	area.monitorable = false
	# One bounding rect covering all dock pixels, expanded by one cell to
	# ensure the sub hull overlaps even when touching the edge.
	var min_p := positions[0]
	var max_p := positions[0]
	for pos in positions:
		min_p = min_p.min(pos)
		max_p = max_p.max(pos)
	max_p += Vector2(scale, scale)  # include the trailing edge of the last pixel
	var bbox_size := max_p - min_p
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = bbox_size
	shape.shape = box
	shape.position = min_p + bbox_size * 0.5
	area.add_child(shape)
	return area
