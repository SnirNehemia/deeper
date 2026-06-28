class_name Shoal
extends Node2D

## MILESTONE_10.md — THE SHOAL: a school of tiny fish that moves and decides as
## ONE organism. This controller owns the group: it spawns N lightweight members
## (a Fish each, on Behavior.SHOAL_MEMBER), steers them every frame with
## boids-style flocking (separation / alignment / cohesion + leader-follow),
## runs a GROUP state machine, manages the leader (and promotion-on-death), and
## pools the mass-slam into a SINGLE sub.breach_from_hit so the damage spine
## stays one-path. No member ever seeks on its own — the controller assigns each
## member's `shoal_velocity` and the member just applies it.
##
## This is the codebase's first GROUP meta-entity; every enemy before it was an
## independent single body. All numeric dials live in GameFeel.flock (the M8
## spine/content split) so the whole thing stays deeper-tuner-friendly.

## The GROUP state machine (its own enum — NOT Fish.State, which the members'
## reused single-fish code still nominally carries but never runs).
##  DRIFT    — wander as a VERY LOOSE, sparse cloud around a leader (unbothered).
##  STALK    — sub spotted (within detect_range): tighten into a dense coordinated
##             school and orbit a point beside the sub, following it; after one
##             full circle, commit to the charge.
##  CHARGE   — the dense school drives at one locked hull point; on contact issue
##             exactly ONE pooled breach, then disperse.
##  DISPERSE — loosen back out while the charge cooldown runs, then → DRIFT.
##  SCATTER  — leader was killed: panic-flee briefly (harmless), then promote the
##             nearest survivor to a new leader and regroup (→ DRIFT).
##  FLEE     — terminal: thinned at/below the flee threshold → all survivors swim
##             away and go dormant (so thinning the cloud ends it, not only
##             beheading it).
enum GroupState { DRIFT, STALK, CHARGE, DISPERSE, SCATTER, FLEE }

## Set by the spawner (world.gd) before add_child.
var sub: Sub = null
var tier: EnemyDef.Class = EnemyDef.Class.SMALL
var sky_zones: Array = []
var water_surface_y: float = 0.0

var _members: Array[Fish] = []
var _leader: Fish = null
var _state: GroupState = GroupState.DRIFT
var _original_count: int = 0
## Prize multiplier the CURRENT leader carries: 1.0 for the original, scaled down
## by leader_drop_share on each promotion (a diminishing reward for re-beheading).
var _prize_mult: float = 1.0
var _charge_cooldown: float = 0.0
var _charge_timer: float = 0.0
var _charge_target: Vector2 = Vector2.ZERO
## Where the charge first locked on; the live tracking target is clamped to within
## charge_track_m of this, so the strike follows the sub only so far.
var _charge_origin: Vector2 = Vector2.ZERO
var _charge_hit_done: bool = false
## STALK orbit: _orbit_angle is the school's current angle around the sub;
## _orbit_accum tracks total swept angle so one full circle (TAU) → CHARGE.
var _orbit_angle: float = 0.0
var _orbit_accum: float = 0.0
var _scatter_timer: float = 0.0
var _flee_timer: float = 0.0
var _fled_done: bool = false
var _drift_target: Vector2 = Vector2.ZERO
var _spawn_anchor: Vector2 = Vector2.ZERO
## LOD: false while the school is dormant (far from the sub) — members' per-frame
## physics is switched off and the controller only does a cheap group-drift.
var _active: bool = true
## One-time: members get nudged out of any terrain they spawned inside on the
## first physics frame (space queries aren't safe yet in _ready).
var _settled: bool = false

