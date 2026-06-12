extends Node

## Headless test for Module B: on-board salvage storage, dock banking, and the
## persisted save. (Collecting salvage itself is the claw's job — see
## test_claw; this suite covers what happens to it once it's on board.)
##
## Run: godot --headless res://tests/test_salvage.tscn

var _failures := 0

func _ready() -> void:
	SaveData.reset_for_test()
	await _test_storage_counters()
	await _test_carcass_kind()
	await _test_dock_banking()
	_test_save_round_trip()
	SaveData.reset_for_test()

	if _failures == 0:
		print("SALVAGE TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("SALVAGE TESTS FAILED: %d failing check(s)" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok:   ", msg)
	else:
		push_error("  FAIL: " + msg)
		_failures += 1

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _new_sub() -> Sub:
	var sub := Sub.new()
	add_child(sub)
	return sub

func _test_storage_counters() -> void:
	print("[storage counters]")
	var sub := _new_sub()

	sub.deposit_salvage(SalvageItem.Kind.SCRAP)
	sub.deposit_salvage(SalvageItem.Kind.SCRAP)
	sub.deposit_salvage(SalvageItem.Kind.FISH)
	_check(sub.storage_scrap == 2, "depositing scrap raises the scrap counter")
	_check(sub.storage_fish == 1, "depositing a carcass raises the fish counter")

	# Unbanked storage is lost on implosion reset (the push-your-luck stakes).
	sub.reset_state()
	_check(sub.storage_scrap == 0 and sub.storage_fish == 0,
		"reset (implosion) clears unbanked on-board storage")

	sub.queue_free()
	await _frames(2)

func _test_carcass_kind() -> void:
	print("[carcass tagging]")
	var carcass := SalvageItem.make_carcass(Vector2.ZERO)
	add_child(carcass)
	_check(carcass.kind == SalvageItem.Kind.FISH, "carcass has the FISH kind")
	_check(carcass.is_in_group("salvage"), "carcass is findable by the claw")
	_check(carcass.is_in_group("salvage_carcass"), "carcass is tagged for run-reset cleanup")
	carcass.queue_free()
	await _frames(2)

func _test_dock_banking() -> void:
	print("[dock banking]")
	var sub := _new_sub()
	sub.storage_scrap = 3
	sub.storage_fish = 2

	var dock := Vector2(2000, 2000)
	var radius := 100.0

	sub.global_position = dock + Vector2(500, 0)  # far from dock
	_check(not sub.try_bank(dock, radius), "far from dock: nothing banked")
	_check(sub.storage_scrap == 3 and sub.storage_fish == 2, "storage untouched away from dock")

	sub.global_position = dock
	_check(sub.try_bank(dock, radius), "at the dock: storage is banked")
	_check(sub.storage_scrap == 0 and sub.storage_fish == 0, "storage emptied after banking")
	_check(SaveData.banked_scrap == 3 and SaveData.banked_fish == 2,
		"banked totals reflect the deposited storage")

	sub.queue_free()
	await _frames(2)

func _test_save_round_trip() -> void:
	print("[save round trip]")
	SaveData.bank(4, 1)  # appends to the 3/2 banked above -> 7/3, and saves to disk
	var saved_scrap := SaveData.banked_scrap
	var saved_fish := SaveData.banked_fish

	SaveData.banked_scrap = 0
	SaveData.banked_fish = 0
	SaveData.load_data()

	_check(SaveData.banked_scrap == saved_scrap and SaveData.banked_fish == saved_fish,
		"reloading the save file restores the banked totals")
