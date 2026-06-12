class_name SalvageHud
extends CanvasLayer

## Top-right salvage readout (Module B): what's currently on board (at risk
## until the sub gets back to dock) vs. what's already banked and saved.

var sub: Sub

var _label: Label

func _ready() -> void:
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_label.offset_left = -340
	_label.offset_top = 16
	_label.size = Vector2(324, 80)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)

func _process(_delta: float) -> void:
	if sub == null:
		return
	_label.text = "Storage: %d/%d (%d scrap, %d carcasses)\nBanked: %d scrap, %d carcasses" % [
		sub.storage_count(), GameFeel.claw.storage_capacity,
		sub.storage_scrap, sub.storage_fish,
		SaveData.banked_scrap, SaveData.banked_fish,
	]
