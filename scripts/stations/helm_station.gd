class_name HelmStation
extends Station

## The helm: direct control. While a crew is seated, their move vector becomes
## the sub's drive input (accelerate left/right/up/down). Letting go (or leaving
## the seat) drops the drive to zero and the heavy sub coasts to a stop.

## The sub this helm steers (set by the sub when it builds the helm).
var sub: Sub = null

func handle_input(input: PlayerInput) -> void:
	if sub != null:
		sub.drive_input = input.move

func exit(crew: Crew) -> void:
	super.exit(crew)
	if sub != null:
		sub.drive_input = Vector2.ZERO
