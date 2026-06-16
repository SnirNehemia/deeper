class_name PhysicalLayerParser
extends RefCounted

## M6 Module 3: scans a map's physical_layer PNG and produces solid-block
## rectangles (in world coordinates, scaled per MapConfig.pixel_scale()),
## tagged with their TerrainType. Adjacent horizontal pixels of the same
## terrain are merged into one rectangle per row, to cut down the resulting
## collision shape count.
##
## Passable colors (water, sky) are skipped and produce no collision geometry.

## Pixels of these colors represent open space — navigable, no collision.
## Sky (#4d9bc7) is passable: buoyancy pushes the sub back down when it rises
## above the water surface (see MapLoader.water_surface_y + Sub.SURFACE_FLOAT_DEPTH).
const PASSABLE_COLORS: Array = [
	Color(0x1d / 255.0, 0x4a / 255.0, 0x70 / 255.0),  # #1d4a70 water
	Color(0x4D / 255.0, 0x9B / 255.0, 0xC7 / 255.0),  # #4d9bc7 sky — open air above surface
]

## One merged block: world-space Rect2 + TerrainType.Type.
class Block:
	var rect: Rect2
	var terrain: TerrainType.Type

	func _init(p_rect: Rect2, p_terrain: TerrainType.Type) -> void:
		rect = p_rect
		terrain = p_terrain

## Parses `config.physical_layer`. Returns an Array[Block]. Every
## non-transparent pixel becomes part of a block; empty Array if the image
## can't load.
static func parse(config: MapConfig) -> Array[Block]:
	var blocks: Array[Block] = []

	var image := Image.new()
	var err := image.load(config.physical_layer)
	if err != OK:
		push_error("PhysicalLayerParser: failed to load " + config.physical_layer)
		return blocks

	var scale := config.pixel_scale()
	var size := image.get_size()
	for y in size.y:
		var run_start := -1
		var run_terrain := -1
		for x in size.x:
			var pixel := image.get_pixel(x, y)
			var solid := pixel.a >= TerrainType.COLOR_EPS and not _is_passable(pixel)
			var terrain := int(TerrainType.from_color(pixel)) if solid else -1
			if solid and run_start >= 0 and terrain == run_terrain:
				continue  # extend the current run
			if run_start >= 0:
				blocks.append(_make_block(run_start, x, y, scale, run_terrain as TerrainType.Type))
				run_start = -1
			if solid:
				run_start = x
				run_terrain = terrain
		if run_start >= 0:
			blocks.append(_make_block(run_start, size.x, y, scale, run_terrain as TerrainType.Type))

	return blocks

const _PASSABLE_EPS := 2.0 / 255.0  # wider than TerrainType.COLOR_EPS for PNG round-trip safety

static func _is_passable(pixel: Color) -> bool:
	for c in PASSABLE_COLORS:
		if absf(pixel.r - c.r) < _PASSABLE_EPS \
				and absf(pixel.g - c.g) < _PASSABLE_EPS \
				and absf(pixel.b - c.b) < _PASSABLE_EPS:
			return true
	return false

static func _make_block(x0: int, x1: int, y: int, scale: float, terrain: TerrainType.Type) -> Block:
	var rect := Rect2(Vector2(x0, y) * scale, Vector2(x1 - x0, 1) * scale)
	return Block.new(rect, terrain)

## Returns the water surface y in world coordinates — the top edge of the
## first row that contains a water pixel (#1d4a70). Scanning from y=0 downward
## finds the exact sky/water boundary regardless of whether the map has sky.
## Returns 0.0 if the image is missing or contains no water pixels.
static func find_water_surface_y(config: MapConfig) -> float:
	var image := Image.new()
	if image.load(config.physical_layer) != OK:
		return 0.0
	var scale := config.pixel_scale()
	var water := PASSABLE_COLORS[0]  # #1d4a70
	for y in image.get_height():
		for x in image.get_width():
			var p := image.get_pixel(x, y)
			if p.a < _PASSABLE_EPS:
				continue
			if absf(p.r - water.r) < _PASSABLE_EPS \
					and absf(p.g - water.g) < _PASSABLE_EPS \
					and absf(p.b - water.b) < _PASSABLE_EPS:
				return y * scale  # top edge of the first water row = the surface
	return 0.0

## Finds all connected sky (#4d9bc7) regions via flood fill and returns them
## as an Array of Dictionaries {"rect": Rect2, "surface_y": float}.
## "surface_y" is the world-y at the bottom of each region — the local water
## surface for that sky zone. Both the top open-air area and enclosed cave air
## pockets are included, each with their own independent surface_y.
static func find_sky_zones(config: MapConfig) -> Array:
	var image := Image.new()
	if image.load(config.physical_layer) != OK:
		return []
	var w := image.get_width()
	var h := image.get_height()
	var scale := config.pixel_scale()
	var sky := PASSABLE_COLORS[1]  # #4d9bc7

	# Flat visited + is-sky grid (PackedByteArray for speed)
	var visited := PackedByteArray()
	visited.resize(w * h)
	visited.fill(0)
	var is_sky := PackedByteArray()
	is_sky.resize(w * h)
	for y in h:
		for x in w:
			var p := image.get_pixel(x, y)
			var sky_px: bool = p.a >= _PASSABLE_EPS \
				and absf(p.r - sky.r) < _PASSABLE_EPS \
				and absf(p.g - sky.g) < _PASSABLE_EPS \
				and absf(p.b - sky.b) < _PASSABLE_EPS
			is_sky[y * w + x] = 1 if sky_px else 0

	var zones: Array = []
	for y in h:
		for x in w:
			var idx := y * w + x
			if visited[idx] or not is_sky[idx]:
				visited[idx] = 1
				continue
			# BFS flood fill for this connected sky region
			var queue: PackedInt32Array = PackedInt32Array()
			queue.append(idx)
			visited[idx] = 1
			var min_x := x; var max_x := x
			var min_y := y; var max_y := y
			var qi := 0
			while qi < queue.size():
				var cur := queue[qi]; qi += 1
				var cy := cur / w; var cx := cur % w
				if cx < min_x: min_x = cx
				if cx > max_x: max_x = cx
				if cy < min_y: min_y = cy
				if cy > max_y: max_y = cy
				# 4-connected neighbours (bounds-safe, no row-wrap)
				if cx > 0:
					var n := cur - 1
					if not visited[n] and is_sky[n]:
						visited[n] = 1; queue.append(n)
				if cx < w - 1:
					var n := cur + 1
					if not visited[n] and is_sky[n]:
						visited[n] = 1; queue.append(n)
				if cy > 0:
					var n := cur - w
					if not visited[n] and is_sky[n]:
						visited[n] = 1; queue.append(n)
				if cy < h - 1:
					var n := cur + w
					if not visited[n] and is_sky[n]:
						visited[n] = 1; queue.append(n)
			zones.append({
				"rect": Rect2(
					Vector2(min_x, min_y) * scale,
					Vector2(max_x - min_x + 1, max_y - min_y + 1) * scale),
				"surface_y": (max_y + 1) * scale,  # world-y of the bottom edge
			})
	return zones
