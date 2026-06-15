class_name TerrainBody
extends StaticBody2D

## M6 Module 3: a StaticBody2D holding the merged collision rectangles for one
## TerrainType, built by PhysicalLayerBuilder. Sub._check_terrain_impacts()
## reads `terrain_type` off the collided body to apply per-material impact
## rules (sand/sharp rock/dock).

var terrain_type: TerrainType.Type = TerrainType.Type.NORMAL_ROCK

func _ready() -> void:
	collision_layer = Layers.TERRAIN
	collision_mask = 0

## Adds one rectangle (world-space, top-left origin) as a collision shape.
func add_rect(rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.position + rect.size * 0.5
	add_child(shape)
