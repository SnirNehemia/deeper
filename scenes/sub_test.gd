extends Node2D

## Sub interior playtest: a stationary submarine with two crew inside, so we can
## verify running through all three rooms and climbing the ladder to the conning
## area before the sub starts moving (that arrives with the helm).

func _ready() -> void:
	_add_background()

	var sub := Sub.new()
	sub.position = Vector2(0, 40)
	add_child(sub)

	# Crew are CHILDREN of the sub, so they'll ride along once it moves.
	var p1 := Crew.new()
	p1.player_index = 0
	p1.body_color = PlaceholderArt.CREW_P1_COLOR
	p1.position = Vector2(-240, -60)  # engine room (stern)
	sub.add_child(p1)

	var p2 := Crew.new()
	p2.player_index = 1
	p2.body_color = PlaceholderArt.CREW_P2_COLOR
	p2.position = Vector2(40, -60)    # middle room, near the ladder
	sub.add_child(p2)

	var cam := Camera2D.new()
	cam.position = Vector2(0, -80)
	add_child(cam)
	cam.make_current()

	_add_hint_label()

func _add_background() -> void:
	var bg := ColorRect.new()
	bg.color = PlaceholderArt.SANDBOX_BG
	bg.size = Vector2(4000, 2000)
	bg.position = Vector2(-2000, -1500)
	bg.z_index = -100
	add_child(bg)

func _add_hint_label() -> void:
	var label := Label.new()
	label.text = "P1: A/D move, W jump, W/S on ladder    P2: arrows, Up/Down on ladder    (Esc quits)"
	label.position = Vector2(-680, -380)
	label.add_theme_color_override("font_color", Color.WHITE)
	add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	# Dev convenience only (not gameplay input): quit on Esc.
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
