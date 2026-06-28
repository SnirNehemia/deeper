class_name SubVisual
extends Node2D

## Placeholder art for the submarine, on its own node so the sub can apply a
## cosmetic pitch tilt (rotate this) while the physics body and crew stay
## upright. Draws entirely from the parent Sub's compiled geometry (rooms,
## doors, ladders) — no hand-authored constants.

## The turret stations, set by Sub. Each tube + barrel is drawn here so they
## tilt with the hull's pitch (playtest #8).
var turrets: Array[TurretStation] = []

## The salvage claw station, set by Sub. Its belly arm is drawn here so it
## tilts with the hull too.
var claw: ClawStation = null

## The floodlight stations, set by Sub. Each beam is drawn here so it tilts
## with the hull's pitch, like the turrets.
var floodlights: Array[FloodlightStation] = []

## The telescope arm stations (M7-2), set by Sub. Arms are drawn here so they
## tilt with the hull's pitch, like the claw.
var telescopes: Array[TelescopeStation] = []

func _draw() -> void:
	var sub := get_parent() as Sub
	if sub == null or sub.geometry == null:
		return

	# Floodlight beams are drawn first, underneath everything else — the hull
	# silhouette and room interiors drawn next cover any part of a beam that
	# would otherwise show through the hull from inside the sub (2026-06-19).
	for f in floodlights:
		_draw_floodlight_beam(f)

	# MILESTONE_11.md Module 1: the sub's own ambient readability glow, also
	# drawn before the opaque hull so it reads as a soft halo bleeding into
	# the water around the hull, not just the hull's own silhouette.
	_draw_ambient_bubble(sub)

	# Outer hull silhouette: one continuous shape, drawn as overlapping rounded
	# rects (one per occupied cell), so it reads as a single hull.
	for r in sub.hull_rects():
		_draw_round_rect(r, 24.0, PlaceholderArt.HULL_COLOR)

	# Room interiors + a floor highlight per room.
	for room in sub.geometry.rooms:
		draw_rect(room.rect, PlaceholderArt.SUB_INTERIOR)
		draw_rect(Rect2(room.rect.position.x, room.rect.position.y + room.rect.size.y - 6.0,
			room.rect.size.x, 6.0), PlaceholderArt.SUB_FLOOR)

	# Doorway headers + steps (structure) on each shared vertical wall.
	for door in sub.geometry.doors:
		var room := sub.geometry.rooms[door.a_index]
		var header_h := room.rect.size.y - Sub.DOOR_H
		draw_rect(Rect2(door.wall_x - Sub.WALL_T * 0.5, room.rect.position.y, Sub.WALL_T, header_h),
			PlaceholderArt.SUB_STRUCTURE)
		draw_rect(Rect2(door.wall_x - Sub.WALL_T * 0.5, door.floor_y - Sub.DOOR_STEP_H,
			Sub.WALL_T, Sub.DOOR_STEP_H), PlaceholderArt.SUB_STRUCTURE)

	# Ladders (rails + rungs) in each shaft.
	for ladder in sub.geometry.ladders:
		_draw_ladder(ladder.x, ladder.top_y, ladder.bottom_y)

	# Consoles at the seats — the helm, hull station in the tower, plus one
	# per turret station (the legacy bow gun and any placed Turret Rooms, M4-10).
	_draw_console(sub.helm_seat_local())
	if sub.hull_station != null:
		_draw_console(sub.hull_station_seat_local())

	for t in turrets:
		_draw_console(t.position)
		_draw_turret(t)
	_draw_claw_console(sub)
	_draw_storage_pen(sub)
	_draw_claw()
	for t in telescopes:
		_draw_console(t.position)
		_draw_telescope(t)
	for f in floodlights:
		_draw_console(f.position)
	_draw_water(sub)

## A small console box + dial standing on the floor at a seat (sub-local).
func _draw_console(seat: Vector2) -> void:
	var floor_y := seat.y + PlaceholderArt.CREW_HEIGHT_M * Sub.PPM * 0.5
	draw_rect(Rect2(seat.x - 14.0, floor_y - 22.0, 28.0, 22.0), PlaceholderArt.SUB_STRUCTURE)
	draw_circle(Vector2(seat.x, floor_y - 30.0), 6.0, PlaceholderArt.LADDER_COLOR)

## A torpedo tube + aimed barrel for one gun, drawn in hull-local space so it
## pitches with the sub. Reads live aim + occupancy from the station.
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

