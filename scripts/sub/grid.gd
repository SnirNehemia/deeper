class_name SubGrid
extends RefCounted

## Grid constants for the modular submarine (Milestone 4, see
## MODULAR_SUB_IMPLEMENTATION.md §2). Cell = 2.5m wide x 3.0m tall, at the
## locked 1m = 48px scale (GameFeel.PIXELS_PER_METER). Integer Vector2i grid
## positions: +x toward the bow (right), +y downward. Never re-derive these
## constants locally.

const CELL_W_M := 2.5
const CELL_H_M := 3.0

## 2.5m * 48px/m = 120px, 3.0m * 48px/m = 144px.
const CELL_W_PX := 120.0
const CELL_H_PX := 144.0

## Bounds sanity guard (§5 rule 7) — a technical guard only; real growth
## limiting is economic (price escalation), not this box.
const MAX_CELLS := Vector2i(8, 5)
