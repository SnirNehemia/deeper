class_name Sub
extends CharacterBody2D

## The submarine: one physics body with a cutaway interior the crew run around
## inside. Built entirely in code, but its geometry is no longer hand-authored:
## the layout (a SubLayout of placed room modules on the uniform grid) is
## compiled by SubGeometry into room rects, auto-doorways, and parity-placed
## ladders, and this node generates the interior collision/water/hull from that
## (MODULAR_SUB_IMPLEMENTATION.md §4; ROOM_SYSTEM.md §2-3). One pipeline — if
## geometry is ever built anywhere else, that's a bug.
##
## Local space convention: the helm row's interior FLOOR top is at y = 0 and
## "up" is negative y (SubGeometry is re-anchored to keep this). The crew are
## parented to this node, so when the sub moves they ride along. The outer hull
## collides with TERRAIN; interior pieces are separate static bodies on the
## INTERIOR layer that only the crew touch.

const PPM := 48.0

## Interior wall/floor slab thickness.
const WALL_T := 16.0
## Doorway opening height above the floor (2 m).
const DOOR_H := 2.0 * PPM  # 96
## A low step on the floor in each doorway: crew hop to cross (playtest #2).
const DOOR_STEP_H := 0.3 * PPM  # ~14
## Ladder floor-opening / shaft width (the visible ladder width); HOLE_HALF
## kept for crew centering. 0.9m (narrowed from 1.0m at Checkpoint 1).
const HOLE_W := 0.9 * PPM   # 43.2
const HOLE_HALF := HOLE_W * 0.5  # 21.6

## Uniform cell size (one room), from the grid constants.
const CELL_W := SubGrid.CELL_W_PX  # 180
const CELL_H := SubGrid.CELL_H_PX  # 144

## Hull silhouette margin: each occupied cell grows by this to form the hull.
const HULL_MARGIN := 32.0

## Vertical ladder openings only spill water UP into the room above once the
## lower room is nearly full (the tower/upper rooms stay dry until then) — the
## M3 conning behavior, now applied to every stacked pair.
const LADDER_SILL_FRACTION := 0.95

## The sub floats here (px below the surface). Above this line, weight fades in
## over EMERGE_RANGE so the rise gets heavier as it emerges (can't fly out).
const SURFACE_FLOAT_DEPTH := 150.0
const _EMERGE_RANGE := 220.0

## The layout this sub is generated from. Defaults to the Minnow+ starting
## layout; the world/tests can assign a different one before _ready.
var layout: SubLayout = SubLayout.starting_layout()
## The compiled geometry (rooms, doors, ladders), re-anchored to floor-y=0.
var geometry: SubGeometry

## The persistent upgrade state (engine boost + repair training are stats and
## still apply; the M3 gun_room is dropped until M4-9 re-adds it as a placed
## turret room — see DECISIONS 2026-06-13). Read at build time.
var loadout: SubLoadout = SubLoadout.new()

## Desired drive direction this frame, set by the helm occupant.
var drive_input: Vector2 = Vector2.ZERO
## Current cosmetic pitch (radians); the hull art + crew art tilt by this.
var pitch: float = 0.0

## Buoyancy: neutrally buoyant underwater, heavier as it rises out of the water.
var buoyancy_enabled: bool = false
var water_surface_y: float = 0.0

## Per-room water level (0-1), indexed by room water index (placement order).
var water_levels: Array[float] = []

## How many rooms this sub has (placement count). Internal loops use this.
var _active_rooms: int = 0
## Cached movement multiplier from the loadout (engine boost).
var _move_mult: float = 1.0

## Live hull breaches, each leaking into its room.
var breaches: Array[Breach] = []

## On-board salvage storage (Module B): banked at the dock, lost on implosion.
var storage_scrap: int = 0
var storage_fish: int = 0

signal salvage_collected(kind: int)
signal breach_spawned(breach: Breach)
signal imploded

var _implosion_fired: bool = false

var _visual: SubVisual
var _hull_shapes: Array[CollisionShape2D] = []
var _hull_shape_centers: Array[Vector2] = []
var _impact_cooldown: float = 0.0
const _IMPACT_COOLDOWN_TIME := 0.6

