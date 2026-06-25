# MILESTONE 9 — The First Real Bestiary: Lurker & Spitter (+ Deep-Area Roster)

*Read order for the build session: `STATUS.md` → `DECISIONS.md` →
`MILESTONE_8.md` (the spine these species are authored against) →
`.claude/skills/add-deeper-enemy/SKILL.md` → `ELEMENTAL_UPDATE.md` (Discharger
hook) → this file. Plan back before building.*

*(This brief supersedes the M8 close-out stub. The stub's three pencilled fish are
re-rostered below; its non-fish carry-over — the economy balance pass — is
preserved in "Carried forward from the M8 stub.")*

M8 built the **enemy spine**: species are pure data (`EnemyDef` `.tres` with
Small/Big/Elite stat blocks), spawned against three AI archetypes (territorial /
hunter / chaser), authored by the `add-deeper-enemy` skill, dropping
color-currency. It shipped **no new species** — only the promoted reference reef
fish and the basic chaser.

**M9 spends that spine on real content.** It adds the first two mechanically
distinct fish, each introducing a **new AI behavior** — the first content past the
M8 "no new AI patterns" freeze. It also designs two more advanced species for the
deep areas (built in a later slice).

### Roster lineage (canon note — avoid drift)
The M8 close-out stub pencilled M9 as *"sand lurker, silver school fish, armored
grey tank."* Snir's M9 design **keeps the sand lurker**, reshapes the *silver
school* into **The Shoal** (queued), replaces the *armored grey tank* with **The
Spitter** (a ranged puffer), and adds **The Discharger** (queued). The armored
tank is not retired — it simply isn't in this roster. Record this supersession in
`DECISIONS.md` when the milestone closes.

### Committed scope vs. queued
- **M9 ships:** The Lurker + The Spitter (built, tested, playable).
- **Designed here, queued for M10:** The Shoal + The Discharger (full specs below;
  bigger lifts that introduce new sub-systems — flocking, station-disable).

---

## Design intent (why this milestone exists)

M8 made variety *cheap to author* but left the bestiary nearly empty. M9 proves
the spine by building fish that **could not have existed under the old three
behaviors** — an ambusher that hides, a kiter that shoots destructible
projectiles — and it does so by hand-coding novel behaviors **on top of**
skill-authored data, exactly as the skill's "novel mechanic" path prescribes.

Two pillars this milestone must not violate (inherited from M8):
- **Flooding is the sole death path.** Every new attack (lunge bite, bubble, slam,
  bolt) routes through `sub.breach_from_hit()` / `Fish.take_damage()`. No new HP
  pool on the sub, no instant-kill.
- **Push-your-luck preservation.** Grabbed enemies and dropped currency stay at
  risk until banked/docked. New species don't change that.

---

## Authoring model (how every species here is built)

Each species splits into two layers:
- **Data (skill-authored):** a `.tres` from `add-deeper-enemy` — body color,
  currency color, `ranged`/`grabbable` flags, Small/Big/Elite stat blocks. The
  skill's intake blocks on every field and rejects reserved currency colors.
- **Behavior (hand-coded):** every M9 species has a *novel* AI pattern, so each
  gets a new `Fish.Behavior` branch (or companion class) — the skill's explicit
  "confirm scope, then hand-code" path. **All numeric dials live in `GameFeel`**,
  never in the `.tres` (the M8 spine/content split; keeps everything
  `deeper-tuner`-friendly).

Reserved currency colors to avoid (Elemental namespace): `yellow, grey/gray,
light_grey, cyan, light_blue, red, purple, gold`. Color suggestions below are
placeholders; the final pick happens during the skill's intake with Snir.

---

## Species 1 — THE LURKER  *(build first; easiest)*

### In-game behavior
A flat, sand-colored fish lying half-buried on the seabed, nearly motionless. Its
attention radius is **invisible** — players only find it by spotting the fish
itself against the sand. When the sub enters its hidden range it gives a
split-second tell (a tremor / sand-puff), then **lunges very fast** in a straight
line, lands a **single** bite, and **darts off to re-bury somewhere new** — so no
sandy stretch is ever "cleared" in the players' memory.

### Design decisions (confirmed with Snir)
- Post-strike: **re-bury somewhere new** (never the same spot).
- Fairness: a brief **wind-up telegraph** before the lunge (default; tunable).

### Why it's first
Self-contained new AI behavior. Reuses the existing state machine, stored `home`
position, terrain/sky/gravity handling, and the existing bite path. **No new
projectile, collision, or damage-model code.**

