extends Node

## Headless test for the sub interior (Step 3).
##
## Run: godot --headless res://tests/test_sub.tscn
## Drops crew inside a real Sub and drives them through the live InputHub to
## prove the geometry actually works: land on the floor, run through the doorways
## across all three rooms, and climb the ladder up into the conning area.

var _failures := 0

func _ready() -> void:
	await _run()
	if _failures == 0:
		print("SUB TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("SUB TESTS FAILED: %d failing check(s)" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok:   ", msg)
	else:
		push_error("  FAIL: " + msg)
		_failures += 1

func _key(keycode: Key, pressed: bool) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = keycode
	e.pressed = pressed
	return e

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _run() -> void:
	print("[sub]")
	var hub: Node = get_node("/root/InputHub")

	var sub := Sub.new()
	add_child(sub)

	# P1 starts in the stern (engine) room, on the left.
	var crew := Crew.new()
	crew.player_index = 0
	crew.position = Vector2(-240, -60)
	sub.add_child(crew)

	# Land.
	await _frames(90)
	_check(crew.is_on_floor(), "crew lands on the sub floor")

	# Run all the way right (D) — through both doorways into the helm room.
	hub._input(_key(KEY_D, true))
	await _frames(150)
	hub._input(_key(KEY_D, false))
	_check(crew.position.x > Sub.DIV_X + 20.0, "crew ran through doorways into the helm room")
	_check(crew.is_on_floor(), "crew still on the floor after the run (not stuck on a header)")

	# Walk back to the ladder column (left) and stop near center.
	hub._input(_key(KEY_A, true))
	await _frames(60)
	hub._input(_key(KEY_A, false))
	await _frames(30)

	# Nudge onto the ladder x (~0) so the sensor overlaps the climb column.
	crew.position.x = 0.0
	crew.velocity = Vector2.ZERO
	await _frames(5)
	var floor_y := crew.position.y

	# Climb up (W) into the conning area.
	hub._input(_key(KEY_W, true))
	await _frames(90)
	hub._input(_key(KEY_W, false))
	_check(crew.position.y < floor_y - Sub.ROOM_H * 0.5,
		"crew climbed the ladder up toward the conning area")

	# Climb back down (S) and land again.
	hub._input(_key(KEY_S, true))
	await _frames(120)
	hub._input(_key(KEY_S, false))
	await _frames(60)
	_check(crew.is_on_floor(), "crew climbed back down and is on the floor")
