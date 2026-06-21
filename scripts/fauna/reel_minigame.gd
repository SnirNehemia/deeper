class_name ReelMinigame
extends RefCounted

## Shared timing-minigame logic for reeling in a live, struggling catch on the
## claw or telescope arm (2026-06-21 follow-up to MILESTONE_8.md Module 2).
## Tunables live in GameFeel.reel — see TUNING.md.
##
## A taut rope runs from the arm's base to the held catch; a bead sweeps back
## and forth along it. Press the action key while the bead is in the green
## zone (close to the sub end) to land a pull. Land nothing by the time the
## bead arrives back at the sub and the hull takes a small leak at the arm's
## base. The owning station calls tick() every physics frame and attempt_pull()
## on the action key, and reads bead_t()/the zone fractions to draw the rope.

var room_weight: float
var _elapsed: float = 0.0
var _succeeded_this_cycle: bool = false
var _prev_cycle_frac: float = 0.0

func _init(p_room_weight: float) -> void:
	room_weight = p_room_weight

func _cycle_frac() -> float:
	var period := GameFeel.reel.sweep_period_s(room_weight)
	return fmod(_elapsed, period) / period

## Advances the sweep. Returns true exactly once, the instant the bead arrives
## back at the sub end without a successful pull since the last arrival — the
## station should open a leak right then.
func tick(delta: float) -> bool:
	_elapsed += delta
	var cycle_frac := _cycle_frac()
	var crossed_sub_end := _prev_cycle_frac < 0.5 and cycle_frac >= 0.5
	_prev_cycle_frac = cycle_frac
	if crossed_sub_end:
		var missed := not _succeeded_this_cycle
		_succeeded_this_cycle = false
		return missed
	return false

## Bead position along the rope: 0 = at the catch, 1 = at the sub.
func bead_t() -> float:
	var cycle_frac := _cycle_frac()
	if cycle_frac < 0.5:
		return cycle_frac * 2.0
	return (1.0 - cycle_frac) * 2.0

func success_zone_frac() -> float:
	return GameFeel.reel.success_zone_frac(room_weight)

func near_zone_frac() -> float:
	return GameFeel.reel.near_zone_frac(room_weight)

## A pull attempt. Only the approach leg (bead heading toward the sub) is
## judged — the return leg is just slack paying back out. Returns true if
## this lands the pull (the caller applies the GameFeel.reel.pull_distance_m
## progress); at most one successful landing counts per sweep.
func attempt_pull() -> bool:
	if _cycle_frac() >= 0.5 or _succeeded_this_cycle:
		return false
	var short_of_sub := 1.0 - bead_t()  # 0 at the sub end, 1 at the catch end
	if short_of_sub <= success_zone_frac():
		_succeeded_this_cycle = true
		return true
	return false
