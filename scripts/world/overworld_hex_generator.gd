class_name OverworldHexGenerator
extends HexWorldGenerator

## Generates the overworld: an island / continent surrounded by ocean.
## Per-column variable surface height from `SURFACE_MIN_LAYER` to
## `SURFACE_MAX_LAYER` on land; ocean columns have a shallow seabed
## (layers -1..-3) with water filled up to sea level. Bedrock sits at
## `BEDROCK_LAYER`. Stone fills the interior between bedrock and the
## surface layer.
##
## This generator is **deterministic** from the world seed: the same
## seed always produces the same island shape and terrain.

# --- key layer constants -------------------------------------------------

const SEA_LEVEL: int = 0
const SURFACE_MIN_LAYER: int = -3
const SURFACE_MAX_LAYER: int = 9
const BEDROCK_LAYER: int = -20
## Caves start appearing at or below this layer (in land columns).
const CAVE_MIN_LAYER: int = -4
## Topsoil depth (biome base continues below the surface for this many layers).
const TOPSOIL_DEPTH: int = 2
## Dirt layer thickness below the topsoil.
const DIRT_DEPTH: int = 3
## Ocean floor ranges in [SEABED_MIN, SEABED_MAX]. The value depends
## on how close the column is to the coast (shallow near shore).
const SEABED_MIN: int = -3
const SEABED_MAX: int = -1

# --- island shape constants ---------------------------------------------

const BASE_ISLAND_RADIUS_CHUNKS: int = 10
const ISLAND_RADIUS_JITTER_CHUNKS: int = 3

# --- noises -------------------------------------------------------------

var _biome_noise: FastNoiseLite
var _feature_noise: FastNoiseLite
var _mine_noise: FastNoiseLite
var _elevation_noise: FastNoiseLite
var _coastline_noise: FastNoiseLite
## Shallow ocean depth variation.
var _seabed_noise: FastNoiseLite
## Decides per-region cliff style (steep / mixed / stair).
var _cliff_style_noise: FastNoiseLite
## Ridge noise used to carve river lines on land columns.
var _river_noise: FastNoiseLite
## Sparse underground cave carving below CAVE_MIN_LAYER.
var _cave_noise: FastNoiseLite
## Ore placement noises.
var _ore_iron_noise: FastNoiseLite
var _ore_gold_noise: FastNoiseLite
var _ore_crystal_noise: FastNoiseLite
## Sparse portal placement noise.
var _portal_noise: FastNoiseLite

var _landmasses: Array[LandmassShape] = []
## Set after the first `generate_chunk` call (when we first learn the
## chunk size in hex units). Used to size the default landmass.
var _landmasses_initialized: bool = false

# Cached spiral-search result for the guaranteed mine entrance.
var _cached_anchor: Vector2i = Vector2i(4, 4)
var _anchor_resolved: bool = false
var _cached_portal_anchor: Vector2i = Vector2i(-4, -4)
var _portal_anchor_resolved: bool = false

# Cached palette indices (resolved on first generate_chunk call).
var _idx_grass: int = -1
var _idx_dirt: int = -1
var _idx_sand: int = -1
var _idx_stone: int = -1
var _idx_water: int = -1
var _idx_bedrock: int = -1
var _ov_forest: int = -1
var _ov_hill: int = -1
var _ov_mountain: int = -1
var _ov_rocks_stone: int = -1
var _ov_rocks_sand: int = -1
var _ov_mine_entrance: int = -1
var _ov_ore_iron: int = -1
var _ov_ore_gold: int = -1
var _ov_ore_crystal: int = -1
var _ov_portal: int = -1
var _indices_resolved: bool = false


