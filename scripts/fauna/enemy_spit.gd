class_name EnemySpit
extends Area2D

## A slow projectile fired by a ranged enemy (MILESTONE_8.md Module 3): travels
## straight at wherever the sub was when fired and damages it through
## breach_from_hit on contact — the same M5 damage spine a bite or a ram
## already uses, never a second path. Fizzles harmlessly on terrain or after
## its lifetime. Fired from the fish's world position, not parented to it.

## Flight velocity in px/s, set by the firing fish.
var velocity: Vector2 = Vector2.ZERO
## Severity (GameFeel.breach scale) applied on a hull hit.
var damage: float = GameFeel.enemy_ranged.damage
## Seconds before an unspent shot fizzles out.
var lifetime: float = GameFeel.enemy_ranged.projectile_lifetime_s

var _life: float = 0.0

func _ready() -> void:
	collision_layer = Layers.ENEMY_PROJECTILE
	collision_mask = Layers.SUB_HULL | Layers.TERRAIN
	monitoring = true
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	rotation = velocity.angle()

func _physics_process(delta: float) -> void:
	position += velocity * delta
	_life += delta
	if _life > lifetime:
		queue_free()
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body is Sub:
		var sub := body as Sub
		var local := sub.to_local(global_position)
		sub.breach_from_hit(sub.nearest_room(local), damage, local)
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color(0.65, 0.25, 0.7, 0.9))
	draw_circle(Vector2(-7.0, 0.0), 3.0, Color(0.65, 0.25, 0.7, 0.5))
