extends Node

## Headless test for MILESTONE_9.md — THE LURKER (AMBUSHER behavior). Covers:
## per-tier stats load from lurker_fish.tres; the attention ring is NEVER drawn
## (invisible range); the sub entering the hidden range triggers
## detect→windup→lunge→bite that breaches the sub through the same breach spine
## as any other bite; and after a bite the lurker picks a NEW home and heads
## back to re-bury there (never the same spot).
##
## Run: godot --headless res://tests/test_enemy_lurker.tscn

var _failures := 0

func _ready() -> void:
	await _test_tiers_load_from_lurker_def()
	await _test_attention_ring_is_never_drawn()
	await _test_ambush_bites_and_reburies()
	await _test_lurker_treats_sand_as_passable()

	if _failures == 0:
		print("ENEMY LURKER TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("ENEMY LURKER TESTS FAILED: %d failing check(s)" % _failures)
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

func _make_lurker(sub: Sub, cls: EnemyDef.Class, pos: Vector2) -> Fish:
	var fish := Fish.new()
	fish.sub = sub
	fish.behavior = Fish.Behavior.AMBUSHER
	fish.current_class = cls
	fish.position = pos
	add_child(fish)
	return fish

func _test_tiers_load_from_lurker_def() -> void:
	print("[per-tier stats load from lurker_fish.tres]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)

	# Far from the sub so they just sit buried (no detect) while we read stats.
	var small := _make_lurker(sub, EnemyDef.Class.SMALL, Vector2(500.0 * _ppm(), 500.0 * _ppm()))
	var elite := _make_lurker(sub, EnemyDef.Class.ELITE, Vector2(560.0 * _ppm(), 500.0 * _ppm()))
	await _frames(2)

	_check(small.enemy_def.species_name == "Sand Lurker",
		"AMBUSHER loads the Sand Lurker species by default")
	_check(small.enemy_def.currency_color == "tan", "the Lurker drops 'tan' currency")
	_check(not small.enemy_def.ranged, "the Lurker is melee (ranged=false)")
	_check(small.enemy_def.grabbable, "the Lurker is grabbable")
	_check(small.hp_max == small.enemy_def.class_small.hp, "Small tier reads its own hp block")
	_check(elite.hp_max == elite.enemy_def.class_elite.hp, "Elite tier reads its own hp block")
	_check(elite.hp_max > small.hp_max, "Elite has more hp than Small")
	var small_shape: CollisionShape2D = small.get_child(0)
	var elite_shape: CollisionShape2D = elite.get_child(0)
	_check(elite_shape.shape.radius > small_shape.shape.radius,
		"Elite's collision size is visibly bigger than Small's (size_scale consumed)")
	_check(small.state == Fish.State.LURK, "a Lurker out of range just sits buried (LURK)")

	small.queue_free()
	elite.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_attention_ring_is_never_drawn() -> void:
	print("[the Lurker's attention ring is invisible by design]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)

	var lurker := _make_lurker(sub, EnemyDef.Class.SMALL, Vector2(500.0 * _ppm(), 500.0 * _ppm()))
	# A plain territorial fish as the control: it DOES draw its ring.
	var control := Fish.new()
	control.sub = sub
	control.behavior = Fish.Behavior.TERRITORIAL
	control.position = Vector2(600.0 * _ppm(), 500.0 * _ppm())
	add_child(control)
	await _frames(2)

	_check(not lurker.shows_detection_ring(),
		"the Lurker never draws its attention ring (invisible range)")
	_check(control.shows_detection_ring(),
		"control: a territorial fish does draw its ring")

	lurker.queue_free()
	control.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_ambush_bites_and_reburies() -> void:
	print("[detect -> windup -> lunge -> bite breaches, then re-bury somewhere new]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)

	# Just outside hull contact but well inside the hidden detect radius (the
	# default hull is ~8.3 m wide, so 6 m center-to-center is ~1.8 m off the
	# hull edge — within ambush_detect_m, clear of a passive contact bite).
	var fish := _make_lurker(sub, EnemyDef.Class.SMALL, sub.global_position + Vector2(6.0 * _ppm(), 0))
	await _frames(2)

	var home_before: Vector2 = fish.home
	_check(fish.state == Fish.State.WINDUP or fish.state == Fish.State.LUNGE,
		"the sub inside the hidden range triggers the windup/lunge (no passive idle)")
	_check(sub.breaches.is_empty(), "precondition: no breach yet")

	var hit := false
	for i in 240:  # 4 s — plenty for a 0.2 s windup + an 18 m/s lunge over ~2 m
		await get_tree().physics_frame
		if not sub.breaches.is_empty():
			hit = true
			break
	_check(hit, "the lunge bite breaches the sub through the same breach_from_hit spine a bite uses")

	# After the strike it darts off to a NEW burial spot and heads back there.
	await _frames(2)
	_check(fish.home != home_before, "after a bite the Lurker re-buries somewhere new (home moved)")
	_check(fish.state == Fish.State.RETURN or fish.state == Fish.State.LURK,
		"after the strike it returns to its new burial spot (RETURN, then LURK)")

	fish.queue_free()
	sub.queue_free()
	await _frames(2)

func _terrain_body(t: int, center: Vector2, size: Vector2) -> TerrainBody:
	var body := TerrainBody.new()
	body.terrain_type = t
	body.add_rect(Rect2(center - size * 0.5, size))  # world-space rect
	add_child(body)
	return body

func _blocks_at(fish: Fish, pos: Vector2) -> bool:
	fish.global_position = pos
	fish._terrain_cast.target_position = Vector2.ZERO
	fish._terrain_cast.force_shapecast_update()
	return fish._terrain_cast_blocks()

func _test_lurker_treats_sand_as_passable() -> void:
	print("[the lurker moves through sand (its hiding place) but not rock]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)

	# A sand block on the left, a rock block on the right, well apart.
	var ppm := _ppm()
	var sand_c := Vector2(-40.0 * ppm, 0)
	var rock_c := Vector2(40.0 * ppm, 0)
	_terrain_body(TerrainType.Type.SAND, sand_c, Vector2(8.0 * ppm, 8.0 * ppm))
	_terrain_body(TerrainType.Type.NORMAL_ROCK, rock_c, Vector2(8.0 * ppm, 8.0 * ppm))

	var lurker := _make_lurker(sub, EnemyDef.Class.SMALL, sand_c)
	# A plain territorial fish as the control — sand must still block it.
	var control := Fish.new()
	control.sub = sub
	control.behavior = Fish.Behavior.TERRITORIAL
	control.position = sand_c
	add_child(control)
	await _frames(3)

	_check(not _blocks_at(lurker, sand_c), "a lurker buried in sand is NOT blocked (sand is passable for it)")
	_check(_blocks_at(lurker, rock_c), "a lurker is still blocked by solid rock")
	_check(_blocks_at(control, sand_c), "a normal (non-lurker) fish IS still blocked by sand")

	lurker.queue_free()
	control.queue_free()
	sub.queue_free()
	await _frames(2)
