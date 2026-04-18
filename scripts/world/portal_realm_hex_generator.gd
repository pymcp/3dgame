class_name PortalRealmHexGenerator
extends HexWorldGenerator

## Generates the portal realm — a sparse archipelago of floating
## purple-stone hex islands suspended in a deep void. Coordinates are
## "compressed" relative to the overworld (see main.gd: portal entry
## at overworld (q,r) maps to portal-realm (floori(q/10), floori(r/10))),
## so the realm is intentionally much smaller than the overworld.
##
## Terrain shape:
##   - Thin platforms in layers `[FLOOR_MIN..FLOOR_MAX]` carved by 3D
##     `_island_noise`. Anything outside that range is empty void.
##   - A single `portal_bedrock` floor cell at `BEDROCK_LAYER`
##     (purely a safety net so falling players aren't lost forever).
##   - Sparse `ore_amethyst` overlays on stone columns.
##
## Return portals are NOT placed by this generator — main.gd seeds
## them on demand when a player enters the realm via an overworld
## portal, so each entry has its paired exit at the compressed coord.

const BEDROCK_LAYER: int = -20
## Floating-island band. Layers in [FLOOR_MIN..FLOOR_MAX] may carry
## `portal_stone`/`portal_dirt` hexes; everything else is empty void.
const FLOOR_MIN: int = -3
const FLOOR_MAX: int = 3

var _island_noise: FastNoiseLite
var _dirt_noise: FastNoiseLite
var _ore_noise: FastNoiseLite

# Cached palette indices.
var _idx_portal_stone: int = -1
var _idx_portal_dirt: int = -1
var _idx_portal_bedrock: int = -1
var _ov_amethyst: int = -1
var _ov_portal_return: int = -1
var _indices_resolved: bool = false


func _init(world_seed: int = 0) -> void:
	super(world_seed)
	# Lower frequency than the mine — islands are larger / more sparse.
	_island_noise = _make_noise(0.05, 3, 4201)
	_dirt_noise = _make_noise(0.10, 2, 4297)
	_ore_noise = _make_noise(0.09, 2, 4391)


func _ensure_indices(palette: TilePalette) -> void:
	if _indices_resolved:
		return
	_indices_resolved = true
	_idx_portal_stone = palette.base_index(&"portal_stone")
	_idx_portal_dirt = palette.base_index(&"portal_dirt")
	_idx_portal_bedrock = palette.base_index(&"portal_bedrock")
	_ov_amethyst = palette.overlay_index(&"ore_amethyst")
	_ov_portal_return = palette.overlay_index(&"portal_return")


func generate_chunk(chunk_pos: Vector3i, chunk: HexWorldChunk, palette: TilePalette) -> void:
	# Skip chunks fully above the floating-island band or fully below
	# bedrock.
	var chunk_bottom: int = chunk_pos.z * chunk.size_layer
	var chunk_top: int = chunk_bottom + chunk.size_layer - 1
	if chunk_bottom > FLOOR_MAX:
		return
	if chunk_top < BEDROCK_LAYER:
		return

	_ensure_indices(palette)

	var base_q: int = chunk_pos.x * chunk.size_qr
	var base_r: int = chunk_pos.y * chunk.size_qr
	var base_l: int = chunk_pos.z * chunk.size_layer

	# Clamp the layer loop to the populated range.
	var ll_lo: int = maxi(0, BEDROCK_LAYER - base_l)
	var ll_hi: int = mini(chunk.size_layer - 1, FLOOR_MAX - base_l)
	if ll_hi < ll_lo:
		return

	for lq: int in chunk.size_qr:
		var q: int = base_q + lq
		for lr: int in chunk.size_qr:
			var r: int = base_r + lr
			var qf: float = float(q)
			var rf: float = float(r)
			for ll: int in range(ll_lo, ll_hi + 1):
				var layer: int = base_l + ll

				# Far-below bedrock floor.
				if layer == BEDROCK_LAYER:
					chunk.set_cell_local(
						Vector3i(lq, lr, ll),
						HexCell.new(q, r, layer, _idx_portal_bedrock, -1)
					)
					continue

				# Anything outside the floating-island band is void.
				if layer < FLOOR_MIN or layer > FLOOR_MAX:
					continue

				# 3D noise carves the islands. Higher threshold = more
				# void. Bias slightly toward the middle layer so
				# islands cluster near layer 0.
				var dist_from_mid: float = absf(float(layer)) * 0.08
				var n: float = _island_noise.get_noise_3d(qf, rf, float(layer) * 1.5)
				if n - dist_from_mid < 0.10:
					continue

				# Pick base: dirt on the top of an island, stone below.
				# Approx "top": no neighbor cell at layer+1.
				var above_n: float = -1e9
				if layer + 1 <= FLOOR_MAX:
					above_n = _island_noise.get_noise_3d(qf, rf, float(layer + 1) * 1.5) \
						- absf(float(layer + 1)) * 0.08
				var base_id: int = _idx_portal_stone
				if above_n < 0.10 and _dirt_noise.get_noise_2d(qf, rf) > 0.0:
					base_id = _idx_portal_dirt

				var cell: HexCell = HexCell.new(q, r, layer, base_id, -1)

				# Sparse amethyst on stone, deeper preferred.
				if base_id == _idx_portal_stone and layer <= 0:
					if _ore_noise.get_noise_3d(qf, rf, float(layer)) > 0.55:
						cell.overlay_id = _ov_amethyst

				chunk.set_cell_local(Vector3i(lq, lr, ll), cell)
