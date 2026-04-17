class_name PauseMenu
extends CanvasLayer

signal resumed
signal quit_requested
signal player_toggled(player_id: int, enabled: bool)

var _panel_texture: Texture2D
var _button_brown_texture: Texture2D
var _button_red_texture: Texture2D
var _banner_texture: Texture2D

var _root: Control
var _selected_index: int = 0
var _select_indicators: Array[Label] = []
var _item_labels: Array[Label] = []

var _p1_enabled: bool = true
var _p2_enabled: bool = true

const MENU_ACTIONS: Array[String] = ["resume", "toggle_p1", "toggle_p2", "quit"]


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_load_textures()
	_build_ui()
	_refresh_labels()


func _load_textures() -> void:
	_panel_texture = _load_tex("res://assets/ui/panel_brown.png")
	_button_brown_texture = _load_tex("res://assets/ui/button_brown.png")
	_button_red_texture = _load_tex("res://assets/ui/button_red.png")
	_banner_texture = _load_tex("res://assets/ui/banner_hanging.png")


func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _build_ui() -> void:
	_root = ColorRect.new()
	(_root as ColorRect).color = Color(0.0, 0.0, 0.0, 0.6)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel_wrapper: VBoxContainer = VBoxContainer.new()
	panel_wrapper.custom_minimum_size = Vector2(420, 470)
	panel_wrapper.add_theme_constant_override("separation", 0)
	center.add_child(panel_wrapper)

	_build_banner(panel_wrapper)
	_build_panel(panel_wrapper)


func _build_banner(parent: VBoxContainer) -> void:
	var banner_center: CenterContainer = CenterContainer.new()
	parent.add_child(banner_center)

	if _banner_texture:
		var banner: TextureRect = TextureRect.new()
		banner.texture = _banner_texture
		banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		banner.custom_minimum_size = Vector2(380, 70)
		banner_center.add_child(banner)

		var title: Label = Label.new()
		title.text = "PAUSED"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		title.add_theme_font_size_override("font_size", 28)
		title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
		title.add_theme_color_override("font_shadow_color", Color(0.2, 0.1, 0.0, 0.8))
		title.add_theme_constant_override("shadow_offset_x", 2)
		title.add_theme_constant_override("shadow_offset_y", 2)
		banner.add_child(title)
	else:
		var title: Label = Label.new()
		title.text = "PAUSED"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 28)
		title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
		banner_center.add_child(title)


func _build_panel(parent: VBoxContainer) -> void:
	var panel_center: CenterContainer = CenterContainer.new()
	parent.add_child(panel_center)

	var panel_bg: NinePatchRect = NinePatchRect.new()
	panel_bg.custom_minimum_size = Vector2(400, 380)
	if _panel_texture:
		panel_bg.texture = _panel_texture
		panel_bg.patch_margin_left = 8
		panel_bg.patch_margin_top = 8
		panel_bg.patch_margin_right = 8
		panel_bg.patch_margin_bottom = 8
	panel_center.add_child(panel_bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel_bg.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	_add_menu_button(vbox, "Resume", _button_brown_texture, 0)
	_add_menu_button(vbox, "Disable Player 1", _button_brown_texture, 1)
	_add_menu_button(vbox, "Disable Player 2", _button_brown_texture, 2)
	_add_menu_button(vbox, "Quit Game", _button_red_texture, 3)

	var hint: Label = Label.new()
	hint.text = "W/S  Select  \u2022  Enter  Confirm  \u2022  Esc  Resume"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5, 0.8))
	vbox.add_child(hint)


