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

enum Mode { LIST, PLACEMENT, SHOP, ASSEMBLY }

var _mode: Mode = Mode.LIST
var _index: int = 0
var _shop_index: int = 0
var _assembly_index: int = 0
var _place_mirrored: bool = false
var _slot: SubLoadout.Slot = SubLoadout.Slot.STERN
var _changed: bool = false
var _note: String = ""
var _entries: Array = []
var _shop_entries: Array = []
var _assembly_entries: Array = []
var _view: _View

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_entries = SubLoadout.catalog()
	_rebuild_shop_entries()
	_rebuild_assembly_entries()
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
		Mode.ASSEMBLY:
			_assembly_key(key.physical_keycode)
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
				_try_buy_room(_shop_entries[_shop_index]["def"])
		KEY_TAB:
			_mode = Mode.ASSEMBLY
		KEY_ESCAPE:
			_close()

func _assembly_key(code: int) -> void:
	match code:
		KEY_UP, KEY_W:
			if not _assembly_entries.is_empty():
				_assembly_index = wrapi(_assembly_index - 1, 0, _assembly_entries.size())
				_place_mirrored = false
		KEY_DOWN, KEY_S:
			if not _assembly_entries.is_empty():
				_assembly_index = wrapi(_assembly_index + 1, 0, _assembly_entries.size())
				_place_mirrored = false
		KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D:
			if not _assembly_entries.is_empty():
				var entry: Dictionary = _assembly_entries[_assembly_index]
				if entry["type"] == "place_room" and entry["def"].has_firing_face:
					_place_mirrored = not _place_mirrored
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if not _assembly_entries.is_empty():
				var entry: Dictionary = _assembly_entries[_assembly_index]
				if entry["type"] == "buy_slot":
					_try_buy_slot(entry["pos"])
				else:
					_try_place_room(entry["pos"], entry["id"], _place_mirrored)
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

## Rebuilds the shop list: one entry per purchasable room type. Called on
## open and after a successful room purchase (so "In inventory: N" updates).
func _rebuild_shop_entries() -> void:
	_shop_entries = []
	for def in ModuleCatalog.purchasable_rooms():
		_shop_entries.append({"type": "room", "def": def})
	if _shop_entries.is_empty():
		_shop_index = 0
	else:
		_shop_index = clampi(_shop_index, 0, _shop_entries.size() - 1)

## Rebuilds the assembly list: one entry per cell currently buyable as a slot
## (ROOM_SYSTEM.md §4.1). Called on open and after a successful slot purchase
## (buying a slot changes which positions are buyable next).
func _rebuild_assembly_entries() -> void:
	_assembly_entries = []
	for pos in SaveData.layout.buyable_slot_positions():
		_assembly_entries.append({"type": "buy_slot", "pos": pos})
	for slot in SaveData.layout.slots:
		for id in SaveData.layout.inventory:
			if int(SaveData.layout.inventory[id]) <= 0:
				continue
			var def := ModuleCatalog.by_id(id)
			if def == null or def.is_core or def.is_pod:
				continue
			_assembly_entries.append({"type": "place_room", "pos": slot, "id": id, "def": def})
	if _assembly_entries.is_empty():
		_assembly_index = 0
	else:
		_assembly_index = clampi(_assembly_index, 0, _assembly_entries.size() - 1)
	_place_mirrored = false

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
		_rebuild_assembly_entries()

