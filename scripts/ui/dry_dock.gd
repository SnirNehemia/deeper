class_name DryDock
extends CanvasLayer

## The dry-dock screen (Module D). Opens while docked; pauses the run and lets
## the crew spend banked resources on two tabs:
##   - Shop:     buy rooms/pods from the catalog into inventory.
##   - Assembly: place inventory rooms/pods onto the hull, buy new hull slots,
##               or return placed rooms/pods to inventory.
##
## Purchases and placements persist via SaveData; on close the world rebuilds
## the sub so the changes show up.
##
## Navigated with W/S or arrows, Enter/Space to buy/confirm, Esc to back out or
## leave, Tab to switch between Shop and Assembly. This is a menu, so it reads
## keys directly (like the world's Esc-to-quit) rather than going through the
## gameplay input abstraction.

signal closed(changed: bool)

enum Mode { SHOP, ASSEMBLY }

var _mode: Mode = Mode.SHOP
var _shop_index: int = 0
var _assembly_cursor: Vector2i = Vector2i.ZERO
var _changed: bool = false
var _note: String = ""
var _shop_entries: Array = []
## Cell -> available action in Assembly (2026-06-16 menu rework). Each value
## is a Dictionary with either "buy_slot" (bool) or "menu" (Array of
## Dictionaries, each {"type": ..., "id": ..., possibly "face": ...} —
## "place_room"/"return_room"/"place_pod"/"return_pod").
var _assembly_actions: Dictionary = {}
## Every cell the Assembly cursor can stand on — a superset of
## `_assembly_actions.keys()` (2026-06-15): includes inert cells like the
## tower so the marker can pass over/rest on them, even though Enter there
## does nothing.
var _assembly_cells: Dictionary = {}
## True while a cell's action menu is open (2026-06-16). "use" cycles
## `_menu_index`, "interact" confirms the highlighted item, Esc closes it.
var _menu_open: bool = false
## The highlighted item in the open menu — `_assembly_actions[_assembly_cursor]["menu"][_menu_index]`.
var _menu_index: int = 0
## True while picking which exterior face a pod attaches to (entered from a
## "place_pod" menu item). "use"/arrows cycle `_face_index` over `_faces`.
var _face_select: bool = false
var _face_index: int = 0
var _faces: Array = []
## The inventory pod id mid-attachment during face selection.
var _pending_pod_id: String = ""
## True while picking which facing/face a "Rotate" action commits to (entered
## from a "rotate_room" menu item). "use"/arrows cycle `_rotate_index` over
## `_rotate_options` (a list of facing strings, 2026-06-19).
var _rotate_select: bool = false
var _rotate_index: int = 0
var _rotate_options: Array = []
var _view: _View

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
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
		Mode.SHOP:
			_shop_key(key.physical_keycode)
		Mode.ASSEMBLY:
			_assembly_key(key.physical_keycode)
	_view.queue_redraw()

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
				var entry: Dictionary = _shop_entries[_shop_index]
				if entry["type"] == "pod":
					_try_buy_pod(entry["def"])
				else:
					_try_buy_room(entry["def"])
		KEY_TAB:
			_mode = Mode.ASSEMBLY
		KEY_ESCAPE:
			_close()

func _assembly_key(code: int) -> void:
	if _rotate_select:
		_rotate_select_key(code)
		return
	if _face_select:
		_face_select_key(code)
		return
	if _menu_open:
		_menu_key(code)
		return
	match code:
		KEY_UP, KEY_W:
			_move_assembly_cursor(Vector2i(0, -1))
		KEY_DOWN, KEY_S:
			_move_assembly_cursor(Vector2i(0, 1))
		KEY_LEFT, KEY_A:
			_move_assembly_cursor(Vector2i(-1, 0))
		KEY_RIGHT, KEY_D:
			_move_assembly_cursor(Vector2i(1, 0))
		# "interact" (P1=E, P2=Right-Shift): buy a slot or open the cell's menu.
		# KP_Enter and Space are kept as convenience aliases.
		KEY_E, KEY_SHIFT, KEY_KP_ENTER, KEY_SPACE:
			_try_assembly_action()
		KEY_TAB:
			_mode = Mode.SHOP
		KEY_ESCAPE:
			_close()

