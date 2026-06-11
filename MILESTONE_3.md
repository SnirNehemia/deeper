# MILESTONE_3.md — Salvage Run (Lower Deck, Claw, and the First Save)

*Brief for Claude Code. Read CLAUDE.md first (developer context, build discipline, git rules), then STATUS.md (architecture & extension notes — stations, per-room water, GameFeel, layers) and DECISIONS.md. This is a feature-sized chunk: decompose into internal steps, headless-check after each, commit per working step.*

## Goal
The run gains a *reason*: salvage. The sub grows a **lower deck** with two new rooms — a **claw room** (belly-mounted grabber arm, a new third station) and a **storage room** (where loot is secured). Crew claw items off the seafloor and out of cracked-open wrecks, haul them through the sub by hand, rack them in storage, and **dock at the surface to bank them** — the only way to keep anything. Implosion loses everything not yet banked. Banked scrap **persists between sessions** (first save file). There is **no win condition yet**: the eventual win is salvaging 4 unique relics (later milestone); for now the loop is collect → survive the trip home → bank → go again.

This milestone exists to answer: *does hauling treasure home under threat create the push-your-luck tension the design banks on?*

All new numbers are **starting values** in `GameFeel` (extend the autoload). Expect heavy tuning.

## Settled design points driving this brief (append to DECISIONS.md at close-out)
- Win condition deferred: ultimate win = 4 unique relics (post-M3). M3 is collect-and-bank only.
- Salvage sources: loose seafloor/cave items **and** breakable wrecks (torpedo to open).
- Implosion loses all salvage not banked at the dock (no 50% mercy yet — revisit with checkpoint buoys later).
- Banked total persists between runs and sessions; no spending yet (dry dock arrives later).
- New rooms: claw room **below the middle room**, storage room **below the engine room**. Claw arm hangs from the sub's belly.
- Players start with all stations for now; rooms/stations as purchasable upgrades come later.
- Claw is **variant 1: two-joint rigid arm** (see §4). Variant 2 (telescopic fold-in arm) is built **only if v1 disappoints in playtest** — do not build it now.
- More of the **same fish**, repositioned/added to guard salvage spots. No new threat types.
- Unstored items inside the sub are **loose physics props**: they slide with pitch tilt and float/drift when a room floods. Only racked items are secure.

## Spec

### 1. Lower deck (sub expansion)
- Two new interior rooms under the existing row, same 1m=48px scale (suggested 5m × 2.5m each, slightly squatter than the main deck — designer eyeball is fine, keep them readable):
  - **Claw room** directly below the **middle room**, connected by a ladder through a floor opening.
  - **Storage room** directly below the **engine room**, connected by a ladder from the engine room. Claw room ↔ storage room connected by a normal doorway with the standard door step (`DOOR_STEP_H`).
