class_name HexWorld
extends Node3D

## One hex world instance. Drives chunk streaming, rendering, and the
## mining/placement API. The overworld and the mine are each a
## `HexWorld` instance with a different generator + palette + render
## layer bit.
##
## Chunk key is `Vector3i(chunk_q, chunk_r, chunk_layer)`.

signal cell_mined(coord: Vector3i, base_id: int, overlay_id: int, dropped_base: bool)
signal cell_placed(coord: Vector3i)
signal chunk_loaded(chunk_pos: Vector3i)
signal chunk_unloaded(chunk_pos: Vector3i)

## Hex cells per chunk along q and r axes.
@export var chunk_size_qr: int = 16
## Hex layers per chunk along the y axis.
@export var chunk_size_layer: int = 4
## How many chunks out from each player (q/r) to keep loaded.
@export var load_radius_qr: int = 3
## How many chunks up/down from each player's current layer to keep loaded.
@export var load_radius_layer: int = 2
## Chunks outside this radius (from all players) are unloaded.
@export var unload_radius_qr: int = 5
@export var unload_radius_layer: int = 3
## Max chunks built per frame (throttle to avoid hitches).
@export var max_chunks_per_frame: int = 2
## Max chunks built per frame when draining a `prime_around` request.
## Higher than max_chunks_per_frame so teleport/setup priming finishes
## quickly, but still bounded so a 50-chunk prime doesn't freeze a frame.
@export var max_priming_chunks_per_frame: int = 6
## Streaming tick interval.
@export var chunk_update_interval: float = 0.25
## `VisualInstance3D.layers` bitmask for every MMI in this world.
@export var render_layer_bit: int = 2
## Physics collision layer assigned to each chunk body.
@export var collision_layer: int = 2

var palette: TilePalette
var generator: HexWorldGenerator

var _chunks: Dictionary = {}       # Vector3i chunk_pos -> HexWorldChunk
var _load_queue: Array[Vector3i] = []
var _pending_chunks: Dictionary = {}  # Vector3i -> true (in-queue or loaded)
var _cell_damage: Dictionary = {}  # Vector3i coord -> float

## Coords of cells that have been edited this frame and need their
## owning chunk's visuals + collision rebuilt. Drained in `_process`.
var _dirty_chunks: Dictionary = {}  # Vector3i chunk_pos -> true

## Marker -> Set[Vector3i] cache so `find_all_markers` is O(1) instead
## of O(loaded_chunks * cells_per_chunk). Maintained on cell edits.
var _markers: Dictionary = {}  # StringName -> Dictionary[Vector3i,true]

var _active_players: Array[Node3D] = []
var _update_timer: float = 0.0


func setup(world_palette: TilePalette, world_generator: HexWorldGenerator) -> void:
	palette = world_palette
	generator = world_generator


## Register players whose positions drive chunk streaming in this world.
## Typically called when a player enters this world (overworld / mine).
func set_active_players(players: Array[Node3D]) -> void:
	_active_players = players


## Update the global overlay scale multiplier (trees, rocks, ores) and
## rebuild visuals on all loaded chunks so the change shows immediately.
## This is a global static — calling on one `HexWorld` affects all worlds.
func set_overlay_scale(new_scale: float) -> void:
	HexWorldChunk.overlay_scale_multiplier = new_scale
	for cp_v: Variant in _chunks.keys():
		var chunk: HexWorldChunk = _chunks[cp_v] as HexWorldChunk
		if is_instance_valid(chunk):
			chunk.rebuild_visuals()


func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= chunk_update_interval:
		_update_timer = 0.0
		_update_streaming()
	_drain_load_queue()
	_flush_dirty_chunks()


# --- streaming -----------------------------------------------------------

