extends Node

## Headless test for MILESTONE_10.md — THE SHOAL (a flocking-swarm group entity).
## Covers: tier → member count; members flock (cohesive around the leader,
## separated without stacking); a BALL_UP→SLAM pools into EXACTLY ONE
## breach_from_hit (not N per-fish); killing the leader scatters the school then
## promotes a new leader (crown moves + grows in, reduced prize share); thinning
## below the threshold sends survivors into a terminal flee; and the leader
## carries the teal prize while members drop ~none.
##
## Run: godot --headless res://tests/test_enemy_shoal.tscn

var _failures := 0

func _ready() -> void:
	# Most behaviour tests place a school "far" from the sub to keep it resting;
	# with the LOD that distance now means "dormant", so force schools to stay
	# fully active here. _test_dormant_when_far overrides this to test the LOD.
	GameFeel.flock.active_range_m = 1.0e9
	await _test_tiers_map_to_member_counts()
	await _test_members_flock_cohesively()
	await _test_dormant_when_far()
	await _test_dormant_school_stays_out_of_rock()
	await _test_stays_below_water_surface()
	await _test_avoids_terrain()
	await _test_spawns_clear_of_terrain()
	await _test_spot_stalk_charge_one_breach()
	await _test_charge_tracks_small_dodge()
	await _test_dodged_charge_misses()
	await _test_leader_kill_scatters_and_promotes()
	await _test_thinning_triggers_flee()
	await _test_survives_run_reset()
	await _test_leader_holds_prize_members_drop_none()

	if _failures == 0:
		print("ENEMY SHOAL TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("ENEMY SHOAL TESTS FAILED: %d failing check(s)" % _failures)
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

func _make_shoal(sub: Sub, tier: EnemyDef.Class, pos: Vector2) -> Shoal:
	var s := Shoal.new()
	s.sub = sub
	s.tier = tier
	s.position = pos
	add_child(s)
	return s

func _test_tiers_map_to_member_counts() -> void:
	print("[tier = school size: Small/Big/Elite map to denser clouds]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)
	var far := sub.global_position + Vector2(60.0 * _ppm(), 0)
	var small := _make_shoal(sub, EnemyDef.Class.SMALL, far)
	var big := _make_shoal(sub, EnemyDef.Class.BIG, far + Vector2(20.0 * _ppm(), 0))
	var elite := _make_shoal(sub, EnemyDef.Class.ELITE, far + Vector2(40.0 * _ppm(), 0))
	await _frames(3)

	_check(small._members.size() == GameFeel.flock.small_count, "Small tier spawns small_count members")
	_check(big._members.size() == GameFeel.flock.big_count and big._members.size() > small._members.size(),
		"Big tier is a denser cloud than Small")
	_check(elite._members.size() == GameFeel.flock.elite_count and elite._members.size() > big._members.size(),
		"Elite tier is the densest cloud")

	var m0: Fish = small._members[0]
	_check(m0.enemy_def.species_name == "Shoal", "members load the Shoal species")
	_check(m0.enemy_def.currency_color == "teal", "the Shoal drops teal currency")
	_check(m0.enemy_def.grabbable, "a Shoal member is grabbable (behaves like any caught fish)")

	# One faint attention ring per school, drawn by the leader only.
	_check(small._leader.shows_detection_ring(), "the leader shows the school's faint attention ring")
	var nonleader: Fish = null
	for m: Fish in small._members:
		if not m._is_leader:
			nonleader = m
			break
	_check(nonleader != null and not nonleader.shows_detection_ring(),
		"non-leader members show no ring (one ring per school, not 40)")

	small.queue_free()
	big.queue_free()
	elite.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_members_flock_cohesively() -> void:
	print("[members flock: cohesive around the leader, separated without stacking]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)
	var far := sub.global_position + Vector2(60.0 * _ppm(), 0)
	var shoal := _make_shoal(sub, EnemyDef.Class.BIG, far)
	await _frames(180)  # let the cloud settle

	var free := shoal._free_members()
	_check(free.size() >= 2, "precondition: members present")
	var c := shoal._centroid(free)
	var max_d := 0.0
	var min_pair := INF
	var sum_nn := 0.0
	for i in free.size():
		var fi: Fish = free[i]
		max_d = maxf(max_d, fi.global_position.distance_to(c))
		var nn := INF
		for j in free.size():
			if j == i:
				continue
			var d := fi.global_position.distance_to((free[j] as Fish).global_position)
			nn = minf(nn, d)
			if j > i:
				min_pair = minf(min_pair, d)
		sum_nn += nn
	var avg_nn := sum_nn / float(free.size())
	_check(max_d < 30.0 * _ppm(), "the loose drift cloud stays bounded (doesn't fly apart)")
	_check(avg_nn > 0.3 * _ppm(), "separation spreads the cloud out (members keep real spacing)")
	_check(min_pair > 0.05 * _ppm(), "no two members collapse onto the exact same point")
	_check(shoal._state == Shoal.GroupState.DRIFT, "a far-off school just drifts (never engages)")

	shoal.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_dormant_when_far() -> void:
	print("[a far school goes dormant (cheap) and wakes up when the sub nears]")
	var saved: float = GameFeel.flock.active_range_m
	GameFeel.flock.active_range_m = 40.0  # the real shipped value
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)
	var ppm := _ppm()
	var shoal := _make_shoal(sub, EnemyDef.Class.BIG, sub.global_position + Vector2(80.0 * ppm, 0))
	await _frames(10)

	_check(not shoal._active, "a far-off school is dormant")
	var a_member: Fish = shoal._first_alive()
	_check(a_member != null and not a_member.is_physics_processing(),
		"dormant members' per-frame physics is switched off (the cheap win)")

	# Still lazily drifting (position changes over time).
	var p0 := a_member.global_position
	await _frames(40)
	_check(a_member.global_position.distance_to(p0) > 2.0, "a dormant school still lazily drifts")

	# Bring the sub next to it → it wakes to full behaviour.
	sub.global_position = shoal._blob_pos()
	await _frames(5)
	_check(shoal._active, "the school wakes when the sub comes near")
	_check(a_member.is_physics_processing(), "woken members resume per-frame physics")

	GameFeel.flock.active_range_m = saved
	shoal.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_dormant_school_stays_out_of_rock() -> void:
	print("[a dormant school drifting near rock doesn't get stuck in it]")
	var saved: float = GameFeel.flock.active_range_m
	GameFeel.flock.active_range_m = 40.0  # let the far school actually go dormant
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)
	var ppm := _ppm()
	var wall := StaticBody2D.new()
	wall.collision_layer = Layers.TERRAIN
	wall.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rectshape := RectangleShape2D.new()
	rectshape.size = Vector2(12.0, 12.0) * ppm
	cs.shape = rectshape
	wall.add_child(cs)
	wall.global_position = Vector2(300.0 * ppm, 300.0 * ppm)  # far from the sub → dormant
	add_child(wall)
	await _frames(2)

	var shoal := _make_shoal(sub, EnemyDef.Class.BIG, wall.global_position + Vector2(-8.0 * ppm, 0))
	await _frames(120)  # dormant rigid drift + the periodic re-settle
	_check(not shoal._active, "precondition: the school is dormant (far from the sub)")
	var stuck := 0
	for m: Fish in shoal._members:
		m._terrain_cast.target_position = Vector2.ZERO
		m._terrain_cast.force_shapecast_update()
		if m._terrain_cast.is_colliding():
			stuck += 1
	_check(stuck == 0, "no member ends up stuck in rock while dormant beside it")

	GameFeel.flock.active_range_m = saved
	shoal.queue_free()
	wall.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_stays_below_water_surface() -> void:
	print("[the school never pins itself against the water surface]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)
	var ppm := _ppm()
	var surf := 500.0 * ppm
	var s := Shoal.new()
	s.sub = sub
	s.tier = EnemyDef.Class.BIG
	s.water_surface_y = surf      # must be set BEFORE add_child (members read it in _ready)
	s.position = Vector2(200.0 * ppm, surf + 2.0 * ppm)  # just below the surface
	add_child(s)
	# Run a good while: the roam keeps trying to wander up toward (and past) the
	# surface — exactly what used to freeze the school against it.
	await _frames(300)
	var above := 0
	for m: Fish in s._members:
		if m.global_position.y < surf - 0.5 * ppm:
			above += 1
	_check(above == 0, "no member is stuck above/at the water surface")
	_check(s._centroid(s._free_members()).y > surf, "the school stays submerged (centroid below the surface)")
	s.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_spot_stalk_charge_one_breach() -> void:
	print("[spot -> stalk (circle the sub) -> charge = EXACTLY ONE pooled breach]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)
	var ppm := _ppm()
	var rect: Rect2 = sub.hull_rects()[0]
	var hull_world := sub.to_global(rect.position + rect.size * 0.5)
	# Spawn within detect range so it engages and runs the full sequence.
	var shoal := _make_shoal(sub, EnemyDef.Class.SMALL, hull_world + Vector2(0, -10.0 * ppm))
	await _frames(2)

	var before := sub.breaches.size()
	var saw_stalk := false
	var dispersed := false
	# Generous budget: orbit one full circle (TAU / orbit_speed_rad ≈ 3.7s) + the
	# charge, at 60 fps.
	for i in 900:
		await get_tree().physics_frame
		if shoal._state == Shoal.GroupState.STALK:
			saw_stalk = true
		if shoal._state == Shoal.GroupState.DISPERSE:
			dispersed = true
			break
	_check(saw_stalk, "the school spots the sub and STALKS (circles it) before charging")
	_check(dispersed, "the school charges and then disperses")
	_check(sub.breaches.size() - before == 1,
		"the charge pools into EXACTLY ONE breach (not one per member)")

	shoal.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_charge_tracks_small_dodge() -> void:
	print("[the charge TRACKS a small dodge (within charge_track_m) and still lands]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)
	var ppm := _ppm()
	var rect: Rect2 = sub.hull_rects()[0]
	var hull_world := sub.to_global(rect.position + rect.size * 0.5)
	var shoal := _make_shoal(sub, EnemyDef.Class.SMALL, hull_world + Vector2(0, -10.0 * ppm))
	await _frames(2)

	# Commit to a charge, then jink only a few metres — well inside the track range.
	var charging := false
	for i in 900:
		await get_tree().physics_frame
		if shoal._state == Shoal.GroupState.CHARGE:
			sub.global_position += Vector2(4.0 * ppm, 0.0)  # small dodge, within charge_track_m (10m)
			charging = true
			break
	_check(charging, "precondition: committed to a charge")
	var before := sub.breaches.size()

	var hit := false
	for i in 300:
		await get_tree().physics_frame
		if sub.breaches.size() > before:
			hit = true
			break
		if shoal._state == Shoal.GroupState.DRIFT:
			break  # dispersed all the way back without landing → tracking failed
	_check(hit, "the strike ball tracks the small dodge and still breaches the hull")

	shoal.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_dodged_charge_misses() -> void:
	print("[a BIG/early dodge (past the track range) whiffs — no breach, no shove]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)
	var ppm := _ppm()
	var rect: Rect2 = sub.hull_rects()[0]
	var hull_world := sub.to_global(rect.position + rect.size * 0.5)
	var shoal := _make_shoal(sub, EnemyDef.Class.SMALL, hull_world + Vector2(0, -10.0 * ppm))
	await _frames(2)

	# Let it engage and commit to the charge, then DODGE: teleport the sub clear.
	var charging := false
	for i in 900:
		await get_tree().physics_frame
		if shoal._state == Shoal.GroupState.CHARGE:
			sub.global_position += Vector2(80.0 * ppm, 0.0)  # well outside contact range
			charging = true
			break
	_check(charging, "precondition: the school committed to a charge")
	var before := sub.breaches.size()

	var dispersed := false
	for i in 300:
		await get_tree().physics_frame
		if shoal._state == Shoal.GroupState.DISPERSE:
			dispersed = true
			break
	_check(dispersed, "the whiffed charge gives up and disperses")
	_check(sub.breaches.size() == before,
		"a dodged charge deals NO breach (it hit empty water, not the sub)")

	shoal.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_spawns_clear_of_terrain() -> void:
	print("[members that spawn overlapping rock get settled into clear water]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)
	var ppm := _ppm()
	var wall := StaticBody2D.new()
	wall.collision_layer = Layers.TERRAIN
	wall.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rectshape := RectangleShape2D.new()
	rectshape.size = Vector2(10.0, 10.0) * ppm
	cs.shape = rectshape
	wall.add_child(cs)
	var wall_pos := Vector2(300.0 * ppm, 300.0 * ppm)
	wall.global_position = wall_pos
	add_child(wall)
	await _frames(2)
	var wall_rect := Rect2(wall_pos - rectshape.size * 0.5, rectshape.size)

	# Spawn the school straddling the slab edge — members land both inside it and
	# clipping its edge (centre clear but body overlapping), the case the old
	# point-check missed.
	var shoal := _make_shoal(sub, EnemyDef.Class.BIG, wall_pos + Vector2(rectshape.size.x * 0.5, 0))
	await _frames(3)  # the one-time settle runs on the first physics frame
	var stuck := 0
	for m: Fish in shoal._members:
		m._terrain_cast.target_position = Vector2.ZERO
		m._terrain_cast.force_shapecast_update()
		if m._terrain_cast.is_colliding():
			stuck += 1
	_check(stuck == 0, "no member's body is left overlapping rock after the spawn-settle")

	shoal.queue_free()
	wall.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_avoids_terrain() -> void:
	print("[the school avoids terrain (sand/rock), not just the surface]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)
	var ppm := _ppm()
	# A rock slab on the TERRAIN layer; the shoal drifts right beside it.
	var wall := StaticBody2D.new()
	wall.collision_layer = Layers.TERRAIN
	wall.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rectshape := RectangleShape2D.new()
	rectshape.size = Vector2(8.0, 30.0) * ppm
	cs.shape = rectshape
	wall.add_child(cs)
	var wall_pos := Vector2(300.0 * ppm, 300.0 * ppm)  # far from the sub → stays DRIFT
	wall.global_position = wall_pos
	add_child(wall)
	await _frames(2)
	var wall_rect := Rect2(wall_pos - rectshape.size * 0.5, rectshape.size)

	# Spawn just left of the slab; the roam keeps nudging the school toward it.
	var shoal := _make_shoal(sub, EnemyDef.Class.BIG, wall_pos + Vector2(-7.0 * ppm, 0))
	await _frames(240)
	var inside := 0
	for m: Fish in shoal._members:
		if wall_rect.has_point(m.global_position):
			inside += 1
	_check(inside == 0, "no member ends up inside the rock slab (terrain avoidance keeps them out)")

	shoal.queue_free()
	wall.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_leader_kill_scatters_and_promotes() -> void:
	print("[leader kill -> scatter -> promote a new leader (crown moves + grows in)]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)
	var far := sub.global_position + Vector2(60.0 * _ppm(), 0)
	var shoal := _make_shoal(sub, EnemyDef.Class.BIG, far)
	await _frames(5)

	var old_leader: Fish = shoal._leader
	_check(old_leader != null and old_leader._is_leader, "a leader is crowned at spawn")

	old_leader.die()
	await _frames(2)
	_check(shoal._state == Shoal.GroupState.SCATTER, "killing the leader scatters the school in panic")

	var budget := int((GameFeel.flock.scatter_time_s + 1.5) * 60.0)
	var promoted := false
	for i in budget:
		await get_tree().physics_frame
		if shoal._leader != null and shoal._leader != old_leader:
			promoted = true
			break
	_check(promoted, "a new leader is promoted from the survivors")
	_check(is_instance_valid(shoal._leader) and shoal._leader._is_leader and not old_leader._is_leader,
		"the crown moved off the dead leader onto the new one")
	_check(shoal._leader._leader_anim < 1.0, "the promoted leader grows its crown in (animation just started)")
	_check(is_equal_approx(shoal._leader._leader_prize_mult, GameFeel.flock.leader_drop_share),
		"the promoted leader carries only the reduced prize share")

	shoal.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_thinning_triggers_flee() -> void:
	print("[thinning below the threshold -> terminal flee]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)
	var far := sub.global_position + Vector2(60.0 * _ppm(), 0)
	var shoal := _make_shoal(sub, EnemyDef.Class.SMALL, far)
	await _frames(5)
	_check(shoal._members.size() == GameFeel.flock.small_count, "Small shoal spawned small_count members")

	# Kill members until survivors reach the flee threshold.
	var to_kill := shoal._members.size() - shoal._flee_at()
	var killed := 0
	for m: Fish in shoal._members:
		if killed >= to_kill:
			break
		m.die()
		killed += 1
	await _frames(3)
	_check(shoal._state == Shoal.GroupState.FLEE,
		"thinning the school to the threshold sends the survivors into terminal flee")

	shoal.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_survives_run_reset() -> void:
	print("[after a run reset rebuilds the sub, the school keeps swimming (not frozen)]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)
	var far := sub.global_position + Vector2(60.0 * _ppm(), 0)
	var shoal := _make_shoal(sub, EnemyDef.Class.BIG, far)
	await _frames(10)

	# Reproduce World._rebuild_sub + reset_run: free the old sub, spawn a new one,
	# re-point the fish AND shoal groups at it, then reset both groups.
	sub.queue_free()
	await _frames(2)
	var sub2 := Sub.new()
	add_child(sub2)
	await _frames(2)
	get_tree().call_group("fish", "set", "sub", sub2)
	get_tree().call_group("shoal", "set", "sub", sub2)
	get_tree().call_group("fish", "reset_fish")
	get_tree().call_group("shoal", "reset_shoal")
	await _frames(2)
	_check(is_instance_valid(shoal.sub) and shoal.sub == sub2,
		"the controller re-targeted the rebuilt sub (not the freed one)")

	# Confirm the school is actually moving again, not frozen in place.
	var p0: Array[Vector2] = []
	for m: Fish in shoal._members:
		p0.append(m.global_position)
	await _frames(45)
	var moved := 0
	for i in shoal._members.size():
		if (shoal._members[i] as Fish).global_position.distance_to(p0[i]) > 1.0:
			moved += 1
	_check(moved > shoal._members.size() / 2,
		"the school keeps swimming after the rebuild (not frozen)")

	shoal.queue_free()
	sub2.queue_free()
	await _frames(2)

func _test_leader_holds_prize_members_drop_none() -> void:
	print("[leader carries the teal prize; members drop ~none]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)
	var far := sub.global_position + Vector2(60.0 * _ppm(), 0)
	var shoal := _make_shoal(sub, EnemyDef.Class.SMALL, far)
	await _frames(5)

	var member: Fish = null
	for m: Fish in shoal._members:
		if not m._is_leader:
			member = m
			break
	member.die()
	await _frames(1)
	_check(member.last_drops.is_empty(), "a plain swarm member drops little/nothing")

	var leader: Fish = shoal._leader
	var death_pos := leader.global_position
	leader.die()
	await _frames(1)
	_check(leader.last_drops.size() > 0, "the leader carries the big teal prize (currency drops)")
	# The drops must land AT the kill, not offset by the controller's position
	# (shoal members are parented to the Shoal node, not the world origin).
	var loot_near := not leader.last_drops.is_empty()
	for d in leader.last_drops:
		if d.global_position.distance_to(death_pos) > 2.0 * _ppm():
			loot_near = false
	_check(loot_near, "the leader's loot drops AT the kill (collectible), not far away")

	shoal.queue_free()
	sub.queue_free()
	get_tree().call_group("salvage", "queue_free")
	await _frames(2)
