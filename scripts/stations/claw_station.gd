class_name ClawStation
extends Station

## The salvage claw: a two-joint articulated arm hung from the keel under the
## lower claw room, operated from a console in that room. Driven excavator
## style — one stick axis per joint, blended together:
##   - Left/Right swings the whole arm at the SHOULDER.
##   - Up/Down bends the ELBOW.
## A cage rides the arm's tip. Press `use` over a piece of salvage to snap the
## cage shut on it (it holds a few). To deliver, pose the arm back "home" to
## the keel and press `use` again to dump the cage into the storage pen. There
## is no auto-return — you fold it back yourself.
##
## Like the turret, the arm is drawn by SubVisual so it tilts with the hull's
## cosmetic pitch; grabbing uses that same tilted tip position.

## Where the arm is anchored on the keel, in sub-local space (bottom-center of
## the claw room's belly). Set by Sub at build time from the generated geometry.
var anchor_local: Vector2 = Vector2.ZERO
## Sub-local y of the claw room floor, where dropped catches land (set by Sub).
var drop_floor_y: float = 0.0
## Sub-local x of the dropping hatch (section s2) where catches enter the hold.
var hatch_x: float = 0.0

## The direction the arm reaches out toward at rest (sub-local unit vector),
## set by Sub from the claw room's `facing` (2026-06-19 "any outer face"
## rework). shoulder_angle = 0 points the upper arm along this direction.
var down_dir: Vector2 = Vector2.DOWN

## Joint angles (radians). shoulder = 0 points the upper arm along `down_dir`
## and swings to either side; elbow bends the forearm relative to the upper arm.
## Start folded up at home (tip near the anchor).
var shoulder_angle: float = 0.0
var elbow_angle: float = deg_to_rad(160.0)

## The actual salvage items trapped in the cage right now (kept alive and
## visible — they ride inside the cage as the arm moves). Capacity is
## GameFeel.claw.cage_capacity.
var _caught: Array[SalvageItem] = []
## Brief "snap" animation timer so the cage hatch visibly clamps shut.
var _snap_timer: float = 0.0

## MILESTONE_8.md Module 2: a live fish caught by the cage, held separately
## from `_caught` salvage above (it doesn't take a cage-capacity slot — a
## struggling catch is processed into a normal carcass on delivery instead).
var _grabbed_fish: Fish = null

## 2026-06-21 reel-in minigame: non-null exactly while `_grabbed_fish` is set.
## See scripts/fauna/reel_minigame.gd and GameFeel.reel (TUNING.md). Since the
## claw has no single "extension" scalar like the telescope, progress is
## tracked as distance-reeled-in (m) against the distance at the moment of
## the grab; the joints are frozen at their grabbed pose and lerped toward
## the folded-home pose (shoulder 0 / elbow at its limit) by that fraction.
var _reel: ReelMinigame = null
var _reel_progress_m: float = 0.0
var _reel_total_m: float = 0.0
var _reel_grab_shoulder: float = 0.0
var _reel_grab_elbow: float = 0.0

func _ready() -> void:
	super._ready()
	elbow_angle = deg_to_rad(GameFeel.claw.elbow_limit_deg)

func _physics_process(delta: float) -> void:
	_snap_timer = maxf(0.0, _snap_timer - delta)
	_carry_caught()
	_carry_and_tug_fish(delta)

func handle_input(input: PlayerInput) -> void:
	var c: GameFeel.ClawFeel = GameFeel.claw
	var delta := get_physics_process_delta_time()
	# Excavator control: each axis drives one joint; you can move both at once.
	# Once a live fish is hooked, normal joint control is replaced by the
	# reel-in minigame (see _attempt_pull) — the joints follow landed pulls,
	# not the joystick, until it's delivered.
	if not is_instance_valid(_grabbed_fish):
		var s_lim := deg_to_rad(c.shoulder_limit_deg)
		var e_lim := deg_to_rad(c.elbow_limit_deg)
		shoulder_angle = clampf(
			shoulder_angle + input.move.x * deg_to_rad(c.shoulder_speed_deg) * delta,
			-s_lim, s_lim)
		elbow_angle = clampf(
			elbow_angle + input.move.y * deg_to_rad(c.elbow_speed_deg) * delta,
			-e_lim, e_lim)
	# `use` is the context action: reel a pull attempt if a fish is hooked;
	# otherwise, when the cage is folded home and holding, open it to drop the
	# catch through the keel hatch into the hold; otherwise snap the cage shut
	# on whatever salvage/fish it's over.
	if input.use_pressed:
		if is_instance_valid(_grabbed_fish):
			_attempt_pull()
		elif is_home() and not _caught.is_empty():
			_drop_into_hold()
		else:
			_snap()

