class_name Fish
extends Area2D

## A small territorial fish (~1 m): idles/patrols around its home point, and
## if the sub enters its territory it chases and bites the hull (drip-tier
## breach per bite, with a recover pause between passes). It always breaks
## off and swims home when the sub leaves. One torpedo hit kills it (cartoon
## pop + bubbles); it stays gone until the run resets.
##
## AI is deliberately dumb: distance checks + four states, no pathfinding.
## It can't enter the cave interior — avoiding it by piloting is valid play.

enum State { PATROL, CHASE, RECOVER, RETURN }

## The sub it guards against (set at placement).
var sub: Sub = null
## Territory center; the fish spawns here and always swims back here.
var home: Vector2

var state: State = State.PATROL
var is_dead: bool = false

var _facing: float = 1.0
var _patrol_target: Vector2
var _bite_cooldown: float = 0.0
var _recover_dir: Vector2 = Vector2.ZERO
var _wobble: float = 0.0

func _ready() -> void:
	add_to_group("fish")
	home = global_position
	_patrol_target = home
	collision_layer = Layers.FISH
	collision_mask = Layers.PROJECTILE | Layers.SUB_HULL
	monitoring = true
	monitorable = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PlaceholderArt.FISH_LENGTH_M * GameFeel.PIXELS_PER_METER * 0.5
	shape.shape = circle
	add_child(shape)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	var feel: GameFeel.FishFeel = GameFeel.fish
	var ppm: float = GameFeel.PIXELS_PER_METER
	_wobble += delta
	_bite_cooldown = maxf(0.0, _bite_cooldown - delta)

	var sub_in_territory := sub != null \
		and home.distance_to(sub.global_position) <= feel.territory_radius_m * ppm

	match state:
		State.PATROL:
			_patrol(feel, ppm, delta)
			if sub_in_territory:
				state = State.CHASE
		State.CHASE:
			if not sub_in_territory:
				state = State.RETURN
			else:
				_swim_toward(sub.global_position, feel.chase_speed * ppm, delta)
				_try_bite()
		State.RECOVER:
			# Circle off after a bite, then come back for another pass.
			global_position += _recover_dir * feel.return_speed * ppm * delta
			if _bite_cooldown <= 0.0:
				state = State.CHASE if sub_in_territory else State.RETURN
		State.RETURN:
			_swim_toward(home, feel.return_speed * ppm, delta)
			if global_position.distance_to(home) < 10.0:
				state = State.PATROL
			elif sub_in_territory:
				state = State.CHASE
	queue_redraw()

func _patrol(feel: GameFeel.FishFeel, ppm: float, delta: float) -> void:
	# Drift between random points in the inner half of the territory.
	if global_position.distance_to(_patrol_target) < 12.0:
		var r := feel.territory_radius_m * ppm * 0.5
		_patrol_target = home + Vector2(randf_range(-r, r), randf_range(-r, r) * 0.5)
	_swim_toward(_patrol_target, feel.patrol_speed * ppm, delta)

func _swim_toward(target: Vector2, speed: float, delta: float) -> void:
	var dir := global_position.direction_to(target)
	global_position += dir * speed * delta
	if absf(dir.x) > 0.1:
		_facing = signf(dir.x)

## On hull contact (and off cooldown): lunge-bite — a small drip-tier breach
## at the bite point — then circle away for another pass.
func _try_bite() -> void:
	if _bite_cooldown > 0.0:
		return
	var touching := false
	for body in get_overlapping_bodies():
		if body == sub:
			touching = true
			break
	if not touching:
		return
	var local := sub.to_local(global_position)
	sub.spawn_breach(sub.nearest_room(local), GameFeel.water.bite_leak_rate, local)
	_bite_cooldown = GameFeel.fish.bite_interval
	# Circle away: mostly back the way it came, with some sideways drift.
	var away := sub.global_position.direction_to(global_position)
	_recover_dir = (away + Vector2(0, -0.5)).normalized()
	state = State.RECOVER

func _on_area_entered(area: Area2D) -> void:
	# One torpedo hit kills (the turret should feel powerful).
	if is_dead or not (area is Torpedo):
		return
	area.queue_free()
	die()

## Cartoon pop + bubbles; the fish stays gone until reset_fish(). Leaves
## behind a sinking carcass (Module B: a "fish" salvage currency) at the kill
## site for the sub to collect.
func die() -> void:
	is_dead = true
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var pop := Torpedo.Puff.new()
	pop.global_position = global_position
	get_parent().add_child(pop)
	get_parent().add_child(SalvageItem.make_carcass(global_position))

## Back home, alive — the world's run reset calls this on the "fish" group.
func reset_fish() -> void:
	is_dead = false
	visible = true
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	global_position = home
	_patrol_target = home
	_bite_cooldown = 0.0
	state = State.PATROL

func _draw() -> void:
	var ppm: float = GameFeel.PIXELS_PER_METER
	var len_px := PlaceholderArt.FISH_LENGTH_M * ppm
	var half := len_px * 0.5
	var c := PlaceholderArt.FISH_COLOR
	# All drawn facing right, mirrored by _facing.
	draw_set_transform(Vector2.ZERO, 0.0,
		Vector2(_facing, 1.0 + 0.06 * sin(_wobble * 6.0)))
	# Chunky body.
	draw_circle(Vector2(0, 0), half * 0.55, c)
	draw_rect(Rect2(-half * 0.55, -half * 0.4, half * 0.9, half * 0.8), c)
	# Tail fin.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half * 0.5, 0), Vector2(-half, -half * 0.45),
		Vector2(-half, half * 0.45)]), c.darkened(0.2))
	# Big eye, biased forward.
	draw_circle(Vector2(half * 0.25, -half * 0.12), half * 0.22, Color.WHITE)
	draw_circle(Vector2(half * 0.32, -half * 0.12), half * 0.11, Color.BLACK)
	# Grumpy little fin on top.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half * 0.1, -half * 0.5), Vector2(half * 0.15, -half * 0.5),
		Vector2(-half * 0.05, -half * 0.8)]), c.darkened(0.2))
