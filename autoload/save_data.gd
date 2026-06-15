extends Node

## Persisted meta-progression (autoload "SaveData").
##
## The save system (Module B + D + M4-6): the banked salvage totals, the
## submarine's bought upgrades (the loadout), and — new in M4 — the submarine
## **layout** (placed rooms, pods, owned slots, and the inventory of bought-but-
## unplaced rooms), written to a small JSON file in the user data directory and
## reloaded on launch. On load the layout is validated and, if a rules change
## ever made it illegal, recovered (non-core rooms returned to inventory) rather
## than lost (MODULAR_SUB_IMPLEMENTATION.md §5/§9). Sub builds from this layout.

const SAVE_PATH := "user://save.json"

## Salvage that's been banked (safe) by returning to the dock. The carcass
## tiers are the ROOM_SYSTEM.md §4.2 spend resources: banked_fish is the small
## carcass (s_ca) — the only one that drops today; medium/large (m_ca/l_ca)
## fill once bigger enemies exist (M5) but the wallet handles them now so room
## prices can be multi-resource.
var banked_scrap: int = 0       ## sc
var banked_fish: int = 0        ## s_ca (small carcass)
var banked_med_carcass: int = 0   ## m_ca
var banked_large_carcass: int = 0 ## l_ca

## The submarine's persistent upgrade state (engine boost / repair training;
## the gun-room slot is parked until M4-9).
var loadout: SubLoadout = SubLoadout.new()

## The submarine's persistent layout (M4). Defaults to the Minnow+; the dock
## shop/assembly (M4-7/M4-8) will mutate it and call save_data().
var layout: SubLayout = SubLayout.starting_layout()

func _ready() -> void:
	load_data()

## Read the save file, if any. Missing/corrupt files just leave everything at
## its defaults — there's nothing to lose on a fresh install. A pre-M4 save with
## no "layout" key loads as the starting layout (legacy upgrade).
func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		banked_scrap = int(data.get("banked_scrap", 0))
		banked_fish = int(data.get("banked_fish", 0))
		banked_med_carcass = int(data.get("banked_med_carcass", 0))
		banked_large_carcass = int(data.get("banked_large_carcass", 0))
		loadout.from_dict(data.get("loadout", {}))
		if data.has("layout"):
			# Validate + recover so a layout left illegal by a rules change
			# boots to core + inventory instead of crashing or vanishing.
			layout = SubValidator.recover(SubLayout.from_dict(data["layout"]))
		else:
			layout = SubLayout.starting_layout()  # pre-M4 save

func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"banked_scrap": banked_scrap,
		"banked_fish": banked_fish,
		"banked_med_carcass": banked_med_carcass,
		"banked_large_carcass": banked_large_carcass,
		"loadout": loadout.to_dict(),
		"layout": layout.to_dict(),
	}))

## Add salvage to the banked totals and persist immediately.
func bank(scrap: int, fish: int) -> void:
	if scrap <= 0 and fish <= 0:
		return
	banked_scrap += scrap
	banked_fish += fish
	save_data()

## Can the player currently afford `cost` scrap?
func can_afford(cost: int) -> bool:
	return banked_scrap >= cost

## Try to buy an upgrade from the catalog. Fails (returns false) if it's
## already owned or unaffordable. `slot` only matters for the gun room.
## Deducts the scrap, marks it owned, and saves.
func purchase(id: String, slot: SubLoadout.Slot = SubLoadout.Slot.NONE) -> bool:
	var entry := SubLoadout.catalog_entry(id)
	if entry.is_empty() or loadout.owns(id):
		return false
	var cost: int = entry["cost"]
	if not can_afford(cost):
		return false
	banked_scrap -= cost
	loadout.set_owned(id, slot)
	save_data()
	return true

