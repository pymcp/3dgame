class_name CharacterSheet
extends Control

## Per-player non-pausing modal. Lives inside each player's SubViewport
## so it only covers their half of the screen. Movement keys drive the
## cursor; target_up/down (Q/Z, Numpad 7/1, gamepad LB/RB) switch tabs;
## `mine` = interact (equip/use/craft/unequip); `jump` = drop;
## `inventory` = close.

signal opened
signal closed

const TAB_COUNT: int = 8

@export var player_id: int = 1

var inventory: Inventory = null
var equipment: PlayerEquipment = null
var overworld: HexWorld = null
var mine: HexWorld = null
var player_controller: PlayerController = null

var _root: NinePatchRect = null
var _body: Control = null
var _banner_label: Label = null
var _tab_strip: VBoxContainer = null
var _footer: Label = null

var _tabs: Array[CharacterSheetTab] = []
var _tab_labels: Array[Label] = []
var _active_index: int = 0
var _is_open: bool = false

# Fires once per key press for nav; polled via `is_action_just_pressed`
# but we also track held-direction repeat for comfort.
var _nav_repeat_timer: float = 0.0
const NAV_REPEAT_INITIAL: float = 0.25
const NAV_REPEAT_INTERVAL: float = 0.1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_shell()


func configure(p_player_id: int, inv: Inventory, eq: PlayerEquipment,
		ow: HexWorld, m: HexWorld, pc: PlayerController) -> void:
	player_id = p_player_id
	inventory = inv
	equipment = eq
	overworld = ow
	mine = m
	player_controller = pc
	equipment.set_inventory(inv)
	_build_tabs()


func _build_shell() -> void:
	# Translucent backdrop so the world dims slightly.
	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.45)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var wrapper: VBoxContainer = VBoxContainer.new()
	wrapper.custom_minimum_size = Vector2(680.0, 560.0)
	wrapper.add_theme_constant_override("separation", 0)
	center.add_child(wrapper)

	# Banner
	var banner_center: CenterContainer = CenterContainer.new()
	wrapper.add_child(banner_center)
	var banner_tex: Texture2D = _load_tex("res://assets/ui/banner_hanging.png")
	if banner_tex:
		var banner: TextureRect = TextureRect.new()
		banner.texture = banner_tex
		banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		banner.custom_minimum_size = Vector2(420.0, 80.0)
		banner_center.add_child(banner)
		_banner_label = Label.new()
		_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_banner_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_banner_label.add_theme_font_size_override("font_size", 20)
		_banner_label.text = "P%d Inventory" % player_id
		banner.add_child(_banner_label)

	# Panel
	_root = NinePatchRect.new()
	_root.texture = _load_tex("res://assets/ui/panel_brown.png")
	_root.patch_margin_left = 20
	_root.patch_margin_right = 20
	_root.patch_margin_top = 20
	_root.patch_margin_bottom = 20
	_root.custom_minimum_size = Vector2(680.0, 480.0)
	wrapper.add_child(_root)

	var panel_vbox: VBoxContainer = VBoxContainer.new()
	panel_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_vbox.offset_left = 20.0
	panel_vbox.offset_top = 20.0
	panel_vbox.offset_right = -20.0
	panel_vbox.offset_bottom = -20.0
	_root.add_child(panel_vbox)

	# Horizontal split: sidebar (tabs) | body
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 0)
	panel_vbox.add_child(hbox)

	# Left sidebar — vertical tab list
	_tab_strip = VBoxContainer.new()
	_tab_strip.add_theme_constant_override("separation", 2)
	_tab_strip.custom_minimum_size = Vector2(120.0, 0.0)
	hbox.add_child(_tab_strip)

	var vsep: VSeparator = VSeparator.new()
	hbox.add_child(vsep)

	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_body)

	var sep: HSeparator = HSeparator.new()
	panel_vbox.add_child(sep)

	_footer = Label.new()
	_footer.add_theme_font_size_override("font_size", 12)
	_footer.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_vbox.add_child(_footer)
	_refresh_footer()


