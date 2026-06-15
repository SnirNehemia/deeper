extends SceneTree

## One-off generator for the M6 Module 2 test map assets. Run once with:
##   godot --headless --script res://tests/gen_test_map.gd
## Produces res://maps/test_map/*.png + test_map.json. Re-run any time the
## marker layout needs to change; the outputs are checked into the repo.

const DIR := "res://maps/test_map"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))

	_write_generation_layer()
	_write_physical_layer()
	_write_visual_layer(DIR + "/test_map_bg.png", Color(0.10, 0.25, 0.45), Color(0.06, 0.16, 0.32))
	_write_visual_layer(DIR + "/test_map_fg.png", Color(0.05, 0.08, 0.07, 0.9), Color(0.0, 0.0, 0.0, 0.0))
	_write_config()

	print("Test map assets written to " + DIR)
	quit()

## 10x10 image, transparent except for four marker pixels (one per spawn
## color from MILESTONE_6 Module 2):
##   (1,1) white   -> player spawn
##   (5,2) purple  -> territorial fish
##   (8,8) green   -> hunter fish
##   (3,8) grey    -> wreckage
func _write_generation_layer() -> void:
	var img := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.set_pixel(1, 1, Color(1, 1, 1))       # #FFFFFF
	img.set_pixel(5, 2, Color(0.5, 0, 0.5))   # #800080
	img.set_pixel(8, 8, Color(0, 1, 0))       # #00FF00
	img.set_pixel(3, 8, Color(0.5, 0.5, 0.5)) # #808080
	img.save_png(DIR + "/test_map_gen.png")

## 10x10 image with one merge-able run per terrain type (M6 Module 3):
##   row 0, x0-4 grey    (#808080) -> normal rock, 5px run
##   row 1, x0-3 tan     (#D2B48C) -> sand
##   row 2, x0-1 black   (#000000) -> sharp rock
##   row 3, x0-2 brown   (#6E473B) -> docking zone
func _write_physical_layer() -> void:
	var img := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(0, 5):
		img.set_pixel(x, 0, Color(0.5, 0.5, 0.5))
	for x in range(0, 4):
		img.set_pixel(x, 1, Color(0xD2 / 255.0, 0xB4 / 255.0, 0x8C / 255.0))
	for x in range(0, 2):
		img.set_pixel(x, 2, Color(0, 0, 0))
	for x in range(0, 3):
		img.set_pixel(x, 3, Color(0x6E / 255.0, 0x47 / 255.0, 0x3B / 255.0))
	img.save_png(DIR + "/test_map_phys.png")

## M6 Module 4: a 10x10 checkerboard so nearest-neighbor scaling is visible
## as crisp 48px squares once placed in the world. `even`/`odd` are the two
## tile colors (the foreground layer uses a mostly-transparent checker so it
## reads as a sparse rocky silhouette).
func _write_visual_layer(path: String, even: Color, odd: Color) -> void:
	var img := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	for y in 10:
		for x in 10:
			img.set_pixel(x, y, even if (x + y) % 2 == 0 else odd)
	img.save_png(path)

func _write_config() -> void:
	var data := {
		"map_id": "test_map",
		"pixels_per_meter": 1.0,
		"physical_layer": DIR + "/test_map_phys.png",
		"generation_layer": DIR + "/test_map_gen.png",
		"visual_background": DIR + "/test_map_bg.png",
		"visual_foreground": DIR + "/test_map_fg.png",
	}
	var file := FileAccess.open(DIR + "/test_map.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  "))
	file.close()
