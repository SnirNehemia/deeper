extends Node

## Headless test for the M4 dry-dock shop purchase logic (Module 7, part 1:
## the slot economy spend — ROOM_SYSTEM.md §4.1, MODULAR_SUB_IMPLEMENTATION.md
## §6/§8). Buying a slot deducts escalating scrap, grows the layout, and
## persists; illegal positions and insufficient scrap are refused. No UI here —
## these are the controller functions the keyboard shop will call.
##
## Run: godot --headless res://tests/test_shop.tscn

var _failures := 0

func _ready() -> void:
	_test_buy_slot_happy_path()
	_test_buy_slot_refused_when_broke()
	_test_buy_slot_refused_for_illegal_position()
	_test_price_escalates_with_owned_slots()
	_test_purchase_persists()
	_test_buy_room_into_inventory()
	_test_buy_room_refused_when_broke()
	_test_buy_room_refused_for_core_or_unknown()
	_test_multi_resource_cost()
	_test_place_room_happy_path()
	_test_place_room_refused_when_firing_face_blocked()
	_test_place_room_refused_without_slot()
	_test_place_room_refused_without_inventory()
	SaveData.reset_for_test()

	if _failures == 0:
		print("SHOP TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("SHOP TESTS FAILED: %d failing check(s)" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok:   ", msg)
	else:
		push_error("  FAIL: " + msg)
		_failures += 1

