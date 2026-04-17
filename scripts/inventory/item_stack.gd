class_name ItemStack
extends RefCounted

## Lightweight value-type for "N copies of item X". Used by recipes and
## UI code; `Inventory` still stores counts in a flat dictionary for
## cheap hot-path lookups.

var id: StringName = &""
var count: int = 0


func _init(p_id: StringName = &"", p_count: int = 0) -> void:
	id = p_id
	count = p_count


func duplicate_stack() -> ItemStack:
	return ItemStack.new(id, count)