func _update_streaming() -> void:
	if palette == null or generator == null:
		return
	# Cache each active player's chunk center once.
	var centers: Array[Vector3i] = []
	for player: Node3D in _active_players:
		if is_instance_valid(player):
			centers.append(_chunk_at_world(player.global_position))

	# Build the wanted set + enqueue missing chunks in a single pass.
	# (We don't keep `wanted` for the unload pass; instead the unload
	# pass distance-checks each loaded chunk directly against centers.)
	for center: Vector3i in centers:
		for dz: int in range(-load_radius_layer, load_radius_layer + 1):
			for dq: int in range(-load_radius_qr, load_radius_qr + 1):
				for dr: int in range(-load_radius_qr, load_radius_qr + 1):
					var cp: Vector3i = Vector3i(center.x + dq, center.y + dr, center.z + dz)
					if not _chunks.has(cp) and not _pending_chunks.has(cp):
						_load_queue.append(cp)
						_pending_chunks[cp] = true

	# Unload chunks beyond the unload radius. Iterate _chunks once,
	# distance-check directly against centers (faster than building
	# a "wanted" dict).
	if centers.is_empty():
		return  # No active players — keep everything loaded.
	var to_unload: Array[Vector3i] = []
	for cp_v: Variant in _chunks.keys():
		var cp: Vector3i = cp_v as Vector3i
		var keep: bool = false
		for center: Vector3i in centers:
			if absi(cp.x - center.x) <= unload_radius_qr \
				and absi(cp.y - center.y) <= unload_radius_qr \
				and absi(cp.z - center.z) <= unload_radius_layer:
				keep = true
				break
		if not keep:
			to_unload.append(cp)
	for cp: Vector3i in to_unload:
		_unload_chunk(cp)


func _drain_load_queue() -> void:
	var built: int = 0
	while not _load_queue.is_empty() and built < max_chunks_per_frame:
		var cp: Vector3i = _load_queue.pop_front()
		if not _chunks.has(cp):
			_load_chunk(cp)
		built += 1


## Drain dirty chunks once per frame, coalescing many edits into one
## rebuild per chunk. Drastically reduces hitches when batch-placing
## roads, batch-mining, or generating chunks that emit many cells.
func _flush_dirty_chunks() -> void:
	if _dirty_chunks.is_empty():
		return
	var snapshot: Array = _dirty_chunks.keys()
	_dirty_chunks.clear()
	for cp_v: Variant in snapshot:
		var chunk: HexWorldChunk = _chunks.get(cp_v) as HexWorldChunk
		if chunk != null and is_instance_valid(chunk):
			chunk.flush_rebuild()


## Force a single chunk to rebuild now (skip the per-frame defer).
## Used by `mine_cell` / `place_*` callers that want immediate feedback.
func flush_chunk_now(coord: Vector3i) -> void:
	var cp: Vector3i = ChunkMath.cell_to_chunk(coord, chunk_size_qr, chunk_size_layer)
	_dirty_chunks.erase(cp)
	var chunk: HexWorldChunk = _chunks.get(cp) as HexWorldChunk
	if chunk != null and is_instance_valid(chunk):
		chunk.flush_rebuild()


## Force-load every chunk within `load_radius_* (+ extras)` of
## `world_pos` right now. Use before teleporting a player into this
## world so they don't fall through ungenerated air.
##
## **Synchronous** by default (back-compat with existing callers that
## need ground under the player on the next frame). Pass `async=true`
## to enqueue instead — the chunks will load over the next few frames
## via the normal `_drain_load_queue` budget. Async priming is a big
## win when a caller doesn't actually need the ground immediately
## (e.g. workbench placement at startup).
func prime_around(world_pos: Vector3,
		extra_radius_qr: int = 0,
		extra_radius_layer: int = 0,
		async: bool = false) -> void:
	if palette == null or generator == null:
		return
	var center: Vector3i = _chunk_at_world(world_pos)
	var rqr: int = load_radius_qr + max(0, extra_radius_qr)
	var rlayer: int = load_radius_layer + max(0, extra_radius_layer)
	for dz: int in range(-rlayer, rlayer + 1):
		for dq: int in range(-rqr, rqr + 1):
			for dr: int in range(-rqr, rqr + 1):
				var cp: Vector3i = Vector3i(center.x + dq, center.y + dr, center.z + dz)
				if _chunks.has(cp):
					continue
				if async:
					if not _pending_chunks.has(cp):
						_load_queue.push_front(cp)  # priority over streaming
						_pending_chunks[cp] = true
				else:
					if not _chunks.has(cp):
						_load_chunk(cp)
						_pending_chunks[cp] = true


func _load_chunk(cp: Vector3i) -> void:
	var chunk: HexWorldChunk = HexWorldChunk.new(
		cp, chunk_size_qr, chunk_size_layer, render_layer_bit, palette
	)
	add_child(chunk)
	chunk.apply_collision_layer(collision_layer)
	# Generate content into the chunk.
	generator.generate_chunk(cp, chunk, palette)
	# Index any markers placed during generation.
	_index_chunk_markers(cp, chunk)
	# Initial build is synchronous — chunk is freshly born, callers
	# expect it usable on next frame.
	chunk.rebuild()
	_chunks[cp] = chunk
	chunk_loaded.emit(cp)


