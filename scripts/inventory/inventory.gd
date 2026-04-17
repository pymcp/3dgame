class_name Inventory
extends Node

signal inventory_changed(resource_type: String, new_count: int)

var items: Dictionary = {}  # String -> int


func add_item(resource_type: String, count: int = 1) -> void:
	if not items.has(resource_type):
		items[resource_type] = 0
	items[resource_type] += count
	inventory_changed.emit(resource_type, items[resource_type])


func remove_item(resource_type: String, count: int = 1) -> bool:
	if not has_item(resource_type, count):
		return false
	items[resource_type] -= count
	if items[resource_type] <= 0:
		items.erase(resource_type)
		inventory_changed.emit(resource_type, 0)
	else:
		inventory_changed.emit(resource_type, items[resource_type])
	return true


func get_count(resource_type: String) -> int:
	return items.get(resource_type, 0)


func has_item(resource_type: String, count: int = 1) -> bool:
	return items.get(resource_type, 0) >= count


func get_all_items() -> Dictionary:
	return items.duplicate()


func clear() -> void:
	items.clear()