func _ready() -> void:
	add_to_group("shoal")
	_spawn_anchor = global_position
	_drift_target = global_position
	var ppm := GameFeel.PIXELS_PER_METER
	var count: int = GameFeel.flock.member_count(tier)
	_original_count = count
	for _i in count:
		var m := Fish.new()
		m.behavior = Fish.Behavior.SHOAL_MEMBER
		m.current_class = tier
		m.sub = sub
		m.sky_zones = sky_zones
		m.water_surface_y = water_surface_y
		m._is_shoal_member = true
		# Spawn loosely clustered; the flocking pulls them into a cohesive cloud.
		m.position = Vector2(randf_range(-2.0, 2.0), randf_range(-1.5, 1.5)) * ppm
		add_child(m)
		_members.append(m)
	if not _members.is_empty():
		# The original leader carries the full prize and starts already crowned.
		_promote_leader(_members[0], 1.0, false)

func _physics_process(delta: float) -> void:
	if sub == null or not is_instance_valid(sub):
		return
	# First physics frame: relocate any member that spawned inside rock/sand into
	# clear water (the marker may be painted right next to terrain). Done here, not
	# in _ready, because space-state queries aren't valid that early.
	if not _settled:
		_settled = true
		_settle_members_into_water()
	# LOD: a RESTING school far from the sub goes dormant — no flocking, no
	# wall-rays, no per-member physics; just a cheap lazy group-drift — until the
	# sub comes near. Only DRIFT-state schools dormant; an engaged one is near the
	# sub by definition and stays fully alive until it disperses back to DRIFT.
	var far: bool = _dist_to_hull(_blob_pos()) > GameFeel.flock.active_range_m * GameFeel.PIXELS_PER_METER
	if _state == GroupState.DRIFT and far:
		if _active:
			_set_active(false)
		_dormant_drift(delta)
		return
	if not _active:
		_set_active(true)
	_charge_cooldown = maxf(0.0, _charge_cooldown - delta)
	_update_transitions()
	match _state:
		GroupState.DRIFT:
			_do_drift(delta)
		GroupState.STALK:
			_do_stalk(delta)
		GroupState.CHARGE:
			_do_charge(delta)
		GroupState.DISPERSE:
			_do_disperse(delta)
		GroupState.SCATTER:
			_do_scatter(delta)
		GroupState.FLEE:
			_do_flee(delta)

## Group-wide transitions checked before the per-state steering runs: terminal
## flee on thinning (takes priority), and panic-scatter the instant the leader
## is beheaded.
func _update_transitions() -> void:
	if _state == GroupState.FLEE:
		return
	if _survivor_count() <= _flee_at():
		_begin_flee()
		return
	if _state != GroupState.SCATTER and (_leader == null or not is_instance_valid(_leader) or _leader.is_dead):
		_begin_scatter()

# --- DRIFT ---------------------------------------------------------------

func _do_drift(delta: float) -> void:
	var ppm := GameFeel.PIXELS_PER_METER
	var fl := GameFeel.flock
	var free := _free_members()
	if free.is_empty():
		return
	_ensure_leader(free)
	# The leader cruises toward a renewed target within drift_roam_m of the spawn
	# anchor, trailing the aligned school behind it so the whole shoal sweeps
	# across an area as one organism. Renew a bit before arriving so it never
	# stalls — the motion stays continuous and flowing. The roam is wider
	# horizontally than vertically (a school favours sweeping sideways).
	if _leader.global_position.distance_to(_drift_target) < 2.5 * ppm:
		var r := fl.drift_roam_m * ppm
		_drift_target = _spawn_anchor + Vector2(randf_range(-r, r), randf_range(-r * 0.45, r * 0.45))
		# Never aim the school up into the water surface.
		if water_surface_y > 0.0:
			_drift_target.y = maxf(_drift_target.y, water_surface_y + fl.surface_avoid_m * ppm)
	# Loose by default: members trail the leader with LOW cohesion, so the school
	# is a sparse, spread-out drift until it notices the sub. The (expensive)
	# steering recomputes only on flock frames; members coast in between.
	if _flock_frame():
		for m: Fish in free:
			var seek := _drift_target if m == _leader else _leader.global_position
			m.shoal_velocity = _steer(m, free, seek, fl.leader_follow_weight, fl.drift_cohesion_weight, fl.drift_speed_mps)
	# Spot the sub (within the attention ring, off the post-charge cooldown) →
	# tighten up and start stalking it.
	if _charge_cooldown <= 0.0 and _dist_to_hull(_centroid(free)) <= fl.detect_range_m * ppm:
		_enter_stalk(free)

