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
- Buoyancy: the sub floats at `Sub.SURFACE_FLOAT_DEPTH` (~3 m, reads "Depth 3 m"
  at rest) and gets heavy as it emerges so it can't fly out of the water; neutral
  below the surface band (holds depth when idle). Tune with
  `GameFeel.sub.surface_gravity` + `Sub.SURFACE_FLOAT_DEPTH`. Only the world
  enables buoyancy; dry sandboxes/tests leave it off.
- Interior floors are StaticBody2D moved via parent transform; no jitter seen, but
  if fast driving ever shows it, switch interior to AnimatableBody2D.
- `up` = jump = climb = "steer up" share a key; fine because a seated crew can't
  jump/climb. Standing directly under the ladder and pressing up grabs the ladder
  (normal ladder behavior).
- Feel is at canon "weighty"; `GameFeel.use_snappy()` switches the crew preset for
  playtest comparison (no live key yet).

## Suggested next step
Playtest Milestone 1 for **feel** (crew weight, jump, sub heft, pitch, camera) and
feed tuning notes into `GameFeel`. Then Milestone 2 territory: turret, water/breaches,
or enemies (per DECISIONS, water should prove fun first).