func _init(world_seed: int = 0) -> void:
	super(world_seed)
	_biome_noise = _make_noise(0.08, 3, 0)
	_feature_noise = _make_noise(0.15, 2, 97)
	_mine_noise = _make_noise(0.02, 2, 217)
	_elevation_noise = _make_noise(0.03, 3, 331)
	_coastline_noise = _make_noise(0.02, 2, 409)
	_seabed_noise = _make_noise(0.08, 2, 503)
	_cliff_style_noise = _make_noise(0.015, 2, 613)
	_river_noise = _make_noise(0.04, 2, 719)
	_cave_noise = _make_noise(0.06, 3, 827)
	_ore_iron_noise = _make_noise(0.10, 2, 911)
	_ore_gold_noise = _make_noise(0.09, 2, 1013)
	_ore_crystal_noise = _make_noise(0.08, 2, 1117)
	_portal_noise = _make_noise(0.04, 2, 1223)


# --- API ----------------------------------------------------------------

## Compute the island's shape once we know the chunk size in hex
## units. Seeded deterministically from `seed`.
func _ensure_landmasses(chunk_size_qr: int) -> void:
	if _landmasses_initialized:
		return
	_landmasses_initialized = true

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var jitter_q: int = rng.randi_range(-ISLAND_RADIUS_JITTER_CHUNKS, ISLAND_RADIUS_JITTER_CHUNKS)
	var jitter_r: int = rng.randi_range(-ISLAND_RADIUS_JITTER_CHUNKS, ISLAND_RADIUS_JITTER_CHUNKS)
	var rq: float = float(BASE_ISLAND_RADIUS_CHUNKS + jitter_q) * float(chunk_size_qr)
	var rr: float = float(BASE_ISLAND_RADIUS_CHUNKS + jitter_r) * float(chunk_size_qr)

	_landmasses.append(
		LandmassShape.new(Vector2.ZERO, rq, rr, _coastline_noise, 0.22)
	)


## Returns the max `land_factor` across all landmasses. Positive on
## land, <= 0 in ocean.
func land_factor(q: int, r: int) -> float:
	var best: float = -1e9
	for lm: LandmassShape in _landmasses:
		var f: float = lm.land_factor(float(q), float(r))
		if f > best:
			best = f
	return best


## Compute the surface hex layer at (q, r). Land columns sit in
## [SEA_LEVEL, SURFACE_MAX_LAYER]; ocean columns return a seabed
## layer in [SEABED_MIN, SEABED_MAX].
##
## `cached_lf` lets callers pass an already-computed `land_factor`
## value to avoid a redundant landmass scan. Pass `INF` (the default)
## to compute it inline.
func surface_layer_at(q: int, r: int, cached_lf: float = INF) -> int:
	var lf: float = cached_lf if cached_lf != INF else land_factor(q, r)
	if lf <= 0.0:
		return _seabed_layer_at(q, r, lf)

	# Coastal taper: near the coast (small positive lf) the surface
	# starts at sea level and rises as we head inland. Well inland,
	# the full elevation noise range is expressed.
	var coast: float = clampf(lf * 4.0, 0.0, 1.0)
	var elev_raw: float = _elevation_noise.get_noise_2d(float(q), float(r))  # -1..1
	var elev_range: float = float(SURFACE_MAX_LAYER - SEA_LEVEL)
	# Bias so the average land surface sits above sea level, but allow
	# strongly-negative noise to dip below sea level inland — those
	# pockets become lakes in Phase 3.
	var elev_scaled: float = (elev_raw * 0.5 + 0.3) * elev_range
	var surface_f: float = float(SEA_LEVEL) + coast * elev_scaled

	# Cliff style — per-region terrace size. Terracing quantizes the
	# smooth elevation to multiples of `step`, so `step == 1` produces
	# natural single-layer staircases while `step == 3` produces
	# abrupt multi-layer cliffs between wider flat shelves.
	var step: int = cliff_step_at(q, r)
	if step > 1:
		surface_f = floorf(surface_f / float(step)) * float(step)

	# Rivers: ridge noise carves thin meandering lines across the
	# land. Only carve on land columns that currently sit above sea
	# level (don't deepen an existing lake bed).
	if is_river_at(q, r, lf) and surface_f >= float(SEA_LEVEL):
		return SEA_LEVEL - 1

	return clampi(roundi(surface_f), SURFACE_MIN_LAYER, SURFACE_MAX_LAYER)


