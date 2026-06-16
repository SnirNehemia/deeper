class_name PhysicalLayerParser
extends RefCounted

## M6 Module 3: scans a map's physical_layer PNG and produces solid-block
## rectangles (in world coordinates, scaled per MapConfig.pixel_scale()),
## tagged with their TerrainType. Adjacent horizontal pixels of the same
## terrain are merged into one rectangle per row, to cut down the resulting
## collision shape count.
##
## Passable colors (water, sky) are skipped and produce no collision geometry.

## Pixels of these colors represent open water — navigable, no collision.
## Sky (#4d9bc7) is intentionally NOT in this list: sky pixels create solid
## non-damaging collision (TerrainType.DOCK) so the sub can't fly into cave
## ceiling openings, mirroring the buoyancy ceiling from the Shore Shelf map.
const PASSABLE_COLORS: Array = [
	Color(0x1d / 255.0, 0x4a / 255.0, 0x70 / 255.0),  # #1d4a70 water
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

static func _is_passable(pixel: Color) -> bool:
	for c in PASSABLE_COLORS:
		if absf(pixel.r - c.r) < TerrainType.COLOR_EPS \
				and absf(pixel.g - c.g) < TerrainType.COLOR_EPS \
				and absf(pixel.b - c.b) < TerrainType.COLOR_EPS:
			return true
	return false

static func _make_block(x0: int, x1: int, y: int, scale: float, terrain: TerrainType.Type) -> Block:
	var rect := Rect2(Vector2(x0, y) * scale, Vector2(x1 - x0, 1) * scale)
	return Block.new(rect, terrain)
