class_name Station
extends Area2D

## A crew station: a zone a crew member can stand in and press interact to take
## control (sit down), press interact again to leave. One occupant at a time.
##
## This base handles occupancy and the seat position; subclasses (HelmStation,
## later turret/periscope) override handle_input() to do something with the
## seated player's controls. The crew node drives the lifecycle: it detects the
## zone, calls enter()/exit(), and forwards input via handle_input().

## How big the "stand here to use it" zone is.
@export var zone_size: Vector2 = Vector2(70, 96)

## The crew currently seated here, or null.
var occupant: Crew = null

## The sub this station belongs to and which water "room" it sits in (see
## Sub.room_rect/water_levels). Set by the sub when it builds the station.
## Used to eject the occupant and refuse entry once that room floods past
## the seat-flood threshold.
var sub: Sub = null
var room_index: int = -1

func _ready() -> void:
	collision_layer = Layers.STATION
	collision_mask = 0
	monitorable = true   # crew sensors detect this zone
	monitoring = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = zone_size
	shape.shape = rect
	add_child(shape)

func can_enter() -> bool:
	return occupant == null and not is_flooded()

## True once this station's room has flooded past the seat-flood threshold.
func is_flooded() -> bool:
	if sub == null or room_index < 0:
		return false
	return sub.water_levels[room_index] > GameFeel.water.seat_flood_threshold

func enter(crew: Crew) -> void:
	occupant = crew
	queue_redraw()

func exit(crew: Crew) -> void:
	if occupant == crew:
		occupant = null
	queue_redraw()

## Where the seated crew's origin locks. Defaults to this node's position; the
## crew rides it as the sub moves.
func seat_global_position() -> Vector2:
	return global_position

## Consume the seated player's input for this frame. Override in subclasses.
func handle_input(_input: PlayerInput) -> void:
	pass

## Face-relative aim control (2026-06-2x): for an element mounted on a hull
## face pointing `facing_dir` (unit vector: right/left/top/bottom), maps the
## player's move input to a signed aim-sweep value so that pushing
## camera-right/down always sweeps the aim toward the screen's right/down,
## whichever wall the element sits on. Side faces (left/right) aim with W/S
## (move.y); top/bottom faces aim with A/D (move.x).
static func face_aim_input(facing_dir: Vector2, input: PlayerInput) -> float:
	var sign := signf(facing_dir.x - facing_dir.y)
	if facing_dir.y != 0.0:
		return input.move.x * sign
	return input.move.y * sign

## The move-input axis orthogonal to face_aim_input's, for elements (like the
## floodlight) that use the other axis for a second control (e.g. zoom).
static func face_cross_input(facing_dir: Vector2, input: PlayerInput) -> float:
	if facing_dir.y != 0.0:
		return input.move.y
	return input.move.x

## Face-relative zoom control (2026-06-2x): like face_cross_input, but signed
## so that pushing toward open water (away from the hull, in `facing_dir`'s
## own direction) is always positive — used by the floodlight to grow its
## reach when pushed outward and shrink it when pushed back toward the hull.
static func face_zoom_input(facing_dir: Vector2, input: PlayerInput) -> float:
	var sign := facing_dir.x + facing_dir.y
	return face_cross_input(facing_dir, input) * sign
