class_name EnemyDef
extends Resource

## Per-species enemy data (MILESTONE_8.md Module 0). One `.tres` per species
## lives under res://data/enemies/, authored against this schema. Global
## tunables (knockback scalar, grab-tug force bands, currency denominations,
## ranged-projectile base behavior) live in GameFeel instead — this resource
## holds only what varies species-to-species.

enum Class { SMALL, BIG, ELITE }

@export var species_name: String = ""
@export var body_color: Color = Color.WHITE      ## visual identity
@export var currency_color: String = ""          ## non-reserved palette name; independent of body_color
@export var ranged: bool = false                 ## base trait, applies to all classes
@export var grabbable: bool = true
@export var class_small: EnemyClassStats
@export var class_big: EnemyClassStats
@export var class_elite: EnemyClassStats         ## the only block carrying an elite ability

func stats_for(c: Class) -> EnemyClassStats:
	match c:
		Class.BIG:
			return class_big
		Class.ELITE:
			return class_elite
		_:
			return class_small
