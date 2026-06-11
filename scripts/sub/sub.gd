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
const CONN_HEIGHT := 2.0 * PPM         # 96 — conning area headroom
const DECK_Y := CEIL_Y - WALL_T        # top of the ceiling segments
const CONN_CEIL_Y := DECK_Y - CONN_HEIGHT

# Divider x positions between the three rooms.
const DIV_X := ROOM_W * 0.5   # 120

## Water "rooms": engine (0), middle (1), helm (2), conning area (3).
const ROOM_COUNT := 4
## Connections water can flow through: engine<->middle, middle<->helm via the
## doorways, middle<->conning via the ladder opening.
const WATER_CONNECTIONS := [[0, 1], [1, 2], [1, 3]]

# Helm seat location (helm/bow room, near the floor). Crew origin sits here.
const HELM_X := HALF_W - ROOM_W * 0.5                          # 240 — helm room center
const HELM_SEAT_Y := -PlaceholderArt.CREW_HEIGHT_M * PPM * 0.5 # crew feet on the floor

## Desired drive direction this frame, set by the helm occupant (each axis in
## [-1, 1]). Zero when no one is steering — the sub then coasts to a stop.
var drive_input: Vector2 = Vector2.ZERO

## Current cosmetic pitch (radians). The hull art and the crew art both tilt by
## this; the physics body stays upright. Read by crew to match the tilted floor.
var pitch: float = 0.0

## Buoyancy: when enabled, the sub is neutrally buoyant underwater but gets
## heavier as it rises out of the water, so it floats at the surface and can't
## fly. The world enables this; dry sandboxes/tests leave it off.
var buoyancy_enabled: bool = false
var water_surface_y: float = 0.0

# The sub floats here (px below the surface) — spawn it at this depth so it rests
# without bobbing. Above this line, weight fades in over EMERGE_RANGE so the rise
# gets heavier the further it emerges, and it can't lift its hull out of the water.
const SURFACE_FLOAT_DEPTH := 150.0
const _EMERGE_RANGE := 220.0

## Per-room water level (0-1 fraction of room height), indexed by
## room id: 0 = engine, 1 = middle, 2 = helm, 3 = conning area.
var water_levels: Array[float] = [0.0, 0.0, 0.0, 0.0]

## Live hull breaches, each leaking into its room (see Breach).
var breaches: Array[Breach] = []

## Fired when a new breach opens (HUD listens for the alert flash).
signal breach_spawned(breach: Breach)

var _visual: SubVisual
var _hull_collision: CollisionPolygon2D
# Grace period between impact-spawned breaches so one scrape along the rocks
# doesn't open a breach every physics frame.
var _impact_cooldown: float = 0.0
const _IMPACT_COOLDOWN_TIME := 0.6

func _ready() -> void:
	collision_layer = Layers.SUB_HULL
	collision_mask = Layers.TERRAIN
	_visual = SubVisual.new()
	add_child(_visual)
	_build_hull_collision()
	_build_interior()
	_build_ladder()
	_build_helm()

func _physics_process(delta: float) -> void:
	var feel: GameFeel.SubFeel = GameFeel.sub
	var ppm: float = GameFeel.PIXELS_PER_METER

	# Horizontal: velocity-target control (heavy spin-up / long coast).
	var target_x := clampf(drive_input.x, -1.0, 1.0) * feel.max_speed_h * ppm
	var rate_x := feel.accel_h() if absf(target_x) > 0.01 else feel.decel_h()
	velocity.x = move_toward(velocity.x, target_x, rate_x * ppm * delta)

	# Vertical: acceleration-based thrust (bounded), so buoyancy weight can
	# actually overpower it near the surface instead of being cancelled out.
	var max_v := feel.max_speed_v * ppm
	if absf(drive_input.y) > 0.01:
		velocity.y += clampf(drive_input.y, -1.0, 1.0) * feel.accel_v() * ppm * delta
	else:
		velocity.y = move_toward(velocity.y, 0.0, feel.decel_v() * ppm * delta)
	if buoyancy_enabled:
		var above := (water_surface_y + SURFACE_FLOAT_DEPTH) - global_position.y
		var emergence := clampf(above / _EMERGE_RANGE, 0.0, 1.0)
		velocity.y += feel.surface_gravity * ppm * emergence * delta

	_update_water(delta)
	velocity.y += GameFeel.water.weight_accel * ppm * total_fill_fraction() * delta

	velocity.y = clampf(velocity.y, -max_v, max_v)

	var pre_velocity := velocity
	move_and_slide()
	_check_terrain_impacts(pre_velocity, delta)

	# Cosmetic pitch tilt proportional to horizontal speed. The crew art stays
	# aligned (they read `pitch`); the hull collider tilts with it so collisions
	# match the visible hull. The body's other axes stay upright (no sliding).
	var t := clampf(velocity.x / (feel.max_speed_h * ppm), -1.0, 1.0)
	pitch = deg_to_rad(feel.max_pitch_deg) * t
	_visual.rotation = pitch
	_hull_collision.rotation = pitch
	_visual.queue_redraw()

## Depth shown to the player: metres below the surface. Reads 0 while the sub
## floats at rest (its keel sits SURFACE_FLOAT_DEPTH down, which we treat as the
## waterline), and clamps at 0 above that.
func depth_m() -> float:
	var below := global_position.y - water_surface_y - SURFACE_FLOAT_DEPTH
	return maxf(0.0, below / GameFeel.PIXELS_PER_METER)

