class_name SubLayout
extends RefCounted

## The persisted shape of the submarine (MODULAR_SUB_IMPLEMENTATION.md §3.2):
## placed room modules, exterior pods, and the inventory of owned-but-
## unplaced modules. Plain data + serialization only — generation lives in
## the pipeline (M4 Module 3+), legality lives in validate() (M4 Module 2).

## One placed room module. `grid_pos` is its top-left cell; `mirrored` flips
## a module with a special face (e.g. a turret's firing_face) horizontally.
class Placement:
	var module_id: String = ""
	var grid_pos: Vector2i = Vector2i.ZERO
	var mirrored: bool = false

	func _init(p_module_id: String = "", p_grid_pos: Vector2i = Vector2i.ZERO,
			p_mirrored: bool = false) -> void:
		module_id = p_module_id
		grid_pos = p_grid_pos
		mirrored = p_mirrored

	func to_dict() -> Dictionary:
		return {
			"module_id": module_id,
			"grid_pos": [grid_pos.x, grid_pos.y],
			"mirrored": mirrored,
		}

	static func from_dict(data: Dictionary) -> Placement:
		var pos: Array = data.get("grid_pos", [0, 0])
		return Placement.new(
			str(data.get("module_id", "")),
			Vector2i(int(pos[0]), int(pos[1])),
			bool(data.get("mirrored", false)))

## One exterior pod, clipped to a face of an occupied cell. `face` is one of
## "top", "bottom", "left", "right".
class PodPlacement:
	var pod_id: String = ""
	var host_cell: Vector2i = Vector2i.ZERO
	var face: String = ""

	func _init(p_pod_id: String = "", p_host_cell: Vector2i = Vector2i.ZERO,
			p_face: String = "") -> void:
		pod_id = p_pod_id
		host_cell = p_host_cell
		face = p_face

	func to_dict() -> Dictionary:
		return {
			"pod_id": pod_id,
			"host_cell": [host_cell.x, host_cell.y],
			"face": face,
		}

	static func from_dict(data: Dictionary) -> PodPlacement:
		var cell: Array = data.get("host_cell", [0, 0])
		return PodPlacement.new(
			str(data.get("pod_id", "")),
			Vector2i(int(cell[0]), int(cell[1])),
			str(data.get("face", "")))

var placements: Array[Placement] = []
var pods: Array[PodPlacement] = []

## Owned-but-unplaced module ids -> count.
var inventory: Dictionary = {}

## Owned empty room-shells (ROOM_SYSTEM.md §4.1, "Option B"): a slot is a
## real, generated, walled room with no station inside, bought adjacent to
## the existing hull. Bought separately from rooms; a room from `inventory`
## is later placed into an empty slot. Cells, not modules — no ModuleDef.
var slots: Array[Vector2i] = []

func to_dict() -> Dictionary:
	var placement_dicts: Array = []
	for p in placements:
		placement_dicts.append(p.to_dict())
	var pod_dicts: Array = []
	for pod in pods:
		pod_dicts.append(pod.to_dict())
	var slot_dicts: Array = []
	for slot in slots:
		slot_dicts.append([slot.x, slot.y])
	return {
		"placements": placement_dicts,
		"pods": pod_dicts,
		"inventory": inventory.duplicate(),
		"slots": slot_dicts,
	}

static func from_dict(data: Dictionary) -> SubLayout:
	var layout := SubLayout.new()
	for p in data.get("placements", []):
		layout.placements.append(Placement.from_dict(p))
	for pod in data.get("pods", []):
		layout.pods.append(PodPlacement.from_dict(pod))
	for id in data.get("inventory", {}):
		layout.inventory[id] = int(data["inventory"][id])
	for slot in data.get("slots", []):
		layout.slots.append(Vector2i(int(slot[0]), int(slot[1])))
	return layout

## All grid cells occupied by a placement, given its module's footprint.
static func placement_cells(p: Placement) -> Array:
	var def := ModuleCatalog.by_id(p.module_id)
	var cells: Array = []
	if def == null:
		return cells
	for dx in def.footprint.x:
		for dy in def.footprint.y:
			cells.append(p.grid_pos + Vector2i(dx, dy))
	return cells

