# MILESTONE_1.md — Crew Sandbox + Helm

*Brief for Claude Code. Read CLAUDE.md first (developer context, build discipline, git rules). This is a feature-sized chunk: decompose into internal steps, headless-check after each, commit per working step.*

## Goal
Two players on one keyboard run, jump, and climb inside a 3-room cutaway submarine; either player can take the helm and drive the sub through a shore-to-shelf underwater test map. Placeholder art. This milestone exists to answer: *does moving around the sub and steering it feel good?*

## Step 0 — Environment (do first)
- Locate the Godot 4.x executable, record `GODOT_PATH` and exact version in CLAUDE.md.
- Initialize the Godot project (1920×1080 base resolution, `canvas_items` stretch mode, `expand` aspect). Confirm headless launch works. Commit.

## World scale & rendering (locked decisions)
- HD canvas with chunky pixel sprites ("option c" / Terraria-style). **World scale: 1 meter = 48 px.** All placeholder sprites at this texel density; smooth motion/rotation allowed.
- Texture filtering OFF (nearest) for the pixel look.
- Centralize all asset paths in one script/resource; placeholder art = flat-colored rects/polygons with text labels.
- All game-feel numbers below live in **one tunable config** (autoload), not scattered in scripts.

## Spec

### 1. Input abstraction (build before any gameplay)
- `PlayerInput` data per player per frame: `move: Vector2`, `jump`, `interact`, `use` (pressed/held).
- Provider pattern: only providers read raw input. Implement `KeyboardProvider` ×2:
  - **P1:** A/D move, W jump (and climb-up on ladders), S climb-down/drop, E interact, Q use.
  - **P2:** Left/Right move, Up jump/climb-up, Down climb-down, Right-Shift interact, Enter use.
- Architecture must make adding `GamepadProvider`/`WebSocketProvider` later trivial (no gameplay code touches devices).

### 2. The sub (interior + exterior)
- 3 rooms in a row, each **5m × 3m** interior: Helm (bow), middle flex room, Engine (stern — non-functional prop this milestone). Open hatch doorways between rooms; one ladder up to a small **conning area (2m × 2m)** above the middle room.
- The sub is one physics body in the ocean; crew are bodies in the sub's local space (parented — they move with the sub automatically).
- Exterior: rounded placeholder hull silhouette around the rooms, distinct color. Sub collides with terrain; bumping terrain is harmless this milestone (no damage system yet).

### 3. Crew movement (inside the sub)
- Slightly weighty: max run speed **4.5 m/s**, time-to-max **0.15s**, stop time **0.10s**. Keep a "snappy" preset (0.05s / 0.03s) switchable in the config.
- Jump: apex height **1.3m**, with **0.1s** coyote time and **0.1s** input buffer.
- Ladders: press up/down while overlapping to attach; climb **3 m/s**; jump or move sideways to detach.
- Two visually distinct crew placeholders (e.g., orange / cyan capsules with eyes), **1.5m tall**, simple squash on land, 2-frame run flip.

### 4. Stations (helm only this milestone)
- Generic `Station` interface: `enter(player)`, `exit(player)`, `handle_input(input)`. Standing in the station zone + interact = enter (character locks in place, visibly "seated"); interact again = exit. One occupant max.
- **Helm (direct control):** occupant's move vector accelerates the sub. Heavy-but-controllable: max speed **6 m/s horizontal / 4 m/s vertical**, time-to-max **3s**, coast-to-stop **2s** after input released. Neutral buoyancy (no drift when idle). Visual pitch tilt up to **±5°** proportional to horizontal speed (cosmetic only; collisions stay upright).

### 5. Test map ("Shore Shelf")
- ~**300m wide × 130m deep**. Left edge: shore ramp and a surface dock (the spawn — sub starts floating at the surface). Shallows plateau ~**20m** deep extending right, then a **shelf edge** cliff dropping to a ~**110m** deep basin with 2–3 rock pillars and one cave mouth (a dark recess, nothing inside yet).
- Static polygon/tile terrain, 3 placeholder colors (sand / rock / deep rock). Water surface line at the top; sky strip above it. Background color darkens with depth (simple gradient, two or three bands is fine).

### 6. Camera & HUD
- Fixed-zoom camera following the sub with smooth lerp; visible width ≈ **60m** of world (sub + generous margin).
- HUD: depth meter top-center, in meters below surface, updating live. Nothing else.

## Acceptance criteria
- [ ] Two players simultaneously: run, jump, climb the ladder, pass through all 3 rooms + conning area, with zero input cross-talk.
- [ ] Either player can enter/exit the helm; while helming, their character stops moving and the sub responds.
- [ ] Sub feels heavy: noticeable spin-up, long coast, slight pitch tilt; cannot pass through terrain.
- [ ] Crew stays correctly positioned inside the sub at full speed (no jitter/sliding).
- [ ] Drive from the dock, across the shallows, over the shelf edge, down past 100m; depth meter tracks correctly.
- [ ] Game launches from a fresh clone with no manual setup; headless check passes.

## Out of scope (do not build)
Turret, water/breaches, enemies, oxygen, repair, salvage, engine functionality, sound, menus beyond a quit key, gamepad/phone input, art beyond labeled placeholders, any zoom behavior.

## Verify by playing (for Snir)
1. Launch: `"GODOT_PATH" --path .` (Claude Code: fill in the real path).
2. P1 (WASD/E) and P2 (arrows/Right-Shift): run around all rooms, jump, climb the ladder. Both at once — confirm neither hijacks the other.
3. P1 enters the helm (stand at it, press E) and drives right and down over the cliff edge while P2 keeps running around inside. The sub should feel like a heavy vehicle, not a cursor.
4. Watch the depth meter pass 100m near the basin floor. Try to push through a rock pillar — you should bump, not clip.
5. Swap: P2 takes the helm, P1 runs around. Then tell Claude (design chat) how the *feel* was — too heavy? too floaty? — so we tune the config.
