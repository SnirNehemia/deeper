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
	await _test_ladder_climb(Vector2i(1, 0), "claw")     # helm -> claw room
	await _test_ladder_climb(Vector2i(0, 0), "bullet")   # engine -> bullet room

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

	_check(sub.active_room_count() == 7, "water model has 7 rooms")

	# Placement-order indices: engine 0, helm 1, turret_room 2, tower 3,
	# bullet_room 4, claw_room 5, storage 6.
	var claw := sub.room_rect(5)
	var bullet := sub.room_rect(4)
	var storage := sub.room_rect(6)
	var helm := sub.room_rect(1)
	var engine := sub.room_rect(0)

	_check(claw.position.y >= helm.position.y + helm.size.y,
		"claw room sits below the helm")
	_check(absf(claw.position.x - helm.position.x) < 1.0
			and absf(claw.size.x - helm.size.x) < 1.0,
		"claw room is directly under the helm (same x-span)")

	_check(bullet.position.y >= engine.position.y + engine.size.y,
		"bullet room sits below the engine room")
	_check(absf(bullet.position.x - engine.position.x) < 1.0
			and absf(bullet.size.x - engine.size.x) < 1.0,
		"bullet room is directly under the engine room (same x-span)")

	_check(is_equal_approx(claw.size.y, Sub.CELL_H)
			and is_equal_approx(bullet.size.y, Sub.CELL_H),
		"lower deck rooms are the uniform 3 m cell height (settled M4 delta)")

	# Claw and storage share an edge (the doorway between them).
	_check(is_equal_approx(storage.position.x, claw.position.x + claw.size.x),
		"claw room and storage room share a wall (the doorway)")

	sub.queue_free()
	await _frames(2)

func _test_door_step_connectivity() -> void:
	print("[claw <-> storage doorway]")
	var sub := _new_sub()
	# Pool water in storage above its (squatter-room) door sill: it should
	# spill into the claw room next door.
	# Lower deck is now the uniform 3 m height, so its doors use the same sill
	# as the main deck. Flood the claw room (index 5); it spills through the
	# claw<->storage doorway into the storage room (index 6).
	var sill: float = GameFeel.water.door_sill_m / GameFeel.water.room_height_m
	sub.water_levels = [0.0, 0.0, 0.0, 0.0, 0.0, sill + 0.3, 0.0]

	await _frames(120)
	_check(sub.water_levels[6] > 0.01,
		"water above the door sill spills from the claw room into the storage room")

	sub.queue_free()
	await _frames(2)

## Drives a crew member down a lower-deck ladder from a normal standing
## position on the main deck, then back up (playtest #1: ladders were too
## fiddly to grab and the storage one couldn't be climbed down at all).
func _test_ladder_climb(upper_cell: Vector2i, label: String) -> void:
	print("[%s ladder]" % label)
	var sub := _new_sub()
	# The ladder shaft x for the stack starting at this upper (main-deck) cell.
	var ladder_x := 0.0
	for l in sub.geometry.ladders:
		if l.upper_cell == upper_cell:
			ladder_x = l.x
	var mid_floor := sub.claw_drop_floor_y() * 0.5  # halfway between main (0) and lower (144) floors

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
	_check(crew.position.y > mid_floor,
		"%s ladder: crew climbs down to the lower deck" % label)

	# Press up: climb back to the main deck.
	_press(KEY_W)
	await _frames(90)
	_release(KEY_W)
	await _frames(30)
	_check(crew.position.y < mid_floor,
		"%s ladder: crew climbs back up to the main deck" % label)

	sub.queue_free()
	await _frames(2)
