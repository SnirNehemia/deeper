extends Node

## Headless test for the lower deck (Milestone 3, Module A).
##
## Run: godot --headless res://tests/test_lower_deck.tscn
## Verifies the claw room (below middle) and storage room (below engine) are
## reachable rooms with their own water levels, connected to each other by a
## doorway, and that floor-opening flow fills the bottom deck first and drains
## it last.

var _failures := 0

func _ready() -> void:
	GameFeel.water.drain_rate = 0.0
	await _test_room_geometry()
	await _test_floor_opening_fills_bottom_first()
	await _test_drains_last()
	await _test_door_step_connectivity()

	if _failures == 0:
		print("LOWER DECK TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("LOWER DECK TESTS FAILED: %d failing check(s)" % _failures)
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

func _new_sub() -> Sub:
	var sub := Sub.new()
	add_child(sub)
	return sub

func _test_room_geometry() -> void:
	print("[lower deck geometry]")
	var sub := _new_sub()

	_check(Sub.ROOM_COUNT == 6, "water model has 6 rooms")

	var claw := sub.room_rect(4)
	var storage := sub.room_rect(5)
	var middle := sub.room_rect(1)
	var engine := sub.room_rect(0)

	_check(claw.position.y >= middle.position.y + middle.size.y,
		"claw room sits below the middle room")
	_check(absf(claw.position.x - middle.position.x) < 1.0
			and absf(claw.size.x - middle.size.x) < 1.0,
		"claw room is directly under the middle room (same x-span)")

	_check(storage.position.y >= engine.position.y + engine.size.y,
		"storage room sits below the engine room")
	_check(absf(storage.position.x - engine.position.x) < 1.0
			and absf(storage.size.x - engine.size.x) < 1.0,
		"storage room is directly under the engine room (same x-span)")

	_check(is_equal_approx(claw.size.y, Sub.LOWER_ROOM_H)
			and is_equal_approx(storage.size.y, Sub.LOWER_ROOM_H),
		"lower deck rooms are squatter than the main deck (2.5 m)")

	# Claw and storage share an edge (the doorway between them).
	_check(is_equal_approx(claw.position.x, storage.position.x + storage.size.x),
		"claw room and storage room share a wall (the doorway)")

	sub.queue_free()
	await _frames(2)

func _test_floor_opening_fills_bottom_first() -> void:
	print("[bottom deck floods first]")
	var sub := _new_sub()
	# Flood the middle room; the claw room below starts dry.
	sub.water_levels = [0.0, 1.0, 0.0, 0.0, 0.0, 0.0]

	await _frames(2)
	_check(sub.water_levels[4] > 0.0, "claw room gains water from the middle room above")

	await _frames(900)  # ~15s
	_check(sub.water_levels[4] > sub.water_levels[1],
		"the claw room (bottom deck) is fuller than the middle room above it")

	sub.queue_free()
	await _frames(2)

func _test_drains_last() -> void:
	print("[bottom deck drains last]")
	var sub := _new_sub()
	GameFeel.water.drain_rate = 1.0 / 12.0  # restore canon drain for this check
	# Engine room and storage room start equally flooded; let the pumps drain
	# both at the same rate while the floor opening keeps pushing water down.
	sub.water_levels = [0.5, 0.0, 0.0, 0.0, 0.0, 0.5]

	await _frames(60)  # ~1s
	var storage_remaining: float = sub.water_levels[5]
	var engine_remaining: float = sub.water_levels[0]
	_check(storage_remaining > 0.0, "storage room (bottom deck) still holds water")
	_check(storage_remaining >= engine_remaining - 0.001,
		"the bottom deck retains at least as much water as the room above it")

	GameFeel.water.drain_rate = 0.0
	sub.queue_free()
	await _frames(2)

func _test_door_step_connectivity() -> void:
	print("[claw <-> storage doorway]")
	var sub := _new_sub()
	# Pool water in storage above its (squatter-room) door sill: it should
	# spill into the claw room next door.
	var sill: float = GameFeel.water.door_sill_m / GameFeel.water.lower_room_height_m
	sub.water_levels = [0.0, 0.0, 0.0, 0.0, 0.0, sill + 0.3]

	await _frames(120)
	_check(sub.water_levels[4] > 0.01,
		"water above the lower-deck door sill spills from storage into the claw room")

	sub.queue_free()
	await _frames(2)
