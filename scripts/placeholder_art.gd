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
const FLOODLIGHT_COLOR := Color("f5e6a0")  ## floodlight pod lens/beam (warm white)
const INTERIOR_WATER := Color(0.16, 0.42, 0.58, 0.75)  ## flooding water in a room
const BREACH_COLOR := Color("ff8c3a")     ## generic danger hue (alert flash)
# Breach severity tiers (playtest #3): distinct colour + size so the crew can
# tell at a glance which leak to patch first. A danger gradient yellow->red.
const BREACH_SMALL := Color("f5d020")     ## slow drip (yellow)
const BREACH_MED := Color("ff8c3a")       ## steady leak (orange)
const BREACH_BIG := Color("ff3030")       ## gusher (red)

# --- Fauna ---
const FISH_COLOR := Color("e8742c")       ## chunky territorial fish (orange)
const FISH_LENGTH_M: float = 1.0
const CHASER_COLOR := Color("39c45a")     ## basic_chaser: green, open-water
const CHASER_LENGTH_M: float = 1.6        ## more elongated than the territorial fish
## MILESTONE_9.md — THE LURKER (AMBUSHER): a sand-buried ambusher. Sand-colored
## so it hides against the seabed; a flattened/low silhouette (drawn in
## Fish._draw) so it reads as "buried."
const LURKER_COLOR := Color(0.82, 0.71, 0.48)  ## sandy tan
const LURKER_LENGTH_M: float = 1.2        ## longer + drawn flat, so it looks half-buried
## MILESTONE_9.md — THE SPITTER: a round, dark-brown puffer that inflates to a
## taut circle before firing bubbles.
const SPITTER_COLOR := Color(0.36, 0.23, 0.13)  ## dark brown
const SPITTER_LENGTH_M: float = 1.2
## MILESTONE_10.md — THE SHOAL: a cloud of tiny, slim fish that move as one
## organism. Pale silvery-teal so the swarm shimmers as a group and reads
## distinct from the green chaser; they drop "teal" currency (the leader carries
## the prize). The leader wears a grown-in spike marker (drawn in Fish._draw).
const SHOAL_COLOR := Color(0.7, 0.85, 0.82)     ## pale silvery-teal
const SHOAL_LENGTH_M: float = 0.6               ## slim little body
const SHOAL_LEADER_MARK := Color(0.96, 0.98, 0.95)  ## bright crown spikes over the leader

# --- Salvage ---
const SCRAP_COLOR := Color("c8a050")      ## scrap crate (warm metal)
## MILESTONE_8.md Module 4: named currency-color lookup for rendering a drop —
## per-species currency_color (EnemyDef) and "gold" (the elite premium
## currency) are arbitrary strings, not a fixed enum, so this is a Dictionary
## rather than more const Colors. Unknown names (a typo, or a color not yet
## registered here) fall back to a neutral grey rather than erroring.
## 2026-06-26 (Snir): the fauna economy is consolidated to two droppable colors
## — "brown" (territorial/hunter reef fish + Sand Lurker + Spitter) and "teal"
## (chaser + the queued Shoal + Discharger) — plus "gold" (the elite premium).
## "purple" is the reserved third currency for a future category (nothing drops
## it yet). "orange"/"tan" are legacy palette entries no longer dropped by any
## species, kept only so old saves/pickups still render instead of grey-falling.
const CURRENCY_COLORS := {
	"brown": Color("8a5a32"),
	"teal": Color("2ec4b6"),
	"gold": Color("d4af37"),
	"orange": Color("e8742c"),  ## legacy — no longer dropped
	"tan": Color("d2b48c"),     ## legacy — no longer dropped
}
static func currency_color(name: String) -> Color:
	return CURRENCY_COLORS.get(name, Color("b8b8c0"))
const WRECK_COLOR := Color("5a5a52")      ## closed wreck hull (dull rust-grey)
const WRECK_OPEN_COLOR := Color("3a3a36") ## cracked-open wreck (darker, hollow)
const WRECK_LENGTH_M: float = 4.0

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
