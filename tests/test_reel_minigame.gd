extends Node

## Headless test for the reel-in timing minigame (2026-06-21 follow-up to
## MILESTONE_8.md Module 2). Covers: a landed pull brings the catch closer,
## a fully-missed sweep opens a leak at the arm's base, reaching home finishes
## the catch through the normal damage pipeline, and an impossible-weight
## catch can never land a pull (only ever leaks).
##
## Run: godot --headless res://tests/test_reel_minigame.tscn

var _failures := 0

func _ready() -> void:
	_test_landed_pull_shortens_extension()
	_test_full_miss_opens_a_leak()
	_test_reaching_home_finishes_the_catch()
	_test_impossible_weight_never_lands()

	if _failures == 0:
		print("REEL MINIGAME TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("REEL MINIGAME TESTS FAILED: %d failing check(s)" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok:   ", msg)
	else:
		push_error("  FAIL: " + msg)
		_failures += 1

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

func _telescope(sub: Sub) -> TelescopeStation:
	for child in sub.get_children():
		if child is TelescopeStation:
			return child
	return null

## A fish hooked directly (bypassing the grab-radius search — these tests are
## about the reel minigame, not the grab itself) at the telescope's tip, on
## the given room_weight via a custom EnemyDef so the test controls difficulty
## exactly rather than going through a class tier.
func _hook_fish(t: TelescopeStation, sub: Sub, room_weight: float) -> Fish:
	var stats := EnemyClassStats.new()
	stats.room_weight = room_weight
	stats.move_speed = 3.5
	var def := EnemyDef.new()
	def.species_name = "test_reel_fish"
	def.grabbable = true
	def.class_small = stats
	def.class_big = stats
	def.class_elite = stats
	var fish := Fish.new()
	fish.enemy_def = def
	fish.position = sub.to_global(t.tip_local())
	add_child(fish)
	fish.home = fish.position + Vector2(-50000.0, 0.0)
	fish.grab()
	t._grabbed_fish = fish
	t._reel = ReelMinigame.new(room_weight)
	return fish

## Advance the reel by exactly one full sweep, attempting a pull at the
## instant the bead sits inside the green zone (the middle of the approach
## leg's success window) — a reliable "land it" pattern for an easy-weight
## catch, used to test the success path without depending on real player
## timing input.
func _land_one_pull(t: TelescopeStation, sub: Sub, room_weight: float) -> void:
	var period := GameFeel.reel.sweep_period_s(room_weight)
	var step := period / 240.0
	for i in 240:
		t._carry_and_tug_fish(step)
		# Attempt every step on the approach leg; attempt_pull() only landing
		# inside the green zone keeps this honest rather than rigged.
		t._attempt_pull()

func _test_landed_pull_shortens_extension() -> void:
	print("[a landed pull brings the catch closer]")
	var sub := _make_telescope_sub()
	var t := _telescope(sub)
	t.extension = GameFeel.telescope.reach_m * Sub.PPM * 0.8
	var start_ext := t.extension
	var fish := _hook_fish(t, sub, 1.0)  # light/easy: wide green zone

	_land_one_pull(t, sub, 1.0)

	_check(t.extension < start_ext, "extension shrank after a full sweep of pull attempts")
	_check(start_ext - t.extension <= GameFeel.reel.pull_distance_m * Sub.PPM + 0.5,
		"shrank by at most one pull_distance_m worth (one landing per sweep)")

	fish.queue_free()
	sub.queue_free()

func _test_full_miss_opens_a_leak() -> void:
	print("[a fully-missed sweep leaks at the arm's base]")
	var sub := _make_telescope_sub()
	var t := _telescope(sub)
	t.extension = GameFeel.telescope.reach_m * Sub.PPM * 0.8
	var fish := _hook_fish(t, sub, 1.0)
	_check(sub.breaches.is_empty(), "precondition: no breach yet")

	var period := GameFeel.reel.sweep_period_s(1.0)
	var step := period / 60.0
	for i in 61:  # one full sweep, never pressing the action key
		t._carry_and_tug_fish(step)

	_check(not sub.breaches.is_empty(), "a full sweep with no landed pull opens a breach")
	_check(sub.breaches[0].room == t.room_index, "the leak opens in the telescope's own room")

	fish.queue_free()
	sub.queue_free()

func _test_reaching_home_finishes_the_catch() -> void:
	print("[reaching home finishes the catch]")
	var sub := _make_telescope_sub()
	var t := _telescope(sub)
	t.extension = GameFeel.telescope.home_radius_m * Sub.PPM * 0.5  # already basically home
	var fish := _hook_fish(t, sub, 1.0)

	t._carry_and_tug_fish(0.016)

	_check(fish.is_dead, "a catch reeled fully home is finished off")
	_check(not t.has_grabbed_fish(), "the station drops its reference once finished")

	sub.queue_free()

func _test_impossible_weight_never_lands() -> void:
	print("[an impossible-weight catch can never land a pull]")
	var sub := _make_telescope_sub()
	var t := _telescope(sub)
	t.extension = GameFeel.telescope.reach_m * Sub.PPM * 0.8
	var start_ext := t.extension
	var heavy := GameFeel.reel.impossible_weight_min + 1.0
	_check(GameFeel.reel.success_zone_frac(heavy) <= 0.0,
		"precondition: the success zone has collapsed to nothing at this weight")
	var fish := _hook_fish(t, sub, heavy)

	# Run several full sweeps, attempting a pull on every step.
	var period := GameFeel.reel.sweep_period_s(heavy)
	var step := period / 60.0
	for i in 60 * 3:
		t._carry_and_tug_fish(step)
		t._attempt_pull()

	_check(t.extension == start_ext, "extension never shrinks no matter how it's timed")
	_check(not sub.breaches.is_empty(), "an unwinnable catch leaks instead of ever landing")

	fish.queue_free()
	sub.queue_free()