func _add_menu_button(parent: VBoxContainer, text: String, tex: Texture2D, index: int) -> void:
	var button_center: CenterContainer = CenterContainer.new()
	parent.add_child(button_center)

	var btn_bg: NinePatchRect = NinePatchRect.new()
	btn_bg.custom_minimum_size = Vector2(300, 48)
	if tex:
		btn_bg.texture = tex
		btn_bg.patch_margin_left = 8
		btn_bg.patch_margin_top = 8
		btn_bg.patch_margin_right = 8
		btn_bg.patch_margin_bottom = 8
	button_center.add_child(btn_bg)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	btn_bg.add_child(hbox)

	var indicator: Label = Label.new()
	indicator.text = "\u25b6"
	indicator.add_theme_font_size_override("font_size", 20)
	indicator.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	indicator.visible = index == 0
	hbox.add_child(indicator)
	_select_indicators.append(indicator)

	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	label.add_theme_color_override("font_shadow_color", Color(0.15, 0.1, 0.0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)
	_item_labels.append(label)

	var spacer: Label = Label.new()
	spacer.text = "\u25b6"
	spacer.add_theme_font_size_override("font_size", 20)
	spacer.modulate = Color(0, 0, 0, 0)
	hbox.add_child(spacer)


## Called by main.gd to seed the current enabled state before `show_menu`.
func set_player_states(p1_enabled: bool, p2_enabled: bool) -> void:
	_p1_enabled = p1_enabled
	_p2_enabled = p2_enabled
	if is_inside_tree():
		_refresh_labels()


func _refresh_labels() -> void:
	if _item_labels.size() < MENU_ACTIONS.size():
		return
	var resume_locked: bool = not (_p1_enabled or _p2_enabled)
	if resume_locked:
		_item_labels[0].text = "Resume (need a player)"
		_item_labels[0].add_theme_color_override("font_color", Color(0.6, 0.55, 0.45))
	else:
		_item_labels[0].text = "Resume"
		_item_labels[0].add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))

	_item_labels[1].text = "Disable Player 1" if _p1_enabled else "Enable Player 1"
	_item_labels[2].text = "Disable Player 2" if _p2_enabled else "Enable Player 2"
	_item_labels[3].text = "Quit Game"


func show_menu() -> void:
	visible = true
	_selected_index = 0
	_refresh_labels()
	_update_selection()
	get_tree().paused = true


func hide_menu() -> void:
	if not (_p1_enabled or _p2_enabled):
		return  # Can't leave the menu while both players are disabled.
	visible = false
	get_tree().paused = false
	resumed.emit()


func _update_selection() -> void:
	for i: int in range(_select_indicators.size()):
		_select_indicators[i].visible = i == _selected_index


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key: InputEventKey = event as InputEventKey
		match key.keycode:
			KEY_ESCAPE:
				hide_menu()
				get_viewport().set_input_as_handled()
			KEY_UP, KEY_W:
				_selected_index = (_selected_index - 1 + MENU_ACTIONS.size()) % MENU_ACTIONS.size()
				_update_selection()
				get_viewport().set_input_as_handled()
			KEY_DOWN, KEY_S:
				_selected_index = (_selected_index + 1) % MENU_ACTIONS.size()
				_update_selection()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_F:
				_confirm_selection()
				get_viewport().set_input_as_handled()

	if event is InputEventJoypadButton and event.pressed:
		var joy: InputEventJoypadButton = event as InputEventJoypadButton
		match joy.button_index:
			JOY_BUTTON_DPAD_UP:
				_selected_index = (_selected_index - 1 + MENU_ACTIONS.size()) % MENU_ACTIONS.size()
				_update_selection()
				get_viewport().set_input_as_handled()
			JOY_BUTTON_DPAD_DOWN:
				_selected_index = (_selected_index + 1) % MENU_ACTIONS.size()
				_update_selection()
				get_viewport().set_input_as_handled()
			JOY_BUTTON_A:
				_confirm_selection()
				get_viewport().set_input_as_handled()
			JOY_BUTTON_START, JOY_BUTTON_B:
				hide_menu()
				get_viewport().set_input_as_handled()


func _confirm_selection() -> void:
	var action: String = MENU_ACTIONS[_selected_index]
	match action:
		"resume":
			hide_menu()
		"toggle_p1":
			_p1_enabled = not _p1_enabled
			_refresh_labels()
			player_toggled.emit(1, _p1_enabled)
		"toggle_p2":
			_p2_enabled = not _p2_enabled
			_refresh_labels()
			player_toggled.emit(2, _p2_enabled)
		"quit":
			get_tree().quit()
