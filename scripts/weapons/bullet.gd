class_name Bullet
extends Torpedo

## A fast, low-damage round fired by the Bullet Room (M4-12, ROOM_SYSTEM.md §6
## "Bullet weapon room"). Same flight/hit/despawn behavior as Torpedo (small
## hitbox, terrain puff, one-hit fish kill) — just faster, smaller, and
## shorter-lived, with its own look.

func _ready() -> void:
	radius = 3.0
	lifetime = GameFeel.bullet.bullet_lifetime
	super._ready()

## A bullet deals its own (smaller) damage — so it only chips a 2-HP bubble and
## takes a second round to pop it, while a turret torpedo bursts one outright.
func damage_value() -> float:
	return GameFeel.bullet.damage

func _draw() -> void:
	# A small bright streak (local +x is the flight direction).
	draw_rect(Rect2(-10.0, -2.0, 18.0, 4.0), PlaceholderArt.HULL_COLOR)
	draw_circle(Vector2(8.0, 0.0), 2.5, PlaceholderArt.HULL_COLOR)
