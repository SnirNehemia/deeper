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
	await _test_currency_kind()
	await _test_falls_under_gravity_when_airborne()
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

	sub.deposit_salvage(SalvageItem.make_scrap(Vector2.ZERO))
	sub.deposit_salvage(SalvageItem.make_scrap(Vector2.ZERO))
	sub.deposit_salvage(SalvageItem.make_currency(Vector2.ZERO, "teal", 5))
	_check(sub.storage_scrap == 2, "depositing scrap raises the scrap counter")
	_check(int(sub.storage_currency.get("teal", 0)) == 5,
		"depositing currency raises that color's running total")

	# Unbanked storage is lost on implosion reset (the push-your-luck stakes).
	sub.reset_state()
	_check(sub.storage_scrap == 0 and sub.storage_currency.is_empty(),
		"reset (implosion) clears unbanked on-board storage")

	sub.queue_free()
	await _frames(2)

func _test_currency_kind() -> void:
	print("[currency tagging]")
	var drop := SalvageItem.make_currency(Vector2.ZERO, "teal", 5)
	add_child(drop)
	_check(drop.kind == SalvageItem.Kind.CURRENCY, "a drop has the CURRENCY kind")
	_check(drop.currency_color == "teal" and drop.currency_value == 5,
		"a drop carries its color and denomination value")
	_check(drop.is_in_group("salvage"), "a drop is findable by the claw")
	_check(drop.is_in_group("salvage_carcass"), "a drop is tagged for run-reset cleanup")
	drop.queue_free()
	await _frames(2)

func _test_falls_under_gravity_when_airborne() -> void:
	print("[a drop stranded above the water surface falls under plain gravity]")
	var drop := SalvageItem.make_currency(Vector2(0.0, -50.0), "teal", 5)
	drop.water_surface_y = 1000.0  # the drop's y (-50) is well above this
	add_child(drop)
	await _frames(2)

	var y0 := drop.global_position.y
	await _frames(10)
	var y1 := drop.global_position.y
	await _frames(10)
	var y2 := drop.global_position.y
	_check((y2 - y1) > (y1 - y0),
		"an airborne drop's fall speed increases over time like gravity")

	var reached_water := false
	for i in 300:
		await get_tree().physics_frame
		if drop.global_position.y >= drop.water_surface_y:
			reached_water = true
			break
	_check(reached_water, "the drop actually reaches the water, it doesn't fall forever")

	drop.queue_free()
	await _frames(2)

func _test_dock_banking() -> void:
	print("[dock banking]")
	var sub := _new_sub()
	sub.storage_scrap = 3
	sub.storage_currency = {"teal": 12}

	var dock := Vector2(2000, 2000)
	var radius := 100.0

	sub.global_position = dock + Vector2(500, 0)  # far from dock
	_check(not sub.try_bank(dock, radius), "far from dock: nothing banked")
	_check(sub.storage_scrap == 3 and sub.storage_currency.get("teal", 0) == 12,
		"storage untouched away from dock")

	sub.global_position = dock
	_check(sub.try_bank(dock, radius), "at the dock: storage is banked")
	_check(sub.storage_scrap == 0 and sub.storage_currency.is_empty(), "storage emptied after banking")
	_check(SaveData.banked_scrap == 3 and SaveData.banked_currency.get("teal", 0) == 12,
		"banked totals reflect the deposited storage")

	sub.queue_free()
	await _frames(2)

func _test_save_round_trip() -> void:
	print("[save round trip]")
	SaveData.bank(4, {"teal": 1})  # appends to the 3/12 banked above -> 7/13, and saves to disk
	var saved_scrap := SaveData.banked_scrap
	var saved_teal: int = SaveData.banked_currency.get("teal", 0)

	SaveData.banked_scrap = 0
	SaveData.banked_currency = {}
	SaveData.load_data()

	_check(SaveData.banked_scrap == saved_scrap and SaveData.banked_currency.get("teal", 0) == saved_teal,
		"reloading the save file restores the banked totals")
