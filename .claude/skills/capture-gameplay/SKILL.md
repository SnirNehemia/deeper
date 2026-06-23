---
name: capture-gameplay
description: >-
  Capture a screenshot (or a short frame sequence) of DEEPER actually rendering,
  to SHOW Snir a visual/feel change instead of just describing it — and to
  self-verify visual changes that headless tests can't see. Use after changing
  anything visible (a new enemy's look/movement, water rising, the sub tilting,
  a room's art, a HUD element, lighting/beam shapes), when Snir asks "show me"
  or "what does it look like", or before handing off verify-by-playing steps for
  a visual feature. Do NOT use for pure-logic changes (use the test-runner) or
  for capturing the live editor.
---

# Capture DEEPER gameplay as an image

Snir judges the game by **feel and look**, and he doesn't read code. Headless
tests prove logic but render nothing. This skill produces a real rendered
screenshot (or a few frames of motion) so you can *show* him a change — and check
visual work yourself before claiming it works.

The technique is already proven in the repo: see `tests/capture_world.gd` and
`tests/capture_m2.gd`. This skill makes it a repeatable habit.

## The one critical gotcha

**Capture runs WINDOWED, never `--headless`.** Godot's `--headless` mode has no
renderer, so `get_viewport().get_texture()` comes back blank. A capture scene
must launch with a real window:

```
"D:\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe" --path . res://tests/capture_<thing>.tscn
```

A window flashes open on Snir's machine for a second and auto-closes — that's
expected. (It cannot run while he already has the game/editor open on the same
project lock; if a run is in progress, wait or use a fresh launch.)

## How it works: build the state, then snapshot it

Don't try to drive live input. The reliable pattern (same as the existing capture
scripts) is to **construct the exact game state that demonstrates your change**,
let the physics settle a few frames, point a camera at it, and snapshot the
viewport. For "before/after" comparisons, capture two states.

### Procedure

1. **Write a throwaway capture scene** — a `.gd` + `.tscn` pair in `tests/`,
   named `capture_<thing>` (e.g. `capture_elite_fish`). Model it on
   `tests/capture_world.gd`. Construct the scene to frame your change clearly:
   spawn the relevant nodes, set the state (e.g. `sub.water_levels = [...]`,
   `fish.current_class = EnemyDef.Class.ELITE`), position a `Camera2D` with the
   right zoom, add the `DepthHud`/`SalvageHud` if relevant.
2. **Save to `captures/`** (throwaway output, not committed — gitignore the
   folder). Use `img.save_png("res://captures/<thing>.png")`.
3. **Run it windowed** with the command above. Capture the console output
   yourself; treat any script error as a failure to fix.
4. **Send it to Snir** with `SendUserFile` (status `proactive` if he's away),
   with a one-line caption of what he's looking at and what to notice.
5. **Clean up** the throwaway `capture_<thing>.gd/.tscn` and the PNG once sent,
   unless it's worth keeping as a reusable reference (like `capture_world`).

### Still-frame template

```gdscript
extends Node2D
## Throwaway visual capture of <what>. Saves res://captures/<thing>.png and quits.

func _ready() -> void:
    # --- build the state you want to show ---
    add_child(ShoreShelf.new())              # or MapLoader for the real map
    var sub := Sub.new()
    sub.position = Vector2(0, 0)
    add_child(sub)
    for i in 30:
        await get_tree().physics_frame       # let geometry/water settle

    # ... spawn/configure the thing your change affects ...

    var cam := Camera2D.new()
    cam.zoom = Vector2.ONE * 2.0              # frame it; tune the zoom
    cam.position = sub.position
    add_child(cam)
    cam.make_current()

    await _snapshot("captures/<thing>.png")

func _snapshot(path: String) -> void:
    for i in 30:
        await get_tree().physics_frame
    await RenderingServer.frame_post_draw     # MUST wait for the draw
    var img := get_viewport().get_texture().get_image()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
    img.save_png("res://" + path)
    get_tree().quit(0)
```

### Short motion sequence (for feel: movement, water rising, a beam sweeping)

When a single still can't convey it, capture a numbered sequence and send the key
frames (or assemble a GIF only if `ffmpeg`/`magick` is available on PATH — check
first; if not, just send 3–4 representative stills).

```gdscript
# inside _ready, after setup, instead of a single _snapshot:
for frame in 24:
    # advance the thing: e.g. step the sub, raise water, sweep a beam
    for i in 5:
        await get_tree().physics_frame
    await RenderingServer.frame_post_draw
    var img := get_viewport().get_texture().get_image()
    img.save_png("res://captures/<thing>_%03d.png" % frame)
get_tree().quit(0)
```

## When to reach for this

- You changed how something **looks** (enemy art/size, room visuals, HUD, beam,
  water shader) → capture a still, show Snir.
- You changed how something **moves/feels** and want to confirm it reads right →
  capture a short sequence.
- You're about to write "verify by playing" for a visual feature → attach a
  capture so Snir knows what he's looking for before he launches.
- Reproducing a visual bug Snir reported → capture the broken state, then the
  fixed state, and show both.

Keep captures cheap and disposable. The deliverable is the image in Snir's hands,
not the script that made it.
