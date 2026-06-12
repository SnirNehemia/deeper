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

	_add_debug_buttons()

## TEMP playtest aid: two buttons under the readout that drop salvage straight
## into storage, so we can test the storage pen / banking without grinding the
## claw. (Respects the storage cap.) Remove when debug mode is no longer needed.
func _add_debug_buttons() -> void:
	_add_debug_button("+1 scrap", -340, SalvageItem.Kind.SCRAP)
	_add_debug_button("+1 carcass", -236, SalvageItem.Kind.FISH)

func _add_debug_button(text: String, left: float, kind: int) -> void:
	var btn := Button.new()
	btn.text = text
	btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn.offset_left = left
	btn.offset_right = left + 96.0
	btn.offset_top = 78.0
	btn.offset_bottom = 104.0
	btn.pressed.connect(func() -> void:
		if sub != null:
			sub.deposit_salvage(kind))
	add_child(btn)

func _process(_delta: float) -> void:
	if sub == null:
		return
	_label.text = "Storage: %d/%d (%d scrap, %d carcasses)\nBanked: %d scrap, %d carcasses" % [
		sub.storage_count(), GameFeel.claw.storage_capacity,
		sub.storage_scrap, sub.storage_fish,
		SaveData.banked_scrap, SaveData.banked_fish,
	]
