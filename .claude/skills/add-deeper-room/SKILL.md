---
name: add-deeper-room
description: >-
  Add a new room type to the DEEPER submarine (a station, weapon room, collector
  arm, sensor, or passive container that occupies one grid cell). Use when a brief
  says "add a room", "new room", "new station", "new weapon room", "new collector",
  or specs a room from the ROOM_SYSTEM.md catalog. Covers filling the room-def,
  hand-coding the unique mechanic against a reference room, wiring the upgrade tree
  and multi-resource price, adding validation/art/layers, and the headless test.
  Do NOT use for: designing what a room does (that's a milestone brief), balancing
  stats/prices (playtest tuning), or larger multi-cell rooms (ROOM_SYSTEM.md §7 —
  their own pass).
---

# Add a DEEPER room

This skill adds **one uniform-cell room type** to DEEPER. The submarine's room
plumbing — grid, pipeline, validator, per-room water, hull generation, section
baking, upgrade-tree wiring, multi-resource costs — **already exists and is
inherited**. Your job is to fill the *declarative* parts (the room-def) and
hand-code only the room's *unique mechanic* against the closest existing room.
Everything else is wired for you. Do not re-implement it.

> **Mental model:** the plumbing is data; the mechanism is code. A room-def
> captures everything uniform across rooms (id, sections, elements, stats, upgrade
> tree, price). A room's one novel behaviour (an arm's reach, a weapon's
> projectile, a sensor's pulse) is always hand-written against a reference room.
> This skill makes the plumbing free and points you at the right reference — it
> does **not** pretend the mechanic is data.

## 0. Preconditions — read before touching anything

**Read, in order:** `CLAUDE.md` → `STATUS.md` → `DECISIONS.md` →
`MODULAR_SUB_IMPLEMENTATION.md` (§4–5: pipeline, validation) → `ROOM_SYSTEM.md`
(§2 sections, §3 ladder parity, §4 economy, §5 upgrades, §6 catalog). The catalog
in `ROOM_SYSTEM.md` §6 is your reference set — find the closest existing room to
the one you're adding and read its implementation before writing anything.

**Confirm these systems exist** (if any is missing, stop — the room can't be added
cleanly and that's a design-level problem to surface):
- the grid + `SubLayout` data model and `rebuild_from_layout` pipeline
  (`MODULAR_SUB_IMPLEMENTATION.md` §4);
- the **section-bake step** that compiles s1–s5 to local x-offsets *before* the
  pipeline runs (`ROOM_SYSTEM.md` §2);
- `validate()` as the **sole** layout authority (`MODULAR_SUB_IMPLEMENTATION.md`
  §5) — never branch layout legality anywhere else;
- the generic **upgrade-tree** mechanism (`ROOM_SYSTEM.md` §5);
- **multi-resource cost** checking at the dock (`ROOM_SYSTEM.md` §4.2 — sc / s_ca /
  m_ca / l_ca, *not* scrap-only);
- the shop catalog the room must be registered in
  (`scripts/sub/module_catalog.gd` — `ModuleCatalog.all()` and `purchasable_rooms()`);
- `PlaceholderArt` (`scripts/placeholder_art.gd`) and `CollisionLayers`
  (`scripts/collision_layers.gd`).

**Confirm these specific files exist before writing:**
- `scripts/sub/module_def.gd` (`ModuleDef` — catalog entry schema)
- `scripts/sub/module_catalog.gd` (`ModuleCatalog.all()` — the catalog list +
  `purchasable_rooms()`)
- `scripts/sub/sub_validator.gd` (`SubValidator.validate()` — the one validator)
- `scripts/sub/sub_geometry.gd` (`SubGeometry` — `section_center_x()`)
- `scripts/sub/sub.gd` (`Sub._compute_anchors()`, `Sub._build_stations()`)
- `autoload/save_data.gd` (`buy_room`, `can_afford_cost`, `cost_bundle()`)
- `scripts/ui/dry_dock.gd` (Shop tab — reads `ModuleCatalog.purchasable_rooms()`
  automatically, no per-room UI code needed)

> **Reference rooms (closest-match table):** pick the nearest and read it first.
> - **Collector arm** → claw room (`scripts/stations/claw_station.gd`, two-joint,
>   ferry-to-pen) or the telescope room (M7: aim/extend/retract/Q-grab/auto-deposit-cages).
> - **Weapon** → base-gun room (`turret_room`) or bullet room (§6) for fire-and-forget;
>   the heavy-torpedo room (when built) for post-launch guidance + two-stage detonation.
> - **Passive container** → storage room (§6: no station, cages only).
> - **Remote/utility station** → the conning-tower Hull station (M5: remote-acts
>   on the nearest target within a room radius).
> (Verify these paths against the live tree — `STATUS.md` is the index of what
> landed in which module.)

## 1. The room-def — fill the template

Author the room declaratively in `module_catalog.gd`. Follow `_turret_room()` as
the template (confirm exact field names in `module_def.gd` before writing):

```gdscript
## <One-line note: what real mechanic this is, citing ROOM_SYSTEM.md §6 and
## the Sub._build_xxx function that seats it.>
static func _my_room() -> ModuleDef:
    var def := ModuleDef.new()
    def.id = "my_room"                       # stable snake_case key
    def.display_name = "My Room"             # shop/UI label
    def.description = "<one-line player-facing blurb, shown in the Shop tab>"
    def.footprint = Vector2i(1, 1)           # always 1×1 for current rooms
    def.has_firing_face = true               # only if it has an outward-facing mechanic
    def.cost = {"sc": 4}                     # from ROOM_SYSTEM.md §6; never scrap-only assumption
    return def
```

Add it to `ModuleCatalog.all()`. That's the **entire shop/buy/inventory wiring** —
`purchasable_rooms()` and the dry dock's Shop tab pick it up automatically because
it's non-core, non-pod, and has a non-empty `cost_bundle()`.

**Section → element map** (`ROOM_SYSTEM.md` §2 notation):
- **Default station is `s3`.** Passive rooms (storage) declare *no* station.
- Use `sN` (mid-wall), `tN`/`bN` (ceiling/floor of section N — e.g. `b3` for a
  keel-mounted arm base).
- **Never author an element into the floor's ladder section** (s1 on odd floors,
  s5 on even — §3). This is an authoring-time check; there is no runtime guard.
- **Outside-element wall side:** guns, arms, sensors mount on an exterior face.
  The design screen switches them left/right or auto-assigns the open-water face.
- **Stats block:** all as `GameFeel` keys, never literals in logic.
- **Price:** `[-]` for a starting room (no purchase); a resource bundle for a
  purchasable one. Add the resource costs as `GameFeel` keys, not literals.

## 2. Hand-code the mechanic (only if the room has a new one)

Write the mechanic **against the nearest reference room** (table in §0).
Flood-eject, water, hull, section-baking, save/load, and tilt are **inherited —
do not re-implement them.**

- Reuse existing state machines — e.g. a new collector should ride the existing
  `SalvageItem` state machine (water → grabbed → caged/banked), not a parallel one.
- Keep the mechanic's surface small: one clear input scheme, one clear effect.
- Orientation-aware elements (anything mounted on an outer wall) must read the
  mounted side and map directional input toward open water — mirror the floodlight
  (`scripts/stations/floodlight_station.gd`) / claw orientation handling so
  controls feel correct on either wall.
- Anything drawn (arms, tips, cages, beams, projectiles) goes through
  `scripts/sub/sub_visual.gd`'s `_draw()` so it **tilts with the hull** — mirror
  how the claw is drawn (`_draw_claw()`).

Instantiate the station in a new `Sub._build_my_room(entry: Dictionary)` and call
it from `Sub._build_stations()`:
```gdscript
for r in _my_rooms:
    _build_my_room(r)
```

If the mechanic won't sit cleanly on the existing interface, **stop and report in
design terms** (see §8).

## 3. Wire the upgrade tree (generically)

> **NOTE: The generic upgrade-tree mechanism (`ROOM_SYSTEM.md` §5) is NOT yet
> implemented in code** (DECISIONS.md M4-11 scoping call). If the brief's room has
> an upgrade tree, **build the room without it**, carry an empty stub, and flag the
> upgrade tree as a follow-up in STATUS.md. Do not build a bespoke upgrade menu
> per room. When the generic mechanism does land, rooms will expose stat hooks the
> tree drives — the sections below describe that future-state design.

Design guidance for when the mechanism ships:
- **Linear chain:** "X first `[cost]`, then Y `[cost]`."
- **Branch (one-time fork into mutually exclusive paths):** "splits to A or B,"
  each with its own sub-chain.
- Upgrades change **stats** (speed/damage/rate/capacity), **behaviour**, or
  **element count** (extra cages, more minibombs). Wire them as data + hooks —
  the room exposes the hooks, the tree drives them.
- Costs escalate along a path, paid in §4.2 resource tiers.
- A room with no upgrades carries an empty/stub tree — fine; don't invent content.

## 4. Price and slot

`ROOM_SYSTEM.md` §4:

- **Adding a room is two independent buys:** a **cell slot** (growth budget, price
  escalates per `MODULAR_SUB_IMPLEMENTATION.md` §6) and the **room** (bought into
  inventory, placed into an empty slot). You usually only price the *room* here;
  the slot economy is shared and already exists.
- **Costs are multi-resource bundles**, written `[…]`: `sc` scrap, `s_ca` small
  carcass, `m_ca` medium carcass, `l_ca` large carcass. **Never assume scrap-only**
  — the dock's multi-resource check is the path (§4.2). `[-]` = starting room,
  owned from run one, not in the shop.
- Add the resource costs as `GameFeel` keys, not literals.

## 5. Validation, art, layers, import, catalog

- **Validation:** if the room needs a new legality rule, add it in `validate()`
  **only** (`MODULAR_SUB_IMPLEMENTATION.md` §5). The existing rules already cover
  common cases for any `has_firing_face` room (rule 5: firing face exterior; rule 8:
  at row/column edge). Only add a new rule if the mechanic imposes a constraint
  neither covers.
- **Section→element map authoring check:** confirm your element sections don't
  land in the floor's parity ladder section (§3) — authoring-time check, no code.
- **Art:** register colours/dimensions in `scripts/placeholder_art.gd`. Draw the
  element in `scripts/sub/sub_visual.gd`'s `_draw()` — follow `_draw_turret()` /
  `_draw_storage_pen()` for the pattern. No real art (that's the art pass).
- **Layers:** only touch `scripts/collision_layers.gd` if the mechanic needs a
  *new* collision layer. Most don't — torpedoes use `PROJECTILE`, claws use
  `SALVAGE`, etc.
- **Import trap:** if you added a script with `class_name`, run once:
  ```
  "D:\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe" --headless --path . --import
  ```
  before testing, or you'll get "Could not resolve class" stale-cache errors.
- **Catalog:** done in step 1 — `purchasable_rooms()` picks it up automatically.

## 6. The test (copy-paste skeleton)

Every room must pass the **universal invariants** in a headless suite
(`tests/test_<room>.tscn` + `.gd`, modelled on the nearest existing room test).

```gdscript
func _test_placed_my_room() -> void:
    print("[placed My Room]")
    var layout := SubLayout.starting_layout()
    # Pick a slot consistent with any has_firing_face edge rule (rule 8):
    layout.placements.append(SubLayout.Placement.new("my_room", Vector2i(3, 0), "right"))
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

> Building a `Sub` and reading its stations is **synchronous** — `Sub._ready()`
> builds geometry, anchors, and stations all in one call; no physics-frame awaits
> needed for these checks.

Assert:
- **buyable** (or present in the base loadout for `[-]`); **placeable only in a
  legal empty slot**; an illegal placement is **refused with a message**;
- **sections bake correctly** — station lands at s3 x-offset; `tN`/`bN` mounts
  land at the right ceiling/floor point; parity ladder section is clear;
- the room **floods / breaches / ejects** like any room;
- the **upgrade tree applies and persists** (when the mechanism lands);
- **persists through save → load → rebuild**; **tilts with the hull**.

Then add the **room-specific assertions** (mechanic, stats, grab/deposit cycle, etc.).

## 7. Definition of done

All boxes checked, then commit:

- [ ] room-def filled (id, name, footprint, section→element map, outside wall,
      stats as `GameFeel` keys);
- [ ] mechanic hand-coded against the reference room (if any), inherited plumbing
      untouched;
- [ ] upgrade tree: empty stub + follow-up flagged in STATUS.md (per M4-11);
- [ ] price (multi-resource) + any slot/reserved-cell interaction;
- [ ] new validation cases in `validate()` only;
- [ ] `PlaceholderArt` + `CollisionLayers` updated, no magic numbers;
- [ ] `--headless --import` run if a `class_name` was added;
- [ ] registered in the shop catalog (or base loadout for `[-]`);
- [ ] room test green **and full suite green**;
- [ ] `STATUS.md` updated (what shipped, files touched, test);
- [ ] commit message matching the milestone convention, e.g. `M7-2: telescope arm room`.

## 8. Do NOT

- Re-implement flood-eject, water, hull generation, **section baking**, or
  **upgrade-tree plumbing** per-room.
- Add geometry outside `rebuild_from_layout`.
- Let s1–s5 leak into the pipeline / water / hull / `validate` (they bake to
  coordinates upstream — `ROOM_SYSTEM.md` §8 invariant).
- Author an element into a floor's parity ladder section (§3).
- Copy layout-legality logic out of `validate()`.
- Assume scrap-only costs (§4.2).
- Branch on a 2×1-vs-1×1 footprint (stale M4-draft logic — one uniform cell, §8).
- Add real art or sound.
- Build a larger (multi-cell) room here (`ROOM_SYSTEM.md` §7 — its own pass).
- Build a bespoke per-room upgrade menu — flag the tree as a follow-up instead.
- Add per-room Shop-tab UI code — `purchasable_rooms()` + the existing Shop loop
  in `dry_dock.gd` already lists any catalog entry with a cost.
- Use for ship-wide upgrades (Repair Training in `sub_loadout.gd` — unrelated system).

**If the procedure can't be followed cleanly** — too many special cases, sections
leak, the upgrade tree won't generalise, costs fight the system, the mechanic
won't sit on the existing interface — **stop and report to Snir in design terms.**
That means the room interface isn't as clean as `ROOM_SYSTEM.md` assumes, which is
worth knowing *before* later milestones pile on more rooms. Pressure-testing the
interface is half the reason this skill exists.
