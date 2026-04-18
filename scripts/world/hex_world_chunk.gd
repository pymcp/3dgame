class_name HexWorldChunk
extends Node3D

## One chunk of a `HexWorld`. Holds cell data (sparse) plus a
## `MultiMeshInstance3D` per base-tile kind and per overlay kind, plus
## per-cell collision.

const LAYER_HEIGHT: float = HexGrid.HEX_TILE_HEIGHT  # world-units per layer step
const HEX_RADIUS: float = HexGrid.HEX_SIZE
const SQRT3: float = HexGrid.SQRT3

## Global multiplier applied to overlay MultiMesh instance transforms
## (trees, rocks, ores, hills, mountains). Base tiles are not affected.
## Adjusted at runtime via `HexWorld.set_overlay_scale(...)`.
static var overlay_scale_multiplier: float = 1.0

## Precomputed (cos, sin) for 60° rotation steps 0–5. Index 0 is
## identity (0°), index 1 is 60°, etc. Used by `_write_mmi` for
## per-instance Y-rotation.
static var _ROT_TABLE: Array[Vector2] = _build_rot_table()

## Local-space hex prism vertex template (6 top, 6 bottom). Pointy-top.
## Flat-top axis along +x is offset; we mirror axial_to_world layout.
static var _HEX_PRISM_TOP: PackedVector3Array = _build_hex_top()
static var _HEX_PRISM_BOTTOM: PackedVector3Array = _build_hex_bottom()

static func _build_rot_table() -> Array[Vector2]:
	var t: Array[Vector2] = []
	for i: int in 6:
		var angle: float = float(i) * PI / 3.0
		t.append(Vector2(cos(angle), sin(angle)))
	return t

static func _build_hex_top() -> PackedVector3Array:
	# Pointy-top hex centered at origin with circumradius HEX_RADIUS.
	# Matches the visual pivot of Kenney hex tiles (bottom-aligned), so
	# vertical positioning is done by the caller.
	var pts: PackedVector3Array = PackedVector3Array()
	pts.resize(6)
	for i: int in 6:
		var a: float = (PI / 6.0) + float(i) * PI / 3.0  # 30°, 90°, 150°...
		pts[i] = Vector3(HEX_RADIUS * cos(a), 0.0, HEX_RADIUS * sin(a))
	return pts

static func _build_hex_bottom() -> PackedVector3Array:
	var pts: PackedVector3Array = PackedVector3Array()
	pts.resize(6)
	for i: int in 6:
		var a: float = (PI / 6.0) + float(i) * PI / 3.0
		pts[i] = Vector3(HEX_RADIUS * cos(a), -LAYER_HEIGHT, HEX_RADIUS * sin(a))
	return pts


## Shared overlay collider (cylinder for trees/mountains/blocking rocks).
## Reused across thousands of cells via shape-resource sharing.
static var _overlay_cylinder: CylinderShape3D = _make_overlay_cylinder()

static func _make_overlay_cylinder() -> CylinderShape3D:
	# Thinner + taller for blocking overlays (trees, mountains, hills,
	# rocks). Thinner avoids diagonal snagging; taller prevents the
	# player from stepping up over them.
	var c: CylinderShape3D = CylinderShape3D.new()
	c.height = LAYER_HEIGHT * 3.0
	c.radius = HexGrid.HEX_SIZE * 0.8
	return c

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

# Collision: one StaticBody3D with:
#   - one merged ConcavePolygonShape3D for ALL base cell tops/sides (rebuilt as a unit)
#   - one CollisionShape3D per blocking overlay (cylinder; tracked individually)
var _collision_body: StaticBody3D
var _base_collision_shape: CollisionShape3D = null
var _base_concave: ConcavePolygonShape3D = null
var _overlay_collision_shapes: Dictionary = {}  # local_coord Vector3i -> CollisionShape3D

# Decorations (prop nodes) keyed by coord they anchor to. Preserved
# across visual rebuilds.
var _decorations: Dictionary = {}  # local_coord Vector3i -> Node3D

## True if a rebuild has been requested but not yet flushed.
## The owning `HexWorld` calls `flush_rebuild()` once per frame.
var _dirty_visuals: bool = false
var _dirty_collision: bool = false


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
	_dirty_visuals = true
	_dirty_collision = true


func clear_cell_local(local: Vector3i) -> void:
	cells.erase(local)
	_dirty_visuals = true
	_dirty_collision = true


## Mark the chunk so the next `flush_rebuild()` does work. The owning
## `HexWorld` calls `flush_rebuild()` from `_process` to coalesce many
## edits in one frame into a single rebuild.
func mark_dirty() -> void:
	_dirty_visuals = true
	_dirty_collision = true


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