### Implementation
- **New behavior** `Fish.Behavior.AMBUSHER` (extend the enum at
  `scripts/fauna/fish.gd:22`).
- **New states** layered into the `_physics_process` machine:
  - `LURK` — sits at `home`, drift ≈ 0 (stays buried). Each frame runs a *silent*
    detect check: sub within `ambush_detect_m` **and** line-of-sight
    (`_has_line_of_sight_to_sub()`) → `WINDUP`.
  - `WINDUP` — hold `ambush_windup_s` (~0.2 s) playing the tremor tell → `LUNGE`.
  - `LUNGE` — dash straight at the nearest hull point at `ambush_lunge_speed_mps`
    (much faster than any current fish). On bite (reuse `_try_bite()`) → pick a
    **new `home`** → `RETURN`.
  - Reuse existing `RETURN` to swim to the new home, then back to `LURK`.
- **Invisible range:** in `_draw()` (the detection-ring block ~line 618), force
  `show_range = false` for AMBUSHER. Detection logic is unaffected — only the
  drawn circle is suppressed.
- **Re-bury target:** new `home` = current position + a random offset biased
  toward terrain, validated against `_terrain_cast` (not inside terrain) and
  `_is_blocked_by_sky()` (not above water). Fall back to the old home if no valid
  spot is found within a few tries.
- **Look:** sand `body_color` (~`Color(0.82, 0.71, 0.48)`); a flattened/low
  placeholder silhouette so it reads as "buried" (small AMBUSHER variant in the
  `placeholder_art.gd` fish draw).
- **GameFeel additions** (`FishFeel`): `ambush_detect_m`, `ambush_windup_s`,
  `ambush_lunge_speed_mps`, `ambush_lurk_drift` (≈0).
- **Tiers:** Small/Big/Elite scale hp/damage/size/speed/currency as usual. Elite
  ability `none` (its identity *is* the ambush) — optional stretch:
  `NOVEL_HANDCODE` "double-lunge."
- **Data file:** `data/enemies/lurker_fish.tres` (`grabbable=true`,
  `ranged=false`); currency color suggestion `"tan"`.

### Files
`fish.gd` (enum + states + invisible ring + re-bury), `placeholder_art.gd` (sand
color + flat silhouette + currency color), `autoload/game_feel.gd` (ambush dials),
`data/enemies/lurker_fish.tres` (new), spawn wiring in `scenes/world.gd`.

### Acceptance
Per-tier stats load; sub entering the hidden range triggers windup→lunge→bite that
breaches the sub; the attention ring is never drawn; after a bite the fish picks a
new valid home and returns there. `tests/test_enemy_lurker.gd` + full regression
green.

---

## Species 2 — THE SPITTER  *(build second; harder)*

### In-game behavior
A round, dark-brown pufferfish. On spotting the sub it **keeps its distance**, then
slowly **inflates** until it's a full taut circle — and fires. Small ones spit a
single **bubble**; bigger ones spit several in a **scattered spread**. Bubbles
drift toward the sub and **breach the hull on contact**, but players can **shoot
them out of the air**: each bubble has 2 HP, slows any ammo that hits it, and a
strong enough shot **bursts through and continues** on its path. While fully
inflated the spitter is a big, juicy target — **pop it in time for bonus payoff.**

### Design decisions (confirmed with Snir)
- Bubble-on-sub effect: **pure breach hit** (the interest is in shooting it down).
- Inflated state: **juicy target** — extra damage taken + bonus currency if popped
  while inflated.

### Why it's harder
The bubble is a **destructible projectile** — there is no projectile-vs-projectile
or shootable-projectile precedent in the codebase, and player torpedoes are
deliberately one-hit-destroy. This introduces a new collision layer and touches
the player weapon path.

### Implementation
- **New behavior** `Fish.Behavior.SPITTER` — a *kiting* loop:
  - sub closer than `spit_keep_min_m` → back away; farther than `spit_keep_max_m`
    → approach; inside the band → hold and run the inflate cycle.
  - **New state** `INFLATE`: a timer scales the visual up to "full circle" over
    `inflate_time_s`; at full → fire, then deflate (reset scale) and cooldown.
- **Bubble count by tier:** Small 1, Big 2, Elite ~4 in a spread cone (random
  jitter around the aim vector). Lives in the behavior — no special elite ability
  needed (`elite_ability = "none"`); Elite is simply bigger + more bubbles.