# Cached seat/anchor positions (sub-local), computed from the geometry at build.
var _helm_seat: Vector2 = Vector2.ZERO
var _turret_seat: Vector2 = Vector2.ZERO
var _turret_tube: Vector2 = Vector2.ZERO
var _claw_seat: Vector2 = Vector2.ZERO
var _claw_anchor: Vector2 = Vector2.ZERO
var _claw_drop_floor_y: float = 0.0
var _claw_hatch: Vector2 = Vector2.ZERO
var _storage_pen: Vector2 = Vector2.ZERO
var _respawn_local: Vector2 = Vector2.ZERO
## Crew start-of-run seats in the conning tower, one per potential player
## (up to 4). Empty if there's no tower (shouldn't happen in a valid layout).
var _tower_seats: Array[Vector2] = []
## One entry per placed `turret_room` (M4-10, ROOM_SYSTEM.md §6 "Base gun
## room"): {"room": SubGeometry.Room, "seat": Vector2, "tube": Vector2,
## "facing": float}. Built in _compute_anchors, consumed by
## _build_turret_room. Distinct from the legacy bow-gun anchors above (the
## starting "room" module), which stay as the Minnow+'s built-in weapon.
var _turret_rooms: Array = []

## Same shape as `_turret_rooms`, for placed `bullet_room`s (M4-12,
## ROOM_SYSTEM.md §6 "Bullet weapon room") — computed by the same
## `_gun_room_anchors` helper, consumed by `_build_bullet_room`.
var _bullet_rooms: Array = []

func _ready() -> void:
	collision_layer = Layers.SUB_HULL
	collision_mask = Layers.TERRAIN
	_move_mult = loadout.move_mult()

	# Compile + re-anchor the geometry so the helm row's floor sits at y = 0.
	geometry = SubGeometry.build(layout)
	var helm := _room_by_id("helm")
	if helm != null:
		geometry.translate(Vector2(0.0, -(helm.rect.position.y + helm.rect.size.y)))

	_active_rooms = geometry.rooms.size()
	water_levels.resize(_active_rooms)
	for i in _active_rooms:
		water_levels[i] = 0.0

	_compute_anchors()

	_visual = SubVisual.new()
	add_child(_visual)
	_build_hull_collision()
	_build_interior()
	_build_stations()

## How many water rooms this sub currently has.
func active_room_count() -> int:
	return _active_rooms

## Kept for callers from the M3 gun-room era; the layout-driven sub has no
## bolt-on gun room (it returns as a placed turret room in M4-9).
func has_gun_room() -> bool:
	return false

func gun_room_side() -> int:
	return 0

## The repair-time multiplier the crew applies (from "Repair Training").
func repair_time_mult() -> float:
	return loadout.repair_time_mult()

# --- Room geometry accessors (the public API the crew/water/stations use) ---

## The Room (SubGeometry.Room) carrying a given module id, or null. First match.
func _room_by_id(id: String) -> SubGeometry.Room:
	for room in geometry.rooms:
		if room.module_id == id:
			return room
	return null

## Sub-local rect of a water room by index (its open interior, floor = bottom).
func room_rect(i: int) -> Rect2:
	if i < 0 or i >= geometry.rooms.size():
		return Rect2()
	return geometry.rooms[i].rect

## Cross-sectional area of a room, used to weight flow and overall fill.
func room_volume(i: int) -> float:
	var r := room_rect(i)
	return r.size.x * r.size.y

## Volume-weighted average fill across all rooms (0-1).
func total_fill_fraction() -> float:
	var total_water := 0.0
	var total_vol := 0.0
	for i in _active_rooms:
		var vol := room_volume(i)
		total_water += water_levels[i] * vol
		total_vol += vol
	if total_vol <= 0.0:
		return 0.0
	return total_water / total_vol

## Which water room a local-space point falls in, or -1 if outside all rooms.
func room_index_at(local_pos: Vector2) -> int:
	for i in _active_rooms:
		if room_rect(i).has_point(local_pos):
			return i
	return -1

## Water surface y (local space) for a room, or +INF if the index is invalid.
func room_water_surface_y(room: int) -> float:
	if room < 0 or room >= _active_rooms:
		return INF
	var r := room_rect(room)
	return r.position.y + r.size.y * (1.0 - water_levels[room])

## Which water room is closest to a local point (for impacts/bites on the shell).
func nearest_room(local_pos: Vector2) -> int:
	var direct := room_index_at(local_pos)
	if direct >= 0:
		return direct
	var best := 0
	var best_d := INF
	for i in _active_rooms:
		var d := local_pos.distance_squared_to(room_rect(i).get_center())
		if d < best_d:
			best_d = d
			best = i
	return best

