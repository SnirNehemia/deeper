class_name CrewVisual
extends Node2D

## Placeholder crew body: a colored capsule with eyes and two little feet.
##
## Drawn in local space with the origin AT THE FEET (local y grows upward into
## the body), so squash/stretch scaling pivots on the floor contact point. The
## owning Crew sets the public fields each frame and calls queue_redraw().

## Body color (orange P1 / cyan P2).
var color: Color = Color.WHITE
## Facing direction: +1 right, -1 left (drives eye/feet bias).
var facing: float = 1.0
## True while running on the ground (animates the feet).
var running: bool = false
## Advancing counter; its integer parity picks the run frame.
var run_phase: float = 0.0

func _draw() -> void:
	var ppm: float = GameFeel.PIXELS_PER_METER
	var w := PlaceholderArt.CREW_WIDTH_M * ppm
	var h := PlaceholderArt.CREW_HEIGHT_M * ppm
	var r := w * 0.5

	# Capsule body: bottom cap at the feet, top cap at the head, rect between.
	draw_circle(Vector2(0, -r), r, color)
	draw_circle(Vector2(0, -(h - r)), r, color)
	draw_rect(Rect2(-r, -(h - r), w, h - 2.0 * r), color)

	# Eyes near the head, biased toward the facing direction.
	var eye_y := -(h - r) - 2.0
	var bias := facing * 5.0
	draw_circle(Vector2(bias - 6.0, eye_y), 4.0, Color.WHITE)
	draw_circle(Vector2(bias + 6.0, eye_y), 4.0, Color.WHITE)
	draw_circle(Vector2(bias - 6.0 + facing * 1.5, eye_y), 2.0, Color.BLACK)
	draw_circle(Vector2(bias + 6.0 + facing * 1.5, eye_y), 2.0, Color.BLACK)

	# Feet: simple 2-frame run flip (one foot lifts at a time while running).
	var foot_color := color.darkened(0.35)
	var lift := 6.0 if running else 0.0
	var phase := int(run_phase) % 2
	var left_lift := -lift if phase == 0 else 0.0
	var right_lift := -lift if phase == 1 else 0.0
	draw_rect(Rect2(-r, -5.0 + left_lift, r * 0.8, 5.0), foot_color)
	draw_rect(Rect2(r * 0.2, -5.0 + right_lift, r * 0.8, 5.0), foot_color)