## Buy a slot (an empty, buildable cell adjacent to the hull) at `pos`
## (ROOM_SYSTEM.md §4.1 — the growth purchase, the gate before a room has
## anywhere to go). The price escalates on slots already owned
## (`GameFeel.dock`, M4-2). Fails (false) if `pos` isn't a legal buyable
## position right now or there isn't enough scrap. On success: deduct scrap,
## add the slot to the layout, persist.
func buy_slot(pos: Vector2i) -> bool:
	if pos not in layout.buyable_slot_positions():
		return false
	var cost := next_slot_price(pos)
	if banked_scrap < cost:
		return false
	banked_scrap -= cost
	layout.slots.append(pos)
	layout.total_slots_bought += 1
	save_data()
	return true

## The scrap price of a slot at `pos`, given its level (rows below the
## conning tower) and how many slots have ever been bought (2026-06-14 levels
## rework, ROOM_SYSTEM.md §4.1). Uses the cumulative purchase count, not
## `layout.slots.size()`, so the price doesn't fluctuate as rooms are placed
## into or returned from owned slots (2026-06-15 fix).
func next_slot_price(pos: Vector2i) -> int:
	return GameFeel.dock.slot_price(layout.level_of(pos), layout.total_slots_bought)

## Current balance of a resource code (ROOM_SYSTEM.md §4.2).
func resource_balance(code: String) -> int:
	match code:
		"sc": return banked_scrap
		"s_ca": return banked_fish
		"m_ca": return banked_med_carcass
		"l_ca": return banked_large_carcass
	return 0

func _add_resource(code: String, amount: int) -> void:
	match code:
		"sc": banked_scrap += amount
		"s_ca": banked_fish += amount
		"m_ca": banked_med_carcass += amount
		"l_ca": banked_large_carcass += amount

## True if every resource in `cost` (code -> amount) is covered by the wallet.
func can_afford_cost(cost: Dictionary) -> bool:
	for code in cost:
		if resource_balance(code) < int(cost[code]):
			return false
	return true

## Buy a room module into inventory (ROOM_SYSTEM.md §4.1 — the contents
## purchase, separate from buying a slot). Fails (false) for a non-purchasable
## id (core/pod/unknown) or an unaffordable multi-resource cost. On success:
## spend the bundle, add one to inventory, persist.
func buy_room(id: String) -> bool:
	var def := ModuleCatalog.by_id(id)
	if def == null or def.is_core or def.is_pod:
		return false
	var cost := def.cost_bundle()
	if cost.is_empty() or not can_afford_cost(cost):
		return false
	for code in cost:
		_add_resource(code, -int(cost[code]))
	layout.inventory[id] = int(layout.inventory.get(id, 0)) + 1
	if id == "floodlight_room":
		# Bundled purchase (2026-06-19, DECISIONS.md round 4): the room's price
		# also covers its floodlight pod, so buying the room grants both.
		layout.inventory["floodlight_pod"] = int(layout.inventory.get("floodlight_pod", 0)) + 1
	save_data()
	return true

## Place an inventory room into an owned empty slot (M4-8: the second half of
## the ROOM_SYSTEM.md §4.1 room economy — a bought room from `buy_room` lands
## here). `facing` ("right"/"left"/"top"/"bottom") only matters for modules
## with a special face (a turret/bullet room's gun, the claw's arm) — it picks
## which outer wall that face points to. Leave empty ("") to auto-pick the
## first facing (in `SubLayout.FACINGS` order) that validates.
## Fails (false), with no state change, if `pos` isn't an owned empty slot,
## `id` isn't in inventory, `id` is core/pod/unknown, or placing it there
## would make the layout fail `SubValidator.validate` (e.g. a turret's firing
## face would be bricked in). On success: move the slot to a placement, take
## one off inventory, persist.
func place_room(id: String, pos: Vector2i, facing: String = "") -> bool:
	return _place_room_candidate(id, pos, facing)["violations"].is_empty() \
		and _commit_place_room(id, pos, facing)

## The validation violations that placing `id` at `pos` (with `facing`) would
## cause, without committing anything — empty means the placement is legal.
## Used by the assembly UI to explain a refused placement.
func place_room_violations(id: String, pos: Vector2i, facing: String = "") -> Array:
	return _place_room_candidate(id, pos, facing)["violations"]