## "The Minnow+" (MODULAR_SUB_IMPLEMENTATION.md §2.1, resized to the uniform
## 1x1 cell per ROOM_SYSTEM.md §1): the M3 sub re-expressed on the grid. Helm
## at the bow (right) end of the main row, tower above the middle room, claw
## room below the middle, storage below the engine — same adjacencies as
## before, each room now a single (3.75m x 3m) cell.
##
##          [Tower 1x1]            y = -1
## [Engine 1x1][Room 1x1][Helm 1x1]  y =  0   (bow -> right)
## [Storage 1x1][Claw 1x1]           y = +1
static func starting_layout() -> SubLayout:
	var layout := SubLayout.new()
	layout.placements = [
		Placement.new("engine", Vector2i(0, 0)),
		Placement.new("room", Vector2i(1, 0)),
		Placement.new("helm", Vector2i(2, 0)),
		Placement.new("tower", Vector2i(1, -1)),
		Placement.new("storage", Vector2i(0, 1)),
		Placement.new("claw_room", Vector2i(1, 1)),
	]
	return layout

## All cells that are part of the built hull: every placed module's
## footprint cells plus every bought-but-empty slot (ROOM_SYSTEM.md §4.1 —
## a slot is a real generated room shell the instant it's bought, so it
## counts as hull for adjacency purposes just like a placed room).
func occupied_cells() -> Array:
	var cells: Array = []
	for p in placements:
		for cell in placement_cells(p):
			if cell not in cells:
				cells.append(cell)
	for slot in slots:
		if slot not in cells:
			cells.append(slot)
	return cells

## The four grid-adjacent neighbors of a cell (no diagonals — only shared
## walls count as adjacency for slot-buying and connections).
static func neighbors(cell: Vector2i) -> Array:
	return [
		cell + Vector2i(1, 0), cell + Vector2i(-1, 0),
		cell + Vector2i(0, 1), cell + Vector2i(0, -1),
	]

## The grid row occupied by the conning tower, or null if there is no tower
## placement (defensive only — every valid layout has exactly one).
func _tower_row() -> Variant:
	for p in placements:
		if p.module_id == "tower":
			return p.grid_pos.y
	return null

## The "level" of a grid row for the slot economy (2026-06-14 levels rework,
## ROOM_SYSTEM.md §4.1): the tower's row is level 0 and stays the tower's
## alone forever; the row directly beneath it is level 1, the next is level
## 2, and so on. Levels at or above the tower's row (<= 0) are never
## buyable. If there's no tower (shouldn't happen), every row is level 1.
func level_of(pos: Vector2i) -> int:
	var tower_row: Variant = _tower_row()
	if tower_row == null:
		return 1
	return pos.y - int(tower_row)

## Empty cells the player could buy as a new slot right now (ROOM_SYSTEM.md
## §4.1): not already occupied (by a placement or another slot), adjacent to
## at least one occupied cell (the slot must touch the existing hull), within
## the bounds guard (SubGrid.MAX_CELLS) once added, and on a level below the
## conning tower's (the tower's row never gets neighbors offered for sale).
func buyable_slot_positions() -> Array:
	var occupied := occupied_cells()
	var min_pos := Vector2i(999, 999)
	var max_pos := Vector2i(-999, -999)
	for cell in occupied:
		min_pos = Vector2i(min(min_pos.x, cell.x), min(min_pos.y, cell.y))
		max_pos = Vector2i(max(max_pos.x, cell.x), max(max_pos.y, cell.y))

	var candidates: Array = []
	for cell in occupied:
		for n in neighbors(cell):
			if n in occupied or n in candidates:
				continue
			if level_of(n) < 1:
				continue
			var span_min := Vector2i(min(min_pos.x, n.x), min(min_pos.y, n.y))
			var span_max := Vector2i(max(max_pos.x, n.x), max(max_pos.y, n.y))
			var span := span_max - span_min + Vector2i.ONE
			if span.x <= SubGrid.MAX_CELLS.x and span.y <= SubGrid.MAX_CELLS.y:
				candidates.append(n)
	return candidates
