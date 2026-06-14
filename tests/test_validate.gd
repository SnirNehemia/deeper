extends Node

## Headless test for the M4 validation engine (Module 3,
## MODULAR_SUB_IMPLEMENTATION.md §5 + slot additions from ROOM_SYSTEM.md
## §4.1/§8). Pure data: SubValidator.validate(layout) is the single legality
## check; no UI, no pipeline.
##
## Run: godot --headless res://tests/test_validate.tscn

var _failures := 0

func _ready() -> void:
	_test_starting_layout_is_valid()
	_test_starting_layout_with_slots_is_valid()
	_test_missing_helm_or_tower()
	_test_overlapping_placements()
	_test_slot_overlapping_placement()
	_test_tower_unsupported()
	_test_disconnected_room()
	_test_turret_firing_face_blocked_vs_clear()
	_test_pod_faces()
	_test_bounds_guard()
	_test_recovery_path()

	if _failures == 0:
		print("VALIDATE TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("VALIDATE TESTS FAILED: %d failing check(s)" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok:   ", msg)
	else:
		push_error("  FAIL: " + msg)
		_failures += 1

func _test_starting_layout_is_valid() -> void:
	print("[starting layout]")
	var layout := SubLayout.starting_layout()
	var result := SubValidator.validate(layout)
	_check(result["ok"], "the starting layout (Minnow+) validates cleanly")
	_check(result["violations"].is_empty(), "no violations on the starting layout")

func _test_starting_layout_with_slots_is_valid() -> void:
	print("[starting layout + bought slots]")
	var layout := SubLayout.starting_layout()
	var candidates: Array = layout.buyable_slot_positions()
	layout.slots.append(candidates[0])
	var result := SubValidator.validate(layout)
	_check(result["ok"], "a starting layout with a bought slot still validates")

func _test_missing_helm_or_tower() -> void:
	print("[missing helm/tower]")
	var layout := SubLayout.starting_layout()
	# Drop the helm placement entirely. Since the tower now sits directly above
	# the helm (2026-06-16 layout), removing the helm also removes the
	# tower's support — this is correctly invalid (rule 3), unlike the old
	# layout where the tower sat elsewhere.
	for i in range(layout.placements.size()):
		if layout.placements[i].module_id == "helm":
			layout.placements.remove_at(i)
			break
	var result := SubValidator.validate(layout)
	_check(not result["ok"], "removing the helm from beneath the tower invalidates the layout")

	var duped_helm := SubLayout.starting_layout()
	duped_helm.placements.append(SubLayout.Placement.new("helm", Vector2i(5, 0)))
	var result_helm := SubValidator.validate(duped_helm)
	_check(not result_helm["ok"], "a layout with two helms is invalid")

	var duped := SubLayout.starting_layout()
	duped.placements.append(SubLayout.Placement.new("tower", Vector2i(5, 0)))
	var result2 := SubValidator.validate(duped)
	_check(not result2["ok"], "a layout with two towers is invalid")
	var in_inv := SubLayout.starting_layout()
	in_inv.inventory["tower"] = 1
	var result3 := SubValidator.validate(in_inv)
	_check(not result3["ok"], "the tower can never sit in inventory")

func _test_overlapping_placements() -> void:
	print("[overlapping placements]")
	var layout := SubLayout.starting_layout()
	# Stack another room directly on top of the existing helm cell (1, 0).
	layout.placements.append(SubLayout.Placement.new("storage", Vector2i(1, 0)))
	var result := SubValidator.validate(layout)
	_check(not result["ok"], "two rooms sharing a cell is invalid")

func _test_slot_overlapping_placement() -> void:
	print("[slot overlapping a placement]")
	var layout := SubLayout.starting_layout()
	# (1, 0) is the existing helm cell — buying it as a slot is illegal.
	layout.slots.append(Vector2i(1, 0))
	var result := SubValidator.validate(layout)
	_check(not result["ok"], "a slot overlapping an existing room is invalid")

func _test_tower_unsupported() -> void:
	print("[tower unsupported]")
	var layout := SubLayout.new()
	layout.placements = [
		SubLayout.Placement.new("helm", Vector2i(2, 0)),
		SubLayout.Placement.new("tower", Vector2i(1, -1)),
	]
	var result := SubValidator.validate(layout)
	_check(not result["ok"], "a tower with nothing beneath it is invalid")

func _test_disconnected_room() -> void:
	print("[disconnected room]")
	var layout := SubLayout.starting_layout()
	# Far away, touching nothing.
	layout.placements.append(SubLayout.Placement.new("storage", Vector2i(6, 4)))
	var result := SubValidator.validate(layout)
	_check(not result["ok"], "a room with no path back to the helm is invalid")

