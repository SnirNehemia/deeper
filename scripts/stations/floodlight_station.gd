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
## The cone's current reach (m) — its base half-width is derived from this via
## GameFeel.floodlight.base_half_width_m(height_m), so a longer beam is
## narrower and a shorter beam is wider.
var height_m: float = GameFeel.floodlight.initial_height_m

## Whether the lamp is currently lit. Toggled by "use" — the beam is only
## drawn while this is true.
var is_on: bool = true

## The beam's live direction: base_dir rotated by aim_angle.
func beam_dir() -> Vector2:
	return base_dir.rotated(aim_angle)

func handle_input(input: PlayerInput) -> void:
	if input.use_pressed:
		is_on = not is_on
	var delta := get_physics_process_delta_time()
	var cone := deg_to_rad(GameFeel.floodlight.rotate_cone_half_angle_deg)
	# Face-relative controls (2026-06-2x): a side-mounted lamp (left/right
	# wall) aims with W/S and zooms with A/D; a top/bottom-mounted lamp aims
	# with A/D and zooms with W/S.
	aim_angle = clampf(
		aim_angle + Station.face_aim_input(base_dir, input) * deg_to_rad(GameFeel.floodlight.rotate_speed_deg) * delta,
		-cone, cone)
	height_m = clampf(
		height_m - Station.face_cross_input(base_dir, input) * GameFeel.floodlight.zoom_speed_m * delta,
		GameFeel.floodlight.min_height_m, GameFeel.floodlight.max_height_m)
