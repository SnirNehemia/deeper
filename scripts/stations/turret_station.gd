class_name TurretStation
extends Station

## The torpedo turret: gunner seat in the middle flex room, tube bow-mounted
## next to the helm. The gunner sweeps the barrel continuously with W/S (the
## tube is on the vertical bow wall), the angle holds where they leave it, and
## it's clamped to a forward cone — so the helm must still point the sub at
## threats. `use` fires slow torpedoes with infinite ammo. The barrel itself is
## drawn by SubVisual so it tilts with the hull (playtest #6/#8).
##
## Also used for the Bullet Room (M4-12, ROOM_SYSTEM.md §6): same seat/aim/
## barrel, but `use_bullet = true` and `fire_cooldown`/`projectile_speed`
## reconfigured for fast, low-damage bullets instead of torpedoes.

## This gun's tube position (sub-local) and which way it faces: a unit vector
## pointing out of the hull (e.g. (1,0) = bow/right, (-1,0) = stern/left,
## (0,-1) = top, (0,1) = bottom). Always set by Sub at build time from the
## generated geometry, based on the room's `facing` (2026-06-19 "any outer
## face" rework — replaces the old +1/-1 scalar `facing`).
var tube_local: Vector2 = Vector2.ZERO
var facing_dir: Vector2 = Vector2.RIGHT

## Current aim angle in radians (0 = straight along facing_dir, + = clockwise).
var aim_angle: float = 0.0

## Time between shots (s) and projectile speed (m/s). Default to the base
## torpedo turret's feel; the Bullet Room (M4-12) overrides both at build time.
var fire_cooldown: float = GameFeel.turret.fire_cooldown
var projectile_speed: float = GameFeel.turret.torpedo_speed

## True for the Bullet Room (M4-12, ROOM_SYSTEM.md §6 "Bullet weapon room"):
## fires `Bullet` (fast, low-damage) instead of `Torpedo`.
var use_bullet: bool = false

var _cooldown: float = 0.0

## The barrel's local direction: facing_dir, tilted by aim_angle.
func barrel_dir() -> Vector2:
	return facing_dir.rotated(aim_angle)

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)

func is_ready_to_fire() -> bool:
	return _cooldown <= 0.0

func handle_input(input: PlayerInput) -> void:
	# Continuous aim, face-relative (2026-06-2x): a side-mounted gun (left/
	# right wall) aims with W/S; a top/bottom-mounted gun aims with A/D. Either
	# way the barrel holds its angle and clamps to the forward cone.
	var cone := deg_to_rad(GameFeel.turret.cone_half_angle_deg)
	var delta := get_physics_process_delta_time()
	aim_angle = clampf(
		aim_angle + Station.face_aim_input(facing_dir, input) * deg_to_rad(GameFeel.turret.aim_speed_deg) * delta,
		-cone, cone)
	if input.use_held and _cooldown <= 0.0:
		_fire()

func _fire() -> void:
	_cooldown = fire_cooldown
	# The visible barrel tilts with the hull's cosmetic pitch, so launch the
	# projectile along that same tilted line (keeps shot + barrel aligned).
	var dir := barrel_dir().rotated(sub.pitch)
	var projectile: Torpedo = Bullet.new() if use_bullet else Torpedo.new()
	projectile.velocity = dir * projectile_speed * GameFeel.PIXELS_PER_METER
	# Launch into the world (not the sub) so it flies free of the hull.
	var world := sub.get_parent()
	world.add_child(projectile)
	projectile.global_position = sub.to_global(tube_local.rotated(sub.pitch)) + dir * 30.0
	projectile.sky_zones = sub.sky_zones
