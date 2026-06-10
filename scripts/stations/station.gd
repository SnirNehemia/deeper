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
	return occupant == null

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
