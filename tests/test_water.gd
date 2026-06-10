extends Node

## Headless test for the water model core (Milestone 2, Module A).
##
## Run: godot --headless res://tests/test_water.tscn
## Sets per-room water levels directly (no breaches/visuals yet) and ticks
## physics to verify equalization flow direction/speed and the water-as-weight
## effect on the sub's vertical velocity.

var _failures := 0

func _ready() -> void:
	_test_equalization()
	_test_conning_connection()
	_test_weight()

	if _failures == 0:
		print("WATER TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("WATER TESTS FAILED: %d failing check(s)" % _failures)
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

func _test_equalization() -> void:
	print("[equalization]")
	var sub := _new_sub()
	sub.water_levels = [1.0, 0.0, 0.0, 0.0]

	await _frames(2)
	_check(sub.water_levels[0] < 1.0, "flooded engine room loses water on the first tick")
	_check(sub.water_levels[1] > 0.0, "middle room (connected) gains water")
	_check(sub.water_levels[2] == 0.0, "helm room (not directly connected) unaffected on first tick")

	await _frames(600)  # ~10s at 60fps
	var spread := absf(sub.water_levels[0] - sub.water_levels[1])
	_check(spread < 0.1, "engine and middle rooms equalize within ~10s")
	_check(sub.water_levels[2] > 0.05, "helm room eventually receives water via the middle room")

	sub.queue_free()
	await _frames(2)

func _test_conning_connection() -> void:
	print("[conning connection]")
	var sub := _new_sub()
	sub.water_levels = [0.0, 1.0, 0.0, 0.0]

	await _frames(2)
	_check(sub.water_levels[3] > 0.0, "conning area gains water from the flooded middle room")

	# Conning area has a smaller volume, so it should fill faster (higher level)
	# than the larger middle room loses, per-tick, before they converge.
	_check(sub.room_volume(3) < sub.room_volume(1), "conning area volume is smaller than a main room")

	sub.queue_free()
	await _frames(2)

func _test_weight() -> void:
	print("[water weight]")
	var dry := _new_sub()
	var flooded := _new_sub()
	flooded.water_levels = [1.0, 1.0, 1.0, 1.0]

	await _frames(5)
	_check(flooded.velocity.y > dry.velocity.y, "fully flooded sub sinks faster than a dry one")
	_check(flooded.velocity.y > 0.0, "fully flooded sub gains downward velocity from water weight")

	dry.queue_free()
	flooded.queue_free()
	await _frames(2)
