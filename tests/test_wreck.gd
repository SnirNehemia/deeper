extends Node

## Headless test for Milestone 3 Module E: breakable wrecks. One torpedo hit
## cracks a wreck open and spills 2-3 scrap crates; reset_wreck() reseals it
## and clears whatever it spilled (the M3 "respawn wrecks on reset" rule).
##
## Run: godot --headless res://tests/test_wreck.tscn

var _failures := 0

func _ready() -> void:
	await _test_crack_spills_loot()
	await _test_reset_reseals_and_clears()
	_test_no_double_crack()
	await _test_bullet_burst_cracks_wreck()

	if _failures == 0:
		print("WRECK TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("WRECK TESTS FAILED: %d failing check(s)" % _failures)
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

func _new_wreck() -> Wreck:
	var wreck := Wreck.new()
	wreck.position = Vector2.ZERO
	add_child(wreck)
	return wreck

func _fire_torpedo_at(wreck: Wreck) -> void:
	var torpedo := Torpedo.new()
	torpedo.velocity = Vector2.ZERO
	torpedo.global_position = wreck.global_position
	add_child(torpedo)

func _test_crack_spills_loot() -> void:
	print("[torpedo cracks a wreck open]")
	var wreck := _new_wreck()
	await _frames(2)
	_check(not wreck.cracked, "a fresh wreck starts sealed")

	var before := get_tree().get_nodes_in_group("salvage").size()
	_fire_torpedo_at(wreck)
	await _frames(2)
	var after := get_tree().get_nodes_in_group("salvage").size()

	_check(wreck.cracked, "one torpedo hit cracks the wreck open")
	var spilled := after - before
	_check(spilled >= 2 and spilled <= 3, "cracking spills 2-3 salvage items (got %d)" % spilled)

	wreck.queue_free()
	await _frames(2)

func _test_reset_reseals_and_clears() -> void:
	print("[reset reseals the wreck and clears its loot]")
	var wreck := _new_wreck()
	await _frames(2)
	_fire_torpedo_at(wreck)
	await _frames(2)
	_check(wreck.cracked, "wreck is cracked before reset")
	_check(wreck._spilled.size() >= 2, "wreck tracked its spilled items")

	var spilled_items := wreck._spilled.duplicate()
	wreck.reset_wreck()
	await _frames(2)

	_check(not wreck.cracked, "reset_wreck() reseals the wreck")
	for item in spilled_items:
		_check(not is_instance_valid(item) or item.is_queued_for_deletion(),
			"reset_wreck() clears the items it spilled")

	wreck.queue_free()
	await _frames(2)

func _test_no_double_crack() -> void:
	print("[an already-cracked wreck ignores further hits]")
	var wreck := _new_wreck()
	await _frames(2)
	_fire_torpedo_at(wreck)
	await _frames(2)
	_check(wreck.cracked, "first hit cracks the wreck")
	var spilled_after_first := wreck._spilled.size()

	_fire_torpedo_at(wreck)
	await _frames(2)
	_check(wreck._spilled.size() == spilled_after_first,
		"a second hit on an already-open wreck spills nothing more")

	wreck.queue_free()
	await _frames(2)

func _fire_bullet_at(wreck: Wreck) -> void:
	var bullet := Bullet.new()
	bullet.velocity = Vector2.ZERO
	bullet.global_position = wreck.global_position
	add_child(bullet)

func _test_bullet_burst_cracks_wreck() -> void:
	print("[bullet burst cracks a wreck open]")
	var wreck := Wreck.new()
	wreck.position = Vector2(2000.0, 0.0)  # clear of leftover torpedoes from earlier tests
	add_child(wreck)
	await _frames(2)

	var shots := int(wreck.hp_max / GameFeel.bullet.damage)
	for i in shots - 1:
		_fire_bullet_at(wreck)
		await _frames(2)
		_check(not wreck.cracked, "wreck survives bullet %d/%d" % [i + 1, shots])

	var before := get_tree().get_nodes_in_group("salvage").size()
	_fire_bullet_at(wreck)
	await _frames(2)
	var after := get_tree().get_nodes_in_group("salvage").size()

	_check(wreck.cracked, "wreck cracks open on the %dth bullet" % shots)
	_check(after - before >= 2, "cracking via bullets still spills loot")

	wreck.queue_free()
	await _frames(2)
