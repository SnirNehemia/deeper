extends Node2D

## Milestone 1 world: the Shore Shelf map with the crewed sub. Drive from the
## dock, across the shallows, over the shelf edge, and down into the basin while
## the depth meter tracks you. A smooth follow-camera frames ~60 m of world.

const M := 48.0

# Fresh-run spawn points: the sub floats at the dock; crew start in the
# engine and middle rooms (local to the sub).
const SUB_SPAWN := Vector2(45.0 * M, Sub.SURFACE_FLOAT_DEPTH)

## Module B: how close to the dock spawn point the sub must be to bank
## on-board salvage into the persistent save.
const DOCK_BANK_RADIUS := 15.0 * M

var _sub: Sub
var _cam: Camera2D
var _crew: Array[Crew] = []
var _fade: ColorRect
var _shake_time: float = 0.0
var _resetting: bool = false
var _depth_hud: DepthHud
var _salvage_hud: SalvageHud
var _alerts: AlertHud
var _dock_prompt: Label
var _dry_dock: DryDock = null

func _ready() -> void:
	add_child(ShoreShelf.new())

	# Sub (built from the saved loadout) + crew, floating at the dock.
	_spawn_sub_and_crew()

	# Territorial fish: guarding the cave mouth, the cave treasure cluster,
	# and the basin pillars/wreck. The shallows wreck stays unguarded. They
	# reset home via the "fish" group on implosion.
	# M5 follow-up: the basin-pillar fish are back to plain territorial (all
	# purple fish now behave the same — guard their spot, break off when the
	# sub leaves). The relentless-chase role is now exclusively the green
	# basic_chasers below, so the two aggression reads don't look identical.
	_add_fish(Vector2(70.0 * M, 64.0 * M))    # cave mouth
	_add_fish(Vector2(54.0 * M, 70.0 * M))    # cave treasure cluster
	_add_fish(Vector2(85.0 * M, 47.0 * M))    # first pillar
	_add_fish(Vector2(115.0 * M, 100.0 * M))  # second pillar / basin wreck
	_add_fish(Vector2(148.0 * M, 54.0 * M))   # third pillar

	# M5 follow-up: two "basic_chasers" patrolling the open-water gaps between
	# the (now wider-spaced) pillars — green, elongated, relentless once they
	# spot the sub.
	_add_fish(Vector2(99.0 * M, 75.0 * M), false, true)
	_add_fish(Vector2(132.0 * M, 90.0 * M), false, true)

	# Fixed-zoom follow camera: ~60 m visible width, smoothed.
	_cam = Camera2D.new()
	var visible_width_m := 60.0
	var zoom := get_viewport().get_visible_rect().size.x / (visible_width_m * M)
	_cam.zoom = Vector2(zoom, zoom)
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 5.0
	add_child(_cam)
	_cam.make_current()

	_depth_hud = DepthHud.new()
	_depth_hud.sub = _sub
	add_child(_depth_hud)

	_alerts = AlertHud.new()
	add_child(_alerts)
	_alerts.watch(_sub)

	_salvage_hud = SalvageHud.new()
	_salvage_hud.sub = _sub
	add_child(_salvage_hud)

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
	_add_dock_prompt()

## Build the sub from the saved loadout and seat the two crew inside it.
func _spawn_sub_and_crew() -> void:
	_sub = Sub.new()
	_sub.loadout = SaveData.loadout
	_sub.layout = SaveData.layout  # the persisted sub shape (M4)
	_sub.buoyancy_enabled = true  # floats at the surface, can't fly out of the water
	_sub.position = SUB_SPAWN
	add_child(_sub)
	_sub.imploded.connect(_on_imploded)

	var p1 := Crew.new()
	p1.player_index = 0
	p1.body_color = PlaceholderArt.CREW_P1_COLOR
	p1.position = _sub.tower_seat_local(0)  # conning tower, seat 1
	_sub.add_child(p1)

	var p2 := Crew.new()
	p2.player_index = 1
	p2.body_color = PlaceholderArt.CREW_P2_COLOR
	p2.position = _sub.tower_seat_local(1)  # conning tower, seat 2
	_sub.add_child(p2)
	_crew = [p1, p2]

