extends Node

## Headless test for Module D: the dry-dock loadout — buying upgrades with
## banked scrap, persisting them, and the sub building itself from them (engine
## boost, faster repairs).
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
	await _test_engine_and_repair_mults()
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

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _count_turrets(sub: Sub) -> int:
	var n := 0
	for c in sub.get_children():
		if c is TurretStation:
			n += 1
	return n

func _test_purchase_and_save() -> void:
	print("[purchase + save]")
	SaveData.reset_for_test()
	var cost: int = SubLoadout.catalog_entry("engine_boost")["cost"]

	_check(not SaveData.purchase("engine_boost"), "can't buy with no banked scrap")

	SaveData.banked_scrap = cost + 5
	_check(SaveData.purchase("engine_boost"), "buy engine boost once affordable")
	_check(SaveData.banked_scrap == 5, "the cost was deducted from banked scrap")
	_check(SaveData.loadout.engine_boost, "engine boost is now owned")
	_check(not SaveData.purchase("engine_boost"), "can't buy the same upgrade twice")

	# Persist + reload.
	var scrap := SaveData.banked_scrap
	SaveData.banked_scrap = 0
	SaveData.loadout = SubLoadout.new()
	SaveData.load_data()
	_check(SaveData.banked_scrap == scrap, "banked scrap survives a save/reload")
	_check(SaveData.loadout.engine_boost, "owned upgrade survives a save/reload")

func _test_engine_and_repair_mults() -> void:
	print("[engine + repair mults]")
	# A boosted sub should out-accelerate a base sub over the same input.
	var base := Sub.new()
	add_child(base)
	var fast := Sub.new()
	var lo := SubLoadout.new()
	lo.engine_boost = true
	fast.loadout = lo
	add_child(fast)
	await _frames(2)

	for i in 30:
		base.drive_input = Vector2(1, 0)
		fast.drive_input = Vector2(1, 0)
		await get_tree().physics_frame
	_check(fast.velocity.x > base.velocity.x + 1.0,
		"engine boost makes the sub accelerate faster")

	var repair := Sub.new()
	var lo2 := SubLoadout.new()
	lo2.fast_repair = true
	repair.loadout = lo2
	add_child(repair)
	await _frames(2)
	_check(repair.repair_time_mult() < 1.0, "repair training shortens repair time")
	_check(is_equal_approx(base.repair_time_mult(), 1.0), "base sub repairs at normal speed")

	base.queue_free()
	fast.queue_free()
	repair.queue_free()
	await _frames(2)
