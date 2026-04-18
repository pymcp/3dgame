class_name HexGrid
extends RefCounted

## Pointy-top axial hex math utilities. Pure static — no storage.
## Actual cell storage lives in `HexWorldChunk`.

const SQRT3: float = 1.7320508
## 1.0 / sqrt(3) — matches Kenney hex tile width of 1.0.
const HEX_SIZE: float = 0.57735027
## Kenney hex tile mesh Y extent. Used as a default for per-layer stacking.
const HEX_TILE_HEIGHT: float = 0.2

const AXIAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]


static func axial_to_world(q: int, r: int) -> Vector3:
	var x: float = HEX_SIZE * (SQRT3 * q + SQRT3 / 2.0 * r)
	var z: float = HEX_SIZE * (3.0 / 2.0 * r)
	return Vector3(x, 0.0, z)


static func world_to_axial(world_pos: Vector3) -> Vector2i:
	var q_frac: float = (SQRT3 / 3.0 * world_pos.x - 1.0 / 3.0 * world_pos.z) / HEX_SIZE
	var r_frac: float = (2.0 / 3.0 * world_pos.z) / HEX_SIZE
	return axial_round(q_frac, r_frac)


static func axial_round(q_frac: float, r_frac: float) -> Vector2i:
	var s_frac: float = -q_frac - r_frac
	var q_round: int = roundi(q_frac)
	var r_round: int = roundi(r_frac)
	var s_round: int = roundi(s_frac)
	var q_diff: float = absf(q_round - q_frac)
	var r_diff: float = absf(r_round - r_frac)
	var s_diff: float = absf(s_round - s_frac)
	if q_diff > r_diff and q_diff > s_diff:
		q_round = -r_round - s_round
	elif r_diff > s_diff:
		r_round = -q_round - s_round
	return Vector2i(q_round, r_round)


static func get_neighbors(q: int, r: int) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for dir: Vector2i in AXIAL_DIRECTIONS:
		neighbors.append(Vector2i(q + dir.x, r + dir.y))
	return neighbors


static func axial_distance(a: Vector2i, b: Vector2i) -> int:
	var diff: Vector2i = a - b
	return (absi(diff.x) + absi(diff.x + diff.y) + absi(diff.y)) / 2


## Draw a straight hex line from `a` to `b` (inclusive) using cube
## coordinate interpolation. Returns an ordered list of all hexes
## along the line.
static func hex_line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var dist: int = axial_distance(a, b)
	if dist == 0:
		return [a]
	var results: Array[Vector2i] = []
	# Convert axial→cube for lerp.
	var aq: float = float(a.x)
	var ar: float = float(a.y)
	var a_s: float = -aq - ar
	var bq: float = float(b.x)
	var br: float = float(b.y)
	var b_s: float = -bq - br
	for i: int in range(0, dist + 1):
		var t: float = float(i) / float(dist)
		var cq: float = aq + (bq - aq) * t
		var cr: float = ar + (br - ar) * t
		# Round cube coords back to axial.
		results.append(axial_round(cq, cr))
	return results
