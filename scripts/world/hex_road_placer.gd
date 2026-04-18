class_name HexRoadPlacer
extends RefCounted

## Public API for placing and removing roads on a `HexWorld`.
## Roads are overlays (thin Kenney path strips) placed on top of a base
## hex tile. When a road is placed or removed, all adjacent road tiles
## are re-resolved so their shape (straight / corner / T / crossing)
## stays correct.

## Bases that can receive a road overlay.
const ALLOWED_BASES: Array[StringName] = [&"grass", &"dirt", &"sand", &"stone"]


## Place a road overlay at `coord`. Resolves the correct shape and
## rotation based on adjacent roads. Returns true on success.
static func place_road(world: HexWorld, coord: Vector3i) -> bool:
	var cell: HexCell = world.get_cell(coord)
	if cell == null:
		return false
	# Already a road?
	if HexRoadResolver.is_road(world, coord):
		return false
	# Already has a non-road overlay?
	if cell.has_overlay():
		return false
	# Check base is allowed.
	var pal: TilePalette = world.palette
	if pal == null:
		return false
	var tk: TileKind = pal.bases[cell.base_id] if cell.base_id >= 0 and cell.base_id < pal.bases.size() else null
	if tk == null or not (tk.id in ALLOWED_BASES):
		return false
	# Resolve the correct road overlay for this position.
	var result: Dictionary = HexRoadResolver.resolve(world, coord)
	var ov_id: int = result["overlay_id"] as int
	if ov_id < 0:
		return false
	world.swap_overlay(coord, ov_id, result["rotation"] as int)
	# Update all neighboring road tiles so they react to the new road.
	_update_neighbors(world, coord)
	return true


## Remove the road overlay at `coord`. Returns true if a road was removed.
static func remove_road(world: HexWorld, coord: Vector3i) -> bool:
	if not HexRoadResolver.is_road(world, coord):
		return false
	var cell: HexCell = world.get_cell(coord)
	if cell == null:
		return false
	cell.overlay_id = -1
	cell.rotation = 0
	world.set_cell(coord, cell)
	# Update neighbors so they recalculate without this road.
	_update_neighbors(world, coord)
	return true


## Re-resolve each neighbor that is already a road (same layer ±1).
static func _update_neighbors(world: HexWorld, coord: Vector3i) -> void:
	for i: int in 6:
		var dir: Vector2i = HexGrid.AXIAL_DIRECTIONS[i]
		for dz: int in [0, -1, 1]:
			var neighbor: Vector3i = Vector3i(coord.x + dir.x, coord.y + dir.y, coord.z + dz)
			if HexRoadResolver.is_road(world, neighbor):
				_update_road_tile(world, neighbor)


## Recalculate the road overlay shape at `coord` (must already be a road).
static func _update_road_tile(world: HexWorld, coord: Vector3i) -> void:
	var result: Dictionary = HexRoadResolver.resolve(world, coord)
	var ov_id: int = result["overlay_id"] as int
	if ov_id < 0:
		return
	world.swap_overlay(coord, ov_id, result["rotation"] as int)
