extends Node

## Headless test for the M4 geometry compiler (Module 4, part 1:
## MODULAR_SUB_IMPLEMENTATION.md §4 stages 1-2 + ROOM_SYSTEM.md §2-3). Pure
## data: SubGeometry.build(layout) -> room rects, auto-doorways, parity-placed
## ladders. No scene nodes, no rendering.
##
## Run: godot --headless res://tests/test_geometry.tscn

var _failures := 0

func _ready() -> void:
	_test_room_count_and_indices()
	_test_rooms_are_centered()
	_test_cell_size()
	_test_doors_match_horizontal_adjacency()
	_test_ladders_match_vertical_adjacency()
	_test_ladder_parity_sides()
	_test_sections_bake_to_offsets()
	_test_slots_are_not_rooms_but_count_for_centering()
	_test_connections_topology()

	if _failures == 0:
		print("GEOMETRY TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("GEOMETRY TESTS FAILED: %d failing check(s)" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok:   ", msg)
	else:
		push_error("  FAIL: " + msg)
		_failures += 1

func _room_at(geo: SubGeometry, cell: Vector2i) -> SubGeometry.Room:
	for room in geo.rooms:
		if room.cell == cell:
			return room
	return null

func _test_room_count_and_indices() -> void:
	print("[rooms]")
	var geo := SubGeometry.build(SubLayout.starting_layout())
	_check(geo.rooms.size() == 5, "the M11 base sub compiles to 5 rooms")  ## floodlight_room added
	# Water indices are the placement order, 0..4, unique.
	var seen: Dictionary = {}
	for room in geo.rooms:
		seen[room.water_index] = true
	_check(seen.size() == 5, "every room has a distinct water index")
	_check(geo.index_at(Vector2i(1, 0)) == _room_at(geo, Vector2i(1, 0)).water_index,
		"index_at agrees with the room's water index")
	_check(geo.index_at(Vector2i(9, 9)) == -1, "an empty cell has no room index")

func _test_rooms_are_centered() -> void:
	print("[centering]")
	var geo := SubGeometry.build(SubLayout.starting_layout())
	# The occupied bounding box (3 wide x 2 tall: x in [-1..1], y in [-1..0])
	# centers on the origin, so the rects' combined bbox is symmetric.
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for room in geo.rooms:
		min_p = min_p.min(room.rect.position)
		max_p = max_p.max(room.rect.position + room.rect.size)
	var center := (min_p + max_p) * 0.5
	_check(is_equal_approx(center.x, 0.0) and is_equal_approx(center.y, 0.0),
		"the room bounding box is centered on the sub origin")

func _test_cell_size() -> void:
	print("[cell size]")
	var geo := SubGeometry.build(SubLayout.starting_layout())
	var helm := _room_at(geo, Vector2i(0, 0))
	_check(is_equal_approx(helm.rect.size.x, SubGrid.CELL_W_PX), "a room is one cell wide (3.75m)")
	_check(is_equal_approx(helm.rect.size.y, SubGrid.CELL_H_PX), "a room is one cell tall (3.0m)")

func _test_doors_match_horizontal_adjacency() -> void:
	print("[doors]")
	var geo := SubGeometry.build(SubLayout.starting_layout())
	# Horizontal neighbours: floodlight_room(-2,0)-telescope_room(-1,0),
	# telescope_room(-1,0)-helm(0,0), helm(0,0)-bullet_room(1,0) = 3 doorways.
	_check(geo.doors.size() == 3, "three doorways (the horizontally adjacent room pairs)")
	# A door sits on the shared wall between its two cells.
	var found := false
	for door in geo.doors:
		if door.a_cell == Vector2i(-1, 0) and door.b_cell == Vector2i(0, 0):
			found = true
			var left := _room_at(geo, Vector2i(-1, 0))
			_check(is_equal_approx(door.wall_x, left.rect.position.x + left.rect.size.x),
				"the telescope_room-helm doorway is on their shared wall")
	_check(found, "there is a telescope_room<->helm doorway")

func _test_ladders_match_vertical_adjacency() -> void:
	print("[ladders]")
	var geo := SubGeometry.build(SubLayout.starting_layout())
	# Vertical neighbours: tower(0,-1)-helm(0,0) = 1 ladder.
	_check(geo.ladders.size() == 1, "one ladder (the vertically stacked room pair)")
	var pairs: Array = []
	for ladder in geo.ladders:
		pairs.append([ladder.upper_cell, ladder.lower_cell])
	_check([Vector2i(0, -1), Vector2i(0, 0)] in pairs, "tower<->helm ladder exists")

func _test_ladder_parity_sides() -> void:
	print("[ladder parity]")
	# floor number counts from the top row (tower at y=-1 = floor 1).
	_check(SubGeometry.ladder_section(1) == 1, "floor 1 (odd) -> s1")
	_check(SubGeometry.ladder_section(2) == 5, "floor 2 (even) -> s5")
	_check(SubGeometry.ladder_section(3) == 1, "floor 3 (odd) -> s1")

	var geo := SubGeometry.build(SubLayout.starting_layout())
	for ladder in geo.ladders:
		if ladder.upper_cell == Vector2i(0, -1):
			_check(ladder.section == 1, "tower's floor (1, odd) puts its ladder on s1")

func _test_sections_bake_to_offsets() -> void:
	print("[section baking]")
	# s1 center sits half a section in from the left; s5 half a section from
	# the right. They are baked to x-offsets here and never exposed as indices
	# downstream (ROOM_SYSTEM.md §8 invariant — checked by there being no
	# section field on Room).
	var left := 0.0
	_check(is_equal_approx(SubGeometry.section_center_x(left, 1), 0.5 * SubGeometry.SECTION_W),
		"s1 bakes to half a section in from the left wall")
	_check(is_equal_approx(SubGeometry.section_center_x(left, 5),
			SubGrid.CELL_W_PX - 0.5 * SubGeometry.SECTION_W),
		"s5 bakes to half a section in from the right wall")
	_check(is_equal_approx(SubGeometry.SECTION_W * 5, SubGrid.CELL_W_PX),
		"five baked sections span the cell")

func _test_slots_are_not_rooms_but_count_for_centering() -> void:
	print("[slots]")
	var layout := SubLayout.starting_layout()
	# Buy a slot off the bow end so it shifts the bounding box.
	var candidates: Array = layout.buyable_slot_positions()
	# Pick a candidate to the right of the helm if available, else the first.
	var bought: Vector2i = candidates[0]
	for c in candidates:
		if c.x > bought.x:
			bought = c
	layout.slots.append(bought)
	var geo := SubGeometry.build(layout)
	_check(geo.rooms.size() == 5, "a bought-but-empty slot is not a generated room")
	# The slot widened/shifted the bounding box, so the box now spans the slot.
	_check(geo.grid_max.x >= bought.x and geo.grid_min.x <= bought.x,
		"the slot is inside the geometry's bounding box (counts as hull)")

func _test_connections_topology() -> void:
	print("[connections]")
	var geo := SubGeometry.build(SubLayout.starting_layout())
	var conns := geo.connections()
	_check(conns.size() == 4, "four water connections (3 doors + 1 ladder)")
	var doors := 0
	var ladders := 0
	for c in conns:
		if c["kind"] == "door":
			doors += 1
		elif c["kind"] == "ladder":
			ladders += 1
	_check(doors == 3 and ladders == 1, "connections split 3 doors / 1 ladder")