# --- Seat / anchor positions (sub-local), computed once from the geometry ---

## Sub-local x of a given section within a room (1..5), via the compiler.
func _section_x(room: SubGeometry.Room, section: int) -> float:
	return SubGeometry.section_center_x(room.rect.position.x, section)

## Element positions are anchored to their authored section (ROOM_SYSTEM.md §6),
## never to a wall offset — so they line up on the section grid.
func _compute_anchors() -> void:
	var crew_half := PlaceholderArt.CREW_HEIGHT_M * PPM * 0.5

	# Control room (helm): station in s3.
	var helm := _room_by_id("helm")
	if helm != null:
		var floor_y := helm.rect.position.y + helm.rect.size.y
		_helm_seat = Vector2(_section_x(helm, 3), floor_y - crew_half)
		# Bow torpedo tube: just off the helm room's outer (bow) wall, mid-height.
		# (The base M2 gun; the proper wall-mounted gun room arrives at M4-9.)
		_turret_tube = Vector2(helm.rect.position.x + helm.rect.size.x + 36.0,
			helm.rect.get_center().y)

	# Base gun room (the middle "room"): gunner station in s3.
	var middle := _room_by_id("room")
	if middle != null:
		_turret_seat = Vector2(_section_x(middle, 3),
			middle.rect.position.y + middle.rect.size.y - crew_half)

	# Claw room: station in s3, claw base at b3 (bottom of s3), dropping hatch
	# at s2 (ROOM_SYSTEM.md §6).
	var claw_room := _room_by_id("claw_room")
	if claw_room != null:
		var floor_y := claw_room.rect.position.y + claw_room.rect.size.y
		_claw_seat = Vector2(_section_x(claw_room, 3), floor_y - crew_half)
		# Keel anchor (claw base, b3): bottom of s3, below the floor slab.
		_claw_anchor = Vector2(_section_x(claw_room, 3), floor_y + WALL_T)
		_claw_drop_floor_y = floor_y
		# Dropping hatch in s2 — where the arm delivers catches into the hold.
		_claw_hatch = Vector2(_section_x(claw_room, 2), floor_y)

	# Storage room: cage in s3 (upgrades add cages to s4 then s2).
	var storage := _room_by_id("storage")
	if storage != null:
		_storage_pen = Vector2(_section_x(storage, 3),
			storage.rect.position.y + storage.rect.size.y - 27.0)

	# Respawn in the conning tower — the safest, last-to-flood spot.
	var tower := _room_by_id("tower")
	if tower != null:
		_respawn_local = Vector2(tower.rect.get_center().x,
			tower.rect.position.y + tower.rect.size.y - crew_half)
		# Crew start-of-run seats (up to 4 players), spread across the tower
		# floor in sections 2/4/1/5 (s3 stays clear for the ladder/respawn
		# center). ROOM_SYSTEM.md crew-start rework, 2026-06-14.
		var tower_floor_y := tower.rect.position.y + tower.rect.size.y - crew_half
		_tower_seats = [
			Vector2(_section_x(tower, 2), tower_floor_y),
			Vector2(_section_x(tower, 4), tower_floor_y),
			Vector2(_section_x(tower, 1), tower_floor_y),
			Vector2(_section_x(tower, 5), tower_floor_y),
		]
	elif helm != null:
		_respawn_local = _helm_seat

	# Placed gun rooms (turret_room M4-10, bullet_room M4-12): gunner seat in
	# s3, tube on the firing-face wall (mirrored picks which side it points
	# to — validate() rule 5 already guarantees that side is exterior).
	_turret_rooms = _gun_room_anchors("turret_room", crew_half)
	_bullet_rooms = _gun_room_anchors("bullet_room", crew_half)

## One {"room", "seat", "tube", "facing"} entry per placed room of `module_id`
## with a firing-face gun: gunner seat in s3, tube just outside the firing-face
## wall (mirrored -> stern/-x, unmirrored -> bow/+x), same convention as
## SubValidator._firing_face_offset.
func _gun_room_anchors(module_id: String, crew_half: float) -> Array:
	var anchors: Array = []
	for room in geometry.rooms:
		if room.module_id != module_id:
			continue
		var floor_y := room.rect.position.y + room.rect.size.y
		var seat := Vector2(_section_x(room, 3), floor_y - crew_half)
		var tube: Vector2
		var facing: float
		if room.mirrored:
			tube = Vector2(room.rect.position.x - 36.0, room.rect.get_center().y)
			facing = -1.0
		else:
			tube = Vector2(room.rect.position.x + room.rect.size.x + 36.0, room.rect.get_center().y)
			facing = 1.0
		anchors.append({"room": room, "seat": seat, "tube": tube, "facing": facing})
	return anchors

