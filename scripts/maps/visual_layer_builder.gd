class_name VisualLayerBuilder
extends RefCounted

## M6 Module 4: builds the background/foreground Sprite2Ds for a map's
## visual_background and visual_foreground layers. Both are scaled exactly
## to world dimensions via MapConfig.pixel_scale() and use nearest-neighbor
## filtering so chunky pixel art stays sharp.

## Loads `path` as a texture and returns a Sprite2D positioned with its
## top-left at the origin, scaled so each source pixel covers
## `pixel_scale` world pixels. Returns null if the texture can't load.
static func build_layer(path: String, pixel_scale: float) -> Sprite2D:
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		push_error("VisualLayerBuilder: failed to load " + path)
		return null

	var texture := ImageTexture.create_from_image(image)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# pixel_scale is world-px-per-source-px, so a 1px source pixel becomes a
	# pixel_scale x pixel_scale world square.
	sprite.scale = Vector2(pixel_scale, pixel_scale)
	return sprite

## The world-space size (px) the layer covers, given the source image size.
static func world_size(image_size: Vector2i, pixel_scale: float) -> Vector2:
	return Vector2(image_size) * pixel_scale