func _try_place_room(pos: Vector2i, id: String, mirrored: bool) -> void:
	var violations := SaveData.place_room_violations(id, pos, mirrored)
	if not violations.is_empty():
		_note = violations[0]
		return
	if SaveData.place_room(id, pos, mirrored):
		_changed = true
		var def := ModuleCatalog.by_id(id)
		_note = "%s placed!" % (def.display_name if def != null else id)
		_rebuild_shop_entries()
		_rebuild_assembly_entries()

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
			DryDock.Mode.ASSEMBLY:
				_draw_assembly(f)
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
				hint = "W/S select   Enter buy   Tab: assembly   Esc leave"
			DryDock.Mode.ASSEMBLY:
				hint = "W/S select   Enter build/place   A/D mirror   Tab: upgrades   Esc leave"
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
			y += 86.0

	## A top-down blueprint of the hull: each occupied cell drawn as a filled
	## box (room name), each owned-but-empty slot as an outlined box, and each
	## currently-buyable slot position as a faint ghost box with its price —
	## the selected one highlighted. Enter buys the selected ghost cell.
	func _draw_assembly(f: Font) -> void:
		f.draw_string(get_canvas_item(), Vector2(80, 170),
			"ASSEMBLY — the sub's hull (faint cells are buyable slots)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("7aa0c0"))

		var layout := SaveData.layout
		var buyable: Array = layout.buyable_slot_positions()
		var cells: Array = layout.occupied_cells().duplicate()
		for c in buyable:
			if c not in cells:
				cells.append(c)
		if cells.is_empty():
			return

		var min_pos := Vector2i(999, 999)
		var max_pos := Vector2i(-999, -999)
		for c in cells:
			min_pos = Vector2i(min(min_pos.x, c.x), min(min_pos.y, c.y))
			max_pos = Vector2i(max(max_pos.x, c.x), max(max_pos.y, c.y))
		var span := max_pos - min_pos + Vector2i.ONE
		const CELL_PX := 70.0
		var origin := Vector2(size.x * 0.5 - span.x * CELL_PX * 0.5, 240.0)

		var placed: Dictionary = {}  # cell -> display name
		for p in layout.placements:
			var def := ModuleCatalog.by_id(p.module_id)
			var label := def.display_name if def != null else p.module_id
			for cell in SubLayout.placement_cells(p):
				placed[cell] = label

		for cell in placed:
			var r := _cell_rect(cell, min_pos, origin, CELL_PX)
			draw_rect(r, Color(0.35, 0.4, 0.5, 0.9))
			draw_rect(r, Color(1, 1, 1, 0.6), false, 2.0)
			f.draw_string(get_canvas_item(), r.position + Vector2(6, 22), str(placed[cell]),
				HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 14, Color.WHITE)

		for slot in layout.slots:
			var r := _cell_rect(slot, min_pos, origin, CELL_PX)
			draw_rect(r, Color(0.25, 0.28, 0.34, 0.6))
			draw_rect(r, Color(1, 1, 1, 0.4), false, 2.0)
			f.draw_string(get_canvas_item(), r.position + Vector2(6, 22), "empty slot",
				HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 13, Color(1, 1, 1, 0.6))

		var price := SaveData.next_slot_price()
		var afford: bool = SaveData.banked_scrap >= price
		for i in dock._assembly_entries.size():
			var entry: Dictionary = dock._assembly_entries[i]
			var pos: Vector2i = entry["pos"]
			var r := _cell_rect(pos, min_pos, origin, CELL_PX)
			var selected := i == dock._assembly_index
			if entry["type"] == "buy_slot":
				var ghost_col := Color("e0c060") if selected else Color(0.5, 0.6, 0.4, 0.35)
				draw_rect(r, Color(ghost_col.r, ghost_col.g, ghost_col.b, 0.18 if not selected else 0.30))
				draw_rect(r, ghost_col, false, 3.0 if selected else 1.5)
				var price_col := Color.WHITE if afford else Color(1, 0.6, 0.4)
				f.draw_string(get_canvas_item(), r.position + Vector2(6, 22), "%d sc" % price,
					HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 18, price_col)
			elif selected:
				var def: ModuleDef = entry["def"]
				var ghost_col := Color("6ad0a0")
				draw_rect(r, Color(ghost_col.r, ghost_col.g, ghost_col.b, 0.30))
				draw_rect(r, ghost_col, false, 3.0)
				var label := "Place: %s" % def.display_name
				if def.has_firing_face:
					label += "  (mirrored)" if dock._place_mirrored else "  (A/D to mirror)"
				f.draw_string(get_canvas_item(), r.position + Vector2(6, 22), label,
					HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 13, Color.WHITE)

	func _cell_rect(cell: Vector2i, min_pos: Vector2i, origin: Vector2, cell_px: float) -> Rect2:
		var local := Vector2(cell - min_pos) * cell_px
		return Rect2(origin + local + Vector2(2, 2), Vector2(cell_px - 4, cell_px - 4))

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
