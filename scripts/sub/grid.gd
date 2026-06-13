class_name SubGrid
extends RefCounted

## Grid constants for the modular submarine (Milestone 4, see
## MODULAR_SUB_IMPLEMENTATION.md §2 and ROOM_SYSTEM.md §2). One uniform cell =
## 5.0m wide x 3.0m tall (5 sections of 1.0m each), at the locked 1m = 48px
## scale (GameFeel.PIXELS_PER_METER). Integer Vector2i grid positions: +x
## toward the bow (right), +y downward. Never re-derive these constants
## locally.
##
## Cell width settled at 5m (1m sections) after the Checkpoint 1 playtest:
## the 3.75m draft read too narrow, 7.5m too wide. One section = 1 metre.

const CELL_W_M := 5.0
const CELL_H_M := 3.0

## A room's interior width is divided into 5 equal sections (s1-s5), each
## 1.0m wide (ROOM_SYSTEM.md §2). This is an authoring-layer constant; the
## generation pipeline never sees section indices, only the coordinates they
## bake to.
const SECTION_W_M := 1.0

## 5.0m * 48px/m = 240px, 3.0m * 48px/m = 144px.
const CELL_W_PX := 240.0
const CELL_H_PX := 144.0

## Bounds sanity guard (§5 rule 7) — a technical guard only; real growth
## limiting is economic (price escalation), not this box.
const MAX_CELLS := Vector2i(8, 5)
