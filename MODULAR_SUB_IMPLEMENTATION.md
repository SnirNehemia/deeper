# MODULAR_SUB_IMPLEMENTATION.md — DEEPER

*Implementation design for the grid-based modular submarine. Read by Claude Code before starting MILESTONE_4. This document is **canon for how the system works**; MILESTONE_4.md is canon for **build order**. If anything here conflicts with code reality, stop and surface it in design terms — do not improvise a different architecture.*

---

## 1. The one-paragraph version

The submarine is a **layout**: a set of room modules placed on a fixed **grid** (cell = **2.5m wide × 3m tall**, at the locked 1m = 48px scale), plus **external pods** clipped to exterior hull faces. Everything physical about the sub — interior geometry, doors, ladders, hull silhouette, hull collider, water cells, breach surfaces, sub mass, implosion volume — is **generated from the layout** by one pipeline. Players buy modules at the dry dock into an **inventory**, then **assemble** the layout themselves on a grid screen; a single **validation function** is the only authority on what's legal, and the assembler refuses invalid placements outright, so an invalid sub can never exist. Refitting happens only at the dock, applies instantly, and the layout persists in the save.

---

## 2. The grid

- **Cell:** 5m × 3.0m (240 × 144 px). Constants live with the other geometry constants; never re-derive them locally. *(Superseded from 2.5m by `ROOM_SYSTEM.md` §1, settled at Checkpoint 1 — see `DECISIONS.md`.)*
- **Coordinates:** integer `Vector2i` grid positions; +x toward the bow (right), +y downward. Origin is arbitrary but fixed per layout (the helm anchors it — see §5).
- **Uniform height rule:** all rooms are exactly 1 cell (3m) tall (settled — the lower deck loses its squat 2.5m height; this is a deliberate visual change, re-verify feel at Checkpoint 1).
- **Room sizes:** every room module occupies a whole number of cells. The standard catalog uses 2×1 (the classic 5×3m room) and 1×1 (tower-sized).

### 2.1 The normalized starting layout ("The Minnow+")
The current hand-built M3 sub re-expressed on the grid. Target layout (grid positions illustrative — keep relative arrangement):

```
            [Tower 1×1]              y = -1
[Engine 2×1][Middle 2×1][Helm 2×1]   y =  0   (bow → right)
[Storage 2×1][Claw 2×1]              y = +1
```

- Helm at the bow end of the main row; tower directly above the middle room; claw room below middle; storage below engine (matching M3 adjacency).
- Geometry deltas vs M3 to expect and accept: tower grows 2×2m → 2.5×3m; lower-deck rooms grow 2.5m → 3m tall. Everything else identical. Update test constants accordingly — do not "preserve" old sizes with special cases.

---

## 3. Data model

Three plain data layers. Keep them dumb; behavior lives in the generators.

1. **ModuleDef** (per module *type*, one resource each): id, display name, footprint in cells (e.g. 2×1), price, station scene (optional), special faces (e.g. turret `firing_face`), flags (`is_pod`, `is_core`). The catalog is the list of ModuleDefs.
2. **Layout** (per save): the helm + tower fixed placements, a list of `{module_id, grid_pos, orientation}` for placed rooms, a list of `{pod_id, host_cell, face}` for pods, and the **inventory** (owned-but-unplaced module ids).
3. **GeneratedSub** (runtime only, never saved): everything the pipeline derives — room rects, connections, hull polygon, water cells, etc.

Orientation: rooms support horizontal mirroring only (a 2×1 room facing bow or stern). No rotation — cells are not square, rotation would break the grid. Turret rooms use mirroring to choose their firing direction; placement on top/bottom rows can also expose an up/down firing face (see §7).

---

## 4. The generation pipeline (one entry point)

`rebuild_from_layout(layout)` is the **only** way sub geometry comes into existence — boot, dock refit, and tests all call it. It runs these stages in order; each stage consumes only the layout and prior stages' output:

1. **Rooms:** instantiate each placed module's interior (floor, walls, ceiling) at its grid rect. Stations spawn with their room.
2. **Connections (automatic, rule-based — players never place doors):**
   - Two rooms sharing a full vertical wall segment (horizontally adjacent cells) → a **doorway** in that shared wall: standard opening + physical `DOOR_STEP_H` lip + `door_sill_m` water sill. One doorway per shared wall segment, centered.
   - Two rooms stacked (vertically adjacent cells) → a **floor opening + ladder** using the existing ladder rules and the M3 floor-opening water behavior (water falls down freely; pushes up only when the lower room is full past the opening). One opening per shared horizontal segment, centered.
   - The tower connects to whatever room sits beneath it by exactly this rule (today: the middle room — same as M3).
3. **Hull:** compute the rectilinear union outline of all occupied cells; the hull visual is this outline with the existing rounded placeholder styling; the **hull polygon collider** is regenerated from the same outline (it must keep tilting with the cosmetic pitch like today). Pods render as bumps attached outside the outline; pods do **not** alter the collider in M4.
4. **Water cells:** one water volume per placed room (a 2×1 room is ONE water cell — do not split per grid cell). Volume = footprint area. Register all door/ladder sills from stage 2. The 6-cell M3 model becomes "N-cell, generated."
5. **Breach surfaces:** each room's exterior-facing wall segments (cell faces not shared with another room) are its valid breach surfaces; nearest-room impact rule unchanged.
6. **Derived totals:** sub mass contribution, combined room volume, and the implosion threshold (same single `GameFeel` fraction × current total volume).
7. **Crew placement:** on refit, crew are repositioned to the helm room floor (refits only happen docked and paused, so no mid-run edge cases exist — enforce that invariant rather than handling its violation).