## Force an immediate rebuild. Used right after `generate_chunk()` so
## the chunk is render-ready before being added to `_chunks`.
func rebuild() -> void:
	rebuild_visuals()
	rebuild_collision()
	_dirty_visuals = false
	_dirty_collision = false


## Apply pending edits if any. Called from `HexWorld._process`.
func flush_rebuild() -> void:
	if _dirty_visuals:
		rebuild_visuals()
		_dirty_visuals = false
	if _dirty_collision:
		rebuild_collision()
		_dirty_collision = false


func rebuild_visuals() -> void:
	# Bucket cells by base index and by overlay index.
	var by_base: Dictionary = {}     # base_id -> Array[Vector3i local]
	var by_overlay: Dictionary = {}  # overlay_id -> Array[Vector3i local]
	for local_key: Variant in cells:
		var local: Vector3i = local_key as Vector3i
		var cell: HexCell = cells[local] as HexCell
		var base_arr_v: Variant = by_base.get(cell.base_id)
		if base_arr_v == null:
			var fresh: Array = [local]
			by_base[cell.base_id] = fresh
		else:
			(base_arr_v as Array).append(local)
		if cell.overlay_id >= 0:
			var ov_arr_v: Variant = by_overlay.get(cell.overlay_id)
			if ov_arr_v == null:
				var fresh_ov: Array = [local]
				by_overlay[cell.overlay_id] = fresh_ov
			else:
				(ov_arr_v as Array).append(local)
	_write_base_mmis(by_base)
	_write_overlay_mmis(by_overlay)