func _build_tabs() -> void:
	# Tab order: Equipment | Weapons | Armor | Accessories | Materials |
	#            Consumables | Crafting | Quests
	var t_equip: EquipmentTab = EquipmentTab.new()
	t_equip.set_player_controller(player_controller)
	_add_tab(t_equip)

	var t_weap: ItemsTab = ItemsTab.new()
	t_weap.setup_categories("Weapons", [ItemDef.CAT_WEAPON], &"equip")
	_add_tab(t_weap)

	var t_arm: ItemsTab = ItemsTab.new()
	t_arm.setup_categories("Armor",
		[ItemDef.CAT_ARMOR_HEAD, ItemDef.CAT_ARMOR_CHEST,
		ItemDef.CAT_ARMOR_LEGS, ItemDef.CAT_ARMOR_BOOTS], &"equip")
	_add_tab(t_arm)

	var t_acc: ItemsTab = ItemsTab.new()
	t_acc.setup_categories("Accessories",
		[ItemDef.CAT_RING, ItemDef.CAT_AMULET], &"equip")
	_add_tab(t_acc)

	var t_mat: ItemsTab = ItemsTab.new()
	t_mat.setup_categories("Materials", [ItemDef.CAT_MATERIAL], &"none")
	_add_tab(t_mat)

	var t_con: ItemsTab = ItemsTab.new()
	t_con.setup_categories("Consumables", [ItemDef.CAT_CONSUMABLE], &"use")
	_add_tab(t_con)

	var t_craft: CraftingTab = CraftingTab.new()
	t_craft.set_worlds(overworld, mine)
	t_craft.set_player_controller(player_controller)
	_add_tab(t_craft)

	_add_tab(QuestTab.new())

	# Configure + show first.
	for tab: CharacterSheetTab in _tabs:
		tab.configure(player_id, inventory, equipment, self)
	_select_tab(0)


func _add_tab(tab: CharacterSheetTab) -> void:
	tab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab.visible = false
	_body.add_child(tab)
	_tabs.append(tab)

	# Kenney button ninepatch wrapper so the tab label has an opaque
	# backdrop separating it from the panel_brown wood texture.
	var btn: NinePatchRect = NinePatchRect.new()
	btn.texture = load("res://assets/ui/button_brown.png") as Texture2D
	btn.patch_margin_left = 6
	btn.patch_margin_right = 6
	btn.patch_margin_top = 6
	btn.patch_margin_bottom = 6
	btn.custom_minimum_size = Vector2(120.0, 28.0)
	_tab_strip.add_child(btn)

	var lbl: Label = Label.new()
	lbl.text = tab.tab_title()
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.offset_left = 8
	lbl.offset_right = -4
	lbl.offset_top = 1
	lbl.offset_bottom = -1
	# Outline + dark fill so text stays legible on any button tint.
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 4)
	btn.add_child(lbl)
	_tab_labels.append(lbl)
	# Stash the wrapper on the label so _update_tab_label_visuals can
	# swap textures without needing a parallel array.
	lbl.set_meta("wrapper", btn)


func _select_tab(index: int) -> void:
	if _tabs.is_empty():
		return
	index = ((index % _tabs.size()) + _tabs.size()) % _tabs.size()
	if _active_index >= 0 and _active_index < _tabs.size():
		_tabs[_active_index].visible = false
		_tabs[_active_index].on_blur()
	_active_index = index
	_tabs[_active_index].visible = true
	_tabs[_active_index].refresh()
	_tabs[_active_index].on_focus()
	_update_tab_label_visuals()


func _update_tab_label_visuals() -> void:
	for i: int in _tab_labels.size():
		var active: bool = i == _active_index
		var lbl: Label = _tab_labels[i]
		var wrapper: NinePatchRect = lbl.get_meta("wrapper") as NinePatchRect
		lbl.text = _tabs[i].tab_title()
		if active:
			if wrapper:
				wrapper.texture = load("res://assets/ui/button_red.png") as Texture2D
			lbl.add_theme_color_override("font_color", Color(1.0, 0.98, 0.85))
		else:
			if wrapper:
				wrapper.texture = load("res://assets/ui/button_brown.png") as Texture2D
			lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75))