func _unload_chunk(cp: Vector3i) -> void:
	if not _chunks.has(cp):
		return
	var chunk: HexWorldChunk = _chunks[cp] as HexWorldChunk
	_chunks.erase(cp)
	_pending_chunks.erase(cp)
	_dirty_chunks.erase(cp)
	_unindex_chunk_markers(cp, chunk)
	if is_instance_valid(chunk):
		chunk.queue_free()
	chunk_unloaded.emit(cp)


# --- coordinate helpers --------------------------------------------------

func _chunk_at_world(world_pos: Vector3) -> Vector3i:
	var qr: Vector2i = HexGrid.world_to_axial(world_pos)
	var layer: int = floori(world_pos.y / HexWorldChunk.LAYER_HEIGHT)
	return ChunkMath.cell_to_chunk(
		Vector3i(qr.x, qr.y, layer), chunk_size_qr, chunk_size_layer
	)


## World position → hex cell coord. Y becomes the integer layer.
func world_to_coord(world_pos: Vector3) -> Vector3i:
	var qr: Vector2i = HexGrid.world_to_axial(world_pos)
	var layer: int = floori(world_pos.y / HexWorldChunk.LAYER_HEIGHT)
	return Vector3i(qr.x, qr.y, layer)


## Hex cell coord → world center position.
func coord_to_world(coord: Vector3i) -> Vector3:
	var xz: Vector3 = HexGrid.axial_to_world(coord.x, coord.y)
	return Vector3(xz.x, float(coord.z) * HexWorldChunk.LAYER_HEIGHT, xz.z)


## Find a nearby hex column (within `max_radius` axial rings of
## `preferred`) where a player body can safely stand:
##   - the target cell is air (nothing solid to be inside of), AND
##   - the cell directly below exists and does not carry a blocking
##     overlay (markers, trees, hills, boulders).
## For each candidate column we also walk downward up to
## `max_layer_scan` layers from `preferred.z` to handle callers who
## pass a preferred point high above the surface.
## Returns the world position just above the floor. Callers should
## `prime_around(preferred_world)` first so the relevant chunks are
## loaded — otherwise the search sees only air and picks the preferred
## column as-is.
func find_safe_spawn(preferred: Vector3i, max_radius: int = 4, max_layer_scan: int = 12) -> Vector3:
	var offsets: Array[Vector2i] = [Vector2i(0, 0)]
	for radius: int in range(1, max_radius + 1):
		for dq: int in range(-radius, radius + 1):
			for dr: int in range(-radius, radius + 1):
				var off: Vector2i = Vector2i(dq, dr)
				if HexGrid.axial_distance(Vector2i(0, 0), off) == radius:
					offsets.append(off)
	for off: Vector2i in offsets:
		# For each (q,r) column, walk downward from preferred.z looking
		# for the topmost safe standing layer.
		for dz: int in range(0, -max_layer_scan - 1, -1):
			var col: Vector3i = Vector3i(
				preferred.x + off.x, preferred.y + off.y, preferred.z + dz
			)
			if _column_is_safe(col):
				return _column_stand_position(col)
	return _column_stand_position(preferred)


## Convenience: `find_safe_spawn` using a world-space preferred point.
## Primes chunks around that point first so newly-streamed content is
## considered by the search.
func find_safe_spawn_world(preferred_world: Vector3, max_radius: int = 4) -> Vector3:
	prime_around(preferred_world)
	return find_safe_spawn(world_to_coord(preferred_world), max_radius)


func _column_is_safe(coord: Vector3i) -> bool:
	if palette == null:
		return false
	# The standing cell must be empty (no solid base to be trapped in).
	if get_cell(coord) != null:
		return false
	# The cell below must exist (floor) and not carry a blocking overlay
	# (those extend vertically past the player's feet).
	var below: HexCell = get_cell(Vector3i(coord.x, coord.y, coord.z - 1))
	if below == null:
		return false
	if below.has_overlay():
		var ok: OverlayKind = palette.overlays[below.overlay_id]
		if ok != null and ok.blocks_movement:
			return false
	return true


func _column_stand_position(coord: Vector3i) -> Vector3:
	var wp: Vector3 = coord_to_world(coord)
	return Vector3(wp.x, float(coord.z) * HexWorldChunk.LAYER_HEIGHT + 0.05, wp.z)


