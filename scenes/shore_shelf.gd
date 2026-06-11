class_name ShoreShelf
extends Node2D

## The Milestone 1 test map (shrunk in Milestone 3, playtest #1, for faster
## playtesting): ~160 m wide x 130 m deep. A shore + dock on the left, a short
## shallows plateau, a shelf-edge cliff close to shore dropping into a basin
## with rock pillars and a cave mouth. Sky above the waterline (y = 0), water
## darkening with depth below it. Static terrain on the TERRAIN layer; the
## sub's hull collides with it (bumping is harmless this milestone).

const M := 48.0  ## pixels per meter

const WIDTH_M := 160.0
const DEPTH_M := 130.0
const FLOOR_BASIN_M := 110.0

func _ready() -> void:
	_build_sky_and_water()
	_build_terrain()
	_build_dock()
	_build_cave_marker()

func _v(mx: float, my: float) -> Vector2:
	return Vector2(mx * M, my * M)

func _build_sky_and_water() -> void:
	# Sky strip above the waterline.
	var sky := ColorRect.new()
	sky.color = PlaceholderArt.SKY_COLOR
	sky.position = _v(-40.0, -40.0)
	sky.size = _v(WIDTH_M + 80.0, 40.0)
	sky.z_index = -100
	add_child(sky)

	# Water column, darkening in a few bands with depth.
	var bands := 6
	for i in bands:
		var t0 := float(i) / bands
		var t1 := float(i + 1) / bands
		var band := ColorRect.new()
		band.color = PlaceholderArt.WATER_SURFACE.lerp(PlaceholderArt.DEEP_WATER, t0)
		band.position = _v(-40.0, t0 * DEPTH_M)
		band.size = _v(WIDTH_M + 80.0, (t1 - t0) * DEPTH_M)
		band.z_index = -90
		add_child(band)

func _build_terrain() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Layers.TERRAIN
	body.collision_mask = 0
	add_child(body)

	# Sea-floor + ground silhouette (left shore -> shallows -> steep shelf cliff
	# -> basin). The cliff face has a real cave carved into it: the boundary juts
	# left into the rock to form a hollow the sub can drive into.
	var profile := [
		_v(0.0, -6.0),    # shore top (above water)
		_v(8.0, -2.0),    # ramp toward the water
		_v(15.0, 4.0),
		_v(20.0, 20.0),   # shallows plateau begins (20 m deep)
		_v(60.0, 20.0),   # shallows plateau
		_v(64.0, 26.0),   # shelf edge
		_v(66.0, 54.0),   # cliff face down to the cave mouth (top)
		_v(40.0, 56.0),   # cave ceiling (into the rock)
		_v(40.0, 78.0),   # cave back wall
		_v(66.0, 80.0),   # cave floor (back to the cliff face)
		_v(68.0, FLOOR_BASIN_M),    # cliff continues to the basin floor
		_v(WIDTH_M, FLOOR_BASIN_M), # basin floor
		_v(WIDTH_M, DEPTH_M),       # down the right edge
		_v(0.0, DEPTH_M),           # along the bottom
	]
	_add_terrain_polygon(body, PackedVector2Array(profile), PlaceholderArt.TERRAIN_ROCK, -80)

	# Sand cap along the shallows + ramp.
	var sand := PackedVector2Array([
		_v(8.0, -2.0), _v(15.0, 4.0), _v(20.0, 20.0),
		_v(60.0, 20.0), _v(64.0, 26.0),
		_v(64.0, 29.0), _v(60.0, 23.0), _v(20.0, 23.0), _v(15.0, 7.0), _v(8.0, 1.0),
	])
	_add_visual_polygon(sand, PlaceholderArt.TERRAIN_SAND, -79)

	# Deep rock over the basin floor.
	var deep := PackedVector2Array([
		_v(68.0, FLOOR_BASIN_M), _v(WIDTH_M, FLOOR_BASIN_M),
		_v(WIDTH_M, DEPTH_M), _v(68.0, DEPTH_M),
	])
	_add_visual_polygon(deep, PlaceholderArt.TERRAIN_DEEP_ROCK, -79)

	# Rock pillars rising from the basin floor.
	_add_pillar(body, 93.0, 10.0, 55.0)
	_add_pillar(body, 120.0, 12.0, 38.0)
	_add_pillar(body, 141.0, 9.0, 62.0)

	# Dark fill inside the carved cave so it reads as a recess (nothing in it yet).
	var cave := PackedVector2Array([
		_v(68.0, 52.0), _v(38.0, 54.0), _v(38.0, 80.0), _v(68.0, 82.0),
	])
	_add_visual_polygon(cave, PlaceholderArt.CAVE_COLOR, -85)

func _add_pillar(body: StaticBody2D, center_x_m: float, width_m: float, top_m: float) -> void:
	var pts := PackedVector2Array([
		_v(center_x_m - width_m * 0.5, top_m),
		_v(center_x_m + width_m * 0.5, top_m),
		_v(center_x_m + width_m * 0.5, FLOOR_BASIN_M),
		_v(center_x_m - width_m * 0.5, FLOOR_BASIN_M),
	])
	_add_terrain_polygon(body, pts, PlaceholderArt.TERRAIN_ROCK, -78)

func _build_dock() -> void:
	# A simple surface dock near the shore (visual only).
	var dock := ColorRect.new()
	dock.color = PlaceholderArt.DOCK_COLOR
	dock.position = _v(4.0, -1.0)
	dock.size = _v(10.0, 1.5)
	dock.z_index = -70
	add_child(dock)
	for i in 3:
		var post := ColorRect.new()
		post.color = PlaceholderArt.DOCK_COLOR
		post.position = _v(5.0 + i * 4.0, 0.5)
		post.size = _v(0.6, 4.0)
		post.z_index = -71
		add_child(post)

## The milestone's victory beat: a warm glowing lamp deep inside the cave.
## No pickup logic — arriving is the reward.
func _build_cave_marker() -> void:
	var marker := CaveMarker.new()
	marker.position = _v(53.0, 68.0)  # by the cave's back wall
	marker.z_index = -75               # over the cave fill, under the sub
	add_child(marker)

## A pulsing placeholder lamp/star (visual only).
class CaveMarker extends Node2D:
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.75 + 0.25 * sin(_t * 2.5)
		var warm := Color(1.0, 0.85, 0.4)
		# Soft glow halo.
		for i in 4:
			draw_circle(Vector2.ZERO, (60.0 - i * 12.0) * pulse,
				Color(warm, 0.05 + i * 0.04))
		# Lamp core + little star points.
		draw_circle(Vector2.ZERO, 9.0, warm)
		draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.97, 0.85))
		for i in 4:
			var dir := Vector2.from_angle(i * TAU / 4.0 + _t * 0.5)
			draw_line(dir * 12.0, dir * (22.0 * pulse), Color(warm, 0.8), 2.0)

## Add a polygon that both collides (TERRAIN) and is drawn.
func _add_terrain_polygon(body: StaticBody2D, pts: PackedVector2Array, color: Color, z: int) -> void:
	var col := CollisionPolygon2D.new()
	col.polygon = pts
	body.add_child(col)
	_add_visual_polygon(pts, color, z)

func _add_visual_polygon(pts: PackedVector2Array, color: Color, z: int) -> void:
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = color
	poly.z_index = z
	add_child(poly)
