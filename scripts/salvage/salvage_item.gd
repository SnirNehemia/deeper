class_name SalvageItem
extends Area2D

## A piece of salvage. It moves through a little lifecycle (Module C rework):
##
##   WATER   — drifting in the ocean (scrap on the map / a sunken carcass).
##             The claw can snap it into its cage.
##   CAGED   — trapped in the claw's cage; the claw drives its position.
##   LOOSE   — dropped through the keel hatch onto a sub floor; a crew member
##             can pick it up and carry it.
##   CARRIED — being carried by a crew member to the storage cage.
##
## Placeholder visuals only: scrap = a bobbing crate, currency = a colored
## gem that sinks toward the seafloor before settling.
##
## MILESTONE_8.md Module 4: the old carcass tiers (FISH/MED_FISH) are retired
## in favor of a generic CURRENCY kind carrying a color name + denomination
## value (an enemy's currency_color, or "gold" for the elite premium —
## see GameFeel.currency / Fish.die()).

enum Kind { SCRAP, CURRENCY }
enum State { WATER, CAGED, LOOSE, CARRIED }

const RADIUS_PX := 14.0

@export var kind: Kind = Kind.SCRAP
## Only meaningful when kind == CURRENCY.
@export var currency_color: String = ""
@export var currency_value: int = 0

var state: State = State.WATER
## The crew node carrying this item (only while CARRIED).
var carried_by: Node2D = null

var _wobble: float = randf() * TAU
# Currency pickups sink at this speed (px/s), decaying to a stop so they "settle".
var _sink_speed: float = 0.0

## 2026-06-24: sky zones from the map and the global water surface y — same
## fields Fish carries, set by whoever spawns this drop (e.g. Fish._spawn_drop
## copies its own). A drop that's airborne (e.g. a kill that happened above
## the surface) falls under plain gravity instead of using the underwater
## sink-and-settle behavior below.
var sky_zones: Array = []
var water_surface_y: float = 0.0
var _fall_velocity: float = 0.0

static func make_scrap(world_pos: Vector2) -> SalvageItem:
	var item := SalvageItem.new()
	item.kind = Kind.SCRAP
	item.position = world_pos
	return item

## A colored-currency pickup: spawns at the kill site and slowly sinks before
## settling. `color` is a species' currency_color or "gold" (elite premium);
## `value` is its denomination (see GameFeel.currency.split).
static func make_currency(world_pos: Vector2, color: String, value: int) -> SalvageItem:
	var item := SalvageItem.new()
	item.kind = Kind.CURRENCY
	item.currency_color = color
	item.currency_value = value
	item.position = world_pos
	item._sink_speed = 1.0 * GameFeel.PIXELS_PER_METER
	item.add_to_group("salvage_carcass")
	return item

var _terrain_cast: ShapeCast2D

func _ready() -> void:
	# Joined so the claw and crew can find salvage by group.
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
	# A falling drop (see _in_sky() below) must not clip through rock — same
	# guard Fish uses for its own gravity fall.
	_terrain_cast = ShapeCast2D.new()
	var cast_shape := CircleShape2D.new()
	cast_shape.radius = RADIUS_PX * 0.85
	_terrain_cast.shape = cast_shape
	_terrain_cast.collision_mask = Layers.TERRAIN
	_terrain_cast.enabled = true
	add_child(_terrain_cast)

func _physics_process(delta: float) -> void:
	_wobble += delta
	match state:
		State.CAGED:
			pass  # the claw drives our position
		State.CARRIED:
			# Ride just above the carrying crew's head (same local space — both
			# are children of the sub).
			if is_instance_valid(carried_by):
				position = carried_by.position + Vector2(0,
					-PlaceholderArt.CREW_HEIGHT_M * GameFeel.PIXELS_PER_METER * 0.7)
		State.LOOSE:
			pass  # sits where it was dropped
		State.WATER:
			if _in_sky():
				var fall_step := Vector2(0, _fall_velocity * delta)
				_terrain_cast.target_position = fall_step
				_terrain_cast.force_shapecast_update()
				if _terrain_cast.is_colliding():
					_fall_velocity = 0.0
				else:
					_fall_velocity += GameFeel.sub.surface_gravity * GameFeel.PIXELS_PER_METER * delta
					global_position += fall_step
			else:
				_fall_velocity = 0.0
				if _sink_speed > 0.0:
					position.y += _sink_speed * delta
					_sink_speed = maxf(0.0,
						_sink_speed - GameFeel.PIXELS_PER_METER * 0.5 * delta)
	queue_redraw()

## True if this drop is currently in open air (above the main surface, or
## inside an air pocket's sky zone) — mirrors Fish._in_sky().
func _in_sky() -> bool:
	if water_surface_y > 0.0 and global_position.y < water_surface_y:
		return true
	for zone in sky_zones:
		if not zone.get("is_pocket", false):
			continue
		var sz: float = zone["surface_y"]
		if global_position.y < sz:
			var rect: Rect2 = zone["rect"]
			# Bound by the pocket's actual footprint (x AND y), not just x —
			# mirrors Fish._in_sky()'s same fix.
			if rect.has_point(global_position):
				return true
	return false

func is_water() -> bool:
	return state == State.WATER

func is_loose() -> bool:
	return state == State.LOOSE

## Snapped into the claw's cage. Stops sinking and draws above the hull so it
## reads as trapped inside the cage.
func set_caged() -> void:
	state = State.CAGED
	carried_by = null
	_sink_speed = 0.0
	z_index = 50

## Dropped through the keel hatch into the sub: reparent under the sub (so it
## rides along), land at `local_pos`, and become a pickup-able loose item.
func drop_into_sub(sub: Node2D, local_pos: Vector2) -> void:
	if not is_instance_valid(sub):
		queue_free()
		return
	if get_parent() != sub:
		reparent(sub)
	position = local_pos
	state = State.LOOSE
	carried_by = null
	z_index = 6
	add_to_group("carryable")

## Picked up by a crew member; rides along with them.
func set_carried(crew: Node2D) -> void:
	state = State.CARRIED
	carried_by = crew
	z_index = 50

## Put back down on a sub floor at `local_pos` (the crew dropped it).
func set_loose_at(local_pos: Vector2) -> void:
	state = State.LOOSE
	carried_by = null
	position = local_pos
	z_index = 6

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
		Kind.CURRENCY:
			var c := PlaceholderArt.currency_color(currency_color)
			var sides := shape_sides_for(currency_value)
			_draw_regular_polygon(Vector2(0, bob), RADIUS_PX, sides, c)
			_draw_regular_polygon(Vector2(0, bob), RADIUS_PX * 0.4, sides, c.darkened(0.3))

## Denomination value -> polygon side count: each rung up GameFeel.currency's
## denomination ladder adds one edge (1=triangle, 5=square, 10=pentagon,
## 50=hexagon) so a pickup's worth reads at a glance, not just its color.
## Reads the ladder from GameFeel rather than hardcoding it, so re-tuning the
## denominations there keeps the shapes in step automatically.
static func shape_sides_for(value: int) -> int:
	var tiers := GameFeel.currency.denominations.duplicate()
	tiers.sort()
	var idx := tiers.find(value)
	if idx == -1:
		return 8  # an unrecognized value (e.g. a future custom drop): default to circle-ish
	return 3 + idx

func _draw_regular_polygon(center: Vector2, radius: float, sides: int, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := TAU * i / sides - PI / 2.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)
