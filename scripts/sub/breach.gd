class_name Breach
extends Node2D

## A hull breach: a leak point on a room wall that feeds water into the sub's
## per-room water model (see Sub.water_levels). Spawned by terrain impacts
## (speed-scaled leak rate) and fish bites (drip-tier); removed by repair.
##
## Visual: a white-orange spark/spray marker (the danger color — reserved for
## breaches and alerts). A warning blink runs for the first few seconds so a
## fresh breach catches the eye through the cutaway.

## Which water room this breach floods (see Sub room indices).
var room: int = 0
## Leak rate in room-level fraction per second.
var leak_rate: float = 0.0

## Repair progress 0-1, driven by a crew holding `use` nearby (Module D).
var repair_progress: float = 0.0

# Blink bookkeeping: fresh breaches flash a warning ring for a few seconds.
var _age: float = 0.0
const _WARN_TIME := 3.0

func _process(delta: float) -> void:
	_age += delta
	queue_redraw()

func _draw() -> void:
	# Colour + size scale by severity tier so the worst leak stands out
	# (playtest #3): yellow/small drip, orange/medium, red/big gusher.
	var c := _tier_color()
	var s := _tier_scale()
	# Spray: a small fan of streaks bursting inward from the breach point,
	# jittering with time so it reads as live water/sparks.
	var t := Time.get_ticks_msec() / 1000.0
	for i in 5:
		var ang := -PI * 0.5 + (i - 2) * 0.35 + sin(t * 7.0 + i) * 0.1
		var len := (14.0 + 6.0 * sin(t * 11.0 + i * 2.0)) * s
		draw_line(Vector2.ZERO, Vector2.from_angle(ang) * len, c, 3.0)
	# Core spark.
	draw_circle(Vector2.ZERO, 5.0 * s, Color.WHITE)
	draw_circle(Vector2.ZERO, 8.0 * s, Color(c, 0.6))

	# Fresh-breach warning blink: a pulsing ring for the first few seconds.
	if _age < _WARN_TIME and fmod(_age, 0.4) < 0.25:
		draw_arc(Vector2.ZERO, 18.0 * s, 0.0, TAU, 24, c, 3.0)

	# Repair progress arc (Module D): fills clockwise as the patch completes.
	if repair_progress > 0.0:
		draw_arc(Vector2.ZERO, 24.0 * s, -PI * 0.5, -PI * 0.5 + TAU * repair_progress,
			24, Color.WHITE, 4.0)

## Severity tier from the leak rate, vs the GameFeel tier values (drip-tier
## fish bites read as "small"). Returned as colour + draw-scale helpers.
func _tier() -> int:
	var w: GameFeel.WaterFeel = GameFeel.water
	var big_threshold := (w.leak_rate_mid + w.leak_rate_max) * 0.5
	var mid_threshold := (w.leak_rate_min + w.leak_rate_mid) * 0.5
	if leak_rate >= big_threshold:
		return 2
	elif leak_rate >= mid_threshold:
		return 1
	return 0

func _tier_color() -> Color:
	match _tier():
		2: return PlaceholderArt.BREACH_BIG
		1: return PlaceholderArt.BREACH_MED
		_: return PlaceholderArt.BREACH_SMALL

func _tier_scale() -> float:
	match _tier():
		2: return 1.5
		1: return 1.1
		_: return 0.75
