extends Node

## Autoload: list of known crafting recipes.

const RecipeScript: Script = preload("res://scripts/inventory/recipe.gd")

var _recipes: Array = []  # Array[Recipe]


func _init() -> void:
	_seed_recipes()


func all() -> Array:
	return _recipes


func get_by_id(id: StringName) -> Resource:
	for r: Resource in _recipes:
		if r.id == id:
			return r
	return null


func _seed_recipes() -> void:
	_recipes.append(RecipeScript.build(&"recipe_sword_basic", "Basic Sword",
		[[&"iron_ore", 2], [&"wood", 1]], &"sword_basic", 1))
	_recipes.append(RecipeScript.build(&"recipe_sword_iron", "Iron Sword",
		[[&"iron_ore", 4], [&"wood", 1]], &"sword_iron", 1))
	_recipes.append(RecipeScript.build(&"recipe_axe_basic", "Woodcutter's Axe",
		[[&"stone", 3], [&"wood", 2]], &"axe_basic", 1))
	_recipes.append(RecipeScript.build(&"recipe_axe_upgraded", "Battle Axe",
		[[&"iron_ore", 3], [&"wood", 2]], &"axe_upgraded", 1))
	_recipes.append(RecipeScript.build(&"recipe_hammer_basic", "War Hammer",
		[[&"stone", 4], [&"wood", 1]], &"hammer_basic", 1))
	_recipes.append(RecipeScript.build(&"recipe_hammer_upgraded", "Great Hammer",
		[[&"iron_ore", 3], [&"stone", 2], [&"wood", 1]], &"hammer_upgraded", 1))
