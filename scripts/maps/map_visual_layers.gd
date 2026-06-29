class_name MapVisualLayers
extends Node2D

## M6 Module 4: assembles a map's full visual stack in the order required by
## the spec:
##   1. visual_background  (behind the sub, players, and fish)
##   2. (gameplay: sub interior/stations/crew/objects/enemies — added by the
##      world separately, at the default z_index)
##   3. the ambient water shimmer overlay
##   4. visual_foreground  (in front of plain gameplay, but BELOW the
##      depth-fog overlay — see Z_FOREGROUND, 2026-06-29 follow-up #4)

const Z_BACKGROUND := -100
const Z_SHIMMER := -50   # between background and gameplay (z=0), so only the
                         # background art wobbles — not the sub, crew, or fish
## 2026-06-29 follow-up #4 (Snir): was 100 (in front of EVERYTHING, including
## the depth-fog overlay at z=40 — the foreground used to poke through the
## darkness untouched). Now sits below the fog overlay so it gets darkened
## like the rest of the outside world, while staying above plain gameplay
## (fish/wrecks, z=0) for its original parallax-occlusion purpose.
const Z_FOREGROUND := 10

var background: Sprite2D
var shimmer: WaterShimmerOverlay
var foreground: Sprite2D
## The world-space size (px) the background image scales to — exposed so
## other per-frame layers (MILESTONE_11.md's depth fog) can size themselves
## to match without re-deriving it from the texture.
var world_size: Vector2 = Vector2.ZERO

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
	layers.world_size = world_size

	layers.shimmer = WaterShimmerOverlay.build(world_size)
	layers.shimmer.z_index = Z_SHIMMER
	layers.add_child(layers.shimmer)

	layers.foreground = VisualLayerBuilder.build_layer(config.visual_foreground, scale)
	if layers.foreground != null:
		layers.foreground.z_index = Z_FOREGROUND
		layers.add_child(layers.foreground)

	return layers