- **Inflated = juicy:** an `_inflated` flag. `take_damage()` applies
  `inflate_damage_mult` while set; `die()` while inflated adds bonus currency to
  the drop (`GameFeel` `inflate_pop_bonus`).
- **THE BUBBLE — new destructible projectile** `scripts/fauna/bubble.gd`
  (`Bubble extends Area2D`, modeled on `EnemySpit` + the HP pattern from
  `wreck.gd`):
  - Fields: `velocity`, `hp = 2.0`, `damage` (breach severity to the sub),
    `lifetime`. `monitoring = true`.
  - **New collision layer** `BUBBLE = 1 << 12` in `scripts/collision_layers.gd`.
    Bubble `layer = BUBBLE`; `mask = SUB_HULL | TERRAIN | PROJECTILE`.
  - `body_entered` (sub hull / terrain) → breach via `sub.breach_from_hit()` (the
    same spine as every other attack), then pop.
  - `area_entered` (player Torpedo/Bullet) → **the duel**:
    - read the shot's damage (`Torpedo.damage_value()`, Bullet overrides);
    - **slow the shot** (`velocity *= bubble_slow_factor`) — always;
    - shot damage **≥ remaining hp** → bubble bursts; shot **continues** with
      carry-over damage reduced by the hp it spent (pierce);
    - shot damage **< remaining hp** → bubble survives (`hp -= damage`); shot is
      consumed. E.g. one Bullet (1 dmg) chips a 2-HP bubble and dies; two pop it.
      A turret torpedo (5 dmg) bursts it and flies on.
  - The duel logic lives **in the bubble** (it mutates / frees the shot), so
    player projectile *masks* don't change — only small Torpedo helpers are added.
- **Player ammo touch (`scripts/weapons/torpedo.gd`):** add `damage_value()` and
  an instance `damage_remaining` (init from `GameFeel.turret/bullet.damage` at
  spawn) so carry-over damage can be decremented after a pierce; add `slow(factor)`
  and `consume()` helpers. `bullet.gd` overrides `damage_value()`. This is the
  **only** change to the player weapon path; default one-hit-destroy on
  terrain/fish is untouched.
- **GameFeel additions:** `BubbleFeel { hp, speed_mps, lifetime_s, damage,
  slow_factor }`; spitter dials `inflate_time_s`, `spit_keep_min_m`,
  `spit_keep_max_m`, `inflate_damage_mult`, `inflate_pop_bonus`, scatter spread.
- **Look:** dark-brown `body_color` (~`Color(0.36, 0.23, 0.13)`); inflate = scale
  tween to a full circle; bubble = pale translucent circle.
- **Data file:** `data/enemies/spitter_fish.tres` (`ranged=true`,
  `grabbable=true`); currency color suggestion `"brown"`.

### Files
`scripts/fauna/bubble.gd` (new), `scripts/collision_layers.gd` (+BUBBLE),
`scripts/weapons/torpedo.gd` (damage_value / instance damage / slow / consume),
`scripts/weapons/bullet.gd` (override), `fish.gd` (SPITTER + INFLATE +
inflated-juicy hooks), `autoload/game_feel.gd` (bubble + spitter dials),
`placeholder_art.gd` (brown + currency color), `data/enemies/spitter_fish.tres`
(new), spawn wiring in `scenes/world.gd`.

### Acceptance
Inflate→fire spawns N bubbles by tier; a bubble breaches the sub on contact; a
Bullet chips a bubble and a second pops it; a torpedo bursts it and continues
(pierce, slowed); an inflated spitter takes bonus damage and drops bonus currency.
`tests/test_enemy_spitter.gd` + full regression green. (New `class_name Bubble`
script → run `--headless --import` once.)

---

## Deep-Area Roster — designed here, queued for M10

### Species 3 — THE SHOAL  *(flocking swarm; biggest lift; was the M8 stub's "silver school")*
**In-game:** a cloud of tiny fish moving as one organism, orbiting a single
**visible leader**. The threat is the **coordinated mass-slam**: the school
periodically balls up tight, rams ONE hull point for a heavy combined hit, then
disperses. Kill the **leader** and the rest **scatter in panic** (briefly
fleeing/harmless) before regrouping around a new leader.

**Why it's bigger:** introduces a *group meta-entity* with boids-style flocking
(separation / alignment / cohesion), a leader role, and a group state machine
(`DRIFT → BALL_UP → SLAM → DISPERSE`, plus `SCATTER` on leader death). This is the
school-of-fish behavior M8 explicitly deferred to "M9+."

