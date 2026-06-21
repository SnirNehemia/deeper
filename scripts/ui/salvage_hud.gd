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
	toggle.focus_mode = Control.FOCUS_NONE  # don't eat Tab (opens the dry dock)
	toggle.text = "Debug mode"
	toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toggle.offset_left = -132
	toggle.offset_right = -12
	toggle.offset_top = 78.0
	toggle.offset_bottom = 104.0
	toggle.toggled.connect(_on_debug_toggled)
	add_child(toggle)

	_debug_buttons.append(_make_scrap_debug_button("+100 scrap", -340))
	_debug_buttons.append(_make_currency_debug_button("+100 teal", -236, "teal"))
	_debug_buttons.append(_make_currency_debug_button("+100 gold", -132, "gold"))
	_apply_debug_visibility()

## Debug shortcut: banks 100 scrap or color currency directly (so a single
## click affords a room/slot purchase in the dry dock), instead of the normal
## one-at-a-time storage-pen deposit.
func _make_scrap_debug_button(text: String, left: float) -> Button:
	var btn := _new_debug_button(text, left)
	btn.pressed.connect(func(): SaveData.bank(100))
	return btn

func _make_currency_debug_button(text: String, left: float, color: String) -> Button:
	var btn := _new_debug_button(text, left)
	btn.pressed.connect(func(): SaveData.bank(0, {color: 100}))
	return btn

func _new_debug_button(text: String, left: float) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE  # don't eat Tab (opens the dry dock)
	btn.text = text
	btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn.offset_left = left
	btn.offset_right = left + 96.0
	btn.offset_top = 110.0
	btn.offset_bottom = 136.0
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
	var storage_bits: Array[String] = ["%d/%d scrap" % [sub.storage_scrap, GameFeel.claw.storage_capacity]]
	for code in sub.storage_currency:
		storage_bits.append("%d %s" % [int(sub.storage_currency[code]), code])
	var banked_bits: Array[String] = ["%d scrap" % SaveData.banked_scrap]
	for code in SaveData.banked_currency:
		banked_bits.append("%d %s" % [int(SaveData.banked_currency[code]), code])
	_label.text = "Storage: %s\nBanked: %s" % [", ".join(storage_bits), ", ".join(banked_bits)]
