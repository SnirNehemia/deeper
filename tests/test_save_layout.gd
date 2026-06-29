extends Node

## Headless test for the M4 save extension (Module 6,
## MODULAR_SUB_IMPLEMENTATION.md §9): the submarine layout (placements, pods,
## owned slots, inventory) persists alongside banked salvage + loadout, a
## pre-M4 save with no layout loads as the starting layout, and a layout left
## illegal by a rules change is recovered (non-core rooms back to inventory)
## rather than lost.
##
## Run: godot --headless res://tests/test_save_layout.tscn

var _failures := 0

func _ready() -> void:
	_test_layout_round_trip()
	_test_legacy_save_upgrades_to_starting_layout()
	_test_invalid_layout_recovers_on_load()
	_test_engine_module_dropped_on_load()
	SaveData.reset_for_test()

	if _failures == 0:
		print("SAVE LAYOUT TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("SAVE LAYOUT TESTS FAILED: %d failing check(s)" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok:   ", msg)
	else:
		push_error("  FAIL: " + msg)
		_failures += 1

func _write_raw_save(data: Dictionary) -> void:
	var file := FileAccess.open(SaveData.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file = null

func _test_layout_round_trip() -> void:
	print("[layout round-trip]")
	SaveData.reset_for_test()
	# Buy a slot and stash a room in inventory, then persist.
	var candidates: Array = SaveData.layout.buyable_slot_positions()
	var bought_slot: Vector2i = candidates[0]
	SaveData.layout.slots.append(bought_slot)
	SaveData.layout.inventory["turret_room"] = 1
	SaveData.banked_scrap = 12
	SaveData.save_data()

	# Wipe memory, reload from disk.
	SaveData.banked_scrap = 0
	SaveData.layout = SubLayout.new()
	SaveData.load_data()

	_check(SaveData.banked_scrap == 12, "banked scrap still round-trips")
	_check(SaveData.layout.placements.size() == 5, "the 5 placed rooms persisted")  ## MILESTONE_11.md: floodlight_room added
	_check(bought_slot in SaveData.layout.slots, "the bought slot persisted")
	_check(SaveData.layout.inventory.get("turret_room", 0) == 1,
		"the inventoried room persisted")
	# What loaded is still a legal sub.
	_check(SubValidator.validate(SaveData.layout)["ok"], "the reloaded layout validates")

func _test_legacy_save_upgrades_to_starting_layout() -> void:
	print("[legacy save upgrade]")
	SaveData.reset_for_test()
	# A pre-M4 save: banked totals + loadout, but NO layout key.
	# The "engine_boost" key is from pre-M7-1 saves and is silently ignored on load.
	_write_raw_save({
		"banked_scrap": 7,
		"banked_fish": 3,
		"loadout": {"engine_boost": true, "fast_repair": false, "gun_room": "none"},
	})
	SaveData.layout = SubLayout.new()  # clobber, prove load restores it
	SaveData.load_data()

	_check(SaveData.banked_scrap == 7, "legacy banked scrap loads")
	_check(SaveData.layout.placements.size() == 5,
		"a save with no layout boots to the M11 base sub (5 rooms)")
	_check(SubValidator.validate(SaveData.layout)["ok"], "the upgraded layout validates")

func _test_invalid_layout_recovers_on_load() -> void:
	print("[invalid layout recovery]")
	SaveData.reset_for_test()
	# Hand-write a save whose layout is illegal: a non-core room overlapping the
	# claw room's cell. On load it must recover (room back to inventory), not
	# crash or wipe the save.
	var broken := SubLayout.starting_layout()
	broken.placements.append(SubLayout.Placement.new("storage", Vector2i(-1, 0)))  # overlaps telescope_room
	_check(not SubValidator.validate(broken)["ok"], "the hand-written layout is illegal")
	_write_raw_save({
		"banked_scrap": 5,
		"banked_fish": 0,
		"loadout": {},
		"layout": broken.to_dict(),
	})

	SaveData.load_data()
	_check(SaveData.banked_scrap == 5, "scrap is untouched by the recovery")
	_check(SubValidator.validate(SaveData.layout)["ok"],
		"the loaded layout was recovered to a legal one")
	_check(SaveData.layout.inventory.get("storage", 0) >= 1,
		"the offending room was returned to inventory, not lost")

func _test_engine_module_dropped_on_load() -> void:
	print("[engine module dropped on load]")
	SaveData.reset_for_test()
	# Simulate an old 7-room save that includes the retired engine room.
	# On load, recover() must strip the engine placement (unknown module) and
	# leave a valid sub — no crash, no ghost placement.
	var old_layout := SubLayout.starting_layout()
	old_layout.placements.append(SubLayout.Placement.new("engine", Vector2i(2, 0)))
	_write_raw_save({
		"banked_scrap": 3,
		"loadout": {},
		"layout": old_layout.to_dict(),
	})

	SaveData.load_data()
	_check(SaveData.banked_scrap == 3, "scrap is untouched")
	var engine_found := false
	for p in SaveData.layout.placements:
		if p.module_id == "engine":
			engine_found = true
	_check(not engine_found, "the retired engine placement is dropped on load")
	_check(SubValidator.validate(SaveData.layout)["ok"],
		"the layout without the engine still validates")