## The belly salvage claw: a two-joint arm ending in a cage. Drawn in hull-local
## space so it pitches with the sub.
func _draw_claw() -> void:
	if claw == null:
		return
	var anchor := claw.anchor_local
	draw_rect(Rect2(anchor + Vector2(-12.0, -7.0), Vector2(24.0, 12.0)),
		PlaceholderArt.SUB_STRUCTURE)

	var joint := claw.joint_local()
	var tip := claw.tip_local()
	draw_line(anchor, joint, PlaceholderArt.SUB_STRUCTURE, 7.0)
	draw_line(joint, tip, PlaceholderArt.SUB_STRUCTURE, 6.0)
	draw_circle(anchor, 6.0, PlaceholderArt.HULL_COLOR)
	draw_circle(joint, 6.0, PlaceholderArt.HULL_COLOR)
	_draw_cage(joint, tip)
	if claw.has_grabbed_fish():
		_draw_reel_rope(anchor, tip, claw.reel_minigame())

## A basket cage at the arm tip, opening outward, with a hinged hatch that
## closes (clamp_amount -> 1) when holding salvage.
func _draw_cage(joint: Vector2, tip: Vector2) -> void:
	var fwd := (tip - joint).normalized() if tip.distance_to(joint) > 0.1 else claw.down_dir
	var side := fwd.orthogonal()
	var c := PlaceholderArt.LADDER_COLOR
	var hw := 22.0
	var back := tip - fwd * 8.0
	var mouth := tip + fwd * 22.0
	var bl := back + side * hw
	var br := back - side * hw
	var ml := mouth + side * hw
	var mr := mouth - side * hw
	draw_line(bl, br, c, 3.0)
	draw_line(bl, ml, c, 3.0)
	draw_line(br, mr, c, 3.0)
	var rib := tip + fwd * 8.0
	draw_line(rib + side * hw, rib - side * hw, c, 2.0)
	var openness := 1.0 - claw.clamp_amount()
	var center := mouth
	var l_open := ml + fwd * 10.0 + side * 6.0
	var r_open := mr + fwd * 10.0 - side * 6.0
	draw_line(ml, center.lerp(l_open, openness), c, 3.0)
	draw_line(mr, center.lerp(r_open, openness), c, 3.0)

## The claw operator's console + the keel drop hatch the claw lowers through.
func _draw_claw_console(sub: Sub) -> void:
	if claw == null:
		return
	var cx := claw.position.x
	var floor_y := sub.claw_drop_floor_y()
	draw_rect(Rect2(cx - 14.0, floor_y - 22.0, 28.0, 22.0), PlaceholderArt.SUB_STRUCTURE)
	draw_circle(Vector2(cx, floor_y - 30.0), 6.0, PlaceholderArt.LADDER_COLOR)

	var hx := claw.hatch_x  # dropping hatch sits in section s2
	var hw := 22.0
	draw_rect(Rect2(hx - hw, floor_y - 3.0, hw * 2.0, 6.0), PlaceholderArt.SUB_INTERIOR)
	draw_line(Vector2(hx - hw, floor_y), Vector2(hx + hw, floor_y),
		PlaceholderArt.LADDER_COLOR, 2.0)
	draw_line(Vector2(hx - hw, floor_y), Vector2(hx - hw + 14.0, floor_y - 12.0),
		PlaceholderArt.SUB_STRUCTURE, 3.0)

## The storage pen in the storage room: a cage occupying section s3, that fills
## with delivered salvage. Sized to one section wide so it visibly sits in its
## section (ROOM_SYSTEM.md §6).
func _draw_storage_pen(sub: Sub) -> void:
	var center := sub.storage_pen_center()
	var sec_w := SubGrid.CELL_W_PX / 5.0  # one section
	var pen := Rect2(center.x - sec_w * 0.5, center.y - 27.0, sec_w, 54.0)
	var floor_y := pen.position.y + pen.size.y
	var bar := PlaceholderArt.LADDER_COLOR
	draw_rect(Rect2(pen.position, Vector2(pen.size.x, 4.0)), bar)
	var x := pen.position.x
	while x <= pen.position.x + pen.size.x + 0.1:
		draw_line(Vector2(x, pen.position.y), Vector2(x, floor_y), bar, 2.0)
		x += sec_w * 0.25  # four bars across the section
	# Stacked scrap crates, packed bottom-up. Color currency is capacity-free
	# (MILESTONE_8.md Module 4 — a running value total per color, not discrete
	# physical objects) so it has nothing to stack here; see SalvageHud for
	# its readout instead.
	var total: int = sub.storage_scrap
	var per_row := 3
	var slot := pen.size.x / per_row
	for i in total:
		var col := i % per_row
		var row := i / per_row
		var p := Vector2(pen.position.x + slot * (col + 0.5), floor_y - 10.0 - row * 14.0)
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), PlaceholderArt.SCRAP_COLOR)

