extends Node

## Headless test for the input abstraction (Step 1).
##
## Run: godot --headless res://tests/test_input.tscn
## Booting a real scene (rather than --script) means global class_names resolve
## and the InputHub autoload is live, so this exercises the actual shipping path.
##
## Feeds synthetic key events through the providers and the InputHub autoload,
## asserting the snapshots are correct — including the tricky bits: right-shift
## location, P1/P2 cross-talk isolation, and edge ("pressed") vs held.

func _ready() -> void:
	var failures := 0
	failures += _test_providers()
	failures += _test_hub()

	if failures == 0:
		print("INPUT TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("INPUT TESTS FAILED: %d failing check(s)" % failures)
		get_tree().quit(1)

func _key(keycode: Key, pressed: bool, location: int = KEY_LOCATION_UNSPECIFIED) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = keycode
	e.location = location
	e.pressed = pressed
	return e

func _check(cond: bool, msg: String) -> int:
	if cond:
		print("  ok:   ", msg)
		return 0
	push_error("  FAIL: " + msg)
	return 1

func _test_providers() -> int:
	print("[providers]")
	var f := 0
	var p1 := KeyboardProvider.make_player_one()
	var p2 := KeyboardProvider.make_player_two()

	# P1 runs right; P2 must not feel it.
	p1.handle_event(_key(KEY_D, true))
	p1.poll(0.016)
	p2.poll(0.016)
	f += _check(p1.input.move == Vector2(1, 0), "P1 D -> move.x +1")
	f += _check(p2.input.move == Vector2.ZERO, "P2 unaffected by P1 D (no cross-talk)")

	# P1 left + up: up is negative y; jump fires on the first poll only.
	p1.handle_event(_key(KEY_D, false))
	p1.handle_event(_key(KEY_A, true))
	p1.handle_event(_key(KEY_W, true))
	p1.poll(0.016)
	f += _check(p1.input.move == Vector2(-1, -1), "P1 A+W -> move (-1,-1), up is -y")
	f += _check(p1.input.jump_pressed and p1.input.jump_held, "P1 W -> jump_pressed first poll")
	p1.poll(0.016)
	f += _check(not p1.input.jump_pressed and p1.input.jump_held, "P1 jump_pressed clears, held stays")

	# P1 interact / use.
	p1.handle_event(_key(KEY_E, true))
	p1.handle_event(_key(KEY_Q, true))
	p1.poll(0.016)
	f += _check(p1.input.interact_pressed, "P1 E -> interact_pressed")
	f += _check(p1.input.use_pressed, "P1 Q -> use_pressed")

	# P2 arrows.
	p2.handle_event(_key(KEY_LEFT, true))
	p2.poll(0.016)
	f += _check(p2.input.move == Vector2(-1, 0), "P2 Left -> move.x -1")

	# Shift location: LEFT shift must be ignored, RIGHT shift = P2 interact.
	p2.handle_event(_key(KEY_SHIFT, true, KEY_LOCATION_LEFT))
	p2.poll(0.016)
	f += _check(not p2.input.interact_held, "P2 LEFT shift ignored")
	p2.handle_event(_key(KEY_SHIFT, true, KEY_LOCATION_RIGHT))
	p2.poll(0.016)
	f += _check(p2.input.interact_pressed and p2.input.interact_held, "P2 RIGHT shift -> interact")

	# P2 Enter = use.
	p2.handle_event(_key(KEY_ENTER, true))
	p2.poll(0.016)
	f += _check(p2.input.use_pressed and p2.input.use_held, "P2 Enter -> use")

	# reset() clears everything.
	p2.reset()
	p2.poll(0.016)
	f += _check(p2.input.move == Vector2.ZERO and not p2.input.use_held and not p2.input.interact_held,
		"reset() clears held state")

	return f

func _test_hub() -> int:
	print("[hub]")
	var f := 0
	var hub: Node = get_node("/root/InputHub")  # the live autoload
	f += _check(hub != null, "InputHub autoload is present")
	if hub == null:
		return f

	f += _check(hub.player_count() == 2, "hub registers 2 players")
	f += _check(hub.get_input(0) != null, "hub.get_input(0) returns a snapshot")
	f += _check(hub.get_input(1) != null, "hub.get_input(1) returns a snapshot")
	f += _check(hub.get_input(2) == null, "hub.get_input(2) is null (out of range)")

	# Route a P1 event through the hub like a real frame would.
	hub._input(_key(KEY_D, true))
	hub._physics_process(0.016)
	f += _check(hub.get_input(0).move == Vector2(1, 0), "hub routes P1 D to player 0")
	f += _check(hub.get_input(1).move == Vector2.ZERO, "hub keeps players isolated")

	return f