**Implementation sketch:** a new `scripts/fauna/shoal.gd` controller spawns N
lightweight members (a slim fish variant for perf) and steers them with flocking
toward / around the leader; the leader is a distinct member with extra hp + a
visible marker; on leader death → SCATTER timer → promote the nearest member →
regroup. The slam is a synchronized convergence on the nearest hull point pooled
into one `breach_from_hit`. New member `.tres` (tiny stats); the controller is
code. Likely its own milestone slice.

### Species 4 — THE DISCHARGER  *(electric station-jammer)*
**In-game:** keeps its distance, **visibly charges up** (glow ramp = telegraph),
then fires an **electric bolt** at the sub. On hit it **knocks out the nearest
station for a few seconds** — the seated crew is booted and that station goes
dead, forcing a scramble to cover. Shoot it during the wind-up (or get clear) to
avoid the bolt.

**Canon hook (`ELEMENTAL_UPDATE.md` §2):** the Discharger is the canonical
**electrical-type fauna** that future **Yellow Shock** rounds *heal* instead of
damage — "do not shoot blindly." This species establishes that category.

**Implementation sketch:**
- New behavior (kiting like SPITTER) + a `CHARGE` state: glow ramp over
  `charge_time_s`, then fire. Fairness option: taking damage during CHARGE resets
  it.
- **Bolt:** reuse the `EnemySpit` pattern (`ENEMY_PROJECTILE` layer), visually a
  lightning streak; on sub hit it finds the nearest `Station` to the impact and
  calls a new `Station.disable(seconds)`.
- **New station-disable system (small, contained):** add `_disabled_timer` +
  `disable()` + `is_disabled()` to `scripts/stations/station.gd`; `can_enter()`
  returns false while disabled; mirror the existing flood-eject by having
  `crew.gd._be_seated()` also eject when `_station.is_disabled()`. Reuses the
  proven flood-eject path.
- **Electrical-type tag (forward-compat):** add `electric: bool` (or a
  `fauna_type` string) to `EnemyDef` so future Yellow Shock rounds heal it. No
  elemental weapons exist yet, so M9 only sets the flag + leaves a TODO at the
  damage site; the heal branch lands with the Elemental Update.
- New `discharger_fish.tres`; currency color suggestion `"indigo"` (avoid the
  reserved `yellow`). Charge / bolt dials in `GameFeel`.

---

## Carried forward from the M8 stub (economy balance — not a fish)

The M8 close-out stub flagged M9 to also pick up **M8 Module 4b's deferred economy
balance pass**, now that real species exist to drop colors. This is **not part of
the committed Lurker/Spitter build** and stays an open carry-over item — surface
it to Snir as its own decision, do not silently bundle it:
- Whether `ROOM_SYSTEM.md` §6 room prices should **gate on a specific currency
  color** per room (the soft-gate idea M8's flat "4 random colors" price
  sidestepped), now that `tan`/`brown` (+ later shoal/discharger colors) are real
  and droppable.
- Whether the **flat room price should vary by room** now there's a real color
  economy to balance against.
- **`gold` naming + `gold_drop` tuning** re-confirm (M8 Module 4 flagged it
  "implemented, not re-confirmed") now that gold is about to be droppable in
  actual gameplay.

Recommendation: ship the two fish first (the faucet), then run the economy pass as
a follow-on so it can be balanced against the species that actually exist.

---

## Out of scope (hard guardrails)
- **No bosses.** Bosses escape the add-enemy skill by design; not touched here.
- **No new sub HP / death path.** Lunge bite, bubble, slam, bolt all flood through
  `breach_from_hit`. Flooding stays the only death.
- **No Elemental weapons.** The Discharger only *sets* the electrical-type flag;
  the Yellow-Shock-heals branch is Elemental Update work. Currency colors stay a
  separate namespace; reserved hues are avoided, not used.
- **No final balance.** All new dials ship as first-pass numbers, tuned in playtest
  via `deeper-tuner`.
- **Shoal & Discharger are not built in M9** — designed and queued only.

---

## Shared / cross-cutting work
- **`Fish.Behavior` enum** gains `AMBUSHER` + `SPITTER` (M9); Shoal-member +
  `DISCHARGER` later. Each new branch follows the existing three as pattern.
