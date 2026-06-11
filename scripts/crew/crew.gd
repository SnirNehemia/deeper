class_name Crew
extends CharacterBody2D

## A crew member you run, jump, and climb around the sub with.
##
## Reads its controls through the input abstraction (InputHub.get_input by
## player index) — never the keyboard directly — and applies the tunable crew
## feel from GameFeel. Builds its own collision capsule, placeholder visual, and
## ladder sensor in code so it can be dropped into any scene (or parented inside
## the moving sub, where it rides along automatically).

## Which InputHub player drives this crew (0 = P1, 1 = P2).
@export var player_index: int = 0
## Placeholder body color.
@export var body_color: Color = PlaceholderArt.CREW_P1_COLOR

var _visual: CrewVisual
var _squash_tween: Tween

# Grace timers (seconds remaining).
var _coyote: float = 0.0
var _jump_buffer: float = 0.0

# Ladder state: how many ladder zones we overlap, and whether we're climbing.
var _ladder_overlaps: int = 0
var _on_ladder: bool = false

# Station state: a station we're standing in range of, and the one we're seated
# at (driving) if any.
var _nearby_station: Station = null
var _station: Station = null

# The breach we're currently holding `use` at (repair resets if we release or
# step out of range — no partial credit).
var _repair_target: Breach = null

# Drowning: air remaining (seconds) while the head is underwater, and the
# respawn countdown while dead. Dead crew ignore all input.
var air_seconds: float = 0.0
var is_dead: bool = false
var _respawn_timer: float = 0.0
var _respawn_label: Label = null

var _facing: float = 1.0
var _run_phase: float = 0.0
var _was_on_floor: bool = false

# On foot we stand on the sub interior, the hatch deck, and bump other crew.
# While climbing we drop HATCH so the ladder can carry us through the deck hole.
const _MASK_FOOT := Layers.INTERIOR | Layers.HATCH | Layers.CREW
const _MASK_CLIMB := Layers.INTERIOR | Layers.CREW

func _ready() -> void:
	collision_layer = Layers.CREW
	collision_mask = _MASK_FOOT

	var ppm: float = GameFeel.PIXELS_PER_METER

	var collider := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = PlaceholderArt.CREW_WIDTH_M * ppm * 0.5
	capsule.height = PlaceholderArt.CREW_HEIGHT_M * ppm
	collider.shape = capsule
	add_child(collider)

	_visual = CrewVisual.new()
	_visual.color = body_color
	# Visual origin at the capsule's feet so squash/stretch pivots on the floor.
	_visual.position = Vector2(0, PlaceholderArt.CREW_HEIGHT_M * ppm * 0.5)
	add_child(_visual)

	_add_ladder_sensor()
	_add_station_sensor()

	air_seconds = GameFeel.water.air_time

func _add_ladder_sensor() -> void:
	var sensor := Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = Layers.LADDER
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(PlaceholderArt.CREW_WIDTH_M * GameFeel.PIXELS_PER_METER,
		PlaceholderArt.CREW_HEIGHT_M * GameFeel.PIXELS_PER_METER)
	shape.shape = rect
	sensor.add_child(shape)
	add_child(sensor)
	sensor.area_entered.connect(func(_a: Area2D) -> void: _ladder_overlaps += 1)
	sensor.area_exited.connect(func(_a: Area2D) -> void:
		_ladder_overlaps = maxi(0, _ladder_overlaps - 1))

func _add_station_sensor() -> void:
	var sensor := Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = Layers.STATION
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(PlaceholderArt.CREW_WIDTH_M * GameFeel.PIXELS_PER_METER,
		PlaceholderArt.CREW_HEIGHT_M * GameFeel.PIXELS_PER_METER)
	shape.shape = rect
	sensor.add_child(shape)
	add_child(sensor)
	sensor.area_entered.connect(func(a: Area2D) -> void:
		if a is Station:
			_nearby_station = a)
	sensor.area_exited.connect(func(a: Area2D) -> void:
		if a == _nearby_station:
			_nearby_station = null)

func _physics_process(delta: float) -> void:
	if is_dead:
		_tick_respawn(delta)
		return

	var input: PlayerInput = InputHub.get_input(player_index)
	var feel: GameFeel.CrewFeel = GameFeel.crew
	var ppm: float = GameFeel.PIXELS_PER_METER

	_update_air(delta)
	if is_dead:
		return

	var move_x := input.move.x if input != null else 0.0
	var move_y := input.move.y if input != null else 0.0
	var jump_pressed := input.jump_pressed if input != null else false
	var interact_pressed := input.interact_pressed if input != null else false

	# Seated at a station: hand our input to it and stay locked in the seat.
	if _station != null:
		_be_seated(input, interact_pressed)
		_update_visual(0.0, ppm, delta)
		return

	# Sit down at a station we're standing in (and that's free).
	if interact_pressed and _nearby_station != null and _nearby_station.can_enter():
		_enter_station(_nearby_station)
		_update_visual(0.0, ppm, delta)
		return

	# Grab a ladder when overlapping one and deliberately pushing up or down.
	# (Pressing down is also how you drop through the conning hatch.)
	if not _on_ladder and _ladder_overlaps > 0 and absf(move_y) > 0.5:
		_on_ladder = true

	collision_mask = _MASK_CLIMB if _on_ladder else _MASK_FOOT
	if _on_ladder:
		_move_on_ladder(move_x, move_y, feel, ppm, delta)
	else:
		_move_on_foot(move_x, jump_pressed, feel, ppm, delta)

	var use_held := input.use_held if input != null else false
	_update_repair(use_held and not _on_ladder, delta)

	_update_visual(move_x, ppm, delta)

