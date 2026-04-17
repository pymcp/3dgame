class_name UndergroundChunkRenderer
extends Node3D

const BLOCK_SIZE: float = 0.25

var block_grid: BlockGrid
var _multi_meshes: Dictionary = {}  # BlockType -> MultiMeshInstance3D (blocks)
var _slope_mmis: Dictionary = {}  # BlockType -> MultiMeshInstance3D (slopes)
var _collision_body: StaticBody3D = null

# Cached list of exposed solid blocks in this chunk. Rebuilt by rebuild_mesh
# (which is called on chunk load + block removal), then filtered against
# hidden_blocks by rebuild_visuals — avoiding a 32³ re-scan on every
# occlusion change.
#
# Entry layout (4 parallel arrays instead of per-entry objects for speed):
#   _cache_world_blocks[i] -> Vector3i
#   _cache_block_types[i]  -> int (BlockGrid.BlockType)
#   _cache_is_slope[i]     -> bool
#   _cache_origins[i]      -> Vector3 (already scaled by BLOCK_SIZE)
var _cache_world_blocks: Array[Vector3i] = []
var _cache_block_types: Array[int] = []
var _cache_is_slope: Array[bool] = []
var _cache_origins: Array[Vector3] = []
var _cache_valid: bool = false

# Shared meshes loaded once (static-like via class variable)
static var _block_meshes: Dictionary = {}  # BlockType -> Mesh
static var _slope_mesh_stone: Mesh = null
static var _slope_mesh_rock: Mesh = null
static var _meshes_loaded: bool = false

# Model paths for block types
const BLOCK_MODELS: Dictionary = {
	BlockGrid.BlockType.STONE: "res://assets/nature/cliff_block_stone.glb",
	BlockGrid.BlockType.ROCK: "res://assets/nature/cliff_block_rock.glb",
	BlockGrid.BlockType.ORE_IRON: "res://assets/nature/cliff_block_stone.glb",
	BlockGrid.BlockType.ORE_GOLD: "res://assets/nature/cliff_block_stone.glb",
	BlockGrid.BlockType.ORE_CRYSTAL: "res://assets/nature/cliff_block_stone.glb",
	BlockGrid.BlockType.BEDROCK: "res://assets/nature/cliff_block_rock.glb",
}


func _ready() -> void:
	if not _meshes_loaded:
		_load_block_meshes()
		_meshes_loaded = true


func _load_block_meshes() -> void:
	var loaded_paths: Dictionary = {}
	for block_type: int in BLOCK_MODELS:
		var path: String = BLOCK_MODELS[block_type]
		if not loaded_paths.has(path):
			if ResourceLoader.exists(path):
				var scene: PackedScene = load(path)
				var instance: Node3D = scene.instantiate()
				var mesh_inst: MeshInstance3D = _find_mesh_instance(instance)
				if mesh_inst:
					loaded_paths[path] = mesh_inst.mesh
				instance.queue_free()
		if loaded_paths.has(path):
			_block_meshes[block_type] = loaded_paths[path]

	# Load slope meshes for cave edges
	_slope_mesh_stone = _load_mesh_from_scene("res://assets/nature/cliff_blockSlope_stone.glb")
	_slope_mesh_rock = _load_mesh_from_scene("res://assets/nature/cliff_blockSlope_rock.glb")


func _load_mesh_from_scene(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path)
	var instance: Node3D = scene.instantiate()
	var mesh_inst: MeshInstance3D = _find_mesh_instance(instance)
	var mesh: Mesh = mesh_inst.mesh if mesh_inst else null
	instance.queue_free()
	return mesh


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child: Node in node.get_children():
		var result: MeshInstance3D = _find_mesh_instance(child)
		if result:
			return result
	return null


func set_grid(grid: BlockGrid, hidden_blocks: Dictionary = {}) -> void:
	block_grid = grid
	rebuild_mesh(hidden_blocks)


func rebuild_mesh(hidden_blocks: Dictionary = {}) -> void:
	# Full rebuild: collision + visuals. Called on chunk load and block removal.
	# Only remove collision body — preserve MultiMesh nodes (reused) and decorations.
	if _collision_body and is_instance_valid(_collision_body):
		remove_child(_collision_body)
		_collision_body.queue_free()
		_collision_body = null

	if block_grid == null:
		return

	# Block grid changed — cached exposed list is stale
	_cache_valid = false

	# Build trimesh collision — one ConcavePolygonShape3D per chunk instead of
	# thousands of individual CollisionShape3D nodes.
	_rebuild_collision()

	# Build visuals (will rebuild cache on first call)
	_rebuild_visuals(hidden_blocks)