## While a cell's action menu is open: "use" (P1=Q, P2=Enter, or arrows) cycles
## the highlighted item, "interact" confirms the highlighted item, and Esc
## closes the menu without acting.
func _menu_key(code: int) -> void:
	var action: Dictionary = _assembly_actions.get(_assembly_cursor, {})
	var menu: Array = action.get("menu", [])
	if menu.is_empty():
		_close_menu()
		return
	match code:
		KEY_Q, KEY_ENTER, KEY_DOWN, KEY_S:
			_menu_index = wrapi(_menu_index + 1, 0, menu.size())
		KEY_UP, KEY_W:
			_menu_index = wrapi(_menu_index - 1, 0, menu.size())
		KEY_E, KEY_SHIFT, KEY_KP_ENTER, KEY_SPACE:
			_confirm_menu_item(menu[_menu_index])
		KEY_ESCAPE:
			_close_menu()

## While picking which facing/face to rotate to: "use"/arrows cycle through
## `_rotate_options`, "interact" commits the highlighted option, Esc cancels
## back to the cell's menu (which stays open, 2026-06-19).
func _rotate_select_key(code: int) -> void:
	match code:
		KEY_Q, KEY_ENTER, KEY_UP, KEY_W, KEY_RIGHT, KEY_D:
			_rotate_index = wrapi(_rotate_index + 1, 0, _rotate_options.size())
		KEY_DOWN, KEY_S, KEY_LEFT, KEY_A:
			_rotate_index = wrapi(_rotate_index - 1, 0, _rotate_options.size())
		KEY_E, KEY_SHIFT, KEY_KP_ENTER, KEY_SPACE:
			_confirm_rotate_select()
		KEY_ESCAPE:
			_rotate_select = false
			_rotate_options = []
			_rotate_index = 0

func _confirm_rotate_select() -> void:
	var facing: String = _rotate_options[_rotate_index]
	if SaveData.set_facing(_assembly_cursor, facing):
		_changed = true
		_note = "Rotated."
		_rebuild_assembly_entries()
	_rotate_select = false
	_rotate_options = []
	_rotate_index = 0
	_close_menu()

## While picking a pod's exterior face: "use"/arrows cycle through `_faces`,
## "interact" attaches the pod to the highlighted face, Esc cancels back to
## the cell's menu (which stays open).
func _face_select_key(code: int) -> void:
	match code:
		KEY_Q, KEY_ENTER, KEY_UP, KEY_W, KEY_RIGHT, KEY_D:
			_face_index = wrapi(_face_index + 1, 0, _faces.size())
		KEY_DOWN, KEY_S, KEY_LEFT, KEY_A:
			_face_index = wrapi(_face_index - 1, 0, _faces.size())
		KEY_E, KEY_SHIFT, KEY_KP_ENTER, KEY_SPACE:
			_confirm_face_select()
		KEY_ESCAPE:
			_face_select = false
			_faces = []
			_face_index = 0
			_pending_pod_id = ""

## Moves the Assembly cursor one cell in `dir`, but only onto a cell that's
## part of the hull/buyable area (`_assembly_cells`) — the marker can reach
## every room and slot, including inert ones like the tower, but can't wander
## off into empty space (2026-06-14 nav rework, widened 2026-06-15 so inert
## cells no longer block passage).
func _move_assembly_cursor(dir: Vector2i) -> void:
	var candidate := _assembly_cursor + dir
	if _assembly_cells.has(candidate):
		_assembly_cursor = candidate
		_close_menu()

## "interact" outside any open menu: buys a slot instantly, or opens the
## cursor's action menu if it has one (2026-06-16 menu rework).
func _try_assembly_action() -> void:
	var action: Dictionary = _assembly_actions.get(_assembly_cursor, {})
	if action.has("buy_slot"):
		_try_buy_slot(_assembly_cursor)
	elif action.has("menu") and not action["menu"].is_empty():
		_menu_open = true
		_menu_index = 0