func helm_seat_local() -> Vector2:
	return _helm_seat
func turret_seat_local() -> Vector2:
	return _turret_seat
func turret_tube_local() -> Vector2:
	return _turret_tube
func claw_seat_local() -> Vector2:
	return _claw_seat
func claw_anchor_local() -> Vector2:
	return _claw_anchor
func claw_drop_floor_y() -> float:
	return _claw_drop_floor_y
## The dropping hatch on the claw room floor (section s2), where the claw
## delivers catches into the hold (sub-local).
func hold_hatch_local() -> Vector2:
	return _claw_hatch
## A sub-local spot in the conning tower for a respawning crew member to stand.
func respawn_local() -> Vector2:
	return _respawn_local

## Sub-local start-of-run seat in the conning tower for player `index`
## (0-based, up to 4). Falls back to `respawn_local()` if there's no
## dedicated seat for that index.
func tower_seat_local(index: int) -> Vector2:
	if index < _tower_seats.size():
		return _tower_seats[index]
	return _respawn_local

func _physics_process(delta: float) -> void:
	var feel: GameFeel.SubFeel = GameFeel.sub
	var ppm: float = GameFeel.PIXELS_PER_METER
	var mult := _move_mult

	var target_x := clampf(drive_input.x, -1.0, 1.0) * feel.max_speed_h * ppm * mult
	var rate_x := feel.accel_h() if absf(target_x) > 0.01 else feel.decel_h()
	velocity.x = move_toward(velocity.x, target_x, rate_x * ppm * mult * delta)

	var max_v := feel.max_speed_v * ppm * mult
	if absf(drive_input.y) > 0.01:
		velocity.y += clampf(drive_input.y, -1.0, 1.0) * feel.accel_v() * ppm * mult * delta
	else:
		velocity.y = move_toward(velocity.y, 0.0, feel.decel_v() * ppm * delta)
	if buoyancy_enabled:
		var above := (water_surface_y + SURFACE_FLOAT_DEPTH) - global_position.y
		var emergence := clampf(above / _EMERGE_RANGE, 0.0, 1.0)
		velocity.y += feel.surface_gravity * ppm * emergence * delta

	_update_water(delta)
	velocity.y += GameFeel.water.weight_accel * ppm * total_fill_fraction() * delta

	if not _implosion_fired \
			and total_fill_fraction() >= GameFeel.water.implosion_fraction:
		_implosion_fired = true
		imploded.emit()

	velocity.y = clampf(velocity.y, -max_v, max_v)

	var pre_velocity := velocity
	move_and_slide()
	_check_terrain_impacts(pre_velocity, delta)

	var t := clampf(velocity.x / (feel.max_speed_h * ppm), -1.0, 1.0)
	pitch = deg_to_rad(feel.max_pitch_deg) * t
	_visual.rotation = pitch
	_set_hull_rotation(pitch)
	_visual.queue_redraw()

## Depth shown to the player: metres below the surface.
func depth_m() -> float:
	var below := global_position.y - water_surface_y - SURFACE_FLOAT_DEPTH
	return maxf(0.0, below / GameFeel.PIXELS_PER_METER)

## The water-cell connections (door + ladder pairs) the flow model consumes,
## each {a, b, sill}. Doors spill over a knee-high sill; ladders only spill up
## once the lower room is nearly full (LADDER_SILL_FRACTION).
func _connections() -> Array:
	var door_sill: float = GameFeel.water.door_sill_m / GameFeel.water.room_height_m
	var conns: Array = []
	for door in geometry.doors:
		conns.append({"a": door.a_index, "b": door.b_index, "sill": door_sill})
	for ladder in geometry.ladders:
		conns.append({"a": ladder.upper_index, "b": ladder.lower_index, "sill": LADDER_SILL_FRACTION})
	return conns

