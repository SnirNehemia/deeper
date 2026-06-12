class_name SubVisual
extends Node2D

## Placeholder art for the submarine, kept on its own node so the sub can apply
## a cosmetic pitch tilt (rotate this) while the physics body and the crew stay
## perfectly upright. Reads the geometry constants from Sub.

## The turret stations, set by Sub. Each tube + barrel is drawn here (rather
## than on the station node) so they tilt with the hull's pitch (playtest #8).
## One for the base bow gun, plus the bought gun-room gun if present.
var turrets: Array[TurretStation] = []

## The salvage claw station, set by Sub. Its belly arm is drawn here so it
## tilts with the hull too.
var claw: ClawStation = null

func _draw() -> void:
	var deck_y := Sub.CEIL_Y - Sub.WALL_T
	var conn_ceil_y := deck_y - 2.0 * Sub.PPM

	var sub := get_parent() as Sub

	# Outer hull silhouette: one continuous shape, drawn as overlapping rounded
	# rects (main deck, lower deck, conning tower, + a bought gun room) — each
	# room block expanded by a uniform margin, so it reads as a single hull
	# rather than separate "blobs" (playtest #1 of Module A).
	var rects: Array = sub.hull_rects() if sub != null else \
		[Sub.HULL_MAIN_RECT, Sub.HULL_LOWER_RECT, Sub.HULL_CONN_RECT]
	for r in rects:
		_draw_round_rect(r, 24.0, PlaceholderArt.HULL_COLOR)

	# Room interiors.
	for i in 3:
		var room_x := -Sub.HALF_W + i * Sub.ROOM_W
		draw_rect(Rect2(room_x, Sub.CEIL_Y, Sub.ROOM_W, Sub.ROOM_H), PlaceholderArt.SUB_INTERIOR)
	# Conning interior.
	draw_rect(Rect2(-Sub.CONN_HALF, conn_ceil_y, Sub.CONN_HALF * 2.0, deck_y - conn_ceil_y),
		PlaceholderArt.SUB_INTERIOR)
	# Lower deck interiors (claw room below middle, storage room below engine).
	draw_rect(Rect2(-Sub.DIV_X, 0.0, Sub.ROOM_W, Sub.LOWER_ROOM_H), PlaceholderArt.SUB_INTERIOR)
	draw_rect(Rect2(-Sub.HALF_W, 0.0, Sub.ROOM_W, Sub.LOWER_ROOM_H), PlaceholderArt.SUB_INTERIOR)

	# Floor deck highlight.
	draw_rect(Rect2(-Sub.HALF_W, 0, Sub.HALF_W * 2.0, 6.0), PlaceholderArt.SUB_FLOOR)

	# Doorway headers (visual).
	var header_h := Sub.ROOM_H - Sub.DOOR_H
	for sx in [-Sub.DIV_X, Sub.DIV_X]:
		draw_rect(Rect2(sx - Sub.WALL_T * 0.5, Sub.CEIL_Y, Sub.WALL_T, header_h),
			PlaceholderArt.SUB_STRUCTURE)
		# Door step on the floor (the little lip crew hop over).
		draw_rect(Rect2(sx - Sub.WALL_T * 0.5, -Sub.DOOR_STEP_H, Sub.WALL_T, Sub.DOOR_STEP_H),
			PlaceholderArt.SUB_STRUCTURE)

	# Conning deck (structure) across the conning floor, including the hatch.
	draw_rect(Rect2(-Sub.CONN_HALF, Sub.CEIL_Y - Sub.WALL_T, Sub.CONN_HALF * 2.0, Sub.WALL_T),
		PlaceholderArt.SUB_STRUCTURE)

	# Ladder rails + rungs (middle room up to the conning area).
	_draw_ladder(0.0, conn_ceil_y, 0.0)
	# Lower-deck ladders: middle room down to the claw room, engine room down
	# to the storage room.
	_draw_ladder(Sub.CLAW_LADDER_X, -20.0, Sub.LOWER_FLOOR_Y)
	_draw_ladder(Sub.STORAGE_LADDER_X, -20.0, Sub.LOWER_FLOOR_Y)

	# Doorway between storage and the claw room (lower deck), with its header
	# and door step.
	var lower_header_h := Sub.LOWER_ROOM_H - Sub.DOOR_H
	draw_rect(Rect2(-Sub.DIV_X - Sub.WALL_T * 0.5, 0.0, Sub.WALL_T, lower_header_h),
		PlaceholderArt.SUB_STRUCTURE)
	draw_rect(Rect2(-Sub.DIV_X - Sub.WALL_T * 0.5, Sub.LOWER_FLOOR_Y - Sub.DOOR_STEP_H,
		Sub.WALL_T, Sub.DOOR_STEP_H), PlaceholderArt.SUB_STRUCTURE)

	# Helm console, sitting on the floor in the bow room (tilts with the hull).
	var hx := Sub.HELM_X
	draw_rect(Rect2(hx - 16.0, -24.0, 32.0, 24.0), PlaceholderArt.SUB_STRUCTURE)
	draw_rect(Rect2(hx - 3.0, -40.0, 6.0, 16.0), PlaceholderArt.SUB_STRUCTURE)
	draw_circle(Vector2(hx, -42.0), 7.0, PlaceholderArt.LADDER_COLOR)

	# Gunner console in the middle flex room.
	var tx := Sub.TURRET_SEAT_X
	draw_rect(Rect2(tx - 14.0, -22.0, 28.0, 22.0), PlaceholderArt.SUB_STRUCTURE)
	draw_circle(Vector2(tx, -30.0), 6.0, PlaceholderArt.HULL_COLOR)

	if sub != null and sub.has_gun_room():
		_draw_gun_room(sub)

	for t in turrets:
		_draw_turret(t)
	_draw_claw()
	_draw_water()

