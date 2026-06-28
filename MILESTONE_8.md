# MILESTONE 8 — The Fauna Pass: Enemy Spine + add-enemy Skill + Color Economy

*Read order for the build session: `STATUS.md` → `DECISIONS.md` →
`ROOM_SYSTEM.md` (§4 economy, §6 catalog) → `MODULAR_SUB_IMPLEMENTATION.md` →
`SKILL_STUB_add_room.md` (the structural model for the new skill) → this file.
Plan back before building.*

M8 is **pure infrastructure**. It adds **no new species**. The existing
fish/chaser is promoted into a fully-propertied **reference enemy** that every
future fish is authored against, the **add-enemy skill** is written and
pressure-tested by re-deriving that reference enemy from it, and the room
**economy is re-denominated from carcasses into species color-currency**. The
three named fish (sand lurker, silver school, armored grey tank) are **M9**, not
this milestone — see "Out of scope."

This is an accepted 4-week+ milestone: the economy redesign rides inside it
deliberately. Modules are ordered so the build stays feel-testable after each.

---

## Design intent (why this milestone exists)

The combat loop currently has three near-identical fish (territorial, hunter,
chaser) separated only by aggression range. The Fauna Pass turns "enemy" into a
**rich authored data type** — weight, difficulty classes, ranged attacks,
grab-tug behavior, color drops — so that variety becomes cheap content (a new
`.tres` file) instead of expensive code. M8 builds that type and the tool that
authors it; M9 spends it on actual species.

Two pillars this milestone must not violate:
- **Flooding is the sole death path.** Every new attack vector (ranged shots,
  rams with knockback) routes through the existing breach/water spine via
  `breach_from_hit`. No new HP pool on the sub, no instant-kill.
- **Push-your-luck preservation.** Held enemies and dropped currency are at risk
  until banked/docked — the grab-tug system is a physics interaction, not a safe
  income exception.

---

## Canon reversals this milestone makes (write these to DECISIONS.md)

These are **design-level supersessions**, not silent code changes. Each gets a
DECISIONS.md entry citing the line it overrides.

1. **Color-currency replaces the carcass economy.** `ROOM_SYSTEM.md` §4.2's
   `s_ca`/`m_ca`/`l_ca` carcass tiers are **retired**. Enemies drop **species
   color-currency** instead. This supersedes §4.2 and the M3/M5 carcass-drop
   decisions (DECISIONS.md ~lines 149, 179, and the M5 medium-carcass entry).
2. **The entire §6 room catalog is re-priced into color costs.** Every `[… sc,
   … s_ca …]` price becomes a color-currency price. This is the economy redesign;
   it is the last and riskiest module (see Module 4).
3. **Currency colors are a separate namespace from Elemental colors.** The
   Elemental Update reserves yellow / light-grey / cyan / red / purple with fixed
   element meanings (`ELEMENTAL_UPDATE.md` §2). Species currency colors **must not
   reuse those hues**. A species' **body color and its currency color are
   independent fields** — the grey armored fish does *not* drop grey currency.
4. **The elite premium currency is named `gold`, not purple.** "Purple" stays
   reserved for the Elemental Purple Gem. (One-line swap to `pearl` if preferred;
   `gold` chosen for "premium" read with no element collision.)

---

## Storage decision (canon — write to DECISIONS.md and ROOM_SYSTEM/STATUS)

Per-species enemy data lives in **per-species Godot `.tres` Resources**, one file
per species, under `res://data/enemies/`, typed by an `EnemyDef` script.

**Division of labor (the rule the skill enforces):**
- **Global tunables live in `GameFeel`** — knockback scalar, grab-tug force
  bands, currency denomination values (1/5/10/50), what each color *buys*, ranged
  projectile base behavior. The spine's physics constants.
- **Per-species content lives in `.tres`** — color, class stat blocks, elite
  ability choice, drop totals, flags. Authoring the skill touches a new `.tres`
  and **never edits `GameFeel`**.

This is the same spine/content separation that lets M8 (spine) and M9 (species)
be distinct milestones. Schema sketch (verify field names against real code when
building; this is the shape, not the final):

```
res://data/enemies/
  enemy_def.gd          # class_name EnemyDef extends Resource
  enemy_class_stats.gd  # class_name EnemyClassStats extends Resource
  reference_fish.tres   # the M8 reference enemy (the promoted existing fish)
```