## Runs the highlighted menu item: place/return a room closes the menu
## immediately, return a pod closes the menu immediately, and place a pod
## drops into face-selection (the menu stays open underneath until a face is
## confirmed or cancelled).
func _confirm_menu_item(item: Dictionary) -> void:
	match item["type"]:
		"place_room":
			_try_place_room(_assembly_cursor, item["id"])
			if not _face_select:
				_close_menu()
		"return_room":
			_try_return_room(_assembly_cursor)
			_close_menu()
		"return_pod":
			_try_return_pod(_assembly_cursor, item["face"])
			_close_menu()
		"place_pod":
			_enter_face_select(item["id"])
		"rotate_room":
			_enter_rotate_select(_assembly_cursor)

## Drops into rotate-selection for the cursor's cell: lists every facing/face
## `rotate_options` says is legal, so the player can pick one directly instead
## of cycling blindly (2026-06-19). The menu stays open underneath until a
## choice is confirmed or cancelled.
func _enter_rotate_select(pos: Vector2i) -> void:
	var options := SaveData.rotate_options(pos)
	if options.is_empty():
		_note = "No other facing is available."
		return
	_rotate_options = options
	_rotate_index = 0
	_rotate_select = true

## Drops into face-selection for attaching `pod_id` to the cursor's cell —
## only the cell's exterior faces are offered ("only on outer edges of the
## sub"). If none are free, stays in the menu with a note.
func _enter_face_select(pod_id: String) -> void:
	var faces := _exterior_faces(_assembly_cursor)
	if faces.is_empty():
		_note = "No exterior face is free for the pod."
		return
	_faces = faces
	_face_index = 0
	_pending_pod_id = pod_id
	_face_select = true

func _confirm_face_select() -> void:
	var face: String = _faces[_face_index]
	_try_place_pod(_assembly_cursor, _pending_pod_id, face)
	_face_select = false
	_close_menu()

## Closes any open menu/face-select and resets their transient state
## (2026-06-16). Called on cursor move, after rebuilding the assembly entries,
## and after confirming an action.
func _close_menu() -> void:
	_menu_open = false
	_menu_index = 0
	_face_select = false
	_faces = []
	_face_index = 0
	_pending_pod_id = ""
	_rotate_select = false
	_rotate_options = []
	_rotate_index = 0

## The cell's faces ("top"/"bottom"/"left"/"right") that aren't occupied by
## another room — the candidates for attaching a pod (2026-06-16).
func _exterior_faces(cell: Vector2i) -> Array:
	var occupied := SaveData.layout.occupied_cells()
	var occ_set: Dictionary = {}
	for c in occupied:
		occ_set[c] = true
	var offsets := {
		"top": Vector2i(0, -1), "bottom": Vector2i(0, 1),
		"left": Vector2i(-1, 0), "right": Vector2i(1, 0),
	}
	var faces: Array = []
	for face in offsets:
		if not occ_set.has(cell + offsets[face]):
			faces.append(face)
	return faces

## A human-readable label for a menu item, for the dropdown drawn in
## `_View._draw_assembly` (2026-06-16).
func _menu_item_label(item: Dictionary) -> String:
	var def := ModuleCatalog.by_id(item["id"])
	var name: String = def.display_name if def != null else item["id"]
	match item["type"]:
		"place_room":
			return "Place: %s" % name
		"return_room":
			return "Return %s to inventory" % name
		"rotate_room":
			return "Rotate %s (next facing)" % name
		"place_pod":
			return "Attach pod: %s" % name
		"return_pod":
			return "Detach %s (%s face)" % [name, item["face"]]
	return ""

## Rebuilds the shop list: one entry per purchasable room type. Called on
## open and after a successful room purchase (so "In inventory: N" updates).
func _rebuild_shop_entries() -> void:
	_shop_entries = []
	for def in ModuleCatalog.purchasable_rooms():
		_shop_entries.append({"type": "room", "def": def})
	for def in ModuleCatalog.purchasable_pods():
		_shop_entries.append({"type": "pod", "def": def})
	if _shop_entries.is_empty():
		_shop_index = 0
	else:
		_shop_index = clampi(_shop_index, 0, _shop_entries.size() - 1)

