class_name GenerationLayerParser
extends RefCounted

## M6 Module 2: scans a map's generation_layer PNG pixel-by-pixel and reports
## where to spawn the player sub and fauna/wreck entities, in world
## coordinates (scaled per MapConfig.pixel_scale()).

const PLAYER_SPAWN := Color(1, 1, 1)        # #FFFFFF
const TERRITORIAL_FISH := Color(0.5, 0, 0.5)  # #800080
const HUNTER_FISH := Color(0, 1, 0)         # #00FF00
const WRECKAGE := Color(0.5, 0.5, 0.5)      # #808080

const COLOR_EPS := 0.5 / 255.0

## Result dictionary keys.
const KEY_PLAYER_SPAWN := "player_spawn"
const KEY_TERRITORIAL_FISH := "territorial_fish"
const KEY_HUNTER_FISH := "hunter_fish"
const KEY_WRECKAGE := "wreckage"

## Parses `config.generation_layer`. Returns a Dictionary:
## - "player_spawn": Vector2 (world px), or Vector2.ZERO if no white pixel found
## - "territorial_fish": Array[Vector2]
## - "hunter_fish": Array[Vector2]
## - "wreckage": Array[Vector2]
## Returns an empty dictionary (with empty defaults) if the image can't load.
static func parse(config: MapConfig) -> Dictionary:
	var result := {
		KEY_PLAYER_SPAWN: Vector2.ZERO,
		KEY_TERRITORIAL_FISH: [] as Array[Vector2],
		KEY_HUNTER_FISH: [] as Array[Vector2],
		KEY_WRECKAGE: [] as Array[Vector2],
	}

	var image := Image.new()
	var err := image.load(config.generation_layer)
	if err != OK:
		push_error("GenerationLayerParser: failed to load " + config.generation_layer)
		return result

	var scale := config.pixel_scale()
	var size := image.get_size()
	for y in size.y:
		for x in size.x:
			var pixel := image.get_pixel(x, y)
			if pixel.a < COLOR_EPS:
				continue
			var world_pos := Vector2(x, y) * scale
			if _color_matches(pixel, PLAYER_SPAWN):
				result[KEY_PLAYER_SPAWN] = world_pos
			elif _color_matches(pixel, TERRITORIAL_FISH):
				(result[KEY_TERRITORIAL_FISH] as Array[Vector2]).append(world_pos)
			elif _color_matches(pixel, HUNTER_FISH):
				(result[KEY_HUNTER_FISH] as Array[Vector2]).append(world_pos)
			elif _color_matches(pixel, WRECKAGE):
				(result[KEY_WRECKAGE] as Array[Vector2]).append(world_pos)

	return result

static func _color_matches(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < COLOR_EPS \
		and absf(a.g - b.g) < COLOR_EPS \
		and absf(a.b - b.b) < COLOR_EPS