## A module can be picked up off the hull (back to inventory) and placed back
## into a slot like an ordinary room if it isn't the tower or a pod. The helm
## is core but, since 2026-06-15, can be relocated — the dry dock just won't
## let the player leave with it sitting in inventory (`DryDock._close`).
static func _is_relocatable(def: ModuleDef) -> bool:
	return def != null and not def.is_pod and (not def.is_core or def.id == "helm")

## Resolve an explicit or auto-picked `facing` for placing `id` at `pos`. If
## `facing` is given, use it as-is. Otherwise, for modules whose facing
## matters (a firing-face gun or the claw), try `SubLayout.FACINGS` in order
## and return the first that validates (falling back to "right" if none do,
## so the caller's validation reports the real reason). Other modules default
## to "right" (their facing has no gameplay effect).
func _resolve_placement_facing(id: String, pos: Vector2i) -> String:
	var def := ModuleCatalog.by_id(id)
	if def == null or not (def.has_firing_face or id == "claw_room"):
		return "right"
	for facing in SubLayout.FACINGS:
		var candidate := SubLayout.from_dict(layout.to_dict())
		if pos in candidate.slots:
			candidate.slots.erase(pos)
		candidate.placements.append(SubLayout.Placement.new(id, pos, facing))
		if SubValidator.validate(candidate)["violations"].is_empty():
			return facing
	return "right"

func _place_room_candidate(id: String, pos: Vector2i, facing: String) -> Dictionary:
	if pos not in layout.slots:
		return {"violations": ["There's no empty slot at %s." % pos]}
	if int(layout.inventory.get(id, 0)) <= 0:
		return {"violations": ["The %s isn't in inventory." % id]}
	var def := ModuleCatalog.by_id(id)
	if not _is_relocatable(def):
		return {"violations": ["The %s can't be placed as a room." % id]}
	if facing == "":
		facing = _resolve_placement_facing(id, pos)
	var candidate := SubLayout.from_dict(layout.to_dict())
	candidate.slots.erase(pos)
	candidate.placements.append(SubLayout.Placement.new(id, pos, facing))
	return SubValidator.validate(candidate)

func _commit_place_room(id: String, pos: Vector2i, facing: String) -> bool:
	if facing == "":
		facing = _resolve_placement_facing(id, pos)
	layout.slots.erase(pos)
	layout.placements.append(SubLayout.Placement.new(id, pos, facing))
	layout.inventory[id] = int(layout.inventory.get(id, 0)) - 1
	if layout.inventory[id] <= 0:
		layout.inventory.erase(id)
	if id == "floodlight_room":
		# The room and its lamp are one inseparable unit (2026-06-19 rework) —
		# auto-attach the bundled pod to the first valid exterior face so the
		# player never sees a separate attach step.
		for face in ["right", "left", "top", "bottom"]:
			if _place_pod_candidate("floodlight_pod", pos, face)["violations"].is_empty():
				_commit_place_pod("floodlight_pod", pos, face)
				break
	save_data()
	return true

## Pick a placed room back up off the hull and return it to inventory,
## freeing its cell back into an owned empty slot (the reverse of
## `place_room` — 2026-06-14 Assembly nav rework). Fails (false), with no
## state change, if there's no placement at `pos` or it's the tower/a pod
## (see `_is_relocatable` — the helm CAN be returned, but the dry dock won't
## let the player leave without it placed somewhere). On success: drop the
## placement, add the cell to `layout.slots`, add one to inventory, persist.
func return_room_to_inventory(pos: Vector2i) -> bool:
	for i in layout.placements.size():
		var p: SubLayout.Placement = layout.placements[i]
		if p.grid_pos != pos:
			continue
		var def := ModuleCatalog.by_id(p.module_id)
		if not _is_relocatable(def):
			return false
		layout.placements.remove_at(i)
		layout.slots.append(pos)
		layout.inventory[p.module_id] = int(layout.inventory.get(p.module_id, 0)) + 1
		if p.module_id == "floodlight_room":
			# The lamp comes back with its room (2026-06-19 rework).
			for j in layout.pods.size():
				var pod: SubLayout.PodPlacement = layout.pods[j]
				if pod.host_cell == pos:
					layout.pods.remove_at(j)
					layout.inventory[pod.pod_id] = int(layout.inventory.get(pod.pod_id, 0)) + 1
					break
		save_data()
		return true
	return false

