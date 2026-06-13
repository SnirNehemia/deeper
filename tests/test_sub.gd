extends Node

## Headless test for the sub interior + ladder/hatch behavior (Step 3, revised).
##
## Run: godot --headless res://tests/test_sub.tscn
## Drives crew through the live InputHub to prove the geometry and the playtest
## fixes: traverse all rooms, climb the ladder, crew block each other, and the
## conning hatch is solid unless you press down.

var _failures := 0
var _hub: Node

func _ready() -> void:
	_hub = get_node("/root/InputHub")
	_test_dimensions()
	await _test_traversal_and_ladder()
	await _test_crew_collision()
	await _test_hatch()

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

func _press(keycode: Key) -> void:
	_hub._input(_key(keycode, true))

func _release(keycode: Key) -> void:
	_hub._input(_key(keycode, false))

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _new_sub() -> Sub:
	var sub := Sub.new()
	add_child(sub)
	return sub

## The sub-local x of the ladder shaft from the middle room up to the tower.
func _tower_ladder_x(sub: Sub) -> float:
	for l in sub.geometry.ladders:
		if l.upper_cell == Vector2i(1, -1):
			return l.x
	return 0.0

func _test_dimensions() -> void:
	print("[dimensions]")
	# Crew shortened to 4/5 of the original 1.5 m.
	_check(is_equal_approx(PlaceholderArt.CREW_HEIGHT_M, 1.2), "crew height is 1.2 m (4/5 of 1.5)")

func _test_traversal_and_ladder() -> void:
	print("[traversal + ladder]")
	var sub := _new_sub()
	var crew := Crew.new()
	crew.player_index = 0
	crew.position = Vector2(-240, -60)
	sub.add_child(crew)

	await _frames(90)
	_check(crew.is_on_floor(), "crew lands on the sub floor")

	# Run right through both doorways into the helm room, hopping the door steps
	# (playtest #2): pulse a jump every so often while running.
	_press(KEY_D)
	for i in 240:
		if i % 25 == 0:
			_press(KEY_W)
		elif i % 25 == 3:
			_release(KEY_W)
		await get_tree().physics_frame
	_release(KEY_D)
	_release(KEY_W)
	_check(crew.position.x > sub.room_rect(2).position.x + 20.0,
		"crew hops the door steps into the helm room")

	# Onto the tower ladder column (middle room -> tower, parity section s1) and
	# climb up.
	var ladder_x := _tower_ladder_x(sub)
	crew.position.x = ladder_x
	crew.velocity = Vector2.ZERO
	await _frames(5)
	var floor_y := crew.position.y

	_press(KEY_W)
	await _frames(90)
	_release(KEY_W)
	_check(crew.position.y < floor_y - Sub.CELL_H * 0.5, "crew climbed up the ladder")

	# Climb back down to the floor.
	_press(KEY_S)
	await _frames(120)
	_release(KEY_S)
	await _frames(60)
	_check(crew.is_on_floor(), "crew climbed back down to the floor")

	sub.queue_free()
	await _frames(2)

func _test_crew_collision() -> void:
	print("[crew collide]")
	var sub := _new_sub()
	# A (P1) to the left of a stationary B (P2); A runs right into B.
	var a := Crew.new()
	a.player_index = 0
	a.position = Vector2(-250, -60)  # engine room (x in [-270, -90]), left side
	sub.add_child(a)
	var b := Crew.new()
	b.player_index = 1
	b.position = Vector2(-170, -60)  # engine room, to A's right
	sub.add_child(b)

	await _frames(60)  # let both settle on the floor
	var b_x := b.position.x

	_press(KEY_D)
	await _frames(90)  # long enough to overtake B if there were no collision
	_release(KEY_D)
	_check(a.position.x > -250.0, "crew A actually moved right")
	_check(a.position.x < b_x - 25.0, "crew A is blocked by crew B (can't pass through)")

	sub.queue_free()
	await _frames(2)

func _test_hatch() -> void:
	print("[conning hatch]")
	# Let any prior sub-test's queued-free sub + crew fully clear the physics
	# space first, so a lingering crew body can't block this one's descent.
	await _frames(10)
	var sub := _new_sub()
	var crew := Crew.new()
	crew.player_index = 0
	# Drop onto the hatch deck over the tower's ladder opening (tower floor at
	# y = -144; drop in from above so it lands on the hatch, not through it).
	var ladder_x := _tower_ladder_x(sub)
	crew.position = Vector2(ladder_x, -200)
	sub.add_child(crew)

	await _frames(60)
	_check(crew.is_on_floor() and crew.position.y < -120.0,
		"crew stands on the conning hatch (does not auto-fall through)")
	var deck_y := crew.position.y

	# No input for a moment: still standing, hasn't fallen.
	await _frames(30)
	_check(absf(crew.position.y - deck_y) < 10.0, "crew stays put on the hatch with no input")

	# Press down: now it drops through the hatch and descends.
	_press(KEY_S)
	await _frames(90)
	_release(KEY_S)
	_check(crew.position.y > deck_y + Sub.CELL_H * 0.5, "pressing down drops through the hatch")

	sub.queue_free()
	await _frames(2)
