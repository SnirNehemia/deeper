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
	_test_return_room_to_inventory()
	_test_return_room_refused_for_tower()
	_test_return_helm_to_inventory()
	_test_place_helm_back()
	_test_slot_price_stable_across_place_and_return()
	_test_buy_pod_into_inventory()
	_test_buy_pod_refused_when_broke()
	_test_buy_pod_refused_for_non_pod()
	_test_place_pod_happy_path()
	_test_place_pod_refused_on_non_exterior_face()
	_test_place_pod_refused_on_room_that_cant_host_it()
	_test_place_pod_refused_without_inventory()
	_test_return_pod_to_inventory()
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
	var price := SaveData.next_slot_price(pos)
	var ok := SaveData.buy_slot(pos)
	_check(ok, "buying a legal slot with enough scrap succeeds")
	_check(pos in SaveData.layout.slots, "the bought slot is now part of the layout")
	_check(SaveData.banked_scrap == 100 - price, "the slot's scrap price was deducted")
	_check(SubValidator.validate(SaveData.layout)["ok"], "the sub with the new slot still validates")

func _test_buy_slot_refused_when_broke() -> void:
	print("[too poor]")
	SaveData.reset_for_test()
	var pos: Vector2i = SaveData.layout.buyable_slot_positions()[0]
	var price := SaveData.next_slot_price(pos)
	SaveData.banked_scrap = price - 1  # one short
	var ok := SaveData.buy_slot(pos)
	_check(not ok, "buying a slot you can't afford is refused")
	_check(SaveData.layout.slots.is_empty(), "no slot was added")
	_check(SaveData.banked_scrap == price - 1, "no scrap was spent")

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
	var first := GameFeel.dock.slot_price(1, SaveData.layout.slots.size())
	SaveData.buy_slot(SaveData.layout.buyable_slot_positions()[0])
	var second := GameFeel.dock.slot_price(1, SaveData.layout.slots.size())
	_check(second > first, "owning one more slot raises the price of the next level-1 slot")

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
	_check(SaveData.layout.placements.size() == 7, "buying a room leaves the placed rooms alone")

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
	var pos := Vector2i(3, 1)  # adjacent to storage at (2,1); +x neighbor (4,1) is exterior
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
	var pos := Vector2i(3, 1)
	SaveData.buy_slot(pos)
	SaveData.buy_room("turret_room")
	# Mirrored fires -x into (2,1) = storage, which is occupied.
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

