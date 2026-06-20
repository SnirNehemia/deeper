class_name PlayerInput
extends RefCounted

## One player's control state for the current frame.
##
## This is the ONLY thing gameplay code is allowed to read for input. It never
## touches the keyboard, a gamepad, or a network socket directly — an
## InputProvider fills this in. Swap the provider (keyboard -> gamepad -> phone)
## and every consumer keeps working unchanged.
##
## Axis convention matches Godot screen space: move.x is +1 right / -1 left,
## move.y is +1 down / -1 up. So "press up" (jump key / climb-up) reads as
## move.y == -1, and the helm can do `velocity += move * accel` directly.

## Direction the player is pushing, each axis in [-1, 1].
var move: Vector2 = Vector2.ZERO

## Jump / climb-up control (P1 W, P2 Up). "pressed" is the rising edge this
## frame; "held" is true for as long as the key is down.
var jump_pressed: bool = false
var jump_held: bool = false

## Interact control — enter/exit stations, etc. (P1 E, P2 /).
var interact_pressed: bool = false
var interact_held: bool = false

## Use control — fire / activate a station's action (P1 Q, P2 .).
var use_pressed: bool = false
var use_held: bool = false

## Reset everything to neutral (e.g. on focus loss so no key "sticks").
func clear() -> void:
	move = Vector2.ZERO
	jump_pressed = false
	jump_held = false
	interact_pressed = false
	interact_held = false
	use_pressed = false
	use_held = false
