class_name Fish
extends Area2D

## A small territorial fish (~1 m): idles/patrols around its home point, and
## if the sub enters its territory it chases and bites the hull (drip-tier
## breach per bite, with a recover pause between passes). It always breaks
## off and swims home when the sub leaves. One torpedo hit kills it (cartoon
## pop + bubbles); it stays gone until the run resets.
##
## AI is deliberately dumb: distance checks + four states, no pathfinding.
## It can't enter the cave interior — avoiding it by piloting is valid play.

enum State { PATROL, CHASE, RECOVER, RETURN, HUNT, LURK, WINDUP, LUNGE, KITE, INFLATE }

## MILESTONE_8.md Module 0: the AI pattern, independent of the EnemyDef class
## tier below. TERRITORIAL = M2 behaviour (chase trigger only inside
## territory, always breaks off and swims home). HUNTER (design doc §7): once
## locked on (from hunter_detect_m), chases anywhere, giving up only after
## hunter_lose_time spent beyond hunter_lose_m. CHASER ("basic_chaser"):
## relentless once locked on (from chaser_detect_m) — never gives up; only a
## successful bite earns the crew a chaser_backoff_time breather. AMBUSHER
## (MILESTONE_9.md — the Sand Lurker): lies buried and motionless with an
## INVISIBLE detect range; when the sub enters it, a brief tremor windup, then
## a fast committed lunge for a single bite, then it darts off and re-buries
## somewhere new (never the same spot). SPITTER (MILESTONE_9.md — the Spitter
## puffer): a kiter that keeps a standoff band, inflates to a full circle, then
## fires destructible bubbles at the sub (more from bigger ones); juicy and
## vulnerable while inflated.
enum Behavior { TERRITORIAL, HUNTER, CHASER, AMBUSHER, SPITTER }

const DEFAULT_ENEMY_DEF_PATH := "res://data/enemies/reference_fish.tres"
## 2026-06-24: the chaser was always meant to be its own species (it was just
## sharing the reference fish's Big-class block for convenience) — split out
## so it can carry its own currency_color independent of the territorial/
## hunter fish, per Snir's call.
const CHASER_ENEMY_DEF_PATH := "res://data/enemies/chaser_fish.tres"
## MILESTONE_9.md — the Sand Lurker is its own species (sand body; drops the
## shared "brown" fauna currency, 2026-06-26), bound to the AMBUSHER behavior
## the same way the chaser is bound to CHASER.
const LURKER_ENEMY_DEF_PATH := "res://data/enemies/lurker_fish.tres"
## MILESTONE_9.md — the Spitter is its own species (dark-brown body, "brown"
## currency), bound to the SPITTER behavior.
const SPITTER_ENEMY_DEF_PATH := "res://data/enemies/spitter_fish.tres"
## Loaded lazily (not preloaded as a const) — preloading a custom-scripted
## .tres at fish.gd's own parse time raced the engine's global-class
## registration in headless runs and silently produced a scriptless Resource.
static var _default_enemy_def: EnemyDef = null
static var _chaser_enemy_def: EnemyDef = null
static var _lurker_enemy_def: EnemyDef = null
static var _spitter_enemy_def: EnemyDef = null

## The sub it guards against (set at placement).
var sub: Sub = null
## Territory center; the fish spawns here and always swims back here.
var home: Vector2

## Placement data: which AI pattern this fish runs (see Behavior above).
var behavior: Behavior = Behavior.TERRITORIAL

## MILESTONE_8.md Module 0: per-species stats live in an EnemyDef resource,
## selected by class tier (Small/Big/Elite) — not hard-coded here. Defaults to
## the promoted reference fish; placement data assigns both independently of
## `behavior` (today's chaser spawns happen to use the Big tier for its
## higher HP, but that's a calling convention, not a rule baked in here).
var enemy_def: EnemyDef = null
var current_class: EnemyDef.Class = EnemyDef.Class.SMALL

## Sky zones from the map (pocket zones only) and the global water surface y.
## Fish stay below water_surface_y and cannot enter cave air pockets.
var sky_zones: Array = []
var water_surface_y: float = 0.0

var state: State = State.PATROL
var is_dead: bool = false
var _hunter_lose_timer: float = 0.0

## MILESTONE_8.md Module 2: true while held by a claw/telescope arm. A
## grabbed fish stops running its own AI/movement entirely — the holding
## station drives its position (riding the tip, like a SalvageItem) and
## reads `class_stats()`/`struggle_direction()` each frame to tug the sub.
var grabbed: bool = false

## M5: HP. Torpedo damage == hp_max (one-shot); bullet needs a burst. Set in
## _ready (after `enemy_def`/`current_class` are assigned by the placer) from
## the active class block's `hp`.
var hp_max: float = 5.0
var hp: float = hp_max

var _facing: float = 1.0
var _patrol_target: Vector2
var _bite_cooldown: float = 0.0
var _ranged_cooldown: float = 0.0
var _recover_dir: Vector2 = Vector2.ZERO
var _wobble: float = 0.0
var _hit_flash: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
## 2026-06-24: a fish stranded in open air (above water_surface_y, or inside
## an air pocket's sky zone) falls under plain gravity, no AI steering — it
## cannot swim in open air, only in water. Accumulates while airborne, reset
## to zero the instant it's back in the water.
var _fall_velocity: float = 0.0
var _stun_timer: float = 0.0
var _terrain_cast: ShapeCast2D
## True once a chaser has locked on — keeps the detection ring hidden even
## during RECOVER (when state briefly leaves HUNT between attacks).
var _has_spotted: bool = false

