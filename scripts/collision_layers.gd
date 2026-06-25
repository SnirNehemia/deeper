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
const STATION := 1 << 6    ## station interaction zones (helm, etc.)
const PROJECTILE := 1 << 7 ## torpedoes (hit terrain and fish, never the own hull)
const FISH := 1 << 8       ## enemy fauna bodies
const SALVAGE := 1 << 9    ## scrap pickups and fish carcasses, collected by the hull
const WRECK := 1 << 10     ## sunken wrecks, cracked open by a torpedo hit
const ENEMY_PROJECTILE := 1 << 11 ## ranged-enemy shots (hit terrain and the own hull, never fish)
## MILESTONE_9.md — THE SPITTER: a destructible bubble. It hits the hull/terrain
## and is also shootable out of the air by player projectiles, so it masks
## PROJECTILE too. The bubble owns the duel logic (it mutates/frees the shot),
## so player projectile masks are unchanged.
const BUBBLE := 1 << 12     ## spitter bubbles (hit hull/terrain; shootable by player ammo)
