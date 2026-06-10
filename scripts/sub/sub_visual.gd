class_name SubVisual
extends Node2D

## Placeholder art for the submarine, kept on its own node so the sub can apply
## a cosmetic pitch tilt (rotate this) while the physics body and the crew stay
## perfectly upright. Reads the geometry constants from Sub.

func _draw() -> void:
	var deck_y := Sub.CEIL_Y - Sub.WALL_T
	var conn_ceil_y := deck_y - 2.0 * Sub.PPM

	# Outer hull silhouette (rounded), behind everything.
	_draw_round_rect(Rect2(-Sub.HALF_W - 40.0, -Sub.ROOM_H - 24.0,
		Sub.HALF_W * 2.0 + 80.0, Sub.ROOM_H + 24.0 + 1.5 * Sub.PPM),
		48.0, PlaceholderArt.HULL_COLOR)
	# Conning tower bump on top.
	_draw_round_rect(Rect2(-Sub.CONN_HALF - 18.0, conn_ceil_y - 18.0,
		Sub.CONN_HALF * 2.0 + 36.0, deck_y - conn_ceil_y + 24.0),
		18.0, PlaceholderArt.HULL_COLOR)

	# Room interiors.
	for i in 3:
		var room_x := -Sub.HALF_W + i * Sub.ROOM_W
		draw_rect(Rect2(room_x, Sub.CEIL_Y, Sub.ROOM_W, Sub.ROOM_H), PlaceholderArt.SUB_INTERIOR)
	# Conning interior.
	draw_rect(Rect2(-Sub.CONN_HALF, conn_ceil_y, Sub.CONN_HALF * 2.0, deck_y - conn_ceil_y),
		PlaceholderArt.SUB_INTERIOR)

	# Floor deck highlight.
	draw_rect(Rect2(-Sub.HALF_W, 0, Sub.HALF_W * 2.0, 6.0), PlaceholderArt.SUB_FLOOR)

	# Doorway headers (visual).
	var header_h := Sub.ROOM_H - Sub.DOOR_H
	for sx in [-Sub.DIV_X, Sub.DIV_X]:
		draw_rect(Rect2(sx - Sub.WALL_T * 0.5, Sub.CEIL_Y, Sub.WALL_T, header_h),
			PlaceholderArt.SUB_STRUCTURE)

	# Conning deck (structure) across the conning floor, including the hatch.
	draw_rect(Rect2(-Sub.CONN_HALF, Sub.CEIL_Y - Sub.WALL_T, Sub.CONN_HALF * 2.0, Sub.WALL_T),
		PlaceholderArt.SUB_STRUCTURE)

	# Ladder rails + rungs.
	var rail_x := Sub.HOLE_HALF - 6.0
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