func _rebuild_collision() -> void:
	_collision_body = StaticBody3D.new()
	_collision_body.name = "BlockCollision"
	_collision_body.collision_layer = 4  # Layer 3: underground
	_collision_body.collision_mask = 0
	add_child(_collision_body)

	var faces: PackedVector3Array = PackedVector3Array()
	var cs: int = BlockGrid.CHUNK_SIZE
	var bs: float = BLOCK_SIZE

	# 6 face directions and their quad vertex offsets (in BLOCK_SIZE units from block origin)
	var face_dirs: Array[Vector3i] = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]
	var face_quads: Array[Array] = [
		[Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)],  # +X
		[Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)],  # -X
		[Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)],  # +Y
		[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)],  # -Y
		[Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)],  # +Z
		[Vector3(1, 0, 0), Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0)],  # -Z
	]

	for y: int in range(cs):
		for z: int in range(cs):
			for x: int in range(cs):
				if not block_grid.is_exposed(x, y, z):
					continue
				var bt: BlockGrid.BlockType = block_grid.get_block(x, y, z)
				if bt == BlockGrid.BlockType.AIR:
					continue

				var wp: Vector3 = block_grid.world_position(x, y, z) * bs

				# Only emit faces adjacent to air
				for fi: int in range(6):
					var d: Vector3i = face_dirs[fi]
					if block_grid.get_block(x + d.x, y + d.y, z + d.z) != BlockGrid.BlockType.AIR:
						continue
					var q: Array = face_quads[fi]
					var v0: Vector3 = wp + q[0] * bs
					var v1: Vector3 = wp + q[1] * bs
					var v2: Vector3 = wp + q[2] * bs
					var v3: Vector3 = wp + q[3] * bs
					faces.append(v0); faces.append(v1); faces.append(v2)
					faces.append(v0); faces.append(v2); faces.append(v3)

	if faces.size() > 0:
		var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision = true
		var col_shape: CollisionShape3D = CollisionShape3D.new()
		col_shape.shape = shape
		_collision_body.add_child(col_shape)


func rebuild_visuals(hidden_blocks: Dictionary = {}) -> void:
	# Public wrapper — only rebuilds MultiMesh visuals, NOT collision.
	# Called by UndergroundManager when occlusion set changes.
	_rebuild_visuals(hidden_blocks)


func _rebuild_visuals(hidden_blocks: Dictionary = {}) -> void:
	if block_grid == null:
		return

	# Populate cache on first call or after block-grid change. This is the
	# single 32³ scan — subsequent visual rebuilds (triggered by occlusion)
	# iterate only the exposed-block list, which is typically <5% of chunk volume.
	if not _cache_valid:
		_rebuild_exposed_cache()
		_cache_valid = true

	# Filter cache against hidden_blocks, bucketed by block type.
	# Store indices into the cache for each bucket so we can look up origin cheaply.
	var blocks_by_type: Dictionary = {}  # BlockType -> Array[int] indices
	var slopes_by_type: Dictionary = {}  # BlockType -> Array[int] indices

	var n: int = _cache_world_blocks.size()
	for i: int in range(n):
		if hidden_blocks.has(_cache_world_blocks[i]):
			continue
		var bt: int = _cache_block_types[i]
		if _cache_is_slope[i]:
			if not slopes_by_type.has(bt):
				slopes_by_type[bt] = [] as Array
			(slopes_by_type[bt] as Array).append(i)
		else:
			if not blocks_by_type.has(bt):
				blocks_by_type[bt] = [] as Array
			(blocks_by_type[bt] as Array).append(i)

	# Write block buffers
	_write_mmi_buffers(blocks_by_type, _multi_meshes, false)
	# Write slope buffers
	_write_mmi_buffers(slopes_by_type, _slope_mmis, true)


