extends Node2D

## Milestone 1 world: the Shore Shelf map with the crewed sub. Drive from the
## dock, across the shallows, over the shelf edge, and down into the basin while
## the depth meter tracks you. A smooth follow-camera frames ~60 m of world.

const M := 48.0

var _sub: Sub
var _cam: Camera2D

func _ready() -> void:
	add_child(ShoreShelf.new())

	# Sub spawns floating at the surface, just past the dock over the shallows.
	_sub = Sub.new()
	_sub.position = Vector2(45.0 * M, 0.0)
	add_child(_sub)

	var p1 := Crew.new()
	p1.player_index = 0
	p1.body_color = PlaceholderArt.CREW_P1_COLOR
	p1.position = Vector2(-240, -60)  # engine room
	_sub.add_child(p1)

	var p2 := Crew.new()
	p2.player_index = 1
	p2.body_color = PlaceholderArt.CREW_P2_COLOR
	p2.position = Vector2(40, -60)    # middle room
	_sub.add_child(p2)

	# Fixed-zoom follow camera: ~60 m visible width, smoothed.
	_cam = Camera2D.new()
	var visible_width_m := 60.0
	var zoom := get_viewport().get_visible_rect().size.x / (visible_width_m * M)
	_cam.zoom = Vector2(zoom, zoom)
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 5.0
	add_child(_cam)
	_cam.make_current()

	var hud := DepthHud.new()
	hud.sub = _sub
	add_child(hud)

	_add_hint_label()

func _physics_process(_delta: float) -> void:
	if _sub != null and _cam != null:
		_cam.global_position = _sub.global_position

func _add_hint_label() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "Walk to the helm (bow) and press E / Right-Shift to drive. Steer out over the shelf and dive. (Esc quits)"
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.offset_top = -40
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	layer.add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	# Dev convenience only (not gameplay input): quit on Esc.
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
