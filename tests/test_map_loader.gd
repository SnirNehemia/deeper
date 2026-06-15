extends Node

## Headless test for M6 Module 2: MapConfig + GenerationLayerParser.
##
## Run: godot --headless res://tests/test_map_loader.tscn
## Verifies: the JSON config loads with the right ratio, and the generation
## layer's marker pixels (white/purple/green/grey) map to the correct
## world-space spawn points and entity buckets.

const M := GameFeel.PIXELS_PER_METER

var _failures := 0

func _ready() -> void:
	_test_config_load()
	_test_generation_parse()
	if _failures == 0:
		print("MAP LOADER TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("MAP LOADER TESTS FAILED: %d failing check(s)" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok:   ", msg)
	else:
		push_error("  FAIL: " + msg)
		_failures += 1

func _test_config_load() -> void:
	print("[map config]")
	var config := MapConfig.load_from_json("res://maps/test_map/test_map.json")
	_check(config != null, "config loads")
	_check(config.map_id == "test_map", "map_id parsed")
	_check(config.pixels_per_meter == 1.0, "pixels_per_meter parsed")
	_check(config.pixel_scale() == M, "pixel_scale() == 48px at 1 px/m")
	_check(config.generation_layer == "res://maps/test_map/test_map_gen.png",
		"generation_layer path parsed")

func _test_generation_parse() -> void:
	print("[generation layer parse]")
	var config := MapConfig.load_from_json("res://maps/test_map/test_map.json")
	var spawns := GenerationLayerParser.parse(config)

	_check(spawns[GenerationLayerParser.KEY_PLAYER_SPAWN] == Vector2(1, 1) * M,
		"player spawn at white pixel (1,1) -> world (%s, %s)" % [M, M])

	var territorial: Array[Vector2] = spawns[GenerationLayerParser.KEY_TERRITORIAL_FISH]
	_check(territorial.size() == 1 and territorial[0] == Vector2(5, 2) * M,
		"territorial fish at purple pixel (5,2)")

	var hunters: Array[Vector2] = spawns[GenerationLayerParser.KEY_HUNTER_FISH]
	_check(hunters.size() == 1 and hunters[0] == Vector2(8, 8) * M,
		"hunter fish at green pixel (8,8)")

	var wrecks: Array[Vector2] = spawns[GenerationLayerParser.KEY_WRECKAGE]
	_check(wrecks.size() == 1 and wrecks[0] == Vector2(3, 8) * M,
		"wreckage at grey pixel (3,8)")
