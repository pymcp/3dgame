class_name HexPathfinder
extends RefCounted

## A* pathfinder over the hex grid of a single `HexWorld`.
## Wraps Godot's `AStar3D`. Points are added lazily as chunks load and
## removed when chunks unload. Mining / placement edits incrementally
## update the affected columns.
##
## Walkable rule (matches `HexWorld._column_is_safe`):
##   * `coord` cell is air (no base), AND
##   * cell at `coord - layer_unit` exists with a base, AND
##   * that floor cell carries no `OverlayKind.blocks_movement` overlay.
##
## Neighbor connections are made to the 6 axial neighbors at the
## same layer plus the 6 axial neighbors at ±1 layer (so creatures can
## walk up small slopes and step down into 1-layer pits).
##
## All public methods accept `Vector3i(q, r, layer)` coords matching
## `HexWorld.world_to_coord`.

const _OFFSET: int = 32768  # so q/r/layer in [-32768, 32767] pack uniquely


var hex_world: HexWorld
var astar: AStar3D
## Coords (Vector3i) that have been registered as walkable AStar points.
var _walkable: Dictionary = {}  # Vector3i -> int (point id)


func _init(world: HexWorld) -> void:
	hex_world = world
	astar = AStar3D.new()
	if hex_world == null:
		return
	hex_world.chunk_loaded.connect(_on_chunk_loaded)
	hex_world.chunk_unloaded.connect(_on_chunk_unloaded)
	hex_world.cell_mined.connect(_on_cell_changed)
	hex_world.cell_placed.connect(_on_cell_changed)
	# Seed any chunks that were already loaded before us.
	for cp_v: Variant in hex_world._chunks.keys():
		_on_chunk_loaded(cp_v as Vector3i)


# --- public API ----------------------------------------------------------

## Returns true if `coord` is currently a walkable air-above-floor cell.
func is_walkable(coord: Vector3i) -> bool:
	if hex_world == null or hex_world.palette == null:
		return false
	if hex_world.get_cell(coord) != null:
		return false
	var below: HexCell = hex_world.get_cell(Vector3i(coord.x, coord.y, coord.z - 1))
	if below == null:
		return false
	if below.has_overlay():
		var ok: OverlayKind = hex_world.palette.overlays[below.overlay_id]
		if ok != null and ok.blocks_movement:
			return false
	return true


