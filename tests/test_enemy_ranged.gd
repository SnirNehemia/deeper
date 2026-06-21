extends Node

## Headless test for MILESTONE_8.md Module 3 — ranged attacks + the three
## difficulty classes. Covers: class tier visibly changes size/stats, the
## `ranged` base trait fires a projectile that breaches the sub like a bite
## does, the Elite-only `ranged_spit` ability grants ranged fire even on a
## non-ranged species (and intensifies it on an already-ranged one), and an
## unimplemented/NOVEL_HANDCODE elite_ability doesn't crash the spawn.
##
## Run: godot --headless res://tests/test_enemy_ranged.tscn

var _failures := 0

func _ready() -> void:
	await _test_class_selector_changes_size_and_stats()
	await _test_ranged_base_trait_fires_and_breaches()
	_test_elite_ranged_spit_grants_and_intensifies()
	_test_unimplemented_elite_ability_does_not_crash()

	if _failures == 0:
		print("ENEMY RANGED TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("ENEMY RANGED TESTS FAILED: %d failing check(s)" % _failures)
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

func _test_class_selector_changes_size_and_stats() -> void:
	print("[spawn-time class selector]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)

	var small := Fish.new()
	small.sub = sub
	small.current_class = EnemyDef.Class.SMALL
	small.position = Vector2(500.0 * _ppm(), 500.0 * _ppm())
	add_child(small)
	var elite := Fish.new()
	elite.sub = sub
	elite.current_class = EnemyDef.Class.ELITE
	elite.position = Vector2(600.0 * _ppm(), 500.0 * _ppm())
	add_child(elite)
	await _frames(2)

	_check(small.hp_max == small.enemy_def.class_small.hp, "Small tier reads its own hp block")
	_check(elite.hp_max == elite.enemy_def.class_elite.hp, "Elite tier reads its own hp block")
	_check(elite.hp_max > small.hp_max, "Elite has more hp than Small")
	var small_shape: CollisionShape2D = small.get_child(0)
	var elite_shape: CollisionShape2D = elite.get_child(0)
	_check(elite_shape.shape.radius > small_shape.shape.radius,
		"Elite's collision size is visibly bigger than Small's (size_scale consumed)")

	small.queue_free()
	elite.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_ranged_base_trait_fires_and_breaches() -> void:
	print("[ranged base trait fires and breaches like a bite]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)

	var stats := EnemyClassStats.new()
	stats.room_weight = 1.0
	var def := EnemyDef.new()
	def.species_name = "test_ranged_fish"
	def.ranged = true
	def.class_small = stats
	def.class_big = stats
	def.class_elite = stats

	var fish := Fish.new()
	fish.sub = sub
	fish.enemy_def = def
	# Within fire_range_m but well clear of hull contact (9.5 m center-to-
	# center is the same safe non-contact distance test_fish.gd's territory
	# test uses against this same default ~8.3 m-wide hull), so any breach
	# here can only come from the ranged shot, not the contact bite.
	fish.position = sub.global_position + Vector2(9.5 * _ppm(), 0)
	add_child(fish)
	await _frames(2)
	_check(sub.breaches.is_empty(), "precondition: no breach yet")

	fish._try_ranged_fire(0.016)

	var hit := false
	for i in 180:  # 3s — plenty of time at 5 m/s over 8 m
		await get_tree().physics_frame
		if not sub.breaches.is_empty():
			hit = true
			break
	_check(hit, "a ranged shot breaches the sub through the same breach_from_hit spine a bite uses")

	fish.queue_free()
	sub.queue_free()
	await _frames(2)

func _elite_def(ability: String, base_ranged: bool) -> EnemyDef:
	var stats := EnemyClassStats.new()
	stats.elite_ability = ability
	stats.room_weight = 1.0
	var def := EnemyDef.new()
	def.species_name = "test_elite_fish"
	def.ranged = base_ranged
	def.class_small = EnemyClassStats.new()
	def.class_big = EnemyClassStats.new()
	def.class_elite = stats
	return def

func _test_elite_ranged_spit_grants_and_intensifies() -> void:
	print("[elite ranged_spit ability]")
	var sub := Sub.new()
	add_child(sub)

	# Gains: a non-ranged species' Elite still wants to fire with the ability.
	var granted := Fish.new()
	granted.sub = sub
	granted.enemy_def = _elite_def("ranged_spit", false)
	granted.current_class = EnemyDef.Class.ELITE
	granted.position = sub.global_position
	add_child(granted)
	_check(granted._wants_ranged(),
		"a non-ranged species' Elite with ranged_spit still wants to fire")
	_check(not granted._ranged_intensified(),
		"gaining ranged (base trait false) does not count as intensifying it")

	# Intensifies: an already-ranged species' Elite with the same ability
	# fires on a shorter cooldown instead.
	var intensified := Fish.new()
	intensified.sub = sub
	intensified.enemy_def = _elite_def("ranged_spit", true)
	intensified.current_class = EnemyDef.Class.ELITE
	intensified.position = sub.global_position
	add_child(intensified)
	_check(intensified._wants_ranged(), "an already-ranged Elite with ranged_spit still wants to fire")
	_check(intensified._ranged_intensified(), "base ranged=true + the ability counts as intensified")

	granted.queue_free()
	intensified.queue_free()
	sub.queue_free()

func _test_unimplemented_elite_ability_does_not_crash() -> void:
	print("[unimplemented / NOVEL_HANDCODE elite_ability is inert, not a crash]")
	var sub := Sub.new()
	add_child(sub)

	var shielded := Fish.new()
	shielded.sub = sub
	shielded.enemy_def = _elite_def("brief_shield", false)
	shielded.current_class = EnemyDef.Class.ELITE
	shielded.position = sub.global_position
	add_child(shielded)
	_check(not shielded.is_dead, "a recognized-but-unimplemented common ability spawns fine")

	var novel := Fish.new()
	novel.sub = sub
	novel.enemy_def = _elite_def("NOVEL_HANDCODE", false)
	novel.current_class = EnemyDef.Class.ELITE
	novel.position = sub.global_position
	add_child(novel)
	_check(not novel.is_dead, "a NOVEL_HANDCODE placeholder spawns fine (logs, doesn't crash)")

	shielded.queue_free()
	novel.queue_free()
	sub.queue_free()
