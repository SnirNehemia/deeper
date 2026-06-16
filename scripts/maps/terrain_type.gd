class_name TerrainType
extends RefCounted

## M6 Module 3: the four physical_layer hex codes and the impact-rule
## modifiers each one applies on top of the baseline ramming rules
## (GameFeel.water.breach_speed_threshold / GameFeel.breach).

enum Type { NORMAL_ROCK, SAND, SHARP_ROCK, DOCK }

const NORMAL_ROCK_COLOR := Color(0.5, 0.5, 0.5)       # #808080
const SAND_HEX_COLOR := Color(0xD2 / 255.0, 0xB4 / 255.0, 0x8C / 255.0)  # #D2B48C
const SHARP_ROCK_COLOR := Color(0, 0, 0)               # #000000
const DOCK_COLOR := Color(0x6E / 255.0, 0x47 / 255.0, 0x3B / 255.0)  # #6E473B
const SKY_COLOR := Color(0x4D / 255.0, 0x9B / 255.0, 0xC7 / 255.0)  # #4d9bc7

const COLOR_EPS := 0.5 / 255.0

## Maps a physical_layer pixel color to a terrain Type, or -1 if the pixel
## doesn't match any known terrain hex (treated as solid normal rock by the
## caller, since an authored map shouldn't have stray colors, but staying
## permissive keeps the parser from silently dropping blocks).
static func from_color(color: Color) -> Type:
	if _matches(color, SHARP_ROCK_COLOR):
		return Type.SHARP_ROCK
	if _matches(color, SAND_HEX_COLOR):
		return Type.SAND
	if _matches(color, DOCK_COLOR):
		return Type.DOCK
	return Type.NORMAL_ROCK

static func _matches(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < COLOR_EPS and absf(a.g - b.g) < COLOR_EPS and absf(a.b - b.b) < COLOR_EPS

## True if impacts on this terrain never breach the hull (docking bays).
static func is_non_damaging(type: Type) -> bool:
	return type == Type.DOCK

## Multiplier applied to GameFeel.water.breach_speed_threshold:
## sand is forgiving (threshold doubled), sharp rock is punishing (halved).
static func threshold_mult(type: Type) -> float:
	match type:
		Type.SAND: return 2.0
		Type.SHARP_ROCK: return 0.5
		_: return 1.0

## Multiplier applied to the computed breach severity once over threshold.
## Sand impacts breach at half severity.
static func severity_mult(type: Type) -> float:
	match type:
		Type.SAND: return 0.5
		_: return 1.0

## If true, any impact over threshold is forced to GameFeel.breach.severity_max
## (sharp rock: instant high-severity, rapid-flooding breach).
static func forces_max_severity(type: Type) -> bool:
	return type == Type.SHARP_ROCK
