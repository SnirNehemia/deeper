class_name DepthHud
extends CanvasLayer

## Top-center depth meter: how far below the surface the sub is, live in meters.
## Surface (waterline) is world y = 0, so depth = sub.y / pixels-per-meter,
## clamped at 0 while at/above the surface.

var sub: Sub

var _label: Label

func _ready() -> void:
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.offset_top = 16
	_label.add_theme_font_size_override("font_size", 36)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)

func _process(_delta: float) -> void:
	if sub == null:
		return
	var depth := maxf(0.0, sub.global_position.y / GameFeel.PIXELS_PER_METER)
	_label.text = "Depth  %d m" % int(round(depth))