## A floodlight's beam (M4-17 rework): a cone with its tip at the hull and its
## base flaring outward into open water, in the station's live aim direction.
## Reach `h` and base half-width are linked via
## GameFeel.floodlight.base_half_width_m(h) (a chord of a circle of radius R
## centered on the lamp). Drawn as several length-wise slices whose alpha
## follows a sigmoid falloff with distance — light decays the farther it
## travels from the lamp, centered at h/2 with width h/8, so the falloff
## always scales with the beam's current reach (2026-06-2x). Each slice is
## further drawn as a few nested, wider, more-transparent trapezoids (widest
## first) so the beam's lateral edges fade out softly instead of cutting off
## sharply (2026-06-19).
func _draw_floodlight_beam(f: FloodlightStation) -> void:
	if not f.is_on:
		return
	var beam := PlaceholderArt.FLOODLIGHT_COLOR
	var feel := GameFeel.floodlight
	var tip := f.tip_local
	var dir := f.beam_dir()
	var perp := Vector2(-dir.y, dir.x)
	var h := f.height_m
	var half_width_m := feel.base_half_width_m(h)
	var decay_center_m := h * 0.5
	var decay_width_m := h / 8.0
	var segments := 10
	# Widest/faintest fringe first, narrowest/brightest core last (drawn on
	# top), so the overlap reads as a soft glow toward the edges. "extra_m" is
	# an additive meters-wide halo (not a multiple of the cone's own width),
	# distinct from FloodlightFeel's own edge softness — it's MILESTONE_11.md
	# Module 1's depth-fog cutout reaching a bit past the beam's normal edge.
	var fringes := [
		{"scale": 1.6, "alpha_mul": 0.12, "extra_m": 0.0},
		{"scale": 1.3, "alpha_mul": 0.35, "extra_m": 0.0},
		{"scale": 1.0, "alpha_mul": 1.0, "extra_m": 0.0},
	]
	# MILESTONE_11.md Module 1: this extra halo only matters once there's fog
	# to cut through -- scaled by the current darkness so it's a no-op in the
	# fog-free Shallows (and ramps in smoothly, never a hard pop) but a real
	# soft-edged cutout once the water around the lamp has actually darkened.
	var fog_softness_m := GameFeel.fog.floodlight_cutout_softness_m
	var fog_alpha := GameFeel.fog.darkness_alpha(f.sub.depth_m()) if f.sub != null else 0.0
	if fog_softness_m > 0.0 and fog_alpha > 0.0:
		fringes.append({"scale": 1.6, "alpha_mul": 0.05 * fog_alpha, "extra_m": fog_softness_m})
	for i in range(segments):
		var d0 := h * float(i) / segments
		var d1 := h * float(i + 1) / segments
		var p0 := tip + dir * (d0 * Sub.PPM)
		var p1 := tip + dir * (d1 * Sub.PPM)
		var d_mid := (d0 + d1) * 0.5
		var alpha := feel.max_alpha \
			/ (1.0 + exp((d_mid - decay_center_m) / decay_width_m))
		for fringe in fringes:
			var scale: float = fringe["scale"]
			var extra_px: float = float(fringe["extra_m"]) * Sub.PPM
			var w0 := perp * (half_width_m * (d0 / h) * scale * Sub.PPM + extra_px)
			var w1 := perp * (half_width_m * (d1 / h) * scale * Sub.PPM + extra_px)
			draw_colored_polygon(PackedVector2Array([
				p0 - w0, p0 + w0, p1 + w1, p1 - w1,
			]), Color(beam.r, beam.g, beam.b, alpha * float(fringe["alpha_mul"])))