## Build collision: one merged ConcavePolygonShape3D for all base
## cells (player walks on the top hex faces, bumps the side faces),
## plus one cylinder per blocking overlay.
##
## A 16x16x4 chunk with mostly-air on top and stone underneath used to
## spawn ~200-1000 `CollisionShape3D` child nodes per chunk; the merged
## concave variant is a single child with all triangles batched.
func rebuild_collision() -> void:
	# --- Base collision: rebuild the single merged ConcavePolygonShape3D ---
	# We only emit faces visible to the player:
	#   - TOP face of every solid cell whose neighbour above is air
	#     (walkable top + landing surface)
	#   - SIDE faces between solid and air on the same horizontal level
	#     (cliff walls + ramp risers; players collide running into them)
	# Skipping interior faces eliminates ~80% of triangles and removes
	# ghost colliders inside the rock.
	#
	# Each face is two triangles (6 vertices) in CCW winding (top face)
	# / outward facing (side face).
	var verts: PackedVector3Array = PackedVector3Array()
	# Pre-grow estimate: most cells have at most one top face + a few
	# side faces. Average ~10 verts per visible cell is generous.
	verts.resize(0)

	# Cache by (q, r) so all layers in the same column share one
	# `axial_to_world` call. In a fully-stone chunk this is a 4×
	# reduction in HexGrid math.
	var col_xz: Dictionary = {}  # Vector2i(q, r) -> Vector2(x, z)

	for local_key: Variant in cells:
		var local: Vector3i = local_key as Vector3i
		var cell: HexCell = cells[local] as HexCell
		if cell == null:
			continue
		if cell.base_id < 0 or cell.base_id >= _palette.bases.size():
			continue
		var tk: TileKind = _palette.bases[cell.base_id]
		if tk == null:
			continue
		var qr: Vector2i = Vector2i(cell.q, cell.r)
		var xz_v: Variant = col_xz.get(qr)
		var cx: float
		var cz: float
		if xz_v == null:
			var w: Vector3 = HexGrid.axial_to_world(cell.q, cell.r)
			cx = w.x
			cz = w.z
			col_xz[qr] = Vector2(cx, cz)
		else:
			var v2: Vector2 = xz_v
			cx = v2.x
			cz = v2.y
		var y_top: float = float(cell.layer + 1) * LAYER_HEIGHT + cell.elevation
		var y_bot: float = float(cell.layer) * LAYER_HEIGHT + cell.elevation

		# TOP face: emit only if cell directly above is empty.
		var above: HexCell = cells.get(Vector3i(local.x, local.y, local.z + 1))
		if above == null:
			# 6-vertex hex fan -> 4 triangles (12 verts). CCW from above.
			# Triangles: (0,1,2) (0,2,3) (0,3,4) (0,4,5)
			var top: PackedVector3Array = _HEX_PRISM_TOP
			var center: Vector3 = Vector3(cx, y_top, cz)
			var v0: Vector3 = center + top[0]
			for i: int in range(1, 5):
				var v1: Vector3 = center + top[i]
				var v2: Vector3 = center + top[i + 1]
				verts.append(v0)
				verts.append(v1)
				verts.append(v2)

		# SIDE faces: each of 6 hex sides. Side `s` connects top
		# vertices `s` and `(s+1)%6` (positioned at angles 30°+s·60°).
		# Pointy-top side directions for s=0..5 are SE, SW, W, NW, NE, E,
		# but `AXIAL_DIRECTIONS` is ordered E, NE, NW, W, SW, SE
		# (indices 0..5). Map side index → axial dir index so we
		# suppress the wall toward an existing neighbor in the
		# correct direction. Mapping: side s → axial dir (5 - s) % 6.
		for s_idx: int in 6:
			var dir_idx: int = (5 - s_idx + 6) % 6
			var dir: Vector2i = HexGrid.AXIAL_DIRECTIONS[dir_idx]
			var n_local: Vector3i = Vector3i(local.x + dir.x, local.y + dir.y, local.z)
			var n_cell: HexCell = cells.get(n_local)
			# Same-layer neighbour exists -> shared side, no wall needed.
			if n_cell != null:
				continue
			# Boundary of chunk? Skip the wall to avoid double-walls
			# at chunk seams (the neighbour chunk will emit its own
			# wall when it loads, or none if it's also air).
			# Heuristic: assume out-of-chunk = present rock to keep
			# back-compat with the original cylinder (don't carve
			# pop-in at chunk borders). We DO emit the wall.
			# 4-vertex side quad. Pointy-top: side `s` connects top
			# vertices s and (s+1)%6 to their bottom counterparts.
			var top_i: Vector3 = _HEX_PRISM_TOP[s_idx]
			var top_j: Vector3 = _HEX_PRISM_TOP[(s_idx + 1) % 6]
			var bot_i: Vector3 = _HEX_PRISM_BOTTOM[s_idx]
			var bot_j: Vector3 = _HEX_PRISM_BOTTOM[(s_idx + 1) % 6]
			# We need both top and bottom at the cell's actual y.
			# _HEX_PRISM_TOP has y=0, _HEX_PRISM_BOTTOM has y=-LAYER_HEIGHT.
			# Translate so top is at y_top, bottom at y_bot.
			var center: Vector3 = Vector3(cx, y_top, cz)
			var ti: Vector3 = center + Vector3(top_i.x, 0.0, top_i.z)
			var tj: Vector3 = center + Vector3(top_j.x, 0.0, top_j.z)
			var bi: Vector3 = Vector3(ti.x, y_bot, ti.z)
			var bj: Vector3 = Vector3(tj.x, y_bot, tj.z)
			# Triangle 1: ti, bi, tj  (CCW from outside-right)
			# Triangle 2: tj, bi, bj
			verts.append(ti); verts.append(bi); verts.append(tj)
			verts.append(tj); verts.append(bi); verts.append(bj)

	# Replace the merged shape (one node, one resource).
	if _base_collision_shape == null:
		_base_collision_shape = CollisionShape3D.new()
		_base_collision_shape.name = "BaseShape"
		_collision_body.add_child(_base_collision_shape)
	if verts.is_empty():
		# No cells -> remove the shape so physics has nothing to query.
		if _base_collision_shape.shape != null:
			_base_collision_shape.shape = null
		_base_concave = null
	else:
		# Build a fresh ConcavePolygonShape3D and assign. Reusing the
		# old one and calling `set_faces` on it is fine but allocating
		# a new one is simpler and the GC cost is negligible compared
		# to the previous N-cylinder churn.
		_base_concave = ConcavePolygonShape3D.new()
		_base_concave.set_faces(verts)
		_base_collision_shape.shape = _base_concave

	# --- Overlay collision: cylinders per blocking overlay (unchanged) ---
	for ov_key: Variant in _overlay_collision_shapes.keys():
		var ov_shape: CollisionShape3D = _overlay_collision_shapes[ov_key] as CollisionShape3D
		if is_instance_valid(ov_shape):
			ov_shape.queue_free()
	_overlay_collision_shapes.clear()
	for local_key: Variant in cells:
		var local: Vector3i = local_key as Vector3i
		var cell: HexCell = cells[local] as HexCell
		if cell == null or cell.overlay_id < 0 or cell.overlay_id >= _palette.overlays.size():
			continue
		var ok: OverlayKind = _palette.overlays[cell.overlay_id]
		if ok == null or not ok.blocks_movement:
			continue
		var center: Vector3 = _cell_world_center(cell)
		var ocs: CollisionShape3D = CollisionShape3D.new()
		ocs.shape = _overlay_cylinder
		# Sit the tall cylinder on top of the base tile.
		ocs.position = Vector3(center.x, center.y + LAYER_HEIGHT + _overlay_cylinder.height * 0.5, center.z)
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
		_write_mmi(mmi, locals, tk.tint, 0.0, 1.0)


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
		var mmi: MultiMeshInstance3D = _get_or_make_mmi(_overlay_mmis, ov_id, ok.mesh, ok.use_colormap)
		# Road overlays (use_colormap=false) always render at scale 1.0 so
		# they align with hex edges; other overlays use the global scale.
		var scale: float = 1.0 if not ok.use_colormap else overlay_scale_multiplier
		_write_mmi(mmi, locals, ok.tint, ok.y_offset, scale)


