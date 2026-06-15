class_name MapVisualLayers
extends Node2D

## M6 Module 4: assembles a map's full visual stack in the order required by
## the spec:
##   1. visual_background  (behind the sub, players, and fish)
##   2. (gameplay: sub interior/stations/crew/objects/enemies — added by the
##      world separately, at the default z_index)
##   3. the ambient water shimmer overlay
##   4. visual_foreground  (in front of everything)

const Z_BACKGROUND := -100
const Z_SHIMMER := 50
const Z_FOREGROUND := 100

var background: Sprite2D
var shimmer: WaterShimmerOverlay
var foreground: Sprite2D

## Builds the full stack for `config`. World size is derived from the
## background image's pixel size (falls back to `fallback_world_size` if the
## background can't load).
static func build(config: MapConfig, fallback_world_size := Vector2(48.0, 48.0)) -> MapVisualLayers:
	var layers := MapVisualLayers.new()
	layers.name = "MapVisualLayers"

	var scale := config.pixel_scale()
	var world_size := fallback_world_size

	layers.background = VisualLayerBuilder.build_layer(config.visual_background, scale)
	if layers.background != null:
		layers.background.z_index = Z_BACKGROUND
		layers.add_child(layers.background)
		world_size = VisualLayerBuilder.world_size(layers.background.texture.get_size(), scale)

	layers.shimmer = WaterShimmerOverlay.build(world_size)
	layers.shimmer.z_index = Z_SHIMMER
	layers.add_child(layers.shimmer)

	layers.foreground = VisualLayerBuilder.build_layer(config.visual_foreground, scale)
	if layers.foreground != null:
		layers.foreground.z_index = Z_FOREGROUND
		layers.add_child(layers.foreground)

	return layers