## MILESTONE_11.md Module 1: a soft, low-alpha glow centered on the sub's own
## hull (bounding-box center of its occupied cells), reaching
## GameFeel.fog.ambient_bubble_radius_m past the hull into the dark — the
## sub's own readability bubble, distinct from the floodlight beam. Drawn as
## nested circles, widest/faintest first, like the beam's fringe technique.
func _draw_ambient_bubble(sub: Sub) -> void:
	var radius_m := GameFeel.fog.ambient_bubble_radius_m
	if radius_m <= 0.0:
		return
	# Scaled by the current darkness so the bubble is invisible in the fog-
	# free Shallows (nothing to punch through yet) and fades in smoothly with
	# depth, matching the floodlight's own fog-cutout fringe above.
	var fog_alpha := GameFeel.fog.darkness_alpha(sub.depth_m())
	if fog_alpha <= 0.0:
		return
	var rects := sub.hull_rects()
	if rects.is_empty():
		return
	var bbox: Rect2 = rects[0]
	for r in rects:
		bbox = bbox.merge(r)
	var center := bbox.get_center()
	var radius_px := radius_m * Sub.PPM
	var glow := PlaceholderArt.FLOODLIGHT_COLOR
	var rings := [
		{"scale": 1.0, "alpha": 0.10},
		{"scale": 0.65, "alpha": 0.18},
		{"scale": 0.35, "alpha": 0.28},
	]
	for ring in rings:
		draw_circle(center, radius_px * float(ring["scale"]),
			Color(glow.r, glow.g, glow.b, float(ring["alpha"]) * fog_alpha))

## Flooding water: a flat rect rising from each room's floor. Drawn last.
func _draw_water(sub: Sub) -> void:
	for i in sub.active_room_count():
		var level: float = sub.water_levels[i]
		if level <= 0.0:
			continue
		var r := sub.room_rect(i)
		var height := r.size.y * level
		draw_rect(Rect2(r.position.x, r.position.y + r.size.y - height, r.size.x, height),
			PlaceholderArt.INTERIOR_WATER)

## Ladder rails + rungs: a vertical column centered on `center_x`, spanning
## local-y from `top_y` to `bottom_y`.
func _draw_ladder(center_x: float, top_y: float, bottom_y: float) -> void:
	var rail_x := Sub.HOLE_HALF - 6.0
	var height := bottom_y - top_y
	draw_rect(Rect2(center_x - rail_x - 2.0, top_y, 4.0, height), PlaceholderArt.LADDER_COLOR)
	draw_rect(Rect2(center_x + rail_x - 2.0, top_y, 4.0, height), PlaceholderArt.LADDER_COLOR)
	var rung := top_y + 8.0
	while rung < bottom_y:
		draw_rect(Rect2(center_x - rail_x, rung, rail_x * 2.0, 3.0), PlaceholderArt.LADDER_COLOR)
		rung += 16.0

## Telescope arm (M7-2): straight arm from the hull wall, tip grabber,
## onboard cages at s2 and s4. All in hull-local space so it pitches with the sub.
func _draw_telescope(t: TelescopeStation) -> void:
	if t == null:
		return
	var base := t.base_local
	var tip := t.tip_local()
	var dir := t.facing_dir.rotated(t.aim_angle)
	var perp := dir.orthogonal()
	# Arm tube
	draw_line(base, tip, PlaceholderArt.SUB_STRUCTURE, 7.0)
	# Base mount block
	draw_rect(Rect2(base + Vector2(-10.0, -10.0), Vector2(20.0, 20.0)),
		PlaceholderArt.SUB_STRUCTURE)
	draw_circle(base, 5.0, PlaceholderArt.HULL_COLOR)
	# Chelae (pincer tips): open/spread when waiting for Q; closed when holding an item.
	var jaw_len := 14.0
	if t.has_tip_item():
		# Closed: two short prongs nearly parallel, gripping the item.
		var pinch := perp * 5.0
		draw_line(tip + pinch, tip + pinch + dir * jaw_len, PlaceholderArt.LADDER_COLOR, 3.0)
		draw_line(tip - pinch, tip - pinch + dir * jaw_len, PlaceholderArt.LADDER_COLOR, 3.0)
		draw_circle(tip, 10.0, PlaceholderArt.SCRAP_COLOR.lightened(0.2))
	else:
		# Open: two prongs angled outward from the tip, like spread tongs.
		draw_line(tip, tip + dir.rotated(deg_to_rad(35.0)) * jaw_len, PlaceholderArt.LADDER_COLOR, 3.0)
		draw_line(tip, tip + dir.rotated(deg_to_rad(-35.0)) * jaw_len, PlaceholderArt.LADDER_COLOR, 3.0)
	draw_circle(tip, 5.0, PlaceholderArt.HULL_COLOR)
	# Onboard cages
	_draw_telescope_cages(t)
	if t.has_grabbed_fish():
		_draw_reel_rope(base, tip, t.reel_minigame())

