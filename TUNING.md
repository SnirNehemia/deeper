# TUNING.md — where every game-feel number lives

This is a map, not a manual — each line below tells you which file/class owns
a group of tunable numbers and what they affect in-game. The numbers
themselves are commented in place in the code; this file exists so you (Snir)
can find the right knob without reading code to locate it.

**Everything in this file lives in one autoload: `autoload/game_feel.gd`**
(the `GameFeel` singleton), organized into one class per system. Open that
file and search for the class name below to find the actual numbers.

| System | Class in game_feel.gd | Governs |
|---|---|---|
| Crew movement | `CrewFeel` (`GameFeel.crew`) | Run speed/accel, jump height, ladder climb speed. Two presets: `weighty` (canon) / `snappy` (playtest comparison). |
| Sub driving | `SubFeel` (`GameFeel.sub`) | Sub top speed, spin-up/coast time, cosmetic pitch tilt, out-of-water gravity. |
| Flooding/water | `WaterFeel` (`GameFeel.water`) | Room flow/drain rates, breach leak tiers, repair time/range, door sill height, implosion threshold, air supply, respawn delay. |
| Hit damage spine | `BreachFeel` (`GameFeel.breach`) | Maps any hit's "severity" number to a flooding rate — the single dial all combat damage (bites, rams, the reel-minigame's miss-leak) ultimately runs through. |
| Enemy impact on the sub | `EnemyImpactFeel` (`GameFeel.enemy_impact`) | Ram knockback strength; the Light/Medium/Heavy weight bands and how hard each tugs the sub while held (`tug_force_scalar_medium`/`_heavy`). |
| **Reel-in minigame** | `ReelFeel` (`GameFeel.reel`) | The tug-rope timing game: sweep speed, green/yellow zone width vs. weight, the weight at which a catch becomes unlandable, progress per landed pull, miss-leak severity, finishing damage. See "Reel minigame" below. |
| Torpedo turret | `TurretFeel` (`GameFeel.turret`) | Torpedo speed/damage/cooldown, aim cone and sweep speed. |
| Bullet gun | `BulletFeel` (`GameFeel.bullet`) | Bullet speed/damage/cooldown — fast chip-damage alternative to the torpedo. |
| Floodlight | `FloodlightFeel` (`GameFeel.floodlight`) | Beam reach/rotate speed, cone shape, light falloff/brightness. |
| Fish AI | `FishFeel` (`GameFeel.fish`) | Territory radius, patrol/chase/hunt/return speeds, bite interval, hunter/chaser detection and give-up ranges. (Per-species HP/damage/weight is NOT here — see "Per-species data" below.) |
| Ranged enemy fire | `EnemyRangedFeel` (`GameFeel.enemy_ranged`) | Fire range, cooldown, projectile speed/lifetime, hit severity, and the cooldown multiplier an Elite's `ranged_spit` ability gets when "intensifying" an already-ranged species. Per-species ranged on/off is the `.tres`'s `ranged` flag, not here. |
| Wreck | `WreckFeel` (`GameFeel.wreck`) | Wreck hp. |
| Hull station (conning tower) | `HullStationFeel` (`GameFeel.hull_station`) | Remote-patch range and speed. |
| Salvage claw arm | `ClawFeel` (`GameFeel.claw`) | Arm segment lengths, joint sweep speeds/limits, grab radius, cage/storage capacity. |
| Dry dock economy | `DockFeel` (`GameFeel.dock`) | Slot prices and how they scale with slots owned / depth level. |
| Telescope arm | `TelescopeFeel` (`GameFeel.telescope`) | Reach, aim arc/speed, extend/retract speed, auto-retract speed, grab radius, cage capacity. |

## Per-species enemy data (NOT in GameFeel)

Per-species stats (hp, bite damage, weight, size, move speed, currency drops,
elite ability, body color, currency color) deliberately live OUTSIDE GameFeel,
in one `.tres` file per species under `res://data/enemies/`. Open one in the
Godot editor (Inspector panel) to tune that species' numbers or colors — no
code involved. Two exist today:

| Species (file) | AI behavior(s) | Body color | Currency color |
|---|---|---|---|
| `reference_fish.tres` ("Reef Fish") | Territorial, Hunter | orange | orange |
| `chaser_fish.tres` ("Basic Chaser") | Chaser | green | teal |

The split exists so "how floaty does combat feel" (GameFeel, shared) stays
separate from "how tough is THIS fish" (per-species data) — see DECISIONS.md,
MILESTONE_8.md Module 0. Which file a fish actually uses is picked by its AI
behavior in `Fish._ready()` (`scripts/fauna/fish.gd`) — a Chaser-behavior fish
loads `chaser_fish.tres`, anything else loads `reference_fish.tres` — unless a
spawn explicitly overrides it with a different `EnemyDef` (the world's one
ranged-Elite demo spawn does this). The actual on-screen render color is
`PlaceholderArt.FISH_COLOR`/`CHASER_COLOR` (`scripts/placeholder_art.gd`) —
kept in sync with each species' `body_color` field by hand, since body color
isn't wired to read from the `.tres` directly yet (an ART-PASS-flagged gap).

## Reel minigame, in plain terms

When a claw or telescope arm hooks a live fish, a rope appears from the arm's
base to the fish with a bead sliding back and forth on it. The bead's speed
and how wide the green "good pull" zone is both depend on the fish's
`room_weight` (set per-species/per-class in its `.tres` — see above):

- `sweep_period_easy_s` / `sweep_period_hard_s`: how fast the bead sweeps,
  at the lightest vs. the heaviest weight.
- `success_zone_easy_frac` / `success_zone_hard_frac`: how wide the green
  zone is, at the lightest vs. heaviest weight. Hard end is 0 — see next line.
- `impossible_weight_min`: the weight at/above which the green zone has
  shrunk to nothing — that catch can never be landed, only released. No
  species reaches this today (Elite tops out at 3.0; this defaults to 4.0) —
  it's headroom for a future "too big to land" enemy.
- `pull_distance_m`: how much closer a landed pull brings the catch.
- `miss_leak_severity`: how bad the leak is when a full sweep lands nothing.
- `finish_damage`: the (always-lethal) damage dealt the instant a catch is
  fully reeled home.
