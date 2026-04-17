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


func _init(world_seed: int = 0) -> void:
	super(world_seed)
	_cave_noise = _make_noise(0.06, 3, 0)
	_ore_iron_noise = _make_noise(0.10, 2, 11)
	_ore_gold_noise = _make_noise(0.09, 2, 23)
	_ore_crystal_noise = _make_noise(0.08, 2, 41)
	_rocks_noise = _make_noise(0.12, 2, 59)
	_tunnel_noise = _make_noise(0.08, 2, 77)


func generate_chunk(chunk_pos: Vector3i, chunk: HexWorldChunk, palette: TilePalette) -> void:
	# Mine populates everything at-or-below the ceiling.
	var chunk_bottom_layer: int = chunk_pos.z * chunk.size_layer
	if chunk_bottom_layer > CEILING_LAYER:
		return

	var idx_dark_stone: int = palette.base_index(&"dark_stone")
	var idx_mine_dirt: int = palette.base_index(&"mine_dirt")
	var idx_bedrock: int = palette.base_index(&"bedrock")

	var ov_iron: int = palette.overlay_index(&"ore_iron")
	var ov_gold: int = palette.overlay_index(&"ore_gold")
	var ov_crystal: int = palette.overlay_index(&"ore_crystal")
	var ov_rocks: int = palette.overlay_index(&"rocks_mine")
	var ov_ladder_up: int = palette.overlay_index(&"ladder_up")

	var base_q: int = chunk_pos.x * chunk.size_qr
	var base_r: int = chunk_pos.y * chunk.size_qr
	var base_l: int = chunk_pos.z * chunk.size_layer

	for lq: int in chunk.size_qr:
		for lr: int in chunk.size_qr:
			for ll: int in chunk.size_layer:
				var q: int = base_q + lq
				var r: int = base_r + lr
				var layer: int = base_l + ll
				if layer > CEILING_LAYER:
					continue
				if layer < BEDROCK_LAYER:
					continue

				var in_chamber: bool = _in_spawn_chamber(q, r)
				var local: Vector3i = Vector3i(lq, lr, ll)

				# Bedrock floor.
				if layer == BEDROCK_LAYER:
					chunk.set_cell_local(local, HexCell.new(q, r, layer, idx_bedrock, -1))
					continue

				# Layers above the walkable tunnels are left empty. A
				# rendered ceiling would sit directly under the iso
				# camera's view path and occlude the chamber. The
				# dark mine `Environment` background handles the
				# visual "enclosure" overhead.
				if layer > CHAMBER_AIR_TOP:
					continue

				# Air tunnels / chamber: layers 0..CHAMBER_AIR_TOP.
				if layer >= 0 and layer <= CHAMBER_AIR_TOP:
					if in_chamber:
						# Leave empty — walkable chamber.
						continue
					# Outside chamber: carve winding tunnels, else solid wall.
					var t: float = _tunnel_noise.get_noise_3d(
						float(q) * 1.0, float(r) * 1.0, float(layer) * 3.0
					)
					if t > 0.35:
						continue
					# Wall.
					chunk.set_cell_local(local, HexCell.new(q, r, layer, idx_dark_stone, -1))
					continue

				# Floor layer (-1): solid floor in chamber, caves/ore below.
				if layer == -1 and in_chamber:
					var floor_cell: HexCell = HexCell.new(q, r, layer, idx_dark_stone, -1)
					if q == 0 and r == 0:
						floor_cell.overlay_id = ov_ladder_up
					chunk.set_cell_local(local, floor_cell)
					continue

				# Deep mine: 3D perlin > threshold → empty (caves).
				var cave: float = _cave_noise.get_noise_3d(float(q), float(r) * 1.4, float(layer) * 2.0)
				if cave > 0.35:
					continue

				var base_id: int = idx_dark_stone
				# Shallow mine dirt band (layer -1 .. -3).
				if layer >= -3:
					var dirt_val: float = _rocks_noise.get_noise_2d(float(q) * 0.7, float(r) * 0.7)
					if dirt_val > 0.1:
						base_id = idx_mine_dirt

				var cell: HexCell = HexCell.new(q, r, layer, base_id, -1)

				# Ores — layered by depth.
				if layer <= -1 and _ore_iron_noise.get_noise_3d(float(q), float(r), float(layer)) > 0.55:
					cell.overlay_id = ov_iron
				elif layer <= -5 and _ore_gold_noise.get_noise_3d(float(q), float(r), float(layer)) > 0.6:
					cell.overlay_id = ov_gold
				elif layer <= -10 and _ore_crystal_noise.get_noise_3d(float(q), float(r), float(layer)) > 0.65:
					cell.overlay_id = ov_crystal
				elif base_id == idx_dark_stone and _rocks_noise.get_noise_3d(float(q), float(r), float(layer)) > 0.55:
					cell.overlay_id = ov_rocks

				chunk.set_cell_local(local, cell)


func _in_spawn_chamber(q: int, r: int) -> bool:
	return HexGrid.axial_distance(Vector2i(q, r), Vector2i.ZERO) <= SPAWN_RADIUS
