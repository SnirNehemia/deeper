class_name Sub
extends CharacterBody2D

## The submarine: one physics body that will move through the ocean, with a
## cutaway interior the crew run around inside.
##
## Built entirely in code. Local space convention: the interior FLOOR top is at
## y = 0 and "up" is negative y. Three 5m x 3m rooms sit in a row (Engine /
## stern on the left, flex Middle, Helm / bow on the right) with open doorways
## between them, plus a ladder from the middle room up to a small conning area.
##
## The crew are parented to this node, so when the sub moves they ride along
## automatically. The sub's own outer hull collides with TERRAIN; the interior
## pieces are separate static bodies on the INTERIOR layer that only the crew
## touch.

const PPM := 48.0

const ROOM_W := 5.0 * PPM     # 240
const ROOM_H := 3.0 * PPM     # 144
const HALF_W := 1.5 * ROOM_W  # 360 (three rooms, centered: x in [-360, 360])
const WALL_T := 16.0          # collision thickness for floors/walls
const DOOR_H := 2.0 * PPM     # 96 — doorway opening height above the floor
const HOLE_HALF := 0.5 * PPM  # 24 — half-width of the ladder hole in the ceiling
const CEIL_Y := -ROOM_H       # -144 — ceiling bottom / room headroom
const CONN_HALF := 1.5 * PPM  # 72 — half-width of the conning area
const CONN_TOP := -ROOM_H - 2.0 * PPM  # -240-ish — conning ceiling region

# Divider x positions between the three rooms.
const DIV_X := ROOM_W * 0.5   # 120

func _ready() -> void:
	collision_layer = Layers.SUB_HULL
	collision_mask = Layers.TERRAIN
	_build_hull_collision()
	_build_interior()
	_build_ladder()

## Rough outer-shell collider (vs terrain). Shape only matters once the ocean map
## exists; bumping terrain is harmless this milestone.
func _build_hull_collision() -> void:
	var hull := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(HALF_W * 2.0 + 80.0, ROOM_H + 6.0 * PPM)
	hull.shape = shape
	hull.position = Vector2(0, -ROOM_H * 0.5)
	add_child(hull)

func _build_interior() -> void:
	# Floor across all three rooms (top surface at y = 0).
	_add_static(Vector2(0, WALL_T * 0.5), Vector2(HALF_W * 2.0 + WALL_T, WALL_T))

	# End walls (stern / bow), floor up past the ceiling.
	_add_static(Vector2(-HALF_W - WALL_T * 0.5, -ROOM_H * 0.5 - 8.0), Vector2(WALL_T, ROOM_H + WALL_T + 32.0))
	_add_static(Vector2(HALF_W + WALL_T * 0.5, -ROOM_H * 0.5 - 8.0), Vector2(WALL_T, ROOM_H + WALL_T + 32.0))

	# Ceiling: two segments leaving a ladder hole at the center. The TOP of these
	# segments doubles as the conning-area floor.
	var ceil_y := CEIL_Y - WALL_T * 0.5
	var left_w := HALF_W - HOLE_HALF
	_add_static(Vector2(-(HOLE_HALF + left_w * 0.5), ceil_y), Vector2(left_w, WALL_T))
	_add_static(Vector2(HOLE_HALF + left_w * 0.5, ceil_y), Vector2(left_w, WALL_T))

	# Solid deck over the ladder hole (HATCH layer). Crew stand on it normally, so
	# they don't auto-fall through the hatch; they pass it only while climbing the
	# ladder (which drops the HATCH layer), i.e. only when pressing down/up.
	_add_hatch(Vector2(0, ceil_y), Vector2(HOLE_HALF * 2.0, WALL_T))

	# Doorway headers: short beams hanging from the ceiling between rooms, leaving
	# a DOOR_H opening above the floor.
	var header_h := ROOM_H - DOOR_H
	var header_y := CEIL_Y + header_h * 0.5
	_add_static(Vector2(-DIV_X, header_y), Vector2(WALL_T, header_h))
	_add_static(Vector2(DIV_X, header_y), Vector2(WALL_T, header_h))

	# Conning area walls and ceiling, sitting on the middle ceiling segments.
	var deck_y := CEIL_Y - WALL_T              # top of the ceiling segments
	var conn_ceil_y := deck_y - 2.0 * PPM      # 2 m of headroom in the conning area
	_add_static(Vector2(-CONN_HALF - WALL_T * 0.5, (deck_y + conn_ceil_y) * 0.5),
		Vector2(WALL_T, deck_y - conn_ceil_y))
	_add_static(Vector2(CONN_HALF + WALL_T * 0.5, (deck_y + conn_ceil_y) * 0.5),
		Vector2(WALL_T, deck_y - conn_ceil_y))
	_add_static(Vector2(0, conn_ceil_y - WALL_T * 0.5),
		Vector2(CONN_HALF * 2.0 + WALL_T * 2.0, WALL_T))

