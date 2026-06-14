# STATUS — DEEPER

_Read this at session start. Last updated: 2026-06-15 (M4-8e: Assembly keys
remapped to the interact/use convention, and slot prices no longer drift when
rooms are placed/returned. M4-9a: the floodlight pod can now be bought into
inventory and attached/detached from an exterior hull face at the data layer.
Next: M4-9b — the Assembly-tab UI for attaching pods → Checkpoint 2.)_

## Where we are
**Milestone 3 is closed (Modules A-E).** Milestone 4 ("The Dry Dock & The
Growing Sub") is well underway — **all 26 headless suites green.**

**The submarine is now fully layout-driven** (built from a `SubLayout` via the
`SubGeometry` pipeline; no hand-authored geometry). Snir **played Checkpoint 1**
and the geometry is tuned (5m rooms / 1m sections, 0.9m ladders, elements
snapped to their sections). The **dock UI is now complete for the room economy**:
the dry dock has three tabs — Upgrades, Shop (buy rooms into inventory and buy
slots), and Assembly (a hull blueprint where buyable slots show as ghost cells
with prices, and owned inventory rooms can be placed into owned empty slots,
with an A/D mirrored toggle for rooms with a firing face). Next up is M4-9
(pods) → Checkpoint 2. See "Suggested next step" near the bottom.

**Required reading for M4, in order:** `CLAUDE.md` → this file → `DECISIONS.md`
→ `MODULAR_SUB_IMPLEMENTATION.md` (grid/pipeline/validation/dock canon) →
**`ROOM_SYSTEM.md`** (supersedes parts of the other two: one uniform cell, the
s1-s5 authoring/section layer, two-step slot/room economy, multi-resource
costs). `MILESTONE_4_v2.md` is the original build brief but its module
*numbering* is superseded by "M4 module order" below. `SKILL_STUB_add_module.md`
is dead — superseded by `SKILL_STUB_add_room.md`.

**Sonnet discipline (this milestone is being built in small steps):** one small
change at a time → headless-check it → **full suite green** → commit with a
descriptive message. Never start the next step on red. After adding any new
`class_name` script, run `--headless --path . --import` once. Explain everything
to Snir in game-behaviour terms and end each task with verify-by-playing steps
(he does not read code).

### Milestone 4 — Module 1b: grid resized to the uniform 3.75m cell
- Per `ROOM_SYSTEM.md` §1-2: the mixed 2x1/1x1 footprint catalog is replaced
  with **one uniform cell** for every room (helm, tower, control room, engine,
  claw room, storage, turret room) — **3.75m wide x 3m tall** (five 0.75m
  "sections," s1-s5, the new authoring layer for where stations/hatches/guns
  sit within a room — sections bake to coordinates before the generation
  pipeline runs and never reach it).
- `SubGrid` (scripts/sub/grid.gd): `CELL_W_M` is now 3.75 (was 2.5),
  `CELL_W_PX` 180 (was 120); added `SECTION_W_M = 0.75`. `CELL_H_M`/`CELL_H_PX`
  unchanged (3.0m / 144px).
- `ModuleCatalog`: every room's `footprint` is now `Vector2i(1, 1)`.
- `SubLayout.starting_layout()` ("the Minnow+") re-expressed on the new grid:
  same adjacencies (engine/control/helm in a row, tower above control,
  storage below engine, claw below control), each now a single cell.
- **Data-only, same as Module 1** — nothing in the running game changed; the
  hand-built M3 sub still builds and plays exactly as before. **Not yet
  visible in-game** — the wider/uniform cells only become visible once
  Modules 3-4 (generated interiors/hull/water) swap in the generated sub, at
  which point Checkpoint 1 asks Snir to judge the new sizing.
- Test: `test_layout` updated for the new constants/footprints (20/20 suites
  green).
- **Commit:** `M4-1b: resize grid to uniform 3.75m cell per ROOM_SYSTEM.md`.

### Milestone 4 — Module 2: slot economy (data model)
- Per `ROOM_SYSTEM.md` §4.1 ("Option B", settled with Snir): a **slot** is an
  owned-but-empty cell — a real room-shell once generated, just with no
  station inside. `SubLayout.slots: Array[Vector2i]` holds them, separate
  from `placements` (rooms with a module) and `inventory` (owned-but-unplaced
  room modules). Serializes/round-trips like everything else in the layout.
- `SubLayout.occupied_cells()`: every placement's footprint cells **plus**
  every slot — a slot counts as hull for adjacency, same as a placed room.
- `SubLayout.buyable_slot_positions()`: the empty cells the player could buy
  *right now* — empty, touching at least one occupied cell (slots must be
  **adjacent to the existing hull**, per Snir), and keeping the layout's
  bounding box within `SubGrid.MAX_CELLS`. This is what the dock shop (M4-7)
  and assembly screen (M4-8) will offer.
- `GameFeel.dock` (new `DockFeel` block): `slot_base_price` (4 scrap) and
  `slot_escalation` (0.25, linear — `price(n) = base * (1 + 0.25*n)`),
  **on its own track from any future per-room price escalation**, per Snir's
  call that slots and rooms escalate independently.
- **Still data-only / no UI** — nothing buyable in-game yet; the dock shop
  (M4-7) is what wires this to scrap and the dock menu.
- Test: `test_slots` (starting layout has no slots; buyable positions are
  empty+adjacent+in-bounds with no duplicates; buying a slot grows
  `occupied_cells` and updates future candidates; bounds guard excludes
  out-of-range slots; price escalation math; serialization round-trip).
  21/21 suites green.
- **Commit:** `M4-2: slot economy data model + price escalation`.

### Milestone 4 — Module 3: validation engine
- `SubValidator.validate(layout) -> {ok, violations[]}` (`scripts/sub/sub_validator.gd`):
  the single authority on layout legality, per `MODULAR_SUB_IMPLEMENTATION.md`
  §5's 7 rules plus the slot-overlap addition from `ROOM_SYSTEM.md` §4.1.
  Pure data, no side effects, callable headlessly:
  1. Core fixed — exactly one helm and one tower among placements; neither
     ever sits in inventory.
  2. Connectivity — every occupied cell (placed rooms **and** bought slots)
     reaches the helm via grid adjacency (stand-in for the auto doors/ladders
     the pipeline will generate from the same adjacency).
  3. Tower support — the cell below the tower is occupied.
  4. No overlap — no two placements share a cell; a slot can't overlap a
     placement either.
  5. Clear firing face — a turret room's firing face (the cell its gun points
     into, flipped by `mirrored`) must be exterior.
  6. Pod faces — a pod's host cell must be occupied and its face must be
     exterior; one pod per cell+face.
  7. Bounds sanity — the occupied-cell bounding box (placements + slots) fits
     `SubGrid.MAX_CELLS`.
