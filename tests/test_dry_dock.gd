extends Node

## Headless test for the Dry Dock screen (Module D): navigating + buying
## upgrades and the gun-room placement sub-flow, driven through the same key
## handlers the player uses. (The visuals are eyeball-only; this checks the
## logic and that it leaves the tree unpaused on close.)
##
## Run: godot --headless res://tests/test_dry_dock.tscn

var _failures := 0
var _closed_changed := -1  # -1 = not closed yet; 0/1 = changed flag

func _ready() -> void:
	# Keep running even though the dock pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveData.reset_for_test()
	SaveData.banked_scrap = 20

	var dock := DryDock.new()
	add_child(dock)
	dock.closed.connect(func(changed: bool) -> void: _closed_changed = 1 if changed else 0)

	_check(get_tree().paused, "opening the dry dock pauses the run")

	# Buy a no-slot upgrade (engine boost) via the list key handler.
	_select(dock, "engine_boost")
	var before: int = SaveData.banked_scrap
	dock._list_key(KEY_ENTER)
	_check(SaveData.loadout.engine_boost, "Enter on engine boost buys it")
	_check(SaveData.banked_scrap < before, "scrap was spent")

	# Buy the gun room: Enter opens placement, A/D pick the end, Enter confirms.
	_select(dock, "gun_room")
	dock._list_key(KEY_ENTER)
	_check(dock._mode == DryDock.Mode.PLACEMENT, "buying the gun room opens the placement view")
	dock._placement_key(KEY_RIGHT)
	_check(dock._slot == SubLoadout.Slot.BOW, "D/Right selects the bow hardpoint")
	dock._placement_key(KEY_ENTER)
	_check(SaveData.loadout.gun_room == SubLoadout.Slot.BOW, "confirming installs the bow gun room")
	_check(dock._mode == DryDock.Mode.LIST, "placement returns to the list after confirming")

	# Close it.
	dock._list_key(KEY_ESCAPE)
	await get_tree().process_frame
	_check(not get_tree().paused, "closing the dry dock unpauses the run")
	_check(_closed_changed == 1, "close reports that the loadout changed")

	SaveData.reset_for_test()
	if _failures == 0:
		print("DRY DOCK TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("DRY DOCK TESTS FAILED: %d failing check(s)" % _failures)
		get_tree().quit(1)

func _select(dock: DryDock, id: String) -> void:
	for i in dock._entries.size():
		if dock._entries[i]["id"] == id:
			dock._index = i
			return

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok:   ", msg)
	else:
		push_error("  FAIL: " + msg)
		_failures += 1
