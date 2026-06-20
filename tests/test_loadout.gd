extends Node

## Headless test for Module D: the dry-dock loadout — buying upgrades with
## banked scrap, persisting them, and the sub building itself from them
## (faster repairs). Engine Boost was retired in M7-1.
##
## NOTE (M4-4b): the second gun room is no longer a SubLoadout bolt-on — the sub
## is layout-driven now, and the turret room returns as a placeable room in
## M4-9. The gun-room build/flood checks were removed here and move to the
## M4-9 turret-room test. Buying "gun_room" still records in the save (the M3
## dry dock UI), it just no longer reshapes the sub.
##
## Run: godot --headless res://tests/test_loadout.tscn

var _failures := 0

func _ready() -> void:
	SaveData.reset_for_test()
	_test_purchase_and_save()
	_test_repair_mult()
	SaveData.reset_for_test()

	if _failures == 0:
		print("LOADOUT TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("LOADOUT TESTS FAILED: %d failing check(s)" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok:   ", msg)
	else:
		push_error("  FAIL: " + msg)
		_failures += 1

func _test_purchase_and_save() -> void:
	print("[purchase + save]")
	SaveData.reset_for_test()
	var cost: int = SubLoadout.catalog_entry("fast_repair")["cost"]

	_check(not SaveData.purchase("fast_repair"), "can't buy with no banked scrap")

	SaveData.banked_scrap = cost + 5
	_check(SaveData.purchase("fast_repair"), "buy fast_repair once affordable")
	_check(SaveData.banked_scrap == 5, "the cost was deducted from banked scrap")
	_check(SaveData.loadout.fast_repair, "fast_repair is now owned")
	_check(not SaveData.purchase("fast_repair"), "can't buy the same upgrade twice")

	# engine_boost is no longer in the catalog (M7-1).
	_check(SubLoadout.catalog_entry("engine_boost").is_empty(),
		"engine_boost is not in the catalog (retired M7-1)")
	_check(not SaveData.purchase("engine_boost"), "buying a retired upgrade is refused")

	# Persist + reload.
	var scrap := SaveData.banked_scrap
	SaveData.banked_scrap = 0
	SaveData.loadout = SubLoadout.new()
	SaveData.load_data()
	_check(SaveData.banked_scrap == scrap, "banked scrap survives a save/reload")
	_check(SaveData.loadout.fast_repair, "fast_repair survives a save/reload")

func _test_repair_mult() -> void:
	print("[repair mult]")
	var base := SubLoadout.new()
	_check(is_equal_approx(base.repair_time_mult(), 1.0), "base sub repairs at normal speed")
	_check(is_equal_approx(base.move_mult(), 1.0), "move_mult is permanently 1.0 (engine retired)")

	var trained := SubLoadout.new()
	trained.fast_repair = true
	_check(trained.repair_time_mult() < 1.0, "repair training shortens repair time")
	_check(is_equal_approx(trained.move_mult(), 1.0), "fast_repair does not change move_mult")
