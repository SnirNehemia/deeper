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

## Milestone 5: "damage = breaches" spine. Every hit on the sub (bite, ram,
## future projectile) goes through Sub.breach_from_hit(room, severity, point),
## which spawns one M2 breach whose inflow rate scales with severity.
class BreachFeel:
	## Severity at/below this maps to the lightest leak.
	var severity_min: float = 1.0
	## Severity at/above this maps to the heaviest gush.
	var severity_max: float = 5.0
	## Inflow rate (level-fraction/s) at severity_min — a small, slow-patchable leak.
	var inflow_at_min: float = 1.0 / 120.0
	## Inflow rate (level-fraction/s) at severity_max — a gushing breach.
	var inflow_at_max: float = 1.0 / 20.0
	## Severity added per m/s of impact speed above breach_speed_threshold,
	## so a full-speed ram lands near severity_max while a graze stays near severity_min.
	var ram_severity_per_speed: float = 1.0
	## Max alpha of the struck-room flash at severity_max (scales down toward 0 at severity_min).
	var flash_alpha_max: float = 0.5

	## Linear map from severity to inflow rate, clamped to [severity_min, severity_max].
	func severity_to_inflow(severity: float) -> float:
		var t := clampf((severity - severity_min) / (severity_max - severity_min), 0.0, 1.0)
		return lerpf(inflow_at_min, inflow_at_max, t)

var breach: BreachFeel = BreachFeel.new()

## MILESTONE_8.md Module 1: rams have physical consequence, on top of (never
## instead of) the breach_from_hit damage spine above. Sub.apply_ram_knockback
## adds a one-time velocity impulse; the sub's existing accel/decel feel
## (SubFeel) naturally pulls it back toward the helm's intended speed over the
## next few frames, so no separate decay timer is needed here. Per-species
## weight lives in EnemyClassStats.room_weight (data), not here (spine).
class EnemyImpactFeel:
	## Sub velocity (m/s) added per (1 room_weight unit x 1 m/s impact speed).
	var ram_knockback_scalar: float = 0.4

	## MILESTONE_8.md Module 2: grab-tug weight bands. room_weight at/below
	## this is Light — hard-pinned by the holding arm, no tug calc at all (the
	## approved cheap-path optimization). At/above heavy_weight_min is Heavy —
	## a dominant drag. Between the two is Medium — a real tug-of-war. The
	## reference fish's three EnemyClassStats tiers (Small 1.0 / Big 2.0 /
	## Elite 3.0) land one per band by design.
	var light_weight_max: float = 1.5
	var heavy_weight_min: float = 2.5
	## Sub *target*-velocity (m/s) shifted per (1 room_weight unit x 1 m/s of
	## the held enemy's struggle speed), for Medium/Heavy bands only. A target
	## shift (not a raw velocity add) settles at a bounded drift speed instead
	## of accelerating forever — the same accel/decel feel the helm already
	## fights against just chases a pulled-on target instead of a clean one.
	## Split per band (2026-06-21: Snir found Medium too strong relative to
	## the helm's ability to fight it) — Heavy keeps the original, intentionally
	## dominant value.
	var tug_force_scalar_medium: float = 0.18
	var tug_force_scalar_heavy: float = 0.35

	enum WeightBand { LIGHT, MEDIUM, HEAVY }

	func weight_band(room_weight: float) -> WeightBand:
		if room_weight <= light_weight_max:
			return WeightBand.LIGHT
		if room_weight >= heavy_weight_min:
			return WeightBand.HEAVY
		return WeightBand.MEDIUM

	## The tug scalar to use for a catch of this room_weight (Light never
	## calls set_tug at all, so it never reaches here in practice).
	func tug_scalar_for(room_weight: float) -> float:
		if weight_band(room_weight) == WeightBand.HEAVY:
			return tug_force_scalar_heavy
		return tug_force_scalar_medium

var enemy_impact: EnemyImpactFeel = EnemyImpactFeel.new()