**Hard rule for the build:** stages must not reach around each other or read scene-tree state from the old sub. If a stage needs something, it comes from the layout or an earlier stage's output. This is what keeps the system Sonnet-proof.

---

## 5. Validation (one function, the only authority)

`validate(layout) -> {ok, violations[]}` — pure, no side effects, callable headlessly. The assembly UI calls it live and refuses any placement that fails; the loader calls it on boot. **No other code re-implements any of these rules.** Rules, each with a player-readable violation message:

1. **Core fixed:** helm and tower exist exactly once each, at their fixed grid positions (helm + tower are the *only* locked modules — settled). They are not in inventory and cannot be moved or sold.
2. **Connectivity:** every placed room reaches the helm through the auto-connection graph (doors/ladders). No islands.
3. **Tower support:** the cell directly below the tower is occupied (the tower must stand on a room and gain its ladder).
4. **No overlap:** no two footprints share a cell; nothing occupies the tower's cell or helm's cells.
5. **Clear special faces:** a turret room's `firing_face` must be an exterior face (not adjacent to another room) — a gun can never be bricked in. Same mechanism generalizes to future modules.
6. **Pod faces:** a pod attaches only to an exterior face of an occupied cell; one pod per face.
7. **Bounds sanity:** layout fits inside a generous max bounding box (e.g. 8×5 cells) purely as a technical guard; real growth limiting is economic (price escalation), not this box.

When loading a save: if `validate` fails (rules changed between versions), **do not crash and do not delete anything** — move every non-core placed module back to inventory, keep scrap untouched, and boot with the core + whatever still validates. The player reassembles at the dock. This is the designed recovery path, not an error state.

---

## 6. The dry dock (menu, keyboard-only)

Opens via `interact` when the sub floats in the dock zone; gameplay pauses. Two tabs, both navigable with both players' existing keymaps (no mouse — settled):

- **Shop:** catalog list with prices and short descriptions; buying moves a module into inventory and deducts scrap. **Price escalation (the soft cap):** each module's cost is `base_price × (1 + escalation × owned_count_total)` — owning more modules makes the next one pricier. Starting numbers in `GameFeel.dock` (see §8). No selling/refunds in M4.
- **Assembly:** the sub layout drawn as a grid diagram; a cell cursor moved with the move keys; select an inventory module → valid placements highlight (driven live by `validate`) → place with `use`. Select a placed non-core module → pick it up back to the cursor → re-place or return to inventory. **Rearranging is free, but only here** (settled). An **Apply** action runs `validate` one final time, calls `rebuild_from_layout`, writes the save, and closes the menu. Cancel restores the pre-edit layout.

The refit is an **instant swap** (settled) — no construction animation in M4.

---

## 7. The two M4 modules

- **Turret room (2×1):** contains a gunner seat; the tube mounts on its `firing_face` (bow-or-stern via mirroring; if placed on the top/bottom hull row with that face exterior, up/down mounts are allowed if cheap to support — otherwise defer vertical mounts and say so). The ±60° cone, sweep/hold aim, cooldown, and torpedo behavior are **reused unchanged** from the existing turret, with the cone centered on the face normal. The original bow turret stays as-is in M4 (it belongs to the middle room/bow mount today); unifying it into a turret-room module is allowed only if it falls out naturally — never force a risky refactor for symmetry.
- **Floodlight pod (face-clip):** a small exterior pod on any exterior face; renders outside the hull; adds a wall-mounted **aim seat** inside the host room (a `Station` subclass — inherits flood eject for free). W/S sweeps the light cone (PointLight2D/cone placeholder) like the turret barrel, holds angle. Ambient darkness does NOT change in M4 — the pod just provably works; Zone 2 (M5) makes it matter.

---

## 8. Tunables (`GameFeel.dock` — starting values, expect tuning)

Pacing target (settled): the **first room is affordable after ~1 good run**. With M3 values (item = 1 scrap, heavy = 3), a good run banks roughly 5–8 scrap. So:

- `turret_room_price = 6`, `floodlight_price = 4`, `escalation = 0.25` (each owned module raises subsequent prices 25%).
- `dock_zone` reuses the M3 banking zone.
- Max bounds guard: `max_cells = Vector2i(8, 5)`.

---

## 9. Persistence

Extend the M3 `user://` save (same file): banked scrap (existing) + inventory (module id counts) + layout (placements & pods). Write on every bank **and** on every dock Apply. Load on boot → `validate` → `rebuild_from_layout` (with the §5 fallback). Mid-run state still never saves.

---

## 10. Invariants & known traps (read twice)

- **One pipeline:** if any code is found constructing room geometry, water cells, or hull outside `rebuild_from_layout`, that is a bug to fix, not a pattern to extend.
- **One validator:** UI highlighting, Apply, and boot-load must all call the same `validate`.
- **Water conservation:** the M2 volume-weighted equalization must keep conserving water with N generated cells of mixed sizes — the existing `test_water` math extends, it does not get a parallel implementation.
- **Class cache:** after adding any `class_name` script, run `--headless --import` once (known Godot 4.4 trap, see STATUS).
- **Respawn:** drowning respawn stays at the tower in every layout (it's core-fixed, so this is free — assert it anyway).
- **Tilt:** generated hull visual, breach markers, turret barrels, pods, and water rects all keep the playtest-#1 parenting fix (children of the hull visual, pitch with the sub).
- **Do not build:** module selling, walkable dock, construction animations, hull-rating purchases (M5), pod collision, mouse input, rotation of rooms, per-grid-cell water, mid-run refitting, migration wizards. When in doubt: the module returns to inventory and the player reassembles — that hammer solves every weird state.