- `SubValidator.recover(layout)`: the §5 load-time recovery path — on a
  failing layout, core placements keep their cells, non-core placements keep
  theirs on a first-claim basis (losers return to inventory, scrap untouched),
  slots/pods that no longer fit are dropped. Re-validates clean for the cases
  that matter (a stray overlapping room). Never crashes, never deletes a
  module outright.
- **Pure data/logic — no UI, no pipeline wiring yet.** Nothing changes
  in-game; this is the function M4-4's generation pipeline, the M4-8 assembly
  screen, and boot-load will all call as their one shared legality check.
- Test: `test_validate` — starting layout (with/without a bought slot)
  validates; missing/duplicate helm or tower, overlapping placements, a slot
  overlapping a room, an unsupported tower, a disconnected room, a bricked-in
  turret firing face, bad/duplicate pod faces, and an over-bounds layout are
  all correctly rejected; `recover()` restores a broken layout to a valid one
  and returns the bumped module to inventory. 22/22 suites green (the
  `capture_*` scenes are windowed screenshot tools, not part of the count —
  they time out headless by design and are excluded from the suite run).
- **Commit:** `M4-3: validation engine (validate + load recovery)`.

### Milestone 4 — Module 4a: layout geometry compiler (`SubGeometry`)
- `SubGeometry.build(layout)` (`scripts/sub/sub_geometry.gd`): the pure-data
  core of the generation pipeline (`MODULAR_SUB_IMPLEMENTATION.md` §4 stages
  1-2 + `ROOM_SYSTEM.md` §2-3). From a `SubLayout` it computes, in sub-local
  space (centered on the occupied bounding box, +x bow, +y down):
  - one interior **rect per placed room** (floor = bottom edge), each tagged
    with the water index the live Sub uses (placement order);
  - an auto-**doorway** for every horizontally adjacent room pair (shared
    vertical wall, opening on the floor);
  - an auto-**ladder** for every vertically stacked room pair, placed on the
    parity section — odd floors (counting from the top row) → s1, even → s5
    (`ROOM_SYSTEM.md` §3). The s1-s5 authoring sections are **baked to local
    x-offsets here** and never reach the live Sub/water/validate
    (`ROOM_SYSTEM.md` §8 invariant).
  - `connections()` reports the door+ladder topology the water model consumes.
- Bought-but-empty **slots are not rooms** (no interior generated) but DO
  count toward the hull bounding box / centering, matching `occupied_cells()`.
- **Pure data — nothing wired into the live Sub yet; the M3 hand-built sub
  still runs unchanged.** This is the foundation the M4-4b swap consumes.
- Test: `test_geometry` (room count/indexing, centering, cell size, door &
  ladder adjacency, ladder parity sides, section baking, slots-as-hull,
  connection topology). 23/23 suites green.
- **Commit:** `M4-4a: layout geometry compiler (rooms + doors + parity ladders)`.

