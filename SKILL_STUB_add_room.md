# SKILL_STUB_add_room.md — spec for Claude Code to build the add-room skill

*This is NOT the skill. It's a brief telling you (Claude Code) how to **write** a
`SKILL.md` that adds a new room type to DEEPER. It **supersedes
`SKILL_STUB_add_module.md`**, which was written against the old mixed-footprint
M4 draft. Read `ROOM_SYSTEM.md` (the room canon) and
`MODULAR_SUB_IMPLEMENTATION.md` (grid/pipeline/validation canon) before doing
anything with this.*

## What changed vs. the old stub
The old stub assumed pods + mixed footprints and said "build after M4 Module 4."
The room model is now: **one uniform cell, a five-section authoring layer (s1–s5)
that bakes to coordinates, parity-placed ladders, t/b element notation,
multi-resource costs, and per-room upgrade trees** (`ROOM_SYSTEM.md`). The skill
must encode *that* model. The timing also changes — see "When to build it."

## Skill shape (decided): guided checklist + a declarative room-def template
A purely declarative "fill in a room-def, code generates" system does **not**
fit, because the roadmap includes genuinely novel mechanics (wrecking ball,
shield) that no schema can express — the first such mechanic either bloats the
schema into a language or breaks out of it. So:

- **The plumbing is declarative.** A **room-def template** captures everything
  uniform across rooms: id, display name, footprint (1×1 for now), the section→
  element map (station s3 default, hatch/gun/claw/storage in s2/s3/s4, t/b
  variants), outside-element wall side, stats block, the upgrade tree, and the
  multi-resource price. The skill reads/fills this and wires the uniform parts.
- **The mechanism is hand-coded.** A new room's *unique behaviour* (the swing of
  a wrecking ball, a shield's absorption hook into the breach/water model) is
  always written by hand, against the closest existing room as a reference. The
  skill's job is to make the plumbing free and point at the right reference, not
  to pretend the mechanic is data.

This is why the skill is a checklist *with* a template, not one or the other.

## Where it goes
- Path: `.claude/skills/add-deeper-room/SKILL.md` (repo-side Claude Code skill).
- Invoked when a brief says "add a room" / "new room" / "new station" / "new
  weapon room."

## What the skill must contain (sections to write)

### 1. Trigger description
A tight `description:` firing on add-a-room requests and not unrelated work.
Model it on the house skill descriptions.

### 2. Preconditions block
- Confirm the grid + `ModuleDef` + `validate` + `rebuild_from_layout` +
  **section-bake step** + **upgrade-tree wiring** + **multi-resource cost**
  systems all exist (point at real files — **TODO: fill paths once the M4
  pipeline + ROOM_SYSTEM systems are committed**).
- Require reading `ROOM_SYSTEM.md` (§2 sections, §3 ladder parity, §4 economy,
  §5 upgrades) and `MODULAR_SUB_IMPLEMENTATION.md` §4–5 (pipeline, validation).

### 3. The ordered procedure (the heart of it)
Write the canonical step list. From the room model it should be roughly — verify
against real code and correct:
1. Fill the **room-def** from the template: id, name, footprint, section→element
   map (default station s3; declare hatch/gun/claw/storage and any t/b mounts),
   outside-element wall side, stats, price `[…]` in sc/s_ca/m_ca/l_ca.
   (**TODO: real room-def path + copy-paste template.**)
2. If the room has a **new mechanic**, hand-code it against the nearest reference
   room (TODO: list the reference set — claw/telescope for arms, base-gun/bullet/
   heavy-torpedo for weapons, storage for passive containers). Flood-eject, water,
   hull, and section-baking are inherited — **do not re-implement them.**
3. Wire the **upgrade tree** through the generic tree mechanism (TODO: cite it),
   linear or branch; never build a bespoke upgrade menu.
4. Add the **price** (and any **slot** interaction) per `ROOM_SYSTEM.md` §4 —
   multi-resource bundle, escalation where applicable. (TODO: real `GameFeel`
   keys for the resource tiers + slot price.)
