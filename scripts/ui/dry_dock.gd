class_name DryDock
extends CanvasLayer

## The dry-dock upgrade screen (Module D). Opens while docked; pauses the run
## and lets the crew spend banked scrap on three classes of upgrade:
##   - Add room     -> a second gun + control room (you pick the hardpoint).
##   - Upgrade room -> engine boost.
##   - Upgrade crew -> repair training.
##
## Buying the gun room drops into a "submarine design planning" view where you
## choose which end it bolts onto (stern or bow). Purchases persist via
## SaveData; on close the world rebuilds the sub so the changes show up.
##
## Navigated with W/S or arrows, Enter/Space to buy, Esc/Tab to leave. This is
## a menu, so it reads keys directly (like the world's Esc-to-quit) rather than
## going through the gameplay input abstraction.

signal closed(changed: bool)

enum Mode { LIST, PLACEMENT }

var _mode: Mode = Mode.LIST
var _index: int = 0
var _slot: SubLoadout.Slot = SubLoadout.Slot.STERN
var _changed: bool = false
var _note: String = ""
var _entries: Array = []
var _view: _View

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_entries = SubLoadout.catalog()
	get_tree().paused = true

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.07, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_view = _View.new()
	_view.dock = self
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	_note = ""
	if _mode == Mode.LIST:
		_list_key(key.physical_keycode)
	else:
		_placement_key(key.physical_keycode)
	_view.queue_redraw()

func _list_key(code: int) -> void:
	match code:
		KEY_UP, KEY_W:
			_index = wrapi(_index - 1, 0, _entries.size())
		KEY_DOWN, KEY_S:
			_index = wrapi(_index + 1, 0, _entries.size())
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_try_buy(_entries[_index])
		KEY_ESCAPE, KEY_TAB:
			_close()

func _placement_key(code: int) -> void:
	match code:
		KEY_LEFT, KEY_A:
			_slot = SubLoadout.Slot.STERN
		KEY_RIGHT, KEY_D:
			_slot = SubLoadout.Slot.BOW
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if SaveData.purchase("gun_room", _slot):
				_changed = true
				_note = "Gun room installed!"
			_mode = Mode.LIST
		KEY_ESCAPE:
			_mode = Mode.LIST

func _try_buy(entry: Dictionary) -> void:
	var id: String = entry["id"]
	if SaveData.loadout.owns(id):
		_note = "Already installed."
		return
	if not SaveData.can_afford(entry["cost"]):
		_note = "Not enough scrap (need %d)." % int(entry["cost"])
		return
	if entry.get("needs_slot", false):
		_mode = Mode.PLACEMENT
		_slot = SubLoadout.Slot.STERN
		return
	if SaveData.purchase(id):
		_changed = true
		_note = "%s installed!" % entry["label"]

func _close() -> void:
	get_tree().paused = false
	closed.emit(_changed)
	queue_free()


## The drawn view — title, the upgrade list, and the placement schematic. Reads
## live state off its parent dock.
class _View extends Control:
	var dock: DryDock

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		var w := size.x
		# Title.
		f.draw_string(get_canvas_item(), Vector2(80, 70), "DRY DOCK",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color("e0c060"))
		f.draw_string(get_canvas_item(), Vector2(80, 110),
			"Banked: %d scrap   %d fish" % [SaveData.banked_scrap, SaveData.banked_fish],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)

		if dock._mode == DryDock.Mode.PLACEMENT:
			_draw_placement(f)
		else:
			_draw_list(f)

		# Footer note + controls.
		if dock._note != "":
			f.draw_string(get_canvas_item(), Vector2(80, size.y - 96), dock._note,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("ff8c3a"))
		var hint := "W/S select   Enter buy   Esc/Tab leave" if dock._mode == DryDock.Mode.LIST \
			else "A/D pick the end   Enter confirm   Esc back"
		f.draw_string(get_canvas_item(), Vector2(80, size.y - 60), hint,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.7))

	func _draw_list(f: Font) -> void:
		var y := 190.0
		for i in dock._entries.size():
			var e: Dictionary = dock._entries[i]
			var owned: bool = SaveData.loadout.owns(e["id"])
			var afford: bool = SaveData.can_afford(e["cost"])
			var selected := i == dock._index
			if selected:
				draw_rect(Rect2(64, y - 30, 760, 64), Color(1, 1, 1, 0.10))
			var name_col := Color.WHITE
			if owned:
				name_col = Color(0.5, 0.9, 0.6)
			elif not afford:
				name_col = Color(0.6, 0.6, 0.65)
			var tag := "[%s]" % e["klass"]
			f.draw_string(get_canvas_item(), Vector2(80, y), tag,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("7aa0c0"))
			f.draw_string(get_canvas_item(), Vector2(80, y + 26), str(e["label"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 26, name_col)
			var right := "OWNED" if owned else "%d scrap" % int(e["cost"])
			f.draw_string(get_canvas_item(), Vector2(560, y + 22), right,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 24, name_col)
			f.draw_string(get_canvas_item(), Vector2(80, y + 50), str(e["desc"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 0.55))
			y += 86.0

	func _draw_placement(f: Font) -> void:
		f.draw_string(get_canvas_item(), Vector2(80, 190),
			"SUBMARINE DESIGN  —  choose where the gun room bolts on:",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
		# A little side-on schematic of the sub with the two hardpoint slots.
		var center := Vector2(size.x * 0.5, size.y * 0.5 + 20.0)
		var s := 0.62
		# Existing rooms (dim).
		var body := Color(0.45, 0.48, 0.56)
		_box(Rect2(-Sub.HALF_W, Sub.CEIL_Y, Sub.HALF_W * 2.0, Sub.ROOM_H), center, s, body)
		_box(Sub.HULL_CONN_RECT.grow(-Sub.HULL_MARGIN), center, s, body)
		_box(Rect2(-Sub.HALF_W, 0.0, Sub.HALF_W + Sub.DIV_X, Sub.LOWER_ROOM_H), center, s, body)
		# Slot outlines; the chosen one glows.
		var stern := Rect2(-Sub.HALF_W - Sub.ROOM_W, Sub.CEIL_Y, Sub.ROOM_W, Sub.ROOM_H)
		var bow := Rect2(Sub.HALF_W, Sub.CEIL_Y, Sub.ROOM_W, Sub.ROOM_H)
		_slot_box(stern, center, s, dock._slot == SubLoadout.Slot.STERN, "STERN  (gun aft)", f)
		_slot_box(bow, center, s, dock._slot == SubLoadout.Slot.BOW, "BOW  (gun fwd)", f)

	func _box(local: Rect2, center: Vector2, s: float, col: Color) -> void:
		draw_rect(Rect2(center + local.position * s, local.size * s), col)

	func _slot_box(local: Rect2, center: Vector2, s: float, on: bool, label: String, f: Font) -> void:
		var r := Rect2(center + local.position * s, local.size * s)
		if on:
			draw_rect(r, Color("e0c060"))
			draw_rect(r, Color.WHITE, false, 3.0)
		else:
			draw_rect(r, Color(0.3, 0.32, 0.38, 0.5))
			draw_rect(r, Color(1, 1, 1, 0.4), false, 2.0)
		f.draw_string(get_canvas_item(), r.position + Vector2(4, -10), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			Color.WHITE if on else Color(1, 1, 1, 0.6))