# --- STALK (circle the sub) ----------------------------------------------

func _enter_stalk(free: Array) -> void:
	_state = GroupState.STALK
	# Start the orbit beside wherever the school currently is, relative to the sub.
	_orbit_angle = (_centroid(free) - sub.global_position).angle()
	_orbit_accum = 0.0

func _do_stalk(delta: float) -> void:
	var ppm := GameFeel.PIXELS_PER_METER
	var fl := GameFeel.flock
	var free := _free_members()
	if free.is_empty():
		return
	_ensure_leader(free)
	# Disengage only if the sub slips well away (hysteresis) → back to loose drift.
	if _dist_to_hull(_centroid(free)) > fl.lose_range_m * ppm:
		_state = GroupState.DRIFT
		_drift_target = _centroid(free)
		return
	# Slide to a point to the SIDE of the sub and orbit it, following it as it
	# moves. The DENSE cohesion (vs. drift) packs the school into a tight,
	# coordinated knot circling the hull.
	_orbit_angle += fl.orbit_speed_rad * delta
	_orbit_accum += fl.orbit_speed_rad * delta
	var orbit_target := sub.global_position + Vector2.from_angle(_orbit_angle) * fl.stalk_offset_m * ppm
	if _flock_frame():
		for m: Fish in free:
			m.shoal_velocity = _steer(m, free, orbit_target, fl.stalk_cohesion_weight, fl.stalk_cohesion_weight, fl.stalk_speed_mps)
	# After one full sweep around the sub, commit to the charge.
	if _orbit_accum >= TAU:
		_charge_origin = _nearest_hull_point(_centroid(free))
		_charge_target = _charge_origin
		_charge_timer = fl.charge_timeout_s
		_charge_hit_done = false
		_state = GroupState.CHARGE

# --- CHARGE --------------------------------------------------------------

func _do_charge(delta: float) -> void:
	var ppm := GameFeel.PIXELS_PER_METER
	var fl := GameFeel.flock
	var free := _free_members()
	if free.is_empty():
		return
	var center := _centroid(free)
	# Track the sub as a coordinated ball, but only within charge_track_m of where
	# the charge first locked on: re-aim at the sub's live nearest hull point,
	# clamped to that range. A small jink gets followed; a big/early dodge puts
	# the sub past the range, so the ball reaches the clamped edge and whiffs.
	var desired := _nearest_hull_point(center)
	var off := desired - _charge_origin
	var maxr := fl.charge_track_m * ppm
	if off.length() > maxr:
		desired = _charge_origin + off.normalized() * maxr
	_charge_target = desired
	for m: Fish in free:
		var to_t := _charge_target - m.global_position
		var dir := to_t.normalized() if to_t != Vector2.ZERO else Vector2.ZERO
		m.shoal_velocity = dir * fl.charge_speed_mps * ppm
	_charge_timer -= delta
	# The hit lands ONLY on actual contact with the sub's CURRENT hull — measured
	# live, never on merely reaching the tracked target. Combined with the capped
	# tracking above, a small dodge gets chased down and hit, while a big/early
	# dodge leaves the ball striking the clamped edge in empty water — no breach,
	# no shove.
	if not _charge_hit_done and _dist_to_hull(center) <= fl.charge_contact_m * ppm:
		_deliver_charge(center)
		_begin_disperse()
	elif center.distance_to(_charge_target) <= fl.charge_contact_m * ppm or _charge_timer <= 0.0:
		# Reached the committed spot (or ran out of time) without touching the
		# hull — the sub dodged. Whiff: just disperse, no damage.
		_begin_disperse()