## MILESTONE_9.md — AMBUSHER (Sand Lurker) state. _windup_timer counts down the
## tremor tell; _lunge_dir is the committed straight-line strike direction
## (locked at the windup→lunge transition, so the lunge can be dodged);
## _lunge_origin is where the lunge began, to measure its commit distance.
var _windup_timer: float = 0.0
var _lunge_dir: Vector2 = Vector2.ZERO
var _lunge_origin: Vector2 = Vector2.ZERO

## MILESTONE_9.md — SPITTER (Spitter puffer) state. _inflate_timer ramps the
## puff-up; _inflate_cooldown gates re-inflation after a volley; _inflated is
## true through the whole puff-up (the "juicy target" window — extra damage
## taken + bonus currency if popped before it fires).
var _inflate_timer: float = 0.0
var _inflate_cooldown: float = 0.0
var _inflated: bool = false

func _ready() -> void:
	add_to_group("fish")
	home = global_position
	_patrol_target = home
	collision_layer = Layers.FISH
	collision_mask = Layers.PROJECTILE | Layers.SUB_HULL
	monitoring = true
	monitorable = true
	if enemy_def == null:
		if behavior == Behavior.CHASER:
			if _chaser_enemy_def == null:
				_chaser_enemy_def = load(CHASER_ENEMY_DEF_PATH)
			enemy_def = _chaser_enemy_def
		elif behavior == Behavior.AMBUSHER:
			if _lurker_enemy_def == null:
				_lurker_enemy_def = load(LURKER_ENEMY_DEF_PATH)
			enemy_def = _lurker_enemy_def
		elif behavior == Behavior.SPITTER:
			if _spitter_enemy_def == null:
				_spitter_enemy_def = load(SPITTER_ENEMY_DEF_PATH)
			enemy_def = _spitter_enemy_def
		else:
			if _default_enemy_def == null:
				_default_enemy_def = load(DEFAULT_ENEMY_DEF_PATH)
			enemy_def = _default_enemy_def
	hp_max = class_stats().hp
	hp = hp_max
	# MILESTONE_8.md Module 3: class tier visibly changes size (the Module 0
	# `size_scale` field's first real consumer) — art stays identical at every
	# tier (ART-PASS FLAG), just scaled.
	var length_m := _base_length_m() * class_stats().size_scale
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = length_m * GameFeel.PIXELS_PER_METER * 0.5
	shape.shape = circle
	add_child(shape)
	# ShapeCast for terrain: fish can't swim through rock.
	_terrain_cast = ShapeCast2D.new()
	var cast_shape := CircleShape2D.new()
	cast_shape.radius = circle.radius * 0.85  # slightly smaller to avoid edge false-positives
	_terrain_cast.shape = cast_shape
	_terrain_cast.collision_mask = Layers.TERRAIN
	_terrain_cast.enabled = true
	add_child(_terrain_cast)
	area_entered.connect(_on_area_entered)
	_check_elite_ability()
	# AMBUSHER starts buried, not patrolling. Set after _check_elite_ability so
	# the Elite-tier RECOVER nudge in there can't override it.
	if behavior == Behavior.AMBUSHER:
		state = State.LURK