func _physics_process(delta: float) -> void:
	if _sub != null and _cam != null:
		_cam.global_position = _sub.global_position
		# Implosion crunch: brief camera shake.
		if _shake_time > 0.0:
			_shake_time -= delta
			_cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 14.0
		else:
			_cam.offset = Vector2.ZERO

	# Module B: returning to the dock banks whatever's on board.
	# Module D: while docked, the dry dock can be opened to spend it.
	if _sub != null:
		_sub.try_bank(SUB_SPAWN, DOCK_BANK_RADIUS)
		if _dock_prompt != null:
			_dock_prompt.visible = _is_docked() and _dry_dock == null

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
	# M5: nothing persists between rounds yet (Snir will decide later what
	# should) — wipe banked salvage, loadout, and layout back to the starting
	# Minnow+ before rebuilding the sub.
	SaveData.reset_for_test()
	_rebuild_sub()
	_sub.global_position = SUB_SPAWN
	_crew[0].reset_at(_sub.tower_seat_local(0))
	_crew[1].reset_at(_sub.tower_seat_local(1))
	get_tree().call_group("fish", "reset_fish")
	get_tree().call_group("wreck", "reset_wreck")
	get_tree().call_group("salvage_carcass", "queue_free")
	get_tree().call_group("carryable", "queue_free")  # loose/caged catches in the hold
	_cam.reset_smoothing()

func _add_fish(pos: Vector2, is_hunter := false, is_chaser := false) -> void:
	var fish := Fish.new()
	fish.sub = _sub
	fish.position = pos
	fish.is_hunter = is_hunter
	fish.is_chaser = is_chaser
	add_child(fish)

func _add_hint_label() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "Claw: stick swings shoulder / elbow, Q snaps the cage, fold home + Q drops the catch into the hold - on foot: Q picks up / carries a catch, Q at the storage cage stows it - Esc quits"
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.offset_top = -40
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	layer.add_child(label)

## "Press Tab: Dry Dock" prompt, shown only while floating at the dock.
func _add_dock_prompt() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_dock_prompt = Label.new()
	_dock_prompt.text = "At the dock — press Tab to open the Dry Dock and spend salvage"
	_dock_prompt.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_dock_prompt.offset_top = 70
	_dock_prompt.offset_left = -360
	_dock_prompt.size = Vector2(720, 40)
	_dock_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock_prompt.add_theme_font_size_override("font_size", 24)
	_dock_prompt.add_theme_color_override("font_color", Color("e0c060"))
	_dock_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_dock_prompt.add_theme_constant_override("outline_size", 5)
	_dock_prompt.visible = false
	layer.add_child(_dock_prompt)

func _is_docked() -> bool:
	return _sub != null \
		and _sub.global_position.distance_to(SUB_SPAWN) <= DOCK_BANK_RADIUS

## Open the dry dock (pauses the run). On close, if anything was bought, the
## sub is rebuilt so the new room/upgrades take effect immediately.
func _open_dry_dock() -> void:
	if _dry_dock != null or _resetting:
		return
	_dry_dock = DryDock.new()
	add_child(_dry_dock)
	_dry_dock.closed.connect(_on_dry_dock_closed)

func _on_dry_dock_closed(changed: bool) -> void:
	_dry_dock = null
	if changed:
		_rebuild_sub()

## Rebuild the sub from the (possibly upgraded) loadout, at the dock, with a
## fresh crew aboard. Used after a dry-dock purchase so changes show up now.
func _rebuild_sub() -> void:
	_sub.queue_free()  # frees its crew + stations too
	_spawn_sub_and_crew()
	_depth_hud.sub = _sub
	_salvage_hud.sub = _sub
	_alerts.watch(_sub)
	_cam.reset_smoothing()

func _unhandled_input(event: InputEvent) -> void:
	# Dev convenience only (not gameplay input): quit on Esc, dry dock on Tab.
	if not (event is InputEventKey) or not event.pressed:
		return
	if event.keycode == KEY_ESCAPE:
		get_tree().quit()
	elif event.keycode == KEY_TAB and _is_docked():
		_open_dry_dock()
		# Consume so this same press doesn't reach the dock as a "close".
		get_viewport().set_input_as_handled()
