class_name PlaceholderArt
extends RefCounted

## All placeholder visual constants in one place: colors and crew dimensions.
##
## Everything is a flat color or a plain size for now. When real art arrives,
## this is the only file that should need to change — gameplay refers to these
## names, never to literal colors or magic sizes.

# --- Crew ---
const CREW_WIDTH_M: float = 0.7
const CREW_HEIGHT_M: float = 1.5
const CREW_P1_COLOR := Color("e8833a")   ## orange
const CREW_P2_COLOR := Color("3ac6e8")   ## cyan

# --- Sub / hull ---
const HULL_COLOR := Color("c8c8d0")
const SUB_INTERIOR := Color("2a2f3a")     ## room background
const SUB_STRUCTURE := Color("8a8f9c")    ## floors/walls/headers
const SUB_FLOOR := Color("4a5160")        ## floor deck highlight
const LADDER_COLOR := Color("e0c060")     ## ladder rails/rungs

# --- Terrain ---
const TERRAIN_SAND := Color("d8c27a")
const TERRAIN_ROCK := Color("6b6b78")
const TERRAIN_DEEP_ROCK := Color("3a3a48")

# --- Environment ---
const SKY_COLOR := Color("9fd3e8")
const WATER_SURFACE := Color("2b6c8f")
const DEEP_WATER := Color("0a1a2e")
const SANDBOX_BG := Color("17202b")