## The species' base body length in metres (before the class size_scale), used
## by both the collision shape (_ready) and the drawn silhouette (_draw).
func _base_length_m() -> float:
	match behavior:
		Behavior.CHASER:
			return PlaceholderArt.CHASER_LENGTH_M
		Behavior.AMBUSHER:
			return PlaceholderArt.LURKER_LENGTH_M
		Behavior.SPITTER:
			return PlaceholderArt.SPITTER_LENGTH_M
		_:
			return PlaceholderArt.FISH_LENGTH_M

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if grabbed:
		# Position/visuals are driven by the holding station each frame
		# (mirrors how a caught SalvageItem rides the tip); no AI runs.
		queue_redraw()
		return
	if _try_depenetrate_from_terrain(delta):
		# Embedded in rock right now (e.g. knocked into a wall) — push back
		# out along the wall's normal instead of running AI this frame. AI
		# isn't safe to run here: a per-step terrain block that's bypassed
		# whenever "we're already stuck" would let an AI still trying to swim
		# INTO the wall re-trigger that bypass every single frame, walking
		# straight through it. Depenetrating first guarantees AI below only
		# ever runs once the fish is actually clear again.
		queue_redraw()
		return
	var ppm: float = GameFeel.PIXELS_PER_METER
	if _in_sky():
		var fall_step := Vector2(0, _fall_velocity * delta)
		_terrain_cast.target_position = fall_step
		_terrain_cast.force_shapecast_update()
		if not _terrain_cast.is_colliding():
			# Still genuinely falling through open air: plain gravity, no
			# steering, no AI this frame.
			_fall_velocity += GameFeel.sub.surface_gravity * ppm * delta
			global_position += fall_step
			queue_redraw()
			return
		# Landed on something solid while still nominally "in the sky" (e.g. a
		# pocket's own rock floor): DON'T return early here. `_in_sky()` alone
		# never turns false in this case — the fish is still above the local
		# water line — so if we kept short-circuiting every frame it would
		# freeze there motionless forever, looking exactly like a fish stuck
		# "on top of" the rocks. Fall through to normal AI instead; its own
		# sky/terrain escape guards below already know how to work it back
		# toward real water from here (and gravity resumes the instant AI
		# opens up a path to fall through again).
	_fall_velocity = 0.0
	var feel: GameFeel.FishFeel = GameFeel.fish
	_wobble += delta
	_bite_cooldown = maxf(0.0, _bite_cooldown - delta)
	_inflate_cooldown = maxf(0.0, _inflate_cooldown - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	if _knockback != Vector2.ZERO:
		var knockback_step := _knockback * delta
		# A hit near a wall used to be able to knock the fish straight into
		# rock with no terrain check at all, embedding it there — the
		# _swim_toward guard above stops it from being trapped FOREVER once
		# embedded, but it's better to just not embed it in the first place.
		_terrain_cast.target_position = knockback_step
		_terrain_cast.force_shapecast_update()
		if _terrain_cast.is_colliding():
			_knockback = Vector2.ZERO
		else:
			global_position += knockback_step
			_knockback = _knockback.move_toward(Vector2.ZERO,
				feel.hit_knockback_decay * ppm * delta)

	if _stun_timer > 0.0:
		_stun_timer -= delta
		queue_redraw()
		return

	var sub_in_territory := sub != null \
		and _dist_to_sub_hull(home) <= feel.territory_radius_m * ppm
	var dist_to_sub := _dist_to_sub_hull(global_position) if sub != null else INF

	# Hunters lock on from farther away, in PATROL/CHASE/RETURN, regardless of
	# territory (design doc §7). Gated by line-of-sight: being within range
	# behind solid rock must not spot the sub (a wall is a wall) — but once
	# locked on, losing sight again does NOT break the chase, since both
	# behaviors are defined by how stubbornly they hold on, not by vision.
	if behavior == Behavior.HUNTER and state != State.HUNT and state != State.RECOVER \
			and dist_to_sub <= feel.hunter_detect_m * ppm \
			and _has_line_of_sight_to_sub():
		state = State.HUNT
		_has_spotted = true
		_hunter_lose_timer = 0.0

	# Basic chasers lock on from chaser_detect_m and never let go.
	if behavior == Behavior.CHASER and state != State.HUNT and state != State.RECOVER \
			and dist_to_sub <= feel.chaser_detect_m * ppm \
			and _has_line_of_sight_to_sub():
		state = State.HUNT
		_has_spotted = true

	# Spitters notice the sub from spit_detect_m (with line of sight) and drop
	# into their kiting loop. Only from idle states (PATROL/RETURN) — the kite/
	# inflate cycle drives itself once engaged.
	if behavior == Behavior.SPITTER and (state == State.PATROL or state == State.RETURN) \
			and dist_to_sub <= GameFeel.spitter.spit_detect_m * ppm \
			and _has_line_of_sight_to_sub():
		state = State.KITE
		_has_spotted = true

	match state:
		State.PATROL:
			_patrol(feel, ppm, delta)
			if sub_in_territory:
				state = State.CHASE
		State.CHASE:
			if not sub_in_territory:
				state = State.RETURN
			else:
				_swim_toward(_nearest_hull_point(global_position), feel.chase_speed * ppm, delta)
				_try_bite(feel.chase_speed)
				_try_ranged_fire(delta)
		State.HUNT:
			# Basic chasers never give up. Hunters chase anywhere, only
			# giving up after a sustained spell beyond hunter_lose_m.
			if behavior != Behavior.CHASER:
				if dist_to_sub > feel.hunter_lose_m * ppm:
					_hunter_lose_timer += delta
					if _hunter_lose_timer >= feel.hunter_lose_time:
						state = State.RETURN
				else:
					_hunter_lose_timer = 0.0
			var speed := feel.chaser_speed if behavior == Behavior.CHASER else feel.hunt_speed
			_swim_toward(_nearest_hull_point(global_position), speed * ppm, delta)
			_try_bite(speed)
			_try_ranged_fire(delta)
		State.RECOVER:
			# Circle off after a bite, then come back for another pass.
			var recover_step := _recover_dir * feel.return_speed * ppm * delta
			var recover_new := global_position + recover_step
			if not _is_blocked_by_sky(recover_new):
				_terrain_cast.target_position = recover_step
				_terrain_cast.force_shapecast_update()
				if not _terrain_cast.is_colliding():
					global_position = recover_new
			if _bite_cooldown <= 0.0:
				if behavior == Behavior.HUNTER or behavior == Behavior.CHASER:
					state = State.HUNT
					_has_spotted = true
				else:
					state = State.CHASE if sub_in_territory else State.RETURN
		State.RETURN:
			_swim_toward(home, feel.return_speed * ppm, delta)
			if global_position.distance_to(home) < 10.0:
				# AMBUSHER re-buries at the (new) home; everyone else patrols
				# (a spitter re-spots from PATROL via the top-of-frame check).
				state = State.LURK if behavior == Behavior.AMBUSHER else State.PATROL
			elif behavior == Behavior.TERRITORIAL and sub_in_territory:
				# Only territorial fish re-engage via CHASE from RETURN; hunter/
				# chaser re-acquire through the HUNT lock-on above, spitter
				# through the KITE spot check.
				state = State.CHASE
		State.KITE:
			_spitter_kite(ppm, delta)
		State.INFLATE:
			_spitter_inflate(ppm, delta)
		State.LURK:
			# Buried and ~motionless: hold at home, run a SILENT detect each
			# frame (no attention ring is ever drawn — see _draw). Sub inside
			# the hidden radius with line of sight → wind up the strike.
			if feel.ambush_lurk_drift > 0.0:
				_swim_toward(home, feel.ambush_lurk_drift * ppm, delta)
			if sub != null and dist_to_sub <= feel.ambush_detect_m * ppm \
					and _has_line_of_sight_to_sub():
				_windup_timer = feel.ambush_windup_s
				state = State.WINDUP
		State.WINDUP:
			# Brief tremor tell (drawn in _draw) before committing — the
			# fairness window that lets an alert pilot react.
			_windup_timer -= delta
			if _windup_timer <= 0.0:
				# Lock the strike direction NOW (committed straight line → it
				# can be dodged), clear any leftover bite cooldown so the lunge
				# always lands its bite, and go.
				_lunge_dir = global_position.direction_to(_nearest_hull_point(global_position))
				_lunge_origin = global_position
				_bite_cooldown = 0.0
				state = State.LUNGE
		State.LUNGE:
			# Fast committed dash along the locked direction. Terrain/sky ends
			# it as a miss; overshooting the commit distance does too.
			var lunge_step := _lunge_dir * feel.ambush_lunge_speed_mps * ppm * delta
			var blocked := _is_blocked_by_sky(global_position + lunge_step)
			if not blocked:
				_terrain_cast.target_position = lunge_step
				_terrain_cast.force_shapecast_update()
				blocked = _terrain_cast_blocks()
			if not blocked:
				global_position += lunge_step
				if absf(_lunge_dir.x) > 0.1:
					_facing = signf(_lunge_dir.x)
			# Reuse the shared bite path; a landed bite flips state to RECOVER.
			_try_bite(feel.ambush_lunge_speed_mps)
			if state == State.RECOVER:
				# Bit the hull → dart off and re-bury somewhere new.
				home = _pick_rebury_home()
				state = State.RETURN
				_has_spotted = false
			elif blocked or global_position.distance_to(_lunge_origin) >= feel.ambush_lunge_reach_m * ppm:
				# Missed (hit rock/surface, or overshot) → re-bury elsewhere too,
				# so no sandy stretch is ever "cleared" in the players' memory.
				home = _pick_rebury_home()
				state = State.RETURN
	queue_redraw()

## Distance from `world_pos` to the nearest point on the sub's hull (local
## rects, distance-preserved by sub.to_local). Returns 0 if the point is
## inside the hull.
func _dist_to_sub_hull(world_pos: Vector2) -> float:
	return world_pos.distance_to(_nearest_hull_point(world_pos))

## True if nothing solid sits between the fish and the nearest point of the
## sub's hull right now — a raycast against the TERRAIN layer only (the sub
## itself isn't on that layer, so it never blocks its own line of sight).
## Gates the INITIAL hunter/chaser lock-on only: detection must respect walls,
## but once locked on, both behaviors are defined by refusing to let go, not
## by maintaining a clear sightline, so this is never re-checked afterward.
func _has_line_of_sight_to_sub() -> bool:
	var target := _nearest_hull_point(global_position)
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target, Layers.TERRAIN)
	var result := space_state.intersect_ray(query)
	return result.is_empty()

