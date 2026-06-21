extends Node

## Headless test for MILESTONE_8.md Module 2 — grab-tug physics.
## Covers: the three weight bands (Light pinned / Medium tug-of-war / Heavy
## dominant drag) and the EnemyDef `grabbable` flag refusing both arms.
##
## Run: godot --headless res://tests/test_grab_tug.tscn

var _failures := 0

func _ready() -> void:
	_test_weight_band_classification()
	await _test_light_is_pinned()
	await _test_medium_tugs()
	await _test_heavy_drags_harder_than_medium()
	await _test_grabbable_false_refuses_telescope()
	await _test_grabbable_false_refuses_claw()

	if _failures == 0:
		print("GRAB TUG TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("GRAB TUG TESTS FAILED: %d failing check(s)" % _failures)
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

func _make_telescope_sub() -> Sub:
	var layout := SubLayout.new()
	layout.placements = [
		SubLayout.Placement.new("telescope_room", Vector2i(-1, 0), "left"),
		SubLayout.Placement.new("helm",           Vector2i(0,  0)),
		SubLayout.Placement.new("tower",          Vector2i(0, -1)),
	]
	var sub := Sub.new()
	sub.layout = layout
	add_child(sub)
	return sub

func _make_claw_sub() -> Sub:
	var layout := SubLayout.new()
	layout.placements = [
		SubLayout.Placement.new("claw_room", Vector2i(-1, 0), "left"),
		SubLayout.Placement.new("helm",      Vector2i(0,  0)),
		SubLayout.Placement.new("tower",     Vector2i(0, -1)),
	]
	var sub := Sub.new()
	sub.layout = layout
	add_child(sub)
	return sub

func _telescope(sub: Sub) -> TelescopeStation:
	for child in sub.get_children():
		if child is TelescopeStation:
			return child
	return null

func _claw(sub: Sub) -> ClawStation:
	for child in sub.get_children():
		if child is ClawStation:
			return child
	return null

func _make_input(move: Vector2, use_pressed: bool) -> PlayerInput:
	var inp := PlayerInput.new()
	inp.move = move
	inp.use_pressed = use_pressed
	return inp

## A fish at `pos` on the given EnemyDef class tier, alive and grabbable
## unless `custom_def` overrides EnemyDef entirely (e.g. for grabbable=false).
## `home` is pushed off to one side (struggle_direction() points fish->home,
## which is zero-length and produces no tug at all if grabbed exactly on top
## of its own home point — these tests need a real escape direction).
func _make_fish(pos: Vector2, fish_class: EnemyDef.Class, custom_def: EnemyDef = null) -> Fish:
	var fish := Fish.new()
	fish.position = pos
	fish.current_class = fish_class
	if custom_def != null:
		fish.enemy_def = custom_def
	add_child(fish)
	# Far enough that the sub drifting toward it over the test's several
	# seconds never overshoots and flips the pull direction mid-test.
	fish.home = pos + Vector2(-50000.0, 0.0)
	return fish

func _ungrabbable_def() -> EnemyDef:
	var def := EnemyDef.new()
	def.species_name = "test_ungrabbable"
	def.grabbable = false
	def.class_small = EnemyClassStats.new()
	def.class_big = EnemyClassStats.new()
	def.class_elite = EnemyClassStats.new()
	return def

func _test_weight_band_classification() -> void:
	print("[weight band classification]")
	var imp := GameFeel.enemy_impact
	_check(imp.weight_band(1.0) == GameFeel.EnemyImpactFeel.WeightBand.LIGHT,
		"Small tier (room_weight 1.0) is Light")
	_check(imp.weight_band(2.0) == GameFeel.EnemyImpactFeel.WeightBand.MEDIUM,
		"Big tier (room_weight 2.0) is Medium")
	_check(imp.weight_band(3.0) == GameFeel.EnemyImpactFeel.WeightBand.HEAVY,
		"Elite tier (room_weight 3.0) is Heavy")

func _test_light_is_pinned() -> void:
	print("[light: hard-pinned, no tug]")
	var sub := _make_telescope_sub()
	var t := _telescope(sub)
	t.extension = GameFeel.telescope.reach_m * Sub.PPM * 0.5  # extended, not home
	await _frames(2)

	var fish := _make_fish(sub.to_global(t.tip_local()), EnemyDef.Class.SMALL)
	await _frames(1)
	t.handle_input(_make_input(Vector2.ZERO, true))
	_check(fish.grabbed, "a light fish is grabbed")

	await _frames(60)  # 1s
	_check(sub.velocity.length() < 1.0, "a light catch exerts no tug at all (pinned)")

	fish.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_medium_tugs() -> void:
	print("[medium: a real tug-of-war]")
	var sub := _make_telescope_sub()
	var t := _telescope(sub)
	t.extension = GameFeel.telescope.reach_m * Sub.PPM * 0.5
	await _frames(2)

	var fish := _make_fish(sub.to_global(t.tip_local()), EnemyDef.Class.BIG)
	await _frames(1)
	t.handle_input(_make_input(Vector2.ZERO, true))
	_check(fish.grabbed, "a medium fish is grabbed")

	await _frames(180)  # 3s, long enough to approach its steady drift
	var medium_speed := sub.velocity.length()
	_check(medium_speed > 20.0, "a medium catch visibly tugs the sub")

	fish.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_heavy_drags_harder_than_medium() -> void:
	print("[heavy: dominant drag]")
	# Medium reference run.
	var sub_m := _make_telescope_sub()
	var t_m := _telescope(sub_m)
	t_m.extension = GameFeel.telescope.reach_m * Sub.PPM * 0.5
	await _frames(2)
	var fish_m := _make_fish(sub_m.to_global(t_m.tip_local()), EnemyDef.Class.BIG)
	await _frames(1)
	t_m.handle_input(_make_input(Vector2.ZERO, true))
	await _frames(180)
	var medium_speed := sub_m.velocity.length()

	# Heavy run.
	var sub_h := _make_telescope_sub()
	var t_h := _telescope(sub_h)
	t_h.extension = GameFeel.telescope.reach_m * Sub.PPM * 0.5
	await _frames(2)
	var fish_h := _make_fish(sub_h.to_global(t_h.tip_local()), EnemyDef.Class.ELITE)
	await _frames(1)
	t_h.handle_input(_make_input(Vector2.ZERO, true))
	await _frames(180)
	var heavy_speed := sub_h.velocity.length()

	_check(heavy_speed > medium_speed, "a heavy catch drags the sub harder than a medium one")

	# Bounded, not runaway: keep running and confirm it has settled rather
	# than still accelerating (the target-shift model has a terminal speed).
	await _frames(180)
	var heavy_speed_later := sub_h.velocity.length()
	_check(absf(heavy_speed_later - heavy_speed) < heavy_speed * 0.25,
		"the heavy drag settles at a bounded drift speed instead of accelerating forever")

	fish_m.queue_free()
	sub_m.queue_free()
	fish_h.queue_free()
	sub_h.queue_free()
	await _frames(2)

func _test_grabbable_false_refuses_telescope() -> void:
	print("[grabbable=false refuses the telescope]")
	var sub := _make_telescope_sub()
	var t := _telescope(sub)
	t.extension = GameFeel.telescope.reach_m * Sub.PPM * 0.5
	await _frames(2)

	var fish := _make_fish(sub.to_global(t.tip_local()), EnemyDef.Class.SMALL, _ungrabbable_def())
	await _frames(1)
	t.handle_input(_make_input(Vector2.ZERO, true))
	_check(not fish.grabbed, "grabbable=false refuses the telescope arm")
	_check(not t.has_grabbed_fish(), "telescope holds nothing")

	fish.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_grabbable_false_refuses_claw() -> void:
	print("[grabbable=false refuses the claw]")
	var sub := _make_claw_sub()
	var claw := _claw(sub)
	claw.shoulder_angle = 0.0
	claw.elbow_angle = 0.0  # extended, not home
	await _frames(2)

	var fish := _make_fish(sub.to_global(claw.tip_local()), EnemyDef.Class.SMALL, _ungrabbable_def())
	await _frames(1)
	claw.handle_input(_make_input(Vector2.ZERO, true))
	_check(not fish.grabbed, "grabbable=false refuses the claw arm")
	_check(not claw.has_grabbed_fish(), "claw holds nothing")

	fish.queue_free()
	sub.queue_free()
	await _frames(2)
