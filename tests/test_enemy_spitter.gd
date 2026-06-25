extends Node

## Headless test for MILESTONE_9.md — THE SPITTER + its destructible bubble.
## Covers: per-tier stats + bubble counts; the full inflate->fire cycle spawns
## bubbles; a bubble breaches the sub on contact (same breach spine as a bite);
## the shoot-it-down duel — a Bullet chips a 2-HP bubble and a second pops it,
## a turret torpedo bursts it and continues with reduced carry-over damage
## (slowed); and an inflated spitter is juicy (extra damage + bonus drop).
##
## Run: godot --headless res://tests/test_enemy_spitter.tscn

var _failures := 0

func _ready() -> void:
	await _test_tiers_and_bubble_counts()
	await _test_inflate_cycle_fires_bubbles()
	await _test_bubble_breaches_sub()
	await _test_bullet_chips_then_second_pops()
	await _test_torpedo_bursts_and_pierces()
	await _test_inflated_is_juicy()

	if _failures == 0:
		print("ENEMY SPITTER TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("ENEMY SPITTER TESTS FAILED: %d failing check(s)" % _failures)
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

func _spitter(sub: Sub, cls: EnemyDef.Class, pos: Vector2) -> Fish:
	var fish := Fish.new()
	fish.sub = sub
	fish.behavior = Fish.Behavior.SPITTER
	fish.current_class = cls
	fish.position = pos
	add_child(fish)
	return fish

func _count_bubbles() -> int:
	var n := 0
	for child in get_children():
		if child is Bubble:
			n += 1
	return n

func _test_tiers_and_bubble_counts() -> void:
	print("[per-tier stats + bubble counts from spitter_fish.tres]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)

	var small := _spitter(sub, EnemyDef.Class.SMALL, Vector2(500.0 * _ppm(), 500.0 * _ppm()))
	var big := _spitter(sub, EnemyDef.Class.BIG, Vector2(540.0 * _ppm(), 500.0 * _ppm()))
	var elite := _spitter(sub, EnemyDef.Class.ELITE, Vector2(580.0 * _ppm(), 500.0 * _ppm()))
	await _frames(2)

	_check(small.enemy_def.species_name == "Spitter", "SPITTER loads the Spitter species by default")
	_check(small.enemy_def.currency_color == "brown", "the Spitter drops 'brown' currency")
	_check(small.enemy_def.grabbable, "the Spitter is grabbable")
	_check(elite.hp_max > small.hp_max, "Elite has more hp than Small")
	_check(small._bubble_count() == GameFeel.spitter.small_bubbles, "Small fires 1 bubble")
	_check(big._bubble_count() == GameFeel.spitter.big_bubbles, "Big fires 2 bubbles")
	_check(elite._bubble_count() == GameFeel.spitter.elite_bubbles, "Elite fires a scatter (4)")

	small.queue_free()
	big.queue_free()
	elite.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_inflate_cycle_fires_bubbles() -> void:
	print("[detect -> kite -> inflate -> fire spawns bubbles]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)

	# Place it squarely in the standoff band (keep_min..keep_max) with line of
	# sight, so it spots the sub, holds, inflates, and fires.
	var mid := (GameFeel.spitter.spit_keep_min_m + GameFeel.spitter.spit_keep_max_m) * 0.5
	var fish := _spitter(sub, EnemyDef.Class.SMALL, sub.global_position + Vector2(mid * _ppm(), 0))
	await _frames(2)

	var before := _count_bubbles()
	var fired := false
	# inflate_time + a little slack, at 60 fps.
	var budget := int((GameFeel.spitter.inflate_time_s + 1.0) * 60.0)
	for i in budget:
		await get_tree().physics_frame
		if _count_bubbles() > before:
			fired = true
			break
	_check(fired, "the inflate cycle fires at least one bubble at the sub")

	for child in get_children():
		if child is Bubble:
			child.queue_free()
	fish.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_bubble_breaches_sub() -> void:
	print("[a bubble breaches the sub on contact]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)
	_check(sub.breaches.is_empty(), "precondition: no breach yet")

	var b := Bubble.new()
	b.global_position = sub.global_position + Vector2(6.0 * _ppm(), 0)
	b.velocity = Vector2(-GameFeel.bubble.speed_mps * _ppm(), 0)  # drift into the hull
	add_child(b)

	var hit := false
	for i in 180:
		await get_tree().physics_frame
		if not sub.breaches.is_empty():
			hit = true
			break
	_check(hit, "a bubble springs a leak when it reaches the hull (breach_from_hit spine)")

	if is_instance_valid(b):
		b.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_bullet_chips_then_second_pops() -> void:
	print("[a Bullet chips a 2-HP bubble; a second pops it]")
	var b := Bubble.new()
	b.global_position = Vector2.ZERO
	add_child(b)
	await _frames(2)
	var hp0: float = b.hp

	# First bullet (1 dmg) — not enough to burst a 2-HP bubble.
	var b1 := Bullet.new()
	b1.velocity = Vector2.ZERO
	b1.global_position = Vector2.ZERO
	add_child(b1)
	await _frames(2)
	_check(is_instance_valid(b) and not b._popped, "the bubble survives the first bullet")
	_check(b.hp < hp0, "the bubble is chipped (hp dropped) by the first bullet")
	_check(not is_instance_valid(b1), "the first bullet is consumed by the bubble")

	# Second bullet pops it.
	var b2 := Bullet.new()
	b2.velocity = Vector2.ZERO
	b2.global_position = Vector2.ZERO
	add_child(b2)
	await _frames(2)
	_check(not is_instance_valid(b) or b._popped, "a second bullet pops the bubble")

	if is_instance_valid(b):
		b.queue_free()
	await _frames(2)

func _test_torpedo_bursts_and_pierces() -> void:
	print("[a turret torpedo bursts a bubble and continues, slowed, with reduced damage]")
	var b := Bubble.new()
	b.global_position = Vector2.ZERO
	add_child(b)
	await _frames(2)
	var bubble_hp: float = b.hp

	var t := Torpedo.new()
	t.velocity = Vector2(GameFeel.turret.torpedo_speed * _ppm(), 0)
	t.global_position = Vector2.ZERO
	add_child(t)
	var v0: float = t.velocity.length()
	var dmg0: float = t.damage_value()
	await _frames(2)

	_check(not is_instance_valid(b) or b._popped, "the torpedo bursts the bubble")
	_check(is_instance_valid(t), "the torpedo survives and flies on (pierce)")
	if is_instance_valid(t):
		_check(is_equal_approx(t.damage_remaining, dmg0 - bubble_hp),
			"carry-over damage is reduced by the hp the bubble soaked")
		_check(t.velocity.length() < v0, "the torpedo is slowed by passing through the bubble")
		t.queue_free()
	if is_instance_valid(b):
		b.queue_free()
	await _frames(2)

func _test_inflated_is_juicy() -> void:
	print("[an inflated spitter takes bonus damage and drops bonus currency]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)

	# Bonus damage: a non-lethal hit while inflated removes amount * mult hp.
	var juicy := _spitter(sub, EnemyDef.Class.BIG, Vector2(500.0 * _ppm(), 500.0 * _ppm()))
	await _frames(2)
	var hp_before: float = juicy.hp
	juicy._inflated = true
	juicy.take_damage(2.0, juicy.global_position)
	_check(is_equal_approx(hp_before - juicy.hp, 2.0 * GameFeel.spitter.inflate_damage_mult),
		"a hit while inflated deals inflate_damage_mult x the damage")

	# Bonus drop: dying inflated yields more pickups than dying deflated.
	var plain := _spitter(sub, EnemyDef.Class.SMALL, Vector2(560.0 * _ppm(), 500.0 * _ppm()))
	var popped := _spitter(sub, EnemyDef.Class.SMALL, Vector2(600.0 * _ppm(), 500.0 * _ppm()))
	await _frames(2)
	plain.die()
	popped._inflated = true
	popped.die()
	await _frames(2)
	_check(popped.last_drops.size() > plain.last_drops.size(),
		"a spitter popped while inflated drops bonus currency (more pickups)")

	juicy.queue_free()
	plain.queue_free()
	popped.queue_free()
	sub.queue_free()
	get_tree().call_group("salvage", "queue_free")
	await _frames(2)
