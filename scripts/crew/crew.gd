class_name Crew
extends CharacterBody2D

## A crew member you run and jump around the sub with.
##
## Reads its controls through the input abstraction (InputHub.get_input by
## player index) — never the keyboard directly — and applies the tunable crew
## feel from GameFeel. Builds its own collision capsule and placeholder visual in
## code so it can be dropped into any scene.
##
## Movement feel: weighty run accel/decel, a fixed-apex jump softened by coyote
## time and an input buffer, plus squash-on-land / stretch-on-jump.

## Which InputHub player drives this crew (0 = P1, 1 = P2).
@export var player_index: int = 0
## Placeholder body color.
@export var body_color: Color = PlaceholderArt.CREW_P1_COLOR

var _visual: CrewVisual
var _squash_tween: Tween

# Grace timers (seconds remaining).
var _coyote: float = 0.0
var _jump_buffer: float = 0.0

var _facing: float = 1.0
var _run_phase: float = 0.0
var _was_on_floor: bool = false

func _ready() -> void:
	var ppm: float = GameFeel.PIXELS_PER_METER

	var collider := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = PlaceholderArt.CREW_WIDTH_M * ppm * 0.5
	capsule.height = PlaceholderArt.CREW_HEIGHT_M * ppm
	collider.shape = capsule
	add_child(collider)

	_visual = CrewVisual.new()
	_visual.color = body_color
	# Place the visual's origin at the capsule's feet (bottom).
	_visual.position = Vector2(0, PlaceholderArt.CREW_HEIGHT_M * ppm * 0.5)
	add_child(_visual)

func _physics_process(delta: float) -> void:
	var input: PlayerInput = InputHub.get_input(player_index)
	var feel: GameFeel.CrewFeel = GameFeel.crew
	var ppm: float = GameFeel.PIXELS_PER_METER

	var move_x := input.move.x if input != null else 0.0
	var jump_pressed := input.jump_pressed if input != null else false

	var on_floor := is_on_floor()

	# --- Horizontal: accelerate toward target, decelerate to a stop ---
	var target_vx := move_x * feel.run_max_speed * ppm
	var rate := feel.run_accel() if absf(target_vx) > 0.01 else feel.run_decel()
	velocity.x = move_toward(velocity.x, target_vx, rate * ppm * delta)

	# --- Gravity ---
	velocity.y += feel.gravity() * ppm * delta

	# --- Jump with coyote time + input buffer ---
	_coyote = feel.coyote_time if on_floor else _coyote - delta
	_jump_buffer = feel.jump_buffer_time if jump_pressed else _jump_buffer - delta
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = -feel.jump_velocity() * ppm
		_jump_buffer = 0.0
		_coyote = 0.0
		_stretch()

	move_and_slide()

	# --- Land squash (just touched down this frame) ---
	var landed_now := is_on_floor() and not _was_on_floor
	if landed_now:
		_squash()
	_was_on_floor = is_on_floor()

	# --- Visual: facing + run animation ---
	if absf(move_x) > 0.01:
		_facing = signf(move_x)
	var running := is_on_floor() and absf(velocity.x) > 0.1 * ppm
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
