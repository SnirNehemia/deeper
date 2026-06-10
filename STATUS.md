# STATUS — DEEPER

_Read this at session start. Last updated: 2026-06-10._

## Where we are
**Milestone 1 (Crew Sandbox + Helm) is complete.** Two players share one keyboard,
run/jump/climb a 3-room cutaway submarine, take the helm, and drive it through the
Shore Shelf test map while a depth meter tracks them. All placeholder art.

- Engine: Godot **4.4.1 stable**. Path recorded in CLAUDE.md (`GODOT_PATH`).
- Main scene: `res://scenes/world.tscn`.
- World scale: **1 m = 48 px**. All feel numbers in `GameFeel` (autoload).

## How to run
- Play: `"GODOT_PATH" --path .`  (opens straight into the world)
- Headless check / tests (see below): `"GODOT_PATH" --headless res://tests/<name>.tscn`
  → each prints `... TESTS PASSED` and exits 0.
- PowerShell capture quirk: pipe through `Out-String` to see test stdout.

## File map
- `autoload/`
  - `input_hub.gd` — central input registry (autoload **InputHub**); owns providers, polls each frame.
  - `game_feel.gd` — all tunable feel numbers (autoload **GameFeel**): crew (weighty/snappy), sub, `PIXELS_PER_METER`.
- `scripts/`
  - `collision_layers.gd` — named physics layers (TERRAIN/SUB_HULL/CREW/INTERIOR/LADDER/HATCH/STATION).
  - `placeholder_art.gd` — all placeholder colors + crew dimensions (single art-swap point).
  - `input/` — `player_input.gd` (per-player snapshot), `input_provider.gd` (base), `keyboard_provider.gd` (P1/P2 split keyboard).
  - `crew/` — `crew.gd` (run/jump/climb/seat, CharacterBody2D), `crew_visual.gd` (placeholder capsule).
  - `sub/` — `sub.gd` (body, interior, ladder, helm, driving), `sub_visual.gd` (hull art + console; tilts for pitch).
  - `stations/` — `station.gd` (base: zone + occupancy), `helm_station.gd` (direct sub control).
  - `ui/` — `depth_hud.gd` (top-center depth meter, CanvasLayer).
  - `util/` — `grid_background.gd` (motion grid for sub_test), `shore_shelf.gd` lives in scenes/.
- `scenes/`
  - `world.tscn`/`.gd` — **main scene**: Shore Shelf map + crewed sub + follow camera + depth HUD.
  - `shore_shelf.gd` — the test map (terrain/water/sky).
  - `sub_test.tscn`/`.gd` — open-water driving sandbox (grid bg).
  - `sandbox.tscn`/`.gd` — crew-feel sandbox (flat floor + platforms).
- `tests/` — headless suites: `test_input`, `test_crew`, `test_sub`, `test_helm`, `test_world` (all passing).
  Plus `capture_tilt`/`capture_world` — throwaway windowed screenshot tools (png output gitignored).

## Acceptance criteria (Milestone 1) — all met
- Two players run/jump/climb all 3 rooms + conning area, zero cross-talk. ✓
- Either player enters/exits the helm; while helming their crew stops and the sub responds. ✓
- Sub feels heavy (spin-up, long coast, slight pitch); cannot pass through terrain. ✓
- Crew stay positioned inside the sub at full speed (verified: ~0 px drift). ✓
- Drive dock → shallows → over the shelf → past 100 m; depth meter tracks. ✓
- Runs from a fresh clone, no manual setup; headless check passes. ✓

## Known issues / notes
- Pitch tilt is cosmetic for the interior: hull + crew **art** tilt and the **hull
  collider tilts with them**, but the body's footing stays upright so crew don't
  slide. Tilt strength is a one-number tweak (`GameFeel.sub.max_pitch_deg`).
- Sub hull collider is a polygon matched to the hull silhouette (fixed the earlier
  big collision gap) and rotates with the pitch.
