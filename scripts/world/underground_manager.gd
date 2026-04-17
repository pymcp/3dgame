class_name UndergroundManager
extends Node3D

## Manages multi-chunk underground world: loading, unloading, rendering, and occlusion.

signal chunk_loaded(chunk_pos: Vector3i)
signal chunk_unloaded(chunk_pos: Vector3i)


class ChunkData:
	var grid: BlockGrid
	var renderer: UndergroundChunkRenderer

	func _init(g: BlockGrid, r: UndergroundChunkRenderer) -> void:
		grid = g
		renderer = r


@export var load_radius_xz: int = 2
@export var load_radius_y: int = 1
@export var chunk_update_interval: float = 0.5
@export var max_chunks_per_frame: int = 2
@export var occlusion_update_interval: float = 0.1

var generator: UndergroundGenerator
var _chunks: Dictionary = {}  # Vector3i -> ChunkData
var _player_positions: Array[Vector3] = []
var _update_timer: float = 0.0
var _load_queue: Array[Vector3i] = []

# Occlusion hiding: camera->player raywalk
var _hidden_blocks: Dictionary = {}  # Vector3i (world block coords) -> true (global view)
var _hidden_by_chunk: Dictionary = {}  # Vector3i chunk_pos -> Dictionary[Vector3i world_block -> true]
var _occlusion_timer: float = 0.0
var _occlusion_cameras: Array[Camera3D] = []
var _occlusion_players: Array[Node3D] = []


func _ready() -> void:
	# Don't process until players are underground
	set_process(false)


func setup(gen: UndergroundGenerator) -> void:
	generator = gen


func _process(delta: float) -> void:
	# Process queued chunk loads (max per frame)
	var loaded_this_frame: int = 0
	while not _load_queue.is_empty() and loaded_this_frame < max_chunks_per_frame:
		var chunk_pos: Vector3i = _load_queue.pop_front()
		if not _chunks.has(chunk_pos):
			_load_chunk(chunk_pos)
			loaded_this_frame += 1

	# Throttle chunk update checks
	_update_timer += delta
	if _update_timer >= chunk_update_interval:
		_update_timer = 0.0
		_update_loaded_chunks()

	# Throttle occlusion updates
	_occlusion_timer += delta
	if _occlusion_timer >= occlusion_update_interval:
		_occlusion_timer = 0.0
		_update_occlusion()


## Call each frame with positions of underground players
func update_player_positions(positions: Array[Vector3]) -> void:
	_player_positions = positions
	# Enable/disable processing based on whether anyone is underground
	var should_process: bool = not positions.is_empty() or not _load_queue.is_empty()
	if should_process != is_processing():
		set_process(should_process)


## Set occlusion sources (camera + player pairs)
func set_occlusion_sources(cameras: Array[Camera3D], players: Array[Node3D]) -> void:
	_occlusion_cameras = cameras
	_occlusion_players = players


## Get the BlockGrid at a given chunk position (or null)
func get_grid_at(chunk_pos: Vector3i) -> BlockGrid:
	var data: ChunkData = _chunks.get(chunk_pos)
	return data.grid if data else null


## Get the BlockGrid containing a world-space block position
func get_grid_for_world_block(world_block: Vector3i) -> BlockGrid:
	var chunk_pos: Vector3i = _world_block_to_chunk(world_block)
	return get_grid_at(chunk_pos)


## Get the renderer at a given chunk position (or null)
func get_renderer_at(chunk_pos: Vector3i) -> UndergroundChunkRenderer:
	var data: ChunkData = _chunks.get(chunk_pos)
	return data.renderer if data else null


## Remove a block at world-space block coordinates. Returns old block type.
func remove_block_world(world_block: Vector3i) -> BlockGrid.BlockType:
	var chunk_pos: Vector3i = _world_block_to_chunk(world_block)
	var data: ChunkData = _chunks.get(chunk_pos)
	if data == null:
		return BlockGrid.BlockType.AIR

	var local: Vector3i = _world_to_local(world_block, chunk_pos)
	var old_type: BlockGrid.BlockType = data.grid.get_block(local.x, local.y, local.z)
	data.grid.set_block(local.x, local.y, local.z, BlockGrid.BlockType.AIR)
	data.renderer.rebuild_mesh(_hidden_blocks)

	# Neighboring chunks may need rebuild if block was on a chunk boundary
	_rebuild_neighbor_chunks_if_needed(local, chunk_pos)

	return old_type


