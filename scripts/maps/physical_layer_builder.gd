class_name PhysicalLayerBuilder
extends RefCounted

## M6 Module 3: turns PhysicalLayerParser.Block list into actual scene nodes —
## one TerrainBody (StaticBody2D) per terrain type carrying all of that
## type's merged rectangles as collision shapes, plus a "dock_zone" Area2D
## covering the docking-bay blocks for the Helm/Core dry-dock interaction.

## Builds and returns a Node2D containing one TerrainBody per terrain type
## present, plus (if any DOCK blocks exist) a dock-zone Area2D in the "dock_zone" group.
static func build(config: MapConfig) -> Node2D:
	var root := Node2D.new()
	root.name = "PhysicalLayer"

	var blocks := PhysicalLayerParser.parse(config)
	var bodies: Dictionary = {}  # TerrainType.Type -> TerrainBody
	var dock_rects: Array[Rect2] = []

	for block in blocks:
		if block.terrain == TerrainType.Type.DOCK:
			dock_rects.append(block.rect)
		var body: TerrainBody = bodies.get(block.terrain)
		if body == null:
			body = TerrainBody.new()
			body.name = "Terrain_%d" % block.terrain
			body.terrain_type = block.terrain
			bodies[block.terrain] = body
			root.add_child(body)
		body.add_rect(block.rect)

	if not dock_rects.is_empty():
		root.add_child(_build_dock_zone(dock_rects))

	return root

static func _build_dock_zone(rects: Array[Rect2]) -> Area2D:
	var area := Area2D.new()
	area.name = "DockZone"
	area.add_to_group("dock_zone")
	area.collision_layer = 0
	area.collision_mask = Layers.SUB_HULL
	area.monitoring = true
	area.monitorable = false
	for rect in rects:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.position + rect.size * 0.5
		area.add_child(shape)
	return area