func _test_return_room_to_inventory() -> void:
	print("[return a room to inventory]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 1000
	var pos := Vector2i(3, 1)
	SaveData.buy_slot(pos)
	SaveData.buy_room("turret_room")
	SaveData.place_room("turret_room", pos, false)
	var ok := SaveData.return_room_to_inventory(pos)
	_check(ok, "returning a placed room to inventory succeeds")
	_check(pos in SaveData.layout.slots, "the cell becomes an owned empty slot again")
	_check(SaveData.layout.inventory.get("turret_room", 0) == 1,
		"the room is back in inventory")
	var still_placed := false
	for p in SaveData.layout.placements:
		if p.module_id == "turret_room" and p.grid_pos == pos:
			still_placed = true
	_check(not still_placed, "the turret room is no longer placed")

func _test_return_room_refused_for_tower() -> void:
	print("[can't return the tower]")
	SaveData.reset_for_test()
	var ok := SaveData.return_room_to_inventory(Vector2i(1, -1))  # tower
	_check(not ok, "returning the tower is refused")
	_check(SaveData.layout.placements.size() == 7, "no placement was removed")

## The helm is core but, since 2026-06-15, can be picked up and placed back
## like any other room — the dry dock just won't let the player leave with it
## in inventory (DryDock._close, covered by test_dock_shop_ui).
func _test_return_helm_to_inventory() -> void:
	print("[return the helm to inventory]")
	SaveData.reset_for_test()
	var ok := SaveData.return_room_to_inventory(Vector2i(1, 0))  # helm
	_check(ok, "the helm can be picked up like any other room")
	_check(SaveData.layout.inventory.get("helm", 0) == 1, "the helm is now in inventory")
	_check(Vector2i(1, 0) in SaveData.layout.slots,
		"the helm's old cell becomes an owned empty slot")
	var still_placed := false
	for p in SaveData.layout.placements:
		if p.module_id == "helm":
			still_placed = true
	_check(not still_placed, "the helm is no longer placed")

func _test_place_helm_back() -> void:
	print("[place the helm back]")
	SaveData.reset_for_test()
	SaveData.return_room_to_inventory(Vector2i(1, 0))
	var ok := SaveData.place_room("helm", Vector2i(1, 0), false)
	_check(ok, "the helm can be placed back into an owned slot")
	var found := false
	for p in SaveData.layout.placements:
		if p.module_id == "helm" and p.grid_pos == Vector2i(1, 0):
			found = true
	_check(found, "the helm is placed again")
	_check(SaveData.layout.inventory.get("helm", 0) == 0,
		"the helm is removed from inventory once placed")

## 2026-06-15 fix: the price of the *next* slot must depend only on how many
## slots have ever been bought, not on how many are currently sitting empty —
## placing a room into a slot or returning one to inventory must not move the
## price of other slots.
func _test_slot_price_stable_across_place_and_return() -> void:
	print("[slot price stable across place/return]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 1000
	var pos := Vector2i(3, 0)
	SaveData.buy_slot(pos)
	SaveData.buy_room("turret_room")

	var other: Vector2i = SaveData.layout.buyable_slot_positions()[0]
	var price_before := SaveData.next_slot_price(other)

	SaveData.place_room("turret_room", pos, false)
	_check(SaveData.next_slot_price(other) == price_before,
		"placing a room into a slot doesn't change the price of other slots")

	SaveData.return_room_to_inventory(pos)
	_check(SaveData.next_slot_price(other) == price_before,
		"returning a room to inventory doesn't change the price of other slots")

func _test_buy_pod_into_inventory() -> void:
	# The floodlight pod is no longer sold separately (2026-06-19,
	# DECISIONS.md round 4) — buying the Floodlight Room bundles it in.
	print("[buy a pod into inventory]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 20
	_check(not SaveData.buy_pod("floodlight_pod"),
		"the floodlight pod can no longer be bought separately")
	var cost: Dictionary = ModuleCatalog.by_id("floodlight_room").cost_bundle()
	var ok := SaveData.buy_room("floodlight_room")
	_check(ok, "buying the floodlight room with enough scrap succeeds")
	_check(SaveData.layout.inventory.get("floodlight_room", 0) == 1,
		"the bought room lands in inventory")
	_check(SaveData.layout.inventory.get("floodlight_pod", 0) == 1,
		"its bundled pod also lands in inventory")
	_check(SaveData.banked_scrap == 20 - int(cost.get("sc", 0)),
		"the bundle's scrap cost was deducted")

func _test_buy_pod_refused_when_broke() -> void:
	print("[pod too expensive]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 0
	var ok := SaveData.buy_pod("floodlight_pod")
	_check(not ok, "buying a pod you can't afford is refused")
	_check(SaveData.layout.inventory.is_empty(), "nothing was added to inventory")

func _test_buy_pod_refused_for_non_pod() -> void:
	print("[buy_pod refuses non-pods]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 1000
	_check(not SaveData.buy_pod("turret_room"), "a room isn't bought as a pod")
	_check(not SaveData.buy_pod("does_not_exist"), "an unknown id is refused, not a crash")
	_check(SaveData.banked_scrap == 1000, "no scrap spent on any refused buy")

## Buys a slot at (3,1) (adjacent to storage at (2,1)) and places a freshly
## bought Floodlight Room there — the dedicated room that can host the
## floodlight pod (M4-9). Its +x face (4,1) is exterior, its -x face (2,1) is
## storage (occupied).
func _setup_floodlight_room() -> void:
	SaveData.buy_slot(Vector2i(3, 1))
	SaveData.buy_room("floodlight_room")
	SaveData.place_room("floodlight_room", Vector2i(3, 1), false)

func _test_place_pod_happy_path() -> void:
	print("[attach a pod to an exterior face]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 1000
	_setup_floodlight_room()
	var ok := SaveData.place_pod("floodlight_pod", Vector2i(3, 1), "right")
	_check(ok, "attaching the floodlight pod to its room's exterior face succeeds")
	_check(SaveData.layout.inventory.get("floodlight_pod", 0) == 0,
		"the attached pod is removed from inventory")
	_check(SaveData.layout.pods.size() == 1, "the pod is now in the layout's pod list")
	_check(SubValidator.validate(SaveData.layout)["ok"], "the sub still validates after attaching")

func _test_place_pod_refused_on_non_exterior_face() -> void:
	print("[pod refused on a non-exterior face]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 1000
	_setup_floodlight_room()
	# The floodlight room's left face (2,1) is storage — not exterior.
	var ok := SaveData.place_pod("floodlight_pod", Vector2i(3, 1), "left")
	_check(not ok, "attaching a pod to a non-exterior face is refused")
	_check(SaveData.layout.inventory.get("floodlight_pod", 0) == 1,
		"the pod is still in inventory")
	_check(not SaveData.place_pod_violations("floodlight_pod", Vector2i(3, 1), "left").is_empty(),
		"the violation list explains why")

func _test_place_pod_refused_on_room_that_cant_host_it() -> void:
	print("[pod refused on a room that can't host it]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 1000
	SaveData.buy_room("floodlight_room")  # bundles the pod into inventory
	# Turret room's top face (2,-1) is exterior, but it isn't built to host a pod.
	var ok := SaveData.place_pod("floodlight_pod", Vector2i(2, 0), "top")
	_check(not ok, "attaching a pod to a room that can't host it is refused")
	_check(SaveData.layout.inventory.get("floodlight_pod", 0) == 1,
		"the pod is still in inventory")
	_check(not SaveData.place_pod_violations("floodlight_pod", Vector2i(2, 0), "top").is_empty(),
		"the violation list explains why")

func _test_place_pod_refused_without_inventory() -> void:
	print("[pod refused without inventory]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 1000
	_setup_floodlight_room()
	# Buying the room bundles in its pod (2026-06-19) — remove it to test the
	# "not in inventory" case on its own.
	SaveData.layout.inventory.erase("floodlight_pod")
	var ok := SaveData.place_pod("floodlight_pod", Vector2i(3, 1), "right")
	_check(not ok, "attaching a pod not owned in inventory is refused")
	_check(SaveData.layout.pods.is_empty(), "no pod was attached")

func _test_return_pod_to_inventory() -> void:
	print("[detach a pod back to inventory]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 1000
	_setup_floodlight_room()
	SaveData.place_pod("floodlight_pod", Vector2i(3, 1), "right")
	var ok := SaveData.return_pod_to_inventory(Vector2i(3, 1), "right")
	_check(ok, "detaching an attached pod succeeds")
	_check(SaveData.layout.inventory.get("floodlight_pod", 0) == 1,
		"the pod is back in inventory")
	_check(SaveData.layout.pods.is_empty(), "the pod is no longer in the layout's pod list")
	_check(not SaveData.return_pod_to_inventory(Vector2i(3, 1), "right"),
		"detaching a pod that isn't there is refused")
	_check(not SaveData.return_pod_to_inventory(Vector2i(2, 0), "top"),
		"detaching a pod that isn't there is refused")

func _test_place_room_refused_without_inventory() -> void:
	print("[no inventory]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 1000
	var pos := Vector2i(3, 1)
	SaveData.buy_slot(pos)
	var ok := SaveData.place_room("turret_room", pos, false)
	_check(not ok, "placing a room not owned in inventory is refused")
	_check(pos in SaveData.layout.slots, "the slot remains empty")
	_check(not SaveData.place_room_violations("turret_room", pos, false).is_empty(),
		"the violation list explains the room isn't in inventory")
