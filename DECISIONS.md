# DECISIONS.md — DEEPER

*Append-only log. Check before re-opening anything. "Parked" = good idea, wrong time.*

## Settled (2026-06-10)
- **Structure:** run-based roguelite with persistent sub upgrades (not a campaign)
- **View:** side cutaway interior; sub stays upright (slight pitch tilt for feel; no Lovers-style spin)
- **Players:** 1–4 local co-op; keyboard-split only until fun is proven; 2 cheap XInput gamepads to be ordered before 3–4 player tests; phone-as-controller (WebSocket) deferred to post-MVP
- **Workflow:** Claude Project = design/specs; Claude Code = all building; Snir does not read code
- **Briefs:** feature-sized chunks; Claude Code self-decomposes
- **Git:** auto-commit per working feature; push at session end
- **Feel:** sub heavy-but-controllable; crew slightly weighty; all feel values in one tunable config
- **Run length target:** 30–45 min full runs (eventually); MVP win condition stays short (reach 500m)
- **Playtest cadence:** weekly with two testers — each week should ship something feelable
- **Damage model v1:** per-room water level only; no fluid sim, no fire, no wiring
- **Death penalty:** implosion keeps ~50% of salvage banked at last checkpoint buoy
- **Art:** placeholder-first; asset plan undecided; style target "cartoon shapes, pixel skin"
- **Scope:** no devlog/marketing content in this project

