# MILESTONE_7.md — Hands on the Deep (The Telescopic Arm, a Leaner Base Sub, and a Reason to Reach)

## Progress so far (updated 2026-06-21)

**All four planned modules (M7-0 through M7-3) are done, plus a 7-item polish pass. Full headless suite green except a pre-existing, unrelated `test_claw` failure.** See `STATUS.md` for the up-to-date file-level changelog; this section is the milestone-level summary.

- **M7-0 — add-deeper-room skill promoted.** `.claude/skills/add-deeper-room/SKILL.md` is the real, code-verified skill (the root stub is gone). It was used to build the telescope room (M7-2) as its validation pass.
- **M7-1 — engine room retired; base sub slimmed.** `ModuleCatalog` no longer has an `engine` entry. `SubLoadout.engine_boost`/`ENGINE_BOOST_MULT` are gone; `move_mult()` always returns 1.0. `SubValidator.validate()`/`recover()` now flag and silently drop placements with an unknown module id, so an old 7-room save loads cleanly (engine dropped, rest recovered). Starting layout dropped to 4 rooms.
- **M7-2 — the telescope arm room.** New `telescope_room` (`TelescopeStation`, `scripts/stations/telescope_station.gd`): a single straight arm, aim/extend/retract, **Q** grabs salvage, auto-deposits into its own two onboard cages (s2+s4, capacity 6 each) when the arm returns home. `tests/test_telescope.tscn` covers aim clamping, extend/retract limits, grab, auto-deposit, full-cage refusal, reset on implosion.
- **M7-3 — telescope is the base collector; claw demoted to a buyable alt.** `SubLayout.starting_layout()` is now **telescope_room(-1,0,"left") + helm(0,0) + bullet_room(1,0,"right") + tower(0,-1)** — 4 rooms, no engine, no dedicated claw/storage room. `claw_room` is now purchasable (5 sc) through the normal shop/assembly flow, unchanged mechanically from M3 (two-joint excavator, own pen, foot-ferry).
- **M7-3 polish (7 items, same session as M7-3):**
  1. **Reserved zone** — the cell in the telescope's facing direction is reserved (`SubLayout.reserved_cell_types()` + `SubValidator` rule 10), so a room can never be placed in the arm's reach path. Same mechanism guns/claw/floodlight already use.
  2. **Face-relative controls** — `telescope_station.gd` now uses the shared `Station.face_aim_input`/`face_zoom_input` helpers (same pattern as the floodlight), so the arm's controls read correctly regardless of which wall it's mounted on.
  3. **Chelae indicator** — the arm tip draws open pincer lines when idle (waiting for **Q**) and closed prongs when carrying a catch, replacing the old static jaw line.
  4. **Both-player shop keys** — the dry dock's shop and assembly screens now respond to either player's interact/use keys (P1: E/Q, P2: `/`/`.`); mode-switch moved to **Tab** (freeing **Q** up as a P1 buy key). Fixed several stale `KEY_SHIFT` references left over from the pre-M6 P2 keybind change.
  5. **Auto-retract** — releasing the extend/retract key lets the arm slowly return home on its own (`GameFeel.telescope.auto_retract_speed`).
  6. **Faster auto-retract while carrying** — a caught item pulls the arm home noticeably faster (`auto_retract_speed_carrying`), so a catch doesn't sit exposed in open water.
  7. **Skill update** — `add-deeper-room/SKILL.md` now explicitly documents the face-relative control API and the exterior-element reserved-cell pattern, so the next outside-mounted room (gun, sensor, arm) doesn't have to rediscover them by reading the floodlight/claw/telescope source.
- **Known issue (pre-existing, unrelated):** `test_claw.tscn` fails one check ("the dropped catch is loose again on the floor") — confirmed present before any M7 work (checked via `git stash`), not a regression from this milestone.

**Next step:** Snir playtest of the full M7 slice per "Verify by playing" below, then tune `GameFeel.telescope` from feedback. `MILESTONE_8` (or further M7 follow-ups) to be planned after that.

---

*Brief for Claude Code. Read CLAUDE.md first (developer context, build discipline, git rules), then STATUS.md (architecture & extension notes — stations, per-room water, GameFeel, the SubLayout → SubGeometry → Sub pipeline, claw/salvage state machine), then DECISIONS.md, then ROOM_SYSTEM.md (room/section/ladder/economy canon — §2 sections, §3 ladder parity, §4 economy, §5 upgrades) and MODULAR_SUB_IMPLEMENTATION.md §4–5 (pipeline, validation). This is a tight, feature-sized chunk: decompose into the modules below in order, headless-check after each, full suite green before the next, commit per working step. If anything in this brief conflicts with code reality, stop and surface it in design terms — do not improvise a different architecture.*

