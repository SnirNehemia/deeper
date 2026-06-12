extends Node

## Headless test for the two-joint salvage claw (Milestone 3 rework).
##
## Run: godot --headless res://tests/test_claw.tscn
## The articulated arm (shoulder + elbow) is driven excavator-style — one stick
## axis per joint. A cage on the tip snaps shut on salvage (`use`), holds a few,
## and dumps into the storage pen (`use` again, once folded home). Storage has
## a hard cap. The hull never auto-collects.

var _failures := 0

func _ready() -> void:
	await _test_joint_controls()
	await _test_snap_and_dump()
	await _test_carry()
	await _test_cage_capacity()
	await _test_storage_cap()
	await _test_no_hull_autocollect()

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

func _make_input(move: Vector2, use_pressed: bool) -> PlayerInput:
	var inp := PlayerInput.new()
	inp.move = move
	inp.use_pressed = use_pressed
	return inp

## The cage's world position for placing test salvage right at the tip.
func _tip_world(sub: Sub, claw: ClawStation) -> Vector2:
	return sub.to_global(claw.tip_local())

func _test_joint_controls() -> void:
	print("[excavator joint controls]")
	var sub := _new_sub()
	await _frames(2)
	var claw := _find_claw(sub)
	_check(claw != null, "sub built a claw station")
	_check(claw.room_index == 4, "claw console is in the lower claw room")
	_check(claw.is_home(), "the arm starts folded at home")

	claw.shoulder_angle = 0.0
	claw.elbow_angle = 0.0
	# Hold right: the shoulder should swing (angle grows).
	for i in 20:
		claw.handle_input(_make_input(Vector2(1, 0), false))
		await get_tree().physics_frame
	_check(claw.shoulder_angle > 0.1, "Left/Right swings the shoulder joint")

	var sh := claw.shoulder_angle
	# Hold down: the elbow should bend (angle grows), shoulder unchanged.
	for i in 20:
		claw.handle_input(_make_input(Vector2(0, 1), false))
		await get_tree().physics_frame
	_check(claw.elbow_angle > 0.1, "Up/Down bends the elbow joint")
	_check(is_equal_approx(claw.shoulder_angle, sh), "the two joints move independently")

	sub.queue_free()
	await _frames(2)

func _test_snap_and_dump() -> void:
	print("[snap + dump]")
	var sub := _new_sub()
	sub.global_position = Vector2.ZERO
	await _frames(2)
	var claw := _find_claw(sub)

	# Pose the arm out (straight down, fully extended) so it's not home.
	claw.shoulder_angle = 0.0
	claw.elbow_angle = 0.0
	_check(not claw.is_home(), "an extended arm is not home")

	# Drop a scrap crate right at the cage and snap it shut.
	var item := SalvageItem.make_scrap(_tip_world(sub, claw))
	add_child(item)
	await _frames(2)
	claw.handle_input(_make_input(Vector2.ZERO, true))
	_check(claw.cage_count() == 1, "use snaps the cage shut on the salvage")
	await _frames(2)
	_check(is_instance_valid(item) and item.state == SalvageItem.State.CAGED,
		"the caught item stays alive, held inside the cage (visible)")
	_check(item.global_position.distance_to(_tip_world(sub, claw)) < 40.0,
		"the held item rides at the cage")
	_check(sub.storage_count() == 0, "nothing is stored until the catch is dumped")

	# Fold home and open the cage to drop the catch into the hold.
	claw.shoulder_angle = 0.0
	claw.elbow_angle = deg_to_rad(GameFeel.claw.elbow_limit_deg)
	_check(claw.is_home(), "folding the arm back reaches home")
	claw.handle_input(_make_input(Vector2.ZERO, true))
	_check(claw.cage_count() == 0, "use at home opens the cage")
	await _frames(2)  # the drop reparents deferred
	_check(is_instance_valid(item) and item.is_loose(),
		"the catch drops into the hold as a loose, carryable item")
	_check(item.get_parent() == sub, "the loose catch rides on the sub")
	_check(sub.storage_count() == 0, "dropping into the hold does not stow it yet")

	sub.queue_free()
	await _frames(2)

