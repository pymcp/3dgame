class_name PlayerEquipment
extends Node

## Equipment slots on a player (weapon, head, chest, legs, boots, ring,
## amulet). The pickaxe is NOT tracked here — it lives on
## `PlayerController.pickaxe_tier` and is always implicitly held.
##
## Equipping moves the item from the player's `Inventory` into the
## slot; unequipping moves it back.

signal equipped(slot: StringName, item_id: StringName)
signal unequipped(slot: StringName, item_id: StringName)

const SLOTS: Array[StringName] = [
	&"weapon", &"head", &"chest", &"legs", &"boots", &"ring", &"amulet",
]

var inventory: Inventory = null

var _slots: Dictionary = {}  # StringName slot -> StringName item_id (&"" = empty)


func _init() -> void:
	for slot: StringName in SLOTS:
		_slots[slot] = &""


func set_inventory(inv: Inventory) -> void:
	inventory = inv


func get_equipped(slot: StringName) -> StringName:
	return _slots.get(slot, &"")


func is_empty(slot: StringName) -> bool:
	return _slots.get(slot, &"") == &""


func get_all_slots() -> Dictionary:
	return _slots.duplicate()


## Equip the given item from inventory. Returns true if the item was
## moved into its slot. Automatically unequips whatever was already in
## that slot (back to inventory).
func equip(item_id: StringName) -> bool:
	if inventory == null:
		return false
	var def: ItemDef = ItemRegistry.get_def(item_id)
	if def == null or not def.is_equippable():
		return false
	if not inventory.has_item(item_id, 1):
		return false
	var slot: StringName = def.equipment_slot()
	# Swap out anything currently in the slot (go back to inventory).
	var previous: StringName = _slots.get(slot, &"")
	if previous != &"":
		_slots[slot] = &""
		inventory.add_item(previous, 1)
		unequipped.emit(slot, previous)
	inventory.remove_item(item_id, 1)
	_slots[slot] = item_id
	equipped.emit(slot, item_id)
	return true


## Unequip a slot back into inventory. Returns true if something was
## unequipped.
func unequip(slot: StringName) -> bool:
	if inventory == null:
		return false
	var item_id: StringName = _slots.get(slot, &"")
	if item_id == &"":
		return false
	_slots[slot] = &""
	inventory.add_item(item_id, 1)
	unequipped.emit(slot, item_id)
	return true