## Step size (in layers) between adjacent height shelves at (q, r).
## 1 = every layer (staircase), 2 = 2-layer terraces (mixed),
## 3 = 3-layer terraces (steep cliffs).
func cliff_step_at(q: int, r: int) -> int:
	var v: float = _cliff_style_noise.get_noise_2d(float(q), float(r))
	if v > 0.25:
		return 3
	if v < -0.25:
		return 1
	return 2


## True if (q, r) sits on a river line. Rivers are thin ridges of
## |noise| < epsilon, which naturally produces curvy single-hex-wide
## paths. Connectivity to lakes / coasts is approximate — some rivers
## dead-end, which is accepted as a cosmetic trade-off.
##
## Pass `cached_lf` to skip the internal land-check landmass scan.
const RIVER_THRESHOLD: float = 0.04
func is_river_at(q: int, r: int, cached_lf: float = INF) -> bool:
	var lf: float = cached_lf if cached_lf != INF else land_factor(q, r)
	if lf <= 0.0:
		return false
	var v: float = _river_noise.get_noise_2d(float(q), float(r))
	return absf(v) < RIVER_THRESHOLD


## True if the column is part of a landmass (not ocean).
func is_land(q: int, r: int) -> bool:
	return land_factor(q, r) > 0.0


# --- generation ---------------------------------------------------------

func generate_chunk(chunk_pos: Vector3i, chunk: HexWorldChunk, palette: TilePalette) -> void:
	_ensure_landmasses(chunk.size_qr)
	_ensure_indices(palette)

	# Bedrock lives deep; chunks whose layer range is entirely above
	# `SURFACE_MAX_LAYER` or entirely below `BEDROCK_LAYER` are skipped.
	var chunk_bottom: int = chunk_pos.z * chunk.size_layer
	var chunk_top: int = chunk_bottom + chunk.size_layer - 1
	if chunk_bottom > SURFACE_MAX_LAYER:
		return
	if chunk_top < BEDROCK_LAYER:
		return

	var base_q: int = chunk_pos.x * chunk.size_qr
	var base_r: int = chunk_pos.y * chunk.size_qr

	for lq: int in chunk.size_qr:
		for lr: int in chunk.size_qr:
			var q: int = base_q + lq
			var r: int = base_r + lr
			_fill_column(q, r, lq, lr, chunk_bottom, chunk_top, chunk)


func _ensure_indices(palette: TilePalette) -> void:
	if _indices_resolved:
		return
	_indices_resolved = true
	_idx_grass = palette.base_index(&"grass")
	_idx_dirt = palette.base_index(&"dirt")
	_idx_sand = palette.base_index(&"sand")
	_idx_stone = palette.base_index(&"stone")
	_idx_water = palette.base_index(&"water")
	_idx_bedrock = palette.base_index(&"bedrock")
	_ov_forest = palette.overlay_index(&"forest")
	_ov_hill = palette.overlay_index(&"hill")
	_ov_mountain = palette.overlay_index(&"mountain")
	_ov_rocks_stone = palette.overlay_index(&"rocks_stone")
	_ov_rocks_sand = palette.overlay_index(&"rocks_sand")
	_ov_mine_entrance = palette.overlay_index(&"mine_entrance")
	_ov_ore_iron = palette.overlay_index(&"ore_iron")
	_ov_ore_gold = palette.overlay_index(&"ore_gold")
	_ov_ore_crystal = palette.overlay_index(&"ore_crystal")
	_ov_portal = palette.overlay_index(&"portal")


