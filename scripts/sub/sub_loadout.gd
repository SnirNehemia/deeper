class_name SubLoadout
extends RefCounted

## The persistent upgrade state of the submarine (Module D, the dry dock).
## Bought between runs with banked salvage; read by Sub when it builds itself,
## so every future run's sub reflects what's been unlocked.
##
## Three upgrade classes, mirroring the dry-dock screen:
##   - "Add room"     -> a second gun with its own control room (placed by the
##                       player at a hardpoint slot: stern or bow).
##   - "Upgrade room" -> engine boost (faster move + dive).
##   - "Upgrade crew" -> repair training (faster breach patching).

## Where the bought gun room bolts onto the hull. NONE = not owned yet.
enum Slot { NONE, STERN, BOW }

## How much each owned upgrade changes the sub.
const ENGINE_BOOST_MULT := 1.5   ## ×movement/dive accel + top speed
const FAST_REPAIR_MULT := 0.6    ## ×repair time (lower = quicker)

var engine_boost: bool = false
var fast_repair: bool = false
var gun_room: Slot = Slot.NONE

## The dry-dock catalog: one entry per purchasable upgrade. Costs are in scrap.
static func catalog() -> Array:
	return [
		{
			"id": "gun_room", "klass": "Add room", "label": "Second Gun + Control Room",
			"desc": "A second torpedo gun with its own room. You choose where it bolts on.",
			"cost": 6, "needs_slot": true,
		},
		{
			"id": "engine_boost", "klass": "Upgrade room", "label": "Engine Boost",
			"desc": "Faster movement and diving.",
			"cost": 3, "needs_slot": false,
		},
		{
			"id": "fast_repair", "klass": "Upgrade crew", "label": "Repair Training",
			"desc": "Crew patch breaches faster.",
			"cost": 3, "needs_slot": false,
		},
	]

static func catalog_entry(id: String) -> Dictionary:
	for e in catalog():
		if e["id"] == id:
			return e
	return {}

func owns(id: String) -> bool:
	match id:
		"engine_boost": return engine_boost
		"fast_repair": return fast_repair
		"gun_room": return gun_room != Slot.NONE
	return false

## Mark an upgrade owned. `slot` only matters for the gun room.
func set_owned(id: String, slot: Slot = Slot.NONE) -> void:
	match id:
		"engine_boost": engine_boost = true
		"fast_repair": fast_repair = true
		"gun_room": gun_room = slot if slot != Slot.NONE else Slot.STERN

func move_mult() -> float:
	return ENGINE_BOOST_MULT if engine_boost else 1.0

func repair_time_mult() -> float:
	return FAST_REPAIR_MULT if fast_repair else 1.0

func to_dict() -> Dictionary:
	return {
		"engine_boost": engine_boost,
		"fast_repair": fast_repair,
		"gun_room": _slot_to_str(gun_room),
	}

func from_dict(data: Dictionary) -> void:
	engine_boost = bool(data.get("engine_boost", false))
	fast_repair = bool(data.get("fast_repair", false))
	gun_room = _slot_from_str(str(data.get("gun_room", "none")))

static func _slot_to_str(s: Slot) -> String:
	match s:
		Slot.STERN: return "stern"
		Slot.BOW: return "bow"
	return "none"

static func _slot_from_str(s: String) -> Slot:
	match s:
		"stern": return Slot.STERN
		"bow": return Slot.BOW
	return Slot.NONE