## Reel-in timing minigame (2026-06-21 follow-up to MILESTONE_8.md Module 2):
## once a live fish is hooked, a taut rope runs from the arm's base to the
## catch and a bead sweeps back and forth along it (period scaled by weight).
## Press the action key while the bead is in the green zone, close to the sub
## end, to land a pull — the catch comes pull_distance_m closer. Land nothing
## by the time the bead swings back to the sub and the hull takes a small
## leak at the arm's base. See TUNING.md for where this fits among the other
## game-feel knobs.
class ReelFeel:
	## Full back-and-forth sweep period (s) at the easiest (near-zero weight)
	## and hardest (at impossible_weight_min) ends of the difficulty curve.
	var sweep_period_easy_s: float = 1.6
	var sweep_period_hard_s: float = 0.6
	## Half-width of the green "success" zone, as a fraction of the rope's
	## length, at the easiest and hardest ends. Shrinks to nothing at the
	## hardest end — see impossible_weight_min below.
	var success_zone_easy_frac: float = 0.35
	var success_zone_hard_frac: float = 0.0
	## Extra width (flat, regardless of difficulty) of the yellow "close"
	## band shown beyond the green zone — visual feedback only, no separate
	## mechanical effect (any press outside green simply doesn't land).
	var near_zone_margin_frac: float = 0.15
	## room_weight at/above which the green zone has shrunk to exactly zero —
	## the catch can never be landed, only released. Above every species in
	## today's reference data (Elite tops out at 3.0): reserved headroom for
	## a future "too big to land" enemy class.
	var impossible_weight_min: float = 4.0
	## Progress (m) the catch comes closer to home per landed pull.
	var pull_distance_m: float = 2.0
	## Breach severity (GameFeel.breach scale) opened at the arm's base when
	## a full sweep passes without landing a pull.
	var miss_leak_severity: float = 1.5
	## Damage dealt the instant a catch is fully reeled home — always lethal
	## regardless of remaining hp; the reel-in itself is the kill, not a
	## separate hp check.
	var finish_damage: float = 9999.0

	func _difficulty_t(room_weight: float) -> float:
		return clampf(room_weight / impossible_weight_min, 0.0, 1.0)
	func sweep_period_s(room_weight: float) -> float:
		return lerpf(sweep_period_easy_s, sweep_period_hard_s, _difficulty_t(room_weight))
	func success_zone_frac(room_weight: float) -> float:
		return lerpf(success_zone_easy_frac, success_zone_hard_frac, _difficulty_t(room_weight))
	func near_zone_frac(room_weight: float) -> float:
		return success_zone_frac(room_weight) + near_zone_margin_frac

var reel: ReelFeel = ReelFeel.new()

## MILESTONE_8.md Module 3: ranged enemy fire. `ranged=true` (EnemyDef, a
## per-species base trait) or the Elite-only `ranged_spit` ability lets a fish
## fire a slow projectile at the sub instead of relying on contact alone. The
## shot damages the sub through the same `breach_from_hit` spine a bite uses —
## no second damage path. Per-species on/off lives in the `.tres`; this block
## is purely the shared base behavior (speed, cadence, severity).
class EnemyRangedFeel:
	## Range (m) within which a ranged-capable enemy will fire.
	var fire_range_m: float = 12.0
	## Seconds between shots.
	var fire_cooldown_s: float = 2.5
	## Shot travel speed (m/s) — slow and dodgeable, not a hitscan.
	var projectile_speed_mps: float = 5.0
	## Seconds before an unspent shot fizzles out.
	var projectile_lifetime_s: float = 6.0
	## Severity (GameFeel.breach scale) applied via breach_from_hit on a hit —
	## same scale as Fish bite damage, not a separate hp number.
	var damage: float = 1.0
	## An Elite with the `ranged_spit` ability AND the species' base `ranged`
	## trait already true "intensifies" rather than merely "gains" — its
	## cooldown is multiplied by this (so it fires roughly twice as often).
	var intensify_cooldown_mult: float = 0.5

var enemy_ranged: EnemyRangedFeel = EnemyRangedFeel.new()

## MILESTONE_9.md — THE SPITTER's bubble (scripts/fauna/bubble.gd): the game's
## first DESTRUCTIBLE projectile. Drifts to the hull and breaches it on contact
## (breach_from_hit, the only death path), but players can shoot it out of the
## air — it carries hp and runs a duel against a passing shot (see bubble.gd).
## First-pass numbers; tune in playtest.
class BubbleFeel:
	## Shot damage needed to burst it. 2.0 = one turret torpedo (5 dmg) bursts
	## it outright; a 1-dmg bullet needs two to pop it.
	var hp: float = 2.0
	## Drift speed (m/s) toward the sub — slow and shootable, not a hitscan.
	var speed_mps: float = 4.0
	## Seconds before an undisturbed bubble fizzles out.
	var lifetime_s: float = 6.0
	## Breach severity (GameFeel.breach scale) on a hull hit — same scale as a
	## bite, not a separate hp number.
	var damage: float = 1.0
	## A bubble always drags a passing shot: its velocity is multiplied by this
	## on contact (whether the shot bursts through or is consumed).
	var slow_factor: float = 0.6

