class_name KeyboardProvider
extends InputProvider

## Turns a fixed set of physical keys into a PlayerInput.
##
## Two of these run at once for split-keyboard couch co-op (P1 on the left of
## the board, P2 on the arrows). Held state is tracked from key events so we can
## distinguish LEFT vs RIGHT Shift (Godot has no separate keycode for them — only
## InputEventKey.location tells them apart), which keeps P1 and P2 from stepping
## on each other.
##
## Keys are matched by PHYSICAL position (physical_keycode), so the layout is
## independent of the user's keyboard language.

## A single physical key, optionally pinned to a location (left/right modifier).
class KeyBind:
	var keycode: Key
	var location: int  ## KEY_LOCATION_UNSPECIFIED (0) = any location accepted.

	func _init(p_keycode: Key, p_location: int = KEY_LOCATION_UNSPECIFIED) -> void:
		keycode = p_keycode
		location = p_location

	func matches(event: InputEventKey) -> bool:
		if event.physical_keycode != keycode:
			return false
		return location == KEY_LOCATION_UNSPECIFIED or event.location == location

var _bind_left: KeyBind
var _bind_right: KeyBind
var _bind_up: KeyBind       ## jump / climb-up
var _bind_down: KeyBind     ## climb-down / drop
var _bind_interact: KeyBind
var _bind_use: KeyBind

# Live held state, updated from key down/up events.
var _held_left: bool = false
var _held_right: bool = false
var _held_up: bool = false
var _held_down: bool = false
var _held_interact: bool = false
var _held_use: bool = false

# Held state at the previous poll, for rising-edge ("pressed") detection.
var _prev_up: bool = false
var _prev_interact: bool = false
var _prev_use: bool = false

func _init(left: KeyBind, right: KeyBind, up: KeyBind, down: KeyBind,
		interact: KeyBind, use: KeyBind) -> void:
	_bind_left = left
	_bind_right = right
	_bind_up = up
	_bind_down = down
	_bind_interact = interact
	_bind_use = use

## Player 1: A/D move, W jump+climb-up, S climb-down/drop, E interact, Q use.
static func make_player_one() -> KeyboardProvider:
	return KeyboardProvider.new(
		KeyBind.new(KEY_A),
		KeyBind.new(KEY_D),
		KeyBind.new(KEY_W),
		KeyBind.new(KEY_S),
		KeyBind.new(KEY_E),
		KeyBind.new(KEY_Q))

## Player 2: arrows move, Up jump+climb-up, Down climb-down, / interact, . use.
static func make_player_two() -> KeyboardProvider:
	return KeyboardProvider.new(
		KeyBind.new(KEY_LEFT),
		KeyBind.new(KEY_RIGHT),
		KeyBind.new(KEY_UP),
		KeyBind.new(KEY_DOWN),
		KeyBind.new(KEY_SLASH),
		KeyBind.new(KEY_PERIOD))

func handle_event(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	var down := key_event.pressed
	if _bind_left.matches(key_event):
		_held_left = down
	if _bind_right.matches(key_event):
		_held_right = down
	if _bind_up.matches(key_event):
		_held_up = down
	if _bind_down.matches(key_event):
		_held_down = down
	if _bind_interact.matches(key_event):
		_held_interact = down
	if _bind_use.matches(key_event):
		_held_use = down

func poll(_delta: float) -> void:
	input.move = Vector2(
		(1.0 if _held_right else 0.0) - (1.0 if _held_left else 0.0),
		(1.0 if _held_down else 0.0) - (1.0 if _held_up else 0.0))

	input.jump_held = _held_up
	input.jump_pressed = _held_up and not _prev_up

	input.interact_held = _held_interact
	input.interact_pressed = _held_interact and not _prev_interact

	input.use_held = _held_use
	input.use_pressed = _held_use and not _prev_use

	_prev_up = _held_up
	_prev_interact = _held_interact
	_prev_use = _held_use

func reset() -> void:
	_held_left = false
	_held_right = false
	_held_up = false
	_held_down = false
	_held_interact = false
	_held_use = false
	_prev_up = false
	_prev_interact = false
	_prev_use = false
	input.clear()