## Get block type at world-space block coordinates
func get_block_world(world_block: Vector3i) -> BlockGrid.BlockType:
	var chunk_pos: Vector3i = _world_block_to_chunk(world_block)
	var data: ChunkData = _chunks.get(chunk_pos)
	if data == null:
		return BlockGrid.BlockType.STONE
	var local: Vector3i = _world_to_local(world_block, chunk_pos)
	return data.grid.get_block(local.x, local.y, local.z)


## Get damage at world-space block coordinates
func get_damage_world(world_block: Vector3i) -> float:
	var chunk_pos: Vector3i = _world_block_to_chunk(world_block)
	var data: ChunkData = _chunks.get(chunk_pos)
	if data == null:
		return 0.0
	var local: Vector3i = _world_to_local(world_block, chunk_pos)
	return data.grid.get_damage(local.x, local.y, local.z)


## Set damage at world-space block coordinates
func set_damage_world(world_block: Vector3i, amount: float) -> void:
	var chunk_pos: Vector3i = _world_block_to_chunk(world_block)
	var data: ChunkData = _chunks.get(chunk_pos)
	if data == null:
		return
	var local: Vector3i = _world_to_local(world_block, chunk_pos)
	data.grid.set_damage(local.x, local.y, local.z, amount)


## Clear damage at world-space block coordinates
func clear_damage_world(world_block: Vector3i) -> void:
	var chunk_pos: Vector3i = _world_block_to_chunk(world_block)
	var data: ChunkData = _chunks.get(chunk_pos)
	if data == null:
		return
	var local: Vector3i = _world_to_local(world_block, chunk_pos)
	data.grid.clear_damage(local.x, local.y, local.z)


func _update_loaded_chunks() -> void:
	if _player_positions.is_empty():
		return

	# Determine which chunks should be loaded based on player positions
	var needed: Dictionary = {}  # Vector3i -> true
	var bs: float = UndergroundChunkRenderer.BLOCK_SIZE
	var cs: int = BlockGrid.CHUNK_SIZE
	var chunk_world_size: float = cs * bs

	for pos: Vector3 in _player_positions:
		var center_chunk: Vector3i = Vector3i(
			floori(pos.x / chunk_world_size),
			floori(pos.y / chunk_world_size),
			floori(pos.z / chunk_world_size)
		)
		for dy: int in range(-load_radius_y, load_radius_y + 1):
			for dz: int in range(-load_radius_xz, load_radius_xz + 1):
				for dx: int in range(-load_radius_xz, load_radius_xz + 1):
					needed[center_chunk + Vector3i(dx, dy, dz)] = true

	# Unload chunks no longer needed
	var to_unload: Array[Vector3i] = []
	for chunk_pos: Vector3i in _chunks:
		if not needed.has(chunk_pos):
			to_unload.append(chunk_pos)

	for chunk_pos: Vector3i in to_unload:
		_unload_chunk(chunk_pos)

	# Queue new chunks for loading (throttled in _process)
	for chunk_pos: Vector3i in needed:
		if not _chunks.has(chunk_pos) and chunk_pos not in _load_queue:
			_load_queue.append(chunk_pos)

	# Prune load queue of no-longer-needed chunks
	_load_queue = _load_queue.filter(func(pos: Vector3i) -> bool: return needed.has(pos))


func _load_chunk(chunk_pos: Vector3i) -> void:
	if generator == null:
		return

	var grid: BlockGrid = generator.generate_chunk(chunk_pos)
	var renderer: UndergroundChunkRenderer = UndergroundChunkRenderer.new()
	renderer.name = "Chunk_%d_%d_%d" % [chunk_pos.x, chunk_pos.y, chunk_pos.z]
	add_child(renderer)
	renderer.set_grid(grid, _hidden_blocks)

	_chunks[chunk_pos] = ChunkData.new(grid, renderer)
	chunk_loaded.emit(chunk_pos)