```gdscript
# enemy_def.gd
class_name EnemyDef extends Resource
@export var species_name: String
@export var body_color: Color                       # visual identity
@export var currency_color: String                  # NON-reserved palette; independent of body_color
@export var ranged: bool = false                    # base trait, applies to all classes
@export var grabbable: bool = true
@export var class_small: EnemyClassStats
@export var class_big: EnemyClassStats
@export var class_elite: EnemyClassStats            # the only one carrying an elite ability

# enemy_class_stats.gd
class_name EnemyClassStats extends Resource
@export var damage: float
@export var hp: float
@export var room_weight: float
@export var size_scale: float                       # vary size only for now (ART-PASS FLAG)
@export var move_speed: float
@export var currency_drop_total: int                # baked into 1/5/10/50 denominations at death
@export var gold_drop: int = 0                      # elite premium currency; 0 for non-elite blocks
@export_enum("none","ranged_spit","brief_shield","speed_burst","NOVEL_HANDCODE") var elite_ability: String = "none"
```

Rationale (for the record): `.tres` gives a typed schema that fails loudly at
load, a free Inspector authoring GUI (dropdowns for currency color and the elite
menu — directly serving the skill's "prompt for everything, assume nothing"
goal), plain-text round-tripping the skill can write and git can diff. CSV is too
flat for the ragged class/ability/drop structure; YAML/JSON loses type-safety and
tooling; a single `GameFeel`-style `.gd` is wrong for per-species content (it
fights the content-authoring skill). See the discussion captured in the design
session.

---

## Module 0 — Enemy data spine (the `EnemyDef` type + the reference enemy)

**Goal:** the existing fish becomes a data-driven `EnemyDef` consumer with no
behavior change yet, so everything after this is additive.

- Create `EnemyDef` + `EnemyClassStats` resource scripts per the schema above.
- Author `reference_fish.tres` reproducing the **current** fish stats (HP, speed,
  bite damage) as the Small block; fill plausible Big/Elite blocks (tuning later).
- Refactor `scripts/fauna/fish.gd` to read its stats from an assigned `EnemyDef`
  + a `class` selector (Small/Big/Elite) instead of hard-coded numbers and the
  `is_territorial`/`is_hunter`/`is_chaser` flag soup. The three existing AI
  behaviors stay; they become a **behavior field**, not separate flag combos.
- No new mechanics in this module. Headless check: existing fish behave exactly
  as before, now sourced from the `.tres`.

**Acceptance:** existing maps spawn the same fish, same feel, but every stat now
comes from `reference_fish.tres`. `test_fish` still green.

---

## Module 1 — Weight + bump-back knockback

**Goal:** rams have physical consequence scaled by enemy weight and speed.

- `room_weight` is read from the active class block.
- When an enemy rams the sub, in addition to the existing `breach_from_hit`, the
  sub receives an impulse scaled by `enemy.room_weight × impact_speed`, tuned by
  a single `GameFeel` knockback scalar. Heavier/faster enemy = bigger shove.
- The breach is unchanged — knockback is **on top of** the existing damage spine,
  not a replacement. Death is still flooding only.

**Acceptance:** a heavy ram visibly shoves the sub; a light one barely nudges.
All knockback magnitude lives in one `GameFeel` key. Headless test asserts
impulse scales with weight.

---

## Module 2 — Grab-tug physics (claw + telescope)

**Goal:** held enemies tug the sub by their weight while they keep swimming.

- A grabbed enemy (via claw or telescope arm) keeps applying its movement intent.
  That intent becomes a force on the sub through the arm:
  - **Light** (below a `GameFeel` threshold): **hard-coded pinned** — treated as
    held in place, no tug calc. (Approved optimization.)
  - **Medium:** a real force the sub's control station fights against
    (rope-pull feel — the sub can win but must work).
  - **Heavy:** dominant force; the controller can barely influence the motion.
  - Build the medium/heavy as a **proper continuous calc** (weight vs. sub thrust);
    only "light = pinned" is the hard-coded shortcut.
- Respect the **`grabbable` flag** — `grabbable=false` enemies cannot be picked up
  by either arm.
- Held enemies remain **at risk on implosion until docked/banked** (push-your-luck
  pillar — they are not safe income).

**Acceptance:** grabbing a light fish pins it; a medium one creates a tug-of-war
at the helm; a heavy one drags the sub. A `grabbable=false` enemy refuses both
arms. Force bands live in `GameFeel`. Headless test covers the three bands + the
flag.

---

## Module 3 — Ranged attacks + the three difficulty classes

**Goal:** enemies can fire, and any species can be authored at three power tiers.

