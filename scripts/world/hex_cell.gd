class_name HexCell
extends RefCounted

## One hex cell in a `HexWorld`. Cells are *sparse* — a coord that has no
## stored `HexCell` is considered open air / walkable empty space.
##
## `base_id` and `overlay_id` are indices into the world's `TilePalette`.
## An `overlay_id == -1` means "no overlay on this cell".

var q: int = 0
var r: int = 0
var layer: int = 0
var base_id: int = 0
var overlay_id: int = -1
## Extra hex-scale elevation added on top of `layer * LAYER_HEIGHT` (typically 0).
var elevation: float = 0.0
## Y-rotation in 60° increments (0–5). 0 = 0°, 1 = 60°, … 5 = 300°.
## Used by road tiles and any future rotated tiles.
var rotation: int = 0


func _init(q_val: int = 0, r_val: int = 0, layer_val: int = 0, base: int = 0, overlay: int = -1) -> void:
	q = q_val
	r = r_val
	layer = layer_val
	base_id = base
	overlay_id = overlay


func coord() -> Vector3i:
	return Vector3i(q, r, layer)


func has_overlay() -> bool:
	return overlay_id >= 0