# --- Geometry (sub-local space) ---

func upper_len() -> float:
	return GameFeel.claw.upper_len_m * Sub.PPM

func fore_len() -> float:
	return GameFeel.claw.fore_len_m * Sub.PPM

## Elbow joint position: down the upper arm from the anchor.
func joint_local() -> Vector2:
	return anchor_local + down_dir.rotated(shoulder_angle) * upper_len()

## Cage (tip) position: down the forearm from the elbow.
func tip_local() -> Vector2:
	var upper_dir := down_dir.rotated(shoulder_angle)
	var fore_dir := upper_dir.rotated(elbow_angle)
	return joint_local() + fore_dir * fore_len()

## Tip in world space, matching the hull's cosmetic pitch tilt (so grabbing
## lines up with what's drawn).
func _tip_global() -> Vector2:
	return sub.to_global(tip_local().rotated(sub.pitch))

# --- Cage state ---

func cage_count() -> int:
	return _caught.size()

func cage_full() -> bool:
	return _caught.size() >= GameFeel.claw.cage_capacity

func has_grabbed_fish() -> bool:
	return is_instance_valid(_grabbed_fish)

## The active reel-in minigame, or null if nothing's hooked (read by
## SubVisual to draw the tug-rope + bead).
func reel_minigame() -> ReelMinigame:
	return _reel

## True when the cage is folded back near the keel anchor, ready to dump.
func is_home() -> bool:
	return tip_local().distance_to(anchor_local) <= GameFeel.claw.home_radius_m * Sub.PPM

## How fully the cage hatch is clamped shut (0 open .. 1 shut), for the visual.
func clamp_amount() -> float:
	if _snap_timer > 0.0:
		return 1.0
	return 1.0 if _caught.size() > 0 else 0.0

## Where a caught item rides inside the cage (sub-local), staggered along the
## cage mouth so two catches sit side by side instead of overlapping.
const _CAGE_SLOT_SPACING := 26.0

func _caught_slot_local(index: int, count: int) -> Vector2:
	var fore_dir := (tip_local() - joint_local())
	var side := fore_dir.orthogonal().normalized() if fore_dir.length() > 0.1 else Vector2.RIGHT
	var spread := (float(index) - (count - 1) * 0.5) * _CAGE_SLOT_SPACING
	return tip_local() + side * spread

## Keep each trapped item glued inside the cage as the arm moves (and prune any
## that vanished, e.g. on a run reset).
func _carry_caught() -> void:
	for i in range(_caught.size() - 1, -1, -1):
		if not is_instance_valid(_caught[i]) or _caught[i].is_queued_for_deletion():
			_caught.remove_at(i)
	for i in _caught.size():
		var local := _caught_slot_local(i, _caught.size())
		_caught[i].global_position = sub.to_global(local.rotated(sub.pitch))

## Snap the cage hatch shut on any salvage within reach of the tip, up to
## capacity. Caught items stay alive and visible — they ride in the cage.
func _snap() -> void:
	_snap_timer = 0.18
	if cage_full():
		return
	var tip := _tip_global()
	var grab := GameFeel.claw.grab_radius_m * Sub.PPM
	# Nearest-first so a tight snap grabs the obvious target.
	var hits: Array = []
	for node in sub.get_tree().get_nodes_in_group("salvage"):
		var item := node as SalvageItem
		if item == null or item.is_queued_for_deletion() or not item.is_water():
			continue
		var d := tip.distance_to(item.global_position)
		if d <= grab:
			hits.append({"item": item, "d": d})
	hits.sort_custom(func(a, b): return a["d"] < b["d"])
	for h in hits:
		if cage_full():
			break
		var item: SalvageItem = h["item"]
		item.set_caged()
		item.set_deferred("monitoring", false)
		_caught.append(item)
	_carry_caught()
	_try_grab_fish()

