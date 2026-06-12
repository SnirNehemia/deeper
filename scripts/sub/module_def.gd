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

## Size in grid cells (width, height). Rooms are 2x1 or 1x1; pods don't use
## this (they clip to a face, no cell of their own).
@export var footprint: Vector2i = Vector2i(2, 1)

## Scrap cost before price escalation (GameFeel.dock.escalation).
@export var price: int = 0

## Core modules (helm, tower) exist exactly once, are never in inventory,
## and cannot be moved, sold, or revalidated away.
@export var is_core: bool = false

## Pods clip to an exterior hull face instead of occupying a cell.
@export var is_pod: bool = false

## True for modules with a special face that must stay exterior, e.g. a
## turret room's firing face (validate() rule 5).
@export var has_firing_face: bool = false

## Optional path to the station scene this module seats, if any.
@export var station_scene: String = ""
