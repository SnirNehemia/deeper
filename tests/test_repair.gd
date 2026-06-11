extends Node

## Headless test for repair + auto-drain (Milestone 2, Module D).
##
## Run: godot --headless res://tests/test_repair.tscn
## A crew stands at a breach and holds `use` (Q for P1): progress fills over
## ~3s, releasing resets it with no partial credit, completing removes the
## breach, and a breach-free room auto-drains.

var _failures := 0
var _hub: Node

func _ready() -> void:
	_hub = get_node("/root/InputHub")
	await _test_hold_release_hold()
	await _test_auto_drain()

	if _failures == 0:
		print("REPAIR TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("REPAIR TESTS FAILED: %d failing check(s)" % _failures)
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

func _test_hold_release_hold() -> void:
	print("[hold / release / hold]")
	var sub := Sub.new()
	add_child(sub)
	var crew := Crew.new()
	crew.player_index = 0
	crew.position = Vector2(-240, -60)  # engine room floor
	sub.add_child(crew)
	await _frames(30)  # settle on the floor

	# Breach right where the crew stands (drip-tier so the room stays dry).
	var breach: Breach = sub.spawn_breach(0, GameFeel.water.leak_rate_min,
		crew.position)
	await _frames(2)

	# Hold `use` for half the repair time: progress grows but isn't done.
	_press(KEY_Q)
	await _frames(90)  # 1.5s of the 3s repair
	_check(breach.repair_progress > 0.3, "holding use fills repair progress")
	_check(is_instance_valid(breach) and not sub.breaches.is_empty(),
		"half a hold does not patch the breach")

	# Release: progress resets to zero (no partial credit).
	_release(KEY_Q)
	await _frames(5)
	_check(breach.repair_progress == 0.0, "releasing use resets progress to zero")

	# Hold to completion: breach removed.
	_press(KEY_Q)
	await _frames(200)  # > 3s
	_release(KEY_Q)
	_check(sub.breaches.is_empty(), "a full 3s hold patches the breach")
	_check(not is_instance_valid(breach) or breach.is_queued_for_deletion(),
		"patched breach node is removed")

	sub.queue_free()
	await _frames(2)

func _test_auto_drain() -> void:
	print("[auto-drain]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)

	# Flood the engine room with no breaches anywhere: it should drain.
	sub.water_levels[0] = 0.5
	await _frames(60)  # ~1s at the ~12s-to-empty rate
	_check(sub.water_levels[0] < 0.5, "breach-free room drains on its own")

	var mid_level: float = sub.water_levels[0]
	await _frames(600)  # ~10s more
	_check(sub.water_levels[0] < mid_level, "drain keeps going")
	var total := 0.0
	for i in Sub.ROOM_COUNT:
		total += sub.water_levels[i]
	_check(total < 0.05, "the water is essentially gone within ~12s")

	# A breached room does NOT drain (others do). Flood every room evenly so
	# equalization is neutral and only the drain/leak difference shows.
	sub.water_levels = [0.5, 0.5, 0.5, 0.5]
	sub.spawn_breach(1, GameFeel.water.leak_rate_min)
	await _frames(60)
	_check(sub.water_levels[1] > sub.water_levels[0] + 0.02,
		"a breached room stays wet while breach-free rooms drain")

	sub.queue_free()
	await _frames(2)
