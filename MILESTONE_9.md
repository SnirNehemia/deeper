# MILESTONE 9 — stub (the three named fish + economy balance)

*Created at M8 close-out (2026-06-25), per `MILESTONE_8.md`'s session-end
ritual. This is a stub, not a built brief — plan back from `STATUS.md` →
`DECISIONS.md` → `MILESTONE_8.md` (the enemy spine + the add-enemy skill it
produced) before building.*

## What M8 left for M9

M8 shipped pure infrastructure: the `EnemyDef`/`EnemyClassStats` spine, ram
knockback, grab-tug, ranged attacks + difficulty classes, the color-currency
economy, and the `add-deeper-enemy` skill (validated by re-deriving the
reference fish from it). It shipped **zero new species** on purpose — M9 is
where the spine gets spent.

## Headline content: the three named fish

`MILESTONE_8.md`'s "Out of scope" section names them; this is where they get
built, **each authored through the `add-deeper-enemy` skill** (not by hand —
that's the skill's whole point, and a second real-world use after its
validation pass is the best test of whether it actually holds up):

- **Sand lurker** — territorial, ambush-flavored (confirm AI pattern;
  territorial is the existing behavior closest to "waits, then strikes").
- **Silver school** — the M9 flocking/swarm behavior Snir has flagged
  before (`DECISIONS.md` notes "the school-of-fish flocking behavior is M9
  content"). **This is likely a new AI pattern**, which the skill's §4
  explicitly routes to hand-coding, not the menu — budget real design time
  for it, not just a `.tres` fill.
- **Armored grey tank** — heavy, high-`room_weight` (Heavy grab-tug band by
  design), likely a high-hp/low-speed profile. Confirm whether "armored"
  implies a damage-reduction mechanic (which would need a `NOVEL_HANDCODE`
  elite ability or a base-trait field the skill doesn't have yet — if so,
  that's a skill/schema gap to flag, not silently bypass).

## The economy balance pass (M8 Module 4b's deferred half)

`MILESTONE_8.md` Module 4b explicitly deferred real balance: room prices are
flat-and-random (`GameFeel.currency.flat_room_price`/`room_price_colors`)
because the color faucet (which species drop which colors) didn't exist yet.
M9 is where it does — re-visit:
- whether `ROOM_SYSTEM.md` §6 prices should gate on a *specific* currency
  color per room (the soft-gate idea Snir's "every room costs 4 random
  colors" sidestepped at M8) now that three more colors are real and
  droppable;
- whether the flat 4-unit price should vary by room now that there's a real
  color economy to balance against;
- `gold_drop` tuning now that gold is actually droppable by something.

## Headroom

The milestone doc flags "headroom for 1-2 more species" — don't force it;
three named fish + the balance pass is already a full milestone. If the
skill proves itself smoothly on the first two, a third/fourth species is a
cheap bonus, not a requirement.

## Open items to resolve with Snir before building (do not guess)

1. **Silver school's flocking AI** — confirm the actual flocking algorithm
   (boids-style separation/alignment/cohesion, or something simpler) and
   whether it's per-fish individual `Fish` nodes or a different entity
   entirely. This is a real new-behavior design call, not a tuning knob.
2. **Armored tank's "armor"** — confirm whether it's just high `hp`/
   `room_weight` (no new mechanic needed) or a real damage-reduction trait
   (needs schema/skill discussion).
3. **Re-confirm `gold`/currency naming** (`DECISIONS.md` M8 Module 4 flagged
   this as "implemented, not re-confirmed") now that real species are
   landing and the name is about to appear in actual gameplay text.