## The charge's single pooled hit: ONE breach_from_hit (the same M5 spine a bite
## uses) at the ACTUAL current contact point, plus one combined ram shove. Never
## N per-fish bites, and never a phantom hit on a locked spot the sub has left —
## this only runs once the centroid is genuinely against the live hull.
func _deliver_charge(center: Vector2) -> void:
	_charge_hit_done = true
	var hull_point := _nearest_hull_point(center)
	var local := sub.to_local(hull_point)
	sub.breach_from_hit(sub.nearest_room(local), GameFeel.flock.charge_damage, local)
	var dir := center.direction_to(hull_point)
	if dir != Vector2.ZERO:
		# A gentle, flat shove (tunable) — not scaled up by member count, so a big
		# school bumps the sub rather than launching it.
		sub.apply_ram_knockback(dir, GameFeel.flock.charge_knockback_weight, GameFeel.flock.charge_speed_mps)

# --- DISPERSE ------------------------------------------------------------

func _begin_disperse() -> void:
	_state = GroupState.DISPERSE
	_charge_cooldown = GameFeel.flock.charge_cooldown_s

func _do_disperse(delta: float) -> void:
	var ppm := GameFeel.PIXELS_PER_METER
	var fl := GameFeel.flock
	var free := _free_members()
	if free.is_empty():
		return
	_ensure_leader(free)
	# Loosen back out (low cohesion): ease away from the sub while the cooldown runs.
	if _flock_frame():
		for m: Fish in free:
			var away := sub.global_position.direction_to(m.global_position)
			var seek := m.global_position + away * 4.0 * ppm
			m.shoal_velocity = _steer(m, free, seek, fl.drift_cohesion_weight, fl.drift_cohesion_weight, fl.drift_speed_mps)
	if _charge_cooldown <= 0.0:
		_state = GroupState.DRIFT
		_drift_target = _centroid(free)

# --- SCATTER (leader killed) --------------------------------------------

func _begin_scatter() -> void:
	_state = GroupState.SCATTER
	_scatter_timer = GameFeel.flock.scatter_time_s
	if _leader != null and is_instance_valid(_leader):
		_leader._is_leader = false
	_leader = null

func _do_scatter(delta: float) -> void:
	var ppm := GameFeel.PIXELS_PER_METER
	var free := _free_members()
	for m: Fish in free:
		var away := sub.global_position.direction_to(m.global_position)
		if away == Vector2.ZERO:
			away = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		var sv := _avoid_surface(m, away * GameFeel.flock.scatter_speed_mps * ppm, GameFeel.flock.scatter_speed_mps)
		m.shoal_velocity = _avoid_terrain(m, sv, GameFeel.flock.scatter_speed_mps)
	_scatter_timer -= delta
	if _scatter_timer <= 0.0:
		if free.is_empty():
			return  # nobody free to promote yet — wait (a grab may free up / a flee may trigger)
		# Promote the survivor nearest the cloud's centre; it carries a REDUCED
		# share of the prize (diminishing each beheading) and grows its crown in.
		var newl := _nearest_free_to(_centroid(free), free)
		_promote_leader(newl, _prize_mult * GameFeel.flock.leader_drop_share, true)
		_state = GroupState.DRIFT
		_drift_target = _centroid(free)

# --- FLEE (thinned out) --------------------------------------------------

func _begin_flee() -> void:
	_state = GroupState.FLEE
	_flee_timer = GameFeel.flock.flee_despawn_s
	if _leader != null and is_instance_valid(_leader):
		_leader._is_leader = false
	_leader = null

func _do_flee(delta: float) -> void:
	if _fled_done:
		return
	var ppm := GameFeel.PIXELS_PER_METER
	for m: Fish in _free_members():
		var away := sub.global_position.direction_to(m.global_position)
		if away == Vector2.ZERO:
			away = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		var fv := _avoid_surface(m, away * GameFeel.flock.flee_speed_mps * ppm, GameFeel.flock.flee_speed_mps)
		m.shoal_velocity = _avoid_terrain(m, fv, GameFeel.flock.flee_speed_mps)
	_flee_timer -= delta
	if _flee_timer <= 0.0:
		# Gone for good. Members go dormant (kept, not freed) so a run reset can
		# revive the whole encounter via reset_shoal().
		for m: Fish in _members:
			if is_instance_valid(m) and not m.is_dead:
				m.visible = false
				m.set_deferred("monitoring", false)
				m.set_deferred("monitorable", false)
				m.shoal_velocity = Vector2.ZERO
		_fled_done = true

