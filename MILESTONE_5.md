# MILESTONE_5.md — Teeth & Consequences (Damage = Breaches, the Hunt, and a Reason to Shoot Back)

*Brief for Claude Code. Read CLAUDE.md first (developer context, build discipline, git rules), then STATUS.md (architecture & extension notes — stations, per-room water, breach/patch system, GameFeel, layers, the SubLayout → SubGeometry → Sub pipeline) and DECISIONS.md. This is a feature-sized chunk: decompose into the 3 modules below in order, headless-check after each, full suite green before the next, commit per working step.*

## Goal
Hits stop being instant kills, and **damage to the sub means water** — there is no separate hull-HP number anywhere. A bullet, torpedo, fish bite, or hard ram **spawns a breach** in the room it hits, scaled in severity by how hard the hit was, and that breach floods exactly like an M2 hull breach. The single death path stays **flooding → implosion** (M2, unchanged). On the enemy side, fish and wrecks gain HP so the guns you spent all of M4 customizing finally have stakes — a torpedo still one-shots a fish, but the bullet gun becomes a chip-stream. And the existing fish gain the **territorial-vs-hunter aggression split** the design doc has always specified (§7), reusing the same fish art — so some threats are avoidable and some commit to chasing you across the map.

This milestone answers: *once weapons take a few hits to kill, the sub can be flooded by teeth and rams (not just terrain), and some fauna actively hunt you, is the combat tense and fair — or fiddly and punishing?*

All new numbers are **starting values** in `GameFeel` (extend the autoload). Expect heavy tuning — wire every constant through `GameFeel`, nothing hardcoded in logic.

## The core model (read this first — it's the whole milestone)
Settled with Snir 2026-06-15, and it is deliberately *smaller* than a hull-HP system — it reuses the breach/water spine the game already has:
- **No sub integrity pool. No second death path. No hull-failure loss.** Those were considered and rejected. The sub's only health is its water level; the only loss is implosion (M2).
- **Every hit on the sub = a breach.** One front door, `Sub.breach_from_hit(room, severity, world_point)`, spawns a breach in the struck room. Bites, rams, and (future) enemy projectiles all call it.
- **Severity scales flow rate, not a damage number.** A *bigger* breach lets water in *faster*; it is not a different mechanic, just a larger value on the same M2 breach. A light bite = a small fast-patchable leak; a full-speed ram or torpedo hit = a gushing breach. Severity maps to the breach's inflow rate via `GameFeel.breach.severity_*`.
- **Repair has two speeds now:** crew **hand-patch at the breach** (M2, fast — unchanged) and a new **conning-tower Hull station that auto-patches the nearest breach remotely, but slower**. Hand-patch always beats the tower; the tower is for solo/short-handed play and for keeping up while the crew is busy elsewhere.

This is the spine. Modules A–C build exactly this and nothing more.

## Scope discipline (read before building)
This is a **tight slice (3 modules)**. Hard guardrails:
- **No hull integrity / HP pool on the sub.** Damage is breaches, full stop. If you find yourself adding a `hull_integrity` float, you've left the spec.
- **No new fauna species.** Reuse `fish.gd` / the existing fish scene. The hunter behaviour is a *new state path on the same fish*, toggled by a per-fish `is_hunter` flag — not a new scene.
- **No new weapons.** The Turret Room (torpedo) and Bullet Room (bullet) from M4 are the whole arsenal. They just deal HP damage to enemies now instead of instant-killing.
- **No enemy projectiles built this milestone.** `breach_from_hit` is wired as the front door a future enemy projectile *would* call, but no enemy fires anything in M5.
- **No grapplers, chargers, or bosses.** Parked for M6+.
- **No zone/map/depth-pressure work.** "The Descent" (depth zones, hull pressure rating, palette shifts, Krita map pipeline) is its own future milestone. M5 happens entirely on the existing Shore Shelf map.

