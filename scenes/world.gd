extends Node2D

## World scene: loads a hand-drawn map from MapConfig when available (M6),
## otherwise falls back to the ShoreShelf test map. Sub, crew, HUD, and
## dry-dock UI are set up the same way regardless of which map is active.

const M := 48.0
const MAP_CONFIG_PATH := "res://maps/cavern_depths_01/world_01.json"

## Fallback values used with ShoreShelf (overridden by MapLoader when a map loads).
const SHORE_SHELF_SPAWN := Vector2(45.0 * M, Sub.SURFACE_FLOAT_DEPTH)
const SHORE_SHELF_DOCK_RADIUS := 15.0 * M

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

## Set by _load_map(); world uses these for spawning and dock checks.
var _sub_spawn: Vector2 = SHORE_SHELF_SPAWN
var _dock_center: Vector2 = SHORE_SHELF_SPAWN
var _dock_radius: float = SHORE_SHELF_DOCK_RADIUS
var _map_loader: MapLoader = null  # non-null when a map config was found

func _ready() -> void:
	_load_map()
	_spawn_sub_and_crew()
	_spawn_entities()

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

## Loads the hand-drawn map config if the JSON exists; otherwise falls back to
## the ShoreShelf procedural map. Populates _sub_spawn / _dock_center / _dock_radius.
func _load_map() -> void:
	if FileAccess.file_exists(MAP_CONFIG_PATH):
		var config := MapConfig.load_from_json(MAP_CONFIG_PATH)
		if config != null:
			_map_loader = MapLoader.build(config)
			add_child(_map_loader)
			_sub_spawn = _map_loader.sub_spawn
			_dock_center = _map_loader.dock_center
			_dock_radius = _map_loader.dock_radius
			return
	# Fallback: ShoreShelf placeholder map.
	add_child(ShoreShelf.new())
	_sub_spawn = SHORE_SHELF_SPAWN
	_dock_center = SHORE_SHELF_SPAWN
	_dock_radius = SHORE_SHELF_DOCK_RADIUS

## Spawn fish and wrecks: from the gen layer when a map is loaded, otherwise
## the hardcoded ShoreShelf placements used since Milestone 1.
func _spawn_entities() -> void:
	if _map_loader != null:
		for pos in _map_loader.territorial_fish_spawns:
			_add_fish(pos)
		for pos in _map_loader.hunter_fish_spawns:
			_add_fish(pos, false, true)  # green gen-layer pixels → green chasers
		for pos in _map_loader.wreck_spawns:
			_add_wreck(pos)
	else:
		_add_fish(Vector2(70.0 * M, 64.0 * M))
		_add_fish(Vector2(54.0 * M, 70.0 * M))
		_add_fish(Vector2(85.0 * M, 47.0 * M))
		_add_fish(Vector2(115.0 * M, 100.0 * M))
		_add_fish(Vector2(148.0 * M, 54.0 * M))
		_add_fish(Vector2(99.0 * M, 50.0 * M), false, true)
		_add_fish(Vector2(132.0 * M, 48.0 * M), false, true)

## Build the sub from the saved loadout and seat the two crew inside it.
func _spawn_sub_and_crew() -> void:
	_sub = Sub.new()
	_sub.loadout = SaveData.loadout
	_sub.layout = SaveData.layout
	_sub.buoyancy_enabled = true
	_sub.water_surface_y = _map_loader.water_surface_y if _map_loader != null else 0.0
	_sub.sky_zones = _map_loader.sky_zones if _map_loader != null else []
	_sub.position = _sub_spawn
	add_child(_sub)
	_sub.imploded.connect(_on_imploded)
	if _sub.hull_station != null:
		_sub.hull_station.dock_requested.connect(_on_hull_station_dock_requested)

	var p1 := Crew.new()
	p1.player_index = 0
	p1.body_color = PlaceholderArt.CREW_P1_COLOR
	p1.position = _sub.tower_seat_local(0)
	_sub.add_child(p1)

	var p2 := Crew.new()
	p2.player_index = 1
	p2.body_color = PlaceholderArt.CREW_P2_COLOR
	p2.position = _sub.tower_seat_local(1)
	_sub.add_child(p2)
	_crew = [p1, p2]

func _physics_process(delta: float) -> void:
	if _sub != null and _cam != null:
		_cam.global_position = _sub.global_position
		if _shake_time > 0.0:
			_shake_time -= delta
			_cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 14.0
		else:
			_cam.offset = Vector2.ZERO

	if _sub != null:
		_sub.try_bank(_dock_center, _dock_radius)
		if _dock_prompt != null:
			_dock_prompt.visible = _is_docked() and _dry_dock == null

func _on_imploded() -> void:
	if _resetting:
		return
	_resetting = true
	_sub.drive_input = Vector2.ZERO
	_sub.play_implosion_crunch()
	_shake_time = 0.9

	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 1.0)
	await tween.finished
	await get_tree().create_timer(0.5).timeout

	reset_run()

	var fade_in := create_tween()
	fade_in.tween_property(_fade, "color:a", 0.0, 0.6)
	_resetting = false

## Resets the run back to the start: sub at dock, crew aboard, fish home.
func reset_run() -> void:
	SaveData.reset_for_test()
	_rebuild_sub()
	_sub.global_position = _sub_spawn
	_crew[0].reset_at(_sub.tower_seat_local(0))
	_crew[1].reset_at(_sub.tower_seat_local(1))
	get_tree().call_group("fish", "reset_fish")
	get_tree().call_group("wreck", "reset_wreck")
	get_tree().call_group("salvage_carcass", "queue_free")
	get_tree().call_group("carryable", "queue_free")
	_cam.reset_smoothing()

func _add_fish(pos: Vector2, is_hunter := false, is_chaser := false) -> void:
	var fish := Fish.new()
	fish.sub = _sub
	fish.position = pos
	fish.is_hunter = is_hunter
	fish.is_chaser = is_chaser
	fish.sky_zones = _map_loader.sky_zones if _map_loader != null else []
	fish.water_surface_y = _map_loader.water_surface_y if _map_loader != null else 0.0
	add_child(fish)

func _add_wreck(pos: Vector2) -> void:
	var wreck := Wreck.new()
	wreck.position = pos
	add_child(wreck)

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

## "Press Tab: Dry Dock" prompt, shown only while near the dock.
func _add_dock_prompt() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_dock_prompt = Label.new()
	_dock_prompt.text = "At the dock — use the tower console to open the Dry Dock"
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
	if _sub == null:
		return false
	return _sub.global_position.distance_to(_dock_center) <= _dock_radius

func _on_hull_station_dock_requested() -> void:
	if _is_docked():
		_open_dry_dock()

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

func _rebuild_sub() -> void:
	_sub.queue_free()
	_spawn_sub_and_crew()
	_depth_hud.sub = _sub
	_salvage_hud.sub = _sub
	_alerts.watch(_sub)
	_cam.reset_smoothing()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	if event.keycode == KEY_ESCAPE:
		get_tree().quit()
