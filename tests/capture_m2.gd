extends Node2D

## Throwaway visual capture for Milestone 2 sign-off: the sub nosed toward the
## cave (glowing marker visible), partially flooded with a live breach, a
## territorial fish nearby, and a torpedo in flight. Saves res://m2_capture.png
## and quits.

func _ready() -> void:
	add_child(ShoreShelf.new())

	var sub := Sub.new()
	sub.position = Vector2(140.0 * 48.0, 66.0 * 48.0)  # at the cave mouth
	add_child(sub)
	for i in 30:
		await get_tree().physics_frame

	# Flood + breaches of all three tiers so the colour/size difference shows.
	sub.water_levels = [0.45, 0.25, 0.1, 0.0, 0.0, 0.0]
	sub.spawn_breach(0, GameFeel.water.leak_rate_max, Vector2(sub.room_rect(0).position.x + 30.0, -70.0))  # red/big
	sub.spawn_breach(1, GameFeel.water.leak_rate_mid, Vector2(-30.0, -70.0))               # orange/med
	sub.spawn_breach(2, GameFeel.water.leak_rate_min, Vector2(sub.room_rect(2).end.x - 30.0, -70.0))   # yellow/small

	var p1 := Crew.new()
	p1.player_index = 99
	p1.position = Vector2(-240, -60)  # in the flooded engine room
	sub.add_child(p1)
	var p2 := Crew.new()
	p2.player_index = 99
	p2.body_color = PlaceholderArt.CREW_P2_COLOR
	p2.position = Vector2(70, -60)    # at the gunner seat
	sub.add_child(p2)

	var fish := Fish.new()
	fish.sub = sub
	fish.position = sub.position + Vector2(-14.0 * 48.0, -2.0 * 48.0)
	add_child(fish)

	var torpedo := Torpedo.new()
	torpedo.velocity = Vector2.LEFT * GameFeel.turret.torpedo_speed * 48.0
	add_child(torpedo)
	torpedo.global_position = sub.position + Vector2(-9.0 * 48.0, -1.5 * 48.0)

	var cam := Camera2D.new()
	var zoom := get_viewport().get_visible_rect().size.x / (60.0 * 48.0)
	cam.zoom = Vector2(zoom, zoom)
	cam.position = sub.position + Vector2(-6.0 * 48.0, 0)
	add_child(cam)
	cam.make_current()

	var hud := DepthHud.new()
	hud.sub = sub
	add_child(hud)

	await _capture()

func _capture() -> void:
	for i in 30:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://m2_capture.png")
	get_tree().quit(0)
