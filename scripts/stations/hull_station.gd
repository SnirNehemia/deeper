class_name HullStation
extends Station

## Conning-tower Hull station (M5-C1): a remote, slower alternative to a hand
## patch. A seated crew holds `use` to auto-patch the nearest active breach
## within GameFeel.hull_station.range_rooms (via the door/ladder graph), at
## GameFeel.hull_station.patch_time — slower than a hand-patch
## (GameFeel.water.repair_time). When the current target seals, it retargets
## the next-nearest breach in range automatically. Out of range -> idle.
## Flood-eject is inherited from Station (is_flooded()/exit()).
##
## A single tap (use_pressed) while docked emits dock_requested so the world
## can open the dry-dock screen.

signal dock_requested

var _target: Breach = null

func handle_input(input: PlayerInput) -> void:
	if input.use_pressed:
		dock_requested.emit()
	if sub == null or not input.use_held:
		_target = null
		return
	if _target == null or not sub.breaches.has(_target):
		_target = _find_nearest_breach()
	if _target == null:
		return
	var delta := get_physics_process_delta_time()
	_target.repair_progress += delta / GameFeel.hull_station.patch_time
	if _target.repair_progress >= 1.0:
		sub.remove_breach(_target)
		_target = null

## Nearest breach (by room-graph distance, then by position) within range_rooms
## of this station's room, or null if none.
func _find_nearest_breach() -> Breach:
	var reachable := sub.rooms_within(room_index, GameFeel.hull_station.range_rooms)
	var best: Breach = null
	var best_d := INF
	for breach in sub.breaches:
		if not reachable.has(breach.room):
			continue
		var d := position.distance_squared_to(breach.position)
		if d < best_d:
			best_d = d
			best = breach
	return best

func exit(crew: Crew) -> void:
	super.exit(crew)
	_target = null
