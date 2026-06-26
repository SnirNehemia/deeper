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
| Fish AI | `FishFeel` (`GameFeel.fish`) | Territory radius, patrol/chase/hunt/return speeds, bite interval, hunter/chaser detection and give-up ranges, **plus the Sand Lurker's ambush dials** (`ambush_detect_m` hidden range, `ambush_windup_s` tell length, `ambush_lunge_speed_mps`, `ambush_lunge_reach_m` commit distance). (Per-species HP/damage/weight is NOT here — see "Per-species data" below.) |
| Ranged enemy fire | `EnemyRangedFeel` (`GameFeel.enemy_ranged`) | Fire range, cooldown, projectile speed/lifetime, hit severity, and the cooldown multiplier an Elite's `ranged_spit` ability gets when "intensifying" an already-ranged species. Per-species ranged on/off is the `.tres`'s `ranged` flag, not here. |
| Spitter (puffer) | `SpitterFeel` (`GameFeel.spitter`) | Detect range, the keep-distance band (min/max), inflate time + cooldown, full-inflation draw scale, bubbles fired per tier (1/2/4), scatter spread, and the "juicy while inflated" damage multiplier + bonus-currency drop. |
| Spitter bubble | `BubbleFeel` (`GameFeel.bubble`) | The destructible bubble: hp (shots to pop), drift speed, lifetime, hull-breach severity, and how much it slows a shot that passes through. |
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
| `reference_fish.tres` ("Reef Fish") | Territorial, Hunter | orange | brown |
| `chaser_fish.tres` ("Basic Chaser") | Chaser | green | teal |
| `lurker_fish.tres` ("Sand Lurker") | Ambusher | sand | brown |
| `spitter_fish.tres` ("Spitter") | Spitter | dark brown | brown |

**Currency economy (deliberately just two droppable colors + a reserved third):**
to keep the wallet from sprawling as species multiply, all fauna drop one of two
currencies — **brown** (reef fish, Sand Lurker, Spitter) or **teal** (chaser, and
the queued Shoal + Discharger). **purple** is reserved for a future category but
nothing drops it yet. "gold" is the separate elite-only premium. Room prices
(`GameFeel.currency.room_price_colors`) are drawn from the droppable set
(brown/teal) so a room never costs a color you can't earn.

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

## Map authoring — what each painted pixel color means

A map is four PNGs (see `MapConfig` / `maps/cavern_depths_01/`). Two of them are
painted by **color code** — paint these exact hex values in Krita and the game
turns them into spawns and terrain. (The other two PNGs, background + foreground,
are just art.)

### Generation layer (`*_gen.png`) — where things spawn
One marker pixel = one spawn. For the fish, **blob size sets the difficulty
tier**: a single pixel = Small, two touching pixels (even diagonally) = Big,
three or more touching = Elite. Defined in `GenerationLayerParser`.

| Paint this hex | Color | Spawns |
|---|---|---|
| `#FFFFFF` | white | Player sub spawn point (one) |
| `#E8742C` | orange | Reef fish — Territorial behavior |
| `#00FF00` | green | Chaser fish |
| `#D2B48C` | tan | **Sand Lurker** (buried ambusher) — MILESTONE_9. Same hex as sand below, but this is the gen layer, so no conflict. |
| `#825528` | brown | **Spitter** (bubble puffer) — MILESTONE_9 |
| `#808080` | grey | Wreck (salvage) |
| `#6E473B` | brown | Dock zone (paint a cluster; its bounding box = the bay) |

### Physical layer (`*_phys.png`) — solid terrain & water
Every non-transparent pixel here is terrain or open space. Defined in
`TerrainType` / `PhysicalLayerParser`.

| Paint this hex | Color | Meaning |
|---|---|---|
| `#1d4a70` | deep blue | Water (open, navigable) |
| `#4d9bc7` | light blue | Sky / air (above the surface or a cave air pocket) |
| `#808080` | grey | Normal rock (solid) |
| `#D2B48C` | tan | **Sand** — forgiving to ram (half severity); the **Sand Lurker swims through it** (its hiding medium), everything else is blocked by it |
| `#000000` | black | Sharp rock — punishing (any bump = a max-severity gusher) |
| `#6E473B` | brown | Dock terrain (never breaches the hull) |

> Note: brown `#6E473B` means "dock" on **both** layers (a spawn-zone marker on
> the gen layer, non-damaging floor on the phys layer) — that pairing is
> intentional, paint it on both where the bay is.

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
