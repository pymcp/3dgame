class_name MineHexGenerator
extends HexWorldGenerator

## Generates the mine — a deep, infinite-in-q/r world with a solid
## stone ceiling (layer `CEILING_LAYER`), walkable air layers above the
## spawn chamber floor, carved caves and ore deposits below, and a
## bedrock floor far below. Layer 0..CHAMBER_AIR_TOP is the "entrance
## level" (spawn chamber + open tunnels). Layers below carry more
## dangerous/rare ores.

const SPAWN_RADIUS: int = 2              # hex radius of the cleared spawn chamber
const CHAMBER_AIR_TOP: int = 1           # chamber/tunnels are air on layers [0 .. this]
const CEILING_LAYER: int = CHAMBER_AIR_TOP + 1
const BEDROCK_LAYER: int = -20

var _cave_noise: FastNoiseLite
var _ore_iron_noise: FastNoiseLite
var _ore_gold_noise: FastNoiseLite
var _ore_crystal_noise: FastNoiseLite
var _rocks_noise: FastNoiseLite
var _tunnel_noise: FastNoiseLite

# Cached palette indices (resolved once on first chunk).
var _idx_dark_stone: int = -1
var _idx_mine_dirt: int = -1
var _idx_bedrock: int = -1
var _ov_iron: int = -1
var _ov_gold: int = -1
var _ov_crystal: int = -1
var _ov_rocks: int = -1
var _ov_ladder_up: int = -1
var _indices_resolved: bool = false


func _init(world_seed: int = 0) -> void:
	super(world_seed)
	_cave_noise = _make_noise(0.06, 3, 0)
	_ore_iron_noise = _make_noise(0.10, 2, 11)
	_ore_gold_noise = _make_noise(0.09, 2, 23)
	_ore_crystal_noise = _make_noise(0.08, 2, 41)
	_rocks_noise = _make_noise(0.12, 2, 59)
	_tunnel_noise = _make_noise(0.08, 2, 77)


func _ensure_indices(palette: TilePalette) -> void:
	if _indices_resolved:
		return
	_indices_resolved = true
	_idx_dark_stone = palette.base_index(&"dark_stone")
	_idx_mine_dirt = palette.base_index(&"mine_dirt")
	_idx_bedrock = palette.base_index(&"bedrock")
	_ov_iron = palette.overlay_index(&"ore_iron")
	_ov_gold = palette.overlay_index(&"ore_gold")
	_ov_crystal = palette.overlay_index(&"ore_crystal")
	_ov_rocks = palette.overlay_index(&"rocks_mine")
	_ov_ladder_up = palette.overlay_index(&"ladder_up")


func generate_chunk(chunk_pos: Vector3i, chunk: HexWorldChunk, palette: TilePalette) -> void:
	# Mine populates everything at-or-below the ceiling.
	var chunk_bottom_layer: int = chunk_pos.z * chunk.size_layer
	if chunk_bottom_layer > CEILING_LAYER:
		return

	_ensure_indices(palette)

	var base_q: int = chunk_pos.x * chunk.size_qr
	var base_r: int = chunk_pos.y * chunk.size_qr
	var base_l: int = chunk_pos.z * chunk.size_layer

	# Clamp the layer loop to the populated range so we don't iterate
	# all `chunk.size_layer` slots when the chunk straddles the
	# ceiling or extends below bedrock.
	var ll_lo: int = maxi(0, BEDROCK_LAYER - base_l)
	var ll_hi: int = mini(chunk.size_layer - 1, CEILING_LAYER - base_l)
	if ll_hi < ll_lo:
		return

	for lq: int in chunk.size_qr:
		var q: int = base_q + lq
		for lr: int in chunk.size_qr:
			var r: int = base_r + lr
			# Hoist the per-column chamber check out of the layer loop.
			var in_chamber: bool = _in_spawn_chamber(q, r)
			for ll: int in range(ll_lo, ll_hi + 1):
				var layer: int = base_l + ll
				var local: Vector3i = Vector3i(lq, lr, ll)

				# Bedrock floor.
				if layer == BEDROCK_LAYER:
					chunk.set_cell_local(local, HexCell.new(q, r, layer, _idx_bedrock, -1))
					continue

				# Layers above the walkable tunnels are left empty. A
				# rendered ceiling would sit directly under the iso
				# camera's view path and occlude the chamber.
				if layer > CHAMBER_AIR_TOP:
					continue

				# Air tunnels / chamber: layers 0..CHAMBER_AIR_TOP.
				if layer >= 0:  # already <= CHAMBER_AIR_TOP from above
					if in_chamber:
						continue  # walkable chamber — empty
					# Outside chamber: carve winding tunnels, else solid wall.
					var t: float = _tunnel_noise.get_noise_3d(
						float(q), float(r), float(layer) * 3.0
					)
					if t > 0.35:
						continue
					chunk.set_cell_local(local, HexCell.new(q, r, layer, _idx_dark_stone, -1))
					continue

				# Floor layer (-1): solid floor in chamber.
				if layer == -1 and in_chamber:
					var floor_cell: HexCell = HexCell.new(q, r, layer, _idx_dark_stone, -1)
					if q == 0 and r == 0:
						floor_cell.overlay_id = _ov_ladder_up
					chunk.set_cell_local(local, floor_cell)
					continue

				# Deep mine: 3D perlin > threshold → empty (caves).
				var cave: float = _cave_noise.get_noise_3d(
					float(q), float(r) * 1.4, float(layer) * 2.0
				)
				if cave > 0.35:
					continue

				var base_id: int = _idx_dark_stone
				# Shallow mine dirt band (layer -1 .. -3).
				if layer >= -3:
					var dirt_val: float = _rocks_noise.get_noise_2d(
						float(q) * 0.7, float(r) * 0.7
					)
					if dirt_val > 0.1:
						base_id = _idx_mine_dirt

				var cell: HexCell = HexCell.new(q, r, layer, base_id, -1)

				# Ores — layered by depth. Single noise call per branch.
				var qf: float = float(q)
				var rf: float = float(r)
				var lf: float = float(layer)
				if layer <= -1 and _ore_iron_noise.get_noise_3d(qf, rf, lf) > 0.55:
					cell.overlay_id = _ov_iron
				elif layer <= -5 and _ore_gold_noise.get_noise_3d(qf, rf, lf) > 0.6:
					cell.overlay_id = _ov_gold
				elif layer <= -10 and _ore_crystal_noise.get_noise_3d(qf, rf, lf) > 0.65:
					cell.overlay_id = _ov_crystal
				elif base_id == _idx_dark_stone and _rocks_noise.get_noise_3d(qf, rf, lf) > 0.55:
					cell.overlay_id = _ov_rocks

				chunk.set_cell_local(local, cell)


func _in_spawn_chamber(q: int, r: int) -> bool:
	return HexGrid.axial_distance(Vector2i(q, r), Vector2i.ZERO) <= SPAWN_RADIUS
