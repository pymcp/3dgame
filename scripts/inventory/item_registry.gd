extends Node

## Autoload: canonical registry of every `ItemDef` in the game.
## Access via `ItemRegistry.get_def(&"iron_ore")` etc.
##
## The pickaxe is intentionally absent — mining uses the implicit
## `PlayerController.pickaxe_tier`, never an inventory item.

const ItemDefScript: Script = preload("res://scripts/inventory/item_def.gd")

const SURVIVAL: String = "res://assets/survival/"

var _defs: Dictionary = {}  # StringName id -> ItemDef


func _init() -> void:
	_seed_defs()


func get_def(id: StringName) -> ItemDef:
	return _defs.get(id, null)


func has_def(id: StringName) -> bool:
	return _defs.has(id)


func all_ids() -> Array:
	return _defs.keys()


func ids_by_category(category: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _defs:
		var d: ItemDef = _defs[id]
		if d.category == category:
			out.append(id)
	return out


## Display-friendly fallback when an id has no registered def (shouldn't
## normally happen — drops all come from registered ids — but useful
## in debug). Mirrors the old `_format_name` behavior.
func display_name_for(id: StringName) -> String:
	var d: ItemDef = _defs.get(id, null)
	if d:
		return d.display_name
	return String(id).replace("_", " ").capitalize()


func _seed_defs() -> void:
	# --- raw materials (ore drops, dirt, etc.) ---
	_add(_make(&"stone", "Stone", ItemDef.CAT_MATERIAL, "Chunk of rough stone."))
	_add(_make(&"dirt_clod", "Dirt Clod", ItemDef.CAT_MATERIAL, "A lump of topsoil."))
	_add(_make(&"sand", "Sand", ItemDef.CAT_MATERIAL, "Fine desert sand."))
	_add(_make(&"wood", "Wood", ItemDef.CAT_MATERIAL, "A bundle of timber."))
	_add(_make(&"iron_ore", "Iron Ore", ItemDef.CAT_MATERIAL, "Rough iron ore, ready for smelting."))
	_add(_make(&"gold_ore", "Gold Ore", ItemDef.CAT_MATERIAL, "Gleaming chunks of gold ore."))
	_add(_make(&"crystal", "Crystal", ItemDef.CAT_MATERIAL, "A shimmering raw crystal."))

	# --- weapons (combat — no effect in v1, reserved) ---
	_add(_make_weapon(&"sword_basic", "Basic Sword", SURVIVAL + "tool-axe.glb", 2.0,
		"A simple iron sword."))
	_add(_make_weapon(&"sword_iron", "Iron Sword", SURVIVAL + "tool-axe-upgraded.glb", 4.0,
		"A well-forged iron blade."))
	_add(_make_weapon(&"axe_basic", "Woodcutter's Axe", SURVIVAL + "tool-axe.glb", 2.5,
		"A sturdy axe, good against armor."))
	_add(_make_weapon(&"axe_upgraded", "Battle Axe", SURVIVAL + "tool-axe-upgraded.glb", 4.5,
		"A reinforced combat axe."))
	_add(_make_weapon(&"hammer_basic", "War Hammer", SURVIVAL + "tool-hammer.glb", 3.0,
		"Heavy, blunt, and satisfying."))
	_add(_make_weapon(&"hammer_upgraded", "Great Hammer", SURVIVAL + "tool-hammer-upgraded.glb", 5.0,
		"Reforged with steel bands."))


func _make(id: StringName, display: String, category: StringName, description: String = "") -> ItemDef:
	var d: ItemDef = ItemDef.new()
	d.id = id
	d.display_name = display
	d.category = category
	d.description = description
	return d


func _make_weapon(id: StringName, display: String, mesh_path: String, damage: float,
		description: String = "") -> ItemDef:
	var d: ItemDef = _make(id, display, ItemDef.CAT_WEAPON, description)
	d.icon_mesh_path = mesh_path
	d.model_scene_path = mesh_path
	d.attack_damage = damage
	d.stack_size = 1
	return d


func _add(def: ItemDef) -> void:
	_defs[def.id] = def
