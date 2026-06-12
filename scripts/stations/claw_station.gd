class_name ClawStation
extends Station

## The salvage claw: a belly-mounted arm operated from the lower claw room.
## The operator aims with the stick (the arm reaches out the bottom of the
## sub, so it points down into a cone) and HOLDS `use` to extend it. When the
## claw tip touches a piece of salvage it grips it, then automatically reels
## back in and drops it into on-board storage. This is the only way to collect
## salvage (Module C: the hull no longer auto-collects).
##
## Like the turret, the arm is drawn by SubVisual so it tilts with the hull's
## cosmetic pitch; grabbing uses that same tilted tip position so what you see
## is what you grab.

## Where the arm is anchored on the keel, in sub-local space (bottom-center of
## the claw room's belly).
const ANCHOR_LOCAL := Vector2(0.0, Sub.LOWER_BOTTOM_Y)

## Max reach of the arm (px) and how fast it extends/retracts (px/s).
const MAX_REACH := 5.0 * Sub.PPM
const EXTEND_SPEED := 4.0 * Sub.PPM
const RETRACT_SPEED := 6.0 * Sub.PPM
## How close the tip must get to a salvage item to grip it.
const GRAB_RADIUS := 0.5 * Sub.PPM
## The arm points down out of the keel; aim is clamped to this half-cone off
## of straight-down (so it can angle to either side but never reach upward
## through the hull).
const AIM_HALF_CONE := deg_to_rad(70.0)

## Current extension length (0 = fully retracted) and aim direction (sub-local,
## generally downward). Read by SubVisual to draw the arm.
var length: float = 0.0
var aim_dir: Vector2 = Vector2.DOWN

## The salvage item currently gripped (being reeled in), or null.
var _held_item: SalvageItem = null

func handle_input(input: PlayerInput) -> void:
	var delta := get_physics_process_delta_time()

	if _held_item != null:
		# Holding a catch: ignore aim/extend, just reel it in.
		_retract(delta)
		_held_item.global_position = _tip_global()
		if length <= 0.5:
			_deposit_held()
		return

	# Free arm: aim it where the stick points (clamped to the downward cone),
	# and extend while `use` is held, retract otherwise.
	if input.move.length() > 0.2:
		aim_dir = _clamp_to_cone(input.move.normalized())
	if input.use_held:
		length = minf(MAX_REACH, length + EXTEND_SPEED * delta)
		_try_grab()
	else:
		_retract(delta)

## When unoccupied, the arm simply retracts and parks.
func _physics_process(_delta: float) -> void:
	if occupant == null and length > 0.0:
		length = maxf(0.0, length - RETRACT_SPEED * get_physics_process_delta_time())

func exit(crew: Crew) -> void:
	super.exit(crew)
	# Drop any catch back into the water if the operator bails mid-haul.
	_held_item = null

func _retract(delta: float) -> void:
	length = maxf(0.0, length - RETRACT_SPEED * delta)

## Clamp an aim direction into the downward half-cone (never points up through
## the hull).
func _clamp_to_cone(dir: Vector2) -> Vector2:
	var ang := Vector2.DOWN.angle_to(dir)
	ang = clampf(ang, -AIM_HALF_CONE, AIM_HALF_CONE)
	return Vector2.DOWN.rotated(ang)

## The tip position in world space, matching the hull's cosmetic pitch tilt.
func _tip_global() -> Vector2:
	var tip_local := ANCHOR_LOCAL + aim_dir * length
	return sub.to_global(tip_local.rotated(sub.pitch))

## Grip the nearest salvage item within reach of the tip, if any.
func _try_grab() -> void:
	var tip := _tip_global()
	var best: SalvageItem = null
	var best_d := GRAB_RADIUS
	for node in sub.get_tree().get_nodes_in_group("salvage"):
		var item := node as SalvageItem
		if item == null or item.is_queued_for_deletion():
			continue
		var d := tip.distance_to(item.global_position)
		if d <= best_d:
			best_d = d
			best = item
	if best != null:
		_held_item = best
		best.set_deferred("monitoring", false)

func _deposit_held() -> void:
	if _held_item != null:
		sub.deposit_salvage(_held_item.kind)
		_held_item.queue_free()
		_held_item = null
