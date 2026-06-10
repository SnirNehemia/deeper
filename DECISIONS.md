# DECISIONS.md — DEEPER

*Append-only log. Check before re-opening anything. "Parked" = good idea, wrong time.*

## Settled (2026-06-10)
- **Structure:** run-based roguelite with persistent sub upgrades (not a campaign)
- **View:** side cutaway interior; sub stays upright (slight pitch tilt for feel; no Lovers-style spin)
- **Players:** 1–4 local co-op; keyboard-split only until fun is proven; 2 cheap XInput gamepads to be ordered before 3–4 player tests; phone-as-controller (WebSocket) deferred to post-MVP
- **Workflow:** Claude Project = design/specs; Claude Code = all building; Snir does not read code
- **Briefs:** feature-sized chunks; Claude Code self-decomposes
- **Git:** auto-commit per working feature; push at session end
- **Feel:** sub heavy-but-controllable; crew slightly weighty; all feel values in one tunable config
- **Run length target:** 30–45 min full runs (eventually); MVP win condition stays short (reach 500m)
- **Playtest cadence:** weekly with two testers — each week should ship something feelable
- **Damage model v1:** per-room water level only; no fluid sim, no fire, no wiring
- **Death penalty:** implosion keeps ~50% of salvage banked at last checkpoint buoy
- **Art:** placeholder-first; asset plan undecided; style target "cartoon shapes, pixel skin"
- **Scope:** no devlog/marketing content in this project

## Settled (2026-06-10, round 2)
- **Title locked:** DEEPER (repo: `deeper`)
- **Resolution strategy:** option (c) — HD canvas (1920×1080 base) with chunky pixel sprites at one locked texel density; smooth camera/rotation allowed
- **Ocean structure (canon change, doc §6):** open 2D ocean; runs start at a shore station, cross the shallows over the continental shelf, plunge at the shelf edge; explorable side caves in deep zones
- **Camera:** fixed framing (sub + margin) for MVP; *parked:* auto-zoom and helm-controlled zoom for later versions
- **Helm control:** direct (occupant's stick pushes the sub) for MVP; *parked:* throttle + ballast scheme, decide post-MVP
- **Crew vulnerability:** crew can drown in flooded rooms; respawns at helm room after a delay; *no* revive mechanic in v1
- **Interior movement:** jump + ladders
- **Turret:** limited arc for MVP; revisit free-aim vs arc when module placement arrives
- **Milestone 1:** crew sandbox + working helm (sub moves through a shore/shelf test map); turret, water, enemies are Milestone 2+
- **Pacing:** ~5 dev-hours/week → milestones sized to ~1–2 weeks each

## Settled (2026-06-10, round 3)
- **Collision damage:** terrain impacts breach the hull, scaling with speed; gentle bumps free (M1 still has no damage system — arrives M2+)
- **Water after patching:** auto-drains in MVP; *parked:* dedicated pump station module later
- **Engine room:** prop in MVP, helm self-sufficient; functional engine arrives as a module post-MVP
- **Repair economy:** infinite hold-to-repair in MVP; patch kits become a resource with the repair bay module
- **Enemy aggression:** small fauna territorial (avoidable), large fauna hunts on detection
- **Tone:** genuinely tense deep zones; cute crew + cozy interior as the contrast anchor
- **Docs:** PLAYTEST_LOG.md added; no further doc files until a real need appears

## Settled (2026-06-10, round 4 — Milestone 1 build)
- **Engine:** Godot 4.4.1 stable (path in CLAUDE.md). Project: 1920×1080, canvas_items/expand, nearest filter.
- **Input:** provider pattern (PlayerInput snapshot + InputHub autoload); only providers read devices. P2 interact pinned to *right* Shift by key location to avoid cross-talk.
- **Crew height:** 1.2 m (was 1.5; shortened per playtest).
- **Crew collision:** crew are solid to each other — must jump over to pass (designer call).
- **Ladders (revised from spec):** pressing a direction does *not* drop you; you can climb and move sideways at once; you stay attached until you leave the ladder zone. The conning hatch is a solid deck you stand on — you drop through it only by pressing **down**.
- **Pitch tilt:** cosmetic only — hull *and crew art* tilt together, physics bodies stay upright (so nobody slides). Tilt ∝ horizontal speed, ±5°.
- **Ride-along:** crew are parented to the sub and ride it with zero sliding (verified) — no moving-platform physics needed for the interior.
- **Depth reference:** waterline = world y 0; depth = sub y / 48 px, clamped ≥ 0.

## Open
- **Solo play:** is "lock station" enough, or does solo need an AI helper (Lovers-style pet)? Answer via solo playtests during MVP.
- **Pitch direction/strength:** confirm the lean feels right in playtest (one-number tweak).

## Parked
- Snappy Overcooked-style crew movement (kept as switchable preset; playtest against weighty)
- Phone-as-controller via WebSocket (post-MVP, only if gamepads aren't enough)
- Godot MCP for Claude Code (revisit only if visual-bug iteration becomes painful)
- Fire/electrical damage systems (water must prove fun first)
- EVA dive-suit module (v1 content at earliest)
- Cosmetics (paint, flags, googly eyes) — vertical-slice era