## The nearest point on the sub's hull to `world_pos`, in world space. Used
## as the actual swim target in CHASE/HUNT (2026-06-22 fix) instead of the
## sub's single fixed origin point — every aggroed fish used to beeline for
## that one exact coordinate (which reads as "the base of the sub" since the
## sub re-anchors its origin to the helm row's floor), so several fish
## converging on the sub at once would all stack on top of each other at
## that one spot. Aiming at the closest hull surface instead spreads them
## around the hull, approaching from wherever they actually are.
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

func _patrol(feel: GameFeel.FishFeel, ppm: float, delta: float) -> void:
	# Drift between random points in the inner half of the territory.
	if global_position.distance_to(_patrol_target) < 12.0:
		var r := feel.territory_radius_m * ppm * 0.5
		_patrol_target = home + Vector2(randf_range(-r, r), randf_range(-r, r) * 0.5)
	_swim_toward(_patrol_target, feel.patrol_speed * ppm, delta)

func _swim_toward(target: Vector2, speed: float, delta: float) -> void:
	var dir := global_position.direction_to(target)
	var step := dir * speed * delta
	if _is_blocked_by_sky(global_position + step):
		return
	_terrain_cast.target_position = step
	_terrain_cast.force_shapecast_update()
	if _terrain_cast_blocks():
		return
	global_position += step
	if absf(dir.x) > 0.1:
		_facing = signf(dir.x)

## MILESTONE_9.md — AMBUSHER: pick a fresh burial spot after a strike so the
## lurker never returns to the exact same place ("re-bury somewhere new"). Samples
## random offsets biased downward (toward the seabed it buries against); a
## candidate is valid only if the swept path to it is clear of terrain (so it's
## both reachable and not inside rock) and it isn't above a water/pocket surface.
## Falls back to the current home if no valid spot turns up in a few tries.
func _pick_rebury_home() -> Vector2:
	var ppm := GameFeel.PIXELS_PER_METER
	for _i in 8:
		var ang := randf_range(-PI, PI)
		var dist := randf_range(4.0, 9.0) * ppm
		var offset := Vector2(cos(ang), sin(ang)) * dist
		offset.y = absf(offset.y) * 0.7 + dist * 0.3  # bias toward the floor below
		var candidate := global_position + offset
		if _is_blocked_by_sky(candidate):
			continue
		_terrain_cast.target_position = candidate - global_position
		_terrain_cast.force_shapecast_update()
		if _terrain_cast_blocks():
			continue
		return candidate
	return home