# --- Leader management ----------------------------------------------------

## Make `m` the leader: tougher (extra hp), carrying `prize_mult` of the prize,
## and (if `animate`) growing its crown spikes in from nothing.
func _promote_leader(m: Fish, prize_mult: float, animate: bool) -> void:
	if m == null or not is_instance_valid(m):
		return
	_leader = m
	_prize_mult = prize_mult
	m._is_leader = true
	m._leader_prize_mult = prize_mult
	m._leader_anim = 0.0 if animate else 1.0
	m.hp_max = m.class_stats().hp + GameFeel.flock.leader_extra_hp
	m.hp = m.hp_max

## Safety net: if the cloud is somehow leaderless mid-state (and not already
## scattering), crown the first free member so steering still has a focus. Normal
## leader-death promotion happens through SCATTER, not here.
func _ensure_leader(free: Array) -> void:
	if _leader != null and is_instance_valid(_leader) and not _leader.is_dead:
		return
	if free.is_empty():
		return
	_promote_leader(free[0], _prize_mult, false)

# --- Boids steering -------------------------------------------------------

## Whether to recompute the flocking steering this frame (MILESTONE_10 perf):
## true only every flock_update_interval frames, staggered per school by its
## instance id so different schools update on different frames. Members coast on
## their last velocity on the off-frames, halving (or more) the active O(N²) cost
## with no visible change. The charge/scatter/flee drives ignore this and steer
## every frame, since those need per-frame precision.
func _flock_frame() -> bool:
	var interval: int = maxi(1, GameFeel.flock.flock_update_interval)
	return (Engine.get_physics_frames() + int(get_instance_id())) % interval == 0

## One member's steering for this frame, in px/s. Combines separation /
## alignment / cohesion among `neighbors` with a seek toward `seek_target`
## (the leader, the orbit point, or a flee point) and a little wander, then
## normalizes to `max_speed_mps` and steers clear of the surface + terrain.
## `cohesion_w` is passed per-state so DRIFT can be loose/sparse and STALK dense.
## O(n²) over the members, but n ≤ elite_count (40), so it's cheap.
func _steer(m: Fish, neighbors: Array, seek_target: Vector2, seek_weight: float, cohesion_w: float, max_speed_mps: float) -> Vector2:
	var ppm := GameFeel.PIXELS_PER_METER
	var fl := GameFeel.flock
	var sep := Vector2.ZERO
	var ali := Vector2.ZERO
	var coh := Vector2.ZERO
	var n := 0
	for o: Fish in neighbors:
		if o == m:
			continue
		var d := m.global_position.distance_to(o.global_position)
		n += 1
		ali += o.shoal_velocity
		coh += o.global_position
		if d < fl.separation_radius_m * ppm and d > 0.001:
			# Scale the push by CLOSENESS (full at contact, zero at the radius
			# edge) and DON'T normalize the sum — so two members nearly on top of
			# each other shove apart hard, instead of every neighbour pushing the
			# same amount and letting them settle stacked.
			var closeness := 1.0 - d / (fl.separation_radius_m * ppm)
			sep += (m.global_position - o.global_position).normalized() * closeness
	var steer := Vector2.ZERO
	if sep != Vector2.ZERO:
		steer += sep * fl.separation_weight
	if n > 0:
		if ali != Vector2.ZERO:
			steer += ali.normalized() * fl.alignment_weight
		coh /= n
		var to_coh := coh - m.global_position
		if to_coh != Vector2.ZERO:
			steer += to_coh.normalized() * cohesion_w
	var to_seek := seek_target - m.global_position
	if to_seek != Vector2.ZERO:
		steer += to_seek.normalized() * seek_weight
	steer += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * fl.wander
	# Ease from the member's current velocity toward the new steering, so it
	# carries momentum and turns smoothly (a real school flows; it doesn't snap a
	# fresh heading every frame).
	var target := Vector2.ZERO if steer == Vector2.ZERO else steer.normalized() * max_speed_mps * ppm
	target = _avoid_surface(m, target, max_speed_mps)
	target = _avoid_terrain(m, target, max_speed_mps)
	return m.shoal_velocity.lerp(target, fl.turn_smoothing)

