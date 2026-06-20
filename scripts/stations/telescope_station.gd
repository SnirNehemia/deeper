class_name TelescopeStation
extends Station

## Telescoping collector arm: a single straight arm from the hull wall, operated
## from a console in the telescope room.
##
## Controls (from any outer wall; "toward open water" is always forward):
##   A/D  — aim the arm within a clamped arc around facing_dir
##   S    — extend arm toward open water (up to reach_m)
##   W    — retract arm back toward the base
##   Q    — grab a SalvageItem in WATER state near the tip (explicit, never on-contact)
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

func _physics_process(_delta: float) -> void:
	# Keep tip item locked to the tip as the arm moves (and prune stale refs).
	if is_instance_valid(_tip_item) and not _tip_item.is_queued_for_deletion():
		_tip_item.global_position = _tip_global()
	elif _tip_item != null:
		_tip_item = null

func handle_input(input: PlayerInput) -> void:
	var feel := GameFeel.telescope
	var delta := get_physics_process_delta_time()

	# Aim: A/D (move.x) rotates the arm around facing_dir. Clamped to ±arc/2.
	var half_arc := deg_to_rad(feel.aim_arc_deg * 0.5)
	aim_angle = clampf(
		aim_angle + input.move.x * deg_to_rad(feel.aim_speed_deg) * delta,
		-half_arc, half_arc)

	# Extend/retract: S (+move.y) extends, W (-move.y) retracts.
	var max_ext := feel.reach_m * Sub.PPM
	if input.move.y > 0.0:
		extension = clampf(extension + feel.extend_speed * Sub.PPM * delta, 0.0, max_ext)
	elif input.move.y < 0.0:
		extension = clampf(extension - feel.retract_speed * Sub.PPM * delta, 0.0, max_ext)

	# Auto-deposit when the arm returns home.
	if is_home() and is_instance_valid(_tip_item):
		_try_deposit()

	# Grab on Q.
	if input.use_pressed:
		_grab()

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
func reset_cages() -> void:
	_cage_s2.clear()
	_cage_s4.clear()
	if is_instance_valid(_tip_item):
		_tip_item.queue_free()
	_tip_item = null
	aim_angle = 0.0
	extension = 0.0
