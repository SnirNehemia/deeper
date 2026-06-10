class_name Layers
extends RefCounted

## Named physics collision layers (bit values), so nothing uses magic numbers.
##
## The split matters: crew collide only with the sub's INTERIOR (floors, walls,
## ladders), while the sub's HULL collides only with TERRAIN. That keeps the
## crew riding safely inside the hull without fighting the sub's own outer shell.

const TERRAIN := 1 << 0    ## world / ocean terrain
const SUB_HULL := 1 << 1   ## the sub's outer shell (vs terrain)
const CREW := 1 << 2       ## crew bodies
const INTERIOR := 1 << 3   ## sub interior floors/walls the crew stand on
const LADDER := 1 << 4     ## ladder climb zones
const HATCH := 1 << 5      ## solid deck over the ladder hole; crew pass it only while climbing
