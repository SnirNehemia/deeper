extends Node

## Headless test for Module D: the dry-dock loadout — buying upgrades with
## banked scrap, persisting them, and the sub building itself from them
## (engine boost, faster repairs, and a player-placed second gun room that
## adds a 7th water room + a second turret).
##
## Run: godot --headless res://tests/test_loadout.tscn

var _failures := 0

func _ready() -> void:
	SaveData.reset_for_test()
	_test_purchase_and_save()
	await _test_engine_and_repair_mults()
	await _test_gun_room_build()
	await _test_gun_room_water()
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

func _test_gun_room_build() -> void:
	print("[gun room build]")
	var sub := Sub.new()
	var lo := SubLoadout.new()
	lo.gun_room = SubLoadout.Slot.STERN
	sub.loadout = lo
	add_child(sub)
	await _frames(2)

	_check(sub.active_room_count() == 7, "a gun room gives the sub a 7th water room")
	_check(sub.water_levels.size() == 7, "water levels resized for the gun room")
	_check(_count_turrets(sub) == 2, "the sub now has two turret stations")

	var gun := sub.room_rect(Sub.GUN_ROOM)
	_check(is_equal_approx(gun.position.x, -Sub.HALF_W - Sub.ROOM_W),
		"a STERN gun room bolts onto the left end")
	_check(sub.room_index_at(gun.get_center()) == Sub.GUN_ROOM,
		"the gun room is locatable by position")

	sub.queue_free()
	await _frames(2)

func _test_gun_room_water() -> void:
	print("[gun room flooding]")
	var sub := Sub.new()
	var lo := SubLoadout.new()
	lo.gun_room = SubLoadout.Slot.STERN
	sub.loadout = lo
	add_child(sub)
	GameFeel.water.drain_rate = 0.0
	await _frames(2)

	# Flood the gun room above its door sill; it should spill into the engine
	# room (0), which is the room it shares a doorway with on the stern side.
	var sill: float = GameFeel.water.door_sill_m / GameFeel.water.room_height_m
	sub.water_levels[Sub.GUN_ROOM] = sill + 0.3
	await _frames(120)
	_check(sub.water_levels[0] > 0.01,
		"water in the gun room spills through its doorway into the engine room")

	GameFeel.water.drain_rate = 1.0 / 12.0  # restore for any later suites
	sub.queue_free()
	await _frames(2)
