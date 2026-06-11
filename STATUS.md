# STATUS — DEEPER

_Read this at session start. Last updated: 2026-06-11 (M3 Module A, playtest #1 revision)._

## Where we are
**Milestone 3, Module A (lower deck + 6-cell water) is built, playtested
once, and revised.** Snir's first playtest of the lower deck gave 5 change
requests, all implemented and headless-tested:
- The floor-opening water mechanic is **removed** — flooded lower-deck rooms
  (claw, storage) only drain/spread via their existing door connections (the
  claw<->storage doorway). Water doesn't visibly drip down ladders, and that's
  fine.
- Both lower-deck ladders (claw, storage) are now reliably grabbable **and
  climbable down** from a normal standing position in the room above — their
  grab zones extend up to the main-deck ceiling.
- Ladders alternate sides floor-to-floor (conning ladder centered, claw ladder
  on the left of the middle room, storage ladder on the right of the engine
  room) so climbing through multiple decks needs lateral movement, not just
  holding "up".
- The crew's ladder-grab check now requires horizontal alignment with the
  ladder's own column (not the wider sensor-overlap band) — fixes accidental
  ladder-grabs while just running/jumping past one (the "up" key is shared
  between jump and climb).
- The hull silhouette is now **one continuous shape** (rooms + a uniform outer
  margin), both visually and in collision — was two separate "blobs" before.
- The shore shelf map is **smaller (160m x 130m)** and the cave is closer to
  shore, for faster playtest loops.

**Follow-up (same day):** after looking at the build, Snir asked for the
lower-deck ladders to sit closer to the outer/dividing wall of their lower
room rather than mid-room. Both ladders moved (still single shafts spanning
both decks, still alternating sides): claw ladder now near the engine/middle
divider (claw room's left wall), storage ladder now near the outer hull
(storage room's left wall). Re-tested, all 14 suites green.

Next: Snir plays this revision; if it holds up, Module B (salvage items,
carry, storage, banking, save) is next.

_(Original M2 summary:)_
**Milestone 2 (Water, Torpedoes, and First Blood)** The sub can get hurt, flood, and die, and fight back: terrain
impacts breach the hull, rooms flood and weigh the sub down, crew patch
breaches under pressure and can drown trying, too much water imploses the sub
(clean reset at the dock), and a bow torpedo turret kills the 3 territorial
fish guarding the basin and cave mouth. Glowing lamp in the cave = the victory
beat. All placeholder art.

- Engine: Godot **4.4.1 stable**. Path recorded in CLAUDE.md (`GODOT_PATH`).
- Main scene: `res://scenes/world.tscn`.
- World scale: **1 m = 48 px**. All feel numbers in `GameFeel` (autoload).

## How to run
- Play: `"GODOT_PATH" --path .`  (opens straight into the world)
- Headless check / tests: `"GODOT_PATH" --headless --path . res://tests/<name>.tscn`
  → each prints `... TESTS PASSED` and exits 0.
- PowerShell capture quirk: pipe through `Out-String` to see test stdout.
- **After adding any new `class_name` script:** run `"GODOT_PATH" --headless
  --path . --import` once, or headless runs fail with "Could not resolve
  class" (the global class cache is stale).

## File map
- `autoload/`
  - `input_hub.gd` — central input registry (autoload **InputHub**); owns providers, polls each frame.
  - `game_feel.gd` — all tunables (autoload **GameFeel**): crew, sub, **water** (flow/drain/leak tiers/**door sill**/air/implosion), **turret** (cone 60°, aim sweep, 1.0s cooldown), **fish**.
- `scripts/`
  - `collision_layers.gd` — named layers (TERRAIN/SUB_HULL/CREW/INTERIOR/LADDER/HATCH/STATION/**PROJECTILE/FISH**).
  - `placeholder_art.gd` — all colors + dimensions (single art-swap point). BREACH_COLOR is the reserved danger hue.
  - `input/` — `player_input.gd`, `input_provider.gd`, `keyboard_provider.gd` (P1/P2 split keyboard).
  - `crew/` — `crew.gd` (run/jump/climb/seat + **swim dampening, repair, air timer, drown/respawn**; ladder grab requires being centered on the ladder's own column), `crew_visual.gd` (capsule + **bubble air gauge**).
  - `sub/` — `sub.gd` (body, interior, helm+turret, **6-room water model (3 main deck + conning + claw + storage lower-deck rooms)**, breaches, impacts, implosion signal, reset, **unified hull collision shape (`HULL_*_RECT` + direct `CollisionShape2D` children, tilts together)**), `sub_visual.gd` (hull + consoles + **water rects**, lower-deck rooms + ladders), `breach.gd` (**leak point: spray marker, warning blink, repair arc**).
  - `stations/` — `station.gd` (base: zone + occupancy + **flood eject/refuse**), `helm_station.gd`, `turret_station.gd` (**bow cone aim + fire**).
  - `weapons/` — `torpedo.gd` (slow straight shot, trail, terrain puff; inner `Puff` class).
  - `fauna/` — `fish.gd` (**territorial: patrol/chase/bite/return, torpedo kill, reset_fish**).
  - `ui/` — `depth_hud.gd` (depth meter), `alert_hud.gd` (**breach screen-edge flash**).
  - `util/` — `grid_background.gd`.
- `scenes/`
  - `world.tscn`/`.gd` — **main scene**: map + crewed sub + 3 fish + camera + HUDs + **implosion sequence & run reset**.
  - `shore_shelf.gd` — the map (terrain/water/sky + **cave lamp marker**).
  - `sub_test.tscn`, `sandbox.tscn` — M1 sandboxes (no water/buoyancy).
- `tests/` — headless suites, all passing: `test_input`, `test_crew`, `test_sub`,
  `test_helm`, `test_world`, `test_water`, `test_station_flood`, `test_damage`,
  `test_repair`, `test_drowning`, `test_implosion`, `test_turret`, `test_fish`,
  **`test_lower_deck`** (M3 Module A: lower-deck geometry, claw<->storage door
  flow, both ladders climbable down and back up).
  Plus `capture_*` — throwaway windowed screenshot tools (png gitignored;
  `capture_m2` stages the full M2 tableau).

## Milestone 2 acceptance criteria — all implemented & headless-tested
- Ramming terrain >2 m/s breaches the nearest room, leak scales with speed; gentle bumps free. ✓
- Water rises, flows through hatches/ladder, weighs the sub down. ✓
- Station floods past ~60% → ejects occupant, refuses entry until drained. ✓
- Hold `use` 3s at a breach → patched (release = reset); patched room auto-drains (~12s). ✓
- Head underwater 10s → drown (cartoon pop), respawn at helm room after 7s; partner unaffected. ✓
- ~70% total water → crunch/shake/fade implosion → clean reset at the dock (water, breaches, crew, fish). ✓
- Turret seat (middle room), ±45° bow cone, ~10 m/s torpedoes, 1.2s cooldown, infinite ammo; one hit kills a fish. ✓
- 3 fish with territories (cave mouth + 2 pillars): chase inside ~10 m, bite = drip breach every ~3s, disengage when you flee. ✓
- New breach → screen-edge flash + anchored blinking marker. ✓
- All M1 criteria still pass; full suite green. ✓

## Known issues / notes
- All M1 notes still hold (cosmetic pitch, hull polygon collider, buoyancy band,
  hatch behavior, shared `up` key).
- Water "volume" uses room cross-section area; the conning area is smaller so
  it fills/drains visibly faster than main rooms. Intended.
- Equalizing flow runs even between a flooded room and a draining neighbor —
  so patching one room while a neighbor is breached still leaves water sloshing
  in. That's the co-op pressure, not a bug.
- The turret tube + barrel and the breach markers are now drawn under the hull
  visual, so they pitch with the sub (playtest #1 fix). Torpedoes launch along
  the tilted barrel. The water rects also live on the hull visual, so they tilt
  with the ±5° pitch too — minor and pre-existing; revisit only if it reads odd.
- Torpedoes ignore the own hull by collision mask (PROJECTILE vs TERRAIN|FISH),
  so point-blank backward shots fly through the sub harmlessly. Accepted for M2.
- Fish are Area2D (no physics body): they can drift into terrain while chasing.
  In practice territories keep them in open water; revisit if it reads badly.
- Dead-crew countdown label is parented to the (invisible) crew, so it rides
  the sub at the spot of death until respawn.

## Open feel questions for the playtest (→ PLAYTEST_LOG.md + GameFeel)
Is rising water scary or annoying? Is 3s repair too long under pressure? Do
torpedoes feel chunky or just sluggish? Is the fish fight fun or a chore? Plus
all M1 questions (crew weight, sub heft, camera framing).

## Suggested next step
**Playtest this M3 Module A revision** (verify-by-playing steps below). If the
lower deck, ladders, hull silhouette, and smaller map all feel good, move on
to **Module B** (salvage items, carry, storage, banking, save) in the next
session.

## Verify by playing (for Snir) — M3 Module A revision
1. Launch: `"GODOT_PATH" --path .`
2. **Smaller map:** the shore/shelf/cave should all feel closer together than
   last time — less travel time to get into action.
3. **Hull shape:** look at the sub from outside — it should read as one solid
   hull silhouette (main deck + conning tower bump + lower-deck belly), not
   two separate blobs.
4. **Storage ladder (near the outer/left wall of the engine room):** walk to
   it, press down to climb into the storage room below; press up to climb
   back to the engine room. Should grab cleanly from a normal standing
   position, both directions.
5. **Claw ladder (near the engine/middle divider, left side of the middle
   room):** same check — down to the claw room, up back to the middle room.
6. **Run past a ladder while jumping:** run through the engine/middle rooms
   hopping the door steps (tap "up" near a doorway) — you should jump, not
   suddenly grab a nearby ladder.
7. **Lower-deck flooding:** breach the storage or claw room (ram terrain near
   the lower deck, or just check water behavior) — water should pool in that
   room and spill into its neighbour through the doorway, but not "leak" up
   through the ladders.

(M2 verify steps — crash/repair/drown/implode/fish fight/victory beat — still
apply and should all still work; see git history for the full M2 checklist if
needed.)
