# MILESTONE 11 — The Deep Dark: Depth Fog & The Dock You Left

*Read order for the build session: `STATUS.md` → `DECISIONS.md` →
`MODULAR_SUB_IMPLEMENTATION.md` (the Floodlight pod, §"Floodlight pod (face-clip)")
→ `TUNING.md` (`FloodlightFeel`, `DockFeel`) → this file. Plan back before building.*

*(This is an **atmosphere + fix** milestone, not a content one. It is the first
piece of the long-deferred "vertical / descent feel" work. The **art pass** is
deliberately NOT here — it stays a parallel side-spike until the fog exists to
light sprites against, then becomes its own later milestone. See "Parked /
queued" below.)*

The roster milestones (M8 spine → M9 species → M10 Shoal) built *what* lives in
the deep. **M11 builds what the deep feels like.** Until now, depth has been a
number on a readout and a hull-pressure gate — descending hasn't *looked* like
anything. M11 makes the ocean close in: a dark-blue gradient that thickens as you
sink, held back locally by the floodlight you already own. It also fixes a
real-map bug — returning from the dry dock dumps you at the wrong dock — now that
the live map has more than one.

### Committed scope vs. parked
- **M11 ships:** Module 1 (Depth Fog) + Module 2 (Dock-Return Fix), both built,
  tested, playable.
- **Parked (NOT built here):**
  - **The Art Pass** — the two-branch experiment (pixel-shader overlay à la Dead
    Cells / Sea of Stars / World of Anterra **vs.** cute-vector vibe à la Kingdom
    Rush / Lovers in a Dangerous Spacetime). Reason it waits: per project canon
    the art pipeline is deferred until after the vertical slice, and committing a
    visual identity *before* the fog changes what the screen looks like means
    re-judging every sprite's silhouette/value against a background that didn't
    exist yet. Run it as a side-spike once M11's fog is in; fold the winner into
    a dedicated "Art Pass" milestone. **Not scheduled — do not start in M11.**
  - **The economy / room-store balance pass** — re-parked yet again (carried out
    of M8 → M9 → M10, now M11). Snir's call: M11 ships on fog + dock only. Full
    intent still lives in `MILESTONE_9.md`. Record the re-park in `DECISIONS.md`
    when M11 closes.
  - **Fog-as-vision-gate** — M11's fog is **purely cosmetic** (see Module 1). Any
    future "darkness hides threats / fauna see you less in the dark" mechanic is a
    separate design decision, explicitly out of scope here.

---

## Design intent (why this milestone exists)

The core run fantasy is *descending through increasingly dangerous depth zones*.
That danger is currently mechanical-only (pressure gates, tougher fauna). M11 adds
the **felt** half: the light goes out of the world as you sink, and the floodlight
stops being a M4-era "it provably works" toy and becomes the thing you actually
steer by. This directly serves the design-doc's Zone 3 promise ("dark —
floodlights matter") and turns the existing floodlight pod into a load-bearing
station instead of a curiosity.

Two pillars this milestone must not violate:
- **Fog is cosmetic only.** It darkens the *outside water*. It must not change
  enemy detection, player hitboxes, AI ranges, or any gameplay number. No hidden
  difficulty rides in on the darkness. (If it ever should, that's a future
  milestone with its own brief.)
- **The sub stays readable.** Crew, rooms, windows, and station UI are always
  legible regardless of depth. The fog lives *behind/around* the hull, never over
  the player's own interior. Couch co-op must never get harder to *read* — only
  harder to *see out into*.

---

## Module 1 — Depth Fog (the headline)

A darkness layer over the outside water that thickens with depth, punched through
locally by the floodlight (and ambiently by the sub's own lit interior).

### Locked design decisions (from scope round)
- **Onset:** **continuous gradient with a per-zone cap.** Darkness scales smoothly
  with the sub's current depth (darker every metre), but each depth zone clamps to
  a **darkness ceiling** so the deep can't crush to pure black before its zone —
  the gradient is continuous, the *cap* is per-zone. Drives off the same depth
  value the hull-pressure gate already reads.
- **The Shallows are fog-free:** **0 darkness at the surface, absent through the
  Shallows (0–50m)**, ramping up only once descent begins (shelf edge onward),
  toward the full per-zone cap in the deep. Surface play looks exactly as it does
  today.
- **Floodlight clear-zone:** **soft falloff** — the beam cone fades into the dark
  at its edges (no crisp lit/unlit boundary). Reuse/extend the Module-20 beam work
  (soft edges, hull occlusion already solved) rather than inventing a new cone.
- **Rendering model:** **fog is a darkness layer that the floodlight and the
  room interiors punch through.** A single dark-blue overlay sits over the outside
  water; the floodlight cone and the sub's lit interior are cut-outs / lighter
  regions in it. Not a global screen tint that dims everything equally.
- **Sub interior stays lit:** **windows and room interiors remain fully readable
  at any depth** — only the surrounding water darkens. The sub also casts a faint
  ambient bubble of its own readability so the hull never sits in a black void.

### Build notes (non-binding — the build session owns the how)
- A `CanvasModulate` / dark-blue overlay layer over the world, *under* the sub +
  HUD layers so it never tints crew/rooms/UI. Depth drives its alpha/value via the
  continuous-with-cap curve.
- The floodlight cone and the hull's lit-interior bubble are subtractive cut-outs
  (Light2D punch-through, or a second masked layer) so the dark recedes where
  light is. Lean on the existing `PointLight2D`/cone the pod already uses.
- All numbers go in a **new `FogFeel` block (`GameFeel.fog`)** in
  `autoload/game_feel.gd`, `deeper-tuner`-friendly: surface-clear depth, ramp
  start depth (shelf edge), per-zone darkness caps, dark-blue color, falloff
  softness on the floodlight cut-out, the sub's ambient-bubble radius. Add the row
  to `TUNING.md`.
- Floodlight reach/cone/falloff numbers stay in `FloodlightFeel`; `FogFeel` only
  owns the *darkness*, not the *light*. Keep the two blocks from overlapping.

### ⏸ Mid-build playtest checkpoint (REQUIRED — Snir's call)
After fog renders and the floodlight punches through it, **stop and hand Snir a
playable build** before touching the dock fix. The fog is the whole *feel* of the
milestone and is almost entirely tuning — it must be felt, not guessed. Capture
stills (surface = clear, mid-descent = thickening, deep-with-floodlight = a lit
pocket in the dark) and let Snir drive it and tune `FogFeel` before Module 2.

---

## Module 2 — Dock-Return Fix (the bug)

Returning from the dry dock currently puts the sub at the wrong dock now that the
live map has **more than one**. Fix: you re-enter the world at **the dock you
actually left**.

### Locked design decisions (from scope round)
- **Identity:** key on the **last dock physically docked-at / touched** — the dock
  the sub was at when it opened the dry dock is the dock it returns to. Not
  "nearest," not a separately-set home dock — the one you were physically on.
- **Multiple docks already exist in the live map**, so this is a real, reproducible
  bug, not forward-looking polish — it should be verifiable by docking at a
  non-default dock, entering the dry dock, and confirming you come back to that
  same one.

### Build notes (non-binding)
- On dock entry (the existing dock-prompt / Tab-opens-dry-dock path, see
  `STATUS.md` dry-dock history), record the **active dock's identity** (id /
  position of the docking-zone the sub was touching). On dry-dock close / world
  re-entry, restore the sub to **that** dock instead of a hard-coded or default
  spawn.
- Watch the **implosion-reset and buy-a-room rebuild paths** — `_rebuild_sub()` /
  `reset_run()` re-spawn the sub and have historically dropped state (see the M10
  Shoal `_rebuild_sub` group-repoint fix). Make sure the remembered dock survives a
  dock-side purchase rebuild but a **run reset** still returns to the run's proper
  start dock — confirm which is intended for each path; don't silently conflate
  "returned from shopping" with "imploded and reset."
- Likely touches `world.gd` (dock prompt / dry-dock open+close / sub respawn) and
  wherever the docking-zone blocks are identified (the brown `#6E473B` docking-zone
  tiles noted in `STATUS.md`). No new `GameFeel` numbers expected.

---

## Out of scope (hard guardrails)

- **No art pass.** Do not add the pixelation shader, swap to a vector style, open
  the two art branches, or touch sprite/asset pipeline. The fog overlay is the
  *only* visual-layer change. (The art experiment is a separate parked spike.)
- **No vision/AI changes.** Fog must not alter any detection range, give-up range,
  hitbox, or AI behaviour. Cosmetic only. Grep the diff: nothing in `FishFeel` /
  `FlockFeel` / `SpitterFeel` / enemy `.tres` should change.
- **No economy / room-price changes.** `DockFeel` slot prices, room color-costs,
  currency drops — all untouched. (Re-parked, again.)
- **No new fauna, no new rooms, no boss work.**
- **No new death path.** Flooding-only stands. Fog can't drown you, blind you into
  a hidden hazard, or gate survival.
- **Stay on Godot 4.4.1.** No engine upgrade in this milestone.

---

## Verification

**Headless (every step):** `"D:\Godot_v4.4.1-stable_win64.exe" --headless --path .
--quit` must show no parse/load errors. If a new `class_name` is introduced (e.g.
a fog-controller node), run `"...Godot..." --headless --path . --import` once (the
documented stale-class-cache trap). Tests run via the `deeper-test-runner`
subagent.

**Show, don't tell:** use the `capture-gameplay` skill to screenshot (a) the
surface looking clear/unchanged, (b) a mid-descent frame with the fog thickening,
(c) a deep frame where the floodlight carves a soft-edged lit pocket out of the
dark with the sub interior still fully readable — show Snir.

**Verify by playing** — launch `"D:\Godot_v4.4.1-stable_win64.exe" --path .`:
- **Shallows are clear.** At the surface and across the Shallows the world looks
  exactly as before — no tint, no darkness.
- **It closes in as you sink.** Crossing the shelf edge and descending, the outside
  water should darken smoothly toward the per-zone cap — continuous, but never
  fully black before its zone.
- **The floodlight matters now.** In the dark, aim the floodlight — it should carve
  a **soft-edged** lit cone out of the fog. Crew, rooms, and windows stay fully
  readable the whole time; the sub never sits in a pure-black void.
- **Cosmetic only.** Fauna should detect, chase, and bite exactly as before in the
  dark — the darkness changes nothing but what *you* can see.
- **The dock you left.** Dock at a **non-default** dock, open the dry dock, then
  close it — you should return to **that same dock**, not snap to another one. Buy
  a room from that dock and confirm you're still at it after the rebuild.

---

## Open items for the build session to resolve with Snir (do not guess)
1. **Per-zone darkness caps** — the exact ceiling value for each of the 4 zones
   (Shallows = 0). First-pass numbers in `FogFeel`; lock the curve in the mid-build
   playtest.
2. **Dark-blue hue** — the precise fog color; confirm against the descent mood (a
   single `FogFeel` color, tunable). Verify it reads as "deep water," not "night."
3. **Floodlight cut-out softness** — how soft the cone's fade-into-dark is; tune
   alongside the Module-20 beam edges so they feel like one system.
4. **Ambient sub-bubble radius** — how far the sub's own readability glow reaches
   into the fog (0 = floodlight-only; small = "you can always see your hull's
   immediate surroundings"). Snir's feel call in playtest.
5. **Run-reset vs. shop-rebuild dock identity** — confirm that returning from the
   dry dock restores the *touched* dock, but a full **implosion run-reset** still
   returns to the run's intended start dock (don't conflate the two respawn paths).

---

## Session-end ritual (per CLAUDE.md)
1. Update `STATUS.md`: depth fog shipped (continuous-with-per-zone-cap darkness
   layer, Shallows-clear, floodlight + interior punch-through, cosmetic-only);
   dock-return fixed (returns to the last-touched dock); file-map changes; known
   issues; **the art pass + the economy balance pass remain parked** as future work.
2. Append to `DECISIONS.md`: the M11 scoping (fog + dock only; **art pass parked as
   a post-vertical-slice spike**, **economy re-parked again**); the fog design
   rulings (continuous gradient + per-zone cap, Shallows fog-free, soft-falloff
   floodlight cut-out, **fog is cosmetic-only — no vision/AI gate**, sub interior
   always readable); the dock-return rule (last-physically-touched dock); and the
   **first atmosphere/lighting-layer precedent** in the codebase (the depth-fog
   overlay).
3. Commit per working module (fog, then dock); update `TUNING.md` with the new
   `FogFeel` row; hand Snir the `git push`.
