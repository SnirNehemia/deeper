class_name EnemyClassStats
extends Resource

## Per-class (Small/Big/Elite) stat block for an EnemyDef (MILESTONE_8.md
## Module 0). Authored per-species in `.tres`; never edited from GameFeel —
## global spine tunables (knockback scalar, grab-tug bands, currency
## denominations) live there instead.

@export var damage: float = 1.0            ## breach severity inflicted per hit
@export var hp: float = 5.0
@export var room_weight: float = 1.0        ## M8 Module 1: ram-knockback scalar input
@export var size_scale: float = 1.0         ## M8 Module 3 (ART-PASS FLAG): size only
@export var move_speed: float = 3.5         ## m/s, headline aggression speed
@export var currency_drop_total: int = 0    ## M8 Module 4: denominated into 1/5/10/50 on death
@export var gold_drop: int = 0              ## elite premium currency; 0 for non-elite blocks
@export_enum("none", "ranged_spit", "brief_shield", "speed_burst", "NOVEL_HANDCODE") var elite_ability: String = "none"
