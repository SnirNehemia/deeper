# STATUS — DEEPER

_Read this at session start. Last updated: 2026-06-11._

## Where we are
**Milestone 2 (Water, Torpedoes, and First Blood) is code-complete — awaiting
the playtest.** The sub can get hurt, flood, and die, and fight back: terrain
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
  - `game_feel.gd` — all tunables (autoload **GameFeel**): crew, sub, **water** (flow/drain/leak/air/implosion), **turret**, **fish**.
- `scripts/`
  - `collision_layers.gd` — named layers (TERRAIN/SUB_HULL/CREW/INTERIOR/LADDER/HATCH/STATION/**PROJECTILE/FISH**).
  - `placeholder_art.gd` — all colors + dimensions (single art-swap point). BREACH_COLOR is the reserved danger hue.
  - `input/` — `player_input.gd`, `input_provider.gd`, `keyboard_provider.gd` (P1/P2 split keyboard).
  - `crew/` — `crew.gd` (run/jump/climb/seat + **swim dampening, repair, air timer, drown/respawn**), `crew_visual.gd` (capsule + **bubble air gauge**).
  - `sub/` — `sub.gd` (body, interior, helm+turret, **per-room water, breaches, impacts, implosion signal, reset**), `sub_visual.gd` (hull + consoles + **water rects**), `breach.gd` (**leak point: spray marker, warning blink, repair arc**).
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
  `test_helm`, `test_world`, **`test_water`, `test_station_flood`, `test_damage`,
  `test_repair`, `test_drowning`, `test_implosion`, `test_turret`, `test_fish`**.
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
- The turret's aim line and tube are drawn by the station (untilted); the hull
  art tilts ±5°, so at full speed the tube can look ~a tube-width off the hull
  line. Cosmetic; fix only if a playtester notices.
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
**Playtest Milestone 2** (verify-by-playing steps in MILESTONE_2.md §Verify,
also summarized below), log answers in PLAYTEST_LOG.md, then tune `GameFeel`
numbers. After that: Snir scopes Milestone 3 in a fresh session.

## Verify by playing (for Snir) — quick copy
1. Launch: `"GODOT_PATH" --path .`
2. **Crash test:** nudge the shallows floor gently — nothing. Ram a pillar at
   speed: flash, spraying breach, rising water.
3. **Repair drama:** half-flood a room, hold Q (P1) / Enter (P2) at the breach
   ~3s, watch it drain. Feel the sub fly heavier while flooded.
4. **Drown on purpose:** stand in a flooding room until the bubbles run out —
   pop, then respawn at the helm room ~7s later.
5. **Implode on purpose:** take hits until the water wins — crunch, fade,
   fresh start at the dock.
6. **The fight:** P1 helms at the pillars, P2 takes the mid-room turret (E /
   R-Shift to sit, move to aim in the bow cone, Q / Enter to fire). One hit
   per fish.
7. **Victory beat:** kill the cave-mouth fish, slip inside to the glowing lamp.
