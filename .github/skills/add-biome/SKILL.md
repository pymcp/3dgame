---
name: add-biome
description: "Add a new overworld base tile (biome) to the hex-grid terrain generation system. Use when adding new terrain types, biome zones, or environmental themes."
---
# Add Biome

## When to Use
- Adding a new base terrain type (e.g., swamp, snow, volcanic)
- Modifying biome distribution or thresholds
- Adding a new `TileKind` to a palette

## Background
Biomes are `TileKind` resources (`scripts/world/tile_kind.gd`) held in a `TilePalette` (`scripts/world/tile_palette.gd`). The overworld palette is built by `DefaultPalettes.build_overworld()` in [scripts/world/default_palettes.gd](scripts/world/default_palettes.gd). The overworld generator (`scripts/world/overworld_hex_generator.gd`) samples biome noise at each cell and picks a base by `id`.

## Procedure

### 1. Add a `TileKind` to the overworld palette
In [scripts/world/default_palettes.gd](scripts/world/default_palettes.gd), extend `build_overworld()`:
```gdscript
var swamp: TileKind = TileKind.new()
swamp.id = &"swamp"
swamp.display_name = "Swamp"
swamp.mesh = MeshLoader.load_mesh("res://assets/hex_tiles/dirt.glb")
swamp.tint = Color(0.4, 0.5, 0.3)   # muddy green modulation
swamp.height = HexGrid.HEX_TILE_HEIGHT
swamp.hardness = 1.0                 # seconds to mine
swamp.drops = [ &"mud" ]
swamp.valid_layers = [0]             # surface-only
swamp.unbreakable = false
swamp.walkable_top = true
palette.bases.append(swamp)
```
The `id` is a `StringName` and must be unique within the palette.

### 2. Pick or reuse a Kenney hex mesh
Mesh options in `assets/hex_tiles/` (base terrain): `grass.glb`, `dirt.glb`, `sand.glb`, `stone.glb`, `water.glb`, plus `*-forest.glb`, `*-hill.glb`, `*-mountain.glb`, `*-rocks.glb`, `*-desert.glb`, `*-lumber.glb`, `*-island.glb` variants. Prefer tinting a common mesh (via `TileKind.tint`) over committing a new model.

### 3. Teach the generator when to place the new biome
In [scripts/world/overworld_hex_generator.gd](scripts/world/overworld_hex_generator.gd), biome noise picks a base `id` by thresholds. Add a branch:
```gdscript
if biome_val < -0.4:
    base_id = &"water"
elif biome_val < -0.15:
    base_id = &"sand"
elif biome_val < -0.05:
    base_id = &"swamp"          # new biome band
elif biome_val < 0.35:
    base_id = &"grass"
```
Order matters — the first threshold that matches wins.

### 4. (Optional) Restrict by layer
Set `valid_layers` on the `TileKind` to constrain where it can appear. An empty array means "any layer". The overworld only generates layer 0, so this is mainly useful if the mine generator is meant to pick the base too.

### 5. (Optional) Add an overlay for this biome
If the new biome should carry trees/rocks, also add an `OverlayKind` (see the `add-overlay` skill) with `allowed_on_bases = [&"swamp"]` and sample a feature-noise branch in the generator.

### 6. Tests
Update `tests/test_runner.gd` if a palette-lookup assertion is wanted for the new id. The existing `_test_palette_lookup` case already exercises `base_index(...)`; mirror it.

## Available Hex Terrain Models
From Kenney Hexagon Kit (`assets/hex_tiles/`):
- **Base**: `grass.glb`, `dirt.glb`, `sand.glb`, `stone.glb`, `water.glb`
- **Variants**: `grass-forest.glb`, `grass-hill.glb`, `dirt-lumber.glb`, `sand-desert.glb`, `sand-rocks.glb`, `stone-hill.glb`, `stone-mountain.glb`, `stone-rocks.glb`, `water-island.glb`, `water-rocks.glb`

For quick visual differentiation, prefer `tint` color modulation over adding new meshes.