## Goal
The submarine gets a **second, contrasting way to harvest the deep** — a **telescopic arm room** that aims, extends straight out, snags salvage on command, and **auto-deposits into its own onboard cages when it retracts**. Where the M3 claw is a fiddly two-joint excavator you operate by hand and then ferry the haul across the sub by foot, the telescope is a clean point-extend-grab-retract loop a single player can run solo. Shipping the telescope is also the moment we **slim the base sub down to its essentials** — the starting hull becomes **telescope + control + bullet, with the conning tower above** — and **retire the engine room** (its job folds permanently into the control room). The dedicated storage room leaves the base loadout too: early salvage now lives wherever it was collected (telescope cages, or the claw's own small pen once you buy a claw), and a real storage room returns only as a later purchase.

This milestone answers: *does a clean, solo-runnable collector make the salvage loop feel good from the very first dive — and does a leaner base sub read better than the old six-room Minnow+?*

All new numbers are **starting values** in `GameFeel` (extend the autoload). Expect heavy tuning — wire every constant through `GameFeel`, nothing hardcoded in logic.

> **Canon supersession — read before building (important):** `ROOM_SYSTEM.md` §6
> already lists a **"Claw telescope room"** as a `[-]` starting room with a
> *different* mechanic: up/down to extend/fold, right/left to rotate, `use` to
> close the claw, capacity 4 **on the claw itself**, no aim arc, no onboard cages.
> **This milestone supersedes that §6 entry.** The M7 telescope is: **A/D aim, S
> extend, W retract, Q grab, ~8 m reach, two onboard cages (s2+s4, capacity 6
> each), auto-deposit on retract.** When you close out M7, **rewrite the §6
> "Claw telescope room" entry to match this milestone** (and note the supersession
> in DECISIONS.md). Do not build both — the M7 spec below is authoritative.

> **Cell-width reminder (don't re-derive):** the cell is **5 m wide = 5 × 1 m
> sections** (`ROOM_SYSTEM.md` §2, settled at Checkpoint 1). Section x-offsets and the arm's home
> geometry are in that coordinate system. The ~8 m telescope reach is measured from
> the keel base **out into open water**, not in section units — it is several cells
> long, the room's defining "long reach."

## The core idea (read this first — it frames every module)
Settled with Snir 2026-06-20. Two threads, deliberately kept small:

1. **The telescope is the new default collector; the claw is demoted to a buyable alternate.** The base sub ships with the telescope. The two-joint claw still exists in code and in the world — it just becomes a **purchasable room** instead of base equipment. We are **re-homing the claw, not deleting it.**
2. **Salvage storage is now per-collector, not a shared room.** The telescope auto-deposits into **its own two cages** on retract; the claw (when bought) keeps **its own small built-in pen** (the M3 storage-pen mechanic, moved into the claw room). The standalone storage room is **gone from the base** and returns later as its own purchasable room when capacity becomes a real constraint. **The push-your-luck rule is unchanged: cage/pen contents are lost on implosion until the sub banks at the dock.** Telescope salvage is *not* "instantly safe" — it is secured exactly like claw salvage, by docking.

The contrast between the two collectors is the point:

| | **Telescope (base)** | **Claw (buyable alt)** |
|---|---|---|
| Control | Aim A/D, extend S, retract W, grab Q | Two-joint excavator (L/R shoulder, U/D elbow) |
| Reach | **Long, straight (~8m)** | Short, swings wide |
| Storage | **Auto-deposits to its own 2 cages on retract** | Crew ferries the catch by foot to its pen |
| Feel | Clean, solo-runnable | Fiddly, two-player-friendly |
| Securing salvage | Bank at dock (lost on implosion otherwise) | Bank at dock (lost on implosion otherwise) |

## Scope discipline (read before building)
This is a **tight slice**. Hard guardrails:
- **One new room only: the telescope room.** No other new rooms, stations, or weapons.
- **Do not delete the claw.** It becomes a buyable room via the existing shop/assembly + add-room path. Its mechanic, its arm, its pen, and its `SalvageItem` ferry states are all preserved.
- **No new salvage types, no new fauna, no new map work.** The telescope grabs the *exact same* `SalvageItem`s the claw does (scrap, small/medium carcasses), on the existing map.
- **No auto-collect-on-contact.** The arm **does not** vacuum salvage on touch. Grab is the explicit **Q** press, as the original telescope brief specified (DECISIONS.md: "Q picks up"). "Auto" refers only to the **deposit-into-its-own-cages on retract** step — not to grabbing.
- **No banking-on-retract.** Retract deposits into the room's onboard cages; it does **not** bank to the save file. Banking is still "dock at the surface," unchanged.
- **No upgrade-tree work.** Engine Boost is being *removed* (see below), not re-homed. The dormant `SubLoadout` upgrade plumbing stays parked exactly as DECISIONS.md left it; do not extend it.
- **No telescope upgrade tree this milestone.** The room-def carries an empty/linear-stub tree per the add-room template, but no upgrade content ships. (Reach/capacity upgrades are a later pass.)

## Settled design points (append to DECISIONS.md at close-out)
- **Telescope arm is the base collector; claw is demoted to a buyable alternate room (2026-06-20, Snir).** Resolves the long-parked "telescopic arm room" deferral (DECISIONS.md) by building it — but as *base equipment*, with the M3 claw re-homed as a purchasable alt rather than retired.
- **Starting sub is now telescope + control + bullet, tower above (2026-06-20, Snir).** Replaces the six-room Minnow+ (engine/middle/helm row + tower/claw/storage). The base loses the engine room, the dedicated claw room, and the dedicated storage room.
- **Engine room retired; its function folds permanently into the control room (2026-06-20, Snir).** There is no engine room and there never will be one — propulsion is an inherent property of the sub / control room, not a placeable module. **The parked "Engine Boost" upgrade dies with it** — remove it from data and from DECISIONS as a live concept (note it as retired, don't silently drop it). Repair Training is unaffected by this milestone.
- **Telescope control scheme (from the original parked brief, DECISIONS.md):** aim left/right with **A/D**, extend with **S**, retract with **W**, grab with **Q**. Orientation-aware like the floodlight (the room can mount on either outer wall; "extend" always pushes toward open water).
- **Telescope storage = two onboard cages, s2 + s4, capacity 6 each (12 total) (2026-06-20, Snir).** The arm **auto-deposits its current catch into these cages on retract**. Cages fill visibly. When both are full, further grabs are refused (push-your-luck) until the sub **banks at the dock**. **Cage contents are lost on implosion until banked** — same risk rule as the claw pen; the telescope is not a "safe income" exception.
- **Claw keeps its own small built-in pen (capacity 4) (2026-06-20, Snir).** The M3 storage-pen mechanic moves *into the claw room* — the claw no longer depends on a separate storage room. The standalone storage room returns only as a later purchasable room when capacity is a real constraint.
- **Telescope reach ~8m (2026-06-20, Snir):** long and straight, the "long tool," versus the claw's short wide swing. (`GameFeel.telescope.reach_m`.)

## Spec

### Module 0 — Promote the add-room skill (do this first)
Before building the telescope, turn `SKILL_STUB_add_room.md` into the real,
code-verified `add-deeper-room` skill, and then **build the telescope room (Module
2) by following it** — the telescope becomes the skill's first live validation.

- **Build the skill** per `SKILL_STUB_add_room.md` (its §"What the skill must
  contain" lists every section). Path: `.claude/skills/add-deeper-room/SKILL.md`.
- **Fill the stub's deferred TODOs against real code now** — the M4 pipeline,
  `validate`, section-bake, multi-resource costs, and the first hand-built
  purchasable rooms (the M4/§6 base-gun and bullet rooms) all exist, so the file
  paths, the room-def template, the `GameFeel` resource keys, and the test skeleton
  can point at real code instead of guesses. No TODO markers may survive Module 0.
- **Reconciling the stub's "hand-build the first room first" instruction:** the
  stub says to hand-build the *first purchasable room* and lift the skill's
  templates from it. That has **already happened** — the base-gun and bullet rooms
  (§6) are built and in `STATUS`. So the skill's reference implementations already
  exist; Module 0 lifts from *those*, and the telescope (Module 2) is the skill's
  **validation pass** (the stub's step 3: "re-derive an existing room from the
  skill"). Building the telescope *via* the skill is exactly the pressure-test the
  stub asks for.
- **If the skill can't be made clean** — sections leak into the pipeline, the
  upgrade tree won't generalise, costs fight the system, the telescope needs a
  step the procedure doesn't cover — **stop and report to Snir in design terms**
  (stub §"Build instructions" step 5). A telescope that won't fit the room
  interface is a signal worth more than a shipped room.
- **Test:** the skill's own validation — follow the finished SKILL.md to re-derive
  an existing room (e.g. the bullet room) in a scratch branch; any missing or
  ambiguous step is a skill bug to fix, then discard the branch. **Commit:**
  `M7-0: promote add-room stub to code-verified add-deeper-room skill`.

### Module 1 — Retire the engine room; slim the base loadout
Before the telescope can be the base collector, the base sub has to change shape. Do this first so every later module builds on the new starting layout.
- **Remove the engine room as a placeable module.** Drop its `ModuleDef`/catalog entry, its shop entry, and any assembly affordance. Propulsion stays exactly as it plays today — fold whatever the engine room contributed into the **control room** / the sub's inherent movement, so the sub still drives identically. **No movement behaviour change is intended** — this is a structural removal, not a tuning pass.
- **Delete the "Engine Boost" upgrade** from the dormant upgrade data and mark it retired in DECISIONS.md. Leave Repair Training and the rest of the dormant `SubLoadout` plumbing untouched (DECISIONS.md, 2026-06-16 round 5).
- **Rewrite the starting layout ("the base sub").** New base = **control + bullet in the main row, conning tower above the control room, telescope room** in the collector slot (the telescope room itself lands in Module 2 — until then, stub the base layout against the existing claw room so the game still builds and plays, then swap to the telescope in Module 3). The base no longer contains an engine room, a dedicated claw room, or a dedicated storage room.
- **Save migration:** an existing save written against the six-room Minnow+ must load without crashing. Reuse the M4 `SubValidator.recover` "first claim wins / drop what no longer fits" path — a saved engine/storage room that no longer has a catalog entry is silently dropped on load, exactly as the recovery rule already handles a stray room. Add a test for loading an old-shaped save.
- **Test:** `tests/test_shop.tscn` / `test_slots.tscn` / the layout/save suites — the base sub builds with the new room set, contains no engine room, drives identically to before, and an old six-room save loads and recovers cleanly. **Commit:** `M7-1: retire engine room (fold into control), slim base loadout, drop Engine Boost`.

### Module 2 — The telescope room (build it *via the Module 0 skill*)
Build the new room by **following the `add-deeper-room` skill you just promoted in
Module 0** — this is the skill's validation pass. The plumbing (buy, place, flood,
hull, eject, sections-bake, save/load, tilt) is inherited from the template — **do
not re-implement it.** Only the telescope *mechanic* and its cages are hand-coded,
against the M3 claw as the reference room. If the skill is missing a step the
telescope needs, fix the skill (Module 0), don't work around it here.
- **Room-def / section layout (ROOM_SYSTEM.md §2 notation):**
  - **Station in s3** (the telescope console — operate the arm from here).
  - **Arm base at b3** (drops through the floor/keel directly under the station, like the claw base hangs from the keel).
  - **Two storage cages: s2 and s4**, each capacity `GameFeel.telescope.cage_capacity` (default 6 → 12 total). These are the room's own onboard pens, drawn filling as catches deposit.
  - Ladders are parity-placed automatically in s1/s5 (§3) — author nothing there.
  - The arm is an **outside element**: mounts on the room's open-water wall (left/right), auto-assigned to the exterior face or switchable in the design screen like the claw/floodlight.
- **The arm mechanic (hand-coded against the claw as reference):**
  - A single straight telescoping arm from the b3 keel base. **Aim A/D** rotates it within a clamped arc (does not swing into the hull — mirror the floodlight's hull clamp). **Extend S** lengthens it up to `GameFeel.telescope.reach_m` (~8m). **Retract W** shortens it back toward the base.
  - **Grab Q:** when the arm tip overlaps a `SalvageItem` in WATER state, **Q** snaps it onto the tip (reuse the claw's grab → the item enters CAGED/CARRIED-equivalent state riding the tip; stay on the existing `SalvageItem` state machine, don't invent a parallel one). The tip holds **one** item at a time (or `GameFeel.telescope.tip_capacity`, default 1) — grab is explicit, never on-contact.
  - **Auto-deposit on retract:** when the arm returns to "home" (tip within `GameFeel.telescope.home_radius_m` of the base, mirroring the claw's home check), any item on the tip **transfers automatically into the room's cages** (s2 first, then s4), with no crew ferry. This is the one "automatic" step — it replaces the claw's foot-ferry entirely for this room.
  - **Cages full:** if both cages are at capacity, a retract-deposit is refused and the item stays on the tip (so the player sees they're full and must dock); a grab while the tip is occupied is also refused. Mirror the claw's "full pen refuses, keep holding" rule.
- **Orientation-aware** like the floodlight: the room reads its mounted wall and maps "extend" toward open water, so A/D/S/W feel correct on either side.
- **Drawn by `SubVisual`** (arm, tip, cages, console, keel hatch) so the whole assembly tilts with the hull, exactly as the claw is drawn.
- **Tunables in `GameFeel.telescope`:** `reach_m` (~8), `aim_speed`, `extend_speed`, `retract_speed`, `aim_arc_deg`, `home_radius_m`, `tip_capacity` (1), `cage_capacity` (6). No magic numbers in logic.
- **Test:** new `tests/test_telescope.tscn` — aim clamps at the hull and never points inward; extend stops at `reach_m`; **Q** grabs an overlapping salvage item and refuses when the tip is occupied or the item isn't overlapping; retract to home auto-deposits the tip item into s2 then s4; a full pair of cages refuses deposit (item stays on tip) and refuses further grabs; the room floods/breaches/ejects/tilts like any room (template invariants); persists through save → load → rebuild. **Commit:** `M7-2: telescope arm room — aim/extend/retract/grab + auto-deposit cages`.

### Module 3 — Make the telescope the base collector; demote the claw to a buyable alt
Now wire the new room into the base loadout and move the claw to the shop.
- **Base sub uses the telescope room** in the collector slot (replacing the Module 1 stub). The starting layout is finalised: **control + bullet row, tower above control, telescope room** — no engine, no separate claw room, no storage room.
- **The claw room becomes a purchasable room** through the existing shop + assembly flow (its `ModuleDef`/catalog entry stays; it gains a shop price in `GameFeel`/the cost table per ROOM_SYSTEM.md §4 multi-resource costs). Buying and placing it works through the same path as any other room. **Its built-in pen (capacity 4) and the full M3 ferry (claw grab → keel-hatch drop → crew carry → stow in pen) are preserved unchanged.**
- **Both collectors coexist:** a player can run telescope-only (base), buy a claw room and run both, or rearrange at the dock for free (M4 rule). Each collector banks its own cages/pen at the dock; implosion loses any un-banked contents from both.
- **Test:** `tests/test_shop.tscn` + the assembly/layout suites — the base sub contains the telescope and not the claw; the claw is buyable and places legally into an owned slot; a bought claw room collects + ferries + stows into its own pen exactly as in M3; banking at the dock secures both telescope cages and the claw pen; implosion drops un-banked contents from both. **Commit:** `M7-3: telescope is base collector, claw re-homed as a buyable alternate room`.

## Out of scope (parked — do not build this milestone)
- **Telescope upgrade tree** (longer reach, bigger cages) — later pass; room-def carries only the empty stub.
- **A returning dedicated storage room** — comes back as its own purchasable room when capacity is a real constraint, not now.
- **Any change to propulsion feel** — engine removal is structural only; movement must play identically.
- **New salvage types, fauna, weapons, or map work.**
- **Reconnecting the upgrade tree / Repair Training UI** — still parked (and per Snir, gated behind the later elemental update).
- **The elemental update** — explicitly after the art pass; unrelated to this milestone.

## Verify by playing — Milestone 7
Launch: `"D:\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe" --path .`

1. **The leaner base sub.** Start a fresh run — the sub should be **control + bullet side by side, conning tower on top, and a telescope room** as the collector. There should be **no engine room** and **no separate storage room**. The sub should drive exactly as it did before (the engine folding in shouldn't change how it feels to pilot).
2. **Run the telescope solo.** Sit at the telescope console. **A/D** should aim the arm, **S** extend it straight out (up to ~8m — clearly longer than the old claw's reach), **W** retract it. The arm should never swing into the hull.
3. **Grab and auto-store.** Extend toward a piece of seafloor scrap or a fish carcass, press **Q** to snag it onto the tip, then **W** to retract — when the arm comes home the catch should **drop itself into the room's cages on its own** (no carrying it by hand). The two cages (left and right of the console) should visibly fill.
4. **Fill it up.** Keep collecting until both cages are full (12 items) — further grabs should be refused, signalling it's time to surface. Dock and bank — the cages should empty into your banked total.
5. **Lose it to implosion.** Collect a few items but *don't* dock; let the sub flood and implode — the un-banked cage contents should be **lost** (same risk as the old claw pen). The telescope is not a safe-income exception.
6. **Buy the claw back.** At the dock, the **claw room** should now be a **purchasable** room. Buy and place it, then play with both: the claw should work exactly as it did in M3 (two-joint excavator, Q to cage, ferry the catch by foot to its own small pen). Both collectors should bank at the dock.
7. Report back: does the telescope feel good to run *solo* (the headline goal)? Is its clean point-extend-grab-retract loop a clear contrast to the fiddly claw? Does the leaner base sub read better than the old six-room one? → PLAYTEST_LOG.md, then tune `GameFeel.telescope` from there.
