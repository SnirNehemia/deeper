# MILESTONE 10 — The Shoal: A School That Thinks As One

*Read order for the build session: `STATUS.md` → `DECISIONS.md` →
`MILESTONE_9.md` (the Deep-Area Roster, whose Shoal spec this elaborates) →
`.claude/skills/add-deeper-enemy/SKILL.md` → this file. Plan back before building.*

*(This brief promotes M9's queued **Shoal** design into a committed build. It
**re-parks** the other two Deep-Area Roster items — the Discharger and the economy
balance pass — to later milestones so the swarm build stays undiluted. See
"Parked / queued" below.)*

M9 spent the M8 enemy spine on real content: the **Lurker** (an ambusher that
hides) and the **Spitter** (a kiter that fires destructible bubbles) — two
single-fish species, each a hand-coded behavior on top of skill-authored data. It
also *designed* two deeper-area species and left them queued.

**M10 builds the first of those: THE SHOAL.** It is the biggest lift in the
roster — not another single fish, but a **group meta-entity**: a school that moves
and decides as one organism. M9 itself flagged it as "likely its own milestone
slice," and M8 explicitly deferred school-of-fish behavior to "M9+." This is that
slice.

### Roster lineage (canon note — avoid drift)
M9's Deep-Area Roster queued three things for "M10": the Shoal, the Discharger,
and the carried-forward economy balance pass. Snir's M10 **commits the Shoal
only.** The **Discharger** becomes its own later milestone (its full M9 spec
stands, untouched), and the **economy balance pass** stays parked. Neither is
retired — they are simply not in this milestone. Record this re-scoping in
`DECISIONS.md` when M10 closes.

### Committed scope vs. parked
- **M10 ships:** The Shoal (built, tested, playable).
- **Parked (designed in M9, NOT built here):** The Discharger + the economy
  balance pass (full specs already in `MILESTONE_9.md`).

---

## Design intent (why this milestone exists)

M9 proved the spine could host *novel single-fish behaviors*. M10 proves it can
host a **group**: many cheap fish steered as one organism by a controller, with a
leader role and a group-level state machine. This is boids-style flocking
(separation / alignment / cohesion) plus a coordinated group attack — a structural
first for the codebase, where every enemy until now has been an independent
single body.

Two pillars this milestone must not violate (inherited from M8/M9):
- **Flooding is the sole death path.** The school's mass-slam routes through a
  **single** `sub.breach_from_hit()`. No new HP pool on the sub, no instant-kill.
- **Push-your-luck preservation.** The leader's dropped currency stays at risk
  until banked/docked; a grabbed swarm member behaves like any other grabbed fish
  (it leaves the flock and is at risk in the claw).

---

## Authoring model (how the Shoal is built)

The species splits into the usual two layers, but with a twist — the "individual"
is a swarm member, and a new **controller** owns the group:
- **Data (skill-authored):** one `.tres` for the member fish (tiny stats),
  `data/enemies/shoal_fish.tres` — body color, `currency_color = "teal"`,
  `ranged=false`, `grabbable=true`, Small/Big/Elite blocks. Per-tier
  `currency_drop_total` encodes the **leader prize** size (members drop ~none).
  The skill's intake blocks on every field and rejects reserved currency colors.
- **Behavior (hand-coded):** a new **controller class** `scripts/fauna/shoal.gd`
  (the group meta-entity) plus a new `Fish.Behavior.SHOAL_MEMBER` branch. This is
  the skill's explicit "confirm scope, then hand-code" path. **All numeric dials
  live in `GameFeel`** (new `FlockFeel` block), never in the `.tres` — the M8
  spine/content split, keeping everything `deeper-tuner`-friendly.

Reserved currency colors to avoid (Elemental namespace): `yellow, grey/gray,
light_grey, cyan, light_blue, red, purple, gold`. The fauna economy is
consolidated to **brown + teal** (M9); the Shoal drops **teal** (the
deep/advanced-fauna color). The exact body color/leader-marker style is confirmed
during the skill's intake with Snir.

---

## THE SHOAL — full spec

