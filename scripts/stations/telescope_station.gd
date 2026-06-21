class_name TelescopeStation
extends Station

## Telescoping collector arm: a single straight arm from the hull wall, operated
## from a console in the telescope room.
##
## Controls (face-relative — see Station.face_aim_input / face_zoom_input):
##   Left/right wall: W/S aim, A extends toward open water, D retracts toward hull.
##   Top/bottom wall: A/D aim, W extends toward open water, S retracts toward hull.
##   Q    — grab a SalvageItem in WATER state near the tip (explicit, never on-contact)
## Auto-retract: when no extend/retract key is held the arm slowly returns home on
##   its own; much faster when carrying an item (speeds in GameFeel.telescope).
##
## Auto-deposit: when the arm comes home (tip within home_radius_m of the base),
## any item on the tip transfers automatically into the room's s2 cage (then s4).
## Cages full → deposit refused, item stays on tip. Banking at the dock empties
## the cages into the save file. Un-banked cage contents are lost on implosion.

## Sub-local position of the arm's pivot on the exterior hull wall (set by Sub).
var base_local: Vector2 = Vector2.ZERO
## Unit vector from the base toward open water (from room.facing). Set by Sub.
var facing_dir: Vector2 = Vector2.LEFT
## Sub-local x of the s2 and s4 onboard cages (set by Sub from _section_x).
var cage_s2_x: float = 0.0
var cage_s4_x: float = 0.0
## Sub-local y of the room's inner floor, where cage icons are drawn.
var cage_floor_y: float = 0.0

## Current aim offset (radians from facing_dir). Clamped to ±aim_arc_deg/2.
var aim_angle: float = 0.0
## Current arm extension (pixels). 0 = home; max = reach_m * PPM.
var extension: float = 0.0

## Item riding the arm tip (grabbed but not yet deposited).
var _tip_item: SalvageItem = null
## Onboard cage contents: arrays of SalvageItem.Kind (int). s2 fills first.
var _cage_s2: Array[int] = []
var _cage_s4: Array[int] = []

## MILESTONE_8.md Module 2: a live fish caught by the tip, held separately
## from `_tip_item` (it doesn't take a cage-capacity slot — a struggling
## catch is processed into a normal carcass on delivery instead).
var _grabbed_fish: Fish = null

## 2026-06-21 reel-in minigame: non-null exactly while `_grabbed_fish` is set.
## See scripts/fauna/reel_minigame.gd and GameFeel.reel (TUNING.md).
var _reel: ReelMinigame = null

## The last physics-frame index handle_input() was called on (Engine.
## get_physics_frames()) — used to detect "nobody's seated here right now" for
## the passive auto-retract below, without depending on Station.occupant
## (which headless tests never set, since they call handle_input directly).
## A 1-frame tolerance absorbs any same-tick ordering ambiguity between this
## node's own _physics_process and the seated crew's call into handle_input.
var _last_driven_frame: int = -999

func _physics_process(delta: float) -> void:
	# Keep tip item locked to the tip as the arm moves (and prune stale refs).
	if is_instance_valid(_tip_item) and not _tip_item.is_queued_for_deletion():
		_tip_item.global_position = _tip_global()
	elif _tip_item != null:
		_tip_item = null
	_carry_and_tug_fish(delta)
	# Nobody's been driving this console lately and there's no catch to reel
	# in — let an extended arm slowly fold itself home (2026-06-21 fix: this
	# used to live only inside handle_input, so it silently stopped running
	# the moment a player walked away from the station).
	if not is_instance_valid(_grabbed_fish) \
			and Engine.get_physics_frames() - _last_driven_frame > 1:
		_passive_retract(delta)

func _passive_retract(delta: float) -> void:
	var feel := GameFeel.telescope
	var carrying := is_instance_valid(_tip_item)
	var speed := feel.auto_retract_speed_carrying if carrying else feel.auto_retract_speed
	extension = clampf(extension - speed * Sub.PPM * delta, 0.0, feel.reach_m * Sub.PPM)

