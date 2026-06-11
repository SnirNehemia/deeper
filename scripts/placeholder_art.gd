class_name PlaceholderArt
extends RefCounted

## All placeholder visual constants in one place: colors and crew dimensions.
##
## Everything is a flat color or a plain size for now. When real art arrives,
## this is the only file that should need to change — gameplay refers to these
## names, never to literal colors or magic sizes.

# --- Crew ---
const CREW_WIDTH_M: float = 0.7
const CREW_HEIGHT_M: float = 1.2
const CREW_P1_COLOR := Color("e8833a")   ## orange
const CREW_P2_COLOR := Color("3ac6e8")   ## cyan

# --- Sub / hull ---
const HULL_COLOR := Color("c8c8d0")
const SUB_INTERIOR := Color("2a2f3a")     ## room background
const SUB_STRUCTURE := Color("8a8f9c")    ## floors/walls/headers
const SUB_FLOOR := Color("4a5160")        ## floor deck highlight
const LADDER_COLOR := Color("e0c060")     ## ladder rails/rungs
const INTERIOR_WATER := Color(0.16, 0.42, 0.58, 0.75)  ## flooding water in a room
const BREACH_COLOR := Color("ff8c3a")     ## generic danger hue (alert flash)
# Breach severity tiers (playtest #3): distinct colour + size so the crew can
# tell at a glance which leak to patch first. A danger gradient yellow->red.
const BREACH_SMALL := Color("f5d020")     ## slow drip (yellow)
const BREACH_MED := Color("ff8c3a")       ## steady leak (orange)
const BREACH_BIG := Color("ff3030")       ## gusher (red)

# --- Fauna ---
const FISH_COLOR := Color("7a4ae8")       ## chunky territorial fish (purple)
const FISH_LENGTH_M: float = 1.0

# --- Terrain ---
const TERRAIN_SAND := Color("d8c27a")
const TERRAIN_ROCK := Color("6b6b78")
const TERRAIN_DEEP_ROCK := Color("3a3a48")

# --- Environment ---
const SKY_COLOR := Color("9fd3e8")
const WATER_SURFACE := Color("2b6c8f")
const DEEP_WATER := Color("0a1a2e")
const SANDBOX_BG := Color("17202b")
const CAVE_COLOR := Color("05080f")     ## dark recess
const DOCK_COLOR := Color("7a5a3a")     ## wooden dock
