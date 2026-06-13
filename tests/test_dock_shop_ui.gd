extends Node

## Headless test for the M4-7c dry-dock Shop tab (rooms into inventory + the
## wallet display state). Drives the same key handlers the player uses; the
## actual spend/price logic lives in SaveData/ModuleCatalog and is already
## covered by test_shop — this only checks the menu wiring.
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
	_check(not dock._shop_entries.is_empty(), "the shop lists at least one purchasable room")

	# Buying with too little money is refused.
	SaveData.banked_scrap = 0
	dock._shop_key(KEY_ENTER)
	_check(SaveData.layout.inventory.is_empty(), "buying with no scrap adds nothing to inventory")
	_check(dock._note != "", "an affordability note is shown")

	# Buying with enough money adds it to inventory and spends the wallet.
	var def: ModuleDef = dock._shop_entries[dock._shop_index]
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

	# Tab returns to the Upgrades list.
	dock._shop_key(KEY_TAB)
	_check(dock._mode == DryDock.Mode.LIST, "Tab from the Shop returns to the Upgrades list")

	# Esc closes from either tab.
	dock._shop_key(KEY_TAB)  # back to Shop
	dock._shop_key(KEY_ESCAPE)
	await get_tree().process_frame
	_check(not get_tree().paused, "Esc from the Shop unpauses and closes the dock")

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