func _refresh_footer() -> void:
	if _footer == null:
		return
	var mine_hint: String = InputManager.get_action_hint(player_id, "mine")
	var jump_hint: String = InputManager.get_action_hint(player_id, "jump")
	var tup: String = InputManager.get_action_hint(player_id, "target_up")
	var tdn: String = InputManager.get_action_hint(player_id, "target_down")
	var inv_hint: String = InputManager.get_action_hint(player_id, "inventory")
	_footer.text = "[%s] Interact   [%s] Drop   [%s/%s] Tab   [%s] Close" % [
		mine_hint, jump_hint, tup, tdn, inv_hint,
	]


# --- open/close ---------------------------------------------------------

func open() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	if player_controller != null:
		player_controller.set_input_blocked(true)
	if _active_index >= 0 and _active_index < _tabs.size():
		_tabs[_active_index].refresh()
		_tabs[_active_index].on_focus()
	_refresh_footer()
	opened.emit()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	if player_controller != null:
		player_controller.set_input_blocked(false)
	closed.emit()


func is_open() -> bool:
	return _is_open


# --- input ---------------------------------------------------------------

func _process(delta: float) -> void:
	if InputManager.is_action_just_pressed(player_id, "inventory"):
		if _is_open:
			close()
		else:
			open()
		return
	if not _is_open:
		return

	# Tab switching.
	if InputManager.is_action_just_pressed(player_id, "target_up"):
		_select_tab(_active_index - 1)
		return
	if InputManager.is_action_just_pressed(player_id, "target_down"):
		_select_tab(_active_index + 1)
		return

	# Interact + drop.
	if InputManager.is_action_just_pressed(player_id, "mine"):
		_tabs[_active_index].handle_interact()
		return
	if InputManager.is_action_just_pressed(player_id, "jump"):
		_tabs[_active_index].handle_drop()
		return

	# Movement → nav. Use InputManager.get_move_vector but poll with a
	# simple repeat scheme so a held direction keeps moving.
	var vec: Vector2 = InputManager.get_move_vector(player_id)
	var dir: Vector2i = Vector2i(
		sign(vec.x) if absf(vec.x) > 0.5 else 0,
		-(sign(vec.y) if absf(vec.y) > 0.5 else 0),  # up = +Y in grid
	) if false else _nav_dir_from_just_pressed()
	# Prefer discrete just_pressed — gives snappy one-step moves.
	if dir != Vector2i.ZERO:
		_tabs[_active_index].handle_nav(dir)
		_nav_repeat_timer = NAV_REPEAT_INITIAL
		return

	# Held-direction repeat using analog vector.
	if absf(vec.x) > 0.5 or absf(vec.y) > 0.5:
		_nav_repeat_timer -= delta
		if _nav_repeat_timer <= 0.0:
			_nav_repeat_timer = NAV_REPEAT_INTERVAL
			var held: Vector2i = Vector2i(
				sign(vec.x) if absf(vec.x) > 0.5 else 0,
				-(sign(vec.y) if absf(vec.y) > 0.5 else 0),
			)
			if held != Vector2i.ZERO:
				_tabs[_active_index].handle_nav(held)
	else:
		_nav_repeat_timer = 0.0


func _nav_dir_from_just_pressed() -> Vector2i:
	var dir: Vector2i = Vector2i.ZERO
	if InputManager.is_action_just_pressed(player_id, "move_left"):
		dir.x -= 1
	if InputManager.is_action_just_pressed(player_id, "move_right"):
		dir.x += 1
	if InputManager.is_action_just_pressed(player_id, "move_up"):
		dir.y -= 1
	if InputManager.is_action_just_pressed(player_id, "move_down"):
		dir.y += 1
	return dir


func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
