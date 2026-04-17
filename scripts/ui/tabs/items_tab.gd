class_name ItemsTab
extends CharacterSheetTab

## Generic grid tab driven by a set of `categories` filter. One tab per
## category group (weapons, armor, accessories, materials, consumables,
## quest). Layout = 6-col grid of `ItemSlotControl`.

const COLUMNS: int = 6
const ROWS: int = 4

var _title: String = ""
var _categories: Array[StringName] = []
var _action_label: StringName = &"none"  # &"equip", &"use", &"none"

var _grid: GridContainer = null
var _slots: Array[ItemSlotControl] = []
var _entries: Array[StringName] = []  # ids currently shown (parallel to _slots for filled cells)
var _cursor_index: int = 0
var _hint_label: Label = null


func setup_categories(title: String, cats: Array[StringName], action: StringName) -> void:
	_title = title
	_categories = cats
	_action_label = action


func tab_title() -> String:
	return _title


func _on_configured() -> void:
	_build_layout()
	if inventory != null:
		if not inventory.inventory_changed.is_connected(_on_inventory_changed):
			inventory.inventory_changed.connect(_on_inventory_changed)
	refresh()


func _build_layout() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(_grid)
	for _i: int in COLUMNS * ROWS:
		var slot: ItemSlotControl = ItemSlotControl.new()
		_grid.add_child(slot)
		_slots.append(slot)

	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_hint_label.text = ""
	vbox.add_child(_hint_label)


func refresh() -> void:
	if inventory == null:
		return
	_entries.clear()
	var all: Dictionary = inventory.get_all_items()
	for id_key: Variant in all:
		var id: StringName = id_key as StringName
		var count: int = all[id_key]
		if count <= 0:
			continue
		var def: ItemDef = ItemRegistry.get_def(id)
		if def == null:
			continue
		if not _categories.has(def.category):
			continue
		_entries.append(id)
	# Paint grid.
	for i: int in _slots.size():
		var slot: ItemSlotControl = _slots[i]
		if i < _entries.size():
			var id: StringName = _entries[i]
			slot.set_slot(id, inventory.get_count(id))
		else:
			slot.clear_slot()
	_cursor_index = clampi(_cursor_index, 0, maxi(_entries.size() - 1, 0))
	_update_cursor_visuals()
	_update_hint()


func on_focus() -> void:
	_cursor_index = 0
	_update_cursor_visuals()
	_update_hint()


func handle_nav(dir: Vector2i) -> void:
	if _entries.is_empty():
		return
	var row: int = _cursor_index / COLUMNS
	var col: int = _cursor_index % COLUMNS
	col = (col + dir.x + COLUMNS) % COLUMNS
	row = (row + dir.y + ROWS) % ROWS
	var new_index: int = row * COLUMNS + col
	if new_index >= _entries.size():
		new_index = _entries.size() - 1
	_cursor_index = new_index
	_update_cursor_visuals()
	_update_hint()


func handle_interact() -> void:
	if _entries.is_empty() or _cursor_index >= _entries.size():
		return
	var id: StringName = _entries[_cursor_index]
	match _action_label:
		&"equip":
			if equipment != null and equipment.equip(id):
				Toast.push("Equipped: %s" % ItemRegistry.display_name_for(id))
		&"use":
			Toast.push("Used: %s (no effect yet)" % ItemRegistry.display_name_for(id))
		_:
			pass


func handle_drop() -> void:
	if _entries.is_empty() or _cursor_index >= _entries.size():
		return
	var id: StringName = _entries[_cursor_index]
	if inventory.remove_item(id, 1):
		Toast.push("Dropped: %s" % ItemRegistry.display_name_for(id))


func _update_cursor_visuals() -> void:
	for i: int in _slots.size():
		_slots[i].set_selected(i == _cursor_index and i < _entries.size())


func _update_hint() -> void:
	if _hint_label == null:
		return
	if _entries.is_empty() or _cursor_index >= _entries.size():
		_hint_label.text = "(empty)"
		return
	var id: StringName = _entries[_cursor_index]
	var def: ItemDef = ItemRegistry.get_def(id)
	var name: String = def.display_name if def else String(id)
	var desc: String = def.description if def and def.description != "" else ""
	_hint_label.text = "%s — %s" % [name, desc] if desc != "" else name


func _on_inventory_changed(_id: StringName, _count: int) -> void:
	refresh()