func _update_water(delta: float) -> void:
	var w: GameFeel.WaterFeel = GameFeel.water
	var room_breached: Array[bool] = []
	room_breached.resize(_active_rooms)
	for breach in breaches:
		water_levels[breach.room] += breach.leak_rate * delta
		room_breached[breach.room] = true
	for i in _active_rooms:
		if not room_breached[i]:
			water_levels[i] -= w.drain_rate * delta
	for conn in _connections():
		_flow_over_sill(conn["a"], conn["b"], conn["sill"], w.flow_rate, delta)
	for i in _active_rooms:
		water_levels[i] = clampf(water_levels[i], 0.0, 1.0)

## Spill water from the higher of two rooms into the lower, but only the part
## standing above the connection's sill. Volume-conserving.
func _flow_over_sill(a: int, b: int, sill: float, rate: float, delta: float) -> void:
	if maxf(water_levels[a], water_levels[b]) <= sill:
		return
	var hi := a
	var lo := b
	if water_levels[b] > water_levels[a]:
		hi = b
		lo = a
	var effective: float = water_levels[hi] - maxf(sill, water_levels[lo])
	if effective <= 0.0:
		return
	var transfer: float = rate * effective * delta
	water_levels[hi] -= transfer
	water_levels[lo] += transfer * room_volume(hi) / room_volume(lo)

func _check_terrain_impacts(pre_velocity: Vector2, delta: float) -> void:
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)
	if _impact_cooldown > 0.0:
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var approach_mps := maxf(0.0, -pre_velocity.dot(col.get_normal())) / PPM
		if register_impact(approach_mps, col.get_position()):
			_impact_cooldown = _IMPACT_COOLDOWN_TIME
			break

## Apply a terrain impact at the given speed (m/s) and global point. Exposed
## for headless tests.
func register_impact(speed_mps: float, global_point: Vector2) -> bool:
	var w: GameFeel.WaterFeel = GameFeel.water
	if speed_mps < w.breach_speed_threshold:
		return false
	var rate := w.leak_rate_min
	if speed_mps >= w.breach_speed_high:
		rate = w.leak_rate_max
	elif speed_mps >= w.breach_speed_mid:
		rate = w.leak_rate_mid
	var local := to_local(global_point)
	spawn_breach(nearest_room(local), rate, local)
	return true

## Open a breach leaking into `room` at `rate`. Also used by fish bites.
func spawn_breach(room: int, rate: float, local_pos := Vector2.INF) -> Breach:
	var breach := Breach.new()
	breach.room = room
	breach.leak_rate = rate
	var r := room_rect(room)
	if local_pos == Vector2.INF:
		local_pos = Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y)
	breach.position = local_pos.clamp(r.position, r.position + r.size)
	breaches.append(breach)
	_visual.add_child(breach)
	breach_spawned.emit(breach)
	return breach

func remove_breach(breach: Breach) -> void:
	breaches.erase(breach)
	breach.queue_free()

func play_implosion_crunch() -> void:
	var tween := create_tween()
	_visual.modulate = PlaceholderArt.BREACH_COLOR
	tween.tween_property(_visual, "scale", Vector2(0.92, 0.8), 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_visual, "modulate", Color.WHITE, 0.5)

func reset_state() -> void:
	for i in _active_rooms:
		water_levels[i] = 0.0
	for breach in breaches:
		breach.queue_free()
	breaches.clear()
	storage_scrap = 0
	storage_fish = 0
	velocity = Vector2.ZERO
	drive_input = Vector2.ZERO
	pitch = 0.0
	_impact_cooldown = 0.0
	_implosion_fired = false
	_visual.scale = Vector2.ONE
	_visual.modulate = Color.WHITE
	_visual.rotation = 0.0
	_set_hull_rotation(0.0)

# --- Storage / banking (Module B/C) ---

func storage_pen_center() -> Vector2:
	return _storage_pen

func near_storage(local_pos: Vector2) -> bool:
	return local_pos.distance_to(storage_pen_center()) <= 1.6 * PPM

func storage_count() -> int:
	return storage_scrap + storage_fish

func storage_full() -> bool:
	return storage_count() >= GameFeel.claw.storage_capacity

func deposit_salvage(kind: int) -> bool:
	if storage_full():
		return false
	match kind:
		SalvageItem.Kind.SCRAP:
			storage_scrap += 1
		SalvageItem.Kind.FISH:
			storage_fish += 1
	salvage_collected.emit(kind)
	return true

