extends Node

## Headless test for drowning & respawn (Milestone 2, Module E).
##
## Run: godot --headless res://tests/test_drowning.tscn
## A crew in a fully flooded room runs out of air and drowns; a second crew in
## a dry room is untouched. The dead crew respawns standing in the helm room
## after the respawn delay, with full air. Surfacing refills air quickly.

var _failures := 0

func _ready() -> void:
	# Keep the flooded room flooded for the whole test (no breach, so the
	# auto-drain would otherwise empty it under the crew).
	GameFeel.water.drain_rate = 0.0
	await _test_drown_and_respawn()
	await _test_air_refill()

	if _failures == 0:
		print("DROWNING TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("DROWNING TESTS FAILED: %d failing check(s)" % _failures)
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

func _seconds(s: float) -> void:
	await _frames(int(ceil(s * 60.0)))

func _test_drown_and_respawn() -> void:
	print("[drown + respawn]")
	# Shorten the timers so the test stays fast; ratios preserved.
	GameFeel.water.air_time = 1.0
	GameFeel.water.respawn_delay = 1.0

	var sub := Sub.new()
	add_child(sub)
	# Flood only the engine room: the victim drowns there, but the helm room
	# (the respawn point) stays dry long enough to verify full-air respawn —
	# water creeps toward it only slowly over two door sills.
	sub.water_levels = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

	var victim := Crew.new()
	victim.player_index = 0
	victim.position = Vector2(-SubGrid.CELL_W_PX, -60)  # engine room — fully underwater
	sub.add_child(victim)

	var buddy := Crew.new()
	buddy.player_index = 1
	buddy.position = Vector2(sub.helm_seat_local().x, -60)  # helm room — dry
	sub.add_child(buddy)

	await _frames(10)
	_check(victim.is_head_submerged(), "victim's head is underwater in the flooded room")
	_check(not buddy.is_head_submerged(), "buddy in the dry room is fine")
	_check(victim.air_seconds < GameFeel.water.air_time, "victim's air is draining")

	# Wait out the air, plus margin: the victim drowns.
	await _seconds(1.4)
	_check(victim.is_dead, "victim drowns when the air runs out")
	_check(not buddy.is_dead, "buddy is untouched by the victim's drowning")
	_check(not victim._visual.visible, "drowned body is gone (cartoon pop)")

	# Wait out the respawn delay: back in the helm room, alive, full air.
	await _seconds(1.4)
	_check(not victim.is_dead, "victim respawns after the delay")
	_check(victim._visual.visible, "respawned crew is visible again")
	_check(sub.room_index_at(victim.position) == 3, "respawn lands in the conning tower")
	_check(victim.air_seconds >= GameFeel.water.air_time - 0.1, "respawn restores full air")
	_check(not buddy.is_dead, "buddy still fine after the respawn")

	sub.queue_free()
	await _frames(2)

func _test_air_refill() -> void:
	print("[air refill on surfacing]")
	GameFeel.water.air_time = 10.0  # restore canon values

	var sub := Sub.new()
	add_child(sub)
	sub.water_levels = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

	var crew := Crew.new()
	crew.player_index = 0
	crew.position = Vector2(-240, -60)  # flooded engine room
	sub.add_child(crew)

	await _seconds(2.0)  # hold breath for ~2s
	var drained: float = crew.air_seconds
	_check(drained < 9.0, "air drained while submerged")

	# Drain the room instantly: the crew surfaces and refills fast.
	sub.water_levels = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	await _seconds(2.5)  # refill takes ~2s for the full bar
	_check(crew.air_seconds >= GameFeel.water.air_time - 0.1,
		"air refills quickly once surfaced")

	sub.queue_free()
	await _frames(2)