## Local-space rectangle of a water "room" (0=engine, 1=middle, 2=helm,
## 3=conning area), floor-to-ceiling, used for both volume math and rendering.
func room_rect(i: int) -> Rect2:
	if i == 3:
		return Rect2(-CONN_HALF, CONN_CEIL_Y, CONN_HALF * 2.0, CONN_HEIGHT)
	var room_x := -HALF_W + i * ROOM_W
	return Rect2(room_x, CEIL_Y, ROOM_W, ROOM_H)

## Cross-sectional "volume" (area) of a water room, used to weight flow and the
## overall fill fraction so the smaller conning area fills/drains faster.
func room_volume(i: int) -> float:
	var r := room_rect(i)
	return r.size.x * r.size.y

## Volume-weighted average fill across all rooms (0-1) — drives the water
## weight effect and the implosion check.
func total_fill_fraction() -> float:
	var total_water := 0.0
	var total_vol := 0.0
	for i in ROOM_COUNT:
		var vol := room_volume(i)
		total_water += water_levels[i] * vol
		total_vol += vol
	return total_water / total_vol

## Which water "room" a local-space point falls in, or -1 if it's outside all
## of them (e.g. inside a doorway/header). Used by crew to find their water
## level and by stations to know which room floods them.
func room_index_at(local_pos: Vector2) -> int:
	for i in ROOM_COUNT:
		var r := room_rect(i)
		if r.has_point(local_pos):
			return i
	return -1

## Water surface y (local space) for a given room, or +INF if the room index
## is invalid (treated as "no water here").
func room_water_surface_y(room: int) -> float:
	if room < 0 or room >= ROOM_COUNT:
		return INF
	var r := room_rect(room)
	return r.position.y + r.size.y * (1.0 - water_levels[room])

## Equalize water levels between connected rooms and clamp to [0, 1].
## Conserves total water volume across each pairwise transfer.
func _update_water(delta: float) -> void:
	var w: GameFeel.WaterFeel = GameFeel.water
	# Breaches leak into their rooms.
	for breach in breaches:
		water_levels[breach.room] += breach.leak_rate * delta
	for pair in WATER_CONNECTIONS:
		var i: int = pair[0]
		var j: int = pair[1]
		var diff: float = water_levels[i] - water_levels[j]
		var d_level_i := w.flow_rate * diff * delta
		water_levels[i] -= d_level_i
		water_levels[j] += d_level_i * room_volume(i) / room_volume(j)
	for i in ROOM_COUNT:
		water_levels[i] = clampf(water_levels[i], 0.0, 1.0)

## Inspect this frame's slide collisions for terrain hits hard enough to
## breach the hull. Impact speed is the pre-collision velocity into the
## surface; below the threshold (gentle docking) it is always free.
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

## Apply a terrain impact at the given speed (m/s) and global point. Spawns a
## breach (leak rate scaled by speed) when above the free-bump threshold.
## Returns true if a breach was created. Exposed for headless tests.
func register_impact(speed_mps: float, global_point: Vector2) -> bool:
	var w: GameFeel.WaterFeel = GameFeel.water
	if speed_mps < w.breach_speed_threshold:
		return false
	var severity := clampf(inverse_lerp(w.breach_speed_threshold, w.breach_speed_max,
		speed_mps), 0.0, 1.0)
	var rate := lerpf(w.leak_rate_min, w.leak_rate_max, severity)
	var local := to_local(global_point)
	spawn_breach(_nearest_room(local), rate, local)
	return true

## Open a breach leaking into `room` at `rate` (level-fraction/s). If no local
## position is given, the marker lands on the room's outer wall. Also used by
## fish bites. Returns the new breach.
func spawn_breach(room: int, rate: float, local_pos := Vector2.INF) -> Breach:
	var breach := Breach.new()
	breach.room = room
	breach.leak_rate = rate
	var r := room_rect(room)
	if local_pos == Vector2.INF:
		local_pos = Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y)
	# Clamp the marker onto the room rectangle so it always reads as "on the
	# wall of that room" even if the impact point was out on the hull shell.
	breach.position = local_pos.clamp(r.position, r.position + r.size)
	breaches.append(breach)
	add_child(breach)
	breach_spawned.emit(breach)
	return breach

## Remove a patched breach (Module D calls this when repair completes).
func remove_breach(breach: Breach) -> void:
	breaches.erase(breach)
	breach.queue_free()

## Which water room is closest to a local-space point (for impacts that land
## on the hull shell, outside every room rectangle).
func _nearest_room(local_pos: Vector2) -> int:
	var direct := room_index_at(local_pos)
	if direct >= 0:
		return direct
	var best := 0
	var best_d := INF
	for i in ROOM_COUNT:
		var r := room_rect(i)
		var d := local_pos.distance_squared_to(r.get_center())
		if d < best_d:
			best_d = d
			best = i
	return best

func _build_helm() -> void:
	var helm := HelmStation.new()
	helm.sub = self
	helm.room_index = 2  # helm/bow room
	helm.position = Vector2(HELM_X, HELM_SEAT_Y)
	add_child(helm)

## Outer-shell collider (vs terrain), shaped to match the hull silhouette (the
## old rough rectangle hung ~1.5 m below the art, causing a visible gap). Tilts
## with the cosmetic pitch so the collision matches what you see.
func _build_hull_collision() -> void:
	_hull_collision = CollisionPolygon2D.new()
	_hull_collision.polygon = PackedVector2Array([
		Vector2(-352, -168), Vector2(-90, -168), Vector2(-90, -274), Vector2(90, -274),
		Vector2(90, -168), Vector2(352, -168), Vector2(400, -120), Vector2(400, 24),
		Vector2(352, 72), Vector2(-352, 72), Vector2(-400, 24), Vector2(-400, -120),
	])
	add_child(_hull_collision)

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