func try_bank(dock_pos: Vector2, radius: float) -> bool:
	if global_position.distance_to(dock_pos) > radius:
		return false
	if storage_scrap <= 0 and storage_fish <= 0:
		return false
	SaveData.bank(storage_scrap, storage_fish)
	storage_scrap = 0
	storage_fish = 0
	return true

# --- Hull (generated from the occupied cells) ---

## Sub-local rect of a grid cell (anchored like the room rects), for the hull
## and for slot shells.
func cell_rect(cell: Vector2i) -> Rect2:
	return geometry.cell_rect(cell)

## The rounded rects that make up the hull silhouette: one per occupied cell
## (placed room or bought slot) grown by the hull margin. Adjacent grown rects
## overlap so the union reads as one continuous hull. Shared by the collider
## and SubVisual so they always match.
func hull_rects() -> Array:
	var rects: Array = []
	for cell in layout.occupied_cells():
		rects.append(cell_rect(cell).grow(HULL_MARGIN))
	return rects

func _build_hull_collision() -> void:
	for r in hull_rects():
		_add_hull_rect(r)

func _add_hull_rect(r: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.position + r.size * 0.5
	add_child(shape)
	_hull_shapes.append(shape)
	_hull_shape_centers.append(shape.position)

func _set_hull_rotation(angle: float) -> void:
	for i in _hull_shapes.size():
		_hull_shapes[i].position = _hull_shape_centers[i].rotated(angle)
		_hull_shapes[i].rotation = angle

# --- Interior generation (walls, floors, ceilings, doors, ladders) ---

func _build_interior() -> void:
	# Horizontal slabs: each room's floor (shared as the ceiling of the room
	# below it), plus a solid ceiling for any room with nothing above.
	for room in geometry.rooms:
		_build_floor(room)
		if geometry.index_at(room.cell + Vector2i(0, -1)) < 0:
			_build_ceiling(room)
	# Vertical walls: exterior walls where a room has no neighbour; doorways
	# where two rooms share a vertical edge (built once, from the left room).
	for room in geometry.rooms:
		if geometry.index_at(room.cell + Vector2i(-1, 0)) < 0:
			_build_exterior_wall(room, -1)
		if geometry.index_at(room.cell + Vector2i(1, 0)) < 0:
			_build_exterior_wall(room, 1)
		else:
			_build_doorway(room)
	# Ladders: one shaft per stacked pair, on the parity section.
	for ladder in geometry.ladders:
		_add_ladder_shaft(ladder.x, ladder.top_y, ladder.bottom_y)

## A room's floor slab (top surface at the rect's bottom edge). If a room sits
## below, leave a HOLE_W ladder opening and cover it with a HATCH deck (crew
## stand on it unless they press down to climb).
func _build_floor(room: SubGeometry.Room) -> void:
	var r := room.rect
	var floor_y := r.position.y + r.size.y
	var below := room.cell + Vector2i(0, 1)
	if geometry.index_at(below) < 0:
		_add_static(Vector2(r.get_center().x, floor_y + WALL_T * 0.5), Vector2(r.size.x, WALL_T))
		return
	var hole_x := _ladder_x_between(room.cell, below)
	var left_w := (hole_x - HOLE_HALF) - r.position.x
	var right_w := (r.position.x + r.size.x) - (hole_x + HOLE_HALF)
	if left_w > 0.0:
		_add_static(Vector2(r.position.x + left_w * 0.5, floor_y + WALL_T * 0.5), Vector2(left_w, WALL_T))
	if right_w > 0.0:
		_add_static(Vector2(r.position.x + r.size.x - right_w * 0.5, floor_y + WALL_T * 0.5),
			Vector2(right_w, WALL_T))
	# Solid HATCH deck over the opening (crew don't auto-fall; climbing drops it).
	_add_hatch(Vector2(hole_x, floor_y + WALL_T * 0.5), Vector2(HOLE_W, WALL_T))

## A solid ceiling slab for a room with nothing above it (top of the sub).
func _build_ceiling(room: SubGeometry.Room) -> void:
	var r := room.rect
	_add_static(Vector2(r.get_center().x, r.position.y - WALL_T * 0.5), Vector2(r.size.x, WALL_T))

## A solid exterior side wall on `side` (-1 left, +1 right) of a room.
func _build_exterior_wall(room: SubGeometry.Room, side: int) -> void:
	var r := room.rect
	var edge_x := r.position.x if side < 0 else r.position.x + r.size.x
	_add_static(Vector2(edge_x + side * WALL_T * 0.5, r.get_center().y),
		Vector2(WALL_T, r.size.y + WALL_T))

## A doorway in a room's right wall (shared with the room to its right): a
## header hanging from the ceiling leaving DOOR_H clearance, plus a floor step.
func _build_doorway(room: SubGeometry.Room) -> void:
	var r := room.rect
	var wall_x := r.position.x + r.size.x
	var floor_y := r.position.y + r.size.y
	var header_h := r.size.y - DOOR_H
	_add_static(Vector2(wall_x, r.position.y + header_h * 0.5), Vector2(WALL_T, header_h))
	_add_static(Vector2(wall_x, floor_y - DOOR_STEP_H * 0.5), Vector2(WALL_T, DOOR_STEP_H))

## The sub-local x of the ladder shaft between two vertically stacked cells.
func _ladder_x_between(upper: Vector2i, lower: Vector2i) -> float:
	for ladder in geometry.ladders:
		if ladder.upper_cell == upper and ladder.lower_cell == lower:
			return ladder.x
	return cell_rect(upper).get_center().x

func _add_ladder_shaft(center_x: float, top_y: float, bottom_y: float) -> void:
	var ladder := Area2D.new()
	ladder.collision_layer = Layers.LADDER
	ladder.collision_mask = 0
	ladder.monitorable = true
	ladder.monitoring = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(HOLE_W, bottom_y - top_y)
	shape.shape = rect
	shape.position = Vector2(center_x, (top_y + bottom_y) * 0.5)
	ladder.add_child(shape)
	add_child(ladder)

func _add_static(center: Vector2, size: Vector2) -> void:
	_add_box(center, size, Layers.INTERIOR)

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

# --- Stations (helm, base turret, claw), seated from the computed anchors ---

func _build_stations() -> void:
	if _room_by_id("helm") != null:
		_build_helm()
	if _room_by_id("room") != null:
		_build_turret()
	for tr in _turret_rooms:
		_build_turret_room(tr)
	for br in _bullet_rooms:
		_build_bullet_room(br)
	if _room_by_id("claw_room") != null:
		_build_claw()

func _build_helm() -> void:
	var helm := HelmStation.new()
	helm.sub = self
	helm.room_index = _room_by_id("helm").water_index
	helm.position = _helm_seat
	add_child(helm)

func _build_turret() -> void:
	var turret := TurretStation.new()
	turret.sub = self
	turret.room_index = _room_by_id("room").water_index
	turret.position = _turret_seat
	turret.tube_local = _turret_tube
	turret.facing = 1.0
	add_child(turret)
	_visual.turrets.append(turret)

## A placed Turret Room's gunner station (M4-10) — same TurretStation as the
## legacy bow gun, seated/aimed from this room's own anchors.
func _build_turret_room(tr: Dictionary) -> void:
	var turret := TurretStation.new()
	turret.sub = self
	turret.room_index = tr["room"].water_index
	turret.position = tr["seat"]
	turret.tube_local = tr["tube"]
	turret.facing = tr["facing"]
	add_child(turret)
	_visual.turrets.append(turret)

## A placed Bullet Room's gunner station (M4-12, ROOM_SYSTEM.md §6 "Bullet
## weapon room") — same TurretStation as the Turret Room, but firing fast,
## low-damage bullets at a high rate instead of torpedoes.
func _build_bullet_room(br: Dictionary) -> void:
	var turret := TurretStation.new()
	turret.sub = self
	turret.room_index = br["room"].water_index
	turret.position = br["seat"]
	turret.tube_local = br["tube"]
	turret.facing = br["facing"]
	turret.fire_cooldown = GameFeel.bullet.fire_cooldown
	turret.projectile_speed = GameFeel.bullet.bullet_speed
	turret.use_bullet = true
	add_child(turret)
	_visual.turrets.append(turret)

func _build_claw() -> void:
	var claw := ClawStation.new()
	claw.sub = self
	claw.room_index = _room_by_id("claw_room").water_index
	claw.position = _claw_seat
	claw.anchor_local = _claw_anchor
	claw.drop_floor_y = _claw_drop_floor_y
	claw.hatch_x = _claw_hatch.x
	add_child(claw)
	_visual.claw = claw