## Keep a member off the water surface: within surface_avoid_m of it (or above
## it), bias `vel` downward — full strength at/over the surface, fading to zero
## at the band edge — then cap back to `cap_mps`. Without this the school steers
## up into the surface and the per-member _is_blocked_by_sky guard freezes it
## there (it blocks upward motion but never redirects it). No-op when there's no
## surface (water_surface_y <= 0, e.g. the open-water demo).
func _avoid_surface(m: Fish, vel: Vector2, cap_mps: float) -> Vector2:
	if water_surface_y <= 0.0:
		return vel
	var ppm := GameFeel.PIXELS_PER_METER
	var band := GameFeel.flock.surface_avoid_m * ppm
	var depth := m.global_position.y - water_surface_y  # >0 below surface, <0 above
	if depth >= band:
		return vel
	var push := clampf((band - depth) / band, 0.0, 1.0)
	vel.y += cap_mps * ppm * push  # +y is downward
	return vel.limit_length(cap_mps * ppm)

## Keep a member off terrain (sand/rock), the same way _avoid_surface keeps it
## off the water surface. Three short "feeler" rays (forward + two angled) probe
## the TERRAIN layer ahead of where the member is heading; any hit adds a push
## away along the wall's normal, scaled by how close it is. Without this the
## per-member terrain block would just freeze a fish steered straight into rock.
func _avoid_terrain(m: Fish, vel: Vector2, cap_mps: float) -> Vector2:
	var ppm := GameFeel.PIXELS_PER_METER
	var look := GameFeel.flock.obstacle_avoid_m * ppm
	if look <= 0.0:
		return vel
	# Re-probe only every obstacle_check_interval frames, staggered per member by
	# its instance id, and reuse the cached veer in between — this is the big perf
	# win (raycasts were ~40% of frame time with many schools). The hard per-step
	# terrain block in _shoal_member_move still runs every frame, so a member can't
	# slip into rock between probes.
	var interval: int = maxi(1, GameFeel.flock.obstacle_check_interval)
	if (Engine.get_physics_frames() + int(m.get_instance_id())) % interval == 0:
		m._shoal_terrain_push = _probe_terrain(m, vel, look)
	if m._shoal_terrain_push == Vector2.ZERO:
		return vel
	vel += m._shoal_terrain_push * cap_mps * ppm
	return vel.limit_length(cap_mps * ppm)

## Cast the three terrain feeler rays once and return the (normalized) push away
## from any wall ahead, or ZERO. Called only on a member's probe frame (see above).
func _probe_terrain(m: Fish, vel: Vector2, look: float) -> Vector2:
	var heading := vel.normalized() if vel != Vector2.ZERO else Vector2(m._facing, 0.0)
	var space := get_world_2d().direct_space_state
	var push := Vector2.ZERO
	for ang in [0.0, 0.5, -0.5]:
		var dir := heading.rotated(ang)
		var q := PhysicsRayQueryParameters2D.create(m.global_position, m.global_position + dir * look, Layers.TERRAIN)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var dist: float = m.global_position.distance_to(hit["position"])
			push += (hit["normal"] as Vector2) * clampf(1.0 - dist / look, 0.0, 1.0)
	return push.normalized() if push != Vector2.ZERO else Vector2.ZERO

# --- LOD: dormant while far -----------------------------------------------

## Cheap position estimate for the range check (the leader, or any survivor) —
## O(1), no centroid pass needed every frame.
func _blob_pos() -> Vector2:
	if _leader != null and is_instance_valid(_leader) and not _leader.is_dead:
		return _leader.global_position
	var m := _first_alive()
	return m.global_position if m != null else global_position

