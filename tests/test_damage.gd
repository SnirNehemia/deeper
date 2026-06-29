extends Node

## Headless test for collision breaches (Milestone 2, Module C).
##
## Run: godot --headless res://tests/test_damage.tscn
## Simulated impacts at several speeds: below the threshold is always free, and
## above it the leak rate grows with impact speed. Breaches feed water into the
## per-room model, and spawn_breach lands in the right room.

var _failures := 0

func _ready() -> void:
	await _test_impact_threshold()
	await _test_leak_rate_scaling()
	await _test_breach_floods_room()
	await _test_real_collision()

	if _failures == 0:
		print("DAMAGE TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("DAMAGE TESTS FAILED: %d failing check(s)" % _failures)
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

func _test_impact_threshold() -> void:
	print("[impact threshold]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)

	var hit := sub.register_impact(1.0, sub.global_position)
	_check(not hit, "1 m/s bump is free (no breach)")
	_check(sub.breaches.is_empty(), "no breach recorded after a gentle bump")

	hit = sub.register_impact(1.9, sub.global_position)
	_check(not hit, "1.9 m/s bump is still free (just under threshold)")

	hit = sub.register_impact(3.0, sub.global_position)
	_check(hit, "3 m/s impact breaches the hull")
	_check(sub.breaches.size() == 1, "exactly one breach recorded")

	sub.queue_free()
	await _frames(2)

func _test_leak_rate_scaling() -> void:
	print("[leak rate scaling]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)

	sub.register_impact(2.5, sub.global_position)
	sub.register_impact(4.0, sub.global_position)
	sub.register_impact(6.0, sub.global_position)
	_check(sub.breaches.size() == 3, "three impacts made three breaches")

	var soft: Breach = sub.breaches[0]
	var mid: Breach = sub.breaches[1]
	var hard: Breach = sub.breaches[2]
	_check(soft.leak_rate < mid.leak_rate and mid.leak_rate < hard.leak_rate,
		"leak rate grows with impact speed")
	# Each tier reads as a distinct colour + size (playtest #3).
	_check(soft._tier_color() != mid._tier_color()
		and mid._tier_color() != hard._tier_color(),
		"small/medium/big breaches are different colours")
	_check(soft._tier_scale() < mid._tier_scale()
		and mid._tier_scale() < hard._tier_scale(),
		"small/medium/big breaches are different sizes")
	var r_soft: float = soft.leak_rate
	var r_hard: float = hard.leak_rate
	var b: GameFeel.BreachFeel = GameFeel.breach
	# M5: rate = severity_to_inflow(speed - breach_speed_threshold).
	_check(absf(r_soft - b.severity_to_inflow(2.5 - GameFeel.water.breach_speed_threshold)) < 0.0001,
		"soft impact rate matches severity-to-inflow mapping")
	_check(absf(r_hard - b.severity_to_inflow(6.0 - GameFeel.water.breach_speed_threshold)) < 0.0001,
		"hard impact rate matches severity-to-inflow mapping")
	_check(r_hard <= b.inflow_at_max + 0.0001,
		"hardest breach stays within the inflow range")

	sub.queue_free()
	await _frames(2)

func _test_breach_floods_room() -> void:
	print("[breach floods its room]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)

	# Drip into the helm room (index 2) at the worst rate; nothing else flooded.
	var helm_center := sub.room_rect(2).get_center()
	var breach: Breach = sub.spawn_breach(2, GameFeel.water.leak_rate_max,
		helm_center)
	_check(breach.room == 2, "spawn_breach lands in the requested room")
	_check(sub.room_index_at(breach.position) == 2, "breach marker sits inside the helm room")

	await _frames(120)  # ~2s at the ~20s-to-full rate
	_check(sub.water_levels[2] > 0.05, "breached helm room takes on water over time")
	_check(sub.water_levels[2] > sub.water_levels[0],
		"breached room is wetter than a distant dry room")

	sub.queue_free()
	await _frames(2)

func _test_real_collision() -> void:
	print("[real terrain collision]")
	# A wall of TERRAIN to starboard; drive the sub into it at ramming speed.
	var wall := StaticBody2D.new()
	wall.collision_layer = Layers.TERRAIN
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(100, 2000)
	shape.shape = rect
	wall.position = Vector2(900, 0)
	wall.add_child(shape)
	add_child(wall)

	var sub := Sub.new()
	add_child(sub)
	await _frames(2)
	# Launch at ramming speed straight at the wall (past the breach threshold).
	sub.velocity = Vector2(6.0 * Sub.PPM, 0)
	sub.drive_input = Vector2.RIGHT

	for i in 120:
		await get_tree().physics_frame
		if not sub.breaches.is_empty():
			break
	_check(not sub.breaches.is_empty(), "ramming a terrain wall opens a breach")
	if not sub.breaches.is_empty():
		## MILESTONE_11.md: floodlight_room (leftmost) shifted every later
		## room's water index by +1 -- bullet_room (the actual bow/rightmost
		## room a rightward ram hits) is now index 3, was 2.
		_check(sub.breaches[0].room == 3,
			"bow-first ram breaches the bullet_room (bow) room")

	sub.queue_free()
	wall.queue_free()
	await _frames(2)
