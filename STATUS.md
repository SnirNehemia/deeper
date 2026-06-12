# STATUS — DEEPER

_Read this at session start. Last updated: 2026-06-12 (M3 Module C reworked
into a two-joint articulated claw + storage pen; dry dock moved to M4)._

## Where we are
**Milestone 3 is now scoped to the lower deck + salvage loop only (A, B, C).**
Per Snir, the **dry dock + sub upgrades were moved to Milestone 4** — that code
(Module D below) is built, tested, and committed; it's just re-labelled M4 and
left in place (not wired to block anything). All **18** headless suites green.

### Module C — Salvage claw, REWORKED into a two-joint articulated arm (newest)
- Replaces the earlier telescopic claw. A **two-joint arm** (shoulder + elbow)
  hangs from the keel under the claw room and is driven **excavator-style** —
  one stick axis per joint, blended together (the real ISO/SAE crane scheme):
  **Left/Right swings the shoulder, Up/Down bends the elbow.** It reaches down
  and swings wide along the seafloor. (`ClawStation`,
  scripts/stations/claw_station.gd; tunables in `GameFeel.claw`.)
- **Cage grabber** on the tip: press **`use`** over salvage to snap the cage
  shut on it (holds **2** — `GameFeel.claw.cage_capacity`). **The catch stays
  visible, trapped inside the basket cage** (it rides the arm, staggered so two
  catches sit apart) rather than vanishing. No auto-return — you **pose the arm
  back home** to the keel yourself.
- **Two-step delivery (a co-op ferry chain):** at home, **`use`** opens the
  cage and **drops the catch through a keel hatch onto the claw-room floor** as
  a **loose, carryable item**. A crew member on foot then **`use`**s to pick it
  up, **carries** it (it rides above their head), walks to the **storage pen**
  in the storage room, and **`use`**s there to stow it. Carrying = hands full,
  so no repairing while ferrying. (`SalvageItem` is a small state machine:
  WATER → CAGED → LOOSE → CARRIED → stowed.)
- **Storage pen** (storage room, against the **right** wall clear of the
  ladder): a visible holding cage that fills as crew stow catches, capacity
  **8** (`GameFeel.claw.storage_capacity`); when full it refuses more until you
  **bank at the dock** (push-your-luck).
- **Dedicated console** in the claw room, styled like the helm/turret consoles;
  a drop **hatch** drawn on the claw-room floor at the arm base.
- The whole arm + cage + console + hatch + pen are drawn by `SubVisual`.
- It is the only way to collect salvage — no hull auto-collect.
- **Debug aid:** a top-right **"Debug mode"** toggle reveals **+1 scrap / +1
  carcass** buttons that drop salvage straight into storage (gated off in
  normal play; remove when no longer needed).
- Tests: `test_claw` (joint controls, snap→home→drop-into-hold, the crew
  pickup/carry/stow/drop ferry, cage capacity, storage cap, no-auto-collect).

### Module D — Dry Dock & sub upgrades (now Milestone 4)
- **Dry dock** (`DryDock`, scripts/ui/dry_dock.gd): while floating at the
  dock, press **Tab** to open an upgrade screen (pauses the run). Spend
  banked **scrap** on three upgrade classes:
  - **Add room** → a second torpedo gun *with its own control room*. Buying
    it opens a **submarine design planning view** where you choose which end
    it bolts onto (stern, gun facing aft / bow, gun facing forward).
  - **Upgrade room** → **Engine Boost** (×1.5 move + dive).
  - **Upgrade crew** → **Repair Training** (breaches patch ~40% faster).
- **Persistent loadout** (`SubLoadout`, scripts/sub/sub_loadout.gd) saved in
  `user://save.json`; the sub builds itself from it every launch, and the
  world **rebuilds the sub on the spot** when you buy something at the dock.
- **The gun room is a real room:** it adds a 7th water cell (floods + drains,
  shares a doorway with the end room it attaches to), extends the hull
  silhouette + collision, and seats a second `TurretStation` whose tube fires
  outward (turrets are now parameterised by `facing` + `tube_local`).
