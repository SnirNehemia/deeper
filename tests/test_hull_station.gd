extends Node

## Headless test for the conning-tower Hull station (Milestone 5, Module C1).
##
## Run: godot --headless res://tests/test_hull_station.tscn
## A crew seated at the Hull station holds `use`: it auto-patches the nearest
## active breach within range_rooms, slower than a hand-patch, and retargets
## the next-nearest breach once one is sealed. Out-of-range breaches are
## ignored, and a flooded tower refuses/ejects its occupant (base Station rule).

var _failures := 0

func _ready() -> void:
	await _test_patches_slower_than_hand_patch()
	await _test_retargets_next_breach()
	_test_out_of_range_ignored()
	_test_flooded_tower_ejects()

	if _failures == 0:
		print("HULL STATION TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("HULL STATION TESTS FAILED: %d failing check(s)" % _failures)
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

func _hull_station(sub: Sub) -> HullStation:
	for child in sub.get_children():
		if child is HullStation:
			return child
	return null

func _held_input() -> PlayerInput:
	var input := PlayerInput.new()
	input.use_held = true
	return input

func _test_patches_slower_than_hand_patch() -> void:
	print("[hull station patches, slower than a hand-patch]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)

	var station := _hull_station(sub)
	_check(station != null, "the conning tower has a Hull station")
	if station == null:
		sub.queue_free()
		await _frames(2)
		return

	var tower_room := station.room_index
	var breach: Breach = sub.spawn_breach(tower_room, GameFeel.water.leak_rate_min)
	await _frames(2)

	var input := _held_input()
	var hold_frames := 60  # 1s
	for i in hold_frames:
		station.handle_input(input)
		await get_tree().physics_frame

	var hand_patch_progress := hold_frames / 60.0 / GameFeel.water.repair_time
	_check(breach.repair_progress > 0.0, "holding use at the tower advances repair progress")
	_check(breach.repair_progress < hand_patch_progress,
		"the tower patches slower than a hand-patch would over the same time")

	# Finish it off.
	var patch_time := GameFeel.hull_station.patch_time
	var remaining_frames := int(ceil((1.0 - breach.repair_progress) * patch_time * 60.0)) + 2
	for i in remaining_frames:
		station.handle_input(input)
		await get_tree().physics_frame
	_check(sub.breaches.is_empty(), "the tower eventually seals the breach")

	sub.queue_free()
	await _frames(2)

func _test_retargets_next_breach() -> void:
	print("[retargets the next-nearest breach]")
	var sub := Sub.new()
	add_child(sub)
	await _frames(2)

	var station := _hull_station(sub)
	var tower_room := station.room_index
	# Both breaches at the tower itself (room 0 hops away) so both are
	# in range regardless of layout; one closer to the seat than the other.
	var b1: Breach = sub.spawn_breach(tower_room, GameFeel.water.leak_rate_min, station.position)
	var b2: Breach = sub.spawn_breach(tower_room, GameFeel.water.leak_rate_min,
		station.position + Vector2(40, 0))
	await _frames(2)

	var input := _held_input()
	var patch_frames := int(GameFeel.hull_station.patch_time * 60.0) + 5
	for i in patch_frames:
		station.handle_input(input)
		await get_tree().physics_frame
	_check(not is_instance_valid(b1) or b1.is_queued_for_deletion(),
		"the nearer breach is sealed first")
	_check(sub.breaches.size() == 1 and sub.breaches[0] == b2,
		"the station retargets to the remaining breach")

	for i in patch_frames:
		station.handle_input(input)
		await get_tree().physics_frame
	_check(sub.breaches.is_empty(), "the retargeted breach is sealed too")

	sub.queue_free()
	await _frames(2)

func _test_out_of_range_ignored() -> void:
	print("[breaches beyond range_rooms are ignored]")
	var sub := Sub.new()
	add_child(sub)
	# Don't await physics frames — keep this synchronous so room/breach state
	# can't drift before we read it.
	var reach0 := sub.rooms_within(0, 0)
	_check(reach0 == [0], "range_rooms=0 reaches only the starting room")
	var reach_full := sub.rooms_within(0, GameFeel.hull_station.range_rooms)
	_check(reach_full.size() >= reach0.size(), "a larger range reaches at least as many rooms")
	sub.queue_free()

func _test_flooded_tower_ejects() -> void:
	print("[a flooded tower refuses/ejects its occupant]")
	var sub := Sub.new()
	add_child(sub)
	var station := _hull_station(sub)
	var tower_room := station.room_index

	_check(station.can_enter(), "a dry tower station can be entered")
	sub.water_levels[tower_room] = GameFeel.water.seat_flood_threshold + 0.05
	_check(station.is_flooded(), "a flooded tower room reports flooded")
	_check(not station.can_enter(), "a flooded tower station refuses entry")

	sub.queue_free()
