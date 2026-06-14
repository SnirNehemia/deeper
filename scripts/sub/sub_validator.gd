class_name SubValidator
extends RefCounted

## The single authority on whether a layout is legal
## (MODULAR_SUB_IMPLEMENTATION.md §5, plus the slot additions from
## ROOM_SYSTEM.md §4.1). Pure, no side effects, callable headlessly. The
## assembly UI calls this live and refuses any placement that fails; the
## loader calls it on boot (with the §5 fallback: move non-core placements
## back to inventory and re-validate, never crash or delete).
##
## validate(layout) -> {"ok": bool, "violations": Array[String]}
## Every violation is a player-readable message; no other code re-implements
## any of these rules.

## Offset of a turret room's firing face, given its mirrored flag (§5 rule 5).
## Unmirrored fires toward the bow (+x); mirrored flips toward the stern (-x).
static func _firing_face_offset(mirrored: bool) -> Vector2i:
	return Vector2i(-1, 0) if mirrored else Vector2i(1, 0)

## Offset from a pod's host cell to the exterior cell its face points at
## (§5 rule 6).
static func _pod_face_offset(face: String) -> Vector2i:
	match face:
		"top":
			return Vector2i(0, -1)
		"bottom":
			return Vector2i(0, 1)
		"left":
			return Vector2i(-1, 0)
		"right":
			return Vector2i(1, 0)
		_:
			return Vector2i.ZERO

static func validate(layout: SubLayout) -> Dictionary:
	var violations: Array[String] = []

	# Rule 1: core fixed — the tower exists exactly once and is never in
	# inventory. The helm is core too, but (2026-06-15) can be picked up and
	# relocated like any other room — it's just never allowed to be missing
	# when the dry dock closes (DryDock._close enforces that separately, since
	# "in inventory between placements" is a normal mid-edit state here). A
	# duplicate helm placement is still a violation.
	var helm_placements: Array = []
	var tower_placements: Array = []
	for p in layout.placements:
		if p.module_id == "helm":
			helm_placements.append(p)
		elif p.module_id == "tower":
			tower_placements.append(p)
	if helm_placements.size() > 1:
		violations.append("The sub can have at most one helm (found %d)." % helm_placements.size())
	if tower_placements.size() != 1:
		violations.append("The sub must have exactly one conning tower (found %d)." % tower_placements.size())
	if layout.inventory.get("tower", 0) > 0:
		violations.append("The tower can never sit in inventory — it is a fixed part of the sub.")

	# Rule 4: no overlap — no two placement footprints share a cell, and no
	# slot overlaps a placement's footprint either.
	var cell_owners: Dictionary = {}
	for p in layout.placements:
		for cell in SubLayout.placement_cells(p):
			if cell_owners.has(cell):
				violations.append("Two rooms (%s and %s) both occupy cell %s." % [
					cell_owners[cell], p.module_id, cell])
			else:
				cell_owners[cell] = p.module_id
	for slot in layout.slots:
		if cell_owners.has(slot):
			violations.append("Slot %s overlaps the %s room." % [slot, cell_owners[slot]])

	var occupied := layout.occupied_cells()

	# Rule 7: bounds sanity — the layout's bounding box fits inside
	# SubGrid.MAX_CELLS (a technical guard only; real growth limiting is
	# economic price escalation, not this box).
	if not occupied.is_empty():
		var min_pos := Vector2i(999, 999)
		var max_pos := Vector2i(-999, -999)
		for cell in occupied:
			min_pos = Vector2i(min(min_pos.x, cell.x), min(min_pos.y, cell.y))
			max_pos = Vector2i(max(max_pos.x, cell.x), max(max_pos.y, cell.y))
		var span := max_pos - min_pos + Vector2i.ONE
		if span.x > SubGrid.MAX_CELLS.x or span.y > SubGrid.MAX_CELLS.y:
			violations.append("The sub is too large (%dx%d cells, max is %dx%d)." % [
				span.x, span.y, SubGrid.MAX_CELLS.x, SubGrid.MAX_CELLS.y])

	# Rule 3: tower support — the cell directly below the tower is occupied
	# (the tower must stand on a room and gain its ladder).
	if tower_placements.size() == 1:
		var tower_cell: Vector2i = tower_placements[0].grid_pos
		var below := tower_cell + Vector2i(0, 1)
		if below not in occupied:
			violations.append("The conning tower has nothing beneath it to stand on.")

	# Rule 2: connectivity — every occupied cell (placed rooms and bought
	# slots alike) reaches the helm through the auto-connection graph
	# (adjacency stands in for doors/ladders here; the pipeline generates the
	# real connections from the same adjacency).
	if helm_placements.size() == 1 and not occupied.is_empty():
		var start: Vector2i = helm_placements[0].grid_pos
		var occupied_set: Dictionary = {}
		for cell in occupied:
			occupied_set[cell] = true
		var visited: Dictionary = {}
		var queue: Array = [start]
		visited[start] = true
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_front()
			for n in SubLayout.neighbors(cell):
				if occupied_set.has(n) and not visited.has(n):
					visited[n] = true
					queue.append(n)
		for cell in occupied:
			if not visited.has(cell):
				violations.append("Cell %s is cut off from the rest of the sub." % cell)

	# Rule 5: clear special faces — a turret room's firing face must be an
	# exterior face (not adjacent to another room) — a gun can never be
	# bricked in.
	for p in layout.placements:
		var def := ModuleCatalog.by_id(p.module_id)
		if def != null and def.has_firing_face:
			var firing_cell := p.grid_pos + _firing_face_offset(p.mirrored)
			if firing_cell in occupied:
				violations.append("The %s's gun is blocked by another room." % p.module_id)

	# Rule 8: firing-face rooms sit at the far edge of their level — a
	# turret's gun faces open water, so the room itself must be the
	# leftmost or rightmost occupied cell in its grid row (2026-06-14).
	for p in layout.placements:
		var fdef := ModuleCatalog.by_id(p.module_id)
		if fdef == null or not fdef.has_firing_face:
			continue
		var row_min_x := p.grid_pos.x
		var row_max_x := p.grid_pos.x
		for cell in occupied:
			if cell.y == p.grid_pos.y:
				row_min_x = min(row_min_x, cell.x)
				row_max_x = max(row_max_x, cell.x)
		if p.grid_pos.x != row_min_x and p.grid_pos.x != row_max_x:
			violations.append("The %s must sit at the far left or right edge of its level." % p.module_id)

	# Rule 6: pod faces — a pod attaches only to an exterior face of an
	# occupied cell; one pod per face.
	var pod_faces: Dictionary = {}
	for pod in layout.pods:
		if pod.host_cell not in occupied:
			violations.append("The %s pod is attached to an empty cell %s." % [pod.pod_id, pod.host_cell])
			continue
		var exterior_cell := pod.host_cell + _pod_face_offset(pod.face)
		if exterior_cell in occupied:
			violations.append("The %s pod's %s face is not exterior." % [pod.pod_id, pod.face])
		var key := str(pod.host_cell) + ":" + pod.face
		if pod_faces.has(key):
			violations.append("More than one pod is attached to cell %s's %s face." % [pod.host_cell, pod.face])
		else:
			pod_faces[key] = true

	return {"ok": violations.is_empty(), "violations": violations}

