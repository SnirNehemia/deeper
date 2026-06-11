extends Node2D

## Milestone 1 world: the Shore Shelf map with the crewed sub. Drive from the
## dock, across the shallows, over the shelf edge, and down into the basin while
## the depth meter tracks you. A smooth follow-camera frames ~60 m of world.

const M := 48.0

# Fresh-run spawn points: the sub floats at the dock; crew start in the
# engine and middle rooms (local to the sub).
const SUB_SPAWN := Vector2(45.0 * M, Sub.SURFACE_FLOAT_DEPTH)
const P1_SPAWN := Vector2(-240, -60)
const P2_SPAWN := Vector2(40, -60)

var _sub: Sub
var _cam: Camera2D
var _crew: Array[Crew] = []
var _fade: ColorRect
var _shake_time: float = 0.0
var _resetting: bool = false

func _ready() -> void:
	add_child(ShoreShelf.new())

	# Sub spawns floating at the surface, just past the dock over the shallows.
	_sub = Sub.new()
	_sub.buoyancy_enabled = true  # floats at the surface, can't fly out of the water
	_sub.position = SUB_SPAWN
	add_child(_sub)
	_sub.imploded.connect(_on_imploded)

	var p1 := Crew.new()
	p1.player_index = 0
	p1.body_color = PlaceholderArt.CREW_P1_COLOR
	p1.position = P1_SPAWN  # engine room
	_sub.add_child(p1)

	var p2 := Crew.new()
	p2.player_index = 1
	p2.body_color = PlaceholderArt.CREW_P2_COLOR
	p2.position = P2_SPAWN    # middle room
	_sub.add_child(p2)
	_crew = [p1, p2]

	# Territorial fish: one guarding the cave mouth, two around the basin
	# pillars. They reset home via the "fish" group on implosion.
	_add_fish(Vector2(70.0 * M, 64.0 * M))    # cave mouth
	_add_fish(Vector2(96.0 * M, 47.0 * M))    # first pillar
	_add_fish(Vector2(138.0 * M, 54.0 * M))   # third pillar

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

	var alerts := AlertHud.new()
	add_child(alerts)
	alerts.watch(_sub)

	# Implosion fade overlay (above everything; transparent until needed).
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 10
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade)

	_add_hint_label()

func _physics_process(delta: float) -> void:
	if _sub != null and _cam != null:
		_cam.global_position = _sub.global_position
		# Implosion crunch: brief camera shake.
		if _shake_time > 0.0:
			_shake_time -= delta
			_cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 14.0
		else:
			_cam.offset = Vector2.ZERO

## Lose condition: too much water. Crunch (~1.5s of shake + hull crumple +
## fade to dark), then a clean reset back at the dock. One guard flag keeps
## re-triggers out while the sequence plays.
func _on_imploded() -> void:
	if _resetting:
		return
	_resetting = true
	_sub.drive_input = Vector2.ZERO
	_sub.play_implosion_crunch()
	_shake_time = 0.9

	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 1.0)  # fade to dark over the crunch
	await tween.finished
	await get_tree().create_timer(0.5).timeout  # a beat of darkness

	reset_run()

	var fade_in := create_tween()
	fade_in.tween_property(_fade, "color:a", 0.0, 0.6)
	_resetting = false

## One world-level routine that puts the run back at its start: sub floating
## at the dock (dry, breach-free), crew aboard and alive, fish back home.
## Future death penalties hook in here.
func reset_run() -> void:
	_sub.reset_state()
	_sub.global_position = SUB_SPAWN
	_crew[0].reset_at(P1_SPAWN)
	_crew[1].reset_at(P2_SPAWN)
	get_tree().call_group("fish", "reset_fish")
	_cam.reset_smoothing()

func _add_fish(pos: Vector2) -> void:
	var fish := Fish.new()
	fish.sub = _sub
	fish.position = pos
	add_child(fish)

func _add_hint_label() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "E / R-Shift: take a station (helm at the bow, turret mid-room) - Q / Enter: fire or hold to repair breaches - Esc quits"
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
