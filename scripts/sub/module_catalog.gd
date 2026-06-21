class_name ModuleCatalog
extends RefCounted

## The list of buyable/placeable module types (MODULAR_SUB_IMPLEMENTATION.md
## §3.1). Core modules (helm, tower) are never bought or sold — they're listed
## here only so the generation pipeline and validator have one ModuleDef per
## id, including the core ones. Content for turret_room and floodlight_pod
## (stations, prices) arrives in M4 Modules 9-10; their entries exist now so
## the data model and starting layout are complete.

static func all() -> Array[ModuleDef]:
	return [
		_room("helm", "Helm", Vector2i(1, 1), 0, true),
		_room("tower", "Conning Tower", Vector2i(1, 1), 0, true),
		_claw_room(),
		_room("storage", "Storage Room", Vector2i(1, 1), 0, false),
		_turret_room(),
		_bullet_room(),
		_floodlight_room(),
		_floodlight_pod(),
		_telescope_room(),
	]

static func by_id(id: String) -> ModuleDef:
	for def in all():
		if def.id == id:
			return def
	return null

## MILESTONE_8.md Module 4: every purchasable room costs a flat
## GameFeel.currency.flat_room_price in one randomly-chosen currency color —
## first-pass numbers, explicitly provisional (Snir, 2026-06-21: skip the
## planned color→room mapping Q&A, balance later). The color is picked once
## per room id and cached for the process's lifetime: `all()` rebuilds a
## fresh Array[ModuleDef] on every call, so re-rolling per call would make
## the *same* room's price flicker between colors across two calls in the
## same shop session.
static var _room_price_color_cache: Dictionary = {}

static func _flat_room_cost(room_id: String) -> Dictionary:
	if not _room_price_color_cache.has(room_id):
		var colors := GameFeel.currency.room_price_colors
		_room_price_color_cache[room_id] = colors[randi() % colors.size()]
	return {_room_price_color_cache[room_id]: GameFeel.currency.flat_room_price}

static func _room(id: String, display_name: String, footprint: Vector2i,
		price: int, is_core: bool) -> ModuleDef:
	var def := ModuleDef.new()
	def.id = id
	def.display_name = display_name
	def.footprint = footprint
	def.price = price
	def.is_core = is_core
	return def

## The Claw Room (M7-3): a two-joint excavator arm. Now a purchasable alternate
## collector; the telescope_room is the base loadout's default collector.
static func _claw_room() -> ModuleDef:
	var def := ModuleDef.new()
	def.id = "claw_room"
	def.display_name = "Claw Room"
	def.description = "Two-joint excavator arm. Grab and dump salvage into the hold."
	def.footprint = Vector2i(1, 1)
	def.cost = _flat_room_cost("claw_room")
	return def

## The Base Gun Room (M4-10, ROOM_SYSTEM.md §6 "Base gun room") — the first
## hand-built purchasable room with a real mechanic: a torpedo gun on its
## firing-face wall, with its own gunner seat (Sub._build_turret_room).
static func _turret_room() -> ModuleDef:
	var def := ModuleDef.new()
	def.id = "turret_room"
	def.display_name = "Turret Room"
	def.description = "Operate a torpedo gun firing toward open water."
	def.footprint = Vector2i(1, 1)
	def.has_firing_face = true
	def.cost = _flat_room_cost("turret_room")  # base gun room (ROOM_SYSTEM.md §6)
	return def

## The Bullet Room (M4-12, ROOM_SYSTEM.md §6 "Bullet weapon room") — the
## second hand-built room, built via the add-deeper-room skill: a fast,
## low-damage gun on its firing-face wall, with its own gunner seat
## (Sub._build_bullet_room). Reuses TurretStation (seat/aim/cone) with
## Bullet projectiles instead of Torpedo.
static func _bullet_room() -> ModuleDef:
	var def := ModuleDef.new()
	def.id = "bullet_room"
	def.display_name = "Bullet Room"
	def.description = "Fires fast bullets at a high rate."
	def.footprint = Vector2i(1, 1)
	def.has_firing_face = true
	def.cost = _flat_room_cost("bullet_room")  # bullet weapon room (ROOM_SYSTEM.md §6)
	return def

## A room built to host the floodlight pod (M4-9) — the pod attaches to one of
## this room's exterior faces once both are owned. A plain room can't host a
## pod (ModuleDef.can_host_pod), so pod placement never competes with the
## pick-up/return action of an ordinary room.
static func _floodlight_room() -> ModuleDef:
	var def := ModuleDef.new()
	def.id = "floodlight_room"
	def.display_name = "Floodlight Room"
	def.footprint = Vector2i(1, 1)
	def.can_host_pod = true
	def.cost = _flat_room_cost("floodlight_room")  # bundled price covers the room + its pod (2026-06-19)
	return def

## The floodlight pod is no longer sold separately (2026-06-19): buying the
## Floodlight Room (above) grants both the room and this pod into inventory
## in one purchase (SaveData.buy_room), per DECISIONS.md round 4. This entry
## stays in the catalog (empty cost keeps it out of purchasable_pods()) so
## ModuleCatalog.by_id("floodlight_pod") and SubValidator pod-placement rules
## still resolve normally.
static func _floodlight_pod() -> ModuleDef:
	var def := ModuleDef.new()
	def.id = "floodlight_pod"
	def.display_name = "Floodlight Pod"
	def.is_pod = true
	def.footprint = Vector2i(0, 0)
	def.cost = {}
	return def

## The Telescope Room (M7-2): a straight telescoping arm mounted on the room's
## exterior wall. Aim A/D, extend S, retract W, grab Q. Auto-deposits the
## caught item into the room's two onboard cages (s2 + s4, capacity 6 each)
## when the arm retracts to home. Built by TelescopeStation (Sub._build_telescope_room).
static func _telescope_room() -> ModuleDef:
	var def := ModuleDef.new()
	def.id = "telescope_room"
	def.display_name = "Telescope Room"
	def.description = "A long straight collector arm. Aim, extend, grab, retract to auto-store."
	def.footprint = Vector2i(1, 1)
	def.cost = _flat_room_cost("telescope_room")  # starter is free via layout, this is for a 2nd
	return def

## The modules a player can buy into inventory at the dock right now: not core
## (helm/tower), not pods (pods attach in the assembly screen, M4-9), and with
## a non-empty price. Returns ModuleDefs.
static func purchasable_rooms() -> Array:
	var rooms: Array = []
	for def in all():
		if not def.is_core and not def.is_pod and not def.cost_bundle().is_empty():
			rooms.append(def)
	return rooms

## The pod modules a player can buy into inventory at the dock right now
## (M4-9: exterior pods, e.g. the floodlight pod) — pods with a non-empty
## price. Returns ModuleDefs.
static func purchasable_pods() -> Array:
	var pods: Array = []
	for def in all():
		if def.is_pod and not def.cost_bundle().is_empty():
			pods.append(def)
	return pods