## A torpedo tube + aimed barrel for one gun, drawn in hull-local space so it
## pitches with the sub. Reads the live aim + occupancy from the station.
func _draw_turret(t: TurretStation) -> void:
	if t == null:
		return
	var tube := t.tube_local
	draw_rect(Rect2(tube - Vector2(14.0, 10.0), Vector2(28.0, 20.0)),
		PlaceholderArt.SUB_STRUCTURE)
	var dir := t.barrel_dir()
	draw_line(tube, tube + dir * 34.0, PlaceholderArt.SUB_STRUCTURE, 8.0)
	if t.occupant != null:
		draw_line(tube + dir * 34.0, tube + dir * 150.0, Color(1.0, 1.0, 1.0, 0.35), 2.0)
		if t.is_ready_to_fire():
			draw_circle(tube + dir * 150.0, 4.0, Color(1.0, 1.0, 1.0, 0.6))

## The bought gun room's interior: its room background, floor highlight, the
## doorway into the neighbouring end room, and a gunner console.
func _draw_gun_room(sub: Sub) -> void:
	var r := sub.room_rect(Sub.GUN_ROOM)
	draw_rect(r, PlaceholderArt.SUB_INTERIOR)
	draw_rect(Rect2(r.position.x, 0.0, r.size.x, 6.0), PlaceholderArt.SUB_FLOOR)
	# Doorway header + step at the inner boundary with the end room.
	var inner := sub.gun_room_side() * Sub.HALF_W
	var header_h := Sub.ROOM_H - Sub.DOOR_H
	draw_rect(Rect2(inner - Sub.WALL_T * 0.5, Sub.CEIL_Y, Sub.WALL_T, header_h),
		PlaceholderArt.SUB_STRUCTURE)
	draw_rect(Rect2(inner - Sub.WALL_T * 0.5, -Sub.DOOR_STEP_H, Sub.WALL_T, Sub.DOOR_STEP_H),
		PlaceholderArt.SUB_STRUCTURE)
	# Gunner console.
	var gx := r.get_center().x
	draw_rect(Rect2(gx - 14.0, -22.0, 28.0, 22.0), PlaceholderArt.SUB_STRUCTURE)
	draw_circle(Vector2(gx, -30.0), 6.0, PlaceholderArt.HULL_COLOR)

## The belly salvage claw: a telescoping arm from the keel anchor out to the
## current tip, with a little open claw at the end. Drawn in hull-local space
## so it pitches with the sub.
func _draw_claw() -> void:
	if claw == null:
		return
	var anchor := ClawStation.ANCHOR_LOCAL
	var tip := anchor + claw.aim_dir * claw.length
	# A small port box on the keel where the arm exits.
	draw_rect(Rect2(anchor + Vector2(-10.0, -6.0), Vector2(20.0, 10.0)),
		PlaceholderArt.SUB_STRUCTURE)
	if claw.length <= 0.5:
		return
	draw_line(anchor, tip, PlaceholderArt.SUB_STRUCTURE, 5.0)
	# Two little pincers splaying off the tip's forward direction.
	var fwd := claw.aim_dir
	var side := fwd.orthogonal()
	draw_line(tip, tip + (fwd * 0.4 + side).normalized() * 14.0, PlaceholderArt.LADDER_COLOR, 4.0)
	draw_line(tip, tip + (fwd * 0.4 - side).normalized() * 14.0, PlaceholderArt.LADDER_COLOR, 4.0)

## Flooding water: a flat rect rising from the floor of each room, clipped to
## the room rectangle. Drawn last so it sits over the interior/structure.
func _draw_water() -> void:
	var sub := get_parent() as Sub
	if sub == null:
		return
	for i in sub.active_room_count():
		var level: float = sub.water_levels[i]
		if level <= 0.0:
			continue
		var r := sub.room_rect(i)
		var height := r.size.y * level
		draw_rect(Rect2(r.position.x, r.position.y + r.size.y - height, r.size.x, height),
			PlaceholderArt.INTERIOR_WATER)

## Ladder rails + rungs: a vertical column centered on `center_x`, spanning
## local-y from `top_y` to `bottom_y` (top_y < bottom_y).
func _draw_ladder(center_x: float, top_y: float, bottom_y: float) -> void:
	var rail_x := Sub.HOLE_HALF - 6.0
	var height := bottom_y - top_y
	draw_rect(Rect2(center_x - rail_x - 2.0, top_y, 4.0, height), PlaceholderArt.LADDER_COLOR)
	draw_rect(Rect2(center_x + rail_x - 2.0, top_y, 4.0, height), PlaceholderArt.LADDER_COLOR)
	var rung := top_y + 8.0
	while rung < bottom_y:
		draw_rect(Rect2(center_x - rail_x, rung, rail_x * 2.0, 3.0), PlaceholderArt.LADDER_COLOR)
		rung += 16.0

func _draw_round_rect(rect: Rect2, radius: float, color: Color) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	draw_rect(Rect2(rect.position + Vector2(r, 0), Vector2(rect.size.x - 2.0 * r, rect.size.y)), color)
	draw_rect(Rect2(rect.position + Vector2(0, r), Vector2(rect.size.x, rect.size.y - 2.0 * r)), color)
	draw_circle(rect.position + Vector2(r, r), r, color)
	draw_circle(rect.position + Vector2(rect.size.x - r, r), r, color)
	draw_circle(rect.position + Vector2(r, rect.size.y - r), r, color)
	draw_circle(rect.position + Vector2(rect.size.x - r, rect.size.y - r), r, color)