- Unbanked upgrades cost scrap up front; prices live in `SubLoadout.catalog()`
  (gun room 6, engine 3, repairs 3) — easy to retune.
- Tests: `test_loadout` (buying/saving, engine + repair mults, the gun room
  giving 7 rooms / 2 turrets / a flooding doorway) and `test_dry_dock`
  (navigation, placement flow, pause/unpause on close).

_(The Module C claw is described at the top — it was reworked from the
telescopic version into the two-joint arm.)_

_(M3 Module B summary — salvage items, storage, dock banking, save:)_
- **Salvage items** (`SalvageItem`): scrap crates (scattered on the map:
  shallows, each pillar, inside the cave) and fish carcasses (spawned where a
  territorial fish dies, sinking before settling). Two currencies: scrap and
  fish carcasses.
- **On-board storage** (`Sub.storage_scrap`/`storage_fish`); **dock banking**
  (within ~15 m of the dock spawn) moves storage into `SaveData` and empties
  it; unbanked storage is lost on implosion. `SalvageHud` shows the totals.
- **Save file** autoload `SaveData` persists banked totals (and now the
  upgrade loadout) to `user://save.json`.

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
  - `save_data.gd` — persisted meta (autoload **SaveData**): `banked_scrap`/`banked_fish` + the upgrade **loadout**, JSON to `user://save.json`; **buy()/purchase()** spend scrap.
