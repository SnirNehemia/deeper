extends Node

## Headless test for implosion & reset (Milestone 2, Module F).
##
## Run: godot --headless res://tests/test_implosion.tscn
## Loads the real world scene, forces water past the implosion threshold, and
## asserts the full reset: sub back at the dock (dry, breach-free, stopped),
## both crew alive aboard, depth ~0.

var _failures := 0

func _ready() -> void:
	await _test_implosion_reset()

	if _failures == 0:
		print("IMPLOSION TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("IMPLOSION TESTS FAILED: %d failing check(s)" % _failures)
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

func _test_implosion_reset() -> void:
	print("[implosion -> reset]")
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await _frames(10)

	var sub: Sub = world._sub
	_check(sub != null, "world built its sub")

	# Drive away from the dock and breach everything: drag the sub under.
	sub.global_position += Vector2(40.0 * 48.0, 30.0 * 48.0)
	sub.spawn_breach(0, GameFeel.water.leak_rate_max)
	sub.water_levels = [0.9, 0.9, 0.9, 0.0, 0.9, 0.9, 0.9]  # just over the 70% total threshold
	var pre_reset_x := sub.global_position.x

	await _frames(5)
	_check(world._resetting, "crossing the water threshold starts the implosion sequence")

	# The sequence runs ~1.5s of crunch + fade + the reset + fade-in.
	await _frames(200)
	_check(not world._resetting, "implosion sequence finishes")
	_check(sub.global_position.distance_to(world.SUB_SPAWN) < 10.0,
		"sub is back at the dock spawn")
	_check(absf(sub.global_position.x - pre_reset_x) > 100.0,
		"the reset actually moved the sub (it wasn't at the dock already)")
	_check(sub.total_fill_fraction() < 0.01, "water is cleared")
	_check(sub.breaches.is_empty(), "breaches are cleared")
	_check(sub.velocity.length() < 5.0, "sub is at a dead stop")
	_check(sub.depth_m() < 1.0, "depth meter reads ~0 at the surface")

	var p1: Crew = world._crew[0]
	var p2: Crew = world._crew[1]
	_check(not p1.is_dead and not p2.is_dead, "both crew are alive")
	_check(sub.room_index_at(p1.position) >= 0 and sub.room_index_at(p2.position) >= 0,
		"both crew stand inside the sub")
	_check(p1.air_seconds >= GameFeel.water.air_time - 0.1, "crew air is full again")

	# The run can implode again on a later flood (guard flag re-arms).
	sub.water_levels = [0.9, 0.9, 0.9, 0.0, 0.9, 0.9, 0.9]
	await _frames(5)
	_check(world._resetting, "a second flood can implode the sub again")
	await _frames(200)
	_check(not world._resetting, "second reset completes")

	world.queue_free()
	await _frames(2)