var bubble: BubbleFeel = BubbleFeel.new()

## MILESTONE_9.md — THE SPITTER (SPITTER behavior): a round puffer that keeps its
## distance, inflates to a taut circle, and fires bubbles (more from bigger
## ones). Fully inflated it's a juicy target — extra damage taken + bonus
## currency if popped before it fires. First-pass numbers; tune in playtest.
class SpitterFeel:
	## How far it first notices the sub (and the radius of its drawn ring).
	var spit_detect_m: float = 16.0
	## Preferred standoff band: closer than min → back away; farther than max →
	## approach; inside the band → hold and inflate.
	var spit_keep_min_m: float = 7.0
	var spit_keep_max_m: float = 11.0
	## Seconds to inflate from resting to full before it fires.
	var inflate_time_s: float = 1.6
	## Seconds after firing before it can inflate again.
	var inflate_cooldown_s: float = 2.5
	## Drawn body scale at full inflation (1.0 = resting size).
	var inflate_full_scale: float = 1.9
	## Bubbles fired per tier (Small 1, Big 2, Elite a scatter spread).
	var small_bubbles: int = 1
	var big_bubbles: int = 2
	var elite_bubbles: int = 4
	## Half-angle (deg) of the random spread cone when firing more than one.
	var scatter_spread_deg: float = 18.0
	## Damage multiplier applied to hits taken while inflated (juicy target).
	var inflate_damage_mult: float = 2.0
	## Extra currency added to the drop if it's popped while inflated.
	var inflate_pop_bonus: int = 10

var spitter: SpitterFeel = SpitterFeel.new()

## MILESTONE_8.md Module 4: color-currency economy. Replaces the retired
## carcass tiers (s_ca/m_ca/l_ca) — an enemy drops its species' currency_color
## (EnemyDef, per-species) instead, split into these denominations. Room
## prices are flat-and-random for now (Snir, 2026-06-21: "price/balance is not
## crucial, I'll balance it in a later milestone" — skipping the planned
## color→room mapping Q&A). See TUNING.md.
class CurrencyFeel:
	## Denomination pickups a drop total is broken into, largest first (a
	## simple greedy split — the milestone's open "denomination split rule"
	## question, resolved with the simplest option since exact behavior here
	## isn't load-bearing yet).
	var denominations: Array[int] = [50, 10, 5, 1]
	## Flat price (in one randomly-chosen currency color) for every
	## purchasable room — first-pass numbers, explicitly provisional until
	## M9's real species/color faucet exists to balance against.
	var flat_room_price: int = 4
	## The pool a room's price color is randomly drawn from. 2026-06-26 (Snir):
	## the fauna economy is deliberately consolidated to TWO droppable colors so
	## it doesn't get cumbersome as species multiply — "brown" (territorial/
	## hunter reef fish + Sand Lurker + Spitter) and "teal" (chaser + the queued
	## Shoal + Discharger). A third, "purple", is reserved for a future category
	## but nothing drops it yet, so it's NOT in this pool. Deliberately excludes
	## "gold" too — that's the elite-only premium currency, not a room-gating color.
	var room_price_colors: Array[String] = ["brown", "teal"]

	## Breaks `total` into denomination pickups, e.g. 8 -> [5, 1, 1, 1].
	func split(total: int) -> Array[int]:
		var pickups: Array[int] = []
		var remaining := total
		for d in denominations:
			while remaining >= d:
				pickups.append(d)
				remaining -= d
		return pickups

var currency: CurrencyFeel = CurrencyFeel.new()

## Turret / torpedo feel (Milestone 2). Torpedoes are slow and weighty like
## the sub — leading a moving fish is the skill.
class TurretFeel:
	var torpedo_speed: float = 7.5     ## m/s, travels straight
	var fire_cooldown: float = 1.0      ## s between shots (playtest #7: +20% rate)
	var cone_half_angle_deg: float = 60.0  ## aim cone around the bow's forward (playtest #6)
	## Continuous-aim sweep speed (deg/s): W/S nudge the barrel and it holds
	## its angle, clamped to the cone (playtest #6).
	var aim_speed_deg: float = 75.0
	var torpedo_lifetime: float = 15.0   ## s before a miss fizzles out
	## M5: HP damage dealt to a Fish/Wreck on hit. Equal to fish.hp so one
	## torpedo still one-shots a fish (M2 acceptance, preserved).
	var damage: float = 5.0
	## ±speed spread added at launch (m/s) so shots don't all land the same place.
	var speed_variation_m: float = 0.5

