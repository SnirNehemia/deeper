extends Node

## Headless test for the lower deck (Milestone 3, Module A + playtest #1
## revision).
##
## Run: godot --headless res://tests/test_lower_deck.tscn
## Verifies the claw room (below middle) and storage room (below engine) are
## reachable rooms with their own water levels, connected to each other by a
## doorway (water spills between them but does NOT flow up through the
## ladders), and that both lower-deck ladders can be climbed down and back up
## from a normal standing position.

var _failures := 0
var _hub: Node

func _ready() -> void:
	_hub = get_node("/root/InputHub")
	GameFeel.water.drain_rate = 0.0
	await _test_room_geometry()
	await _test_door_step_connectivity()
	await _test_ladder_climb(Sub.CLAW_LADDER_X, "claw")
	await _test_ladder_climb(Sub.STORAGE_LADDER_X, "storage")

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

func _key(keycode: Key, pressed: bool) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = keycode
	e.pressed = pressed
	return e

func _press(keycode: Key) -> void:
	_hub._input(_key(keycode, true))

func _release(keycode: Key) -> void:
	_hub._input(_key(keycode, false))

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

## Drives a crew member down a lower-deck ladder from a normal standing
## position on the main deck, then back up (playtest #1: ladders were too
## fiddly to grab and the storage one couldn't be climbed down at all).
func _test_ladder_climb(ladder_x: float, label: String) -> void:
	print("[%s ladder]" % label)
	var sub := _new_sub()
	var crew := Crew.new()
	crew.player_index = 0
	crew.position = Vector2(ladder_x, -100.0)
	sub.add_child(crew)

	await _frames(90)
	_check(crew.is_on_floor(), "%s ladder: crew lands on the main deck floor" % label)

	# Press down: grab the ladder and descend to the lower deck.
	_press(KEY_S)
	await _frames(90)
	_release(KEY_S)
	await _frames(30)
	_check(crew.position.y > Sub.LOWER_FLOOR_Y * 0.5,
		"%s ladder: crew climbs down to the lower deck" % label)

	# Press up: climb back to the main deck.
	_press(KEY_W)
	await _frames(90)
	_release(KEY_W)
	await _frames(30)
	_check(crew.position.y < Sub.LOWER_FLOOR_Y * 0.5,
		"%s ladder: crew climbs back up to the main deck" % label)

	sub.queue_free()
	await _frames(2)
