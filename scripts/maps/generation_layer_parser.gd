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
## MILESTONE_9.md fauna: the Sand Lurker (AMBUSHER) and the Spitter (SPITTER)
## get their own marker hues so they're paintable into a real map, same as the
## territorial/hunter markers — chosen (Snir, 2026-06-26) to echo each species'
## own color: tan for the sand-buried lurker, brown for the dark puffer. (The
## lurker marker shares sand's #D2B48C, but it's on a different PNG — the
## gen layer — so there's no parsing conflict.) Blob size still sets the tier.
const LURKER_FISH := Color(0xD2 / 255.0, 0xB4 / 255.0, 0x8C / 255.0)          # #D2B48C tan
const SPITTER_FISH := Color(0x82 / 255.0, 0x55 / 255.0, 0x28 / 255.0)         # #825528 brown
## MILESTONE_10.md — THE SHOAL marker. Echoes the species' pale silvery-teal
## body (Snir's "marker = the species' own color" rule); a blob's size sets the
## SCHOOL SIZE (1px = Small/10 members, 2px = Big/20, 3+px = Elite/40) via the
## same clustering as every other fauna marker. world.gd spawns the Shoal
## CONTROLLER per blob, not a lone fish.
const SHOAL_FISH := Color(0xB3 / 255.0, 0xD9 / 255.0, 0xD1 / 255.0)           # #B3D9D1 pale silvery-teal
const WRECKAGE := Color(0x80 / 255.0, 0x80 / 255.0, 0x80 / 255.0)            # #808080
const DOCK_ZONE := Color(0x6E / 255.0, 0x47 / 255.0, 0x3B / 255.0)           # #6E473B

const COLOR_EPS := 2.0 / 255.0  # tolerant of 8-bit PNG round-trip rounding

## Result dictionary keys.
const KEY_PLAYER_SPAWN := "player_spawn"
const KEY_TERRITORIAL_FISH := "territorial_fish"
const KEY_HUNTER_FISH := "hunter_fish"
const KEY_LURKER_FISH := "lurker_fish"
const KEY_SPITTER_FISH := "spitter_fish"
const KEY_SHOAL_FISH := "shoal_fish"
const KEY_WRECKAGE := "wreckage"
const KEY_DOCK_ZONES := "dock_zones"

## Parses `config.generation_layer`. Returns a Dictionary:
## - "player_spawn": Vector2 (world px), or Vector2.ZERO if no white pixel found
## - "territorial_fish": Array[Dictionary] — {"pos": Vector2, "cls": EnemyDef.Class}
## - "hunter_fish": Array[Dictionary] — same shape
## - "wreckage": Array[Vector2]
## - "dock_zones": Array[Array[Vector2]] — one inner array per physically
##   separate dock (8-connected pixel blob, MILESTONE_11.md Module 2 — a map
##   can paint more than one dock; build each dock's own bbox/center from its
##   own inner array, never merge them together)
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
		KEY_LURKER_FISH: [] as Array[Dictionary],
		KEY_SPITTER_FISH: [] as Array[Dictionary],
		KEY_SHOAL_FISH: [] as Array[Dictionary],
		KEY_WRECKAGE: [] as Array[Vector2],
		KEY_DOCK_ZONES: [] as Array,  ## Array[Array[Vector2]] -- see parse() doc above
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
	var lurker_coords: Array[Vector2i] = []
	var spitter_coords: Array[Vector2i] = []
	var shoal_coords: Array[Vector2i] = []
	var dock_coords: Array[Vector2i] = []
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
			elif _color_matches(pixel, LURKER_FISH):
				lurker_coords.append(Vector2i(x, y))
			elif _color_matches(pixel, SPITTER_FISH):
				spitter_coords.append(Vector2i(x, y))
			elif _color_matches(pixel, SHOAL_FISH):
				shoal_coords.append(Vector2i(x, y))
			elif _color_matches(pixel, WRECKAGE):
				(result[KEY_WRECKAGE] as Array[Vector2]).append(world_pos)
			elif _color_matches(pixel, DOCK_ZONE):
				dock_coords.append(Vector2i(x, y))

	result[KEY_TERRITORIAL_FISH] = _cluster_to_spawns(territorial_coords, scale)
	result[KEY_HUNTER_FISH] = _cluster_to_spawns(hunter_coords, scale)
	result[KEY_LURKER_FISH] = _cluster_to_spawns(lurker_coords, scale)
	result[KEY_SPITTER_FISH] = _cluster_to_spawns(spitter_coords, scale)
	result[KEY_SHOAL_FISH] = _cluster_to_spawns(shoal_coords, scale)
	result[KEY_DOCK_ZONES] = _cluster_dock_zones(dock_coords, scale)
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

## MILESTONE_11.md Module 2: dock-zone pixels are clustered into separate
## physical docks the same way fauna markers cluster into population blobs
## (8-connected flood fill) — a map can paint more than one dock, and each
## becomes its own independently-detectable zone. Unlike _cluster_to_spawns,
## a dock blob keeps every pixel's own world position (not just a centroid +
## tier), since the caller needs the full extent to build each dock's bbox/
## Area2D.
static func _cluster_dock_zones(coords: Array[Vector2i], scale: float) -> Array:
	var remaining := {}
	for c in coords:
		remaining[c] = true
	var docks: Array = []
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
		var positions: Array[Vector2] = []
		for p in blob:
			positions.append(Vector2(p) * scale)
		docks.append(positions)
	return docks
