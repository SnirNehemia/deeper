extends Node

## Headless test for territorial fish (Milestone 2, Module H).
##
## Run: godot --headless res://tests/test_fish.tscn
## State machine by distance: patrol at home, chase when the sub enters the
## territory, return when it leaves. Hull contact bites a drip-tier breach
## (with a pause between bites), one torpedo kills, and reset_fish revives.

var _failures := 0

func _ready() -> void:
	await _test_territory_states()
	await _test_bite()
	await _test_torpedo_kill_and_reset()
	await _test_bullet_burst()
	await _test_hunter_chases_and_gives_up()
	await _test_territorial_unaffected_by_hunt_path()
	await _test_chaser_locks_on_and_never_gives_up()

	if _failures == 0:
		print("FISH TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("FISH TESTS FAILED: %d failing check(s)" % _failures)
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

func _ppm() -> float:
	return GameFeel.PIXELS_PER_METER

func _test_territory_states() -> void:
	print("[territory states]")
	var sub := Sub.new()
	sub.position = Vector2(-100.0 * _ppm(), 0)  # far away
	add_child(sub)

	var fish := Fish.new()
	fish.sub = sub
	fish.position = Vector2.ZERO
	add_child(fish)
	await _frames(10)

	_check(fish.state == Fish.State.PATROL, "fish patrols while the sub is far away")
	_check(fish.global_position.distance_to(fish.home)
		< GameFeel.fish.territory_radius_m * _ppm(),
		"patrolling fish stays inside its territory")

	# Sub enters the territory: chase. (Center 9.5 m out: inside the 10 m
	# territory but the ~8.3 m-wide hull doesn't touch the fish yet, so we see
	# pure chasing, not an instant bite.)
	sub.global_position = fish.home + Vector2(9.5 * _ppm(), 0)
	await _frames(5)
	_check(fish.state == Fish.State.CHASE, "fish chases when the sub enters its territory")
	var d0 := fish.global_position.distance_to(sub.global_position)
	await _frames(10)
	var d1 := fish.global_position.distance_to(sub.global_position)
	_check(d1 < d0, "chasing fish closes the distance")

	# Sub leaves: the fish breaks off and swims home. (It may finish a bite's
	# RECOVER circling first, so wait for it to disengage rather than checking a
	# fixed frame.)
	sub.global_position = fish.home + Vector2(40.0 * _ppm(), 0)
	var broke_off := false
	for i in 300:
		await get_tree().physics_frame
		if fish.state == Fish.State.RETURN or fish.state == Fish.State.PATROL:
			broke_off = true
			break
	_check(broke_off, "fish breaks off when the sub leaves the territory")
	var made_it_home := false
	for i in 900:  # up to 15s — plenty at 2 m/s, then it resumes patrolling
		await get_tree().physics_frame
		if fish.state == Fish.State.PATROL:
			made_it_home = true
			break
	_check(made_it_home, "fish swims home and resumes patrolling")

	fish.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_bite() -> void:
	print("[bite]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)

	# Fish right at the hull's bow edge, inside its own territory.
	var fish := Fish.new()
	fish.sub = sub
	# Just off the helm room's bow wall, mid-height (within the hull margin).
	fish.position = Vector2(sub.room_rect(2).end.x + 30.0, -72.0)
	add_child(fish)
	# Poll instead of a blind wait so the knockback check below sees the
	# impulse fresh (it decays back over the next several frames).
	for i in 30:
		await get_tree().physics_frame
		if not sub.breaches.is_empty():
			break

	_check(not sub.breaches.is_empty(), "hull contact produces a bite breach")
	if not sub.breaches.is_empty():
		var breach: Breach = sub.breaches[0]
		var expected_severity: float = fish.enemy_def.class_small.damage
		_check(absf(breach.leak_rate - GameFeel.breach.severity_to_inflow(expected_severity)) < 0.0001,
			"bite breach is drip-tier")
		_check(breach.room == 2, "bow bite breaches the helm (bow) room")
		# MILESTONE_8.md Module 1: the bite also shoves the sub (stern-ward,
		# away from the bow-mounted fish), on top of the breach above.
		_check(sub.velocity.x < 0.0, "bite also shoves the sub away from the fish")
	var bites_after_first: int = sub.breaches.size()
	_check(bites_after_first == 1, "no rapid-fire bites (one per pass)")

	# Within the 3s bite interval there is no second bite even if it touches.
	await _frames(60)  # 1s
	_check(sub.breaches.size() == bites_after_first,
		"bite cooldown holds for the recover pass")

	fish.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_torpedo_kill_and_reset() -> void:
	print("[torpedo kill + reset]")
	var sub := Sub.new()
	sub.position = Vector2(-100.0 * _ppm(), 0)
	add_child(sub)

	var fish := Fish.new()
	fish.sub = sub
	fish.position = Vector2.ZERO
	add_child(fish)
	await _frames(5)

	# A torpedo flying straight at the fish.
	var torpedo := Torpedo.new()
	torpedo.velocity = Vector2.RIGHT * GameFeel.turret.torpedo_speed * _ppm()
	add_child(torpedo)
	torpedo.global_position = fish.global_position + Vector2(-3.0 * _ppm(), 0)

	await _frames(40)  # ~0.7s of flight covers the 3 m
	_check(fish.is_dead, "one torpedo hit kills the fish")
	_check(not fish.visible, "dead fish is gone (pop + bubbles)")
	_check(not is_instance_valid(torpedo) or torpedo.is_queued_for_deletion(),
		"the torpedo is spent on the kill")

	# The run reset brings it back home.
	get_tree().call_group("fish", "reset_fish")
	await _frames(5)
	_check(not fish.is_dead and fish.visible, "reset_fish revives the fish")
	_check(fish.global_position.distance_to(fish.home) < 24.0,
		"revived fish is back at its home point (small patrol drift allowed)")
	_check(fish.state == Fish.State.PATROL, "revived fish goes back to patrolling")

	fish.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_bullet_burst() -> void:
	print("[bullet burst]")
	var sub := Sub.new()
	sub.position = Vector2(-100.0 * _ppm(), 0)
	add_child(sub)

	var fish := Fish.new()
	fish.sub = sub
	fish.position = Vector2.ZERO
	add_child(fish)
	await _frames(5)

	var shots := int(fish.hp_max / GameFeel.bullet.damage)
	for i in shots - 1:
		var bullet := Bullet.new()
		bullet.velocity = Vector2.ZERO
		bullet.global_position = fish.global_position
		add_child(bullet)
		await _frames(2)
		_check(not fish.is_dead, "fish survives bullet %d/%d" % [i + 1, shots])

	_check(fish.hp < fish.hp_max, "fish flinched (lost HP) without dying")

	# The final shot kills it.
	var killer := Bullet.new()
	killer.velocity = Vector2.ZERO
	killer.global_position = fish.global_position
	add_child(killer)
	await _frames(2)
	_check(fish.is_dead, "fish dies on the %dth bullet" % shots)

	get_tree().call_group("fish", "reset_fish")
	await _frames(2)
	fish.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_hunter_chases_and_gives_up() -> void:
	print("[hunter chases past the territorial leash, then gives up]")
	var sub := Sub.new()
	sub.position = Vector2(-100.0 * _ppm(), 0)
	add_child(sub)

	var fish := Fish.new()
	fish.sub = sub
	fish.behavior = Fish.Behavior.HUNTER
	fish.position = Vector2.ZERO
	add_child(fish)
	await _frames(5)

	# Sub well outside the territorial leash (10m) but inside hunter_detect_m (16m).
	sub.global_position = fish.home + Vector2(14.0 * _ppm(), 0)
	await _frames(10)
	_check(fish.state == Fish.State.HUNT, "hunter locks on beyond the territorial leash")

	# Sub runs far away, beyond hunter_lose_m (24m). The hunter keeps chasing
	# for a while (sustained lose-timer), not instantly.
	sub.global_position = fish.home + Vector2(40.0 * _ppm(), 0)
	await _frames(10)
	_check(fish.state == Fish.State.HUNT, "hunter doesn't give up immediately when out of range")

	# After the sustained lose-timer it disengages and heads home. Keep the
	# sub far ahead each frame (outrunning the hunter) so the lose-timer
	# actually accumulates instead of resetting as the fish closes in.
	var gave_up := false
	for i in int(GameFeel.fish.hunter_lose_time * 60.0) + 30:
		sub.global_position = fish.global_position + Vector2(40.0 * _ppm(), 0)
		await get_tree().physics_frame
		if fish.state == Fish.State.RETURN or fish.state == Fish.State.PATROL:
			gave_up = true
			break
	_check(gave_up, "hunter gives up after the sustained out-of-range timer")

	fish.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_territorial_unaffected_by_hunt_path() -> void:
	print("[territorial fish is unaffected by the hunt path]")
	var sub := Sub.new()
	sub.position = Vector2(-100.0 * _ppm(), 0)
	add_child(sub)

	var fish := Fish.new()
	fish.sub = sub
	fish.behavior = Fish.Behavior.TERRITORIAL
	fish.position = Vector2.ZERO
	add_child(fish)
	await _frames(5)

	# Same distance that triggers a hunter (beyond territory, within
	# hunter_detect_m) — a territorial fish should just keep patrolling.
	sub.global_position = fish.home + Vector2(14.0 * _ppm(), 0)
	await _frames(10)
	_check(fish.state == Fish.State.PATROL,
		"territorial fish ignores a sub beyond its territory radius")

	fish.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_chaser_locks_on_and_never_gives_up() -> void:
	print("[basic_chaser locks on and never gives up]")
	var sub := Sub.new()
	sub.position = Vector2(-100.0 * _ppm(), 0)
	add_child(sub)

	var fish := Fish.new()
	fish.sub = sub
	fish.behavior = Fish.Behavior.CHASER
	fish.current_class = EnemyDef.Class.BIG
	fish.position = Vector2.ZERO
	add_child(fish)
	await _frames(5)

	_check(fish.hp_max == fish.enemy_def.class_big.hp, "chaser has the higher Big-class HP")

	# Within chaser_detect_m (18m) but beyond the territorial leash (10m).
	sub.global_position = fish.home + Vector2(15.0 * _ppm(), 0)
	await _frames(10)
	_check(fish.state == Fish.State.HUNT, "chaser locks on within chaser_detect_m")

	# Run the sub far away, well beyond hunter_lose_m (24m), for longer than
	# hunter_lose_time — a chaser should keep hunting regardless.
	for i in int(GameFeel.fish.hunter_lose_time * 60.0) + 30:
		sub.global_position = fish.global_position + Vector2(40.0 * _ppm(), 0)
		await get_tree().physics_frame
	_check(fish.state == Fish.State.HUNT, "chaser never gives up even far out of range")

	fish.queue_free()
	sub.queue_free()
	await _frames(2)