## Buy a pod module into inventory (M4-9 — the exterior-pod analogue of
## `buy_room`). Fails (false) for a non-pod id or an unaffordable cost. On
## success: spend the bundle, add one to inventory, persist.
func buy_pod(id: String) -> bool:
	var def := ModuleCatalog.by_id(id)
	if def == null or not def.is_pod:
		return false
	var cost := def.cost_bundle()
	if cost.is_empty() or not can_afford_cost(cost):
		return false
	for code in cost:
		_add_resource(code, -int(cost[code]))
	layout.inventory[id] = int(layout.inventory.get(id, 0)) + 1
	save_data()
	return true

## Attach an inventory pod to an exterior face of an occupied cell (M4-9, the
## second half of the pod economy — a bought pod from `buy_pod` lands here).
## Fails (false), with no state change, if `id` isn't a pod in inventory, or
## attaching it at `host_cell`/`face` would make the layout fail
## `SubValidator.validate` (not exterior, already has a pod, etc). On success:
## add the pod placement, take one off inventory, persist.
func place_pod(id: String, host_cell: Vector2i, face: String) -> bool:
	return _place_pod_candidate(id, host_cell, face)["violations"].is_empty() \
		and _commit_place_pod(id, host_cell, face)

## The validation violations that attaching `id` at `host_cell`/`face` would
## cause, without committing anything — empty means the placement is legal.
func place_pod_violations(id: String, host_cell: Vector2i, face: String) -> Array:
	return _place_pod_candidate(id, host_cell, face)["violations"]

func _place_pod_candidate(id: String, host_cell: Vector2i, face: String) -> Dictionary:
	if int(layout.inventory.get(id, 0)) <= 0:
		return {"violations": ["The %s isn't in inventory." % id]}
	var def := ModuleCatalog.by_id(id)
	if def == null or not def.is_pod:
		return {"violations": ["The %s can't be attached as a pod." % id]}
	var host_def: ModuleDef = null
	for p in layout.placements:
		if p.grid_pos == host_cell:
			host_def = ModuleCatalog.by_id(p.module_id)
			break
	if host_def == null or not host_def.can_host_pod:
		return {"violations": ["The %s needs to be attached to a room built to host it." % id]}
	var candidate := SubLayout.from_dict(layout.to_dict())
	candidate.pods.append(SubLayout.PodPlacement.new(id, host_cell, face))
	return SubValidator.validate(candidate)

func _commit_place_pod(id: String, host_cell: Vector2i, face: String) -> bool:
	layout.pods.append(SubLayout.PodPlacement.new(id, host_cell, face))
	layout.inventory[id] = int(layout.inventory.get(id, 0)) - 1
	if layout.inventory[id] <= 0:
		layout.inventory.erase(id)
	save_data()
	return true

## Detach the pod at `host_cell`/`face` and return it to inventory (the
## reverse of `place_pod`). Fails (false), with no state change, if there's no
## pod there. On success: drop the pod placement, add one to inventory,
## persist.
func return_pod_to_inventory(host_cell: Vector2i, face: String) -> bool:
	for i in layout.pods.size():
		var pod: SubLayout.PodPlacement = layout.pods[i]
		if pod.host_cell != host_cell or pod.face != face:
			continue
		layout.pods.remove_at(i)
		layout.inventory[pod.pod_id] = int(layout.inventory.get(pod.pod_id, 0)) + 1
		save_data()
		return true
	return false

## Wipe the in-memory and on-disk save (used by tests).
func reset_for_test() -> void:
	banked_scrap = 0
	banked_fish = 0
	banked_med_carcass = 0
	banked_large_carcass = 0
	loadout = SubLoadout.new()
	layout = SubLayout.starting_layout()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