## Settled design points (append to DECISIONS.md at close-out)
- Direction chosen (2026-06-15, Snir): **Teeth & Consequences** — combat depth — over "The Descent" (depth zones), which is parked as its own future milestone.
- **Damage-to-sub model (2026-06-15, Snir — supersedes the earlier "hull HP" idea):** the sub has **no integrity pool**. A hit spawns a breach in the struck room; **bigger/harder hit = bigger breach = faster water inflow**. Flooding→implosion remains the only sub death path. This collapses combat damage onto the existing M2 breach/water system rather than adding a parallel model.
- **Repair (2026-06-15, Snir):** crew hand-patching at the breach stays the fast path (M2). The conning-tower **Hull station auto-patches the nearest breach within ~4 rooms, slower than a hand-patch.** Both coexist; hand-patch is always faster. Resolves the long-open "what lives in the conning tower?" question (DECISIONS.md): the Hull station does.
- **Enemy HP (2026-06-15, Snir):** fish HP = 5, torpedo = 5, bullet = 1, so **one torpedo still one-shots a fish** (M2 acceptance preserved) while the bullet gun needs a ~5-round burst — making the two weapons feel different. Wrecks get HP too (one torpedo still cracks, bullet burst also works).
- **Aggression split (design doc §7):** small fauna territorial (attacks only inside its territory, breaks off when the sub leaves — current M2 behaviour, unchanged); a subset are **hunters** that chase the sub across the map once detected and only give up after a sustained out-of-range timer. Same fish art; toggled by `is_hunter`.

## Spec

### Module A — Damage is breaches (the spine)
One front door turns every hit into a severity-scaled breach; existing water/implosion does the rest. Nothing here invents a new health concept.
- Add `Sub.breach_from_hit(room, severity: float, world_point: Vector2)`:
  - spawns a breach in `room` using the existing M2 breach system, with **inflow rate scaled by `severity`** (`GameFeel.breach.severity_to_inflow`, e.g. severity 1 → light leak, severity 5 → gush). It is the *same* breach object the player already patches — only the rate differs.
  - is the **single** entry point for all combat/impact damage to the sub.
- **Wire the existing sources through it:**
  - **Fish bite** (M2 already spawns a small breach on bite): route that through `breach_from_hit` with `GameFeel.breach.bite_severity` so a bite is a small-but-real leak. (Behaviour stays close to M2; this just unifies the path.)
  - **Hard terrain ram** (M2 speed-scaled collision breach): route through `breach_from_hit` with severity scaled by impact speed above the breach threshold (`GameFeel.breach.ram_severity_per_speed`). Gentle bumps still produce nothing; a full-speed rock ram is a gushing breach. Preserve the existing "below threshold = free" rule.
  - **(Forward hook, not fired this milestone):** `breach_from_hit` is the exact method a future enemy projectile will call. Leave it clean and public; build no enemy projectile now.
- **No integrity field, no hull-failure loss, no new death path.** Implosion (water ≥ threshold, M2) is untouched and remains the only way the sub goes down.
- **Feedback:** a brief flash/shake on the struck room scaled to severity (a bite is a flinch, a ram is a slam), so the player can tell *where* and *how hard* they were hit. Keep it legible.
- **Test:** `tests/test_water.tscn` (or extend the breach test) — `breach_from_hit` spawns a breach whose inflow scales with severity; a high-severity breach floods its room faster than a low-severity one; a bite produces a small breach, a full-speed ram a large one, a sub-threshold bump nothing; the breach is patchable by the normal M2 hand-patch; flooding still reaches implosion and triggers the unchanged `reset_run()`. **Commit:** `M5-A: damage = severity-scaled breaches (one front door, bites + rams routed through it)`.

### Module B — Enemy & wreck HP (weapons that matter)
Fish stop dying to a single graze; "one torpedo kills" stays true because torpedo damage = fish HP.
- `Fish` gains `hp: float` / `hp_max: float` (`GameFeel.fish.hp`, default 5) and `take_damage(amount, from_point)`:
  - subtracts HP, plays a **hit flinch** (brief flash + small knockback away from the hit), and
  - at HP ≤ 0 runs the existing M2 death (cartoon pop + bubbles, removed until reset).