func handle_input(input: PlayerInput) -> void:
	_last_driven_frame = Engine.get_physics_frames()
	var feel := GameFeel.telescope
	var delta := get_physics_process_delta_time()

	# Once a live fish is hooked, normal aim/extend/retract control is
	# replaced by the reel-in minigame (see _attempt_pull) — the tip's
	# distance is driven by landed pulls, not the joystick.
	if not is_instance_valid(_grabbed_fish):
		# Aim: face-relative (W/S on left/right walls; A/D on top/bottom walls).
		var half_arc := deg_to_rad(feel.aim_arc_deg * 0.5)
		aim_angle = clampf(
			aim_angle + Station.face_aim_input(facing_dir, input) * deg_to_rad(feel.aim_speed_deg) * delta,
			-half_arc, half_arc)

		# Extend/retract: face-relative (positive = toward open water = extend).
		# Auto-retract when no key is held; faster while carrying.
		var max_ext := feel.reach_m * Sub.PPM
		var zoom := Station.face_zoom_input(facing_dir, input)
		if zoom > 0.0:
			extension = clampf(extension + feel.extend_speed * Sub.PPM * delta, 0.0, max_ext)
		elif zoom < 0.0:
			extension = clampf(extension - feel.retract_speed * Sub.PPM * delta, 0.0, max_ext)
		else:
			var carrying := is_instance_valid(_tip_item)
			var auto_speed := feel.auto_retract_speed_carrying if carrying else feel.auto_retract_speed
			extension = clampf(extension - auto_speed * Sub.PPM * delta, 0.0, max_ext)

	# Auto-deposit a tip item when the arm returns home (a held fish finalizes
	# on its own, from _carry_and_tug_fish, once fully reeled in).
	if is_home() and is_instance_valid(_tip_item):
		_try_deposit()

	# Use: reel a pull attempt if a fish is hooked, else grab.
	if input.use_pressed:
		if is_instance_valid(_grabbed_fish):
			_attempt_pull()
		else:
			_grab()
			_try_grab_fish()

# --- Geometry ---

## Arm tip position in sub-local space.
func tip_local() -> Vector2:
	return base_local + facing_dir.rotated(aim_angle) * extension

## Arm tip in world space, matching hull pitch tilt.
func _tip_global() -> Vector2:
	return sub.to_global(tip_local().rotated(sub.pitch))

## True when the tip is close enough to the base to trigger auto-deposit.
func is_home() -> bool:
	return extension <= GameFeel.telescope.home_radius_m * Sub.PPM

# --- Cage accessors (read by SubVisual) ---

func cage_s2() -> Array[int]:
	return _cage_s2

func cage_s4() -> Array[int]:
	return _cage_s4

func has_tip_item() -> bool:
	return is_instance_valid(_tip_item)

func has_grabbed_fish() -> bool:
	return is_instance_valid(_grabbed_fish)

## The active reel-in minigame, or null if nothing's hooked (read by
## SubVisual to draw the tug-rope + bead).
func reel_minigame() -> ReelMinigame:
	return _reel

func cage_count() -> int:
	return _cage_s2.size() + _cage_s4.size()

func cages_full() -> bool:
	var cap := GameFeel.telescope.cage_capacity
	return _cage_s2.size() >= cap and _cage_s4.size() >= cap

# --- Grab and deposit ---

func _grab() -> void:
	if is_instance_valid(_tip_item):
		return  # tip already occupied
	if cages_full():
		return  # no room to store a catch
	var tip := _tip_global()
	var grab_r := GameFeel.telescope.grab_radius_m * Sub.PPM
	var nearest: SalvageItem = null
	var nearest_d := INF
	for node in sub.get_tree().get_nodes_in_group("salvage"):
		var item := node as SalvageItem
		if item == null or item.is_queued_for_deletion() or not item.is_water():
			continue
		var d := tip.distance_to(item.global_position)
		if d <= grab_r and d < nearest_d:
			nearest = item
			nearest_d = d
	if nearest == null:
		return
	nearest.set_caged()
	nearest.set_deferred("monitoring", false)
	_tip_item = nearest

## MILESTONE_8.md Module 2: also try to catch a live, grabbable fish near
## the tip — independent of the salvage above (a held fish doesn't take a
## cage-capacity slot). Refuses an EnemyDef `grabbable=false` enemy, an
## already-dead one, and one already held by another arm.
func _try_grab_fish() -> void:
	if is_instance_valid(_grabbed_fish):
		return
	var tip := _tip_global()
	var grab_r := GameFeel.telescope.grab_radius_m * Sub.PPM
	var nearest_fish: Fish = null
	var nearest_d := INF
	for node in sub.get_tree().get_nodes_in_group("fish"):
		var fish := node as Fish
		if fish == null or not fish.is_grabbable():
			continue
		var d := tip.distance_to(fish.global_position)
		if d <= grab_r and d < nearest_d:
			nearest_fish = fish
			nearest_d = d
	if nearest_fish == null:
		return
	nearest_fish.grab()
	_grabbed_fish = nearest_fish
	_reel = ReelMinigame.new(nearest_fish.class_stats().room_weight)

