class_name HexRoadResolver
extends RefCounted

## Auto-tiling brain for hex roads. Given a cell's coordinate and its
## `HexWorld`, computes which road *overlay* + rotation should be placed
## based on which neighboring cells are also roads.
##
## Roads are overlays with `marker = &"road"` (thin Kenney path strips
## placed on top of the hex base tile with `use_colormap = false`).
##
## Algorithm:
##   1. Build a 6-bit connectivity bitmask (bit i ↔ neighbor in dir i has a road).
##   2. Normalize by circular right-shift to find the minimum bitmask (canonical form).
##   3. Look up canonical bitmask in `_CANONICAL_TABLE` → overlay id name + base_rotation.
##   4. Final Y-rotation = (base_rotation + normalization shift) % 6.

## Canonical bitmask → [overlay_id_name, base_rotation].
## base_rotation is the rotation step needed to align the Kenney GLB's
## default connectivity with the canonical mask's bit positions.
## Computed by normalizing each tile's default mask (from vertex analysis).
static var _CANONICAL_TABLE: Dictionary = {
	# 0 neighbors — full hex pad
	0:  [&"road_crossing", 0],
	# 1 neighbor — end faces W by default; rot 3 to face canonical dir 0 (E)
	1:  [&"road_end", 3],
	# 2 neighbors — adjacent (60°): NW+W by default; rot 2 to canonical
	3:  [&"road_corner_sharp", 2],
	# 2 neighbors — skip-1 (120°): NE+W by default; rot 1
	5:  [&"road_corner", 1],
	# 2 neighbors — opposite (180°): E+W by default; rot 0
	9:  [&"road_straight", 0],
	# 3 neighbors — three consecutive (fan): NE+NW+W; rot 1
	7:  [&"road_intersection_a", 1],
	# 3 neighbors — 1+2+3 gap pattern: E+NE+W; rot 0
	11: [&"road_intersection_b", 0],
	# 3 neighbors — mirror of B: E+W+SE; rot 3
	13: [&"road_intersection_c", 3],
	# 3 neighbors — Y-shape (120° spaced): NE+W+SE; rot 1
	21: [&"road_intersection_f", 1],
	# 4 neighbors — four consecutive, missing adjacent pair: rot 0
	15: [&"road_intersection_h", 0],
	# 4 neighbors — missing skip-1 pair (2 apart): rot 5
	23: [&"road_intersection_d", 5],
	# 4 neighbors — missing opposite pair (3 apart): rot 2
	27: [&"road_intersection_e", 2],
	# 5 neighbors: E+NE+NW+W+SE; rot 5
	31: [&"road_intersection_g", 5],
	# 6 neighbors
	63: [&"road_crossing", 0],
}


## Returns `{ overlay_id: int, rotation: int }` for the road overlay that
## should be placed at `coord`, or `{ overlay_id: -1 }` if lookup fails.
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
	# Rotation formula: tile default at base_rot matches canonical; undo
	# the normalization shift to match the actual mask directions.
	var final_rot: int = (base_rot - best_shift + 6) % 6

	var pal: TilePalette = world.palette
	if pal == null:
		return { "overlay_id": -1, "rotation": 0 }
	var ov_idx: int = pal.overlay_index(overlay_name)
	return { "overlay_id": ov_idx, "rotation": final_rot }


## Build a 6-bit bitmask: bit i is set if the neighbor in
## `AXIAL_DIRECTIONS[i]` (same layer or ±1 layer) is also a road.
static func build_bitmask(world: HexWorld, coord: Vector3i) -> int:
	var mask: int = 0
	for i: int in 6:
		var dir: Vector2i = HexGrid.AXIAL_DIRECTIONS[i]
		var nq: int = coord.x + dir.x
		var nr: int = coord.y + dir.y
		# Check same layer and ±1 layer (terrain height varies per column).
		for dz: int in [0, -1, 1]:
			var neighbor: Vector3i = Vector3i(nq, nr, coord.z + dz)
			if is_road(world, neighbor):
				mask |= (1 << i)
				break
	return mask


## Check whether the cell at `coord` has a road overlay.
static func is_road(world: HexWorld, coord: Vector3i) -> bool:
	var cell: HexCell = world.get_cell(coord)
	if cell == null:
		return false
	if not cell.has_overlay():
		return false
	if cell.overlay_id < 0 or cell.overlay_id >= world.palette.overlays.size():
		return false
	var ok: OverlayKind = world.palette.overlays[cell.overlay_id]
	return ok != null and ok.marker == &"road"


## Normalization helper (exposed for tests).
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
