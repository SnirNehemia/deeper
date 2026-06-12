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
## the claw room's belly).
const ANCHOR_LOCAL := Vector2(0.0, Sub.LOWER_BOTTOM_Y)

## Joint angles (radians). shoulder = 0 points the upper arm straight DOWN and
## swings to either side; elbow bends the forearm relative to the upper arm.
## Start folded up at home (tip near the anchor).
var shoulder_angle: float = 0.0
var elbow_angle: float = deg_to_rad(160.0)

## Pieces currently held in the cage (each a SalvageItem.Kind). Capacity is
## GameFeel.claw.cage_capacity.
var _cage: Array[int] = []
## Brief "snap" animation timer so the cage visibly clamps shut on a grab.
var _snap_timer: float = 0.0

func _ready() -> void:
	super._ready()
	elbow_angle = deg_to_rad(GameFeel.claw.elbow_limit_deg)

func _physics_process(delta: float) -> void:
	_snap_timer = maxf(0.0, _snap_timer - delta)

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
	# `use` is the context action: dump when the cage is home, else snap it shut.
	if input.use_pressed:
		if is_home():
			_dump()
		else:
			_snap()

# --- Geometry (sub-local space) ---

func upper_len() -> float:
	return GameFeel.claw.upper_len_m * Sub.PPM

func fore_len() -> float:
	return GameFeel.claw.fore_len_m * Sub.PPM

## Elbow joint position: down the upper arm from the anchor.
func joint_local() -> Vector2:
	return ANCHOR_LOCAL + Vector2.DOWN.rotated(shoulder_angle) * upper_len()

## Cage (tip) position: down the forearm from the elbow.
func tip_local() -> Vector2:
	var upper_dir := Vector2.DOWN.rotated(shoulder_angle)
	var fore_dir := upper_dir.rotated(elbow_angle)
	return joint_local() + fore_dir * fore_len()

## Tip in world space, matching the hull's cosmetic pitch tilt (so grabbing
## lines up with what's drawn).
func _tip_global() -> Vector2:
	return sub.to_global(tip_local().rotated(sub.pitch))

# --- Cage state ---

func cage_count() -> int:
	return _cage.size()

func cage_full() -> bool:
	return _cage.size() >= GameFeel.claw.cage_capacity

## True when the cage is folded back near the keel anchor, ready to dump.
func is_home() -> bool:
	return tip_local().distance_to(ANCHOR_LOCAL) <= GameFeel.claw.home_radius_m * Sub.PPM

## How fully the cage is clamped shut (0 open .. 1 shut), for the visual.
func clamp_amount() -> float:
	if _snap_timer > 0.0:
		return 1.0
	return 1.0 if _cage.size() > 0 else 0.0

## Snap the cage shut on any salvage within reach of the tip, up to capacity.
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
		if item == null or item.is_queued_for_deletion():
			continue
		var d := tip.distance_to(item.global_position)
		if d <= grab:
			hits.append({"item": item, "d": d})
	hits.sort_custom(func(a, b): return a["d"] < b["d"])
	for h in hits:
		if cage_full():
			break
		var item: SalvageItem = h["item"]
		_cage.append(item.kind)
		item.set_deferred("monitoring", false)
		item.queue_free()

## Dump the cage into the storage pen (only when home). Stops early if the pen
## fills up — leftover catch stays in the cage until you bank at the dock.
func _dump() -> void:
	while not _cage.is_empty():
		if not sub.deposit_salvage(_cage[0]):
			break  # storage pen full
		_cage.pop_front()
