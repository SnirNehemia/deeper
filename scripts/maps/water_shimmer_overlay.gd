class_name WaterShimmerOverlay
extends ColorRect

## M6 Module 4: the ambient water motion sub-module. A full-coverage panel
## with `shaders/water_shimmer.gdshader` applied, so everything drawn beneath
## it (background landscape, sub, crew, fish) gets a gentle, looping
## horizontal UV wobble — a cheap stand-in for fluid motion.

const SHADER_PATH := "res://shaders/water_shimmer.gdshader"

## Builds a shimmer overlay covering `world_size` (px), with its top-left at
## the origin — matching the background/foreground layers it sits between.
static func build(world_size: Vector2) -> WaterShimmerOverlay:
	var overlay := WaterShimmerOverlay.new()
	overlay.position = Vector2.ZERO
	overlay.size = world_size
	overlay.color = Color(1, 1, 1, 1)  # irrelevant: the shader fully overrides COLOR
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var material := ShaderMaterial.new()
	material.shader = load(SHADER_PATH)
	overlay.material = material

	return overlay
