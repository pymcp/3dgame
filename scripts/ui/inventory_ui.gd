class_name InventoryUI
extends Control

@export var player_id: int = 1

var _inventory: Inventory = null
var _grid: GridContainer = null
var _visible: bool = false
var _slots: Dictionary = {}  # resource_type -> Label
var _panel: PanelContainer = null


func _ready() -> void:
	# Make this Control fill the CanvasLayer so anchoring works
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_ui()


func _build_ui() -> void:
	# Center container to hold the panel
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# Background panel
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(280, 360)
	center.add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	_panel.add_child(vbox)

	# Title
	var title: Label = Label.new()
	title.text = "Inventory - P%d" % player_id
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Separator
	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	# Grid for items
	_grid = GridContainer.new()
	_grid.columns = 2
	vbox.add_child(_grid)


func set_inventory(inventory: Inventory) -> void:
	if _inventory:
		_inventory.inventory_changed.disconnect(_on_inventory_changed)
	_inventory = inventory
	if _inventory:
		_inventory.inventory_changed.connect(_on_inventory_changed)
		_refresh()


func _on_inventory_changed(_resource_type: String, _new_count: int) -> void:
	_refresh()


func _refresh() -> void:
	if _inventory == null or _grid == null:
		return

	# Clear existing slots
	for child: Node in _grid.get_children():
		child.queue_free()
	_slots.clear()

	# Add items
	var items: Dictionary = _inventory.get_all_items()
	for resource_type: String in items:
		var count: int = items[resource_type]
		if count <= 0:
			continue

		# Resource name label
		var name_label: Label = Label.new()
		name_label.text = _format_name(resource_type)
		_grid.add_child(name_label)

		# Count label
		var count_label: Label = Label.new()
		count_label.text = "x%d" % count
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_grid.add_child(count_label)
		_slots[resource_type] = count_label


func _format_name(resource_type: String) -> String:
	return resource_type.replace("_", " ").capitalize()


func _process(_delta: float) -> void:
	if InputManager.is_action_just_pressed(player_id, "inventory"):
		_visible = not _visible
		visible = _visible
		if _visible:
			_refresh()
