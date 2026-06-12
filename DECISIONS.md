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

## Parked
- Snappy Overcooked-style crew movement (kept as switchable preset; playtest against weighty)
- Phone-as-controller via WebSocket (post-MVP, only if gamepads aren't enough)
- Godot MCP for Claude Code (revisit only if visual-bug iteration becomes painful)
- Fire/electrical damage systems (water must prove fun first)
- EVA dive-suit module (v1 content at earliest)
- Cosmetics (paint, flags, googly eyes) — vertical-slice era
