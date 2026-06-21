class_name ModuleDef
extends Resource

## One entry in the module catalog (MODULAR_SUB_IMPLEMENTATION.md §3.1):
## a room or pod *type* that can be bought, placed, and generated. The
## catalog (ModuleCatalog) is the list of these. Plain data only — behavior
## lives in the generation pipeline (M4 Module 3+).

## Stable identifier used in Layout placements/inventory and save data.
@export var id: String = ""

## Player-facing name shown in the dock shop and assembly screen.
@export var display_name: String = ""

## A one-line player-facing blurb shown in the Shop tab (M4-10,
## ROOM_SYSTEM.md §6 "worked examples" — e.g. the turret room's "operate the
## base weapon"). Empty for rooms with nothing special to call out.
@export var description: String = ""

## Size in grid cells (width, height). All current rooms are a single
## uniform cell (1x1, ROOM_SYSTEM.md §1-2); pods don't use this (they clip to
## a face, no cell of their own). Larger (multi-cell) rooms are reserved for
## a future design pass (ROOM_SYSTEM.md §7) — do not generalize speculatively.
@export var footprint: Vector2i = Vector2i(1, 1)

## Scrap cost before price escalation (GameFeel.dock.escalation). Kept for the
## simple/legacy single-currency case; `cost` (below) is the canonical price.
@export var price: int = 0

## Multi-resource price bundle (ROOM_SYSTEM.md §4.2): resource code -> amount,
## e.g. {"sc": 4} or {"teal": 4}. Codes: "sc" = scrap, any other code is a
## color-currency code (MILESTONE_8.md Module 4 — see GameFeel.currency /
## ModuleCatalog._flat_room_cost). Empty means "use `price` scrap".
@export var cost: Dictionary = {}

## The resource bundle to charge for this module — `cost` if set, else `price`
## scrap (so older single-price entries still work).
func cost_bundle() -> Dictionary:
	if not cost.is_empty():
		return cost
	if price > 0:
		return {"sc": price}
	return {}

## Core modules (helm, tower) exist exactly once, are never in inventory,
## and cannot be moved, sold, or revalidated away.
@export var is_core: bool = false

## Pods clip to an exterior hull face instead of occupying a cell.
@export var is_pod: bool = false

## True for modules with a special face that must stay exterior, e.g. a
## turret room's firing face (validate() rule 5).
@export var has_firing_face: bool = false

## True for rooms a pod can be attached to (M4-9: e.g. the Floodlight Room
## hosts the floodlight pod on one of its exterior faces). Plain rooms can't
## host pods — keeps pod placement scoped to the room built for it.
@export var can_host_pod: bool = false

## Optional path to the station scene this module seats, if any.
@export var station_scene: String = ""
