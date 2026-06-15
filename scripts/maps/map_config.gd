class_name MapConfig
extends Resource

## M6 Module 2: a lightweight map configuration loaded from a JSON file.
## Points at the four layered PNGs that describe one hand-drawn map, plus the
## pixel-to-meter ratio used to scale every layer into world coordinates.

@export var map_id: String = ""

## How many image pixels make up one in-game meter. World calculations must
## scale by (PIXELS_PER_METER / pixels_per_meter) rather than assuming 1:1, so
## raising this later (denser source art) needs no parser rewrites.
@export var pixels_per_meter: float = 1.0

@export var physical_layer: String = ""
@export var generation_layer: String = ""
@export var visual_background: String = ""
@export var visual_foreground: String = ""

## Loads a MapConfig from a JSON file at `path` (e.g. "res://maps/test_map/test_map.json").
## Returns null if the file is missing or malformed.
static func load_from_json(path: String) -> MapConfig:
	if not FileAccess.file_exists(path):
		push_error("MapConfig: file not found: " + path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		push_error("MapConfig: invalid JSON in " + path)
		return null
	var config := MapConfig.new()
	config.map_id = data.get("map_id", "")
	config.pixels_per_meter = float(data.get("pixels_per_meter", 1.0))
	config.physical_layer = data.get("physical_layer", "")
	config.generation_layer = data.get("generation_layer", "")
	config.visual_background = data.get("visual_background", "")
	config.visual_foreground = data.get("visual_foreground", "")
	return config

## The world-space size (in pixels) of one source-image pixel, given the
## game's world scale (GameFeel.PIXELS_PER_METER px = 1 m).
func pixel_scale() -> float:
	return GameFeel.PIXELS_PER_METER / pixels_per_meter
