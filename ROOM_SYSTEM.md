# ROOM_SYSTEM.md — DEEPER

*Design canon for rooms, room sections, elements, upgrades, and the room economy.
This is the source of truth for **what a room is** and **how rooms are authored**.
It extends and, where noted in §1, **supersedes** parts of
`MODULAR_SUB_IMPLEMENTATION.md`. If anything here conflicts with code reality,
stop and surface it in design terms — do not improvise a different architecture.*

*Read order for Claude Code: `CLAUDE.md` → `STATUS.md` → `DECISIONS.md` →
`MODULAR_SUB_IMPLEMENTATION.md` (grid/pipeline/validation canon) → this file.*

---

## 1. What this changes in the M4 canon (read first)

`MODULAR_SUB_IMPLEMENTATION.md` was written assuming a mixed-footprint catalog
(2×1 "classic" rooms, a 1×1 tower). This document **replaces that with one
uniform cell** and adds an authoring layer the pipeline never sees. The two
load-bearing changes:

1. **One uniform cell replaces the 2×1 / 1×1 footprint system.** Every standard
   room occupies exactly **one cell**. The tower is one cell, the helm is one
   cell, every room is one cell. The handful of **larger rooms** that will exist
   later are the rare exception, deferred until we actually design one (§7).
   *(Supersedes `MODULAR_SUB_IMPLEMENTATION.md` §2 "Room sizes" and §2.1's
   2×1/1×1 deltas. The cell also **widens to 3.75m** (5 × 0.75m sections); height
   stays 3m — see §2.)*

