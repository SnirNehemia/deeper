extends Node

## Headless test for M6 Module 4: VisualLayerBuilder, WaterShimmerOverlay, and
## MapVisualLayers assembly/ordering.
##
## Run: godot --headless res://tests/test_visual_layers.tscn

const M := GameFeel.PIXELS_PER_METER

var _failures := 0

func _ready() -> void:
	_test_layer_build()
	_test_shimmer_overlay()
	_test_stack_assembly()
	if _failures == 0:
		print("VISUAL LAYER TESTS PASSED")
		get_tree().quit(0)
	else:
		push_error("VISUAL LAYER TESTS FAILED: %d failing check(s)" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok:   ", msg)
	else:
		push_error("  FAIL: " + msg)
		_failures += 1

func _test_layer_build() -> void:
	print("[visual layer build]")
	var config := MapConfig.load_from_json("res://maps/test_map/test_map.json")
	var sprite := VisualLayerBuilder.build_layer(config.visual_background, config.pixel_scale())

	_check(sprite != null, "background layer loads")
	_check(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"background uses nearest-neighbor filtering")
	_check(not sprite.centered, "background origin is top-left (not centered)")
	_check(sprite.scale == Vector2(M, M), "background scaled to 1 source px = %dpx world" % int(M))

	var world_size := VisualLayerBuilder.world_size(sprite.texture.get_size(), config.pixel_scale())
	_check(world_size == Vector2(10, 10) * M, "10x10 source image -> 480x480 world size")
	sprite.free()

func _test_shimmer_overlay() -> void:
	print("[water shimmer overlay]")
	var overlay := WaterShimmerOverlay.build(Vector2(480, 480))
	_check(overlay.size == Vector2(480, 480), "overlay covers the requested world size")
	_check(overlay.material is ShaderMaterial, "overlay has a ShaderMaterial")
	_check((overlay.material as ShaderMaterial).shader.resource_path == WaterShimmerOverlay.SHADER_PATH,
		"overlay uses the water shimmer shader")
	_check(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "overlay doesn't block input")
	overlay.free()

func _test_stack_assembly() -> void:
	print("[map visual layer stack]")
	var config := MapConfig.load_from_json("res://maps/test_map/test_map.json")
	var layers := MapVisualLayers.build(config)
	add_child(layers)

	_check(layers.background != null, "background built")
	_check(layers.foreground != null, "foreground built")
	_check(layers.shimmer != null, "shimmer overlay built")

	_check(layers.background.z_index < 0, "background renders behind gameplay (z < 0)")
	_check(layers.shimmer.z_index > layers.background.z_index and layers.shimmer.z_index < 0,
		"shimmer sits between background and gameplay (only wobbles the background art)")
	_check(layers.foreground.z_index > layers.shimmer.z_index,
		"foreground renders in front of everything")

	_check(layers.shimmer.size == Vector2(10, 10) * M,
		"shimmer sized to the background's world dimensions")

	remove_child(layers)
	layers.free()
