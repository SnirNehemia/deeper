extends Node2D

## Throwaway visual capture of the Shore Shelf map: places the sub down by the
## shelf edge so the screenshot shows the cliff, basin, pillars, cave, water
## gradient, and depth HUD. Saves res://world_capture.png and quits.

func _ready() -> void:
	add_child(ShoreShelf.new())

	var sub := Sub.new()
	sub.position = Vector2(132.0 * 48.0, 66.0 * 48.0)  # nosed into the cave
	add_child(sub)
	for i in 60:
		await get_tree().physics_frame

	var p1 := Crew.new()
	p1.player_index = 99
	p1.position = Vector2(-240, -60)
	sub.add_child(p1)
	var p2 := Crew.new()
	p2.player_index = 99
	p2.body_color = PlaceholderArt.CREW_P2_COLOR
	p2.position = Vector2(40, -60)
	sub.add_child(p2)

	var cam := Camera2D.new()
	var zoom := get_viewport().get_visible_rect().size.x / (60.0 * 48.0)
	cam.zoom = Vector2(zoom, zoom)
	cam.position = sub.position
	add_child(cam)
	cam.make_current()

	var hud := DepthHud.new()
	hud.sub = sub
	add_child(hud)

	await _capture()

func _capture() -> void:
	for i in 60:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://world_capture.png")
	get_tree().quit(0)