- **Wire the weapons:** the torpedo hit path calls `take_damage(GameFeel.torpedo.damage = 5)` instead of instant-killing; the bullet calls `take_damage(GameFeel.bullet.damage = 1)`. A torpedo one-shots a 5-HP fish (M2 preserved); a bullet needs ~5 rounds — torpedo = heavy single, bullet = chip stream.
- **Wrecks** (M3 `Wreck`): give HP via the same `take_damage` so a wreck opens to either weapon — `GameFeel.wreck.hp` tuned so one torpedo still cracks it but a bullet burst also works. Keep the M3 loot-spill on death unchanged.
- **Test:** `tests/test_fish.tscn` extended — a fish survives 4 bullets and dies on the 5th; dies to one torpedo; flinches without dying on a non-lethal hit; a wreck opens via either weapon and still spills loot. **Commit:** `M5-B: enemy + wreck HP; weapons deal damage instead of instant-kill`.

### Module C — The conning-tower Hull station + the hunt
Two things: the remote repair station that gives the tower its job, and the hunter aggression path that makes all of the above matter. The hunt is placed at the very end as schedule buffer — A+B already deliver "combat can flood you and your guns now bite," so the milestone is feel-testable even if the hunt runs short.

**C1 — Hull station (remote auto-patch) in the conning tower.**
- Add a **Hull station** in the **conning tower** (the fixed top cell). A crew member takes the seat and holds `use` to **auto-patch the nearest active breach** to the sub, searching outward up to **`GameFeel.hull_station.range_rooms` (= 4)** rooms away through the room graph. It patches at `GameFeel.hull_station.patch_rate`, **slower than a crew hand-patch** at the breach — so the tower keeps you alive when short-handed, but a free pair of hands at the leak is always better.
  - When the current target breach is sealed, it moves to the next-nearest within range automatically. If no breach is within range, it idles.
  - Inherits the `Station` base flood-eject rule (a flooded tower ejects the occupant — rare, since the tower is the high point, and that's fine).
  - This is a *station to run to* (pillar 1) and a solo/short-handed lifeline (design doc §4 solo viability). It does **not** repair an integrity pool (there isn't one) — it only patches breaches, slower and at range.
- Update conning-tower seat usage so the tower is now a real station occupancy, not just a spawn point. A respawning crew member does not auto-occupy it.
- **Test:** `tests/test_hull_station.tscn` (or extend `test_water`) — occupying the tower and holding `use` patches the nearest breach over time and is **slower** than a hand-patch; after sealing one breach it retargets the next-nearest; a breach beyond 4 rooms is ignored; a flooded tower ejects the occupant. **Commit:** `M5-C1: conning-tower Hull station (slow remote breach auto-patch, range 4)`.

**C2 — Hunter fish (no new species).**
- `Fish` gains `is_hunter: bool` (placement data, default false → current territorial behaviour, unchanged). When true, the state machine gains a hunt path: once the sub enters `GameFeel.fish.hunter_detect_m` (suggested ~16m, larger than the territorial ~10m), the fish enters `hunt` and chases the sub **anywhere on the map** — no territory leash. It disengages only after the sub has been outside `hunter_lose_m` (~24m) for a sustained `hunter_lose_time` (~5s), then returns home. Same bite (→ `breach_from_hit`), same flinch, same HP — only the engagement rule differs.
- Keep the AI dumb: distance checks + states (`idle/patrol → hunt → bite → return`), no pathfinding. It's fine if hunters can't enter cave interiors — that makes the cave a safe pocket, which is good.
- Convert **1–2 existing Shore Shelf fish to hunters** via the placement flag in `shore_shelf.gd` / `world.gd`, leaving the rest territorial, so the map teaches both reads. Wire `is_hunter` reset into the existing fish-reset in `reset_run()`.
- **Test:** `tests/test_fish.tscn` gains hunter cases — a hunter chases past the territorial leash distance; gives up only after the sustained lose-timer; a territorial fish is unaffected by the new path. **Commit:** `M5-C2: hunter fish aggression path (reuses existing fish, is_hunter flag)`.

## Module order (build in this sequence)
- **A — Damage is breaches** (spine; everything assumes hits → breaches).
- **B — Enemy/wreck HP** (guns become meaningful).
- **C — Hull station + hunt** (the repair answer and the threat that exercises A+B; hunt is the schedule buffer, built last).

Each module: one small change → headless-check → **full suite green** → commit with a descriptive message. After adding any new `class_name` script, run `--headless --path . --import` once. Explain everything to Snir in game-behaviour terms; he doesn't read code.

## Out of scope (do not build)
A sub integrity/HP pool of any kind; a second death path / hull-failure loss; new fauna species; grapplers, chargers, latchers, bosses; enemy projectiles actually firing (only the `breach_from_hit` front door exists); per-room hull HP; depth zones, the shelf-edge plunge, hull pressure ratings, palette/darkness shifts, the Krita map pipeline; a repair-bay / patch-kit resource economy; per-room upgrade trees; ammo limits; oxygen scrubber; sound pass; gamepads/phone controllers; non-physical empty slots and the dock reachability warning (the two M4 cleanups — **re-parked**, since the 3-module slice no longer has room; note this in DECISIONS.md for a future milestone); any real art (labeled placeholders only). If a "while we're here" idea appears, check it against the design pillars and DECISIONS.md before building, and default to parking it.

## Acceptance criteria
- [ ] Every hit on the sub (bite, ram, future projectile) spawns a breach via one shared `breach_from_hit` front door — there is **no** integrity/HP field on the sub anywhere.
- [ ] A harder hit produces a faster-flowing breach; a light bite a slow one; a sub-threshold bump nothing. Breaches are patchable by the normal M2 hand-patch.
- [ ] Flooding→implosion remains the only sub death path and is otherwise unchanged.
- [ ] A torpedo one-shots a fish; a bullet takes a ~5-round burst; fish flinch on non-lethal hits. Wrecks open to either weapon and still spill loot.
- [ ] A crew member in the conning-tower Hull station holds `use` to auto-patch the nearest breach within 4 rooms, slower than a hand-patch, retargeting the next breach when one is sealed; a flooded tower ejects them.
- [ ] At least one fish is a hunter that chases the sub across the map and disengages only after a sustained out-of-range timer; at least one stays territorial and avoidable.
- [ ] All M1–M4 acceptance criteria still pass; full headless suite green, including the new breach-severity / HP / hull-station / hunter tests.
- [ ] Snir's checkpoint was run and feedback addressed; STATUS.md, DECISIONS.md, PLAYTEST_LOG.md updated; the conning-tower "what lives here?" open question is marked resolved (Hull station); the two re-parked M4 cleanups are noted for a future milestone.

## Verify by playing (for Snir)
1. Launch; play one normal run — it should feel like M4 (build, dive, loot, dock).
2. **Take damage on purpose.** Ram a rock at full speed: the struck room should spring a *gushing* breach (flash/shake there). Let a fish bite you: a *small* leak. Confirm the difference is readable — hard hit = water pouring in fast, light hit = a trickle.
3. **Lose to teeth, not terrain.** Stay off the rocks and let fish bites pile up while you fail to patch — the rooms should flood and eventually implode you, same as a terrain death. (There's no separate "hull broke" death — it's all water.)
4. **Two repair speeds.** Hand-patch a breach (fast, M2). Now leave a breach and send someone to the conning-tower Hull station instead — it should seal the nearest breach *slowly* from up there, then move to the next. Does the tower feel like a useful solo/short-handed lifeline without trivializing damage? Run the table: pilot, gunner, hand-patcher, tower — good "who's on what?!" scramble or one job too many?
5. **Feel the two guns differently.** Torpedo a fish — one shot, dead. Kill one with the bullet gun only — a burst, with the fish flinching each hit. Torpedo = heavy single; bullet = stream?
6. **Meet a hunter.** Drift near the converted hunter fish: instead of guarding a spot it should lock on and chase you across open water, peeling off only once you've been clear a few seconds. Exciting or annoying? Is the territorial/hunter difference readable in play, given they look the same?
7. Report the feel → PLAYTEST_LOG.md: Is combat tense or punishing? Does "damage = water" stay clear, or does it blur with terrain breaches? Is the tower station worth a seat? Does the hunter make the map scarier? Tune the `GameFeel.breach` / `GameFeel.fish` / `GameFeel.hull_station` numbers from there.
