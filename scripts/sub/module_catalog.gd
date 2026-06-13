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
		_room("room", "Room", Vector2i(1, 1), 0, false),
		_room("engine", "Engine Room", Vector2i(1, 1), 0, false),
		_room("claw_room", "Claw Room", Vector2i(1, 1), 0, false),
		_room("storage", "Storage Room", Vector2i(1, 1), 0, false),
		_turret_room(),
		_floodlight_pod(),
	]

static func by_id(id: String) -> ModuleDef:
	for def in all():
		if def.id == id:
			return def
	return null

static func _room(id: String, display_name: String, footprint: Vector2i,
		price: int, is_core: bool) -> ModuleDef:
	var def := ModuleDef.new()
	def.id = id
	def.display_name = display_name
	def.footprint = footprint
	def.price = price
	def.is_core = is_core
	return def

static func _turret_room() -> ModuleDef:
	var def := ModuleDef.new()
	def.id = "turret_room"
	def.display_name = "Turret Room"
	def.footprint = Vector2i(1, 1)
	def.has_firing_face = true
	def.cost = {"sc": 4}  # base gun room (ROOM_SYSTEM.md §6)
	return def

static func _floodlight_pod() -> ModuleDef:
	var def := ModuleDef.new()
	def.id = "floodlight_pod"
	def.display_name = "Floodlight Pod"
	def.is_pod = true
	def.footprint = Vector2i(0, 0)
	def.cost = {"sc": 4}  # MODULAR_SUB_IMPLEMENTATION.md §8
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
