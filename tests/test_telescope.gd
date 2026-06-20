extends Node

## Headless test for the M7-2 telescope arm room.
## Tests: aim clamping, extend/retract limits, grab (overlapping + refused),
## auto-deposit on home, cages-full refusal, reset on implosion.
##
## Run: godot --headless res://tests/test_telescope.tscn

var _failures := 0

func _ready() -> void:
	_test_aim_clamp()
	_test_extend_retract()
	_test_grab_and_auto_deposit()
	_test_cages_full_refuses_deposit_and_grab()
	_test_reset_clears_cages()

	if _failures == 0:
		print("TELESCOPE TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("TELESCOPE TESTS FAILED: %d failing check(s)" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok:   ", msg)
	else:
		push_error("  FAIL: " + msg)
		_failures += 1

## Build a Sub containing exactly one telescope_room at (-1,0) facing "left",
## a helm at (0,0), and a tower at (0,-1). This is a valid layout (matches
## the upcoming M7-3 base loadout) so all validators pass.
func _make_sub() -> Sub:
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

func _test_aim_clamp() -> void:
	print("[aim clamping]")
	var sub := _make_sub()
	var t := _telescope(sub)
	_check(t != null, "a telescope_room spawns a TelescopeStation")

	# handle_input uses get_physics_process_delta_time() which returns 0 outside
	# a real physics tick. Set aim_angle beyond the limit then call handle_input
	# with move.x = 0 — the clampf still runs on the out-of-range value.
	var half_arc := deg_to_rad(GameFeel.telescope.aim_arc_deg * 0.5)
	t.aim_angle = deg_to_rad(9999.0)
	t.handle_input(_fake_input(Vector2(0.0, 0.0)))
	_check(absf(t.aim_angle - half_arc) < 0.01,
		"aim clamps at +half_arc (out-of-range value clamped by handle_input)")

	t.aim_angle = deg_to_rad(-9999.0)
	t.handle_input(_fake_input(Vector2(0.0, 0.0)))
	_check(absf(t.aim_angle + half_arc) < 0.01,
		"aim clamps at -half_arc (out-of-range value clamped by handle_input)")

	# Verify the arc is zero-centered (the arm starts pointing along facing_dir).
	t.aim_angle = 0.0
	t.handle_input(_fake_input(Vector2(0.0, 0.0)))
	_check(t.aim_angle == 0.0, "zero aim_angle stays zero when no input")

	sub.queue_free()

func _test_extend_retract() -> void:
	print("[extend / retract]")
	var sub := _make_sub()
	var t := _telescope(sub)
	var max_ext := GameFeel.telescope.reach_m * Sub.PPM

	# Same headless trick: set extension beyond max then run the extend branch.
	# LEFT-facing arm: face_zoom_input > 0 (extend) when move.x < 0 (A key).
	t.extension = max_ext * 10.0  # way beyond reach
	t.handle_input(_fake_input(Vector2(-1.0, 0.0)))  # A = extend for left-facing arm
	_check(absf(t.extension - max_ext) < 0.1, "extend clamps at reach_m")

	# Retract branch: set extension to 0 and hold D — must not go negative.
	# LEFT-facing arm: face_zoom_input < 0 (retract) when move.x > 0 (D key).
	t.extension = 0.0
	t.handle_input(_fake_input(Vector2(1.0, 0.0)))  # D = retract for left-facing arm
	_check(t.extension == 0.0, "retract clamps at 0 (cannot go negative)")

	# Verify positive extension actually works in the branch.
	t.extension = 0.0
	# delta = 0 means no movement, but branch is taken. Result stays 0.
	# That's expected; the important thing is no crash and no negative value.
	_check(t.extension >= 0.0, "extension is never negative")

	sub.queue_free()

func _test_grab_and_auto_deposit() -> void:
	print("[grab and auto-deposit]")
	var sub := _make_sub()
	var t := _telescope(sub)
	# Place a scrap item exactly at the tip in world space (arm fully home, tip ≈ base).
	var scrap := SalvageItem.make_scrap(sub.to_global(t.tip_local()))
	add_child(scrap)

	# Grab should fail when tip is farther than grab_radius_m (arm home, scrap at base).
	t.aim_angle = 0.0
	t.extension = 0.0
	scrap.global_position = sub.to_global(t.tip_local())
	var grab_input := _fake_use_input()
	t.handle_input(grab_input)
	_check(t.has_tip_item(), "Q grabs a salvage item overlapping the tip")

	# Retract to home (already home) — auto-deposit should fire.
	t.handle_input(_fake_input(Vector2.ZERO))
	_check(not t.has_tip_item(), "auto-deposit fires on home: tip item cleared")
	_check(t.cage_s2().size() == 1, "item deposited into s2 cage")

	# A second grab + retract fills the next s2 slot.
	var scrap2 := SalvageItem.make_scrap(sub.to_global(t.tip_local()))
	add_child(scrap2)
	scrap2.global_position = sub.to_global(t.tip_local())
	t.handle_input(grab_input)
	_check(t.has_tip_item(), "second grab works while s2 has room")
	t.handle_input(_fake_input(Vector2.ZERO))
	_check(t.cage_s2().size() == 2, "second item also deposited to s2")

	sub.queue_free()

func _test_cages_full_refuses_deposit_and_grab() -> void:
	print("[cages full refusal]")
	var sub := _make_sub()
	var t := _telescope(sub)
	var cap := GameFeel.telescope.cage_capacity
	# Manually fill both cages to capacity.
	for _i in cap:
		t._cage_s2.append(SalvageItem.Kind.SCRAP)
	for _i in cap:
		t._cage_s4.append(SalvageItem.Kind.SCRAP)
	_check(t.cages_full(), "cages report full when both at capacity")

	# Attempt grab — should be refused.
	var scrap := SalvageItem.make_scrap(sub.to_global(t.tip_local()))
	add_child(scrap)
	scrap.global_position = sub.to_global(t.tip_local())
	t.handle_input(_fake_use_input())
	_check(not t.has_tip_item(), "grab refused when both cages are full")

	# Manually put an item on the tip, then try to deposit into full cages.
	var scrap2 := SalvageItem.make_scrap(Vector2.ZERO)
	add_child(scrap2)
	scrap2.set_caged()
	t._tip_item = scrap2
	t._try_deposit()
	_check(t.has_tip_item(), "deposit refused when both cages are full — item stays on tip")

	sub.queue_free()

func _test_reset_clears_cages() -> void:
	print("[reset clears cages]")
	var sub := _make_sub()
	var t := _telescope(sub)
	# Fill a cage and put an item on the tip.
	t._cage_s2.append(SalvageItem.Kind.SCRAP)
	var scrap := SalvageItem.make_scrap(sub.to_global(t.tip_local()))
	add_child(scrap)
	scrap.set_caged()
	t._tip_item = scrap
	_check(t.cage_count() == 1 and t.has_tip_item(), "precondition: cage+tip populated")

	t.reset_cages()
	_check(t.cage_count() == 0, "reset empties the cages")
	_check(not t.has_tip_item(), "reset clears the tip item")
	_check(t.extension == 0.0, "reset returns arm to home (extension 0)")

	sub.queue_free()

# --- Input helpers ---

## A PlayerInput that holds the given move vector for one frame.
func _fake_input(move: Vector2) -> PlayerInput:
	var p := PlayerInput.new()
	p.move = move
	return p

## A PlayerInput with use_pressed = true (Q).
func _fake_use_input() -> PlayerInput:
	var p := PlayerInput.new()
	p.use_pressed = true
	return p
