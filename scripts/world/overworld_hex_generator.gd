class_name OverworldHexGenerator
extends HexWorldGenerator

## Generates the overworld layer (layer 0 only). Lower layers are left
## empty (they exist if the player digs them out). Uses FastNoiseLite
## for biome + feature + mine-entrance placement.

var _biome_noise: FastNoiseLite
var _feature_noise: FastNoiseLite
var _mine_noise: FastNoiseLite


func _init(world_seed: int = 0) -> void:
	super(world_seed)
	# Higher frequency so neighboring hexes vary visibly inside one chunk.
	_biome_noise = _make_noise(0.08, 3, 0)
	_feature_noise = _make_noise(0.15, 2, 97)
	_mine_noise = _make_noise(0.02, 2, 217)


func generate_chunk(chunk_pos: Vector3i, chunk: HexWorldChunk, palette: TilePalette) -> void:
	# Only populate the surface layer (0). The overworld is flat.
	if chunk_pos.z != 0:
		return

	# Compute palette indices once.
	var idx_grass: int = palette.base_index(&"grass")
	var idx_dirt: int = palette.base_index(&"dirt")
	var idx_sand: int = palette.base_index(&"sand")
	var idx_stone: int = palette.base_index(&"stone")
	var idx_water: int = palette.base_index(&"water")

	var ov_forest: int = palette.overlay_index(&"forest")
	var ov_hill: int = palette.overlay_index(&"hill")
	var ov_mountain: int = palette.overlay_index(&"mountain")
	var ov_rocks_stone: int = palette.overlay_index(&"rocks_stone")
	var ov_rocks_sand: int = palette.overlay_index(&"rocks_sand")
	var ov_mine_entrance: int = palette.overlay_index(&"mine_entrance")

	var base_q: int = chunk_pos.x * chunk.size_qr
	var base_r: int = chunk_pos.y * chunk.size_qr

	for lq: int in chunk.size_qr:
		for lr: int in chunk.size_qr:
			var q: int = base_q + lq
			var r: int = base_r + lr
			var biome_val: float = _biome_noise.get_noise_2d(float(q), float(r))
			var feature_val: float = _feature_noise.get_noise_2d(float(q), float(r))
			var mine_val: float = _mine_noise.get_noise_2d(float(q), float(r))

			var base_id: int = idx_grass
			if biome_val < -0.4:
				base_id = idx_water
			elif biome_val < -0.2:
				base_id = idx_sand
			elif biome_val < 0.1:
				base_id = idx_grass
			elif biome_val < 0.3:
				base_id = idx_dirt
			else:
				base_id = idx_stone

			var cell: HexCell = HexCell.new(q, r, 0, base_id, -1)

			# Features: layered on top.
			if base_id == idx_grass and feature_val > 0.4:
				cell.overlay_id = ov_forest
			elif base_id == idx_grass and feature_val > 0.25:
				cell.overlay_id = ov_hill
			elif base_id == idx_stone and feature_val > 0.3:
				cell.overlay_id = ov_mountain
			elif base_id == idx_stone and feature_val > 0.1:
				cell.overlay_id = ov_rocks_stone
			elif base_id == idx_sand and feature_val > 0.3:
				cell.overlay_id = ov_rocks_sand

			# Mine entrances — sparse and on stone biome only.
			if base_id == idx_stone and mine_val > 0.55:
				cell.overlay_id = ov_mine_entrance

			# Guaranteed spawn-area mine entrance at (4, 4).
			if q == 4 and r == 4:
				cell.base_id = idx_stone
				cell.overlay_id = ov_mine_entrance

			var local: Vector3i = Vector3i(lq, lr, 0)
			chunk.set_cell_local(local, cell)