## Rebuilds the assembly cursor-action map (2026-06-14 nav rework): every cell
## the marker can land on gets an entry describing what Enter does there —
## buy a slot, place an inventory room into an owned empty slot, or return a
## placed room to inventory. Called on open and after any successful
## buy/place/return (since those change which cells have actions). Snaps the
## cursor onto a valid cell if it isn't on one already.
func _rebuild_assembly_entries() -> void:
	_assembly_actions = {}
	for pos in SaveData.layout.buyable_slot_positions():
		_assembly_actions[pos] = {"buy_slot": true}
	for slot in SaveData.layout.slots:
		var menu := _build_cell_menu(slot)
		if not menu.is_empty():
			_assembly_actions[slot] = {"menu": menu}
	for p in SaveData.layout.placements:
		var menu := _build_cell_menu(p.grid_pos)
		if not menu.is_empty():
			_assembly_actions[p.grid_pos] = {"menu": menu}

	# Every cell the marker can stand on: the whole hull (placed rooms + owned
	# slots) plus the buyable ghost cells — including inert cells (the tower)
	# that have no action (2026-06-15).
	_assembly_cells = {}
	for cell in SaveData.layout.occupied_cells():
		_assembly_cells[cell] = true
	for pos in SaveData.layout.buyable_slot_positions():
		_assembly_cells[pos] = true

	if not _assembly_cells.has(_assembly_cursor):
		if _assembly_cells.is_empty():
			_assembly_cursor = Vector2i.ZERO
		else:
			_assembly_cursor = _assembly_cells.keys()[0]
	_close_menu()

## The dropdown menu for interacting with an owned cell (2026-06-16 menu
## rework): an empty slot offers placing each relocatable inventory room; a
## placed room offers returning itself to inventory, plus — if it
## `can_host_pod` — attaching each inventory pod and detaching any pod already
## on it. Empty means the cell has nothing to do (buy_slot ghosts and inert
## cells like the tower aren't routed through here).
func _build_cell_menu(cell: Vector2i) -> Array:
	var menu: Array = []
	if cell in SaveData.layout.slots:
		for id in SaveData.layout.inventory:
			if int(SaveData.layout.inventory[id]) <= 0:
				continue
			var def := ModuleCatalog.by_id(id)
			if not SaveData._is_relocatable(def):
				continue
			menu.append({"type": "place_room", "id": id})
		return menu

	var placed_def: ModuleDef = null
	var placed_id := ""
	for p in SaveData.layout.placements:
		if p.grid_pos == cell:
			placed_def = ModuleCatalog.by_id(p.module_id)
			placed_id = p.module_id
			break
	if placed_def == null:
		return menu
	if SaveData._is_relocatable(placed_def):
		menu.append({"type": "return_room", "id": placed_id})
	var rotatable := placed_def.has_firing_face or placed_id == "claw_room" \
		or placed_id == "floodlight_room"
	if rotatable and SaveData.rotate_room_violations(cell).is_empty():
		menu.append({"type": "rotate_room", "id": placed_id})
	if placed_def.can_host_pod and placed_id != "floodlight_room":
		for id in SaveData.layout.inventory:
			if int(SaveData.layout.inventory[id]) <= 0:
				continue
			var pdef := ModuleCatalog.by_id(id)
			if pdef == null or not pdef.is_pod:
				continue
			menu.append({"type": "place_pod", "id": id})
		for pod in SaveData.layout.pods:
			if pod.host_cell == cell:
				menu.append({"type": "return_pod", "id": pod.pod_id, "face": pod.face})
	return menu

func _try_buy_room(def: ModuleDef) -> void:
	var cost := def.cost_bundle()
	if not SaveData.can_afford_cost(cost):
		_note = "Not enough resources (need %s)." % _cost_string(cost)
		return
	if SaveData.buy_room(def.id):
		_changed = true
		_note = "%s bought into inventory!" % def.display_name
		_rebuild_shop_entries()

func _try_buy_pod(def: ModuleDef) -> void:
	var cost := def.cost_bundle()
	if not SaveData.can_afford_cost(cost):
		_note = "Not enough resources (need %s)." % _cost_string(cost)
		return
	if SaveData.buy_pod(def.id):
		_changed = true
		_note = "%s bought into inventory!" % def.display_name
		_rebuild_shop_entries()