- Buoyancy: the sub floats at `Sub.SURFACE_FLOAT_DEPTH` and gets heavy as it
  emerges so it can't fly out of the water; neutral below the surface band (holds
  depth when idle). Tune with `GameFeel.sub.surface_gravity` +
  `Sub.SURFACE_FLOAT_DEPTH`. Only the world enables buoyancy (`buoyancy_enabled`);
  dry sandboxes/tests leave it off.
- Depth meter reads **0 at the surface float** (`Sub.depth_m()` measures below the
  floating waterline, i.e. offset by `SURFACE_FLOAT_DEPTH`), clamped ≥ 0.
- Interior floors are StaticBody2D moved via parent transform; no jitter seen, but
  if fast driving ever shows it, switch interior to AnimatableBody2D.
- `up` = jump = climb = "steer up" share a key; fine because a seated crew can't
  jump/climb. Standing directly under the ladder and pressing up grabs the ladder
  (normal ladder behavior).
- Feel is at canon "weighty"; `GameFeel.use_snappy()` switches the crew preset for
  playtest comparison (no live key yet).

## Architecture & how to extend (read before Milestone 2)
Core idea: **input → providers → InputHub → consumers**; **all feel numbers in
GameFeel**; **all placeholder art in PlaceholderArt**; **physics layers in Layers**.

- **Add an input device (gamepad/phone):** subclass `InputProvider` (override
  `handle_event`/`poll`/`reset` to fill its `PlayerInput`), then register it in
  `InputHub._register_milestone1_players()`. No gameplay code changes — every
  consumer reads `InputHub.get_input(index)`.
- **Add a station (turret, periscope, pump…):** subclass `Station`, override
  `handle_input(input)` (and `seat_global_position()` if the seat isn't the node
  origin). Build it inside `Sub` like `_build_helm()`. The crew seat/enter/exit
  flow and the "one occupant" rule are already handled in `crew.gd` + `station.gd`.
  Crew detect stations via a STATION-layer Area2D sensor.
- **Sub systems (water/breaches, damage, oxygen):** the sub is one `CharacterBody2D`
  with the interior built in code (`_build_interior`). Per-room state belongs on
  `Sub`; the rooms are known rectangles (see the geometry consts at the top of
  `sub.gd`). Damage model v1 = per-room water level only (see DECISIONS).
- **Add/extend the map:** terrain lives in `scenes/shore_shelf.gd` as TERRAIN-layer
  `CollisionPolygon2D` + matching `Polygon2D` visuals. Carve caves by routing the
  ground polygon boundary into the rock (see the cave in `_build_terrain`).
- **Tuning:** crew + sub feel are all in `autoload/game_feel.gd` (meters/seconds;
  `PIXELS_PER_METER = 48`). `GameFeel.use_snappy()` swaps the crew preset.
- **Collision layers:** `scripts/collision_layers.gd`. Crew touch INTERIOR + HATCH
  + each other (CREW); the sub hull touches TERRAIN; ladders/hatch/stations are
  their own layers. Keep new physics on named layers, never magic numbers.
- **Testing discipline:** every system has a headless scene test in `tests/`
  (`extends Node`, `_ready()` runs checks via the live autoloads, prints
  `ok:`/`FAIL:`, `get_tree().quit(0/1)`). Run them as **scenes**, not `--script`
  (global class_names don't resolve under `--script`). Pipe PowerShell output
  through `Out-String` to capture stdout. `tests/capture_*.tscn` are windowed
  screenshot tools for visual sign-off (png output is gitignored).

## Open feel questions for the next playtest
Crew weight/jump, sub heft + coast, pitch amount/direction, camera framing,
buoyancy strength (`surface_gravity`) and float depth, whether `up`=jump=climb
sharing a key ever bites. Feed answers into `GameFeel` / the relevant const.

## Suggested next step (Milestone 2)
Snir scopes M2 in a fresh session. Per DECISIONS the likely territory is **water /
breaches first** (damage model v1 = per-room water level; auto-drains after
patching; infinite hold-to-repair in MVP), then turret (limited arc) and enemies
(small fauna territorial, large fauna hunts on detection). Start by writing a
`MILESTONE_2.md` brief the same way `MILESTONE_1.md` was written.
