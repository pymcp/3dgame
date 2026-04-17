class_name HexWorldChunk
extends Node3D

## One chunk of a `HexWorld`. Holds cell data (sparse) plus a
## `MultiMeshInstance3D` per base-tile kind and per overlay kind, plus
## per-cell collision.

const LAYER_HEIGHT: float = HexGrid.HEX_TILE_HEIGHT  # world-units per layer step

var chunk_pos: Vector3i = Vector3i.ZERO
var size_qr: int = 16
var size_layer: int = 4
## Bitmask assigned to every `VisualInstance3D.layers` under this chunk.
var render_layer_bit: int = 2

## Sparse storage: `Vector3i local_coord -> HexCell`.
var cells: Dictionary = {}

var _palette: TilePalette

# MMI children, keyed by palette index.
var _base_mmis: Dictionary = {}    # base_index -> MultiMeshInstance3D
var _overlay_mmis: Dictionary = {} # overlay_index -> MultiMeshInstance3D

# Collision: one StaticBody3D with many CollisionShape3D cylinders (one per
# solid cell). Cheap + accurate for hex columns.
var _collision_body: StaticBody3D
var _collision_shapes: Dictionary = {}  # local_coord Vector3i -> CollisionShape3D
# Overlay (tree/mountain/hill/rocks) colliders, keyed separately so we
# can rebuild them independently of the base shapes.
var _overlay_collision_shapes: Dictionary = {}  # local_coord Vector3i -> CollisionShape3D

# Decorations (prop nodes) keyed by coord they anchor to. Preserved
# across visual rebuilds.
var _decorations: Dictionary = {}  # local_coord Vector3i -> Node3D


func _init(cpos: Vector3i, qr: int, layer: int, render_bit: int, palette: TilePalette) -> void:
	chunk_pos = cpos
	size_qr = qr
	size_layer = layer
	render_layer_bit = render_bit
	_palette = palette


func _ready() -> void:
	_collision_body = StaticBody3D.new()
	_collision_body.name = "Collision"
	# The owning HexWorld sets `collision_layer` and re-propagates it via
	# `apply_collision_layer`. Default to Overworld (2) until then.
	_collision_body.collision_layer = 2
	_collision_body.collision_mask = 0
	add_child(_collision_body)


## Called by the owning `HexWorld` after the chunk is added to the tree
## so the chunk's `StaticBody3D` lives on the correct physics layer.
func apply_collision_layer(layer_bits: int) -> void:
	if _collision_body != null:
		_collision_body.collision_layer = layer_bits


## Returns the cell stored at `local`, or null if none exists.
func get_cell_local(local: Vector3i) -> HexCell:
	return cells.get(local)


func set_cell_local(local: Vector3i, cell: HexCell) -> void:
	cells[local] = cell


func clear_cell_local(local: Vector3i) -> void:
	cells.erase(local)


## Insert a decoration node as a child, tied to a local coord.
## Replaces any existing decoration at that coord (old one is freed).
func attach_decoration(local: Vector3i, node: Node3D) -> void:
	if _decorations.has(local):
		var old: Node3D = _decorations[local] as Node3D
		if is_instance_valid(old):
			old.queue_free()
	_decorations[local] = node
	add_child(node)


func clear_decoration(local: Vector3i) -> void:
	if _decorations.has(local):
		var old: Node3D = _decorations[local] as Node3D
		if is_instance_valid(old):
			old.queue_free()
		_decorations.erase(local)


## Rebuild all MMI visuals and collision from current `cells`. Called
## after generation completes and after any cell change.
func rebuild() -> void:
	rebuild_visuals()
	rebuild_collision()


func rebuild_visuals() -> void:
	# Bucket cells by base index and by overlay index.
	var by_base: Dictionary = {}     # base_id -> Array[Vector3i local]
	var by_overlay: Dictionary = {}  # overlay_id -> Array[Vector3i local]
	for local_key: Variant in cells.keys():
		var local: Vector3i = local_key as Vector3i
		var cell: HexCell = cells[local] as HexCell
		if not by_base.has(cell.base_id):
			by_base[cell.base_id] = []
		(by_base[cell.base_id] as Array).append(local)
		if cell.overlay_id >= 0:
			if not by_overlay.has(cell.overlay_id):
				by_overlay[cell.overlay_id] = []
			(by_overlay[cell.overlay_id] as Array).append(local)
	_write_base_mmis(by_base)
	_write_overlay_mmis(by_overlay)