func _first_alive() -> Fish:
	for m: Fish in _members:
		if is_instance_valid(m) and not m.is_dead:
			return m
	return null

# --- Spawn-clear-of-terrain ----------------------------------------------

## Nudge any member whose BODY overlaps terrain (or that's above water) out to the
## nearest clear water spot, so a school painted next to rock doesn't strand fish
## embedded in the wall where they can't move. Uses each member's own terrain
## shapecast (the exact shape/mask the movement uses) so it catches body-EDGE
## overlaps, not just centre-in-rock — that was the gap that left fish stuck.
func _settle_members_into_water() -> void:
	var ppm := GameFeel.PIXELS_PER_METER
	for m: Fish in _members:
		if not is_instance_valid(m):
			continue
		if not _member_blocked(m, m.global_position):
			continue
		var origin := m.global_position
		var placed := false
		for ring in range(1, 24):
			var radius := float(ring) * 0.5 * ppm
			for a in 12:
				var cand := origin + Vector2.from_angle(a * TAU / 12.0) * radius
				if not _member_blocked(m, cand):
					m.global_position = cand
					placed = true
					break
			if placed:
				break
		if not placed:
			m.global_position = origin   # deeply buried marker — give up (map-authoring issue)

## True if member `m`'s BODY at `pos` overlaps impassable terrain, or `pos` is
## above the water surface. Probes with the member's own terrain shapecast (so it
## matches exactly what blocks its movement), restoring its position afterward.
func _member_blocked(m: Fish, pos: Vector2) -> bool:
	if water_surface_y > 0.0 and pos.y < water_surface_y:
		return true
	var prev := m.global_position
	m.global_position = pos
	m._terrain_cast.target_position = Vector2.ZERO
	m._terrain_cast.force_shapecast_update()
	var blocked := m._terrain_cast_blocks()
	m.global_position = prev
	return blocked

## Switch the whole school between full (active) and dormant. Dormant turns OFF
## each member's per-frame physics (its movement shapecast + redraw) and its
## hit-sensor — so a far/off-screen school costs almost nothing; the controller
## drifts it as a cheap rigid group instead. Activating restores all of that.
func _set_active(active: bool) -> void:
	_active = active
	for m: Fish in _members:
		if not is_instance_valid(m) or m.is_dead:
			continue
		m.set_physics_process(active)
		m.set_deferred("monitoring", active)
		m.set_deferred("monitorable", active)
		if active:
			m.shoal_velocity = Vector2.ZERO

## Dormant behaviour: lazily drift the whole school toward a wandering target as a
## rigid group — O(N) position adds, no flocking, no raycasts, no per-member
## physics. Keeps the school looking alive off-screen for almost no cost.
func _dormant_drift(delta: float) -> void:
	var ppm := GameFeel.PIXELS_PER_METER
	var fl := GameFeel.flock
	var anchor := _first_alive()
	if anchor == null:
		return
	# Safety net: dormant members can't depenetrate themselves (physics is off),
	# so periodically (staggered per school) re-settle any that ended up in rock —
	# cheap (one shapecast per member, ~twice a second), and self-corrects anything
	# the rigid drift may have nudged into terrain.
	if (Engine.get_physics_frames() + int(get_instance_id())) % 30 == 0:
		_settle_members_into_water()
	if anchor.global_position.distance_to(_drift_target) < 2.0 * ppm:
		_drift_target = _pick_dormant_target(anchor)
	var step := anchor.global_position.direction_to(_drift_target) * fl.drift_speed_mps * 0.5 * ppm * delta
	# Don't rigidly shove the group into rock: if the next group position is
	# blocked, renew the target and hold this frame.
	if _member_blocked(anchor, anchor.global_position + step):
		_drift_target = _pick_dormant_target(anchor)
		return
	for m: Fish in _members:
		if is_instance_valid(m) and not m.is_dead:
			m.global_position += step

