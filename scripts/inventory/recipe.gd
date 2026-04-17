class_name Recipe
extends Resource

## A single crafting recipe. Inputs are consumed from the player's
## inventory, output is added on success. Requires `requires_marker`
## overlay nearby (default: workbench).

@export var id: StringName = &""
@export var display_name: String = ""
## Parallel arrays: `input_ids[i]` of count `input_counts[i]`. Flat
## typed arrays keep the resource easy to inspect.
@export var input_ids: Array[StringName] = []
@export var input_counts: Array[int] = []
@export var output_id: StringName = &""
@export var output_count: int = 1
@export var requires_marker: StringName = &"workbench"


static func build(id: StringName, display: String,
		inputs: Array, output_id: StringName, output_count: int = 1,
		marker: StringName = &"workbench") -> Recipe:
	var r: Recipe = Recipe.new()
	r.id = id
	r.display_name = display
	r.input_ids = []
	r.input_counts = []
	for entry: Array in inputs:
		r.input_ids.append(entry[0] as StringName)
		r.input_counts.append(entry[1] as int)
	r.output_id = output_id
	r.output_count = output_count
	r.requires_marker = marker
	return r


func can_craft(inv: Inventory) -> bool:
	if inv == null:
		return false
	for i: int in input_ids.size():
		if inv.get_count(input_ids[i]) < input_counts[i]:
			return false
	return true


## Consume inputs and grant output. Returns true on success. Does NOT
## check marker proximity — callers handle that.
func craft(inv: Inventory) -> bool:
	if inv == null or not can_craft(inv):
		return false
	for i: int in input_ids.size():
		inv.remove_item(input_ids[i], input_counts[i])
	inv.add_item(output_id, output_count)
	return true
