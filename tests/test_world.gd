extends Node

## Headless test for the Shore Shelf map (Steps 5/6).
##
## Run: godot --headless res://tests/test_world.tscn
## Verifies the sub spawns at the surface, the depth reading tracks vertical
## motion, the sub collides with the sea floor (can't sink through it), and it
## can rise back toward the surface.

var _failures := 0

func _ready() -> void:
	await _run()
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

func _run() -> void:
	print("[world]")
	add_child(ShoreShelf.new())

	var sub := Sub.new()
	sub.position = Vector2(45.0 * 48.0, 0.0)  # surface, over the shallows
	add_child(sub)

	await _frames(20)
	_check(_depth(sub) < 3.0, "sub spawns at the surface (~0 m depth)")

	# Dive: drive straight down long enough to reach the shallows floor (~20 m),
	# which should stop the sub (hull bottom rests ~17 m down).
	for i in 480:
		sub.drive_input = Vector2(0, 1)
		await get_tree().physics_frame
	var deep := _depth(sub)
	_check(deep > 10.0, "depth increases as the sub dives")
	_check(deep < 22.0 and absf(sub.velocity.y) < 30.0,
		"sub rests on the sea floor instead of sinking through it")

	# Surface again.
	for i in 300:
		sub.drive_input = Vector2(0, -1)
		await get_tree().physics_frame
	sub.drive_input = Vector2.ZERO
	_check(_depth(sub) < deep - 5.0, "sub rises back toward the surface")
