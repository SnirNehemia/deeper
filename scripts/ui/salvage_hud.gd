class_name SalvageHud
extends CanvasLayer

## Top-right salvage readout (Module B): the storage pen (at risk until banked)
## vs. what's already banked and saved. Plus a Debug-mode toggle that reveals
## playtest-only "add salvage" buttons.

var sub: Sub

var _label: Label
var _debug: bool = false
var _debug_buttons: Array[Button] = []

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

	_build_debug_controls()

## A "Debug" toggle button plus the (hidden by default) add-salvage buttons it
## reveals. The buttons are a playtest aid — gate is off in normal play.
func _build_debug_controls() -> void:
	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.text = "Debug mode"
	toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toggle.offset_left = -132
	toggle.offset_right = -12
	toggle.offset_top = 78.0
	toggle.offset_bottom = 104.0
	toggle.toggled.connect(_on_debug_toggled)
	add_child(toggle)

	_debug_buttons.append(_make_debug_button("+1 scrap", -340, SalvageItem.Kind.SCRAP))
	_debug_buttons.append(_make_debug_button("+1 carcass", -236, SalvageItem.Kind.FISH))
	_apply_debug_visibility()

func _make_debug_button(text: String, left: float, kind: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn.offset_left = left
	btn.offset_right = left + 96.0
	btn.offset_top = 110.0
	btn.offset_bottom = 136.0
	btn.pressed.connect(func() -> void:
		if sub != null:
			sub.deposit_salvage(kind))
	add_child(btn)
	return btn

func _on_debug_toggled(on: bool) -> void:
	_debug = on
	_apply_debug_visibility()

func _apply_debug_visibility() -> void:
	for b in _debug_buttons:
		b.visible = _debug

func _process(_delta: float) -> void:
	if sub == null:
		return
	_label.text = "Storage: %d/%d (%d scrap, %d carcasses)\nBanked: %d scrap, %d carcasses" % [
		sub.storage_count(), GameFeel.claw.storage_capacity,
		sub.storage_scrap, sub.storage_fish,
		SaveData.banked_scrap, SaveData.banked_fish,
	]
