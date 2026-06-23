# CLAUDE.md — DEEPER

Couch co-op submarine roguelite, 1–4 players, Godot 4.x, GDScript. Side-view cutaway sub; crew runs between stations. Canon design lives in `DEEPER_design_doc_v0.3.md` (repo root). Read `STATUS.md` at session start and `DECISIONS.md` before proposing changes to anything settled.

## The developer
Snir does not read or write code and will not learn Godot. He is the designer; you are the entire engineering team. Consequences:
- Explain everything in game-behavior terms, never code terms.
- Every completed task ends with **"Verify by playing"** instructions: launch command + what to do in-game + what should happen. Never ask him to inspect code or logs.
- When something goes wrong, ask him what he *saw on screen*, not what the error says — but also capture console output yourself when running the game.
- Decisions about game design go to him; decisions about implementation are yours. Don't ask him to choose between technical approaches.
- When he floats a new design idea (mechanic, room, enemy, economy/balance change), you may pressure-test it first with the `deeper-design-critic` subagent (`.claude/agents/`) — a vision-protective skeptic that grounds critique in the design doc + `DECISIONS.md`. Use it to sharpen or sanity-check before building, not as a gate; the final design call is always his.

## Environment
- Windows. Plain local folder (no OneDrive/sync issues). GitHub remote configured.
- Godot 4.x is installed but its path is unknown. **First session task:** locate the executable (try `where godot`, common install paths under `Program Files`/`AppData`, Start Menu shortcuts), verify with `--version`, then **edit this file** to record the full path here:
  - `GODOT_PATH = D:\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe`
  - Confirmed version: **4.4.1.stable** — target Godot 4.4 API.

## Build & verify discipline
- After every change set: run a headless check before declaring success. Minimum: launch the project headless (`"GODOT_PATH" --headless --path . --quit`) and treat any script parse/load errors as failures. For logic that can run without rendering, prefer a quick headless test scene/script.
- For features that need eyes (movement feel, water rising), do the headless check, then hand Snir the verify-by-playing steps. Launch command for him: `"GODOT_PATH" --path .` (or the editor's play button — give both). For visual changes, use the `capture-gameplay` skill to render a screenshot and **show** him the result instead of only describing it.
- The project must always run from a fresh clone: no manual editor setup steps, no absolute paths in code, scenes as `.tscn` text or constructed in code.
- **Delegate headless test runs to the `deeper-test-runner` subagent** (`.claude/agents/`) to keep verbose test output out of the main context. Tell it what changed; it picks the smallest relevant test set (or ask for "full regression" before a module-complete commit) and returns a terse pass/fail verdict. It runs/reports only — fixing failures stays with the main agent.

## Code rules
- GDScript only. Godot **4.x** APIs — never Godot 3 patterns (no `KinematicBody2D`, no `yield`, use `CharacterBody2D`, `await`, typed GDScript where natural).
- English for all code, comments, and asset names.
- **Input abstraction is sacred:** every player is a `PlayerInput` provider (keyboard-split now; gamepad and WebSocket-phone providers later). No node reads raw input directly except providers.
- **Game feel lives in one config** (autoload or single resource): movement accel/decel, water flow rate, etc. Canon: sub = heavy but controllable; crew = slightly weighty (keep a "snappy" preset switchable for playtests). When Snir gives playtest feel feedback, you may hand it to the `deeper-tuner` subagent (`.claude/agents/`) to apply the parameter edit + headless check + verify-by-playing, keeping the tuning ping-pong out of the main context. It executes his directives only — it never decides balance itself.
- Placeholder art only (colored rects, labeled shapes) at consistent sizes; centralize asset paths so the future art swap is cheap.
- No third-party addons or dependencies without asking Snir first (in design terms: what it adds, what it risks).

## Task sizing
Briefs arrive as feature-sized chunks. Break them into internal steps yourself; headless-check after each step; never declare a feature done with a known-broken intermediate state.

## Git
- Auto-commit after each **module is complete** (headless check passed). Do not commit after every small tuning tweak or intermediate iteration — group related changes into one commit when a feature or fix is fully working end-to-end. Never commit a broken state. Push to GitHub at session end.

## Session end ritual
Run the `session-wrap` skill, which walks these steps:
1. Update `STATUS.md`: what was built, file-map changes, known issues, suggested next step.
2. Append any newly settled or parked decisions to `DECISIONS.md`.
3. Commit. (Pushing is Snir's — hand him `git push`; there's no GitHub auth here.)
