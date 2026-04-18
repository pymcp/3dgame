class_name OverlayKind
extends Resource

## Data-driven definition of an *overlay* on a hex cell (tree, rocks,
## hill, ore deposit, mine-entrance marker, ladder…). Mining a cell
## strips the overlay first, then the base. The overlay also controls
## "what's visually on top of this hex and what drops when harvested."
##
## A `HexCell.overlay_id` is the index of one of these inside the
## world's `TilePalette.overlays` array, or `-1` for "no overlay".

@export var id: StringName = &""
@export var display_name: String = ""
## Hex-scale `.glb` placed on top of the cell's base tile.
@export var mesh: Mesh
## Tint applied as per-instance color in the MultiMesh.
@export var tint: Color = Color(1, 1, 1, 1)
## Y offset applied on top of the cell's surface (for props that sit
## slightly embedded or levitate).
@export var y_offset: float = 0.0
## Time (seconds) needed to strip this overlay during mining.
@export var hardness: float = 1.0
## If true, blocks walk-through (e.g. boulders, trees). Ore deposits are
## generally `false` so players can walk through and dig from adjacent
## cells.
@export var blocks_movement: bool = false
## Drops produced when the overlay is stripped.
@export var drops: PackedStringArray = PackedStringArray()
## String ids of `TileKind`s this overlay is allowed to sit on. Empty =
## allowed on anything.
@export var allowed_on_bases: Array[StringName] = []
## Layers this overlay may generate on. Empty = any layer.
@export var valid_layers: PackedInt32Array = PackedInt32Array()
## Non-visual marker used by gameplay systems (e.g. mine entrance,
## ladder). Decoupling from `id` lets us rename freely.
@export var marker: StringName = &""
## When false, the chunk renderer skips the colormap material_override so
## the mesh keeps its embedded GLB material (used for Kenney path tiles
## that carry their own texture).
@export var use_colormap: bool = true


func allowed_on_base(base_id: StringName) -> bool:
	if allowed_on_bases.is_empty():
		return true
	return allowed_on_bases.has(base_id)


func allows_layer(layer: int) -> bool:
	if valid_layers.is_empty():
		return true
	return valid_layers.has(layer)