func _test_carry() -> void:
	print("[crew ferries a catch to storage]")
	var sub := _new_sub()
	await _frames(2)
	# A loose catch sitting on the claw room floor at the drop hatch.
	var item := SalvageItem.make_scrap(Vector2.ZERO)
	sub.add_child(item)
	await _frames(1)
	item.drop_into_sub(sub, Sub.HOLD_HATCH_LOCAL)
	_check(item.is_loose(), "the catch is loose in the hold")

	var crew := Crew.new()
	crew.player_index = 0
	sub.add_child(crew)
	await _frames(1)

	# Stand on the hatch and pick it up.
	crew.position = Sub.HOLD_HATCH_LOCAL + Vector2(0, -10)
	crew._carry_action()
	_check(crew.is_carrying(), "a crew on the hatch picks up the loose catch")
	_check(item.state == SalvageItem.State.CARRIED, "the item is now carried")

	# Walk to the storage pen and stow it.
	crew.position = sub.storage_pen_center()
	crew._carry_action()
	_check(not crew.is_carrying(), "stowing at the storage cage empties our hands")
	_check(sub.storage_scrap == 1, "the carried catch lands in storage")
	await _frames(2)
	_check(not is_instance_valid(item) or item.is_queued_for_deletion(),
		"the stowed item leaves the world")

	# Drop (not at storage) puts a catch back on the floor.
	var item2 := SalvageItem.make_scrap(Vector2.ZERO)
	sub.add_child(item2)
	await _frames(1)
	item2.drop_into_sub(sub, Sub.HOLD_HATCH_LOCAL)
	crew.position = Sub.HOLD_HATCH_LOCAL + Vector2(0, -10)
	crew._carry_action()
	_check(crew.is_carrying(), "picked up the second catch")
	crew.position = Vector2(60, Sub.LOWER_FLOOR_Y - 10)  # away from the pen
	crew._carry_action()
	_check(not crew.is_carrying(), "dropping away from the pen frees our hands")
	_check(item2.is_loose(), "the dropped catch is loose again on the floor")

	sub.queue_free()
	await _frames(2)

func _test_cage_capacity() -> void:
	print("[cage capacity]")
	var sub := _new_sub()
	sub.global_position = Vector2.ZERO
	await _frames(2)
	var claw := _find_claw(sub)
	claw.shoulder_angle = 0.0
	claw.elbow_angle = 0.0

	var cap: int = GameFeel.claw.cage_capacity
	# Pile more than a cageful at the tip.
	for i in cap + 2:
		add_child(SalvageItem.make_scrap(_tip_world(sub, claw)))
	await _frames(2)
	claw.handle_input(_make_input(Vector2.ZERO, true))
	_check(claw.cage_count() == cap, "one snap fills the cage to capacity, no more")
	_check(claw.cage_full(), "the cage reports full")

	sub.queue_free()
	await _frames(2)

func _test_storage_cap() -> void:
	print("[storage cap]")
	var sub := _new_sub()
	await _frames(2)
	var cap: int = GameFeel.claw.storage_capacity
	var accepted := 0
	for i in cap + 5:
		if sub.deposit_salvage(SalvageItem.Kind.SCRAP):
			accepted += 1
	_check(accepted == cap, "storage accepts exactly its capacity")
	_check(sub.storage_full(), "storage reports full at the cap")
	_check(not sub.deposit_salvage(SalvageItem.Kind.FISH), "a full pen refuses more")

	sub.queue_free()
	await _frames(2)

func _test_no_hull_autocollect() -> void:
	print("[no hull auto-collect]")
	var sub := _new_sub()
	sub.global_position = Vector2.ZERO
	await _frames(2)
	var item := SalvageItem.make_scrap(sub.global_position)
	add_child(item)
	await _frames(30)
	_check(sub.storage_count() == 0,
		"salvage touching the hull is NOT collected without working the claw")
	_check(is_instance_valid(item) and not item.is_queued_for_deletion(),
		"the untouched item stays in the world")

	item.queue_free()
	sub.queue_free()
	await _frames(2)
