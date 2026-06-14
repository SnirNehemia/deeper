extends Node

## Headless test for the M4-7c/M4-8 dry-dock Shop + Assembly tabs (rooms into
## inventory, slot-buying on the hull blueprint, + the wallet display state).
## Drives the same key handlers the player uses; the actual spend/price logic
## lives in SaveData/ModuleCatalog and is already covered by test_shop — this
## only checks the menu wiring.
##
## Run: godot --headless res://tests/test_dock_shop_ui.tscn

var _failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveData.reset_for_test()

	var dock := DryDock.new()
	add_child(dock)

	_check(dock._mode == DryDock.Mode.LIST, "the dock opens on the Upgrades list")

	# Tab switches to the Shop tab and back.
	dock._list_key(KEY_TAB)
	_check(dock._mode == DryDock.Mode.SHOP, "Tab from the Upgrades list opens the Shop")
	_check(not dock._shop_entries.is_empty(), "the shop lists at least one entry")

	# The first entry should be the purchasable room (turret_room).
	dock._shop_index = 0
	var room_entry: Dictionary = dock._shop_entries[0]
	_check(room_entry["type"] == "room", "the first shop entry is a purchasable room")
	var def: ModuleDef = room_entry["def"]

	# Buying with too little money is refused.
	SaveData.banked_scrap = 0
	dock._shop_key(KEY_ENTER)
	_check(SaveData.layout.inventory.is_empty(), "buying with no scrap adds nothing to inventory")
	_check(dock._note != "", "an affordability note is shown")

	# Buying with enough money adds it to inventory and spends the wallet.
	var cost := def.cost_bundle()
	SaveData.banked_scrap = 100
	SaveData.banked_fish = 100
	SaveData.banked_med_carcass = 100
	SaveData.banked_large_carcass = 100
	var scrap_before := SaveData.banked_scrap
	dock._shop_key(KEY_ENTER)
	_check(SaveData.layout.inventory.get(def.id, 0) == 1,
		"buying an affordable room adds it to inventory")
	_check(SaveData.banked_scrap == scrap_before - int(cost.get("sc", 0)),
		"buying the room spent the scrap portion of its cost")

	# Tab from the Shop opens Assembly: a blueprint listing buyable slot
	# positions. Buying one grows the layout's owned slots.
	dock._shop_key(KEY_TAB)
	_check(dock._mode == DryDock.Mode.ASSEMBLY, "Tab from the Shop opens Assembly")
	_check(not dock._assembly_actions.is_empty(), "Assembly lists at least one available action")

	# The marker can pass over/rest on inert cells (the tower) — it just does
	# nothing on Enter there (2026-06-15 nav widening).
	var tower_pos := Vector2i(1, -1)
	_check(dock._assembly_cells.has(tower_pos), "the marker can stand on the tower cell")
	_check(not dock._assembly_actions.has(tower_pos), "the tower has no Assembly action")
	dock._assembly_cursor = tower_pos
	var placements_before := SaveData.layout.placements.size()
	dock._assembly_key(KEY_ENTER)
	_check(SaveData.layout.placements.size() == placements_before, "Enter on the tower does nothing")

	var slot_pos: Vector2i = Vector2i.ZERO
	var found_slot := false
	for pos in dock._assembly_actions:
		if dock._assembly_actions[pos].has("buy_slot"):
			slot_pos = pos
			found_slot = true
			break
	_check(found_slot, "Assembly lists at least one buyable slot position")

	dock._assembly_cursor = slot_pos
	var slots_before := SaveData.layout.slots.size()
	dock._assembly_key(KEY_ENTER)
	_check(SaveData.layout.slots.size() == slots_before + 1,
		"buying a slot grows the layout's owned slots")
	_check(slot_pos in SaveData.layout.slots, "the bought slot position is now owned")

	# The bought turret room is now in inventory and we own at least one empty
	# slot — Assembly should also offer a "place_room" action for it.
	var place_pos: Vector2i = Vector2i.ZERO
	var place_id := ""
	var found_place := false
	for pos in dock._assembly_actions:
		var action: Dictionary = dock._assembly_actions[pos]
		if action.has("place_room"):
			place_pos = pos
			place_id = action["place_room"][0]
			found_place = true
			break
	_check(found_place, "Assembly offers placing the inventory room into a slot")

	if found_place:
		dock._assembly_cursor = place_pos
		var inv_before := int(SaveData.layout.inventory.get(place_id, 0))
		dock._assembly_key(KEY_ENTER)
		var placed := false
		for p in SaveData.layout.placements:
			if p.module_id == place_id and p.grid_pos == place_pos:
				placed = true
		if placed:
			_check(place_pos not in SaveData.layout.slots,
				"placing a room consumes the owned slot")
			_check(int(SaveData.layout.inventory.get(place_id, 0)) == inv_before - 1,
				"placing a room removes it from inventory")
		else:
			# Placement was refused (e.g. firing face blocked) — try mirroring.
			dock._assembly_cursor = place_pos
			dock._assembly_key(KEY_M)
			dock._assembly_key(KEY_ENTER)
			for p in SaveData.layout.placements:
				if p.module_id == place_id and p.grid_pos == place_pos:
					placed = true
			_check(placed, "placing the room (mirrored if needed) succeeds")

		# The placed room is now an owned-cell with a "return_room" action —
		# Enter there picks it back up into inventory (2026-06-14 nav rework).
		if placed:
			dock._assembly_cursor = place_pos
			_check(dock._assembly_actions.get(place_pos, {}).has("return_room"),
				"Assembly offers returning the placed room to inventory")
			dock._assembly_key(KEY_ENTER)
			_check(int(SaveData.layout.inventory.get(place_id, 0)) == inv_before,
				"returning the room to inventory restores it")
			_check(place_pos in SaveData.layout.slots,
				"returning the room frees its cell back into an owned slot")

	# The helm can be picked up like any other room (2026-06-15) — but the
	# dock refuses to close while it's sitting in inventory.
	dock._mode = DryDock.Mode.ASSEMBLY
	dock._rebuild_assembly_entries()
	var helm_pos := Vector2i(2, 0)
	dock._assembly_cursor = helm_pos
	_check(dock._assembly_actions.get(helm_pos, {}).has("return_room"),
		"Assembly offers returning the helm to inventory")
	dock._assembly_key(KEY_ENTER)
	_check(SaveData.layout.inventory.get("helm", 0) == 1, "the helm is now in inventory")
	dock._assembly_key(KEY_ESCAPE)
	_check(get_tree().paused, "the dock refuses to close without the helm placed")
	_check(dock._note != "", "a note explains why the dock won't close")

	# Place the helm back — now closing is allowed again. (Other rooms may
	# also be in inventory by now, so go straight to SaveData rather than
	# relying on the UI's first-in-inventory pick for this slot.)
	_check(dock._assembly_actions.get(helm_pos, {}).has("place_room"),
		"Assembly offers placing a room back into the helm's old slot")
	_check(SaveData.place_room("helm", helm_pos, false), "the helm can be placed back")
	_check(SaveData.layout.inventory.get("helm", 0) == 0, "the helm is placed back")
	dock._rebuild_assembly_entries()

	# Tab returns to the Upgrades list.
	dock._assembly_key(KEY_TAB)
	_check(dock._mode == DryDock.Mode.LIST, "Tab from Assembly returns to the Upgrades list")

	# Esc closes from any tab.
	dock._list_key(KEY_TAB)      # Shop
	dock._shop_key(KEY_TAB)      # Assembly
	dock._assembly_key(KEY_ESCAPE)
	await get_tree().process_frame
	_check(not get_tree().paused, "Esc from Assembly unpauses and closes the dock")

	SaveData.reset_for_test()
	if _failures == 0:
		print("DOCK SHOP UI TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("DOCK SHOP UI TESTS FAILED: %d failing check(s)" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok:   ", msg)
	else:
		push_error("  FAIL: " + msg)
		_failures += 1
