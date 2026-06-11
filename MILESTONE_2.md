# MILESTONE_2.md — Water, Torpedoes, and First Blood

*Brief for Claude Code. Read CLAUDE.md first (developer context, build discipline, git rules), then STATUS.md (architecture & how-to-extend notes — stations, per-room state, GameFeel, layers). This is a feature-sized chunk: decompose into internal steps, headless-check after each, commit per working step.*

## Goal
The sub can now get hurt, flood, and die — and fight back. Terrain impacts breach the hull and rooms fill with water; crew patch breaches under pressure and can drown trying; too much water imploses the sub. A bow torpedo turret (second station) lets the crew kill 2–3 territorial fish guarding the deep parts of the Shore Shelf map. This milestone exists to answer: *is running between stations while water rises actually fun?* (This is the MVP's core bet — see design doc §12.)

All new numbers below are **starting values** and live in `GameFeel` (extend the existing autoload). Expect heavy tuning after the playtest.

## Spec

### 1. Hull damage & breaches (collision)
- Terrain impacts breach the hull, **scaling with impact speed** (settled in DECISIONS):
  - Below **2 m/s** impact speed: free, no damage (gentle docking/bumping never punishes).
  - Above that: spawn a breach in the room nearest the impact point. **Leak rate scales with impact speed** — a moderate bump makes a slow drip, ramming at full speed (6 m/s) makes a gusher.
  - Suggested leak rates: slowest breach floods its room in ~90s; worst single breach floods it in ~20s. Multiple breaches stack.
- A breach is a visible point on the room wall: placeholder = white-orange spark/spray marker (the danger color from the art direction — don't reuse this hue elsewhere).
- Fish bites also create breaches (small, drip-tier) — see §6.

### 2. Water in rooms
- Per-room `water_level` (0–1), rendered as a flat blue rect rising from the room floor (clipped to the room rectangle). The conning area is a fourth "room" for water purposes.
- Water flows between connected rooms through the open hatch doorways and the ladder opening: simple equalizing flow rate, no fluid sim (design doc §5.3). Suggested: connected rooms equalize noticeably within ~10–15s.
- **Water is weight:** total water adds downward force to the sub, scaling with fill. A half-flooded sub should feel sluggish climbing; a nearly full one sinks even at full vertical thrust. One tunable curve/number in `GameFeel`.
- **Flooded stations go offline:** when a room's water rises above seat height (~60%), its station ejects the occupant and can't be entered until the level drops. Yes — this means a flooded helm room leaves the sub adrift. That's the drama.
- Crew in water: movement dampened (suggested: ~50% run speed, weak jump) while submerged above the waist.

### 3. Repair
- Stand at a breach + **hold `use` for ~3s** → breach patched. Progress resets if released (no partial credit). Show a simple progress arc/bar at the breach.
- Infinite repairs, no kits (settled — patch kits arrive with the repair bay module, post-MVP).
- When **all** breaches in a room are patched, the room **auto-drains** (settled). Suggested drain: full room empties in ~12s.

### 4. Crew drowning & respawn
- A crew member whose head is underwater starts a **10s air timer** (small bubble gauge above their head; pauses and refills quickly when they surface). At zero: they drown — body pops/fades (keep it cartoon-cute, not grim).
- Respawn at the **helm room** after **7s**. While dead, that player gets a simple "respawning…" countdown. No revive mechanic (settled).
- 10s of air is deliberate: it's *just* enough to finish one 3s repair underwater if you commit early. Preserve that gamble when tuning.

### 5. Implosion & reset (lose condition)
- When **total water across all rooms crosses ~70%** of combined room volume: implosion.
- Implosion moment: brief crunch — screen shake, hull placeholder crumples/flashes, fade to dark (~1.5s total). No game-over menu.
- Then reset: sub back at the dock floating at the surface, water cleared, breaches cleared, both crew respawned aboard, fish back in their territories. Depth meter back to 0. Go again.

### 6. Turret station (torpedoes)
- Second station, built on the existing `Station` base (see STATUS architecture notes). Gunner seat in the **middle flex room**; the tube is **bow-mounted** next to the helm.
- **Arc:** forward cone only — suggested ±45° around the sub's forward horizontal. The gunner's move vector aims within the cone (visible placeholder barrel/aim line); `use` fires.
- **Torpedoes: slow and weighty**, like the sub. Suggested: ~10 m/s, fire every ~1.2s, **infinite ammo** (pure feel test this milestone). Travel straight, small placeholder trail.
- Torpedo hits terrain → small harmless puff. Torpedoes do **not** damage the own hull in M2 (avoid friendly-fire frustration while feel is unproven; revisit later).
- Note the cooperation this creates: a bow cone means the helm must *point the sub* at threats — steering is part of aiming. Don't widen the arc to "fix" that; it's the point.

### 7. Enemy: territorial fish
- **2–3 small fish with distinct territories** (settled): one guarding the **cave mouth**, the rest around the **basin rock pillars**. Placeholder: chunky colored fish shape with a big eye, ~1m long.
- **Territorial behavior** (DECISIONS: small fauna territorial): idles/patrols inside its territory radius (suggested ~10m). If the sub enters: chases and bites. If the sub leaves the territory: breaks off and swims home. Avoidable by careful piloting — that's a valid strategy.
- **Bite:** lunges at the hull on contact, creating a **small drip-tier breach** at the bite point, then circles for another pass (suggested ~3s between bites per fish).
- **One torpedo hit kills** (settled — turret should feel powerful). Death: cartoon pop + a few bubbles, fish gone until reset.
- Keep AI dumb: distance checks + states (idle / chase / bite / return). No pathfinding needed in open water; it's fine if fish can't enter the cave interior.

### 8. Map & reward beat
- Reuse the Shore Shelf map. Place a small **glowing marker** (placeholder lamp/star) inside the existing cave — no pickup logic, it just makes *arriving* feel like something. Clearing the cave-mouth fish and slipping inside is the milestone's victory beat.

### 9. HUD additions
- Keep the depth meter. Add a **breach alert**: when a new breach opens, a brief screen-edge flash plus a flashing warning marker anchored to the breach itself (visible through the cutaway). No per-room gauges — the rising water *is* the gauge (settled: readable in-world, alert for the moment of impact).

## Build plan — strict module order (for Claude Code)
Implement in exactly this order. Each module ends with: headless test green → full existing suite green → commit. Never start the next module on a broken state. Dependency logic: the water model is the spine (A); everything that *creates* water (C, G→H) or *reacts* to it (B, D, E, F) hangs off it; the turret (G) is independent and deliberately placed late as a buffer — if the schedule slips, G+H can split into a follow-up without leaving anything half-built.

### Module A — Water model core (data only, no visuals)
- Per-room `water_level` (0–1) state on `Sub` (rooms + conning area = 4 cells; room rectangles already exist as geometry consts in `sub.gd`).
- Equalizing flow between rooms connected by open hatch doorways / the ladder opening; flow rate in `GameFeel`.
- Water-as-weight: downward force on the sub scaling with total fill (one curve/number in `GameFeel`). Hook into the existing buoyancy path; dry sandboxes/tests stay unaffected.
- New `GameFeel.water` block: flow rate, weight curve, drain rate, leak-rate range (used by C), seat-height threshold (used by B).
- **Test:** `tests/test_water.tscn` — set levels directly, tick, assert equalization direction/speed and weight force. **Commit:** `water model core`.

### Module B — Water rendering + crew/station reaction
- Blue rect per room rising from the floor, clipped to the room rectangle (colors via `PlaceholderArt`).
- Crew submerged above the waist: ~50% run speed, weak jump (values in `GameFeel.crew`).
- Station offline rule: room water above seat height (~60%) ejects the occupant and blocks entry until it drops (implement on the `Station` base so helm and the future turret both inherit it).
- **Test:** extend `test_water` or add `test_station_flood` — assert eject + entry-block at threshold. **Commit:** `water visuals + flooded stations`. *(Visual sign-off via `tests/capture_*` screenshot tool.)*

### Module C — Breaches + collision damage
- Impact detection on the sub vs TERRAIN layer: compute impact speed; <2 m/s free, above it spawn a `Breach` (position on the wall of the nearest room, leak rate scaled by speed within the `GameFeel` range). Breaches feed water into Module A's model.
- Breach visual: white-orange spray marker at the point. HUD alert: screen-edge flash on new breach + flashing marker anchored to the breach (extend `depth_hud.gd` or a sibling CanvasLayer).
- Expose `Sub.spawn_breach(room, rate)` for tests and for fish bites later (H).
- **Test:** `tests/test_damage.tscn` — simulated impacts at several speeds: no breach below threshold, leak rate ordering above it. **Commit:** `collision breaches + alerts`.

### Module D — Repair + auto-drain
- Crew `use` held within range of a breach: 3s progress (resets on release), progress arc at the breach, breach removed on completion.
- Room with zero breaches auto-drains at `GameFeel` drain rate.
- **Test:** `tests/test_repair.tscn` — hold/release/hold sequences, patch completes, drain empties the room. **Commit:** `repair + auto-drain`.

### Module E — Drowning & respawn
- Per-crew 10s air timer while head is underwater (bubble gauge above the head; quick refill on surfacing).
- At zero: cartoon pop, body removed; 7s "respawning…" countdown for that player; respawn standing in the helm room. Input for the dead player is ignored except nothing-to-do; the other player is untouched.
- **Test:** `tests/test_drowning.tscn` — submerge a crew, assert timer → death → respawn position/timing. **Commit:** `drowning + respawn`.

### Module F — Implosion & reset
- Watch total water vs ~70% of combined volume → implosion sequence (~1.5s: shake, hull flash/crumple, fade) → full reset: sub at dock surface float, water/breaches cleared, crew aboard, depth 0. (Fish reset joins in Module H.)
- Implement reset as one `world.gd`-level routine so future death penalties reuse it.
- **Test:** `tests/test_implosion.tscn` — force water past threshold headlessly, assert reset state. **Commit:** `implosion + reset`. *(Milestone is feel-testable from here even if time runs short.)*

### Module G — Turret station + torpedoes
- `TurretStation` subclassing `Station` (per the STATUS extension notes): gunner seat in the middle flex room, bow-mounted tube visual by the helm.
- Aim: occupant's move vector sweeps a ±45° forward cone (visible barrel/aim line); `use` fires. Torpedo: ~10 m/s straight, ~1.2s cooldown, infinite ammo, small trail; terrain hit = harmless puff; ignores own hull. New `GameFeel.turret` block.
- New collision layer for projectiles in `collision_layers.gd` (named, never magic numbers).
- **Test:** `tests/test_turret.tscn` — enter/exit, cone clamping, fire cooldown, torpedo despawn on terrain. **Commit:** `turret station + torpedoes`.

### Module H — Territorial fish
- `Fish` scene (placeholder chunky fish, ~1m): state machine idle/patrol → chase (sub inside ~10m territory) → bite (contact lunge, calls `spawn_breach` drip-tier, ~3s between bites) → return home when the sub leaves. One torpedo hit = pop + bubbles, removed until reset.
- Place 3: one at the cave mouth, two at the basin pillars (in `shore_shelf.gd` or `world.gd`). Wire fish respawn into Module F's reset.
- **Test:** `tests/test_fish.tscn` — state transitions by distance, bite spawns a breach, torpedo kill. **Commit:** `territorial fish`.

### Module I — Integration & close-out
- Glowing marker inside the cave (placeholder lamp, no logic).
- Full suite + all M1 tests green; manual M1 regression pass (run/climb/helm/ride-along).
- Update STATUS.md (file map, known issues, next step), append new decisions to DECISIONS.md, write Snir's verify-by-playing steps, commit + push.

## Acceptance criteria
- [ ] Ramming terrain above ~2 m/s breaches the nearest room; harder hits leak visibly faster; sub-2 m/s bumps never damage.
- [ ] Water rises in breached rooms, flows through open hatches to neighbors, and visibly weighs the sub down.
- [ ] A station whose room floods past seat height ejects its occupant and refuses entry until drained.
- [ ] Holding `use` at a breach for ~3s patches it; a fully patched room auto-drains.
- [ ] A submerged crew member drowns after ~10s and respawns at the helm room ~7s later; the other player can keep playing throughout.
- [ ] At ~70% total water: crunch-and-fade implosion, then a clean reset at the dock (water, breaches, crew, fish all restored).
- [ ] Either player can take the turret seat, aim within the bow cone, and fire slow torpedoes with infinite ammo; one hit kills a fish.
- [ ] 2–3 fish hold distinct territories (cave mouth + pillars), chase only inside them, bite breaches the hull, and they disengage when you flee.
- [ ] New breach triggers the screen-edge flash + anchored warning marker.
- [ ] All M1 acceptance criteria still pass (movement, helm, ride-along, depth meter); full headless test suite green, including new tests for water/damage/turret/fish.

## Out of scope (do not build)
Salvage/pickups, oxygen scrubber system (the air timer is per-crew-in-water only), patch kits, pump station, fire/electrical, large hunting fauna, more enemy types, ammo limits, engine functionality, sound, dry dock/meta, new maps, gamepads, any art beyond labeled placeholders.

## Verify by playing (for Snir)
1. Launch: `"GODOT_PATH" --path .`
2. **Crash test:** drive gently against the shallows floor — nothing should happen. Then ram a rock pillar at full speed: warning flash, a spraying breach, water rising in that room.
3. **Repair drama:** let one room half-flood, then have the off-helm player wade in and hold `use` at the breach (~3s). Watch the room drain once it's patched. Notice the sub flying heavier while flooded.
4. **Drown on purpose:** stand in a flooding room until the bubble gauge empties. You should pop, then respawn at the helm room ~7s later while your partner keeps playing.
5. **Implode on purpose:** take several hard hits and let the water win. Expect a crunchy fade and a clean restart at the dock.
6. **The fight:** P1 helms toward the basin pillars; P2 takes the turret (middle room). The fish should ignore you until you're close, then chase and bite. Torpedoes are slow — P1 must point the bow, P2 leads the shot. One hit per fish.
7. **Victory beat:** kill the cave-mouth fish and slide the sub into the cave to the glowing marker. Then report the *feel*: Is rising water scary or annoying? Is 3s repair too long under pressure? Do torpedoes feel chunky or just sluggish? Is the fish fight fun or a chore? → answers go to PLAYTEST_LOG.md and into `GameFeel`.