## Cycle a placed room's `facing` to the next direction in `SubLayout.FACINGS`
## that validates (2026-06-19 "any outer face" rework, replaces the old
## binary mirrored flip) -- e.g. a turret room firing bow-ward turns to fire
## stern-ward, then up, then down, then back to bow-ward. A `floodlight_room`
## instead cycles its attached pod's face (the lamp, not the room, has a
## "facing"). Fails (false), with no state change, if there's no placement at
## `pos`, or no other facing/face validates.
## Whether moving the floodlight pod at `pos` from `current_face` to `face`
## would validate, checked against a candidate layout (no mutation).
func _floodlight_pod_face_ok(pos: Vector2i, current_face: String, face: String) -> bool:
	var candidate := SubLayout.from_dict(layout.to_dict())
	for i in range(candidate.pods.size() - 1, -1, -1):
		var pod: SubLayout.PodPlacement = candidate.pods[i]
		if pod.pod_id == "floodlight_pod" and pod.host_cell == pos and pod.face == current_face:
			candidate.pods.remove_at(i)
			break
	candidate.pods.append(SubLayout.PodPlacement.new("floodlight_pod", pos, face))
	return SubValidator.validate(candidate)["violations"].is_empty()

## The floodlight pod's current exterior face at `pos`, or "" if there's none.
func _floodlight_pod_face(pos: Vector2i) -> String:
	for pod in layout.pods:
		if pod.pod_id == "floodlight_pod" and pod.host_cell == pos:
			return pod.face
	return ""

## All facings/faces (other than the placement's current one) that the
## placement at `pos` could legally rotate to, in `SubLayout.FACINGS` order.
## Empty means there's no legal alternative (or no rotatable placement here).
## Used by the Assembly UI to populate the "Rotate" submenu (2026-06-19).
func rotate_options(pos: Vector2i) -> Array:
	for p in layout.placements:
		if p.grid_pos != pos:
			continue
		if p.module_id == "floodlight_room":
			var current_face := _floodlight_pod_face(pos)
			var options: Array = []
			for face in SubLayout.FACINGS:
				if face != current_face and _floodlight_pod_face_ok(pos, current_face, face):
					options.append(face)
			return options
		var options: Array = []
		for facing in SubLayout.FACINGS:
			if facing == p.facing:
				continue
			var candidate := SubLayout.from_dict(layout.to_dict())
			for cp in candidate.placements:
				if cp.grid_pos == p.grid_pos:
					cp.facing = facing
			if SubValidator.validate(candidate)["violations"].is_empty():
				options.append(facing)
		return options
	return []

## Commits the placement (or floodlight pod) at `pos` to face `facing`
## directly, if legal. Used by the Assembly UI's "Rotate" submenu after the
## player picks an option from `rotate_options` (2026-06-19).
func set_facing(pos: Vector2i, facing: String) -> bool:
	for p in layout.placements:
		if p.grid_pos != pos:
			continue
		if p.module_id == "floodlight_room":
			var current_face := _floodlight_pod_face(pos)
			if not _floodlight_pod_face_ok(pos, current_face, facing):
				return false
			for pod in layout.pods:
				if pod.pod_id == "floodlight_pod" and pod.host_cell == pos:
					pod.face = facing
					save_data()
					return true
			return false
		var candidate := SubLayout.from_dict(layout.to_dict())
		for cp in candidate.placements:
			if cp.grid_pos == p.grid_pos:
				cp.facing = facing
		if SubValidator.validate(candidate)["violations"].is_empty():
			p.facing = facing
			save_data()
			return true
		return false
	return false

## The validation violations that rotating the placement at `pos` would cause,
## without committing anything -- empty means at least one other facing/face
## is legal. Used by the assembly UI to decide whether to show a "Rotate"
## option.
func rotate_room_violations(pos: Vector2i) -> Array:
	if rotate_options(pos).is_empty():
		return ["No other facing is available."]
	return []