func _try_buy_slot(pos: Vector2i) -> void:
	var price := SaveData.next_slot_price(pos)
	if SaveData.banked_scrap < price:
		_note = "Not enough scrap (need %d sc)." % price
		return
	if SaveData.buy_slot(pos):
		_changed = true
		_note = "Slot bought at (%d, %d)!" % [pos.x, pos.y]
		_rebuild_assembly_entries()

## Places `id` at `pos`. For a room with a special face (a turret/bullet's
## gun, the claw's arm), `SaveData` auto-picks the first facing (in
## `SubLayout.FACINGS` order) that validates (2026-06-19 "any outer face"
## rework) — the player adjusts it afterward with the "Rotate" menu item.
func _try_place_room(pos: Vector2i, id: String) -> void:
	var violations := SaveData.place_room_violations(id, pos)
	if not violations.is_empty():
		_note = violations[0]
		return
	if SaveData.place_room(id, pos):
		_changed = true
		var def := ModuleCatalog.by_id(id)
		_note = "%s placed!" % (def.display_name if def != null else id)
		_rebuild_shop_entries()
		_rebuild_assembly_entries()

## Picks the placed room at `pos` back up into inventory (2026-06-14 Assembly
## nav rework — the reverse of _try_place_room). No-op (with a note) if
## SaveData refuses (core/pod or nothing there).
func _try_return_room(pos: Vector2i) -> void:
	var def: ModuleDef = null
	for p in SaveData.layout.placements:
		if p.grid_pos == pos:
			def = ModuleCatalog.by_id(p.module_id)
			break
	if SaveData.return_room_to_inventory(pos):
		_changed = true
		_note = "%s returned to inventory." % (def.display_name if def != null else "Room")
		_rebuild_shop_entries()
		_rebuild_assembly_entries()
	else:
		_note = "That room can't be moved."

## Attaches inventory pod `id` to `pos`'s `face` (2026-06-16, the menu's
## "place_pod" -> face-select flow). No-op (with a note) if SaveData refuses
## (face not exterior, room can't host it, etc).
func _try_place_pod(pos: Vector2i, id: String, face: String) -> void:
	var violations := SaveData.place_pod_violations(id, pos, face)
	if not violations.is_empty():
		_note = violations[0]
		return
	if SaveData.place_pod(id, pos, face):
		_changed = true
		var def := ModuleCatalog.by_id(id)
		_note = "%s attached!" % (def.display_name if def != null else id)
		_rebuild_shop_entries()
		_rebuild_assembly_entries()

## Detaches the pod on `pos`'s `face` back to inventory (2026-06-16, the
## menu's "return_pod" item). No-op (with a note) if there's no pod there.
func _try_return_pod(pos: Vector2i, face: String) -> void:
	var pod_id := ""
	for pod in SaveData.layout.pods:
		if pod.host_cell == pos and pod.face == face:
			pod_id = pod.pod_id
			break
	if SaveData.return_pod_to_inventory(pos, face):
		_changed = true
		var def := ModuleCatalog.by_id(pod_id)
		_note = "%s returned to inventory." % (def.display_name if def != null else "Pod")
		_rebuild_shop_entries()
		_rebuild_assembly_entries()
	else:
		_note = "That pod can't be moved."