### In-game behavior
A cloud of tiny fish moving as one organism, drifting and turning together,
orbiting a single **visible leader**. The threat is the **coordinated
mass-slam**: when the sub comes near, the school **balls up tight**, then rams ONE
hull point for a **single heavy combined hit**, and **disperses** again. Kill the
leader and the rest **scatter in panic** (briefly fleeing/harmless) before
**regrouping** around a new leader. Keep thinning the school and, below a
headcount threshold, the survivors **flee for good** — so killing *members*
matters, not just the leader.

### Design decisions (confirmed with Snir)
- **Tiers = school SIZE.** Small/Big/Elite control how *many* members are in the
  school; each member is identical. A bigger tier is a denser cloud and a scarier
  mass-slam.
- **Payout = the leader holds the prize.** Members drop little or nothing; the
  **leader** carries the big **teal** payout. Each leader kill drops a chunk —
  hunting the leader through the swarm is the incentive.
- **Leader kills = regroup until thinned out.** Killing the leader scatters the
  school, which then promotes a new leader and regroups; once the surviving
  headcount falls below a threshold the school flees permanently. There is no
  "kill one fish and win" — but there *is* an end state (thin it out).
- **Currency = teal.**

### Why it's the biggest lift
It introduces a *group* meta-entity with boids-style flocking (separation /
alignment / cohesion), a **leader role** with promotion-on-death, and a
**group-level state machine** — none of which exist in the codebase, where every
enemy so far is an independent single body. Members must stay cheap (perf with
many bodies on screen), and the slam must collapse N fish into **one** breach so
the damage spine stays single-path.

### Implementation
- **New controller `scripts/fauna/shoal.gd`** (`Shoal extends Node2D`): owns the
  group state machine, spawns and steers the members, runs the flocking math,
  manages the leader (and promotion), pools the slam into one hit, and handles
  scatter / regroup / flee.
- **Group state machine (in the controller — its own enum, not `Fish.State`):**
  - `DRIFT` — wander as a loose cloud at `drift_speed_mps`.
  - `BALL_UP` — sub within `ball_up_range_m` → tighten cohesion to
    `ball_up_radius_m` over `ball_up_time_s`.
  - `SLAM` — synchronized converge on the nearest hull point at
    `slam_speed_mps`; on contact issue **one** `sub.breach_from_hit` with
    `slam_damage`.
  - `DISPERSE` — loosen back out, run `slam_cooldown_s`, → `DRIFT`.
  - `SCATTER` — on leader death: panic-flee for `scatter_time_s`, then promote
    the nearest surviving member to leader → regroup (→ `DRIFT`).
  - `FLEE` — terminal: surviving headcount < `flee_threshold_frac` × original →
    all members swim away harmlessly and despawn.
- **Members:** `Fish` instances with a new `Behavior.SHOAL_MEMBER` whose
  `_physics_process` does **no independent target-seeking** — the controller
  computes each member's steering vector (flocking + leader-follow) and assigns
  its velocity each frame. This **reuses** Fish's collision, `take_damage()` /
  `die()`, grab handling, terrain/sky handling, and `_draw()` while centralizing
  the AI in the controller. Perf: cap member count and use a slim silhouette via a
  `SHOAL` case in `_base_length_m()`.
- **Leader:** a distinct member flagged `_is_leader`, with `leader_extra_hp` and a
  **visible marker** drawn in `_draw()` (e.g. a small outline / crown over the
  member body). The leader carries the teal prize (`currency_drop_total`). On
  leader death → `SCATTER` timer → promote the nearest surviving member to leader
  (gains the marker + a tunable share of the remaining prize, `leader_drop_share`)
  → regroup.
- **Slam = one pooled hit:** members converge, and when the cluster reaches the
  hull the **controller** issues a single `breach_from_hit` (combined severity
  from `FlockFeel.slam_damage`) — not N per-fish bites. This keeps the single
  damage spine and reads as one heavy combined hit.
- **Thinning → flee:** every member death counts toward the headcount; when
  survivors drop below `flee_threshold_frac` × original count, switch the whole
  school to `FLEE`. (So thinning the cloud — not only beheading it — ends the
  encounter.)
- **Tiers → member count:** the controller reads its spawned tier (from the M8
  gen-layer blob-size clustering — 1px = Small, 2 = Big, 3+ = Elite) and picks the
  member count from `FlockFeel.small_count / big_count / elite_count`. Member
  per-fish stats come from `shoal_fish.tres` (identical across tiers); the
  **leader prize** scales per tier via the `.tres` `currency_drop_total`.