func _fill_column(
		q: int, r: int, lq: int, lr: int,
		chunk_bottom: int, chunk_top: int, chunk: HexWorldChunk
) -> void:
	var lf: float = land_factor(q, r)
	var is_ocean: bool = lf <= 0.0
	var surface_layer: int = surface_layer_at(q, r, lf)
	var surface_base: int = _choose_surface_base(q, r, surface_layer, lf)

	for ll: int in chunk.size_layer:
		var layer: int = chunk_bottom + ll
		if layer < BEDROCK_LAYER:
			continue
		if layer > SURFACE_MAX_LAYER:
			continue
		var cell: HexCell = _cell_for_layer(
			q, r, layer, surface_layer, surface_base, is_ocean
		)
		if cell == null:
			continue
		chunk.set_cell_local(Vector3i(lq, lr, ll), cell)

	# Decorative surface overlays only apply if the surface cell is
	# inside this chunk, above sea level, and on land (not seabed, not
	# submerged inland-lake bed).
	if surface_layer < chunk_bottom or surface_layer > chunk_top:
		return
	if is_ocean or surface_layer < SEA_LEVEL:
		return
	var surface_cell: HexCell = chunk.get_cell_local(Vector3i(lq, lr, surface_layer - chunk_bottom))
	if surface_cell == null:
		return
	# Skip surface overlays when the cell already carries an ore
	# overlay (ores win — see `_cell_for_layer`).
	if surface_cell.overlay_id >= 0:
		return
	_maybe_place_surface_overlay(q, r, surface_layer, surface_base, surface_cell)


func _cell_for_layer(
		q: int, r: int, layer: int, surface_layer: int,
		surface_base: int, is_ocean: bool
) -> HexCell:
	if layer == BEDROCK_LAYER:
		return HexCell.new(q, r, layer, _idx_bedrock, -1)
	if layer < BEDROCK_LAYER:
		return null
	if is_ocean:
		# Ocean seabed + water. Stone fills between bedrock and seabed.
		if layer == surface_layer:
			return HexCell.new(q, r, layer, surface_base, -1)
		if layer > surface_layer and layer <= SEA_LEVEL:
			return HexCell.new(q, r, layer, _idx_water, -1)
		if layer < surface_layer and layer > BEDROCK_LAYER:
			return HexCell.new(q, r, layer, _idx_stone, -1)
		return null

	# Land column.
	# Above surface: air, or water if sub-sea-level (inland lake).
	if layer > surface_layer:
		if surface_layer < SEA_LEVEL and layer <= SEA_LEVEL:
			return HexCell.new(q, r, layer, _idx_water, -1)
		return null
	# Surface layer itself.
	if layer == surface_layer:
		return HexCell.new(q, r, layer, surface_base, -1)

	# Below surface — apply strata + caves + ores.
	var depth_below: int = surface_layer - layer  # 1, 2, 3...

	# Sparse cave: carves void below CAVE_MIN_LAYER.
	if layer <= CAVE_MIN_LAYER and layer > BEDROCK_LAYER:
		var cave_val: float = _cave_noise.get_noise_3d(
			float(q), float(r) * 1.2, float(layer) * 2.0
		)
		if cave_val > 0.55:
			return null

	# Stratify: topsoil (biome continues), dirt band, then stone.
	var strata_base: int = _strata_base_for_depth(surface_base, depth_below)

	var cell: HexCell = HexCell.new(q, r, layer, strata_base, -1)

	# Ores only on stone strata, gated by depth, rarer/deeper than the mine.
	if strata_base == _idx_stone:
		var overlay_id: int = _ore_overlay_for(q, r, layer)
		if overlay_id >= 0:
			cell.overlay_id = overlay_id
	return cell


func _strata_base_for_depth(surface_base: int, depth_below: int) -> int:
	# Topsoil: biome base continues for `TOPSOIL_DEPTH` layers below
	# the surface — but only for soft biomes. Stone/bedrock/sand
	# surfaces transition to dirt/stone immediately so buried stone
	# peaks don't look like floating stone caps.
	if depth_below <= TOPSOIL_DEPTH and (surface_base == _idx_grass or surface_base == _idx_dirt):
		return surface_base
	if depth_below <= TOPSOIL_DEPTH + DIRT_DEPTH:
		return _idx_dirt
	return _idx_stone


