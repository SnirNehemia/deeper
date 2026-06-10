class_name GridBackground
extends Node2D

## A faint static grid, purely so you can see the sub move before the real ocean
## map exists. Draws a large area of 1 m grid lines; the camera moving over it
## gives a sense of speed.

@export var spacing: float = GameFeel.PIXELS_PER_METER  ## 1 m
@export var half_extent: Vector2 = Vector2(6000, 4000)
@export var line_color := Color(1, 1, 1, 0.06)

func _draw() -> void:
	var x := -half_extent.x
	while x <= half_extent.x:
		draw_line(Vector2(x, -half_extent.y), Vector2(x, half_extent.y), line_color, 1.0)
		x += spacing
	var y := -half_extent.y
	while y <= half_extent.y:
		draw_line(Vector2(-half_extent.x, y), Vector2(half_extent.x, y), line_color, 1.0)
		y += spacing