## Boot/load recovery path (§5): if validate fails, do not crash and do not
## delete anything — for each cell conflict, the core module (helm/tower)
## or whichever placement claimed the cell first wins; every module that
## loses its cell goes back to inventory untouched, scrap is untouched, and
## slots/pods that no longer make sense are dropped (the slot purchase and
## any pod purchase are not separately tracked once spent, so there is
## nothing to refund — this is the designed recovery path, not an error
## state; the player reassembles at the dock).
static func recover(layout: SubLayout) -> SubLayout:
	var result := validate(layout)
	if result["ok"]:
		return layout

	var recovered := SubLayout.new()
	recovered.inventory = layout.inventory.duplicate()

	var claimed: Dictionary = {}
	# Core placements (helm/tower) always keep their cells.
	for p in layout.placements:
		var def := ModuleCatalog.by_id(p.module_id)
		if def != null and def.is_core:
			for cell in SubLayout.placement_cells(p):
				claimed[cell] = true
			recovered.placements.append(p)

	# Non-core placements keep their cells on a first-come basis; losers
	# return to inventory.
	for p in layout.placements:
		var def := ModuleCatalog.by_id(p.module_id)
		if def != null and def.is_core:
			continue
		var cells := SubLayout.placement_cells(p)
		var conflict := false
		for cell in cells:
			if claimed.has(cell):
				conflict = true
				break
		if conflict:
			recovered.inventory[p.module_id] = recovered.inventory.get(p.module_id, 0) + 1
			continue
		for cell in cells:
			claimed[cell] = true
		recovered.placements.append(p)

	# Bought slots that no longer line up with the rebuilt hull are dropped.
	for slot in layout.slots:
		if not claimed.has(slot):
			recovered.slots.append(slot)
			claimed[slot] = true

	var occupied: Dictionary = claimed

	# Pods that no longer attach to an occupied, exterior face are dropped.
	var pod_faces: Dictionary = {}
	for pod in layout.pods:
		if not occupied.has(pod.host_cell):
			continue
		var exterior_cell := pod.host_cell + _pod_face_offset(pod.face)
		if occupied.has(exterior_cell):
			continue
		var key := str(pod.host_cell) + ":" + pod.face
		if pod_faces.has(key):
			continue
		pod_faces[key] = true
		recovered.pods.append(pod)

	return recovered
