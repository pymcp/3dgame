class_name ItemSlotControl
extends Control

## A single slot in the character sheet grid. Shows a 3D icon for the
## item plus a bottom-right stack count. Selection frame is drawn
## around the slot by the owning tab (via a cached Kenney button).

const SLOT_SIZE: Vector2 = Vector2(72.0, 72.0)

var item_id: StringName = &""
var count: int = 0
var selected: bool = false

var _icon: TextureRect = null
var _count_label: Label = null
var _frame: NinePatchRect = null
var _frame_selected: NinePatchRect = null


func _init() -> void:
	custom_minimum_size = SLOT_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_frame = NinePatchRect.new()
	_frame.texture = _load_tex("res://assets/ui/button_brown.png")
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.patch_margin_left = 8
	_frame.patch_margin_right = 8
	_frame.patch_margin_top = 8
	_frame.patch_margin_bottom = 8
	add_child(_frame)

	_frame_selected = NinePatchRect.new()
	_frame_selected.texture = _load_tex("res://assets/ui/button_red.png")
	_frame_selected.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame_selected.patch_margin_left = 8
	_frame_selected.patch_margin_right = 8
	_frame_selected.patch_margin_top = 8
	_frame_selected.patch_margin_bottom = 8
	_frame_selected.visible = false
	add_child(_frame_selected)

	_icon = TextureRect.new()
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 6.0
	_icon.offset_top = 6.0
	_icon.offset_right = -6.0
	_icon.offset_bottom = -6.0
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(_icon)

	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", 14)
	_count_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_count_label.add_theme_constant_override("outline_size", 3)
	_count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_count_label.offset_right = -4.0
	_count_label.offset_bottom = -2.0
	_count_label.offset_left = -40.0
	_count_label.offset_top = -22.0
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_count_label)

	_refresh_visual()


func set_slot(p_item_id: StringName, p_count: int) -> void:
	item_id = p_item_id
	count = p_count
	_refresh_visual()


func set_selected(p_selected: bool) -> void:
	if selected == p_selected:
		return
	selected = p_selected
	if _frame_selected != null:
		_frame_selected.visible = selected


func clear_slot() -> void:
	item_id = &""
	count = 0
	_refresh_visual()


func _refresh_visual() -> void:
	if _icon == null:
		return
	if item_id == &"":
		_icon.texture = null
		_count_label.text = ""
		return
	_icon.texture = ItemIconRenderer.get_icon(get_tree(), item_id)
	if count > 1:
		_count_label.text = "x%d" % count
	else:
		_count_label.text = ""


func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
