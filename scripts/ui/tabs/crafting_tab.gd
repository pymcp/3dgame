class_name CraftingTab
extends CharacterSheetTab

## Left: scrollable list of recipes. Right: inputs/output + status line.
## Nearby-workbench check queries the active `HexWorld` for the
## `&"workbench"` marker.

var _recipe_list: ItemList = null
var _detail_vbox: VBoxContainer = null
var _status_label: Label = null
var _craft_btn_label: Label = null
var _selected_recipe: Recipe = null
var _overworld: HexWorld = null
var _mine: HexWorld = null
var player_controller: PlayerController = null


func tab_title() -> String:
	return "Crafting"


func set_worlds(overworld_world: HexWorld, mine_world: HexWorld) -> void:
	_overworld = overworld_world
	_mine = mine_world


func set_player_controller(pc: PlayerController) -> void:
	player_controller = pc


func _on_configured() -> void:
	_build_layout()
	_populate_recipes()
	if inventory != null and not inventory.inventory_changed.is_connected(_on_inventory_changed):
		inventory.inventory_changed.connect(_on_inventory_changed)


func _build_layout() -> void:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 12)
	add_child(hbox)

	_recipe_list = ItemList.new()
	_recipe_list.custom_minimum_size = Vector2(220, 260)
	_recipe_list.allow_reselect = true
	_recipe_list.focus_mode = Control.FOCUS_NONE
	_recipe_list.add_theme_font_size_override("font_size", 14)
	_recipe_list.item_selected.connect(_on_recipe_selected)
	hbox.add_child(_recipe_list)

	_detail_vbox = VBoxContainer.new()
	_detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_detail_vbox)


func _populate_recipes() -> void:
	_recipe_list.clear()
	for r: Recipe in RecipeRegistry.all():
		_recipe_list.add_item(r.display_name)
	if _recipe_list.item_count > 0:
		_recipe_list.select(0)
		_on_recipe_selected(0)


func _on_recipe_selected(index: int) -> void:
	var recipes: Array = RecipeRegistry.all()
	if index < 0 or index >= recipes.size():
		_selected_recipe = null
	else:
		_selected_recipe = recipes[index] as Recipe
	_rebuild_detail()


func _rebuild_detail() -> void:
	for child: Node in _detail_vbox.get_children():
		child.queue_free()
	_status_label = null
	_craft_btn_label = null
	if _selected_recipe == null:
		return
	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", 18)
	title.text = _selected_recipe.display_name
	_detail_vbox.add_child(title)

	var out_def: ItemDef = ItemRegistry.get_def(_selected_recipe.output_id)
	var out_label: Label = Label.new()
	out_label.add_theme_font_size_override("font_size", 14)
	out_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.7))
	out_label.text = "Output: %s x%d" % [
		out_def.display_name if out_def else String(_selected_recipe.output_id),
		_selected_recipe.output_count
	]
	_detail_vbox.add_child(out_label)
	if out_def and out_def.description != "":
		var desc: Label = Label.new()
		desc.text = out_def.description
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		_detail_vbox.add_child(desc)

	var inputs_title: Label = Label.new()
	inputs_title.text = "Inputs:"
	inputs_title.add_theme_font_size_override("font_size", 14)
	_detail_vbox.add_child(inputs_title)
	for i: int in _selected_recipe.input_ids.size():
		var id: StringName = _selected_recipe.input_ids[i]
		var need: int = _selected_recipe.input_counts[i]
		var have: int = inventory.get_count(id) if inventory else 0
		var line: Label = Label.new()
		line.add_theme_font_size_override("font_size", 13)
		var name: String = ItemRegistry.display_name_for(id)
		line.text = "  %s: %d / %d" % [name, have, need]
		if have < need:
			line.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		else:
			line.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
		_detail_vbox.add_child(line)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 13)
	_detail_vbox.add_child(_status_label)

	_craft_btn_label = Label.new()
	_craft_btn_label.add_theme_font_size_override("font_size", 14)
	_craft_btn_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	_detail_vbox.add_child(_craft_btn_label)

	_update_status()


func _update_status() -> void:
	if _selected_recipe == null or _status_label == null:
		return
	var near: bool = _near_required_marker()
	var can: bool = inventory != null and _selected_recipe.can_craft(inventory)
	_status_label.text = "Near workbench: %s    Inputs: %s" % [
		"Yes" if near else "No",
		"Yes" if can else "No",
	]
	_status_label.add_theme_color_override("font_color",
		Color(0.7, 1.0, 0.7) if near and can else Color(1.0, 0.7, 0.5))
	if _craft_btn_label:
		_craft_btn_label.text = "[Mine] Craft" if (near and can) else "(missing requirements)"


func _near_required_marker() -> bool:
	if _selected_recipe == null or player_controller == null:
		return false
	var world: HexWorld = _mine if player_controller.is_underground else _overworld
	if world == null:
		return false
	var pc: Vector3i = world.world_to_coord(player_controller.global_position)
	return world.find_nearby_marker(pc, _selected_recipe.requires_marker) != HexWorld.NO_COORD


func handle_nav(dir: Vector2i) -> void:
	if dir.y != 0 and _recipe_list.item_count > 0:
		var sel: int = 0
		var current: PackedInt32Array = _recipe_list.get_selected_items()
		if current.size() > 0:
			sel = current[0]
		sel = (sel + dir.y + _recipe_list.item_count) % _recipe_list.item_count
		_recipe_list.select(sel)
		_on_recipe_selected(sel)


func handle_interact() -> void:
	if _selected_recipe == null or inventory == null:
		return
	if not _near_required_marker():
		Toast.push("Not near a workbench")
		return
	if not _selected_recipe.can_craft(inventory):
		Toast.push("Missing ingredients")
		return
	if _selected_recipe.craft(inventory):
		Toast.push("Crafted: %s" % _selected_recipe.display_name)


func _on_inventory_changed(_id: StringName, _count: int) -> void:
	_rebuild_detail()