## A dormant wander target within roam of the spawn anchor that's in open water
## (below the surface and not in terrain); falls back to staying put if none found.
func _pick_dormant_target(anchor: Fish) -> Vector2:
	var ppm := GameFeel.PIXELS_PER_METER
	var fl := GameFeel.flock
	var r := fl.drift_roam_m * ppm
	for _i in 8:
		var cand := _spawn_anchor + Vector2(randf_range(-r, r), randf_range(-r * 0.45, r * 0.45))
		if water_surface_y > 0.0:
			cand.y = maxf(cand.y, water_surface_y + fl.surface_avoid_m * ppm)
		if not _member_blocked(anchor, cand):
			return cand
	return anchor.global_position

# --- Membership queries ---------------------------------------------------

## Members still in the school (not killed). Grabbed members count as survivors
## (they're alive, just held), so a grab alone never trips the flee threshold.
func _survivor_count() -> int:
	var n := 0
	for m: Fish in _members:
		if is_instance_valid(m) and not m.is_dead:
			n += 1
	return n

## Members the controller actively steers: alive AND not grabbed. A grabbed
## member has left the flock (it's riding the claw), so it isn't steered.
func _free_members() -> Array:
	var out: Array = []
	for m: Fish in _members:
		if is_instance_valid(m) and not m.is_dead and not m.grabbed:
			out.append(m)
	return out

## Survivor headcount at/below which the whole school flees for good.
func _flee_at() -> int:
	return int(round(_original_count * GameFeel.flock.flee_threshold_frac))

func _centroid(list: Array) -> Vector2:
	if list.is_empty():
		return global_position
	var sum := Vector2.ZERO
	for m: Fish in list:
		sum += m.global_position
	return sum / float(list.size())

func _nearest_free_to(point: Vector2, free: Array) -> Fish:
	var best: Fish = null
	var best_d := INF
	for m: Fish in free:
		var d := m.global_position.distance_to(point)
		if d < best_d:
			best_d = d
			best = m
	return best

# --- Hull geometry (mirrors Fish's nearest-hull-point math) ---------------

func _dist_to_hull(world_pos: Vector2) -> float:
	return world_pos.distance_to(_nearest_hull_point(world_pos))

func _nearest_hull_point(world_pos: Vector2) -> Vector2:
	var local := sub.to_local(world_pos)
	var best := local
	var best_dist := INF
	for rect: Rect2 in sub.hull_rects():
		var clamped := Vector2(
			clampf(local.x, rect.position.x, rect.end.x),
			clampf(local.y, rect.position.y, rect.end.y))
		var d := local.distance_to(clamped)
		if d < best_dist:
			best_dist = d
			best = clamped
	return sub.to_global(best)

# --- Run reset ------------------------------------------------------------

## Restore the whole encounter on a run reset (world.reset_run calls this on the
## "shoal" group AFTER reviving the members via the "fish" group's reset_fish).
## reset_fish has already put each member back at its home with base hp; here we
## just clear the leader/flee state and re-crown the original leader.
func reset_shoal() -> void:
	_state = GroupState.DRIFT
	_prize_mult = 1.0
	_charge_cooldown = 0.0
	_charge_timer = 0.0
	_charge_hit_done = false
	_orbit_accum = 0.0
	_scatter_timer = 0.0
	_flee_timer = 0.0
	_fled_done = false
	_active = true   # known-active after a reset; the LOD gate re-dormants if still far
	_drift_target = _spawn_anchor
	for m: Fish in _members:
		if not is_instance_valid(m):
			continue
		m.sub = sub      # re-point at the (possibly rebuilt) sub the controller now holds
		m._is_leader = false
		m._leader_prize_mult = 1.0
		m._leader_anim = 1.0
		m.shoal_velocity = Vector2.ZERO
		m._shoal_terrain_push = Vector2.ZERO
		m.set_physics_process(true)
		m.visible = true
		m.set_deferred("monitoring", true)
		m.set_deferred("monitorable", true)
	var alive: Array = []
	for m: Fish in _members:
		if is_instance_valid(m) and not m.is_dead:
			alive.append(m)
	if not alive.is_empty():
		_promote_leader(alive[0], 1.0, false)
