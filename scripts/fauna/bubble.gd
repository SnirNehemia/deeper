class_name Bubble
extends Area2D

## MILESTONE_9.md — THE SPITTER's projectile, and the game's FIRST destructible
## projectile. A pale bubble drifts toward the sub and breaches the hull on
## contact (the same breach_from_hit spine as every other attack — flooding
## stays the only death). Unlike an EnemySpit, players can shoot it out of the
## air: it carries hp, and a player shot that hits it runs a little "duel".
##
## The duel lives HERE, not in the weapon: the bubble mutates / frees the shot.
## That's why player projectile collision masks never change — only the small
## Torpedo.slow()/consume()/damage_remaining helpers were added.
##   - always SLOW the shot (a bubble drags anything that hits it);
##   - shot's remaining damage >= bubble hp  → bubble BURSTS, shot pierces and
##     continues with its damage reduced by the hp the bubble soaked;
##   - shot's remaining damage <  bubble hp  → bubble survives (hp -= damage),
##     shot is consumed. So one 1-dmg Bullet chips a 2-HP bubble and dies; a
##     second pops it; a 5-dmg turret torpedo bursts it and flies on.

## Flight velocity in px/s, set by the firing spitter.
var velocity: Vector2 = Vector2.ZERO
## Hit points — how much shot damage it takes to burst.
var hp: float = GameFeel.bubble.hp
## Breach severity (GameFeel.breach scale) applied to the hull on contact.
var damage: float = GameFeel.bubble.damage
## Seconds before an undisturbed bubble fizzles out.
var lifetime: float = GameFeel.bubble.lifetime_s
## Radius, px (also the drawn size).
var radius: float = 0.45 * GameFeel.PIXELS_PER_METER

var _life: float = 0.0
var _popped: bool = false

func _ready() -> void:
	collision_layer = Layers.BUBBLE
	# Hits the hull and terrain (a body), and is shootable by player ammo (an
	# area on the PROJECTILE layer). The bubble monitors the shot; the shot
	# never has to know about the bubble.
	collision_mask = Layers.SUB_HULL | Layers.TERRAIN | Layers.PROJECTILE
	monitoring = true
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	position += velocity * delta
	_life += delta
	if _life > lifetime:
		queue_free()
	queue_redraw()

## Hull or terrain contact: breach the sub (if it's the hull), then pop. Same
## breach spine a bite, ram, or EnemySpit uses — never a second damage path.
func _on_body_entered(body: Node2D) -> void:
	if _popped:
		return
	if body is Sub:
		var sub := body as Sub
		var local := sub.to_local(global_position)
		sub.breach_from_hit(sub.nearest_room(local), damage, local)
	_pop()

## A player shot hit the bubble — run the duel (see the class header).
func _on_area_entered(area: Area2D) -> void:
	if _popped or not (area is Torpedo):
		return
	var shot := area as Torpedo
	shot.slow(GameFeel.bubble.slow_factor)  # always drag a passing shot
	var dmg := shot.damage_remaining
	if dmg >= hp:
		# Strong enough: burst, and the shot pierces on with reduced damage.
		shot.damage_remaining = dmg - hp
		_pop()
	else:
		# Not enough to burst: the bubble soaks the hit and the shot is spent.
		hp -= dmg
		shot.consume()

func _pop() -> void:
	if _popped:
		return
	_popped = true
	var puff := Torpedo.Puff.new()
	puff.global_position = global_position
	get_parent().add_child(puff)
	queue_free()

func _draw() -> void:
	# Pale translucent bubble with a soft rim and a little highlight.
	draw_circle(Vector2.ZERO, radius, Color(0.8, 0.92, 1.0, 0.35))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(0.9, 0.97, 1.0, 0.7), 2.0)
	draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.22, Color(1, 1, 1, 0.6))
