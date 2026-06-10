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

func _draw() -> void:
	# Placeholder console: a small box, brighter when free, dim when occupied.
	var color := PlaceholderArt.SUB_STRUCTURE if occupant == null else PlaceholderArt.SUB_FLOOR
	draw_rect(Rect2(-16, -8, 32, 24), color)
	draw_rect(Rect2(-3, -22, 6, 16), PlaceholderArt.SUB_STRUCTURE)  # control column
	draw_circle(Vector2(0, -24), 7, PlaceholderArt.LADDER_COLOR)    # wheel
