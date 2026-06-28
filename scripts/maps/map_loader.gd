class_name MapLoader
extends Node2D

## M6 wiring: assembles everything a map needs from a MapConfig —
## physical terrain, gen-layer entity spawn data, and visual layers — into
## one Node2D added to the world scene. The world pulls spawn coordinates
## and dock parameters from here instead of hardcoding them.

## World position where the player sub should spawn (from gen-layer white pixel).
var sub_spawn: Vector2 = Vector2.ZERO
## The water surface y in world coordinates (top of the first water row).
## Fed to Sub.water_surface_y as the global fallback for buoyancy.
var water_surface_y: float = 0.0
## All connected sky regions found in the physical layer, including the top
## open-air zone and any enclosed cave air pockets. Each entry is a Dictionary
## {"rect": Rect2, "surface_y": float}. Copied to Sub.sky_zones so the sub
## can apply local buoyancy inside each pocket.
var sky_zones: Array = []
## World-space size (px) of the map, from MapVisualLayers' background image —
## MILESTONE_11.md's depth fog overlay sizes itself to this.
var world_size: Vector2 = Vector2.ZERO
## One entry per physically separate dock (MILESTONE_11.md Module 2 — a map
## can paint more than one; each gen-layer dock-pixel blob clusters into its
## own zone here, never merged with another). Each: {"center": Vector2,
## "radius": float, "area": Area2D}. The world iterates these for the
## dry-dock proximity check, Sub.try_bank(), and dock-return positioning.
var docks: Array[Dictionary] = []
## Entity spawn lists read by the world to create Fish and Wreck nodes.
## Fish spawns are Array[Dictionary] — {"pos": Vector2, "cls": EnemyDef.Class}
## — one entry per connected pixel blob in the gen layer (see
## GenerationLayerParser._cluster_to_spawns: blob size sets the class tier).
var territorial_fish_spawns: Array[Dictionary] = []
var hunter_fish_spawns: Array[Dictionary] = []
## MILESTONE_9.md fauna, paintable into a map the same way (tan #D2B48C = Sand
## Lurker, brown #825528 = Spitter). Same {"pos", "cls"} blob-sized shape.
var lurker_fish_spawns: Array[Dictionary] = []
var spitter_fish_spawns: Array[Dictionary] = []
## MILESTONE_10.md — THE SHOAL, paintable the same way (pale silvery-teal
## #B3D9D1). Blob size = SCHOOL SIZE (Small/Big/Elite → 10/20/40 members); world.gd
## spawns the Shoal CONTROLLER per blob, not a lone fish.
var shoal_spawns: Array[Dictionary] = []
var wreck_spawns: Array[Vector2] = []

## Builds and returns a MapLoader for `config`. Adds terrain + visual layers
## as children immediately; entity spawn coordinates are available on the
## returned node for the caller to spawn Fish/Wreck at.
static func build(config: MapConfig) -> MapLoader:
	var loader := MapLoader.new()
	loader.name = "MapLoader"

	# --- Physical terrain ---
	loader.water_surface_y = PhysicalLayerParser.find_water_surface_y(config)
	loader.sky_zones = PhysicalLayerParser.find_sky_zones(config)
	var terrain := PhysicalLayerBuilder.build(config)
	loader.add_child(terrain)

	# --- Visual layers ---
	var visuals := MapVisualLayers.build(config)
	loader.add_child(visuals)
	loader.world_size = visuals.world_size

	# --- Generation layer ---
	var spawns := GenerationLayerParser.parse(config)
	loader.sub_spawn = spawns[GenerationLayerParser.KEY_PLAYER_SPAWN]
	loader.territorial_fish_spawns = spawns[GenerationLayerParser.KEY_TERRITORIAL_FISH]
	loader.hunter_fish_spawns = spawns[GenerationLayerParser.KEY_HUNTER_FISH]
	loader.lurker_fish_spawns = spawns[GenerationLayerParser.KEY_LURKER_FISH]
	loader.spitter_fish_spawns = spawns[GenerationLayerParser.KEY_SPITTER_FISH]
	loader.shoal_spawns = spawns[GenerationLayerParser.KEY_SHOAL_FISH]
	loader.wreck_spawns = spawns[GenerationLayerParser.KEY_WRECKAGE]

	var dock_blobs: Array = spawns[GenerationLayerParser.KEY_DOCK_ZONES]
	for blob in dock_blobs:
		var positions: Array[Vector2] = blob
		if positions.is_empty():
			continue
		var area := _build_dock_area(positions, config.pixel_scale())
		loader.add_child(area)
		loader.docks.append({
			"center": _bbox_center(positions),
			"radius": _bbox_half_diagonal(positions),
			"area": area,
		})

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