## Hold `use` within range of a breach to patch it: progress fills over
## GameFeel.water.repair_time and fully resets the moment the hold breaks
## (released, walked away, or grabbed a ladder).
func _update_repair(repairing: bool, delta: float) -> void:
	var sub := get_parent() as Sub
	var target: Breach = null
	if repairing and sub != null:
		var range_px := GameFeel.water.repair_range_m * GameFeel.PIXELS_PER_METER
		var best := range_px
		for b in sub.breaches:
			var d := position.distance_to(b.position)
			if d <= best:
				best = d
				target = b
	if _repair_target != null and _repair_target != target \
			and is_instance_valid(_repair_target):
		_repair_target.repair_progress = 0.0
	_repair_target = target
	if target != null:
		target.repair_progress += delta / GameFeel.water.repair_time
		if target.repair_progress >= 1.0:
			sub.remove_breach(target)
			_repair_target = null

## True if the crew's waist (its origin) is below the local water surface of
## the sub room it's standing in.
func is_submerged() -> bool:
	var sub := get_parent() as Sub
	if sub == null:
		return false
	var room := sub.room_index_at(position)
	if room < 0:
		return false
	return position.y >= sub.room_water_surface_y(room)

## True if the crew's HEAD (top of the capsule) is underwater — this is what
## starts the air timer.
func is_head_submerged() -> bool:
	var sub := get_parent() as Sub
	if sub == null:
		return false
	var head := position + Vector2(0,
		-PlaceholderArt.CREW_HEIGHT_M * GameFeel.PIXELS_PER_METER * 0.5)
	var room := sub.room_index_at(position)
	if room < 0:
		return false
	return head.y >= sub.room_water_surface_y(room)

## Air timer: drains while the head is underwater, refills fast on surfacing.
## Hitting zero drowns the crew (cartoon pop, then a respawn countdown).
func _update_air(delta: float) -> void:
	var w: GameFeel.WaterFeel = GameFeel.water
	if is_head_submerged():
		air_seconds -= delta
		if air_seconds <= 0.0:
			_drown()
	else:
		air_seconds = minf(w.air_time,
			air_seconds + (w.air_time / w.air_refill_time) * delta)

func _drown() -> void:
	is_dead = true
	_respawn_timer = GameFeel.water.respawn_delay
	if _station != null:
		_exit_station()
	_repair_target = null
	velocity = Vector2.ZERO
	# Cartoon pop: a quick balloon-burst scale-up, then the body vanishes and
	# only the "respawning..." countdown stays.
	_play_scale(Vector2(1.6, 1.6), 0.2, Tween.TRANS_BACK)
	_visual.visible = false
	# A ghost shouldn't block the living: no collisions while dead.
	collision_layer = 0
	collision_mask = 0
	_show_respawn_label()

func _tick_respawn(delta: float) -> void:
	_respawn_timer -= delta
	if _respawn_label != null:
		_respawn_label.text = "respawning... %d" % int(ceil(maxf(0.0, _respawn_timer)))
	if _respawn_timer <= 0.0:
		_respawn()

func _respawn() -> void:
	is_dead = false
	air_seconds = GameFeel.water.air_time
	# Back on your feet in the helm room (just aft of the helm seat).
	position = Vector2(Sub.HELM_X - 1.5 * GameFeel.PIXELS_PER_METER, Sub.HELM_SEAT_Y)
	velocity = Vector2.ZERO
	collision_layer = Layers.CREW
	collision_mask = _MASK_FOOT
	_on_ladder = false
	_visual.visible = true
	_visual.scale = Vector2.ONE
	if _respawn_label != null:
		_respawn_label.queue_free()
		_respawn_label = null

func _show_respawn_label() -> void:
	_respawn_label = Label.new()
	_respawn_label.add_theme_font_size_override("font_size", 20)
	_respawn_label.add_theme_color_override("font_color", Color.WHITE)
	_respawn_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_respawn_label.add_theme_constant_override("outline_size", 4)
	_respawn_label.position = Vector2(-60.0, -110.0)
	add_child(_respawn_label)

