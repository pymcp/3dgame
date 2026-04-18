class_name HexPathfinder
extends RefCounted

## A* pathfinder over the hex grid of a single `HexWorld`.
## Wraps Godot's `AStar3D`. Points are added lazily as chunks load and
## removed when chunks unload. Mining / placement edits incrementally
## update the affected columns.
##
## **Deferred updates**: chunk-loaded events queue cells for processing
## rather than registering thousands of points synchronously inside one
## frame. Cell-changed events are coalesced too. Call `process_pending`
## from the owning system (a `Node` ticking each frame) with a budget
## to drain the work over multiple frames. This eliminates the multi-
## hundred-ms hitch on mine entry / fast travel.
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

## Default per-frame budget for `process_pending`. Bumped fairly high
## because each unit of work is just an add_point + connect_points,
## but kept bounded so chunk floods don't cause hitches.
const DEFAULT_BUDGET_PER_FRAME: int = 256


var hex_world: HexWorld
var astar: AStar3D
## Coords (Vector3i) that have been registered as walkable AStar points.
var _walkable: Dictionary = {}  # Vector3i -> int (point id)

# --- deferred work queues ------------------------------------------------
#
# When chunks load we defer the per-cell scan; when cells are mined or
# placed we defer the per-coord refresh. `process_pending` (called by
# `CreatureSpawner._process` once per frame) drains these.
var _pending_chunks: Array[Vector3i] = []   # chunks we still need to scan
var _pending_chunks_set: Dictionary = {}    # dedup
var _pending_refresh: Dictionary = {}       # Vector3i coord -> true


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
	# Resolve both cells through the same chunk when possible — the
	# standing cell (coord) and the floor cell (coord - layer_unit)
	# share the same (q, r) column, so they live in the same chunk
	# unless `coord.z` straddles a chunk boundary.
	var size_qr: int = hex_world.chunk_size_qr
	var size_layer: int = hex_world.chunk_size_layer
	var stand_cp: Vector3i = ChunkMath.cell_to_chunk(coord, size_qr, size_layer)
	var stand_chunk: HexWorldChunk = hex_world._chunks.get(stand_cp) as HexWorldChunk
	if stand_chunk == null:
		return false
	# The standing cell must be empty (no solid base to be trapped in).
	if stand_chunk.get_cell_local(
			ChunkMath.cell_to_local(coord, stand_cp, size_qr, size_layer)) != null:
		return false
	# The cell below must exist (floor) and not carry a blocking overlay.
	var floor_coord: Vector3i = Vector3i(coord.x, coord.y, coord.z - 1)
	var floor_cp: Vector3i = stand_cp
	if (coord.z - 1) < stand_cp.z * size_layer:
		# Crossed a chunk boundary downward — look up the chunk below.
		floor_cp = ChunkMath.cell_to_chunk(floor_coord, size_qr, size_layer)
	var floor_chunk: HexWorldChunk = stand_chunk if floor_cp == stand_cp \
			else hex_world._chunks.get(floor_cp) as HexWorldChunk
	if floor_chunk == null:
		return false
	var below: HexCell = floor_chunk.get_cell_local(
			ChunkMath.cell_to_local(floor_coord, floor_cp, size_qr, size_layer))
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


## Drain pending chunk scans + cell refreshes up to `budget` units of
## work. Must be called every frame (e.g. from CreatureSpawner._process)
## to keep the graph in sync without large hitches.
##
## Returns the number of "work units" performed (rough proxy for cost):
##   - 1 unit per cell processed during chunk scan
##   - 1 unit per refreshed coord
func process_pending(budget: int = DEFAULT_BUDGET_PER_FRAME) -> int:
	var spent: int = 0
	# 1) refresh changed cells (coalesced from multiple cell-changed events)
	if not _pending_refresh.is_empty():
		var to_clear: Array[Vector3i] = []
		for c_v: Variant in _pending_refresh.keys():
			if spent >= budget:
				break
			var c: Vector3i = c_v as Vector3i
			_refresh_point(c)
			to_clear.append(c)
			spent += 1
		for c: Vector3i in to_clear:
			_pending_refresh.erase(c)
	# 2) drain queued chunk scans (most expensive — each cell is one unit)
	while not _pending_chunks.is_empty() and spent < budget:
		var cp: Vector3i = _pending_chunks[0]
		var consumed: int = _scan_chunk_partial(cp, budget - spent)
		spent += consumed
		# `_scan_chunk_partial` returns -1 when the chunk is complete.
		if consumed < 0:
			_pending_chunks.pop_front()
			_pending_chunks_set.erase(cp)
	return spent