func _get_or_make_mmi(cache: Dictionary, key: int, mesh: Mesh, colormap: bool = true) -> MultiMeshInstance3D:
	if cache.has(key):
		var mmi: MultiMeshInstance3D = cache[key] as MultiMeshInstance3D
		if is_instance_valid(mmi):
			return mmi
	var new_mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	new_mmi.layers = render_layer_bit
	if colormap:
		new_mmi.material_override = TileOcclusion.get_material()
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	new_mmi.multimesh = mm
	add_child(new_mmi)
	cache[key] = new_mmi
	return new_mmi


func _write_mmi(mmi: MultiMeshInstance3D, locals: Array, tint: Color, y_offset: float, scale: float) -> void:
	var count: int = locals.size()
	var mm: MultiMesh = mmi.multimesh
	mm.instance_count = count
	if count == 0:
		return
	# Build flat buffer: 12 floats (3x4 transform) + 4 floats (color) per instance.
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(count * 16)
	# Cache axial->world by (q, r). Many instances share the same column
	# (especially for base tiles in stone-filled chunks), so this avoids
	# recomputing `axial_to_world` once per layer per column.
	var xz_cache: Dictionary = {}  # Vector2i(q, r) -> Vector3 (xz only)
	for i: int in count:
		var local: Vector3i = locals[i] as Vector3i
		var cell: HexCell = cells[local] as HexCell
		var qr: Vector2i = Vector2i(cell.q, cell.r)
		var xz_v: Variant = xz_cache.get(qr)
		var xz: Vector3
		if xz_v == null:
			xz = HexGrid.axial_to_world(cell.q, cell.r)
			xz_cache[qr] = xz
		else:
			xz = xz_v
		var pos_y: float = float(cell.layer) * LAYER_HEIGHT + cell.elevation + y_offset
		var pos_x: float = xz.x
		var pos_z: float = xz.z
		var offset: int = i * 16
		if cell.rotation == 0:
			# Uniform-scaled basis rows (3x4 layout: basis.x, basis.y, basis.z, origin).
			buf[offset + 0] = scale; buf[offset + 1] = 0.0;   buf[offset + 2] = 0.0;   buf[offset + 3] = pos_x
			buf[offset + 4] = 0.0;   buf[offset + 5] = scale; buf[offset + 6] = 0.0;   buf[offset + 7] = pos_y
			buf[offset + 8] = 0.0;   buf[offset + 9] = 0.0;   buf[offset + 10] = scale; buf[offset + 11] = pos_z
		else:
			# Rotated basis: Y-rotation by cell.rotation * 60°.
			var cs: Vector2 = _ROT_TABLE[cell.rotation]
			var c: float = cs.x * scale
			var s: float = cs.y * scale
			# Row-major 3x4: [Xx Xy Xz Tx] [Yx Yy Yz Ty] [Zx Zy Zz Tz]
			# Y-rotation matrix: [[cos 0 sin] [0 1 0] [-sin 0 cos]]
			buf[offset + 0] = c;   buf[offset + 1] = 0.0;   buf[offset + 2] = s;     buf[offset + 3] = pos_x
			buf[offset + 4] = 0.0; buf[offset + 5] = scale; buf[offset + 6] = 0.0;   buf[offset + 7] = pos_y
			buf[offset + 8] = -s;  buf[offset + 9] = 0.0;   buf[offset + 10] = c;    buf[offset + 11] = pos_z
		buf[offset + 12] = tint.r; buf[offset + 13] = tint.g; buf[offset + 14] = tint.b; buf[offset + 15] = tint.a
	mm.buffer = buf


func _cell_world_center(cell: HexCell) -> Vector3:
	var xz: Vector3 = HexGrid.axial_to_world(cell.q, cell.r)
	var y: float = float(cell.layer) * LAYER_HEIGHT + cell.elevation
	return Vector3(xz.x, y, xz.z)
