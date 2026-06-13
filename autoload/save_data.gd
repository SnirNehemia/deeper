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

## Salvage that's been banked (safe) by returning to the dock.
var banked_scrap: int = 0
var banked_fish: int = 0

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

## Wipe the in-memory and on-disk save (used by tests).
func reset_for_test() -> void:
	banked_scrap = 0
	banked_fish = 0
	loadout = SubLoadout.new()
	layout = SubLayout.starting_layout()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
