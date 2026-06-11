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

var _life: float = 0.0

func _ready() -> void:
	collision_layer = Layers.PROJECTILE
	collision_mask = Layers.TERRAIN | Layers.FISH
	monitoring = true
	monitorable = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	rotation = velocity.angle()

func _physics_process(delta: float) -> void:
	position += velocity * delta
	_life += delta
	if _life > GameFeel.turret.torpedo_lifetime:
		queue_free()
	queue_redraw()

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