- Hull silhouette extends downward to wrap the new deck; hull polygon collider updated to match. The conning tower remains the high point (and respawn spot).
- **Water model grows to 6 cells.** The new rooms join the per-room water system with the standard door sill (`door_sill_m`) between them and a sill at each ladder floor-opening (use the existing ladder-opening sill logic; the floor openings should let water *fall down* freely into the lower deck but require the lower room to be full past the opening before it pushes up — bottom deck floods first, drains last. That's intended drama, keep it).
- Breaches can spawn in the new rooms like any other (nearest-room rule unchanged). Stations there inherit the flood eject/refuse rule from the `Station` base automatically.
- Implosion threshold stays a fraction of **total** combined volume — re-check the 70% number still feels right with 6 cells (it's one `GameFeel` value).

### 2. Salvage items
- A `SalvageItem`: placeholder chunky crate/ingot shape, ~0.6m, labeled, worth a `scrap_value` (default 1; make a rarer "heavy" variant worth 3 that's visibly bigger). World-space `RigidBody2D` when outside the sub (sinks slowly, rests on terrain).
- New collision layer `SALVAGE` in `collision_layers.gd` (named, no magic numbers).
- **Inside the sub**, an item becomes an interior physics prop in the sub's local space: it slides with the cosmetic pitch tilt, can be nudged by crew, and **floats on a room's water surface** — flooding can carry loot around (and toward an open cage hatch). If physics props inside the moving sub fight back hard, fall back to: items are static where dropped but float straight up with the water level. Try the fun version first.
- **Crew carrying:** stand at an item and press `use` to pick it up (carried above the head, slight run-speed penalty ~15%, jump unaffected); press `use` again to drop. One item per crew. Carrying blocks repairing (the `use` key is busy — that's a real tradeoff, keep it). A carried item is dropped automatically if the carrier drowns.

### 3. Storage room & banking
- A **storage rack** zone in the storage room: carry an item into the zone and press `use` → the item snaps into a rack slot, becomes secured (no physics, can't float away). Press `use` at a racked item to take it back out. Suggested 6 slots, visible filled/empty.
- **Banking:** when the sub is floating in the **dock zone** at the surface (define a generous zone around the spawn dock), all racked items convert to banked scrap — small flash + counter tick per item. Unracked items do not bank; the crew has to finish the job.
- **Persistence:** banked scrap total saved to disk immediately on banking (one `ConfigFile`/JSON in `user://`, meta only per design doc §11.4). Loads on launch. Survives implosion, quitting, everything.
- **Implosion / reset:** `reset_run()` clears all unbanked salvage (carried, loose, racked-but-not-banked, and anything still in the claw), respawns world salvage and wrecks at their home positions, and leaves banked scrap untouched.
- **HUD:** add a small scrap counter (top corner): `banked + (carried-this-run)`, e.g. `12 ⛁ +3`. Keep it minimal; the racked items are visible in-world through the cutaway.

### 4. Claw station (variant 1: two-joint arm)
- `ClawStation` subclassing `Station`, seat in the **claw room**. The arm itself hangs from a mount on the **sub's belly**, outside the hull, below the claw room.
- **Arm:** two rigid segments (suggested 2m + 2m), two joints:
  - **A/D** rotates the shoulder joint (mount), **W/S** rotates the elbow joint. Both sweep continuously at an `arm_speed_deg` (`GameFeel.claw`) and hold their angle, same feel language as the turret. Clamp each joint to a sane range so the arm can't clip up through the hull (suggested shoulder ±100° from straight-down, elbow ±120°).
  - **`use` (Q / Enter)** toggles the claw open/closed. Closing while the claw tip overlaps a `SalvageItem` grips it (item parents to the claw tip). Opening releases it wherever it is.
- The arm is placeholder segments + a jaw shape; it tilts with the hull like the turret barrel (children of the hull visual / same fix as playtest #1 §8). The arm does **not** collide with terrain in M3 (ghost through rock; only the claw tip senses items) — arm-vs-terrain physics is parked, don't build it.
- **Getting loot inside — the cage & hatch:**
  - The claw room floor has a **cage**: a stair-stepped basket recessed into the sub's belly, open to the sea from below/outside, with a **manual hatch** in the claw-room floor above it.
  - The claw operator drops a gripped item **into the cage** from outside (release over the cage mouth; the cage catches and holds items — suggested capacity 2).
  - A crew member stands at the hatch and presses `interact` to open/close it. While open: items in the cage can be picked up (`use`) from the room above; **and the cage opening is a water path** — if the cage holds water-line-submerged sea and the hatch is open, the claw room takes water (treat an open hatch below the waterline as a small fixed-rate leak into the claw room, `GameFeel.claw.open_hatch_leak`). Closed hatch = sealed. This makes "shut the hatch!" a job.
- Co-op shape this creates (don't smooth it away): one player aims/grips outside, one player works the hatch and hauls items to storage. Solo is possible but slow — that's consistent with the pillars.
- **Variant 2 (do NOT build now):** telescopic arm that grips and folds the item directly inside. Build only if the playtest verdict on v1 is negative; keep the station interface clean enough that swapping the arm mechanism is contained.

### 5. Wrecks
- A `Wreck`: placeholder broken-hull shape (~4m), placed on terrain. Static, hittable by torpedoes (uses the FISH-style hit path or its own layer; named layer either way).
- **One torpedo hit cracks it open**: pop/debris puff, the wreck swaps to an "open" sprite, and it spills **2–3 SalvageItems** that settle nearby. Wrecks don't damage the sub and don't respawn within a run; `reset_run()` restores them.
- Place 2–3 wrecks: one on the shallows plateau (tutorial-grade, no fish), one or two in the basin near pillars/cave (guarded).

### 6. Salvage placement & fish guards
- Loose items: a few singles scattered on the basin floor, plus a small cluster **inside the cave** (the lamp's treasure — the old victory beat becomes the best haul).
- Add **2–3 more of the same fish** (total 5–6), repositioned so every worthwhile salvage spot is inside or near a territory; the shallows wreck stays free. Reuse `fish.gd` untouched if possible; territories and homes are placement data.

### 7. Out of scope guardrails for this milestone
The claw arm has scope-gravity. If any of these tempt: stop. No arm-vs-terrain collision, no winch/cable physics, no item damage, no relics, no spending/dry dock UI, no checkpoint buoys, no new enemy behaviors, no map changes beyond placements, no Krita pipeline (that's M4), no variant-2 arm, no sounds, no real art.

## Build plan — strict module order
Each module: headless test green → full suite green → commit. Never start the next on a broken state. The lower deck (A) is the spine; salvage/carry (B) and the claw (C–D) hang off it; wrecks and placement (E) are content; close-out (F) integrates.

### Module A — Lower deck + 6-cell water
- New rooms, ladders, door step, hull silhouette + collider extension; water model to 6 cells with floor-opening flow (down freely, up only past full); stations-in-flood inherited.
- **Test:** `tests/test_lower_deck.tscn` — room connectivity, water falls down/pools, fills bottom-first; extend `test_water` expectations. Re-verify implosion threshold math with 6 cells in `test_implosion`. **Commit:** `lower deck + 6-cell water`.

### Module B — Salvage items, carry, storage, banking, save
- `SalvageItem` (world + interior prop behavior), crew carry/drop, storage rack, dock-zone banking, `user://` save (load on boot, write on bank), HUD counter, `reset_run()` clears unbanked + respawns world salvage.
- **Test:** `tests/test_salvage.tscn` — pickup/drop, rack snap, bank converts + persists (write/read the file headlessly), reset clears unbanked. **Commit:** `salvage + storage + banking + save`.

### Module C — Claw station + arm
- `ClawStation` seat, two-joint arm (sweep/hold/clamps, tilts with hull), claw open/close grip on `SalvageItem`s, `GameFeel.claw` block, `SALVAGE` layer.
- **Test:** `tests/test_claw.tscn` — enter/exit, joint clamping, grip/release parenting, flood eject inherited. **Commit:** `claw station + arm`.

### Module D — Cage + manual hatch
- Cage geometry (catches dropped items, capacity), hatch open/close via `interact`, pickup-through-open-hatch, open-hatch-underwater leak into the claw room.
- **Test:** `tests/test_cage.tscn` — item dropped into cage stays, hatch gates pickup, open submerged hatch leaks / closed doesn't. **Commit:** `cage + hatch`.

### Module E — Wrecks + placement + fish guards
- `Wreck` (torpedo-cracked, spills items), place wrecks + loose items + cave cluster, add/reposition fish, wire wrecks + salvage into `reset_run()`.
- **Test:** `tests/test_wreck.tscn` — torpedo opens, items spawn, reset restores. **Commit:** `wrecks + salvage placement`.

### Module F — Integration & close-out
- Full suite + all M1/M2 tests green; manual regression (movement, helm, turret, repair, drown, implode — now with 6 rooms).
- Update STATUS.md, append decisions to DECISIONS.md, write Snir's verify-by-playing, commit + push.

## Acceptance criteria
- [ ] The sub has a lower deck (claw + storage rooms) reachable by ladders; water floods it first and drains it last; breaches/stations/door steps all behave there.
- [ ] Crew can pick up, carry (one each, slight slowdown, can't repair while carrying), drop, rack, and un-rack salvage items.
- [ ] Loose items inside the sub slide with tilt and float on flood water; racked items don't.
- [ ] Floating the sub in the dock zone banks racked items only; banked scrap shows on the HUD and **persists across a full quit-and-relaunch**.
- [ ] Implosion (and any `reset_run()`) wipes all unbanked salvage and restores world salvage/wrecks/fish; banked scrap survives.
- [ ] A third crew station: the claw — A/D and W/S sweep the two joints continuously with hold, `use` grips/releases; arm tilts with the hull; gripped items can be dropped into the belly cage.
- [ ] The cage hatch opens/closes with `interact`; items are only retrievable when open; an open hatch below the waterline leaks water into the claw room.
- [ ] One torpedo cracks a wreck open and spills 2–3 items; wrecks restore on reset.
- [ ] 5–6 fish guard the salvage spots; the shallows wreck is safely lootable.
- [ ] All M1 + M2 acceptance criteria still pass; full headless suite green including the five new tests.

## Verify by playing (for Snir)
1. Launch: `"GODOT_PATH" --path .`
2. **Tour the lower deck:** climb down from the middle room to the claw room, through the doorway (hop the step) to storage, up the ladder to the engine room. Take a hit down there and watch the bottom deck flood first.
3. **Easy money:** drive over the shallows wreck, torpedo it open, then sit the claw (claw room, E / R-Shift). A/D swings the shoulder, W/S the elbow, Q closes the jaw on an item. Drop it in the belly cage, have the other player open the floor hatch (E), grab it (Q), carry it to storage, rack it (Q).
4. **Hatch panic:** leave the hatch open while submerged — the claw room should start taking water until someone shuts it.
5. **Bank it:** surface at the dock — racked items flash into the scrap counter. Quit the game completely, relaunch: the number is still there.
6. **Lose it:** grab loot from the basin (fish should now be guarding it), then let the sub implode on purpose. Everything you hadn't banked is gone; the banked number isn't.
7. **The real run:** fight past the cave fish, claw the cave cluster, and make it home heavy and leaking. Then report the *feel*: Is the claw fun or fiddly? Is hauling items by hand a good job or a chore? Does losing unbanked loot sting right? Is the hatch leak readable? → PLAYTEST_LOG.md.
