extends Node

## Headless test for the water model core (Milestone 2, Module A).
##
## Run: godot --headless res://tests/test_water.tscn
## Sets per-room water levels directly (no breaches/visuals yet) and ticks
## physics to verify equalization flow direction/speed and the water-as-weight
## effect on the sub's vertical velocity.

var _failures := 0

func _ready() -> void:
	# This suite tests pure equalization/weight; rooms with no breaches
	# auto-drain (Module D), which would empty them mid-test, so turn it off.
	GameFeel.water.drain_rate = 0.0
	_test_equalization()
	_test_conning_connection()
	_test_weight()
	_test_door_sill()

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
	# Room indices: 0=claw_room, 1=helm, 2=bullet_room, 3=tower.
	# claw_room(0) and helm(1) are adjacent via a door.
	sub.water_levels = [1.0, 0.0, 0.0, 0.0]

	await _frames(2)
	_check(sub.water_levels[0] < 1.0, "flooded claw_room loses water on the first tick")
	_check(sub.water_levels[1] > 0.0, "helm (connected via door) gains water")
	_check(sub.water_levels[2] == 0.0, "bullet_room (not directly connected to claw) unaffected on first tick")

	await _frames(600)  # ~10s at 60fps
	var spread := absf(sub.water_levels[0] - sub.water_levels[1])
	_check(spread < 0.1, "claw_room and helm equalize within ~10s")
	_check(sub.water_levels[2] > 0.05, "bullet_room eventually receives water via the helm")

	sub.queue_free()
	await _frames(2)

func _test_conning_connection() -> void:
	print("[conning connection]")
	var sub := _new_sub()
	# Room indices: 0=claw_room, 1=helm, 2=bullet_room, 3=tower.
	# Helm(1) connects to tower(3) via ladder — flood helm and confirm tower gets wet.
	sub.water_levels = [0.0, 1.0, 0.0, 0.0]

	await _frames(2)
	_check(sub.water_levels[3] > 0.0, "tower gains water from the flooded helm via the ladder")

	sub.queue_free()
	await _frames(2)

func _test_door_sill() -> void:
	print("[door sill / overflow]")
	var sill: float = GameFeel.water.door_sill_m / GameFeel.water.room_height_m

	# A puddle below the sill pools in its room and does NOT leak to a neighbour.
	var sub := _new_sub()
	sub.water_levels = [sill * 0.5, 0.0, 0.0, 0.0]  # claw_room, below knee height
	await _frames(120)
	_check(sub.water_levels[1] < 0.001,
		"water below the door sill stays pooled (no leak to the middle room)")
	_check(sub.water_levels[0] > sill * 0.4,
		"the pooled water is still there in the breached room")
	sub.queue_free()
	await _frames(2)

	# Above the sill, it spills over into the neighbour.
	var sub2 := _new_sub()
	sub2.water_levels = [sill + 0.3, 0.0, 0.0, 0.0]
	await _frames(120)
	_check(sub2.water_levels[1] > 0.01,
		"water above the door sill spills into the adjacent room")
	sub2.queue_free()
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