- **Difficulty classes:** Small / Big / Elite are **per-species authored stat
  blocks** already on `EnemyDef` (Module 0). This module wires the **spawn-time
  class selector** so a map/spawn can request a class, and the enemy adopts that
  block's damage/hp/weight/size/speed/drops. **Size varies per class; art stays
  identical (ART-PASS FLAG in the doc + a TODO comment at the sprite site).**
- **Elite-only ability:** the Elite block's `elite_ability` field fires its hook.
  M8 ships the **common-menu** abilities only (see the skill's fixed menu below);
  `NOVEL_HANDCODE` is a flagged placeholder that asserts/logs if selected without
  a hand-coded implementation (no novel ability is authored in M8).
- **Ranged as a base trait:** `ranged=true` is a per-species base trait (all
  classes), **independent of** elite abilities. A ranged enemy fires a projectile
  that damages the sub **through `breach_from_hit`** (the M5 hook — reuse it; do
  not invent a second damage path). Projectile base behavior (speed, cadence)
  lives in `GameFeel`; per-species ranged on/off is in the `.tres`.

**Acceptance:** the reference enemy can be spawned as Small/Big/Elite with
visibly different size and stats; a `ranged=true` variant fires and the shot
springs a breach like a bite does; selecting one common elite ability on the
Elite block works end-to-end. Headless tests per class + ranged fire.

---

## Module 4 — Color currency + full economy re-pricing *(last; schedule buffer)*

**This is the riskiest module and the explicit slip/extend buffer — like M5's
hunt module. If it runs long, it extends the milestone; it is never cut, but it
is sequenced last so Modules 0–3 are already feel-testable.**

**4a — Currency drops (mechanical):**
- On death, an enemy emits its class block's `currency_drop_total` in its
  `currency_color`, **broken into 1/5/10/50 denomination pickups** (denomination
  values in `GameFeel`). Bigger class = bigger total.
- Elite kills additionally drop `gold_drop` (the renamed premium currency).
- Drops are **claw/telescope-collectable, on-board, bankable** — reuse the
  existing salvage→storage→bank pipeline, swapping carcass `Kind`s for
  color-currency types. Carcass `Kind`s are **removed** from the salvage system.
- Dropped currency is **lost on implosion until banked** (push-your-luck pillar).

**4b — Economy re-pricing (design):**
- Re-denominate the **entire `ROOM_SYSTEM.md` §6 catalog** from `sc`/`s_ca`/
  `m_ca`/`l_ca` into **color-currency costs**, with **color as a soft gate**
  (a room can demand a specific color, nudging the player toward hunting that
  species). Update §4.2 (resource list), §6 (every price), and the slot-price
  escalation reference.
- **This sub-step is provisional and explicitly tuned in M9**, because the color
  faucet (which species drop which colors) doesn't physically exist until M9
  ships the named fish. The re-pricing must be authored as "first-pass numbers,
  to be balanced against the real M9 drop economy" — do not treat it as final.
- The reference enemy's `currency_color` is a placeholder non-reserved hue so the
  pipeline is exercisable in M8 without real species.

> **Drafting note for the build session:** the color→room mapping (which rooms
> demand which colors, what the soft gate looks like) is a *design* decision, not
> a code one. The build session must **stop and ask Snir** for the color→room
> mapping before writing §6 prices — do not invent the gate structure. A short
> structured Q&A pass, then author.

**Acceptance:** killing the reference enemy drops collectable colored currency in
mixed denominations; banking works; the §6 catalog reads in colors; a color-gated
room refuses purchase without the right color. Full salvage/shop/dock headless
suite green.

---

## Module 5 — The add-enemy skill (built + validated against the reference enemy)

*Structurally modeled on `SKILL_STUB_add_room.md` — declarative plumbing + a
fixed menu of common abilities + novel mechanics flagged for hand-code. Bosses
are excluded from the skill entirely (they are the only enemies unique enough to
escape it).*

**Path:** `.claude/skills/add-deeper-enemy/SKILL.md`. **Trigger:** "add an enemy
/ new fish / new fauna / new species."

**The skill must contain:**

1. **Trigger description** — fires on add-enemy requests, not unrelated work.
2. **Preconditions block** — confirm `EnemyDef`/`EnemyClassStats`, the spawn
   class-selector, `breach_from_hit`, the grab-tug system, the currency-drop
   pipeline, and `GameFeel` enemy keys all exist (cite real file paths once
   Modules 0–4 are committed). Require reading the relevant `ROOM_SYSTEM.md` /
   `DECISIONS.md` entries.
3. **The "prompt for everything, assume nothing" intake** — the skill's core
   purpose. It must **ask Snir for every field and refuse to default silently**:
   - species name; body color; **currency color (must be non-reserved; the skill
     names the reserved Elemental hues and rejects them)**;
   - per-class (Small/Big/Elite) damage, hp, `room_weight`, size_scale,
     move_speed, currency_drop_total; elite `gold_drop`;
   - `ranged` yes/no (and if yes, any non-default projectile behavior);
   - `grabbable` yes/no;
   - the **elite ability**: pick from the fixed menu, or declare it **novel**;
   - the **AI behavior** (territorial / hunter / chaser / a new pattern → if new,
     that's a hand-coded mechanic).
   The skill must explicitly list these as required and **block on missing ones**.
4. **Fixed menu of common elite abilities** (the starter set the skill offers;
   anything else is `NOVEL_HANDCODE`): **`ranged_spit`** (gains/【intensifies a
   ranged attack), **`brief_shield`** (short damage-immunity window),
   **`speed_burst`** (periodic lunge). *(Confirm/extend this menu with Snir when
   the skill is written — see open item below.)*
5. **Novel-mechanic path** — like the room skill's wrecking-ball/shield handling:
   a genuinely new elite ability or AI pattern is **hand-coded against the
   nearest reference enemy**, not forced into the schema. The skill points at the
   reference set and writes the plumbing only.
6. **The procedure** — fill the `.tres` from the template; wire the class blocks;
   pick/hand-code the elite ability; register body color + size in
   `placeholder_art.gd`; add to the spawn catalog; if a new `class_name` lands,
   run `--headless --import` once (stale-class-cache trap); headless-check.
7. **Test skeleton** — per-class spawn, ranged fire if applicable, grab-tug band,
   currency drop, elite ability.

**Validation pass (mandatory):** after writing the skill, **re-derive
`reference_fish.tres` from it** end-to-end. If the skill can't reproduce the
reference enemy, the skill is wrong — fix the skill, not the reference.

**Acceptance:** the skill exists, its intake blocks on every missing field and
rejects reserved currency colors, and running it reproduces the reference enemy.

---

## Out of scope (hard guardrails)

- **No new species.** Sand lurker, silver school fish, armored grey tank are
  **M9**. M8 ships only the promoted reference enemy. (Per the design session:
  the by-hand reference is the existing fish upgraded, *not* the lurker.)
- **No bosses.** Bosses escape the skill by design; not touched here.
- **No new AI patterns.** Only the existing territorial/hunter/chaser behaviors,
  re-homed onto the data type. The school-of-fish flocking behavior is M9 content.
- **No Elemental coupling.** Currency colors stay a separate namespace; the
  Elemental system stays parked. M8 only *avoids* its reserved hues.
- **No art.** Classes vary by **size only**; identical sprites with an ART-PASS
  flag. No per-class or per-species graphics.
- **No final economy balance.** Module 4b's re-pricing is provisional, tuned in M9
  once the color faucet exists.

---

## Milestone sizing & feel-testability

- ~4 weeks, slippage **extends** (never cuts); Module 4 is the buffer.
- Feel-testable checkpoints: after Module 1 (knockback changes every ram), after
  Module 2 (grab-tug changes every arm grab), after Module 3 (classes + ranged
  change every fight), after Module 4 (currency replaces carcasses end-to-end).
- Weekly playtest after each major module against the two testers.

---

## Open items for the build session to resolve with Snir (do not guess)

1. **The color→room mapping** for Module 4b — which rooms demand which colors,
   and what the soft gate looks like in the shop. Structured Q&A before writing
   §6 prices.
2. **The fixed elite-ability menu** — confirm/extend the starter set
   (`ranged_spit` / `brief_shield` / `speed_burst`) before finalizing the skill.
3. **Elite premium currency name** — `gold` assumed; confirm vs. `pearl`.
4. **Denomination split rule** — how a `currency_drop_total` breaks into
   1/5/10/50 pickups (greedy largest-first vs. a spread). A `GameFeel`-tunable
   rule; confirm the intent.

---

## Session-end ritual (per CLAUDE.md)

1. Update `STATUS.md`: spine built, `.tres` storage live, economy re-denominated,
   skill written + validated; file-map changes; known issues; M9 as next step.
2. Append all reversals above to `DECISIONS.md` (carcass→color, §6 re-pricing,
   color-namespace separation, gold naming, `.tres` storage), each citing the
   entry it supersedes.
3. Update `ROOM_SYSTEM.md` §4.2 + §6 and add a canon-supersession note pointing at
   the DECISIONS entries.
4. Create `MILESTONE_9.md` stub: the three named fish authored through the skill,
   + economy balance pass, + headroom for 1–2 more species.
5. Commit per working module; push at session end.
