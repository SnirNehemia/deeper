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

enum State { PATROL, CHASE, RECOVER, RETURN, HUNT }

## MILESTONE_8.md Module 0: the AI pattern, independent of the EnemyDef class
## tier below. TERRITORIAL = M2 behaviour (chase trigger only inside
## territory, always breaks off and swims home). HUNTER (design doc §7): once
## locked on (from hunter_detect_m), chases anywhere, giving up only after
## hunter_lose_time spent beyond hunter_lose_m. CHASER ("basic_chaser"):
## relentless once locked on (from chaser_detect_m) — never gives up; only a
## successful bite earns the crew a chaser_backoff_time breather.
enum Behavior { TERRITORIAL, HUNTER, CHASER }

const DEFAULT_ENEMY_DEF_PATH := "res://data/enemies/reference_fish.tres"
## Loaded lazily (not preloaded as a const) — preloading a custom-scripted
## .tres at fish.gd's own parse time raced the engine's global-class
## registration in headless runs and silently produced a scriptless Resource.
static var _default_enemy_def: EnemyDef = null

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
var _stun_timer: float = 0.0
var _terrain_cast: ShapeCast2D
## True once a chaser has locked on — keeps the detection ring hidden even
## during RECOVER (when state briefly leaves HUNT between attacks).
var _has_spotted: bool = false

func _ready() -> void:
	add_to_group("fish")
	home = global_position
	_patrol_target = home
	collision_layer = Layers.FISH
	collision_mask = Layers.PROJECTILE | Layers.SUB_HULL
	monitoring = true
	monitorable = true
	if enemy_def == null:
		if _default_enemy_def == null:
			_default_enemy_def = load(DEFAULT_ENEMY_DEF_PATH)
		enemy_def = _default_enemy_def
	hp_max = class_stats().hp
	hp = hp_max
	# MILESTONE_8.md Module 3: class tier visibly changes size (the Module 0
	# `size_scale` field's first real consumer) — art stays identical at every
	# tier (ART-PASS FLAG), just scaled.
	var length_m := (PlaceholderArt.CHASER_LENGTH_M if behavior == Behavior.CHASER else PlaceholderArt.FISH_LENGTH_M) \
		* class_stats().size_scale
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

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if grabbed:
		# Position/visuals are driven by the holding station each frame
		# (mirrors how a caught SalvageItem rides the tip); no AI runs.
		queue_redraw()
		return
	var feel: GameFeel.FishFeel = GameFeel.fish
	var ppm: float = GameFeel.PIXELS_PER_METER
	_wobble += delta
	_bite_cooldown = maxf(0.0, _bite_cooldown - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	if _knockback != Vector2.ZERO:
		global_position += _knockback * delta
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
	# territory (design doc §7).
	if behavior == Behavior.HUNTER and state != State.HUNT and state != State.RECOVER \
			and dist_to_sub <= feel.hunter_detect_m * ppm:
		state = State.HUNT
		_has_spotted = true
		_hunter_lose_timer = 0.0

	# Basic chasers lock on from chaser_detect_m and never let go.
	if behavior == Behavior.CHASER and state != State.HUNT and state != State.RECOVER \
			and dist_to_sub <= feel.chaser_detect_m * ppm:
		state = State.HUNT
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
				state = State.PATROL
			elif sub_in_territory:
				state = State.CHASE
	queue_redraw()

## Distance from `world_pos` to the nearest point on the sub's hull (local
## rects, distance-preserved by sub.to_local). Returns 0 if the point is
## inside the hull.
func _dist_to_sub_hull(world_pos: Vector2) -> float:
	return world_pos.distance_to(_nearest_hull_point(world_pos))

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
	if _terrain_cast.is_colliding():
		return
	global_position += step
	if absf(dir.x) > 0.1:
		_facing = signf(dir.x)

## True if `pos` would be in open air (above main surface or inside a pocket).
## Fish are water creatures — they never cross these boundaries.
func _is_blocked_by_sky(pos: Vector2) -> bool:
	if water_surface_y > 0.0 and pos.y < water_surface_y:
		return true
	for zone in sky_zones:
		if not zone.get("is_pocket", false):
			continue
		var sz: float = zone["surface_y"]
		if pos.y < sz and global_position.y >= sz:
			var rect: Rect2 = zone["rect"]
			if pos.x >= rect.position.x and pos.x <= rect.position.x + rect.size.x:
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
	hp -= amount
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

## One denomination pickup, scattered a little around the kill site so several
## drops from one kill don't all stack on the exact same pixel.
func _spawn_drop(color: String, value: int) -> void:
	var scatter := Vector2(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0))
	var drop := SalvageItem.make_currency(global_position + scatter, color, value)
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
	state = State.PATROL
	hp_max = class_stats().hp
	hp = hp_max
	_hit_flash = 0.0
	_knockback = Vector2.ZERO
	_stun_timer = 0.0
	_hunter_lose_timer = 0.0
	_has_spotted = false
	last_drops.clear()

## Radius (px) of the detection zone shown as the attention circle.
func _detect_radius_px() -> float:
	var ppm := GameFeel.PIXELS_PER_METER
	var feel := GameFeel.fish
	if behavior == Behavior.CHASER:
		return feel.chaser_detect_m * ppm
	if behavior == Behavior.HUNTER:
		return feel.hunter_detect_m * ppm
	return feel.territory_radius_m * ppm

## The active EnemyDef class block (Small/Big/Elite) this fish reads its
## stats from (MILESTONE_8.md Module 0). Public — the claw/telescope arms
## read room_weight/move_speed from this while holding a grab (Module 2).
func class_stats() -> EnemyClassStats:
	return enemy_def.stats_for(current_class)

func _draw() -> void:
	var ppm: float = GameFeel.PIXELS_PER_METER
	var is_chaser := behavior == Behavior.CHASER
	# MILESTONE_8.md Module 3: class tier scales the drawn size too, matching
	# the collision circle set in _ready() — art stays identical at every
	# tier (ART-PASS FLAG), just scaled.
	var length_m := (PlaceholderArt.CHASER_LENGTH_M if is_chaser else PlaceholderArt.FISH_LENGTH_M) \
		* class_stats().size_scale
	var len_px := length_m * ppm
	var half := len_px * 0.5
	var base_color := PlaceholderArt.CHASER_COLOR if is_chaser else PlaceholderArt.FISH_COLOR
	var c := Color.WHITE if _hit_flash > 0.0 else base_color

	# Detection range circle — drawn before the fish-body transform so it
	# stays round (not affected by the wobble/stretch scale).
	# Territorial fish: always visible (they can lose you, so it's useful).
	# Chasers: visible until they've locked on, then it disappears.
	var show_range := not is_dead and not grabbed and not (is_chaser and _has_spotted)
	if show_range:
		var ring := Color(base_color.r, base_color.g, base_color.b, 0.05)
		draw_circle(Vector2.ZERO, _detect_radius_px(), ring)

	# All drawn facing right, mirrored by _facing. Chasers are stretched
	# lengthwise (more elongated) on top of their longer base length.
	var stretch := 1.3 if is_chaser else 1.0
	draw_set_transform(Vector2.ZERO, 0.0,
		Vector2(_facing * stretch, 1.0 + 0.06 * sin(_wobble * 6.0)))
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
