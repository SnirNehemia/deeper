extends Node

## Headless test for the M4 grid + layout data model (Module 1). Pure data:
## the catalog, the Layout placements/pods/inventory, serialization
## round-tripping, and the starting "Minnow+" layout's contents.
##
## Run: godot --headless res://tests/test_layout.tscn

var _failures := 0

func _ready() -> void:
	_test_grid_constants()
	_test_catalog()
	_test_footprints()
	_test_starting_layout()
	_test_serialization_round_trip()

	if _failures == 0:
		print("LAYOUT TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("LAYOUT TESTS FAILED: %d failing check(s)" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok:   ", msg)
	else:
		push_error("  FAIL: " + msg)
		_failures += 1

func _test_grid_constants() -> void:
	print("[grid constants]")
	_check(is_equal_approx(SubGrid.CELL_W_PX, SubGrid.CELL_W_M * GameFeel.PIXELS_PER_METER),
		"cell width in px matches 3.75m at the locked scale")
	_check(is_equal_approx(SubGrid.CELL_H_PX, SubGrid.CELL_H_M * GameFeel.PIXELS_PER_METER),
		"cell height in px matches 3.0m at the locked scale")
	_check(is_equal_approx(SubGrid.SECTION_W_M * 5, SubGrid.CELL_W_M),
		"five 0.75m sections span the cell width")
	_check(SubGrid.MAX_CELLS.x > 0 and SubGrid.MAX_CELLS.y > 0, "a bounds guard is defined")

func _test_catalog() -> void:
	print("[module catalog]")
	var ids := ["helm", "tower", "claw_room", "storage",
		"turret_room", "bullet_room", "floodlight_pod"]
	for id in ids:
		var def := ModuleCatalog.by_id(id)
		_check(def != null, "catalog has a '%s' module" % id)
		_check(def.id == id, "'%s' def reports its own id" % id)
	_check(ModuleCatalog.by_id("helm").is_core, "helm is core")
	_check(ModuleCatalog.by_id("tower").is_core, "tower is core")
	_check(not ModuleCatalog.by_id("storage").is_core, "storage is not core")
	_check(ModuleCatalog.by_id("turret_room").has_firing_face,
		"the turret room has a firing face")
	_check(ModuleCatalog.by_id("floodlight_pod").is_pod, "the floodlight is a pod")
	_check(ModuleCatalog.by_id("engine") == null,
		"engine module is retired — by_id returns null")
	_check(ModuleCatalog.by_id("does_not_exist") == null,
		"an unknown id returns null, not a crash")

func _test_footprints() -> void:
	print("[footprints]")
	_check(ModuleCatalog.by_id("helm").footprint == Vector2i(1, 1), "helm is 1x1")
	_check(ModuleCatalog.by_id("tower").footprint == Vector2i(1, 1), "tower is 1x1")
	_check(ModuleCatalog.by_id("claw_room").footprint == Vector2i(1, 1), "claw_room is 1x1")

	var p := SubLayout.Placement.new("helm", Vector2i(4, 0))
	var cells: Array = SubLayout.placement_cells(p)
	_check(cells.size() == 1, "a 1x1 placement occupies 1 cell")
	_check(Vector2i(4, 0) in cells, "a 1x1 placement at (4,0) occupies (4,0)")

func _test_starting_layout() -> void:
	print("[starting layout]")
	var layout := SubLayout.starting_layout()
	_check(layout.placements.size() == 4,
		"the M7 base sub has 4 placed modules (claw_room, helm, bullet_room, tower)")

	var ids: Array = []
	for p in layout.placements:
		ids.append(p.module_id)
	for id in ["helm", "tower", "claw_room", "bullet_room"]:
		_check(id in ids, "the starting layout includes a '%s'" % id)

	# Every placed module's id resolves in the catalog.
	for p in layout.placements:
		_check(ModuleCatalog.by_id(p.module_id) != null,
			"placement '%s' resolves in the catalog" % p.module_id)

	# Tower sits directly above the helm (helm at (0,0), tower at (0,-1)).
	var tower_pos := Vector2i.ZERO
	var helm_pos := Vector2i.ZERO
	for p in layout.placements:
		if p.module_id == "tower":
			tower_pos = p.grid_pos
		elif p.module_id == "helm":
			helm_pos = p.grid_pos
	_check(tower_pos == helm_pos + Vector2i(0, -1),
		"the tower sits directly above the helm")

	_check(layout.pods.is_empty(), "the starting layout has no pods")
	_check(layout.inventory.is_empty(), "the starting layout has an empty inventory")

	# Within the bounds guard.
	var min_pos := Vector2i(999, 999)
	var max_pos := Vector2i(-999, -999)
	for p in layout.placements:
		for cell in SubLayout.placement_cells(p):
			min_pos = Vector2i(min(min_pos.x, cell.x), min(min_pos.y, cell.y))
			max_pos = Vector2i(max(max_pos.x, cell.x), max(max_pos.y, cell.y))
	var span := max_pos - min_pos + Vector2i.ONE
	_check(span.x <= SubGrid.MAX_CELLS.x and span.y <= SubGrid.MAX_CELLS.y,
		"the starting layout fits inside the bounds guard")

func _test_serialization_round_trip() -> void:
	print("[serialization round trip]")
	var layout := SubLayout.starting_layout()
	layout.inventory["floodlight_pod"] = 2
	layout.pods.append(SubLayout.PodPlacement.new("floodlight_pod", Vector2i(0, 0), "bottom"))

	var data := layout.to_dict()
	var restored := SubLayout.from_dict(data)

	_check(restored.placements.size() == layout.placements.size(),
		"placements round-trip (count)")
	var same_placements := true
	for i in layout.placements.size():
		var a := layout.placements[i]
		var b := restored.placements[i]
		if a.module_id != b.module_id or a.grid_pos != b.grid_pos or a.facing != b.facing:
			same_placements = false
	_check(same_placements, "placements round-trip (contents)")

	_check(restored.pods.size() == 1, "pods round-trip (count)")
	_check(restored.pods[0].pod_id == "floodlight_pod"
		and restored.pods[0].host_cell == Vector2i(0, 0)
		and restored.pods[0].face == "bottom", "pods round-trip (contents)")

	_check(restored.inventory.get("floodlight_pod", 0) == 2, "inventory round-trips")
