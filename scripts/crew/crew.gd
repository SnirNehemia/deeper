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

func _physics_process(delta: float) -> void:
	var input: PlayerInput = InputHub.get_input(player_index)
	var feel: GameFeel.CrewFeel = GameFeel.crew
	var ppm: float = GameFeel.PIXELS_PER_METER

	var move_x := input.move.x if input != null else 0.0
	var move_y := input.move.y if input != null else 0.0
	var jump_pressed := input.jump_pressed if input != null else false

	# Grab a ladder when overlapping one and deliberately pushing up or down.
	# (Pressing down is also how you drop through the conning hatch.)
	if not _on_ladder and _ladder_overlaps > 0 and absf(move_y) > 0.5:
		_on_ladder = true

	collision_mask = _MASK_CLIMB if _on_ladder else _MASK_FOOT
	if _on_ladder:
		_move_on_ladder(move_x, move_y, feel, ppm, delta)
	else:
		_move_on_foot(move_x, jump_pressed, feel, ppm, delta)

	_update_visual(move_x, ppm, delta)

func _move_on_foot(move_x: float, jump_pressed: bool, feel: GameFeel.CrewFeel,
		ppm: float, delta: float) -> void:
	var on_floor := is_on_floor()

	# Horizontal: accelerate toward target, decelerate to a stop.
	var target_vx := move_x * feel.run_max_speed * ppm
	var rate := feel.run_accel() if absf(target_vx) > 0.01 else feel.run_decel()
	velocity.x = move_toward(velocity.x, target_vx, rate * ppm * delta)

	# Gravity.
	velocity.y += feel.gravity() * ppm * delta

	# Jump with coyote time + input buffer.
	_coyote = feel.coyote_time if on_floor else _coyote - delta
	_jump_buffer = feel.jump_buffer_time if jump_pressed else _jump_buffer - delta
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = -feel.jump_velocity() * ppm
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

func _update_visual(move_x: float, ppm: float, delta: float) -> void:
	if absf(move_x) > 0.01:
		_facing = signf(move_x)
	var running := not _on_ladder and is_on_floor() and absf(velocity.x) > 0.1 * ppm
	if running:
		# Step cadence scales with speed so faster = quicker shuffle.
		_run_phase += (absf(velocity.x) / ppm) * delta * 4.0
	_visual.color = body_color
	_visual.facing = _facing
	_visual.running = running
	_visual.run_phase = _run_phase
	_visual.queue_redraw()

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