# Build the _cache_* arrays by scanning the chunk once.
func _rebuild_exposed_cache() -> void:
	_cache_world_blocks.clear()
	_cache_block_types.clear()
	_cache_is_slope.clear()
	_cache_origins.clear()

	var cs: int = BlockGrid.CHUNK_SIZE
	var bs: float = BLOCK_SIZE
	var cpx: int = block_grid.chunk_position.x * cs
	var cpy: int = block_grid.chunk_position.y * cs
	var cpz: int = block_grid.chunk_position.z * cs

	for y: int in range(cs):
		for z: int in range(cs):
			for x: int in range(cs):
				if not block_grid.is_exposed(x, y, z):
					continue
				var block_type: BlockGrid.BlockType = block_grid.get_block(x, y, z)
				if block_type == BlockGrid.BlockType.AIR:
					continue
				var is_slope: bool = block_grid.has_air_above(x, y, z) and block_type != BlockGrid.BlockType.BEDROCK
				_cache_world_blocks.append(Vector3i(cpx + x, cpy + y, cpz + z))
				_cache_block_types.append(int(block_type))
				_cache_is_slope.append(is_slope)
				_cache_origins.append(Vector3((cpx + x) * bs, (cpy + y) * bs, (cpz + z) * bs))


# Upload instance data into MultiMesh buffers. Reuses MMI nodes to avoid
# tree-ops churn, and writes a single PackedFloat32Array per type for the
# GPU upload instead of per-instance setter loops.
func _write_mmi_buffers(by_type: Dictionary, mmi_map: Dictionary, is_slope: bool) -> void:
	var bs: float = BLOCK_SIZE

	# Hide MMIs whose type no longer has any visible instances
	for existing_type: int in mmi_map:
		if not by_type.has(existing_type):
			var mmi_existing: MultiMeshInstance3D = mmi_map[existing_type]
			if is_instance_valid(mmi_existing) and mmi_existing.multimesh:
				mmi_existing.multimesh.instance_count = 0

	for block_type: int in by_type:
		var mesh: Mesh = _get_slope_mesh(block_type) if is_slope else _block_meshes.get(block_type)
		if mesh == null:
			continue

		var indices: Array = by_type[block_type]
		var count: int = indices.size()

		var mmi: MultiMeshInstance3D = mmi_map.get(block_type)
		var multi_mesh: MultiMesh
		if mmi == null or not is_instance_valid(mmi):
			mmi = MultiMeshInstance3D.new()
			mmi.name = ("SlopeType_%d" if is_slope else "BlockType_%d") % block_type
			mmi.layers = 4  # Visual layer 3: underground
			multi_mesh = MultiMesh.new()
			multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
			multi_mesh.use_colors = true
			multi_mesh.mesh = mesh
			mmi.multimesh = multi_mesh
			add_child(mmi)
			mmi_map[block_type] = mmi
		else:
			multi_mesh = mmi.multimesh
			if multi_mesh.mesh != mesh:
				multi_mesh.mesh = mesh

		# Build a flat buffer: 12 floats (transform) + 4 floats (color) per instance.
		# The basis is a uniform scale by BLOCK_SIZE, so each 3x4 row is trivial.
		var props: Dictionary = BlockGrid.get_properties(block_type)
		var tint: Color = props["tint"]
		var buf: PackedFloat32Array = PackedFloat32Array()
		buf.resize(count * 16)

		for i: int in range(count):
			var origin: Vector3 = _cache_origins[indices[i]]
			var base: int = i * 16
			# Row 0
			buf[base + 0] = bs
			buf[base + 1] = 0.0
			buf[base + 2] = 0.0
			buf[base + 3] = origin.x
			# Row 1
			buf[base + 4] = 0.0
			buf[base + 5] = bs
			buf[base + 6] = 0.0
			buf[base + 7] = origin.y
			# Row 2
			buf[base + 8] = 0.0
			buf[base + 9] = 0.0
			buf[base + 10] = bs
			buf[base + 11] = origin.z
			# Color (rgba)
			buf[base + 12] = tint.r
			buf[base + 13] = tint.g
			buf[base + 14] = tint.b
			buf[base + 15] = tint.a

		# Assigning instance_count first, then buffer, avoids a resize-copy dance.
		multi_mesh.instance_count = count
		multi_mesh.buffer = buf


func remove_block(x: int, y: int, z: int, hidden_blocks: Dictionary = {}) -> BlockGrid.BlockType:
	if block_grid == null:
		return BlockGrid.BlockType.AIR
	var old_type: BlockGrid.BlockType = block_grid.get_block(x, y, z)
	block_grid.set_block(x, y, z, BlockGrid.BlockType.AIR)
	# Rebuild mesh (could optimize to only rebuild affected block type)
	rebuild_mesh(hidden_blocks)
	return old_type


func _get_slope_mesh(block_type: BlockGrid.BlockType) -> Mesh:
	# Rock-based types get rock slope, others get stone slope
	if block_type == BlockGrid.BlockType.ROCK:
		return _slope_mesh_rock if _slope_mesh_rock else _slope_mesh_stone
	return _slope_mesh_stone
