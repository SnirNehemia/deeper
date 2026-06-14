---
name: add-deeper-room
description: >
  Add a new purchasable room type to DEEPER's submarine (a new gun, arm,
  storage room, or similar one-cell room with its own station/mechanic). Use
  when a brief says "add a room", "new room", "new station", "new weapon
  room", or asks for a room modeled on the Turret Room. Do NOT use for
  larger (multi-cell) rooms (ROOM_SYSTEM.md §7 — out of scope), for pods
  (floodlight pod is the only one; a different pattern), or for ship-wide
  upgrades (Engine Boost / Repair Training in sub_loadout.gd — unrelated
  system).
---

# Add a DEEPER room

This skill is a **checklist with a template**, not a generator. The plumbing
(catalog entry, shop listing, validation, save/load, hull generation, water,
flood-eject, section baking, art registration) is uniform and this checklist
makes it free. The room's **unique mechanic** (the gun, the arm, whatever it
does) is always hand-written against the closest existing room — copy
`turret_room` (the reference implementation, M4-10) unless the brief points
at a closer relative.

**Read first:** `ROOM_SYSTEM.md` (§2 sections, §3 ladder parity, §4 economy,
§6 the room you're building is probably already specced here) and
`MODULAR_SUB_IMPLEMENTATION.md` §4-5 (pipeline + validation). If the room in
the brief is one of the §6 worked examples, that's your stats/elements spec —
don't invent numbers.

## Preconditions (confirm these exist before starting)

- `scripts/sub/module_def.gd` (`ModuleDef` — catalog entry schema)
- `scripts/sub/module_catalog.gd` (`ModuleCatalog.all()` — the catalog list +
  `purchasable_rooms()`)
- `scripts/sub/sub_validator.gd` (`SubValidator.validate()` — the one
  validator, rules are numbered)
- `scripts/sub/sub_geometry.gd` (`SubGeometry` — compiles layout to rooms/
  doors/ladders; section-bake helper `section_center_x()`)
- `scripts/sub/sub.gd` (`Sub._compute_anchors()` computes seat/element
  positions from sections; `Sub._build_stations()` instantiates station
  nodes)
- `autoload/save_data.gd` (`buy_room`, `can_afford_cost`, `cost_bundle()`)
- `scripts/ui/dry_dock.gd` (Shop tab — reads `ModuleCatalog.purchasable_rooms()`
  automatically, no per-room UI code needed)

If any of these are missing or renamed, **stop** — the pipeline has changed
and this skill needs updating before it can be trusted.

> **Upgrade trees (ROOM_SYSTEM.md §5) are NOT yet wired into code.** No
> generic per-room upgrade-tree mechanism exists (only the unrelated ship-wide
> Engine Boost / Repair Training in `sub_loadout.gd`). If the brief's room has
> an upgrade tree, **build the room without it** and flag the upgrade tree as
> a follow-up — do not invent a one-off upgrade menu. See STATUS.md /
> DECISIONS.md (M4-11, 2026-06-16) for this scoping call.

## The procedure

1. **Pick the room-def from `ROOM_SYSTEM.md` §6** (or the brief). Note: id,
   display name, one-line description, cost bundle (`sc`/`s_ca`/`m_ca`/`l_ca`),
   `has_firing_face` (true only if the mechanic fires/reaches *out* of the
   sub on a wall that must stay exterior — see step 5), `can_host_pod` (almost
   always false — only the Floodlight Room uses this), section→element map
   (default: station in s3).

2. **Add the catalog entry** in `scripts/sub/module_catalog.gd`. Follow
   `_turret_room()` as the template:
   ```gdscript
   ## <One-line note: what real mechanic this is, citing ROOM_SYSTEM.md §6 and
   ## the Sub._build_xxx function that seats it.>
   static func _my_room() -> ModuleDef:
       var def := ModuleDef.new()
       def.id = "my_room"
       def.display_name = "My Room"
       def.description = "<one-line player-facing blurb, shown in the Shop tab>"
       def.footprint = Vector2i(1, 1)
       def.has_firing_face = true  # only if it has an outward-facing mechanic
       def.cost = {"sc": 4}  # from ROOM_SYSTEM.md §6
       return def
   ```
   Add it to the array returned by `ModuleCatalog.all()`. That's the **entire
   shop/buy/inventory wiring** — `purchasable_rooms()` and the dry dock's Shop
   tab pick it up automatically because it's non-core, non-pod, and has a
   non-empty `cost_bundle()`.

3. **Compute the room's anchors** in `Sub._compute_anchors()`. Pattern after
   the M4-10 turret-room block (sub.gd, search `_turret_rooms`): loop
   `geometry.rooms`, filter `room.module_id == "my_room"`, and compute
   sub-local positions via `_section_x(room, N)` for `sN` elements (default
   station in s3) or `room.rect.position.y + room.rect.size.y` for the floor
   y. For a `tN`/`bN` (ceiling/floor-mounted) element, offset from
   `room.rect.position.y` (ceiling) or the floor y by your element's size.
   Store one dict per placed instance in a new `_my_rooms: Array` (mirroring
   `_turret_rooms`), each holding whatever the station needs (seat position,
   any outward-facing anchor, `room.water_index`, `room.mirrored`).

   **Outward-facing elements** (guns, claws, anything denoted "outside" in
   ROOM_SYSTEM.md §2): the firing-face wall depends on `mirrored` — unmirrored
   points toward the bow (+x, room's right wall), mirrored toward the stern
   (-x, room's left wall). This mirrors `SubValidator._firing_face_offset()`
   exactly — same convention, same direction. See the turret-room block for
   the `if room.mirrored: ... else: ...` shape.

4. **Hand-code the mechanic**, against the closest reference:
   - **Weapon firing outward** (gun, torpedo tube): copy `TurretStation`
     (`scripts/stations/turret_station.gd`) and `Sub._build_turret_room()`
     (sub.gd). Reuse `TurretStation` directly if the new gun is just another
     torpedo tube at a different seat/facing (as M4-10 did) — only write a new
     station class if the mechanic itself differs (different projectile,
     aiming, etc).
   - **Arm reaching outward** (claw-like): copy `ClawStation`
     (`scripts/stations/claw_station.gd`) and `Sub._build_claw()`.
   - **Passive container** (storage-like): copy the storage-pen pattern
     (`Sub._compute_anchors()`'s `storage` block + `SubVisual._draw_storage_pen`,
     `Sub.storage_count()`/`storage_scrap`).
   - **Genuinely novel mechanic** (wrecking ball, shield, etc.): write a new
     `*Station` class under `scripts/stations/`, following the shape of
     `TurretStation`/`ClawStation` (fields: `sub`, `room_index`, `position`;
     a `handle_input()` if it's player-operated; hooks into the flood/water
     model only via existing `Sub`/`SaveData` APIs — never re-implement
     flooding).

   In every case: instantiate the station in a new `Sub._build_my_room(entry:
   Dictionary)` and call it from `Sub._build_stations()`:
   ```gdscript
   for r in _my_rooms:
       _build_my_room(r)
   ```
   (additive — existing `if _room_by_id(...) != null: _build_xxx()` lines for
   other rooms are untouched).

5. **Add validation cases only if needed**, in `SubValidator.validate()`
   — do not validate elsewhere. The existing rules already cover the common
   cases for any `has_firing_face` room for free:
   - Rule 5: firing face must be exterior (not blocked by another room).
   - Rule 8: a `has_firing_face` room must sit at the far left/right edge of
     its row.
   A new room with `has_firing_face = true` needs **no new validator code** —
   these rules key off the flag, not the room id. Only add a new rule if the
   room's mechanic imposes a constraint neither rule covers (e.g. "must not be
   on the top floor"). Also confirm (by inspection, not runtime check) that
   your section→element map doesn't author into s1/s5 on a floor where that
   section is the ladder (ROOM_SYSTEM.md §3) — this is an authoring-time
   check, no code needed if you just don't do it.

6. **Register placeholder art + layers**:
   - Add any new colors to `scripts/placeholder_art.gd` (follow the existing
     grouped-by-system layout, e.g. under "# --- Sub / hull ---").
   - Draw the element in `scripts/sub/sub_visual.gd`'s `_draw()` — follow
     `_draw_turret()` / `_draw_storage_pen()` for the pattern (read positions
     off the station/Sub, draw with `PlaceholderArt` colors, no magic numbers).
   - Only touch `scripts/collision_layers.gd` if the mechanic needs a *new*
     collision layer (most don't — torpedoes already use `PROJECTILE`, claws
     use `SALVAGE`, etc).

7. **Class-cache import**: if you added a new `class_name` script (a new
   `*Station`), run once:
   ```
   "D:\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe" --headless --path . --import
   ```
   before running any test that references it, or you'll get "Could not
   resolve class".

8. **Shop catalog**: done in step 2 — nothing further needed.

## Test skeleton

Add a `_test_placed_<room_id>()` function to the relevant `tests/test_*.gd`
(or a new file if the mechanic warrants its own suite), modeled on
`tests/test_turret.gd`'s `_test_placed_turret_room()`. **Important:** building
a `Sub` and reading its stations is **synchronous** — `Sub._ready()` builds
geometry, anchors, and stations all in one call, so the test needs **no
`await get_tree().physics_frame` loops** for these checks (the long
frame-waits elsewhere in `test_turret.gd` predate this and have a known
unrelated hang — don't copy that pattern).

```gdscript
func _test_placed_my_room() -> void:
    print("[placed My Room]")
    var layout := SubLayout.starting_layout()
    # Pick a slot consistent with any has_firing_face edge rule (rule 8):
    layout.placements.append(SubLayout.Placement.new("my_room", Vector2i(3, 0), false))
    _check(SubValidator.validate(layout)["ok"], "the layout with a placed My Room is valid")

    var sub := Sub.new()
    sub.layout = layout
    add_child(sub)

    var room := sub._room_by_id("my_room")
    _check(room != null, "the My Room is in the generated geometry")
    # ... mechanic-specific assertions: station exists, seat/anchor position
    # is where _compute_anchors put it, facing/mirroring is correct, etc.

    sub.queue_free()
```

Universal invariants every new room should pass (most for free via shared
code — call out only if something *doesn't*):
- buyable (`ModuleCatalog.purchasable_rooms()` includes it once cost is set);
- a layout placing it validates (or fails with a player-readable message if
  placed illegally, e.g. a firing-face room mid-row → rule 8);
- floods/ejects like any room (shared `Sub`/water-model code, untouched);
- persists through save → load → `SubValidator.recover()` (shared `SaveData`/
  `SubLayout` code, untouched).

## Definition of done

- [ ] Catalog entry added (`module_catalog.gd`), appears in
      `purchasable_rooms()`.
- [ ] Anchors computed in `_compute_anchors()`, stored in a new
      `_<room>_rooms` array.
- [ ] Mechanic hand-coded (existing station reused, or new `*Station` class
      following the established shape).
- [ ] `_build_<room>()` wired into `_build_stations()`.
- [ ] Validation: confirmed existing rules cover it, or a new numbered rule
      added to `SubValidator.validate()` with a player-readable message.
- [ ] Art: colors in `placeholder_art.gd`, drawing in `sub_visual.gd`.
- [ ] New `class_name` script (if any): ran `--headless --path . --import`.
- [ ] Test added and passing standalone (see hang caveat above).
- [ ] Full headless suite green (no new `FAILED`/`FAIL:`/`SCRIPT ERROR`/
      `Parse Error`).
- [ ] Upgrade tree (if the brief's §6 entry has one): **not built** — note it
      as a follow-up in STATUS.md, per the M4-11 scoping decision.
- [ ] Commit message: `M<milestone>-<step>: <room name> room`.

## Do not

- Don't re-implement flood/eject, water flow, hull generation, section
  baking, or doorway/ladder placement — `Sub`, `SubGeometry`, and the water
  model already do this for every room.
- Don't add geometry outside `SubGeometry`/`Sub._compute_anchors()` /
  `_build_stations()`.
- Don't let s1-s5 section names leak past `_compute_anchors()` — everything
  downstream (pipeline, water, `validate()`) works in baked coordinates only.
- Don't add validation logic outside `SubValidator.validate()`.
- Don't assume scrap-only cost — always use `cost = {...}` /
  `cost_bundle()`, never the legacy `price` field, for new rooms.
- Don't build a bespoke upgrade menu — if the room needs upgrades, stop and
  flag it (see Preconditions).
- Don't add real art/sound — placeholder colors/shapes only.
- Don't add per-room Shop-tab UI code — `purchasable_rooms()` + the existing
  Shop loop in `dry_dock.gd` already lists any catalog entry with a cost.

## Validating this skill

To re-verify this skill still matches the codebase, follow it end-to-end to
re-derive `turret_room` from scratch in a scratch branch (rename it
`turret_room_2`, run through steps 1-8 + the test skeleton, confirm the
result matches `sub.gd`'s real `_turret_rooms`/`_build_turret_room`), then
discard the branch. Any step that's ambiguous or missing means this file is
stale — fix it here, not in the scratch branch.
