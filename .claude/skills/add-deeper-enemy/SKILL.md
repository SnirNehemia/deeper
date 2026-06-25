---
name: add-deeper-enemy
description: >-
  Add a new enemy species to DEEPER (a fish/fauna type authored as an EnemyDef
  .tres with Small/Big/Elite stat blocks). Use when a brief says "add an
  enemy", "new fish", "new fauna", "new species", or specs a species from
  MILESTONE_9.md or a future fauna brief. Covers the "prompt for everything,
  assume nothing" intake, filling the .tres from the template, picking/
  hand-coding the elite ability, wiring the AI behavior, registering art, and
  the headless test. Do NOT use for: bosses (excluded by design — they're
  hand-built, not authored through this skill), designing what a species does
  (that's a milestone brief), or balancing numbers (playtest tuning).
---

# Add a DEEPER enemy

This skill adds **one species** to DEEPER as a per-species `EnemyDef`
`.tres` Resource. The enemy spine — `EnemyDef`/`EnemyClassStats`, the
spawn-time class selector, ram knockback, grab-tug, ranged fire through
`breach_from_hit`, and the color-currency drop pipeline — **already exists
and is inherited** (MILESTONE_8.md, Modules 0-4). Your job is to fill the
*declarative* part (the `.tres`) and hand-code only a genuinely novel
mechanic (an elite ability outside the fixed menu, or an AI behavior outside
territorial/hunter/chaser) against the closest reference species.

> **Mental model:** the plumbing is data; the mechanism is code. A species'
> `.tres` captures everything uniform across enemies (color, three class
> blocks of stats, ranged/grabbable flags, an elite-ability *choice*). A
> genuinely new elite ability or AI pattern is always hand-written against a
> reference enemy. This skill makes the plumbing free and points you at the
> right reference — it does **not** pretend a novel mechanic is data.

**Bosses are excluded entirely.** They are unique enough to escape this
skill by design (MILESTONE_8.md Module 5) — never use this skill for one.

## 0. Preconditions — read before touching anything

**Read, in order:** `CLAUDE.md` → `STATUS.md` → `DECISIONS.md` →
`MILESTONE_8.md` (the enemy-spine canon this skill is built against) →
`ELEMENTAL_UPDATE.md` §2 (reserved currency hues — see §1 below).

**Confirm these systems exist** (if any is missing, stop — the species can't
be added cleanly and that's a design-level problem to surface):
- `EnemyDef`/`EnemyClassStats` (`data/enemies/enemy_def.gd`,
  `data/enemies/enemy_class_stats.gd`) — the per-species schema;
- the spawn-time class selector, `World._add_fish(pos, behavior, cls,
  custom_def)` (`scenes/world.gd`);
- `breach_from_hit` (`scripts/sub/sub.gd`) — the **single** damage path a
  bite, ram, or ranged shot all route through; never invent a second one;
- the grab-tug weight-band system (`GameFeel.enemy_impact`,
  `Fish.is_grabbable()`/`grab()`/`struggle_direction()`, `scripts/fauna/fish.gd`);
- the color-currency drop pipeline (`GameFeel.currency`, `Fish.die()`,
  `Fish._spawn_drop()`, `scripts/fauna/fish.gd`);
- `GameFeel.fish` (`autoload/game_feel.gd`, `FishFeel`) — the shared AI-pacing
  constants (detect/leash ranges, speeds, backoff) for whichever behavior
  this species uses. **Never duplicate a pacing constant into the `.tres`** —
  only what varies species-to-species (damage/hp/weight/size/speed/drops/
  ability) lives there.

**Confirm these specific files exist before writing:**
- `data/enemies/enemy_def.gd`, `data/enemies/enemy_class_stats.gd`
- `data/enemies/reference_fish.tres`, `data/enemies/chaser_fish.tres` (your
  two worked examples — read both before authoring a third)
- `scripts/fauna/fish.gd` (`Fish.Behavior` enum, `_check_elite_ability()`,
  `_wants_ranged()`, `die()`)
- `scenes/world.gd` (`_add_fish`, and `_ranged_demo_def()` as the pattern for
  a demo/test spawn with a `custom_def`)
- `scripts/placeholder_art.gd` (`CURRENCY_COLORS`, `FISH_COLOR`/`CHASER_COLOR`
  pattern for body color)
- `autoload/game_feel.gd` (`FishFeel`, `EnemyImpactFeel`, `EnemyRangedFeel`,
  `CurrencyFeel`) — read, never edit, for this skill's purposes

> **Reference enemies (closest-match table):** read both before authoring.
> - `reference_fish.tres` + `Fish.Behavior.TERRITORIAL`/`HUNTER` — the
>   melee, non-elongated baseline.
> - `chaser_fish.tres` + `Fish.Behavior.CHASER` — the relentless, elongated,
>   open-water variant (pure identity split from the reference fish; same
>   spine, different body/currency color and AI pattern).
> A new species picks **one** `Behavior` (existing three only — a genuinely
> new AI pattern is out of scope, see §4) and authors three `EnemyClassStats`
> blocks against whichever reference is closer in feel.

## 1. The intake — prompt for everything, assume nothing

**This is the skill's core purpose.** Ask Snir for every field below,
one at a time or in a short structured batch, and **block on anything
missing or invalid** — never silently default a real design field. (Tunable
*numbers* can take a reasonable first-pass guess if Snir explicitly says "you
pick" — but the existence of each field must still be surfaced, never
skipped.)

1. **Species name** (`species_name`, display string).
2. **Body color** (`body_color`, a `Color`) — visual identity, independent
   of currency color.
3. **Currency color** (`currency_color`, a String) — **must be a
   non-reserved hue.** The Elemental Update (`ELEMENTAL_UPDATE.md` §2)
   reserves five hues for element meaning: **yellow, light grey, cyan
   (light blue), red, purple**. Canonical reject-list (case-insensitive,
   match on substring too — "light_blue"/"lightblue"/"cyan" all reject):
   `yellow`, `light_grey`, `lightgrey`, `grey`, `gray`, `cyan`, `light_blue`,
   `lightblue`, `red`, `purple`. **Reject any of these and ask again** —
   do not silently pick a substitute. `gold` is also reserved, but for a
   different reason: it's the elite premium currency name (MILESTONE_8.md
   reversal #4), not a per-species color — reject it here too and explain
   why. Currently-real, droppable colors are `orange` (reference fish) and
   `teal` (chaser); a new species should pick a **new** color, not reuse one
   already claimed by a live species (claiming a used color isn't illegal,
   just probably not what Snir meant — flag it and confirm).
4. **Per-class stats**, for **all three** of Small/Big/Elite — do not let
   Snir skip a tier "for now":
   - `damage` (breach severity per hit)
   - `hp`
   - `room_weight` (drives both ram knockback and the grab-tug weight band —
     show Snir `GameFeel.enemy_impact.light_weight_max`/`heavy_weight_min`
     [1.5 / 2.5] so the choice lands in the band they intend)
   - `size_scale`
   - `move_speed`
   - `currency_drop_total`
   - **Elite only:** `gold_drop` (0 is valid and common — most species drop
     no gold)
5. **`ranged`** yes/no (base trait, applies to *all* classes, not just
   Elite). If yes: ask whether the species needs any non-default projectile
   behavior (fire range/cooldown/speed/lifetime/severity), or whether the
   shared `GameFeel.enemy_ranged` defaults are fine. A custom per-species
   override needs its own hand-coded read site in `Fish._try_ranged_fire` —
   confirm with Snir before adding one; today every ranged species shares
   the one `GameFeel.enemy_ranged` block.
6. **`grabbable`** yes/no (claw/telescope can pick it up if true).
7. **The elite ability**: offer the fixed menu (§2 below) by name and
   one-line effect, or let Snir declare it **novel** (§4 below). Required —
   "none" is a valid, explicit answer (most Small/Big blocks; an Elite block
   *can* also be "none" if the species has no special elite trick beyond its
   raw stat bump).
8. **The AI behavior**: `territorial` / `hunter` / `chaser` (the three that
   exist), or a **new pattern** — if new, that's a hand-coded mechanic
   (§4 below), not a menu pick.

## 2. Fixed menu of common elite abilities

The starter set (confirmed with Snir at M8 Module 5 build time — do not
extend without asking again):

| Ability | Intended effect | Implementation status today |
| --- | --- | --- |
| `ranged_spit` | Grants (or intensifies, if already `ranged=true`) a ranged attack on the Elite block. | **Fully implemented** — `Fish._wants_ranged()`/`_ranged_intensified()`/`_try_ranged_fire()`. Use this as your reference if a species wants it. |
| `brief_shield` | A short damage-immunity window. | **Recognized but inert** — `Fish._check_elite_ability()` just `push_warning`s. Selecting it is valid (matches today's menu); it does nothing in-game until a future pass implements it. **Tell Snir this explicitly** before he picks it expecting a working shield. |
| `speed_burst` | A periodic lunge. | **Recognized but inert**, same as `brief_shield` — warn, don't implement, unless Snir explicitly asks you to build the real mechanic in this same session (then it's no longer "just the skill" — flag the scope change). |

Anything else is **`NOVEL_HANDCODE`** — see §4.

## 3. Fill the `.tres` from the template

Author a new file at `res://data/enemies/<species_id>.tres` (snake_case,
matching `chaser_fish.tres`'s naming). Copy `chaser_fish.tres` as the
starting point (closer structural twin than `reference_fish.tres` if your
species is a behavior variant; either is fine as a copy source — the shape
is identical):

```
[gd_resource type="Resource" script_class="EnemyDef" load_steps=6 format=3]

[ext_resource type="Script" path="res://data/enemies/enemy_def.gd" id="1"]
[ext_resource type="Script" path="res://data/enemies/enemy_class_stats.gd" id="2"]

[sub_resource type="Resource" id="1"]   ; Small
script = ExtResource("2")
damage = <small.damage>
hp = <small.hp>
room_weight = <small.room_weight>
size_scale = <small.size_scale>
move_speed = <small.move_speed>
currency_drop_total = <small.currency_drop_total>
gold_drop = 0
elite_ability = "none"

[sub_resource type="Resource" id="2"]   ; Big
... same shape ...

[sub_resource type="Resource" id="3"]   ; Elite
... same shape, elite_ability = "<picked or NOVEL_HANDCODE>", gold_drop = <n> ...

[resource]
script = ExtResource("1")
species_name = "<name>"
body_color = Color(<r>, <g>, <b>, 1)
currency_color = "<color>"
ranged = <bool>
grabbable = <bool>
class_small = SubResource("1")
class_big = SubResource("2")
class_elite = SubResource("3")
```

**Do not hand-author UIDs** (`uid://...`) — let Godot assign them on first
import (the `--headless --import` step below).

## 4. Hand-code a novel mechanic (only if needed)

Two things can require hand-coding instead of a menu pick:

- **A novel elite ability** (`elite_ability = "NOVEL_HANDCODE"`): write it
  against `ranged_spit`'s wiring pattern in `fish.gd` —
  `_check_elite_ability()` is the single dispatch point at spawn; add a new
  branch there, plus whatever state/method the mechanic needs (mirror
  `_wants_ranged`/`_try_ranged_fire` for a fire-based ability, or add a
  parallel small state machine for something else). **Route any damage
  effect through `breach_from_hit` or `take_damage`** — never a second
  damage path.
- **A novel AI behavior** (not territorial/hunter/chaser): extend
  `Fish.Behavior` and hand-code the new state-machine branch in
  `_physics_process`, following the existing three as the pattern (each is a
  `behavior ==` branch reading shared `GameFeel.fish` pacing constants). This
  is a structurally bigger change than an ability — confirm with Snir that
  it's intentional in scope before building it; MILESTONE_8.md explicitly
  scoped "no new AI patterns" for M8 itself (school-of-fish flocking is M9+).

If neither mechanic fits cleanly on the existing interface, **stop and
report in design terms** (see §7) — that's a signal the spine has a gap, not
something to paper over here.

## 5. Wire the spawn + register art

- **Demo/test spawn**: add a call site mirroring `World._ranged_demo_def()`
  — build a `custom_def` (or `load()` the new `.tres` directly) and pass it
  to `_add_fish(pos, behavior, cls, custom_def)`. This is enough to make the
  species spawnable and feel-testable; it does **not** require a new
  gen-map marker color. (A gen-map marker is only needed if a future map
  brief wants to hand-paint this species by pixel color — out of scope for
  a normal species add; flag it as a separate ask if Snir wants it.)
- **Register body color** in `scripts/placeholder_art.gd` (a comment near
  `FISH_COLOR`/`CHASER_COLOR` is enough — the color itself already lives in
  the `.tres`'s `body_color` field and `Fish._draw()` reads it from there).
- **Register currency color** in `PlaceholderArt.CURRENCY_COLORS` (the
  dictionary in `scripts/placeholder_art.gd`) — add `"<color>": Color(...)`.
  Skipping this isn't a crash (unknown colors fall back to neutral grey via
  `currency_color()`), but it means the drop is invisible-by-confusion in
  play; always add it.
- **Import trap**: if you added a new `class_name` script (rare for a plain
  species — only if §4 needed a new enum value or helper script), run once:
  ```
  "D:\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe" --headless --path . --import
  ```
  Authoring a plain `.tres` referencing the *existing* `EnemyDef` script does
  not need this — only a brand-new script does.

## 6. The test (copy-paste skeleton)

Model on `tests/test_enemy_ranged.gd` (load a `.tres`/build a `Fish` headless,
no rendering needed for stat/logic checks). New suite
`tests/test_<species_id>.tscn` + `.gd`:

```gdscript
extends Node

var _failures := 0

func _ready() -> void:
	_test_class_blocks_load_correctly()
	await _test_spawns_and_behaves()
	if _wants_ranged_test:
		await _test_ranged_fire_if_applicable()
	_test_grab_tug_band()
	_test_currency_drop()
	if _has_elite_ability:
		_test_elite_ability()

	if _failures == 0:
		print("<SPECIES> TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("<SPECIES> TESTS FAILED: %d failing check(s)" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok:   ", msg)
	else:
		push_error("  FAIL: " + msg)
		_failures += 1
```

Assert, at minimum:
- **per-class spawn**: Small/Big/Elite each read their own stat block (hp,
  damage, size_scale — mirror `_test_class_selector_changes_size_and_stats`
  in `test_enemy_ranged.gd`);
- **ranged fire, if `ranged=true`**: a shot breaches the sub through
  `breach_from_hit` (mirror `_test_ranged_base_trait_fires_and_breaches`);
- **grab-tug band**: `room_weight` for each class lands in the expected
  Light/Medium/Heavy band (`GameFeel.enemy_impact.weight_band()`), and a
  `grabbable=false` species refuses `is_grabbable()`;
- **currency drop**: killing each class spawns the right total in the
  right `currency_color`, split via `GameFeel.currency.split()` (mirror how
  `Fish.die()` is exercised in `tests/test_fish.gd`'s carcass/drop checks);
  Elite drops `gold_drop` worth of `"gold"` too, if non-zero;
- **elite ability, if not "none"**: `ranged_spit` fires end-to-end (if
  picked); `brief_shield`/`speed_burst`/any inert pick spawns without
  crashing (mirror `_test_unimplemented_elite_ability_does_not_crash`); a
  novel hand-coded ability is exercised directly.

## 7. Definition of done

- [ ] intake completed — every field in §1 asked and answered, no silent
      defaults, reserved currency colors rejected;
- [ ] `.tres` authored at `res://data/enemies/<species_id>.tres` from the
      template, all three class blocks filled;
- [ ] elite ability picked from the fixed menu (§2) or correctly flagged
      `NOVEL_HANDCODE` + hand-coded (§4);
- [ ] AI behavior picked from the existing three, or a new one explicitly
      confirmed as in-scope and hand-coded (§4);
- [ ] novel mechanic (if any) routes damage through `breach_from_hit`/
      `take_damage` — no second damage path;
- [ ] demo/test spawn wired (`custom_def` pattern, §5);
- [ ] `currency_color` registered in `PlaceholderArt.CURRENCY_COLORS`;
- [ ] `--headless --import` run if a new `class_name` script was added;
- [ ] species test green **and full regression suite green**
      (delegate to the `deeper-test-runner` subagent per `CLAUDE.md`);
- [ ] `STATUS.md` updated (species shipped, files touched, test);
- [ ] commit message matching the milestone convention, e.g.
      `M9-1: sand lurker (territorial, ranged_spit Elite)`.

## 8. Do NOT

- Default any intake field silently — block and ask (§1). The one exception:
  a tunable *number* may take Claude's reasonable first guess if Snir
  explicitly delegates it ("you pick the numbers") — but every field's
  *existence* must still be surfaced.
- Accept a reserved currency color (yellow/light-grey/cyan/red/purple/gold) —
  reject and re-ask, citing `ELEMENTAL_UPDATE.md` §2.
- Duplicate a `GameFeel.fish` pacing constant (detect range, speed, backoff)
  into the `.tres` — those stay spine-shared; only what's authored per
  species in `EnemyClassStats`/`EnemyDef` belongs there.
- Invent a second damage path for a novel ability — always
  `breach_from_hit`/`take_damage`.
- Build a new AI behavior or novel elite ability without confirming scope
  with Snir first (§4) — both are bigger than "fill a `.tres`."
- Use this skill for a boss. Bosses are hand-built, never authored here.
- Touch `GameFeel.enemy_impact`/`enemy_ranged`/`currency` — those are spine
  tunables, edited only by a dedicated tuning pass (`deeper-tuner`), never by
  this skill.
- Add real art or sound (placeholder colors/sizes only).

**If the procedure can't be followed cleanly** — the elite-ability dispatch
doesn't generalize, a "simple" species needs a second damage path, the
class-block schema can't express what the species needs — **stop and report
to Snir in design terms.** That means the enemy spine has a gap worth fixing
before more species pile on, which is exactly what M8 Module 5's mandatory
validation pass (next file: re-deriving `reference_fish.tres` through this
skill) is meant to catch early.
