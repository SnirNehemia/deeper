class_name TurretStation
extends Station

## The torpedo turret: gunner seat in the middle flex room, tube bow-mounted
## next to the helm. The gunner sweeps the barrel continuously with W/S (the
## tube is on the vertical bow wall), the angle holds where they leave it, and
## it's clamped to a forward cone — so the helm must still point the sub at
## threats. `use` fires slow torpedoes with infinite ammo. The barrel itself is
## drawn by SubVisual so it tilts with the hull (playtest #6/#8).

## Where the tube sits on the hull, in sub-local space (bow, mid-height).
const TUBE_LOCAL := Vector2(Sub.HALF_W + 36.0, -Sub.ROOM_H * 0.5)

## Current aim angle in radians (0 = straight ahead off the bow, + = down).
var aim_angle: float = 0.0

var _cooldown: float = 0.0

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)

func is_ready_to_fire() -> bool:
	return _cooldown <= 0.0

func handle_input(input: PlayerInput) -> void:
	# Continuous aim: W/S (move.y) nudge the barrel up/down; it holds its angle
	# and clamps to the forward cone. A/D (move.x) is ignored — the tube is on
	# the vertical bow wall.
	var cone := deg_to_rad(GameFeel.turret.cone_half_angle_deg)
	var delta := get_physics_process_delta_time()
	aim_angle = clampf(
		aim_angle + input.move.y * deg_to_rad(GameFeel.turret.aim_speed_deg) * delta,
		-cone, cone)
	if input.use_held and _cooldown <= 0.0:
		_fire()

func _fire() -> void:
	_cooldown = GameFeel.turret.fire_cooldown
	# The visible barrel tilts with the hull's cosmetic pitch, so launch the
	# torpedo along that same tilted line (keeps shot + barrel aligned).
	var world_angle := aim_angle + sub.pitch
	var dir := Vector2.from_angle(world_angle)
	var torpedo := Torpedo.new()
	torpedo.velocity = dir * GameFeel.turret.torpedo_speed * GameFeel.PIXELS_PER_METER
	# Launch into the world (not the sub) so it flies free of the hull.
	var world := sub.get_parent()
	world.add_child(torpedo)
	torpedo.global_position = sub.to_global(TUBE_LOCAL.rotated(sub.pitch)) + dir * 30.0
