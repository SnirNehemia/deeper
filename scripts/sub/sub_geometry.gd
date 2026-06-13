class_name SubGeometry
extends RefCounted

## The generation pipeline's pure-data core (MODULAR_SUB_IMPLEMENTATION.md §4
## stages 1-2; ROOM_SYSTEM.md §2-3). Takes a SubLayout and computes the
## sub-local geometry every other stage and the live Sub node consume:
## one rectangle per placed room, the auto-doorways between horizontally
## adjacent rooms, and the parity-placed ladders between vertically adjacent
## rooms. No scene nodes, no rendering, no physics — callable headlessly.
##
## Coordinate convention (matches the old hand-built Sub): sub-local space,
## centered on the occupied bounding box; +x toward the bow (right), +y down;
## a room's walkable FLOOR is the bottom edge of its rect, its ceiling the top.
## The section authoring layer (s1-s5) is baked to local x-offsets HERE — it
## never reaches the live Sub, the water model, or validate() (ROOM_SYSTEM.md
## §8 invariant).

## Locked world scale (1 m = 48 px), hardcoded like the M3 Sub to keep these
## usable in const initializers (the GameFeel autoload isn't const-evaluable).
const PPM := 48.0
const CELL_W := SubGrid.CELL_W_PX       # 180
const CELL_H := SubGrid.CELL_H_PX       # 144

## Interior wall/floor slab thickness (carried over from the M3 hand-built sub).
const WALL_T := 16.0
## Doorway opening height above the floor (2 m), as in the M3 sub.
const DOOR_H := 2.0 * PPM  # 96
## A doorway's low floor lip the crew hop over (M3 playtest #2).
const DOOR_STEP_H := 0.3 * PPM  # ~14
## Width of a ladder floor-opening (matches the M3 conning/lower-deck holes).
const HOLE_W := 1.0 * PPM  # 48
## One of the five authoring sections, in px (3.75 m / 5 = 0.75 m).
const SECTION_W := CELL_W / 5.0  # 36

## One generated room: its placement, its sub-local interior rect (floor at the
## bottom edge), and the water-cell index the live Sub indexes it by.
class Room:
	var module_id: String
	var cell: Vector2i
	var rect: Rect2
	var water_index: int
	var mirrored: bool

## An auto-doorway between two horizontally adjacent rooms (a shared vertical
## wall). `wall_x` is the sub-local x of the shared wall; the opening is DOOR_H
## tall sitting on the floor at `floor_y`.
class Door:
	var a_cell: Vector2i
	var b_cell: Vector2i
	var a_index: int
	var b_index: int
	var wall_x: float
	var floor_y: float

## An auto-ladder between two vertically stacked rooms (a shared horizontal
## floor). `x` is the sub-local x of the shaft (baked from the floor's parity
## section, s1 or s5); the shaft runs from `top_y` (upper room's floor opening)
## down to `bottom_y` (lower room's floor).
class Ladder:
	var upper_cell: Vector2i
	var lower_cell: Vector2i
	var upper_index: int
	var lower_index: int
	var x: float
	var top_y: float
	var bottom_y: float
	var section: int  # 1 (s1) or 5 (s5)

var rooms: Array[Room] = []
var doors: Array[Door] = []
var ladders: Array[Ladder] = []

## Grid bounding box of the occupied cells (set during build), so consumers can
## derive hull extents and the center offset without recomputing it.
var grid_min: Vector2i = Vector2i.ZERO
var grid_max: Vector2i = Vector2i.ZERO

## cell -> water_index, for fast lookups by the connection builder and the Sub.
var _index_by_cell: Dictionary = {}

## Which ladder section a floor takes, by its floor number counted from the top
## (ROOM_SYSTEM.md §3): odd floors -> s1, even floors -> s5. Counting from the
## topmost occupied row (the tower, in a valid sub) downward, floor 1 = top.
static func ladder_section(floor_number: int) -> int:
	return 1 if (floor_number % 2) == 1 else 5

## Sub-local x of a section's center within a cell whose left edge is at
## `cell_left` (section 1..5, each SECTION_W wide).
static func section_center_x(cell_left: float, section: int) -> float:
	return cell_left + (section - 0.5) * SECTION_W

## A ladder's shaft x within its parity section, positioned toward the section's
## INNER edge (away from the side wall) so a climbing crew clears any doorway
## frame on that wall. The reserved ladder sections (s1/s5) sit against the side
## walls, but a room can also have a doorway on the same wall; the section is
## only ~0.75 m and the crew nearly that wide, so a wall-hugging ladder would
## trap the crew on the door header (the M3 hand-built sub hand-placed ladders
## clear of doorways for the same reason). This keeps the ladder inside s1/s5
## but offset enough for the crew to pass.
const LADDER_WALL_CLEARANCE := 30.0  # px from the side wall (within a 36px section)
static func ladder_shaft_x(cell_left: float, cell_right: float, section: int) -> float:
	if section == 1:
		return cell_left + LADDER_WALL_CLEARANCE
	return cell_right - LADDER_WALL_CLEARANCE

## Build the geometry for a layout. Pure: reads only the layout (and the
## catalog, for footprints). Slots are NOT rooms — they have no interior to
## generate yet (an empty slot is open hull space until a room is placed into
## it), so only `placements` become rooms here.
static func build(layout: SubLayout) -> SubGeometry:
	var geo := SubGeometry.new()
	geo._build(layout)
	return geo

