extends Node

## Headless test for water rendering reaction (Milestone 2, Module B):
## flooded stations eject their occupant and refuse entry, and crew swim
## (dampened) while submerged above the waist.
##
## Run: godot --headless res://tests/test_station_flood.tscn

var _failures := 0
var _hub: Node

func _ready() -> void:
	_hub = get_node("/root/InputHub")
	await _test_flooded_helm_ejects()
	await _test_swim_dampening()
	await _test_feet_vs_waist()

	if _failures == 0:
		print("STATION FLOOD TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("STATION FLOOD TESTS FAILED: %d failing check(s)" % _failures)
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

func _test_flooded_helm_ejects() -> void:
	print("[flooded helm ejects]")
	var sub := Sub.new()
	add_child(sub)

	var driver := Crew.new()
	driver.player_index = 0
	driver.position = Vector2(Sub.HELM_X, Sub.HELM_SEAT_Y)
	sub.add_child(driver)

	await _frames(10)

	var helm: HelmStation = null
	for child in sub.get_children():
		if child is HelmStation:
			helm = child
	_check(helm != null, "sub built a helm station")

	# Sit down.
	_press(KEY_E)
	await _frames(2)
	_release(KEY_E)
	await _frames(2)
	_check(helm.occupant == driver, "pressing E seats the crew at the helm")

	# Flood the helm room (room index 2) past the seat-flood threshold.
	sub.water_levels[2] = GameFeel.water.seat_flood_threshold + 0.1
	await _frames(2)
	_check(helm.occupant == null, "occupant ejected once the helm room floods")
	_check(not helm.can_enter(), "flooded helm refuses entry")

	# Drain it back below the threshold.
	sub.water_levels[2] = 0.0
	await _frames(1)
	_check(helm.can_enter(), "drained helm accepts entry again")

	sub.queue_free()
	await _frames(2)

func _test_swim_dampening() -> void:
	print("[swim dampening]")
	var dry_sub := Sub.new()
	add_child(dry_sub)
	var dry_crew := Crew.new()
	dry_crew.player_index = 0
	dry_crew.position = Vector2(-Sub.HALF_W + Sub.ROOM_W * 0.5, -60)  # engine room
	dry_sub.add_child(dry_crew)

	var wet_sub := Sub.new()
	wet_sub.position = Vector2(5000, 0)  # far from the dry sub so nothing overlaps
	add_child(wet_sub)
	wet_sub.water_levels[0] = 1.0  # fully flood the engine room
	var wet_crew := Crew.new()
	wet_crew.player_index = 1
	wet_crew.position = Vector2(-Sub.HALF_W + Sub.ROOM_W * 0.5, -60)
	wet_sub.add_child(wet_crew)

	await _frames(5)
	_check(wet_crew.is_submerged(), "crew standing in a fully flooded room is submerged")
	_check(not dry_crew.is_submerged(), "crew standing in a dry room is not submerged")

	_press(KEY_D)
	_press(KEY_RIGHT)
	await _frames(20)
	_release(KEY_D)
	_release(KEY_RIGHT)

	_check(absf(wet_crew.velocity.x) < absf(dry_crew.velocity.x),
		"submerged crew accelerates slower than a dry crew")

	dry_sub.queue_free()
	wet_sub.queue_free()
	await _frames(2)

func _test_feet_vs_waist() -> void:
	print("[feet-touch vs waist]")
	# A shallow puddle: deep enough to wet the feet, too shallow to reach the
	# waist. Movement is slowed, but the jump is NOT (playtest #4).
	GameFeel.water.drain_rate = 0.0  # keep the puddle from draining mid-test
	var sub := Sub.new()
	add_child(sub)
	sub.water_levels[0] = 0.1  # ~0.3 m in a 3 m room — ankle-deep
	var crew := Crew.new()
	crew.player_index = 0
	crew.position = Vector2(-Sub.HALF_W + Sub.ROOM_W * 0.5, -60)  # engine room
	sub.add_child(crew)

	await _frames(20)  # settle onto the floor, into the puddle
	_check(crew.is_touching_water(), "feet are in the shallow puddle")
	_check(not crew.is_submerged(), "but the waist is above the shallow puddle")

	sub.queue_free()
	await _frames(2)
	GameFeel.water.drain_rate = 1.0 / 12.0  # restore for any later runs