2. **Sections (s1–s5) are a pure authoring layer.** A room is divided — *only
   terminologically* — into five sections placed side by side, used to author
   where elements (stations, hatches, guns, claws, ladders) sit. **Sections bake
   to local x-offsets before `rebuild_from_layout` runs.** The generation
   pipeline, the water model, the hull generator, and `validate()` **never see
   s1–s5** — they see coordinates and elements, exactly as they do today.
   *(This is an addition to §3–4, not a change to the pipeline's contract: the
   pipeline's inputs are unchanged; a new compile step feeds it.)*

Everything else in `MODULAR_SUB_IMPLEMENTATION.md` (one pipeline, one validator,
generated hull/water/breach surfaces, pods on exterior faces, instant docked
refit, the §10 invariants) still holds.

---

## 2. The cell and the five sections

A room is one grid cell. Its interior width is divided into **five equal
sections, left to right: s1, s2, s3, s4, s5**, each **1m wide → the cell is 3.75m
wide** (was 2.5m in the M4 draft — this is the resolved widening, see the note
below). Sections are an authoring coordinate system, nothing more — "s3" means
"the centre 1m of this room's interior width," and it compiles to a local
x-offset at room-build time.

```
| s1 | s2 | s3 | s4 | s5 |
  ^                    ^
  ladder (odd floors)  ladder (even floors)
```

- **s1 and s5 are reserved for ladders** (see §3). Authoring an element into s1
  or s5 is only legal when that side has no ladder on this floor; otherwise it's
  an authoring error the skill should catch (§ROOM_SYSTEM has no runtime
  enforcement of this — it's caught when the room is written, not at play time).
- **s2, s3, s4 carry the room's own elements.** The **default** is the station in
  **s3**; a room that doesn't say otherwise puts its station there.

### Element placement notation
- `sN` — element sits in section N at floor level (e.g. station in s3, hatch in
  s2, storage cage in s3).
- `tN` / `bN` — element sits at the **top** / **bottom** of section N (e.g. the
  claw base at `b3`, a top-mounted heavy-torpedo tube at `t3`). Use t/b when an
  element lives on the ceiling or floor of the room rather than mid-wall.
- **Outside-the-sub elements** (guns, claws, the future wrecking ball) are
  denoted as outside; in the **sub design screen** they can be switched between
  the **right / left wall**, or auto-assigned to whichever side faces open water
  (the exterior). The section still authors *where along the room* they mount;
  the wall side is the right/left choice.

> **Resolved (cell width):** the cell is **3.75m wide (5 × 0.75m sections)**, widened
> from the M4-draft 2.5m so a station + ladder + gun read clearly at 1m each. This
> is **one grid constant**, but it ripples through every existing test, the hull
> generator, water-cell volumes, and the starting-layout geometry — update those
> constants, don't special-case them. **The wider sub is a playtest point:** add
> "does the 3.75m-wide sub still feel right (framing, heft, room legibility)?" to the
> verify-by-playing notes at the M4 checkpoint where generated geometry first runs
> (`MILESTONE_4_v2.md` Checkpoint 1). Cell *height* is unchanged (3m).

---

## 3. Ladders (automatic, by floor parity)

Ladders are placed automatically wherever floors stack — players never author a
ladder. Which **side** a floor's ladder takes alternates by floor, counted from
the tower downward:

- **Odd floors → ladder in s1.**
- **Even floors → ladder in s5.**

This preserves the M3 "ladders alternate sides floor-to-floor so climbing needs
lateral movement" decision (see `DECISIONS.md`, M3 Module A), now expressed as a
parity rule on the section grid instead of per-room hand placement. The
auto-connection rules in `MODULAR_SUB_IMPLEMENTATION.md` §4 stage 2 still own
*whether* a ladder exists (rooms stacked → floor opening + ladder); this rule
only fixes *which section* it lands in.

A room must not author its own element into the section the ladder claims on its
floor. The skill checks this when the room is written (§ the add-room skill).

---

## 4. The room economy (two-step, multi-resource)

### 4.1 Two separate purchases
Adding a room to the sub is **two independent buys**, in either order:

1. **Buy a cell slot** — an empty buildable cell, added on the sub design screen.
   Slots are the growth budget; their price escalates to soft-cap sub size
   (reuse the `MODULAR_SUB_IMPLEMENTATION.md` §6 price-escalation mechanism).
2. **Buy a room** — purchased in the **shop** into inventory, then placed into an
   empty slot on the design screen.

A bought room with no free slot sits in inventory until a slot exists; an empty
slot with nothing to put in it is just open space. This separation lets a player
pay for *size* and *contents* as distinct decisions.

> Reconcile with M4: `MILESTONE_4_v2.md` Module 1 ("grid + layout data model")
> has **already landed** (`STATUS.md`: `test_layout` green) — that's the data
> layer, untouched by this. What's missing is the **slot economy**, and it
> **gates everything**: a purchased room has nowhere to go without a buyable
> empty slot. So this becomes the **first *content* module of M4** — built on the
> finished data model, before the shop/assembly work. The current Module 6/7
> one-step "buy module → place" flow is amended: the shop also sells slots; the
> assembly screen places rooms into owned slots. Schedule the slot economy as M4's
> first build target after the data model.

### 4.2 Costs and resources
Costs are written in **square brackets**. Resources:

- `sc` — scrap
- `s_ca` — small carcass
- `m_ca` — medium carcass
- `l_ca` — large carcass

Example: `[2 sc, 3 s_ca, m_ca]` = 2 scrap + 3 small carcasses + 1 medium carcass
(a bare resource code with no number means 1). `[-]` marks a **starting room**
(owned from the first run, not purchased).

> Reconcile with M3/M4: today scrap is the only spend currency and carcasses are
> a trophy count with **no spend path** (`DECISIONS.md`, M3 Module D: "no sink
> yet"). Two separate things, one easy and one not:
> - **Easy (automatic with content):** the s/m/l tiers just drop from s/m/l
>   enemies. Today only small fish exist, so only `s_ca` drops; bigger enemies
>   later fill `m_ca`/`l_ca` for free. No work needed now beyond defining the tiers.
> - **The real task:** the dock must **accept carcasses (and bundles) as
>   payment** — a multi-resource cost check replacing scrap-only spend. The room
>   catalog below is already priced in these tiers, so this spend mechanism has to
>   exist for any purchasable room. Schedule it with the M4 shop.

---

## 5. Upgrades and upgrade trees

A room may carry an **upgrade tree** that modifies its station / ability. Trees
can be linear (each upgrade gates the next) or **branch** (a one-time fork into
mutually exclusive paths — e.g. the base gun's "bullets vs. torpedoes"). Costs
escalate along a path and are paid in the resource tiers of §4.2.

Authoring conventions used in the catalog (§6):
- A linear chain is written as "X first [cost], then Y [cost]."
- A branch is written as "splits to two options: A or B," each with its own
  sub-chain.
- Upgrades change **stats** (speed, damage, rate, capacity), **behaviour**
  (secondary explosion, guidance), or **element count** (extra storage cages,
  more minibombs). The skill (§ the add-room skill) owns wiring a tree generically
  so a new room's tree is data + hooks, not a bespoke menu each time.

---

## 6. Room catalog (worked examples)

These are the authored rooms as specced. They double as the reference set the
add-room skill points at. Stats are starting values; expect tuning.

### Starting rooms (`[-]`)

**Control room** `[-]`
Description: the player controls the sub.
Elements: station in s3 (default).
Upgrades: makes the sub faster — each upgrade +10% speed, cost ×2 each step
`[2 s_ca]` base, up to 8 times.

**Claw room (small cage)** `[-]`
Description: grab items from outside the sub and bring them in via a two-joint arm.
Elements: dropping hatch at s2; claw base at `b3`; station in s3 (default).
Cage capacity: 2 volume units.
Upgrades: cage capacity → 4 volume units `[4 sc]`.

**Claw telescope room** `[-]`
Description: grab items from outside the sub via a telescopic arm. Right/left
rotates it continuously; up/down extends/folds it; `use` closes the claw.
Elements: claw base at `b3`; station in s3 (default).
Claw capacity: 4 volume units.
Upgrades: claw capacity → 6 volume units `[4 sc]`.

**Storage room (small)** `[-]`
Description: place items in storage so they don't float around the ship and get wet.
Elements: no station; storage cage in s3, capacity 4.
Upgrades: up to 3 identical storage cages — added to s4 first `[4 sc]`, then s2 `[10 sc]`.

### Purchasable rooms

**Base gun room** `[4 sc]`
Description: operate the base weapon — a gun firing torpedoes.
Stats: speed 3 m/s · damage 2 hp · rate 1/s.
Elements: simple gun ("base torpedo") on one wall.
Upgrades — **branches into bullets or torpedoes**:
- **Bullets** (torpedoes become smaller) `[8 sc, 1 s_ca]`:
  - Fire rate ×1.5 `[2 s_ca]`, then ×3 `[2 m_ca]`.
  - Bullet speed ×3 `[2 s_ca]`, then ×6 `[2 m_ca]`.
- **Torpedoes** (become slightly bigger):
  - Damage ×2 `[2 s_ca]`, then ×3 `[2 m_ca]`.
  - Secondary explosion on impact (circle of extra damage, may hit adjacent
    enemies) `[1 l_ca]`.

**Bullet weapon room** `[6 s_ca]` · cost 4 units
Description: fires high-speed bullets.
Stats: speed 6 m/s · damage 1 hp · rate 3/s.
Elements: gun on one wall.
Upgrades:
- Fire rate → 6/s `[4 s_ca]`, then 12/s `[4 m_ca]`.
- Speed → 10 m/s `[4 s_ca]`, then 20 m/s `[4 m_ca]`.

**Heavy torpedo room** `[6 s_ca]`
Description: fires a torpedo that travels straight and explodes for area damage
in a 4 m radius when the player presses `use` again.
Stats: speed 2 m/s · damage 10 hp · rate 1 per 3 s (and only after the previous
one has exploded).
Elements: tube at `t3` / `b3` — depending on whether it's the top-most or
bottom-most room.
Upgrades — **branches into scattered or guided**:
- **Scattered torpedo** `[4 m_ca]`: first `use` splits it into 3 minibombs going
  in all directions; second `use` explodes them. Each is 10 hp, 2 m radius.
  - More secondary bombs: +2 `[4 m_ca]`, then +2 `[2 l_ca]`.
  - Bigger explosion: 4 m `[4 m_ca]`, then 6 m `[6 m_ca]`.
- **Guided torpedo** `[4 m_ca]`: steer the round after launch (left/right to
  rotate); `use` detonates it in a 5 m radius.
  - Faster: 4 m/s `[4 m_ca]`, then 8 m/s `[2 l_ca]`.
  - Add accel/brake on up/down `[4 l_ca]`.
  - More damage: 15 hp `[4 m_ca]`, then 30 hp `[4 m_ca, 2 l_ca]`.

---

## 7. Larger rooms (reserved, do not build yet)

A few rooms will occupy more than one cell. They are deliberately out of scope
until we design a specific one, but the system must not assume one-cell-forever:
the footprint stays a property of the room (it just happens to be 1×1 for all
current rooms), and the section model is defined per-cell so a 2-wide room is two
section-strips, not ten sections. When the first larger room arrives, it gets its
own design pass; nothing here is to be generalised speculatively.

---

## 8. Invariants (additions to `MODULAR_SUB_IMPLEMENTATION.md` §10)

- **Sections never reach the pipeline.** If any pipeline / water / hull /
  `validate` code reads s1–s5, that's a bug: sections must have been baked to
  coordinates upstream.
- **Ladders are parity-placed, never authored.** A room authoring an element into
  its floor's ladder section is an authoring error, caught when the room is
  written.
- **One uniform cell.** Any code branching on a 2×1-vs-1×1 footprint is stale
  M4-draft logic to remove, not a pattern to extend (until larger rooms exist,
  §7).
- **Costs are multi-resource.** No code may assume scrap-only spend; prices are
  resource bundles (§4.2).
- All existing §10 invariants (one pipeline, one validator, water conservation,
  class-cache import, tower-fixed respawn, tilt parenting) still hold.
