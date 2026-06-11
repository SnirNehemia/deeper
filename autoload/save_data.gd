extends Node

## Persisted meta-progression currency (autoload "SaveData").
##
## Module B's first save system: just the two banked salvage totals, written
## to a small JSON file in the user data directory and reloaded on launch.
## Future dry-dock spending hooks into this same file.

const SAVE_PATH := "user://save.json"

## Salvage that's been banked (safe) by returning to the dock.
var banked_scrap: int = 0
var banked_fish: int = 0

func _ready() -> void:
	load_data()

## Read the save file, if any. Missing/corrupt files just leave the totals at
## their defaults (0) — there's nothing to lose on a fresh install.
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

func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"banked_scrap": banked_scrap,
		"banked_fish": banked_fish,
	}))

## Add salvage to the banked totals and persist immediately.
func bank(scrap: int, fish: int) -> void:
	if scrap <= 0 and fish <= 0:
		return
	banked_scrap += scrap
	banked_fish += fish
	save_data()

## Wipe the in-memory and on-disk save (used by tests).
func reset_for_test() -> void:
	banked_scrap = 0
	banked_fish = 0
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
