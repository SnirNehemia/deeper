extends Node2D

## Sub interior + helm playtest: a submarine with two crew inside, free to move
## through the ocean once someone takes the helm. A faint grid shows motion and
## the camera follows the sub. (The real ocean map / depth meter come next.)

var _sub: Sub
var _cam: Camera2D

func _ready() -> void:
	_add_background()

	var grid := GridBackground.new()
	grid.z_index = -50
	add_child(grid)

	_sub = Sub.new()
	add_child(_sub)

	# Crew are CHILDREN of the sub, so they ride along as it moves.
	var p1 := Crew.new()
	p1.player_index = 0
	p1.body_color = PlaceholderArt.CREW_P1_COLOR
	p1.position = Vector2(-240, -60)  # engine room (stern)
	_sub.add_child(p1)

	var p2 := Crew.new()
	p2.player_index = 1
	p2.body_color = PlaceholderArt.CREW_P2_COLOR
	p2.position = Vector2(40, -60)    # middle room, near the ladder
	_sub.add_child(p2)

	_cam = Camera2D.new()
	_cam.position = Vector2(0, -40)
	add_child(_cam)
	_cam.make_current()

	_add_hint_label()

func _physics_process(_delta: float) -> void:
	# Simple follow: keep the sub framed while driving (smooth camera comes later).
	if _sub != null and _cam != null:
		_cam.global_position = _sub.global_position + Vector2(0, -40)

func _add_background() -> void:
	var bg := ColorRect.new()
	bg.color = PlaceholderArt.SANDBOX_BG
	bg.size = Vector2(20000, 16000)
	bg.position = Vector2(-10000, -8000)
	bg.z_index = -100
	add_child(bg)

func _add_hint_label() -> void:
	# A CanvasLayer keeps the hint pinned to the screen as the camera moves.
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "Walk to the helm (bow/right room) and press E (P1) / Right-Shift (P2) to drive. Move to steer. Press again to leave. (Esc quits)"
	label.position = Vector2(20, 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	layer.add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	# Dev convenience only (not gameplay input): quit on Esc.
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
