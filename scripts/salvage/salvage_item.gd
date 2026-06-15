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
## Placeholder visuals only: scrap = a bobbing crate, carcass = a faded fish
## blob that sinks toward the seafloor before settling.

enum Kind { SCRAP, FISH, MED_FISH }
enum State { WATER, CAGED, LOOSE, CARRIED }

const RADIUS_PX := 14.0

@export var kind: Kind = Kind.SCRAP

var state: State = State.WATER
## The crew node carrying this item (only while CARRIED).
var carried_by: Node2D = null

var _wobble: float = randf() * TAU
# Carcasses sink at this speed (px/s), decaying to a stop so they "settle".
var _sink_speed: float = 0.0

static func make_scrap(world_pos: Vector2) -> SalvageItem:
	var item := SalvageItem.new()
	item.kind = Kind.SCRAP
	item.position = world_pos
	return item

## A fish carcass: spawns at the kill site and slowly sinks before settling.
## `kind` is FISH (small, purple) or MED_FISH (medium, green — from a
## basic_chaser).
static func make_carcass(world_pos: Vector2, kind: Kind = Kind.FISH) -> SalvageItem:
	var item := SalvageItem.new()
	item.kind = kind
	item.position = world_pos
	item._sink_speed = 1.0 * GameFeel.PIXELS_PER_METER
	item.add_to_group("salvage_carcass")
	return item

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
			if _sink_speed > 0.0:
				position.y += _sink_speed * delta
				_sink_speed = maxf(0.0,
					_sink_speed - GameFeel.PIXELS_PER_METER * 0.5 * delta)
	queue_redraw()

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
		Kind.FISH, Kind.MED_FISH:
			var c := PlaceholderArt.CARCASS_MED_COLOR if kind == Kind.MED_FISH else PlaceholderArt.CARCASS_COLOR
			draw_circle(Vector2(0, bob), RADIUS_PX, c)
			draw_circle(Vector2(0, bob), RADIUS_PX * 0.4, c.darkened(0.3))