func _chunk_for_coord(coord: Vector3i) -> HexWorldChunk:
	var cp: Vector3i = ChunkMath.cell_to_chunk(coord, chunk_size_qr, chunk_size_layer)
	return _chunks.get(cp) as HexWorldChunk


# --- cell access ---------------------------------------------------------

func get_cell(coord: Vector3i) -> HexCell:
	var chunk: HexWorldChunk = _chunk_for_coord(coord)
	if chunk == null:
		return null
	var local: Vector3i = ChunkMath.cell_to_local(
		coord, chunk.chunk_pos, chunk_size_qr, chunk_size_layer
	)
	return chunk.get_cell_local(local)


func has_cell(coord: Vector3i) -> bool:
	return get_cell(coord) != null


## Search for a cell with a marker overlay within axial distance 1
## (same layer and ±1 layer) of `coord`. Pass an empty marker
## (`&""`) to match any marker; otherwise only overlays whose
## `OverlayKind.marker == marker` are returned. Returns the matching
## coord, or `NO_COORD` if no match was found.
const NO_COORD: Vector3i = Vector3i(-99999, -99999, -99999)

func find_nearby_marker(coord: Vector3i, marker: StringName = &"") -> Vector3i:
	if palette == null:
		return NO_COORD
	# Fast path: when a specific marker is requested, scan only the
	# cached coord set for that marker (typically <10 entries world-wide).
	if marker != &"":
		var coords_v: Variant = _markers.get(marker)
		if coords_v == null:
			return NO_COORD
		var coords: Dictionary = coords_v
		for c_v: Variant in coords.keys():
			var c: Vector3i = c_v as Vector3i
			if absi(c.z - coord.z) > 1:
				continue
			if HexGrid.axial_distance(Vector2i(c.x, c.y), Vector2i(coord.x, coord.y)) <= 1:
				return c
		return NO_COORD
	# Slow path: any marker — fall through to the original neighborhood scan.
	for dy: int in [0, -1, 1]:
		for dq: int in range(-1, 2):
			for dr: int in range(-1, 2):
				if HexGrid.axial_distance(Vector2i(0, 0), Vector2i(dq, dr)) > 1:
					continue
				var c: Vector3i = Vector3i(coord.x + dq, coord.y + dr, coord.z + dy)
				var cell: HexCell = get_cell(c)
				if cell == null or not cell.has_overlay():
					continue
				if cell.overlay_id < 0 or cell.overlay_id >= palette.overlays.size():
					continue
				var ok: OverlayKind = palette.overlays[cell.overlay_id]
				if ok == null:
					continue
				if ok.marker != &"":
					return c
	return NO_COORD


## Replace or insert a cell at `coord`. Defers chunk rebuild to the
## end-of-frame flush so multiple edits coalesce.
func set_cell(coord: Vector3i, cell: HexCell) -> void:
	var chunk: HexWorldChunk = _chunk_for_coord(coord)
	if chunk == null:
		return
	var local: Vector3i = ChunkMath.cell_to_local(
		coord, chunk.chunk_pos, chunk_size_qr, chunk_size_layer)
	# Update marker index based on the OLD vs NEW cell at this coord
	# so we don't leak stale entries when a marker is mined or replaced.
	var old: HexCell = chunk.get_cell_local(local)
	_unindex_cell_marker(coord, old)
	cell.q = coord.x
	cell.r = coord.y
	cell.layer = coord.z
	chunk.set_cell_local(local, cell)
	_index_cell_marker(coord, cell)
	_dirty_chunks[chunk.chunk_pos] = true


func remove_cell(coord: Vector3i) -> void:
	var chunk: HexWorldChunk = _chunk_for_coord(coord)
	if chunk == null:
		return
	var local: Vector3i = ChunkMath.cell_to_local(
		coord, chunk.chunk_pos, chunk_size_qr, chunk_size_layer
	)
	var old: HexCell = chunk.get_cell_local(local)
	_unindex_cell_marker(coord, old)
	chunk.clear_cell_local(local)
	_dirty_chunks[chunk.chunk_pos] = true


# --- marker index --------------------------------------------------------
#
# Maintains `_markers: StringName -> Set[Vector3i]` so `find_all_markers`
# and the fast path of `find_nearby_marker` can answer in O(matches)
# instead of scanning every cell of every loaded chunk.

