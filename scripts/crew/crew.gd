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

# Ladder state: which ladder shafts we overlap, and whether we're climbing.
var _ladder_areas: Array[Area2D] = []
var _on_ladder: bool = false

# Station state: a station we're standing in range of, and the one we're seated
# at (driving) if any.
var _nearby_station: Station = null
var _station: Station = null

# The breach we're currently holding `use` at (repair resets if we release or
# step out of range — no partial credit).
var _repair_target: Breach = null

# A loose salvage item we're carrying to the storage cage (Module C ferry),
# or null. Hands full = can't repair.
var _carrying: SalvageItem = null
# How close (m) we must be to a loose item to pick it up.
const PICKUP_RANGE_M := 1.0

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
	sensor.area_entered.connect(func(a: Area2D) -> void: _ladder_areas.append(a))
	sensor.area_exited.connect(func(a: Area2D) -> void: _ladder_areas.erase(a))

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

	# Grab a ladder when standing in front of one and deliberately pushing up or
	# down. (Pressing down is also how you drop through the conning hatch.)
	# Checking against the ladder's own column (not the wider sensor-overlap
	# band) keeps a player who's just running and jumping past a ladder from
	# being snagged by it (playtest #1: lower-deck ladders sit in the main
	# traffic path, and "up" doubles as the jump button).
	if not _on_ladder and absf(move_y) > 0.5 and _centered_on_ladder():
		_on_ladder = true

	collision_mask = _MASK_CLIMB if _on_ladder else _MASK_FOOT
	if _on_ladder:
		_move_on_ladder(move_x, move_y, feel, ppm, delta)
	else:
		_move_on_foot(move_x, jump_pressed, feel, ppm, delta)

	# Carry salvage: a press picks up a loose item / drops or stows the one
	# we're carrying. Hands full means no repairing.
	var use_pressed := input.use_pressed if input != null else false
	if use_pressed and not _on_ladder:
		_carry_action()

	var use_held := input.use_held if input != null else false
	_update_repair(use_held and not _on_ladder and _carrying == null, delta)

	_update_visual(move_x, ppm, delta)

## Pick up / carry / drop loose salvage with `use`. Empty-handed near a loose
## item picks it up; carrying near the storage cage stows it; carrying anywhere
## else drops it on the floor.
func _carry_action() -> void:
	var sub := get_parent() as Sub
	if sub == null:
		return
	if _carrying != null:
		if sub.near_storage(position):
			if sub.deposit_salvage(_carrying.kind):
				_carrying.queue_free()
				_carrying = null
		else:
			_carrying.set_loose_at(position)
			_carrying = null
	else:
		var item := _nearest_loose(sub)
		if item != null:
			item.set_carried(self)
			_carrying = item

## True if we're ferrying a salvage item right now.
func is_carrying() -> bool:
	return _carrying != null

## Let go of any carried item where we stand (used on drown / run reset).
func _drop_carry() -> void:
	if _carrying != null:
		if is_instance_valid(_carrying):
			_carrying.set_loose_at(position)
		_carrying = null

func _nearest_loose(_sub: Sub) -> SalvageItem:
	var best: SalvageItem = null
	var best_d := PICKUP_RANGE_M * GameFeel.PIXELS_PER_METER
	for node in get_tree().get_nodes_in_group("salvage"):
		var item := node as SalvageItem
		if item == null or not item.is_loose():
			continue
		var d := position.distance_to(item.position)
		if d <= best_d:
			best_d = d
			best = item
	return best

## Hold `use` within range of a breach to patch it: progress fills over
## GameFeel.water.repair_time. Progress PERSISTS on the breach when you stop
## (playtest #5) — leave for air and resume from where you left off; a second
## crew can even take over the same breach.
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
	_repair_target = target
	if target != null:
		# "Repair Training" crew upgrade (Module D) shortens the patch time.
		var repair_time: float = GameFeel.water.repair_time * sub.repair_time_mult()
		target.repair_progress += delta / repair_time
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

## True if the crew's FEET are in water — even a shallow puddle. This is what
## slows movement (playtest #4): jump clear of the surface and it's false again.
func is_touching_water() -> bool:
	var sub := get_parent() as Sub
	if sub == null:
		return false
	var feet := position + Vector2(0,
		PlaceholderArt.CREW_HEIGHT_M * GameFeel.PIXELS_PER_METER * 0.5)
	var room := sub.room_index_at(position)
	if room < 0:
		return false
	return feet.y >= sub.room_water_surface_y(room)

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
	_drop_carry()
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
	# Back on your feet up in the conning tower (playtest #2) — the safest,
	# last-to-flood spot. The sub computes the spot from its generated geometry.
	var s := get_parent() as Sub
	if s != null:
		position = s.respawn_local()
	velocity = Vector2.ZERO
	collision_layer = Layers.CREW
	collision_mask = _MASK_FOOT
	_on_ladder = false
	_visual.visible = true
	_visual.scale = Vector2.ONE
	if _respawn_label != null:
		_respawn_label.queue_free()
		_respawn_label = null

## Snap this crew to a fresh-run state at a position inside the sub: alive,
## full air, on foot, out of any station (used by the world-level run reset).
func reset_at(local_pos: Vector2) -> void:
	if _station != null:
		_exit_station()
	is_dead = false
	air_seconds = GameFeel.water.air_time
	position = local_pos
	velocity = Vector2.ZERO
	collision_layer = Layers.CREW
	collision_mask = _MASK_FOOT
	_on_ladder = false
	_repair_target = null
	_drop_carry()
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
	# Feet in any water slow you (even a puddle); jumping clear restores speed.
	var swim_mult := water.swim_speed_mult if is_touching_water() else 1.0

	# Horizontal: accelerate toward target, decelerate to a stop. Dampened
	# whenever the feet are in water.
	var target_vx := move_x * feel.run_max_speed * ppm * swim_mult
	var rate := feel.run_accel() if absf(target_vx) > 0.01 else feel.run_decel()
	velocity.x = move_toward(velocity.x, target_vx, rate * ppm * delta)

	# Gravity.
	velocity.y += feel.gravity() * ppm * delta

	# Jump with coyote time + input buffer. A submerged jump is weak.
	_coyote = feel.coyote_time if on_floor else _coyote - delta
	_jump_buffer = feel.jump_buffer_time if jump_pressed else _jump_buffer - delta
	if _jump_buffer > 0.0 and _coyote > 0.0:
		# Only deep (waist-high) water saps the jump, so you can still hop out
		# of a shallow puddle.
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

	# Detach when we leave the ladder column (including drifting off it
	# sideways), or reach a floor without climbing up.
	if not _centered_on_ladder():
		_on_ladder = false
	elif is_on_floor() and move_y >= 0.0:
		_on_ladder = false
	_was_on_floor = is_on_floor()

## True if we're horizontally aligned with the column of a ladder we're
## overlapping (within the ladder's own width, not the wider sensor band).
func _centered_on_ladder() -> bool:
	for area in _ladder_areas:
		var shape: Node2D = area.get_child(0)
		if absf(global_position.x - shape.global_position.x) <= Sub.HOLE_W * 0.5:
			return true
	return false

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