## MILESTONE_8.md Module 2 (+ 2026-06-21 reel minigame): keep a held fish
## riding the tip and, while its weight band is Medium/Heavy, tug the sub via
## its struggle direction. Light is hard-pinned — never calls set_tug at all
## (the approved cheap path: "no tug calc"). Self-corrects if the fish was
## released/died/reset elsewhere (e.g. Fish.reset_fish() during a run reset).
## Advances the reel-in sweep; a full sweep that lands nothing opens a small
## leak at the arm's base. Reaching home finalizes the catch on its own.
func _carry_and_tug_fish(delta: float) -> void:
	if not is_instance_valid(_grabbed_fish) or not _grabbed_fish.grabbed:
		if _grabbed_fish != null:
			sub.clear_tug(self)
			_grabbed_fish = null
			_reel = null
		return
	_grabbed_fish.global_position = _tip_global()
	var stats := _grabbed_fish.class_stats()
	if GameFeel.enemy_impact.weight_band(stats.room_weight) == GameFeel.EnemyImpactFeel.WeightBand.LIGHT:
		sub.clear_tug(self)
	else:
		sub.set_tug(self, _grabbed_fish.struggle_direction(), stats.room_weight, stats.move_speed)
	if _reel.tick(delta):
		sub.breach_from_hit(room_index, GameFeel.reel.miss_leak_severity, base_local)
	if is_home():
		_finalize_fish_catch()

## A pull attempt on the reel minigame's bead (see GameFeel.reel). Landing it
## brings the catch pull_distance_m closer; reaching home finalizes it.
func _attempt_pull() -> void:
	if _reel == null:
		return
	if _reel.attempt_pull():
		extension = maxf(0.0, extension - GameFeel.reel.pull_distance_m * Sub.PPM)

## Delivered home alive: finished off through the normal damage pipeline
## (always lethal — see Fish.finish_catch), reusing the same carcass-drop hook
## `die()` already provides (MILESTONE_8.md Module 4 will later change what
## die() drops — zero rework needed here). The resulting carcass is then
## auto-collected (2026-06-21) — you already did the hard part reeling it in,
## re-grabbing the carcass it just dropped at your own feet would be busywork.
func _finalize_fish_catch() -> void:
	if not is_instance_valid(_grabbed_fish):
		return
	sub.clear_tug(self)
	var fish := _grabbed_fish
	_grabbed_fish = null
	_reel = null
	fish.finish_catch(GameFeel.reel.finish_damage)
	_auto_collect_loot(fish.last_carcass)

## Deposits a just-finished catch's carcass straight into the onboard cage —
## the same place a normal manual grab+retract would land it — skipping the
## "snap it up off the tip again" step. Still un-banked/at-risk until docked,
## same as any other catch; if both cages happen to be full, it's left
## floating, collectible the normal way once one frees up.
func _auto_collect_loot(carcass: SalvageItem) -> void:
	if not is_instance_valid(carcass):
		return
	var cap := GameFeel.telescope.cage_capacity
	if _cage_s2.size() < cap:
		_cage_s2.append(carcass.kind)
	elif _cage_s4.size() < cap:
		_cage_s4.append(carcass.kind)
	else:
		return
	carcass.queue_free()

## Transfer the tip item into the s2 cage (then s4) and free the node.
func _try_deposit() -> void:
	if not is_instance_valid(_tip_item):
		return
	var cap := GameFeel.telescope.cage_capacity
	var kind: int = _tip_item.kind
	if _cage_s2.size() < cap:
		_cage_s2.append(kind)
	elif _cage_s4.size() < cap:
		_cage_s4.append(kind)
	else:
		return  # both full — item stays on tip until the sub banks
	_tip_item.queue_free()
	_tip_item = null

## Called by Sub.try_bank() — transfer all cage contents to the save file.
func bank_cages() -> void:
	var sc := 0
	var fi := 0
	var mc := 0
	for kind in (_cage_s2 + _cage_s4):
		match kind:
			SalvageItem.Kind.SCRAP:    sc += 1
			SalvageItem.Kind.FISH:     fi += 1
			SalvageItem.Kind.MED_FISH: mc += 1
	if sc > 0 or fi > 0 or mc > 0:
		SaveData.bank(sc, fi, mc)
	_cage_s2.clear()
	_cage_s4.clear()

## Called by Sub.reset_state() — lose all un-banked contents on implosion.
## A held-but-undelivered live fish was never banked either: it's released
## back to the wild alive, not killed (MILESTONE_8.md Module 2).
func reset_cages() -> void:
	_cage_s2.clear()
	_cage_s4.clear()
	if is_instance_valid(_tip_item):
		_tip_item.queue_free()
	_tip_item = null
	sub.clear_tug(self)
	if is_instance_valid(_grabbed_fish):
		_grabbed_fish.release()
	_grabbed_fish = null
	_reel = null
	aim_angle = 0.0
	extension = 0.0