func _index_cell_marker(coord: Vector3i, cell: HexCell) -> void:
	if cell == null or palette == null or not cell.has_overlay():
		return
	if cell.overlay_id < 0 or cell.overlay_id >= palette.overlays.size():
		return
	var ok: OverlayKind = palette.overlays[cell.overlay_id]
	if ok == null or ok.marker == &"":
		return
	var bucket_v: Variant = _markers.get(ok.marker)
	var bucket: Dictionary
	if bucket_v == null:
		bucket = {}
		_markers[ok.marker] = bucket
	else:
		bucket = bucket_v
	bucket[coord] = true


func _unindex_cell_marker(coord: Vector3i, cell: HexCell) -> void:
	if cell == null or palette == null or not cell.has_overlay():
		return
	if cell.overlay_id < 0 or cell.overlay_id >= palette.overlays.size():
		return
	var ok: OverlayKind = palette.overlays[cell.overlay_id]
	if ok == null or ok.marker == &"":
		return
	var bucket_v: Variant = _markers.get(ok.marker)
	if bucket_v != null:
		(bucket_v as Dictionary).erase(coord)


func _index_chunk_markers(cp: Vector3i, chunk: HexWorldChunk) -> void:
	if chunk == null or palette == null:
		return
	# Fast path: no markers exist in any palette overlay -> skip entirely.
	if not _palette_has_any_marker():
		return
	for local_v: Variant in chunk.cells:
		var cell: HexCell = chunk.cells[local_v] as HexCell
		if cell == null or not cell.has_overlay():
			continue
		var coord: Vector3i = ChunkMath.local_to_cell(
			local_v as Vector3i, cp, chunk_size_qr, chunk_size_layer)
		_index_cell_marker(coord, cell)


func _unindex_chunk_markers(cp: Vector3i, chunk: HexWorldChunk) -> void:
	if chunk == null or palette == null:
		return
	if not _palette_has_any_marker():
		return
	for local_v: Variant in chunk.cells:
		var cell: HexCell = chunk.cells[local_v] as HexCell
		if cell == null or not cell.has_overlay():
			continue
		var coord: Vector3i = ChunkMath.local_to_cell(
			local_v as Vector3i, cp, chunk_size_qr, chunk_size_layer)
		_unindex_cell_marker(coord, cell)


# Cached `palette has any marker?` answer.
var _palette_has_marker_cached: int = -1  # -1 = unknown, 0 = false, 1 = true
func _palette_has_any_marker() -> bool:
	if _palette_has_marker_cached != -1:
		return _palette_has_marker_cached == 1
	var any: bool = false
	if palette != null:
		for ok: OverlayKind in palette.overlays:
			if ok != null and ok.marker != &"":
				any = true
				break
	_palette_has_marker_cached = 1 if any else 0
	return any


# --- damage / mining -----------------------------------------------------

func get_damage(coord: Vector3i) -> float:
	return _cell_damage.get(coord, 0.0)


func set_damage(coord: Vector3i, amount: float) -> void:
	if amount <= 0.0:
		_cell_damage.erase(coord)
	else:
		_cell_damage[coord] = amount


## Result bundle for `mine_cell`.
class MineResult:
	extends RefCounted
	var changed: bool = false
	var dropped_base: bool = false
	var base_id: int = -1
	var overlay_id: int = -1
	var drops: PackedStringArray = PackedStringArray()


## Single-step mining: strips overlay first, then base (which removes
## the cell entirely, exposing the layer below). Returns a `MineResult`
## so callers can emit VFX / inventory drops.
func mine_cell(coord: Vector3i) -> MineResult:
	var result: MineResult = MineResult.new()
	var cell: HexCell = get_cell(coord)
	if cell == null:
		return result
	_cell_damage.erase(coord)
	if cell.has_overlay():
		var ok: OverlayKind = palette.overlays[cell.overlay_id]
		# Interactable overlays (mine entrance, ladder_up, etc.) cannot
		# be mined — they are removed only by their own gameplay system.
		if ok != null and not ok.marker.is_empty():
			return result
		result.changed = true
		result.overlay_id = cell.overlay_id
		result.base_id = cell.base_id
		result.drops = ok.drops if ok != null else PackedStringArray()
		cell.overlay_id = -1
		set_cell(coord, cell)
		# Mining wants instant visual + collision feedback so the next
		# swing is on the new top surface.
		flush_chunk_now(coord)
		cell_mined.emit(coord, result.base_id, result.overlay_id, false)
		return result
	# No overlay → remove the cell entirely.
	var tk: TileKind = palette.bases[cell.base_id] if cell.base_id >= 0 and cell.base_id < palette.bases.size() else null
	if tk != null and tk.unbreakable:
		return result
	result.changed = true
	result.dropped_base = true
	result.base_id = cell.base_id
	result.overlay_id = -1
	result.drops = tk.drops if tk != null else PackedStringArray()
	remove_cell(coord)
	flush_chunk_now(coord)
	cell_mined.emit(coord, result.base_id, -1, true)
	return result


