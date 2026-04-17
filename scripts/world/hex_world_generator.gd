class_name HexWorldGenerator
extends RefCounted

## Abstract base class for procedurally generating hex chunk contents.
## Concrete implementations (`OverworldHexGenerator`, `MineHexGenerator`)
## override `generate_chunk` to populate the supplied `HexWorldChunk`.

var seed: int = 0


func _init(world_seed: int = 0) -> void:
	seed = world_seed


## Populate `chunk.cells` (keyed by local `Vector3i`) for every cell
## the generator wants to exist in this chunk. Cells the generator does
## *not* insert are treated as open air / walkable empty space.
##
## `palette` is the owning world's `TilePalette`; implementations look
## up base/overlay indices from it.
##
## Default: no-op (empty chunk).
func generate_chunk(_chunk_pos: Vector3i, _chunk: HexWorldChunk, _palette: TilePalette) -> void:
	pass


## Helper for subclasses: build a FastNoiseLite with a repeatable seed
## derived from this generator's `seed` + an offset.
func _make_noise(frequency: float, octaves: int, seed_offset: int) -> FastNoiseLite:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_PERLIN
	n.frequency = frequency
	n.fractal_octaves = octaves
	n.seed = seed + seed_offset
	return n
