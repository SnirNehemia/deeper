# PLAYTEST_LOG.md — DEEPER

*One entry per playtest. Snir fills the feel notes; design chat turns them into tuning changes; Claude Code records what was changed. Newest entries on top.*

---

## Template (copy for each playtest)

### YYYY-MM-DD — Build: (milestone / commit)
**Players:** (solo / 2P / who)
**What was played:** (e.g., M1 sandbox — drove shore to basin, swapped helm)

**Feel notes (raw, in player words):**
-

**Top 3 problems (ranked):**
1.
2.
3.

**Surprises / fun moments:**
-

**Tuning changes made afterward (Claude Code fills in):**
- (config value: old → new, reason)

**Verdict:** (keep going / change direction on X / re-test same build)

---

## Entries

### 2026-06-15 — Milestone 5 build complete, awaiting playtest
**Players:** (pending)
**What was played:** (pending — Modules A/B/C built and headless-tested, not
yet played)

Build ready for Snir's checkpoint per MILESTONE_5.md's "Verify by playing"
steps 1-7 / STATUS.md's M5 verify section: severity-scaled breaches from bites
and rams, fish/wreck HP (torpedo one-shots a fish, bullet needs a ~5-burst,
flinch/flash on non-lethal hits), conning-tower Hull station (slow remote
auto-patch, range 4), and two hunter fish at the basin pillars that chase
across open water vs. the territorial cave/third-pillar fish.

**Feel notes (raw, in player words):**
- (pending)

**Top 3 problems (ranked):**
1.
2.
3.

**Surprises / fun moments:**
-

**Tuning changes made afterward (Claude Code fills in):**
- (pending)

**Verdict:** awaiting playtest

---

### 2026-06-10 — Milestone 2 playtest
**Players:** solo
**What was played:** M2 - breaches, gun and first fish

**Feel notes (raw, in player words):**

 - the map feels a little empty, I think later on we will make swarm of fish instead of single one here and there.

 - it was good overall, I have some issues I will elaborate about here

**Top problems:**
1. make it so when hit, there is a breach, and it starts leaking water inside slowly, it gets faster as there are more breaches.

2. heavier hits makes more breaches

3. add a little "wall step" at each room (like the one connected to the ceiling) - so that when there is a breach, the room slowly gets filled with water and when the it gets higher than the step, it leaks to the adjacent rooms.

4. make players move slower even if there is a small amount of water in the room - this slow them down only if they touch the water (if they can jump above it, they move faster)

5. if a player starts to fix a breach, the bar remains there (so he can start repair it, go out for air and then return from where hw left off.

6. the gun has currently 3 discrete aims. make it continuous, controlled by a/d or w/s, depending if the gun is on vertical wall (like it is currently - here use w/s to aim) or horizontal one.

7. make torpedo rate faster by 20%

8. both gun and breaches does not tilt with the sub - fix it.

**Surprises / fun moments:**
 - the breaches fix is pretty fun and the fish that go over the sub (which I first thought was a bug) gives a 3d feeling (as if the fish is between the camera and the sub) and may make the player move so to get the fish in the gun's range

**Tuning changes made afterward (Claude Code fills in):**
All 8 issues implemented 2026-06-11 (commits "M2 polish …"). Clarified 4 ambiguous points with Snir first (see below).
1. **Breach leak tiers** — replaced the continuous speed→leak curve with one breach per hit at a discrete tier: small `1/90`s (light hit, ≥2 m/s), medium `1/45`s (≥3.5 m/s), big `1/20`s (full ram, ≥5 m/s). Multiple breaches still stack, so total inflow grows with count. *(Snir chose "1 breach per hit, count-driven tiers" over "more breach points per hit".)*
2. **Heavier hits** — folded into #1 (bigger tier, not more points).
3. **Door sill / overflow** — new `door_sill_m = 0.5` (knee height, chosen by Snir). Water pools in a room and only spills to a neighbour once it clears the sill; the ladder→conning opening uses a near-full `0.95` sill so the tower floods only when the middle room is full.
4. **Feet-touch slowdown** — movement now slows whenever the crew's *feet* touch water (any depth); jumping clear restores full speed. Weak-jump stays tied to waist-deep so you can still hop out of a puddle. *(Snir: "feet touch = slow".)*
5. **Persistent repair** — removed the reset-on-release. `repair_progress` now stays on the breach; leave for air and resume, or a second crew can take over. (Reverses the earlier "no partial credit" call.)
6. **Continuous gun aim** — W/S now sweep the barrel at `aim_speed_deg = 75`/s and it holds its angle; A/D ignored (vertical bow mount). Cone widened `45°→60°` (Snir's tweak).
7. **Torpedo rate +20%** — `fire_cooldown 1.2 → 1.0`s.
8. **Tilt fix** — breaches and the gun barrel are now drawn under the hull visual, so they pitch with the sub. Torpedoes launch along the tilted barrel line.

**Follow-up refinements (2026-06-11, same playtest, second pass):**
1. **Respawn at the conning tower** — drowning respawn moved from the helm room to the conning-tower deck (safest, last-to-flood spot).
2. **Physical door steps** — a low lip (`DOOR_STEP_H = 0.3 m`) on the floor at each doorway; crew now do a small hop to cross between rooms. (Separate from the abstract water lip in #5.)
3. **Breach severity is colour + size coded** — small = yellow & small, medium = orange, big = red & large, so the crew can see which leak to patch first.
4. **Jump shrinks only in deep water** — confirmed the jump only weakens once water covers more than half the crew's height (waist/centre underwater); a shallow puddle slows movement but not the jump. (Already in place from the first pass; locked with a test.)
5. **Lowered the water overflow lip 75%** — `door_sill_m 0.5 → 0.125`; water spreads to neighbours much sooner.

**Verdict:** changes implemented; re-test the same build (next playtest) for feel.

---