## MILESTONE_9.md — SPITTER kiting loop: keep the standoff band. Too close →
## back away; too far → approach; lost entirely → break off home; inside the
## band and off cooldown → start inflating.
func _spitter_kite(ppm: float, delta: float) -> void:
	if sub == null:
		state = State.PATROL
		return
	var sp := GameFeel.spitter
	var d := global_position.distance_to(sub.global_position)
	var kite_speed := class_stats().move_speed * ppm
	if d > sp.spit_detect_m * ppm * 1.2:
		state = State.RETURN
	elif d < sp.spit_keep_min_m * ppm:
		var away := sub.global_position.direction_to(global_position)
		_swim_toward(global_position + away * 5.0 * ppm, kite_speed, delta)
	elif d > sp.spit_keep_max_m * ppm:
		_swim_toward(sub.global_position, kite_speed, delta)
	elif _inflate_cooldown <= 0.0:
		_inflate_timer = 0.0
		_inflated = true
		state = State.INFLATE
	# else: in the band but cooling down — hold and wait.

## MILESTONE_9.md — SPITTER inflate cycle: puff up over inflate_time_s (juicy &
## vulnerable the whole time), then fire the tier's bubble count and deflate. The
## puff-up aborts if the sub breaks the band, so you can pressure it off a shot.
func _spitter_inflate(ppm: float, delta: float) -> void:
	if sub == null:
		_inflated = false
		state = State.PATROL
		return
	var sp := GameFeel.spitter
	var d := global_position.distance_to(sub.global_position)
	if d < sp.spit_keep_min_m * ppm or d > sp.spit_detect_m * ppm * 1.2:
		_inflated = false
		state = State.KITE
		return
	var dx := sub.global_position.x - global_position.x
	if absf(dx) > 0.1:
		_facing = signf(dx)
	_inflate_timer += delta
	if _inflate_timer >= sp.inflate_time_s:
		_fire_bubbles(ppm)
		_inflated = false
		_inflate_cooldown = sp.inflate_cooldown_s
		_inflate_timer = 0.0
		state = State.KITE

## Bubbles fired this volley, by class tier (Small 1, Big 2, Elite a spread).
func _bubble_count() -> int:
	match current_class:
		EnemyDef.Class.BIG:
			return GameFeel.spitter.big_bubbles
		EnemyDef.Class.ELITE:
			return GameFeel.spitter.elite_bubbles
		_:
			return GameFeel.spitter.small_bubbles

## Spawn the volley: one bubble straight at the sub, extras jittered within a
## spread cone. Each is a destructible Bubble (scripts/fauna/bubble.gd).
func _fire_bubbles(ppm: float) -> void:
	if sub == null:
		return
	var sp := GameFeel.spitter
	var aim := global_position.direction_to(sub.global_position)
	var count := _bubble_count()
	var spread := deg_to_rad(sp.scatter_spread_deg)
	var muzzle := _base_length_m() * class_stats().size_scale * ppm * 0.6
	for i in count:
		var jitter := 0.0 if count <= 1 else randf_range(-spread, spread)
		var dir := aim.rotated(jitter)
		var b := Bubble.new()
		b.velocity = dir * GameFeel.bubble.speed_mps * ppm
		get_parent().add_child(b)
		b.global_position = global_position + dir * muzzle

## If the fish's own shape is currently overlapping terrain right now (e.g.
## knocked into a wall by a hit), push it back out along the wall's normal
## and report true so the caller skips AI entirely this frame. Letting AI run
## while embedded was an earlier, broken fix for this same bug: any per-step
## terrain block that's bypassed whenever "we're already stuck" gets
## re-triggered every single frame by an AI still trying to swim INTO the
## wall, so it just walks straight through. Depenetrating first instead
## guarantees normal movement only ever resumes once the fish is actually clear.
func _try_depenetrate_from_terrain(delta: float) -> bool:
	_terrain_cast.target_position = Vector2.ZERO
	_terrain_cast.force_shapecast_update()
	# A Sand Lurker resting in sand is buried at home, NOT embedded in rock —
	# sand is passable for it, so only a non-sand (rock) overlap counts as stuck.
	if not _terrain_cast_blocks():
		return false
	var normal := _depenetration_normal()
	if normal != Vector2.ZERO:
		global_position += normal * GameFeel.fish.return_speed * GameFeel.PIXELS_PER_METER * delta
	return true

## True if the (already-updated) terrain cast is blocked by terrain this fish
## can't pass through. Normally ALL terrain blocks. The AMBUSHER (Sand Lurker)
## treats SAND as passable — sand is its home; it burrows and moves through it
## to hide — so only non-sand terrain (rock/dock) blocks the lurker.
func _terrain_cast_blocks() -> bool:
	for i in _terrain_cast.get_collision_count():
		if not _is_passable_terrain(_terrain_cast.get_collider(i)):
			return true
	return false

## Whether this fish may pass through `collider`. Only a Sand Lurker, and only
## through SAND terrain bodies — every other fish (and every other terrain type)
## blocks as before.
func _is_passable_terrain(collider: Object) -> bool:
	return behavior == Behavior.AMBUSHER and collider is TerrainBody \
		and (collider as TerrainBody).terrain_type == TerrainType.Type.SAND

## The collision normal to push out along when depenetrating — the first
## IMPASSABLE collider's normal, so a lurker half-sunk in sand pushes out of the
## rock it's actually stuck in, not out of its own sand.
func _depenetration_normal() -> Vector2:
	for i in _terrain_cast.get_collision_count():
		if not _is_passable_terrain(_terrain_cast.get_collider(i)):
			return _terrain_cast.get_collision_normal(i)
	return _terrain_cast.get_collision_normal(0)

