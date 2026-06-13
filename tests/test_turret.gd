extends Node

## Headless test for the turret station + torpedoes (Milestone 2, Module G).
##
## Run: godot --headless res://tests/test_turret.tscn
## A crew takes the gunner seat (middle room), aims with the move vector
## (clamped to the forward cone), and fires with `use`: cooldown gates the
## rate, torpedoes fly straight and slow, and a terrain hit despawns them
## with a puff. Flooding the middle room ejects the gunner (Station base).

var _failures := 0
var _hub: Node

func _ready() -> void:
	_hub = get_node("/root/InputHub")
	await _test_seat_and_aim()
	await _test_fire_and_despawn()

	if _failures == 0:
		print("TURRET TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("TURRET TESTS FAILED: %d failing check(s)" % _failures)
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

func _find_turret(sub: Sub) -> TurretStation:
	for child in sub.get_children():
		if child is TurretStation:
			return child
	return null

func _count_torpedoes() -> int:
	var n := 0
	for child in get_children():
		if child is Torpedo:
			n += 1
	return n

func _test_seat_and_aim() -> void:
	print("[seat + cone clamping]")
	var sub := Sub.new()
	add_child(sub)
	var gunner := Crew.new()
	gunner.player_index = 0
	gunner.position = sub.turret_seat_local()
	sub.add_child(gunner)
	await _frames(10)

	var turret := _find_turret(sub)
	_check(turret != null, "sub built a turret station")
	_check(turret.room_index == 1, "gunner seat is in the middle flex room")

	# Sit down (E) — same enter/exit flow as the helm.
	_press(KEY_E)
	await _frames(2)
	_release(KEY_E)
	await _frames(2)
	_check(turret.occupant == gunner, "pressing E seats the gunner")

	var cone := deg_to_rad(GameFeel.turret.cone_half_angle_deg)

	# Continuous aim: holding S sweeps the barrel down and it clamps to +cone.
	_press(KEY_S)
	await _frames(120)  # 2s at 75 deg/s = 150 deg, well past the 60 deg edge
	_release(KEY_S)
	_check(absf(turret.aim_angle - cone) < 0.05,
		"holding S sweeps the barrel down to the +60 cone edge")

	# Released, the barrel holds its angle (no recenter).
	var held := turret.aim_angle
	await _frames(30)
	_check(absf(turret.aim_angle - held) < 0.001, "barrel holds its angle with no input")

	# Holding W sweeps up and clamps to -cone.
	_press(KEY_W)
	await _frames(120)
	_release(KEY_W)
	_check(absf(turret.aim_angle - (-cone)) < 0.05,
		"holding W sweeps up to the -60 cone edge")

	# Nudge to a mid angle, then confirm A/D (move.x) do NOT move the barrel —
	# the bow tube is on a vertical wall, aimed only by W/S.
	_press(KEY_S)
	await _frames(20)
	_release(KEY_S)
	var mid := turret.aim_angle
	_check(mid > -cone + 0.05 and mid < cone - 0.05, "barrel parked mid-cone for the A/D check")
	_press(KEY_D)
	await _frames(20)
	_release(KEY_D)
	_check(absf(turret.aim_angle - mid) < 0.001, "A/D do not move the barrel (vertical-wall gun)")

	# Leave the seat.
	_press(KEY_E)
	await _frames(2)
	_release(KEY_E)
	await _frames(2)
	_check(turret.occupant == null, "pressing E again frees the seat")

	sub.queue_free()
	await _frames(2)

func _test_fire_and_despawn() -> void:
	print("[fire + cooldown + terrain despawn]")
	var sub := Sub.new()
	add_child(sub)
	var gunner := Crew.new()
	gunner.player_index = 0
	gunner.position = sub.turret_seat_local()
	sub.add_child(gunner)

	# A terrain wall ahead of the bow for torpedoes to hit.
	var wall := StaticBody2D.new()
	wall.collision_layer = Layers.TERRAIN
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, 4000)
	shape.shape = rect
	wall.position = Vector2(1800, 0)
	wall.add_child(shape)
	add_child(wall)

	await _frames(10)
	var turret := _find_turret(sub)

	_press(KEY_E)
	await _frames(2)
	_release(KEY_E)
	await _frames(2)

	# Hold fire for ~1.5s: with the 1.0s cooldown that's exactly 2 shots
	# (t=0 and t=1.0), with margin before a third at t=2.0.
	_press(KEY_Q)
	await _frames(90)
	_release(KEY_Q)
	var fired := _count_torpedoes()
	_check(fired == 2, "holding use for 1.5s fires exactly 2 torpedoes (1.0s cooldown), got %d" % fired)

	var torpedo: Torpedo = null
	for child in get_children():
		if child is Torpedo:
			torpedo = child
	if torpedo != null:
		var speed_mps := torpedo.velocity.length() / GameFeel.PIXELS_PER_METER
		_check(absf(speed_mps - GameFeel.turret.torpedo_speed) < 0.1,
			"torpedo travels at the configured slow speed")
		_check(torpedo.velocity.x > 0.0, "torpedo flies forward off the bow")

	# Wall is ~1400 px from the tube; at 480 px/s that's ~3s of flight.
	await _frames(240)
	_check(_count_torpedoes() == 0, "torpedoes despawn after hitting the terrain wall")

	sub.queue_free()
	wall.queue_free()
	await _frames(2)
