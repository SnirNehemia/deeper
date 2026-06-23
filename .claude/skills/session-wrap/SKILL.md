---
name: session-wrap
description: >-
  Run DEEPER's end-of-session ritual: confirm tests are green, update STATUS.md,
  append any newly settled/parked decisions to DECISIONS.md, refresh the memory
  status pointer, and make a clean commit — then hand Snir the exact push command
  (pushes are his to do). Use when Snir says "wrap up", "let's end here", "close
  out the session", "update the docs and commit", or at the natural end of a work
  block. Do NOT use mid-feature on a known-broken state.
---

# DEEPER session wrap

The end-of-session ritual from `CLAUDE.md`, as a checklist so nothing is skipped
and the status docs never drift. Run it only when the work is at a clean,
committable stopping point.

## 0. Never wrap on red

First confirm the build is green. Delegate to the `deeper-test-runner` subagent
(tell it what changed, or ask for full regression if this closes a module), or at
minimum boot headless clean:
`"D:\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe" --headless --path . --quit`.
If anything is newly broken, **stop and fix it (or tell Snir) before wrapping** —
do not commit a broken state. Pre-existing known failures (tracked in STATUS.md)
are fine; new ones are not.

## 1. Update `STATUS.md`

`STATUS.md` is the first thing read next session — keep it accurate.
- Update the top `_Last updated: <date>_` line and its one-line summary to point
  at what just shipped and the next step.
- Add a dated entry describing: **what was built**, **file-map changes** (new/
  moved scripts, new GameFeel keys, new tests), **known issues**, and a
  **suggested next step**. Match the voice of the existing entries.
- Convert any relative dates to absolute (today's date).

## 2. Append to `DECISIONS.md` (only if something was settled or parked)

`DECISIONS.md` is **append-only**. If this session settled a design question or
parked an idea, add a dated `## Settled (<date>, <topic>)` block in the existing
style — the *why*, not just the *what*. If nothing was decided, skip this step;
don't pad it.

## 3. Refresh memory status pointer

Update the auto-memory `project_status.md` (in the memory dir, indexed in
MEMORY.md) so next session's recall reflects the new milestone/next-step. Keep it
to the durable state, not this session's play-by-play.

## 4. Commit (clean, grouped, never broken)

- Group the session's related changes into a coherent commit (or a few), per the
  `CLAUDE.md` "commit when a feature/fix is fully working end-to-end" rule. Don't
  commit throwaway capture scenes or `captures/` output.
- Write a descriptive message in the repo's style (`M<milestone>-<module>: …` for
  feature work). End the message with:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
- If on `main`, that's this project's normal working branch — committing there is
  fine per the project's git habits.

## 5. Hand Snir the push (do NOT push yourself)

Pushing is **Snir's** to do — there's no GitHub auth in this environment, so a
push from here will fail. Don't attempt it. Instead, end by telling him plainly:

> Committed locally. To back it up to GitHub, run:
> `git push`

and give a one-line summary of what the commit contains, so he knows what he's
pushing.

## 6. Final summary to Snir

Close with a short, game-terms recap: what's now in the game, what changed since
last session, and the suggested next step — plus any "verify by playing" steps
for features that need his eyes. No code talk.