var turret: TurretFeel = TurretFeel.new()

## Bullet Room feel (M4-12, ROOM_SYSTEM.md §6 "Bullet weapon room" — speed
## 6 m/s, damage 1 hp, rate 3/s). Fast and frequent vs. the base turret's slow,
## weighty torpedoes — same seat/aim/cone via TurretStation, different
## projectile (Bullet).
class BulletFeel:
	var bullet_speed: float = 10.0    ## m/s
	var fire_cooldown: float = 1.0 / 3.0  ## s between shots (rate 3/s)
	var bullet_lifetime: float = 6.0  ## s before an unspent shot fizzles out
	## M5: HP damage dealt to a Fish/Wreck on hit — a ~5-round burst kills a
	## fish, making the bullet gun a chip-stream vs. the torpedo's heavy single.
	var damage: float = 1.0

var bullet: BulletFeel = BulletFeel.new()

## Floodlight Room feel (M4-17 rework): the seated crew steers the beam left/
## right (like a weapon's aim) and trades length for spread with up/down. The
## cone is a chord of a circle of radius `cone_radius_m` centered on the lamp:
## at "height" h (the cone's reach), its base half-width is
## sqrt(R^2 - h^2) — so a longer beam is narrower and vice versa, both
## derived from the single h value the player controls.
class FloodlightFeel:
	var rotate_speed_deg: float = 60.0   ## left/right aim sweep (deg/s)
	var zoom_speed_m: float = 2.0        ## up/down change to h (m/s)
	var cone_radius_m: float = 10.0      ## R, the circle h and the base half-width are drawn from
	var min_height_m: float = 3.0
	## Must stay below cone_radius_m, or base_half_width_m(h) -> 0 and the
	## cone's drawn width vanishes (2026-06-20: capped to radius - 1m).
	var max_height_m: float = cone_radius_m - 0.1
	var initial_height_m: float = 5.0
	## Light intensity decays with distance from the lamp in a sigmoid falloff:
	## centered at half the radius, falling off over this many meters.
	var decay_center_m: float = 5.0      ## R / 2
	var decay_width_m: float = 2.0
	var max_alpha: float = 0.35

	## The cone's base half-width at reach `h` (m): sqrt(R^2 - h^2).
	func base_half_width_m(h: float) -> float:
		return sqrt(max(0.0, cone_radius_m * cone_radius_m - h * h))

var floodlight: FloodlightFeel = FloodlightFeel.new()

## Territorial fish feel (Milestone 2). Small fauna: avoidable by careful
## piloting — they only chase inside their territory and always swim home.
class FishFeel:
	var territory_radius_m: float = 10.0  ## chase trigger around the home point
	var patrol_speed: float = 1.2         ## m/s wandering at home
	var chase_speed: float = 3.5          ## m/s chasing the sub
	var return_speed: float = 2.0         ## m/s swimming home after breaking off
	var bite_interval: float = 3.0        ## s between bites per fish
	## Knockback speed (m/s) applied away from a non-lethal hit, decaying
	## quickly — a flinch, not a launch.
	var hit_knockback_mps: float = 4.0
	var hit_knockback_decay: float = 8.0
	## Brief white flash duration (s) on a non-lethal hit.
	var hit_flash_time: float = 0.15
	## M5-C2: hunter aggression (design doc §7). A hunter-behavior fish
	## detects the sub from farther than its territorial chase range and
	## pursues it anywhere on the map.
	var hunter_detect_m: float = 16.0
	## Once detected, a hunter only gives up after the sub stays beyond this
	## range for hunter_lose_time seconds.
	var hunter_lose_m: float = 24.0
	var hunter_lose_time: float = 5.0
	## m/s while hunting — faster than the territorial chase_speed.
	var hunt_speed: float = 4.5
	## "basic_chaser" behavior: green, elongated, open-water fauna. Once they
	## spot the sub from this far, they never give up — relentless pursuit
	## until they die. After a successful bite they back off for
	## chaser_backoff_time before pressing the attack again, giving the crew a
	## window to land a hit.
	var chaser_detect_m: float = 22.0
	var chaser_speed: float = 5.0
	var chaser_backoff_time: float = 5.0
	## MILESTONE_9.md — THE LURKER (AMBUSHER behavior). A sand-buried ambusher:
	## an INVISIBLE detection range (no attention ring is ever drawn), a brief
	## tremor windup tell for fairness, then a fast committed straight lunge, a
	## single bite, and a re-bury somewhere new. First-pass numbers — tune in
	## playtest (too-short a windup is unfair, too-long is toothless).
	var ambush_detect_m: float = 7.0          ## hidden trigger radius (smaller than any visible range)
	var ambush_windup_s: float = 0.2          ## tremor tell before the lunge (fairness window)
	var ambush_lunge_speed_mps: float = 18.0  ## the strike — much faster than any other fish
	var ambush_lurk_drift: float = 0.0        ## ~motionless while buried (stays put at home)
	var ambush_lunge_reach_m: float = 12.0    ## how far a lunge commits; a miss past this re-buries
	## MILESTONE_8.md Module 0: HP and bite damage moved to per-species
	## EnemyDef/.tres data (res://data/enemies/) — no longer hard-coded here.

