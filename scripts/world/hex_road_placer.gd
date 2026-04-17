class_name HexRoadPlacer
extends RefCounted

## Public API for placing and removing roads on a `HexWorld`.
## When a road is placed or removed, all adjacent road tiles are
## re-resolved so their shape (straight / corner / T / crossing)
## stays correct.


## Place a road at `coord`. Returns true on success.
## Fails if: no cell, cell already has an overlay, or base is
## not an allowed type.
static func place_road(world: HexWorld, coord: Vector3i) -> bool:
	var cell: HexCell = world.get_cell(coord)
	if cell == null or cell.has_overlay():
		return false
	# Resolve the correct tile for the new road (considering neighbors).
	var result: Dictionary = HexRoadResolver.resolve(world, coord)
	var ov_id: int = result["overlay_id"] as int
	if ov_id < 0:
		return false
	# place_overlay_rotated checks allowed_on_base.
	if not world.place_overlay_rotated(coord, ov_id, result["rotation"] as int):
		return false
	# Update all neighboring road tiles so they react to the new road.
	_update_neighbors(world, coord)
	return true


## Remove the road overlay at `coord`. Returns true if a road was
## removed, false if the cell had no road.
static func remove_road(world: HexWorld, coord: Vector3i) -> bool:
	if not HexRoadResolver.is_road(world, coord):
		return false
	# Strip overlay via mine_cell (drops items, emits signal).
	world.mine_cell(coord)
	# Update neighbors so they recalculate without this road.
	_update_neighbors(world, coord)
	return true


## Re-resolve each neighbor that is already a road.
static func _update_neighbors(world: HexWorld, coord: Vector3i) -> void:
	for i: int in 6:
		var dir: Vector2i = HexGrid.AXIAL_DIRECTIONS[i]
		var neighbor: Vector3i = Vector3i(coord.x + dir.x, coord.y + dir.y, coord.z)
		if HexRoadResolver.is_road(world, neighbor):
			_update_road_tile(world, neighbor)


## Recalculate the road tile shape at `coord` (must already be a road).
static func _update_road_tile(world: HexWorld, coord: Vector3i) -> void:
	var result: Dictionary = HexRoadResolver.resolve(world, coord)
	var ov_id: int = result["overlay_id"] as int
	if ov_id < 0:
		return
	world.swap_overlay(coord, ov_id, result["rotation"] as int)
