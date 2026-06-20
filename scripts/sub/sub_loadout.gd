class_name SubLoadout
extends RefCounted

## The persistent upgrade state of the submarine (Module D, the dry dock).
## Bought between runs with banked salvage; read by Sub when it builds itself,
## so every future run's sub reflects what's been unlocked.
##
## Two upgrade classes remain after M7-1 retired Engine Boost:
##   - "Add room"     -> a second gun with its own control room (placed by the
##                       player at a hardpoint slot: stern or bow). Dormant (M4-14).
##   - "Upgrade crew" -> repair training (faster breach patching). Dormant (M4-14).
##
## Engine Boost ("Upgrade room") was retired in M7-1: the engine room no longer
## exists, and propulsion is an inherent property of the control room. move_mult()
## now permanently returns 1.0.

## Where the bought gun room bolts onto the hull. NONE = not owned yet.
enum Slot { NONE, STERN, BOW }

## How much each owned upgrade changes the sub.
const FAST_REPAIR_MULT := 0.6    ## ×repair time (lower = quicker)

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
		"fast_repair": return fast_repair
		"gun_room": return gun_room != Slot.NONE
	return false

## Mark an upgrade owned. `slot` only matters for the gun room.
func set_owned(id: String, slot: Slot = Slot.NONE) -> void:
	match id:
		"fast_repair": fast_repair = true
		"gun_room": gun_room = slot if slot != Slot.NONE else Slot.STERN

## Engine Boost was retired in M7-1. Propulsion is now inherent to the sub.
func move_mult() -> float:
	return 1.0

func repair_time_mult() -> float:
	return FAST_REPAIR_MULT if fast_repair else 1.0

func to_dict() -> Dictionary:
	return {
		"fast_repair": fast_repair,
		"gun_room": _slot_to_str(gun_room),
	}

func from_dict(data: Dictionary) -> void:
	# "engine_boost" key from pre-M7-1 saves is silently ignored on load.
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
