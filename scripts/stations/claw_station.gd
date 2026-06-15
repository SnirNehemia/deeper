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

func _ready() -> void:
	super._ready()
	elbow_angle = deg_to_rad(GameFeel.claw.elbow_limit_deg)

func _physics_process(delta: float) -> void:
	_snap_timer = maxf(0.0, _snap_timer - delta)
	_carry_caught()

func handle_input(input: PlayerInput) -> void:
	var c: GameFeel.ClawFeel = GameFeel.claw
	var delta := get_physics_process_delta_time()
	# Excavator control: each axis drives one joint; you can move both at once.
	var s_lim := deg_to_rad(c.shoulder_limit_deg)
	var e_lim := deg_to_rad(c.elbow_limit_deg)
	shoulder_angle = clampf(
		shoulder_angle + input.move.x * deg_to_rad(c.shoulder_speed_deg) * delta,
		-s_lim, s_lim)
	elbow_angle = clampf(
		elbow_angle + input.move.y * deg_to_rad(c.elbow_speed_deg) * delta,
		-e_lim, e_lim)
	# `use` is the context action: when the cage is folded home and holding,
	# open it to drop the catch through the keel hatch into the hold; otherwise
	# snap the cage shut on whatever salvage it's over.
	if input.use_pressed:
		if is_home() and not _caught.is_empty():
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
