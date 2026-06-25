class_name Torpedo
extends Area2D

## A slow, weighty torpedo: travels straight at a fixed speed with a small
## bubble trail. Terrain hit = harmless puff. Fish hit = the fish dies (one
## hit kills — handled by the fish). Never collides with the own sub hull.
##
## Spawned by TurretStation into the world (not parented to the sub, so it
## doesn't ride along after launch).

## Flight velocity in px/s, set by the turret at launch.
var velocity: Vector2 = Vector2.ZERO

## Sky zones from the map — projectiles arc downward in air (gravity), not water.
var sky_zones: Array = []

## Seconds before an unspent shot fizzles out. Overridden by Bullet (M4-12).
var lifetime: float = GameFeel.turret.torpedo_lifetime

## Collision circle radius, px. Overridden by Bullet (M4-12) for a smaller hitbox.
var radius: float = 8.0

## MILESTONE_9.md — THE SPITTER. The shot's live remaining damage, initialised
## at spawn from its weapon's GameFeel damage. A spitter Bubble (the game's first
## destructible projectile) reads this in its "duel" and decrements it when a
## strong shot pierces through — so carry-over damage is reduced by the hp the
## bubble soaked. Nothing else reads it; fish/wreck still one-shot off the flat
## GameFeel damage, so the default one-hit-destroy on terrain/fish is untouched.
var damage_remaining: float = 0.0

var _life: float = 0.0

func _ready() -> void:
	collision_layer = Layers.PROJECTILE
	collision_mask = Layers.TERRAIN | Layers.FISH
	monitoring = true
	monitorable = true
	damage_remaining = damage_value()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	rotation = velocity.angle()

## This shot's hp damage (the same value a Fish/Wreck reads off GameFeel on a
## hit). Bullet overrides it. Used to seed `damage_remaining` and by the spitter
## Bubble's duel. Virtual so a Bullet instance reports its own (smaller) damage.
func damage_value() -> float:
	return GameFeel.turret.damage

## MILESTONE_9.md — bubble duel helpers (the ONLY additions to the player weapon
## path). slow(): a bubble always drags a passing shot. consume(): a bubble the
## shot couldn't burst through eats it. Both are driven by the Bubble, so the
## shot itself stays a dumb straight-flier and its collision mask never changes.
func slow(factor: float) -> void:
	velocity *= factor

func consume() -> void:
	queue_free()

func _physics_process(delta: float) -> void:
	_apply_sky_gravity(delta)
	position += velocity * delta
	_life += delta
	if _life > lifetime:
		queue_free()
	queue_redraw()

## Projectiles are neutrally buoyant underwater. In sky zones (or approaching
## a pocket mouth) gravity pulls them down, curving the trajectory.
func _apply_sky_gravity(delta: float) -> void:
	var ppm := GameFeel.PIXELS_PER_METER
	for zone in sky_zones:
		var rect: Rect2 = zone["rect"]
		var sz: float = zone["surface_y"]
		var in_zone: bool = rect.has_point(global_position)
		var in_approach: bool = not in_zone and zone.get("is_pocket", false) \
			and global_position.y > sz \
			and global_position.y <= sz + Sub.SURFACE_FLOAT_DEPTH \
			and global_position.x >= rect.position.x \
			and global_position.x <= rect.position.x + rect.size.x
		if in_zone or in_approach:
			var above := (sz + Sub.SURFACE_FLOAT_DEPTH) - global_position.y
			var emergence := clampf(above / Sub.EMERGE_RANGE, 0.0, 1.0)
			velocity.y += GameFeel.sub.surface_gravity * ppm * emergence * delta
			return

func _draw() -> void:
	# Body: a chunky little dart (local +x is the flight direction).
	draw_rect(Rect2(-14.0, -5.0, 24.0, 10.0), PlaceholderArt.HULL_COLOR)
	draw_circle(Vector2(10.0, 0.0), 5.0, PlaceholderArt.HULL_COLOR)
	# Trail: a few fading bubbles behind.
	for i in 3:
		var t := Time.get_ticks_msec() / 1000.0
		var off := -20.0 - i * 12.0 + fmod(t * 30.0, 12.0)
		draw_circle(Vector2(off, sin(t * 8.0 + i) * 3.0), 3.0 - i * 0.7,
			Color(0.85, 0.95, 1.0, 0.5 - i * 0.13))

func _on_body_entered(_body: Node2D) -> void:
	# Terrain: a small harmless puff, then gone. (Fish handle their own death
	# via area overlap — see Fish.)
	_spawn_puff()
	queue_free()

## A brief expanding bubble-burst where the torpedo fizzled.
func _spawn_puff() -> void:
	var puff := Puff.new()
	puff.global_position = global_position
	get_parent().add_child(puff)

class Puff extends Node2D:
	var _age: float = 0.0
	const _LIFETIME := 0.4

	func _process(delta: float) -> void:
		_age += delta
		if _age >= _LIFETIME:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var t := _age / _LIFETIME
		var alpha := 1.0 - t
		draw_arc(Vector2.ZERO, 6.0 + 22.0 * t, 0.0, TAU, 16,
			Color(0.9, 0.95, 1.0, alpha), 3.0)
		for i in 4:
			var ang := i * TAU / 4.0 + 0.5
			draw_circle(Vector2.from_angle(ang) * (10.0 + 14.0 * t), 3.0 * alpha,
				Color(0.9, 0.95, 1.0, alpha * 0.7))
