class_name SalvageItem
extends Area2D

## A piece of salvage floating in the world: either a scrap crate (placed on
## the map) or a sunken fish carcass (spawned where a fish dies). The sub's
## hull collector picks these up on contact (Module B: no claw arm yet) and
## adds them to its on-board storage.
##
## Placeholder visuals only: scrap = a bobbing crate, carcass = a faded fish
## silhouette that sinks toward the seafloor before settling.

enum Kind { SCRAP, FISH }

const RADIUS_PX := 14.0

@export var kind: Kind = Kind.SCRAP

var _wobble: float = randf() * TAU
# Carcasses sink at this speed (px/s), decaying to a stop so they "settle".
var _sink_speed: float = 0.0
# True while trapped in the claw's cage: the claw drives our position, so we
# stop sinking/drifting on our own and ride above the hull (high z) to stay
# visible inside the cage.
var held: bool = false

static func make_scrap(world_pos: Vector2) -> SalvageItem:
	var item := SalvageItem.new()
	item.kind = Kind.SCRAP
	item.position = world_pos
	return item

## A fish carcass: spawns at the kill site and slowly sinks before settling.
static func make_carcass(world_pos: Vector2) -> SalvageItem:
	var item := SalvageItem.new()
	item.kind = Kind.FISH
	item.position = world_pos
	item._sink_speed = 1.0 * GameFeel.PIXELS_PER_METER
	item.add_to_group("salvage_carcass")
	return item

func _ready() -> void:
	# Joined so the claw station can find nearby salvage to grip.
	add_to_group("salvage")
	collision_layer = Layers.SALVAGE
	collision_mask = 0
	monitorable = true
	monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS_PX
	shape.shape = circle
	add_child(shape)

func _physics_process(delta: float) -> void:
	_wobble += delta
	if held:
		# The claw owns our position while we're caged; just keep animating.
		queue_redraw()
		return
	if _sink_speed > 0.0:
		position.y += _sink_speed * delta
		# Decay the sink speed so the carcass eases to a stop ("settling").
		_sink_speed = maxf(0.0, _sink_speed - GameFeel.PIXELS_PER_METER * 0.5 * delta)
	queue_redraw()

## Caught/released by the claw cage. Held items stop sinking and draw above the
## hull so they read as trapped inside the cage.
func set_held(h: bool) -> void:
	held = h
	z_index = 50 if h else 0
	if h:
		_sink_speed = 0.0

func _draw() -> void:
	var bob := sin(_wobble * 2.0) * 3.0
	match kind:
		Kind.SCRAP:
			var c := PlaceholderArt.SCRAP_COLOR
			var r := Rect2(Vector2(-RADIUS_PX, -RADIUS_PX + bob), Vector2(RADIUS_PX, RADIUS_PX) * 2.0)
			draw_rect(r, c)
			draw_rect(r, c.darkened(0.35), false, 2.0)
			draw_line(r.position, r.position + r.size, c.darkened(0.35), 2.0)
			draw_line(r.position + Vector2(r.size.x, 0), r.position + Vector2(0, r.size.y), c.darkened(0.35), 2.0)
		Kind.FISH:
			var c := PlaceholderArt.CARCASS_COLOR
			draw_circle(Vector2(0, bob), RADIUS_PX, c)
			draw_circle(Vector2(0, bob), RADIUS_PX * 0.4, c.darkened(0.3))
