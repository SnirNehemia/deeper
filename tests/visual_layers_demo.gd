extends Node2D

## M6 Module 4 visual check (for Snir): loads the test map's checkerboard
## background/foreground through MapVisualLayers and drops a placeholder
## "sub" rect in between, so the full stacking order and the water shimmer
## are visible together.
##
## Run: godot --path . res://tests/visual_layers_demo.tscn
## Expect: a dark-blue/navy checkerboard background, a grey square "sub" on
## top of it, a sparse dark checker "foreground" in front of everything, and
## the whole picture gently wobbling left/right in a slow sine wave (the
## ambient water shimmer).

func _ready() -> void:
	var config := MapConfig.load_from_json("res://maps/test_map/test_map.json")
	var layers := MapVisualLayers.build(config)
	add_child(layers)

	# Placeholder "sub": a plain rect at gameplay z_index (0), between the
	# background (-100) and the shimmer/foreground (50/100).
	var sub_rect := ColorRect.new()
	sub_rect.color = PlaceholderArt.HULL_COLOR
	sub_rect.size = Vector2(3, 2) * GameFeel.PIXELS_PER_METER
	sub_rect.position = Vector2(3, 4) * GameFeel.PIXELS_PER_METER
	sub_rect.z_index = 0
	add_child(sub_rect)

	# Fixed camera framing the whole 10x10m test map.
	var cam := Camera2D.new()
	var visible_width_m := 10.0
	var zoom := get_viewport().get_visible_rect().size.x / (visible_width_m * GameFeel.PIXELS_PER_METER)
	cam.zoom = Vector2(zoom, zoom)
	cam.position = Vector2(5, 5) * GameFeel.PIXELS_PER_METER
	add_child(cam)
	cam.make_current()

	var label := Label.new()
	label.text = "M6-4 demo: background / placeholder sub / water shimmer / foreground. Esc to quit."
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
