class_name TurretStation
extends Station

## The torpedo turret: gunner seat in the middle flex room, tube bow-mounted
## next to the helm. The seated gunner's move vector aims within a forward
## cone (the helm must point the sub at threats — steering is part of aiming);
## `use` fires slow torpedoes with infinite ammo.

## Where the tube sits on the hull, in sub-local space (bow, mid-height).
const TUBE_LOCAL := Vector2(Sub.HALF_W + 36.0, -Sub.ROOM_H * 0.5)

## Current aim angle in radians (0 = straight ahead off the bow, +down).
var aim_angle: float = 0.0

var _cooldown: float = 0.0

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	queue_redraw()

func handle_input(input: PlayerInput) -> void:
	# Aim: the move vector's direction, clamped into the forward cone.
	var cone := deg_to_rad(GameFeel.turret.cone_half_angle_deg)
	if input.move.length() > 0.3:
		aim_angle = clampf(input.move.angle(), -cone, cone)
	if input.use_held and _cooldown <= 0.0:
		_fire()

func _fire() -> void:
	_cooldown = GameFeel.turret.fire_cooldown
	var torpedo := Torpedo.new()
	torpedo.velocity = Vector2.from_angle(aim_angle) \
		* GameFeel.turret.torpedo_speed * GameFeel.PIXELS_PER_METER
	# Launch into the world (not the sub) so it flies free of the hull.
	var world := sub.get_parent()
	world.add_child(torpedo)
	torpedo.global_position = sub.to_global(TUBE_LOCAL) \
		+ Vector2.from_angle(aim_angle) * 30.0

func _draw() -> void:
	# Drawn in station-local space; offset to the bow tube.
	var tube := TUBE_LOCAL - position
	# Tube housing.
	draw_rect(Rect2(tube + Vector2(-18.0, -10.0), Vector2(28.0, 20.0)),
		PlaceholderArt.SUB_STRUCTURE)
	# Barrel + aim line while someone is gunning.
	var dir := Vector2.from_angle(aim_angle)
	draw_line(tube, tube + dir * 34.0, PlaceholderArt.SUB_STRUCTURE, 8.0)
	if occupant != null:
		draw_line(tube + dir * 34.0, tube + dir * 150.0,
			Color(1.0, 1.0, 1.0, 0.35), 2.0)
		# Cooldown hint: the line brightens when ready to fire.
		if _cooldown <= 0.0:
			draw_circle(tube + dir * 150.0, 4.0, Color(1.0, 1.0, 1.0, 0.6))