var fish: FishFeel = FishFeel.new()

## Wreck feel (Milestone 3 rework, M5: HP). One torpedo still cracks a wreck;
## a bullet burst also works.
class WreckFeel:
	var hp_max: float = 5.0

var wreck: WreckFeel = WreckFeel.new()

## Conning-tower Hull station (M5-C1): a remote, slower alternative to
## hand-patching. A seated crew holds `use` to auto-patch the nearest breach
## within range_rooms, retargeting once each is sealed.
class HullStationFeel:
	## How many rooms away (via doors/ladders) a breach can be auto-patched from.
	var range_rooms: int = 4
	## Time (s) to fully patch a breach from the tower — slower than a hand
	## patch (GameFeel.water.repair_time) so a free pair of hands always wins.
	var patch_time: float = 8.0

var hull_station: HullStationFeel = HullStationFeel.new()

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

## The dry dock's growth economy (MODULAR_SUB_IMPLEMENTATION.md §6/§8,
## ROOM_SYSTEM.md §4.1). Buying a "slot" is a separate purchase from buying a
## room: a slot is an empty, generated room-shell bolted onto the hull
## (adjacent to it), and rooms from inventory are placed into owned empty
## slots. Price depends on two things, both additive on top of the base:
## every slot already owned makes every future slot a little pricier (a soft
## cap on sub size), and deeper levels (farther from the conning tower) cost
## more (2026-06-14 levels rework).
class DockFeel:
	## Cost of a level-1 slot (the row directly under the tower) before any
	## slots have been bought.
	var slot_base_price: int = 2
	## Each slot already owned adds this many scrap to the price of the next.
	var slot_owned_increment: int = 1
	## Each level below level 1 adds this many scrap to the price.
	var slot_level_increment: int = 2

	## Price of a slot at `level` (the tower's row is level 0, the row
	## directly beneath it is level 1, and so on), given how many slots the
	## player already owns.
	func slot_price(level: int, slots_owned: int) -> int:
		return slot_base_price + slots_owned * slot_owned_increment \
			+ (level - 1) * slot_level_increment

var dock: DockFeel = DockFeel.new()

## Telescope arm room feel (M7-2). A single straight arm that aims, extends,
## and auto-deposits into its own onboard cages on retract.
class TelescopeFeel:
	var reach_m: float = 8.0           ## maximum arm length (m)
	var aim_arc_deg: float = 120.0     ## total sweep arc; arm stays within ±60° of facing
	var aim_speed_deg: float = 80.0    ## deg/s
	var extend_speed: float = 6.0      ## m/s extending
	var retract_speed: float = 8.0     ## m/s retracting (manual, faster for snappy feel)
	var auto_retract_speed: float = 3.0         ## m/s auto-retract when no extend key held
	var auto_retract_speed_carrying: float = 10.0 ## faster auto-retract while carrying an item
	var home_radius_m: float = 0.5     ## tip within this distance of base → auto-deposit fires
	var grab_radius_m: float = 0.7     ## tip must be within this of a salvage item to grab
	var tip_capacity: int = 1          ## items the tip can hold at once
	var cage_capacity: int = 6         ## items per onboard cage (s2 + s4 = 12 total)

var telescope: TelescopeFeel = TelescopeFeel.new()
