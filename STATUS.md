# STATUS — DEEPER

_Read this at session start. Last updated: 2026-06-12 (M3 Module B: salvage,
storage, banking, save)._

## Where we are
**Milestone 3, Module B (salvage items, on-board storage, dock banking, and
a first save file) is built and headless-tested.** Module A (lower deck +
6-cell water) was playtested and held up — all good, no further changes
needed.

- **Salvage items** (`SalvageItem`, scripts/salvage/salvage_item.gd): scrap
  crates (placed around the shore-shelf map: shallows, each pillar, and
  inside the cave) and fish carcasses (spawned where a territorial fish dies,
  sinking briefly before settling). Two separate currencies: scrap and fish
  carcasses.
- **Hull collector:** the sub auto-collects any salvage item that touches its
  hull bounding box (no claw arm yet — placeholder for the future claw
  module) and adds it to on-board storage (`Sub.storage_scrap`,
  `Sub.storage_fish`).
- **Dock banking:** returning the sub within ~15 m of its dock spawn point
  banks everything in storage into `SaveData` (persisted) and empties
  storage. `world.gd` checks this every physics frame.
- **Risk:** unbanked on-board storage is lost (reset to 0) on implosion —
  the push-your-luck stakes from the design doc.
- **Save file:** new autoload `SaveData` (autoload/save_data.gd) persists
  `banked_scrap`/`banked_fish` to `user://save.json`, loaded on launch.
- **HUD:** new top-right `SalvageHud` shows on-board vs. banked totals live.
- New test suite `test_salvage` (collector pickup for both salvage kinds,
  dock banking transfer, save/load round trip) — all 15 suites green.

_(M3 Module A summary, playtested and confirmed good:)_
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

**Follow-up #2 (next day):** ladders shortened to one deck tall (just the
lower room's height + a small overlap into the main deck for grabbing from
the hatch), instead of stretching up through the main-deck room above —
matches the reference image where ladders read as confined to the lower deck.
Re-tested, all 14 suites green.

**Follow-up #3 (same day):** the main-deck grab overlap was halved to 20px
(was 40px) — the ladders now poke up just a little less into the room above.
Re-tested, all 14 suites green.

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
  - `save_data.gd` — persisted meta currency (autoload **SaveData**): `banked_scrap`/`banked_fish`, JSON to `user://save.json`.
- `scripts/`
  - `collision_layers.gd` — named layers (TERRAIN/SUB_HULL/CREW/INTERIOR/LADDER/HATCH/STATION/PROJECTILE/FISH/**SALVAGE**).
  - `placeholder_art.gd` — all colors + dimensions (single art-swap point). BREACH_COLOR is the reserved danger hue. **SCRAP_COLOR/CARCASS_COLOR** for salvage.
  - `input/` — `player_input.gd`, `input_provider.gd`, `keyboard_provider.gd` (P1/P2 split keyboard).
  - `crew/` — `crew.gd` (run/jump/climb/seat + **swim dampening, repair, air timer, drown/respawn**; ladder grab requires being centered on the ladder's own column), `crew_visual.gd` (capsule + **bubble air gauge**).
  - `sub/` — `sub.gd` (body, interior, helm+turret, **6-room water model (3 main deck + conning + claw + storage lower-deck rooms)**, breaches, impacts, implosion signal, reset, **unified hull collision shape (`HULL_*_RECT` + direct `CollisionShape2D` children, tilts together)**, **salvage collector + on-board storage + dock banking**), `sub_visual.gd` (hull + consoles + **water rects**, lower-deck rooms + ladders), `breach.gd` (**leak point: spray marker, warning blink, repair arc**).
  - `stations/` — `station.gd` (base: zone + occupancy + **flood eject/refuse**), `helm_station.gd`, `turret_station.gd` (**bow cone aim + fire**).
  - `weapons/` — `torpedo.gd` (slow straight shot, trail, terrain puff; inner `Puff` class).
  - `fauna/` — `fish.gd` (**territorial: patrol/chase/bite/return, torpedo kill, reset_fish**, **death spawns a sinking salvage carcass**).
  - `salvage/` — `salvage_item.gd` (**SalvageItem**: scrap crate / fish carcass pickup, sinking + settling for carcasses).
  - `ui/` — `depth_hud.gd` (depth meter), `alert_hud.gd` (**breach screen-edge flash**), **`salvage_hud.gd`** (on-board vs. banked salvage totals).
  - `util/` — `grid_background.gd`.
- `scenes/`
  - `world.tscn`/`.gd` — **main scene**: map + crewed sub + 3 fish + camera + HUDs + **implosion sequence & run reset** + **dock-banking check**.
  - `shore_shelf.gd` — the map (terrain/water/sky + **cave lamp marker** + **scattered scrap pickups**).
  - `sub_test.tscn`, `sandbox.tscn` — M1 sandboxes (no water/buoyancy).
- `tests/` — headless suites, all passing: `test_input`, `test_crew`, `test_sub`,
  `test_helm`, `test_world`, `test_water`, `test_station_flood`, `test_damage`,
  `test_repair`, `test_drowning`, `test_implosion`, `test_turret`, `test_fish`,
  `test_lower_deck` (M3 Module A: lower-deck geometry, claw<->storage door
  flow, both ladders climbable down and back up),
  **`test_salvage`** (M3 Module B: collector pickup of scrap + carcass, dock
  banking, save/load round trip).
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
**Playtest M3 Module B** (verify-by-playing steps below). If salvage
collection, banking, and the save persisting across launches all feel good,
the natural next step is a **claw arm module** (Module C?) so crew can
actively grab salvage instead of relying on the hull's auto-collector — or,
if Snir would rather, start sketching the dry-dock spend screen now that
there's a real currency to spend.

## Verify by playing (for Snir) — M3 Module B
1. Launch: `"GODOT_PATH" --path .`
2. **Top-right HUD** now shows "On board: 0 scrap, 0 carcasses" and "Banked:
   0 scrap, 0 carcasses" (or whatever you banked in a previous session — the
   save persists).
3. **Collect scrap:** drive the sub into one of the scrap crates (small
   bobbing tan squares) — there are 5: in the shallows, by each of the three
   pillars, and inside the cave. Each one should vanish and "On board: scrap"
   should go up by 1.
4. **Collect a fish carcass:** kill one of the territorial fish with the
   turret — a faded purple blob should appear where it died and slowly sink.
   Drive the hull into it; "On board: carcasses" should go up by 1.
5. **Bank at the dock:** drive the sub back near its starting position (the
   dock, left side of the map). "On board" should drop to 0 and "Banked"
   should go up by the same amounts.
6. **Save persists:** quit the game (Esc) and relaunch — "Banked" should show
   the same totals you ended with.
7. **Risk:** collect some salvage, do NOT return to dock, and let the sub
   implode (e.g. ram the rocks repeatedly until it floods past ~70%). After
   the reset, "On board" should be back to 0 (lost) but "Banked" stays as it
   was.

(M2/M3 Module A verify steps — crash/repair/drown/implode/fish fight/lower
deck/ladders/victory beat — still apply and should all still work; see git
history for the full checklist if needed.)