func _unload_chunk(chunk_pos: Vector3i) -> void:
	var data: ChunkData = _chunks.get(chunk_pos)
	if data == null:
		return
	# Drop any hidden-block tracking for this chunk so we don't leak memory
	# or get false-positive diffs on reload.
	if _hidden_by_chunk.has(chunk_pos):
		for world_block: Vector3i in _hidden_by_chunk[chunk_pos]:
			_hidden_blocks.erase(world_block)
		_hidden_by_chunk.erase(chunk_pos)
	data.renderer.queue_free()
	_chunks.erase(chunk_pos)
	chunk_unloaded.emit(chunk_pos)


func _world_block_to_chunk(world_block: Vector3i) -> Vector3i:
	return ChunkMath.block_to_chunk(world_block, BlockGrid.CHUNK_SIZE)


func _world_to_local(world_block: Vector3i, chunk_pos: Vector3i) -> Vector3i:
	return ChunkMath.block_to_local(world_block, chunk_pos, BlockGrid.CHUNK_SIZE)


func _rebuild_neighbor_chunks_if_needed(local: Vector3i, chunk_pos: Vector3i) -> void:
	var cs: int = BlockGrid.CHUNK_SIZE
	var neighbors_to_rebuild: Array[Vector3i] = []

	if local.x == 0:
		neighbors_to_rebuild.append(chunk_pos + Vector3i(-1, 0, 0))
	elif local.x == cs - 1:
		neighbors_to_rebuild.append(chunk_pos + Vector3i(1, 0, 0))
	if local.y == 0:
		neighbors_to_rebuild.append(chunk_pos + Vector3i(0, -1, 0))
	elif local.y == cs - 1:
		neighbors_to_rebuild.append(chunk_pos + Vector3i(0, 1, 0))
	if local.z == 0:
		neighbors_to_rebuild.append(chunk_pos + Vector3i(0, 0, -1))
	elif local.z == cs - 1:
		neighbors_to_rebuild.append(chunk_pos + Vector3i(0, 0, 1))

	for npos: Vector3i in neighbors_to_rebuild:
		var data: ChunkData = _chunks.get(npos)
		if data != null:
			data.renderer.rebuild_mesh(_hidden_blocks)


## Occlusion: hide blocks between each camera and its player
func _update_occlusion() -> void:
	# new_by_chunk is the authoritative new hidden set, bucketed by chunk.
	var new_by_chunk: Dictionary = {}
	var bs: float = UndergroundChunkRenderer.BLOCK_SIZE

	for i: int in range(mini(_occlusion_cameras.size(), _occlusion_players.size())):
		var cam: Camera3D = _occlusion_cameras[i]
		var player: Node3D = _occlusion_players[i]
		if cam == null or player == null:
			continue
		# Only occlude for underground players
		if player is PlayerController and not (player as PlayerController).is_underground:
			continue

		var cam_pos: Vector3 = cam.global_position
		var player_pos: Vector3 = player.global_position

		# DDA raywalk from camera to player in block grid space
		var start: Vector3 = cam_pos / bs
		var end: Vector3 = player_pos / bs
		var ray_blocks: Array[Vector3i] = _dda_raywalk(start, end)

		# For each block on the ray, also check face-adjacent neighbors
		# to cover the player's visual width (~0.6 blocks radius)
		for block_world: Vector3i in ray_blocks:
			_try_hide_block(block_world, new_by_chunk)
			_try_hide_block(block_world + Vector3i(1, 0, 0), new_by_chunk)
			_try_hide_block(block_world + Vector3i(-1, 0, 0), new_by_chunk)
			_try_hide_block(block_world + Vector3i(0, 1, 0), new_by_chunk)
			_try_hide_block(block_world + Vector3i(0, -1, 0), new_by_chunk)
			_try_hide_block(block_world + Vector3i(0, 0, 1), new_by_chunk)
			_try_hide_block(block_world + Vector3i(0, 0, -1), new_by_chunk)

	# Diff per chunk — only rebuild chunks whose local hidden set actually changed.
	var changed_chunks: Array[Vector3i] = []
	for chunk_pos: Vector3i in _hidden_by_chunk:
		if not new_by_chunk.has(chunk_pos):
			# Chunk had hidden blocks, now has none
			changed_chunks.append(chunk_pos)
	for chunk_pos: Vector3i in new_by_chunk:
		var old_set: Dictionary = _hidden_by_chunk.get(chunk_pos, {})
		var new_set: Dictionary = new_by_chunk[chunk_pos]
		if not _dicts_equal(old_set, new_set):
			changed_chunks.append(chunk_pos)

	if changed_chunks.is_empty():
		return

	# Rebuild flat _hidden_blocks view from new_by_chunk (used as the
	# source-of-truth passed to renderers on next full rebuild_mesh).
	_hidden_blocks.clear()
	for chunk_pos: Vector3i in new_by_chunk:
		for world_block: Vector3i in new_by_chunk[chunk_pos]:
			_hidden_blocks[world_block] = true
	_hidden_by_chunk = new_by_chunk

	# Rebuild ONLY visuals (not collision) for changed chunks.
	for chunk_pos: Vector3i in changed_chunks:
		var data: ChunkData = _chunks.get(chunk_pos)
		if data != null:
			data.renderer.rebuild_visuals(_hidden_blocks)