- **GameFeel additions (`FlockFeel`):** `separation_radius_m`,
  `separation_weight`, `alignment_weight`, `cohesion_weight`,
  `leader_follow_weight`, `wander`, `drift_speed_mps`, `ball_up_range_m`,
  `ball_up_radius_m`, `ball_up_time_s`, `slam_speed_mps`, `slam_damage`,
  `slam_cooldown_s`, `scatter_time_s`, `flee_threshold_frac`,
  `small_count` / `big_count` / `elite_count`, `leader_extra_hp`,
  `leader_drop_share`, `member_drop` (≈0).
- **Look:** slim per-member silhouette; teal-tinted `body_color`; a leader marker
  drawn over the leader. (Final color/marker confirmed at the skill intake.)
- **Data file:** `data/enemies/shoal_fish.tres` (member stats; `grabbable=true`,
  `ranged=false`; currency `"teal"`).

### Files
`scripts/fauna/shoal.gd` (new controller), `scripts/fauna/fish.gd`
(`Behavior.SHOAL_MEMBER` + controller-driven velocity + leader marker in `_draw()`
+ a `SHOAL` case in `_base_length_m()`), `autoload/game_feel.gd` (`FlockFeel`),
`scripts/fauna/placeholder_art.gd` (slim shoal silhouette + leader marker +
currency color), `data/enemies/shoal_fish.tres` (new), spawn wiring in
`scenes/world.gd`.

### Acceptance
Per-tier member count loads (Small/Big/Elite map to denser clouds); members flock
(stay cohesive around the leader, separate without overlapping); a BALL_UP→SLAM
produces **exactly one** pooled `breach_from_hit`; killing the leader triggers
scatter → promotes a new leader (the marker moves) → regroups; thinning the school
below the threshold sends survivors into a terminal flee; the leader carries the
teal prize while members drop ~none. `tests/test_enemy_shoal.gd` + full regression
green. (New `class_name Shoal` → run `--headless --import` once.)

---

## Parked / queued (designed in M9, NOT built in M10)

These keep their full M9 specs — surface them to Snir as the *next* milestones, do
not silently fold them into M10.

- **THE DISCHARGER** (electric station-jammer) — its own later milestone. Carries
  the new `Station.disable()` system, the bolt (reusing the `ENEMY_PROJECTILE`
  layer), and the canonical **electrical-type fauna** tag that future Yellow Shock
  rounds *heal* (`ELEMENTAL_UPDATE.md` §2). M10 touches **no** `EnemyDef` type
  fields — the electrical tag moves entirely with the Discharger.
- **Economy balance pass** (carried from the M8 stub) — parked. Whether room
  prices gate on a specific currency color and vary per room, plus the `gold` /
  `gold_drop` re-confirm, all wait for a dedicated balance milestone. Room prices
  stay at the flat placeholder until then.

---

## Out of scope (hard guardrails)
- **No bosses.** Bosses escape the add-enemy skill by design; not touched here.
- **No new sub HP / death path.** The mass-slam floods through a single
  `breach_from_hit`. Flooding stays the only death.
- **No new collision layer.** Members ride the existing `FISH` layer; the slam
  reuses the damage spine. (`BUBBLE = 1 << 12` from M9 remains the highest bit.)
- **No Elemental weapons / no electrical-type tag.** That category lands with the
  Discharger's milestone. Currency colors stay a separate namespace (brown + teal;
  reserved hues avoided).
- **No final balance.** All `FlockFeel` dials ship as first-pass numbers, tuned in
  playtest via `deeper-tuner`.
- **Discharger & economy pass are not built in M10** — re-parked only.

---

## Shared / cross-cutting work
- **`Fish.Behavior` enum** gains `SHOAL_MEMBER` (the controller drives it; it does
  no independent seeking). The **group** states live in the Shoal controller's own
  enum, not in `Fish.State`.
- **Damage spine:** the slam pools into a single `sub.breach_from_hit()` — no
  second damage path.
- **Spawn wiring:** in `scenes/world.gd`, add a demo-spawn branch that detects the
  shoal species and instantiates the **Shoal controller** (not a lone `Fish`),
  mirroring the existing demo-spawn helpers (e.g. `_ranged_demo_def()`).

---

