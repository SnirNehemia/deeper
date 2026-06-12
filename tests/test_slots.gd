extends Node

## Headless test for the M4 slot economy (Module 2, ROOM_SYSTEM.md §4.1).
## Pure data: owned empty "slots" on the layout, where new slots can be
## bought (adjacent to the existing hull, within bounds), and the
## slots-owned price escalation. No UI, no pipeline, no save I/O.
##
## Run: godot --headless res://tests/test_slots.tscn

var _failures := 0

func _ready() -> void:
	_test_starting_layout_has_no_slots()
	_test_buyable_positions_are_adjacent_and_empty()
	_test_buying_a_slot_grows_the_hull_and_its_neighbors()
	_test_bounds_guard_excludes_out_of_range_slots()
	_test_price_escalation()
	_test_serialization_round_trip()

	if _failures == 0:
		print("SLOT TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("SLOT TESTS FAILED: %d failing check(s)" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok:   ", msg)
	else:
		push_error("  FAIL: " + msg)
		_failures += 1

func _test_starting_layout_has_no_slots() -> void:
	print("[starting layout]")
	var layout := SubLayout.starting_layout()
	_check(layout.slots.is_empty(), "the starting layout has no bought-but-empty slots")
	_check(layout.occupied_cells().size() == 6,
		"occupied_cells covers all 6 starting rooms (1x1 each)")

func _test_buyable_positions_are_adjacent_and_empty() -> void:
	print("[buyable slot positions]")
	var layout := SubLayout.starting_layout()
	var occupied := layout.occupied_cells()
	var candidates: Array = layout.buyable_slot_positions()

	_check(not candidates.is_empty(), "the starting hull has at least one buyable slot position")

	var all_empty_and_adjacent := true
	for c in candidates:
		if c in occupied:
			all_empty_and_adjacent = false
		var touches_hull := false
		for n in SubLayout.neighbors(c):
			if n in occupied:
				touches_hull = true
		if not touches_hull:
			all_empty_and_adjacent = false
	_check(all_empty_and_adjacent,
		"every candidate is empty and touches an occupied cell")

	# A cell far away from the hull is never offered.
	_check(Vector2i(50, 50) not in candidates, "a far-away cell is not a buyable slot")

	# No duplicates.
	var seen: Dictionary = {}
	var has_dupes := false
	for c in candidates:
		if seen.has(c):
			has_dupes = true
		seen[c] = true
	_check(not has_dupes, "buyable slot positions has no duplicates")

func _test_buying_a_slot_grows_the_hull_and_its_neighbors() -> void:
	print("[buying a slot]")
	var layout := SubLayout.starting_layout()
	var candidates: Array = layout.buyable_slot_positions()
	var bought: Vector2i = candidates[0]

	layout.slots.append(bought)

	_check(bought in layout.occupied_cells(),
		"a bought slot becomes part of occupied_cells (the hull)")

	# Buying that slot can open up new adjacent candidates (or at least keep
	# the hull connected) — re-querying should not crash and should still
	# only return empty cells touching the (now larger) hull.
	var occupied_after := layout.occupied_cells()
	var candidates_after: Array = layout.buyable_slot_positions()
	_check(bought not in candidates_after,
		"a bought slot is no longer offered as a candidate")
	var still_valid := true
	for c in candidates_after:
		if c in occupied_after:
			still_valid = false
	_check(still_valid, "post-purchase candidates remain empty cells")

func _test_bounds_guard_excludes_out_of_range_slots() -> void:
	print("[bounds guard]")
	var layout := SubLayout.new()
	# A single room pinned at the far edge of the bounds guard: cells to its
	# "outward" side would bust MAX_CELLS and must not be offered.
	layout.placements = [SubLayout.Placement.new("helm", Vector2i(SubGrid.MAX_CELLS.x - 1, 0))]
	var candidates: Array = layout.buyable_slot_positions()
	for c in candidates:
		var min_x: int = min(c.x, SubGrid.MAX_CELLS.x - 1)
		var max_x: int = max(c.x, SubGrid.MAX_CELLS.x - 1)
		_check(max_x - min_x + 1 <= SubGrid.MAX_CELLS.x,
			"candidate %s keeps the x-span within MAX_CELLS" % c)

func _test_price_escalation() -> void:
	print("[price escalation]")
	var base := GameFeel.dock.slot_price(0)
	_check(base == GameFeel.dock.slot_base_price, "the first slot costs the base price")

	var p0 := GameFeel.dock.slot_price(0)
	var p1 := GameFeel.dock.slot_price(1)
	var p2 := GameFeel.dock.slot_price(2)
	_check(p1 > p0, "the second slot costs more than the first")
	_check(p2 > p1, "the third slot costs more than the second")

	# Linear escalation: price(n) == base * (1 + esc * n).
	var expected_p2 := int(round(GameFeel.dock.slot_base_price
		* (1.0 + GameFeel.dock.slot_escalation * 2)))
	_check(p2 == expected_p2, "escalation follows base * (1 + escalation * owned)")

func _test_serialization_round_trip() -> void:
	print("[serialization round trip]")
	var layout := SubLayout.starting_layout()
	var candidates: Array = layout.buyable_slot_positions()
	layout.slots.append(candidates[0])
	layout.slots.append(candidates[1])

	var data := layout.to_dict()
	var restored := SubLayout.from_dict(data)

	_check(restored.slots.size() == 2, "slots round-trip (count)")
	_check(restored.slots[0] == layout.slots[0] and restored.slots[1] == layout.slots[1],
		"slots round-trip (contents)")