func _ore_overlay_for(q: int, r: int, layer: int) -> int:
	# Iron — rarer than mine (mine: 0.55, here: 0.62), layers <= -2.
	if layer <= -2 and _ore_iron_noise.get_noise_3d(float(q), float(r), float(layer)) > 0.62:
		return _ov_ore_iron
	# Gold — deeper and rarer than mine (mine: -5@0.6, here: -8@0.68).
	if layer <= -8 and _ore_gold_noise.get_noise_3d(float(q), float(r), float(layer)) > 0.68:
		return _ov_ore_gold
	# Crystal — deepest + rarest (mine: -10@0.65, here: -14@0.72).
	if layer <= -14 and _ore_crystal_noise.get_noise_3d(float(q), float(r), float(layer)) > 0.72:
		return _ov_ore_crystal
	return -1


func _choose_surface_base(q: int, r: int, surface_layer: int, land_f: float) -> int:
	if land_f <= 0.0:
		# Ocean seabed: sand near shore, stone further out.
		if land_f > -0.08:
			return _idx_sand
		return _idx_stone

	# Beach: land right at (or below) sea level becomes sand — this
	# also handles inland-lake beds.
	if surface_layer <= SEA_LEVEL:
		return _idx_sand

	# Biome is coupled to elevation, modulated by biome noise for variety.
	var biome_val: float = _biome_noise.get_noise_2d(float(q), float(r))
	if surface_layer >= 6:
		if surface_layer >= 8 or biome_val > -0.2:
			return _idx_stone
		return _idx_dirt
	if surface_layer >= 2:
		if biome_val > 0.25:
			return _idx_dirt
		return _idx_grass
	if biome_val < -0.1:
		return _idx_sand
	return _idx_grass


func _maybe_place_surface_overlay(
		q: int, r: int, surface_layer: int, surface_base: int, surface_cell: HexCell
) -> void:
	var feature_val: float = _feature_noise.get_noise_2d(float(q), float(r))
	var mine_val: float = _mine_noise.get_noise_2d(float(q), float(r))

	# Biome + elevation gated decorative overlays.
	if surface_base == _idx_grass:
		# Dense forests in mid-elevation grass; hills just below the forest threshold.
		if surface_layer >= 1 and surface_layer <= 6 and feature_val > 0.15:
			surface_cell.overlay_id = _ov_forest
		elif surface_layer >= 2 and surface_layer <= 6 and feature_val > 0.0:
			surface_cell.overlay_id = _ov_hill
	elif surface_base == _idx_dirt:
		# Dirt tiles on hillside elevations — sparse hills, no forests.
		if surface_layer >= 2 and surface_layer <= 6 and feature_val > 0.0:
			surface_cell.overlay_id = _ov_hill
	elif surface_base == _idx_stone:
		# Mountains only on high stone; scattered stone rocks on peaks.
		if surface_layer >= 7 and feature_val > 0.2:
			surface_cell.overlay_id = _ov_mountain
		elif surface_layer >= 5 and feature_val > -0.1 and feature_val <= 0.2:
			surface_cell.overlay_id = _ov_rocks_stone
	elif surface_base == _idx_sand:
		# Desert rocks — any sand including beaches.
		if feature_val > 0.1:
			surface_cell.overlay_id = _ov_rocks_sand

	# Mine entrances — sparse, only on stone.
	if surface_base == _idx_stone and mine_val > 0.55:
		surface_cell.overlay_id = _ov_mine_entrance

	# Portals — rare, allowed on any walkable surface base. Don't
	# overwrite a mine entrance.
	if _ov_portal >= 0 and surface_cell.overlay_id < 0:
		var portal_val: float = _portal_noise.get_noise_2d(float(q), float(r))
		if portal_val > 0.65 and surface_base != _idx_water:
			surface_cell.overlay_id = _ov_portal

	# Guaranteed spawn-area mine entrance at the nearest valid land
	# column to (4, 4) (resolved once, cached).
	var anchor: Vector2i = _mine_entrance_anchor()
	if q == anchor.x and r == anchor.y:
		surface_cell.base_id = _idx_stone
		surface_cell.overlay_id = _ov_mine_entrance

	# Guaranteed spawn-area portal at the nearest valid land column
	# to (-4, -4) (opposite corner from the mine, so they don't
	# collide spatially).
	var portal_anchor: Vector2i = _portal_anchor()
	if _ov_portal >= 0 and q == portal_anchor.x and r == portal_anchor.y:
		surface_cell.base_id = _idx_stone
		surface_cell.overlay_id = _ov_portal


