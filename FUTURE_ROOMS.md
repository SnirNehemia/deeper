# FUTURE_ROOMS.md — Parked room briefs (not scheduled into a milestone yet)

*Holding pen for designed-but-unscheduled room types. Each entry is a room brief
captured verbatim from Snir, ready to be lifted into a milestone doc when its
milestone is scheduled. **Nothing here is in scope for M7** (the telescope slice).
Read order before building any of these: `CLAUDE.md` → `STATUS.md` →
`DECISIONS.md` → `MODULAR_SUB_IMPLEMENTATION.md` → `ROOM_SYSTEM.md` → this file.*

*Authored 2026-06-20. Three rooms parked out of M7 to keep the telescope slice
tight (one new room only). Two of the three were proposed alongside content that
**already lives in `ROOM_SYSTEM.md` §6** — those overlaps are flagged inline so we
don't double-spec.*

---

## Scope note — why these are parked, not in M7

M7 ("Hands on the Deep") is a deliberately tight one-new-room slice: ship the
telescope, slim the base sub, demote the claw. Adding any of the rooms below would
turn it into a much larger milestone (two of them are weapons/sensors with their
own multi-branch upgrade trees and, in the sonar's case, new enemy AI). Per the
tight-milestone-slice principle (`DECISIONS.md`), they wait for their own
milestones. Suggested homes are noted per room; **these are suggestions, not
scheduled commitments** — confirm at the relevant milestone kickoff.

---

## Room 1 — Heavy torpedo room

> **Status: already in `ROOM_SYSTEM.md` §6 (lines ~232–248) as an authored
> purchasable room.** The spec below (captured from Snir 2026-06-20) is
> effectively identical to canon. This is **not a new room to design** — it is an
> already-authored catalog entry awaiting a *build* milestone. The only deltas vs.
> §6 are minor and folded in below (the guided path's sub-upgrades are spelled out
> here in full). When scheduled, build from the §6 entry; this is the design-intent
> reference.

**Suggested home: an arsenal-expansion milestone** (the natural "weapons get
deeper" slice — alongside the bullet/base-gun branches already in §6). It is a
substantial room on its own: two upgrade paths, ~7 nodes, post-launch guidance,
two-stage detonation.

**Brief (verbatim):**

Heavy torpedo `[6 s_ca]`:
Description: Fires a torpedo, going in a straight path and explode dealing area
damage in 4 meter radius when the player presses 'use' again.
Speed: 2 m/s
Damage: 10 hp
Rate: 1 per 3 seconds (and only after the previous one exploded)
Element placement: t3/b3 — depending if it is the top-most or bottom-most room.
Upgrades: two paths:

- **Scattered torpedo** `[4 m_ca]`: first 'use' explode it to 3 minibombs going
  in all directions. The second one explodes them too. Each one is 10 hp, 2 meters
  radius.
  - More secondary bombs: 2 more `[4 m_ca]`, then 2 more `[2 l_ca]`
  - Bigger explosion: 4 meters `[4 m_ca]`, then 6 meters `[6 m_ca]`
- **Guided torpedo** `[4 m_ca]`: control the ammunition after it leaves the sub
  (using left/right to rotate its direction), press 'use' to detonate it in an
  explosion of 5 meters radius.
  - Faster torpedo: 4 m/s `[4 m_ca]`, then 8 m/s `[2 l_ca]`
  - Add acceleration / slow down using up/down keys `[4 l_ca]`
  - More damage: 15 hp `[4 m_ca]`, 30 hp `[4 m_ca, 2 l_ca]`

**Flags for the build milestone:**
- The `t3`/`b3` "depends if top-most or bottom-most room" placement is a new
  pattern — the tube mounts on the room's *outer* horizontal face. Confirm the
  section model expresses "mount on the ceiling if this is the top room, else the
  floor" cleanly, or whether it's authored per-placement.
- Post-launch guidance (steer the live round with left/right, brake/accelerate
  with up/down) means the weapon **owns player input after firing** — a control
  hand-off the bullet/base gun don't have. This is the room's real hand-coded
  mechanic; budget for it.
- Two-stage detonation (fire → travel → second 'use' detonates) is also new
  versus fire-and-forget weapons.

---

## Room 2 — Sonar room

> **Status: genuinely new. Not in `ROOM_SYSTEM.md` §6.** Needs a full design pass +
> a new enemy-AI behaviour when scheduled.

**Suggested home: a "sensing / read-the-deep" milestone** — it pairs naturally
with the floodlight/darkness model and is a strong prerequisite for any
depth/darkness work (you can't dive blind into lightless zones without it). Note
it also seeds the later **elemental "Echo Ring" purple variant**, which keys off a
sonar-pulse trigger.

**Brief (verbatim):**

Sonar room:
In the depth there is no light, so eventually sonar is a must. When the player
press 'use' it expands a bright blue (but relatively faint) circle from the room.
When it hits anything (a wall, an item, or an enemy), it leaves a bright blue
contour on it for a second or so.
Some enemies locate the sub based on that signal.
Rate: 1 pulse per 2 seconds.
Upgrade make the blue contour stay longer.

**Flags for the build milestone:**
- **"Some enemies locate the sub based on that signal" is new fauna AI**, not a
  room mechanic — it's a detection path on the fish (a hunter-style aggro trigger
  fired by a pulse, akin to the M5 `is_hunter` toggle). That AI work is the real
  cost here and should be its own module, not folded into the room build. It also
  creates a **risk/reward** tension (ping to see, but pinging draws hunters) that
  is the room's whole design — worth protecting in the brief.
- The expanding-circle + contour-on-contact is a rendering/visibility mechanic;
  confirm it reads against placeholder art before the art pass, or whether sonar
  should wait for art like the elemental update did.
- Upgrade tree is trivial so far (one node: contour persists longer). Fine as a
  linear stub; may want a second node (pulse radius or rate) for a real fork.

---

## Room 3 — Claw snake room (snake-like multi-arm)

> **Status: genuinely new. Not in `ROOM_SYSTEM.md` §6.** It is a **third collector**
> alongside the telescope (base) and claw (buyable), so it should land *after* M7
> has settled the base-vs-buyable collector economy — dropping a third grab-tool
> mid-reshuffle would muddy the contrast M7 is establishing.

**Suggested home: a later collector/utility milestone**, once the telescope/claw
split has been playtested and the "what distinguishes each collector" question is
answered. A snake-claw is the high-skill-ceiling third option (reach + routing
around obstacles), which only reads well once the two simpler collectors are
understood.

**Brief (verbatim):**

Claw snake room (snake-like multi-arm) `[-]`:
Description: allow the player to grab items from outside the sub and get them
inside using a multi-arm "snake-like" claw. Press 'use' to start extending the arm
in a straight line away from the sub. Press it again to turn in the direction
pressed (the player presses w/a/s/d simultaneously) in a snake-like movement. If
the end of the arm (the claw) meets an item, it grabs it (and continues moving). If
the snake reaches its maximal length or collides with itself, it returns to the
sub.
Elements placement: dropping hatch at s2 and claw base at b3 (no need to mention
the station at s3 — it's the default option). The claw capacity is 4 volume units.
Upgrades:
The claw capacity gets to 6 volume units `[4 sc]`

**Flags for the build milestone:**
- The brief marks it `[-]` (a starting room). That **conflicts with the M7 base
  loadout** (telescope + control + bullet, no third collector). It cannot be a
  starting room as written without re-opening M7's base-sub decision. When
  scheduled, decide: purchasable room (most likely), or a base-loadout change of
  its own. **Do not assume `[-]` holds.**
- Snake routing (grow in a line, turn on input, self-collision check, retract on
  max-length-or-self-hit, grab-on-contact-and-continue) is a meaningfully harder
  mechanic than the telescope or claw — it's path-tracking, not a jointed rig.
  Budget it as the milestone's headline mechanic, not a side room.
- "Grab on contact and continue" makes this the one collector that *does*
  auto-grab on touch (the telescope explicitly does not). That's a fine
  distinction but note it so the three collectors stay legibly different:
  telescope = aim/extend/**Q-grab**/auto-store; claw = jointed/**Q-grab**/ferry;
  snake = route/**auto-grab-on-contact**/auto-return.

---

## Cross-cutting note — three collectors, keep them distinct

If all of these ship eventually, DEEPER will have **three** outside-grab rooms
(claw, telescope, snake) plus storage. That's fine only if each has a clear
identity and a clear reason to choose it. Current read:

| Collector | Reach | Control feel | Grab | Storage | Niche |
|---|---|---|---|---|---|
| **Claw** (buyable, M7) | Short, wide swing | Fiddly two-joint, two-player | Q | Ferry to own pen (4) | Hands-on, co-op |
| **Telescope** (base, M7) | Long, straight (~8m) | Clean aim/extend | Q | Auto-deposit to cages (12) | Solo-runnable default |
| **Snake** (parked) | Longest, routable | High skill, route around terrain | Auto on contact | (capacity 4→6) | Reach awkward spots |

Before scheduling the snake, confirm it isn't just "telescope but longer" — its
justification is *routing around obstacles the straight telescope can't reach*. If
that routing isn't fun in practice, the room has no niche.
