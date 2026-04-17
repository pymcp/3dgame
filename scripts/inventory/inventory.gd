class_name Inventory
extends Node

## Flat stack-count store for a single player. Keys are `StringName`
## item ids (see `ItemRegistry`). Accepts `String` or `StringName`
## from callers — all internal storage normalizes to `StringName`.

const ItemStackScript: Script = preload("res://scripts/inventory/item_stack.gd")

signal inventory_changed(resource_type: StringName, new_count: int)

var items: Dictionary = {}  # StringName -> int


func add_item(resource_type: Variant, count: int = 1) -> void:
	var key: StringName = _key(resource_type)
	items[key] = items.get(key, 0) + count
	inventory_changed.emit(key, items[key])


func remove_item(resource_type: Variant, count: int = 1) -> bool:
	var key: StringName = _key(resource_type)
	if not has_item(key, count):
		return false
	items[key] -= count
	if items[key] <= 0:
		items.erase(key)
		inventory_changed.emit(key, 0)
	else:
		inventory_changed.emit(key, items[key])
	return true


func get_count(resource_type: Variant) -> int:
	return items.get(_key(resource_type), 0)


func has_item(resource_type: Variant, count: int = 1) -> bool:
	return items.get(_key(resource_type), 0) >= count


func get_all_items() -> Dictionary:
	return items.duplicate()


func get_stack(resource_type: Variant) -> ItemStack:
	var key: StringName = _key(resource_type)
	return ItemStackScript.new(key, items.get(key, 0))


func clear() -> void:
	items.clear()


static func _key(id: Variant) -> StringName:
	if id is StringName:
		return id
	return StringName(id)