## True if `pos` would be in open air (above main surface or inside a pocket).
## Fish are water creatures — they never cross these boundaries from the water
## side. But if a fish is somehow already above the surface (e.g. released
## from a grab while still inside the sub's air interior), this must NOT also
## block it from moving — every candidate step would still read as "in the
## sky" until the exact frame it crosses back below the line, trapping it in
## open air forever. So the block only applies when starting from legal water
## (mirrors the pocket check below, which already has this guard).
func _is_blocked_by_sky(pos: Vector2) -> bool:
	if water_surface_y > 0.0 and pos.y < water_surface_y and global_position.y >= water_surface_y:
		return true
	for zone in sky_zones:
		if not zone.get("is_pocket", false):
			continue
		var sz: float = zone["surface_y"]
		if pos.y < sz and global_position.y >= sz:
			var rect: Rect2 = zone["rect"]
			# Bound by the pocket's actual footprint (x AND y), not just x —
			# otherwise any fish sharing an x-range with a pocket, however far
			# above its real cavity (even fully submerged elsewhere), would
			# read as "entering that pocket's sky." Mirrors Sub/Torpedo's
			# rect.has_point()-based zone checks.
			if rect.has_point(pos):
				return true
	return false

## True if the fish's CURRENT position is in open air right now (above the
## main surface, or inside an air pocket's sky zone) — drives the plain-
## gravity fall in _physics_process, as opposed to _is_blocked_by_sky's
## "would this candidate move enter the sky" check.
func _in_sky() -> bool:
	if water_surface_y > 0.0 and global_position.y < water_surface_y:
		return true
	for zone in sky_zones:
		if not zone.get("is_pocket", false):
			continue
		var sz: float = zone["surface_y"]
		if global_position.y < sz:
			var rect: Rect2 = zone["rect"]
			# See the matching comment in _is_blocked_by_sky: bound by the
			# pocket's actual footprint, not just its x-range.
			if rect.has_point(global_position):
				return true
	return false

## On hull contact (and off cooldown): lunge-bite — a small drip-tier breach
## at the bite point, plus a ram-knockback shove (MILESTONE_8.md Module 1)
## scaled by this class's weight and how fast the fish was moving — then
## circle away for another pass.
func _try_bite(impact_speed_mps: float) -> void:
	if _bite_cooldown > 0.0:
		return
	var touching := false
	for body in get_overlapping_bodies():
		if body == sub:
			touching = true
			break
	if not touching:
		return
	var local := sub.to_local(global_position)
	var stats := class_stats()
	sub.breach_from_hit(sub.nearest_room(local), stats.damage, local)
	sub.apply_ram_knockback(global_position.direction_to(sub.global_position),
		stats.room_weight, impact_speed_mps)
	_bite_cooldown = GameFeel.fish.chaser_backoff_time if behavior == Behavior.CHASER else GameFeel.fish.bite_interval
	# Circle away: mostly back the way it came, with some sideways drift.
	var away := sub.global_position.direction_to(global_position)
	_recover_dir = (away + Vector2(0, -0.5)).normalized()
	state = State.RECOVER

## MILESTONE_8.md Module 3: `ranged=true` is a per-species base trait, on top
## of (never instead of) the existing bite — independent of the Elite-only
## `ranged_spit` ability below, which also grants it (or, on an
## already-ranged species, "intensifies" it with a shorter cooldown).
func _wants_ranged() -> bool:
	return enemy_def.ranged or (current_class == EnemyDef.Class.ELITE \
		and class_stats().elite_ability == "ranged_spit")

func _ranged_intensified() -> bool:
	return enemy_def.ranged and current_class == EnemyDef.Class.ELITE \
		and class_stats().elite_ability == "ranged_spit"

## Fires a slow EnemySpit at the sub's current position when in range and off
## cooldown. Damages the sub through breach_from_hit on hit (the same M5
## spine a bite uses) — see scripts/fauna/enemy_spit.gd.
func _try_ranged_fire(delta: float) -> void:
	if not _wants_ranged():
		return
	_ranged_cooldown = maxf(0.0, _ranged_cooldown - delta)
	if _ranged_cooldown > 0.0:
		return
	var feel := GameFeel.enemy_ranged
	if global_position.distance_to(sub.global_position) > feel.fire_range_m * GameFeel.PIXELS_PER_METER:
		return
	var spit := EnemySpit.new()
	spit.global_position = global_position
	spit.damage = feel.damage
	spit.lifetime = feel.projectile_lifetime_s
	spit.velocity = global_position.direction_to(sub.global_position) \
		* feel.projectile_speed_mps * GameFeel.PIXELS_PER_METER
	get_parent().add_child(spit)
	_ranged_cooldown = feel.fire_cooldown_s * (feel.intensify_cooldown_mult if _ranged_intensified() else 1.0)

## MILESTONE_8.md Module 3: the Elite block's elite_ability hook. `ranged_spit`
## is wired end-to-end above (via _wants_ranged/_try_ranged_fire) — nothing
## else to do here for it. `brief_shield`/`speed_burst` are recognized common-
## menu choices not yet implemented, and `NOVEL_HANDCODE` means this species
## needs a hand-coded mechanic that doesn't exist yet (MILESTONE_8.md Module
## 5). Both log loudly at spawn rather than silently doing nothing, so a
## misconfigured species is caught immediately instead of just quietly not
## working.
func _check_elite_ability() -> void:
	if current_class != EnemyDef.Class.ELITE:
		return
	var ability := class_stats().elite_ability
	match ability:
		"none", "ranged_spit":
			pass
		"NOVEL_HANDCODE":
			push_warning("%s's elite_ability is NOVEL_HANDCODE -- needs a hand-coded mechanic, see MILESTONE_8.md Module 5" % enemy_def.species_name)
		_:
			push_warning("%s's elite_ability '%s' is not implemented yet" % [enemy_def.species_name, ability])
	state = State.RECOVER

