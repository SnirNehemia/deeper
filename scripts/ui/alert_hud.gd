class_name AlertHud
extends CanvasLayer

## Breach alert overlay: a brief screen-edge flash in the danger color when a
## new breach opens. The breach itself carries its own anchored warning blink
## (see Breach), so this layer only handles the full-screen "something just
## went wrong" moment.

var _flash: ColorRect
var _tween: Tween

func _ready() -> void:
	_flash = ColorRect.new()
	_flash.color = Color(PlaceholderArt.BREACH_COLOR, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

## Watch a sub: flash whenever it spawns a breach, scaled by how bad the leak is.
func watch(sub: Sub) -> void:
	sub.breach_spawned.connect(func(b: Breach) -> void: flash(b.leak_rate))

## One edge flash: snap to visible, fade out fast. Alpha scales with leak_rate
## so a bite is a flinch and a ram is a slam (M5: severity-scaled feedback).
func flash(leak_rate: float = GameFeel.water.leak_rate_max) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var w := GameFeel.water
	var t := clampf(leak_rate / w.leak_rate_max, 0.0, 1.0)
	var alpha: float = lerpf(0.1, GameFeel.breach.flash_alpha_max, t)
	_flash.color = Color(PlaceholderArt.BREACH_COLOR, alpha)
	_tween = create_tween()
	_tween.tween_property(_flash, "color:a", 0.0, 0.8)
