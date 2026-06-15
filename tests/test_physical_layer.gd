extends Node

## Headless test for M6 Module 3: PhysicalLayerParser, PhysicalLayerBuilder,
## and Sub.register_impact's per-TerrainType modifiers.
##
## Run: godot --headless res://tests/test_physical_layer.tscn

const M := GameFeel.PIXELS_PER_METER

var _failures := 0

func _ready() -> void:
	_test_parse_and_merge()
	_test_build_bodies()
	_test_impact_rules()
	if _failures == 0:
		print("PHYSICAL LAYER TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("PHYSICAL LAYER TESTS FAILED: %d failing check(s)" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok:   ", msg)
	else:
		push_error("  FAIL: " + msg)
		_failures += 1

func _test_parse_and_merge() -> void:
	print("[physical layer parse + merge]")
	var config := MapConfig.load_from_json("res://maps/test_map/test_map.json")
	var blocks := PhysicalLayerParser.parse(config)

	# 4 rows painted -> 4 merged runs (one rect per row, horizontally merged).
	_check(blocks.size() == 4, "4 merged blocks (one per painted row), got %d" % blocks.size())

	var by_terrain := {}
	for b in blocks:
		by_terrain[b.terrain] = b

	var normal: PhysicalLayerParser.Block = by_terrain[TerrainType.Type.NORMAL_ROCK]
	_check(normal.rect == Rect2(Vector2(0, 0) * M, Vector2(5, 1) * M),
		"normal rock row merged to a 5px-wide run")

	var sand: PhysicalLayerParser.Block = by_terrain[TerrainType.Type.SAND]
	_check(sand.rect == Rect2(Vector2(0, 1) * M, Vector2(4, 1) * M),
		"sand row merged to a 4px-wide run")

	var sharp: PhysicalLayerParser.Block = by_terrain[TerrainType.Type.SHARP_ROCK]
	_check(sharp.rect == Rect2(Vector2(0, 2) * M, Vector2(2, 1) * M),
		"sharp rock row merged to a 2px-wide run")

	var dock: PhysicalLayerParser.Block = by_terrain[TerrainType.Type.DOCK]
	_check(dock.rect == Rect2(Vector2(0, 3) * M, Vector2(3, 1) * M),
		"dock row merged to a 3px-wide run")

func _test_build_bodies() -> void:
	print("[physical layer build]")
	var config := MapConfig.load_from_json("res://maps/test_map/test_map.json")
	var root := PhysicalLayerBuilder.build(config)
	add_child(root)

	var bodies := 0
	var dock_zones := 0
	for child in root.get_children():
		if child is TerrainBody:
			bodies += 1
			_check(child.collision_layer == Layers.TERRAIN, "TerrainBody is on the TERRAIN layer")
			_check(child.get_child_count() > 0, "TerrainBody has collision shapes")
		elif child.is_in_group("dock_zone"):
			dock_zones += 1
			_check(child is Area2D, "dock zone is an Area2D")

	_check(bodies == 4, "4 TerrainBody nodes (one per terrain type), got %d" % bodies)
	_check(dock_zones == 1, "1 dock-zone Area2D")

	root.queue_free()

func _test_impact_rules() -> void:
	print("[per-terrain impact rules]")
	var sub := Sub.new()
	add_child(sub)
	await get_tree().process_frame

	# Normal rock: 2 m/s is the threshold; below it, no breach.
	_check(sub.register_impact(1.9, sub.global_position, TerrainType.Type.NORMAL_ROCK) == false,
		"normal rock: 1.9 m/s is safe (below 2 m/s threshold)")
	sub.breaches.clear()
	_check(sub.register_impact(2.5, sub.global_position, TerrainType.Type.NORMAL_ROCK) == true,
		"normal rock: 2.5 m/s breaches")
	sub.breaches.clear()

	# Sand: threshold doubled to 4 m/s; 3 m/s is safe.
	_check(sub.register_impact(3.0, sub.global_position, TerrainType.Type.SAND) == false,
		"sand: 3 m/s is safe (below doubled 4 m/s threshold)")
	sub.breaches.clear()
	_check(sub.register_impact(5.0, sub.global_position, TerrainType.Type.SAND) == true,
		"sand: 5 m/s breaches")
	var sand_severity: float = (5.0 - 4.0) * GameFeel.breach.ram_severity_per_speed * 0.5
	_check(absf(sub.breaches[0].leak_rate - GameFeel.breach.severity_to_inflow(sand_severity)) < 1e-6,
		"sand breach severity is halved")
	sub.breaches.clear()

	# Sharp rock: threshold halved to 1 m/s; any hit above it is max severity.
	_check(sub.register_impact(0.9, sub.global_position, TerrainType.Type.SHARP_ROCK) == false,
		"sharp rock: 0.9 m/s is safe (below halved 1 m/s threshold)")
	sub.breaches.clear()
	_check(sub.register_impact(1.5, sub.global_position, TerrainType.Type.SHARP_ROCK) == true,
		"sharp rock: 1.5 m/s breaches")
	_check(absf(sub.breaches[0].leak_rate - GameFeel.breach.severity_to_inflow(GameFeel.breach.severity_max)) < 1e-6,
		"sharp rock breach forced to max severity (rapid flooding)")
	sub.breaches.clear()

	# Dock: never breaches, regardless of speed.
	_check(sub.register_impact(20.0, sub.global_position, TerrainType.Type.DOCK) == false,
		"dock: even a hard hit never breaches")

	sub.queue_free()