func _on_area_entered(area: Area2D) -> void:
	if is_dead or not (area is Torpedo):
		return
	var dmg: float = GameFeel.bullet.damage if area is Bullet else GameFeel.turret.damage
	var hit_point := area.global_position
	area.queue_free()
	take_damage(dmg, hit_point)

## M5: apply weapon damage. Lethal -> die() (unchanged cartoon pop). Non-lethal
## -> a brief white flash + small knockback away from the hit point, so a
## bullet burst reads as "chipping away" rather than nothing happening.
func take_damage(amount: float, from_point: Vector2) -> void:
	if is_dead or grabbed:
		return
	# MILESTONE_9.md — a fully-inflated Spitter is a juicy target: it takes
	# extra damage (and pays a bonus if it dies inflated — see die()).
	var dealt := amount * (GameFeel.spitter.inflate_damage_mult if _inflated else 1.0)
	hp -= dealt
	if hp <= 0.0:
		die()
		return
	_hit_flash = GameFeel.fish.hit_flash_time
	_stun_timer = minf(1.0, amount * amount / 100.0)
	var away := from_point.direction_to(global_position)
	if away == Vector2.ZERO:
		away = Vector2(_facing, 0)
	_knockback = away * GameFeel.fish.hit_knockback_mps * GameFeel.PIXELS_PER_METER

## MILESTONE_8.md Module 2: can a claw/telescope arm pick this fish up right
## now? Dead, already-grabbed, or `grabbable=false` (EnemyDef) all refuse.
func is_grabbable() -> bool:
	return not is_dead and not grabbed and enemy_def.grabbable

## Caught by an arm: stop running AI/movement. The holding station now owns
## this fish's position every frame until release()/die().
func grab() -> void:
	grabbed = true

## The finishing blow once a catch is fully reeled home (2026-06-21 reel
## minigame follow-up to MILESTONE_8.md Module 2): always lethal, regardless
## of remaining hp -- the reel-in itself is the kill, not a separate hp
## check. Lifts the `grabbed` no-damage guard first since the catch is still
## technically "held" at this instant; take_damage's normal death handling
## (die() -> carcass drop) takes it from there.
func finish_catch(amount: float) -> void:
	grabbed = false
	take_damage(amount, global_position)

## Let go — escaped (implosion before being delivered) rather than caught.
## Resumes AI from wherever the arm left it, heading home.
func release() -> void:
	grabbed = false
	state = State.RETURN
	_has_spotted = false

## The struggling fish's escape intent (MILESTONE_8.md Module 2): always
## swims for home, same as the RETURN state's instinct when not held.
func struggle_direction() -> Vector2:
	return global_position.direction_to(home)

## Cartoon pop + bubbles; the fish stays gone until reset_fish(). Drops its
## class block's currency_drop_total in the species' currency_color (plus
## gold_drop, for an Elite), split into denomination pickups — MILESTONE_8.md
## Module 4, retiring the old single-carcass drop. `last_drops` lets a caller
## that already knows it owns this kill (the reel minigame's finishing blow)
## grab references to the pickups it just created and auto-collect them,
## without a group search.
var last_drops: Array[SalvageItem] = []

func die() -> void:
	is_dead = true
	grabbed = false
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var pop := Torpedo.Puff.new()
	pop.global_position = global_position
	get_parent().add_child(pop)
	last_drops.clear()
	var stats := class_stats()
	for value in GameFeel.currency.split(stats.currency_drop_total):
		_spawn_drop(enemy_def.currency_color, value)
	if current_class == EnemyDef.Class.ELITE and stats.gold_drop > 0:
		for value in GameFeel.currency.split(stats.gold_drop):
			_spawn_drop("gold", value)
	# MILESTONE_9.md — popped while inflated: bonus currency in the species'
	# color (you caught the Spitter juicy, before it could fire).
	if _inflated and GameFeel.spitter.inflate_pop_bonus > 0:
		for value in GameFeel.currency.split(GameFeel.spitter.inflate_pop_bonus):
			_spawn_drop(enemy_def.currency_color, value)

## One denomination pickup, scattered a little around the kill site so several
## drops from one kill don't all stack on the exact same pixel.
func _spawn_drop(color: String, value: int) -> void:
	var scatter := Vector2(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0))
	var drop := SalvageItem.make_currency(global_position + scatter, color, value)
	drop.sky_zones = sky_zones
	drop.water_surface_y = water_surface_y
	get_parent().add_child(drop)
	last_drops.append(drop)

## Back home, alive — the world's run reset calls this on the "fish" group.
## Unconditionally releases a grab too — whatever order this runs in versus
## the holding station's own reset, a held fish must never survive a full
## run reset still flagged grabbed (the station re-checks `grabbed` each
## frame and drops a stale reference on its own).
func reset_fish() -> void:
	is_dead = false
	grabbed = false
	visible = true
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	global_position = home
	_patrol_target = home
	_bite_cooldown = 0.0
	_ranged_cooldown = 0.0
	state = State.LURK if behavior == Behavior.AMBUSHER else State.PATROL
	_windup_timer = 0.0
	_inflate_timer = 0.0
	_inflate_cooldown = 0.0
	_inflated = false
	hp_max = class_stats().hp
	hp = hp_max
	_hit_flash = 0.0
	_knockback = Vector2.ZERO
	_stun_timer = 0.0
	_hunter_lose_timer = 0.0
	_has_spotted = false
	last_drops.clear()

