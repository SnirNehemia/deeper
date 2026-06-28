extends Node

## Headless test for MILESTONE_11.md Module 2: the dock-return fix.
##
## Run: godot --headless res://tests/test_dock_return.tscn
## Verifies: (1) the gen-layer dock-zone clustering keeps separate physical
## docks separate instead of merging them into one bbox; (2) the real world
## scene's live map (cavern_depths_01) actually has more than one dock; (3)
## closing the dry dock after a change (buy-a-room rebuild) returns the sub
## to the dock it was AT, not the run's home spawn; (4) a full run reset
## (implosion) always returns to the home spawn regardless of which dock was
## last touched.

var _failures := 0

func _ready() -> void:
	_test_cluster_keeps_docks_separate()
	await _test_world_has_multiple_docks()
	await _test_dry_dock_close_returns_to_touched_dock()
	await _test_run_reset_returns_to_home_dock()

	if _failures == 0:
		print("DOCK RETURN TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("DOCK RETURN TESTS FAILED: %d failing check(s)" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok:   ", msg)
	else:
		push_error("  FAIL: " + msg)
		_failures += 1

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## Two single-pixel dock blobs, far apart, must stay two separate dock
## entries -- never merged into one bbox the way the pre-M11 code did.
func _test_cluster_keeps_docks_separate() -> void:
	print("[gen-layer dock clustering stays separate]")
	var far_apart: Array[Vector2i] = [Vector2i(0, 0), Vector2i(100, 100)]
	var docks: Array = GenerationLayerParser._cluster_dock_zones(far_apart, 1.0)
	_check(docks.size() == 2, "two far-apart dock pixels parse as two separate docks")

	var touching: Array[Vector2i] = [Vector2i(5, 5), Vector2i(6, 6)]
	var merged: Array = GenerationLayerParser._cluster_dock_zones(touching, 1.0)
	_check(merged.size() == 1 and (merged[0] as Array).size() == 2,
		"touching dock pixels still merge into one physical dock")

## The real live map (cavern_depths_01) has more than one dock painted in --
## this is the actual bug repro condition, not a hypothetical.
func _test_world_has_multiple_docks() -> void:
	print("[real map has multiple docks]")
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await _frames(5)
	_check(world._docks.size() >= 2, "cavern_depths_01 parses into 2+ separate docks")
	world.queue_free()
	await _frames(2)

func _test_dry_dock_close_returns_to_touched_dock() -> void:
	print("[dry-dock close returns to the touched dock]")
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await _frames(5)

	_check(world._docks.size() >= 2, "precondition: at least 2 docks")
	# Pick whichever dock is farther from the home spawn as "the other dock".
	var other_idx := 0
	var best_dist := -1.0
	for i in world._docks.size():
		var d: Dictionary = world._docks[i]
		var dist: float = (d["center"] as Vector2).distance_to(world._sub_spawn)
		if dist > best_dist:
			best_dist = dist
			other_idx = i
	var other_dock: Dictionary = world._docks[other_idx]

	world._sub.global_position = other_dock["center"]
	await _frames(2)
	_check(world._is_docked(), "sub reads as docked at the non-home dock")

	world._on_hull_station_dock_requested()
	_check(world._dry_dock != null, "dry dock opened")
	_check(world._active_dock_index == other_idx, "captured the non-home dock as the active one")

	world._on_dry_dock_closed(true)  # simulate a buy-a-room change
	await _frames(2)
	_check(world._sub.global_position.distance_to(other_dock["center"]) < 10.0,
		"rebuilt sub is back at the dock it was touching, not the home spawn")

	world.queue_free()
	await _frames(2)

func _test_run_reset_returns_to_home_dock() -> void:
	print("[run reset always returns to the home dock]")
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await _frames(5)

	var other_idx := 0
	var best_dist := -1.0
	for i in world._docks.size():
		var d: Dictionary = world._docks[i]
		var dist: float = (d["center"] as Vector2).distance_to(world._sub_spawn)
		if dist > best_dist:
			best_dist = dist
			other_idx = i
	var other_dock: Dictionary = world._docks[other_idx]

	world._sub.global_position = other_dock["center"]
	await _frames(2)
	world._on_hull_station_dock_requested()  # _active_dock_index now points at the non-home dock
	if world._dry_dock != null:
		world._dry_dock.queue_free()
		world._dry_dock = null

	world.reset_run()
	await _frames(2)
	_check(world._sub.global_position.distance_to(world._sub_spawn) < 10.0,
		"a run reset returns to the home spawn, ignoring the last-touched dock")

	world.queue_free()
	await _frames(2)
