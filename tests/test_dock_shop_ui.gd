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

	_check(dock._mode == DryDock.Mode.SHOP, "the dock opens on the Shop")
	_check(not dock._shop_entries.is_empty(), "the shop lists at least one entry")

	# The first entry should be the purchasable room (turret_room); pods (e.g.
	# the floodlight pod, M4-9) are listed too, further down.
	dock._shop_index = 0
	var room_entry: Dictionary = dock._shop_entries[0]
	_check(room_entry["type"] == "room", "the first shop entry is a purchasable room")
	var def: ModuleDef = room_entry["def"]

	# The floodlight pod is no longer sold separately (2026-06-19): buying the
	# Floodlight Room bundles it in, so purchasable_pods() is now empty.
	var found_pod := false
	for entry in dock._shop_entries:
		if entry["type"] == "pod":
			found_pod = true
	_check(not found_pod, "the shop no longer lists a separately purchasable pod")

	# Buying with too little money is refused.
	SaveData.banked_scrap = 0
	dock._shop_key(KEY_ENTER)
	_check(SaveData.layout.inventory.is_empty(), "buying with no scrap adds nothing to inventory")
	_check(dock._note != "", "an affordability note is shown")

	# Buying with enough money adds it to inventory and spends the wallet.
	var cost := def.cost_bundle()
	SaveData.banked_scrap = 100
	for code in cost:
		if code != "sc":
			SaveData.banked_currency[code] = 100
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
	# nothing on interact there (2026-06-15 nav widening).
	var tower_pos := Vector2i(1, -1)
	_check(dock._assembly_cells.has(tower_pos), "the marker can stand on the tower cell")
	_check(not dock._assembly_actions.has(tower_pos), "the tower has no Assembly action")
	dock._assembly_cursor = tower_pos
	var placements_before := SaveData.layout.placements.size()
	dock._assembly_key(KEY_E)
	_check(SaveData.layout.placements.size() == placements_before, "interact on the tower does nothing")

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
	dock._assembly_key(KEY_E)
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
		for item in action.get("menu", []):
			if item["type"] == "place_room":
				place_pos = pos
				place_id = item["id"]
				found_place = true
				break
		if found_place:
			break
	_check(found_place, "Assembly offers placing the inventory room into a slot")

	if found_place:
		dock._assembly_cursor = place_pos
		var inv_before := int(SaveData.layout.inventory.get(place_id, 0))
		dock._assembly_key(KEY_E)  # open the cell's menu
		_check(dock._menu_open, "interact on an owned slot opens its menu")
		var menu: Array = dock._assembly_actions[place_pos]["menu"]
		while not (menu[dock._menu_index]["type"] == "place_room" and menu[dock._menu_index]["id"] == place_id):
			dock._assembly_key(KEY_Q)
		dock._assembly_key(KEY_E)  # confirm placement
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
			dock._assembly_key(KEY_E)  # reopen the menu
			while not (menu[dock._menu_index]["type"] == "place_room" and menu[dock._menu_index]["id"] == place_id):
				dock._assembly_key(KEY_Q)
			dock._assembly_key(KEY_M)
			dock._assembly_key(KEY_E)
			for p in SaveData.layout.placements:
				if p.module_id == place_id and p.grid_pos == place_pos:
					placed = true
			_check(placed, "placing the room (mirrored if needed) succeeds")

		# The placed room is now an owned-cell whose menu offers "return_room" —
		# interact opens the menu, then confirming picks it back up into
		# inventory (2026-06-16 menu rework).
		if placed:
			dock._rebuild_assembly_entries()
			dock._assembly_cursor = place_pos
			var has_return := false
			for item in dock._assembly_actions.get(place_pos, {}).get("menu", []):
				if item["type"] == "return_room":
					has_return = true
			_check(has_return, "Assembly offers returning the placed room to inventory")
			dock._assembly_key(KEY_E)  # open the menu
			while dock._assembly_actions[place_pos]["menu"][dock._menu_index]["type"] != "return_room":
				dock._assembly_key(KEY_Q)
			dock._assembly_key(KEY_E)  # confirm return
			_check(int(SaveData.layout.inventory.get(place_id, 0)) == inv_before,
				"returning the room to inventory restores it")
			_check(place_pos in SaveData.layout.slots,
				"returning the room frees its cell back into an owned slot")

	# The helm can be picked up like any other room (2026-06-15) — but the
	# dock refuses to close while it's sitting in inventory.
	dock._mode = DryDock.Mode.ASSEMBLY
	dock._rebuild_assembly_entries()
	var helm_pos := Vector2i(1, 0)
	dock._assembly_cursor = helm_pos
	var helm_has_return := false
	for item in dock._assembly_actions.get(helm_pos, {}).get("menu", []):
		if item["type"] == "return_room":
			helm_has_return = true
	_check(helm_has_return, "Assembly offers returning the helm to inventory")
	dock._assembly_key(KEY_E)  # open the menu
	while dock._assembly_actions[helm_pos]["menu"][dock._menu_index]["type"] != "return_room":
		dock._assembly_key(KEY_Q)
	dock._assembly_key(KEY_E)  # confirm return
	_check(SaveData.layout.inventory.get("helm", 0) == 1, "the helm is now in inventory")
	dock._assembly_key(KEY_ESCAPE)
	_check(get_tree().paused, "the dock refuses to close without the helm placed")
	_check(dock._note != "", "a note explains why the dock won't close")

	# This slot now offers more than one inventory room to place (turret_room
	# and the helm); the "use" key (P1=Q, P2=Enter) cycles which menu item is
	# highlighted (2026-06-16 menu rework).
	dock._assembly_cursor = helm_pos
	var place_count := 0
	for item in dock._assembly_actions.get(helm_pos, {}).get("menu", []):
		if item["type"] == "place_room":
			place_count += 1
	_check(place_count > 1, "this slot offers more than one room to place")
	if place_count > 1:
		dock._assembly_key(KEY_E)  # open the menu
		var start_index := dock._menu_index
		dock._assembly_key(KEY_Q)
		_check(dock._menu_index != start_index, "the use key cycles to a different menu item")
		dock._assembly_key(KEY_ESCAPE)  # close without acting

	# Place the helm back — now closing is allowed again. (Other rooms may
	# also be in inventory by now, so go straight to SaveData rather than
	# relying on the UI's menu order for this slot.)
	_check(SaveData.place_room("helm", helm_pos), "the helm can be placed back")
	_check(SaveData.layout.inventory.get("helm", 0) == 0, "the helm is placed back")
	dock._rebuild_assembly_entries()

	# 2026-06-19 rework: the Floodlight Room and its lamp are one inseparable
	# unit (like the Bullet Room's built-in gun) — placing the room
	# auto-attaches its bundled pod, with no separate attach/detach menu.
	SaveData.banked_scrap = 1000
	var fl_pos: Vector2i = SaveData.layout.buyable_slot_positions()[0]
	_check(SaveData.buy_slot(fl_pos), "buy a slot for the Floodlight Room")
	# Buying the room bundles in its pod (2026-06-19, DECISIONS.md round 4).
	_check(SaveData.buy_room("floodlight_room"), "buy a Floodlight Room into inventory")
	_check(int(SaveData.layout.inventory.get("floodlight_pod", 0)) == 1,
		"buying the Floodlight Room also grants its pod into inventory")
	_check(SaveData.place_room("floodlight_room", fl_pos), "place the Floodlight Room")
	## M11: the base sub already has 1 floodlight_pod (on the base floodlight_room) --
	## placing this second floodlight_room should bring the pod count to 2.
	_check(SaveData.layout.pods.size() == 2, "placing the room auto-attaches its lamp")
	_check(SaveData.layout.inventory.get("floodlight_pod", 0) == 0,
		"the lamp is no longer in inventory")
	dock._rebuild_assembly_entries()

	dock._assembly_cursor = fl_pos
	var has_pod_menu := false
	for item in dock._assembly_actions.get(fl_pos, {}).get("menu", []):
		if item["type"] == "place_pod" or item["type"] == "return_pod":
			has_pod_menu = true
	_check(not has_pod_menu, "the Floodlight Room's menu has no separate pod controls")

	# Returning the room to inventory takes its lamp with it.
	dock._assembly_key(KEY_E)  # open the menu
	_check(dock._menu_open, "interact opens the Floodlight Room's menu")
	while dock._assembly_actions[fl_pos]["menu"][dock._menu_index]["type"] != "return_room":
		dock._assembly_key(KEY_Q)
	dock._assembly_key(KEY_E)  # confirm "return room"
	## M11: the base sub's own floodlight_pod (on the base floodlight_room) is
	## still attached -- check specifically that fl_pos's pod is gone, not that
	## the list is empty.
	var still_attached_at_fl := false
	for pod in SaveData.layout.pods:
		if pod.host_cell == fl_pos:
			still_attached_at_fl = true
	_check(not still_attached_at_fl, "the lamp is detached along with its room")
	_check(SaveData.layout.inventory.get("floodlight_pod", 0) == 1,
		"the lamp is back in inventory")
	_check(SaveData.layout.inventory.get("floodlight_room", 0) == 1,
		"the room is back in inventory")
	dock._rebuild_assembly_entries()

	# Tab returns to the Shop.
	dock._assembly_key(KEY_TAB)
	_check(dock._mode == DryDock.Mode.SHOP, "Tab from Assembly returns to the Shop")

	# Esc closes from any tab.
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
