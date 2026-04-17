---
description: "Use when working on world generation, terrain, chunks, hex grids, block grids, underground caves, ore veins, biome generation, FastNoiseLite configuration, or MultiMeshInstance3D optimization."
---
# World Generation Technical Reference

## Hex Grid (Overworld)

### Coordinate System
- Axial coordinates (q, r) — offset-free, clean math
- Axial to world position (flat-top hexes):
  ```gdscript
  const HEX_SIZE: float = 0.5  # Adjust after measuring Kenney hex model
  const SQRT3: float = 1.7320508
  
  func axial_to_world(q: int, r: int) -> Vector3:
      var x: float = HEX_SIZE * (SQRT3 * q + SQRT3 / 2.0 * r)
      var z: float = HEX_SIZE * (3.0 / 2.0 * r)
      return Vector3(x, 0.0, z)
  ```
- Neighbors (6 directions): `[Vector2i(1,0), Vector2i(1,-1), Vector2i(0,-1), Vector2i(-1,0), Vector2i(-1,1), Vector2i(0,1)]`

### Chunks
- Chunk size: 16×16 hexes
- Chunk key: `Vector2i(floor(q/16), floor(r/16))`
- Load radius: 3 chunks around each player
- For split-screen: load union of both players' chunk sets

### Biome Generation
- `FastNoiseLite` with `TYPE_SIMPLEX_SMOOTH`, frequency ~0.02
- Noise value ranges → terrain types:
  - `< -0.3` → WATER
  - `-0.3 to -0.1` → SAND
  - `-0.1 to 0.3` → GRASS
  - `0.3 to 0.6` → DIRT
  - `> 0.6` → STONE
- Secondary noise layer for elevation/features (forest, hill, mountain)
- Third noise layer for mine entrance placement (very sparse, ~1 per 100 hexes)

### Rendering
- Use `MultiMeshInstance3D` per tile type per chunk
- Load Kenney hex GLB as `PackedScene`, extract mesh at runtime
- Set `instance_count`, then per-instance `Transform3D` for position + Y rotation

## Block Grid (Underground)

### Data Structure
- 3D array: `blocks: Array` indexed as `blocks[x + z * CHUNK_SIZE + y * CHUNK_SIZE * CHUNK_SIZE]`
- Or Dictionary with `Vector3i` keys for sparse storage
- Chunk size: 32×32×32 blocks (`BLOCK_SIZE=0.5`, same 16³ unit physical space)
- Block types enum: `AIR, STONE, ROCK, ORE_IRON, ORE_GOLD, ORE_CRYSTAL, BEDROCK`

### Cave Generation
- `FastNoiseLite` with `TYPE_SIMPLEX_SMOOTH`, frequency ~0.04, 3D noise
- Threshold: noise value > 0.3 → AIR (cave), else → STONE
- Bottom layer (y=0) always BEDROCK
- Ore veins: separate noise per ore type, frequency ~0.075, very high threshold (~0.7)
  - Iron: most common, appears at all depths
  - Gold: rarer, deeper only (y < 16)
  - Crystal: rarest, deepest only (y < 8)

### Block-to-Model Mapping
- `STONE` → `cliff_block_stone.glb`
- `ROCK` → `cliff_block_rock.glb`
- `ORE_IRON` → `cliff_block_stone.glb` (tinted or with particle overlay) 
- `ORE_GOLD` → `cliff_block_stone.glb` (gold tint)
- `ORE_CRYSTAL` → `cliff_block_stone.glb` (purple tint)
- Blocks adjacent to caves → `cliff_blockCave_rock.glb` or `cliff_blockSlope_rock.glb`
- `AIR` → not rendered
- `BEDROCK` → `cliff_block_rock.glb` (unbreakable)

### Greedy Culling
- Only add a block to MultiMesh if it has at least one AIR neighbor in the 6 cardinal directions
- When a block is mined (set to AIR), re-check its 6 neighbors and add newly-exposed blocks to MultiMesh

### Rendering
- `MultiMeshInstance3D` per block type per chunk (same as overworld hex tiles)
- Block size: 0.5×0.5×0.5 units (`BLOCK_SIZE=0.5`)
- Blocks with air above use `cliff_blockSlope` mesh for natural cave ceilings
- Rebuild affected chunk's MultiMesh when a block changes
