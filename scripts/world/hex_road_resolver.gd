class_name HexRoadResolver
extends RefCounted

## Auto-tiling brain for hex roads. Given a cell's coordinate and its
## `HexWorld`, computes which road overlay + rotation should be placed
## based on which neighboring cells are also roads.
##
## Algorithm:
##   1. Build a 6-bit connectivity bitmask (bit i ↔ neighbor in dir i has a road).
##   2. Normalize by circular right-shift to find the minimum bitmask (canonical form).
##   3. Look up canonical bitmask in `_CANONICAL_TABLE` → overlay id name + base_rotation.
##   4. Final Y-rotation = (base_rotation + normalization shift) % 6.

## All road overlay StringName ids. Membership check for "is this cell a road?"
const ROAD_OVERLAY_IDS: Array[StringName] = [
	&"road_end",
	&"road_straight",
	&"road_corner_sharp",
	&"road_corner",
	&"road_intersection_a",
	&"road_intersection_b",
	&"road_intersection_c",
	&"road_intersection_d",
	&"road_intersection_e",
	&"road_intersection_f",
	&"road_intersection_g",
	&"road_intersection_h",
	&"road_crossing",
]

## Canonical bitmask → [overlay_id_name, base_rotation].
## base_rotation compensates for how the Kenney GLB is oriented.
## Tune these if roads look misaligned in-game.
static var _CANONICAL_TABLE: Dictionary = {
	# 0 neighbors — full hex pad
	0:  [&"road_crossing", 0],
	# 1 neighbor
	1:  [&"road_end", 0],
	# 2 neighbors — adjacent (60°)
	3:  [&"road_corner_sharp", 0],
	# 2 neighbors — skip-1 (120°)
	5:  [&"road_corner", 0],
	# 2 neighbors — opposite (180°)
	9:  [&"road_straight", 0],
	# 3 neighbors — three consecutive (fan)
	7:  [&"road_intersection_a", 0],
	# 3 neighbors — 1+2+3 gap pattern
	11: [&"road_intersection_b", 0],
	# 3 neighbors — mirror of B (2+1+3 gaps)
	13: [&"road_intersection_c", 0],
	# 3 neighbors — Y-shape (120° spaced)
	21: [&"road_intersection_f", 0],
	# 4 neighbors — missing adjacent pair
	15: [&"road_intersection_d", 0],
	# 4 neighbors — missing skip-1 pair
	23: [&"road_intersection_e", 0],
	# 4 neighbors — missing opposite pair
	27: [&"road_intersection_h", 0],
	# 5 neighbors
	31: [&"road_intersection_g", 0],
	# 6 neighbors
	63: [&"road_crossing", 0],
}


## Returns `{ overlay_id: int, rotation: int }` for the road tile that
## should be placed at `coord`, or `{ overlay_id: -1 }` if the cell
## is not a valid road location.
static func resolve(world: HexWorld, coord: Vector3i) -> Dictionary:
	var mask: int = build_bitmask(world, coord)
	# Normalize to canonical form (minimum rotation).
	var best_mask: int = mask
	var best_shift: int = 0
	var rotated: int = mask
	for s: int in range(1, 6):
		rotated = ((rotated >> 1) | ((rotated & 1) << 5)) & 0x3F
		if rotated < best_mask:
			best_mask = rotated
			best_shift = s

	var entry: Array = _CANONICAL_TABLE.get(best_mask, [&"road_crossing", 0]) as Array
	var overlay_name: StringName = entry[0] as StringName
	var base_rot: int = entry[1] as int
	var final_rot: int = (base_rot + best_shift) % 6

	var pal: TilePalette = world.palette
	if pal == null:
		return { "overlay_id": -1, "rotation": 0 }
	var ov_idx: int = pal.overlay_index(overlay_name)
	return { "overlay_id": ov_idx, "rotation": final_rot }


## Build a 6-bit bitmask: bit i is set if the neighbor in
## `AXIAL_DIRECTIONS[i]` (same layer) is also a road.
static func build_bitmask(world: HexWorld, coord: Vector3i) -> int:
	var mask: int = 0
	for i: int in 6:
		var dir: Vector2i = HexGrid.AXIAL_DIRECTIONS[i]
		var neighbor: Vector3i = Vector3i(coord.x + dir.x, coord.y + dir.y, coord.z)
		if is_road(world, neighbor):
			mask |= (1 << i)
	return mask


## Check whether the cell at `coord` carries a road overlay.
static func is_road(world: HexWorld, coord: Vector3i) -> bool:
	var cell: HexCell = world.get_cell(coord)
	if cell == null or not cell.has_overlay():
		return false
	if cell.overlay_id < 0 or cell.overlay_id >= world.palette.overlays.size():
		return false
	var ok: OverlayKind = world.palette.overlays[cell.overlay_id]
	return ok != null and ok.marker == &"road"


## Normalize a bitmask to its canonical (minimum) form and return the
## rotation count. Pure static — useful for unit tests.
static func normalize(mask: int) -> Array:
	var best_mask: int = mask
	var best_shift: int = 0
	var rotated: int = mask
	for s: int in range(1, 6):
		rotated = ((rotated >> 1) | ((rotated & 1) << 5)) & 0x3F
		if rotated < best_mask:
			best_mask = rotated
			best_shift = s
	return [best_mask, best_shift]
