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

enum Mode { LIST, PLACEMENT, SHOP }

var _mode: Mode = Mode.LIST
var _index: int = 0
var _shop_index: int = 0
var _slot: SubLoadout.Slot = SubLoadout.Slot.STERN
var _changed: bool = false
var _note: String = ""
var _entries: Array = []
var _shop_entries: Array = []
var _view: _View

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_entries = SubLoadout.catalog()
	_rebuild_shop_entries()
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
	match _mode:
		Mode.LIST:
			_list_key(key.physical_keycode)
		Mode.SHOP:
			_shop_key(key.physical_keycode)
		Mode.PLACEMENT:
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
		KEY_TAB:
			_mode = Mode.SHOP
		KEY_ESCAPE:
			_close()

func _shop_key(code: int) -> void:
	match code:
		KEY_UP, KEY_W:
			if not _shop_entries.is_empty():
				_shop_index = wrapi(_shop_index - 1, 0, _shop_entries.size())
		KEY_DOWN, KEY_S:
			if not _shop_entries.is_empty():
				_shop_index = wrapi(_shop_index + 1, 0, _shop_entries.size())
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if not _shop_entries.is_empty():
				_try_buy_shop_entry(_shop_entries[_shop_index])
		KEY_TAB:
			_mode = Mode.LIST
		KEY_ESCAPE:
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

## Rebuilds the shop list: purchasable room types, then one entry per
## currently-buyable empty slot position. Called on open and after any
## successful shop purchase (buying a slot changes which positions are
## buyable next).
func _rebuild_shop_entries() -> void:
	_shop_entries = []
	for def in ModuleCatalog.purchasable_rooms():
		_shop_entries.append({"type": "room", "def": def})
	for pos in SaveData.layout.buyable_slot_positions():
		_shop_entries.append({"type": "slot", "pos": pos})
	if _shop_entries.is_empty():
		_shop_index = 0
	else:
		_shop_index = clampi(_shop_index, 0, _shop_entries.size() - 1)

func _try_buy_shop_entry(entry: Dictionary) -> void:
	if entry["type"] == "room":
		_try_buy_room(entry["def"])
	else:
		_try_buy_slot(entry["pos"])

func _try_buy_room(def: ModuleDef) -> void:
	var cost := def.cost_bundle()
	if not SaveData.can_afford_cost(cost):
		_note = "Not enough resources (need %s)." % _cost_string(cost)
		return
	if SaveData.buy_room(def.id):
		_changed = true
		_note = "%s bought into inventory!" % def.display_name
		_rebuild_shop_entries()

func _try_buy_slot(pos: Vector2i) -> void:
	var price := SaveData.next_slot_price()
	if SaveData.banked_scrap < price:
		_note = "Not enough scrap (need %d sc)." % price
		return
	if SaveData.buy_slot(pos):
		_changed = true
		_note = "Slot bought at (%d, %d)!" % [pos.x, pos.y]
		_rebuild_shop_entries()

static func _cost_string(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for code in cost:
		parts.append("%d %s" % [int(cost[code]), code])
	return ", ".join(parts)

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
			"Scrap: %d   Small carcass: %d   Medium carcass: %d   Large carcass: %d" % [
				SaveData.banked_scrap, SaveData.banked_fish,
				SaveData.banked_med_carcass, SaveData.banked_large_carcass],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)

		match dock._mode:
			DryDock.Mode.PLACEMENT:
				_draw_placement(f)
			DryDock.Mode.SHOP:
				_draw_shop(f)
			_:
				_draw_list(f)

		# Footer note + controls.
		if dock._note != "":
			f.draw_string(get_canvas_item(), Vector2(80, size.y - 96), dock._note,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("ff8c3a"))
		var hint := ""
		match dock._mode:
			DryDock.Mode.LIST:
				hint = "W/S select   Enter buy   Tab: shop   Esc leave"
			DryDock.Mode.SHOP:
				hint = "W/S select   Enter buy   Tab: upgrades   Esc leave"
			_:
				hint = "A/D pick the end   Enter confirm   Esc back"
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

	func _draw_shop(f: Font) -> void:
		f.draw_string(get_canvas_item(), Vector2(80, 170), "SHOP — buy rooms into inventory",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("7aa0c0"))
		var y := 230.0
		if dock._shop_entries.is_empty():
			f.draw_string(get_canvas_item(), Vector2(80, y), "Nothing for sale yet.",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.6))
			return
		for i in dock._shop_entries.size():
			var entry: Dictionary = dock._shop_entries[i]
			var selected := i == dock._shop_index
			if selected:
				draw_rect(Rect2(64, y - 30, 760, 64), Color(1, 1, 1, 0.10))
			if entry["type"] == "room":
				var def: ModuleDef = entry["def"]
				var cost := def.cost_bundle()
				var afford: bool = SaveData.can_afford_cost(cost)
				var owned: int = int(SaveData.layout.inventory.get(def.id, 0))
				var name_col := Color.WHITE if afford else Color(0.6, 0.6, 0.65)
				f.draw_string(get_canvas_item(), Vector2(80, y + 26), def.display_name,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 26, name_col)
				f.draw_string(get_canvas_item(), Vector2(560, y + 22), DryDock._cost_string(cost),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 24, name_col)
				if owned > 0:
					f.draw_string(get_canvas_item(), Vector2(80, y + 50), "In inventory: %d" % owned,
						HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 0.55))
			else:
				var pos: Vector2i = entry["pos"]
				var price := SaveData.next_slot_price()
				var afford: bool = SaveData.banked_scrap >= price
				var name_col := Color.WHITE if afford else Color(0.6, 0.6, 0.65)
				f.draw_string(get_canvas_item(), Vector2(80, y + 26),
					"Build a slot at (%d, %d)" % [pos.x, pos.y],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 26, name_col)
				f.draw_string(get_canvas_item(), Vector2(560, y + 22), "%d sc" % price,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 24, name_col)
				f.draw_string(get_canvas_item(), Vector2(80, y + 50),
					"Grows the hull — an empty room shell, ready for a bought room",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 0.55))
			y += 86.0

	func _draw_placement(f: Font) -> void:
		f.draw_string(get_canvas_item(), Vector2(80, 190),
			"SUBMARINE DESIGN  —  choose where the gun room bolts on:",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
		# A little side-on schematic of the sub with the two hardpoint slots.
		# (Stylized placeholder boxes — the real layout-driven design screen is
		# the M4 dock; this M3 view just picks a stern/bow end.)
		var center := Vector2(size.x * 0.5, size.y * 0.5 + 20.0)
		var s := 0.62
		var cw := 240.0  # schematic cell width
		var ch := 144.0  # schematic cell height
		# Existing rooms (dim): a 3-cell main row, a tower above, a 2-cell lower row.
		var body := Color(0.45, 0.48, 0.56)
		_box(Rect2(-cw * 1.5, -ch, cw * 3.0, ch), center, s, body)         # main row
		_box(Rect2(-cw * 0.5, -ch * 2.0, cw, ch), center, s, body)         # tower
		_box(Rect2(-cw * 1.5, 0.0, cw * 2.0, ch), center, s, body)         # lower row
		# Slot outlines; the chosen one glows.
		var stern := Rect2(-cw * 1.5 - cw, -ch, cw, ch)
		var bow := Rect2(cw * 1.5, -ch, cw, ch)
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