## Settled (2026-06-10, round 2)
- **Title locked:** DEEPER (repo: `deeper`)
- **Resolution strategy:** option (c) — HD canvas (1920×1080 base) with chunky pixel sprites at one locked texel density; smooth camera/rotation allowed
- **Ocean structure (canon change, doc §6):** open 2D ocean; runs start at a shore station, cross the shallows over the continental shelf, plunge at the shelf edge; explorable side caves in deep zones
- **Camera:** fixed framing (sub + margin) for MVP; *parked:* auto-zoom and helm-controlled zoom for later versions
- **Helm control:** direct (occupant's stick pushes the sub) for MVP; *parked:* throttle + ballast scheme, decide post-MVP
- **Crew vulnerability:** crew can drown in flooded rooms; respawns at helm room after a delay; *no* revive mechanic in v1
- **Interior movement:** jump + ladders
- **Turret:** limited arc for MVP; revisit free-aim vs arc when module placement arrives
- **Milestone 1:** crew sandbox + working helm (sub moves through a shore/shelf test map); turret, water, enemies are Milestone 2+
- **Pacing:** ~5 dev-hours/week → milestones sized to ~1–2 weeks each

## Settled (2026-06-10, round 3)
- **Collision damage:** terrain impacts breach the hull, scaling with speed; gentle bumps free (M1 still has no damage system — arrives M2+)
- **Water after patching:** auto-drains in MVP; *parked:* dedicated pump station module later
- **Engine room:** prop in MVP, helm self-sufficient; functional engine arrives as a module post-MVP
- **Repair economy:** infinite hold-to-repair in MVP; patch kits become a resource with the repair bay module
- **Enemy aggression:** small fauna territorial (avoidable), large fauna hunts on detection
- **Tone:** genuinely tense deep zones; cute crew + cozy interior as the contrast anchor
- **Docs:** PLAYTEST_LOG.md added; no further doc files until a real need appears

## Settled (2026-06-10, round 4 — Milestone 1 build)
- **Engine:** Godot 4.4.1 stable (path in CLAUDE.md). Project: 1920×1080, canvas_items/expand, nearest filter.
- **Input:** provider pattern (PlayerInput snapshot + InputHub autoload); only providers read devices. P2 interact pinned to *right* Shift by key location to avoid cross-talk.
- **Crew height:** 1.2 m (was 1.5; shortened per playtest).
- **Crew collision:** crew are solid to each other — must jump over to pass (designer call).
- **Ladders (revised from spec):** pressing a direction does *not* drop you; you can climb and move sideways at once; you stay attached until you leave the ladder zone. The conning hatch is a solid deck you stand on — you drop through it only by pressing **down**.
- **Pitch tilt:** cosmetic only — hull *and crew art* tilt together, physics bodies stay upright (so nobody slides). Tilt ∝ horizontal speed, ±5°.
- **Ride-along:** crew are parented to the sub and ride it with zero sliding (verified) — no moving-platform physics needed for the interior.
- **Buoyancy:** sub is neutrally buoyant underwater (holds depth when idle) but gets heavier as it emerges, so it floats at the surface and can't fly out (`GameFeel.sub.surface_gravity`, `Sub.SURFACE_FLOAT_DEPTH`). Vertical thrust is acceleration-based so weight can overpower it.
- **Depth meter reads 0 at the surface float** (`Sub.depth_m()` is measured below the floating waterline), clamped ≥ 0.
- **Sub hull collider:** polygon matched to the hull silhouette, tilts with the cosmetic pitch (interior footing stays upright).
- **Cave:** the shelf cave is a real carved opening in the terrain (enterable), not a painted recess.

## Settled (2026-06-11, Milestone 2 build)
- **Water rooms:** 4 cells (engine / middle / helm / conning); conning counts as a room and, being smaller, fills/drains faster (volume-weighted equalization conserves water).
- **Impact rule:** <2 m/s free; 2→6 m/s maps linearly to leak rates from ~90s-to-flood up to ~20s-to-flood; one breach max per 0.6s so a scrape isn't a shotgun blast.
- **Danger color:** BREACH_COLOR (white-orange) reserved exclusively for breaches + alerts (per art direction).
- **Station flood rule lives on the Station base** (room > 60% water → eject + refuse entry), so helm, turret, and future stations all inherit it.
- **Repair:** hold `use` 3s in ~1.2 m of a breach; release = full reset (no partial credit); progress arc drawn at the breach.
- **Air:** 10s underwater (head-height check), refills in ~2s on surfacing; drowning = cartoon pop; respawn 7s later standing in the helm room; dead player's input ignored.
- **Implosion:** total water ≥70% of combined room volume → ~1.5s crunch (shake + hull crumple-flash + fade) → world-level `reset_run()` (sub at dock, water/breaches cleared, crew alive aboard, fish home via the "fish" group). Future death penalties hook into `reset_run()`.
- **Turret:** seat in the middle flex room, tube bow-mounted; aim = move vector clamped to ±45° forward cone; `use` held auto-fires on the 1.2s cooldown; torpedoes 10 m/s straight, infinite ammo, ignore own hull (mask), terrain hit = harmless puff.
- **Fish:** Area2D, 4 states (patrol/chase/recover/return), territory ~10 m, bite = drip-tier breach + ~3s circling pass; one torpedo kill; death is hide-not-free so `reset_fish()` revives at home. Placement: cave mouth + two pillars.
- **Tooling:** after adding a `class_name` script, run `--headless --import` once or headless test runs fail with stale class-cache parse errors.

## Settled (2026-06-11, Milestone 2 playtest #1 — solo)
- **Breaches are tiered, not continuous:** one breach per hit; leak rate is a discrete step (small `1/90`s / medium `1/45`s / big `1/20`s) by impact speed bands (2 / 3.5 / 5 m/s). Total flood rate grows by *stacking* breaches, not by a single bigger leak. (Supersedes M2's continuous speed→leak curve.)
- **Door sills (overflow flooding):** each room holds water up to a knee-high floor lip (`door_sill_m = 0.5`) before it spills to the neighbour; the conning tower floods only when the middle room is near-full (`0.95` sill). Makes single-room flooding a contained drama before it spreads.
- **Crew water slowdown triggers on feet contact** (any depth), not waist; jumping clear of the surface restores full speed. Jump strength only weakens at waist depth (so you can hop out of a puddle).
- **Repair progress PERSISTS** (reverses the M2 "no partial credit" call): the bar stays on the breach when you leave, resume from where you left off, second crew can take over. Patch kits / cost still deferred to the repair-bay module.
- **Turret aim is continuous + holds:** W/S sweep the barrel (vertical bow mount; A/D ignored), it stays where you leave it, clamped to a **±60°** cone (widened from 45°). Steering still matters for aiming.
- **Torpedo cadence:** fire cooldown 1.0s (was 1.2).
- **Tilt:** breaches and the gun barrel are children of the hull visual and pitch with the sub; torpedoes fire along the tilted barrel.
- **Parked (playtester ideas for later):** map feels empty → swarms of fish in deeper zones instead of lone fish (post-MVP content). The "fish swims in front of the sub / 3D depth feel" was a happy accident worth keeping.

## Settled (2026-06-11, playtest #1 — second refinement pass)
- **Drowning respawn moved to the conning tower** (was the helm room): the tower is the last place to flood, so respawning there is the safe, sensible spot.
- **Physical door steps:** a low floor lip (`DOOR_STEP_H = 0.3 m`) at each doorway — crew must do a small hop to move between rooms. This is a *separate* thing from the abstract water overflow lip (below): the step is a collision obstacle, the water lip is a flow threshold.
- **Water overflow lip lowered to 0.125 m** (was 0.5 m / knee): flooding spreads to neighbouring rooms much sooner. (Knee height held water back too long.)
- **Breach severity is read by colour + size:** small = yellow & small, medium = orange, big = red & large. The reserved danger hue is now a yellow→red gradient; `BREACH_COLOR` (orange) stays the generic alert-flash colour.
- **Jump only weakens in deep water:** confirmed the in-water jump penalty triggers only once water covers more than half the crew height (waist/centre submerged); shallow water slows movement but not the jump.

## Open
- **Solo play:** is "lock station" enough, or does solo need an AI helper (Lovers-style pet)? Answer via solo playtests during MVP.
- **Pitch direction/strength:** confirm the lean feels right in playtest (one-number tweak).

## Settled (2026-06-11, Milestone 3 Module A — playtest #1 revision)
- **No floor-opening water flow:** flooded lower-deck rooms (claw, storage)
  only exchange water through the existing claw<->storage doorway; there's no
  separate "water drips down the ladder shaft" mechanic. A breached lower
  room pools and stays mostly put except for spilling sideways through that
  one doorway. Confirmed acceptable — visible dripping isn't needed.
- **Ladder grab zones extend to the ceiling of the room above:** both lower-
  deck ladders (claw, storage) are climbable down from anywhere in the main
  deck room above them, and back up, fixing the original "can't climb down /
  fiddly grab area" complaint.
- **Ladders alternate sides floor-to-floor:** conning ladder centered (x=0),
  claw ladder on the left side of the middle room, storage ladder on the right
  side of the engine room — climbing through multiple decks requires moving
  sideways, not just holding "up". Both are positioned clear of the door-step
  grab zones (door steps also use "up" via the shared jump key).
- **Ladder grab requires column alignment:** the crew must be horizontally
  centered on a ladder's own column (not just within the wider sensor-overlap
  band) to grab it. Fixes the shared jump/climb-up key ("up") snagging the
  crew on a nearby ladder while just running and hopping a door step.
- **Unified hull silhouette:** the hull (visual + collision) is built as the
  interior room rectangles (main deck, lower deck, conning tower) each
  expanded by a uniform outer margin (`Sub.HULL_MARGIN`), drawn/collided as
  one overlapping shape — replacing the old "two separate blobs" look.
- **Hull collision shapes must be direct children of the Sub `CharacterBody2D`**
  (not nested under an intermediate `Node2D`) — Godot 4 only registers
  `CollisionShape2D` as part of a body's collision when directly parented.
  Group rotation (cosmetic pitch tilt) is now done by recomputing each shape's
  position/rotation around the sub's origin every frame, not via a parent
  transform.
- **Smaller shore shelf map (160m x 130m, was 300m x 130m):** shore, shallows,
  pillars, and the cave are all closer together, for faster playtest loops.
  Cave entrance moved from ~x=140m to ~x=66m.

## Settled (2026-06-11, Milestone 3 Module A — playtest #1 revision #2)
- **Lower-deck ladders moved near their lower room's left wall:** the claw
  ladder now sits near the engine/middle divider (claw room's left wall, was
  mid-room), the storage ladder near the outer hull (storage room's left
  wall, was mid-room). Each is still a single shaft spanning both decks.
  Considered also adding a second ladder near the upper room's right wall
  (a literal reading of Snir's reference image), but that put a ladder back
  in the main-deck traffic path and reintroduced the "running/jumping snags
  on a ladder" bug from playtest #1 — reverted in favor of the single
  repositioned shaft per deck pair.

## Settled (2026-06-12, Milestone 3 Module A — playtest #1 revision #3)
- **Lower-deck ladders are one deck tall, not floor-to-ceiling-of-room-above:**
  each shaft now spans just the lower room's height plus a 40px overlap above
  the floor hatch (enough for a crew member standing on the hatch on the main
  deck to grab it). Visually the ladder now reads as confined to the lower
  room, matching Snir's reference image, instead of visibly poking up through
  the main-deck room above it.
- **Overlap halved to 20px** per follow-up request — still enough for the
  crew's ladder sensor to overlap the shaft from a standing position on the
  hatch (verified by `test_lower_deck`), while poking less into the main deck.

## Settled (2026-06-12, Milestone 3 Module B — salvage/storage/banking/save)
- **Module A confirmed good:** Snir played the playtest #1 revision #3 build
  (smaller map, hull silhouette, lower-deck ladders) and it holds up — no
  further changes requested.
- **Salvage source:** both scattered scrap crates placed around the map
  (shallows, each pillar, inside the cave) AND fish carcasses, which spawn
  where a killed territorial fish dies and slowly sink before settling.
  Carcasses are a **separate currency** ("fish") from scrap, not converted.
- **Pickup method (no claw arm yet):** the sub's **hull auto-collects** any
  salvage item that touches its hull bounding box (placeholder for the future
  claw module) and adds it to on-board storage. Crew don't carry items by
  hand in this module.
- **Banking trigger:** returning the sub within ~15 m of its dock spawn point
  banks all on-board storage into the persistent save and empties storage.
- **Risk:** unbanked on-board storage is lost on implosion (reset to 0) —
  the push-your-luck stakes the design doc calls for, pending real checkpoint
  buoys later.
- **Save:** a real first save file (`user://save.json` via the new `SaveData`
  autoload) persists `banked_scrap`/`banked_fish` across game launches.

## Settled (2026-06-12, Milestone 3 Module C — the salvage claw)
- **The claw is the only way to grab salvage** (replaces the Module B hull
  auto-collector): a belly-mounted arm operated from the lower claw room. The
  operator aims into a downward cone and holds `use` to extend; on contact it
  grips the salvage, auto-reels in, and deposits to on-board storage. Making
  it a manned station is the point — someone has to leave the helm/turret, the
  co-op pillar.
- **Implementation:** the arm is drawn by `SubVisual` (tilts with pitch) and
  grabs by a distance check against the "salvage" group at the tip's
  pitch-matched world position (no extra physics body). Salvage items joined
  group "salvage" for this.

## Settled (2026-06-12, Milestone 3 Module D — dry dock + sub upgrades)
- **Three upgrade classes**, per Snir: **Add room** (a second gun *with its
  own control room*), **Upgrade room** (engine boost), **Upgrade crew**
  (repair training). Catalog + prices live in `SubLoadout.catalog()`
  (gun room 6 scrap, engine 3, repairs 3) — balance knobs, easy to retune.
- **Scrap is the spend currency**; fish carcasses are still only a trophy
  count for now (no sink yet — flagged as an open question for playtest).
- **Player-placed gun room (the "submarine design planning window"):** buying
  the gun room opens a schematic where you pick a **hardpoint slot** — STERN
  (gun faces aft) or BOW (gun faces forward). Chose **predefined end-slots**
  over free-form placement: it's a real "where do you want it" decision while
  staying tractable. Stern is the clean/intended one (what Snir asked for);
  the bow slot overlaps the base bow turret's tube cosmetically (noted as a
  known issue, harmless).
- **The gun room is a *real* room**, not just a hull-mounted gun: it adds a
  7th water cell (floods/drains, shares a doorway with the end room it bolts
  onto), extends the hull silhouette + collision, and seats a second
  `TurretStation`. To support it the sub became **loadout-driven** — internal
  loops use a live `_active_rooms` (6 base / 7 with gun room) rather than the
  `ROOM_COUNT` const, `water_levels` resizes at build, and `room_rect(6)`
  returns the slot-placed rect. `TurretStation` gained `facing` + `tube_local`
  so a gun can sit anywhere and fire outward.
- **Persistence + apply:** the loadout saves to `user://save.json` alongside
  banked currency; the sub builds from `SaveData.loadout` every launch, and
  the world **rebuilds the sub in place** when you buy at the dock (fresh crew
  at spawn) so changes show immediately rather than only next launch.
- **Dry dock access:** opened with **Tab** while floating at the dock; it
  **pauses the run** and reads keys directly (a pause menu, like the existing
  Esc-to-quit — not routed through the input abstraction). W/S navigate,
  Enter buys, A/D pick the hardpoint, Esc/Tab leaves.
- **Upgrade effects:** engine boost = ×1.5 move/dive accel + top speed (per-sub
  multiplier, not a global GameFeel mutation); repair training = ×0.6 repair
  time (crew reads `Sub.repair_time_mult()`).

## Settled (2026-06-12, Milestone 3 rescope + claw rework)
- **M3 rescoped to the lower deck + salvage loop only (A, B, C).** The dry dock
  + sub upgrades (Module D) are **moved to Milestone 4**. That code stays in
  the repo (built + tested) but is re-labelled M4; not removed.
- **The salvage claw is reworked from a telescopic arm into a two-joint
  articulated arm** (shoulder + elbow), hung from the keel under the claw room,
  reaching down and swinging wide along the seafloor.
- **Control = excavator-style "operate each joint", both at once:** Left/Right
  swings the shoulder, Up/Down bends the elbow (velocity control, blended).
  Chosen over inverse-kinematics "point & reach" and over one-joint-at-a-time
  toggling, after researching real machine controls — this matches the
  standardized ISO/SAE excavator scheme, which is exactly a two-joint boom+stick
  driven one-axis-per-joint. (Refs: Wikipedia "Excavator controls"; dozr.com
  ISO-vs-SAE; StrategyWiki Construction Simulator controls.)
- **The cage is BOTH** a grabber on the arm's tip **and** a visible holding pen
  in the storage room. Catching: **press `use`** to snap the cage shut on
  overlapping salvage (deliberate, not auto-on-contact). Delivering: **press
  `use` again while folded home** to dump into the pen.
- **Manual home, no auto-return** (Snir's pick): you pose both joints back to
  the keel yourself; "home" = cage tip within `home_radius_m` of the keel
  anchor. (A one-button retract was offered and declined — kept as a fallback
  if it plays tedious.)
- **Capacities (push-your-luck):** the arm cage holds **2**, the storage pen
  holds **8** (`GameFeel.claw.cage_capacity` / `storage_capacity`). A full pen
  refuses dumps until the sub **banks at the dock**. `Sub.deposit_salvage()`
  now returns a bool and enforces the cap.
- **Tunables centralised in `GameFeel.claw`** (segment lengths, joint speeds +
  limits, grab/home radii, capacities) per the one-config rule.
- **Dedicated console** in the claw room styled like the helm/turret consoles
  ("looks like any other station"); arm + cage + storage pen drawn by
  `SubVisual` so they tilt with the hull.

## Settled (2026-06-12, Milestone 3 claw — visible cage + carry ferry)
- **Caught salvage stays visible** inside the basket cage (it rides the arm,
  staggered so two catches sit apart) instead of vanishing on grab — the cage
  is a real container you can see the haul in. `SalvageItem` became a small
  state machine: WATER → CAGED → LOOSE → CARRIED → stowed.
- **Delivery is a two-step co-op ferry, not an auto-dump:** at home the claw
  opens the cage and drops the catch **through a keel hatch onto the claw-room
  floor** as a loose item; a crew on foot picks it up (`use`), carries it (it
  rides above their head), and stows it into the storage pen (`use` near the
  cage). Carrying = hands full = no repairing. This deliberately makes storing
  salvage a second job, reinforcing the co-op pillar.
- **Storage pen moved to the storage room's right wall** (was overlapping the
  storage ladder on the left).
- **Debug mode toggle** in the salvage HUD gates the playtest-only "+1 scrap /
  +1 carcass" add buttons (hidden by default).
- Pickup range 1.0 m; storage-drop range 1.6 m; both tunable. A full pen makes
  "stow" a no-op (keep carrying) until you bank at the dock.

## Settled (2026-06-12, Milestone 4 Module 1 — grid + layout data model)
- **Grid locked at 2.5m x 3.0m cells (120x144px)**, `+x` toward the bow,
  `+y` downward, bounds guard `8x5` cells (`SubGrid`, scripts/sub/grid.gd).
- **Module catalog** (`ModuleCatalog`/`ModuleDef`) holds one entry per module
  *type*: `helm`/`tower` (core, 2x1/1x1), `room` (generic, used for the
  middle room), `engine`, `claw_room`, `storage` (all 2x1), plus placeholder
  entries for the M4 content modules `turret_room` (flags `has_firing_face`)
  and `floodlight_pod` (flags `is_pod`). Content/prices for the last two land
  in Modules 9-10.
- **`SubLayout`** holds placements (module id + grid pos + mirror flag), pods
  (pod id + host cell + face), and an inventory dict, with dict
  serialization for the save file (Module 5).
- **Starting layout ("the Minnow+")** re-expresses the M3 sub on the grid:
  engine/middle("room")/helm in a row, tower above the middle room, claw room
  below the middle, storage below the engine — matching M3 adjacency, no
  pods, empty inventory.
- This module is **data-only**: nothing in the running game changed; the
  hand-built M3 sub still builds and plays exactly as before. The new types
  aren't referenced by `sub.gd`/`sub_visual.gd` yet — that wiring is Module 3+.

## Settled (2026-06-12, Milestone 3 Module E — wrecks + salvage placement + fish guards)
- **`Wreck`** (scripts/salvage/wreck.gd): a static ~4m broken-hull placeholder
  on the seafloor. One torpedo hit cracks it open (pop puff, hull swaps to an
  "open" look with a jagged hole) and spills 2-3 scrap crates that settle
  nearby — same `SalvageItem.make_scrap`, claw-catchable like any other loose
  salvage. New `WRECK` collision layer; doesn't damage the sub.
- **Two wrecks placed**: shallows plateau (unguarded — "easy money"), and
  basin floor near the second pillar (guarded by a fish).
- **Cave treasure cluster grown** from 1 to 3 loose scrap items — best haul
  on the map.
- **Fish guards expanded from 3 to 5**: cave mouth, cave treasure cluster,
  both basin pillars (one also guards the basin wreck), and the third pillar.
- **`reset_run()` reseals wrecks**: `Wreck.reset_wreck()` (on the "wreck"
  group) reseals the hull and frees spilled loot, matching "respawn wrecks at
  home position" from the M3 brief.
- **This closes Milestone 3** (Modules A-E all done). The cage/hatch portion
  of the original Module D brief was already superseded by the claw rework's
  visible-cage + carry-ferry design.

## Settled (2026-06-12, ROOM_SYSTEM.md reconciliation with M4)
- **One uniform cell, 5m x 3m** (settled at Checkpoint 1 playtest 2026-06-13;
  tried 3.75m too narrow, 7.5m too wide), replaces the M4-draft's mixed 2x1/1x1
  footprint catalog — every room (helm, tower, control room, engine, claw
  room, storage, turret room) is exactly one cell. Larger (multi-cell) rooms
  are deliberately deferred until a specific one is designed
  (`ROOM_SYSTEM.md` §7) — not to be generalized speculatively.
  - 5m = five 1m "sections" (s1-s5), a pure authoring layer for where a
    room's elements (station, hatch, gun, claw, ladder) sit. Sections bake to
    local coordinates *before* `rebuild_from_layout` runs and never reach the
    pipeline, water model, hull generator, or `validate()`.
- **Ladders are parity-placed, never authored:** odd floors (counted from the
  tower down) put their ladder in section s1, even floors in s5 — same "sides
  alternate floor-to-floor" rule from M3 Module A, now expressed on the
  section grid instead of hand-placed per room.
- **The room economy becomes two separate purchases:** buying a **slot** (an
  empty, real, generated room-shell — walls/floor/ceiling/auto-doors/ladders,
  just no station — adjacent to the existing hull, "Option B": the hull
  visibly grows the instant you buy it) is independent from buying a **room**
  (a module bought into inventory, then placed into an owned empty slot).
  Slot price escalates on slots-owned only, on its own track separate from
  room-price escalation. This becomes M4's first *content* module (M4-2),
  ahead of the shop/assembly work, since a bought room has nowhere to go
  without a bought slot.
- **Costs become multi-resource:** scrap (`sc`) plus small/medium/large
  carcass tiers (`s_ca`/`m_ca`/`l_ca`, `ROOM_SYSTEM.md` §4.2). Only small
  carcasses drop today (from the existing fish); `m_ca`/`l_ca`-priced
  upgrades ship **visible but unaffordable** until later milestones add bigger
  enemies — plus a **debug-mode "+1 medium/+1 large carcass"** button
  alongside the existing scrap/small-carcass debug adds, for testing those
  paths early.
- **Control room (the M3 "middle room") stays a single uniform cell** — it
  only ever holds one station, so it doesn't need the deferred larger-room
  treatment.
- **Tower keeps its own cell** (always the top room); what station/ability
  lives in it is still an open design question (parked below).
- **`SKILL_STUB_add_room.md` supersedes `SKILL_STUB_add_module.md`** (now
  dead) — the add-room skill is scaffolded at M4 kickoff with the
  canon-derived parts (room-def schema, section/ladder/economy/upgrade
  conventions) written now, and the code-wired parts (file paths,
  `GameFeel` keys, `validate` rule-add mechanism) filled in once M4-10 (the
  first hand-built purchasable room) exists. The skill is then validated by
  re-deriving that room from scratch in a scratch branch.
- **Corrected M4 module order** (supersedes `MILESTONE_4_v2.md`'s 1-11
  numbering; full list in `STATUS.md` "M4 module order"): grid resize (1b) →
  slot economy (2, new) → validation (3) → generated interiors/connections (4)
  → generated hull/water/damage (5) → Checkpoint 1 → save (6) → dock shop with
  multi-resource costs (7) → assembly (8) → pods (9) → Checkpoint 2 → first
  hand-built content room (10) → add-room skill (11) → second room via the
  skill (12) → close-out (13).

## Settled (2026-06-13, M4-3)
- **`validate(layout)` lives in `SubValidator` (`scripts/sub/sub_validator.gd`)**,
  not on `SubLayout` — keeps the data class dumb and gives the rules/recovery
  function their own home, per `MODULAR_SUB_IMPLEMENTATION.md` §10 "one
  validator." All 7 §5 rules implemented, plus the slot-overlap addition from
  `ROOM_SYSTEM.md` §4.1 (a slot can't overlap a placement's cell).
- **Connectivity treats bought slots as hull**, same as placed rooms — both
  must reach the helm via grid adjacency. This anticipates the M4-4 pipeline
  generating real doors/ladders along the same adjacency.
- **Load-recovery (`SubValidator.recover`)** uses a "first claim wins" rule:
  core placements (helm/tower) always keep their cells; non-core placements
  keep theirs if unclaimed, otherwise return to inventory; slots/pods that no
  longer fit are silently dropped (no separate refund — per §5, this is the
  designed recovery path, not an error). This handles the realistic case
  (a stray overlapping room from a rule change) cleanly; it does not attempt
  to repair deeper structural breaks (e.g. a tower left unsupported after its
  support room is stripped) — out of scope until a real save-compat break
  surfaces one.

## Settled (2026-06-13, M4-4 — the layout-driven sub)
- **One geometry pipeline, in code.** `SubGeometry.build(layout)` compiles a
  `SubLayout` into room rects, auto-doorways (horizontal adjacency), and
  parity-placed ladders (vertical adjacency); `Sub` generates all interior
  collision, water cells, hull rects, and seat positions from it. No hand-
  authored geometry remains in `sub.gd`. The s1-s5 authoring sections bake to
  x-offsets in the compiler and never reach the live sub/water/validate.
- **Helm-row floor anchors the origin at y=0.** The compiler centers on the
  occupied bounding box; `Sub` re-anchors (via `SubGeometry.translate`) so the
  helm row's floor is at y=0, preserving the "floor top = y=0" convention every
  seat/claw/crew calc relies on.
- **Gun room dropped until M4-9.** Making the sub layout-driven, the M3
  `SubLoadout` bolt-on gun room has no home; it returns as a *placed* turret
  room in M4-9. Until then the sub is the 6-room Minnow+, `engine_boost`/
  `fast_repair` still apply, and the M3 dry-dock "second gun" purchase records
  in the save but reshapes nothing. **Why:** `MILESTONE_4_v2.md` already
  schedules the turret room as M4-9 content; bridging it in would be throwaway.
- **Ladders sit at the inner edge of their parity section, not the section
  centre.** The reserved ladder sections (s1/s5) hug the side walls, but a room
  can have a doorway on the same wall, and a wall-hugging ladder traps the crew
  on the door header.
  So the shaft is offset inward (still within s1/s5) for clearance, mirroring
  how the M3 hand-built sub hand-placed ladders clear of doorways. **Revisit at
  Checkpoint 1** if the ladder/door spacing reads wrong.
- **Accepted geometry deltas (no compatibility shims):** uniform 3m lower deck
  (lost its squat 2.5m), full-size tower cell; room water indices are placement
  order (engine 0, middle 1, helm 2, tower 3, storage 4, claw 5 — claw/storage
  swapped from the old hand-built numbering).
- **Cell width = 5m, sections = 1m (Checkpoint 1 playtest, 2026-06-13).** The
  3.75m draft read too narrow and 7.5m too wide; 5m settled it, making each of
  the 5 sections exactly 1m. (`SubGrid.CELL_W_M = 5.0`.)
- **Ladder overhang into the room above = 24px** (was 48px) — the ladder poked
  up into the upper room too far (Checkpoint 1). `SubGeometry.LADDER_OVERHANG`.
- **Every in-room element is anchored to its authored section, not a wall
  offset** (Checkpoint 1 r2). Per `ROOM_SYSTEM.md` §6: control-room (helm)
  station s3, base-gun (middle) station s3, claw station s3 + claw base b3 +
  dropping hatch s2, storage cage s3. `Sub._compute_anchors` computes each x via
  `SubGeometry.section_center_x`. (The base gun's tube is still the M2 bow mount
  — the proper wall-mounted gun room is M4-9.)
- **Ladder width = 0.9m** (`HOLE_W = 0.9 * PPM`, narrowed from 1.0m at
  Checkpoint 1 — the ladders read too wide). Hole, shaft, and rails all scale.
- **Gun room stays scheduled for M4-9** (not corrected now). The current weapon
  is the M2 base bow turret (gunner in the middle room, tube at the bow tip) —
  the middle room has no exterior side wall, which is exactly why a real gun
  belongs in its own room on an outer edge. `validate()` rule 5 already requires
  a turret room's firing face to be exterior, so M4-9 can't place one anywhere
  it'd be bricked in.

## Settled (2026-06-13, M4-7c follow-up)
- **Tab-eats-focus bug fixed:** `SalvageHud`'s Debug-mode toggle and its +1
  scrap/+1 carcass buttons now set `focus_mode = Control.FOCUS_NONE`. Without
  this, clicking them gave a `Button` keyboard focus, and Godot's UI controls
  consume `Tab` for focus-navigation before `world.gd`'s `_unhandled_input`
  ever sees it — so the dry dock stopped opening after any debug-button click.
  Any future UI buttons added to the world (not inside a menu) should set this
  too, or Tab-to-open-dock will silently break again.
- **Two shop/assembly visual requests from Snir, parked for later modules
  (not in scope for M4-7c):**
  1. **Slot-buying on a sub blueprint:** instead of (or alongside) the text
     "Build a slot at (x,y)" list, show a diagram of the current hull with
     faint ghost cells over each buyable position, price labelled on top —
     so buying a slot is a visual, spatial choice. **Belongs in M4-8** (the
     assembly screen already needs this grid diagram for placing inventory
     rooms into slots) — build it once, there, rather than twice.
  2. **Richer room shop:** each purchasable room gets a short description, an
     icon indicating its kind (weapon/arm/storage/etc.), and a sidebar listing
     rooms currently in inventory. Needs new `ModuleDef` fields
     (`description`, `icon`/`kind`) — **batch this with M4-10** (the first
     hand-built content room), where that data schema is being defined anyway
     for the add-room skill (`ROOM_SYSTEM.md` §6, `SKILL_STUB_add_room.md`).
     Low payoff today since only the Turret Room is purchasable.

## 2026-06-14 — Slot levels, pricing, edge rule, Assembly nav (settled)
Snir's 7-part request, scoped via AskUserQuestion:
- **Levels**: the conning tower's grid row is level 0 and stays the tower's
  row alone forever — slots can never be bought there or above. The row
  directly beneath the tower is level 1, the next level 2, etc.
  (`SubLayout.level_of`).
- **Pricing**: `slot_price(level, slots_owned) = 2 + slots_owned + 2*(level-1)`
  — i.e. base 2 scrap for a level-1 slot, +2 scrap per level below that, and
  **every slot already owned (any level) adds +1 scrap to all future slot
  prices**. Slots and rooms remain on separate price tracks (per the earlier
  M4-2 decision).
- **Crew spawn**: both players now start in the conning tower
  (`Sub.tower_seat_local`), seats reserved for up to 4 (sections 2,4,1,5 —
  section 3 stays clear for the ladder). Only p1/p2 are wired; p3/p4 seats
  exist but nothing spawns there yet (no 3rd/4th crew in the game).
- **Firing-face edge rule** (`SubValidator` rule 8): a room with a firing
  face must sit at the far left or right edge of its level's occupied cells —
  mid-row placement is refused even if the firing-face cell itself is clear.
- **Assembly nav rework**: arrow-key 2D cursor (`_assembly_cursor`) over a
  cell->action map (`_assembly_actions`); only cells with an action (buy
  slot / place room / return room) are reachable. `M` is now the mirror key
  (freed `A`/`D` for movement). New `SaveData.return_room_to_inventory`.
- **Deferred to M4-9/M4-10** (Snir's call, "edge-rule now, rest stays
  M4-9/M4-10"):
  - Empty slots becoming walkable rooms the crew can enter (needs
    `SubGeometry` to generate a real room-shell, not just hull+floor, for a
    slot cell).
  - The Turret Room's own station and a working gun (this is M4-10's "first
    hand-built purchasable room with a real mechanic" by design).

- **M4-10 scope** (2026-06-16): implemented the Turret Room's gun station
  (the "real mechanic" part of M4-10) plus a one-line `ModuleDef.description`
  shown in the Shop tab. Deferred to later: per-room `icon`/`kind` tags and a
  dedicated Shop-tab inventory sidebar — the description line covers the
  immediate "what does this room do" need without a new UI widget.
- **M4-11 scope** (2026-06-16, Snir's call): the `add-deeper-room` skill
  (`.claude/skills/add-deeper-room/SKILL.md`) is written and covers
  everything that exists today — catalog entry, anchors, mechanic,
  validation, art, tests. **Per-room upgrade trees (ROOM_SYSTEM.md §5) are
  explicitly out of scope and flagged as a follow-up**: no generic
  upgrade-tree mechanism exists in code (only the unrelated ship-wide Engine
  Boost / Repair Training). The next room built via this skill should skip
  its upgrade tree and note it, rather than a bespoke upgrade menu. Building
  the generic upgrade-tree system is a separate future module.
- **M4-12 scope** (2026-06-16): the Bullet Room (`ROOM_SYSTEM.md` §6 "Bullet
  weapon room") is the second room built via the `add-deeper-room` skill —
  chosen over the floodlight pod (already done in M4-9) as the closer relative
  to M4-10's Turret Room, to validate the skill on a near-identical-but-tuned
  gun room. `TurretStation` was generalized (`fire_cooldown`,
  `projectile_speed`, `use_bullet`) and `Torpedo` gained configurable
  `lifetime`/`radius` so the new `Bullet` projectile (`extends Torpedo`) reuses
  flight/hit/despawn/fish-kill logic with its own feel and look. Per the M4-11
  scoping decision, no per-room upgrade tree was added (moot here — §6 doesn't
  specify one for this room either).

## Settled (2026-06-16, round 4 — starting layout rework)
- **The starting sub's placeholder "Room" module is retired.** Both gun
  positions (bow and stern) are now real, placed gun rooms from the room
  economy: a placed Turret Room (bow) and a placed Bullet Room (stern). The
  starting layout is informally "the Minnow+2": Engine/Helm/Turret Room on the
  main row (tower over the helm), Bullet Room/Claw Room/Storage below.
- **The tower's support is now specifically the helm's cell** (tower sits
  directly above it). Consequence: picking the helm up for relocation now
  makes the layout invalid until it's placed somewhere with something under
  the tower again — `SubValidator`'s "missing helm = still valid mid-edit"
  carve-out from 2026-06-15 no longer applies when the helm is directly under
  the tower (which it now always is in the starting layout).
- **A placed gun's firing-face cell is permanently un-buyable as a slot** —
  `SubLayout.buyable_slot_positions()` excludes it outright, rather than
  relying on validation to refuse a slot purchase there.
- Item 5 (Floodlight Room bundled with its pod, placeable on any exterior
  face incl. top/bottom) and item 4 (the Assembly dropdown for placing/
  removing/upgrading rooms and choosing a gun room's firing side) are
  accepted asks, not yet built — see STATUS.md "Next."

## Settled (2026-06-16, round 5 — dry dock drops the Upgrades tab)
- **Item 2 of Snir's latest brief is done**: the dry dock's "Upgrades" tab
  (Second Gun + Control Room / Engine Boost / Repair Training) is removed
  entirely. The dock opens straight on the Shop; Tab cycles Shop <-> Assembly
  only (was a 3-way Upgrades -> Shop -> Assembly -> Upgrades loop).
- **Engine Boost, Repair Training, and the M3 "second gun room hardpoint"
  purchase flow are dropped for now** — chosen option was "remove the tab and
  drop those upgrades for now" (a future upgrade-tree pass can re-add them).
  `SubLoadout` (the data class behind `move_mult()`/`repair_time_mult()` and
  the old `gun_room` slot) is left in place but dormant/unreachable — nothing
  currently calls `SaveData.purchase()`. Not deleted, since it's small and
  cheap to reconnect later; flag for cleanup if a future pass decides not to
  bring these back.
- Items 3-5 (inventory list in Shop/Assembly, Assembly dropdown's "feature
  position"/"upgrade" options, Floodlight Room bundled with its pod) remain
  accepted-but-pending — see STATUS.md "Next."

## Settled (2026-06-17, round 6 — Assembly UI polish)
- **Item 3 done**: an "INVENTORY (unplaced)" panel is pinned to the right
  edge of the dry dock in both Shop and Assembly, listing every owned-but-
  unplaced room/pod with its count.
- **Cell-action and pod-face menus are now real dropdowns** — a floating
  panel of rows anchored near the selected cell (flips/shifts to stay
  on-screen), highlighted row filled in. Replaces the old single crammed
  line of text. Face options are labelled "Left face"/"Right face"/etc.
- **A placed gun's reserved firing-face cell is now labelled** ("reserved /
  gun's line of fire") in the Assembly blueprint instead of being a blank,
  unexplained gap — this was Snir's "some slots aren't available and I don't
  understand why."
- Fixed the unreadable double-text on a selected owned slot (the
  "Interact: open menu" prompt now draws below the "empty slot" label
  instead of on top of it).
- Item 4's "feature position" (gun firing-side choice) and "upgrade" stub
  menu options, and item 5 (Floodlight Room bundled with its pod), remain
  accepted-but-pending — see STATUS.md "Next." Snir noted the dropdown should
  make pod placement clearer once these land; revisit with him after he's
  tried the new dropdown.

## Settled (2026-06-19, round 7 — floodlight bundle, weapon defaults/rotate, claw clearance)
- **Floodlight Room + pod are now a single 10-scrap purchase** (round 4's
  deferred decision, finally implemented): buying the room grants the pod too;
  placing the room chains straight into the pod's face picker. Both now have
  placeholder visuals (console mark inside, lamp+beam outside on the chosen
  face) — previously neither rendered anything.
- **Weapon placement default**: turret/bullet rooms default to firing
  bow-ward ("right"); if that's blocked, placement **auto-flips** to
  stern-ward ("left") instead of refusing. An explicit M-toggle choice is
  still honored as-is (no silent override). A placed gun room's menu now
  offers **"Rotate"** to flip its firing direction later, shown only when the
  flip would still validate.
- **New validator rule 9**: the cell directly below a placed Claw Room must
  stay clear (claw drop path) — reserved the same way as a gun's firing line,
  never buyable/placeable.
- **Open question for Snir**: does "place the claw with a dropdown" mean the
  claw itself should get a left/right directional choice (a new mechanic,
  bigger change), or was protecting its current straight-down drop path the
  whole ask? Parked until he weighs in — see STATUS.md Module 16.

- **Floodlight Room redesign (2026-06-19, M4-17)**: the room and its lamp are
  **one inseparable unit**, like the Bullet Room's built-in gun — no
  detachable pod UI for the player (placing/returning the room auto-attaches/
  detaches the lamp under the hood; the generic pod plumbing stays for
  internal use). The lamp is now a real station: left/right rotates the beam
  (`aim_angle`), up/down scales `spread_factor` (both the cone's width and
  length together). The cone's tip sits at the hull with its base flaring
  outward (previously reversed), the base-lamp circle is gone, edges are
  softened (layered translucent triangles), and the cone is 3x longer
  (`base_length_m` 3m -> 9m).

- **Any-outer-face placement (2026-06-19, M4-18)**: turret/bullet rooms, the
  claw, and the floodlight's lamp can now face/rotate to **any of the four
  hull sides** (right/left/top/bottom), not just left/right. Placement
  auto-picks the first legal facing; a "Rotate" menu option cycles through
  the rest. This also settles M4-16's open question — the claw can drop in
  any direction, not just straight down.
- **Floodlight beam realism (2026-06-19, M4-18)**: the beam's cone radius is
  fixed at 10m and its base width follows `b = 2*sqrt(R^2 - h^2)` as the
  lamp's effective height (h, starting at 5m) changes with zoom. Brightness
  fades along the beam's length via a sigmoid centered at 5m (half the
  radius) with a 5m transition width.
- **Debug top-ups bumped to +100 (2026-06-19, M4-18)**: the dry dock's debug
  "+1 Scrap"/"+1 Carcass" buttons now grant +100 each, for faster
  playtesting.

- **Floodlight on/off + sharper decay (2026-06-19, M4-19)**: the seated
  floodlight crew can toggle the lamp on/off with "use"; off, no beam is
  drawn at all. `decay_width_m` lowered 5m -> 2m for a sharper light/dark
  edge.
- **Rotate is now a pick-from-list, not blind-cycle (2026-06-19, M4-19)**:
  the Assembly "Rotate" menu item opens a sub-dropdown of every currently-
  legal facing/face (`SaveData.rotate_options`/`set_facing`), replacing the
  old single-step auto-cycle (`rotate_room`).
- **Dropdown Up/Down fixed (2026-06-19, M4-19)**: Up/W and Down/S now move
  the highlight in opposite directions in any Assembly dropdown (previously
  both moved it the same way — a longstanding bug).
- **Flagged for later milestones (2026-06-19, out of scope this session)**:
  a damage/HP system (bullet 1 dmg / torpedo 5 dmg / fish 5 HP — no HP
  fields exist yet, every hit is currently an instant kill); making
  bought-but-empty hull slots non-physical instead of solid grey rooms (a
  `SubGeometry.generate()` rework); and a room-reachability check warning on
  dock-exit if a placed room has no crew path (most useful once the slot
  rework lands). Each spawned as its own background task.

- **Floodlight beam polish (2026-06-19, M4-20)**: the beam's lateral edges
  are now soft (layered nested trapezoids fading outward); the beam is drawn
  before the hull silhouette so the hull occludes it from the sub's
  interior; and the pod's exterior face is now a `reserved_cells()` entry,
  blocking room placement there like a gun's firing face or the claw's drop
  cell.

- **Face-relative aim controls (2026-06-20, M4-21)**: a weapon or floodlight
  mounted on a side wall (left/right) aims with W/S; one mounted on top/bottom
  aims with A/D — implemented as shared static helpers `Station.
  face_aim_input()`/`face_cross_input()` so `TurretStation` and
  `FloodlightStation` don't duplicate the sign logic. The floodlight's zoom
  always uses whichever axis its aim isn't using.

- **Beam falloff and range tied to current reach (2026-06-20, M4-21)**: the
  floodlight's sigmoid light decay is now centered at `h/2` with width `h/8`
  (h = current reach), so falloff always scales with the beam's length instead
  of using fixed meter values. The drawn reach is also scaled by
  `cos(aim_angle)`, so the beam shortens as it's aimed toward the wall it's
  mounted on instead of visibly poking through it.
  **Superseded by M4-22 below** — the `cos(aim_angle)` range scaling had the
  opposite of the intended effect (cone widened toward the hull) and was
  removed.

- **Floodlight rotation capped at the hull, outward-zoom fix (2026-06-20,
  M4-22)**: `aim_angle` is now clamped to `90deg - atan(half_width_m /
  height_m)` — a right angle minus the cone's own half-angle — so the beam's
  near edge can swing at most flush with the lamp's mounted wall, never past
  it into the hull; this loosens as the beam lengthens (narrower cone, more
  room to rotate) and tightens as it shortens/widens. Removed `GameFeel.
  floodlight.rotate_cone_half_angle_deg` (the old fixed 75° clamp) and the
  M4-21 `cos(aim_angle)` range shrink — the rotation cap alone is sufficient.
  New shared helper `Station.face_zoom_input()`: zooming outward (away from
  the hull) always lengthens the beam, zooming toward the hull always
  shortens it, on any wall.

- **Reserved-cell labels, tower-relative hull length, floodlight height range
  (2026-06-20, M4-23)**: Assembly's "reserved" cells now show what's reserving
  them (`SubLayout.reserved_cell_types()` -> "gun"/"claw"/"floodlight") instead
  of a one-size-fits-all "(gun's line of fire)". The hull's horizontal growth
  cap is now anchored to the conning tower's column
  (`SubLayout.tower_x_bounds()`: 3 columns left, 5 right, 9 total) instead of
  a fixed 8-wide box (`SubGrid.CELLS_LEFT_OF_TOWER`/`CELLS_RIGHT_OF_TOWER`);
  the vertical cap (`SubGrid.MAX_CELLS.y` = 5) is unchanged. The floodlight's
  minimum reach widened from 1m to 3m; max stays just under `cone_radius_m`
  (~9.9m, tuned in-editor by Snir) — 15m was tried first but made the cone
  vanish at full zoom since
  `base_half_width_m(h)` goes to 0 as h approaches the cone radius.

## Milestone 5 — Teeth & Consequences (settled 2026-06-15)
- **Direction:** "Teeth & Consequences" (combat depth) chosen over "The
  Descent" (depth zones) — the latter is parked as its own future milestone.
- **Damage-to-sub model (supersedes the earlier "hull HP" idea):** the sub has
  **no integrity pool**. A hit spawns a breach in the struck room; bigger/
  harder hit = bigger breach = faster water inflow. Flooding -> implosion
  remains the only sub death path. Combat damage collapses onto the existing
  M2 breach/water system rather than adding a parallel model.
- **Repair:** crew hand-patching at the breach stays the fast path (M2). The
  conning-tower **Hull station auto-patches the nearest breach within ~4
  rooms, slower than a hand-patch.** Both coexist; hand-patch is always
  faster. This resolves the conning-tower "what lives here?" question below —
  **the Hull station does.**
- **Enemy HP:** fish HP = 5, torpedo damage = 5, bullet damage = 1 — one
  torpedo still one-shots a fish (M2 acceptance preserved), bullet gun needs a
  ~5-round burst. Wrecks get HP too (one torpedo still cracks; bullet burst
  also works).
- **Aggression split (design doc §7):** small fauna stay territorial (attacks
  only inside its territory, breaks off when the sub leaves — M2 behaviour,
  unchanged); a subset are **hunters** that chase the sub across the map once
  detected, giving up only after a sustained out-of-range timer. Same fish
  art, toggled by `is_hunter`.

## M5 follow-up (settled 2026-06-15, before playtest)
- **Aggression split, revised:** the M5 "hunter" archetype (chase past the
  territorial leash, give up after a timer) was applied to the basin pillar
  fish and felt confusing — a purple fish that looked territorial but acted
  like a hunter. **Pillar fish are back to plain territorial.** The
  relentless-chase feel now lives in a new dedicated archetype,
  **basic_chaser** (green, elongated, 8 HP, never gives up once it locks on,
  short backoff after each bite). `is_hunter` stays in the code for a future
  enemy that needs the "chase-then-give-up" behaviour; right now nothing uses
  it.
- **Nothing persists between rounds (for now).** Every launch and every run
  reset wipes banked salvage, loadout, and layout back to the stock Minnow+.
  This was a stopgap to unblock testing (a too-big sub from a prior run made
  the new fish unreachable) — Snir will decide later what, if anything,
  should carry over between runs.
- **New salvage tier: medium carcass (green),** dropped only by basic_chasers.
  Same pipeline as the existing carcass (claw → storage → bank), just a third
  `SalvageItem.Kind` and a third banked total. No new mechanic, just a
  higher-value drop to mark the chaser as a better kill.

## Re-parked for a future milestone
- **Non-physical empty slots** and **dock-reachability warning** — the two M4
  cleanups noted in MILESTONE_5.md's scope discipline; the M5 3-module slice
  had no room for them. Revisit in M6+.

## Parked
- ~~**What station/ability lives in the conning tower?**~~ **Resolved (M5-C1,
  2026-06-15): the Hull station** — remote auto-patch of the nearest breach
  within 4 rooms, slower than a hand-patch.
- Snappy Overcooked-style crew movement (kept as switchable preset; playtest against weighty)
- Phone-as-controller via WebSocket (post-MVP, only if gamepads aren't enough)
- Godot MCP for Claude Code (revisit only if visual-bug iteration becomes painful)
- Fire/electrical damage systems (water must prove fun first)
- EVA dive-suit module (v1 content at earliest)
- Cosmetics (paint, flags, googly eyes) — vertical-slice era

## Settled (2026-06-16, Milestone 6 Module 1)
- **Empty slots have no hull:** a bought-but-unfilled assembly slot is purely
  reserved space — it has no exterior hull rect, no collider, and doesn't
  render. The hull/collider is generated only from cells holding an actual
  placed room.
- **Empty slots don't bridge connectivity or block outward faces:** the
  "every room must connect back to the helm" check now walks placed-room
  cells only (an empty slot can't be the only thing holding two rooms
  together); pod/turret/claw "must face open exterior" checks likewise treat
  an empty slot as open, not as blocking hull.
- **Dry Dock close-time check:** leaving the dock now re-runs the full layout
  validator and refuses (with the violation text, staying in the dock) if any
  placed room is left disconnected from the helm.


## Settled (2026-06-17, Milestone 6 close-out)
- **Dry dock entry: tower console only.** Tab no longer opens the dock from the
  world view. The only entry point is `use` at the hull station in the conning
  tower. Rationale: consistent with "every action comes from a crew station"
  and avoids accidental dock-opens while moving.
- **Dock mode switch: Q key.** Inside the dry dock, Q switches between Shop and
  Layout (was Tab). Rationale: Tab is a system/browser key and breaks the
  "no Tab in gameplay" convention; Q matches the game's existing "secondary
  action" key for P1.
- **P2 keybinds: / (interact) and . (use).** Replaces Right-Shift and Enter.
  Rationale: Right-Shift is location-pinned (fragile) and Enter is grabbed by
  some system events; / and . sit naturally on the right side of a UK/US
  keyboard next to the arrow cluster.
- **Fish movement: surface-line blocking, not bounding-box blocking.** Fish
  respect the water surface and pocket boundaries using `water_surface_y` +
  per-pocket surface-y comparisons, not sky-zone bounding-box rects (which
  covered irregular shapes and caused false positives in valid water areas,
  breaking fish AI entirely).
- **Telescopic arm: deferred to its own session.** New room type with a
  dedicated station mechanic (aim with A/D, extend with S, retract with W,
  Q picks up and auto-deposits into hold). Orientation-aware like the
  floodlight. Too large for the M6 polish pass; should be its own milestone
  module brief.

## Settled (2026-06-20, Milestone 7 — Hands on the Deep)

- **Direction chosen:** M7 is a tight one-new-room slice — ship the parked
  telescope, slim the base sub, demote the claw — over the larger candidate themes
  (combat/encounter depth, sensing, progression/meta). Rationale: highest
  fun-per-dev-hour (two modules cash in already-parked work), feelable at the first
  playtest, and it builds directly on the M6 map/terrain pipeline. The other themes
  are noted as future-milestone candidates.

- **Add-room skill promoted to a real, code-verified skill (M7-0).**
  `SKILL_STUB_add_room.md` is now built out as `.claude/skills/add-deeper-room/
  SKILL.md`, with the stub's deferred TODOs filled against real code (the M4
  pipeline, `validate`, section-bake, multi-resource costs, and the §6 base-gun /
  bullet reference rooms all exist). The telescope (M7-2) is the skill's first
  validation pass — built *via* the skill, not by hand. Supersedes
  `SKILL_STUB_add_module.md` (already dead) and retires the stub. If the skill
  can't be made clean, that's a design-level signal to surface before later
  room-heavy milestones — see the skill's §8.

- **Engine room retired; folded permanently into the control room.** There is no
  engine room and there will not be one — propulsion is an inherent property of the
  sub / control room, not a placeable module. **This reverses the 2026-06-10 round
  3 decision** ("functional engine arrives as a module post-MVP", DECISIONS.md
  line ~35): we are choosing *never* rather than *later*, because the engine room
  never earned its slot and the leaner base sub reads better. Engine removal is
  **structural only — movement must play identically** (no tuning change intended).

- **"Engine Boost" upgrade deleted (not re-homed).** With no engine room, the
  parked Engine Boost upgrade has no host; remove it from the dormant upgrade data
  and treat it as retired. **Repair Training and the rest of the dormant
  `SubLoadout` plumbing are untouched** (2026-06-16 round 5 still holds). Note: this
  thins the dormant upgrade system to one live concept (Repair Training) — worth a
  glance when the upgrade-tree reconnection is eventually scheduled (still parked,
  gated behind the post-art elemental update per Snir).

- **Base sub reshaped:** the starting loadout is now **control + bullet (main row),
  conning tower above the control room, telescope room** as the collector. The base
  **loses** the engine room, the dedicated claw room, and the dedicated storage
  room. **This supersedes the 2026-06-16 round 4 "starting layout rework"** (the
  six-room Minnow+) — update that entry's loadout to the M7 base. Old six-room saves
  load via the existing `SubValidator.recover` drop-what-no-longer-fits path.

- **Telescope is the base collector; the claw is demoted to a buyable alternate
  (not deleted).** The claw keeps its full M3 mechanic (two-joint excavator, Q to
  cage, foot-ferry to its own built-in pen, capacity 4) — it just moves from base
  equipment into the shop. Players can run telescope-only, or buy a claw and run
  both; rearrange free at the dock (M4 rule).

- **Telescope mechanic (supersedes `ROOM_SYSTEM.md` §6 "Claw telescope room").**
  The §6 entry (a `[-]` starting room: up/down extend, right/left rotate, `use` to
  close the claw, capacity 4 on the claw, no aim, no cages) is **replaced** by the
  M7 spec: **A/D aim (hull-clamped arc), S extend, W retract, Q grab (explicit,
  never on-contact), ~8 m reach, two onboard cages (s2 + s4, capacity 6 each = 12),
  auto-deposit the tip's catch into the cages on retract.** Orientation-aware like
  the floodlight. **Rewrite the §6 entry to match at M7 close-out.** This also
  **resolves the 2026-06-17 parked "Telescopic arm: deferred to its own session"**
  (DECISIONS.md line ~761) — that park is now fulfilled. (Note the one control
  delta from the original park: the original said "Q picks up and auto-deposits into
  hold"; M7 keeps Q as an explicit *grab*, and "auto" applies only to the
  retract-deposit step — grab is never on-contact.)

- **Salvage storage is now per-collector, not a shared room.** The telescope
  auto-deposits into its own two cages; the claw (when bought) ferries to its own
  pen. The standalone storage room **leaves the base loadout** and returns only as
  a later purchasable room when capacity is a real constraint. **Push-your-luck is
  unchanged: cage/pen contents are lost on implosion until banked at the dock.**
  The telescope is **not** a safe-income exception — its cages are lost on
  implosion exactly like the claw pen; auto-deposit removes the *foot-ferry*, not
  the *docking-to-bank* step.

- **Telescope reach ~8 m** (`GameFeel.telescope.reach_m`) — long and straight, the
  "long tool," versus the claw's short wide swing. Several cells out into open
  water, measured from the keel base. (Reminder: the cell is 5 m wide = 5 ×
  1 m sections, `ROOM_SYSTEM.md` §2 — reach is *not* in section units.)

## Re-parked for a future milestone (2026-06-20)

- **Three room types parked out of M7** to keep the telescope slice tight (one new
  room only). Full briefs in `FUTURE_ROOMS.md`. Suggested homes are non-binding —
  confirm at each milestone kickoff:
  - **Heavy torpedo room** — *already authored in `ROOM_SYSTEM.md` §6*; awaits a
    *build* milestone (suggested: an arsenal-expansion slice). Its real cost is the
    post-launch guidance (weapon owns player input after firing) + two-stage
    detonation. Not a new design, a new build.
  - **Sonar room** — genuinely new (not in §6). Suggested: a sensing /
    "read-the-deep" milestone; natural prerequisite for any darkness/depth work and
    seeds the later elemental "Echo Ring" variant. **"Some enemies locate the sub
    based on the pulse" is new fauna AI**, not a room mechanic — budget it as its
    own module (a pulse-triggered hunter aggro, akin to M5 `is_hunter`).
  - **Claw snake room** — genuinely new (not in §6). A *third* collector; schedule
    *after* M7 has settled the telescope/claw base-vs-buyable economy, so the
    contrast stays legible. **The brief marks it `[-]` (starting room), which
    conflicts with the M7 base loadout — that `[-]` will not hold; it must be
    purchasable (or reopen the base-sub decision).** Its routing/self-collision
    mechanic is meaningfully harder than the telescope or claw — the milestone's
    headline. It is also the one collector that auto-grabs on contact (the telescope
    explicitly does not) — keep the three collectors distinct.

- **Standalone storage room** — returns as its own purchasable room when capacity
  becomes a real constraint (dropped from the M7 base loadout, see above). Not
  scheduled.

## Parked — update

- ~~**Telescopic arm: deferred to its own session** (2026-06-17)~~ **Resolved
  (M7): built as the base collector** with revised controls — see the M7 telescope
  entry above.

## Settled (2026-06-20, M7-1 — implementation)

- **Engine room removed from `ModuleCatalog`**: `_room("engine", ...)` entry
  deleted; `by_id("engine")` now returns null. Old saves with an engine placement
  are caught by a new **unknown-module pre-check in `validate()`** (fires before
  the existing rules) and dropped cleanly by `recover()` (null-def guard added to
  the non-core loop). No inventory refund — the room no longer exists.
- **`SubLoadout.engine_boost` field and `move_mult()` override removed**: Engine
  Boost was the only thing in `catalog()` that called `move_mult()`; it is gone.
  `move_mult()` now permanently returns `1.0`. `fast_repair` and `repair_time_mult()`
  are unchanged. Pre-M7-1 saves with `"engine_boost": true` are silently ignored on
  `from_dict()` load — the key is just not read.
- **Starting layout slimmed to 4 rooms**: claw_room(−1,0,"left") as a telescope
  stub (replaced by telescope_room in M7-3), helm(0,0), bullet_room(1,0,"right"),
  tower(0,−1). Supersedes the six-room Minnow+2 from round 4 (2026-06-16).

## Settled (2026-06-20, M7-3 — implementation)

- **Telescope is the base collector from M7-3 onward.** `SubLayout.starting_layout()` places `telescope_room` at (-1,0) facing "left". `claw_room` is now a purchasable alternate collector (cost `{"sc": 5}`, appears in shop). All tests that relied on `starting_layout()` containing `claw_room` were updated; `test_claw.gd` gained `_new_claw_sub()` to build an explicit claw layout.
- **Shop interact key bug fixed.** `DryDock._shop_key()` now maps `KEY_E` and `KEY_SHIFT` to the buy action, matching the interact keys used everywhere else in the game. Hint text corrected to "Q: assembly" (was "Tab: assembly", wrong key).
- **`telescope_room` is rotatable in Assembly.** `dry_dock.gd` `_build_cell_menu()` `rotatable` check now includes `placed_id == "telescope_room"`.

## Settled (2026-06-20, M7-2 — implementation)

- **`telescope_room` added to `ModuleCatalog`** (cost `{"sc": 6}`, purchasable).
  `TelescopeStation` (`scripts/stations/telescope_station.gd`) extends Station.
  Arm anchored at the exterior wall (matching the claw's `_claw_anchor` logic).
  Console seat in s3; s2 and s4 cages drawn and filled by `SubVisual`.
- **Telescope control scheme implemented**: A/D → `input.move.x` adjusts `aim_angle`
  within `±aim_arc_deg/2` (clamped every frame); S/W → `input.move.y` extends /
  retracts `extension` within `[0, reach_m * PPM]`; Q (`use_pressed`) → `_grab()`
  snaps nearest WATER-state `SalvageItem` within `grab_radius_m` onto the tip.
- **Auto-deposit on retract**: when `is_home()` (`extension ≤ home_radius_m * PPM`)
  and a tip item exists, `_try_deposit()` moves the item's kind into `_cage_s2` then
  `_cage_s4`. The SalvageItem node is freed; its `Kind` (int) is stored in the cage
  array. Cages full → deposit refused, item stays on tip.
- **`Sub.try_bank()` and `reset_state()` extended** to iterate `_telescope_stations`
  so cages bank at dock and are lost on implosion, same risk as the claw pen.
- **`SubVisual` draws**: straight arm tube + base mount + tip jaw + two cage outlines
  with stacked scrap/fish icons. All drawn in hull-local space so the arm tilts with
  the hull's pitch, identical to the claw.

## Settled (2026-06-21, M8 Module 0 — enemy data spine)

- **Per-species enemy data lives in `.tres` Resources under
  `res://data/enemies/`**, typed by `EnemyDef` (`enemy_def.gd`) and
  `EnemyClassStats` (`enemy_class_stats.gd`), exactly per the schema in
  `MILESTONE_8.md`. Global tunables (AI-pacing speeds, detection/leash
  ranges, knockback, hit-flash) stay in `GameFeel.FishFeel` as spine
  constants shared by whichever species runs a given AI pattern; only what
  varies species-to-species (HP, bite damage, future weight/size/drops) moved
  to the `.tres`. `GameFeel.fish.hp_max`/`chaser_hp_max` and
  `GameFeel.breach.bite_severity` are removed (superseded by
  `reference_fish.tres`'s class blocks).
- **AI behavior (territorial/hunter/chaser) is orthogonal to the EnemyDef
  class tier (Small/Big/Elite).** `Fish.is_hunter`/`is_chaser` bools are
  replaced by one `behavior: Behavior` enum; a new, independent
  `current_class: EnemyDef.Class` field selects the stat block. Today's only
  pairing in use — chaser behavior + Big class tier, to preserve the
  chaser's existing higher HP (8, was `chaser_hp_max`) — is a calling
  convention in `scenes/world.gd._add_fish()`, not a rule inside `Fish`
  itself; a future spawn can pair any behavior with any class (e.g. a hunter
  authored as Elite).
- **`reference_fish.tres`'s `currency_color = "teal"`** — a placeholder
  non-reserved hue. Reserved Elemental hues (yellow, light-grey, cyan, red,
  purple per `ELEMENTAL_UPDATE.md` §2) are off-limits for currency colors;
  body color stays independent of currency color per `MILESTONE_8.md`'s
  reversal #3.
- **Resource defaults must be `load()`ed lazily, not `preload()`ed as a
  top-level `const`, when the resource is a custom-scripted `.tres`
  referencing a `class_name` script.** Preloading `reference_fish.tres` as a
  const in `fish.gd` raced the engine's global-class registration in
  headless test runs and silently produced a scriptless `Resource` (no
  error, just `is EnemyDef == false` and every method call failing at
  runtime). `Fish` now lazily `load()`s a cached `static var` the first time
  `_ready()` needs a default. Watch for this pattern anywhere else a
  `class_name`-scripted `.tres` is preloaded by another script.
- **Module 0 acceptance confirmed**: `test_fish.tscn` passes with the same
  single pre-existing failure as on `HEAD` before this change (confirmed via
  `git stash` — a latent hull-width/territory-radius mismatch from the M7 sub
  layout, unrelated to enemy data); `test_world.tscn` and
  `test_physical_layer.tscn` fully green; project boots clean headless.

## Settled (2026-06-21, M8 Module 1 — weight + bump-back knockback)

- **Ram knockback is a one-time velocity impulse on `Sub.velocity`, not a
  separate decaying offset vector (unlike `Fish`'s own hit-knockback).**
  Because the sub's existing accel/decel feel (`SubFeel`) already pulls
  `velocity` toward whatever the helm currently wants every frame, a single
  `velocity += push` at the moment of impact is naturally fought back over
  the next several frames — no second decay timer needed, and it composes
  with player input for free (a shove while you're driving away from it
  recovers faster than one while you're drifting). `Sub.apply_ram_knockback
  (direction, room_weight, impact_speed_mps)` is the single entry point,
  called alongside (never instead of) `breach_from_hit`.
- **The knockback magnitude lives in exactly one `GameFeel` key**
  (`GameFeel.enemy_impact.ram_knockback_scalar`), per `MILESTONE_8.md`
  Module 1's acceptance criterion. `room_weight` (per-species, per-class)
  stays in `EnemyClassStats` from Module 0 — never duplicated into
  `GameFeel`.
- **A bite's "impact speed" is whatever AI-state speed constant was already
  driving the fish that frame** (`chase_speed`/`hunt_speed`/`chaser_speed`)
  — no new per-fish velocity tracking was introduced; `Fish._try_bite()` just
  takes that value as a parameter from its two call sites.
- **Push direction is fish → sub** (continuing the fish's own momentum into
  the hull), computed at the bite point already used for the breach.

## Settled (2026-06-21, M8 Module 2 — grab-tug physics)

- **A continuous tug is modeled as a shift to the helm's *target* velocity,
  not a raw velocity addition.** A raw per-frame `velocity +=` (the Module 1
  ram-knockback pattern) would accelerate the sub without bound for as long
  as a Heavy catch is held, since nothing caps it on the X axis. Shifting
  `target_x` instead lets the *existing* accel/decel feel chase the pulled-on
  target exactly the way it already chases the player's own input — the sub
  settles at a bounded drift speed (a real "terminal velocity" under the
  pull) instead of accelerating forever. The Y axis stays a simple `+=`
  (matching how buoyancy/water-weight already work there) since it's already
  hard-clamped to `max_speed_v` at the end of `_physics_process` regardless
  of source.
- **The three EnemyClassStats tiers map onto the three weight bands by
  design, not coincidence**: Small (room_weight 1.0) = Light/pinned, Big
  (2.0) = Medium/tug, Elite (3.0) = Heavy/drag. `GameFeel.enemy_impact`'s
  `light_weight_max`/`heavy_weight_min` thresholds were chosen specifically
  to land the existing reference-fish numbers one per band — a future
  species authored with an unusual `room_weight` could land in any band
  regardless of its class tier; the bands classify the *number*, not the
  tier label.
- **AI behavior, class tier, and grab state are three independent axes.** A
  grabbed fish's "struggle direction" is always "swim for home" (the same
  instinct the un-grabbed RETURN state already has) regardless of what
  behavior (territorial/hunter/chaser) or class tier it has — grabbing
  doesn't re-derive a direction from whatever AI state it was in when
  caught. This was a deliberate simplification, not a oversight: re-deriving
  CHASE/HUNT intent while grabbed (e.g. "it still wants to bite the sub")
  would be more flavorful but added a second mechanic this module didn't
  need.
- **A live catch never touches the existing salvage cage/capacity system.**
  `ClawStation`/`TelescopeStation` track a grabbed fish in its own field,
  entirely separate from `_caught`/`_cage_s2`/`_cage_s4`. Delivered home
  alive, it's finalized via the *same* `Fish.die()` hook a weapon kill
  already uses (dropping a normal carcass at the delivery point, collectible
  the normal way) — deliberately reusing the existing kill-drop pipeline
  rather than building new currency/storage plumbing in this module. This
  means M8 Module 4's currency rework (changing what `die()` drops) will
  apply to grab-tug catches automatically, with zero rework needed here.
- **Held-but-undelivered catches are released alive on implosion, not
  killed.** This is the "at risk until docked/banked" pillar applied to a
  live catch: the player loses the opportunity (no carcass), the fish loses
  nothing (it swims off). `Sub.reset_state()` now releases the claw's held
  fish; `TelescopeStation.reset_cages()` releases the telescope's.
  `Fish.reset_fish()` (the full run-reset path) also unconditionally clears
  `grabbed` itself, regardless of call order against the station's own
  reset — the station re-validates `_grabbed_fish.grabbed` every frame and
  drops a stale reference on its own, so neither side depends on the other
  firing first.