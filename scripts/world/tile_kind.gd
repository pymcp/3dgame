class_name TileKind
extends Resource

## Data-driven definition of a *base* hex tile that a cell sits on
## (grass, dirt, sand, stone, dark_stone, bedrock, water…).
##
## A `HexCell.base_id` is the index of one of these inside the world's
## `TilePalette.bases` array.

## Short lookup name — also used as string id in save/load + skills.
@export var id: StringName = &""
## Display name for UI.
@export var display_name: String = ""
## Hex tile `.glb` used by the MultiMesh renderer for this base.
@export var mesh: Mesh
## Optional tint applied as per-instance color in the MultiMesh
## (leave white = Color(1,1,1,1) for no tint).
@export var tint: Color = Color(1, 1, 1, 1)
## World-units tall — used for vertical stacking offsets. Defaults to
## Kenney hex tile Y extent of 0.2.
@export var height: float = 0.2
## Time (in seconds) a held mine action needs to remove this base tile
## outright (only relevant once the overlay has already been stripped).
@export var hardness: float = 1.5
## Human-readable string ids of items dropped when the base tile is fully
## removed (ore yields go through the overlay; base drops are for dirt,
## stone chunks, etc.).
@export var drops: PackedStringArray = PackedStringArray()
## Layers this base is allowed to generate in. Empty = any layer.
@export var valid_layers: PackedInt32Array = PackedInt32Array()
## If true, this tile cannot be mined (e.g. `bedrock`). Overrides `hardness`.
@export var unbreakable: bool = false
## If true, cell is walkable on top (stand on it). Water is not.
@export var walkable_top: bool = true


func allows_layer(layer: int) -> bool:
	if valid_layers.is_empty():
		return true
	return valid_layers.has(layer)
