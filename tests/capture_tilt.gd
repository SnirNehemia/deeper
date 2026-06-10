extends Node2D

## Throwaway visual capture: drive the sub to full tilt with crew standing at the
## ends, then save a screenshot so we can confirm the crew sit on the tilted
## floor. Run windowed (needs rendering), saves res://tilt_capture.png, quits.

var _sub: Sub

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = PlaceholderArt.SANDBOX_BG
	bg.size = Vector2(8000, 6000)
	bg.position = Vector2(-4000, -3000)
	bg.z_index = -100
	add_child(bg)

	_sub = Sub.new()
	add_child(_sub)

	var p1 := Crew.new()
	p1.player_index = 99  # no input
	p1.body_color = PlaceholderArt.CREW_P2_COLOR
	p1.position = Vector2(-300, -60)
	_sub.add_child(p1)

	var p2 := Crew.new()
	p2.player_index = 99
	p2.body_color = PlaceholderArt.CREW_P1_COLOR
	p2.position = Vector2(300, -60)
	_sub.add_child(p2)

	var cam := Camera2D.new()
	cam.position = Vector2(0, -40)
	add_child(cam)
	cam.make_current()

	await _capture()

func _capture() -> void:
	# Force max tilt directly, let crew settle on the tilted-art floor.
	for i in 200:
		_sub.drive_input = Vector2(1, 0)
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tilt_capture.png")
	get_tree().quit(0)