# --- chunk events --------------------------------------------------------

## Per-chunk scan progress: chunk_pos -> next local index to process.
## Lets us split a big chunk's add-points work over multiple frames.
var _scan_progress: Dictionary = {}  # Vector3i -> int
## Per-chunk cached keys snapshot so a multi-frame scan doesn't rebuild
## the keys Array every frame (significant for 1024-cell chunks).
var _scan_keys: Dictionary = {}      # Vector3i -> Array


func _on_chunk_loaded(chunk_pos: Vector3i) -> void:
	if _pending_chunks_set.has(chunk_pos):
		return
	_pending_chunks.append(chunk_pos)
	_pending_chunks_set[chunk_pos] = true
	_scan_progress[chunk_pos] = 0


## Process up to `budget` cells of the chunk's keys. Returns either
## the number of cells consumed (>= 0) if work remains, or `-1` when
## the entire chunk has been scanned + caller should pop it.
func _scan_chunk_partial(chunk_pos: Vector3i, budget: int) -> int:
	var chunk: HexWorldChunk = hex_world.get_chunk(chunk_pos)
	if chunk == null:
		return -1
	var size_qr: int = hex_world.chunk_size_qr
	var size_layer: int = hex_world.chunk_size_layer
	var keys_v: Variant = _scan_keys.get(chunk_pos)
	var keys: Array
	if keys_v == null:
		keys = chunk.cells.keys()
		_scan_keys[chunk_pos] = keys
	else:
		keys = keys_v
	var start: int = _scan_progress.get(chunk_pos, 0)
	var end_excl: int = mini(start + budget, keys.size())
	var added: Array[Vector3i] = []
	for i: int in range(start, end_excl):
		var local: Vector3i = keys[i] as Vector3i
		var coord: Vector3i = ChunkMath.local_to_cell(local, chunk_pos, size_qr, size_layer)
		var stand: Vector3i = Vector3i(coord.x, coord.y, coord.z + 1)
		if is_walkable(stand) and not _walkable.has(stand):
			_add_point(stand)
			added.append(stand)
	# Connect newly added points to existing neighbors (cheap dict checks).
	for c: Vector3i in added:
		_connect_neighbors(c)
	if end_excl >= keys.size():
		_scan_progress.erase(chunk_pos)
		_scan_keys.erase(chunk_pos)
		return -1
	_scan_progress[chunk_pos] = end_excl
	return end_excl - start


func _on_chunk_unloaded(chunk_pos: Vector3i) -> void:
	# Cancel any pending scan for this chunk.
	_pending_chunks_set.erase(chunk_pos)
	_scan_progress.erase(chunk_pos)
	_scan_keys.erase(chunk_pos)
	for i: int in range(_pending_chunks.size() - 1, -1, -1):
		if _pending_chunks[i] == chunk_pos:
			_pending_chunks.remove_at(i)
	# Remove any walkable points whose floor or own coord lives in the
	# unloaded chunk. (This is fast — bounded by the points we own,
	# not by every loaded chunk.)
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
	# Coalesce: stash the affected coords; `process_pending` refreshes
	# them next frame. Multiple mines on the same cluster get collapsed
	# into one refresh per coord.
	_pending_refresh[coord] = true
	_pending_refresh[Vector3i(coord.x, coord.y, coord.z + 1)] = true
	_pending_refresh[Vector3i(coord.x, coord.y, coord.z - 1)] = true
	for dir: Vector2i in HexGrid.AXIAL_DIRECTIONS:
		var nq: int = coord.x + dir.x
		var nr: int = coord.y + dir.y
		_pending_refresh[Vector3i(nq, nr, coord.z)] = true
		_pending_refresh[Vector3i(nq, nr, coord.z + 1)] = true


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
			var to_id_v: Variant = _walkable.get(n)
			if to_id_v != null:
				# `connect_points` is idempotent on bidirectional pairs;
				# skip the `are_points_connected` check (which is itself
				# a hashmap lookup pair).
				astar.connect_points(from_id, to_id_v as int, true)


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
