class_name Wreck
extends Area2D

## A sunken wreck (~4m), placeholder broken-hull shape, sitting static on the
## seafloor. One torpedo hit cracks it open: it swaps to its "open" look and
## spills a few SalvageItems nearby that settle on the floor. Doesn't damage
## the sub and doesn't respawn within a run; `reset_wreck()` (called on the
## "wreck" group by `reset_run()`) reseals it and clears its spilled loot.

const HALF_LEN_PX := PlaceholderArt.WRECK_LENGTH_M * GameFeel.PIXELS_PER_METER * 0.5
const HALF_HEIGHT_PX := HALF_LEN_PX * 0.45

var cracked: bool = false
var _spilled: Array[SalvageItem] = []

## M5: HP. One torpedo (= hp_max) still cracks it open; a bullet burst also works.
var hp_max: float = GameFeel.wreck.hp_max
var hp: float = hp_max
var _hit_flash: float = 0.0

func _ready() -> void:
	add_to_group("wreck")
	collision_layer = Layers.WRECK
	collision_mask = Layers.PROJECTILE
	monitoring = true
	monitorable = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(HALF_LEN_PX, HALF_HEIGHT_PX) * 2.0
	shape.shape = rect
	add_child(shape)
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta)
		queue_redraw()

func _on_area_entered(area: Area2D) -> void:
	if cracked or not (area is Torpedo):
		return
	var dmg: float = GameFeel.bullet.damage if area is Bullet else GameFeel.turret.damage
	area.call_deferred("queue_free")
	hp -= dmg
	if hp <= 0.0:
		cracked = true  # guard re-entry now; the rest of _crack() runs deferred
		call_deferred("_crack")
	else:
		_hit_flash = GameFeel.fish.hit_flash_time
		queue_redraw()

## Cracked open: pop, swap to the open look, and spill 2-3 scrap crates that
## settle near the hull. Runs deferred (see _on_area_entered) so it doesn't
## add nodes mid physics-query flush.
func _crack() -> void:
	var pop := Torpedo.Puff.new()
	pop.global_position = global_position
	get_parent().add_child(pop)

	var count := randi_range(2, 3)
	for i in count:
		var offset := Vector2(
			randf_range(-HALF_LEN_PX * 0.8, HALF_LEN_PX * 0.8),
			randf_range(-HALF_HEIGHT_PX, 0.0))
		var item := SalvageItem.make_scrap(global_position + offset)
		get_parent().add_child(item)
		_spilled.append(item)
	queue_redraw()

## World run reset: reseal the wreck and remove anything it spilled that's
## still drifting in the world (collected loot is unaffected once it's left
## the "salvage" group via the claw, same as carcasses/pickups elsewhere).
func reset_wreck() -> void:
	cracked = false
	hp = hp_max
	_hit_flash = 0.0
	for item in _spilled:
		if is_instance_valid(item):
			item.queue_free()
	_spilled.clear()
	queue_redraw()

func _draw() -> void:
	var color := PlaceholderArt.WRECK_OPEN_COLOR if cracked else PlaceholderArt.WRECK_COLOR
	if _hit_flash > 0.0:
		color = color.lerp(Color.WHITE, 0.6)
	var rect := Rect2(Vector2(-HALF_LEN_PX, -HALF_HEIGHT_PX), Vector2(HALF_LEN_PX, HALF_HEIGHT_PX) * 2.0)
	draw_rect(rect, color)
	draw_rect(rect, color.darkened(0.3), false, 2.0)
	if cracked:
		# A jagged hole in the hull where the torpedo hit.
		draw_colored_polygon(PackedVector2Array([
			Vector2(-HALF_LEN_PX * 0.25, -HALF_HEIGHT_PX * 0.6),
			Vector2(HALF_LEN_PX * 0.2, -HALF_HEIGHT_PX * 0.8),
			Vector2(HALF_LEN_PX * 0.35, 0.0),
			Vector2(HALF_LEN_PX * 0.1, HALF_HEIGHT_PX * 0.7),
			Vector2(-HALF_LEN_PX * 0.3, HALF_HEIGHT_PX * 0.5),
		]), Color.BLACK)
	else:
		# A couple of rivet-line details to read as a hull.
		draw_line(Vector2(-HALF_LEN_PX * 0.6, -HALF_HEIGHT_PX), Vector2(-HALF_LEN_PX * 0.6, HALF_HEIGHT_PX), color.darkened(0.3), 2.0)
		draw_line(Vector2(HALF_LEN_PX * 0.6, -HALF_HEIGHT_PX), Vector2(HALF_LEN_PX * 0.6, HALF_HEIGHT_PX), color.darkened(0.3), 2.0)