## MILESTONE_8.md Module 2: also try to catch a live, grabbable fish near the
## tip — independent of the salvage cage above (a held fish doesn't take a
## cage-capacity slot). Refuses an EnemyDef `grabbable=false` enemy, an
## already-dead one, and one already held by another arm.
func _try_grab_fish() -> void:
	if is_instance_valid(_grabbed_fish):
		return
	var tip := _tip_global()
	var grab_r := GameFeel.claw.grab_radius_m * Sub.PPM
	var nearest: Fish = null
	var nearest_d := INF
	for node in sub.get_tree().get_nodes_in_group("fish"):
		var fish := node as Fish
		if fish == null or not fish.is_grabbable():
			continue
		var d := tip.distance_to(fish.global_position)
		if d <= grab_r and d < nearest_d:
			nearest = fish
			nearest_d = d
	if nearest == null:
		return
	nearest.grab()
	_grabbed_fish = nearest
	_reel = ReelMinigame.new(nearest.class_stats().room_weight)
	_reel_grab_shoulder = shoulder_angle
	_reel_grab_elbow = elbow_angle
	_reel_total_m = tip_local().distance_to(anchor_local) / Sub.PPM
	_reel_progress_m = 0.0

## MILESTONE_8.md Module 2 (+ 2026-06-21 reel minigame): keep a held fish
## riding the tip and, while its weight band is Medium/Heavy, tug the sub via
## its struggle direction. Light is hard-pinned — never calls set_tug at all
## (the approved cheap path: "no tug calc"). Self-corrects if the fish was
## released/died/reset elsewhere (e.g. Fish.reset_fish() during a run reset).
## Advances the reel-in sweep (a full sweep landing nothing opens a small
## leak at the anchor) and lerps the frozen grab pose toward the folded-home
## pose by the fraction reeled in so far; reaching home finalizes the catch.
func _carry_and_tug_fish(delta: float) -> void:
	if not is_instance_valid(_grabbed_fish) or not _grabbed_fish.grabbed:
		if _grabbed_fish != null:
			sub.clear_tug(self)
			_grabbed_fish = null
			_reel = null
		return
	var t := clampf(_reel_progress_m / maxf(_reel_total_m, 0.01), 0.0, 1.0)
	shoulder_angle = lerpf(_reel_grab_shoulder, 0.0, t)
	elbow_angle = lerpf(_reel_grab_elbow, deg_to_rad(GameFeel.claw.elbow_limit_deg), t)
	_grabbed_fish.global_position = _tip_global()
	var stats := _grabbed_fish.class_stats()
	if GameFeel.enemy_impact.weight_band(stats.room_weight) == GameFeel.EnemyImpactFeel.WeightBand.LIGHT:
		sub.clear_tug(self)
	else:
		sub.set_tug(self, _grabbed_fish.struggle_direction(), stats.room_weight, stats.move_speed)
	if _reel.tick(delta):
		sub.breach_from_hit(room_index, GameFeel.reel.miss_leak_severity, anchor_local)
	if t >= 1.0:
		_finalize_fish_catch()

## A pull attempt on the reel minigame's bead (see GameFeel.reel). Landing it
## brings the catch pull_distance_m closer (as a fraction of the distance at
## the moment it was grabbed); reaching home finalizes it.
func _attempt_pull() -> void:
	if _reel == null:
		return
	if _reel.attempt_pull():
		_reel_progress_m = minf(_reel_progress_m + GameFeel.reel.pull_distance_m, _reel_total_m)

## Delivered home alive: finished off through the normal damage pipeline
## (always lethal — see Fish.finish_catch), reusing the same carcass-drop hook
## `die()` already provides (MILESTONE_8.md Module 4 will later change what
## die() drops — zero rework needed here).
func _finalize_fish_catch() -> void:
	if not is_instance_valid(_grabbed_fish):
		return
	sub.clear_tug(self)
	var fish := _grabbed_fish
	_grabbed_fish = null
	_reel = null
	fish.finish_catch(GameFeel.reel.finish_damage)

## Called by Sub.reset_state() on implosion: an undelivered catch was never
## banked, so it's lost — released back to the wild alive, not killed.
func release_held_fish() -> void:
	sub.clear_tug(self)
	if is_instance_valid(_grabbed_fish):
		_grabbed_fish.release()
	_grabbed_fish = null
	_reel = null

## Open the cage at home: drop each catch through the keel hatch onto the claw
## room floor as a loose, carryable item. From there a crew member ferries it
## to the storage cage. (Reparenting is deferred — safe to call mid-physics.)
func _drop_into_hold() -> void:
	var n := _caught.size()
	for i in n:
		var item: SalvageItem = _caught[i]
		if not is_instance_valid(item):
			continue
		var lx := hatch_x + (float(i) - (n - 1) * 0.5) * 30.0  # spread around the s2 dropping hatch
		var local := Vector2(lx, drop_floor_y - SalvageItem.RADIUS_PX)
		item.call_deferred("drop_into_sub", sub, local)
	_caught.clear()
