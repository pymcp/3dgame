class_name EquipmentTab
extends CharacterSheetTab

## Paper-doll layout with a person silhouette behind the slots. Cursor
## moves spatially — pressing a direction jumps to the nearest slot in
## that direction. `mine` unequips the selected slot. Below the doll:
## a small read-only "Pickaxe: Tier N" line.

## Slots listed for iteration — order doesn't affect spatial nav.
const SLOT_LIST: Array[StringName] = [
	&"head", &"amulet", &"chest", &"weapon", &"ring", &"legs", &"boots",
]

## Grid positions (col, row) for spatial navigation. The doll is a 3×4
## grid with only the 7 occupied cells interactive.
##      col0      col1     col2
## row0            head
## row1  amulet   chest    weapon
## row2            legs    ring
## row3            boots
const SLOT_GRID_POS: Dictionary = {
	&"head":   Vector2i(1, 0),
	&"amulet": Vector2i(0, 1),
	&"chest":  Vector2i(1, 1),
	&"weapon": Vector2i(2, 1),
	&"legs":   Vector2i(1, 2),
	&"ring":   Vector2i(2, 2),
	&"boots":  Vector2i(1, 3),
}

## Spatial neighbour map. For each slot, the slot reached by each cardinal
## direction. Built to feel natural: down from head→chest, right from
## amulet→chest, etc. Wraps where it makes sense.
const NAV_MAP: Dictionary = {
	# slot: { dir -> target_slot }
	&"head":   { Vector2i(0, -1): &"boots",  Vector2i(0, 1): &"chest",
				 Vector2i(-1, 0): &"amulet", Vector2i(1, 0): &"weapon" },
	&"amulet": { Vector2i(0, -1): &"head",   Vector2i(0, 1): &"legs",
				 Vector2i(-1, 0): &"weapon", Vector2i(1, 0): &"chest" },
	&"chest":  { Vector2i(0, -1): &"head",   Vector2i(0, 1): &"legs",
				 Vector2i(-1, 0): &"amulet", Vector2i(1, 0): &"weapon" },
	&"weapon": { Vector2i(0, -1): &"head",   Vector2i(0, 1): &"ring",
				 Vector2i(-1, 0): &"chest",  Vector2i(1, 0): &"amulet" },
	&"legs":   { Vector2i(0, -1): &"chest",  Vector2i(0, 1): &"boots",
				 Vector2i(-1, 0): &"amulet", Vector2i(1, 0): &"ring" },
	&"ring":   { Vector2i(0, -1): &"weapon", Vector2i(0, 1): &"boots",
				 Vector2i(-1, 0): &"legs",   Vector2i(1, 0): &"amulet" },
	&"boots":  { Vector2i(0, -1): &"legs",   Vector2i(0, 1): &"head",
				 Vector2i(-1, 0): &"amulet", Vector2i(1, 0): &"ring" },
}

var _slot_controls: Dictionary = {}  # StringName slot -> ItemSlotControl
var _slot_labels: Dictionary = {}    # StringName slot -> Label
var _cursor_slot: StringName = &"head"
var _pickaxe_label: Label = null
var _silhouette: Control = null
var player_controller: PlayerController = null


func tab_title() -> String:
	return "Equipment"


func _on_configured() -> void:
	_build_layout()
	if equipment != null:
		if not equipment.equipped.is_connected(_on_equipment_changed):
			equipment.equipped.connect(_on_equipment_changed)
		if not equipment.unequipped.is_connected(_on_equipment_changed):
			equipment.unequipped.connect(_on_equipment_changed)
	refresh()


func set_player_controller(pc: PlayerController) -> void:
	player_controller = pc
	_refresh_pickaxe_line()


func _build_layout() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	# Container for the doll area (silhouette + slots overlay).
	var doll_holder: Control = Control.new()
	doll_holder.custom_minimum_size = Vector2(280.0, 370.0)
	doll_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(doll_holder)

	# Person silhouette drawn behind the slots.
	_silhouette = _PersonSilhouette.new()
	_silhouette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	doll_holder.add_child(_silhouette)

	# Slot grid overlaid on the silhouette.
	var grid: Control = Control.new()
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	doll_holder.add_child(grid)

	# Place each slot at its grid position. Cell size 80×90, with
	# horizontal centering of the 3 columns inside the 280-wide holder.
	const CELL_W: float = 80.0
	const CELL_H: float = 90.0
	const COLS: int = 3
	var grid_w: float = CELL_W * COLS
	var x_offset: float = (280.0 - grid_w) * 0.5

	for slot: StringName in SLOT_LIST:
		var gp: Vector2i = SLOT_GRID_POS[slot]
		var cell: VBoxContainer = VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.position = Vector2(x_offset + gp.x * CELL_W, gp.y * CELL_H + 4.0)
		cell.custom_minimum_size = Vector2(CELL_W, CELL_H)
		cell.size = Vector2(CELL_W, CELL_H)
		grid.add_child(cell)

		var slot_ctrl: ItemSlotControl = ItemSlotControl.new()
		cell.add_child(slot_ctrl)
		var label: Label = Label.new()
		label.text = _slot_label(slot)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 0.85))
		cell.add_child(label)
		_slot_controls[slot] = slot_ctrl
		_slot_labels[slot] = label

	# Pickaxe tier display.
	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)
	_pickaxe_label = Label.new()
	_pickaxe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pickaxe_label.add_theme_font_size_override("font_size", 16)
	_pickaxe_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.6))
	vbox.add_child(_pickaxe_label)


func _slot_label(slot: StringName) -> String:
	match slot:
		&"weapon": return "Weapon"
		&"head": return "Head"
		&"chest": return "Chest"
		&"legs": return "Legs"
		&"boots": return "Boots"
		&"ring": return "Ring"
		&"amulet": return "Amulet"
	return String(slot).capitalize()