## 2026-06-21 reel-in minigame: a taut rope from the arm's base to a hooked
## catch, with red/yellow/green timing zones near the sub end (see
## ReelMinigame / GameFeel.reel) and a bead sliding along it. Shared by the
## claw and telescope, which otherwise have nothing in common to draw it from.
func _draw_reel_rope(base: Vector2, catch_point: Vector2, reel: ReelMinigame) -> void:
	if reel == null:
		return
	# Whole rope reads as the "miss" zone by default; yellow/green overlay
	# nested bands near the sub end.
	draw_line(base, catch_point, Color(0.85, 0.25, 0.25, 0.55), 3.0)
	var near_point := base.lerp(catch_point, reel.near_zone_frac())
	draw_line(base, near_point, Color(0.95, 0.85, 0.2, 0.85), 4.0)
	var succ_frac := reel.success_zone_frac()
	if succ_frac > 0.0:
		var succ_point := base.lerp(catch_point, succ_frac)
		draw_line(base, succ_point, Color(0.25, 0.95, 0.35, 0.9), 4.0)
	var bead_pos := catch_point.lerp(base, reel.bead_t())
	draw_circle(bead_pos, 7.0, Color(0.1, 0.1, 0.1, 0.9))
	draw_circle(bead_pos, 5.0, Color.WHITE)

## Two onboard cage outlines on the room floor (s2 and s4), filling from bottom
## up as catches auto-deposit. Scrap = small square; color currency (Module 4)
## = small circle tinted by its color (PlaceholderArt.currency_color).
func _draw_telescope_cages(t: TelescopeStation) -> void:
	var floor_y := t.cage_floor_y
	var cage_w := 30.0
	var cage_h := 44.0
	var bar := PlaceholderArt.LADDER_COLOR
	var contents_list: Array = [t.cage_s2(), t.cage_s4()]
	var xs: Array = [t.cage_s2_x, t.cage_s4_x]
	for c in 2:
		var cx: float = xs[c]
		var top_y := floor_y - cage_h
		# Cage frame (three sides; floor is the room floor itself)
		draw_line(Vector2(cx - cage_w * 0.5, top_y),
			Vector2(cx - cage_w * 0.5, floor_y), bar, 2.0)
		draw_line(Vector2(cx + cage_w * 0.5, top_y),
			Vector2(cx + cage_w * 0.5, floor_y), bar, 2.0)
		draw_line(Vector2(cx - cage_w * 0.5, top_y),
			Vector2(cx + cage_w * 0.5, top_y), bar, 2.0)
		# Crossbar ribs
		var rib_y := top_y + cage_h * 0.5
		draw_line(Vector2(cx - cage_w * 0.5, rib_y),
			Vector2(cx + cage_w * 0.5, rib_y), bar, 1.0)
		# Contents stacked bottom-up, 2 per row
		var contents: Array[Dictionary] = contents_list[c]
		for i in contents.size():
			var row := i / 2
			var col := i % 2
			var px := cx - 7.0 + col * 14.0
			var py := floor_y - 7.0 - row * 14.0
			var slot := contents[i]
			if slot["kind"] == SalvageItem.Kind.SCRAP:
				draw_rect(Rect2(px - 4.0, py - 4.0, 8.0, 8.0), PlaceholderArt.SCRAP_COLOR)
			else:
				var sides := SalvageItem.shape_sides_for(int(slot["value"]))
				_draw_currency_icon(Vector2(px, py), 4.0, sides,
					PlaceholderArt.currency_color(slot["color"]))

## Mirrors SalvageItem's world-drop shape (1/5/10/50 -> triangle/square/
## pentagon/hexagon) at icon scale, so a cage slot's denomination reads the
## same way it did before it was caught.
func _draw_currency_icon(center: Vector2, radius: float, sides: int, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := TAU * i / sides - PI / 2.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)

func _draw_round_rect(rect: Rect2, radius: float, color: Color) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	draw_rect(Rect2(rect.position + Vector2(r, 0), Vector2(rect.size.x - 2.0 * r, rect.size.y)), color)
	draw_rect(Rect2(rect.position + Vector2(0, r), Vector2(rect.size.x, rect.size.y - 2.0 * r)), color)
	draw_circle(rect.position + Vector2(r, r), r, color)
	draw_circle(rect.position + Vector2(rect.size.x - r, r), r, color)
	draw_circle(rect.position + Vector2(r, rect.size.y - r), r, color)
	draw_circle(rect.position + Vector2(rect.size.x - r, rect.size.y - r), r, color)
