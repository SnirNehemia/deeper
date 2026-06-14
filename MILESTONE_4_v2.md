# MILESTONE_4.md — The Dry Dock & The Growing Sub (v2 — Sonnet build plan)

*Brief for Claude Code. Read CLAUDE.md first, then STATUS.md, DECISIONS.md, and **MODULAR_SUB_IMPLEMENTATION.md** (the architecture canon for this milestone — how the grid, generation pipeline, validation, and dock work; this brief only orders the work). **Do not start until Milestone 3 is closed out.** Milestones are now 3–4 weeks. v2 supersedes the earlier M4 brief.*

## Goal
Banked scrap becomes spendable. Players buy room modules and pods into an **inventory** at a dry-dock menu, then **assemble** their sub on a grid; the sub's geometry, water, hull, and damage model are all generated from that layout. First catalog: a **second turret room** and a **floodlight pod**. Layout persists. Question this milestone answers: *does buying and arranging your own sub feel like real progression — is "the sub is the character" true?*

## How to work this brief (Sonnet discipline)
- Eleven small modules, strict order. Each module ends: its test green → **full existing suite green** → commit with the given message. Never start the next module on red.
- Every module has a **Definition of done** (all boxes or it isn't done) and a **Do-not-touch** list. If a task seems to require touching a do-not-touch item, **stop and report in game terms** — do not improvise.
- Two **Snir checkpoints** (after D and after H): stop, update STATUS with verify-by-playing steps for just that checkpoint, and wait for playtest feedback before continuing.
- All new numbers go in `GameFeel` (new `dock` block per the implementation doc §8). All new colors/dimensions in `placeholder_art.gd`. All new collision needs named layers.
- After adding any `class_name` script: run `--headless --import` once (known trap).

## Settled design points driving this brief (append to DECISIONS.md at close-out)
- Modular sub is **grid-based**: cell 2.5×3m; rooms occupy whole cells; uniform 3m room height (lower deck grows from 2.5m — accepted).
- Whole sub **normalized to the grid**; no grandfathered geometry. Tower becomes 1 cell (2.5×3m).
- **Doors/ladders are automatic** wherever rooms touch (players never place connections).
- Dry dock = **menu, keyboard-only**: shop buys modules into an **inventory**; an **assembly screen** places them; **one validation function** refuses illegal layouts (blocked gun faces, islands, overlaps) so an invalid sub can never exist. Invalid saves recover by returning modules to inventory — nothing is ever lost.
- **Locked core: helm + tower only**; everything else movable. Rearranging is **free, dock-only**. Refit applies instantly.
- **Pods clip to exterior hull faces** (no cell). Growth is **soft-capped by price escalation** (+25%/owned module), plus a technical bounds guard.
- Pacing: first room affordable after **~1 good run**.

---

## Module 1 — Grid constants + layout data model
Define the grid constants, `ModuleDef` catalog resources (helm, tower, generic room, engine, claw room, storage, turret room, floodlight pod — content for the last two arrives in Modules 9–10), and the `Layout` data (placements, pods, inventory) per implementation doc §2–3. Express the normalized starting layout ("The Minnow+", §2.1) in data. **No gameplay code changes.**
- **Definition of done:** [ ] constants exist in one place [ ] catalog resources load [ ] starting layout loads and round-trips through serialization [ ] full suite untouched and green.
- **Do not touch:** `sub.gd` geometry, water, stations, any scene.
- **Test:** `tests/test_layout.tscn` — layout serialize/deserialize, footprints, starting-layout contents. **Commit:** `M4-1 grid + layout data model`.

## Module 2 — Validation engine
Implement `validate(layout)` exactly per implementation doc §5 (all 7 rules, readable violation messages). Pure function, headless-testable, no UI.
- **Definition of done:** [ ] every rule has at least one passing and one failing test case [ ] starting layout validates clean [ ] no rule logic exists anywhere else.
- **Do not touch:** gameplay code, scenes.
- **Test:** `tests/test_validate.tscn` — table of legal/illegal layouts (blocked turret face, floating room, tower unsupported, overlap, pod on interior face). **Commit:** `M4-2 layout validation`.

## Module 3 — Generated interiors + connections (normalization, part 1)
Build pipeline stages 1–2 (§4): rooms, auto-doorways (step + sill), auto floor-openings + ladders, generated from the layout. Swap the sub's hand-built interior for the generated one using the starting layout. Expect and accept the settled geometry deltas (tower 1 cell, lower deck 3m tall); update test constants — no compatibility shims.
- **Definition of done:** [ ] sub interior comes only from `rebuild_from_layout` [ ] door steps, sills, ladder rules behave per M3 tests (updated constants) [ ] crew movement/climb/seat suites green [ ] no old geometry constants left referenced.
- **Do not touch:** water model internals, hull collider, dock/save, turret/claw logic.
- **Test:** extend `test_sub`/`test_crew` to generated geometry; add `tests/test_generation.tscn` for connection placement. **Commit:** `M4-3 generated interiors + connections`.

## Module 4 — Generated hull, water cells, damage, implosion (normalization, part 2)
Pipeline stages 3–6 (§4): hull outline + collider from occupied cells; N water cells (one per room, volume from footprint) with registered sills; breach surfaces = exterior faces; mass/implosion volume derived. The M2/M3 water, damage, repair, drowning, implosion suites must pass on the generated sub (updated constants only — same behaviors).
- **Definition of done:** [ ] zero hardcoded room/hull/water geometry remains in gameplay code [ ] water conservation holds on an asymmetric test layout [ ] implosion threshold = fraction × generated volume [ ] hull collider tilts with pitch as before [ ] full suite green.
- **Do not touch:** equalization math (extend inputs, don't fork it), GameFeel values other than additions.
- **Test:** run water/damage/implosion suites on the starting layout **and** one asymmetric layout; add `tests/test_hull_gen.tscn`. **Commit:** `M4-4 layout-driven hull + water + damage`.

### ⛳ CHECKPOINT 1 — Snir plays (regression of feel)
Update STATUS with steps: full M3-style run — drive, climb everywhere (notice the roomier tower and taller lower deck), breach, flood, repair, drown, implode, claw, bank. Verdict needed: *does it feel identical (apart from the accepted size changes)?* Fix feel regressions before Module 5.

## Module 5 — Save extension + inventory + load recovery
Extend the `user://` save: scrap (existing) + inventory + layout. Boot: load → `validate` → rebuild; on validation failure, non-core modules → inventory, scrap untouched (§5 recovery). Write on bank and (later) on dock Apply.
- **Definition of done:** [ ] quit/relaunch restores layout + inventory + scrap [ ] corrupted/invalid layout boots to core + full inventory, nothing lost [ ] M3 save without layout fields loads as the starting layout.
- **Do not touch:** dock UI (doesn't exist yet), gameplay.
- **Test:** `tests/test_save_layout.tscn` — round-trip, legacy-save upgrade, invalid-layout recovery. **Commit:** `M4-5 layout persistence + recovery`.

## Module 6 — Dock shell + shop tab
Dock-zone prompt → paused menu (keyboard-only, both keymaps). Shop tab: catalog, prices from `GameFeel.dock` with +25%/owned escalation, buy → inventory + deduct + save.
- **Definition of done:** [ ] menu opens only when floating in dock zone [ ] buying deducts, escalates, persists [ ] cannot buy with insufficient scrap [ ] navigable by both players' keys.
- **Do not touch:** assembly/placement (next module), gameplay scenes.
- **Test:** `tests/test_dock_shop.tscn` — price escalation math, purchase persistence (headless save read-back). **Commit:** `M4-6 dry dock shop`.

## Module 7 — Assembly tab (placement UI)
Grid diagram of the layout; cell cursor; select from inventory → `validate`-driven highlighting → place; pick up placed non-core modules; return to inventory; mirror-orientation toggle for rooms with a special face. Apply → final validate → `rebuild_from_layout` → save → close. Cancel restores.
- **Definition of done:** [ ] every illegal placement is refused with its violation message shown [ ] core modules can't be selected/moved [ ] Apply rebuilds the live sub instantly with crew placed in the helm room [ ] Cancel is lossless [ ] keyboard-only.
- **Do not touch:** validation internals (call it, don't copy it), pipeline internals.
- **Test:** `tests/test_assembly.tscn` — place/remove/move flows headlessly via the same controller functions the UI calls. **Commit:** `M4-7 assembly screen`.

## Module 8 — Rearranging polish + pods plumbing
Pod placement in the assembly tab (exterior faces highlight; one per face), pod rendering as hull bumps, pod data through save/rebuild. No functional pod content yet.
- **Definition of done:** [ ] pods placeable/removable/persistent [ ] render outside the hull, tilt with it [ ] no collider change [ ] full suite green.
- **Do not touch:** lighting, stations.
- **Test:** extend `test_assembly` + `test_save_layout` with pods. **Commit:** `M4-8 pod attachment`.

### ⛳ CHECKPOINT 2 — Snir plays (the dock)
Update STATUS with steps: bank scrap, open the dock, buy whatever's affordable, rearrange the existing rooms into a new shape, apply, dive, return, rearrange again. Verdict needed: *is assembling the sub pleasant with a keyboard, and does rearranging feel like a toy or a chore?* Iterate UI before content.

## Module 9 — Content: second turret room
Per implementation doc §7: 2×1 room, gunner seat, tube on the `firing_face` (mirroring picks bow/stern), reusing existing turret/torpedo code with the cone centered on the face normal. Leave the original bow turret untouched.
- **Definition of done:** [ ] purchasable, placeable only with a clear firing face [ ] cone orients to the mounted face [ ] both turrets crewable simultaneously [ ] room floods/ejects/breaches like any room.
- **Do not touch:** existing turret station code paths beyond parameterizing the mount; torpedo behavior.
- **Test:** `tests/test_turret_room.tscn` — face orientation, blocked-face refusal, dual-turret fire. **Commit:** `M4-9 turret room module`.

## Module 10 — Content: floodlight pod
Per §7: exterior pod + interior wall aim-seat (`Station` subclass — flood-eject inherited), W/S sweep + hold for the light cone. Ambient light unchanged.
Post-Module-10: build the module-creation skill per SKILL_STUB_add_module.md
- **Definition of done:** [ ] purchasable, exterior-face only [ ] seat enters/exits/ejects like any station [ ] beam sweeps, holds, tilts with hull.
- **Do not touch:** ambient lighting, day/depth visuals.
- **Test:** `tests/test_floodlight.tscn` — placement rule, aim sweep/hold, eject on flood. **Commit:** `M4-10 floodlight pod`.

## Module 11 — Integration & close-out
Full suite (M1–M4) green; manual regression on a deliberately weird-but-legal layout. Update STATUS.md (file map, known issues, next step = M5 per ROADMAP), append the settled points above to DECISIONS.md, write the final verify-by-playing, commit + push.
- **Commit:** `M4 close-out`.

---

## Acceptance criteria
- [ ] With the starting layout, the game feels like M3 (accepted size deltas aside); full M1–M3 suites green on generated geometry.
- [ ] Scrap buys modules into an inventory; prices escalate with owned count; all of it persists across relaunch.
- [ ] The assembly screen places, moves, and returns rooms/pods, keyboard-only; **no illegal layout can ever be applied or loaded** (blocked gun face, island room, unsupported tower, overlap all refused with messages).
- [ ] Helm + tower are immovable; respawn stays at the tower in every layout.
- [ ] Applying a layout instantly rebuilds the sub: rooms, auto-doors/ladders, hull + collider, water cells, breach surfaces, implosion volume all follow.
- [ ] A second turret room fires along its mounted face; both turrets work at once; the room is a full flood/breach citizen.
- [ ] A floodlight pod clips to the hull and its interior seat sweeps an aimable, angle-holding beam.
- [ ] An invalid save recovers to core + inventory with nothing lost.
- [ ] Both Snir checkpoints were run and their feedback addressed.

## Out of scope (do not build)
Module selling/refunds, walkable dock scene, construction animations, hull-rating or stat purchases, cosmetics, mouse input, room rotation, per-grid-cell water, pod collision, mid-run refitting, ambient darkness, new fauna, map changes, gamepads, real art, any new weapon beyond the second turret.

## Verify by playing (for Snir — final)
1. Launch; play one normal run. It should feel like M3.
2. Bank ~6 scrap. Dock, press E: buy the **turret room**. In Assembly, try to brick its gun against another room — the dock should refuse and say why. Mount it stern-facing instead. Apply.
3. Dive, get chased, and let the new stern gun cover the retreat while the bow gun leads. Two gunners + a pilot = the M4 money shot.
4. Ram something near the new room: it breaches, floods, ejects the gunner, patches, drains.
5. Re-dock, buy the **floodlight**, clip it under the belly, sit its seat, sweep the beam through the cave mouth.
6. Rearrange your whole lower deck just because you can. Apply. Quit fully, relaunch — your sub is still yours.
7. Report the feel: progression or paperwork? Is the assembly screen a toy? Does the asymmetric silhouette feel like *your* sub? → PLAYTEST_LOG.md.
