extends Node

## Headless test for the helm + sub driving (Step 4).
##
## Run: godot --headless res://tests/test_helm.tscn
## A crew walks to the helm, sits, drives the sub through the live InputHub, and
## we verify: seating, heavy spin-up toward max speed, coast-to-stop, vertical
## drive, a free crew riding along inside, and leaving the seat.

var _failures := 0
var _hub: Node

func _ready() -> void:
	_hub = get_node("/root/InputHub")
	await _run()
	if _failures == 0:
		print("HELM TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("HELM TESTS FAILED: %d failing check(s)" % _failures)
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

func _run() -> void:
	print("[helm]")
	var sub := Sub.new()
	add_child(sub)

	# Driver (P1) placed right at the helm seat.
	var driver := Crew.new()
	driver.player_index = 0
	driver.position = Vector2(Sub.HELM_X, Sub.HELM_SEAT_Y)
	sub.add_child(driver)

	# A free crew (P2) standing in the middle room — should ride along untouched.
	var rider := Crew.new()
	rider.player_index = 1
	rider.position = Vector2(40, -60)
	sub.add_child(rider)

	await _frames(10)  # let the station sensor register the overlap

	var helm: HelmStation = null
	for child in sub.get_children():
		if child is HelmStation:
			helm = child
	_check(helm != null, "sub built a helm station")

	# Sit down (E).
	_press(KEY_E)
	await _frames(2)
	_release(KEY_E)
	await _frames(2)
	_check(helm.occupant == driver, "pressing E seats the crew at the helm")

	# Let the rider fully settle before measuring ride-along.
	await _frames(60)
	# Drive right: heavy spin-up.
	var rider_local := rider.position
	var start_x := sub.global_position.x
	_press(KEY_D)
	await _frames(30)
	var v_early := sub.velocity.x
	await _frames(120)
	var v_late := sub.velocity.x
	_check(v_early > 0.0 and v_late > v_early, "sub spins up gradually (heavy)")
	_check(sub.global_position.x > start_x + 100.0, "sub actually moved right")
	var max_h := GameFeel.sub.max_speed_h * GameFeel.PIXELS_PER_METER
	_check(v_late < max_h + 1.0, "sub never exceeds its max horizontal speed")

	# Pitch: the sub leans, and the crew ART leans with it (physics stays upright).
	_check(absf(sub.pitch) > 0.01, "sub pitches while driving")
	_check(absf(driver._visual.rotation - sub.pitch) < 0.001, "driver art tilts to match the sub")
	_check(absf(rider._visual.rotation - sub.pitch) < 0.001, "rider art tilts to match the sub")
	_check(absf(driver.rotation) < 0.001, "driver physics body stays upright")

	# The free rider stayed put inside the sub (rode along, no sliding).
	_check(rider.position.distance_to(rider_local) < 8.0, "free crew rides along inside the sub")
	_check(driver.global_position.distance_to(helm.seat_global_position()) < 2.0,
		"driver stays locked in the moving seat")

	# Release: coast to a stop.
	_release(KEY_D)
	await _frames(160)
	_check(absf(sub.velocity.x) < max_h * 0.1, "sub coasts to a near stop")

	# Drive down: vertical control.
	_press(KEY_S)
	await _frames(60)
	_check(sub.velocity.y > 0.0, "sub dives when steering down")
	_release(KEY_S)

	# Leave the seat (E again): drive input clears and it coasts.
	_press(KEY_E)
	await _frames(2)
	_release(KEY_E)
	await _frames(2)
	_check(helm.occupant == null, "pressing E again leaves the helm")
	_check(sub.drive_input == Vector2.ZERO, "leaving the helm zeroes the drive input")
