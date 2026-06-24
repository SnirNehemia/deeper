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
	await _test_chaser_is_its_own_species()
	await _test_falls_under_gravity_when_stranded()
	await _test_pocket_sky_check_bounded_by_rect()
	await _test_escapes_when_embedded_in_terrain()
	await _test_resumes_ai_after_landing_in_a_pocket()
	await _test_chaser_does_not_detect_through_walls()
	await _test_does_not_swim_through_a_wall_while_chasing()

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

func _test_chaser_is_its_own_species() -> void:
	print("[the chaser is its own species, not a recolored reference fish]")
	var sub := Sub.new()
	sub.position = Vector2(-1000.0 * _ppm(), 0)
	add_child(sub)

	var chaser := Fish.new()
	chaser.sub = sub
	chaser.behavior = Fish.Behavior.CHASER
	add_child(chaser)
	var territorial := Fish.new()
	territorial.sub = sub
	territorial.behavior = Fish.Behavior.TERRITORIAL
	add_child(territorial)
	await _frames(2)

	_check(chaser.enemy_def.currency_color == "teal",
		"an unconfigured chaser defaults to its own teal-currency species")
	_check(territorial.enemy_def.currency_color == "orange",
		"an unconfigured territorial fish still defaults to the orange reference species")
	_check(chaser.enemy_def != territorial.enemy_def,
		"chaser and territorial fish use two distinct EnemyDef resources")

	chaser.queue_free()
	territorial.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_falls_under_gravity_when_stranded() -> void:
	print("[a fish stranded above the water surface falls under plain gravity, no steering]")
	var sub := Sub.new()
	sub.position = Vector2(-1000.0 * _ppm(), 0)  # far away: fish stays out of CHASE/HUNT
	add_child(sub)

	var fish := Fish.new()
	fish.sub = sub
	add_child(fish)
	await _frames(2)

	fish.water_surface_y = 1000.0
	fish.home = Vector2(500.0, 1200.0)  # sideways + underwater: if the fish could
	                                      # still steer while airborne it would drift toward x=500
	fish.global_position = Vector2(0.0, -50.0)  # stranded above the surface line
	fish.state = Fish.State.RETURN

	var x0 := fish.global_position.x
	var y0 := fish.global_position.y
	await _frames(10)
	var y1 := fish.global_position.y
	await _frames(10)
	var y2 := fish.global_position.y

	_check(fish.global_position.x == x0,
		"a falling fish does not steer sideways, even toward home")
	_check((y2 - y1) > (y1 - y0),
		"fall speed increases over time like gravity, not a constant drift")

	var reached_water := false
	for i in 300:
		await get_tree().physics_frame
		if fish.global_position.y >= fish.water_surface_y:
			reached_water = true
			break
	_check(reached_water, "the fish actually reaches the water, it doesn't fall forever")

	fish.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_pocket_sky_check_bounded_by_rect() -> void:
	print("[a pocket's sky zone is bounded by its rect, not just its x-range]")
	var sub := Sub.new()
	sub.position = Vector2(-1000.0 * _ppm(), 0)
	add_child(sub)

	var fish := Fish.new()
	fish.sub = sub
	add_child(fish)
	await _frames(2)

	fish.water_surface_y = 0.0  # disabled (default) -- isolates the pocket check below
	fish.sky_zones = [{
		"rect": Rect2(100.0, 500.0, 200.0, 100.0),
		"surface_y": 550.0,
		"is_pocket": true,
	}]

	# Shares the pocket's x-range but is far above its actual vertical
	# footprint (genuinely underwater elsewhere) -- this used to false-positive
	# as "in that pocket's sky" before bounding the check by the full rect.
	fish.global_position = Vector2(150.0, 50.0)
	_check(not fish._in_sky(),
		"a fish sharing a pocket's x-range but outside its rect is not treated as airborne")

	# Genuinely inside the pocket's footprint and above its local surface IS sky.
	fish.global_position = Vector2(150.0, 520.0)
	_check(fish._in_sky(),
		"a fish actually inside a pocket's rect, above its local surface, is airborne")

	fish.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_escapes_when_embedded_in_terrain() -> void:
	print("[a fish embedded in rock (e.g. knocked into a wall) can still escape]")
	var sub := Sub.new()
	sub.position = Vector2(-1000.0 * _ppm(), 0)  # far away: fish stays out of CHASE/HUNT
	add_child(sub)

	var rock := TerrainBody.new()
	rock.add_rect(Rect2(-50.0, -50.0, 100.0, 100.0))  # a solid block centered on the origin
	add_child(rock)
	await _frames(2)

	var fish := Fish.new()
	fish.sub = sub
	add_child(fish)
	await _frames(2)

	fish.global_position = Vector2.ZERO  # embedded dead-center in the rock
	fish.home = Vector2(500.0, 0.0)      # a clear target well outside the rock
	fish.state = Fish.State.RETURN

	var start := fish.global_position
	await _frames(30)

	_check(fish.global_position.distance_to(start) > 1.0,
		"a fish embedded in rock can still move toward open water, instead of being frozen forever")

	fish.queue_free()
	rock.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_resumes_ai_after_landing_in_a_pocket() -> void:
	print("[a fish that lands on rock inside an air pocket resumes AI instead of freezing on top of it forever]")
	var sub := Sub.new()
	sub.position = Vector2(-1000.0 * _ppm(), 0)  # far away: fish stays out of CHASE/HUNT
	add_child(sub)

	# A solid floor a little below the fish's start point, still well within
	# the pocket's own sky zone -- the fish should land on this, not fall
	# through it, and the landing itself must not freeze it in place.
	var rock := TerrainBody.new()
	rock.add_rect(Rect2(-200.0, 50.0, 400.0, 200.0))
	add_child(rock)
	await _frames(2)

	var fish := Fish.new()
	fish.sub = sub
	add_child(fish)
	await _frames(2)

	fish.water_surface_y = 0.0  # disabled (default) -- isolate the pocket case
	fish.sky_zones = [{
		"rect": Rect2(-200.0, -200.0, 400.0, 260.0),  # covers the fish's start AND the rock's top
		"surface_y": 1000.0,  # comfortably above both, so "in this pocket's air" holds throughout
		"is_pocket": true,
	}]
	fish.home = Vector2(900.0, 1000.0)  # a clear target well outside the pocket and the rock
	fish.global_position = Vector2(0.0, -10.0)  # starts in the pocket's air, just above the floor
	fish.state = Fish.State.RETURN

	await _frames(20)  # falls and lands on the rock floor
	var landed := fish.global_position
	await _frames(90)  # should now be resuming AI, working its way back toward home

	_check(fish.global_position.distance_to(landed) > 1.0,
		"a fish landed on a pocket's rock floor resumes AI instead of freezing there forever")

	fish.queue_free()
	rock.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_chaser_does_not_detect_through_walls() -> void:
	print("[a chaser doesn't lock on to a sub hidden behind solid rock, even within range]")
	var sub := Sub.new()
	sub.position = Vector2(-100.0 * _ppm(), 0)
	add_child(sub)

	var fish := Fish.new()
	fish.sub = sub
	fish.behavior = Fish.Behavior.CHASER
	fish.position = Vector2.ZERO
	add_child(fish)
	await _frames(2)

	# A solid wall directly between the fish's home and where the sub is about
	# to move to.
	var rock := TerrainBody.new()
	rock.add_rect(Rect2(7.0 * _ppm(), -300.0, 1.0 * _ppm(), 600.0))
	add_child(rock)
	await _frames(2)

	# Within chaser_detect_m (18m) but hidden behind the wall.
	sub.global_position = fish.home + Vector2(15.0 * _ppm(), 0)
	await _frames(10)
	_check(fish.state != Fish.State.HUNT,
		"a chaser doesn't detect a sub hidden behind solid rock, even within range")

	# Remove the wall, same distance: now it should lock on.
	rock.queue_free()
	await _frames(2)
	await _frames(10)
	_check(fish.state == Fish.State.HUNT,
		"the same chaser detects the sub once it has a clear line of sight")

	fish.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_does_not_swim_through_a_wall_while_chasing() -> void:
	print("[a fish chasing into a wall stays blocked, doesn't slip through by grazing it]")
	var sub := Sub.new()
	add_child(sub)

	var rock := TerrainBody.new()
	rock.add_rect(Rect2(40.0, -300.0, 40.0, 600.0))
	add_child(rock)
	await _frames(2)

	var fish := Fish.new()
	fish.sub = sub
	fish.behavior = Fish.Behavior.CHASER
	fish.global_position = Vector2.ZERO
	add_child(fish)
	await _frames(2)

	fish.state = Fish.State.HUNT  # already locked on -- detection/LOS isn't what's under test here
	sub.global_position = Vector2(200.0, 0.0)  # on the far side of the wall

	for i in 120:
		await get_tree().physics_frame

	_check(fish.global_position.x < 40.0,
		"a fish can't cross through solid rock just by repeatedly bumping into it")

	fish.queue_free()
	rock.queue_free()
	sub.queue_free()
	await _frames(2)
