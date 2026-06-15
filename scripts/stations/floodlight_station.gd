class_name FloodlightStation
extends Station

## The floodlight's console seat (M4-9c rework, 2026-06-19). The room and its
## lamp are one inseparable unit (like the Bullet Room's built-in gun) — no
## detachable pod. The seated crew steers the beam left/right (aim_angle, like
## a weapon) and widens/narrows it with up/down (spread_factor), scaling both
## the cone's base width and its length together.

## The lamp's hull-surface point (sub-local) the beam fans out from.
var tip_local: Vector2 = Vector2.ZERO
## The beam's default direction (unit vector, sub-local) before aim_angle.
var base_dir: Vector2 = Vector2.RIGHT

## Current aim offset in radians from base_dir, + = clockwise.
var aim_angle: float = 0.0
## Current width/length multiplier on top of GameFeel.floodlight base sizes.
var spread_factor: float = 1.0

## The beam's live direction: base_dir rotated by aim_angle.
func beam_dir() -> Vector2:
	return base_dir.rotated(aim_angle)

func handle_input(input: PlayerInput) -> void:
	var delta := get_physics_process_delta_time()
	var cone := deg_to_rad(GameFeel.floodlight.rotate_cone_half_angle_deg)
	aim_angle = clampf(
		aim_angle + input.move.x * deg_to_rad(GameFeel.floodlight.rotate_speed_deg) * delta,
		-cone, cone)
	spread_factor = clampf(
		spread_factor - input.move.y * GameFeel.floodlight.zoom_speed * delta,
		GameFeel.floodlight.min_spread, GameFeel.floodlight.max_spread)