### Milestone 4 — Module 4b: the live sub is now layout-driven (DONE)
**The submarine is fully generated from its layout — the first M4 change that's
visible in-game.** `Sub` (`scripts/sub/sub.gd`) no longer hardcodes geometry: it
compiles `SubLayout` (default `starting_layout()`) via `SubGeometry`, re-anchors
so the helm row's floor stays at y=0, and generates its interior collision
(floors, ceilings, doorways, parity ladders, hatches), water rooms, hull rects,
and seat/anchor positions from that. `sub_visual.gd` draws from the same
geometry. Stations get their positions from the sub at build (turret tube on the
helm's bow wall, claw keel anchor + drop floor); crew respawn uses the sub's
generated tower spot.
- **Gun room dropped until M4-9** (settled with Snir): the sub is the 6-room
  Minnow+; the M3 `SubLoadout` gun room is ignored (its `test_loadout`
  build/flood checks were removed, the M3 dry-dock placement schematic
  de-coupled from the old `Sub.*` consts). `engine_boost`/`fast_repair` stats
  still apply.
- **New room indices (placement order):** engine 0, middle 1, helm 2, tower 3,
  storage 4, claw 5 (claw/storage swapped vs the old hand-built order).
- **Geometry deltas (baked into tests, no shims):** 5m-wide cells (settled at
  Checkpoint 1 — see below; 1m sections), uniform 3m lower deck (no longer
  squat), full-size tower cell.
- **Checkpoint 1 round-1 tunings (Snir playtested 2026-06-13):**
  - Cell width: tried 3.75m (too narrow) → 7.5m (too wide) → **settled 5m**
    (`SubGrid.CELL_W_M`), so each of the 5 sections is exactly 1m.
  - Ladder overhang into the room above **halved** (48px → 24px,
    `SubGeometry.LADDER_OVERHANG`) — the ladder stuck up too far.
  - **Storage cage moved to section s3** (`ROOM_SYSTEM.md` §6). It was using a
    leftover M3 wall-offset (right edge − 66px), so it didn't line up with any
    section; now anchored to the centre section and drawn one section wide.
- **Checkpoint 1 round-2 tunings (Snir, 2026-06-13):**
  - Ladder width narrowed to 0.9m (`HOLE_W = 0.9 * PPM`) — read too wide.
  - **All in-room elements snapped to their authored section** (not wall
    offsets): helm/base-gun/claw stations s3, claw base b3, claw dropping hatch
    s2, storage cage s3 (`ROOM_SYSTEM.md` §6). `Sub._compute_anchors` uses
    `SubGeometry.section_center_x` for every element x.
  - **Gun room confirmed deferred to M4-9.** The current weapon is the M2 base
    bow turret (gunner middle room, tube at the bow); a proper room-with-its-
    own-exterior-gun is M4-9, and `validate()` already requires its firing face
    to be exterior (outer edge).
  - Still open: re-confirm the 0.9m ladders + section-snapped elements on play.
- **Ladder clearance fix:** ladder shafts sit at the *inner* edge of their
  parity section (s1/s5), not the section center, so a climbing crew clears the
  doorway frame on that wall. The uniform 0.75m section is barely wider than the
  crew (0.7m), so a wall-hugging ladder trapped the crew on the door header
  (the M3 hand-built sub hand-placed ladders clear of doorways for the same
  reason). **Flag for Checkpoint 1:** confirm the ladder/door spacing reads OK.
- **M4-5 largely folded in here:** because `room_rect()` feeds both the interior
  AND the water/hull, the generated hull collider (one grown rect per occupied
  cell), generated water cells + door/ladder sills, and the implosion threshold
  (fraction × generated total volume) all came across in this same swap.
  Remaining M4-5 polish (restrict breach surfaces to exterior faces; an
  explicit asymmetric-layout water-conservation test) is minor and tracked but
  does not change the Checkpoint-1 feel.
- Test: every coupled suite re-derived to the new geometry. **All 23 headless
  suites green; the main scene boots clean.**
- **Commit:** `M4-4b: layout-driven sub (generated interior/visual/stations)`.

### Milestone 4 — Module 6: save extension + layout persistence + recovery (DONE)
- `SaveData` now persists the submarine **layout** (placements, pods, owned
  slots, inventory) alongside banked salvage + loadout, via
  `SubLayout.to_dict/from_dict` (`autoload/save_data.gd`). `world.gd` builds the
  live sub from `SaveData.layout`.
- **Load-time validation + recovery** (`MODULAR_SUB_IMPLEMENTATION.md` §5/§9):
  on load the layout is run through `SubValidator.recover` — a layout left
  illegal by a rules change boots to core + inventory (non-core rooms returned,
  scrap untouched) instead of crashing or vanishing.
- **Legacy upgrade:** a pre-M4 save with no `layout` key loads as the starting
  Minnow+.
- Still no shop to *change* the layout yet (M4-7) — this is the persistence
  layer the shop/assembly will write through.
- Test: `test_save_layout` (round-trip of slots/inventory/placements;
  legacy-save upgrade; invalid-layout recovery returns the offending room to
  inventory). 24/24 suites green.
- **Commit:** `M4-6: save extension + layout persistence + recovery`.

### Milestone 4 — Module 7a: dry-dock shop, slot purchasing (DONE)
- `SaveData.buy_slot(pos)` + `next_slot_price()` (`autoload/save_data.gd`): the
  slot-economy spend (ROOM_SYSTEM.md §4.1 — the gate before a room has anywhere
  to go). Buying a legal buyable position deducts the escalating scrap price
  (`GameFeel.dock`, M4-2), appends the slot to the layout, and persists.
  Illegal positions (not adjacent to the hull / out of bounds) and insufficient
  scrap are refused with no state change.
- **Logic only — no shop UI yet** (M4-7b/c). These are the controller functions
  the keyboard shop will call.
- Test: `test_shop` (happy path, too-poor refusal, illegal-position refusal,
  price escalation, save/reload persistence). 25/25 suites green.
- **Commit:** `M4-7a: dry-dock shop slot purchasing logic`.
### Milestone 4 — Module 7b: multi-resource wallet + room purchasing (DONE)
- **Wallet** (`SaveData`): the four ROOM_SYSTEM.md §4.2 spend resources —
  `sc`=banked_scrap, `s_ca`=banked_fish (small carcass, the only tier that
  drops today), `m_ca`/`l_ca`=new banked counters (fill once bigger enemies
  exist, M5). All persist. `resource_balance(code)` / `can_afford_cost(bundle)`.
- **Module costs** are resource bundles: `ModuleDef.cost` (e.g. `{"sc": 4}`) +
  `cost_bundle()` (falls back to `price` scrap). `turret_room` = `{"sc": 4}`
  (base gun room, ROOM_SYSTEM.md §6); `ModuleCatalog.purchasable_rooms()` lists
  the buyable non-core, non-pod modules.
- `SaveData.buy_room(id)`: spends the bundle, adds one to `layout.inventory`,
  persists. Refuses core/pod/unknown ids and unaffordable bundles. Buying a
  room does NOT place it — placement is the assembly screen (M4-8).
- Test: `test_shop` extended (buy room into inventory, too-poor/core/pod/unknown
  refusals, multi-resource affordability). 25/25 suites green.
- **Commit:** `M4-7b: multi-resource wallet + room purchasing`.
- **Still to do for M4-7:** (c) the keyboard shop UI tying slot + room buying
  together (sell slots, sell rooms, show wallet). Then **M4-8** assembly (place
  inventory rooms into owned slots, `validate`-driven; Apply rebuilds the sub).

### Milestone 4 — Module 7c: dry-dock Shop tab (DONE)
- `DryDock` (`scripts/ui/dry_dock.gd`) gains a third mode, `Mode.SHOP`,
  alongside the existing M3 Upgrades list and the gun-room Placement view.
  **Tab** cycles Upgrades ↔ Shop from either tab; Esc closes from any tab.
- **Wallet header** now always shows all four resources: scrap, small/medium/
  large carcass (was scrap+fish only).
- **Shop list** (`_rebuild_shop_entries`): purchasable room types first
  (`ModuleCatalog.purchasable_rooms()` — currently just the Turret Room,
  `[4 sc]`), then one entry per `SaveData.layout.buyable_slot_positions()`
  ("Build a slot at (x, y)" at `SaveData.next_slot_price()` scrap).
  W/S navigate, Enter buys via `SaveData.buy_room`/`SaveData.buy_slot` — no
  spend/validate logic duplicated in the UI. A successful buy shows a
  confirmation note and rebuilds the list (slot positions/prices shift after
  a slot purchase); an unaffordable pick shows what's missing and changes
  nothing.
- Bought rooms land in `layout.inventory` (shown as "In inventory: N" under
  the room); bought slots grow `layout.slots` immediately — the world already
  rebuilds the sub on dock close, so a new slot's empty room-shell appears in
  the hull right away. Placing an inventory room into that slot is M4-8.
- Test: `test_dock_shop_ui` (Tab opens/leaves the Shop, an unaffordable buy is
  refused with a note and no state change, an affordable room purchase lands
  in inventory and spends the wallet, a slot purchase grows `layout.slots`,
  Esc closes and unpauses from the Shop tab). 26/26 suites green.
- **Commit:** `M4-7c step 1/2` (Shop tab + buy rooms; buy slots).

### Milestone 4 — Module 8: dry-dock Assembly tab (DONE)
- `DryDock` (`scripts/ui/dry_dock.gd`) gains a fourth mode, `Mode.ASSEMBLY`.
  **Tab** now cycles Upgrades → Shop → Assembly → Upgrades; Esc closes from
  any tab.
- **Assembly view** draws a top-down blueprint of the hull: each placed room
  as a filled, labeled box; each owned-but-empty slot as an outlined "empty
  slot" box; each currently-buyable slot position as a faint ghost cell
  showing its scrap price (gold-highlighted when selected) — this replaces
  the old text-based "Build a slot at (x,y)" list (the M4-7c follow-up request
  from `DECISIONS.md`).
- **Placing inventory rooms** (`_rebuild_assembly_entries`): for every owned
  empty slot and every room currently in `layout.inventory`, Assembly adds a
  "place_room" entry. W/S cycles through all entries (buy-slot ghosts and
  place-room options together); Enter on a place-room entry calls
  `SaveData.place_room` — no validate/spend logic duplicated in the UI. A
  successful placement shows a confirmation note and rebuilds both the Shop
  and Assembly lists (inventory count drops, the slot becomes a placement).
  An illegal placement (e.g. would brick in a turret's firing face) shows the
  first violation message from `SaveData.place_room_violations` and changes
  nothing.
- **Mirrored wall-side toggle**: for rooms with a firing face (the Turret
  Room), pressing **A/D** while that entry is selected toggles a "(mirrored)"
  flag shown on the ghost cell; Enter places it with that orientation. Useful
  when the unmirrored side would point into the hull (refused) — mirroring it
  points the firing face outward instead.
- Test: `test_shop` gained 4 new backend cases (place a room happy path;
  refused when the firing face would be blocked, with violation message;
  refused without an owned slot; refused without inventory). `test_dock_shop_ui`
  gained an Assembly-tab case driving the full Shop→buy room→Assembly→buy
  slot→place room flow via `_assembly_key`. 26/26 suites green.
- **Commit:** `M4-8 step 2` (place inventory rooms into owned slots, mirrored
  toggle) — step 1 (hull blueprint + slot-buying ghost cells) was a prior
  commit this session.

### Milestone 4 — Module 8b: slot levels/pricing, tower spawn, Assembly 2D nav (DONE)
Three small steps from a single Snir request (2026-06-14), done sequentially:

- **Slot levels + pricing rework** (`SubLayout.level_of`, `GameFeel.dock.slot_price`):
  the conning tower's grid row is now **level 0** and can never have a slot —
  it stays the tower's row alone, forever. The row directly beneath it is
  level 1, the next level 2, etc. `buyable_slot_positions()` now excludes
  level <= 0. Slot price is now `slot_base_price + slots_owned * 1 + (level-1) * 2`
  — i.e. a level-1 slot costs `2 + slots_owned`, each level below that adds
  +2 scrap, and **every slot you've bought (any level) adds +1 scrap to the
  next slot's price**, on top of its level surcharge.
- **Firing-face edge rule** (`SubValidator` rule 8, part of the original
  request's #7): a room with a firing face (the Turret Room) must now sit at
  the far left or right edge of its level (the leftmost or rightmost occupied
  cell in its row) — placing it mid-row is refused with a violation message,
  same as a blocked firing face.
- **Crew start in the conning tower** (`Sub.tower_seat_local`, `world.gd`):
  both players now spawn standing in the conning tower (sections 2 and 4 of
  its floor) instead of the engine/middle rooms. `tower_seat_local(index)` has
  seats reserved for up to 4 players (sections 2, 4, 1, 5 — section 3 stays
  clear for the ladder).
- **Assembly tab: 2D arrow-key cursor + return-to-inventory**
  (`scripts/ui/dry_dock.gd`): replaced the old flat W/S entry list with a
  grid cursor (`_assembly_cursor`) over a cell->action map
  (`_assembly_actions`). Arrow keys (or WASD) move the cursor in the expected
  2D directions, but **only onto a cell that has an action** — buy a slot,
  place an inventory room into an owned empty slot, or pick a placed room
  back up into inventory. **M** toggles mirrored placement for firing-face
  rooms (previously A/D, now freed up for movement). Enter performs whichever
  action is valid at the cursor. New `SaveData.return_room_to_inventory(pos)`
  is the backend for the pick-up action.
- Test: `test_slots` gained `_test_levels` (level_of for the tower row, above
  it, and the rows beneath; every buyable position is level >= 1) and a
  rewritten price-escalation test covering both the owned-slots and level
  axes independently. `test_shop` gained `_test_return_room_to_inventory` and
  `_test_return_room_refused_for_core`. `test_dock_shop_ui`'s Assembly flow
  was rewritten for the cursor/action-map API (mirror is now `KEY_M`, slot
  selection/placement/return are all driven via `_assembly_cursor`). 26/26
  suites green.
- **Deferred (per Snir's call, 2026-06-14):** the rest of the original
  request's #6 (empty slots should be walkable rooms the crew can enter) and
  #7 (the Turret Room needs its own station + a working gun) stay parked for
  **M4-9/M4-10** as already planned — #6 needs `SubGeometry` to generate a
  real room-shell for a slot (not just hull + floor), and #7's
  station/gun is exactly M4-10's "first hand-built purchasable room with a
  real mechanic." The edge-placement *rule* for the turret (above) is done
  now; its station and gun are not.
- **Commits:** `Slot levels: tower's row is level 0 and never buyable, price
  scales with level + slots owned; firing-face rooms must sit at a level's
  edge`; `Spawn both players in the conning tower (tower_seat_local), not the
  engine/middle rooms`; `Assembly 2D nav rework: arrow-key cursor over
  buy/place/return actions`.

### Milestone 4 — Module 8c: marker reaches inert cells; relocatable helm (DONE)
Follow-up from playtesting Module 8b (2026-06-15):

- **The Assembly marker can now reach every cell**, not just ones with an
  action — including the conning tower, which previously blocked the cursor
  from passing through it and made some slots unreachable. Pressing Enter on
  an inert cell (the tower) simply does nothing.
- **The helm can be picked up and placed like any other room** — pick it up
  with Enter (it returns to inventory, its cell becomes an empty slot), then
  place it into any owned empty slot the same way a Turret Room would be.
  `SubValidator` no longer requires the helm to be placed (only the tower is
  truly fixed/never-in-inventory); a duplicate helm placement is still
  invalid.
- **The dry dock refuses to close while the helm is in inventory** — Tab and
  Esc from any tab show "The sub needs its helm placed before you can leave
  the dock." and stay open until it's placed somewhere again.
- Test: `test_validate` updated (missing-helm mid-edit now validates;
  duplicate-helm and tower-in-inventory are invalid). `test_shop` gained
  return/place-back coverage for the helm and a refusal test for the tower.
  `test_dock_shop_ui` covers the tower pass-through and the close-refusal/
  placed-back round trip. 26/26 suites green.
- **Commit:** `Assembly: marker can pass over inert cells (e.g. the tower);
  helm is relocatable but required before leaving the dock`.

### Milestone 4 — Module 8d: pick which inventory room to place (DONE)
Follow-up (2026-06-15): when a slot's "Place: ..." ghost has more than one
eligible inventory room (e.g. both the Turret Room and the relocated helm
fit the same empty slot), **Q/E cycle which one is shown** — the ghost label
gains a "(1/2, Q/E to change)" hint — and Enter/M (mirror) act on whichever
is currently picked. With only one eligible room the ghost behaves exactly
as before (no picker shown). The picker resets to the first option whenever
the cursor moves or the assembly list rebuilds.
Test: `test_dock_shop_ui` covers cycling forward with E and back with Q.
26/26 suites green. **Commit:** `Assembly: Q/E picks which inventory room to
place when a slot offers several`.

### Milestone 4 — Module 8e: interact/use key remap + slot price fix (DONE)
Two follow-ups (2026-06-15):
- **Key remap in the Assembly tab.** Every other station uses "interact" to
  do the main action and "use" for a secondary toggle (P1: E=interact,
  Q=use; P2: Right-Shift=interact, Enter=use). The dry dock's Assembly tab
  now matches: **interact (E / Right-Shift, plus Space/Numpad-Enter as
  convenience aliases) buys a slot, places a room, or returns a room to
  inventory** — whatever the cursor's action is. **Use (Q / Enter) cycles
  which inventory room would be placed**, when a slot offers more than one
  (the M4-8d picker). M (mirror) is unchanged. The on-screen hint and the
  "Place: ..." ghost label now say "Interact"/"Use" instead of naming raw
  keys.
- **Slot price bug fixed.** Slot prices were computed from
  `layout.slots.size()` — the count of *currently empty* owned slots. Moving
  a room out of a slot (into inventory) grew that count, and placing a room
  into a slot shrank it, so the price quoted for buying a *different* slot
  would drift up and down as the player reorganized rooms, even though
  nothing was bought or sold. Fixed by adding a new persistent counter,
  `SubLayout.total_slots_bought`, that only increases (in `SaveData.buy_slot`)
  and is saved/loaded with the rest of the layout. Slot prices now key off
  this cumulative count, so they only escalate with actual purchases.
Tests: `test_dock_shop_ui` updated for the new key bindings (interact = E,
use = Q/Enter for the picker); `test_shop` adds
`_test_slot_price_stable_across_place_and_return`. 26/26 suites green.
**Commit:** `Dry dock: remap Assembly to interact/use keys, fix slot price
drift on place/return`.

### Milestone 4 — Module 9a: floodlight pod purchase economy (DONE)
First slice of pods (2026-06-15, MODULAR_SUB_IMPLEMENTATION.md §6/§8): the
**floodlight pod** can now be bought into inventory from the Shop tab (same
"In inventory: N" listing as rooms, its own multi-resource cost), and
attached to / detached from an exterior face of an occupied hull cell via new
`SaveData.place_pod` / `place_pod_violations` / `return_pod_to_inventory`,
mirroring the room place/return economy but keyed by `(host_cell, face)`
instead of a grid position. `SubValidator` already enforced the pod-face
rules (exterior face only, one pod per face) — this just wires the economy up
to them. **Not yet in the Assembly tab** — there's no in-game way to pick a
face and attach a pod yet; that's M4-9b next, plus the pod's actual visual
(a "bump" on the hull) and its aim-seat station, which are separate
follow-ups.
Tests: `test_shop` adds buy/place/return-pod cases (happy path, refused on a
non-exterior face, refused without inventory/scrap); `test_dock_shop_ui`
confirms the floodlight pod appears in the Shop list. 26/26 suites green.
**Commit:** `M4-9a: floodlight pod purchase + attach/detach economy (Shop +
SaveData)`.

### M4 module order (corrected per `ROOM_SYSTEM.md` reconciliation, 2026-06-12)
`MILESTONE_4_v2.md`'s eleven modules are still the backbone, but three things
from `ROOM_SYSTEM.md` change the order and add a module. This list is the
current source of truth for M4 sequencing — supersedes the v2 numbering below:

1. **M4-1 / M4-1b** ✅ done — grid + layout data model (uniform cell, settled at
   5m after Checkpoint 1).
2. **M4-2** ✅ done — **slot economy** data model: buyable empty room-shells
   adjacent to the hull, escalating price separate from room prices. Gates
   everything below — a bought room has nowhere to go without a bought slot.
3. **M4-3** ✅ done — validation engine (`SubValidator.validate`, 7 rules + slot
   overlap, + `recover()` load fallback).
4. **M4-4** ✅ done — generated interiors + connections (`SubGeometry` compiler
   M4-4a, live sub swap M4-4b: rooms, auto-doors, auto ladders with floor-parity
   sides, the section-bake step).
5. **M4-5** ✅ folded into M4-4b — generated hull, water cells, breach surfaces,
   implosion on the new cell. _Minor polish still open: restrict breach surfaces
   to exterior faces; add an asymmetric-layout water-conservation test._
   - **⛳ CHECKPOINT 1** ✅ PLAYED (2026-06-13) — Snir tuned the geometry: 5m
     rooms / 1m sections, 0.9m ladders, halved ladder overhang, every in-room
     element snapped to its authored section.
6. **M4-6** ✅ done — save extension (scrap + carcass tiers + inventory + slots +
   layout, with the "invalid layout → inventory, nothing lost" recovery).
7. **M4-7** — dock shop: sells slots **and** rooms; multi-resource cost engine.
   - **M4-7a** ✅ done — buy slots (`SaveData.buy_slot`, escalating scrap).
   - **M4-7b** ✅ done — multi-resource wallet + buy rooms into inventory
     (`SaveData.buy_room`, `can_afford_cost`, `ModuleDef.cost_bundle`).
   - **M4-7c** ✅ done — the keyboard shop **UI** that calls the above.
8. **M4-8** ✅ done — assembly screen: places owned rooms into owned slots;
   left/right (mirrored) wall choice for rooms with a firing face. **Also
   folded in the M4-7c follow-up request:** buyable slot positions show as
   faint "+price" ghost cells on a diagram of the current hull (not a text
   list) — see `DECISIONS.md` (2026-06-13, M4-7c follow-up).
9. **M4-9** ⬅ **NEXT** — pods plumbing.
   - **⛳ CHECKPOINT 2** — Snir plays: buy a slot, buy a room, place it,
     rearrange.
10. **M4-10** — first hand-built purchasable room with a real mechanic (a
    weapon room, per `ROOM_SYSTEM.md` §6) — the reference implementation for
    the add-room skill. **Also adds the `ModuleDef` fields for the M4-7c
    follow-up request:** a short `description` and an `icon`/`kind` (weapon,
    arm, storage, ...), plus a Shop-tab inventory sidebar — see `DECISIONS.md`
    (2026-06-13, M4-7c follow-up).
11. **M4-11** — build the `add-deeper-room` skill (per
    `SKILL_STUB_add_room.md`), validated by re-deriving the M4-10 room from it.
12. **M4-12** — second content room, built using the skill (e.g. the
    floodlight pod or another `ROOM_SYSTEM.md` §6 room).
13. **M4-13** — close-out: full suite, STATUS/DECISIONS updates, push.

### Milestone 3 — Module E: wrecks + salvage placement + fish guards (closes M3)
- A `Wreck` (scripts/salvage/wreck.gd): a placeholder ~4m broken-hull shape,
  static on the seafloor. **One torpedo hit cracks it open** (pop puff, hull
  swaps to its "open" look with a jagged hole) and **spills 2-3 scrap
  crates** that settle nearby — same `SalvageItem.make_scrap`, claw-catchable
  like any other loose salvage. New `WRECK` collision layer
  (`collision_layers.gd`); placeholder colors in `placeholder_art.gd`.
- **Two wrecks placed** (`shore_shelf.gd`): one on the **shallows plateau**
  (unguarded — "easy money"), one on the **basin floor near the second
  pillar** (guarded by a fish).
- **Cave treasure cluster grown** to 3 loose scrap items (was 1) — the cave
  lamp's haul is now the best one in the map.
- **Fish guards expanded from 3 to 5**: cave mouth, the cave treasure
  cluster, both basin pillars (one now also guards the basin wreck), and the
  third pillar. Still the same `fish.gd`, just more placements.
- **`reset_run()` reseals wrecks**: `Wreck.reset_wreck()` (called on the new
  "wreck" group) reseals the hull and frees whatever it spilled, so a wreck
  you cracked before an implosion is crackable again after the reset —
  matching "respawn wrecks at home position" from the M3 brief.
- Test: `test_wreck` (a fresh wreck starts sealed; one torpedo hit cracks it
  and spills 2-3 salvage items; `reset_wreck()` reseals and clears spilled
  loot; an already-open wreck ignores further hits).
- **This closes Milestone 3** (Modules A-E all done; cage/hatch from the
  original Module D brief were superseded by the claw rework's visible-cage +
  carry-ferry design, which already shipped). M4 (grid/layout) is also already
  underway — see Module 1 below.

### Milestone 4 — Module 1: grid + layout data model
- New plain-data layer for the grid-based modular sub, per
  `MODULAR_SUB_IMPLEMENTATION.md` §2-3. **No gameplay code changed** — the
  current hand-built sub still runs exactly as before.
- `SubGrid` (scripts/sub/grid.gd): the cell size (2.5m x 3.0m = 120x144px at
  the locked 1m=48px scale) and the `MAX_CELLS` (8x5) bounds guard.
- `ModuleDef` (scripts/sub/module_def.gd) + `ModuleCatalog`
  (scripts/sub/module_catalog.gd): one entry per module *type* — `helm`,
  `tower` (both core), `room` (generic, used for the middle room), `engine`,
  `claw_room`, `storage`, plus placeholder entries for the M4 content modules
  `turret_room` (flags a firing face) and `floodlight_pod` (flagged as a pod).
- `SubLayout` (scripts/sub/sub_layout.gd): placements (module id + grid pos +
  mirror flag), pods (pod id + host cell + face), and an inventory dict, with
  `to_dict()`/`from_dict()` round-tripping for the save file (Module 5).
  `SubLayout.starting_layout()` expresses "the Minnow+" (§2.1) — the M3 sub
  re-expressed on the grid: engine/middle/helm in a row, tower above the
  middle room, claw room below the middle, storage below the engine.
- Test: `test_layout` (grid constants, catalog contents/footprints, the
  starting layout's shape and bounds, full serialization round-trip).
- Next (Module 2): `validate(layout)` — the single legality function (7
  rules from §5), pure and headless-testable, no UI yet.

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
  - `sub/` (M4, data-only so far) — `grid.gd` (**SubGrid**: cell size + bounds guard), `module_def.gd` (**ModuleDef**), `module_catalog.gd` (**ModuleCatalog**: catalog of module types), `sub_layout.gd` (**SubLayout**: placements/pods/inventory + serialization + starting layout).
  - `weapons/` — `torpedo.gd` (slow straight shot, trail, terrain puff; inner `Puff` class).
  - `fauna/` — `fish.gd` (**territorial: patrol/chase/bite/return, torpedo kill, reset_fish**, **death spawns a sinking salvage carcass**).
  - `salvage/` — `salvage_item.gd` (**SalvageItem**: scrap crate / fish carcass pickup, sinking + settling for carcasses; in group "salvage" for the claw), `wreck.gd` (**Wreck**: torpedo-cracked hull spilling 2-3 scrap crates; group "wreck", `reset_wreck()` reseals + clears loot).
  - `ui/` — `depth_hud.gd`, `alert_hud.gd` (**breach screen-edge flash**), `salvage_hud.gd` (on-board vs. banked totals), **`dry_dock.gd`** (DryDock: upgrade screen + sub-design placement view).
  - `util/` — `grid_background.gd`.
- `scenes/`
  - `world.tscn`/`.gd` — **main scene**: map + crewed sub (built from loadout) + 3 fish + camera + HUDs + implosion/run reset + dock banking + **dock prompt / Tab opens the dry dock / sub rebuild on purchase**.
  - `shore_shelf.gd` — the map (terrain/water/sky + **cave lamp marker** + **scattered scrap pickups**).
  - `sub_test.tscn`, `sandbox.tscn` — M1 sandboxes (no water/buoyancy).
- `tests/` — 25 headless suites, all passing: `test_input`, `test_crew`, `test_sub`,
  `test_helm`, `test_world`, `test_water`, `test_station_flood`, `test_damage`,
  `test_repair`, `test_drowning`, `test_implosion`, `test_turret`, `test_fish`,
  `test_lower_deck` (Module A), `test_salvage` (Module B storage/bank/save),
  **`test_claw`** (Module C grab/deposit + no-auto-collect regression),
  **`test_loadout`** (Module D buying/saving, engine + repair mults, gun room
  → 7 rooms / 2 turrets / flooding doorway), **`test_dry_dock`** (Module D
  navigation + placement flow + pause/unpause), **`test_wreck`** (Module E:
  torpedo cracks a wreck for 2-3 salvage, reset reseals + clears loot),
  **`test_layout`** (M4 Module 1/1b: grid constants, catalog, footprints,
  starting layout, serialization), **`test_slots`** (M4 Module 2: buyable
  slot positions, hull adjacency, bounds guard, price escalation,
  serialization), **`test_validate`** (M4 Module 3: validate()'s 7 rules +
  slot overlap, and the load-recovery path), **`test_geometry`** (M4 Module 4a:
  the layout→geometry compiler — room rects, doorways, parity ladders, section
  baking), **`test_save_layout`** (M4 Module 6: layout/slots/inventory
  persistence, legacy-save upgrade, invalid-layout load recovery).
  Plus `capture_*` — throwaway windowed screenshot tools (png gitignored;
  `capture_m2` stages the full M2 tableau). They hang under `--headless`
  (no `quit()` — they're meant to be run and screenshotted, not asserted)
  and are excluded from the suite count/run.

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

## Suggested next step — M4-9: pods plumbing
M4-7c (Shop tab), M4-8 (Assembly tab), and M4-8b (slot levels/pricing, tower
spawn, Assembly 2D nav + return-to-inventory) are all done — see Module 8 and
8b above. Next: **M4-9** (pods plumbing — exterior pods that clip to a hull
face, e.g. the floodlight pod), then **⛳ Checkpoint 2** (Snir plays: buy a
slot, buy a room, place it, rearrange, pick it back up). Minor open items:
**M4-5 polish** (breach surfaces → exterior faces only; an asymmetric-layout
water-conservation test); **M4-9/M4-10** also carry the parked ideas from
M4-8b (walkable empty slots; Turret Room station + gun).

## Verify by playing — M4-8b (slot levels/pricing, tower spawn, Assembly nav)
Launch: `"D:\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe" --path .`

1. **Both crew now start standing in the conning tower** (the top room),
   side by side, instead of in the rooms below.
2. Drive to the **dock** and press **Tab** to open the dry dock, then **Tab**
   again twice to reach the **Assembly** tab (hull diagram with ghost cells).
3. **Arrow keys** move a highlighted marker around the hull — it will only
   land on cells that do something: a ghost "buy slot" cell, an empty slot
   you can place a room into, or a placed room you can pick back up. It
   cannot wander onto blank background or off the edge of the buildable area.
4. Notice the **prices on the ghost cells directly under the tower's row are
   gone** — slots can no longer be bought there, only on rows below. Prices on
   lower rows should be **higher than before** and increase further down.
5. Buy a slot (**Enter** on a ghost cell) — the price you paid should match
   what's shown, and the *next* slot's price (on any row) should be 1 scrap
   higher than before.
6. If you have a Turret Room in inventory, move the marker onto the new empty
   slot — you'll see "Place: Turret Room". **M** toggles "(mirrored)" if shown.
   Press **Enter** to place it. If the level has more than one empty cell, try
   placing it in the middle — it should be **refused** ("must sit at the far
   left or right edge of its level") even if its firing face would otherwise
   be clear.
7. Move the marker onto a **placed room** (not the helm/tower) and press
   **Enter** — it should pop back into inventory, and that cell becomes an
   empty slot again (marker still highlights it, now offering "Place:" again).
8. Press **Esc** to close the dock — the hull updates to match.

### Watch out for (traps that already bit this milestone)
- **`class_name` cache:** after adding a new `class_name` script, run
  `"GODOT_PATH" --headless --path . --import` once or headless runs fail with
  "Could not resolve class".
- **Vacuous async tests:** a few suites (e.g. `test_water`) call their
  `await`-ing sub-tests from `_ready` *without* `await`, so they quit before the
  assertions run and pass *vacuously* (tell-tale: "ObjectDB instances leaked at
  exit"). Don't trust those as coverage; if you touch their area, make `_ready`
  actually `await`. The keyed-input / menu tests (`test_dry_dock`, `test_helm`,
  `test_sub`, …) DO await and are real.
- **Test coordinates from constants, not literals:** the cell width has changed
  twice via playtest. Tests derive room positions from `SubGrid.CELL_W_PX` etc.
  so a future tweak doesn't break them — keep doing that.
- **The gun room is parked until ~M4-10** (placeable turret room). The current
  weapon is the M2 base bow gun. `validate()` rule 5 already forces a turret
  room's firing face to be exterior, so it can only ever go on an outer edge.
- **Snir must push to GitHub** — there is no git auth in this environment. Commit
  locally per step; remind him to push.

## Verify by playing — Checkpoint 1 (the generated sub)
Launch: `"D:\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe" --path .`
(or open the project in Godot and press Play.)

The sub should look and play almost exactly like the M3 sub, with these
*intended* differences to eyeball:
1. **Rooms are wider** (5m vs 2.5m, settled after trying 3.75m/7.5m) — drive
   around, ram some terrain. Heavy-but-controllable? Frames well on camera?
2. **The lower deck (claw room + storage) is now full height** (3m, was squat
   2.5m) — climb down there; headroom should feel normal, not cramped.
3. **The conning tower is now a full-size room** on top (was a small nook) —
   climb up into it; it should feel like a proper room.
4. **Ladders sit a little inward from the walls** — climb every ladder (tower
   ↔ middle, middle ↔ claw, engine ↔ storage). You should be able to climb up
   and down cleanly and step off into the doorways without snagging.
5. Everything else from M3 should still work: drive, breach/flood/repair, drown
   + respawn (you reappear up in the tower), implode + reset, the claw
   grab→drop→carry→stow loop, banking at the dock, and the dry dock menu
   (engine boost / repair training still buy; the "second gun" option is
   parked — buying it does nothing visible until a later milestone).

Report anything that feels *worse* than M3 (room size, climbing, camera, heft),
or any spot where the crew gets stuck.

_(The independent **M3 close-out** playtest — wrecks + bigger fish roster — is
also still available; ask for steps if you want it.)_

Open questions for Snir (M3 close-out): is a wreck satisfying to crack open
with a torpedo? Does the unguarded shallows wreck feel like a fair "easy
money" tutorial vs. the guarded basin one? Are 5 fish too many / well placed?
Plus the standing claw/ferry questions: does the two-joint excavator control
feel good? Is the claw→drop→carry→stow ferry fun co-op or too many steps
solo? Are pickup/deposit ranges and cage 2 / storage 8 right?

## Verify by playing — Module E (wrecks + fish guards)
1. Launch: `"GODOT_PATH" --path .`
2. **Easy money:** drive over the **shallows plateau** (near the shore) and
   fire a torpedo into the broken hull shape sitting there — it cracks open
   with a puff and spills a couple of scrap crates onto the seafloor. No fish
   guard it.
3. **Claw them up** as usual (see the claw verify-by-playing below) and ferry
   them to storage.
4. **Guarded wreck:** head into the basin near the **second pillar** — a fish
   now guards a second wreck there. Deal with the fish (or dodge it), crack
   the wreck the same way.
5. **Cave haul:** the cave now has **3** loose scrap items near the lamp,
   guarded by its own fish.
6. **Reset check:** crack a wreck, then let the sub implode (or take heavy
   damage on purpose) to trigger `reset_run()`. Back at the dock, return to
   the cracked wreck — it should be **sealed again** and crackable once more.

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