- **Collision layers:** add `BUBBLE = 1 << 12` (M9). The Discharger bolt reuses
  `ENEMY_PROJECTILE`.
- **Damage spine:** every attack routes through `sub.breach_from_hit()` /
  `Fish.take_damage()` — no second damage path.
- **Spawn wiring:** add demo spawns in `scenes/world.gd` mirroring
  `_ranged_demo_def()` so each species is exercisable.

---

## Build steps (M9 committed)
1. **Lurker** — author `lurker_fish.tres` (skill intake); add `AMBUSHER` +
   LURK/WINDUP/LUNGE + invisible ring + re-bury; GameFeel dials; sand/flat art;
   currency color. Headless check.
2. **Lurker test** — `tests/test_enemy_lurker.gd` (mirror `test_enemy_ranged.gd`):
   per-tier stat load; detect→windup→lunge→bite breaches; re-bury picks a new
   valid home; ring hidden. → `deeper-test-runner`.
3. **Spitter bubble system first** — `bubble.gd` + `BUBBLE` layer + Torpedo
   damage/slow/consume/carry helpers. Headless check + `--import`.
4. **Spitter behavior** — `SPITTER` kiting + `INFLATE` + tier scatter +
   inflated-juicy hooks; author `spitter_fish.tres`; GameFeel dials; brown art.
   Headless check.
5. **Spitter test** — `tests/test_enemy_spitter.gd`: inflate→fire N bubbles by
   tier; bubble breaches on contact; bullet chips / second pops; torpedo bursts +
   continues; slow applied; inflated bonus damage + bonus currency. →
   `deeper-test-runner`.
6. **Full regression** before commit.
7. **Commit** per convention, e.g. `M9-1: sand lurker (AMBUSHER, invisible range,
   re-bury)`; `M9-2: spitter puffer + destructible bubbles (shootable projectile)`.

*(Shoal + Discharger: M10 slice — specced above, not built in M9.)*

---

## Verification
**Headless (every step):** `"D:\Godot_v4.4.1-stable_win64.exe" --headless --path .
--quit` must show no parse/load errors. New `class_name` (`Bubble`) → run
`"...Godot..." --headless --path . --import` once. Per-species tests run via the
`deeper-test-runner` subagent.

**Show, don't tell:** use the `capture-gameplay` skill to screenshot (a) the
lurker buried + mid-lunge, (b) the spitter fully inflated, (c) a bubble being shot
down — show Snir the result.

**Verify by playing** — launch `"D:\Godot_v4.4.1-stable_win64.exe" --path .` (or
the editor Play button):
- **Lurker:** drive low over a sandy stretch. A barely-visible sand-colored fish
  should suddenly lunge, bite once, and dart off to hide elsewhere — with **no**
  attention circle ever shown. It never returns to the exact same spot.
- **Spitter:** approach a dark-brown puffer. It backs off, puffs into a full
  circle, and spits a bubble (more from bigger ones). Shoot a bubble with the fast
  gun — it slows and pops on the second hit; with a torpedo — it bursts and the
  torpedo keeps going. Pop a fully-inflated spitter for a bigger currency drop.
  Let a bubble reach the hull — it springs a normal leak.

---

## Open items for the build session to resolve with Snir (do not guess)
1. **Currency colors** — confirm `tan` (lurker) and `brown` (spitter) during the
   skill intake (both non-reserved; verify against the live `CURRENCY_COLORS`).
2. **Lurker tell length** — `ambush_windup_s` default is a fairness guess; tune in
   playtest (too short = unfair, too long = toothless).
3. **Spitter scatter shape** — Elite bubble count / spread cone width is a
   first-pass; confirm the feel in playtest.
4. **Bubble carry-over rule** — confirm "torpedo keeps full vs. reduced damage
   after bursting a bubble" (spec assumes damage reduced by the hp spent).
5. **Economy balance pass** (carried from M8 stub) — decide whether it rides in M9
   after the fish, or becomes its own milestone slice.

---

## Session-end ritual (per CLAUDE.md)
1. Update `STATUS.md`: lurker + spitter shipped, bubble/destructible-projectile
   system added, file-map changes, known issues, M10 (Shoal + Discharger + economy
   pass) as next.
2. Append to `DECISIONS.md`: the roster-lineage supersession (M8 stub → this
   roster), the `BUBBLE` collision-layer addition, and the "player ammo can now
   pierce destructible projectiles" precedent.
3. Commit per working module; hand Snir the `git push`.
