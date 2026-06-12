extends Node

## Headless test for the salvage claw (Milestone 3, Module C).
##
## Run: godot --headless res://tests/test_claw.tscn
## The belly claw, operated from the claw room, extends down toward salvage,
## grips it on contact, reels back in, and drops it into on-board storage. It
## is now the ONLY way to collect salvage (the hull no longer auto-collects).

var _failures := 0

func _ready() -> void:
	await _test_grab_and_deposit()
	await _test_no_hull_autocollect()
	await _test_unoccupied_retracts()

	if _failures == 0:
		print("CLAW TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("CLAW TESTS FAILED: %d failing check(s)" % _failures)
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

func _new_sub() -> Sub:
	var sub := Sub.new()
	add_child(sub)
	return sub

func _find_claw(sub: Sub) -> ClawStation:
	for child in sub.get_children():
		if child is ClawStation:
			return child
	return null

func _test_grab_and_deposit() -> void:
	print("[grab + deposit]")
	var sub := _new_sub()
	sub.global_position = Vector2.ZERO
	await _frames(2)
	var claw := _find_claw(sub)
	_check(claw != null, "sub built a claw station")
	_check(claw.room_index == 4, "claw seat is in the lower claw room")

	# A scrap crate hanging below the keel, within reach of a straight-down arm.
	var reach := 2.5 * Sub.PPM
	var item := SalvageItem.make_scrap(
		sub.to_global(ClawStation.ANCHOR_LOCAL + Vector2(0, reach)))
	add_child(item)
	await _frames(2)

	# Seat an operator and drive the claw down (hold use, aim down).
	var crew := Crew.new()
	claw.enter(crew)
	var inp := PlayerInput.new()
	inp.use_held = true
	inp.move = Vector2(0, 1)

	var grabbed := false
	for i in 200:
		claw.handle_input(inp)
		if claw._held_item != null:
			grabbed = true
		await get_tree().physics_frame
		if sub.storage_scrap > 0:
			break
	_check(grabbed, "the claw gripped the salvage on contact")
	_check(sub.storage_scrap == 1, "the claw deposited the catch into storage")
	_check(not is_instance_valid(item) or item.is_queued_for_deletion(),
		"the grabbed item is removed from the world")

	sub.queue_free()
	await _frames(2)

func _test_no_hull_autocollect() -> void:
	print("[no hull auto-collect]")
	var sub := _new_sub()
	sub.global_position = Vector2.ZERO
	await _frames(2)

	# An item sitting right inside the hull — with no claw operating, it must
	# NOT be collected (Module C removed the old hull auto-collector).
	var item := SalvageItem.make_scrap(sub.global_position)
	add_child(item)
	await _frames(30)
	_check(sub.storage_scrap == 0 and sub.storage_fish == 0,
		"salvage touching the hull is NOT collected without the claw")
	_check(is_instance_valid(item) and not item.is_queued_for_deletion(),
		"the untouched item is still in the world")

	item.queue_free()
	sub.queue_free()
	await _frames(2)

func _test_unoccupied_retracts() -> void:
	print("[unoccupied parks]")
	var sub := _new_sub()
	await _frames(2)
	var claw := _find_claw(sub)
	claw.length = ClawStation.MAX_REACH  # pretend it was left extended
	await _frames(120)
	_check(claw.length <= 0.5, "an unoccupied claw retracts and parks")

	sub.queue_free()
	await _frames(2)
