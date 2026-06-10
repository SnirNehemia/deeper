class_name InputProvider
extends RefCounted

## Base class for anything that produces a PlayerInput.
##
## Subclasses translate one input source (split keyboard now; gamepad and phone
## later) into the shared PlayerInput snapshot. Gameplay never knows which
## source it is — it only reads `input`.
##
## Lifecycle, driven by InputHub each frame:
##   handle_event(event)  -- fed raw events as they arrive (event-based sources)
##   poll(delta)          -- finalize `input` once per physics frame
##   reset()              -- clear held state (e.g. window lost focus)

## The snapshot this provider keeps fresh. Consumers read it via InputHub.
var input: PlayerInput = PlayerInput.new()

## Receive a raw input event. Default: ignore (polling sources override poll()).
func handle_event(_event: InputEvent) -> void:
	pass

## Recompute `input` for this physics frame.
func poll(_delta: float) -> void:
	pass

## Drop all held state so nothing stays stuck.
func reset() -> void:
	input.clear()