func _build_ladder() -> void:
	var deck_y := CEIL_Y - WALL_T
	var conn_ceil_y := deck_y - 2.0 * PPM
	var ladder := Area2D.new()
	ladder.collision_layer = Layers.LADDER
	ladder.collision_mask = 0
	ladder.monitorable = true
	ladder.monitoring = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# Climb column from the middle-room floor up to just under the conning ceiling.
	var top := conn_ceil_y + WALL_T
	rect.size = Vector2(HOLE_HALF * 2.0, -top)
	shape.shape = rect
	shape.position = Vector2(0, top * 0.5)
	ladder.add_child(shape)
	add_child(ladder)

## Add an interior collision box (center, size) on the INTERIOR layer.
func _add_static(center: Vector2, size: Vector2) -> void:
	_add_box(center, size, Layers.INTERIOR)

## Add the hatch deck box (center, size) on the HATCH layer.
func _add_hatch(center: Vector2, size: Vector2) -> void:
	_add_box(center, size, Layers.HATCH)

func _add_box(center: Vector2, size: Vector2, layer: int) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = center
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)

# --- Placeholder visuals (drawn in local space; collision is separate) ---

func _draw() -> void:
	var deck_y := CEIL_Y - WALL_T
	var conn_ceil_y := deck_y - 2.0 * PPM

	# Outer hull silhouette (rounded), behind everything.
	_draw_round_rect(Rect2(-HALF_W - 40.0, -ROOM_H - 24.0, HALF_W * 2.0 + 80.0, ROOM_H + 24.0 + 1.5 * PPM),
		48.0, PlaceholderArt.HULL_COLOR)
	# Conning tower bump on top.
	_draw_round_rect(Rect2(-CONN_HALF - 18.0, conn_ceil_y - 18.0, CONN_HALF * 2.0 + 36.0, deck_y - conn_ceil_y + 24.0),
		18.0, PlaceholderArt.HULL_COLOR)

	# Room interiors.
	for i in 3:
		var room_x := -HALF_W + i * ROOM_W
		draw_rect(Rect2(room_x, CEIL_Y, ROOM_W, ROOM_H), PlaceholderArt.SUB_INTERIOR)
	# Conning interior.
	draw_rect(Rect2(-CONN_HALF, conn_ceil_y, CONN_HALF * 2.0, deck_y - conn_ceil_y),
		PlaceholderArt.SUB_INTERIOR)

	# Floor deck highlight.
	draw_rect(Rect2(-HALF_W, 0, HALF_W * 2.0, 6.0), PlaceholderArt.SUB_FLOOR)

	# Doorway headers (visual) + divider posts (just the header part).
	var header_h := ROOM_H - DOOR_H
	for sx in [-DIV_X, DIV_X]:
		draw_rect(Rect2(sx - WALL_T * 0.5, CEIL_Y, WALL_T, header_h), PlaceholderArt.SUB_STRUCTURE)

	# Conning deck (structure) across the conning floor, including the hatch.
	draw_rect(Rect2(-CONN_HALF, CEIL_Y - WALL_T, CONN_HALF * 2.0, WALL_T),
		PlaceholderArt.SUB_STRUCTURE)

	# Ladder rails + rungs.
	var rail_x := HOLE_HALF - 6.0
	draw_rect(Rect2(-rail_x - 2.0, conn_ceil_y, 4.0, -conn_ceil_y), PlaceholderArt.LADDER_COLOR)
	draw_rect(Rect2(rail_x - 2.0, conn_ceil_y, 4.0, -conn_ceil_y), PlaceholderArt.LADDER_COLOR)
	var rung := conn_ceil_y + 8.0
	while rung < 0.0:
		draw_rect(Rect2(-rail_x, rung, rail_x * 2.0, 3.0), PlaceholderArt.LADDER_COLOR)
		rung += 16.0

func _draw_round_rect(rect: Rect2, radius: float, color: Color) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	draw_rect(Rect2(rect.position + Vector2(r, 0), Vector2(rect.size.x - 2.0 * r, rect.size.y)), color)
	draw_rect(Rect2(rect.position + Vector2(0, r), Vector2(rect.size.x, rect.size.y - 2.0 * r)), color)
	draw_circle(rect.position + Vector2(r, r), r, color)
	draw_circle(rect.position + Vector2(rect.size.x - r, r), r, color)
	draw_circle(rect.position + Vector2(r, rect.size.y - r), r, color)
	draw_circle(rect.position + Vector2(rect.size.x - r, rect.size.y - r), r, color)
