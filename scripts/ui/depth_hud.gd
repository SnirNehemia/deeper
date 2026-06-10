class_name DepthHud
extends CanvasLayer

## Top-center depth meter: how far below the surface the sub is, live in meters.
## Reads 0 while the sub floats at the surface (see Sub.depth_m()).

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
	_label.text = "Depth  %d m" % int(round(sub.depth_m()))
