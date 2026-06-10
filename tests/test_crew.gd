extends Node

## Headless test for crew feel + movement (Step 2).
##
## Run: godot --headless res://tests/test_crew.tscn
## Two parts: deterministic checks on the GameFeel math, then a physics
## integration test that drops a real Crew onto a floor and drives it through
## the live InputHub (fall+land, jump, reach max run speed).

var _failures := 0

func _ready() -> void:
	_test_feel_math()
	await _test_physics()

	if _failures == 0:
		print("CREW TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("CREW TESTS FAILED: %d failing check(s)" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok:   ", msg)
	else:
		push_error("  FAIL: " + msg)
		_failures += 1

func _approx(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol

func _keydown(keycode: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = keycode
	e.pressed = true
	return e

func _keyup(keycode: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = keycode
	e.pressed = false
	return e

func _test_feel_math() -> void:
	print("[feel math]")
	var f := GameFeel.weighty()
	_check(_approx(f.run_accel(), 30.0, 0.01), "weighty run_accel = 4.5/0.15 = 30")
	_check(_approx(f.run_decel(), 45.0, 0.01), "weighty run_decel = 4.5/0.10 = 45")
	# gravity = 2h/t^2, jump_velocity = 2h/t for h=1.3, t=0.38
	_check(_approx(f.gravity(), 2.0 * 1.3 / (0.38 * 0.38), 0.001), "gravity matches apex formula")
	_check(_approx(f.jump_velocity(), 2.0 * 1.3 / 0.38, 0.001), "jump_velocity matches apex formula")
	var s := GameFeel.snappy()
	_check(s.run_accel() > f.run_accel(), "snappy accelerates faster than weighty")

func _test_physics() -> void:
	print("[physics]")
	var hub: Node = get_node("/root/InputHub")

	# Floor with its top surface at y = 200.
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = Layers.INTERIOR
	floor_body.collision_mask = 0
	floor_body.position = Vector2(0, 260)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2000, 120)
	col.shape = shape
	floor_body.add_child(col)
	add_child(floor_body)

	# Crew (P1) spawned in the air above the floor.
	var crew := Crew.new()
	crew.player_index = 0
	crew.position = Vector2(0, 0)
	add_child(crew)

	# Fall and land.
	for i in 120:
		await get_tree().physics_frame
	_check(crew.is_on_floor(), "crew falls and lands on the floor")
	var rest_y := crew.position.y

	# Jump (press W through the live hub; it polls before crew each frame).
	hub._input(_keydown(KEY_W))
	for i in 6:
		await get_tree().physics_frame
	_check(crew.position.y < rest_y - 20.0, "crew jumps upward when P1 W pressed")
	hub._input(_keyup(KEY_W))

	# Let it settle back down.
	for i in 90:
		await get_tree().physics_frame
	_check(crew.is_on_floor(), "crew lands again after the jump")

	# Run right: hold D long enough to reach top speed.
	hub._input(_keydown(KEY_D))
	for i in 25:
		await get_tree().physics_frame
	var target := GameFeel.crew.run_max_speed * GameFeel.PIXELS_PER_METER
	_check(_approx(crew.velocity.x, target, target * 0.1), "crew reaches ~max run speed holding D")
	hub._input(_keyup(KEY_D))

	# Release: decelerate back toward a stop.
	for i in 20:
		await get_tree().physics_frame
	_check(absf(crew.velocity.x) < target * 0.1, "crew stops after releasing D")