func _test_buy_slot_happy_path() -> void:
	print("[buy a slot]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 100
	var pos: Vector2i = SaveData.layout.buyable_slot_positions()[0]
	var price := SaveData.next_slot_price()
	var ok := SaveData.buy_slot(pos)
	_check(ok, "buying a legal slot with enough scrap succeeds")
	_check(pos in SaveData.layout.slots, "the bought slot is now part of the layout")
	_check(SaveData.banked_scrap == 100 - price, "the slot's scrap price was deducted")
	_check(SubValidator.validate(SaveData.layout)["ok"], "the sub with the new slot still validates")

func _test_buy_slot_refused_when_broke() -> void:
	print("[too poor]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = SaveData.next_slot_price() - 1  # one short
	var pos: Vector2i = SaveData.layout.buyable_slot_positions()[0]
	var ok := SaveData.buy_slot(pos)
	_check(not ok, "buying a slot you can't afford is refused")
	_check(SaveData.layout.slots.is_empty(), "no slot was added")
	_check(SaveData.banked_scrap == SaveData.next_slot_price() - 1, "no scrap was spent")

func _test_buy_slot_refused_for_illegal_position() -> void:
	print("[illegal position]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 100
	# A cell far from the hull is not a buyable slot.
	var ok := SaveData.buy_slot(Vector2i(50, 50))
	_check(not ok, "buying a slot not adjacent to the hull is refused")
	_check(SaveData.layout.slots.is_empty(), "no slot was added")
	_check(SaveData.banked_scrap == 100, "no scrap was spent")

func _test_price_escalates_with_owned_slots() -> void:
	print("[price escalation]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 1000
	var first := SaveData.next_slot_price()
	SaveData.buy_slot(SaveData.layout.buyable_slot_positions()[0])
	var second := SaveData.next_slot_price()
	_check(second > first, "the second slot costs more than the first")

func _test_purchase_persists() -> void:
	print("[persistence]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 100
	var pos: Vector2i = SaveData.layout.buyable_slot_positions()[0]
	SaveData.buy_slot(pos)
	var scrap_after := SaveData.banked_scrap

	# Reload from disk.
	SaveData.banked_scrap = 0
	SaveData.layout = SubLayout.new()
	SaveData.load_data()
	_check(pos in SaveData.layout.slots, "the bought slot survives a save/reload")
	_check(SaveData.banked_scrap == scrap_after, "the post-purchase scrap survives a save/reload")

func _test_buy_room_into_inventory() -> void:
	print("[buy a room into inventory]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 20
	var cost: Dictionary = ModuleCatalog.by_id("turret_room").cost_bundle()
	var ok := SaveData.buy_room("turret_room")
	_check(ok, "buying the turret room with enough scrap succeeds")
	_check(SaveData.layout.inventory.get("turret_room", 0) == 1,
		"the bought room lands in inventory (not placed yet)")
	_check(SaveData.banked_scrap == 20 - int(cost.get("sc", 0)),
		"the room's scrap cost was deducted")
	# Buying a room does NOT place it — placements are unchanged (that's M4-8).
	_check(SaveData.layout.placements.size() == 6, "buying a room leaves the placed rooms alone")

func _test_buy_room_refused_when_broke() -> void:
	print("[room too expensive]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 0
	var ok := SaveData.buy_room("turret_room")
	_check(not ok, "buying a room you can't afford is refused")
	_check(SaveData.layout.inventory.is_empty(), "nothing was added to inventory")

func _test_buy_room_refused_for_core_or_unknown() -> void:
	print("[core / unknown rooms]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 1000
	_check(not SaveData.buy_room("helm"), "the core helm can't be bought")
	_check(not SaveData.buy_room("tower"), "the core tower can't be bought")
	_check(not SaveData.buy_room("floodlight_pod"), "a pod isn't bought as a room (M4-9)")
	_check(not SaveData.buy_room("does_not_exist"), "an unknown id is refused, not a crash")
	_check(SaveData.banked_scrap == 1000, "no scrap spent on any refused buy")

func _test_multi_resource_cost() -> void:
	print("[multi-resource affordability]")
	SaveData.reset_for_test()
	var cost := {"sc": 2, "s_ca": 3, "m_ca": 1}
	SaveData.banked_scrap = 2
	SaveData.banked_fish = 3
	SaveData.banked_med_carcass = 0   # short one medium carcass
	_check(not SaveData.can_afford_cost(cost), "missing one resource tier => can't afford")
	SaveData.banked_med_carcass = 1
	_check(SaveData.can_afford_cost(cost), "all tiers covered => can afford")

func _test_place_room_happy_path() -> void:
	print("[place a room]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 1000
	var pos := Vector2i(3, 0)  # adjacent to helm at (2,0); +x neighbor (4,0) is exterior
	SaveData.buy_slot(pos)
	SaveData.buy_room("turret_room")
	var ok := SaveData.place_room("turret_room", pos, false)
	_check(ok, "placing the turret room unmirrored (firing face clear) succeeds")
	_check(pos not in SaveData.layout.slots, "the slot is consumed by the placement")
	var found := false
	for p in SaveData.layout.placements:
		if p.module_id == "turret_room" and p.grid_pos == pos:
			found = true
	_check(found, "the turret room is now placed at the slot's position")
	_check(SaveData.layout.inventory.get("turret_room", 0) == 0,
		"the placed room is removed from inventory")
	_check(SubValidator.validate(SaveData.layout)["ok"], "the sub still validates after placement")

func _test_place_room_refused_when_firing_face_blocked() -> void:
	print("[firing face blocked]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 1000
	var pos := Vector2i(3, 0)
	SaveData.buy_slot(pos)
	SaveData.buy_room("turret_room")
	# Mirrored fires -x into (2,0) = helm, which is occupied.
	var ok := SaveData.place_room("turret_room", pos, true)
	_check(not ok, "placing the turret room mirrored (firing face blocked) is refused")
	_check(pos in SaveData.layout.slots, "the slot is still empty")
	_check(SaveData.layout.inventory.get("turret_room", 0) == 1,
		"the room is still in inventory")
	_check(not SaveData.place_room_violations("turret_room", pos, true).is_empty(),
		"the violation list explains why")

func _test_place_room_refused_without_slot() -> void:
	print("[no slot]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 1000
	SaveData.buy_room("turret_room")
	var ok := SaveData.place_room("turret_room", Vector2i(3, 0), false)
	_check(not ok, "placing a room at a position with no owned slot is refused")
	_check(SaveData.layout.inventory.get("turret_room", 0) == 1,
		"the room remains in inventory")
	_check(not SaveData.place_room_violations("turret_room", Vector2i(3, 0), false).is_empty(),
		"the violation list explains there's no slot there")

func _test_place_room_refused_without_inventory() -> void:
	print("[no inventory]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 1000
	var pos := Vector2i(3, 0)
	SaveData.buy_slot(pos)
	var ok := SaveData.place_room("turret_room", pos, false)
	_check(not ok, "placing a room not owned in inventory is refused")
	_check(pos in SaveData.layout.slots, "the slot remains empty")
	_check(not SaveData.place_room_violations("turret_room", pos, false).is_empty(),
		"the violation list explains the room isn't in inventory")