func _try_hide_block(block_world: Vector3i, by_chunk: Dictionary) -> void:
	var chunk_pos: Vector3i = _world_block_to_chunk(block_world)
	var data: ChunkData = _chunks.get(chunk_pos)
	if data == null:
		return
	var local: Vector3i = _world_to_local(block_world, chunk_pos)
	var bt: BlockGrid.BlockType = data.grid.get_block(local.x, local.y, local.z)
	if bt == BlockGrid.BlockType.AIR:
		return
	if not by_chunk.has(chunk_pos):
		by_chunk[chunk_pos] = {} as Dictionary
	(by_chunk[chunk_pos] as Dictionary)[block_world] = true


func _dicts_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key: Vector3i in a:
		if not b.has(key):
			return false
	return true


## 3D DDA raywalk — returns all block grid cells the ray passes through
func _dda_raywalk(start: Vector3, end: Vector3) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	var dir: Vector3 = end - start
	var length: float = dir.length()
	if length < 0.001:
		return result

	dir = dir / length  # normalize

	var current: Vector3i = Vector3i(floori(start.x), floori(start.y), floori(start.z))
	var end_cell: Vector3i = Vector3i(floori(end.x), floori(end.y), floori(end.z))

	var step: Vector3i = Vector3i(
		1 if dir.x >= 0 else -1,
		1 if dir.y >= 0 else -1,
		1 if dir.z >= 0 else -1
	)

	# Distance along ray to next cell boundary per axis
	var t_max: Vector3 = Vector3.ZERO
	var t_delta: Vector3 = Vector3.ZERO

	if absf(dir.x) > 0.0001:
		var next_x: float = (current.x + (1 if step.x > 0 else 0)) as float
		t_max.x = (next_x - start.x) / dir.x
		t_delta.x = absf(1.0 / dir.x)
	else:
		t_max.x = INF
		t_delta.x = INF

	if absf(dir.y) > 0.0001:
		var next_y: float = (current.y + (1 if step.y > 0 else 0)) as float
		t_max.y = (next_y - start.y) / dir.y
		t_delta.y = absf(1.0 / dir.y)
	else:
		t_max.y = INF
		t_delta.y = INF

	if absf(dir.z) > 0.0001:
		var next_z: float = (current.z + (1 if step.z > 0 else 0)) as float
		t_max.z = (next_z - start.z) / dir.z
		t_delta.z = absf(1.0 / dir.z)
	else:
		t_max.z = INF
		t_delta.z = INF

	# Walk the ray — Manhattan distance gives correct upper bound for DDA steps
	var max_steps: int = absi(end_cell.x - current.x) + absi(end_cell.y - current.y) + absi(end_cell.z - current.z) + 3
	for _step: int in range(max_steps):
		# Don't hide the block the player is standing in or adjacent to end
		if current == end_cell:
			break
		# Add this cell (skip the starting cell which is usually air above/behind camera)
		if _step > 0:
			result.append(current)

		# Advance along the axis with smallest t_max
		if t_max.x < t_max.y:
			if t_max.x < t_max.z:
				current.x += step.x
				t_max.x += t_delta.x
			else:
				current.z += step.z
				t_max.z += t_delta.z
		else:
			if t_max.y < t_max.z:
				current.y += step.y
				t_max.y += t_delta.y
			else:
				current.z += step.z
				t_max.z += t_delta.z

	return result
