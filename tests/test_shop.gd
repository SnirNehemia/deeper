extends Node

## Headless test for the M4 dry-dock shop purchase logic (Module 7, part 1:
## the slot economy spend — ROOM_SYSTEM.md §4.1, MODULAR_SUB_IMPLEMENTATION.md
## §6/§8). Buying a slot deducts escalating scrap, grows the layout, and
## persists; illegal positions and insufficient scrap are refused. No UI here —
## these are the controller functions the keyboard shop will call.
##
## Run: godot --headless res://tests/test_shop.tscn

var _failures := 0

func _ready() -> void:
	_test_buy_slot_happy_path()
	_test_buy_slot_refused_when_broke()
	_test_buy_slot_refused_for_illegal_position()
	_test_price_escalates_with_owned_slots()
	_test_purchase_persists()
	SaveData.reset_for_test()

	if _failures == 0:
		print("SHOP TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("SHOP TESTS FAILED: %d failing check(s)" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok:   ", msg)
	else:
		push_error("  FAIL: " + msg)
		_failures += 1

func _test_buy_slot_happy_path() -> void:
	print("[buy a slot]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 100
	var pos: Vector2i = SaveData.layout.buyable_slot_positions()[0]
	var price := SaveData.next_slot_price()
	var ok := SaveData.buy_slot(pos)
	_check(ok, "buying a legal slot with enough scrap succeeds")
	_check(pos in SaveData.layout.slots, "the bought slot is now part of the layout")
	_check(SaveData.banked_scrap == 100 - price, "the slot's scrap price was deducted")
	_check(SubValidator.validate(SaveData.layout)["ok"], "the sub with the new slot still validates")

func _test_buy_slot_refused_when_broke() -> void:
	print("[too poor]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = SaveData.next_slot_price() - 1  # one short
	var pos: Vector2i = SaveData.layout.buyable_slot_positions()[0]
	var ok := SaveData.buy_slot(pos)
	_check(not ok, "buying a slot you can't afford is refused")
	_check(SaveData.layout.slots.is_empty(), "no slot was added")
	_check(SaveData.banked_scrap == SaveData.next_slot_price() - 1, "no scrap was spent")

func _test_buy_slot_refused_for_illegal_position() -> void:
	print("[illegal position]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 100
	# A cell far from the hull is not a buyable slot.
	var ok := SaveData.buy_slot(Vector2i(50, 50))
	_check(not ok, "buying a slot not adjacent to the hull is refused")
	_check(SaveData.layout.slots.is_empty(), "no slot was added")
	_check(SaveData.banked_scrap == 100, "no scrap was spent")

func _test_price_escalates_with_owned_slots() -> void:
	print("[price escalation]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 1000
	var first := SaveData.next_slot_price()
	SaveData.buy_slot(SaveData.layout.buyable_slot_positions()[0])
	var second := SaveData.next_slot_price()
	_check(second > first, "the second slot costs more than the first")

func _test_purchase_persists() -> void:
	print("[persistence]")
	SaveData.reset_for_test()
	SaveData.banked_scrap = 100
	var pos: Vector2i = SaveData.layout.buyable_slot_positions()[0]
	SaveData.buy_slot(pos)
	var scrap_after := SaveData.banked_scrap

	# Reload from disk.
	SaveData.banked_scrap = 0
	SaveData.layout = SubLayout.new()
	SaveData.load_data()
	_check(pos in SaveData.layout.slots, "the bought slot survives a save/reload")
	_check(SaveData.banked_scrap == scrap_after, "the post-purchase scrap survives a save/reload")