func _move_on_foot(move_x: float, jump_pressed: bool, feel: GameFeel.CrewFeel,
		ppm: float, delta: float) -> void:
	var on_floor := is_on_floor()
	var water: GameFeel.WaterFeel = GameFeel.water
	var swim_mult := water.swim_speed_mult if is_submerged() else 1.0

	# Horizontal: accelerate toward target, decelerate to a stop. Dampened
	# while submerged above the waist.
	var target_vx := move_x * feel.run_max_speed * ppm * swim_mult
	var rate := feel.run_accel() if absf(target_vx) > 0.01 else feel.run_decel()
	velocity.x = move_toward(velocity.x, target_vx, rate * ppm * delta)

	# Gravity.
	velocity.y += feel.gravity() * ppm * delta

	# Jump with coyote time + input buffer. A submerged jump is weak.
	_coyote = feel.coyote_time if on_floor else _coyote - delta
	_jump_buffer = feel.jump_buffer_time if jump_pressed else _jump_buffer - delta
	if _jump_buffer > 0.0 and _coyote > 0.0:
		var jump_mult := water.swim_jump_mult if is_submerged() else 1.0
		velocity.y = -feel.jump_velocity() * ppm * jump_mult
		_jump_buffer = 0.0
		_coyote = 0.0
		_stretch()

	move_and_slide()

	# Land squash (just touched down this frame).
	if is_on_floor() and not _was_on_floor:
		_squash()
	_was_on_floor = is_on_floor()

func _move_on_ladder(move_x: float, move_y: float, feel: GameFeel.CrewFeel,
		ppm: float, delta: float) -> void:
	# Climb at a steady speed (no gravity), but keep full sideways control so you
	# can climb and move at the same time. You stay on the ladder until you
	# actually move out of its zone (or settle onto a floor below).
	velocity.y = move_y * feel.climb_speed * ppm
	var target_vx := move_x * feel.run_max_speed * ppm
	var rate := feel.run_accel() if absf(target_vx) > 0.01 else feel.run_decel()
	velocity.x = move_toward(velocity.x, target_vx, rate * ppm * delta)

	move_and_slide()

	# Detach when we leave the ladder zone, or reach a floor without climbing up.
	if _ladder_overlaps == 0:
		_on_ladder = false
	elif is_on_floor() and move_y >= 0.0:
		_on_ladder = false
	_was_on_floor = is_on_floor()

func _be_seated(input: PlayerInput, interact_pressed: bool) -> void:
	# A flooded station ejects its occupant immediately.
	if _station.is_flooded():
		_exit_station()
		return
	# Locked in the seat (which rides with the sub); feed input to the station.
	velocity = Vector2.ZERO
	global_position = _station.seat_global_position()
	if input != null:
		_station.handle_input(input)
	if interact_pressed:
		_exit_station()

func _enter_station(station: Station) -> void:
	station.enter(self)
	_station = station
	velocity = Vector2.ZERO
	_on_ladder = false

func _exit_station() -> void:
	if _station != null:
		_station.exit(self)
	_station = null

func _update_visual(move_x: float, ppm: float, delta: float) -> void:
	if absf(move_x) > 0.01:
		_facing = signf(move_x)
	var running := not _on_ladder and is_on_floor() and absf(velocity.x) > 0.1 * ppm
	if running:
		# Step cadence scales with speed so faster = quicker shuffle.
		_run_phase += (absf(velocity.x) / ppm) * delta * 4.0

	# Match the sub's cosmetic pitch: rotate the body art and slide it to where
	# the tilted floor actually is, so we don't look sunk/floating at the ends.
	# Physics stays upright; this is purely the drawing.
	var theta := _sub_pitch()
	var feet := position + Vector2(0.0, PlaceholderArt.CREW_HEIGHT_M * ppm * 0.5)
	_visual.position = feet.rotated(theta) - position
	_visual.rotation = theta

	_visual.color = body_color
	_visual.facing = _facing
	_visual.running = running
	_visual.run_phase = _run_phase
	_visual.air_fraction = clampf(air_seconds / GameFeel.water.air_time, 0.0, 1.0)
	_visual.queue_redraw()

## The cosmetic pitch of the sub we're riding (0 if we're not inside a sub).
func _sub_pitch() -> float:
	var parent := get_parent()
	if parent is Sub:
		return (parent as Sub).pitch
	return 0.0

func _squash() -> void:
	_play_scale(Vector2(1.25, 0.7), 0.12, Tween.TRANS_BACK)

func _stretch() -> void:
	_play_scale(Vector2(0.8, 1.2), 0.15, Tween.TRANS_QUAD)

func _play_scale(from: Vector2, duration: float, trans: Tween.TransitionType) -> void:
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_visual.scale = from
	_squash_tween = create_tween()
	_squash_tween.tween_property(_visual, "scale", Vector2.ONE, duration) \
		.set_trans(trans).set_ease(Tween.EASE_OUT)
