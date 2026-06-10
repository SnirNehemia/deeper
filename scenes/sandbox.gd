extends Node2D

## Crew-movement playtest sandbox.
##
## Not the real game — just a floor, a few step platforms, and the two crew so
## we can answer "does running and jumping feel good?" in isolation before the
## sub interior exists. Built entirely in code (no .tscn authoring needed).

const PPM := GameFeel.PIXELS_PER_METER

func _ready() -> void:
	_add_background()
	_build_level()
	_spawn_crew()
	_add_camera()
	_add_hint_label()

func _add_background() -> void:
	var bg := ColorRect.new()
	bg.color = PlaceholderArt.SANDBOX_BG
	bg.size = Vector2(4000, 2000)
	bg.position = Vector2(-2000, -1500)
	bg.z_index = -100
	add_child(bg)

func _build_level() -> void:
	# Floor: top surface at y = 200.
	add_child(_make_box(Vector2(0, 260), Vector2(2400, 120), PlaceholderArt.TERRAIN_ROCK))
	# Side walls to keep the crew on screen.
	add_child(_make_box(Vector2(-1180, 60), Vector2(40, 520), PlaceholderArt.TERRAIN_ROCK))
	add_child(_make_box(Vector2(1180, 60), Vector2(40, 520), PlaceholderArt.TERRAIN_ROCK))
	# Step platforms ~1 m apart in height, each within a single jump (apex 1.3 m).
	add_child(_make_box(Vector2(300, 200), Vector2(220, 32), PlaceholderArt.TERRAIN_SAND))   # ~1 m up
	add_child(_make_box(Vector2(560, 152), Vector2(220, 32), PlaceholderArt.TERRAIN_SAND))   # ~2 m up
	add_child(_make_box(Vector2(820, 104), Vector2(220, 32), PlaceholderArt.TERRAIN_SAND))   # ~3 m up

## Build a static collision box with a centered colored visual.
func _make_box(center: Vector2, size: Vector2, color: Color) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = Layers.INTERIOR  # crew collide with the INTERIOR layer
	body.collision_mask = 0
	body.position = center
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	var rect := ColorRect.new()
	rect.color = color
	rect.size = size
	rect.position = -size * 0.5
	body.add_child(rect)
	return body

func _spawn_crew() -> void:
	var p1 := Crew.new()
	p1.player_index = 0
	p1.body_color = PlaceholderArt.CREW_P1_COLOR
	p1.position = Vector2(-150, 0)
	add_child(p1)

	var p2 := Crew.new()
	p2.player_index = 1
	p2.body_color = PlaceholderArt.CREW_P2_COLOR
	p2.position = Vector2(150, 0)
	add_child(p2)

func _add_camera() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2(0, 80)
	add_child(cam)
	cam.make_current()

func _add_hint_label() -> void:
	var label := Label.new()
	label.text = "P1: A/D move, W jump    P2: arrows move, Up jump    (Esc to quit)"
	label.position = Vector2(-560, -360)
	label.add_theme_color_override("font_color", Color.WHITE)
	add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	# Dev convenience only (not gameplay input): quit on Esc.
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