func _build(layout: SubLayout) -> void:
	if layout.placements.is_empty():
		return

	# Occupied-cell bounding box, over placements AND slots — the hull (and so
	# the centering origin) includes bought-but-empty slots, which read as hull.
	var occupied := layout.occupied_cells()
	grid_min = Vector2i(999, 999)
	grid_max = Vector2i(-999, -999)
	for cell in occupied:
		grid_min = Vector2i(min(grid_min.x, cell.x), min(grid_min.y, cell.y))
		grid_max = Vector2i(max(grid_max.x, cell.x), max(grid_max.y, cell.y))

	# One room per placement, indexed in placement order (the water-cell index
	# the live Sub uses).
	for i in layout.placements.size():
		var p := layout.placements[i]
		var room := Room.new()
		room.module_id = p.module_id
		room.cell = p.grid_pos
		room.mirrored = p.mirrored
		room.water_index = i
		room.rect = cell_rect(p.grid_pos)
		rooms.append(room)
		_index_by_cell[p.grid_pos] = i

	_build_doors()
	_build_ladders()

## Sub-local rect of a grid cell, centered on the occupied bounding box. The
## rect is the room's open interior; its bottom edge is the walkable floor.
func cell_rect(cell: Vector2i) -> Rect2:
	var span := grid_max - grid_min + Vector2i.ONE
	var total_w := span.x * CELL_W
	var total_h := span.y * CELL_H
	var left := (cell.x - grid_min.x) * CELL_W - total_w * 0.5 + _offset.x
	var top := (cell.y - grid_min.y) * CELL_H - total_h * 0.5 + _offset.y
	return Rect2(left, top, CELL_W, CELL_H)

## Floor number of a grid row, counted from the topmost occupied row (= floor
## 1) downward (ROOM_SYSTEM.md §3, "counted from the tower downward" — the
## tower is the top row in a valid sub).
func floor_number(cell: Vector2i) -> int:
	return cell.y - grid_min.y + 1

## A doorway for every pair of horizontally adjacent rooms (one shared vertical
## wall segment -> one centered opening, §4 stage 2).
func _build_doors() -> void:
	for room in rooms:
		var right_cell := room.cell + Vector2i(1, 0)
		if not _index_by_cell.has(right_cell):
			continue
		var door := Door.new()
		door.a_cell = room.cell
		door.b_cell = right_cell
		door.a_index = room.water_index
		door.b_index = _index_by_cell[right_cell]
		door.wall_x = room.rect.position.x + room.rect.size.x  # shared wall
		door.floor_y = room.rect.position.y + room.rect.size.y  # floor (bottom)
		doors.append(door)

## A ladder for every pair of vertically stacked rooms (one shared horizontal
## floor -> one floor opening + ladder, §4 stage 2). The shaft's side is the
## upper room's floor parity (ROOM_SYSTEM.md §3).
func _build_ladders() -> void:
	for room in rooms:
		var below_cell := room.cell + Vector2i(0, 1)
		if not _index_by_cell.has(below_cell):
			continue
		var ladder := Ladder.new()
		ladder.upper_cell = room.cell
		ladder.lower_cell = below_cell
		ladder.upper_index = room.water_index
		ladder.lower_index = _index_by_cell[below_cell]
		ladder.section = ladder_section(floor_number(room.cell))
		ladder.x = ladder_shaft_x(room.rect.position.x,
			room.rect.position.x + room.rect.size.x, ladder.section)
		# Shaft spans from the upper room's floor (the opening) down through the
		# lower room to its floor.
		var lower_rect := cell_rect(below_cell)
		ladder.top_y = room.rect.position.y + room.rect.size.y - HOLE_W  # small grab overlap above the opening
		ladder.bottom_y = lower_rect.position.y + lower_rect.size.y
		ladders.append(ladder)

## Shift all compiled geometry by `offset` (sub-local px). The compiler centers
## on the occupied bounding box; the live Sub calls this to re-anchor so the
## helm row's floor sits at y=0 (the "floor top = y=0" convention the crew,
## seats, claw, and storage all assume). Pure translation — leaves grid coords
## and section baking untouched.
func translate(offset: Vector2) -> void:
	for room in rooms:
		room.rect.position += offset
	for door in doors:
		door.wall_x += offset.x
		door.floor_y += offset.y
	for ladder in ladders:
		ladder.x += offset.x
		ladder.top_y += offset.y
		ladder.bottom_y += offset.y
	_offset += offset

## Accumulated translation applied via translate() (so cell_rect stays
## consistent with the already-translated room rects).
var _offset: Vector2 = Vector2.ZERO

## Water index of a placed room at a cell, or -1 if no room sits there.
func index_at(cell: Vector2i) -> int:
	return _index_by_cell.get(cell, -1)

## The water-cell connections (door + ladder pairs) the live Sub's flow model
## consumes: each is {a, b, kind} with kind "door" or "ladder". The Sub turns
## these into sill fractions; this just reports the topology.
func connections() -> Array:
	var conns: Array = []
	for door in doors:
		conns.append({"a": door.a_index, "b": door.b_index, "kind": "door"})
	for ladder in ladders:
		conns.append({"a": ladder.upper_index, "b": ladder.lower_index, "kind": "ladder"})
	return conns