func _mine_entrance_anchor() -> Vector2i:
	if _anchor_resolved:
		return _cached_anchor
	# Spiral from (4, 4) looking for the nearest land column whose
	# surface sits above sea level. If nothing found within a
	# reasonable range, fall back to (4, 4).
	var origin: Vector2i = Vector2i(4, 4)
	var max_ring: int = 40
	for ring: int in range(0, max_ring + 1):
		if ring == 0:
			if _is_valid_anchor(origin.x, origin.y):
				_cached_anchor = origin
				_anchor_resolved = true
				return _cached_anchor
			continue
		# Walk the ring in axial coords.
		for dq: int in range(-ring, ring + 1):
			for dr: int in range(-ring, ring + 1):
				if HexGrid.axial_distance(Vector2i(0, 0), Vector2i(dq, dr)) != ring:
					continue
				var q: int = origin.x + dq
				var r: int = origin.y + dr
				if _is_valid_anchor(q, r):
					_cached_anchor = Vector2i(q, r)
					_anchor_resolved = true
					return _cached_anchor
	_anchor_resolved = true
	return _cached_anchor


func _is_valid_anchor(q: int, r: int) -> bool:
	if not is_land(q, r):
		return false
	return surface_layer_at(q, r) >= SEA_LEVEL + 1


## Spiral from (-4, -4) for the guaranteed spawn-area portal. Same
## validity rule as the mine anchor (land column above sea level).
func _portal_anchor() -> Vector2i:
	if _portal_anchor_resolved:
		return _cached_portal_anchor
	var origin: Vector2i = Vector2i(-4, -4)
	var max_ring: int = 40
	for ring: int in range(0, max_ring + 1):
		if ring == 0:
			if _is_valid_anchor(origin.x, origin.y):
				_cached_portal_anchor = origin
				_portal_anchor_resolved = true
				return _cached_portal_anchor
			continue
		for dq: int in range(-ring, ring + 1):
			for dr: int in range(-ring, ring + 1):
				if HexGrid.axial_distance(Vector2i(0, 0), Vector2i(dq, dr)) != ring:
					continue
				var q: int = origin.x + dq
				var r: int = origin.y + dr
				if _is_valid_anchor(q, r):
					_cached_portal_anchor = Vector2i(q, r)
					_portal_anchor_resolved = true
					return _cached_portal_anchor
	_portal_anchor_resolved = true
	return _cached_portal_anchor


func _seabed_layer_at(q: int, r: int, land_f: float) -> int:
	# Near shore: shallow (SEABED_MAX). Deep ocean: deeper (SEABED_MIN).
	# `land_f` is negative in ocean; more negative = further out.
	var depth_bias: float = clampf(-land_f * 2.0, 0.0, 1.0)
	var noise_val: float = _seabed_noise.get_noise_2d(float(q), float(r)) * 0.5 + 0.5  # 0..1
	var t: float = clampf(depth_bias * 0.6 + noise_val * 0.4, 0.0, 1.0)
	# t=0 -> SEABED_MAX (-1), t=1 -> SEABED_MIN (-3).
	var surface_f: float = lerpf(float(SEABED_MAX), float(SEABED_MIN), t)
	return clampi(roundi(surface_f), SEABED_MIN, SEABED_MAX)