- `scripts/`
  - `collision_layers.gd` — named layers (TERRAIN/SUB_HULL/CREW/INTERIOR/LADDER/HATCH/STATION/PROJECTILE/FISH/**SALVAGE**).
  - `placeholder_art.gd` — all colors + dimensions (single art-swap point). BREACH_COLOR is the reserved danger hue. **SCRAP_COLOR/CARCASS_COLOR** for salvage.
  - `input/` — `player_input.gd`, `input_provider.gd`, `keyboard_provider.gd` (P1/P2 split keyboard).
  - `crew/` — `crew.gd` (run/jump/climb/seat + **swim dampening, repair (×loadout repair mult), air timer, drown/respawn**; ladder grab requires being centered on the ladder's own column), `crew_visual.gd` (capsule + **bubble air gauge**).
  - `sub/` — `sub.gd` (body, interior, helm+turret+**claw**, **loadout-driven: 6 base water rooms + optional 7th gun room, engine-boost movement mult**, breaches, impacts, implosion, reset, **unified hull collision (`hull_rects()`, tilts together)**, **on-board storage + dock banking**), `sub_visual.gd` (hull + consoles + water rects + lower deck + **claw arm + multiple turrets + gun room**), `sub_loadout.gd` (**SubLoadout**: upgrade catalog + state + serialization), `breach.gd`.
  - `stations/` — `station.gd` (base: zone + occupancy + **flood eject/refuse**), `helm_station.gd`, `turret_station.gd` (**cone aim + fire; parameterised by `facing`+`tube_local`**), **`claw_station.gd`** (belly claw: aim/extend/grab/retract/deposit).
  - `weapons/` — `torpedo.gd` (slow straight shot, trail, terrain puff; inner `Puff` class).
  - `fauna/` — `fish.gd` (**territorial: patrol/chase/bite/return, torpedo kill, reset_fish**, **death spawns a sinking salvage carcass**).
  - `salvage/` — `salvage_item.gd` (**SalvageItem**: scrap crate / fish carcass pickup, sinking + settling for carcasses; in group "salvage" for the claw).
  - `ui/` — `depth_hud.gd`, `alert_hud.gd` (**breach screen-edge flash**), `salvage_hud.gd` (on-board vs. banked totals), **`dry_dock.gd`** (DryDock: upgrade screen + sub-design placement view).
  - `util/` — `grid_background.gd`.
- `scenes/`
  - `world.tscn`/`.gd` — **main scene**: map + crewed sub (built from loadout) + 3 fish + camera + HUDs + implosion/run reset + dock banking + **dock prompt / Tab opens the dry dock / sub rebuild on purchase**.
  - `shore_shelf.gd` — the map (terrain/water/sky + **cave lamp marker** + **scattered scrap pickups**).
  - `sub_test.tscn`, `sandbox.tscn` — M1 sandboxes (no water/buoyancy).
- `tests/` — 18 headless suites, all passing: `test_input`, `test_crew`, `test_sub`,
  `test_helm`, `test_world`, `test_water`, `test_station_flood`, `test_damage`,
  `test_repair`, `test_drowning`, `test_implosion`, `test_turret`, `test_fish`,
  `test_lower_deck` (Module A), `test_salvage` (Module B storage/bank/save),
  **`test_claw`** (Module C grab/deposit + no-auto-collect regression),
  **`test_loadout`** (Module D buying/saving, engine + repair mults, gun room
  → 7 rooms / 2 turrets / flooding doorway), **`test_dry_dock`** (Module D
  navigation + placement flow + pause/unpause).
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
**Playtest the reworked claw + ferry chain (verify-by-playing below).** Open
questions for Snir: does the two-joint excavator control feel good or too
fiddly? Is the claw→drop→carry→stow ferry fun co-op or too many steps solo
(one crew has to do all of it alone)? Are the pickup/deposit ranges forgiving
enough? Are cage 2 / storage 8 the right numbers? Likely next: tune, then close
out M3.

### Known issues / notes (claw rework)
- **Manual home, no auto-retract** (Snir's call): you pose both joints back to
  the keel yourself. "Home" = cage tip within ~0.9 m of the keel anchor. Easy
  one-button retract is the fallback if it feels tedious.
- **Carried/loose catches ride upright** (they don't tilt with the hull's
  cosmetic pitch), same as the crew bodies — minor, matches existing behavior.
- A full storage pen makes "stow" silently do nothing (the crew keeps holding
  the catch) — bank at the dock to make room.
- Grabbing/pickup use distance checks against the "salvage" group at the
  pitch-matched cage/crew position.
- The dry-dock / upgrade code (now M4) is present and tested but untouched.

## Verify by playing (for Snir) — the reworked claw + ferry
1. Launch: `"GODOT_PATH" --path .`
2. **Take the claw:** send a crew **down the claw ladder** into the lower claw
   room and press **E** at the claw console.
3. **Drive the two-joint arm (excavator-style):** an articulated arm hangs out
   the **bottom** of the sub. **Left/Right swings the shoulder; Up/Down bends
   the elbow.** Sweep the cage down and out to either side; steer the *sub* too
   to line things up.
4. **Catch it:** put the open cage over a scrap crate (or sunken carcass) and
   press **Q** — the hatch snaps shut and the catch **stays visible inside the
   cage**. Holds 2, so you can grab a second (they sit side by side now).
5. **Drop it into the hold:** **fold the arm back home** to the keel and press
   **Q** — the cage opens and the catch **drops through the hatch onto the
   claw-room floor** as a loose item.
6. **Ferry it:** get a crew **on foot** next to the loose item and press **Q**
   to **pick it up** (it rides above their head). Carry it through the doorway
   into the **storage room**, stand by the **storage cage** (right wall), and
   press **Q** to **stow** it — the pen fills and "Storage: N/8" climbs.
   (Pressing Q away from the cage drops it on the floor instead.)
7. **Storage is limited (8):** when full, drive to the **dock** to bank
   (storage empties, banked rises), then fill again.
8. **Debug aid:** top-right **"Debug mode"** button reveals **+1 scrap / +1
   carcass** buttons to fill storage instantly for testing banking.
9. (Unchanged) salvage is **only** collectable with the claw.

(M2 / M3 A+B verify steps — crash/repair/drown/implode/fish fight/lower
deck/ladders/banking/victory beat — still apply; see git history. The dry-dock
"Tab at the dock" upgrade flow also still works but is now M4 content.)
