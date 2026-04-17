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

var _active_players: Array[Node3D] = []
var _update_timer: float = 0.0


func setup(world_palette: TilePalette, world_generator: HexWorldGenerator) -> void:
	palette = world_palette
	generator = world_generator


## Register players whose positions drive chunk streaming in this world.
## Typically called when a player enters this world (overworld / mine).
func set_active_players(players: Array[Node3D]) -> void:
	_active_players = players


func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= chunk_update_interval:
		_update_timer = 0.0
		_update_streaming()
	_drain_load_queue()


# --- streaming -----------------------------------------------------------

func _update_streaming() -> void:
	if palette == null or generator == null:
		return
	var wanted: Dictionary = {}  # Vector3i chunk_pos -> true
	for player: Node3D in _active_players:
		if not is_instance_valid(player):
			continue
		var center: Vector3i = _chunk_at_world(player.global_position)
		for dz: int in range(-load_radius_layer, load_radius_layer + 1):
			for dq: int in range(-load_radius_qr, load_radius_qr + 1):
				for dr: int in range(-load_radius_qr, load_radius_qr + 1):
					wanted[Vector3i(center.x + dq, center.y + dr, center.z + dz)] = true
	# Enqueue missing chunks.
	for cp_v: Variant in wanted.keys():
		var cp: Vector3i = cp_v as Vector3i
		if not _chunks.has(cp) and not _pending_chunks.has(cp):
			_load_queue.append(cp)
			_pending_chunks[cp] = true
	# Unload chunks beyond the unload radius.
	var to_unload: Array[Vector3i] = []
	for cp_v: Variant in _chunks.keys():
		var cp: Vector3i = cp_v as Vector3i
		if _is_outside_unload_radius(cp):
			to_unload.append(cp)
	for cp: Vector3i in to_unload:
		_unload_chunk(cp)


func _is_outside_unload_radius(cp: Vector3i) -> bool:
	for player: Node3D in _active_players:
		if not is_instance_valid(player):
			continue
		var center: Vector3i = _chunk_at_world(player.global_position)
		if absi(cp.x - center.x) <= unload_radius_qr \
			and absi(cp.y - center.y) <= unload_radius_qr \
			and absi(cp.z - center.z) <= unload_radius_layer:
			return false
	return true


func _drain_load_queue() -> void:
	var built: int = 0
	while not _load_queue.is_empty() and built < max_chunks_per_frame:
		var cp: Vector3i = _load_queue.pop_front()
		if not _chunks.has(cp):
			_load_chunk(cp)
		built += 1


## Force-load every chunk within `load_radius_* (+ extras)` of
## `world_pos` right now, bypassing the per-frame throttle. Use before
## teleporting a player into this world so they don't fall through
## ungenerated air, or at startup to hide streaming pop-in.
func prime_around(world_pos: Vector3, extra_radius_qr: int = 0, extra_radius_layer: int = 0) -> void:
	if palette == null or generator == null:
		return
	var center: Vector3i = _chunk_at_world(world_pos)
	var rqr: int = load_radius_qr + max(0, extra_radius_qr)
	var rlayer: int = load_radius_layer + max(0, extra_radius_layer)
	for dz: int in range(-rlayer, rlayer + 1):
		for dq: int in range(-rqr, rqr + 1):
			for dr: int in range(-rqr, rqr + 1):
				var cp: Vector3i = Vector3i(center.x + dq, center.y + dr, center.z + dz)
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
	chunk.rebuild()
	_chunks[cp] = chunk
	chunk_loaded.emit(cp)


func _unload_chunk(cp: Vector3i) -> void:
	if not _chunks.has(cp):
		return
	var chunk: HexWorldChunk = _chunks[cp] as HexWorldChunk
	_chunks.erase(cp)
	_pending_chunks.erase(cp)
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


## Replace or insert a cell at `coord`. The chunk is rebuilt.
func set_cell(coord: Vector3i, cell: HexCell) -> void:
	var chunk: HexWorldChunk = _chunk_for_coord(coord)
	if chunk == null:
		return
	var local: Vector3i = ChunkMath.cell_to_local(
		coord, chunk.chunk_pos, chunk_size_qr, chunk_size_layer
	)
	cell.q = coord.x
	cell.r = coord.y
	cell.layer = coord.z
	chunk.set_cell_local(local, cell)
	chunk.rebuild()


func remove_cell(coord: Vector3i) -> void:
	var chunk: HexWorldChunk = _chunk_for_coord(coord)
	if chunk == null:
		return
	var local: Vector3i = ChunkMath.cell_to_local(
		coord, chunk.chunk_pos, chunk_size_qr, chunk_size_layer
	)
	chunk.clear_cell_local(local)
	chunk.rebuild()


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