## Compute a hex path from `from` to `to`. Both must be (or snap to) a
## known walkable point. Returns an empty array if no path exists.
## Path includes the start coord and the goal coord.
func find_path(from: Vector3i, to: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	if astar.get_point_count() == 0:
		return result
	var from_id: int = _nearest_known_id(from)
	var to_id: int = _nearest_known_id(to)
	if from_id == -1 or to_id == -1:
		return result
	var ids: PackedInt64Array = astar.get_id_path(from_id, to_id, true)
	for id: int in ids:
		result.append(_id_to_coord(id))
	return result


## Pick a random walkable coord within `radius` axial hexes of `center`,
## scanning ±2 layers vertically. Returns `center` if nothing else is
## found (caller can detect by equality).
func get_random_walkable_near(center: Vector3i, radius: int, rng: RandomNumberGenerator = null) -> Vector3i:
	var candidates: Array[Vector3i] = []
	for dq: int in range(-radius, radius + 1):
		for dr: int in range(-radius, radius + 1):
			if HexGrid.axial_distance(Vector2i.ZERO, Vector2i(dq, dr)) > radius:
				continue
			for dz: int in range(-2, 3):
				var c: Vector3i = Vector3i(center.x + dq, center.y + dr, center.z + dz)
				if _walkable.has(c):
					candidates.append(c)
	if candidates.is_empty():
		return center
	var r: RandomNumberGenerator = rng if rng != null else _rng
	var idx: int = r.randi_range(0, candidates.size() - 1)
	return candidates[idx]


## Number of registered walkable points. Useful for diagnostics + tests.
func walkable_count() -> int:
	return _walkable.size()


# --- chunk events --------------------------------------------------------

func _on_chunk_loaded(chunk_pos: Vector3i) -> void:
	var chunk: HexWorldChunk = hex_world.get_chunk(chunk_pos)
	if chunk == null:
		return
	# Walk every solid cell in the chunk and register the air column
	# directly above as walkable. This naturally captures surface tops
	# without scanning the (mostly empty) air space.
	var size_qr: int = hex_world.chunk_size_qr
	var size_layer: int = hex_world.chunk_size_layer
	var added: Array[Vector3i] = []
	for local_v: Variant in chunk.cells.keys():
		var local: Vector3i = local_v as Vector3i
		var coord: Vector3i = ChunkMath.local_to_cell(local, chunk_pos, size_qr, size_layer)
		var stand: Vector3i = Vector3i(coord.x, coord.y, coord.z + 1)
		if is_walkable(stand) and not _walkable.has(stand):
			_add_point(stand)
			added.append(stand)
	# Connect newly added points to any existing neighbors.
	for c: Vector3i in added:
		_connect_neighbors(c)


func _on_chunk_unloaded(chunk_pos: Vector3i) -> void:
	# Remove any walkable points whose floor or own coord lives in the
	# unloaded chunk.
	var size_qr: int = hex_world.chunk_size_qr
	var size_layer: int = hex_world.chunk_size_layer
	var to_remove: Array[Vector3i] = []
	for c_v: Variant in _walkable.keys():
		var c: Vector3i = c_v as Vector3i
		var own_chunk: Vector3i = ChunkMath.cell_to_chunk(c, size_qr, size_layer)
		var floor_chunk: Vector3i = ChunkMath.cell_to_chunk(
			Vector3i(c.x, c.y, c.z - 1), size_qr, size_layer
		)
		if own_chunk == chunk_pos or floor_chunk == chunk_pos:
			to_remove.append(c)
	for c: Vector3i in to_remove:
		_remove_point(c)


func _on_cell_changed(coord: Vector3i, _a: int = 0, _b: int = 0, _c: bool = false) -> void:
	# Re-evaluate the cell itself and its immediate vertical neighbors:
	# mining the floor below a walkable point invalidates that point;
	# mining the cell at a walkable point may now expose air above.
	var to_check: Array[Vector3i] = [
		coord,
		Vector3i(coord.x, coord.y, coord.z + 1),
		Vector3i(coord.x, coord.y, coord.z - 1),
	]
	# Also re-check neighbors at ±1 layer because slopes may have changed.
	for dir: Vector2i in HexGrid.AXIAL_DIRECTIONS:
		var nq: int = coord.x + dir.x
		var nr: int = coord.y + dir.y
		to_check.append(Vector3i(nq, nr, coord.z))
		to_check.append(Vector3i(nq, nr, coord.z + 1))
	for c: Vector3i in to_check:
		_refresh_point(c)


# --- internal graph maintenance ------------------------------------------

func _refresh_point(coord: Vector3i) -> void:
	var should_be: bool = is_walkable(coord)
	var has_now: bool = _walkable.has(coord)
	if should_be and not has_now:
		_add_point(coord)
		_connect_neighbors(coord)
	elif has_now and not should_be:
		_remove_point(coord)


func _add_point(coord: Vector3i) -> void:
	var id: int = _coord_to_id(coord)
	# Use cell center world position for AStar Euclidean fallback heuristic.
	astar.add_point(id, hex_world.coord_to_world(coord))
	_walkable[coord] = id


func _remove_point(coord: Vector3i) -> void:
	if not _walkable.has(coord):
		return
	var id: int = _walkable[coord]
	if astar.has_point(id):
		astar.remove_point(id)
	_walkable.erase(coord)


func _connect_neighbors(coord: Vector3i) -> void:
	if not _walkable.has(coord):
		return
	var from_id: int = _walkable[coord]
	for dir: Vector2i in HexGrid.AXIAL_DIRECTIONS:
		var nq: int = coord.x + dir.x
		var nr: int = coord.y + dir.y
		# Connect at ±0 and ±1 layer — creatures can step up/down 1 layer.
		for dz: int in [0, 1, -1]:
			var n: Vector3i = Vector3i(nq, nr, coord.z + dz)
			if _walkable.has(n):
				var to_id: int = _walkable[n]
				if not astar.are_points_connected(from_id, to_id):
					astar.connect_points(from_id, to_id, true)


func _nearest_known_id(coord: Vector3i) -> int:
	if _walkable.has(coord):
		return _walkable[coord]
	# Fall back to AStar's spatial nearest (uses point world positions).
	if astar.get_point_count() == 0:
		return -1
	var pos: Vector3 = hex_world.coord_to_world(coord)
	return astar.get_closest_point(pos)


# --- coord/id packing ----------------------------------------------------
#
# Pack Vector3i(q, r, layer) where each component is in
# [-_OFFSET, _OFFSET-1] into a single int via three 16-bit lanes.
# Godot ints are 64-bit so this never overflows for any reasonable map.

func _coord_to_id(coord: Vector3i) -> int:
	var q: int = coord.x + _OFFSET
	var r: int = coord.y + _OFFSET
	var l: int = coord.z + _OFFSET
	return (q << 32) | (r << 16) | l


func _id_to_coord(id: int) -> Vector3i:
	var l: int = (id & 0xFFFF) - _OFFSET
	var r: int = ((id >> 16) & 0xFFFF) - _OFFSET
	var q: int = ((id >> 32) & 0xFFFF) - _OFFSET
	return Vector3i(q, r, l)


# Per-pathfinder RNG so multiple pathfinders don't share state.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