5. Add any **new validation cases** the room needs — in `validate` **only**
   (TODO: cite the §5 rule mechanism). Confirm the room authors no element into
   its floor's parity ladder section (§3) — this is an authoring-time check.
6. Register colours/dimensions in `placeholder_art.gd`; named layers in
   `collision_layers.gd` if the mechanic needs them. No magic numbers.
7. If it adds a `class_name` script: run `"GODOT_PATH" --headless --path .
   --import` once (stale-class-cache trap).
8. Add the room to the **shop catalog** so it's buyable.

### 4. The test skeleton
A copy-paste headless test template (**TODO: base it on the first real
hand-built room tests**) asserting the universal invariants every room must pass:
- buyable; placeable only in a legal empty slot; illegal placement refused with a
  message;
- sections bake correctly (station lands at the s3 x-offset; t/b mounts at the
  right ceiling/floor point; ladder takes the parity section, room element does
  not collide with it);
- floods / breaches / ejects like any room;
- the upgrade tree applies and persists;
- persists through save → load → rebuild; tilts with the hull.
Author fills only the room-specific assertions (the mechanic, the stats) on top.

### 5. Definition of done + commit convention
- All-boxes list: room-def, mechanic (if any), upgrade tree, price/slot,
  validation, art, layers, import, catalog, test green, full suite green.
- Commit message matching the milestone convention (e.g. `M6-x <room> room`).

### 6. Explicit "do not" list
Don't re-implement flood-eject, water, hull generation, **section baking**, or
**upgrade-tree plumbing** per-room; don't add geometry outside
`rebuild_from_layout`; don't let s1–s5 leak into the pipeline; don't copy
validation out of `validate`; don't assume scrap-only costs; don't add real art
or sound. (Mirror `ROOM_SYSTEM.md` §8 + `MODULAR_SUB_IMPLEMENTATION.md` §10.)

## When to build it (the rethought timing)
The old "build after M4 Module 4" was a single gate. Split it, because parts are
writable now and parts aren't:

- **Writable now (do at M4 kickoff):** the design-spec portions of the skill —
  trigger description, the room-def *schema* (from `ROOM_SYSTEM.md`, which is
  fixed), the section/ladder/economy/upgrade conventions, the do-not list, the
  procedure's *shape*. These derive from canon, not from code, so they won't be
  guesses.
- **Defer until the systems exist (fill the TODOs then):** every concrete file
  path, the `ModuleDef`/room-def code template, the `GameFeel` resource keys, the
  `validate` rule-add mechanism, the test skeleton. These must point at real code
  or they'll encode guesses — exactly the failure the old stub warned about.

So: scaffold the skill at M4 kickoff with the canon-derived parts written and the
code-wired parts left as explicit TODOs; **lock it (fill TODOs, delete markers)
once the M4 pipeline + the first hand-built purchasable room exist.** Until then
the skill is real but flagged "not yet code-verified."

## Build instructions for you (Claude Code)
1. Build the first **purchasable** room with a real mechanic **by hand** (a
   weapon room is the natural first — base-gun or bullet from `ROOM_SYSTEM.md`
   §6). Do NOT use the skill to build it; it becomes the reference the skill
   points at.
2. Then fill the skill's deferred TODOs from that implementation, lifting concrete
   templates/paths.
3. **Validate the skill by re-deriving an existing room from it:** follow your own
   SKILL.md to regenerate, say, the bullet weapon room from scratch in a scratch
   branch. Any missing or ambiguous step means the skill is wrong — fix it,
   discard the branch.
4. Commit `add room-creation skill`. Note in STATUS that the skill exists and
   when to use it.
5. If the procedure can't be made clean — too many special cases, sections leak,
   the upgrade tree won't generalise, costs fight the system — **stop and report
   in design terms to Snir.** It means the room interface isn't as clean as
   `ROOM_SYSTEM.md` assumed, which is worth knowing before later milestones pile
   on more rooms. This pressure-test is half the reason to write the skill early.

## Out of scope for the skill
Designing what a room *does* (that's a brief), balancing stats/prices (playtest
tuning), designing **larger (multi-cell) rooms** (`ROOM_SYSTEM.md` §7 — their own
pass), and anything outside the add-a-room-type procedure.