## Build steps (M10 committed)
1. **FlockFeel + member data** — add the `FlockFeel` block to
   `autoload/game_feel.gd`; author `shoal_fish.tres` via the skill intake (body
   color + `teal` currency + per-tier leader-prize `currency_drop_total`).
   Headless check.
2. **Controller skeleton** — `shoal.gd` spawns N members (tier → count), parents
   them, and `Behavior.SHOAL_MEMBER` takes its velocity from the controller. Run
   `--headless --import` (new `class_name Shoal`). Headless check.
3. **Flocking** — separation / alignment / cohesion + leader-follow steering; the
   `DRIFT` cloud reads as one organism. Headless check.
4. **Leader + marker** — distinct leader with extra hp and a visible marker in
   `_draw()`; the leader carries the teal prize. Headless check.
5. **Group state machine** — `BALL_UP → SLAM` (one pooled `breach_from_hit`) →
   `DISPERSE` cycle. Headless check.
6. **Scatter / promote / thin-flee** — leader death → `SCATTER` → promote a new
   leader → regroup; headcount < threshold → terminal `FLEE`. Headless check.
7. **Spawn wiring** — shoal demo spawn in `scenes/world.gd`.
8. **Shoal test** — `tests/test_enemy_shoal.gd` (mirror `test_enemy_lurker.gd` /
   `test_enemy_spitter.gd`): tier → member-count load; flocking cohesion;
   one-pooled-slam; leader death scatter + promote + regroup; thin → flee;
   leader-prize vs. member ~none. → `deeper-test-runner`.
9. **Full regression** before commit.
10. **Commit** per convention, e.g. `M10: the shoal (boids flocking swarm,
    killable leader, mass-slam, thin-to-flee)`.

---

## Verification

**Headless (every step):** `"D:\Godot_v4.4.1-stable_win64.exe" --headless --path .
--quit` must show no parse/load errors. New `class_name` (`Shoal`) → run
`"...Godot..." --headless --path . --import` once. The Shoal test runs via the
`deeper-test-runner` subagent.

**Show, don't tell:** use the `capture-gameplay` skill to screenshot (a) the
school drifting as a cohesive cloud with a marked leader, (b) the ball-up/slam
against the hull, (c) the scatter after a leader kill — show Snir the result.

**Verify by playing** — launch `"D:\Godot_v4.4.1-stable_win64.exe" --path .` (or
the editor Play button):
- Approach the school: it should tighten into a tight ball and slam one hull point
  for a single heavy leak, then loosen and drift off.
- Shoot the **marked leader**: the school scatters in panic, then reforms around a
  new leader (the marker moves to it).
- Keep killing members: once the cloud is thinned enough, the survivors should
  turn and flee for good.
- Collect the leader's **teal** drop and bank it — members should drop little or
  nothing.

---

## Open items for the build session to resolve with Snir (do not guess)
1. **Member body color + leader-marker style** — confirm at the skill intake
   (teal-family; verify against the live `CURRENCY_COLORS` for the drop).
2. **Member count per tier** — `small_count / big_count / elite_count` are
   first-pass; tune the cloud density in playtest.
3. **Slam feel** — `slam_damage` / `ball_up_range_m` / `slam_cooldown_s` are
   first-pass; confirm the "one heavy hit then disperse" rhythm in playtest.
4. **Leader-prize on promotion** — does a promoted leader carry a reduced share
   (`leader_drop_share`) or does only the original leader hold the prize? Plus the
   `flee_threshold_frac` value (how thinned before they flee).
5. **Grab interaction** — confirm grabbing one swarm member behaves like any
   grabbed fish (it leaves the flock and is at risk in the claw).

---

## Session-end ritual (per CLAUDE.md)
1. Update `STATUS.md`: the Shoal shipped (boids flocking controller, killable
   leader, mass-slam, thin-to-flee); file-map changes; known issues; the
   **Discharger** + **economy balance pass** remain parked/queued as the next
   milestone.
2. Append to `DECISIONS.md`: the M10 re-scoping (Shoal-only; Discharger + economy
   re-parked), the Shoal design rulings (tier = school size, leader-holds-the-prize,
   regroup-until-thinned-out), and the **group-meta-entity (boids) precedent** —
   the first group enemy in the codebase.
3. Commit per working module; hand Snir the `git push`.