static func _cost_string(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for code in cost:
		parts.append("%d %s" % [int(cost[code]), code])
	return ", ".join(parts)

## True if the helm is currently placed on the hull (not sitting in
## inventory, e.g. mid-relocation). The dry dock refuses to close otherwise
## (2026-06-15) — the helm is the one core room a player can pick up, so this
## is the only guard against leaving without it.
func _has_helm_placed() -> bool:
	for p in SaveData.layout.placements:
		if p.module_id == "helm":
			return true
	return false

func _close() -> void:
	if not _has_helm_placed():
		_note = "The sub needs its helm placed before you can leave the dock."
		return
	for v in SubValidator.validate(SaveData.layout)["violations"]:
		if v.find("cut off") != -1:
			_note = v
			return
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
			DryDock.Mode.SHOP:
				_draw_shop(f)
			DryDock.Mode.ASSEMBLY:
				_draw_assembly(f)
		_draw_inventory_panel(f)

		# Footer note + controls.
		if dock._note != "":
			f.draw_string(get_canvas_item(), Vector2(80, size.y - 96), dock._note,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("ff8c3a"))
		var hint := ""
		match dock._mode:
			DryDock.Mode.SHOP:
				hint = "W/S select   Enter buy   Tab: assembly   Esc leave"
			DryDock.Mode.ASSEMBLY:
				if dock._face_select:
					hint = "Use/Arrows pick face   Interact attach   Esc cancel"
				elif dock._menu_open:
					hint = "Use cycle option   Interact confirm   Esc cancel"
				else:
					hint = "Arrows move   Interact buy slot / open menu   Tab: shop   Esc leave"
		f.draw_string(get_canvas_item(), Vector2(80, size.y - 60), hint,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.7))

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
			if def.description != "":
				f.draw_string(get_canvas_item(), Vector2(80, y + 50), def.description,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 0.55))
			if owned > 0:
				f.draw_string(get_canvas_item(), Vector2(560, y + 50), "In inventory: %d" % owned,
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
		var reserved_types: Dictionary = layout.reserved_cell_types()
		var reserved: Array = reserved_types.keys()
		var cells: Array = layout.occupied_cells().duplicate()
		for c in buyable:
			if c not in cells:
				cells.append(c)
		for c in reserved:
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

		# Cells permanently off-limits because a placed gun fires through them
		# (validate() rule 5) — marked instead of left blank, so it's clear
		# why no price/slot ever appears here (Snir's feedback, 2026-06-17).
		for cell in reserved:
			if cell in layout.occupied_cells():
				continue
			var r := _cell_rect(cell, min_pos, origin, CELL_PX)
			draw_rect(r, Color(0.5, 0.2, 0.2, 0.25))
			draw_rect(r, Color(0.8, 0.4, 0.4, 0.5), false, 1.5)
			f.draw_string(get_canvas_item(), r.position + Vector2(6, 22), "reserved",
				HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 13, Color(1, 0.7, 0.7, 0.8))
			f.draw_string(get_canvas_item(), r.position + Vector2(6, 40), str(reserved_types.get(cell, "")),
				HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 11, Color(1, 0.7, 0.7, 0.6))

		for pos in dock._assembly_actions:
			var action: Dictionary = dock._assembly_actions[pos]
			var r := _cell_rect(pos, min_pos, origin, CELL_PX)
			var selected: bool = pos == dock._assembly_cursor
			if action.has("buy_slot"):
				var price := SaveData.next_slot_price(pos)
				var afford: bool = SaveData.banked_scrap >= price
				var ghost_col := Color("e0c060") if selected else Color(0.5, 0.6, 0.4, 0.35)
				draw_rect(r, Color(ghost_col.r, ghost_col.g, ghost_col.b, 0.18 if not selected else 0.30))
				draw_rect(r, ghost_col, false, 3.0 if selected else 1.5)
				var price_col := Color.WHITE if afford else Color(1, 0.6, 0.4)
				f.draw_string(get_canvas_item(), r.position + Vector2(6, 22), "%d sc" % price,
					HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 18, price_col)
			elif action.has("menu"):
				var menu: Array = action["menu"]
				if selected and dock._face_select:
					var ghost_col := Color("6ad0ff")
					draw_rect(r, Color(ghost_col.r, ghost_col.g, ghost_col.b, 0.30))
					draw_rect(r, ghost_col, false, 3.0)
					var face_items: Array = []
					for face in dock._faces:
						face_items.append("%s face" % str(face).capitalize())
					_draw_dropdown(f, r, face_items, dock._face_index)
				elif selected and dock._rotate_select:
					var ghost_col := Color("c0a0ff")
					draw_rect(r, Color(ghost_col.r, ghost_col.g, ghost_col.b, 0.30))
					draw_rect(r, ghost_col, false, 3.0)
					var rotate_items: Array = []
					for facing in dock._rotate_options:
						rotate_items.append("%s" % str(facing).capitalize())
					_draw_dropdown(f, r, rotate_items, dock._rotate_index)
				elif selected and dock._menu_open:
					var ghost_col := Color("6ad0a0")
					draw_rect(r, Color(ghost_col.r, ghost_col.g, ghost_col.b, 0.30))
					draw_rect(r, ghost_col, false, 3.0)
					var labels: Array = []
					for item in menu:
						labels.append(dock._menu_item_label(item))
					_draw_dropdown(f, r, labels, dock._menu_index)
				elif selected:
					draw_rect(r, Color("e0c060"), false, 3.0)
					f.draw_string(get_canvas_item(), r.position + Vector2(6, 46), "Interact: open menu",
						HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 12, Color(1, 1, 1, 0.8))
			elif selected:
				draw_rect(r, Color(1, 1, 1, 0.2), false, 3.0)

		# The cursor can also rest on inert cells with no action at all (e.g.
		# the tower) — highlight it there too, so the marker is never
		# invisible (2026-06-15).
		if not dock._assembly_actions.has(dock._assembly_cursor):
			var r := _cell_rect(dock._assembly_cursor, min_pos, origin, CELL_PX)
			draw_rect(r, Color(1, 1, 1, 0.25), false, 3.0)

	func _cell_rect(cell: Vector2i, min_pos: Vector2i, origin: Vector2, cell_px: float) -> Rect2:
		var local := Vector2(cell - min_pos) * cell_px
		return Rect2(origin + local + Vector2(2, 2), Vector2(cell_px - 4, cell_px - 4))

	## The "rooms/pods you've bought but haven't placed yet" list, pinned to
	## the right edge of the screen in both Shop and Assembly (item 3 of
	## Snir's 2026-06-16 brief). Mirrors `SaveData.layout.inventory`.
	func _draw_inventory_panel(f: Font) -> void:
		var x := size.x - 420.0
		f.draw_string(get_canvas_item(), Vector2(x, 170), "INVENTORY (unplaced)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("7aa0c0"))
		var y := 210.0
		var any := false
		for id in SaveData.layout.inventory:
			var count := int(SaveData.layout.inventory[id])
			if count <= 0:
				continue
			any = true
			var def := ModuleCatalog.by_id(id)
			var name: String = def.display_name if def != null else id
			f.draw_string(get_canvas_item(), Vector2(x, y), "%s  x%d" % [name, count],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
			y += 30.0
		if not any:
			f.draw_string(get_canvas_item(), Vector2(x, y), "(nothing in inventory)",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.5))

	## A real dropdown list anchored under (or, if it'd run off the bottom,
	## above) `anchor` — one row per `items` entry, the `highlighted` row
	## picked out with a filled highlight bar (2026-06-17 dropdown rework,
	## replacing the single-line "(n/m, Use to cycle)" label).
	func _draw_dropdown(f: Font, anchor: Rect2, items: Array, highlighted: int) -> void:
		const ROW_H := 32.0
		const PAD := 10.0
		var w := 160.0
		for item in items:
			w = max(w, f.get_string_size(str(item), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + PAD * 2.0)
		var h := ROW_H * items.size()
		var pos := Vector2(anchor.position.x, anchor.position.y + anchor.size.y + 4.0)
		if pos.y + h > size.y - 90.0:
			pos.y = anchor.position.y - h - 4.0
		if pos.x + w > size.x - 20.0:
			pos.x = size.x - 20.0 - w
		draw_rect(Rect2(pos, Vector2(w, h)), Color(0.05, 0.08, 0.12, 0.98))
		draw_rect(Rect2(pos, Vector2(w, h)), Color(1, 1, 1, 0.5), false, 2.0)
		for i in items.size():
			var row := Rect2(pos + Vector2(0, ROW_H * i), Vector2(w, ROW_H))
			if i == highlighted:
				draw_rect(row, Color(0.35, 0.6, 0.45, 0.6))
				draw_rect(row, Color("6ad0a0"), false, 2.0)
			f.draw_string(get_canvas_item(), row.position + Vector2(PAD, ROW_H * 0.68), str(items[i]),
				HORIZONTAL_ALIGNMENT_LEFT, w - PAD * 2.0, 18, Color.WHITE)