func refresh() -> void:
	if equipment == null:
		return
	for slot: StringName in SLOT_LIST:
		var ctrl: ItemSlotControl = _slot_controls.get(slot)
		if ctrl == null:
			continue
		var item_id: StringName = equipment.get_equipped(slot)
		ctrl.set_slot(item_id, 1 if item_id != &"" else 0)
	_update_cursor_visuals()
	_refresh_pickaxe_line()


func _refresh_pickaxe_line() -> void:
	if _pickaxe_label == null:
		return
	var tier: int = 1
	if player_controller != null:
		tier = player_controller.pickaxe_tier
	_pickaxe_label.text = "Pickaxe: Tier %d   (always equipped)" % tier


func on_focus() -> void:
	_cursor_slot = &"head"
	_update_cursor_visuals()


func handle_nav(dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	# Normalize to unit cardinal.
	var card: Vector2i
	if abs(dir.x) >= abs(dir.y):
		card = Vector2i(sign(dir.x), 0)
	else:
		card = Vector2i(0, sign(dir.y))
	var map: Dictionary = NAV_MAP.get(_cursor_slot, {})
	var target: StringName = map.get(card, &"")
	if target != &"":
		_cursor_slot = target
		_update_cursor_visuals()


func handle_interact() -> void:
	if equipment == null:
		return
	equipment.unequip(_cursor_slot)


func _update_cursor_visuals() -> void:
	for slot: StringName in SLOT_LIST:
		var ctrl: ItemSlotControl = _slot_controls.get(slot)
		if ctrl != null:
			ctrl.set_selected(slot == _cursor_slot)


func _on_equipment_changed(_slot: StringName, _item_id: StringName) -> void:
	refresh()


# -----------------------------------------------------------------------
# Inner class: draws a simple person silhouette outline via _draw().
# -----------------------------------------------------------------------
class _PersonSilhouette extends Control:
	func _draw() -> void:
		var cx: float = size.x * 0.5
		var color: Color = Color(1.0, 0.95, 0.85, 0.12)
		var outline: Color = Color(1.0, 0.95, 0.85, 0.25)
		var line_w: float = 2.0

		# Head circle — centered on row 0.
		var head_center: Vector2 = Vector2(cx, 40.0)
		var head_radius: float = 22.0
		draw_circle(head_center, head_radius, color)
		_draw_circle_outline(head_center, head_radius, outline, line_w)

		# Neck.
		var neck_top: float = head_center.y + head_radius
		var neck_bottom: float = neck_top + 12.0
		draw_line(Vector2(cx, neck_top), Vector2(cx, neck_bottom), outline, line_w)

		# Torso (rounded rect).
		var torso_top: float = neck_bottom
		var torso_w: float = 80.0
		var torso_h: float = 110.0
		var torso_rect: Rect2 = Rect2(cx - torso_w * 0.5, torso_top,
			torso_w, torso_h)
		draw_rect(torso_rect, color)
		_draw_rounded_rect_outline(torso_rect, 6.0, outline, line_w)

		# Arms — angled lines from shoulders outward.
		var shoulder_y: float = torso_top + 8.0
		var arm_length: float = 50.0
		var hand_drop: float = 60.0
		# Left arm.
		var l_shoulder: Vector2 = Vector2(torso_rect.position.x, shoulder_y)
		var l_hand: Vector2 = Vector2(l_shoulder.x - arm_length, shoulder_y + hand_drop)
		draw_line(l_shoulder, l_hand, outline, line_w)
		# Right arm.
		var r_shoulder: Vector2 = Vector2(torso_rect.end.x, shoulder_y)
		var r_hand: Vector2 = Vector2(r_shoulder.x + arm_length, shoulder_y + hand_drop)
		draw_line(r_shoulder, r_hand, outline, line_w)

		# Legs.
		var hip_y: float = torso_rect.end.y
		var leg_spread: float = 20.0
		var leg_length: float = 120.0
		# Left leg.
		draw_line(Vector2(cx - 10.0, hip_y),
			Vector2(cx - leg_spread, hip_y + leg_length), outline, line_w)
		# Right leg.
		draw_line(Vector2(cx + 10.0, hip_y),
			Vector2(cx + leg_spread, hip_y + leg_length), outline, line_w)

		# Feet — small horizontal ticks at the bottom of each leg.
		var foot_y: float = hip_y + leg_length
		var foot_w: float = 14.0
		draw_line(Vector2(cx - leg_spread - foot_w * 0.5, foot_y),
			Vector2(cx - leg_spread + foot_w * 0.5, foot_y), outline, line_w)
		draw_line(Vector2(cx + leg_spread - foot_w * 0.5, foot_y),
			Vector2(cx + leg_spread + foot_w * 0.5, foot_y), outline, line_w)


	func _draw_circle_outline(center: Vector2, radius: float,
			color: Color, width: float) -> void:
		var pts: int = 32
		var prev: Vector2 = center + Vector2(radius, 0)
		for i: int in range(1, pts + 1):
			var angle: float = TAU * float(i) / float(pts)
			var next: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
			draw_line(prev, next, color, width)
			prev = next


	func _draw_rounded_rect_outline(rect: Rect2, _radius: float,
			color: Color, width: float) -> void:
		# Simple rect outline (no actual rounding — keeps it clean).
		var tl: Vector2 = rect.position
		var tr: Vector2 = Vector2(rect.end.x, rect.position.y)
		var br: Vector2 = rect.end
		var bl: Vector2 = Vector2(rect.position.x, rect.end.y)
		draw_line(tl, tr, color, width)
		draw_line(tr, br, color, width)
		draw_line(br, bl, color, width)
		draw_line(bl, tl, color, width)