func _test_turret_firing_face_blocked_vs_clear() -> void:
	print("[turret firing face]")
	# The starting layout's bow gun is itself a placed Turret Room at (2, 0),
	# unmirrored, with its firing face at (3, 0) clear/exterior.
	var clear_layout := SubLayout.starting_layout()
	var clear_result := SubValidator.validate(clear_layout)
	_check(clear_result["ok"], "the starting layout's turret room (clear firing face) is valid")

	var blocked_layout := SubLayout.starting_layout()
	# Brick in the turret room's firing face at (3, 0).
	blocked_layout.placements.append(SubLayout.Placement.new("storage", Vector2i(3, 0)))
	var blocked_result := SubValidator.validate(blocked_layout)
	_check(not blocked_result["ok"], "a turret room with its firing face bricked in is invalid")

func _test_pod_faces() -> void:
	print("[pod faces]")
	var layout := SubLayout.starting_layout()
	# A Floodlight Room at (-1, 0) — its top face (-1, -1) is empty/exterior,
	# adjacent to the stern (engine at (0,0)), and (unlike the helm) it's
	# built to host a pod.
	layout.placements.append(SubLayout.Placement.new("floodlight_room", Vector2i(-1, 0)))
	layout.pods.append(SubLayout.PodPlacement.new("floodlight_pod", Vector2i(-1, 0), "top"))
	var result := SubValidator.validate(layout)
	_check(result["ok"], "a pod on an exterior face of a room built to host it is valid")

	# The same face, but on the turret room — which can't host a pod.
	var wrong_host := SubLayout.starting_layout()
	wrong_host.pods.append(SubLayout.PodPlacement.new("floodlight_pod", Vector2i(2, 0), "top"))
	var wrong_host_result := SubValidator.validate(wrong_host)
	_check(not wrong_host_result["ok"], "a pod on a room that can't host it is invalid")

	# Pod attached to an empty cell entirely.
	var bad_host := SubLayout.starting_layout()
	bad_host.pods.append(SubLayout.PodPlacement.new("floodlight_pod", Vector2i(6, 4), "top"))
	var bad_host_result := SubValidator.validate(bad_host)
	_check(not bad_host_result["ok"], "a pod attached to an empty cell is invalid")

	# Pod on a face that is not exterior (the helm cell sits to the right
	# of "engine" at (0,0), so engine's right face (1,0) is occupied).
	var bad_face := SubLayout.starting_layout()
	bad_face.pods.append(SubLayout.PodPlacement.new("floodlight_pod", Vector2i(0, 0), "right"))
	var bad_face_result := SubValidator.validate(bad_face)
	_check(not bad_face_result["ok"], "a pod on a non-exterior face is invalid")

	# Two pods on the same cell/face (the same Floodlight Room as above).
	var dupes := SubLayout.starting_layout()
	dupes.placements.append(SubLayout.Placement.new("floodlight_room", Vector2i(-1, 0)))
	dupes.pods.append(SubLayout.PodPlacement.new("floodlight_pod", Vector2i(-1, 0), "top"))
	dupes.pods.append(SubLayout.PodPlacement.new("floodlight_pod", Vector2i(-1, 0), "top"))
	var dupes_result := SubValidator.validate(dupes)
	_check(not dupes_result["ok"], "two pods on the same face is invalid")

func _test_bounds_guard() -> void:
	print("[bounds guard]")
	var layout := SubLayout.starting_layout()
	# Add rooms far enough away to bust MAX_CELLS (8x5), but each adjacent to
	# the previous so connectivity holds — only the bounds rule should fire.
	layout.placements.append(SubLayout.Placement.new("storage", Vector2i(3, 0)))
	layout.placements.append(SubLayout.Placement.new("claw_room", Vector2i(4, 0)))
	layout.placements.append(SubLayout.Placement.new("engine", Vector2i(5, 0)))
	layout.placements.append(SubLayout.Placement.new("storage", Vector2i(6, 0)))
	layout.placements.append(SubLayout.Placement.new("claw_room", Vector2i(7, 0)))
	layout.placements.append(SubLayout.Placement.new("engine", Vector2i(8, 0)))
	var result := SubValidator.validate(layout)
	_check(not result["ok"], "a layout wider than MAX_CELLS is invalid")

func _test_recovery_path() -> void:
	print("[recovery path]")
	var layout := SubLayout.starting_layout()
	# Break the layout: overlap a non-core room onto the claw room's cell
	# (1, 1) — a collision that doesn't touch the tower's support or the
	# helm's connectivity, so the simple "first claim wins" recovery yields
	# a fully valid layout again.
	layout.placements.append(SubLayout.Placement.new("storage", Vector2i(1, 1)))
	_check(not SubValidator.validate(layout)["ok"], "the broken layout is invalid before recovery")

	var recovered := SubValidator.recover(layout)
	var result := SubValidator.validate(recovered)
	_check(result["ok"], "the recovered layout validates")

	var helm_count := 0
	var tower_count := 0
	for p in recovered.placements:
		if p.module_id == "helm":
			helm_count += 1
		elif p.module_id == "tower":
			tower_count += 1
	_check(helm_count == 1 and tower_count == 1, "recovery keeps the core helm and tower")
	_check(recovered.inventory.get("storage", 0) >= 1,
		"recovery returns the offending non-core room to inventory")
