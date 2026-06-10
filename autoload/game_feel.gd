extends Node

## Central tunable game-feel config (autoload: "GameFeel").
##
## Every movement number in the game lives here — nothing is scattered in
## gameplay scripts. Values are in real-world units (meters, seconds); convert
## to screen pixels with PIXELS_PER_METER at the point of use.
##
## World scale is locked: 1 meter = 48 px (chunky-pixel HD canvas).

const PIXELS_PER_METER: float = 48.0

## Crew (on-foot) movement feel. Two presets exist — "weighty" (canon) and
## "snappy" (Overcooked-style, kept for playtest comparison). Switch with
## use_weighty() / use_snappy().
class CrewFeel:
	var run_max_speed: float = 4.5      ## m/s
	var run_time_to_max: float = 0.15   ## s to reach max from standstill
	var run_stop_time: float = 0.10     ## s to stop from max
	var jump_apex_height: float = 1.3   ## m peak of a jump
	var jump_time_to_apex: float = 0.38 ## s from launch to peak
	var coyote_time: float = 0.10       ## s of grace to jump after leaving ground
	var jump_buffer_time: float = 0.10  ## s a jump press is remembered before landing
	var climb_speed: float = 3.0        ## m/s on ladders

	## Acceleration needed to hit max speed in run_time_to_max (m/s^2).
	func run_accel() -> float:
		return run_max_speed / run_time_to_max

	## Deceleration needed to stop from max in run_stop_time (m/s^2).
	func run_decel() -> float:
		return run_max_speed / run_stop_time

	## Gravity that yields the desired apex height + rise time (m/s^2).
	func gravity() -> float:
		return 2.0 * jump_apex_height / (jump_time_to_apex * jump_time_to_apex)

	## Launch speed that reaches the apex in jump_time_to_apex (m/s, upward).
	func jump_velocity() -> float:
		return 2.0 * jump_apex_height / jump_time_to_apex

## Canon "heavy but controllable" crew preset.
static func weighty() -> CrewFeel:
	return CrewFeel.new()  # defaults are the weighty preset

## "Snappy" preset for playtest comparison (faster spin-up/stop).
static func snappy() -> CrewFeel:
	var f := CrewFeel.new()
	f.run_time_to_max = 0.05
	f.run_stop_time = 0.03
	return f

## The crew feel currently in effect. Defaults to weighty.
var crew: CrewFeel = weighty()

func use_weighty() -> void:
	crew = weighty()

func use_snappy() -> void:
	crew = snappy()

## Submarine driving feel: heavy but controllable. Direct control — the helm
## occupant's move vector accelerates the sub; neutral buoyancy means it drifts
## to a stop and never sinks on its own.
class SubFeel:
	var max_speed_h: float = 6.0   ## m/s horizontal
	var max_speed_v: float = 4.0   ## m/s vertical
	var time_to_max: float = 3.0   ## s to spin up to max
	var coast_to_stop: float = 2.0 ## s to coast to a stop once input is released
	var max_pitch_deg: float = 5.0 ## cosmetic nose tilt at full horizontal speed
	var surface_gravity: float = 14.0 ## m/s^2 downward weight when fully out of the water

	func accel_h() -> float:
		return max_speed_h / time_to_max
	func decel_h() -> float:
		return max_speed_h / coast_to_stop
	func accel_v() -> float:
		return max_speed_v / time_to_max
	func decel_v() -> float:
		return max_speed_v / coast_to_stop

## The submarine feel currently in effect.
var sub: SubFeel = SubFeel.new()

## Water / flooding feel (Milestone 2). Per-room water_level (0-1) lives on Sub;
## these numbers tune how it flows, weighs the sub down, drains, and how breaches
## leak. All "rate" values are in level-fraction-per-second.
class WaterFeel:
	## Equalization rate constant between connected rooms (per second). Higher =
	## faster equalizing. ~0.35 brings two rooms to within a few % in ~10-15s.
	var flow_rate: float = 0.35
	## A room with zero breaches drains fully in ~12s.
	var drain_rate: float = 1.0 / 12.0
	## Extra downward acceleration (m/s^2) applied at 100% total fill (weighted
	## average of all rooms). Scales linearly with fill.
	var weight_accel: float = 7.0
	## Room water level (fraction) above which a station in that room ejects its
	## occupant and refuses entry.
	var seat_flood_threshold: float = 0.6
	## Crew run-speed multiplier while submerged above the waist.
	var swim_speed_mult: float = 0.5
	## Crew jump strength multiplier while submerged above the waist.
	var swim_jump_mult: float = 0.4
	## Breach leak-rate range (level-fraction/s): slowest breach floods a room in
	## ~90s, the worst single breach in ~20s. Multiple breaches stack.
	var leak_rate_min: float = 1.0 / 90.0
	var leak_rate_max: float = 1.0 / 20.0
	## Drip-tier leak rate used by fish bites (small, slow).
	var bite_leak_rate: float = 1.0 / 120.0
	## Crew air supply while submerged (seconds) before drowning.
	var air_time: float = 10.0
	## Respawn delay after drowning (seconds).
	var respawn_delay: float = 7.0
	## Total water (volume-weighted average fill across all rooms) above this
	## fraction triggers implosion.
	var implosion_fraction: float = 0.7
	## Impact speed (m/s) below which terrain hits are free (no breach).
	var breach_speed_threshold: float = 2.0
	## Impact speed (m/s) at which a hit produces the worst (leak_rate_max) breach.
	var breach_speed_max: float = 6.0

var water: WaterFeel = WaterFeel.new()
