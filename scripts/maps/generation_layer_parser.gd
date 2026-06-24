class_name GenerationLayerParser
extends RefCounted

## M6 Module 2: scans a map's generation_layer PNG pixel-by-pixel and reports
## where to spawn the player sub and fauna/wreck entities, in world
## coordinates (scaled per MapConfig.pixel_scale()).

const PLAYER_SPAWN := Color(1, 1, 1)                                          # #FFFFFF
## The territorial/hunter fish marker (2026-06-24: recolored purple->orange
## to match the reference fish's body/currency color exactly — Snir's map art
## now uses the same E8742C hex as PlaceholderArt.FISH_COLOR/EnemyDef.body_color,
## not just any orange).
const TERRITORIAL_FISH := Color(0xE8 / 255.0, 0x74 / 255.0, 0x2C / 255.0)    # #E8742C
const HUNTER_FISH := Color(0, 1, 0)                                           # #00FF00
const WRECKAGE := Color(0x80 / 255.0, 0x80 / 255.0, 0x80 / 255.0)            # #808080
const DOCK_ZONE := Color(0x6E / 255.0, 0x47 / 255.0, 0x3B / 255.0)           # #6E473B

const COLOR_EPS := 2.0 / 255.0  # tolerant of 8-bit PNG round-trip rounding

## Result dictionary keys.
const KEY_PLAYER_SPAWN := "player_spawn"
const KEY_TERRITORIAL_FISH := "territorial_fish"
const KEY_HUNTER_FISH := "hunter_fish"
const KEY_WRECKAGE := "wreckage"
const KEY_DOCK_ZONES := "dock_zones"

## Parses `config.generation_layer`. Returns a Dictionary:
## - "player_spawn": Vector2 (world px), or Vector2.ZERO if no white pixel found
## - "territorial_fish": Array[Dictionary] — {"pos": Vector2, "cls": EnemyDef.Class}
## - "hunter_fish": Array[Dictionary] — same shape
## - "wreckage": Array[Vector2]
## - "dock_zones": Array[Vector2] — all dock-zone pixel positions (build the
##   bbox/center from these in the caller to drive dry-dock interaction)
## Returns an empty dictionary (with empty defaults) if the image can't load.
##
## 2026-06-21 (M8 Module 3 follow-up): same-colored pixels that touch
## (including diagonally — a hand-painted blob of a few adjacent pixels reads
## as one connected shape) are grouped into a single spawn at the blob's
## centroid, sized by how many pixels are in it: 1 = Small, 2 = Big, 3+ =
## Elite (clamped — there's no tier above Elite). Lets a map author a
## stronger fish just by painting a bigger blob, no separate class-color
## convention needed.
static func parse(config: MapConfig) -> Dictionary:
	var result := {
		KEY_PLAYER_SPAWN: Vector2.ZERO,
		KEY_TERRITORIAL_FISH: [] as Array[Dictionary],
		KEY_HUNTER_FISH: [] as Array[Dictionary],
		KEY_WRECKAGE: [] as Array[Vector2],
		KEY_DOCK_ZONES: [] as Array[Vector2],
	}

	var image := Image.new()
	var err := image.load(config.generation_layer)
	if err != OK:
		push_error("GenerationLayerParser: failed to load " + config.generation_layer)
		return result

	var scale := config.pixel_scale()
	var size := image.get_size()
	var territorial_coords: Array[Vector2i] = []
	var hunter_coords: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			var pixel := image.get_pixel(x, y)
			if pixel.a < COLOR_EPS:
				continue
			var world_pos := Vector2(x, y) * scale
			if _color_matches(pixel, PLAYER_SPAWN):
				result[KEY_PLAYER_SPAWN] = world_pos
			elif _color_matches(pixel, TERRITORIAL_FISH):
				territorial_coords.append(Vector2i(x, y))
			elif _color_matches(pixel, HUNTER_FISH):
				hunter_coords.append(Vector2i(x, y))
			elif _color_matches(pixel, WRECKAGE):
				(result[KEY_WRECKAGE] as Array[Vector2]).append(world_pos)
			elif _color_matches(pixel, DOCK_ZONE):
				(result[KEY_DOCK_ZONES] as Array[Vector2]).append(world_pos)

	result[KEY_TERRITORIAL_FISH] = _cluster_to_spawns(territorial_coords, scale)
	result[KEY_HUNTER_FISH] = _cluster_to_spawns(hunter_coords, scale)
	return result

static func _color_matches(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < COLOR_EPS \
		and absf(a.g - b.g) < COLOR_EPS \
		and absf(a.b - b.b) < COLOR_EPS

## Groups pixel coordinates into 8-connected blobs (flood fill) and returns
## one {"pos": Vector2, "cls": EnemyDef.Class} spawn per blob, at its
## centroid in world space.
static func _cluster_to_spawns(coords: Array[Vector2i], scale: float) -> Array[Dictionary]:
	var remaining := {}
	for c in coords:
		remaining[c] = true
	var spawns: Array[Dictionary] = []
	for start in coords:
		if not remaining.has(start):
			continue
		var blob: Array[Vector2i] = []
		var queue: Array[Vector2i] = [start]
		remaining.erase(start)
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_back()
			blob.append(cur)
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					var n := Vector2i(cur.x + dx, cur.y + dy)
					if remaining.has(n):
						remaining.erase(n)
						queue.append(n)
		var centroid := Vector2.ZERO
		for p in blob:
			centroid += Vector2(p) * scale
		centroid /= blob.size()
		var cls: EnemyDef.Class
		if blob.size() <= 1:
			cls = EnemyDef.Class.SMALL
		elif blob.size() == 2:
			cls = EnemyDef.Class.BIG
		else:
			cls = EnemyDef.Class.ELITE
		spawns.append({"pos": centroid, "cls": cls})
	return spawns