func rebuild_collision() -> void:
	# Clear existing shapes.
	for key: Variant in _collision_shapes.keys():
		var shape: CollisionShape3D = _collision_shapes[key] as CollisionShape3D
		if is_instance_valid(shape):
			shape.queue_free()
	_collision_shapes.clear()
	for ov_key: Variant in _overlay_collision_shapes.keys():
		var ov_shape: CollisionShape3D = _overlay_collision_shapes[ov_key] as CollisionShape3D
		if is_instance_valid(ov_shape):
			ov_shape.queue_free()
	_overlay_collision_shapes.clear()
	# Add a cylinder shape per solid cell whose top face is exposed.
	# We use a cylinder approximation of the hex column (close enough
	# for collision given the player character's cylinder hitbox).
	# Kenney hex tiles have pivot at their *bottom*, so a cell at
	# layer `L` visually occupies `y ∈ [L * LAYER_HEIGHT, (L+1) * LAYER_HEIGHT]`.
	# Position the collision cylinder so its top matches the mesh top —
	# otherwise the player lands *inside* the visible tile.
	var shape_resource: CylinderShape3D = CylinderShape3D.new()
	shape_resource.height = LAYER_HEIGHT
	shape_resource.radius = HexGrid.HEX_SIZE
	# Thinner + taller shared cylinder for blocking overlays (trees,
	# mountains, hills, rocks). Thinner avoids diagonal snagging; taller
	# makes sure the player can't step up over them.
	var overlay_shape: CylinderShape3D = CylinderShape3D.new()
	overlay_shape.height = LAYER_HEIGHT * 3.0
	overlay_shape.radius = HexGrid.HEX_SIZE * 0.8
	for local_key: Variant in cells.keys():
		var local: Vector3i = local_key as Vector3i
		var cell: HexCell = cells[local] as HexCell
		var tk: TileKind = _palette.bases[cell.base_id] if cell.base_id >= 0 and cell.base_id < _palette.bases.size() else null
		if tk == null:
			continue
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.shape = shape_resource
		var center: Vector3 = _cell_world_center(cell)
		cs.position = Vector3(center.x, center.y + LAYER_HEIGHT * 0.5, center.z)
		_collision_body.add_child(cs)
		_collision_shapes[local] = cs
		# Overlay collision (trees, mountains, hills, blocking rocks).
		if cell.overlay_id >= 0 and cell.overlay_id < _palette.overlays.size():
			var ok: OverlayKind = _palette.overlays[cell.overlay_id]
			if ok != null and ok.blocks_movement:
				var ocs: CollisionShape3D = CollisionShape3D.new()
				ocs.shape = overlay_shape
				# Sit the tall cylinder on top of the base tile.
				ocs.position = Vector3(center.x, center.y + LAYER_HEIGHT + overlay_shape.height * 0.5, center.z)
				_collision_body.add_child(ocs)
				_overlay_collision_shapes[local] = ocs


# --- private -------------------------------------------------------------

func _write_base_mmis(by_base: Dictionary) -> void:
	# Retire MMIs for bases no longer present.
	for key: Variant in _base_mmis.keys():
		if not by_base.has(key):
			var mmi: MultiMeshInstance3D = _base_mmis[key] as MultiMeshInstance3D
			if is_instance_valid(mmi):
				mmi.multimesh.instance_count = 0
	for base_id_v: Variant in by_base.keys():
		var base_id: int = base_id_v as int
		if base_id < 0 or base_id >= _palette.bases.size():
			continue
		var tk: TileKind = _palette.bases[base_id]
		if tk == null or tk.mesh == null:
			continue
		var locals: Array = by_base[base_id] as Array
		var mmi: MultiMeshInstance3D = _get_or_make_mmi(_base_mmis, base_id, tk.mesh)
		_write_mmi(mmi, locals, tk.tint, 0.0)


func _write_overlay_mmis(by_overlay: Dictionary) -> void:
	for key: Variant in _overlay_mmis.keys():
		if not by_overlay.has(key):
			var mmi: MultiMeshInstance3D = _overlay_mmis[key] as MultiMeshInstance3D
			if is_instance_valid(mmi):
				mmi.multimesh.instance_count = 0
	for ov_id_v: Variant in by_overlay.keys():
		var ov_id: int = ov_id_v as int
		if ov_id < 0 or ov_id >= _palette.overlays.size():
			continue
		var ok: OverlayKind = _palette.overlays[ov_id]
		if ok == null or ok.mesh == null:
			continue
		var locals: Array = by_overlay[ov_id] as Array
		var mmi: MultiMeshInstance3D = _get_or_make_mmi(_overlay_mmis, ov_id, ok.mesh)
		# Overlay extra y offset.
		_write_mmi(mmi, locals, ok.tint, ok.y_offset)


func _get_or_make_mmi(cache: Dictionary, key: int, mesh: Mesh) -> MultiMeshInstance3D:
	if cache.has(key):
		var mmi: MultiMeshInstance3D = cache[key] as MultiMeshInstance3D
		if is_instance_valid(mmi):
			return mmi
	var new_mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	new_mmi.layers = render_layer_bit
	new_mmi.material_override = TileOcclusion.get_material()
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	new_mmi.multimesh = mm
	add_child(new_mmi)
	cache[key] = new_mmi
	return new_mmi


func _write_mmi(mmi: MultiMeshInstance3D, locals: Array, tint: Color, y_offset: float) -> void:
	var count: int = locals.size()
	var mm: MultiMesh = mmi.multimesh
	mm.instance_count = count
	if count == 0:
		return
	# Build flat buffer: 12 floats (3x4 transform) + 4 floats (color) per instance.
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(count * 16)
	for i: int in count:
		var local: Vector3i = locals[i] as Vector3i
		var cell: HexCell = cells[local] as HexCell
		var pos: Vector3 = _cell_world_center(cell) + Vector3(0.0, y_offset, 0.0)
		var offset: int = i * 16
		# Identity basis rows (3x4 layout: basis.x, basis.y, basis.z, origin).
		buf[offset + 0] = 1.0; buf[offset + 1] = 0.0; buf[offset + 2] = 0.0; buf[offset + 3] = pos.x
		buf[offset + 4] = 0.0; buf[offset + 5] = 1.0; buf[offset + 6] = 0.0; buf[offset + 7] = pos.y
		buf[offset + 8] = 0.0; buf[offset + 9] = 0.0; buf[offset + 10] = 1.0; buf[offset + 11] = pos.z
		buf[offset + 12] = tint.r; buf[offset + 13] = tint.g; buf[offset + 14] = tint.b; buf[offset + 15] = tint.a
	mm.buffer = buf


func _cell_world_center(cell: HexCell) -> Vector3:
	var xz: Vector3 = HexGrid.axial_to_world(cell.q, cell.r)
	var y: float = float(cell.layer) * LAYER_HEIGHT + cell.elevation
	return Vector3(xz.x, y, xz.z)
