extends Node

## Headless test for M6 Module 2: MapConfig + GenerationLayerParser.
##
## Run: godot --headless res://tests/test_map_loader.tscn
## Verifies: the JSON config loads with the right ratio, and the generation
## layer's marker pixels (white/orange/green/grey) map to the correct
## world-space spawn points and entity buckets.

const M := GameFeel.PIXELS_PER_METER

var _failures := 0

func _ready() -> void:
	_test_config_load()
	_test_generation_parse()
	_test_clustering_by_pixel_count()
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

	var territorial: Array[Dictionary] = spawns[GenerationLayerParser.KEY_TERRITORIAL_FISH]
	_check(territorial.size() == 1 and territorial[0]["pos"] == Vector2(5, 2) * M,
		"territorial fish at orange pixel (5,2)")
	_check(territorial[0]["cls"] == EnemyDef.Class.SMALL,
		"a single isolated pixel parses as Small")

	var hunters: Array[Dictionary] = spawns[GenerationLayerParser.KEY_HUNTER_FISH]
	_check(hunters.size() == 1 and hunters[0]["pos"] == Vector2(8, 8) * M,
		"hunter fish at green pixel (8,8)")
	_check(hunters[0]["cls"] == EnemyDef.Class.SMALL,
		"a single isolated pixel parses as Small")

	var lurkers: Array[Dictionary] = spawns[GenerationLayerParser.KEY_LURKER_FISH]
	_check(lurkers.size() == 1 and lurkers[0]["pos"] == Vector2(2, 5) * M,
		"sand lurker at magenta pixel (2,5)")
	_check(lurkers[0]["cls"] == EnemyDef.Class.SMALL,
		"a single isolated lurker pixel parses as Small")

	var spitters: Array[Dictionary] = spawns[GenerationLayerParser.KEY_SPITTER_FISH]
	_check(spitters.size() == 1 and spitters[0]["pos"] == Vector2(6, 5) * M,
		"spitter at brown pixel (6,5)")
	_check(spitters[0]["cls"] == EnemyDef.Class.SMALL,
		"a single isolated spitter pixel parses as Small")

	var shoals: Array[Dictionary] = spawns[GenerationLayerParser.KEY_SHOAL_FISH]
	_check(shoals.size() == 1 and shoals[0]["pos"] == Vector2(4, 4) * M,
		"shoal at pale silvery-teal pixel (4,4)")
	_check(shoals[0]["cls"] == EnemyDef.Class.SMALL,
		"a single isolated shoal pixel parses as a Small school")

	var wrecks: Array[Vector2] = spawns[GenerationLayerParser.KEY_WRECKAGE]
	_check(wrecks.size() == 1 and wrecks[0] == Vector2(3, 8) * M,
		"wreckage at grey pixel (3,8)")

## 2026-06-21 (M8 Module 3 follow-up): connected pixel blobs in the gen layer
## set the class tier — 1 pixel = Small, 2 connected = Big, 3+ = Elite
## (clamped). Tested directly against the clustering helper (8-connectivity,
## including diagonal touches) rather than via real PNGs.
func _test_clustering_by_pixel_count() -> void:
	print("[clustering: connected pixel blobs -> class tier]")

	var lone: Array[Vector2i] = [Vector2i(0, 0)]
	var lone_spawns := GenerationLayerParser._cluster_to_spawns(lone, 1.0)
	_check(lone_spawns.size() == 1 and lone_spawns[0]["cls"] == EnemyDef.Class.SMALL,
		"a standalone pixel is Small")

	var pair: Array[Vector2i] = [Vector2i(5, 5), Vector2i(6, 6)]  # diagonal touch
	var pair_spawns := GenerationLayerParser._cluster_to_spawns(pair, 1.0)
	_check(pair_spawns.size() == 1 and pair_spawns[0]["cls"] == EnemyDef.Class.BIG,
		"two connected pixels merge into one Big spawn")

	var trio: Array[Vector2i] = [Vector2i(10, 10), Vector2i(11, 10), Vector2i(11, 11)]
	var trio_spawns := GenerationLayerParser._cluster_to_spawns(trio, 1.0)
	_check(trio_spawns.size() == 1 and trio_spawns[0]["cls"] == EnemyDef.Class.ELITE,
		"three connected pixels merge into one Elite spawn")

	var quad: Array[Vector2i] = [Vector2i(20, 20), Vector2i(21, 20), Vector2i(20, 21), Vector2i(21, 21)]
	var quad_spawns := GenerationLayerParser._cluster_to_spawns(quad, 1.0)
	_check(quad_spawns.size() == 1 and quad_spawns[0]["cls"] == EnemyDef.Class.ELITE,
		"four+ connected pixels still clamps at Elite (no tier above it)")

	var apart: Array[Vector2i] = [Vector2i(0, 0), Vector2i(5, 5)]
	var apart_spawns := GenerationLayerParser._cluster_to_spawns(apart, 1.0)
	_check(apart_spawns.size() == 2, "non-adjacent pixels stay separate spawns")
	_check(apart_spawns[0]["cls"] == EnemyDef.Class.SMALL and apart_spawns[1]["cls"] == EnemyDef.Class.SMALL,
		"each separate spawn is its own Small, not merged")