## Hardness remaining on the cell's current top layer (overlay if any,
## else base).
func cell_hardness(coord: Vector3i) -> float:
	var cell: HexCell = get_cell(coord)
	if cell == null:
		return 0.0
	if cell.has_overlay():
		var ok: OverlayKind = palette.overlays[cell.overlay_id]
		return ok.hardness if ok != null else 0.0
	var tk: TileKind = palette.bases[cell.base_id] if cell.base_id >= 0 and cell.base_id < palette.bases.size() else null
	return tk.hardness if tk != null else 0.0


# --- placement -----------------------------------------------------------

## Place a base tile at `coord`. Fails if a cell already exists there.
func place_base(coord: Vector3i, base_id: int) -> bool:
	if has_cell(coord):
		return false
	var cell: HexCell = HexCell.new(coord.x, coord.y, coord.z, base_id, -1)
	set_cell(coord, cell)
	cell_placed.emit(coord)
	return true


## Place an overlay on an existing cell. Fails if no cell or if the
## cell already has an overlay or base disallows this overlay.
func place_overlay(coord: Vector3i, overlay_id: int) -> bool:
	var cell: HexCell = get_cell(coord)
	if cell == null or cell.has_overlay():
		return false
	if overlay_id < 0 or overlay_id >= palette.overlays.size():
		return false
	var ok: OverlayKind = palette.overlays[overlay_id]
	if ok == null:
		return false
	var tk: TileKind = palette.bases[cell.base_id] if cell.base_id >= 0 and cell.base_id < palette.bases.size() else null
	if tk != null and not ok.allowed_on_base(tk.id):
		return false
	cell.overlay_id = overlay_id
	set_cell(coord, cell)
	cell_placed.emit(coord)
	return true


## Place an overlay with a specific Y-rotation (0–5, 60° steps).
## Thin wrapper over `place_overlay()` that also sets `cell.rotation`.
func place_overlay_rotated(coord: Vector3i, overlay_id: int, rot: int) -> bool:
	if not place_overlay(coord, overlay_id):
		return false
	var cell: HexCell = get_cell(coord)
	if cell != null:
		cell.rotation = rot % 6
		set_cell(coord, cell)
	return true


## Replace an existing overlay (and rotation) in-place. Does NOT check
## `allowed_on_base` — caller is trusted (used by `HexRoadPlacer` to
## swap road shapes). Returns false if the cell has no overlay.
func swap_overlay(coord: Vector3i, new_overlay_id: int, new_rotation: int) -> void:
	var cell: HexCell = get_cell(coord)
	if cell == null:
		return
	cell.overlay_id = new_overlay_id
	cell.rotation = new_rotation % 6
	set_cell(coord, cell)


## Scan all loaded chunks and return every coord whose cell carries
## an overlay with the given `marker`. Returns an empty array when
## nothing matches. O(matches) thanks to the marker index.
func find_all_markers(marker: StringName) -> Array[Vector3i]:
	var results: Array[Vector3i] = []
	var bucket_v: Variant = _markers.get(marker)
	if bucket_v == null:
		return results
	var bucket: Dictionary = bucket_v
	for c_v: Variant in bucket.keys():
		results.append(c_v as Vector3i)
	return results


# --- lookups -------------------------------------------------------------

func get_chunk(chunk_pos: Vector3i) -> HexWorldChunk:
	return _chunks.get(chunk_pos) as HexWorldChunk


func chunk_count() -> int:
	return _chunks.size()


## Search for the first cell at or below `start_coord` that has the given overlay marker.
## Useful for "find the ladder in the spawn chamber".
func find_overlay_by_marker_near(start_coord: Vector3i, marker: StringName, radius: int = 8) -> Vector3i:
	var ok_idx: int = palette.overlay_index_by_marker(marker)
	if ok_idx < 0:
		return Vector3i.ZERO
	for dq: int in range(-radius, radius + 1):
		for dr: int in range(-radius, radius + 1):
			for dl: int in range(-radius, radius + 1):
				var c: Vector3i = start_coord + Vector3i(dq, dr, dl)
				var cell: HexCell = get_cell(c)
				if cell != null and cell.overlay_id == ok_idx:
					return c
	return start_coord
