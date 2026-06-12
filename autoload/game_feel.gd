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
	## Holding `use` this long at a breach patches it. Progress PERSISTS on the
	## breach if you leave (playtest #5): walk off for air, come back, resume.
	var repair_time: float = 3.0
	## How close (m) a crew must stand to a breach to repair it.
	var repair_range_m: float = 1.2
	## Height of the water overflow lip at each doorway (m): water pools in a
	## room and only spills to a neighbour once it rises above this lip
	## (playtest #3; lowered 75% in playtest #2 from 0.5 to 0.125).
	var door_sill_m: float = 0.125
	## Main rooms are 3 m tall — used to convert door_sill_m to a level fraction.
	var room_height_m: float = 3.0
	## Lower-deck rooms (claw, storage) are squatter — 2.5 m tall.
	var lower_room_height_m: float = 2.5
	## Extra downward acceleration (m/s^2) applied at 100% total fill (weighted
	## average of all rooms). Scales linearly with fill.
	var weight_accel: float = 7.0
	## Room water level (fraction) above which a station in that room ejects its
	## occupant and refuses entry.
	var seat_flood_threshold: float = 0.6
	## Crew run-speed multiplier while their feet touch water — even a shallow
	## puddle slows you; jump clear of the surface and you're fast again
	## (playtest #4).
	var swim_speed_mult: float = 0.5
	## Crew jump strength multiplier while submerged above the waist.
	var swim_jump_mult: float = 0.4
	## Breach leak tiers (level-fraction/s). Each hit opens ONE breach whose
	## rate is a discrete step by impact force (playtest #1/#2): a light scrape
	## drips (~90s to flood a room), a solid hit leaks (~45s), a full-speed ram
	## gushes (~20s). More breaches stack, so total inflow grows with count.
	var leak_rate_min: float = 1.0 / 90.0   ## small (light hit)
	var leak_rate_mid: float = 1.0 / 45.0   ## medium hit
	var leak_rate_max: float = 1.0 / 20.0   ## big (full-speed ram)
	## Impact-speed (m/s) band edges separating the small/medium/big tiers.
	var breach_speed_mid: float = 3.5
	var breach_speed_high: float = 5.0
	## Drip-tier leak rate used by fish bites (small, slow).
	var bite_leak_rate: float = 1.0 / 120.0
	## Crew air supply while submerged (seconds) before drowning.
	var air_time: float = 10.0
	## A surfaced crew refills the whole air supply this fast (seconds).
	var air_refill_time: float = 2.0
	## Respawn delay after drowning (seconds).
	var respawn_delay: float = 7.0
	## Total water (volume-weighted average fill across all rooms) above this
	## fraction triggers implosion.
	var implosion_fraction: float = 0.7
	## Impact speed (m/s) below which terrain hits are free (no breach).
	var breach_speed_threshold: float = 2.0

var water: WaterFeel = WaterFeel.new()

## Turret / torpedo feel (Milestone 2). Torpedoes are slow and weighty like
## the sub — leading a moving fish is the skill.
class TurretFeel:
	var torpedo_speed: float = 10.0     ## m/s, travels straight
	var fire_cooldown: float = 1.0      ## s between shots (playtest #7: +20% rate)
	var cone_half_angle_deg: float = 60.0  ## aim cone around the bow's forward (playtest #6)
	## Continuous-aim sweep speed (deg/s): W/S nudge the barrel and it holds
	## its angle, clamped to the cone (playtest #6).
	var aim_speed_deg: float = 75.0
	var torpedo_lifetime: float = 8.0   ## s before a miss fizzles out

var turret: TurretFeel = TurretFeel.new()

## Territorial fish feel (Milestone 2). Small fauna: avoidable by careful
## piloting — they only chase inside their territory and always swim home.
class FishFeel:
	var territory_radius_m: float = 10.0  ## chase trigger around the home point
	var patrol_speed: float = 1.2         ## m/s wandering at home
	var chase_speed: float = 3.5          ## m/s chasing the sub
	var return_speed: float = 2.0         ## m/s swimming home after breaking off
	var bite_interval: float = 3.0        ## s between bites per fish

var fish: FishFeel = FishFeel.new()

## Salvage claw feel (Milestone 3 rework). A two-joint articulated arm hung
## from the keel under the claw room, driven excavator-style: one stick axis
## per joint, blended together. The operator poses it out to reach salvage,
## snaps a cage shut on it, poses the arm back home, and dumps into the
## storage pen. All numbers tunable.
class ClawFeel:
	## Arm segment lengths (m): upper arm (shoulder->elbow) + forearm
	## (elbow->cage). Max reach is their sum (~4.6 m).
	var upper_len_m: float = 2.3
	var fore_len_m: float = 2.3
	## Joint sweep speeds (deg/s) while the operator holds a direction.
	var shoulder_speed_deg: float = 70.0
	var elbow_speed_deg: float = 100.0
	## Joint limits (deg). Shoulder = 0 points straight down; it swings to
	## either side but stays in the lower hemisphere (never up through the
	## hull). Elbow bends relative to the upper arm.
	var shoulder_limit_deg: float = 95.0
	var elbow_limit_deg: float = 160.0
	## How close (m) a piece of salvage must be to the cage to be snapped in.
	var grab_radius_m: float = 0.6
	## The cage counts as "home" (ready to dump) when its tip is within this
	## distance (m) of the keel anchor — you fold the arm back to deliver.
	var home_radius_m: float = 0.9
	## How many pieces the arm's cage holds before a trip home.
	var cage_capacity: int = 2
	## How many pieces the storage pen holds before you must bank at the dock.
	var storage_capacity: int = 8

var claw: ClawFeel = ClawFeel.new()
