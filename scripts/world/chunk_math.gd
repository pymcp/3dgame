class_name ChunkMath
extends RefCounted

## Shared chunk-coordinate math for `HexWorld`. Chunks in the new system
## are keyed as `Vector3i(chunk_q, chunk_r, chunk_layer)` with separate
## sizes along q/r and layer axes.


## Floor-divide integer `a` by `b`. Differs from GDScript's `/` operator
## in that it rounds toward negative infinity (correct for negative
## coords).
static func floor_div(a: int, b: int) -> int:
	return floori(float(a) / float(b))


## Convert a hex cell coordinate `(q, r, layer)` to its chunk key.
static func cell_to_chunk(coord: Vector3i, size_qr: int, size_layer: int) -> Vector3i:
	return Vector3i(
		floor_div(coord.x, size_qr),
		floor_div(coord.y, size_qr),
		floor_div(coord.z, size_layer),
	)


## Convert a hex cell coordinate to its local coord inside `chunk_pos`.
## Local coords are always in [0, size) along each axis.
static func cell_to_local(coord: Vector3i, chunk_pos: Vector3i, size_qr: int, size_layer: int) -> Vector3i:
	return Vector3i(
		coord.x - chunk_pos.x * size_qr,
		coord.y - chunk_pos.y * size_qr,
		coord.z - chunk_pos.z * size_layer,
	)


## Convert `chunk_pos` + local cell coord back to a global coord.
static func local_to_cell(local: Vector3i, chunk_pos: Vector3i, size_qr: int, size_layer: int) -> Vector3i:
	return Vector3i(
		local.x + chunk_pos.x * size_qr,
		local.y + chunk_pos.y * size_qr,
		local.z + chunk_pos.z * size_layer,
	)


## Convert a world XZ position to its hex chunk key (ignores Y).
static func world_xz_to_chunk_qr(world_pos: Vector3, size_qr: int) -> Vector2i:
	var axial: Vector2i = HexGrid.world_to_axial(world_pos)
	return Vector2i(floor_div(axial.x, size_qr), floor_div(axial.y, size_qr))


## Convert a Y world position to a layer chunk key, given layer height.
static func world_y_to_chunk_layer(world_y: float, layer_height: float, size_layer: int) -> int:
	var layer: int = floori(world_y / layer_height)
	return floor_div(layer, size_layer)