## Whether the attention/detection ring is drawn for this fish right now.
## Territorial: always (they can lose you, so the ring is useful). Chaser:
## visible until it locks on, then it disappears. AMBUSHER (Lurker): NEVER —
## its detect range is invisible by design (players find it only by spotting
## the fish itself against the sand). Exposed (not inlined in _draw) so tests
## can assert the lurker stays hidden.
func shows_detection_ring() -> bool:
	if is_dead or grabbed:
		return false
	if behavior == Behavior.AMBUSHER:
		return false
	if behavior == Behavior.CHASER and _has_spotted:
		return false
	return true

## Radius (px) of the detection zone shown as the attention circle.
func _detect_radius_px() -> float:
	var ppm := GameFeel.PIXELS_PER_METER
	var feel := GameFeel.fish
	if behavior == Behavior.CHASER:
		return feel.chaser_detect_m * ppm
	if behavior == Behavior.HUNTER:
		return feel.hunter_detect_m * ppm
	if behavior == Behavior.SPITTER:
		return GameFeel.spitter.spit_detect_m * ppm
	return feel.territory_radius_m * ppm

## The active EnemyDef class block (Small/Big/Elite) this fish reads its
## stats from (MILESTONE_8.md Module 0). Public — the claw/telescope arms
## read room_weight/move_speed from this while holding a grab (Module 2).
func class_stats() -> EnemyClassStats:
	return enemy_def.stats_for(current_class)

func _draw() -> void:
	var ppm: float = GameFeel.PIXELS_PER_METER
	var is_chaser := behavior == Behavior.CHASER
	var is_ambusher := behavior == Behavior.AMBUSHER
	var is_spitter := behavior == Behavior.SPITTER
	# MILESTONE_8.md Module 3: class tier scales the drawn size too, matching
	# the collision circle set in _ready() — art stays identical at every
	# tier (ART-PASS FLAG), just scaled.
	var length_m := _base_length_m() * class_stats().size_scale
	var len_px := length_m * ppm
	var half := len_px * 0.5
	var base_color := PlaceholderArt.CHASER_COLOR if is_chaser \
		else (PlaceholderArt.LURKER_COLOR if is_ambusher \
		else (PlaceholderArt.SPITTER_COLOR if is_spitter else PlaceholderArt.FISH_COLOR))
	var c := Color.WHITE if _hit_flash > 0.0 else base_color

	# Detection range circle — drawn before the fish-body transform so it
	# stays round (not affected by the wobble/stretch scale).
	if shows_detection_ring():
		var ring := Color(base_color.r, base_color.g, base_color.b, 0.05)
		draw_circle(Vector2.ZERO, _detect_radius_px(), ring)

	# All drawn facing right, mirrored by _facing. Chasers are stretched
	# lengthwise (more elongated) on top of their longer base length. The Lurker
	# is squashed flat (squash<1) so it reads as half-buried in the sand, and
	# shudders sideways during the WINDUP tell.
	var stretch := 1.3 if is_chaser else 1.0
	var squash := 0.5 if is_ambusher else 1.0
	var tremor := 0.0
	if is_ambusher and state == State.WINDUP:
		tremor = sin(_wobble * 70.0) * half * 0.14  # fast shudder = the strike tell
	draw_set_transform(Vector2(tremor, 0.0), 0.0,
		Vector2(_facing * stretch, (1.0 + 0.06 * sin(_wobble * 6.0)) * squash))
	if is_spitter:
		_draw_puffer(half, c)
		return
	# Chunky body.
	draw_circle(Vector2(0, 0), half * 0.55, c)
	draw_rect(Rect2(-half * 0.55, -half * 0.4, half * 0.9, half * 0.8), c)
	# Tail fin.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half * 0.5, 0), Vector2(-half, -half * 0.45),
		Vector2(-half, half * 0.45)]), c.darkened(0.2))
	# Big eye, biased forward.
	draw_circle(Vector2(half * 0.25, -half * 0.12), half * 0.22, Color.WHITE)
	draw_circle(Vector2(half * 0.32, -half * 0.12), half * 0.11, Color.BLACK)
	# Grumpy little fin on top.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half * 0.1, -half * 0.5), Vector2(half * 0.15, -half * 0.5),
		Vector2(-half * 0.05, -half * 0.8)]), c.darkened(0.2))

## MILESTONE_9.md — the Spitter puffer: a round dark-brown body that swells to a
## taut circle while inflating, sprouting spikes near full. Local +x faces the
## sub (mirrored by the _facing applied in the caller's transform).
func _draw_puffer(half: float, c: Color) -> void:
	var inflate := 1.0
	if state == State.INFLATE:
		var t: float = clampf(_inflate_timer / GameFeel.spitter.inflate_time_s, 0.0, 1.0)
		inflate = lerpf(1.0, GameFeel.spitter.inflate_full_scale, t)
	var r := half * 0.6 * inflate
	# Spikes appear as it nears full inflation.
	if inflate > 1.25:
		for i in 12:
			var ang := i * TAU / 12.0
			var base := Vector2.from_angle(ang) * r
			draw_line(base, Vector2.from_angle(ang) * r * 1.22, c.darkened(0.25), 2.0)
	# Round body.
	draw_circle(Vector2.ZERO, r, c)
	# Small tail nub at the back.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-r * 0.95, 0), Vector2(-r * 1.35, -r * 0.35),
		Vector2(-r * 1.35, r * 0.35)]), c.darkened(0.2))
	# Eye, biased forward.
	draw_circle(Vector2(r * 0.4, -r * 0.2), r * 0.2, Color.WHITE)
	draw_circle(Vector2(r * 0.47, -r * 0.2), r * 0.1, Color.BLACK)
