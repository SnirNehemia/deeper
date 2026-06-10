extends Node

## Headless test for the Shore Shelf map + sub physics (Steps 5/6 + bug fixes).
##
## Run: godot --headless res://tests/test_world.tscn
## Verifies: the sub floats at the surface (buoyant) and can't fly out of the
## water, it dives and rests on the sea floor (matched hull collider), and it can
## drive into the carved cave.

var _failures := 0

func _ready() -> void:
	add_child(ShoreShelf.new())
	await _test_buoyancy_and_floor()
	await _test_cave()
	if _failures == 0:
		print("WORLD TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("WORLD TESTS FAILED: %d failing check(s)" % _failures)
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

func _depth(sub: Sub) -> float:
	return sub.global_position.y / GameFeel.PIXELS_PER_METER

func _test_buoyancy_and_floor() -> void:
	print("[buoyancy + floor]")
	var sub := Sub.new()
	sub.buoyancy_enabled = true
	sub.position = Vector2(45.0 * 48.0, Sub.SURFACE_FLOAT_DEPTH)  # at the float line
	add_child(sub)

	# Settle: should hold its float line, not sink away or bob.
	await _frames(120)
	var float_depth := _depth(sub)
	print("    float depth=", float_depth, " meter=", sub.depth_m())
	_check(float_depth > 1.0 and float_depth < 5.0, "sub holds the surface float line at rest")
	_check(sub.depth_m() < 1.0, "depth meter reads ~0 m at the surface")

	# Dive to the shallows floor (~20 m); the hull should rest on it.
	for i in 480:
		sub.drive_input = Vector2(0, 1)
		await get_tree().physics_frame
	var deep := _depth(sub)
	print("    rest depth=", deep, " vy=", sub.velocity.y)
	_check(deep > 14.0 and deep < 22.0 and absf(sub.velocity.y) < 30.0,
		"sub rests on the sea floor instead of sinking through it")

	# Surface and then keep pushing up: buoyancy must stop it flying out.
	for i in 420:
		sub.drive_input = Vector2(0, -1)
		await get_tree().physics_frame
	var top := sub.global_position.y
	print("    top y(px)=", top, " vy=", sub.velocity.y)
	_check(_depth(sub) < deep - 5.0, "sub rises back toward the surface")
	_check(top > -40.0, "sub can't fly up out of the water (gets heavy)")
	_check(sub.velocity.y > -20.0, "ascent stalls near the surface")

	sub.queue_free()
	await _frames(2)

func _test_cave() -> void:
	print("[cave]")
	var sub := Sub.new()
	sub.position = Vector2(185.0 * 48.0, 66.0 * 48.0)  # in the basin, at cave height
	add_child(sub)

	await _frames(10)
	for i in 460:
		sub.drive_input = Vector2(-1, 0)
		await get_tree().physics_frame
	print("    cave x(m)=", sub.global_position.x / 48.0)
	_check(sub.global_position.x < 150.0 * 48.0, "sub can drive into the cave (past the cliff line)")

	sub.queue_free()
	await _frames(2)
